class_name NetworkCrewRoleAuthority
extends RefCounted

## Server-owned multicrew role intent ledger layered over NetworkSeatAuthority.
## It never claims seats or mutates ship state; the seat ledger remains the
## source of truth for occupancy and generation.

const SeatAuthority := preload("res://scripts/network/network_seat_authority.gd")

const POLICY_VERSION: StringName = &"network_crew_role_authority_v1"
const ROLE_PILOT: StringName = &"pilot"
const ROLE_GUNNER: StringName = &"gunner"
const ROLE_ENGINEER: StringName = &"engineer"
const ROLE_PASSENGER: StringName = &"passenger"
const ROLES := [ROLE_PILOT, ROLE_GUNNER, ROLE_ENGINEER, ROLE_PASSENGER]

var _authority_peer_id := 1
var _seat_authority
var _peers: Dictionary = {}
var _roles: Dictionary = {}
var _last_sequence: Dictionary = {}
var _migration_generation := 1
var _event_sequence := 0
var _last_result: Dictionary = {}


func _init(p_seat_authority = null, p_authority_peer_id: int = 1) -> void:
	_seat_authority = p_seat_authority if p_seat_authority != null else SeatAuthority.new(p_authority_peer_id)
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_last_result = _result(false, &"uninitialized")


func admit_peer(source_peer_id: int, peer_id: int, peer_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if peer_id <= 0 or peer_generation <= 0:
		return _remember(_result(false, &"invalid_peer_generation"))
	var current := int(_peers.get(peer_id, 0))
	if current > peer_generation:
		return _remember(_result(false, &"stale_peer_generation"))
	_peers[peer_id] = peer_generation
	return _remember(_result(true, &"peer_admitted", {"peer_id": peer_id, "peer_generation": peer_generation}))


func accept_role_intent(
		source_peer_id: int,
		peer_id: int,
		peer_generation: int,
	avatar_id: StringName,
	requested_role: StringName,
	request_sequence: int,
	ship_id: StringName = &"",
	ship_generation: int = 0
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _peers.has(peer_id) or int(_peers[peer_id]) != peer_generation:
		return _remember(_result(false, &"peer_not_admitted"))
	if not ROLES.has(requested_role) or avatar_id.is_empty() or request_sequence <= 0:
		return _remember(_result(false, &"invalid_role_intent"))
	var stream_key := _key(peer_id, avatar_id)
	if request_sequence <= int(_last_sequence.get(stream_key, 0)):
		return _remember(_result(false, &"stale_request_sequence"))
	var assignment: Dictionary = _seat_authority.get_assignment(peer_id, avatar_id)
	if assignment.is_empty():
		return _remember(_result(false, &"peer_not_seated"))
	if StringName(assignment.get("role", &"")) != requested_role:
		return _remember(_result(false, &"role_escalation_rejected"))
	var assigned_ship_id := StringName(assignment.get("vessel_id", &""))
	var assigned_ship_generation := int(assignment.get("seat_generation", 0))
	if ship_id.is_empty():
		ship_id = assigned_ship_id
	if ship_generation <= 0:
		ship_generation = assigned_ship_generation
	if ship_id != assigned_ship_id or ship_generation != assigned_ship_generation:
		return _remember(_result(false, &"ship_identity_mismatch"))
	var record := {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"avatar_id": avatar_id,
		"seat_id": StringName(assignment.get("seat_id", &"")),
		"seat_generation": int(assignment.get("seat_generation", 0)),
		"ship_id": ship_id,
		"ship_generation": ship_generation,
		"role": requested_role,
		"request_sequence": request_sequence,
		"migration_generation": _migration_generation,
	}
	_roles[stream_key] = record
	_last_sequence[stream_key] = request_sequence
	_event_sequence += 1
	return _remember(_result(true, &"role_accepted", {"role": record.duplicate(true)}))


func release_peer(source_peer_id: int, peer_id: int, peer_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if int(_peers.get(peer_id, 0)) != peer_generation:
		return _remember(_result(false, &"stale_peer_generation"))
	var released: Array = []
	for key_variant in _roles.keys():
		var key := StringName(key_variant)
		if int((_roles[key] as Dictionary).get("peer_id", 0)) == peer_id:
			released.append((_roles[key] as Dictionary).duplicate(true))
			_roles.erase(key)
			_last_sequence.erase(key)
	_peers.erase(peer_id)
	_event_sequence += 1
	return _remember(_result(true, &"peer_released", {"released_roles": released}))


func release_avatar(source_peer_id: int, peer_id: int, peer_generation: int, avatar_id: StringName) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if int(_peers.get(peer_id, 0)) != peer_generation or avatar_id.is_empty():
		return _remember(_result(false, &"stale_peer_generation"))
	var key := _key(peer_id, avatar_id)
	_roles.erase(key)
	_last_sequence.erase(key)
	_event_sequence += 1
	return _remember(_result(true, &"avatar_released"))


func reset_migration(source_peer_id: int, migration_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if migration_generation <= _migration_generation:
		return _remember(_result(false, &"stale_migration_generation"))
	_migration_generation = migration_generation
	_roles.clear()
	_last_sequence.clear()
	_event_sequence += 1
	return _remember(_result(true, &"migration_reset", {"migration_generation": _migration_generation}))


func get_snapshot() -> Dictionary:
	return {
		"policy_version": POLICY_VERSION,
		"migration_generation": _migration_generation,
		"event_sequence": _event_sequence,
		"admitted_peer_count": _peers.size(),
		"role_count": _roles.size(),
		"roles": _roles.duplicate(true),
	}.duplicate(true)


func _key(peer_id: int, avatar_id: StringName) -> StringName:
	return StringName("%d:%s" % [peer_id, str(avatar_id)])


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
