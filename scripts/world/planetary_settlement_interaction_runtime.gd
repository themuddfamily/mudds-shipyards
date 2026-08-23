class_name PlanetarySettlementInteractionRuntime
extends RefCounted

## Caller-evidence interaction handoff over authored settlement structures.
## It emits stable enter/exit/activity intents without moving actors, opening
## doors, starting activities, or granting rewards.

const ContractScript := preload("res://scripts/world/planetary_settlement_structure_contract.gd")
const MAX_DISCOVERY_RADIUS_M := 250.0
const INTERACTION_RADIUS_M := 18.0

enum State { IDLE, INSIDE, DETACHED }

var _configured := false
var _structures: Dictionary = {}
var _landmarks: Dictionary = {}
var _activities: Array[Dictionary] = []
var _active_structure: StringName = &""
var _attachment_generation := 0
var _state := State.IDLE


func configure(contract: PlanetarySettlementStructureContract) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if contract == null or not contract.is_definition_valid():
		return _result(false, &"invalid_settlement_contract")
	var snapshot := contract.get_snapshot()
	for item in snapshot.get("structures", []) as Array:
		var structure := item as Dictionary
		_structures[StringName(structure.get("id", &""))] = structure.duplicate(true)
	for item in snapshot.get("landmarks", []) as Array:
		var landmark := item as Dictionary
		_landmarks[StringName(landmark.get("id", &""))] = landmark.duplicate(true)
	for item in snapshot.get("activities", []) as Array:
		_activities.append((item as Dictionary).duplicate(true))
	_configured = true
	return _result(true, &"configured")


func discover(position: Variant, radius_m: Variant) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not _finite_vector(position) or not _finite_range(radius_m, 0.0, MAX_DISCOVERY_RADIUS_M):
		return _result(false, &"invalid_discovery_query")
	var discoveries: Array[Dictionary] = []
	for structure_id: StringName in _structures.keys():
		var structure := _structures[structure_id] as Dictionary
		var distance := (position as Vector3).distance_to(structure.position_body_local_m)
		if distance <= float(radius_m):
			discoveries.append({"structure_id": structure_id, "kind": structure.kind, "route_id": structure.route_id, "distance_m": distance, "interaction_id": &"structure:%s" % structure_id})
	discoveries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance_m) < float(b.distance_m))
	return _result(true, &"structures_discovered", {"discoveries": discoveries})


func enter_structure(structure_id: StringName, position: Variant, attachment_generation: Variant) -> Dictionary:
	if not _configured or _state != State.IDLE:
		return _result(false, &"structure_entry_unavailable")
	if not _structures.has(structure_id) or not _finite_vector(position) or not _valid_generation(attachment_generation):
		return _result(false, &"invalid_structure_entry")
	var structure := _structures[structure_id] as Dictionary
	var distance := (position as Vector3).distance_to(structure.position_body_local_m)
	if distance > INTERACTION_RADIUS_M:
		return _result(false, &"structure_out_of_range")
	_active_structure = structure_id
	_attachment_generation = int(attachment_generation)
	_state = State.INSIDE
	var intents: Array[Dictionary] = []
	for activity in _activities:
		var start_landmark := _landmarks.get(StringName(activity.get("start_landmark_id", &"")), {}) as Dictionary
		var start_distance := (structure.position_body_local_m as Vector3).distance_to(start_landmark.get("position_body_local_m", Vector3.INF) as Vector3)
		if StringName(activity.get("route_id", &"")) == StringName(structure.get("route_id", &"")) or start_distance <= 40.0:
			intents.append({"activity_id": activity.get("id", &""), "start_landmark_id": activity.get("start_landmark_id", &""), "activity_intent": true})
	return _result(true, &"structure_entered", {"receipt": {"interaction_id": &"structure:%s:enter" % structure_id, "structure_id": structure_id, "distance_m": distance, "activity_intents": intents}})


func exit_structure(expected_attachment_generation: Variant) -> Dictionary:
	if _state != State.INSIDE:
		return _result(false, &"structure_not_entered")
	if int(expected_attachment_generation) != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	var exited := _active_structure
	_active_structure = &""
	_state = State.IDLE
	return _result(true, &"structure_exited", {"interaction_id": &"structure:%s:exit" % exited})


func detach() -> Dictionary:
	if _state != State.INSIDE:
		return _result(false, &"structure_not_entered")
	_state = State.DETACHED
	return _result(true, &"structure_detached")


func reenter(new_attachment_generation: Variant) -> Dictionary:
	if _state != State.DETACHED or not _valid_generation(new_attachment_generation):
		return _result(false, &"structure_reentry_unavailable")
	if int(new_attachment_generation) <= _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	_attachment_generation = int(new_attachment_generation)
	_state = State.INSIDE
	return _result(true, &"structure_reentered", {"structure_id": _active_structure})


func get_snapshot() -> Dictionary:
	return {"configured": _configured, "state": [&"idle", &"inside", &"detached"][_state], "active_structure_id": _active_structure, "attachment_generation": _attachment_generation, "authority": {"movement": false, "activity": false, "reward": false, "doors": false}}.duplicate(true)


func _valid_generation(value: Variant) -> bool:
	return value is int and int(value) > 0


func _finite_range(value: Variant, minimum: float, maximum: float) -> bool:
	if value is not float and value is not int: return false
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
