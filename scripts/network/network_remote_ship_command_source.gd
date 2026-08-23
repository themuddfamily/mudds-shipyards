class_name NetworkRemoteShipCommandSource
extends RefCounted

const MovementAuthority := preload("res://scripts/network/network_movement_authority.gd")

const MAX_AXIS_LENGTH := 1.0
const MAX_COMMANDS_PER_TICK := 1

var _authority := MovementAuthority.new(1, 6, 2)
var _registered: Dictionary = {}
var _last_result: Dictionary = {"accepted": false, "status": &"uninitialized"}


func register_pilot(peer_id: int, ship_id: StringName, generation: int) -> Dictionary:
	if peer_id <= 0 or ship_id.is_empty() or generation <= 0:
		return _remember(_result(false, &"invalid_pilot_identity"))
	var result := _authority.register_avatar(1, peer_id, ship_id, generation, &"pilot")
	if bool(result.get("accepted", false)):
		_registered[ship_id] = {"peer_id": peer_id, "generation": generation}
	return _remember(result)


func accept_command(peer_id: int, command: Dictionary) -> Dictionary:
	var ship_id := StringName(command.get("entity_id", &""))
	var identity: Dictionary = _registered.get(ship_id, {}) as Dictionary
	if identity.is_empty() or int(identity.get("peer_id", 0)) != peer_id:
		return _remember(_result(false, &"pilot_owner_mismatch"))
	var axis: Variant = command.get("move_axis", null)
	if not axis is Array or (axis as Array).size() != 2:
		return _remember(_result(false, &"invalid_command_axis"))
	var vector := Vector2(float((axis as Array)[0]), float((axis as Array)[1]))
	if not vector.is_finite() or vector.length() > MAX_AXIS_LENGTH:
		return _remember(_result(false, &"command_axis_out_of_bounds"))
	var result := _authority.accept_intent(peer_id, command)
	return _remember(result)


func consume(ship_id: StringName, server_tick: int) -> Dictionary:
	var identity: Dictionary = _registered.get(ship_id, {}) as Dictionary
	if identity.is_empty():
		return _remember(_result(false, &"unknown_pilot"))
	return _remember(_authority.consume_for_tick(ship_id, int(identity.get("generation", 0)), server_tick))


func reset(ship_id: StringName, reason: StringName = &"reset") -> Dictionary:
	var identity: Dictionary = _registered.get(ship_id, {}) as Dictionary
	if identity.is_empty():
		return _remember(_result(true, &"already_reset"))
	_authority.retire_avatar(1, ship_id, int(identity.get("generation", 0)))
	_registered.erase(ship_id)
	return _remember(_result(true, reason))


func get_snapshot() -> Dictionary:
	var pilots: Array = []
	for ship_id in _registered.keys():
		pilots.append(_authority.get_avatar_snapshot(StringName(ship_id)))
	return {"pilot_count": pilots.size(), "pilots": pilots, "authority": "server_only"}.duplicate(true)


func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	for key in payload:
		result[key] = payload[key]
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
