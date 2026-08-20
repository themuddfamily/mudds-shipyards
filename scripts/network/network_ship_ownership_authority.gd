class_name NetworkShipOwnershipAuthority
extends RefCounted

## Server-owned ship ownership ledger and transfer boundary.
##
## This detached contract does not move a ship, select a seat, or replicate a
## transform. A server adapter registers the lifecycle generation, accepts a
## claim/transfer only from the authority process, and applies the returned
## owner to the existing ship/command owner. Clients never mutate this ledger
## directly. Ship generations fence destruction/respawn reuse; request
## sequences fence replay and reordering within one peer/ship stream.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_ship_ownership_authority_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const MAX_SHIPS := 256

var _authority_peer_id := 1
var _event_sequence := 0
var _ships: Dictionary = {}
var _last_request_sequence_by_ship_peer: Dictionary = {}
var _last_result: Dictionary = {}


func _init(p_authority_peer_id: int = 1) -> void:
	_authority_peer_id = p_authority_peer_id
	_last_result = _result(false, &"uninitialized")


## Registration and initial ownership are server lifecycle operations. An
## owner of zero means the ship is available for a later authoritative claim.
func register_ship(
	source_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	owner_peer_id: int = 0
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_id(ship_id) or not _valid_positive_integer(ship_generation):
		return _remember(_result(false, &"invalid_ship_identity"))
	if owner_peer_id < 0:
		return _remember(_result(false, &"invalid_owner_peer_id"))
	if _ships.has(ship_id):
		return _remember(_result(false, &"duplicate_ship"))
	if _ships.size() >= MAX_SHIPS:
		return _remember(_result(false, &"ship_capacity"))
	_ships[ship_id] = {
		"ship_id": ship_id,
		"ship_generation": ship_generation,
		"owner_peer_id": owner_peer_id,
		"ownership_generation": 0,
		"last_request_sequence": -1,
	}
	_event_sequence += 1
	return _remember(_result(true, &"registered", {
		"ship_id": ship_id,
		"ship_generation": ship_generation,
		"owner_peer_id": owner_peer_id,
	}))


## Claims are committed only by the server. `claimant_peer_id` identifies the
## client that receives ownership; it is not permission to mutate this ledger.
func claim(
	source_peer_id: int,
	claimant_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	request_sequence: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var identity_status := _validate_request_identity(claimant_peer_id, ship_id, ship_generation, request_sequence)
	if not identity_status.is_empty():
		return _remember(_result(false, identity_status))
	if not _ships.has(ship_id):
		return _remember(_result(false, &"unknown_ship"))
	var ship := _ships[ship_id] as Dictionary
	if int(ship.ship_generation) != ship_generation:
		return _remember(_result(false, &"stale_ship_generation"))
	if not _sequence_is_new(ship_id, claimant_peer_id, request_sequence):
		return _remember(_result(false, &"stale_request_sequence"))
	if int(ship.owner_peer_id) != 0:
		return _remember(_result(false, &"ship_already_owned"))
	ship.owner_peer_id = claimant_peer_id
	ship.ownership_generation = int(ship.ownership_generation) + 1
	ship.last_request_sequence = request_sequence
	_remember_sequence(ship_id, claimant_peer_id, request_sequence)
	_event_sequence += 1
	return _remember(_result(true, &"claimed", {
		"ship": ship.duplicate(true),
		"event_sequence": _event_sequence,
	}))


## Transfers are also server lifecycle commits. The expected current owner is
## checked before mutation so a late transfer cannot steal a reused command
## stream after disconnect or respawn.
func transfer(
	source_peer_id: int,
	from_peer_id: int,
	to_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	request_sequence: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var identity_status := _validate_request_identity(from_peer_id, ship_id, ship_generation, request_sequence)
	if not identity_status.is_empty():
		return _remember(_result(false, identity_status))
	if to_peer_id <= 0:
		return _remember(_result(false, &"invalid_destination_peer_id"))
	if to_peer_id == from_peer_id:
		return _remember(_result(false, &"same_owner"))
	if not _ships.has(ship_id):
		return _remember(_result(false, &"unknown_ship"))
	var ship := _ships[ship_id] as Dictionary
	if int(ship.ship_generation) != ship_generation:
		return _remember(_result(false, &"stale_ship_generation"))
	if int(ship.owner_peer_id) != from_peer_id:
		return _remember(_result(false, &"owner_mismatch"))
	if not _sequence_is_new(ship_id, from_peer_id, request_sequence):
		return _remember(_result(false, &"stale_request_sequence"))
	ship.owner_peer_id = to_peer_id
	ship.ownership_generation = int(ship.ownership_generation) + 1
	ship.last_request_sequence = request_sequence
	_remember_sequence(ship_id, from_peer_id, request_sequence)
	_event_sequence += 1
	return _remember(_result(true, &"transferred", {
		"ship": ship.duplicate(true),
		"from_peer_id": from_peer_id,
		"to_peer_id": to_peer_id,
		"event_sequence": _event_sequence,
	}))


## Explicit release remains server-only and is generation/sequence guarded.
func release(
	source_peer_id: int,
	owner_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	request_sequence: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var identity_status := _validate_request_identity(owner_peer_id, ship_id, ship_generation, request_sequence)
	if not identity_status.is_empty():
		return _remember(_result(false, identity_status))
	if not _ships.has(ship_id):
		return _remember(_result(false, &"unknown_ship"))
	var ship := _ships[ship_id] as Dictionary
	if int(ship.ship_generation) != ship_generation:
		return _remember(_result(false, &"stale_ship_generation"))
	if int(ship.owner_peer_id) != owner_peer_id:
		return _remember(_result(false, &"owner_mismatch"))
	if not _sequence_is_new(ship_id, owner_peer_id, request_sequence):
		return _remember(_result(false, &"stale_request_sequence"))
	ship.owner_peer_id = 0
	ship.ownership_generation = int(ship.ownership_generation) + 1
	ship.last_request_sequence = request_sequence
	_remember_sequence(ship_id, owner_peer_id, request_sequence)
	_event_sequence += 1
	return _remember(_result(true, &"released", {
		"ship": ship.duplicate(true),
		"released_owner_peer_id": owner_peer_id,
		"event_sequence": _event_sequence,
	}))


## Disconnect cleanup is a server lifecycle event, never a client RPC. It
## clears every ship owned by the peer and forgets that peer's request streams
## so a later connection with the same ID starts a fresh stream explicitly.
func release_peer(source_peer_id: int, peer_id: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if peer_id <= 0:
		return _remember(_result(false, &"invalid_peer_id"))
	var released_ship_ids: Array = []
	for ship_variant in _ships.values():
		var ship := ship_variant as Dictionary
		if int(ship.owner_peer_id) != peer_id:
			continue
		ship.owner_peer_id = 0
		ship.ownership_generation = int(ship.ownership_generation) + 1
		ship.last_request_sequence = -1
		released_ship_ids.append(ship.ship_id)
	_clear_peer_sequences(peer_id)
	if not released_ship_ids.is_empty():
		_event_sequence += 1
	return _remember(_result(true, &"peer_released", {
		"peer_id": peer_id,
		"ship_ids": released_ship_ids,
		"event_sequence": _event_sequence,
	}))


## A destroyed generation must be retired by the server before its ID can be
## registered again with a fresh lifecycle generation.
func retire_ship(source_peer_id: int, ship_id: StringName, ship_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _ships.has(ship_id):
		return _remember(_result(false, &"unknown_ship"))
	var ship := _ships[ship_id] as Dictionary
	if int(ship.ship_generation) != ship_generation:
		return _remember(_result(false, &"stale_ship_generation"))
	_ships.erase(ship_id)
	for key_variant in _last_request_sequence_by_ship_peer.keys():
		if str(key_variant).begins_with("%s:" % String(ship_id)):
			_last_request_sequence_by_ship_peer.erase(key_variant)
	_event_sequence += 1
	return _remember(_result(true, &"retired", {"ship_id": ship_id}))


func get_ship_snapshot(ship_id: StringName) -> Dictionary:
	if not _ships.has(ship_id):
		return {}
	return (_ships[ship_id] as Dictionary).duplicate(true)


func get_snapshot() -> Dictionary:
	var ships: Array = []
	for ship_variant in _ships.values():
		ships.append((ship_variant as Dictionary).duplicate(true))
	ships.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("ship_id", "")) < str(right.get("ship_id", ""))
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"event_sequence": _event_sequence,
		"ships": ships,
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0,
		"server_owns_ship_claims": true,
		"server_owns_ship_transfers": true,
		"server_owns_ship_generations": true,
		"server_owns_disconnect_cleanup": true,
		"client_can_mutate_ownership": false,
		"registered_ship_count": _ships.size(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _validate_request_identity(peer_id: int, ship_id: StringName, ship_generation: int, request_sequence: int) -> StringName:
	if peer_id <= 0:
		return &"invalid_peer_id"
	if not _valid_id(ship_id) or not _valid_positive_integer(ship_generation):
		return &"invalid_ship_identity"
	if not _valid_nonnegative_integer(request_sequence):
		return &"invalid_request_sequence"
	return &""


func _sequence_key(ship_id: StringName, peer_id: int) -> StringName:
	return StringName("%s:%d" % [String(ship_id), peer_id])


func _sequence_is_new(ship_id: StringName, peer_id: int, request_sequence: int) -> bool:
	return request_sequence > int(_last_request_sequence_by_ship_peer.get(_sequence_key(ship_id, peer_id), -1))


func _remember_sequence(ship_id: StringName, peer_id: int, request_sequence: int) -> void:
	_last_request_sequence_by_ship_peer[_sequence_key(ship_id, peer_id)] = request_sequence


func _clear_peer_sequences(peer_id: int) -> void:
	for key_variant in _last_request_sequence_by_ship_peer.keys():
		var key := str(key_variant)
		if key.ends_with(":%d" % peer_id):
			_last_request_sequence_by_ship_peer.erase(key_variant)


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


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	for key in extra:
		result[key] = extra[key]
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result
