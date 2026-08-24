class_name PlanetarySurfaceNavigationRuntime
extends RefCounted

## Caller-evidence navigation state for one authored planetary surface route.
## The runtime advances only when a caller proves proximity to the next
## authored landmark. It never moves an actor, resolves terrain, or owns a
## route/teleport authority.

const ContractScript := preload("res://scripts/world/planetary_surface_navigation_contract.gd")
const WAYPOINT_RADIUS_M := 12.0
const NEARBY_CUE_DISTANCE_M := 50.0
const APPROACHING_CUE_DISTANCE_M := 250.0

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


## Restores detached route progress without restoring actor motion. Active
## sessions reopen as interrupted so a caller must explicitly resume them.
func restore_snapshot(snapshot: Variant) -> Dictionary:
	if _contract == null or not snapshot is Dictionary:
		return _result(false, &"invalid_route_snapshot")
	var saved := snapshot as Dictionary
	var saved_route := StringName(saved.get("route_id", &""))
	var saved_index := int(saved.get("waypoint_index", -1))
	if saved_route.is_empty() or saved_route != StringName(_landmarks[0].get("route_id", &"")):
		return _result(false, &"route_snapshot_mismatch")
	if saved_index < 0 or saved_index > _landmarks.size():
		return _result(false, &"route_snapshot_invalid_index")
	_route_id = saved_route
	_waypoint_index = saved_index
	_last_interruption = StringName(saved.get("last_interruption", &"session_restore"))
	_state = State.COMPLETED if saved_index == _landmarks.size() else State.INTERRUPTED
	return _result(true, &"route_restored")


func get_snapshot() -> Dictionary:
	var next_landmark := _next_landmark()
	return {
		"state": _state_id(),
		"route_id": _route_id,
		"waypoint_index": _waypoint_index,
		"next_landmark_id": StringName(next_landmark.get("id", &"")),
		"next_landmark": next_landmark,
		"landmark_count": _landmarks.size(),
		"last_interruption": _last_interruption,
		"waypoint_radius_m": WAYPOINT_RADIUS_M,
		"authority": {"movement": false, "teleport": false, "terrain": false},
	}.duplicate(true)


## Builds one detached, display-only target from caller-owned on-foot position
## evidence. This neither advances the route nor samples input, so a controller
## path can use the same cue without granting the runtime movement authority.
func get_next_landmark_feedback(position: Variant) -> Dictionary:
	if not _finite_vector(position):
		return _feedback_result(false, &"invalid_position")
	var landmark := _next_landmark()
	if landmark.is_empty() or _state not in [State.ACTIVE, State.INTERRUPTED]:
		return _feedback_result(false, &"next_landmark_unavailable")
	var target := landmark.get("position_body_local_m", Vector3.INF) as Vector3
	if not target.is_finite():
		return _feedback_result(false, &"next_landmark_unavailable")
	var distance := (position as Vector3).distance_to(target)
	return {
		"accepted": true,
		"reason": &"next_landmark_feedback_ready",
		"cue": {
			"available": true,
			"landmark_id": StringName(landmark.get("id", &"")),
			"label": str(landmark.get("display_name", "NEXT LANDMARK")),
			"target_body_local_m": target,
			"distance_m": distance,
			"distance_band": _distance_band(distance),
			"waypoint_radius_m": WAYPOINT_RADIUS_M,
			"route_state": _state_id(),
			"action": &"continue_to_landmark",
			"controller_only": true,
			"raw_input": false,
			"authority": {
				"navigation": false, "movement": false, "interaction": false,
			},
		}.duplicate(true),
	}.duplicate(true)


func _state_id() -> StringName:
	return [&"idle", &"active", &"interrupted", &"completed"][_state]


func _next_landmark() -> Dictionary:
	if _waypoint_index < 0 or _waypoint_index >= _landmarks.size():
		return {}
	return (_landmarks[_waypoint_index] as Dictionary).duplicate(true)


func _distance_band(distance_m: float) -> StringName:
	if distance_m <= WAYPOINT_RADIUS_M:
		return &"arriving"
	if distance_m <= NEARBY_CUE_DISTANCE_M:
		return &"nearby"
	if distance_m <= APPROACHING_CUE_DISTANCE_M:
		return &"approaching"
	return &"distant"


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


func _feedback_result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"cue": {
			"available": false,
			"controller_only": true,
			"raw_input": false,
			"authority": {
				"navigation": false, "movement": false, "interaction": false,
			},
		}.duplicate(true),
	}.duplicate(true)
