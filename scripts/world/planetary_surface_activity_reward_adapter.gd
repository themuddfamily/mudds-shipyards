class_name PlanetarySurfaceActivityRewardAdapter
extends RefCounted

## Clean production adapter between the existing EmberSurfaceLoopHost and the
## planetary activity/reward runtime. The Host remains the physical lifecycle
## owner; ActivityDirector remains the activity owner; the injected callback is
## the existing GameFlow reward authority. This adapter only joins their live
## identity and generation fences and never mutates the Host or creates a store.

const RuntimeScript := preload("res://scripts/world/planetary_activity_reward_runtime.gd")
const HostScript := preload("res://scripts/world/ember_surface_loop_host.gd")

const REQUIRED_HOST_ID: StringName = &"ember_surface_loop"
const REQUIRED_WORLD_ID: StringName = &"ember_moon"
const REQUIRED_PHASE: StringName = &"on_foot"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

enum State {
	IDLE,
	READY,
	ACTIVE,
	DETACHED,
	COMPLETED,
	FAILED,
}

var _host: Object
var _runtime: PlanetaryActivityRewardRuntime
var _state := State.IDLE
var _configuration_errors := PackedStringArray()
var _host_instance_id := 0
var _bound := false
var _sequence_ids: Array[StringName] = []
var _sequence_index := -1


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


## The Host argument is intentionally read through its public API so this
## adapter can be composed by Main/GameFlow without reparenting or ownership
## coupling. A real EmberSurfaceLoopHost satisfies the exact identity contract.
func bind(
		host: Object,
		runtime: PlanetaryActivityRewardRuntime,
		director: ActivityDirector,
		reward_sink: Callable
	) -> Dictionary:
	if _bound:
		return _reject(&"already_bound")
	var host_error := _validate_host(host)
	if not host_error.is_empty():
		return _reject(host_error)
	if runtime == null:
		return _reject(&"runtime_unavailable")
	var runtime_bind := runtime.bind(director, reward_sink, 0)
	if not bool(runtime_bind.get("accepted", false)):
		return _reject(runtime_bind.get("reason", &"runtime_bind_rejected") as StringName)
	_host = host
	_runtime = runtime
	_host_instance_id = host.get_instance_id()
	_bound = true
	_state = State.READY
	return _accept(&"bound")


func begin_activity(activity_id: StringName) -> Dictionary:
	var rejection := _live_host_rejection()
	if not rejection.is_empty():
		return _reject(rejection)
	if _state != State.READY:
		return _reject(&"adapter_not_ready")
	var generations := _host_generations()
	var started := _runtime.begin_visit(generations.run, generations.attachment)
	if not bool(started.get("accepted", false)):
		return _reject(started.get("reason", &"runtime_begin_rejected") as StringName)
	var result := _runtime.start_activity(
		activity_id, generations.run, generations.attachment
	)
	if not bool(result.get("accepted", false)):
		return _reject(result.get("reason", &"activity_start_rejected") as StringName)
	_state = State.ACTIVE
	return _with_adapter(result, true, &"activity_started")


## Starts an ordered set of existing activity landmarks. Completion and reward
## commit of each entry are required before advance_activity_sequence can move
## to the next entry on a fresh host attachment.
func start_activity_sequence(activity_ids: Array[StringName]) -> Dictionary:
	if activity_ids.is_empty():
		return _reject(&"activity_sequence_empty")
	if _state != State.READY:
		return _reject(&"adapter_not_ready")
	_sequence_ids = activity_ids.duplicate()
	_sequence_index = 0
	var started := begin_activity(_sequence_ids[0])
	if bool(started.get("accepted", false)):
		return _with_adapter(started, true, &"activity_sequence_started")
	_sequence_ids = []
	_sequence_index = -1
	return started


func submit_activity_position(position: Vector3) -> Dictionary:
	var rejection := _live_activity_rejection()
	if not rejection.is_empty():
		return _reject(rejection)
	var generations := _host_generations()
	var runtime_snapshot := _runtime.get_snapshot()
	var result := _runtime.submit_position(
		position,
		int(runtime_snapshot.get("activity_generation", 0)),
		generations.run,
		generations.attachment
	)
	if bool(result.get("accepted", false)) \
			and result.get("runtime", {}).get("state", &"") == &"awaiting_reward":
		_state = State.ACTIVE
	return _with_adapter(result, bool(result.get("accepted", false)), result.get("reason", &"activity_position_rejected") as StringName)


func commit_activity_reward() -> Dictionary:
	var rejection := _live_activity_rejection()
	if not rejection.is_empty():
		return _reject(rejection)
	if _state != State.ACTIVE:
		return _reject(&"adapter_activity_not_active")
	var generations := _host_generations()
	var runtime_snapshot := _runtime.get_snapshot()
	var result := _runtime.commit_reward(
		StringName(runtime_snapshot.get("completed_activity_id", &"")),
		int(runtime_snapshot.get("activity_generation", 0)),
		generations.run,
		generations.attachment
	)
	if bool(result.get("accepted", false)):
		_state = State.COMPLETED
	return _with_adapter(result, bool(result.get("accepted", false)), result.get("reason", &"reward_commit_rejected") as StringName)


## Records a player-visible activity failure without manufacturing a reward.
## Retry is intentionally fenced to a newer host attachment generation so a
## detached surface run cannot silently resume on stale world state.
func abort_activity(reason: StringName = &"player_aborted") -> Dictionary:
	var rejection := _live_activity_rejection()
	if not rejection.is_empty():
		return _reject(rejection)
	if _state != State.ACTIVE:
		return _reject(&"adapter_activity_not_active")
	var runtime_state := StringName(_runtime.get_snapshot().get("state", &""))
	if runtime_state != &"active":
		return _reject(&"activity_failure_not_available")
	var generations := _host_generations()
	var result := _runtime.fail(reason, generations.run, generations.attachment)
	if bool(result.get("accepted", false)):
		_state = State.FAILED
	return _with_adapter(result, bool(result.get("accepted", false)), result.get("reason", &"activity_failure_rejected") as StringName)


## Starts a fresh activity after an aborted run. The host attachment generation
## must advance first, proving that the player has re-entered a current surface.
func retry_activity(activity_id: StringName) -> Dictionary:
	if _state != State.FAILED or not _host_is_current():
		return _reject(&"retry_unavailable")
	var generations := _host_generations()
	var reentered := _runtime.begin_visit(generations.run, generations.attachment)
	if not bool(reentered.get("accepted", false)):
		return _with_adapter(reentered, false, reentered.get("reason", &"retry_reentry_rejected") as StringName)
	_state = State.READY
	var started := _runtime.start_activity(activity_id, generations.run, generations.attachment)
	if bool(started.get("accepted", false)):
		_state = State.ACTIVE
		var retry_reason := &"activity_sequence_retried" if _sequence_index >= 0 else &"activity_started"
		return _with_adapter(started, true, retry_reason)
	return _with_adapter(started, false, started.get("reason", &"retry_start_rejected") as StringName)


## Starts another authored activity run after a completed reward cycle. A new
## attachment generation is mandatory, so repeat visits cannot replay a stale
## completion or reward receipt on the same surface binding.
func repeat_activity(activity_id: StringName) -> Dictionary:
	if _state != State.COMPLETED or not _host_is_current():
		return _reject(&"repeat_unavailable")
	var generations := _host_generations()
	var reentered := _runtime.begin_visit(generations.run, generations.attachment)
	if not bool(reentered.get("accepted", false)):
		return _with_adapter(reentered, false, reentered.get("reason", &"repeat_reentry_rejected") as StringName)
	var started := _runtime.start_activity(activity_id, generations.run, generations.attachment)
	if not bool(started.get("accepted", false)):
		return _with_adapter(started, false, started.get("reason", &"repeat_start_rejected") as StringName)
	_state = State.ACTIVE
	return _with_adapter(started, true, &"activity_repeated")


func advance_activity_sequence(landmark_id: StringName = &"") -> Dictionary:
	if _sequence_index < 0 or _sequence_index + 1 >= _sequence_ids.size():
		return _reject(&"activity_sequence_complete")
	if _state != State.COMPLETED:
		return _reject(&"activity_sequence_not_ready")
	var next_index := _sequence_index + 1
	var next_activity := _sequence_ids[next_index]
	if landmark_id.is_empty():
		return _reject(&"activity_landmark_required")
	var expected_landmark := _runtime.get_activity_landmark_id(next_activity)
	if expected_landmark.is_empty() or landmark_id != expected_landmark:
		return _reject(&"activity_landmark_mismatch")
	var repeated := repeat_activity(next_activity)
	if bool(repeated.get("accepted", false)):
		_sequence_index = next_index
		return _with_adapter(repeated, true, &"activity_sequence_advanced")
	return repeated


func detach() -> Dictionary:
	if not _bound or _state in [State.IDLE, State.DETACHED]:
		return _reject(&"adapter_not_active")
	var generations := _host_generations()
	var result := _runtime.detach(generations.run, generations.attachment)
	if bool(result.get("accepted", false)):
		_state = State.DETACHED
	return _with_adapter(result, bool(result.get("accepted", false)), result.get("reason", &"detach_rejected") as StringName)


func reenter() -> Dictionary:
	if _state != State.DETACHED or not _host_is_current():
		return _reject(&"reentry_unavailable")
	var generations := _host_generations()
	var result := _runtime.begin_visit(generations.run, generations.attachment)
	if bool(result.get("accepted", false)):
		_state = State.ACTIVE
	return _with_adapter(result, bool(result.get("accepted", false)), result.get("reason", &"reentry_rejected") as StringName)


## Re-enters the current Ember attachment and commits a reward receipt that was
## preserved while the player returned to the ship. The Host remains the
## lifecycle owner; this only composes its new attachment generation with the
## runtime's detached pending receipt.
func recover_pending_reward() -> Dictionary:
	if _state != State.DETACHED:
		return _reject(&"recovery_unavailable")
	var reentered := reenter()
	if not bool(reentered.get("accepted", false)):
		return reentered
	var committed := commit_activity_reward()
	if bool(committed.get("accepted", false)):
		return committed
	return _with_adapter(
		committed,
		false,
		committed.get("reason", &"reward_recovery_rejected") as StringName
	)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"state": _state_id(),
		"host_instance_id": _host_instance_id,
		"host": _host.call(&"get_snapshot").duplicate(true) if _host_is_current() else {},
		"activity_reward": _runtime.get_snapshot() if _runtime != null else {},
		"activity_sequence": {
			"activity_ids": _sequence_ids.duplicate(),
			"index": _sequence_index,
			"complete": _sequence_index >= 0 and _sequence_index + 1 >= _sequence_ids.size(),
		},
		"authority": {
			"host_mutation": false,
			"activity_authority": false,
			"reward_store": false,
			"reward_callback": true,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := _configuration_errors.duplicate()
	if _bound and not _host_is_current():
		errors.append("bound Ember surface host is no longer current")
	return {
		"schema_version": 1,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"production_wiring": _bound,
		"host_mutations": 0,
		"owns_activity_authority": false,
		"owns_reward_store": false,
		"owns_save_authority": false,
		"owns_network_authority": false,
	}.duplicate(true)


func _validate_host(host: Object) -> StringName:
	if host == null or not is_instance_valid(host) or host.is_queued_for_deletion():
		return &"host_unavailable"
	for method in [&"get_snapshot", &"get_generation", &"get_attachment_generation", &"get_phase"]:
		if not host.has_method(method):
			return &"host_public_api_incomplete"
	var snapshot: Variant = host.call(&"get_snapshot")
	if not snapshot is Dictionary:
		return &"host_snapshot_invalid"
	if StringName((snapshot as Dictionary).get("host_id", &"")) != REQUIRED_HOST_ID:
		return &"host_identity_mismatch"
	var identities: Variant = (snapshot as Dictionary).get("identities", {})
	if not identities is Dictionary \
			or StringName((identities as Dictionary).get("world_id", &"")) != REQUIRED_WORLD_ID:
		return &"host_world_mismatch"
	_configuration_errors = []
	return &""


func _host_is_current() -> bool:
	return _bound and _host != null and is_instance_valid(_host) \
		and not _host.is_queued_for_deletion() \
		and _host.get_instance_id() == _host_instance_id


func _live_host_rejection() -> StringName:
	if not _bound:
		return &"adapter_unbound"
	if not _host_is_current():
		return &"host_unavailable"
	var snapshot: Dictionary = _host.call(&"get_snapshot") as Dictionary
	if not bool(snapshot.get("attached", false)):
		return &"host_not_attached"
	return &""


func _live_activity_rejection() -> StringName:
	var host_rejection := _live_host_rejection()
	if not host_rejection.is_empty():
		return host_rejection
	if _state not in [State.ACTIVE]:
		return &"adapter_activity_not_active"
	var snapshot: Dictionary = _host.call(&"get_snapshot") as Dictionary
	if StringName(snapshot.get("phase_id", &"")) != REQUIRED_PHASE:
		return &"host_not_on_foot"
	return &""


func _host_generations() -> Dictionary:
	return {
		"run": int(_host.call(&"get_generation")),
		"attachment": int(_host.call(&"get_attachment_generation")),
	}


func _state_id() -> StringName:
	return [&"idle", &"ready", &"active", &"detached", &"completed", &"failed"][_state]


func _accept(reason: StringName) -> Dictionary:
	return _with_adapter({}, true, reason)


func _reject(reason: StringName) -> Dictionary:
	return _with_adapter({}, false, reason)


func _with_adapter(value: Dictionary, accepted: bool, reason: StringName) -> Dictionary:
	var result := value.duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	result["adapter"] = get_snapshot()
	return result
