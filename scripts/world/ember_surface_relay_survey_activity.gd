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
const SAMPLE_RACK_CHECKPOINT_ID: StringName = &"ember_sample_rack_analysis_log"
const SAMPLE_RACK_INTERACTION_ID: StringName = &"ember_sample_rack_analysis"
const SAMPLE_RACK_RESPONSE_ID: StringName = &"ember_sample_rack_analysis_marker"

var _optional_checkpoint_completed := false
var _optional_activity_generation := -1
var _optional_run_generation := -1
var _optional_attachment_generation := -1
var _optional_receipt: Dictionary = {}
var _sample_rack_completed := false
var _sample_rack_activity_generation := -1
var _sample_rack_run_generation := -1
var _sample_rack_attachment_generation := -1
var _sample_rack_receipt: Dictionary = {}
var _mandatory_route_progress: Dictionary = {}

func begin(adapter: Object, navigation: RefCounted = null) -> Dictionary:
	if adapter == null:
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	var adapter_state := StringName(
		(adapter.call(&"get_snapshot") as Dictionary).get("state", &"")
	) if adapter.has_method(&"get_snapshot") else &""
	var restarted: Dictionary = {}
	if adapter_state == &"completed" and adapter.has_method(&"repeat_activity"):
		restarted = adapter.call(&"repeat_activity", ACTIVITY_ID)
	elif adapter_state == &"failed" and adapter.has_method(&"retry_activity"):
		restarted = adapter.call(&"retry_activity", ACTIVITY_ID)
	if not restarted.is_empty():
		if bool(restarted.get("accepted", false)):
			_reconcile_optional_checkpoint_generation(adapter)
			_apply_authoritative_route_result(restarted)
		return restarted
	var ids: Array[StringName] = [ACTIVITY_ID]
	var started: Dictionary
	if navigation != null and adapter.has_method(&"start_surface_activity_sequence"):
		started = adapter.call(&"start_surface_activity_sequence", ids, navigation)
	elif adapter.has_method(&"start_activity_sequence"):
		started = adapter.call(&"start_activity_sequence", ids)
	else:
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	if bool(started.get("accepted", false)):
		_reconcile_optional_checkpoint_generation(adapter)
		_apply_authoritative_route_result(started)
	return started

func submit_landmark(adapter: Object, landmark_id: StringName, position: Vector3) -> Dictionary:
	if adapter == null or not adapter.has_method(&"submit_activity_landmark_discovery") \
			or not position.is_finite() or landmark_id.is_empty():
		return {"accepted": false, "reason": &"invalid_relay_survey_evidence"}
	return adapter.call(&"submit_activity_landmark_discovery", landmark_id, position)

func submit_position(adapter: Object, position: Vector3) -> Dictionary:
	if adapter == null or not adapter.has_method(&"submit_activity_position") or not position.is_finite():
		return {"accepted": false, "reason": &"invalid_relay_survey_position"}
	var result := adapter.call(&"submit_activity_position", position) as Dictionary
	if bool(result.get("accepted", false)):
		_apply_authoritative_route_result(result)
	return result

func commit_reward(adapter: Object) -> Dictionary:
	if adapter == null or not adapter.has_method(&"commit_activity_reward"):
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	return adapter.call(&"commit_activity_reward")


func submit_optional_checkpoint(adapter: Object, receipt: Variant) -> Dictionary:
	if adapter == null or not adapter.has_method(&"get_snapshot") or not receipt is Dictionary:
		return _checkpoint_result(false, &"invalid_optional_checkpoint_evidence", adapter)
	_reconcile_optional_checkpoint_generation(adapter)
	var adapter_snapshot := adapter.call(&"get_snapshot") as Dictionary
	var runtime := adapter_snapshot.get("activity_reward", {}) as Dictionary
	var evidence := receipt as Dictionary
	var interaction_id := StringName(evidence.get("interaction_id", &""))
	var checkpoint_id := OPTIONAL_CHECKPOINT_ID if interaction_id == OPTIONAL_INTERACTION_ID \
		else SAMPLE_RACK_CHECKPOINT_ID if interaction_id == SAMPLE_RACK_INTERACTION_ID \
		else &""
	if checkpoint_id.is_empty():
		return _checkpoint_result(false, &"invalid_optional_checkpoint_evidence", adapter)
	if (checkpoint_id == OPTIONAL_CHECKPOINT_ID and _optional_checkpoint_completed) \
			or (checkpoint_id == SAMPLE_RACK_CHECKPOINT_ID and _sample_rack_completed):
		return _checkpoint_result(
			false, &"optional_checkpoint_already_completed", adapter, checkpoint_id
		)
	if StringName(adapter_snapshot.get("state", &"")) != &"active" \
			or StringName(runtime.get("state", &"")) != &"active" \
			or StringName(runtime.get("activity_id", &"")) != ACTIVITY_ID:
		return _checkpoint_result(false, &"relay_survey_not_active", adapter, checkpoint_id)
	if StringName(evidence.get("world_id", &"")) != &"ember_moon" \
			or bool(evidence.get("activity_started", true)) \
			or bool(evidence.get("reward_granted", true)) \
			or bool(evidence.get("historical_claim", true)):
		return _checkpoint_result(
			false, &"invalid_optional_checkpoint_evidence", adapter, checkpoint_id
		)
	var run_generation := int(runtime.get("run_generation", -1))
	var attachment_generation := int(runtime.get("attachment_generation", -1))
	var activity_generation := int(runtime.get("activity_generation", -1))
	if int(evidence.get("host_generation", -2)) != run_generation \
			or int(evidence.get("attachment_generation", -2)) != attachment_generation \
			or run_generation < 1 or attachment_generation < 1 or activity_generation < 1:
		return _checkpoint_result(
			false, &"stale_optional_checkpoint_generation", adapter, checkpoint_id
		)
	if checkpoint_id == SAMPLE_RACK_CHECKPOINT_ID and (
		StringName(evidence.get("checkpoint_id", &"")) != SAMPLE_RACK_CHECKPOINT_ID \
		or StringName(evidence.get("completion_response_id", &"")) \
			!= SAMPLE_RACK_RESPONSE_ID \
		or int(evidence.get("activity_generation", -2)) != activity_generation
	):
		return _checkpoint_result(
			false, &"invalid_optional_checkpoint_evidence", adapter, checkpoint_id
		)
	if checkpoint_id == OPTIONAL_CHECKPOINT_ID:
		_optional_checkpoint_completed = true
		_optional_activity_generation = activity_generation
		_optional_run_generation = run_generation
		_optional_attachment_generation = attachment_generation
		_optional_receipt = evidence.duplicate(true)
	else:
		_sample_rack_completed = true
		_sample_rack_activity_generation = activity_generation
		_sample_rack_run_generation = run_generation
		_sample_rack_attachment_generation = attachment_generation
		_sample_rack_receipt = evidence.duplicate(true)
	return _checkpoint_result(
		true, &"optional_checkpoint_completed", adapter, checkpoint_id
	)


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


## Session-only sample-rack state. Terminal reward persistence deliberately
## continues to capture only the established bunker completion contract.
func get_sample_rack_session_snapshot(adapter: Object = null) -> Dictionary:
	var checkpoint := _sample_rack_optional_checkpoint_snapshot(adapter)
	var current := adapter.call(&"get_session_snapshot") as Dictionary \
		if adapter != null and adapter.has_method(&"get_session_snapshot") else {}
	return {
		"schema_version": 1,
		"activity_id": ACTIVITY_ID,
		"checkpoint_id": SAMPLE_RACK_CHECKPOINT_ID,
		"session_run_generation": int(current.get("run_generation", -1)),
		"session_attachment_generation": int(
			current.get("attachment_generation", -1)
		),
		"completed": _sample_rack_completed,
		"activity_generation": _sample_rack_activity_generation,
		"run_generation": _sample_rack_run_generation,
		"attachment_generation": _sample_rack_attachment_generation,
		"receipt": _sample_rack_receipt.duplicate(true),
		"status": checkpoint.get("status", &"inactive"),
	}.duplicate(true)


func validate_sample_rack_session_snapshot(
		snapshot: Variant, adapter: Object
	) -> Dictionary:
	if not snapshot is Dictionary or adapter == null \
			or not adapter.has_method(&"get_session_snapshot"):
		return {"accepted": false, "reason": &"invalid_sample_rack_checkpoint_snapshot"}
	var saved := snapshot as Dictionary
	var current := adapter.call(&"get_session_snapshot") as Dictionary
	if int(saved.get("schema_version", -1)) != 1 \
			or StringName(saved.get("activity_id", &"")) != ACTIVITY_ID \
			or StringName(saved.get("checkpoint_id", &"")) \
				!= SAMPLE_RACK_CHECKPOINT_ID \
			or saved.get("completed") is not bool \
			or int(saved.get("session_run_generation", -1)) \
				!= int(current.get("run_generation", -2)) \
			or int(saved.get("session_attachment_generation", -1)) \
				>= int(current.get("attachment_generation", -2)):
		return {"accepted": false, "reason": &"stale_sample_rack_checkpoint_snapshot"}
	if bool(saved.completed) and (
		int(saved.get("activity_generation", -1)) < 1 \
		or not saved.get("receipt", {}) is Dictionary
	):
		return {"accepted": false, "reason": &"invalid_sample_rack_checkpoint_snapshot"}
	return {"accepted": true, "reason": &"sample_rack_checkpoint_snapshot_valid"}


func restore_sample_rack_session_snapshot(
		snapshot: Variant, adapter: Object
	) -> Dictionary:
	var validation := validate_sample_rack_session_snapshot(snapshot, adapter)
	if not bool(validation.get("accepted", false)):
		return validation
	var saved := snapshot as Dictionary
	_sample_rack_completed = bool(saved.completed)
	_sample_rack_activity_generation = int(saved.activity_generation)
	_sample_rack_run_generation = int(saved.run_generation)
	_sample_rack_attachment_generation = int(saved.attachment_generation)
	_sample_rack_receipt = (saved.get("receipt", {}) as Dictionary).duplicate(true)
	return _checkpoint_result(
		true, &"optional_checkpoint_restored", adapter, SAMPLE_RACK_CHECKPOINT_ID
	)


func get_snapshot(adapter: Object = null) -> Dictionary:
	var bunker := _optional_checkpoint_snapshot(adapter)
	var sample_rack := _sample_rack_optional_checkpoint_snapshot(adapter)
	return {
		"activity_id": ACTIVITY_ID,
		"start_landmark_id": START_LANDMARK_ID,
		"finish_landmark_id": FINISH_LANDMARK_ID,
		"reward_id": REWARD_ID,
		# Legacy singular view remains the bunker checkpoint consumed by the
		# existing HUD and terminal persistence contracts.
		"optional_checkpoint": bunker,
		"optional_checkpoints": {
			OPTIONAL_CHECKPOINT_ID: bunker,
			SAMPLE_RACK_CHECKPOINT_ID: sample_rack,
		},
		"optional_progress": {
			"completed_count": int(_optional_checkpoint_completed) \
				+ int(_sample_rack_completed),
			"checkpoint_count": 2,
			"authority": {"route": false, "reward": false},
		},
		"mandatory_route": _mandatory_route_progress.duplicate(true),
		"authority": {
			"activity": false, "reward": false, "movement": false, "save": false,
			"optional_checkpoint_receipt": true,
		},
	}.duplicate(true)


func _optional_checkpoint_snapshot(adapter: Object) -> Dictionary:
	_reconcile_optional_checkpoint_generation(adapter)
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


func _sample_rack_optional_checkpoint_snapshot(adapter: Object) -> Dictionary:
	_reconcile_optional_checkpoint_generation(adapter)
	var eligible := false
	var current_activity_generation := -1
	if adapter != null and adapter.has_method(&"get_snapshot"):
		var adapter_snapshot := adapter.call(&"get_snapshot") as Dictionary
		var runtime := adapter_snapshot.get("activity_reward", {}) as Dictionary
		eligible = StringName(adapter_snapshot.get("state", &"")) == &"active" \
			and StringName(runtime.get("state", &"")) == &"active" \
			and StringName(runtime.get("activity_id", &"")) == ACTIVITY_ID
		current_activity_generation = int(runtime.get("activity_generation", -1))
	var status: StringName = &"completed" if _sample_rack_completed \
		else (&"available" if eligible else &"inactive")
	return {
		"checkpoint_id": SAMPLE_RACK_CHECKPOINT_ID,
		"interaction_id": SAMPLE_RACK_INTERACTION_ID,
		"optional": true,
		"eligible": eligible,
		"completed": _sample_rack_completed,
		"status": status,
		"completed_count": 1 if _sample_rack_completed else 0,
		"checkpoint_count": 1,
		"progress_text": "OPTIONAL SAMPLE ANALYSIS  1 / 1" \
			if _sample_rack_completed else "OPTIONAL SAMPLE ANALYSIS  0 / 1",
		"status_text": "Sample rack analysis recorded" if _sample_rack_completed \
			else ("Sample rack analysis available" if eligible \
			else "Optional sample analysis inactive"),
		"activity_generation": _sample_rack_activity_generation,
		"current_activity_generation": current_activity_generation,
		"run_generation": _sample_rack_run_generation,
		"attachment_generation": _sample_rack_attachment_generation,
		"historical_claim": false,
		"content_class": &"NEW",
		"interpretation_status": &"modern_interpretation",
		"authority": {"route": false, "reward": false, "activity_start": false},
	}.duplicate(true)


func _reconcile_optional_checkpoint_generation(adapter: Object) -> void:
	if (not _optional_checkpoint_completed and not _sample_rack_completed) \
			or adapter == null \
			or not adapter.has_method(&"get_snapshot"):
		return
	var adapter_snapshot := adapter.call(&"get_snapshot") as Dictionary
	var runtime := adapter_snapshot.get("activity_reward", {}) as Dictionary
	if StringName(adapter_snapshot.get("state", &"")) != &"active" \
			or StringName(runtime.get("state", &"")) != &"active" \
			or StringName(runtime.get("activity_id", &"")) != ACTIVITY_ID:
		return
	var current_activity_generation := int(runtime.get("activity_generation", -1))
	if _optional_checkpoint_completed \
			and current_activity_generation > _optional_activity_generation:
		_optional_checkpoint_completed = false
		_optional_activity_generation = -1
		_optional_run_generation = -1
		_optional_attachment_generation = -1
		_optional_receipt = {}
	if _sample_rack_completed \
			and current_activity_generation > _sample_rack_activity_generation:
		_sample_rack_completed = false
		_sample_rack_activity_generation = -1
		_sample_rack_run_generation = -1
		_sample_rack_attachment_generation = -1
		_sample_rack_receipt = {}


func _apply_authoritative_route_result(result: Dictionary) -> void:
	var runtime := result.get("runtime", {}) as Dictionary
	var activity_generation := int(runtime.get("activity_generation", -1))
	var next_checkpoint_index := int(result.get("next_checkpoint_index", -1))
	var checkpoint_count := int(result.get("checkpoint_count", -1))
	if StringName(runtime.get("activity_id", &"")) != ACTIVITY_ID \
			or activity_generation < 1 or checkpoint_count != 2 \
			or next_checkpoint_index < 0 or next_checkpoint_index > checkpoint_count:
		return
	_mandatory_route_progress = {
		"source": &"activity_director_checkpoint_result",
		"activity_id": ACTIVITY_ID,
		"activity_generation": activity_generation,
		"next_checkpoint_index": next_checkpoint_index,
		"checkpoint_count": checkpoint_count,
		"next_objective_id": START_LANDMARK_ID if next_checkpoint_index == 0 \
			else (FINISH_LANDMARK_ID if next_checkpoint_index == 1 else &""),
		"complete": next_checkpoint_index == checkpoint_count,
		"authority": {"navigation": false, "movement": false, "reward": false},
	}.duplicate(true)


func _checkpoint_result(
		accepted: bool,
		reason: StringName,
		adapter: Object,
		checkpoint_id: StringName = OPTIONAL_CHECKPOINT_ID
	) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"checkpoint": _optional_checkpoint_snapshot(adapter) \
			if checkpoint_id == OPTIONAL_CHECKPOINT_ID \
			else _sample_rack_optional_checkpoint_snapshot(adapter),
	}.duplicate(true)
