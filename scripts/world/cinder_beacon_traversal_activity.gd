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


## Prepare the exact reset without changing the live route or its paid flag.
func preview_reset() -> Dictionary:
	if _state == State.IDLE:
		return _result(false, &"already_idle")
	var result := _result(true, &"reset")
	result.state = State.RESET
	result.next_beacon_index = 0
	result.reward_requested = false
	return result


func reset() -> Dictionary:
	var prepared := preview_reset()
	if not prepared.accepted:
		return prepared
	_state = prepared.state
	_next_index = prepared.next_beacon_index
	_reward_requested = prepared.reward_requested
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


## The existing nearby session codec captures this owner; restore accepts only
## its exact supported record, never presentation text or a reward request.
static func validate_persistence_record(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"accepted": false, "reason": &"beacon_session_invalid"}
	if value.get("schema_version") != SCHEMA_VERSION:
		return {"accepted": false, "reason": &"beacon_session_unsupported_schema"}
	if value.size() != 2 or not value.get("activities") is Array or value.activities.size() != 1:
		return {"accepted": false, "reason": &"beacon_session_invalid"}
	var entry: Variant = value.activities[0]
	if not entry is Dictionary or entry.size() != 6 or not entry.get("progress") is Dictionary:
		return {"accepted": false, "reason": &"beacon_session_invalid"}
	var state: Dictionary = entry.progress
	var defaults := CinderBeaconTraversalActivity.new().get_snapshot()
	if state.size() != defaults.size():
		return {"accepted": false, "reason": &"beacon_session_invalid"}
	for key in defaults:
		if not state.has(key):
			return {"accepted": false, "reason": &"beacon_session_invalid"}
		if key not in ["state", "generation", "next_beacon_index", "reward_requested"] and state[key] != defaults[key]:
			return {"accepted": false, "reason": &"beacon_session_invalid"}
	for key in ["state", "generation", "next_beacon_index"]:
		var number: Variant = state[key]
		if not (number is int or number is float) or not is_finite(float(number)) \
				or float(number) != floor(float(number)) or float(number) < 0.0 or float(number) > 2147483647.0:
			return {"accepted": false, "reason": &"beacon_session_invalid"}
	var lifecycle := int(state.state)
	var generation := int(state.generation)
	var cursor := int(state.next_beacon_index)
	if lifecycle not in [State.IDLE, State.ACTIVE, State.COMPLETE, State.RESET] \
			or (generation == 0) != (lifecycle == State.IDLE) \
			or cursor < 0 or cursor > BEACONS.size() \
			or (lifecycle == State.COMPLETE and cursor != BEACONS.size()) \
			or (lifecycle == State.ACTIVE and cursor >= BEACONS.size()) \
			or (lifecycle in [State.IDLE, State.RESET] and cursor != 0) \
			or entry.get("activity_id") != String(ACTIVITY_ID) \
			or entry.get("generation") != state.generation or entry.get("state") != state.state \
			or not entry.get("reward_requested") is bool or not entry.get("reward_granted") is bool \
			or not state.get("reward_requested") is bool \
			or entry.reward_requested != (lifecycle == State.COMPLETE) \
			or (entry.reward_granted and not entry.reward_requested) \
			or state.reward_requested != entry.reward_granted:
		return {"accepted": false, "reason": &"beacon_session_invalid"}
	return {"accepted": true, "reason": &"beacon_session_valid"}


## Reconcile only a validated durable payment for this exact live completion.
## A published transaction may report a directory-sync failure after its bytes
## became authoritative; retry must never turn that payment back into debt.
func acknowledge_persisted_reward(record: Dictionary) -> Dictionary:
	var checked := validate_persistence_record(record)
	if not checked.accepted:
		return checked
	var entry: Dictionary = record.activities[0]
	if _state != State.COMPLETE or int(entry.generation) != _generation \
			or not entry.reward_granted or int(entry.state) != State.COMPLETE:
		return _result(false, &"beacon_payment_generation_mismatch")
	_reward_requested = true
	return _result(true, &"beacon_payment_recovered")


func restore_persistence_record(record: Dictionary) -> Dictionary:
	var checked := validate_persistence_record(record)
	if not checked.accepted:
		return checked
	if _generation != 0 or _state != State.IDLE:
		return _result(false, &"beacon_session_owner_already_active")
	var state: Dictionary = record.activities[0].progress
	_generation = int(state.generation)
	_state = int(state.state)
	_next_index = int(state.next_beacon_index)
	_reward_requested = state.reward_requested
	return _result(true, &"beacon_session_restored")


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
