class_name PlanetarySurfaceNavigationRuntime
extends RefCounted

## Caller-evidence navigation state for one authored planetary surface route.
## The runtime advances only when a caller proves proximity to the next
## authored landmark. It never moves an actor, resolves terrain, or owns a
## route/teleport authority.

const ContractScript := preload("res://scripts/world/planetary_surface_navigation_contract.gd")
const WAYPOINT_RADIUS_M := 12.0

enum State { IDLE, ACTIVE, INTERRUPTED, COMPLETED }

var _contract: PlanetarySurfaceNavigationContract
var _landmarks: Array[Dictionary] = []
var _route_id: StringName = &""
var _waypoint_index := -1
var _state := State.IDLE
var _last_interruption: StringName = &""


func configure(contract: PlanetarySurfaceNavigationContract) -> Dictionary:
	if _contract != null:
		return _result(false, &"already_configured")
	if contract == null or not contract.is_definition_valid():
		return _result(false, &"invalid_navigation_contract")
	_contract = contract
	_landmarks = (contract.get_snapshot().get("landmarks", []) as Array).duplicate(true)
	return _result(true, &"configured")


func start_route(route_id: StringName = &"") -> Dictionary:
	if _contract == null:
		return _result(false, &"not_configured")
	if _state in [State.ACTIVE, State.INTERRUPTED]:
		return _result(false, &"route_already_active")
	if _landmarks.is_empty():
		return _result(false, &"route_has_no_landmarks")
	var first_route := StringName(_landmarks[0].get("route_id", &""))
	var selected_route := first_route if route_id.is_empty() else route_id
	if selected_route != first_route:
		return _result(false, &"unknown_route")
	_route_id = selected_route
	_waypoint_index = 0
	_state = State.ACTIVE
	_last_interruption = &""
	return _result(true, &"route_started")


## Commits one ordered waypoint from caller-owned landmark identity and
## position evidence. The runtime does not move or correct the caller.
func submit_landmark_evidence(landmark_id: StringName, position: Variant) -> Dictionary:
	if _state != State.ACTIVE:
		return _result(false, &"route_not_active")
	if not _finite_vector(position):
		return _result(false, &"invalid_position")
	var expected := _landmarks[_waypoint_index] as Dictionary
	var expected_id := StringName(expected.get("id", &""))
	if landmark_id != expected_id:
		return _result(false, &"landmark_mismatch")
	var target := expected.get("position_body_local_m", Vector3.INF) as Vector3
	if position.distance_to(target) > WAYPOINT_RADIUS_M:
		return _result(false, &"landmark_out_of_range")
	_waypoint_index += 1
	if _waypoint_index >= _landmarks.size():
		_state = State.COMPLETED
	return _result(true, &"route_completed" if _state == State.COMPLETED else &"waypoint_reached")


## Records a recoverable interruption while preserving the next waypoint.
func interrupt(reason: StringName = &"route_interrupted") -> Dictionary:
	if _state != State.ACTIVE:
		return _result(false, &"route_not_active")
	if reason.is_empty():
		return _result(false, &"interruption_reason_required")
	_state = State.INTERRUPTED
	_last_interruption = reason
	return _result(true, &"route_interrupted")


## Re-enters the same ordered route from caller-owned position evidence. The
## position is reported, never applied to an actor, and progress is retained.
func resume_route(position: Variant) -> Dictionary:
	if _state != State.INTERRUPTED:
		return _result(false, &"route_not_interrupted")
	if not _finite_vector(position):
		return _result(false, &"invalid_position")
	_state = State.ACTIVE
	return _result(true, &"route_resumed")


func get_snapshot() -> Dictionary:
	var next_landmark: StringName = &""
	if _waypoint_index >= 0 and _waypoint_index < _landmarks.size():
		next_landmark = StringName(_landmarks[_waypoint_index].get("id", &""))
	return {
		"state": _state_id(),
		"route_id": _route_id,
		"waypoint_index": _waypoint_index,
		"next_landmark_id": next_landmark,
		"landmark_count": _landmarks.size(),
		"last_interruption": _last_interruption,
		"waypoint_radius_m": WAYPOINT_RADIUS_M,
		"authority": {"movement": false, "teleport": false, "terrain": false},
	}.duplicate(true)


func _state_id() -> StringName:
	return [&"idle", &"active", &"interrupted", &"completed"][_state]


func _finite_vector(value: Variant) -> bool:
	if value is not Vector3:
		return false
	var vector := value as Vector3
	return is_finite(vector.x) and is_finite(vector.y) and is_finite(vector.z)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"runtime": get_snapshot(),
	}.duplicate(true)
