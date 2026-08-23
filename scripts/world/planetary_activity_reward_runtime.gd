class_name PlanetaryActivityRewardRuntime
extends RefCounted

## Production activity/reward handoff for the authored Ember visit.
##
## ActivityDirector remains the activity authority and the caller supplies the
## existing GameFlow reward authority as a Callable. This bridge owns only the
## generation-fenced handoff: it never creates an activity, reward store,
## inventory, clock, ship, landing, save, or network authority of its own.

const ObjectiveManifestScript := preload(
	"res://scripts/world/planetary_objective_reward_recovery_contract.gd"
)
const ActivityDirectorScript := preload("res://scripts/activities/activity_director.gd")

const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MAX_ACTIVITY_ID_LENGTH := 64
const REQUIRED_WORLD_ID: StringName = &"ember_moon"
const REQUIRED_REWARD_STORE_ID: StringName = &"game_flow_reward_store"
const REQUIRED_REWARD_AUTHORITY_ID: StringName = &"game_flow_reward_authority"

enum State {
	IDLE,
	READY,
	ACTIVE,
	AWAITING_REWARD,
	COMPLETED,
	FAILED,
	DETACHED,
}

var _manifest: PlanetaryObjectiveRewardRecoveryContract
var _director: ActivityDirector
var _reward_sink := Callable()
var _state := State.IDLE
var _run_generation := 0
var _attachment_generation := 0
var _activity_generation := 0
var _active_activity_id: StringName = &""
var _completed_activity_id: StringName = &""
var _pending_reward: Dictionary = {}
var _committed_reward: Dictionary = {}
var _failure_reason: StringName = &""
var _configuration_errors := PackedStringArray()
var _bound_once := false


func _init(manifest: PlanetaryObjectiveRewardRecoveryContract = null) -> void:
	_manifest = manifest if manifest != null else ObjectiveManifestScript.new()
	_configuration_errors = _validate_manifest()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


## Binds the already-existing ActivityDirector and GameFlow reward callback.
## The callback must return {"accepted": bool, "reason": StringName} and is
## called only after a real ActivityDirector completion snapshot is observed.
func bind(
		director: ActivityDirector,
		reward_sink: Callable,
		expected_attachment_generation: int = 0
	) -> Dictionary:
	if _state == State.DETACHED:
		return _reject(&"detached")
	if _bound_once:
		return _reject(&"already_bound")
	if expected_attachment_generation != _attachment_generation:
		return _reject(&"stale_attachment_generation")
	if not is_configuration_valid():
		return _reject(&"invalid_configuration")
	if director == null or not is_instance_valid(director) \
			or director.is_queued_for_deletion() or not director.is_inside_tree():
		return _reject(&"activity_director_unavailable")
	if not reward_sink.is_valid():
		return _reject(&"reward_sink_unavailable")
	if not director.has_signal(&"activity_completed"):
		return _reject(&"activity_completion_signal_unavailable")
	_director = director
	_reward_sink = reward_sink
	_director.activity_completed.connect(_on_activity_completed)
	_bound_once = true
	_state = State.READY
	return _accept(&"bound")


func begin_visit(run_generation: int, attachment_generation: int) -> Dictionary:
	if _state not in [State.READY, State.DETACHED, State.FAILED, State.COMPLETED]:
		return _reject(&"not_ready")
	if not _valid_generation(run_generation) or not _valid_generation(attachment_generation):
		return _reject(&"invalid_generation")
	if _state in [State.DETACHED, State.FAILED, State.COMPLETED] and attachment_generation <= _attachment_generation:
		return _reject(&"stale_attachment_generation")
	if _state in [State.FAILED, State.COMPLETED]:
		_active_activity_id = &""
		_completed_activity_id = &""
		_pending_reward = {}
		_committed_reward = {}
	_run_generation = run_generation
	_attachment_generation = attachment_generation
	_failure_reason = &""
	_state = State.ACTIVE if _pending_reward.is_empty() else State.AWAITING_REWARD
	return _accept(&"visit_started")


func start_activity(
		activity_id: StringName,
		expected_run_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var rejection := _running_rejection(expected_run_generation, expected_attachment_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if _state != State.ACTIVE:
		return _reject(&"activity_not_available")
	if _active_activity_id != &"":
		return _reject(&"activity_already_active")
	if _manifest.activity_ids.find(String(activity_id)) < 0:
		return _reject(&"unknown_planetary_activity")
	var result := _director.start_activity(activity_id)
	if not bool(result.get("accepted", false)):
		return _reject(result.get("reason", &"activity_start_rejected") as StringName)
	_active_activity_id = activity_id
	_activity_generation = int(result.get("generation", 0))
	return _with_runtime(result, true, &"activity_started")


func submit_position(
		position: Vector3,
		expected_activity_generation: int,
		expected_run_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var rejection := _running_rejection(
		expected_run_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _reject(rejection)
	if _state != State.ACTIVE or _active_activity_id == &"":
		return _reject(&"activity_not_active")
	if not position.is_finite():
		return _reject(&"position_invalid")
	if expected_activity_generation != _activity_generation:
		return _reject(&"stale_activity_generation")
	var result := _director.submit_position(
		_active_activity_id, position, expected_activity_generation
	)
	if not bool(result.get("accepted", false)):
		return _with_runtime(result, false, result.get("reason", &"activity_position_rejected") as StringName)
	return _with_runtime(result, true, &"activity_position_submitted")


## Commits exactly one reward through the existing external reward authority.
## The caller must present the completion generation and IDs returned by this
## bridge; no arbitrary activity or reward key can be substituted.
func commit_reward(
		activity_id: StringName,
		activity_generation: int,
		expected_run_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var rejection := _running_rejection(
		expected_run_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _reject(rejection)
	if _state != State.AWAITING_REWARD:
		return _reject(&"reward_not_pending")
	if activity_id != _completed_activity_id \
			or activity_generation != _activity_generation:
		return _reject(&"reward_completion_identity_mismatch")
	if _committed_reward.is_empty() == false:
		return _reject(&"reward_already_committed")
	if not _reward_sink.is_valid():
		return _fail(&"reward_sink_unavailable")
	var result: Variant = _reward_sink.call(_pending_reward.duplicate(true))
	if not result is Dictionary or not bool((result as Dictionary).get("accepted", false)):
		return _reject(result.get("reason", &"reward_commit_rejected") as StringName if result is Dictionary else &"reward_commit_rejected")
	_committed_reward = _pending_reward.duplicate(true)
	_committed_reward["authority_result"] = (result as Dictionary).duplicate(true)
	_pending_reward = {}
	_state = State.COMPLETED
	return _with_runtime(_committed_reward, true, &"reward_committed")


func detach(
		expected_run_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _state == State.IDLE or _state == State.READY:
		return _reject(&"not_started")
	if expected_run_generation != _run_generation \
			or expected_attachment_generation != _attachment_generation:
		return _reject(&"stale_generation")
	_state = State.DETACHED
	return _accept(&"detached")


func fail(reason: StringName, expected_run_generation: int, expected_attachment_generation: int) -> Dictionary:
	var rejection := _running_rejection(expected_run_generation, expected_attachment_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if _state in [State.COMPLETED, State.FAILED]:
		return _reject(&"terminal_state")
	if _state == State.ACTIVE and _active_activity_id != &"":
		if not _director.fail_activity(_active_activity_id, reason, _activity_generation):
			return _reject(&"activity_failure_rejected")
	_failure_reason = reason if not reason.is_empty() else &"planetary_activity_failed"
	_state = State.FAILED
	return _accept(_failure_reason)


func get_state() -> int:
	return _state


func get_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"state": _state_id(),
		"world_id": _manifest.world_id,
		"run_generation": _run_generation,
		"attachment_generation": _attachment_generation,
		"activity_id": _active_activity_id,
		"activity_generation": _activity_generation,
		"completed_activity_id": _completed_activity_id,
		"pending_reward": _pending_reward.duplicate(true),
		"committed_reward": _committed_reward.duplicate(true),
		"failure_reason": _failure_reason,
		"authority": {
			"activity_handoff": true,
			"reward_handoff": true,
			"reward_store": false,
			"ship": false,
			"landing": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := _configuration_errors.duplicate()
	if _state == State.AWAITING_REWARD and _pending_reward.is_empty():
		errors.append("awaiting reward requires a pending receipt")
	if _state == State.COMPLETED and _committed_reward.is_empty():
		errors.append("completed state requires a committed reward receipt")
	return {
		"schema_version": 1,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"production_wiring": _bound_once,
		"owns_activity_authority": false,
		"owns_reward_store": false,
		"owns_save_authority": false,
		"owns_network_authority": false,
	}.duplicate(true)


func _on_activity_completed(activity_id: StringName, generation: int) -> void:
	if _state != State.ACTIVE or activity_id != _active_activity_id \
			or generation != _activity_generation:
		return
	var index := _manifest.activity_ids.find(String(activity_id))
	if index < 0 or index >= _manifest.reward_ids.size():
		_state = State.FAILED
		_failure_reason = &"activity_reward_mapping_missing"
		return
	_completed_activity_id = activity_id
	_pending_reward = {
		"world_id": _manifest.world_id,
		"activity_id": activity_id,
		"objective_id": StringName(_manifest.objective_ids[index]),
		"activity_generation": generation,
		"reward_id": StringName(_manifest.reward_ids[index]),
		"reward_store_id": _manifest.reward_store_id,
		"reward_authority_id": _manifest.reward_authority_id,
		"return_target_id": _manifest.return_target_id,
		"recovery_id": StringName(_manifest.activity_recovery_ids[index]),
		"run_generation": _run_generation,
		"attachment_generation": _attachment_generation,
	}
	_state = State.AWAITING_REWARD


func _validate_manifest() -> PackedStringArray:
	var errors := PackedStringArray()
	if _manifest == null or not _manifest.is_definition_valid():
		errors.append("planetary objective/reward manifest is invalid")
		return errors
	if _manifest.world_id != REQUIRED_WORLD_ID:
		errors.append("manifest world must be ember_moon")
	if _manifest.reward_store_id != REQUIRED_REWARD_STORE_ID:
		errors.append("manifest must use the existing reward store")
	if _manifest.reward_authority_id != REQUIRED_REWARD_AUTHORITY_ID:
		errors.append("manifest must use the existing reward authority")
	return errors


func _running_rejection(expected_run: int, expected_attachment: int) -> StringName:
	if _state == State.DETACHED:
		return &"detached"
	if not _bound_once or _director == null or not is_instance_valid(_director) \
			or not _director.is_inside_tree():
		return &"activity_director_unavailable"
	if expected_run != _run_generation:
		return &"stale_run_generation"
	if expected_attachment != _attachment_generation:
		return &"stale_attachment_generation"
	return &""


func _valid_generation(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_GENERATION


func _state_id() -> StringName:
	return [
		&"idle", &"ready", &"active", &"awaiting_reward", &"completed",
		&"failed", &"detached",
	][_state]


func _accept(reason: StringName) -> Dictionary:
	return _with_runtime({}, true, reason)


func _reject(reason: StringName) -> Dictionary:
	return _with_runtime({}, false, reason)


func _fail(reason: StringName) -> Dictionary:
	_failure_reason = reason
	_state = State.FAILED
	return _reject(reason)


func _with_runtime(value: Dictionary, accepted: bool, reason: StringName) -> Dictionary:
	var result := value.duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	result["runtime"] = get_snapshot()
	return result
