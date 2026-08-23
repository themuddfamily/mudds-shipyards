class_name CinderBeaconTraversalActivity
extends RefCounted

## Original-modern traversal of the four authored Cinder route beacons.

const SCHEMA_VERSION := 1
const ACTIVITY_ID: StringName = &"cinder_debris_beacon_traversal"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const BEACONS: Array[Vector3] = [
	Vector3(16.0, -9.0, -240.0), Vector3(32.0, -26.0, -372.0),
	Vector3(46.0, -44.0, -498.0), Vector3(30.0, -46.0, -600.0),
]
const CHECKPOINT_RADIUS := 32.0
const REWARD_ID: StringName = &"debris_route_navigation_data"

enum State { IDLE, ACTIVE, COMPLETE, RESET }

var _state := State.IDLE
var _generation := 0
var _next_index := 0
var _reward_requested := false


func start(caller_position: Vector3) -> Dictionary:
	if _state == State.ACTIVE:
		return _result(false, &"already_active")
	if not caller_position.is_finite() or caller_position.distance_to(BEACONS[0]) > CHECKPOINT_RADIUS:
		return _result(false, &"outside_first_beacon")
	_generation += 1
	_state = State.ACTIVE
	_next_index = 0
	_reward_requested = false
	return _result(true, &"started")


func submit_beacon(index: int, caller_position: Vector3) -> Dictionary:
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	if index != _next_index or index < 0 or index >= BEACONS.size():
		return _result(false, &"out_of_order_beacon")
	if not caller_position.is_finite() or caller_position.distance_to(BEACONS[index]) > CHECKPOINT_RADIUS:
		return _result(false, &"outside_beacon")
	_next_index += 1
	if _next_index == BEACONS.size():
		_state = State.COMPLETE
	return _result(true, &"complete" if _state == State.COMPLETE else &"beacon_reached")


func request_reward() -> Dictionary:
	if _state != State.COMPLETE:
		return _result(false, &"not_complete")
	if _reward_requested:
		return _result(false, &"reward_already_requested")
	_reward_requested = true
	var result := _result(true, &"reward_request_ready")
	result["reward_request"] = {"reward_id": REWARD_ID, "activity_id": ACTIVITY_ID, "generation": _generation, "granted": false}
	return result


func reset() -> Dictionary:
	if _state == State.IDLE:
		return _result(false, &"already_idle")
	_state = State.RESET
	_next_index = 0
	_reward_requested = false
	return _result(true, &"reset")


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION, "activity_id": ACTIVITY_ID,
		"content_class": CONTENT_CLASS, "evidence_status": EVIDENCE_STATUS,
		"state": _state, "generation": _generation,
		"next_beacon_index": _next_index, "beacon_count": BEACONS.size(),
		"reward_requested": _reward_requested, "reward_authority": false,
		"gameplay_authority": false, "network_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if BEACONS.size() != NearbySectorCluster.ROUTE_BEACON_SPECS.size():
		errors.append("beacon count diverged from authored cluster")
	for point in BEACONS:
		if point.length() > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
			errors.append("beacon route leaves authored cluster envelope")
			break
	return {"schema_version": SCHEMA_VERSION, "valid": errors.is_empty(), "errors": errors,
		"content_class": CONTENT_CLASS, "evidence_status": EVIDENCE_STATUS,
		"fixed_corridor_policy": &"authored_beacons_only", "reward_authority": false}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result
