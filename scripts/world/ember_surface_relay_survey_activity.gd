class_name EmberSurfaceRelaySurveyActivity
extends RefCounted

## Authored Ember relay survey facade over the retained planetary activity
## adapter. The adapter/director remain authoritative for mandatory route
## progression and reward commitment. This facade retains only the optional
## bunker-log checkpoint receipt admitted against their live generations.

const ACTIVITY_ID: StringName = &"ember_beacon_survey"
const START_LANDMARK_ID: StringName = &"ember_relay_tower"
const FINISH_LANDMARK_ID: StringName = &"ember_return_beacon"
const REWARD_ID: StringName = &"ember_beacon_data"
const OPTIONAL_CHECKPOINT_ID: StringName = &"ember_bunker_gantry_log"
const OPTIONAL_INTERACTION_ID: StringName = &"ember_bunker_gantry_survey"

var _optional_checkpoint_completed := false
var _optional_activity_generation := -1
var _optional_run_generation := -1
var _optional_attachment_generation := -1
var _optional_receipt: Dictionary = {}

func begin(adapter: Object, navigation: RefCounted = null) -> Dictionary:
	if adapter == null:
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	var ids: Array[StringName] = [ACTIVITY_ID]
	if navigation != null and adapter.has_method(&"start_surface_activity_sequence"):
		return adapter.call(&"start_surface_activity_sequence", ids, navigation)
	if not adapter.has_method(&"start_activity_sequence"):
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	return adapter.call(&"start_activity_sequence", ids)

func submit_landmark(adapter: Object, landmark_id: StringName, position: Vector3) -> Dictionary:
	if adapter == null or not adapter.has_method(&"submit_activity_landmark_discovery") \
			or not position.is_finite() or landmark_id.is_empty():
		return {"accepted": false, "reason": &"invalid_relay_survey_evidence"}
	return adapter.call(&"submit_activity_landmark_discovery", landmark_id, position)

func submit_position(adapter: Object, position: Vector3) -> Dictionary:
	if adapter == null or not adapter.has_method(&"submit_activity_position") or not position.is_finite():
		return {"accepted": false, "reason": &"invalid_relay_survey_position"}
	return adapter.call(&"submit_activity_position", position)

func commit_reward(adapter: Object) -> Dictionary:
	if adapter == null or not adapter.has_method(&"commit_activity_reward"):
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	return adapter.call(&"commit_activity_reward")


func submit_optional_checkpoint(adapter: Object, receipt: Variant) -> Dictionary:
	if adapter == null or not adapter.has_method(&"get_snapshot") or not receipt is Dictionary:
		return _checkpoint_result(false, &"invalid_optional_checkpoint_evidence", adapter)
	if _optional_checkpoint_completed:
		return _checkpoint_result(false, &"optional_checkpoint_already_completed", adapter)
	var adapter_snapshot := adapter.call(&"get_snapshot") as Dictionary
	var runtime := adapter_snapshot.get("activity_reward", {}) as Dictionary
	var evidence := receipt as Dictionary
	if StringName(adapter_snapshot.get("state", &"")) != &"active" \
			or StringName(runtime.get("state", &"")) != &"active" \
			or StringName(runtime.get("activity_id", &"")) != ACTIVITY_ID:
		return _checkpoint_result(false, &"relay_survey_not_active", adapter)
	if StringName(evidence.get("interaction_id", &"")) != OPTIONAL_INTERACTION_ID \
			or StringName(evidence.get("world_id", &"")) != &"ember_moon" \
			or bool(evidence.get("activity_started", true)) \
			or bool(evidence.get("reward_granted", true)) \
			or bool(evidence.get("historical_claim", true)):
		return _checkpoint_result(false, &"invalid_optional_checkpoint_evidence", adapter)
	var run_generation := int(runtime.get("run_generation", -1))
	var attachment_generation := int(runtime.get("attachment_generation", -1))
	var activity_generation := int(runtime.get("activity_generation", -1))
	if int(evidence.get("host_generation", -2)) != run_generation \
			or int(evidence.get("attachment_generation", -2)) != attachment_generation \
			or run_generation < 1 or attachment_generation < 1 or activity_generation < 1:
		return _checkpoint_result(false, &"stale_optional_checkpoint_generation", adapter)
	_optional_checkpoint_completed = true
	_optional_activity_generation = activity_generation
	_optional_run_generation = run_generation
	_optional_attachment_generation = attachment_generation
	_optional_receipt = evidence.duplicate(true)
	return _checkpoint_result(true, &"optional_checkpoint_completed", adapter)


func get_persistence_snapshot(adapter: Object = null) -> Dictionary:
	var checkpoint := _optional_checkpoint_snapshot(adapter)
	var current := adapter.call(&"get_session_snapshot") as Dictionary \
		if adapter != null and adapter.has_method(&"get_session_snapshot") else {}
	return {
		"schema_version": 1,
		"activity_id": ACTIVITY_ID,
		"checkpoint_id": OPTIONAL_CHECKPOINT_ID,
		"session_run_generation": int(current.get("run_generation", -1)),
		"session_attachment_generation": int(current.get("attachment_generation", -1)),
		"completed": _optional_checkpoint_completed,
		"activity_generation": _optional_activity_generation,
		"run_generation": _optional_run_generation,
		"attachment_generation": _optional_attachment_generation,
		"receipt": _optional_receipt.duplicate(true),
		"status": checkpoint.get("status", &"inactive"),
	}.duplicate(true)


func validate_persistence_snapshot(snapshot: Variant, adapter: Object) -> Dictionary:
	if not snapshot is Dictionary or adapter == null \
			or not adapter.has_method(&"get_session_snapshot"):
		return {"accepted": false, "reason": &"invalid_optional_checkpoint_snapshot"}
	var saved := snapshot as Dictionary
	var current := adapter.call(&"get_session_snapshot") as Dictionary
	if int(saved.get("schema_version", -1)) != 1 \
			or StringName(saved.get("activity_id", &"")) != ACTIVITY_ID \
			or StringName(saved.get("checkpoint_id", &"")) != OPTIONAL_CHECKPOINT_ID \
			or saved.get("completed") is not bool \
			or int(saved.get("session_run_generation", -1)) != int(current.get("run_generation", -2)) \
			or int(saved.get("session_attachment_generation", -1)) >= int(current.get("attachment_generation", -2)):
		return {"accepted": false, "reason": &"stale_optional_checkpoint_snapshot"}
	if bool(saved.completed) and (
			int(saved.get("activity_generation", -1)) < 1 \
			or not (saved.get("receipt", {}) is Dictionary)
	):
		return {"accepted": false, "reason": &"invalid_optional_checkpoint_snapshot"}
	return {"accepted": true, "reason": &"optional_checkpoint_snapshot_valid"}


func restore_persistence_snapshot(snapshot: Variant, adapter: Object) -> Dictionary:
	var validation := validate_persistence_snapshot(snapshot, adapter)
	if not bool(validation.get("accepted", false)):
		return validation
	var saved := snapshot as Dictionary
	_optional_checkpoint_completed = bool(saved.completed)
	_optional_activity_generation = int(saved.activity_generation)
	_optional_run_generation = int(saved.run_generation)
	_optional_attachment_generation = int(saved.attachment_generation)
	_optional_receipt = (saved.get("receipt", {}) as Dictionary).duplicate(true)
	return _checkpoint_result(true, &"optional_checkpoint_restored", adapter)


func get_snapshot(adapter: Object = null) -> Dictionary:
	return {
		"activity_id": ACTIVITY_ID,
		"start_landmark_id": START_LANDMARK_ID,
		"finish_landmark_id": FINISH_LANDMARK_ID,
		"reward_id": REWARD_ID,
		"optional_checkpoint": _optional_checkpoint_snapshot(adapter),
		"authority": {
			"activity": false, "reward": false, "movement": false, "save": false,
			"optional_checkpoint_receipt": true,
		},
	}.duplicate(true)


func _optional_checkpoint_snapshot(adapter: Object) -> Dictionary:
	var eligible := false
	var current_activity_generation := -1
	if adapter != null and adapter.has_method(&"get_snapshot"):
		var adapter_snapshot := adapter.call(&"get_snapshot") as Dictionary
		var runtime := adapter_snapshot.get("activity_reward", {}) as Dictionary
		eligible = StringName(adapter_snapshot.get("state", &"")) == &"active" \
			and StringName(runtime.get("state", &"")) == &"active" \
			and StringName(runtime.get("activity_id", &"")) == ACTIVITY_ID
		current_activity_generation = int(runtime.get("activity_generation", -1))
	var status: StringName = &"completed" if _optional_checkpoint_completed \
		else (&"available" if eligible else &"inactive")
	return {
		"checkpoint_id": OPTIONAL_CHECKPOINT_ID,
		"interaction_id": OPTIONAL_INTERACTION_ID,
		"optional": true,
		"eligible": eligible,
		"completed": _optional_checkpoint_completed,
		"status": status,
		"completed_count": 1 if _optional_checkpoint_completed else 0,
		"checkpoint_count": 1,
		"progress_text": "OPTIONAL BUNKER LOG  1 / 1" if _optional_checkpoint_completed \
			else "OPTIONAL BUNKER LOG  0 / 1",
		"status_text": "Bunker / gantry log recorded" if _optional_checkpoint_completed \
			else ("Bunker / gantry log available" if eligible else "Optional log inactive"),
		"activity_generation": _optional_activity_generation,
		"current_activity_generation": current_activity_generation,
		"run_generation": _optional_run_generation,
		"attachment_generation": _optional_attachment_generation,
		"historical_claim": false,
		"content_class": &"NEW",
		"interpretation_status": &"modern_interpretation",
		"authority": {"route": false, "reward": false, "activity_start": false},
	}.duplicate(true)


func _checkpoint_result(accepted: bool, reason: StringName, adapter: Object) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"checkpoint": _optional_checkpoint_snapshot(adapter),
	}.duplicate(true)
