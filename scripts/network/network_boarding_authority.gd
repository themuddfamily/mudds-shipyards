class_name NetworkBoardingAuthority
extends RefCounted

## Server-owned boarding and moving-interior occupancy ledger.
##
## This detached authority performs no node lookup, movement, animation, or
## MultiplayerPeer work. A production adapter validates the physical approach
## and then submits a `NetworkBoardingIntent`. The server-owned seat record is
## the sole source of truth: one seat can have one occupant, and one avatar can
## have one seat. Ship, seat, and moving-frame generations fence late packets
## after destruction, stream replacement, or re-entry.

const Intent := preload("res://scripts/network/network_boarding_intent.gd")

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_boarding_occupancy_authority_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const MAX_SHIPS := 256
const MAX_SEATS := 1024
const DEFAULT_MAX_TICK_BEHIND := 6
const DEFAULT_MAX_TICK_AHEAD := 2

var _authority_peer_id := 1
var _max_tick_behind := DEFAULT_MAX_TICK_BEHIND
var _max_tick_ahead := DEFAULT_MAX_TICK_AHEAD
var _server_tick := 0
var _event_sequence := 0
var _ships: Dictionary = {}
var _seats: Dictionary = {}
var _occupancies: Dictionary = {}
var _last_sequence_by_avatar: Dictionary = {}
var _last_result: Dictionary = {}


func _init(
	p_authority_peer_id: int = 1,
	p_max_tick_behind: int = DEFAULT_MAX_TICK_BEHIND,
	p_max_tick_ahead: int = DEFAULT_MAX_TICK_AHEAD
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_max_tick_behind = maxi(0, p_max_tick_behind)
	_max_tick_ahead = maxi(0, p_max_tick_ahead)
	_last_result = _result(false, &"uninitialized")


## A ship record binds a stable ship identity to one moving-interior frame.
## Ship ownership/flight authority remains in NetworkShipOwnershipAuthority;
## this ledger only accepts occupancy claims for the registered generation.
func register_ship(
	source_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	frame_id: StringName,
	frame_generation: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_id(ship_id) or not _valid_positive_integer(ship_generation):
		return _remember(_result(false, &"invalid_ship_identity"))
	if not _valid_id(frame_id) or not _valid_positive_integer(frame_generation):
		return _remember(_result(false, &"invalid_frame_identity"))
	if _ships.has(ship_id):
		return _remember(_result(false, &"duplicate_ship"))
	if _ships.size() >= MAX_SHIPS:
		return _remember(_result(false, &"ship_capacity"))
	_ships[ship_id] = {
		"ship_id": ship_id,
		"ship_generation": ship_generation,
		"frame_id": frame_id,
		"frame_generation": frame_generation,
	}
	_event_sequence += 1
	return _remember(_result(true, &"ship_registered", {"ship": _ships[ship_id]}))


## Seat layout is server lifecycle data. Roles are labels checked against the
## intent; this method never assigns a role or lets clients create a seat.
func register_seat(
	source_peer_id: int,
	seat_id: StringName,
	ship_id: StringName,
	seat_generation: int,
	role: StringName
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_id(seat_id) or not _valid_positive_integer(seat_generation):
		return _remember(_result(false, &"invalid_seat_identity"))
	if not Intent.ROLES.has(role):
		return _remember(_result(false, &"invalid_role"))
	if not _ships.has(ship_id):
		return _remember(_result(false, &"unknown_ship"))
	if _seats.has(seat_id):
		return _remember(_result(false, &"duplicate_seat"))
	if _seats.size() >= MAX_SEATS:
		return _remember(_result(false, &"seat_capacity"))
	var ship := _ships[ship_id] as Dictionary
	_seats[seat_id] = {
		"seat_id": seat_id,
		"ship_id": ship_id,
		"ship_generation": int(ship.ship_generation),
		"frame_id": ship.frame_id,
		"frame_generation": int(ship.frame_generation),
		"seat_generation": seat_generation,
		"role": role,
	}
	_event_sequence += 1
	return _remember(_result(true, &"seat_registered", {"seat": _seats[seat_id]}))


func set_server_tick(source_peer_id: int, server_tick: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_nonnegative_integer(server_tick) or server_tick < _server_tick:
		return _remember(_result(false, &"stale_server_tick"))
	_server_tick = server_tick
	return _remember(_result(true, &"server_tick_advanced", {"server_tick": _server_tick}))


## Validates sender, lifecycle generations, tick window, and sequence before
## atomically changing occupancy. A disembark must carry the exact seat/frame
## record it is releasing, so a late packet cannot clear a reused seat.
func accept_intent(source_peer_id: int, wire: Dictionary) -> Dictionary:
	var intent = Intent.from_dictionary(wire)
	if not intent.is_valid():
		return _remember(_result(false, &"invalid_intent", {"errors": intent.get_validation_errors()}))
	if source_peer_id != intent.get_peer_id():
		# The packet sender is transport-authenticated before reaching this
		# server-owned ledger; reject a packet that names a different peer.
		return _remember(_result(false, &"spoofed_peer"))
	if not _ships.has(intent.get_ship_id()):
		return _remember(_result(false, &"unknown_ship"))
	var ship := _ships[intent.get_ship_id()] as Dictionary
	if int(ship.ship_generation) != intent.get_ship_generation():
		return _remember(_result(false, &"stale_ship_generation"))
	if StringName(ship.frame_id) != intent.get_frame_id():
		return _remember(_result(false, &"frame_mismatch"))
	if int(ship.frame_generation) != intent.get_frame_generation():
		return _remember(_result(false, &"stale_frame_generation"))
	if intent.get_client_tick() < _server_tick - _max_tick_behind:
		return _remember(_result(false, &"client_tick_too_old"))
	if intent.get_client_tick() > _server_tick + _max_tick_ahead:
		return _remember(_result(false, &"client_tick_too_far_ahead"))
	var avatar_key := _avatar_key(intent.get_peer_id(), intent.get_avatar_id())
	var previous_sequence := int(_last_sequence_by_avatar.get(avatar_key, -1))
	if intent.get_sequence() <= previous_sequence:
		return _remember(_result(false, &"stale_sequence"))
	_last_sequence_by_avatar[avatar_key] = intent.get_sequence()
	if not _seats.has(intent.get_seat_id()):
		return _remember(_result(false, &"unknown_seat"))
	var seat := _seats[intent.get_seat_id()] as Dictionary
	var seat_status := _validate_seat_generation(seat, intent)
	if not seat_status.is_empty():
		return _remember(_result(false, seat_status))
	if intent.get_action() == Intent.ACTION_BOARD:
		return _remember(_board(intent, seat, avatar_key))
	return _remember(_disembark(intent, seat, avatar_key))


func get_occupancy(peer_id: int, avatar_id: StringName) -> Dictionary:
	var value: Variant = _occupancies.get(_avatar_key(peer_id, avatar_id), {})
	return (value as Dictionary).duplicate(true)


func get_snapshot() -> Dictionary:
	var ships: Array = []
	for value in _ships.values():
		ships.append((value as Dictionary).duplicate(true))
	var seats: Array = []
	for value in _seats.values():
		seats.append((value as Dictionary).duplicate(true))
	var occupancies: Array = []
	for value in _occupancies.values():
		occupancies.append((value as Dictionary).duplicate(true))
	ships.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("ship_id", "")) < str(right.get("ship_id", "")))
	seats.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("seat_id", "")) < str(right.get("seat_id", "")))
	occupancies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("seat_id", "")) < str(right.get("seat_id", "")))
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"server_tick": _server_tick,
		"event_sequence": _event_sequence,
		"ships": ships,
		"seats": seats,
		"occupancies": occupancies,
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0,
		"server_owns_boarding": true,
		"server_owns_seat_occupancy": true,
		"server_owns_frame_binding": true,
		"client_can_mutate_occupancy": false,
		"one_seat_per_avatar": true,
		"one_avatar_per_seat": true,
		"owns_movement": false,
		"owns_ship_simulation": false,
		"registered_ship_count": _ships.size(),
		"registered_seat_count": _seats.size(),
		"occupied_seat_count": _occupancies.size(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


## Server lifecycle cleanup for disconnect. The peer's sequence streams are
## forgotten only after every occupancy record owned by that peer is removed.
func release_peer(source_peer_id: int, peer_id: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if peer_id <= 0:
		return _remember(_result(false, &"invalid_peer_id"))
	var released: Array = []
	for key_variant in _occupancies.keys():
		var key := StringName(key_variant)
		var occupancy := _occupancies[key] as Dictionary
		if int(occupancy.peer_id) != peer_id:
			continue
		released.append(occupancy.duplicate(true))
		_occupancies.erase(key)
	_last_sequence_by_avatar = _without_peer_sequences(peer_id)
	if not released.is_empty():
		_event_sequence += 1
	return _remember(_result(true, &"peer_released", {"occupancies": released}))


func retire_ship(source_peer_id: int, ship_id: StringName, ship_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _ships.has(ship_id):
		return _remember(_result(false, &"unknown_ship"))
	var ship := _ships[ship_id] as Dictionary
	if int(ship.ship_generation) != ship_generation:
		return _remember(_result(false, &"stale_ship_generation"))
	for key_variant in _occupancies.keys():
		var key := StringName(key_variant)
		if StringName((_occupancies[key] as Dictionary).ship_id) == ship_id:
			_occupancies.erase(key)
	for seat_id_variant in _seats.keys():
		var seat_id := StringName(seat_id_variant)
		if StringName((_seats[seat_id] as Dictionary).ship_id) == ship_id:
			_seats.erase(seat_id)
	_ships.erase(ship_id)
	_event_sequence += 1
	return _remember(_result(true, &"ship_retired", {"ship_id": ship_id, "ship_generation": ship_generation}))


func _board(intent, seat: Dictionary, avatar_key: StringName) -> Dictionary:
	if _occupancies.has(avatar_key):
		return _result(false, &"avatar_already_occupied")
	for occupancy_variant in _occupancies.values():
		var occupancy := occupancy_variant as Dictionary
		if StringName(occupancy.seat_id) == intent.get_seat_id():
			return _result(false, &"seat_occupied")
	var assignment := {
		"peer_id": intent.get_peer_id(),
		"avatar_id": intent.get_avatar_id(),
		"ship_id": intent.get_ship_id(),
		"ship_generation": intent.get_ship_generation(),
		"frame_id": intent.get_frame_id(),
		"frame_generation": intent.get_frame_generation(),
		"seat_id": intent.get_seat_id(),
		"seat_generation": intent.get_seat_generation(),
		"role": seat.role,
		"claim_sequence": intent.get_sequence(),
	}
	_occupancies[avatar_key] = assignment
	_event_sequence += 1
	return _result(true, &"boarded", {"occupancy": assignment})


func _disembark(intent, seat: Dictionary, avatar_key: StringName) -> Dictionary:
	if not _occupancies.has(avatar_key):
		return _result(false, &"occupancy_not_found")
	var occupancy := _occupancies[avatar_key] as Dictionary
	if StringName(occupancy.seat_id) != intent.get_seat_id():
		return _result(false, &"seat_mismatch")
	_occupancies.erase(avatar_key)
	_event_sequence += 1
	return _result(true, &"disembarked", {"occupancy": occupancy})


func _validate_seat_generation(seat: Dictionary, intent) -> StringName:
	if StringName(seat.ship_id) != intent.get_ship_id():
		return &"seat_ship_mismatch"
	if int(seat.ship_generation) != intent.get_ship_generation():
		return &"stale_ship_generation"
	if StringName(seat.frame_id) != intent.get_frame_id():
		return &"seat_frame_mismatch"
	if int(seat.frame_generation) != intent.get_frame_generation():
		return &"stale_frame_generation"
	if int(seat.seat_generation) != intent.get_seat_generation():
		return &"stale_seat_generation"
	if StringName(seat.role) != intent.get_role():
		return &"role_mismatch"
	return &""


func _avatar_key(peer_id: int, avatar_id: StringName) -> StringName:
	return StringName("%d:%s" % [peer_id, str(avatar_id)])


func _without_peer_sequences(peer_id: int) -> Dictionary:
	var remaining: Dictionary = {}
	for key_variant in _last_sequence_by_avatar.keys():
		var key := String(key_variant)
		if not key.begins_with("%d:" % peer_id):
			remaining[key_variant] = _last_sequence_by_avatar[key_variant]
	return remaining


func _valid_id(value: StringName) -> bool:
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var alpha_numeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (alpha_numeric or codepoint == 95 or codepoint == 45):
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
