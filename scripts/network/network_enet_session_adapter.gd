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
const PredictionGuard := preload("res://scripts/network/network_prediction_correction_guard.gd")
const ServerBrowser := preload("res://scripts/network/network_server_browser.gd")
const SnapshotJitterBuffer := preload("res://scripts/network/network_snapshot_jitter_buffer.gd")
const ReplicationInterest := preload("res://scripts/network/network_replication_interest.gd")
const SnapshotDeltaCodec := preload("res://scripts/network/network_snapshot_delta_codec.gd")
const SnapshotFragmenter := preload("res://scripts/network/network_snapshot_fragmenter.gd")
const MovingInteriorRelationship := preload("res://scripts/network/moving_interior_relationship.gd")

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
signal prediction_correction_result(result: Dictionary)
signal server_browser_result(result: Dictionary)

const DEFAULT_PORT := 27101
const DEFAULT_MAX_CLIENTS := 8
const AUTHORITY_PEER_ID := 1
const MAX_SECURE_PACKETS_PER_WINDOW := 32
const SECURE_WINDOW_MILLISECONDS := 1000

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
var _prediction
var _server_browser
var _snapshot_jitter
var _replication_interest
var _snapshot_delta_encoder
var _snapshot_delta_decoder
var _snapshot_fragmenter
var _moving_replica_samples: Dictionary = {}
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
var _prediction_entities: Dictionary = {}
var _next_peer_generation := 1
var _replication_budget_counters: Dictionary = {}
var _secure_sequences: Dictionary = {}
var _security_strikes: Dictionary = {}
var _secure_window_started := 0
var _secure_window_counts: Dictionary = {}


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
	_prediction = PredictionGuard.new(AUTHORITY_PEER_ID)
	_server_browser = ServerBrowser.new(AUTHORITY_PEER_ID)
	_snapshot_jitter = SnapshotJitterBuffer.new()
	_replication_interest = ReplicationInterest.new(AUTHORITY_PEER_ID)
	_snapshot_delta_encoder = SnapshotDeltaCodec.new()
	_snapshot_delta_decoder = SnapshotDeltaCodec.new()
	_snapshot_fragmenter = SnapshotFragmenter.new()
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
			_migration.disconnect_peer(AUTHORITY_PEER_ID, peer_id, int(_peer_generations.get(peer_id, 0)))
			_security_strikes.erase(peer_id)
			_secure_window_counts.erase(peer_id)
			for prediction_id_variant in _prediction_entities.keys():
				var prediction_id := StringName(prediction_id_variant)
				var prediction_entity := _prediction_entities[prediction_id] as Dictionary
				if int(prediction_entity.get("owner_peer_id", 0)) == peer_id:
					_prediction.retire_entity(
						AUTHORITY_PEER_ID, prediction_id, int(prediction_entity.get("entity_generation", 0))
					)
					_prediction_entities.erase(prediction_id)
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
	_receive_movement_intent.rpc_id(AUTHORITY_PEER_ID, _make_secure_rpc_packet(&"movement", wire))
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
	_receive_boarding_intent.rpc_id(AUTHORITY_PEER_ID, _make_secure_rpc_packet(&"boarding", wire))
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
	_receive_projectile_intent.rpc_id(AUTHORITY_PEER_ID, _make_secure_rpc_packet(&"projectile", wire))
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
	_receive_landing_intent.rpc_id(AUTHORITY_PEER_ID, _make_secure_rpc_packet(&"landing", wire))
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


func register_prediction_entity(
	owner_peer_id: int,
	entity_id: StringName,
	entity_generation: int
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(owner_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var result: Dictionary = _prediction.register_entity(
		AUTHORITY_PEER_ID, entity_id, entity_generation, owner_peer_id
	)
	if bool(result.get("accepted", false)):
		_prediction_entities[entity_id] = {
			"owner_peer_id": owner_peer_id,
			"entity_generation": entity_generation,
		}
	prediction_correction_result.emit(result.duplicate(true))
	return _remember(result)


func publish_prediction_snapshot(
	entity_id: StringName,
	entity_generation: int,
	server_tick: int,
	event_sequence: int,
	position: Vector3,
	velocity: Vector3
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _prediction_entities.has(entity_id):
		return _remember(_result(false, &"unknown_entity"))
	var entity: Dictionary = _prediction_entities[entity_id]
	var owner_peer_id := int(entity.get("owner_peer_id", 0))
	var snapshot := PredictionGuard.create_snapshot(
		AUTHORITY_PEER_ID, entity_id, entity_generation, owner_peer_id,
		server_tick, event_sequence, position, velocity
	)
	var packet := {
		"snapshot": snapshot,
		"migration_generation": int(_migration.get_snapshot().get("migration_generation", 0)),
	}.duplicate(true)
	_broadcast_prediction_correction.rpc(packet)
	prediction_correction_result.emit({"accepted": true, "status": &"snapshot_published", "packet": packet}.duplicate(true))
	return _remember({"accepted": true, "status": &"snapshot_published", "packet": packet})


func apply_prediction_correction(
	client_tick: int,
	predicted_state: Dictionary,
	packet: Dictionary
) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	if not packet.has("snapshot") or not packet.has("migration_generation"):
		return _remember(_result(false, &"invalid_prediction_packet"))
	if int(packet.get("migration_generation", -1)) != int(_migration.get_snapshot().get("migration_generation", 0)):
		return _remember(_result(false, &"stale_migration_generation"))
	var snapshot: Dictionary = packet.get("snapshot", {}) as Dictionary
	var entity_id := StringName(snapshot.get("entity_id", &""))
	var entity_generation := int(snapshot.get("entity_generation", 0))
	var owner_peer_id := int(snapshot.get("owner_peer_id", 0))
	if owner_peer_id != multiplayer.get_unique_id():
		return _remember(_result(false, &"owner_mismatch"))
	if _prediction.get_entity_snapshot(entity_id).is_empty():
		_prediction.register_entity(AUTHORITY_PEER_ID, entity_id, entity_generation, owner_peer_id)
	var result: Dictionary = _prediction.accept_snapshot(
		AUTHORITY_PEER_ID, owner_peer_id, client_tick, predicted_state, snapshot
	)
	prediction_correction_result.emit(result.duplicate(true))
	return _remember(result)


func get_prediction_entity(entity_id: StringName) -> Dictionary:
	return _prediction.get_entity_snapshot(entity_id)


func reset_snapshot_jitter(migration_generation: int = 1) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	_snapshot_delta_decoder.reset()
	_snapshot_fragmenter.reset()
	_moving_replica_samples.clear()
	return _remember(_snapshot_jitter.reset(migration_generation))


## Presents a released authoritative moving-interior relationship without
## mutating authority or scene state. Packets are ordered by the shared jitter
## buffer before the relationship is interpolated in frame-local coordinates.
func consume_moving_interior_snapshot(
	packet: Dictionary,
	frame_world_transform: Transform3D = Transform3D.IDENTITY,
	alpha: float = 1.0
) -> Dictionary:
	if not packet.has("revision") or not packet.has("server_tick") \
			or not packet.has("relationship"):
		return _remember(_result(false, &"invalid_moving_interior_snapshot"))
	if not is_finite(alpha):
		return _remember(_result(false, &"invalid_interpolation_alpha"))
	var buffered: Dictionary = _snapshot_jitter.push(packet)
	if not bool(buffered.get("accepted", false)):
		return _remember(_result(false, StringName(buffered.get("status", &"buffer_rejected"))))
	var presented: Array = []
	while true:
		var ready: Dictionary = _snapshot_jitter.pop_ready()
		if ready.is_empty():
			break
		var raw_relationship: Variant = ready.get("relationship")
		if not raw_relationship is Dictionary:
			return _remember(_result(false, &"invalid_moving_interior_relationship"))
		var relationship := MovingInteriorRelationship.from_dictionary(raw_relationship as Dictionary)
		if not relationship.is_valid():
			return _remember(_result(false, &"invalid_moving_interior_relationship"))
		var entity_id := relationship.get_entity_id()
		var prior: Dictionary = _moving_replica_samples.get(entity_id, {})
		var local_transform := relationship.get_frame_local_transform()
		if not prior.is_empty():
			var prior_transform: Transform3D = prior.get("local_transform", Transform3D.IDENTITY)
			local_transform = prior_transform.interpolate_with(local_transform, clampf(alpha, 0.0, 1.0))
		_moving_replica_samples[entity_id] = {
			"server_tick": relationship.get_server_tick(),
			"local_transform": relationship.get_frame_local_transform(),
		}
		presented.append({
			"revision": int(ready.get("revision", 0)),
			"server_tick": relationship.get_server_tick(),
			"entity_id": entity_id,
			"parent_frame_id": relationship.get_parent_frame_id(),
			"parent_frame_generation": relationship.get_parent_frame_generation(),
			"world_transform": frame_world_transform * local_transform,
		})
	return _remember(_result(true, &"moving_interior_presented", {
		"samples": presented,
		"buffered_revision": int(buffered.get("revision", 0)),
	}))


func get_snapshot_jitter_state() -> Dictionary:
	return _snapshot_jitter.get_snapshot()


func register_replication_entity(
	entity_id: StringName,
	entity_generation: int,
	owner_peer_id: int,
	position: Vector3,
	replication_radius: float = 1000.0
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_replication_interest.register_entity(
		AUTHORITY_PEER_ID, entity_id, entity_generation, owner_peer_id, position, replication_radius
	))


func register_replication_peer(peer_id: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_replication_interest.register_peer(AUTHORITY_PEER_ID, peer_id))


func publish_replication_state(
	entity_id: StringName,
	entity_generation: int,
	server_tick: int,
	position: Vector3,
	state: Dictionary
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_replication_interest.publish_state(
		AUTHORITY_PEER_ID, entity_id, entity_generation, server_tick, position, state
	))


func set_replication_interest(
	peer_id: int,
	center: Vector3,
	radius: float,
	max_entities: int = ReplicationInterest.MAX_ENTITIES
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_replication_interest.set_peer_interest(
		AUTHORITY_PEER_ID, peer_id, center, radius, max_entities
	))


func replicate_interest_for_peer(peer_id: int, server_tick: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_replication_interest.replicate(AUTHORITY_PEER_ID, peer_id, server_tick))


func replicate_interest_with_budget(peer_id: int, server_tick: int, max_bytes: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if max_bytes <= 0:
		return _remember(_result(false, &"invalid_replication_budget"))
	var batch: Dictionary = _replication_interest.replicate(AUTHORITY_PEER_ID, peer_id, server_tick)
	if not bool(batch.get("accepted", false)):
		return _remember(batch)
	var selected: Array = []
	var deferred: Array = []
	var used_bytes := 0
	var entities: Array = batch.get("entities", []) as Array
	entities.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_owned := int(left.get("owner_peer_id", 0)) == peer_id
		var right_owned := int(right.get("owner_peer_id", 0)) == peer_id
		if left_owned != right_owned:
			return left_owned
		return int(left.get("state_revision", 0)) < int(right.get("state_revision", 0))
	)
	for entity_variant in entities:
		var entity: Dictionary = entity_variant as Dictionary
		var entity_bytes := JSON.stringify(entity).to_utf8_buffer().size()
		if used_bytes + entity_bytes > max_bytes:
			deferred.append(entity.get("entity_id", &""))
			continue
		selected.append(entity)
		used_bytes += entity_bytes
	_replication_budget_counters[peer_id] = {
		"last_server_tick": server_tick,
		"max_bytes": max_bytes,
		"used_bytes": used_bytes,
		"sent_entities": selected.size(),
		"deferred_entities": deferred.size(),
	}
	return _remember({
		"accepted": true,
		"status": &"replicated" if not selected.is_empty() else &"budget_deferred",
		"peer_id": peer_id,
		"server_tick": server_tick,
		"entities": selected,
		"deferred_entity_ids": deferred,
		"used_bytes": used_bytes,
		"max_bytes": max_bytes,
	})


func get_replication_budget_counters(peer_id: int = 0) -> Dictionary:
	if peer_id > 0:
		return (_replication_budget_counters.get(peer_id, {}) as Dictionary).duplicate(true)
	return _replication_budget_counters.duplicate(true)


func publish_server_directory(directory_generation: int, server_tick: int, entries: Array) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _server_browser.publish_snapshot(
		AUTHORITY_PEER_ID, directory_generation, server_tick, entries
	)
	server_browser_result.emit(result.duplicate(true))
	return _remember(result)


func advance_server_directory_clock(server_tick: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _server_browser.advance_clock(AUTHORITY_PEER_ID, server_tick)
	server_browser_result.emit(result.duplicate(true))
	return _remember(result)


func query_server_directory(region_filter: StringName = &"", max_ping_ms: int = -1, include_full: bool = true) -> Array:
	return _server_browser.query(region_filter, max_ping_ms, include_full)


func request_join_advertised_session(
	session_id: StringName,
	address: String = "127.0.0.1",
	port: int = DEFAULT_PORT
) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	var entry: Dictionary = _server_browser.get_session(session_id)
	if entry.is_empty():
		return _remember(_result(false, &"session_not_found"))
	if int(entry.get("player_count", 0)) >= int(entry.get("max_players", 0)):
		return _remember(_result(false, &"session_full"))
	var started: Dictionary = join(address, port)
	started["session_id"] = session_id
	return _remember(started)


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
	var encoded_snapshot: Dictionary = _snapshot_delta_encoder.encode(packet)
	for fragment in _snapshot_fragmenter.fragment(encoded_snapshot, 1, int(packet.get("revision", 0))):
		_broadcast_snapshot_fragment.rpc(fragment)
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
	var payload := _accept_secure_rpc(source_peer_id, wire, &"movement")
	if payload.is_empty():
		return
	var result: Dictionary = _movement.accept_intent(source_peer_id, payload)
	movement_intent_result.emit(result.duplicate(true))


@rpc("any_peer", "reliable")
func _receive_boarding_intent(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var payload := _accept_secure_rpc(source_peer_id, wire, &"boarding")
	if payload.is_empty():
		return
	var result: Dictionary = _boarding.accept_intent(source_peer_id, payload)
	boarding_intent_result.emit(result.duplicate(true))


@rpc("any_peer", "reliable")
func _receive_projectile_intent(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var payload := _accept_secure_rpc(source_peer_id, wire, &"projectile")
	if payload.is_empty():
		return
	var result: Dictionary = _projectile.accept_fire(source_peer_id, payload)
	projectile_intent_result.emit(result.duplicate(true))


@rpc("any_peer", "reliable")
func _receive_landing_intent(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var payload := _accept_secure_rpc(source_peer_id, wire, &"landing")
	if payload.is_empty():
		return
	var result: Dictionary = _landing.accept_intent(source_peer_id, payload)
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
	if not bool(migration_registered.get("accepted", false)) \
		and migration_registered.get("status") == &"peer_already_registered":
		migration_registered = _migration.rebind_peer(
			peer_id, _migration.make_packet(peer_id, peer_generation, 0, &"rebind")
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
	var peer: Dictionary = offer.get("transport", {}) as Dictionary
	_transport.register_peer(
		AUTHORITY_PEER_ID, int(peer.get("peer_id", 0)), int((offer.get("admission", {}) as Dictionary).get("peer", {}).get("peer_generation", 0))
	)
	peer_admitted.emit(
		int((offer.get("admission", {}) as Dictionary).get("peer", {}).get("peer_id", 0)),
		offer.duplicate(true)
	)


@rpc("authority", "call_remote", "reliable")
func _broadcast_snapshot_fragment(fragment: Dictionary) -> void:
	if is_server():
		return
	var reassembled: Dictionary = _snapshot_fragmenter.accept(fragment, Time.get_ticks_msec())
	if not bool(reassembled.get("accepted", false)) or reassembled.get("status") != &"reassembled":
		return
	var packet: Dictionary = reassembled.get("packet", {}) as Dictionary
	var decoded: Dictionary = _snapshot_delta_decoder.decode(packet)
	if not bool(decoded.get("accepted", false)):
		_last_result = decoded.duplicate(true)
		return
	var buffered: Dictionary = _snapshot_jitter.push(decoded.get("packet", {}) as Dictionary)
	if not bool(buffered.get("accepted", false)):
		_last_result = buffered.duplicate(true)
		return
	while true:
		var ready: Dictionary = _snapshot_jitter.pop_ready()
		if ready.is_empty():
			break
		var applied: Dictionary = _lifecycle.apply_replica_snapshot(AUTHORITY_PEER_ID, ready)
		snapshot_applied.emit(applied.duplicate(true))
		_last_result = applied.duplicate(true)


@rpc("authority", "call_remote", "reliable")
func _broadcast_prediction_correction(packet: Dictionary) -> void:
	if is_server():
		return
	# The replica applies the packet explicitly through apply_prediction_correction.
	# Transport delivery alone never mutates prediction or gameplay state.


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
		multiplayer.get_unique_id(), _next_peer_generation, 1, 1, 1
	)
	_next_peer_generation += 1
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
	_migration.disconnect_peer(AUTHORITY_PEER_ID, peer_id, peer_generation)
	_security_strikes.erase(peer_id)
	_secure_window_counts.erase(peer_id)
	_boarding.release_peer(AUTHORITY_PEER_ID, peer_id)
	_seat_authority.release_peer(AUTHORITY_PEER_ID, peer_id)
	for prediction_id_variant in _prediction_entities.keys():
		var prediction_id := StringName(prediction_id_variant)
		var prediction_entity := _prediction_entities[prediction_id] as Dictionary
		if int(prediction_entity.get("owner_peer_id", 0)) == peer_id:
			_prediction.retire_entity(
				AUTHORITY_PEER_ID, prediction_id, int(prediction_entity.get("entity_generation", 0))
			)
			_prediction_entities.erase(prediction_id)
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


func _make_secure_rpc_packet(stream_id: StringName, payload: Dictionary) -> Dictionary:
	var sequence := int(_secure_sequences.get(stream_id, -1)) + 1
	_secure_sequences[stream_id] = sequence
	return _transport.make_packet(
		multiplayer.get_unique_id(), _next_peer_generation - 1, stream_id, sequence, payload
	)


func _accept_secure_rpc(source_peer_id: int, packet: Dictionary, stream_id: StringName) -> Dictionary:
	var now := Time.get_ticks_msec()
	if now - _secure_window_started >= SECURE_WINDOW_MILLISECONDS:
		_secure_window_started = now
		_secure_window_counts.clear()
	var count := int(_secure_window_counts.get(source_peer_id, 0))
	if count >= MAX_SECURE_PACKETS_PER_WINDOW:
		_security_strikes[source_peer_id] = int(_security_strikes.get(source_peer_id, 0)) + 1
		return {}
	_secure_window_counts[source_peer_id] = count + 1
	var checked: Dictionary = _transport.accept_packet(source_peer_id, packet)
	if not bool(checked.get("accepted", false)):
		_security_strikes[source_peer_id] = int(_security_strikes.get(source_peer_id, 0)) + 1
		return {}
	if StringName(checked.get("stream_id", &"")) != stream_id:
		_security_strikes[source_peer_id] = int(_security_strikes.get(source_peer_id, 0)) + 1
		return {}
	return checked.get("payload", {}) as Dictionary




func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	for key in payload:
		result[key] = payload[key]
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
