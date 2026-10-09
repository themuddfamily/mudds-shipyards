class_name CinderAbandonedStructureScanActivity
extends RefCounted

## Original-modern scan of the authored derelict extraction hardware.
## No historical structure, salvage, reward, or ownership claim is made here.

const SCHEMA_VERSION := 1
const ACTIVITY_ID: StringName = &"cinder_derelict_structure_scan"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const STRUCTURE_ANCHOR := Vector3(60.0, -70.0, -700.0)
const APPROACH_ANCHOR := Vector3(60.0, -66.0, -680.0)
const INTERACTION_RADIUS := 24.0
const SCAN_SECONDS := 4.0
const REWARD_ID: StringName = &"derelict_material_sample"

enum State { IDLE, SCANNING, COMPLETE, RESET }

var _state := State.IDLE
var _generation := 0
var _elapsed := 0.0
var _reward_requested := false


func start(caller_position: Vector3) -> Dictionary:
	if _state == State.SCANNING:
		return _result(false, &"already_scanning")
	if not caller_position.is_finite() or caller_position.distance_to(APPROACH_ANCHOR) > INTERACTION_RADIUS:
		return _result(false, &"outside_scan_approach")
	_generation += 1
	_state = State.SCANNING
	_elapsed = 0.0
	_reward_requested = false
	return _result(true, &"started")


func advance_physics(delta: float) -> Dictionary:
	if _state != State.SCANNING:
		return _result(false, &"not_scanning")
	if not is_finite(delta) or delta < 0.0:
		return _result(false, &"invalid_delta")
	_elapsed = minf(SCAN_SECONDS, _elapsed + delta)
	if is_equal_approx(_elapsed, SCAN_SECONDS):
		_elapsed = SCAN_SECONDS
		_state = State.COMPLETE
	return _result(true, &"complete" if _state == State.COMPLETE else &"advanced")


func request_reward() -> Dictionary:
	if _state != State.COMPLETE:
		return _result(false, &"not_complete")
	if _reward_requested:
		return _result(false, &"reward_already_requested")
	_reward_requested = true
	var result := _result(true, &"reward_request_ready")
	result["reward_request"] = {
		"reward_id": REWARD_ID,
		"activity_id": ACTIVITY_ID,
		"generation": _generation,
		"granted": false,
	}
	return result


func reset() -> Dictionary:
	if _state == State.IDLE:
		return _result(false, &"already_idle")
	_state = State.RESET
	_elapsed = 0.0
	_reward_requested = false
	return _result(true, &"reset")


func get_snapshot() -> Dictionary:
	var progress := clampf(_elapsed / SCAN_SECONDS, 0.0, 1.0)
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_id": ACTIVITY_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"state": _state,
		"state_id": _state_id(_state),
		"generation": _generation,
		"elapsed_seconds": _elapsed,
		"scan_seconds": SCAN_SECONDS,
		"progress_unitless": progress,
		"checkpoint_id": &"",
		"reset_serial": _generation if _state == State.RESET else 0,
		"structure_anchor": STRUCTURE_ANCHOR,
		"approach_anchor": APPROACH_ANCHOR,
		"reward_requested": _reward_requested,
		"reward_pending": _reward_requested,
		"reward_authority": false,
		"gameplay_authority": false,
		"network_authority": false,
	}.duplicate(true)


## Compact authority state in the already-supported nearby session codec.
func get_persistence_snapshot() -> Dictionary:
	var snapshot := get_snapshot()
	for key in ["state_id", "progress_unitless", "checkpoint_id", "reset_serial",
			"structure_anchor", "approach_anchor", "reward_pending"]:
		snapshot.erase(key)
	return snapshot


static func validate_persistence_record(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"accepted": false, "reason": &"scan_session_invalid"}
	if value.get("schema_version") != SCHEMA_VERSION:
		return {"accepted": false, "reason": &"scan_session_unsupported_schema"}
	if value.size() != 2 or not value.get("activities") is Array or value.activities.size() != 1:
		return {"accepted": false, "reason": &"scan_session_invalid"}
	var entry: Variant = value.activities[0]
	if not entry is Dictionary or entry.size() != 6 or not entry.get("progress") is Dictionary:
		return {"accepted": false, "reason": &"scan_session_invalid"}
	var state: Dictionary = entry.progress
	var defaults := CinderAbandonedStructureScanActivity.new().get_persistence_snapshot()
	if state.size() != defaults.size():
		return {"accepted": false, "reason": &"scan_session_invalid"}
	for key in defaults:
		if not state.has(key) or (key not in ["state", "generation", "elapsed_seconds", "reward_requested"] and state[key] != defaults[key]):
			return {"accepted": false, "reason": &"scan_session_invalid"}
	for key in ["state", "generation"]:
		var number: Variant = state[key]
		if not (number is int or number is float) or not is_finite(float(number)) \
				or float(number) != floor(float(number)) or float(number) < 0.0 or float(number) > 2147483647.0:
			return {"accepted": false, "reason": &"scan_session_invalid"}
	var elapsed: Variant = state.elapsed_seconds
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)):
		return {"accepted": false, "reason": &"scan_session_invalid"}
	var lifecycle := int(state.state)
	var generation := int(state.generation)
	var seconds := float(elapsed)
	if lifecycle not in [State.IDLE, State.SCANNING, State.COMPLETE, State.RESET] \
			or (generation == 0) != (lifecycle == State.IDLE) \
			or seconds < 0.0 or seconds > SCAN_SECONDS \
			or (lifecycle == State.COMPLETE and seconds != SCAN_SECONDS) \
			or (lifecycle == State.SCANNING and seconds >= SCAN_SECONDS) \
			or (lifecycle in [State.IDLE, State.RESET] and seconds != 0.0) \
			or entry.get("activity_id") != String(ACTIVITY_ID) \
			or entry.get("generation") != state.generation or entry.get("state") != state.state \
			or not entry.get("reward_requested") is bool or not entry.get("reward_granted") is bool \
			or not state.get("reward_requested") is bool \
			or entry.reward_requested != (lifecycle == State.COMPLETE) \
			or (entry.reward_granted and not entry.reward_requested) \
			or state.reward_requested != entry.reward_granted:
		return {"accepted": false, "reason": &"scan_session_invalid"}
	return {"accepted": true, "reason": &"scan_session_valid"}


func acknowledge_persisted_reward(record: Dictionary) -> Dictionary:
	var checked := validate_persistence_record(record)
	if not checked.accepted:
		return checked
	var entry: Dictionary = record.activities[0]
	if _state != State.COMPLETE or int(entry.generation) != _generation \
			or not entry.reward_granted or int(entry.state) != State.COMPLETE:
		return _result(false, &"scan_payment_generation_mismatch")
	_reward_requested = true
	return _result(true, &"scan_payment_recovered")


func restore_persistence_record(record: Dictionary) -> Dictionary:
	var checked := validate_persistence_record(record)
	if not checked.accepted:
		return checked
	if _generation != 0 or _state != State.IDLE:
		return _result(false, &"scan_session_owner_already_active")
	var state: Dictionary = record.activities[0].progress
	_generation = int(state.generation)
	_state = int(state.state)
	_elapsed = float(state.elapsed_seconds)
	_reward_requested = state.reward_requested
	return _result(true, &"scan_session_restored")


static func _state_id(state: int) -> StringName:
	return [&"idle", &"active", &"complete", &"reset"][clampi(state, State.IDLE, State.RESET)]


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if STRUCTURE_ANCHOR != NearbySectorCluster.PLATFORM_ANCHOR:
		errors.append("structure anchor diverged from authored extraction platform")
	if STRUCTURE_ANCHOR.length() > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
		errors.append("structure anchor leaves authored cluster envelope")
	if APPROACH_ANCHOR.length() > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
		errors.append("scan approach leaves authored cluster envelope")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"fixed_anchor_policy": &"authored_derelict_structure_only",
		"reward_authority": false,
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result
