class_name PlanetaryActivityLandmarkRuntime
extends RefCounted

## Proximity/discovery handoff over the authored activity landmark cluster.
## Receipts are caller evidence only: this runtime never moves actors, starts
## activities, grants rewards, or owns route/navigation authority.

const ContractScript := preload("res://scripts/world/planetary_activity_landmark_cluster_contract.gd")
const MAX_DISCOVERY_RADIUS_M := 250.0
const ACTIVATION_RADIUS_M := 24.0

var _configured := false
var _landmarks: Dictionary = {}
var _activities: Dictionary = {}
var _sequence_activity_ids: Array[StringName] = []
var _sequence_landmark_ids: Array[StringName] = []
var _sequence_index := -1


func configure(contract: PlanetaryActivityLandmarkClusterContract) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if contract == null or not contract.is_definition_valid():
		return _result(false, &"invalid_landmark_cluster")
	var snapshot := contract.get_snapshot()
	for item in snapshot.get("landmarks", []) as Array:
		var landmark := item as Dictionary
		_landmarks[StringName(landmark.get("id", &""))] = landmark.duplicate(true)
	for item in snapshot.get("activities", []) as Array:
		var activity := item as Dictionary
		_activities[StringName(activity.get("id", &""))] = activity.duplicate(true)
	_configured = true
	return _result(true, &"configured")


func discover(position: Variant, radius_m: Variant) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not _finite_vector(position) or not _finite_range(radius_m, 0.0, MAX_DISCOVERY_RADIUS_M):
		return _result(false, &"invalid_discovery_query")
	var discoveries: Array[Dictionary] = []
	for landmark_id: StringName in _landmarks.keys():
		var landmark := _landmarks[landmark_id] as Dictionary
		var distance := (position as Vector3).distance_to(landmark.position_body_local_m)
		if distance <= float(radius_m):
			discoveries.append({
				"landmark_id": landmark_id,
				"display_name": landmark.display_name,
				"kind": landmark.kind,
				"distance_m": distance,
				"discovery_receipt": true,
			})
	discoveries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.distance_m) < float(b.distance_m)
	)
	return _result(true, &"landmarks_discovered", {"discoveries": discoveries})


func begin_activity_sequence(activity_ids: Array[StringName]) -> Dictionary:
	if not _configured or activity_ids.is_empty():
		return _result(false, &"activity_sequence_invalid")
	var landmark_ids: Array[StringName] = []
	for activity_id in activity_ids:
		if not _activities.has(activity_id):
			return _result(false, &"unknown_activity")
		var start := StringName((_activities[activity_id] as Dictionary).get("start_landmark_id", &""))
		if not _landmarks.has(start):
			return _result(false, &"activity_landmark_missing")
		landmark_ids.append(start)
	_sequence_activity_ids = activity_ids.duplicate()
	_sequence_landmark_ids = landmark_ids
	_sequence_index = 0
	return _result(true, &"activity_sequence_ready")


func activate_landmark(landmark_id: StringName, position: Variant) -> Dictionary:
	if _sequence_index < 0 or _sequence_index >= _sequence_landmark_ids.size():
		return _result(false, &"activity_sequence_inactive")
	if not _finite_vector(position):
		return _result(false, &"invalid_activation_position")
	var expected := _sequence_landmark_ids[_sequence_index]
	if landmark_id != expected:
		return _result(false, &"landmark_order_mismatch")
	var landmark := _landmarks[landmark_id] as Dictionary
	var distance := (position as Vector3).distance_to(landmark.position_body_local_m)
	if distance > ACTIVATION_RADIUS_M:
		return _result(false, &"landmark_out_of_range")
	var activity := _activities[_sequence_activity_ids[_sequence_index]] as Dictionary
	var receipt := {
		"landmark_id": landmark_id,
		"activity_id": _sequence_activity_ids[_sequence_index],
		"route_id": activity.route_id,
		"distance_m": distance,
		"route_eligible": true,
		"sequence_index": _sequence_index,
		"discovery_receipt": true,
	}.duplicate(true)
	_sequence_index += 1
	return _result(true, &"landmark_activated", {"receipt": receipt})


func get_snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"sequence_index": _sequence_index,
		"next_landmark_id": _sequence_landmark_ids[_sequence_index] if _sequence_index >= 0 and _sequence_index < _sequence_landmark_ids.size() else &"",
		"authority": {"movement": false, "activity": false, "reward": false, "navigation": false},
	}.duplicate(true)


func _finite_range(value: Variant, minimum: float, maximum: float) -> bool:
	if value is not float and value is not int:
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum


func _finite_vector(value: Variant) -> bool:
	return value is Vector3 and (value as Vector3).is_finite()


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := extra.duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	result["runtime"] = get_snapshot()
	return result.duplicate(true)
