class_name NetworkCrewCommandAuthority
extends RefCounted

## Bounded command-envelope gate layered over NetworkCrewRoleAuthority.
## Receipts are detached; ship, weapon, repair, and ping systems consume them
## later and remain the owners of gameplay mutation.

const RoleAuthority := preload("res://scripts/network/network_crew_role_authority.gd")

const POLICY_VERSION: StringName = &"network_crew_command_authority_v1"
const MAX_COMMANDS_PER_TICK := 4
const MAX_ID_LENGTH := 64
const ROLE_ACTIONS := {
	&"pilot": &"flight_command",
	&"gunner": &"fire",
	&"engineer": &"repair",
	&"passenger": &"ping",
}

var _authority_peer_id := 1
var _role_authority
var _last_sequence: Dictionary = {}
var _tick_counts: Dictionary = {}
var _migration_generation := 1
var _event_sequence := 0
var _last_result: Dictionary = {}


func _init(role_authority = null, p_authority_peer_id: int = 1) -> void:
	_role_authority = role_authority if role_authority != null else RoleAuthority.new(null, p_authority_peer_id)
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_last_result = _result(false, &"uninitialized")


func accept_command(
		source_peer_id: int,
		peer_id: int,
		peer_generation: int,
		avatar_id: StringName,
		action: StringName,
	request_sequence: int,
	server_tick: int,
	payload: Dictionary,
	ship_id: StringName = &"",
	ship_generation: int = 0
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if peer_id <= 0 or peer_generation <= 0 or request_sequence <= 0 or server_tick < 0:
		return _remember(_result(false, &"invalid_command_identity"))
	var roles: Dictionary = _role_authority.get_snapshot().get("roles", {}) as Dictionary
	var role_record: Dictionary = roles.get(_key(peer_id, avatar_id), {}) as Dictionary
	if role_record.is_empty() or int(role_record.get("peer_generation", 0)) != peer_generation:
		return _remember(_result(false, &"role_not_admitted"))
	var role := StringName(role_record.get("role", &""))
	var assigned_ship_id := StringName(role_record.get("ship_id", &""))
	var assigned_ship_generation := int(role_record.get("ship_generation", 0))
	if ship_id.is_empty():
		ship_id = assigned_ship_id
	if ship_generation <= 0:
		ship_generation = assigned_ship_generation
	if ship_id.is_empty() or ship_generation <= 0 \
		or ship_id != assigned_ship_id or ship_generation != assigned_ship_generation:
		return _remember(_result(false, &"ship_identity_mismatch"))
	if StringName(ROLE_ACTIONS.get(role, &"")) != action:
		return _remember(_result(false, &"role_action_mismatch"))
	var stream_key := _key(peer_id, avatar_id)
	if request_sequence <= int(_last_sequence.get(stream_key, 0)):
		return _remember(_result(false, &"stale_command_sequence"))
	var tick_key := "%s:%d" % [str(stream_key), server_tick]
	var tick_count := int(_tick_counts.get(tick_key, 0))
	if tick_count >= MAX_COMMANDS_PER_TICK:
		return _remember(_result(false, &"command_rate_limited"))
	var checked := _validate_payload(action, payload)
	if not bool(checked.get("accepted", false)):
		return _remember(checked)
	_tick_counts[tick_key] = tick_count + 1
	_last_sequence[stream_key] = request_sequence
	_event_sequence += 1
	var receipt := {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"avatar_id": avatar_id,
		"seat_id": StringName(role_record.get("seat_id", &"")),
		"seat_generation": int(role_record.get("seat_generation", 0)),
		"ship_id": ship_id,
		"ship_generation": ship_generation,
		"role": role,
		"action": action,
		"request_sequence": request_sequence,
		"server_tick": server_tick,
		"migration_generation": _migration_generation,
		"payload": payload.duplicate(true),
	}
	return _remember(_result(true, &"command_accepted", {"receipt": receipt}))


func release_peer(source_peer_id: int, peer_id: int, peer_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var prefix := "%d:" % peer_id
	for key_variant in _last_sequence.keys():
		if str(key_variant).begins_with(prefix):
			_last_sequence.erase(key_variant)
	for tick_key_variant in _tick_counts.keys():
		if str(tick_key_variant).begins_with(prefix):
			_tick_counts.erase(tick_key_variant)
	return _remember(_result(true, &"peer_commands_released"))


func reset_migration(source_peer_id: int, migration_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if migration_generation <= _migration_generation:
		return _remember(_result(false, &"stale_migration_generation"))
	_migration_generation = migration_generation
	_last_sequence.clear()
	_tick_counts.clear()
	_event_sequence += 1
	return _remember(_result(true, &"migration_reset"))


func get_snapshot() -> Dictionary:
	return {
		"policy_version": POLICY_VERSION,
		"migration_generation": _migration_generation,
		"event_sequence": _event_sequence,
		"tracked_stream_count": _last_sequence.size(),
		"tracked_tick_count": _tick_counts.size(),
	}.duplicate(true)


func _validate_payload(action: StringName, payload: Dictionary) -> Dictionary:
	if action == &"flight_command":
		if not payload.has("thrust_x") or not payload.has("thrust_y") or payload.size() > 3:
			return _result(false, &"invalid_flight_payload")
		var x := float(payload.get("thrust_x", NAN))
		var y := float(payload.get("thrust_y", NAN))
		if not is_finite(x) or not is_finite(y) or absf(x) > 1.0 or absf(y) > 1.0:
			return _result(false, &"invalid_flight_payload")
		return _result(true, &"valid_payload")
	if action == &"fire":
		return _id_payload(payload, &"weapon_id", &"invalid_fire_payload")
	if action == &"repair":
		return _id_payload(payload, &"component_id", &"invalid_repair_payload")
	if action == &"ping":
		return _id_payload(payload, &"marker_id", &"invalid_ping_payload")
	return _result(false, &"unknown_command_action")


func _id_payload(payload: Dictionary, key: StringName, failure: StringName) -> Dictionary:
	if payload.size() != 1 or not payload.has(key):
		return _result(false, failure)
	var value := String(payload.get(key, ""))
	if value.is_empty() or value.length() > MAX_ID_LENGTH or not value.is_valid_identifier():
		return _result(false, failure)
	return _result(true, &"valid_payload")


func _key(peer_id: int, avatar_id: StringName) -> StringName:
	return StringName("%d:%s" % [peer_id, str(avatar_id)])


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
