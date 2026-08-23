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
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_id": ACTIVITY_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"state": _state,
		"generation": _generation,
		"elapsed_seconds": _elapsed,
		"scan_seconds": SCAN_SECONDS,
		"structure_anchor": STRUCTURE_ANCHOR,
		"approach_anchor": APPROACH_ANCHOR,
		"reward_requested": _reward_requested,
		"reward_authority": false,
		"gameplay_authority": false,
		"network_authority": false,
	}.duplicate(true)


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
