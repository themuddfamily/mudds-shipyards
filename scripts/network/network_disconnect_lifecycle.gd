class_name NetworkDisconnectLifecycle
extends RefCounted

## Server-owned disconnect/reconnect lifecycle adapter.
##
## The existing detached seat, ship-ownership, replication-interest and
## session-handshake contracts each own one network concern. This adapter is
## the lifecycle seam that commits their peer cleanup together. A disconnect
## therefore cannot leave a seat occupied, a ship owned, or an interest region
## subscribed while a new transport with the same peer ID is admitted.
##
## No MultiplayerPeer, node, physics, transport, or presentation state is
## created here. The server adapter supplies the real process authority and
## uses the returned detached receipts to update production objects.

const Handshake := preload("res://scripts/network/network_session_handshake.gd")
const SeatAuthority := preload("res://scripts/network/network_seat_authority.gd")
const ShipAuthority := preload("res://scripts/network/network_ship_ownership_authority.gd")
const InterestAuthority := preload("res://scripts/network/network_replication_interest.gd")

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_disconnect_lifecycle_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64

var _authority_peer_id := 1
var _max_updates_per_tick := 16
var _handshake
var _seats
var _ships
var _interest
var _peers: Dictionary = {}
var _peer_interest: Dictionary = {}
var _entity_records: Dictionary = {}
var _event_sequence := 0
var _last_result: Dictionary = {}


func _init(
	p_authority_peer_id: int = 1,
	p_protocol_version: int = 1,
	p_package_generation: int = 1,
	p_session_generation: int = 1,
	p_max_updates_per_tick: int = 16
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_max_updates_per_tick = maxi(1, p_max_updates_per_tick)
	_handshake = Handshake.new(
		_authority_peer_id,
		maxi(1, p_protocol_version),
		maxi(1, p_package_generation),
		maxi(1, p_session_generation)
	)
	_seats = SeatAuthority.new(_authority_peer_id)
	_ships = ShipAuthority.new(_authority_peer_id)
	_interest = InterestAuthority.new(_authority_peer_id, _max_updates_per_tick)
	_last_result = _result(false, &"uninitialized")


static func create_hello(
	p_peer_id: int,
	p_peer_generation: int,
	p_protocol_version: int,
	p_package_generation: int,
	p_session_generation: int,
	p_schema_version: int = Handshake.SCHEMA_VERSION
) -> Dictionary:
	return Handshake.create_hello(
		p_peer_id,
		p_peer_generation,
		p_protocol_version,
		p_package_generation,
		p_session_generation,
		p_schema_version
	)


## Admission and every subsequent lifecycle operation remain server-gated.
## Handshake peer-generation high-water marks reject a delayed old rejoin.
func admit_peer(source_peer_id: int, wire: Dictionary) -> Dictionary:
	# `source_peer_id` is the authenticated transport peer for this one
	# admission packet. The handshake itself rejects spoofed packet identity;
	# no server-side caller can manufacture a different peer here.
	var accepted: Dictionary = _handshake.accept_hello(source_peer_id, wire)
	if not bool(accepted.get("accepted", false)):
		return _remember(_result(false, accepted.get("status", &"invalid_hello"), {
			"handshake": accepted,
		}))
	var peer: Dictionary = accepted.get("peer", {})
	var peer_id := int(peer.get("peer_id", 0))
	var peer_generation := int(peer.get("peer_generation", 0))
	var registered: Dictionary = _interest.register_peer(_authority_peer_id, peer_id)
	if not bool(registered.get("accepted", false)):
		_handshake.release_peer(_authority_peer_id, peer_id, peer_generation)
		return _remember(_result(false, &"interest_peer_registration_failed", {
			"interest": registered,
		}))
	_peers[peer_id] = {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"session_generation": int(peer.get("session_generation", 0)),
		"connected": true,
	}
	_event_sequence += 1
	return _remember(_result(true, &"admitted", {
		"peer": peer.duplicate(true),
		"server_offer": _handshake.get_server_offer(),
		"event_sequence": _event_sequence,
	}))


func register_seat(
	source_peer_id: int,
	seat_id: StringName,
	vessel_id: StringName,
	role: StringName,
	frame_id: StringName = &"",
	seat_generation: int = 1
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	return _remember(_seats.register_seat(
		seat_id, vessel_id, role, frame_id, seat_generation
	))


func claim_seat(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int,
	avatar_id: StringName,
	seat_id: StringName,
	role: StringName,
	request_sequence: int
) -> Dictionary:
	var peer_status := _require_peer(source_peer_id, peer_id, peer_generation)
	if not peer_status.is_empty():
		return _remember(_result(false, peer_status))
	return _remember(_seats.claim(
		_authority_peer_id,
		peer_id,
		avatar_id,
		seat_id,
		role,
		request_sequence
	))


func register_ship(
	source_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	owner_peer_id: int = 0
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	return _remember(_ships.register_ship(
		_authority_peer_id, ship_id, ship_generation, owner_peer_id
	))


func claim_ship(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int,
	ship_id: StringName,
	ship_generation: int,
	request_sequence: int
) -> Dictionary:
	var peer_status := _require_peer(source_peer_id, peer_id, peer_generation)
	if not peer_status.is_empty():
		return _remember(_result(false, peer_status))
	return _remember(_ships.claim(
		_authority_peer_id, peer_id, ship_id, ship_generation, request_sequence
	))


func register_entity(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	owner_peer_id: int,
	position: Vector3,
	replication_radius: float = 1000.0
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if owner_peer_id > 0 and not _peers.has(owner_peer_id):
		return _remember(_result(false, &"unknown_owner_peer"))
	var registered: Dictionary = _interest.register_entity(
		_authority_peer_id,
		entity_id,
		entity_generation,
		owner_peer_id,
		position,
		replication_radius
	)
	if bool(registered.get("accepted", false)):
		_entity_records[entity_id] = {
			"entity_id": entity_id,
			"entity_generation": entity_generation,
			"owner_peer_id": owner_peer_id,
			"position": position,
			"replication_radius": replication_radius,
			"state": {},
			"last_state_tick": 0,
		}
	return _remember(registered)


func publish_entity_state(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	server_tick: int,
	position: Vector3,
	state: Dictionary
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var published: Dictionary = _interest.publish_state(
		_authority_peer_id, entity_id, entity_generation, server_tick, position, state
	)
	if bool(published.get("accepted", false)) and _entity_records.has(entity_id):
		var record := _entity_records[entity_id] as Dictionary
		record["position"] = position
		record["state"] = state.duplicate(true)
		record["last_state_tick"] = server_tick
	return _remember(published)


func set_interest(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int,
	center: Vector3,
	radius: float,
	max_entities: int = 512
) -> Dictionary:
	var peer_status := _require_peer(source_peer_id, peer_id, peer_generation)
	if not peer_status.is_empty():
		return _remember(_result(false, peer_status))
	var updated: Dictionary = _interest.set_peer_interest(
		_authority_peer_id, peer_id, center, radius, max_entities
	)
	if bool(updated.get("accepted", false)):
		_peer_interest[peer_id] = {
			"center": center,
			"radius": radius,
			"max_entities": max_entities,
		}
	return _remember(updated)


func replicate(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int,
	server_tick: int
) -> Dictionary:
	var peer_status := _require_peer(source_peer_id, peer_id, peer_generation)
	if not peer_status.is_empty():
		return _remember(_result(false, peer_status))
	return _remember(_interest.replicate(
		_authority_peer_id, peer_id, server_tick
	))


## Atomically releases all peer-owned seats and ships and removes the peer's
## interest subscription. InterestAuthority predates a peer-release method, so
## its detached state is rebuilt from this adapter's server-owned records; no
## stale peer subscription survives the rebuild.
func disconnect_peer(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var peer_status := _require_peer(source_peer_id, peer_id, peer_generation)
	if not peer_status.is_empty():
		return _remember(_result(false, peer_status))
	var seats: Dictionary = _seats.release_peer(_authority_peer_id, peer_id)
	var ships: Dictionary = _ships.release_peer(_authority_peer_id, peer_id)
	var removed_interest := _peer_interest.erase(peer_id)
	for entity_variant in _entity_records.values():
		var entity := entity_variant as Dictionary
		if int(entity.get("owner_peer_id", 0)) == peer_id:
			entity["owner_peer_id"] = 0
	var released: Dictionary = _handshake.release_peer(
		_authority_peer_id, peer_id, peer_generation
	)
	_peers.erase(peer_id)
	_rebuild_interest_authority()
	_event_sequence += 1
	return _remember(_result(true, &"disconnected", {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"seat_cleanup": seats,
		"ship_cleanup": ships,
		"interest_removed": removed_interest,
		"handshake_cleanup": released,
		"event_sequence": _event_sequence,
	}))


## Session rotation invalidates every current transport before any new join.
## Peer-generation watermarks remain in NetworkSessionHandshake, so a new
## session still requires a strictly newer peer generation.
func rotate_session(
	source_peer_id: int,
	next_package_generation: int = -1
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var rotated: Dictionary = _handshake.rotate_session(
		_authority_peer_id, next_package_generation
	)
	if not bool(rotated.get("accepted", false)):
		return _remember(rotated)
	var released_peer_ids: Array = []
	for peer_variant in _peers.values():
		var peer := peer_variant as Dictionary
		var peer_id := int(peer.get("peer_id", 0))
		released_peer_ids.append(peer_id)
		_seats.release_peer(_authority_peer_id, peer_id)
		_ships.release_peer(_authority_peer_id, peer_id)
		for entity_variant in _entity_records.values():
			var entity := entity_variant as Dictionary
			if int(entity.get("owner_peer_id", 0)) == peer_id:
				entity["owner_peer_id"] = 0
	_peers.clear()
	_peer_interest.clear()
	_rebuild_interest_authority()
	_event_sequence += 1
	return _remember(_result(true, &"session_rotated", {
		"session_generation": rotated.get("session_generation", 0),
		"package_generation": rotated.get("package_generation", 0),
		"released_peer_ids": released_peer_ids,
		"event_sequence": _event_sequence,
	}))


func get_peer(peer_id: int) -> Dictionary:
	if not _peers.has(peer_id):
		return {}
	return (_peers[peer_id] as Dictionary).duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"event_sequence": _event_sequence,
		"session": _handshake.get_snapshot(),
		"peers": _sorted_records(_peers.values(), "peer_id"),
		"peer_interest": _peer_interest.duplicate(true),
		"seats": _seats.get_snapshot(),
		"ships": _ships.get_snapshot(),
		"interest": _get_interest_snapshot(),
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0,
		"server_owns_disconnect_cleanup": true,
		"server_owns_session_rotation": true,
		"server_owns_seat_cleanup": true,
		"server_owns_ship_cleanup": true,
		"server_owns_interest_cleanup": true,
		"stale_rejoins_rejected": true,
		"active_peer_count": _peers.size(),
		"active_interest_count": _peer_interest.size(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _require_peer(source_peer_id: int, peer_id: int, peer_generation: int) -> StringName:
	if source_peer_id != _authority_peer_id:
		return &"unauthorized_source"
	if peer_id <= 0 or peer_generation <= 0:
		return &"invalid_peer_identity"
	if not _peers.has(peer_id):
		return &"peer_not_connected"
	var peer := _peers[peer_id] as Dictionary
	if int(peer.get("peer_generation", 0)) != peer_generation:
		return &"stale_peer_generation"
	return &""


func _rebuild_interest_authority() -> void:
	_interest = InterestAuthority.new(_authority_peer_id, _max_updates_per_tick)
	for peer_variant in _peers.values():
		var peer := peer_variant as Dictionary
		var peer_id := int(peer.get("peer_id", 0))
		_interest.register_peer(_authority_peer_id, peer_id)
		if _peer_interest.has(peer_id):
			var region := _peer_interest[peer_id] as Dictionary
			_interest.set_peer_interest(
				_authority_peer_id,
				peer_id,
				region.get("center", Vector3.ZERO),
				float(region.get("radius", 0.0)),
				int(region.get("max_entities", 512))
			)
	var ordered_ids := _entity_records.keys()
	ordered_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str(left) < str(right)
	)
	var rebuild_tick := 0
	for entity_id_variant in ordered_ids:
		var record := _entity_records[entity_id_variant] as Dictionary
		_interest.register_entity(
			_authority_peer_id,
			StringName(record.get("entity_id", entity_id_variant)),
			int(record.get("entity_generation", 1)),
			int(record.get("owner_peer_id", 0)),
			record.get("position", Vector3.ZERO),
			float(record.get("replication_radius", 1000.0))
		)
		var state: Dictionary = record.get("state", {})
		var state_tick := int(record.get("last_state_tick", 0))
		rebuild_tick = maxi(rebuild_tick, state_tick)
		if not state.is_empty():
			_interest.publish_state(
				_authority_peer_id,
				StringName(record.get("entity_id", entity_id_variant)),
				int(record.get("entity_generation", 1)),
				rebuild_tick,
				record.get("position", Vector3.ZERO),
				state
			)


func _get_interest_snapshot() -> Dictionary:
	var peers: Array = []
	for peer_variant in _peers.values():
		var peer := peer_variant as Dictionary
		var peer_id := int(peer.get("peer_id", 0))
		var region: Dictionary = _peer_interest.get(peer_id, {})
		peers.append({
			"peer_id": peer_id,
			"peer_generation": int(peer.get("peer_generation", 0)),
			"center": region.get("center", Vector3.ZERO),
			"radius": float(region.get("radius", 0.0)),
			"max_entities": int(region.get("max_entities", 0)),
		})
	peers.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("peer_id", 0)) < int(right.get("peer_id", 0))
	)
	var entities: Array = []
	for entity_id_variant in _entity_records.keys():
		var entity_id := StringName(entity_id_variant)
		var entity: Dictionary = _interest.get_entity_snapshot(entity_id)
		if entity.is_empty():
			entity = (_entity_records[entity_id_variant] as Dictionary).duplicate(true)
		entities.append(entity)
	entities.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("entity_id", "")) < str(right.get("entity_id", ""))
	)
	return {
		"schema_version": InterestAuthority.SCHEMA_VERSION,
		"policy_version": InterestAuthority.POLICY_VERSION,
		"peers": peers,
		"entities": entities,
	}.duplicate(true)


func _sorted_records(values: Array, key: String) -> Array:
	var records: Array = []
	for value in values:
		if value is Dictionary:
			records.append((value as Dictionary).duplicate(true))
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get(key, "")) < str(right.get(key, ""))
	)
	return records


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result
