class_name NetworkSeatAuthority
extends RefCounted

## Server-owned seat and crew-role ledger for a moving vessel.
##
## This is deliberately a detached authority contract: it performs no RPC,
## node lookup, movement, animation, or ship simulation. A server adapter may
## call `claim()` after validating a client intent, then replicate the detached
## `snapshot()` to clients. The seat record, rather than a passenger count or
## a client-side latch, is the source of truth for occupancy.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_seat_role_authority_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const ROLE_PILOT: StringName = &"pilot"
const ROLE_GUNNER: StringName = &"gunner"
const ROLE_PASSENGER: StringName = &"passenger"
const ROLE_ENGINEER: StringName = &"engineer"
const ROLES := [ROLE_PILOT, ROLE_GUNNER, ROLE_PASSENGER, ROLE_ENGINEER]

var _authority_peer_id := 1
var _seats: Dictionary = {}
var _assignments: Dictionary = {}
var _last_request_sequence_by_peer: Dictionary = {}
var _event_sequence := 0
var _last_result: Dictionary = {}


func _init(p_authority_peer_id: int = 1) -> void:
	_authority_peer_id = p_authority_peer_id
	_last_result = _result(false, &"uninitialized")


## Registers one stable seat. The caller owns the seat layout; this ledger owns
## only identity, role, frame binding, generation, and subsequent occupancy.
func register_seat(
	seat_id: StringName,
	vessel_id: StringName,
	role: StringName,
	frame_id: StringName = &"",
	seat_generation: int = 1
) -> Dictionary:
	if not _valid_id(seat_id) or not _valid_id(vessel_id):
		return _remember(_result(false, &"invalid_seat_identity"))
	if not _valid_role(role):
		return _remember(_result(false, &"invalid_role"))
	if not _valid_id_or_empty(frame_id):
		return _remember(_result(false, &"invalid_frame_identity"))
	if not _valid_positive_integer(seat_generation):
		return _remember(_result(false, &"invalid_seat_generation"))
	if _seats.has(seat_id):
		return _remember(_result(false, &"duplicate_seat"))
	_seats[seat_id] = {
		"seat_id": seat_id,
		"vessel_id": vessel_id,
		"role": role,
		"frame_id": frame_id,
		"seat_generation": seat_generation,
	}
	_event_sequence += 1
	return _remember(_result(true, &"registered", {"seat": _seats[seat_id]}))


## Atomically claims a seat on behalf of a validated client intent.
## `source_peer_id` is the authority that is allowed to commit the claim;
## `occupant_peer_id` identifies the client that will own the resulting seat.
## A request sequence is monotonic per occupant and prevents replay/reorder.
func claim(
	source_peer_id: int,
	occupant_peer_id: int,
	avatar_id: StringName,
	seat_id: StringName,
	requested_role: StringName,
	request_sequence: int
) -> Dictionary:
	var source_status := _validate_request(source_peer_id, occupant_peer_id, avatar_id, request_sequence)
	if not source_status.is_empty():
		return _remember(_result(false, source_status))
	if not _seats.has(seat_id):
		return _remember(_result(false, &"unknown_seat"))
	var seat := _seats[seat_id] as Dictionary
	if requested_role != StringName(seat.role):
		return _remember(_result(false, &"role_mismatch"))
	var key := _assignment_key(occupant_peer_id, avatar_id)
	if _assignments.has(key):
		return _remember(_result(false, &"avatar_already_seated"))
	for assignment_variant in _assignments.values():
		var assignment := assignment_variant as Dictionary
		if StringName(assignment.get("seat_id", &"")) == seat_id:
			return _remember(_result(false, &"seat_occupied"))
	_assignments[key] = {
		"occupant_peer_id": occupant_peer_id,
		"avatar_id": avatar_id,
		"seat_id": seat_id,
		"vessel_id": seat.vessel_id,
		"role": seat.role,
		"frame_id": seat.frame_id,
		"seat_generation": int(seat.seat_generation),
		"claim_sequence": request_sequence,
	}
	_last_request_sequence_by_peer[occupant_peer_id] = request_sequence
	_event_sequence += 1
	return _remember(_result(true, &"claimed", {"assignment": _assignments[key]}))


## Releases one assignment. Only the server can mutate the ledger. A seat
## generation is checked when supplied so a late release cannot clear a reused
## seat; zero means the caller is intentionally releasing the current record.
func release(
	source_peer_id: int,
	occupant_peer_id: int,
	avatar_id: StringName,
	seat_id: StringName,
	request_sequence: int,
	seat_generation: int = 0
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if occupant_peer_id <= 0 or not _valid_id(avatar_id) or not _valid_nonnegative_integer(request_sequence):
		return _remember(_result(false, &"invalid_release_request"))
	var key := _assignment_key(occupant_peer_id, avatar_id)
	if not _assignments.has(key):
		return _remember(_result(false, &"assignment_not_found"))
	var assignment := _assignments[key] as Dictionary
	if StringName(assignment.get("seat_id", &"")) != seat_id:
		return _remember(_result(false, &"seat_mismatch"))
	if seat_generation > 0 and int(assignment.get("seat_generation", 0)) != seat_generation:
		return _remember(_result(false, &"stale_seat_generation"))
	if not _accept_sequence(occupant_peer_id, request_sequence):
		return _remember(_result(false, &"stale_request_sequence"))
	_assignments.erase(key)
	_last_request_sequence_by_peer[occupant_peer_id] = request_sequence
	_event_sequence += 1
	return _remember(_result(true, &"released", {"assignment": assignment}))


## Disconnect cleanup is server lifecycle authority, not a client request.
func release_peer(source_peer_id: int, occupant_peer_id: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if occupant_peer_id <= 0:
		return _remember(_result(false, &"invalid_peer_id"))
	var removed: Array = []
	for key_variant in _assignments.keys():
		var key := StringName(key_variant)
		var assignment := _assignments[key] as Dictionary
		if int(assignment.get("occupant_peer_id", 0)) == occupant_peer_id:
			removed.append(assignment.duplicate(true))
			_assignments.erase(key)
	if not removed.is_empty():
		_event_sequence += 1
	_last_request_sequence_by_peer.erase(occupant_peer_id)
	return _remember(_result(true, &"peer_released", {"assignments": removed}))


func get_assignment(occupant_peer_id: int, avatar_id: StringName) -> Dictionary:
	var assignment: Variant = _assignments.get(_assignment_key(occupant_peer_id, avatar_id), {})
	return (assignment as Dictionary).duplicate(true)


func get_snapshot() -> Dictionary:
	var seats: Array = []
	for seat_variant in _seats.values():
		seats.append((seat_variant as Dictionary).duplicate(true))
	seats.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("seat_id", "")) < str(right.get("seat_id", ""))
	)
	var assignments: Array = []
	for assignment_variant in _assignments.values():
		assignments.append((assignment_variant as Dictionary).duplicate(true))
	assignments.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("seat_id", "")) < str(right.get("seat_id", ""))
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"event_sequence": _event_sequence,
		"seats": seats,
		"assignments": assignments,
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0,
		"authority_peer_id": _authority_peer_id,
		"registered_seat_count": _seats.size(),
		"occupied_seat_count": _assignments.size(),
		"server_owns_seat_reservation": true,
		"server_owns_role_assignment": true,
		"client_can_mutate_ledger": false,
		"owns_movement": false,
		"owns_ship_simulation": false,
		"owns_damage_or_landing": false,
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _validate_request(source_peer_id: int, occupant_peer_id: int, avatar_id: StringName, request_sequence: int) -> StringName:
	if source_peer_id != _authority_peer_id:
		return &"unauthorized_source"
	if occupant_peer_id <= 0 or not _valid_id(avatar_id):
		return &"invalid_claim_request"
	if not _valid_nonnegative_integer(request_sequence):
		return &"invalid_request_sequence"
	if not _accept_sequence(occupant_peer_id, request_sequence):
		return &"stale_request_sequence"
	return &""


func _accept_sequence(occupant_peer_id: int, request_sequence: int) -> bool:
	return request_sequence > int(_last_request_sequence_by_peer.get(occupant_peer_id, -1))


func _assignment_key(occupant_peer_id: int, avatar_id: StringName) -> StringName:
	return StringName("%d:%s" % [occupant_peer_id, str(avatar_id)])


func _valid_role(value: StringName) -> bool:
	return value in ROLES


func _valid_id_or_empty(value: StringName) -> bool:
	return value == &"" or _valid_id(value)


func _valid_id(value: StringName) -> bool:
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var ascii_alphanumeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (ascii_alphanumeric or codepoint == 95 or codepoint == 45):
			return false
	return true


func _valid_positive_integer(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _valid_nonnegative_integer(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_INTEGER


func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": accepted,
		"status": status,
		"event_sequence": _event_sequence,
	}
	for key in payload:
		result[key] = payload[key]
	return result.duplicate(true)


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result.duplicate(true)
