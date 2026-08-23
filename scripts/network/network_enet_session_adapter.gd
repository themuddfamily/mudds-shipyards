class_name NetworkEnetSessionAdapter
extends Node

## Production transport bridge for the detached authoritative session seams.
##
## This node owns only process transport and packet routing. Admission, peer
## generations, disconnect cleanup, and snapshot ordering remain owned by
## NetworkSnapshotLifecycleAdapter; the server is the only side allowed to
## publish a snapshot. GameFlow and scene replicas can compose this node later
## without taking ownership of transport or lifecycle policy themselves.

const LifecycleAdapter := preload("res://scripts/network/network_snapshot_lifecycle_adapter.gd")
const TransportSecurity := preload("res://scripts/network/network_transport_security.gd")
const MovementAuthority := preload("res://scripts/network/network_movement_authority.gd")
const BoardingAuthority := preload("res://scripts/network/network_boarding_authority.gd")
const ProjectileAuthority := preload("res://scripts/network/network_projectile_authority.gd")
const LandingAuthority := preload("res://scripts/network/network_landing_authority.gd")
const DamageRespawnIntegration := preload("res://scripts/network/network_damage_respawn_integration.gd")
const MovingInteriorAuthority := preload("res://scripts/network/network_moving_interior_authority.gd")
const ShipOwnershipAuthority := preload("res://scripts/network/network_ship_ownership_authority.gd")
const SeatAuthority := preload("res://scripts/network/network_seat_authority.gd")
const SessionMigration := preload("res://scripts/network/network_session_migration.gd")

signal session_started(mode: StringName)
signal session_stopped(reason: StringName)
signal peer_admitted(peer_id: int, receipt: Dictionary)
signal peer_disconnected(peer_id: int, receipt: Dictionary)
signal snapshot_published(packet: Dictionary)
signal snapshot_applied(result: Dictionary)
signal transport_rejected(status: StringName)
signal movement_intent_result(result: Dictionary)
signal boarding_intent_result(result: Dictionary)
signal projectile_intent_result(result: Dictionary)
signal landing_intent_result(result: Dictionary)
signal damage_respawn_result(result: Dictionary)
signal moving_interior_result(result: Dictionary)
signal ship_ownership_result(result: Dictionary)
signal seat_occupancy_result(result: Dictionary)
signal migration_result(result: Dictionary)

const DEFAULT_PORT := 27101
const DEFAULT_MAX_CLIENTS := 8
const AUTHORITY_PEER_ID := 1

var _peer: ENetMultiplayerPeer
var _lifecycle
var _transport
var _movement
var _boarding
var _projectile
var _landing
var _damage_respawn
var _moving_interior
var _ship_ownership
var _seat_authority
var _migration
var _is_server := false
var _configured := false
var _peer_generations: Dictionary = {}
var _projectile_sources: Dictionary = {}
var _landing_entities: Dictionary = {}
var _damage_entities: Dictionary = {}
var _moving_occupants: Dictionary = {}
var _last_result: Dictionary = {}
var _server_offer: Dictionary = {}
var _bound_port := 0
var _latest_snapshot_revision := 0


func _init() -> void:
	_lifecycle = LifecycleAdapter.new(AUTHORITY_PEER_ID)
	_transport = TransportSecurity.new(AUTHORITY_PEER_ID)
	_movement = MovementAuthority.new(AUTHORITY_PEER_ID)
	_boarding = BoardingAuthority.new(AUTHORITY_PEER_ID)
	_projectile = ProjectileAuthority.new(AUTHORITY_PEER_ID)
	_landing = LandingAuthority.new(AUTHORITY_PEER_ID)
	_damage_respawn = DamageRespawnIntegration.new(AUTHORITY_PEER_ID)
	_moving_interior = MovingInteriorAuthority.new(AUTHORITY_PEER_ID)
	_ship_ownership = ShipOwnershipAuthority.new(AUTHORITY_PEER_ID)
	_seat_authority = SeatAuthority.new(AUTHORITY_PEER_ID)
	_migration = SessionMigration.new(AUTHORITY_PEER_ID)
	_last_result = {"accepted": false, "status": &"uninitialized"}


func host(port: int = DEFAULT_PORT, max_clients: int = DEFAULT_MAX_CLIENTS) -> Dictionary:
	if _configured:
		return _remember(_result(false, &"already_started"))
	_peer = ENetMultiplayerPeer.new()
	var status := _peer.create_server(maxi(1, port), maxi(1, max_clients))
	if status != OK:
		_peer = null
		return _remember(_result(false, &"listen_failed", {"error": status}))
	_is_server = true
	_configure_multiplayer()
	session_started.emit(&"server")
	_bound_port = maxi(1, port)
	return _remember(_result(true, &"server_started", {"port": _bound_port}))


func join(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Dictionary:
	if _configured:
		return _remember(_result(false, &"already_started"))
	if address.strip_edges().is_empty():
		return _remember(_result(false, &"invalid_address"))
	_peer = ENetMultiplayerPeer.new()
	var status := _peer.create_client(address, maxi(1, port))
	if status != OK:
		_peer = null
		return _remember(_result(false, &"connect_failed", {"error": status}))
	_is_server = false
	_configure_multiplayer()
	session_started.emit(&"client")
	_bound_port = maxi(1, port)
	return _remember(_result(true, &"client_started", {"address": address, "port": _bound_port}))


func shutdown(reason: StringName = &"requested") -> Dictionary:
	if not _configured:
		return _remember(_result(false, &"not_started"))
	if _is_server:
		for peer_id_variant in _peer_generations.keys():
			var peer_id := int(peer_id_variant)
			var generation := int(_peer_generations.get(peer_id, 0))
			if generation > 0:
				_lifecycle.disconnect_peer(AUTHORITY_PEER_ID, peer_id, generation)
			_boarding.release_peer(AUTHORITY_PEER_ID, peer_id)
			for source_id_variant in _projectile_sources.keys():
				var source_id := StringName(source_id_variant)
				var source := _projectile_sources[source_id] as Dictionary
				if int(source.get("owner_peer_id", 0)) == peer_id:
					_projectile.retire_source(
						AUTHORITY_PEER_ID, source_id, int(source.get("source_generation", 0))
					)
					_projectile_sources.erase(source_id)
			for entity_id_variant in _landing_entities.keys():
				var entity_id := StringName(entity_id_variant)
				var entity := _landing_entities[entity_id] as Dictionary
				if int(entity.get("owner_peer_id", 0)) == peer_id:
					_landing.retire_entity(
						AUTHORITY_PEER_ID, entity_id, int(entity.get("entity_generation", 0))
					)
					_landing_entities.erase(entity_id)
			for damage_id_variant in _damage_entities.keys():
				var damage_id := StringName(damage_id_variant)
				var damage_entity := _damage_entities[damage_id] as Dictionary
				if int(damage_entity.get("owner_peer_id", 0)) == peer_id:
					_damage_respawn.retire_entity(
						AUTHORITY_PEER_ID, damage_id, int(damage_entity.get("entity_generation", 0))
					)
					_damage_entities.erase(damage_id)
			if _moving_occupants.has(peer_id):
				_moving_interior.release_peer(AUTHORITY_PEER_ID, peer_id)
				_moving_occupants.erase(peer_id)
			_ship_ownership.release_peer(AUTHORITY_PEER_ID, peer_id)
			_seat_authority.release_peer(AUTHORITY_PEER_ID, peer_id)
	if _peer != null:
		_peer.close()
		_peer = null
	if multiplayer != null:
		multiplayer.multiplayer_peer = null
	_configured = false
	_is_server = false
	_peer_generations.clear()
	_server_offer.clear()
	session_stopped.emit(reason)
	return _remember(_result(true, &"stopped", {"reason": reason}))


func is_server() -> bool:
	return _is_server and _configured


func get_local_port() -> int:
	return _bound_port


func get_server_offer() -> Dictionary:
	return _server_offer.duplicate(true)


func get_snapshot() -> Dictionary:
	return _lifecycle.get_snapshot()


func get_authoritative_snapshot() -> Dictionary:
	return _lifecycle.get_authoritative_snapshot()


func register_avatar(
	owner_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	mode: StringName = &"on_foot"
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_movement.register_avatar(
		AUTHORITY_PEER_ID, owner_peer_id, entity_id, entity_generation, mode
	))


func set_movement_server_tick(server_tick: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_movement.set_server_tick(AUTHORITY_PEER_ID, server_tick))


func send_movement_intent(wire: Dictionary) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	if not _configured:
		return _remember(_result(false, &"not_started"))
	_receive_movement_intent.rpc_id(AUTHORITY_PEER_ID, wire.duplicate(true))
	return _remember(_result(true, &"queued"))


func register_boarding_ship(
	ship_id: StringName,
	ship_generation: int,
	frame_id: StringName,
	frame_generation: int
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_boarding.register_ship(
		AUTHORITY_PEER_ID, ship_id, ship_generation, frame_id, frame_generation
	))


func register_boarding_seat(
	seat_id: StringName,
	ship_id: StringName,
	seat_generation: int,
	role: StringName
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_boarding.register_seat(
		AUTHORITY_PEER_ID, seat_id, ship_id, seat_generation, role
	))


func set_boarding_server_tick(server_tick: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_boarding.set_server_tick(AUTHORITY_PEER_ID, server_tick))


func send_boarding_intent(wire: Dictionary) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	if not _configured:
		return _remember(_result(false, &"not_started"))
	_receive_boarding_intent.rpc_id(AUTHORITY_PEER_ID, wire.duplicate(true))
	return _remember(_result(true, &"queued"))


func get_boarding_snapshot() -> Dictionary:
	return _boarding.get_snapshot()


func register_projectile_source(
	owner_peer_id: int,
	source_entity_id: StringName,
	source_generation: int,
	faction_id: StringName,
	weapon_profiles: Dictionary
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _projectile.register_source(
		AUTHORITY_PEER_ID, owner_peer_id, source_entity_id, source_generation,
		faction_id, weapon_profiles
	)
	if bool(result.get("accepted", false)):
		_projectile_sources[source_entity_id] = {
			"owner_peer_id": owner_peer_id,
			"source_generation": source_generation,
		}
	return _remember(result)


func set_projectile_server_tick(server_tick: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_projectile.set_server_tick(AUTHORITY_PEER_ID, server_tick))


func send_projectile_intent(wire: Dictionary) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	if not _configured:
		return _remember(_result(false, &"not_started"))
	_receive_projectile_intent.rpc_id(AUTHORITY_PEER_ID, wire.duplicate(true))
	return _remember(_result(true, &"queued"))


func get_projectile(projectile_id: StringName) -> Dictionary:
	return _projectile.get_projectile(projectile_id)


func register_landing_entity(
	owner_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	state: StringName = LandingAuthority.STATE_FLYING
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _landing.register_entity(
		AUTHORITY_PEER_ID, owner_peer_id, entity_id, entity_generation, state
	)
	if bool(result.get("accepted", false)):
		_landing_entities[entity_id] = {
			"owner_peer_id": owner_peer_id,
			"entity_generation": entity_generation,
		}
	return _remember(result)


func register_landing_target(
	target_id: StringName,
	region_id: StringName,
	target_generation: int = 1
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_landing.register_landing_target(
		AUTHORITY_PEER_ID, target_id, region_id, target_generation
	))


func set_landing_server_tick(server_tick: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_landing.set_server_tick(AUTHORITY_PEER_ID, server_tick))


func send_landing_intent(wire: Dictionary) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	if not _configured:
		return _remember(_result(false, &"not_started"))
	_receive_landing_intent.rpc_id(AUTHORITY_PEER_ID, wire.duplicate(true))
	return _remember(_result(true, &"queued"))


func get_landing_entity(entity_id: StringName) -> Dictionary:
	return _landing.get_entity_snapshot(entity_id)


func register_damage_entity(
	owner_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	component_generation: int,
	recovery_seconds: float = 2.0,
	invulnerability_seconds: float = 0.75
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(owner_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var result: Dictionary = _damage_respawn.register_entity(
		AUTHORITY_PEER_ID, owner_peer_id, entity_id, entity_generation,
		component_generation, recovery_seconds, invulnerability_seconds
	)
	if bool(result.get("accepted", false)):
		_damage_entities[entity_id] = {
			"owner_peer_id": owner_peer_id,
			"entity_generation": entity_generation,
		}
	return _remember(result)


func record_damage(
	entity_id: StringName,
	entity_generation: int,
	damage_event: Dictionary,
	component_receipt: Dictionary,
	destroyed: bool
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _damage_respawn.record_damage(
		AUTHORITY_PEER_ID, entity_id, entity_generation,
		damage_event, component_receipt, destroyed
	)
	damage_respawn_result.emit(result.duplicate(true))
	return _remember(result)


func tick_damage_recovery(entity_id: StringName, entity_generation: int, delta: float) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _damage_respawn.tick_recovery(
		AUTHORITY_PEER_ID, entity_id, entity_generation, delta
	)
	damage_respawn_result.emit(result.duplicate(true))
	return _remember(result)


func reserve_damage_respawn(
	entity_id: StringName,
	entity_generation: int,
	reservation: Dictionary
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _damage_respawn.reserve_respawn(
		AUTHORITY_PEER_ID, entity_id, entity_generation, reservation
	)
	damage_respawn_result.emit(result.duplicate(true))
	return _remember(result)


func commit_damage_respawn(
	entity_id: StringName,
	entity_generation: int,
	commit: Dictionary,
	component_reset: Dictionary
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _damage_respawn.commit_respawn(
		AUTHORITY_PEER_ID, entity_id, entity_generation, commit, component_reset
	)
	if bool(result.get("accepted", false)) and _damage_entities.has(entity_id):
		_damage_entities[entity_id]["entity_generation"] = int(result.get("entity_generation", entity_generation))
	damage_respawn_result.emit(result.duplicate(true))
	return _remember(result)


func get_damage_entity(entity_id: StringName) -> Dictionary:
	return _damage_respawn.get_entity_snapshot(entity_id)


func register_moving_interior_frame(frame_id: StringName, frame_generation: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _moving_interior.register_frame(
		AUTHORITY_PEER_ID, frame_id, frame_generation
	)
	moving_interior_result.emit(result.duplicate(true))
	return _remember(result)


func retire_moving_interior_frame(frame_id: StringName, frame_generation: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _moving_interior.retire_frame(
		AUTHORITY_PEER_ID, frame_id, frame_generation
	)
	if bool(result.get("accepted", false)):
		for peer_id_variant in _moving_occupants.keys():
			var peer_id := int(peer_id_variant)
			for released in result.get("released_occupancies", []) as Array:
				if int((released as Dictionary).get("peer_id", 0)) == peer_id:
					_moving_occupants.erase(peer_id)
					break
		moving_interior_result.emit(result.duplicate(true))
	return _remember(result)


func set_moving_interior_server_tick(server_tick: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _moving_interior.set_server_tick(AUTHORITY_PEER_ID, server_tick)
	moving_interior_result.emit(result.duplicate(true))
	return _remember(result)


func register_moving_interior_occupancy(
	owner_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	frame_id: StringName,
	frame_generation: int
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(owner_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var result: Dictionary = _moving_interior.register_occupancy(
		AUTHORITY_PEER_ID, owner_peer_id, entity_id, entity_generation,
		frame_id, frame_generation
	)
	if bool(result.get("accepted", false)):
		_moving_occupants[owner_peer_id] = true
	moving_interior_result.emit(result.duplicate(true))
	return _remember(result)


func handoff_moving_interior_sample(sample: Dictionary) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _moving_interior.handoff_latency_sample(
		AUTHORITY_PEER_ID, sample
	)
	moving_interior_result.emit(result.duplicate(true))
	return _remember(result)


func get_moving_interior_occupancy(entity_id: StringName) -> Dictionary:
	return _moving_interior.get_occupancy(entity_id)


func register_owned_ship(
	ship_id: StringName,
	ship_generation: int,
	owner_peer_id: int = 0
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if owner_peer_id > 0 and not _peer_generations.has(owner_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var result: Dictionary = _ship_ownership.register_ship(
		AUTHORITY_PEER_ID, ship_id, ship_generation, owner_peer_id
	)
	ship_ownership_result.emit(result.duplicate(true))
	return _remember(result)


func claim_ship_for_peer(
	claimant_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	request_sequence: int
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(claimant_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var result: Dictionary = _ship_ownership.claim(
		AUTHORITY_PEER_ID, claimant_peer_id, ship_id, ship_generation, request_sequence
	)
	ship_ownership_result.emit(result.duplicate(true))
	return _remember(result)


func transfer_owned_ship(
	from_peer_id: int,
	to_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	request_sequence: int
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(from_peer_id) or not _peer_generations.has(to_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var result: Dictionary = _ship_ownership.transfer(
		AUTHORITY_PEER_ID, from_peer_id, to_peer_id, ship_id, ship_generation, request_sequence
	)
	ship_ownership_result.emit(result.duplicate(true))
	return _remember(result)


func release_owned_ship(
	owner_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	request_sequence: int
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(owner_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var result: Dictionary = _ship_ownership.release(
		AUTHORITY_PEER_ID, owner_peer_id, ship_id, ship_generation, request_sequence
	)
	ship_ownership_result.emit(result.duplicate(true))
	return _remember(result)


func get_owned_ship(ship_id: StringName) -> Dictionary:
	return _ship_ownership.get_ship_snapshot(ship_id)


func register_crew_seat(
	seat_id: StringName,
	vessel_id: StringName,
	role: StringName,
	frame_id: StringName = &"",
	seat_generation: int = 1
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if _ship_ownership.get_ship_snapshot(vessel_id).is_empty():
		return _remember(_result(false, &"unknown_ship"))
	var result: Dictionary = _seat_authority.register_seat(
		seat_id, vessel_id, role, frame_id, seat_generation
	)
	seat_occupancy_result.emit(result.duplicate(true))
	return _remember(result)


func claim_crew_seat(
	occupant_peer_id: int,
	avatar_id: StringName,
	seat_id: StringName,
	requested_role: StringName,
	request_sequence: int
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(occupant_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var seat: Dictionary = _seat_authority.get_snapshot()
	var seat_record: Dictionary = {}
	for candidate in seat.get("seats", []) as Array:
		if StringName((candidate as Dictionary).get("seat_id", &"")) == seat_id:
			seat_record = candidate as Dictionary
			break
	if seat_record.is_empty():
		return _remember(_result(false, &"unknown_seat"))
	var ship: Dictionary = _ship_ownership.get_ship_snapshot(StringName(seat_record.get("vessel_id", &"")))
	if int(ship.get("owner_peer_id", 0)) != occupant_peer_id:
		return _remember(_result(false, &"ship_owner_mismatch"))
	var result: Dictionary = _seat_authority.claim(
		AUTHORITY_PEER_ID, occupant_peer_id, avatar_id, seat_id, requested_role, request_sequence
	)
	seat_occupancy_result.emit(result.duplicate(true))
	return _remember(result)


func release_crew_seat(
	occupant_peer_id: int,
	avatar_id: StringName,
	seat_id: StringName,
	request_sequence: int,
	seat_generation: int = 0
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(occupant_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var result: Dictionary = _seat_authority.release(
		AUTHORITY_PEER_ID, occupant_peer_id, avatar_id, seat_id, request_sequence, seat_generation
	)
	seat_occupancy_result.emit(result.duplicate(true))
	return _remember(result)


func transfer_crew_seat(
	from_peer_id: int,
	to_peer_id: int,
	avatar_id: StringName,
	seat_id: StringName,
	request_sequence: int,
	seat_generation: int = 0
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(from_peer_id) or not _peer_generations.has(to_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var result: Dictionary = _seat_authority.transfer(
		AUTHORITY_PEER_ID, from_peer_id, to_peer_id, avatar_id, seat_id, request_sequence, seat_generation
	)
	seat_occupancy_result.emit(result.duplicate(true))
	return _remember(result)


func get_crew_assignment(occupant_peer_id: int, avatar_id: StringName) -> Dictionary:
	return _seat_authority.get_assignment(occupant_peer_id, avatar_id)


func rotate_session_migration(next_package_generation: int = -1) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _migration.rotate_server(AUTHORITY_PEER_ID, next_package_generation)
	migration_result.emit(result.duplicate(true))
	return _remember(result)


func accept_migration_packet(source_peer_id: int, packet: Dictionary) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _migration.accept_packet(source_peer_id, packet)
	migration_result.emit(result.duplicate(true))
	return _remember(result)


func rebind_migration_peer(source_peer_id: int, packet: Dictionary) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _migration.rebind_peer(source_peer_id, packet)
	migration_result.emit(result.duplicate(true))
	return _remember(result)


func bind_migration_attachment(
	peer_id: int,
	peer_generation: int,
	seat_id: StringName,
	seat_generation: int,
	ship_id: StringName,
	ship_generation: int,
	interest_center: Vector3,
	interest_radius: float,
	interest_max_entities: int = 512
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _migration.bind_attachment(
		AUTHORITY_PEER_ID, peer_id, peer_generation, seat_id, seat_generation,
		ship_id, ship_generation, interest_center, interest_radius, interest_max_entities
	)
	migration_result.emit(result.duplicate(true))
	return _remember(result)


func get_migration_snapshot() -> Dictionary:
	var snapshot: Dictionary = _migration.get_snapshot()
	snapshot["latest_snapshot_revision"] = _latest_snapshot_revision
	return snapshot.duplicate(true)


func publish_snapshot(
	server_tick: int,
	movement: Array,
	projectiles: Array,
	respawn: Array
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var published: Dictionary = _lifecycle.publish_authority_snapshot(
		AUTHORITY_PEER_ID, server_tick, movement, projectiles, respawn
	)
	if not bool(published.get("accepted", false)):
		return _remember(published)
	var packet := (published.get("snapshot", {}) as Dictionary).duplicate(true)
	_latest_snapshot_revision = int(packet.get("revision", 0))
	_broadcast_snapshot.rpc(packet)
	snapshot_published.emit(packet.duplicate(true))
	return _remember(_result(true, &"snapshot_published", {
		"revision": int(packet.get("revision", 0)),
		"packet": packet,
	}))


@rpc("any_peer", "reliable")
func _receive_movement_intent(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var result: Dictionary = _movement.accept_intent(source_peer_id, wire)
	movement_intent_result.emit(result.duplicate(true))


@rpc("any_peer", "reliable")
func _receive_boarding_intent(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var result: Dictionary = _boarding.accept_intent(source_peer_id, wire)
	boarding_intent_result.emit(result.duplicate(true))


@rpc("any_peer", "reliable")
func _receive_projectile_intent(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var result: Dictionary = _projectile.accept_fire(source_peer_id, wire)
	projectile_intent_result.emit(result.duplicate(true))


@rpc("any_peer", "reliable")
func _receive_landing_intent(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var result: Dictionary = _landing.accept_intent(source_peer_id, wire)
	landing_intent_result.emit(result.duplicate(true))


@rpc("any_peer", "reliable")
func _receive_hello(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var admitted: Dictionary = _lifecycle.admit_peer(source_peer_id, wire)
	if not bool(admitted.get("accepted", false)):
		transport_rejected.emit(StringName(admitted.get("status", &"admission_rejected")))
		return
	var peer: Dictionary = admitted.get("peer", {}) as Dictionary
	var peer_id := int(peer.get("peer_id", 0))
	var peer_generation := int(peer.get("peer_generation", 0))
	var registered: Dictionary = _transport.register_peer(
		AUTHORITY_PEER_ID, peer_id, peer_generation
	)
	if not bool(registered.get("accepted", false)):
		_lifecycle.disconnect_peer(AUTHORITY_PEER_ID, peer_id, peer_generation)
		transport_rejected.emit(StringName(registered.get("status", &"transport_rejected")))
		return
	_peer_generations[peer_id] = peer_generation
	var migration_registered: Dictionary = _migration.register_peer(
		AUTHORITY_PEER_ID, peer_id, peer_generation
	)
	if not bool(migration_registered.get("accepted", false)):
		_lifecycle.disconnect_peer(AUTHORITY_PEER_ID, peer_id, peer_generation)
		_peer_generations.erase(peer_id)
		transport_rejected.emit(StringName(migration_registered.get("status", &"migration_rejected")))
		return
	var offer := {
		"admission": admitted,
		"transport": {
			"peer_id": peer_id,
			"peer_generation": peer_generation,
			"auth_token": registered.get("auth_token", ""),
		},
	}
	_send_server_offer.rpc_id(source_peer_id, offer)
	peer_admitted.emit(peer_id, offer.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func _send_server_offer(offer: Dictionary) -> void:
	if is_server():
		return
	_server_offer = offer.duplicate(true)
	peer_admitted.emit(
		int((offer.get("admission", {}) as Dictionary).get("peer", {}).get("peer_id", 0)),
		offer.duplicate(true)
	)


@rpc("authority", "call_remote", "reliable")
func _broadcast_snapshot(packet: Dictionary) -> void:
	if is_server():
		return
	var applied: Dictionary = _lifecycle.apply_replica_snapshot(AUTHORITY_PEER_ID, packet)
	snapshot_applied.emit(applied.duplicate(true))
	_last_result = applied.duplicate(true)


func _configure_multiplayer() -> void:
	if _configured:
		return
	_configured = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.multiplayer_peer = _peer


func _on_peer_connected(peer_id: int) -> void:
	if is_server() or peer_id != AUTHORITY_PEER_ID:
		return
	var hello := LifecycleAdapter.create_hello(
		multiplayer.get_unique_id(), 1, 1, 1, 1
	)
	_receive_hello.rpc_id(AUTHORITY_PEER_ID, hello)


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_server():
		return
	var peer_generation := int(_peer_generations.get(peer_id, 0))
	if peer_generation <= 0:
		return
	var receipt: Dictionary = _lifecycle.disconnect_peer(
		AUTHORITY_PEER_ID, peer_id, peer_generation
	)
	_boarding.release_peer(AUTHORITY_PEER_ID, peer_id)
	_seat_authority.release_peer(AUTHORITY_PEER_ID, peer_id)
	_peer_generations.erase(peer_id)
	for source_id_variant in _projectile_sources.keys():
		var source_id := StringName(source_id_variant)
		var source := _projectile_sources[source_id] as Dictionary
		if int(source.get("owner_peer_id", 0)) == peer_id:
			_projectile.retire_source(
				AUTHORITY_PEER_ID, source_id, int(source.get("source_generation", 0))
			)
			_projectile_sources.erase(source_id)
	for entity_id_variant in _landing_entities.keys():
		var entity_id := StringName(entity_id_variant)
		var entity := _landing_entities[entity_id] as Dictionary
		if int(entity.get("owner_peer_id", 0)) == peer_id:
			_landing.retire_entity(
				AUTHORITY_PEER_ID, entity_id, int(entity.get("entity_generation", 0))
			)
			_landing_entities.erase(entity_id)
	for damage_id_variant in _damage_entities.keys():
		var damage_id := StringName(damage_id_variant)
		var damage_entity := _damage_entities[damage_id] as Dictionary
		if int(damage_entity.get("owner_peer_id", 0)) == peer_id:
			_damage_respawn.retire_entity(
				AUTHORITY_PEER_ID, damage_id, int(damage_entity.get("entity_generation", 0))
			)
			_damage_entities.erase(damage_id)
	if _moving_occupants.has(peer_id):
		_moving_interior.release_peer(AUTHORITY_PEER_ID, peer_id)
		_moving_occupants.erase(peer_id)
	peer_disconnected.emit(peer_id, receipt.duplicate(true))


func _on_server_disconnected() -> void:
	if not is_server():
		shutdown(&"server_disconnected")




func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	for key in payload:
		result[key] = payload[key]
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
