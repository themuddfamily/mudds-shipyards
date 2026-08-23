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
const CrewRoleAuthority := preload("res://scripts/network/network_crew_role_authority.gd")
const CrewCommandAuthority := preload("res://scripts/network/network_crew_command_authority.gd")
const SessionMigration := preload("res://scripts/network/network_session_migration.gd")
const PredictionGuard := preload("res://scripts/network/network_prediction_correction_guard.gd")
const ServerBrowser := preload("res://scripts/network/network_server_browser.gd")
const SnapshotJitterBuffer := preload("res://scripts/network/network_snapshot_jitter_buffer.gd")
const ReplicationInterest := preload("res://scripts/network/network_replication_interest.gd")
const SnapshotDeltaCodec := preload("res://scripts/network/network_snapshot_delta_codec.gd")
const SnapshotFragmenter := preload("res://scripts/network/network_snapshot_fragmenter.gd")
const CrewSnapshotCodec := preload("res://scripts/network/network_crew_snapshot_codec.gd")
const MovingInteriorRelationship := preload("res://scripts/network/moving_interior_relationship.gd")
const MovingInteriorRelationshipStream := preload("res://scripts/network/moving_interior_relationship_stream.gd")
const MovingInteriorReplica := preload("res://scripts/network/network_moving_interior_replica.gd")
const MovingInteriorReplicaBinding := preload("res://scripts/network/network_moving_interior_replica_binding.gd")
const RemoteShipCommandSource := preload("res://scripts/network/network_remote_ship_command_source.gd")

signal session_started(mode: StringName)
signal session_stopped(reason: StringName)
signal peer_admitted(peer_id: int, receipt: Dictionary)
signal peer_disconnected(peer_id: int, receipt: Dictionary)
signal peer_keepalive_timeout(peer_id: int, receipt: Dictionary)
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
signal crew_role_result(result: Dictionary)
signal crew_command_result(result: Dictionary)
signal crew_snapshot_published(snapshot: Dictionary)
signal crew_snapshot_applied(result: Dictionary)
signal migration_result(result: Dictionary)
signal prediction_correction_result(result: Dictionary)
signal server_browser_result(result: Dictionary)

const DEFAULT_PORT := 27101
const DEFAULT_MAX_CLIENTS := 8
const AUTHORITY_PEER_ID := 1
const NETWORK_PROTOCOL_VERSION := 1
const NETWORK_BUILD_VERSION := 1
const MAX_SECURE_PACKETS_PER_WINDOW := 32
const SECURE_WINDOW_MILLISECONDS := 1000
const RECONNECT_BACKOFF_BASE_MILLISECONDS := 250
const RECONNECT_BACKOFF_MAX_MILLISECONDS := 5000
const RECONNECT_BACKOFF_MAX_ATTEMPTS := 6
const HANDSHAKE_DEFAULT_TIMEOUT_MILLISECONDS := 5000
const HANDSHAKE_MAX_TIMEOUT_MILLISECONDS := 30000
const KEEPALIVE_DEFAULT_TIMEOUT_MILLISECONDS := 10000
const KEEPALIVE_MAX_TIMEOUT_MILLISECONDS := 60000
const MAX_PRESENTATION_ENTITIES := 256
const MAX_MOVING_INTERIOR_PACKET_BYTES := 12000
const MAX_PROJECTILE_REPLICATION_PACKET_BYTES := 6000
const PROJECTILE_BUDGET_WINDOW_TICKS := 10
const PROJECTILE_MAX_SNAPSHOTS_PER_WINDOW := 16
const PROJECTILE_MAX_BYTES_PER_WINDOW := 24000
const MOVING_INTERIOR_BUDGET_WINDOW_TICKS := 10
const MOVING_INTERIOR_MAX_SNAPSHOTS_PER_WINDOW := 8
const MOVING_INTERIOR_MAX_BYTES_PER_WINDOW := 24000

var _peer: ENetMultiplayerPeer
var _lifecycle
var _transport
var _movement
var _remote_ship_commands
var _remote_pilot_replica: Dictionary = {}
var _boarding
var _projectile
var _landing
var _damage_respawn
var _moving_interior
var _ship_ownership
var _seat_authority
var _crew_roles
var _crew_commands
var _migration
var _prediction
var _server_browser
var _snapshot_jitter
var _replication_interest
var _snapshot_delta_encoder
var _snapshot_delta_decoder
var _snapshot_fragmenter
var _crew_snapshot_codec
var _crew_snapshot_fragmenter
var _crew_snapshot_revision := 0
var _crew_replica_snapshot: Dictionary = {}
var _moving_replica_samples: Dictionary = {}
var _moving_relationship_stream
var _moving_replica
var _moving_replica_binding
var _moving_replica_binding_ids: Dictionary = {}
var _moving_snapshot_revision := 0
var _moving_resync_revision := 0
var _moving_recipient_budgets: Dictionary = {}
var _moving_recipient_entities: Dictionary = {}
var _moving_recipient_pending: Dictionary = {}
var _projectile_jitter
var _projectile_replica_samples: Dictionary = {}
var _projectile_snapshot_revision := 0
var _projectile_recipient_budgets: Dictionary = {}
var _projectile_recipient_pending: Dictionary = {}
var _projectile_published_generations: Dictionary = {}
var _projectile_replica_generations: Dictionary = {}
var _projectile_replica_ticks: Dictionary = {}
var _projectile_replica_revision := 0
var _projectile_replica_migration_generation := 1
var _landing_jitter
var _landing_replica_samples: Dictionary = {}
var _landing_snapshot_revision := 0
var _damage_jitter
var _damage_replica_samples: Dictionary = {}
var _damage_snapshot_revision := 0
var _boarding_jitter
var _boarding_replica_samples: Dictionary = {}
var _boarding_snapshot_revision := 0
var _migration_jitter
var _migration_replica_generation := 0
var _migration_replica_samples: Dictionary = {}
var _interest_jitter
var _interest_replica_samples: Dictionary = {}
var _interest_retired_revisions: Dictionary = {}
var _presentation_evictions := 0
var _is_server := false
var _configured := false
var _peer_generations: Dictionary = {}
var _peer_keepalive_deadlines: Dictionary = {}
var _keepalive_timeout_milliseconds := KEEPALIVE_DEFAULT_TIMEOUT_MILLISECONDS
var _projectile_sources: Dictionary = {}
var _landing_entities: Dictionary = {}
var _damage_entities: Dictionary = {}
var _moving_occupants: Dictionary = {}
var _seat_moving_relationships: Dictionary = {}
var _last_result: Dictionary = {}
var _server_offer: Dictionary = {}
var _bound_port := 0
var _session_max_clients := DEFAULT_MAX_CLIENTS
var _hosted_directory_entries: Array = []
var _hosted_directory_generation := 0
var _hosted_directory_tick := 0
var _latest_snapshot_revision := 0
var _prediction_entities: Dictionary = {}
var _next_peer_generation := 1
var _replication_budget_counters: Dictionary = {}
var _secure_sequences: Dictionary = {}
var _security_strikes: Dictionary = {}
var _secure_window_started := 0
var _secure_window_counts: Dictionary = {}
var _reconnect_attempts := 0
var _reconnect_next_allowed_milliseconds := 0
var _session_end_reason: Dictionary = {
	"reason": &"unknown",
	"peer_generation": 0,
	"migration_generation": 0,
	"sequence": 0,
}
var _handshake_deadline: Dictionary = {
	"active": false,
	"deadline_milliseconds": 0,
	"peer_generation": 0,
	"migration_generation": 0,
	"timeout_milliseconds": HANDSHAKE_DEFAULT_TIMEOUT_MILLISECONDS,
}
var _next_join_intent_sequence := 1
var _last_join_intent_sequence := 0


func _init() -> void:
	_lifecycle = LifecycleAdapter.new(AUTHORITY_PEER_ID)
	_transport = TransportSecurity.new(AUTHORITY_PEER_ID)
	_movement = MovementAuthority.new(AUTHORITY_PEER_ID)
	_remote_ship_commands = RemoteShipCommandSource.new()
	_boarding = BoardingAuthority.new(AUTHORITY_PEER_ID)
	_projectile = ProjectileAuthority.new(AUTHORITY_PEER_ID)
	_landing = LandingAuthority.new(AUTHORITY_PEER_ID)
	_damage_respawn = DamageRespawnIntegration.new(AUTHORITY_PEER_ID)
	_moving_interior = MovingInteriorAuthority.new(AUTHORITY_PEER_ID)
	_moving_relationship_stream = MovingInteriorRelationshipStream.new(AUTHORITY_PEER_ID, 2)
	_moving_replica = MovingInteriorReplica.new(AUTHORITY_PEER_ID, 2, 0.0, 0.25, 8.0)
	_moving_replica_binding = MovingInteriorReplicaBinding.new(8.0)
	_ship_ownership = ShipOwnershipAuthority.new(AUTHORITY_PEER_ID)
	_seat_authority = SeatAuthority.new(AUTHORITY_PEER_ID)
	_crew_roles = CrewRoleAuthority.new(_seat_authority, AUTHORITY_PEER_ID)
	_crew_commands = CrewCommandAuthority.new(_crew_roles, AUTHORITY_PEER_ID)
	_migration = SessionMigration.new(AUTHORITY_PEER_ID)
	_prediction = PredictionGuard.new(AUTHORITY_PEER_ID)
	_server_browser = ServerBrowser.new(AUTHORITY_PEER_ID)
	_snapshot_jitter = SnapshotJitterBuffer.new()
	_replication_interest = ReplicationInterest.new(AUTHORITY_PEER_ID)
	_snapshot_delta_encoder = SnapshotDeltaCodec.new()
	_snapshot_delta_decoder = SnapshotDeltaCodec.new()
	_snapshot_fragmenter = SnapshotFragmenter.new()
	_crew_snapshot_codec = CrewSnapshotCodec.new()
	_crew_snapshot_fragmenter = SnapshotFragmenter.new()
	_projectile_jitter = SnapshotJitterBuffer.new()
	_landing_jitter = SnapshotJitterBuffer.new()
	_damage_jitter = SnapshotJitterBuffer.new()
	_boarding_jitter = SnapshotJitterBuffer.new()
	_migration_jitter = SnapshotJitterBuffer.new()
	_interest_jitter = SnapshotJitterBuffer.new()
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
	_session_max_clients = maxi(1, max_clients)
	_configure_multiplayer()
	_reset_session_end_reason()
	_reset_handshake_deadline()
	_next_join_intent_sequence = 1
	_last_join_intent_sequence = 0
	session_started.emit(&"server")
	_bound_port = maxi(1, port)
	return _remember(_result(true, &"server_started", {"port": _bound_port, "capacity": get_session_capacity_snapshot()}))


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
	_session_max_clients = 0
	_configure_multiplayer()
	_reset_session_end_reason()
	_reset_handshake_deadline()
	_next_join_intent_sequence = 1
	_last_join_intent_sequence = 0
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
			_crew_commands.release_peer(AUTHORITY_PEER_ID, peer_id, int(_peer_generations.get(peer_id, 0)))
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
	_seat_moving_relationships.clear()
	_moving_recipient_budgets.clear()
	_moving_recipient_entities.clear()
	_moving_recipient_pending.clear()
	_projectile_snapshot_revision = 0
	_projectile_recipient_budgets.clear()
	_projectile_recipient_pending.clear()
	_projectile_published_generations.clear()
	_projectile_replica_generations.clear()
	_projectile_replica_ticks.clear()
	_projectile_replica_revision = 0
	_projectile_replica_migration_generation = 1
	_peer_keepalive_deadlines.clear()
	_session_max_clients = DEFAULT_MAX_CLIENTS
	_server_offer.clear()
	_crew_snapshot_fragmenter.reset()
	_crew_snapshot_revision = 0
	_crew_replica_snapshot.clear()
	_moving_snapshot_revision = 0
	_moving_resync_revision = 0
	for entity_variant in _moving_replica_binding_ids.keys():
		_moving_replica_binding.detach(StringName(entity_variant))
	_moving_replica_binding_ids.clear()
	mark_reconnect_succeeded()
	record_session_end(reason)
	_reset_handshake_deadline()
	_server_browser.detach(AUTHORITY_PEER_ID)
	_next_join_intent_sequence = 1
	_last_join_intent_sequence = 0
	session_stopped.emit(reason)
	return _remember(_result(true, &"stopped", {"reason": reason}))


func is_server() -> bool:
	return _is_server and _configured


func get_local_port() -> int:
	return _bound_port


func get_server_offer() -> Dictionary:
	return _server_offer.duplicate(true)


func get_session_capacity_snapshot() -> Dictionary:
	return {
		"occupancy": _peer_generations.size(),
		"max_players": _session_max_clients,
		"available_slots": maxi(0, _session_max_clients - _peer_generations.size()),
	}.duplicate(true)


func configure_peer_keepalive(timeout_milliseconds: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	_keepalive_timeout_milliseconds = clampi(timeout_milliseconds, 1, KEEPALIVE_MAX_TIMEOUT_MILLISECONDS)
	return _remember(_result(true, &"keepalive_configured", {
		"timeout_milliseconds": _keepalive_timeout_milliseconds,
	}))


func refresh_peer_keepalive(source_peer_id: int, peer_id: int, peer_generation: int, now_milliseconds: int) -> Dictionary:
	if not is_server() or source_peer_id != AUTHORITY_PEER_ID:
		return _remember(_result(false, &"authority_required"))
	if now_milliseconds < 0 or int(_peer_generations.get(peer_id, 0)) != peer_generation:
		return _remember(_result(false, &"stale_peer_generation"))
	_peer_keepalive_deadlines[peer_id] = now_milliseconds + _keepalive_timeout_milliseconds
	return _remember(_result(true, &"keepalive_refreshed", {"peer_id": peer_id, "deadline_milliseconds": _peer_keepalive_deadlines[peer_id]}))


func check_peer_keepalives(source_peer_id: int, now_milliseconds: int) -> Dictionary:
	if not is_server() or source_peer_id != AUTHORITY_PEER_ID:
		return _remember(_result(false, &"authority_required"))
	if now_milliseconds < 0:
		return _remember(_result(false, &"invalid_keepalive_clock"))
	var timed_out: Array = []
	for peer_variant in _peer_keepalive_deadlines.keys():
		var peer_id := int(peer_variant)
		if now_milliseconds < int(_peer_keepalive_deadlines[peer_id]):
			continue
		timed_out.append(peer_id)
		if _peer != null and multiplayer != null and multiplayer.get_peers().has(peer_id):
			_peer.disconnect_peer(peer_id)
		_on_peer_disconnected(peer_id, &"timeout")
	return _remember(_result(true, &"keepalives_checked", {"timed_out_peer_ids": timed_out}))


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


func publish_boarding_snapshot(
	ship_id: StringName,
	owner_peer_id: int,
	seat_id: StringName,
	ship_generation: int,
	seat_generation: int,
	occupied: bool,
	recipients: Array = [],
	server_tick: int = 0
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if ship_id.is_empty() or seat_id.is_empty() or ship_generation <= 0 or seat_generation <= 0:
		return _remember(_result(false, &"invalid_boarding_snapshot"))
	var target_peers: Array = recipients.duplicate()
	if target_peers.is_empty():
		target_peers = _peer_generations.keys()
	for peer_variant in target_peers:
		if not _peer_generations.has(int(peer_variant)):
			return _remember(_result(false, &"peer_not_admitted"))
	_boarding_snapshot_revision += 1
	var packet := {
		"revision": _boarding_snapshot_revision,
		"server_tick": maxi(0, server_tick),
		"boarding": {
			"ship_id": ship_id,
			"seat_id": seat_id,
			"seat_generation": seat_generation,
			"occupied": occupied,
		},
		"ownership": {
			"ship_id": ship_id,
			"ship_generation": ship_generation,
			"owner_peer_id": owner_peer_id,
		},
	}
	for peer_variant in target_peers:
		if _peer != null:
			_send_boarding_snapshot.rpc_id(int(peer_variant), packet)
	return _remember(_result(true, &"boarding_snapshot_published", {"packet": packet, "recipients": target_peers.size()}))


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


func register_remote_ship_pilot(peer_id: int, ship_id: StringName, generation: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_remote_ship_commands.register_pilot(peer_id, ship_id, generation))


func consume_remote_ship_command(ship_id: StringName, server_tick: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_remote_ship_commands.consume(ship_id, server_tick))


func reset_remote_ship_pilot(ship_id: StringName, reason: StringName = &"reset") -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	return _remember(_remote_ship_commands.reset(ship_id, reason))


func get_remote_ship_command_snapshot() -> Dictionary:
	return _remote_ship_commands.get_snapshot()


func publish_remote_ship_pilot_resync(peer_id: int) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var packet := {
		"migration_generation": int(_migration.get_snapshot().get("migration_generation", 1)),
		"pilot": _remote_ship_commands.get_snapshot(),
	}
	if _peer != null:
		_send_remote_ship_pilot_resync.rpc_id(peer_id, packet)
	return _remember(_result(true, &"remote_pilot_resync_published", {"packet": packet}))


func get_remote_pilot_replica() -> Dictionary:
	return _remote_pilot_replica.duplicate(true)


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


func publish_projectile_snapshot(
	projectile: Dictionary,
	recipients: Array = [],
	terminal: bool = false,
	budget_tick: int = -1
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var validation := _validate_projectile_replica_snapshot(projectile)
	if not bool(validation.get("accepted", false)):
		return _remember(validation)
	var target_peers: Array = recipients.duplicate()
	if target_peers.is_empty():
		target_peers = _peer_generations.keys()
	for peer_variant in target_peers:
		if not _peer_generations.has(int(peer_variant)):
			return _remember(_result(false, &"peer_not_admitted"))
	_projectile_snapshot_revision += 1
	var logical_tick := int(projectile.get("last_update_tick", 0)) if budget_tick < 0 else budget_tick
	var packet := {
		"revision": _projectile_snapshot_revision,
		"server_tick": logical_tick,
		"migration_generation": int(_migration.get_snapshot().get("migration_generation", 1)),
		"projectile": projectile.duplicate(true),
		"terminal": terminal,
	}
	var encoded_size := Marshalls.variant_to_base64(packet).to_utf8_buffer().size()
	if encoded_size > MAX_PROJECTILE_REPLICATION_PACKET_BYTES:
		return _remember(_result(false, &"projectile_packet_too_large"))
	var coalesced := 0
	for peer_variant in target_peers:
		var peer_id := int(peer_variant)
		var published: Dictionary = _projectile_published_generations.get(peer_id, {}) as Dictionary
		var projectile_id := StringName(projectile.get("projectile_id", &""))
		var transition := terminal or not published.has(projectile_id) \
				or int(published.get(projectile_id, 0)) != int(projectile.get("projectile_generation", 0))
		var budget := _projectile_budget_decision(peer_id, packet, logical_tick, transition)
		if bool(budget.get("accepted", false)) and _peer != null:
			_send_projectile_snapshot.rpc_id(peer_id, packet)
		elif budget.get("status") == &"coalesced":
			coalesced += 1
		if bool(budget.get("accepted", false)):
			published[projectile_id] = int(projectile.get("projectile_generation", 0))
			_projectile_published_generations[peer_id] = published
	var status: StringName = &"projectile_snapshot_coalesced" if coalesced == target_peers.size() and not target_peers.is_empty() else &"projectile_snapshot_published"
	return _remember(_result(true, status, {
		"revision": _projectile_snapshot_revision,
		"recipients": target_peers.size(),
		"coalesced": coalesced,
		"terminal": terminal,
		"packet": packet,
	}))


func get_projectile_replication_budget(peer_id: int = 0) -> Dictionary:
	if peer_id > 0:
		return (_projectile_recipient_budgets.get(peer_id, {}) as Dictionary).duplicate(true)
	return _projectile_recipient_budgets.duplicate(true)


func publish_projectile_resync(peer_id: int, budget_tick: int = -1) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var published_count := 0
	var coalesced_count := 0
	for projectile_variant in _projectile.get_projectiles_snapshot():
		var result: Dictionary = publish_projectile_snapshot(
			projectile_variant as Dictionary, [peer_id], false, budget_tick
		)
		if not bool(result.get("accepted", false)):
			return _remember(result)
		published_count += 1
		coalesced_count += int(result.get("coalesced", 0))
	return _remember(_result(true, &"projectile_resync_published", {
		"peer_id": peer_id,
		"projectile_count": published_count,
		"coalesced": coalesced_count,
	}))


func _validate_projectile_replica_snapshot(projectile: Dictionary) -> Dictionary:
	for key in ["projectile_id", "projectile_generation", "source_entity_id", "source_generation",
			"owner_peer_id", "position", "last_update_tick", "state"]:
		if not projectile.has(key):
			return _result(false, &"invalid_projectile_snapshot")
	var position_variant: Variant = projectile.get("position")
	if not position_variant is Vector3 or not (position_variant as Vector3).is_finite():
		return _result(false, &"invalid_projectile_snapshot")
	if StringName(projectile.get("projectile_id", &"")).is_empty() \
			or int(projectile.get("projectile_generation", 0)) <= 0 \
			or StringName(projectile.get("source_entity_id", &"")).is_empty() \
			or int(projectile.get("source_generation", 0)) <= 0 \
			or int(projectile.get("owner_peer_id", 0)) <= 0 \
			or int(projectile.get("last_update_tick", -1)) < 0:
		return _result(false, &"invalid_projectile_snapshot")
	return _result(true, &"valid_projectile_snapshot")


func _projectile_budget_decision(
	peer_id: int,
	packet: Dictionary,
	logical_tick: int,
	transition: bool
) -> Dictionary:
	var size_bytes := Marshalls.variant_to_base64(packet).to_utf8_buffer().size()
	var state: Dictionary = _projectile_recipient_budgets.get(peer_id, {}) as Dictionary
	if state.is_empty():
		state = {"window_tick": logical_tick, "snapshot_count": 0, "byte_count": 0,
			"coalesced_count": 0, "transition_count": 0, "forced_transition_count": 0, "pending_count": 0}
	elif logical_tick < int(state.get("window_tick", logical_tick)):
		return _result(false, &"stale_projectile_budget_tick")
	elif logical_tick >= int(state.get("window_tick", logical_tick)) + PROJECTILE_BUDGET_WINDOW_TICKS:
		state.window_tick = logical_tick
		state.snapshot_count = 0
		state.byte_count = 0
		var pending: Dictionary = _projectile_recipient_pending.get(peer_id, {}) as Dictionary
		for pending_variant in pending.values():
			var pending_packet := pending_variant as Dictionary
			var pending_size := Marshalls.variant_to_base64(pending_packet).to_utf8_buffer().size()
			if int(state.snapshot_count) >= PROJECTILE_MAX_SNAPSHOTS_PER_WINDOW \
					or int(state.byte_count) + pending_size > PROJECTILE_MAX_BYTES_PER_WINDOW:
				break
			if _peer != null:
				_send_projectile_snapshot.rpc_id(peer_id, pending_packet)
			state.snapshot_count = int(state.snapshot_count) + 1
			state.byte_count = int(state.byte_count) + pending_size
			pending.erase(pending_variant)
		_projectile_recipient_pending[peer_id] = pending
	if int(state.snapshot_count) >= PROJECTILE_MAX_SNAPSHOTS_PER_WINDOW \
			or int(state.byte_count) + size_bytes > PROJECTILE_MAX_BYTES_PER_WINDOW:
		if transition:
			state.forced_transition_count = int(state.get("forced_transition_count", 0)) + 1
		else:
			var pending: Dictionary = _projectile_recipient_pending.get(peer_id, {}) as Dictionary
			var projectile_id := StringName((packet.get("projectile", {}) as Dictionary).get("projectile_id", &""))
			pending[projectile_id] = packet.duplicate(true)
			_projectile_recipient_pending[peer_id] = pending
			state.coalesced_count = int(state.get("coalesced_count", 0)) + 1
			state.pending_count = pending.size()
			_projectile_recipient_budgets[peer_id] = state
			return _result(false, &"coalesced", {"pending_count": pending.size()})
	if transition:
		state.transition_count = int(state.get("transition_count", 0)) + 1
	state.snapshot_count = int(state.snapshot_count) + 1
	state.byte_count = int(state.byte_count) + size_bytes
	_projectile_recipient_budgets[peer_id] = state
	return _result(true, &"sent", {"bytes": size_bytes})


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
	if owner_peer_id != AUTHORITY_PEER_ID and not _peer_generations.has(owner_peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var result: Dictionary = _landing.register_entity(
		AUTHORITY_PEER_ID, owner_peer_id, entity_id, entity_generation, state
	)
	if bool(result.get("accepted", false)):
		_landing_entities[entity_id] = {
			"owner_peer_id": owner_peer_id,
			"entity_generation": entity_generation,
		}
	return _remember(result)


func publish_landing_snapshot(
	entity_id: StringName,
	entity_generation: int,
	position: Vector3,
	state: StringName,
	recipients: Array = [],
	server_tick: int = 0
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if entity_id.is_empty() or entity_generation <= 0 or not position.is_finite():
		return _remember(_result(false, &"invalid_landing_snapshot"))
	var target_peers: Array = recipients.duplicate()
	if target_peers.is_empty():
		target_peers = _peer_generations.keys()
	for peer_variant in target_peers:
		if not _peer_generations.has(int(peer_variant)):
			return _remember(_result(false, &"peer_not_admitted"))
	_landing_snapshot_revision += 1
	var packet := {
		"revision": _landing_snapshot_revision,
		"server_tick": maxi(0, server_tick),
		"landing": {
			"entity_id": entity_id,
			"entity_generation": entity_generation,
			"position": position,
			"state": state,
		},
	}
	for peer_variant in target_peers:
		if _peer != null:
			_send_landing_snapshot.rpc_id(int(peer_variant), packet)
	return _remember(_result(true, &"landing_snapshot_published", {"packet": packet, "recipients": target_peers.size()}))


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
	if owner_peer_id != AUTHORITY_PEER_ID and not _peer_generations.has(owner_peer_id):
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


func publish_damage_respawn_snapshot(
	entity_id: StringName,
	entity_generation: int,
	health: float,
	state: StringName,
	destroyed: bool = false,
	recovery_generation: int = 0,
	recipients: Array = [],
	server_tick: int = 0
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if entity_id.is_empty() or entity_generation <= 0 or not is_finite(health) or health < 0.0:
		return _remember(_result(false, &"invalid_damage_snapshot"))
	var target_peers: Array = recipients.duplicate()
	if target_peers.is_empty():
		target_peers = _peer_generations.keys()
	for peer_variant in target_peers:
		if not _peer_generations.has(int(peer_variant)):
			return _remember(_result(false, &"peer_not_admitted"))
	_damage_snapshot_revision += 1
	var packet := {
		"revision": _damage_snapshot_revision,
		"server_tick": maxi(0, server_tick),
		"damage": {
			"entity_id": entity_id,
			"entity_generation": entity_generation,
			"health": health,
			"state": state,
			"destroyed": destroyed,
			"recovery_generation": recovery_generation,
		},
	}
	for peer_variant in target_peers:
		if _peer != null:
			_send_damage_respawn_snapshot.rpc_id(int(peer_variant), packet)
	return _remember(_result(true, &"damage_snapshot_published", {"packet": packet, "recipients": target_peers.size()}))


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


## Publishes one server-captured moving-interior relationship to admitted peers.
## The relationship contract is the wire codec; this adapter only adds bounded
## revision/generation framing and never accepts a client publication.
func publish_moving_interior_snapshot(
	relationship_snapshot: Dictionary,
	recipients: Array = [],
	budget_tick: int = -1
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var relationship := MovingInteriorRelationship.from_dictionary(relationship_snapshot)
	if not relationship.is_valid():
		return _remember(_result(false, &"invalid_moving_interior_relationship", {
			"errors": relationship.get_validation_errors(),
		}))
	var target_peers: Array = recipients.duplicate()
	if target_peers.is_empty():
		target_peers = _peer_generations.keys()
	for peer_variant in target_peers:
		var peer_id := int(peer_variant)
		if peer_id <= 0 or not _peer_generations.has(peer_id):
			return _remember(_result(false, &"peer_not_admitted"))
	var generation := int(_migration.get_snapshot().get("migration_generation", 1))
	var logical_tick := relationship.get_server_tick() if budget_tick < 0 else budget_tick
	var next_revision := _moving_snapshot_revision + 1
	var packet := {
		"revision": next_revision,
		"server_tick": relationship.get_server_tick(),
		"migration_generation": generation,
		"relationship": relationship.get_snapshot(),
	}
	if Marshalls.variant_to_base64(packet).to_utf8_buffer().size() > MAX_MOVING_INTERIOR_PACKET_BYTES:
		return _remember(_result(false, &"moving_interior_packet_too_large"))
	_moving_snapshot_revision = next_revision
	var coalesced := 0
	for peer_variant in target_peers:
		var peer_id := int(peer_variant)
		var entity_id := relationship.get_entity_id()
		var prior: Dictionary = (_moving_recipient_entities.get(peer_id, {}) as Dictionary).get(entity_id, {}) as Dictionary
		var transition := prior.is_empty() or int(prior.get("entity_generation", 0)) != relationship.get_entity_generation()
		var budget := _moving_budget_decision(peer_id, packet, entity_id, logical_tick, transition)
		if bool(budget.get("accepted", false)) and _peer != null:
			_broadcast_moving_interior_snapshot.rpc_id(peer_id, packet)
		elif budget.get("status") == &"coalesced":
			coalesced += 1
	var result := _result(true, &"moving_interior_snapshot_coalesced" if coalesced == target_peers.size() and not target_peers.is_empty() else &"moving_interior_snapshot_published", {
		"revision": next_revision,
		"migration_generation": generation,
		"recipients": target_peers.size(),
		"coalesced": coalesced,
		"packet": packet,
	})
	moving_interior_result.emit(result.duplicate(true))
	return _remember(result)


func publish_moving_interior_release(
	entity_id: StringName,
	entity_generation: int,
	recipients: Array = []
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if entity_id.is_empty() or entity_generation <= 0:
		return _remember(_result(false, &"invalid_moving_interior_release"))
	var target_peers: Array = recipients.duplicate()
	if target_peers.is_empty():
		target_peers = _peer_generations.keys()
	for peer_variant in target_peers:
		if not _peer_generations.has(int(peer_variant)):
			return _remember(_result(false, &"peer_not_admitted"))
	var packet := {"entity_id": entity_id, "entity_generation": entity_generation}
	for peer_variant in target_peers:
		if _peer != null:
			_broadcast_moving_interior_release.rpc_id(int(peer_variant), packet)
	return _remember(_result(true, &"moving_interior_release_published", {"packet": packet}))


func publish_moving_interior_resync(peer_id: int, budget_tick: int = -1) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	if not _peer_generations.has(peer_id):
		return _remember(_result(false, &"peer_not_admitted"))
	var relationships: Array = []
	for relationship_key_variant in _seat_moving_relationships.keys():
		var relationship_key := String(relationship_key_variant)
		if not relationship_key.begins_with("%d:" % peer_id):
			continue
		relationships.append((_seat_moving_relationships[relationship_key_variant] as Dictionary).duplicate(true))
	if relationships.size() > 128:
		return _remember(_result(false, &"moving_interior_resync_capacity"))
	var prior_entities: Dictionary = _moving_recipient_entities.get(peer_id, {}) as Dictionary
	var current_entities: Dictionary = {}
	for relationship_variant in relationships:
		var relationship := relationship_variant as Dictionary
		current_entities[StringName(relationship.get("entity_id", &""))] = relationship.duplicate(true)
	var released_entities: Array = []
	for entity_variant in prior_entities.keys():
		if not current_entities.has(entity_variant):
			released_entities.append(StringName(entity_variant))
	var packet := {
		"authority_peer_id": AUTHORITY_PEER_ID,
		"recipient_peer_id": peer_id,
		"migration_generation": int(_migration.get_snapshot().get("migration_generation", 1)),
		"revision": maxi(1, _moving_snapshot_revision),
		"relationships": relationships,
		"released_entities": released_entities,
	}
	if Marshalls.variant_to_base64(packet).to_utf8_buffer().size() > MAX_MOVING_INTERIOR_PACKET_BYTES:
		return _remember(_result(false, &"moving_interior_packet_too_large"))
	var logical_tick := budget_tick if budget_tick >= 0 else int(_migration.get_snapshot().get("migration_generation", 1))
	var transition := not released_entities.is_empty()
	for entity_variant in current_entities.keys():
		var prior: Dictionary = prior_entities.get(entity_variant, {}) as Dictionary
		var current: Dictionary = current_entities[entity_variant] as Dictionary
		if prior.is_empty() or int(prior.get("entity_generation", 0)) != int(current.get("entity_generation", 0)):
			transition = true
	var budget := _moving_budget_decision(peer_id, packet, &"__resync__", logical_tick, transition)
	if bool(budget.get("accepted", false)) and _peer != null:
		_send_moving_interior_resync.rpc_id(peer_id, packet)
	if bool(budget.get("accepted", false)):
		_moving_recipient_entities[peer_id] = current_entities
	return _remember(_result(bool(budget.get("accepted", false)), budget.get("status", &"moving_interior_resync_published"), {
		"peer_id": peer_id,
		"relationship_count": relationships.size(),
		"released_count": released_entities.size(),
		"packet": packet,
	}))


func get_moving_interior_budget_snapshot(peer_id: int = 0) -> Dictionary:
	if peer_id > 0:
		return (_moving_recipient_budgets.get(peer_id, {}) as Dictionary).duplicate(true)
	return _moving_recipient_budgets.duplicate(true)


func _moving_budget_decision(
	peer_id: int,
	packet: Dictionary,
	entity_id: StringName,
	logical_tick: int,
	transition: bool
) -> Dictionary:
	var size_bytes := Marshalls.variant_to_base64(packet).to_utf8_buffer().size()
	if size_bytes > MAX_MOVING_INTERIOR_PACKET_BYTES:
		return _result(false, &"moving_interior_packet_too_large")
	var state: Dictionary = _moving_recipient_budgets.get(peer_id, {}) as Dictionary
	if state.is_empty():
		state = {"window_tick": logical_tick, "snapshot_count": 0, "byte_count": 0,
			"coalesced_count": 0, "transition_count": 0, "forced_transition_count": 0, "pending_count": 0}
	elif logical_tick < int(state.get("window_tick", logical_tick)):
		return _result(false, &"stale_moving_interior_budget_tick")
	elif logical_tick >= int(state.get("window_tick", logical_tick)) + MOVING_INTERIOR_BUDGET_WINDOW_TICKS:
		state["window_tick"] = logical_tick
		state["snapshot_count"] = 0
		state["byte_count"] = 0
		var pending: Dictionary = _moving_recipient_pending.get(peer_id, {}) as Dictionary
		for pending_variant in pending.values():
			var pending_packet := pending_variant as Dictionary
			var pending_size := Marshalls.variant_to_base64(pending_packet).to_utf8_buffer().size()
			if int(state.snapshot_count) >= MOVING_INTERIOR_MAX_SNAPSHOTS_PER_WINDOW \
					or int(state.byte_count) + pending_size > MOVING_INTERIOR_MAX_BYTES_PER_WINDOW:
				break
			if _peer != null:
				_broadcast_moving_interior_snapshot.rpc_id(peer_id, pending_packet)
			state.snapshot_count = int(state.snapshot_count) + 1
			state.byte_count = int(state.byte_count) + pending_size
			pending.erase(pending_variant)
		_moving_recipient_pending[peer_id] = pending
	if int(state.snapshot_count) >= MOVING_INTERIOR_MAX_SNAPSHOTS_PER_WINDOW \
			or int(state.byte_count) + size_bytes > MOVING_INTERIOR_MAX_BYTES_PER_WINDOW:
		if transition:
			state.forced_transition_count = int(state.get("forced_transition_count", 0)) + 1
		else:
			var pending: Dictionary = _moving_recipient_pending.get(peer_id, {}) as Dictionary
			pending[entity_id] = packet.duplicate(true)
			_moving_recipient_pending[peer_id] = pending
			state.coalesced_count = int(state.get("coalesced_count", 0)) + 1
			state.pending_count = pending.size()
			_moving_recipient_budgets[peer_id] = state
			return _result(false, &"coalesced", {"pending_count": pending.size()})
	if transition:
		state.transition_count = int(state.get("transition_count", 0)) + 1
	state.snapshot_count = int(state.snapshot_count) + 1
	state.byte_count = int(state.byte_count) + size_bytes
	_moving_recipient_budgets[peer_id] = state
	if entity_id != &"__resync__":
		var entities: Dictionary = _moving_recipient_entities.get(peer_id, {}) as Dictionary
		var relationship: Dictionary = packet.get("relationship", {}) as Dictionary
		entities[entity_id] = relationship.duplicate(true)
		_moving_recipient_entities[peer_id] = entities
	return _result(true, &"sent", {"bytes": size_bytes})


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
	var frame_status := _validate_seat_moving_frame(seat_record)
	if not frame_status.is_empty():
		return _remember(_result(false, frame_status))
	var result: Dictionary = _seat_authority.claim(
		AUTHORITY_PEER_ID, occupant_peer_id, avatar_id, seat_id, requested_role, request_sequence
	)
	if bool(result.get("accepted", false)):
		var assignment: Dictionary = result.get("assignment", {}) as Dictionary
		var relationship := _relationship_for_seat_assignment(assignment)
		_seat_moving_relationships[_seat_relationship_key(occupant_peer_id, avatar_id)] = relationship.get_snapshot()
		result["moving_interior_relationship"] = relationship.get_snapshot()
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
	if bool(result.get("accepted", false)):
		_seat_moving_relationships.erase(_seat_relationship_key(occupant_peer_id, avatar_id))
		_crew_roles.release_avatar(AUTHORITY_PEER_ID, occupant_peer_id,
			int(_peer_generations.get(occupant_peer_id, 0)), avatar_id)
		_crew_commands.release_avatar(AUTHORITY_PEER_ID, occupant_peer_id,
			int(_peer_generations.get(occupant_peer_id, 0)), avatar_id)
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
	if bool(result.get("accepted", false)):
		var relationship_key := _seat_relationship_key(from_peer_id, avatar_id)
		var relationship: Dictionary = _seat_moving_relationships.get(relationship_key, {}) as Dictionary
		_seat_moving_relationships.erase(relationship_key)
		if not relationship.is_empty():
			_seat_moving_relationships[_seat_relationship_key(to_peer_id, avatar_id)] = relationship
	seat_occupancy_result.emit(result.duplicate(true))
	return _remember(result)


func get_crew_assignment(occupant_peer_id: int, avatar_id: StringName) -> Dictionary:
	return _seat_authority.get_assignment(occupant_peer_id, avatar_id)


func get_crew_moving_interior_relationship(occupant_peer_id: int, avatar_id: StringName) -> Dictionary:
	return (_seat_moving_relationships.get(
		_seat_relationship_key(occupant_peer_id, avatar_id), {}
	) as Dictionary).duplicate(true)


func accept_crew_role_intent(
	peer_id: int,
	peer_generation: int,
	avatar_id: StringName,
	requested_role: StringName,
	request_sequence: int,
	ship_id: StringName = &"",
	ship_generation: int = 0
) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _crew_roles.accept_role_intent(
		AUTHORITY_PEER_ID, peer_id, peer_generation, avatar_id, requested_role, request_sequence,
		ship_id, ship_generation
	)
	crew_role_result.emit(result.duplicate(true))
	return _remember(result)


func get_crew_role_snapshot() -> Dictionary:
	return _crew_roles.get_snapshot()


func send_crew_role_intent(
	avatar_id: StringName,
	requested_role: StringName,
	request_sequence: int,
	ship_id: StringName = &"",
	ship_generation: int = 0
) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	if not _configured or avatar_id.is_empty() or request_sequence <= 0:
		return _remember(_result(false, &"invalid_role_intent"))
	_receive_crew_role_intent.rpc_id(AUTHORITY_PEER_ID, _make_secure_rpc_packet(&"crew_role", {
		"avatar_id": avatar_id,
		"requested_role": requested_role,
		"request_sequence": request_sequence,
		"ship_id": ship_id,
		"ship_generation": ship_generation,
	}))
	return _remember(_result(true, &"queued"))


func accept_crew_command(
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
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _crew_commands.accept_command(
		AUTHORITY_PEER_ID, peer_id, peer_generation, avatar_id, action,
		request_sequence, server_tick, payload, ship_id, ship_generation
	)
	crew_command_result.emit(result.duplicate(true))
	return _remember(result)


func get_crew_command_snapshot() -> Dictionary:
	return _crew_commands.get_snapshot()


func send_crew_command(
	avatar_id: StringName,
	action: StringName,
	request_sequence: int,
	server_tick: int,
	payload: Dictionary,
	ship_id: StringName = &"",
	ship_generation: int = 0
) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	if not _configured or avatar_id.is_empty() or action.is_empty() \
		or request_sequence <= 0 or server_tick < 0:
		return _remember(_result(false, &"invalid_crew_command"))
	_receive_crew_command.rpc_id(AUTHORITY_PEER_ID, _make_secure_rpc_packet(&"crew_command", {
		"avatar_id": avatar_id,
		"action": action,
		"request_sequence": request_sequence,
		"server_tick": server_tick,
		"ship_id": ship_id,
		"ship_generation": ship_generation,
		"payload": payload.duplicate(true),
	}))
	return _remember(_result(true, &"queued"))


func rotate_session_migration(next_package_generation: int = -1) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _migration.rotate_server(AUTHORITY_PEER_ID, next_package_generation)
	if bool(result.get("accepted", false)):
		_moving_snapshot_revision = 0
		_moving_recipient_budgets.clear()
		_moving_recipient_entities.clear()
		_moving_recipient_pending.clear()
		_projectile_snapshot_revision = 0
		_projectile_recipient_budgets.clear()
		_projectile_recipient_pending.clear()
		_projectile_published_generations.clear()
		_projectile_replica_generations.clear()
		_projectile_replica_ticks.clear()
		_projectile_replica_revision = 0
		_projectile_replica_migration_generation = 1
		_reset_peer_keepalive_deadlines(Time.get_ticks_msec())
	migration_result.emit(result.duplicate(true))
	return _remember(result)


func accept_migration_packet(source_peer_id: int, packet: Dictionary) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var result: Dictionary = _migration.accept_packet(source_peer_id, packet)
	migration_result.emit(result.duplicate(true))
	return _remember(result)


func _reset_peer_keepalive_deadlines(now_milliseconds: int) -> void:
	for peer_variant in _peer_generations.keys():
		_peer_keepalive_deadlines[int(peer_variant)] = now_milliseconds + _keepalive_timeout_milliseconds


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
	_remote_pilot_replica.clear()
	if is_server():
		return _remember(_result(false, &"client_required"))
	mark_reconnect_succeeded()
	if migration_generation > 1:
		_crew_roles.reset_migration(AUTHORITY_PEER_ID, migration_generation)
		_crew_commands.reset_migration(AUTHORITY_PEER_ID, migration_generation)
	_reset_session_end_reason()
	_reset_handshake_deadline()
	_server_browser.detach(AUTHORITY_PEER_ID)
	_next_join_intent_sequence = 1
	_last_join_intent_sequence = 0
	_snapshot_delta_decoder.reset()
	_snapshot_fragmenter.reset()
	_crew_snapshot_fragmenter.reset()
	_crew_snapshot_codec = CrewSnapshotCodec.new()
	_crew_snapshot_revision = 0
	_crew_replica_snapshot.clear()
	_moving_replica_samples.clear()
	_moving_snapshot_revision = 0
	_moving_resync_revision = 0
	_moving_recipient_budgets.clear()
	_moving_recipient_entities.clear()
	_moving_recipient_pending.clear()
	_projectile_snapshot_revision = 0
	_projectile_recipient_budgets.clear()
	_projectile_recipient_pending.clear()
	_projectile_published_generations.clear()
	_projectile_replica_generations.clear()
	_projectile_replica_ticks.clear()
	_projectile_replica_revision = 0
	_projectile_replica_migration_generation = migration_generation
	for entity_variant in _moving_replica_binding_ids.keys():
		_moving_replica_binding.detach(StringName(entity_variant))
	_moving_replica_binding_ids.clear()
	if migration_generation > int(_moving_relationship_stream.get_snapshot().get("migration_generation", 1)):
		_moving_relationship_stream.reset_migration(AUTHORITY_PEER_ID, migration_generation)
		_moving_replica.reset_migration(AUTHORITY_PEER_ID, migration_generation)
	_projectile_replica_samples.clear()
	_projectile_jitter.reset(migration_generation)
	_landing_replica_samples.clear()
	_landing_snapshot_revision = 0
	_landing_jitter.reset(migration_generation)
	_damage_replica_samples.clear()
	_damage_snapshot_revision = 0
	_damage_jitter.reset(migration_generation)
	_boarding_replica_samples.clear()
	_boarding_snapshot_revision = 0
	_boarding_jitter.reset(migration_generation)
	_migration_replica_generation = migration_generation
	_migration_replica_samples.clear()
	_migration_jitter.reset(migration_generation)
	_interest_replica_samples.clear()
	_interest_retired_revisions.clear()
	_presentation_evictions = 0
	_interest_jitter.reset(migration_generation)
	return _remember(_snapshot_jitter.reset(migration_generation))


## Caller-driven reconnect scheduling. This records a capped delay only; it
## never starts a timer, process loop, or transport attempt.
func schedule_reconnect_attempt(now_milliseconds: int) -> Dictionary:
	if now_milliseconds < 0:
		return _remember(_result(false, &"invalid_reconnect_clock"))
	if now_milliseconds < _reconnect_next_allowed_milliseconds:
		return _remember(_result(false, &"reconnect_backoff_active", {
			"retry_after_milliseconds": _reconnect_next_allowed_milliseconds - now_milliseconds,
		}))
	_reconnect_attempts = mini(_reconnect_attempts + 1, RECONNECT_BACKOFF_MAX_ATTEMPTS)
	var exponent := mini(_reconnect_attempts - 1, 5)
	var delay := mini(RECONNECT_BACKOFF_BASE_MILLISECONDS * (1 << exponent), RECONNECT_BACKOFF_MAX_MILLISECONDS)
	_reconnect_next_allowed_milliseconds = now_milliseconds + delay
	return _remember(_result(true, &"reconnect_attempt_scheduled", {
		"attempt": _reconnect_attempts,
		"delay_milliseconds": delay,
		"next_allowed_milliseconds": _reconnect_next_allowed_milliseconds,
	}))


func mark_reconnect_succeeded() -> Dictionary:
	_reconnect_attempts = 0
	_reconnect_next_allowed_milliseconds = 0
	return _remember(_result(true, &"reconnect_backoff_reset"))


func get_reconnect_backoff_state() -> Dictionary:
	return {
		"attempts": _reconnect_attempts,
		"next_allowed_milliseconds": _reconnect_next_allowed_milliseconds,
		"base_delay_milliseconds": RECONNECT_BACKOFF_BASE_MILLISECONDS,
		"max_delay_milliseconds": RECONNECT_BACKOFF_MAX_MILLISECONDS,
		"max_attempts": RECONNECT_BACKOFF_MAX_ATTEMPTS,
	}.duplicate(true)


func record_session_end(
		raw_reason: StringName,
		peer_generation: int = 0,
		migration_generation: int = 0
) -> Dictionary:
	var normalized := &"unknown"
	if raw_reason in [&"timeout", &"timed_out", &"connection_timeout"]:
		normalized = &"timeout"
	elif raw_reason in [&"rejected", &"admission_rejected", &"transport_rejected"]:
		normalized = &"rejected"
	elif raw_reason in [&"protocol_mismatch", &"incompatible_protocol"]:
		normalized = &"protocol_mismatch"
	elif raw_reason in [&"host_migration", &"migration"]:
		normalized = &"host_migration"
	elif raw_reason in [&"manual_leave", &"requested", &"probe_complete"]:
		normalized = &"manual_leave"
	var current_migration := int(_session_end_reason.get("migration_generation", 0))
	if migration_generation > 0 and current_migration > 0 and migration_generation < current_migration:
		return _remember(_result(false, &"stale_session_end_generation", {
			"snapshot": _session_end_reason.duplicate(true),
		}))
	_session_end_reason = {
		"reason": normalized,
		"peer_generation": maxi(0, peer_generation),
		"migration_generation": maxi(0, migration_generation),
		"sequence": int(_session_end_reason.get("sequence", 0)) + 1,
	}
	return _remember(_result(true, &"session_end_recorded", {
		"snapshot": _session_end_reason.duplicate(true),
	}))


func get_session_end_reason_snapshot() -> Dictionary:
	return _session_end_reason.duplicate(true)


func begin_handshake(
		now_milliseconds: int,
		peer_generation: int,
		migration_generation: int,
		timeout_milliseconds: int = HANDSHAKE_DEFAULT_TIMEOUT_MILLISECONDS
) -> Dictionary:
	if now_milliseconds < 0 or peer_generation <= 0 or migration_generation <= 0 \
			or timeout_milliseconds <= 0 or timeout_milliseconds > HANDSHAKE_MAX_TIMEOUT_MILLISECONDS:
		return _remember(_result(false, &"invalid_handshake_deadline"))
	_handshake_deadline = {
		"active": true,
		"deadline_milliseconds": now_milliseconds + timeout_milliseconds,
		"peer_generation": peer_generation,
		"migration_generation": migration_generation,
		"timeout_milliseconds": timeout_milliseconds,
	}
	return _remember(_result(true, &"handshake_deadline_started", {
		"deadline": _handshake_deadline.duplicate(true),
	}))


func check_handshake_deadline(
		now_milliseconds: int,
		peer_generation: int,
		migration_generation: int
) -> Dictionary:
	if now_milliseconds < 0 or peer_generation <= 0 or migration_generation <= 0:
		return _remember(_result(false, &"invalid_handshake_deadline"))
	if not bool(_handshake_deadline.get("active", false)):
		return _remember(_result(true, &"handshake_inactive"))
	if peer_generation != int(_handshake_deadline.peer_generation) \
			or migration_generation != int(_handshake_deadline.migration_generation):
		return _remember(_result(false, &"stale_handshake_generation"))
	if now_milliseconds < int(_handshake_deadline.deadline_milliseconds):
		return _remember(_result(true, &"handshake_pending", {
			"remaining_milliseconds": int(_handshake_deadline.deadline_milliseconds) - now_milliseconds,
		}))
	_handshake_deadline.active = false
	record_session_end(&"timeout", peer_generation, migration_generation)
	return _remember(_result(false, &"handshake_timeout", {
		"generation": {"peer_generation": peer_generation, "migration_generation": migration_generation},
	}))


func accept_handshake(peer_generation: int, migration_generation: int) -> Dictionary:
	if not bool(_handshake_deadline.get("active", false)):
		return _remember(_result(false, &"handshake_inactive"))
	if peer_generation != int(_handshake_deadline.peer_generation) \
			or migration_generation != int(_handshake_deadline.migration_generation):
		return _remember(_result(false, &"stale_handshake_generation"))
	_reset_handshake_deadline()
	return _remember(_result(true, &"handshake_accepted"))


func get_handshake_deadline_state() -> Dictionary:
	return _handshake_deadline.duplicate(true)


func get_presentation_cursor_audit() -> Dictionary:
	return {
		"capacity_per_category": MAX_PRESENTATION_ENTITIES,
		"moving_interior_count": _moving_replica_samples.size(),
		"projectile_count": _projectile_replica_samples.size(),
		"landing_count": _landing_replica_samples.size(),
		"damage_count": _damage_replica_samples.size(),
		"boarding_count": _boarding_replica_samples.size(),
		"interest_count": _interest_replica_samples.size(),
		"eviction_count": _presentation_evictions,
	}.duplicate(true)


func _reset_session_end_reason() -> void:
	_session_end_reason = {
		"reason": &"unknown",
		"peer_generation": 0,
		"migration_generation": 0,
		"sequence": 0,
	}


func _reset_handshake_deadline() -> void:
	_handshake_deadline = {
		"active": false,
		"deadline_milliseconds": 0,
		"peer_generation": 0,
		"migration_generation": 0,
		"timeout_milliseconds": HANDSHAKE_DEFAULT_TIMEOUT_MILLISECONDS,
	}


func _store_presentation_sample(store: Dictionary, entity_id: StringName, record: Dictionary) -> void:
	if not store.has(entity_id) and store.size() >= MAX_PRESENTATION_ENTITIES:
		var keys: Array = store.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		if not keys.is_empty():
			store.erase(keys[0])
			_presentation_evictions += 1
	store[entity_id] = record.duplicate(true)


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
		var stream_generation := int(_moving_relationship_stream.get_snapshot().get("migration_generation", 1))
		var replica_gate: Dictionary = _moving_replica.accept_snapshot(
			AUTHORITY_PEER_ID,
			raw_relationship as Dictionary,
			stream_generation,
			float(ready.get("server_tick", 0))
		)
		if not bool(replica_gate.get("accepted", false)):
			return _remember(_result(false, replica_gate.get("status", &"replica_rejected")))
		var relationship_gate: Dictionary = _moving_relationship_stream.accept_snapshot(
			AUTHORITY_PEER_ID,
			raw_relationship as Dictionary,
			stream_generation
		)
		if not bool(relationship_gate.get("accepted", false)):
			return _remember(_result(false, relationship_gate.get("status", &"relationship_rejected")))
		if relationship_gate.get("status") == &"gap_hold":
			return _remember(_result(true, &"moving_interior_waiting_for_gap", {
				"samples": _frozen_moving_interior_samples(frame_world_transform),
				"buffered_revision": int(ready.get("revision", 0)),
				"frozen": true,
			}))
		var relationship := MovingInteriorRelationship.from_dictionary(raw_relationship as Dictionary)
		if not relationship.is_valid():
			return _remember(_result(false, &"invalid_moving_interior_relationship"))
		var entity_id := relationship.get_entity_id()
		var prior: Dictionary = _moving_replica_samples.get(entity_id, {})
		var local_transform := relationship.get_frame_local_transform()
		if not prior.is_empty():
			var prior_transform: Transform3D = prior.get("local_transform", Transform3D.IDENTITY)
			local_transform = prior_transform.interpolate_with(local_transform, clampf(alpha, 0.0, 1.0))
		_store_presentation_sample(_moving_replica_samples, entity_id, {
			"revision": int(ready.get("revision", 0)),
			"server_tick": relationship.get_server_tick(),
			"parent_frame_id": relationship.get_parent_frame_id(),
			"parent_frame_generation": relationship.get_parent_frame_generation(),
			"local_transform": local_transform,
		})
		presented.append({
			"revision": int(ready.get("revision", 0)),
			"server_tick": relationship.get_server_tick(),
			"entity_id": entity_id,
			"parent_frame_id": relationship.get_parent_frame_id(),
			"parent_frame_generation": relationship.get_parent_frame_generation(),
			"world_transform": frame_world_transform * local_transform,
		})
	if presented.is_empty():
		return _remember(_result(true, &"moving_interior_waiting_for_gap", {
			"samples": _frozen_moving_interior_samples(frame_world_transform),
			"buffered_revision": int(buffered.get("revision", 0)),
			"frozen": true,
		}))
	return _remember(_result(true, &"moving_interior_presented", {
		"samples": presented,
		"buffered_revision": int(buffered.get("revision", 0)),
	}))


func sample_moving_interior_replica(entity_id: StringName, now_seconds: float) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	return _remember(_moving_replica.sample(entity_id, now_seconds))


func detach_moving_interior_replica(entity_id: StringName) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	var result: Dictionary = _moving_replica.detach_entity(entity_id)
	_moving_replica_binding.detach(entity_id)
	_moving_replica_binding_ids.erase(entity_id)
	return _remember(result)


func bind_moving_interior_replica(
	entity_id: StringName,
	entity_generation: int,
	avatar_node: Node3D,
	frame_node: Node3D,
	frame_generation: int
) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	var result: Dictionary = _moving_replica_binding.bind(
		entity_id, entity_generation, avatar_node, frame_node, frame_generation
	)
	if bool(result.get("accepted", false)):
		_moving_replica_binding_ids[entity_id] = {
			"entity_generation": entity_generation,
			"frame_generation": frame_generation,
		}
	return _remember(result)


func apply_moving_interior_replica(entity_id: StringName, now_seconds: float) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	var sampled: Dictionary = _moving_replica.sample(entity_id, now_seconds)
	if not bool(sampled.get("accepted", false)):
		return _remember(sampled)
	var binding_identity: Dictionary = _moving_replica_binding_ids.get(entity_id, {}) as Dictionary
	if binding_identity.is_empty():
		return _remember(_result(false, &"entity_not_bound"))
	var binding: Dictionary = _moving_replica_binding.apply_sample(
		entity_id,
		sampled,
		int(binding_identity.get("entity_generation", 0)),
		int(binding_identity.get("frame_generation", 0))
	)
	return _remember(binding)


func _frozen_moving_interior_samples(frame_world_transform: Transform3D) -> Array:
	var frozen: Array = []
	for entity_variant in _moving_replica_samples.keys():
		var entity_id := StringName(entity_variant)
		var sample: Dictionary = _moving_replica_samples[entity_id] as Dictionary
		frozen.append({
			"revision": int(sample.get("revision", 0)),
			"server_tick": int(sample.get("server_tick", 0)),
			"entity_id": entity_id,
			"parent_frame_id": StringName(sample.get("parent_frame_id", &"")),
			"parent_frame_generation": int(sample.get("parent_frame_generation", 0)),
			"world_transform": frame_world_transform * (sample.get("local_transform", Transform3D.IDENTITY) as Transform3D),
		})
	return frozen


## Presents server-owned projectile positions only. This is a replica-side
## presentation path; hit resolution and damage remain server authority.
func consume_projectile_snapshot(packet: Dictionary, alpha: float = 1.0) -> Dictionary:
	if not packet.has("revision") or not packet.has("server_tick") \
			or not packet.has("projectile"):
		return _remember(_result(false, &"invalid_projectile_snapshot"))
	if not is_finite(alpha):
		return _remember(_result(false, &"invalid_interpolation_alpha"))
	var projectile_variant: Variant = packet.get("projectile")
	if not projectile_variant is Dictionary:
		return _remember(_result(false, &"invalid_projectile_snapshot"))
	var projectile := projectile_variant as Dictionary
	var projectile_id := StringName(projectile.get("projectile_id", &""))
	var position_variant: Variant = projectile.get("position")
	if projectile_id.is_empty() or not position_variant is Vector3 \
			or not (position_variant as Vector3).is_finite():
		return _remember(_result(false, &"invalid_projectile_snapshot"))
	var buffered: Dictionary = _projectile_jitter.push(packet)
	if not bool(buffered.get("accepted", false)):
		return _remember(_result(false, StringName(buffered.get("status", &"buffer_rejected"))))
	var presented: Array = []
	while true:
		var ready: Dictionary = _projectile_jitter.pop_ready()
		if ready.is_empty():
			break
		var ready_variant: Variant = ready.get("projectile")
		if not ready_variant is Dictionary:
			return _remember(_result(false, &"invalid_projectile_snapshot"))
		var ready_projectile := ready_variant as Dictionary
		var ready_id := StringName(ready_projectile.get("projectile_id", &""))
		var ready_position_variant: Variant = ready_projectile.get("position")
		if ready_id.is_empty() or not ready_position_variant is Vector3 \
				or not (ready_position_variant as Vector3).is_finite():
			return _remember(_result(false, &"invalid_projectile_snapshot"))
		var position: Vector3 = ready_position_variant as Vector3
		var prior: Dictionary = _projectile_replica_samples.get(ready_id, {})
		if not prior.is_empty():
			position = (prior.get("position", position) as Vector3).lerp(
				position, clampf(alpha, 0.0, 1.0)
			)
		_store_presentation_sample(_projectile_replica_samples, ready_id, {
			"revision": int(ready.get("revision", 0)),
			"server_tick": int(ready.get("server_tick", 0)),
			"position": position,
		})
		presented.append({
			"revision": int(ready.get("revision", 0)),
			"server_tick": int(ready.get("server_tick", 0)),
			"projectile_id": ready_id,
			"position": position,
		})
	if presented.is_empty():
		var frozen: Array = []
		for projectile_key in _projectile_replica_samples.keys():
			var sample: Dictionary = _projectile_replica_samples[projectile_key] as Dictionary
			frozen.append({
				"revision": int(sample.get("revision", 0)),
				"server_tick": int(sample.get("server_tick", 0)),
				"projectile_id": StringName(projectile_key),
				"position": sample.get("position", Vector3.ZERO),
			})
		return _remember(_result(true, &"projectile_waiting_for_gap", {
			"samples": frozen,
			"frozen": true,
		}))
	return _remember(_result(true, &"projectile_presented", {"samples": presented}))


func get_snapshot_jitter_state() -> Dictionary:
	return _snapshot_jitter.get_snapshot()


## Detached session-quality counters; these are observations, never admission
## or authority inputs. Every presentation cursor resets with migration.
func get_session_quality_telemetry() -> Dictionary:
	var buffers: Array = [_snapshot_jitter, _projectile_jitter, _landing_jitter,
		_damage_jitter, _boarding_jitter, _migration_jitter, _interest_jitter]
	var aggregate := {
		"accepted_count": 0,
		"released_count": 0,
		"stale_rejection_count": 0,
		"gap_rejection_count": 0,
		"pending_depth": 0,
		"max_pending_depth": 0,
		"buffer_count": buffers.size(),
	}
	for buffer in buffers:
		var telemetry: Dictionary = buffer.get_telemetry()
		for key in [&"accepted_count", &"released_count", &"stale_rejection_count", &"gap_rejection_count", &"pending_depth"]:
			aggregate[key] = int(aggregate[key]) + int(telemetry.get(key, 0))
		aggregate.max_pending_depth = maxi(int(aggregate.max_pending_depth), int(telemetry.get("max_pending_depth", 0)))
	return aggregate.duplicate(true)


## Tracks replica presentation lifetime for interest entries. This cache never
## grants replication authority and retired revisions cannot resurrect state.
func consume_interest_snapshot(packet: Dictionary) -> Dictionary:
	if not packet.has("revision") or not packet.has("server_tick") \
			or not packet.has("interest"):
		return _remember(_result(false, &"invalid_interest_snapshot"))
	var interest_variant: Variant = packet.get("interest")
	if not interest_variant is Dictionary:
		return _remember(_result(false, &"invalid_interest_snapshot"))
	var buffered: Dictionary = _interest_jitter.push(packet)
	if not bool(buffered.get("accepted", false)):
		return _remember(_result(false, StringName(buffered.get("status", &"buffer_rejected"))))
	var presented: Array = []
	while true:
		var ready: Dictionary = _interest_jitter.pop_ready()
		if ready.is_empty():
			break
		var ready_interest := ready.get("interest", {}) as Dictionary
		var entity_id := StringName(ready_interest.get("entity_id", &""))
		var state_revision := int(ready_interest.get("state_revision", 0))
		if entity_id.is_empty() or state_revision <= 0:
			return _remember(_result(false, &"invalid_interest_snapshot"))
		var revision := int(ready.get("revision", 0))
		var retired_revision := int(_interest_retired_revisions.get(entity_id, -1))
		if revision <= retired_revision:
			return _remember(_result(false, &"stale_interest_entity"))
		var in_interest := bool(ready_interest.get("in_interest", false))
		if not in_interest:
			_interest_replica_samples.erase(entity_id)
			_interest_retired_revisions[entity_id] = revision
			presented.append({"revision": revision, "entity_id": entity_id, "in_interest": false})
			continue
		var entered := not _interest_replica_samples.has(entity_id)
		var record := {
			"revision": revision,
			"server_tick": int(ready.get("server_tick", 0)),
			"state_revision": state_revision,
			"entity_id": entity_id,
			"in_interest": true,
			"entered": entered,
			"state": (ready_interest.get("state", {}) as Dictionary).duplicate(true),
		}
		_store_presentation_sample(_interest_replica_samples, entity_id, record)
		presented.append(record)
	if presented.is_empty():
		return _remember(_result(true, &"interest_waiting_for_gap", {"samples": [], "frozen": true}))
	return _remember(_result(true, &"interest_presented", {"samples": presented}))


## Presents migration/session metadata only. A new generation retires all
## prior presentation cursors; admission and host authority stay server-owned.
func consume_migration_session_snapshot(packet: Dictionary) -> Dictionary:
	if not packet.has("revision") or not packet.has("server_tick") \
			or not packet.has("migration_generation") or not packet.has("session"):
		return _remember(_result(false, &"invalid_migration_snapshot"))
	var generation := int(packet.get("migration_generation", 0))
	if generation <= 0:
		return _remember(_result(false, &"invalid_migration_snapshot"))
	if _migration_replica_generation > 0 and generation < _migration_replica_generation:
		return _remember(_result(false, &"stale_migration_generation"))
	if generation != _migration_replica_generation:
		_migration_replica_generation = generation
		_migration_replica_samples.clear()
		_migration_jitter.reset(generation)
	var session_variant: Variant = packet.get("session")
	if not session_variant is Dictionary:
		return _remember(_result(false, &"invalid_migration_snapshot"))
	var buffered: Dictionary = _migration_jitter.push(packet)
	if not bool(buffered.get("accepted", false)):
		return _remember(_result(false, StringName(buffered.get("status", &"buffer_rejected"))))
	var presented: Array = []
	while true:
		var ready: Dictionary = _migration_jitter.pop_ready()
		if ready.is_empty():
			break
		var ready_session: Variant = ready.get("session")
		if not ready_session is Dictionary:
			return _remember(_result(false, &"invalid_migration_snapshot"))
		var record := (ready_session as Dictionary).duplicate(true)
		record["revision"] = int(ready.get("revision", 0))
		record["server_tick"] = int(ready.get("server_tick", 0))
		record["migration_generation"] = generation
		_migration_replica_samples = record.duplicate(true)
		presented.append(record)
	if presented.is_empty():
		return _remember(_result(true, &"migration_waiting_for_gap", {
			"samples": [_migration_replica_samples.duplicate(true)] if not _migration_replica_samples.is_empty() else [],
			"frozen": true,
		}))
	return _remember(_result(true, &"migration_presented", {"samples": presented}))


## Presents occupancy and ownership records only. Seat claims and ship-owner
## changes remain server-authoritative; a gap freezes the last presentation.
func consume_boarding_ownership_snapshot(packet: Dictionary) -> Dictionary:
	if not packet.has("revision") or not packet.has("server_tick") \
			or not packet.has("boarding") or not packet.has("ownership"):
		return _remember(_result(false, &"invalid_boarding_snapshot"))
	var boarding_variant: Variant = packet.get("boarding")
	var ownership_variant: Variant = packet.get("ownership")
	if not boarding_variant is Dictionary or not ownership_variant is Dictionary:
		return _remember(_result(false, &"invalid_boarding_snapshot"))
	var buffered: Dictionary = _boarding_jitter.push(packet)
	if not bool(buffered.get("accepted", false)):
		return _remember(_result(false, StringName(buffered.get("status", &"buffer_rejected"))))
	var presented: Array = []
	while true:
		var ready: Dictionary = _boarding_jitter.pop_ready()
		if ready.is_empty():
			break
		var ready_boarding: Variant = ready.get("boarding")
		var ready_ownership: Variant = ready.get("ownership")
		if not ready_boarding is Dictionary or not ready_ownership is Dictionary:
			return _remember(_result(false, &"invalid_boarding_snapshot"))
		var boarding := ready_boarding as Dictionary
		var ownership := ready_ownership as Dictionary
		var ship_id := StringName(ownership.get("ship_id", &""))
		var seat_id := StringName(boarding.get("seat_id", &""))
		if ship_id.is_empty() or seat_id.is_empty() \
				or StringName(boarding.get("ship_id", &"")) != ship_id:
			return _remember(_result(false, &"invalid_boarding_snapshot"))
		var record := {
			"revision": int(ready.get("revision", 0)),
			"server_tick": int(ready.get("server_tick", 0)),
			"ship_id": ship_id,
			"owner_peer_id": int(ownership.get("owner_peer_id", 0)),
			"seat_id": seat_id,
			"seat_occupied": bool(boarding.get("occupied", false)),
		}
		_store_presentation_sample(_boarding_replica_samples, ship_id, record)
		presented.append(record)
	if presented.is_empty():
		var frozen: Array = []
		for ship_variant in _boarding_replica_samples.keys():
			frozen.append((_boarding_replica_samples[ship_variant] as Dictionary).duplicate(true))
		return _remember(_result(true, &"boarding_waiting_for_gap", {"samples": frozen, "frozen": true}))
	return _remember(_result(true, &"boarding_presented", {"samples": presented}))


## Presents damage/respawn state only; health mutation and lifecycle remain
## server-owned. Delayed updates freeze the last known presentation.
func consume_damage_respawn_snapshot(packet: Dictionary, alpha: float = 1.0) -> Dictionary:
	if not packet.has("revision") or not packet.has("server_tick") \
			or not packet.has("damage") or not is_finite(alpha):
		return _remember(_result(false, &"invalid_damage_snapshot"))
	var damage_variant: Variant = packet.get("damage")
	if not damage_variant is Dictionary:
		return _remember(_result(false, &"invalid_damage_snapshot"))
	var damage := damage_variant as Dictionary
	var entity_id := StringName(damage.get("entity_id", &""))
	var health := float(damage.get("health", NAN))
	if entity_id.is_empty() or not is_finite(health):
		return _remember(_result(false, &"invalid_damage_snapshot"))
	var buffered: Dictionary = _damage_jitter.push(packet)
	if not bool(buffered.get("accepted", false)):
		return _remember(_result(false, StringName(buffered.get("status", &"buffer_rejected"))))
	var presented: Array = []
	while true:
		var ready: Dictionary = _damage_jitter.pop_ready()
		if ready.is_empty():
			break
		var ready_variant: Variant = ready.get("damage")
		if not ready_variant is Dictionary:
			return _remember(_result(false, &"invalid_damage_snapshot"))
		var ready_damage := ready_variant as Dictionary
		var ready_id := StringName(ready_damage.get("entity_id", &""))
		var ready_health := float(ready_damage.get("health", NAN))
		if ready_id.is_empty() or not is_finite(ready_health):
			return _remember(_result(false, &"invalid_damage_snapshot"))
		var displayed_health := ready_health
		var prior: Dictionary = _damage_replica_samples.get(ready_id, {})
		if not prior.is_empty():
			displayed_health = lerpf(float(prior.get("health", ready_health)), ready_health, clampf(alpha, 0.0, 1.0))
		var state := StringName(ready_damage.get("state", &"active"))
		_store_presentation_sample(_damage_replica_samples, ready_id, {
			"revision": int(ready.get("revision", 0)),
			"server_tick": int(ready.get("server_tick", 0)),
			"health": displayed_health,
			"state": state,
		})
		presented.append({
			"revision": int(ready.get("revision", 0)),
			"server_tick": int(ready.get("server_tick", 0)),
			"entity_id": ready_id,
			"health": displayed_health,
			"state": state,
		})
	if presented.is_empty():
		var frozen: Array = []
		for entity_variant in _damage_replica_samples.keys():
			var sample: Dictionary = _damage_replica_samples[entity_variant] as Dictionary
			frozen.append({
				"revision": int(sample.get("revision", 0)),
				"server_tick": int(sample.get("server_tick", 0)),
				"entity_id": StringName(entity_variant),
				"health": float(sample.get("health", 0.0)),
				"state": sample.get("state", &"active"),
			})
		return _remember(_result(true, &"damage_waiting_for_gap", {"samples": frozen, "frozen": true}))
	return _remember(_result(true, &"damage_presented", {"samples": presented}))


## Presents landing/support state only; landing acceptance and support remain
## server-owned. Delayed packets freeze the last pose until the gap recovers.
func consume_landing_snapshot(packet: Dictionary, alpha: float = 1.0) -> Dictionary:
	if not packet.has("revision") or not packet.has("server_tick") \
			or not packet.has("landing") or not is_finite(alpha):
		return _remember(_result(false, &"invalid_landing_snapshot"))
	var landing_variant: Variant = packet.get("landing")
	if not landing_variant is Dictionary:
		return _remember(_result(false, &"invalid_landing_snapshot"))
	var landing := landing_variant as Dictionary
	var entity_id := StringName(landing.get("entity_id", &""))
	var position_variant: Variant = landing.get("position")
	if entity_id.is_empty() or not position_variant is Vector3 \
			or not (position_variant as Vector3).is_finite():
		return _remember(_result(false, &"invalid_landing_snapshot"))
	var buffered: Dictionary = _landing_jitter.push(packet)
	if not bool(buffered.get("accepted", false)):
		return _remember(_result(false, StringName(buffered.get("status", &"buffer_rejected"))))
	var presented: Array = []
	while true:
		var ready: Dictionary = _landing_jitter.pop_ready()
		if ready.is_empty():
			break
		var ready_landing_variant: Variant = ready.get("landing")
		if not ready_landing_variant is Dictionary:
			return _remember(_result(false, &"invalid_landing_snapshot"))
		var ready_landing := ready_landing_variant as Dictionary
		var ready_id := StringName(ready_landing.get("entity_id", &""))
		var ready_position_variant: Variant = ready_landing.get("position")
		if ready_id.is_empty() or not ready_position_variant is Vector3 \
				or not (ready_position_variant as Vector3).is_finite():
			return _remember(_result(false, &"invalid_landing_snapshot"))
		var position: Vector3 = ready_position_variant as Vector3
		var prior: Dictionary = _landing_replica_samples.get(ready_id, {})
		if not prior.is_empty():
			position = (prior.get("position", position) as Vector3).lerp(
				position, clampf(alpha, 0.0, 1.0)
			)
		_store_presentation_sample(_landing_replica_samples, ready_id, {
			"revision": int(ready.get("revision", 0)),
			"server_tick": int(ready.get("server_tick", 0)),
			"position": position,
			"state": StringName(ready_landing.get("state", &"flying")),
		})
		presented.append({
			"revision": int(ready.get("revision", 0)),
			"server_tick": int(ready.get("server_tick", 0)),
			"entity_id": ready_id,
			"state": StringName(ready_landing.get("state", &"flying")),
			"position": position,
		})
	if presented.is_empty():
		var frozen: Array = []
		for entity_variant in _landing_replica_samples.keys():
			var sample: Dictionary = _landing_replica_samples[entity_variant] as Dictionary
			frozen.append({
				"revision": int(sample.get("revision", 0)),
				"server_tick": int(sample.get("server_tick", 0)),
				"entity_id": StringName(entity_variant),
				"state": sample.get("state", &"flying"),
				"position": sample.get("position", Vector3.ZERO),
			})
		return _remember(_result(true, &"landing_waiting_for_gap", {
			"samples": frozen,
			"frozen": true,
		}))
	return _remember(_result(true, &"landing_presented", {"samples": presented}))


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
		AUTHORITY_PEER_ID, directory_generation, server_tick, _decorate_hosted_directory(entries)
	)
	if bool(result.get("accepted", false)):
		_hosted_directory_entries = entries.duplicate(true)
		_hosted_directory_generation = directory_generation
		_hosted_directory_tick = server_tick
	server_browser_result.emit(result.duplicate(true))
	return _remember(result)


func _decorate_hosted_directory(entries: Array) -> Array:
	var decorated: Array = []
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null else AUTHORITY_PEER_ID
	var capacity := get_session_capacity_snapshot()
	var capacity_generation := int(_migration.get_snapshot().get("migration_generation", 1))
	for raw_entry in entries:
		var entry := (raw_entry as Dictionary).duplicate(true) if raw_entry is Dictionary else {}
		if int(entry.get("host_peer_id", 0)) == local_peer_id:
			entry["player_count"] = int(capacity.get("occupancy", 0))
			entry["max_players"] = int(capacity.get("max_players", 0))
			entry["available_slots"] = int(capacity.get("available_slots", 0))
			entry["capacity_generation"] = capacity_generation
			entry["protocol_version"] = NETWORK_PROTOCOL_VERSION
			entry["build_version"] = NETWORK_BUILD_VERSION
		decorated.append(entry)
	return decorated


func _refresh_hosted_directory() -> void:
	if not is_server() or _hosted_directory_entries.is_empty():
		return
	var result: Dictionary = _server_browser.publish_snapshot(
		AUTHORITY_PEER_ID, _hosted_directory_generation, _hosted_directory_tick,
		_decorate_hosted_directory(_hosted_directory_entries)
	)
	server_browser_result.emit(result.duplicate(true))


func apply_server_directory_snapshot(directory_generation: int, server_tick: int, entries: Array) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
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


func expire_server_directory(server_tick: int) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	var result: Dictionary = _server_browser.expire_stale(AUTHORITY_PEER_ID, server_tick)
	server_browser_result.emit(result.duplicate(true))
	return _remember(result)


func query_server_directory(region_filter: StringName = &"", max_ping_ms: int = -1, include_full: bool = true) -> Array:
	return _server_browser.query(region_filter, max_ping_ms, include_full)


func query_compatible_server_directory(region_filter: StringName = &"", max_ping_ms: int = -1, include_full: bool = true) -> Dictionary:
	var compatible: Array = []
	var incompatible: Array = []
	for entry in _server_browser.query(region_filter, max_ping_ms, include_full):
		var checked := _check_directory_compatibility(entry)
		if bool(checked.get("compatible", false)):
			compatible.append(entry)
		else:
			var rejected: Dictionary = entry.duplicate(true)
			rejected["incompatible_reason"] = checked.get("reason", &"unknown_protocol")
			incompatible.append(rejected)
	return {"compatible": compatible, "incompatible": incompatible}


func _check_directory_compatibility(entry: Dictionary) -> Dictionary:
	if not entry.has("protocol_version") or not entry.has("build_version"):
		return {"compatible": false, "reason": &"unknown_protocol"}
	if int(entry.get("protocol_version", 0)) != NETWORK_PROTOCOL_VERSION:
		return {"compatible": false, "reason": &"protocol_mismatch"}
	if int(entry.get("build_version", 0)) != NETWORK_BUILD_VERSION:
		return {"compatible": false, "reason": &"build_mismatch"}
	return {"compatible": true, "reason": &"compatible"}


func detach_server_directory() -> Dictionary:
	var result: Dictionary = _server_browser.detach(AUTHORITY_PEER_ID)
	server_browser_result.emit(result.duplicate(true))
	return _remember(result)


func create_join_intent(session_id: StringName) -> Dictionary:
	var entry: Dictionary = _server_browser.get_session(session_id)
	if entry.is_empty():
		return _remember(_result(false, &"session_not_found"))
	var compatibility := _check_directory_compatibility(entry)
	if not bool(compatibility.get("compatible", false)):
		return _remember(_result(false, compatibility.get("reason", &"unknown_protocol")))
	if int(entry.get("player_count", 0)) >= int(entry.get("max_players", 0)):
		return _remember(_result(false, &"session_full"))
	var sequence := _next_join_intent_sequence
	_next_join_intent_sequence += 1
	return _remember(_result(true, &"join_intent_created", {
		"intent": {
			"session_id": session_id,
			"host_peer_id": int(entry.get("host_peer_id", 0)),
			"directory_generation": int(entry.get("directory_generation", 0)),
			"intent_sequence": sequence,
		},
	}))


func consume_join_intent(intent: Dictionary, address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"client_required"))
	var session_id := StringName(intent.get("session_id", &""))
	var generation := int(intent.get("directory_generation", 0))
	var sequence := int(intent.get("intent_sequence", 0))
	if session_id.is_empty() or generation <= 0 or sequence <= 0:
		return _remember(_result(false, &"invalid_join_intent"))
	if sequence <= _last_join_intent_sequence:
		return _remember(_result(false, &"stale_join_intent"))
	var entry: Dictionary = _server_browser.get_session(session_id)
	if entry.is_empty():
		return _remember(_result(false, &"session_not_found"))
	var compatibility := _check_directory_compatibility(entry)
	if not bool(compatibility.get("compatible", false)):
		return _remember(_result(false, compatibility.get("reason", &"unknown_protocol")))
	if generation != int(entry.get("directory_generation", 0)):
		return _remember(_result(false, &"stale_join_intent_generation"))
	_last_join_intent_sequence = sequence
	return request_join_advertised_session(session_id, address, port)


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
	var compatibility := _check_directory_compatibility(entry)
	if not bool(compatibility.get("compatible", false)):
		return _remember(_result(false, compatibility.get("reason", &"unknown_protocol")))
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


func publish_crew_snapshot(command_receipts: Array = []) -> Dictionary:
	if not is_server():
		return _remember(_result(false, &"authority_required"))
	var encoded: Dictionary = _crew_snapshot_codec.encode(
		_crew_roles.get_snapshot(), _crew_commands.get_snapshot(), command_receipts
	)
	if not bool(encoded.get("accepted", false)):
		return _remember(encoded)
	_crew_snapshot_revision += 1
	var generation := int(_migration.get_snapshot().get("migration_generation", 1))
	var role_snapshot: Dictionary = _crew_roles.get_snapshot()
	var command_snapshot: Dictionary = _crew_commands.get_snapshot()
	for peer_variant in _peer_generations.keys():
		var recipient := int(peer_variant)
		var filtered := _crew_snapshot_for_peer(recipient, role_snapshot, command_receipts)
		var filtered_encoded: Dictionary = _crew_snapshot_codec.encode(
			filtered.roles, command_snapshot, filtered.receipts
		)
		if not bool(filtered_encoded.get("accepted", false)):
			continue
		var wire := {"crew_snapshot": (filtered_encoded.bytes as PackedByteArray).get_string_from_utf8()}
		for fragment in _crew_snapshot_fragmenter.fragment(wire, generation, _crew_snapshot_revision):
			_broadcast_crew_snapshot_fragment.rpc_id(recipient, fragment)
	var snapshot := {"revision": _crew_snapshot_revision, "generation": generation, "entry_count": encoded.get("entry_count", 0)}
	crew_snapshot_published.emit(snapshot.duplicate(true))
	return _remember(_result(true, &"crew_snapshot_published", snapshot))


func get_crew_replica_snapshot() -> Dictionary:
	return _crew_replica_snapshot.duplicate(true)


func _crew_snapshot_for_peer(recipient_peer_id: int, role_snapshot: Dictionary, receipts: Array) -> Dictionary:
	var ship_ids: Dictionary = {}
	var roles: Dictionary = {}
	for key_variant in (role_snapshot.get("roles", {}) as Dictionary).keys():
		var role := (role_snapshot.roles[key_variant] as Dictionary).duplicate(true)
		if int(role.get("peer_id", 0)) == recipient_peer_id:
			ship_ids[StringName(role.get("ship_id", &""))] = true
	for key_variant in (role_snapshot.get("roles", {}) as Dictionary).keys():
		var role := (role_snapshot.roles[key_variant] as Dictionary).duplicate(true)
		if ship_ids.has(StringName(role.get("ship_id", &""))):
			roles[key_variant] = role
	var filtered_receipts: Array = []
	for receipt_variant in receipts:
		var receipt := receipt_variant as Dictionary
		var command := receipt.get("receipt", receipt) as Dictionary
		if int(command.get("peer_id", 0)) == recipient_peer_id \
			or ship_ids.has(StringName(command.get("ship_id", &""))):
			filtered_receipts.append(receipt.duplicate(true))
	var filtered_roles := role_snapshot.duplicate(true)
	filtered_roles["roles"] = roles
	return {"roles": filtered_roles, "receipts": filtered_receipts}


@rpc("any_peer", "reliable")
func _receive_movement_intent(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var payload := _accept_secure_rpc(source_peer_id, wire, &"movement")
	if payload.is_empty():
		return
	if not (_remote_ship_commands.get_snapshot().get("pilots", []) as Array).is_empty():
		var remote_result: Dictionary = _remote_ship_commands.accept_command(source_peer_id, payload)
		movement_intent_result.emit(remote_result.duplicate(true))
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
func _receive_crew_role_intent(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var payload := _accept_secure_rpc(source_peer_id, wire, &"crew_role")
	if payload.is_empty():
		return
	var peer_generation := int(_peer_generations.get(source_peer_id, 0))
	var result: Dictionary = _crew_roles.accept_role_intent(
		AUTHORITY_PEER_ID,
		source_peer_id,
		peer_generation,
		StringName(payload.get("avatar_id", &"")),
		StringName(payload.get("requested_role", &"")),
		int(payload.get("request_sequence", 0)),
		StringName(payload.get("ship_id", &"")),
		int(payload.get("ship_generation", 0))
	)
	crew_role_result.emit(result.duplicate(true))


@rpc("any_peer", "reliable")
func _receive_crew_command(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	var payload := _accept_secure_rpc(source_peer_id, wire, &"crew_command")
	if payload.is_empty():
		return
	var command_payload: Dictionary = payload.get("payload", {}) as Dictionary
	var result: Dictionary = _crew_commands.accept_command(
		AUTHORITY_PEER_ID,
		source_peer_id,
		int(_peer_generations.get(source_peer_id, 0)),
		StringName(payload.get("avatar_id", &"")),
		StringName(payload.get("action", &"")),
		int(payload.get("request_sequence", 0)),
		int(payload.get("server_tick", -1)),
		command_payload,
		StringName(payload.get("ship_id", &"")),
		int(payload.get("ship_generation", 0))
	)
	crew_command_result.emit(result.duplicate(true))


@rpc("any_peer", "reliable")
func _receive_hello(wire: Dictionary) -> void:
	if not is_server():
		return
	var source_peer_id := multiplayer.get_remote_sender_id()
	if not _peer_generations.has(source_peer_id) and _peer_generations.size() >= _session_max_clients:
		transport_rejected.emit(&"session_full")
		return
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
	_peer_keepalive_deadlines[peer_id] = Time.get_ticks_msec() + _keepalive_timeout_milliseconds
	_crew_roles.admit_peer(AUTHORITY_PEER_ID, peer_id, peer_generation)
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
		"capacity": get_session_capacity_snapshot(),
	}
	_send_server_offer.rpc_id(source_peer_id, offer)
	peer_admitted.emit(peer_id, offer.duplicate(true))
	_refresh_hosted_directory()


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
func _broadcast_moving_interior_snapshot(packet: Dictionary) -> void:
	if is_server():
		return
	if not packet.has("revision") or not packet.has("server_tick") \
			or not packet.has("relationship") or not packet.has("migration_generation"):
		moving_interior_result.emit(_result(false, &"invalid_moving_interior_snapshot"))
		return
	var generation := int(packet.get("migration_generation", 0))
	var current_generation := int(_moving_relationship_stream.get_snapshot().get("migration_generation", 1))
	if generation != current_generation:
		moving_interior_result.emit(_result(false, &"stale_migration_generation"))
		return
	var applied := consume_moving_interior_snapshot(packet)
	moving_interior_result.emit(applied.duplicate(true))
	_last_result = applied.duplicate(true)


@rpc("authority", "call_remote", "reliable")
func _broadcast_moving_interior_release(packet: Dictionary) -> void:
	if is_server():
		return
	var entity_id := StringName(packet.get("entity_id", &""))
	if entity_id.is_empty() or int(packet.get("entity_generation", 0)) <= 0:
		return
	_moving_replica.detach_entity(entity_id)
	_moving_replica_samples.erase(entity_id)
	_moving_replica_binding.detach(entity_id)
	_moving_replica_binding_ids.erase(entity_id)
	moving_interior_result.emit(_result(true, &"moving_interior_release_applied", {"entity_id": entity_id}))


@rpc("authority", "call_remote", "reliable")
func _send_projectile_snapshot(packet: Dictionary) -> void:
	if is_server():
		return
	_apply_projectile_replica_snapshot(packet)


func _apply_projectile_replica_snapshot(packet: Dictionary) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"authority_required"))
	if not packet.has("revision") or not packet.has("server_tick") \
			or not packet.has("migration_generation") \
			or not packet.has("projectile") or not packet.has("terminal"):
		return _remember(_result(false, &"invalid_projectile_snapshot"))
	if Marshalls.variant_to_base64(packet).to_utf8_buffer().size() > MAX_PROJECTILE_REPLICATION_PACKET_BYTES:
		return _remember(_result(false, &"projectile_packet_too_large"))
	var migration_generation := int(packet.get("migration_generation", 0))
	if migration_generation < _projectile_replica_migration_generation:
		return _remember(_result(false, &"stale_migration_generation"))
	if migration_generation > _projectile_replica_migration_generation:
		_projectile_jitter.reset(1)
		_projectile_replica_samples.clear()
		_projectile_replica_generations.clear()
		_projectile_replica_ticks.clear()
		_projectile_replica_revision = 0
		_projectile_replica_migration_generation = migration_generation
	var projectile: Dictionary = packet.get("projectile", {}) as Dictionary
	var validation := _validate_projectile_replica_snapshot(projectile)
	if not bool(validation.get("accepted", false)):
		return _remember(validation)
	var projectile_id := StringName(projectile.get("projectile_id", &""))
	var generation := int(projectile.get("projectile_generation", 0))
	var prior_generation := int(_projectile_replica_generations.get(projectile_id, 0))
	if generation < prior_generation:
		return _remember(_result(false, &"stale_projectile_generation"))
	var server_tick := int(projectile.get("last_update_tick", 0))
	if server_tick < int(_projectile_replica_ticks.get(projectile_id, -1)):
		return _remember(_result(false, &"stale_projectile_tick"))
	if generation > prior_generation:
		_projectile_replica_samples.erase(projectile_id)
		_projectile_replica_generations[projectile_id] = generation
	_projectile_replica_ticks[projectile_id] = server_tick
	if bool(packet.get("terminal", false)) or StringName(projectile.get("state", &"")) != &"flying":
		_projectile_replica_samples.erase(projectile_id)
		_projectile_replica_revision += 1
		return _remember(_result(true, &"projectile_terminal_applied", {
			"projectile_id": projectile_id,
			"state": StringName(projectile.get("state", &"")),
		}))
	var local_packet := packet.duplicate(true)
	_projectile_replica_revision += 1
	local_packet["revision"] = _projectile_replica_revision
	var applied := consume_projectile_snapshot(local_packet)
	return _remember(applied)


@rpc("authority", "call_remote", "reliable")
func _send_damage_respawn_snapshot(packet: Dictionary) -> void:
	if is_server():
		return
	var applied := consume_damage_respawn_snapshot(packet)
	damage_respawn_result.emit(applied.duplicate(true))
	_last_result = applied.duplicate(true)


@rpc("authority", "call_remote", "reliable")
func _send_landing_snapshot(packet: Dictionary) -> void:
	if is_server():
		return
	var applied := consume_landing_snapshot(packet)
	landing_intent_result.emit(applied.duplicate(true))
	_last_result = applied.duplicate(true)


@rpc("authority", "call_remote", "reliable")
func _send_boarding_snapshot(packet: Dictionary) -> void:
	if is_server():
		return
	var applied := consume_boarding_ownership_snapshot(packet)
	seat_occupancy_result.emit(applied.duplicate(true))
	_last_result = applied.duplicate(true)


@rpc("authority", "call_remote", "reliable")
func _send_remote_ship_pilot_resync(packet: Dictionary) -> void:
	if is_server():
		return
	var generation := int(packet.get("migration_generation", 0))
	if generation <= 0 or not packet.get("pilot", {}) is Dictionary:
		return
	var current := int(_remote_pilot_replica.get("migration_generation", 0))
	if generation < current:
		return
	_remote_pilot_replica = {
		"migration_generation": generation,
		"pilot": (packet.get("pilot", {}) as Dictionary).duplicate(true),
		"presentation_only": true,
	}


@rpc("authority", "call_remote", "reliable")
func _send_moving_interior_resync(packet: Dictionary) -> void:
	_apply_moving_interior_resync(packet)


func _apply_moving_interior_resync(packet: Dictionary) -> Dictionary:
	if is_server():
		return _remember(_result(false, &"authority_required"))
	if not packet.has("authority_peer_id") or not packet.has("recipient_peer_id") \
			or not packet.has("migration_generation") or not packet.has("revision") \
			or not packet.has("relationships"):
		return _remember(_result(false, &"invalid_moving_interior_resync"))
	if int(packet.get("authority_peer_id", 0)) != AUTHORITY_PEER_ID:
		return _remember(_result(false, &"foreign_moving_interior_resync"))
	if _configured and multiplayer.get_unique_id() != int(packet.get("recipient_peer_id", 0)):
		return _remember(_result(false, &"foreign_moving_interior_resync"))
	if Marshalls.variant_to_base64(packet).to_utf8_buffer().size() > MAX_MOVING_INTERIOR_PACKET_BYTES:
		return _remember(_result(false, &"moving_interior_packet_too_large"))
	var resync_revision := int(packet.get("revision", 0))
	if resync_revision < _moving_resync_revision:
		return _remember(_result(false, &"stale_moving_interior_resync"))
	var relationships_variant: Variant = packet.get("relationships")
	if not relationships_variant is Array or (relationships_variant as Array).size() > 128:
		return _remember(_result(false, &"invalid_moving_interior_resync"))
	var released_list_variant: Variant = packet.get("released_entities", [])
	if not released_list_variant is Array or (released_list_variant as Array).size() > 128:
		return _remember(_result(false, &"invalid_moving_interior_resync"))
	var generation := int(packet.get("migration_generation", 0))
	var current_generation := int(_moving_relationship_stream.get_snapshot().get("migration_generation", 1))
	if generation < current_generation:
		return _remember(_result(false, &"stale_migration_generation"))
	if generation > current_generation:
		var reset_result := reset_snapshot_jitter(generation)
		if not bool(reset_result.get("accepted", false)):
			return _remember(reset_result)
	var applied_count := 0
	for relationship_variant in relationships_variant as Array:
		if not relationship_variant is Dictionary:
			return _remember(_result(false, &"invalid_moving_interior_relationship"))
		var next_revision := int(_snapshot_jitter.get_snapshot().get("next_revision", 1))
		var relationship := relationship_variant as Dictionary
		var applied := consume_moving_interior_snapshot({
			"revision": next_revision,
			"server_tick": int(relationship.get("server_tick", -1)),
			"relationship": relationship,
		})
		if not bool(applied.get("accepted", false)):
			return _remember(_result(false, applied.get("status", &"moving_interior_resync_rejected")))
		applied_count += 1
	for released_item in released_list_variant as Array:
		if not released_item is String and not released_item is StringName:
			return _remember(_result(false, &"invalid_moving_interior_resync"))
		var released_id := StringName(released_item)
		_moving_replica.detach_entity(released_id)
		_moving_replica_samples.erase(released_id)
		_moving_replica_binding.detach(released_id)
		_moving_replica_binding_ids.erase(released_id)
	_moving_resync_revision = resync_revision
	return _remember(_result(true, &"moving_interior_resync_applied", {
		"generation": generation,
		"relationship_count": applied_count,
		"released_count": (released_list_variant as Array).size(),
	}))


@rpc("authority", "call_remote", "reliable")
func _broadcast_crew_snapshot_fragment(fragment: Dictionary) -> void:
	if is_server():
		return
	var reassembled: Dictionary = _crew_snapshot_fragmenter.accept(fragment, Time.get_ticks_msec())
	if not bool(reassembled.get("accepted", false)) or reassembled.get("status") != &"reassembled":
		return
	var generation := int(fragment.get("generation", 0))
	var revision := int(fragment.get("revision", 0))
	var current_generation := int(_migration.get_snapshot().get("migration_generation", 1))
	if generation != current_generation or revision <= _crew_snapshot_revision:
		crew_snapshot_applied.emit(_result(false, &"stale_crew_snapshot"))
		return
	var packet: Dictionary = reassembled.get("packet", {}) as Dictionary
	var encoded_text := String(packet.get("crew_snapshot", ""))
	var decoded: Dictionary = _crew_snapshot_codec.decode(encoded_text.to_utf8_buffer())
	if not bool(decoded.get("accepted", false)):
		crew_snapshot_applied.emit(decoded.duplicate(true))
		return
	_crew_snapshot_revision = revision
	_crew_replica_snapshot = decoded.get("snapshot", {}).duplicate(true)
	var applied := _result(true, &"crew_snapshot_applied", {"revision": revision, "snapshot": _crew_replica_snapshot})
	crew_snapshot_applied.emit(applied.duplicate(true))
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


func _on_peer_disconnected(peer_id: int, reason: StringName = &"disconnect") -> void:
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
	_crew_roles.release_peer(AUTHORITY_PEER_ID, peer_id, peer_generation)
	_crew_commands.release_peer(AUTHORITY_PEER_ID, peer_id, peer_generation)
	_seat_authority.release_peer(AUTHORITY_PEER_ID, peer_id)
	for relationship_key_variant in _seat_moving_relationships.keys():
		var relationship_key := String(relationship_key_variant)
		if relationship_key.begins_with("%d:" % peer_id):
			_seat_moving_relationships.erase(relationship_key_variant)
	for prediction_id_variant in _prediction_entities.keys():
		var prediction_id := StringName(prediction_id_variant)
		var prediction_entity := _prediction_entities[prediction_id] as Dictionary
		if int(prediction_entity.get("owner_peer_id", 0)) == peer_id:
			_prediction.retire_entity(
				AUTHORITY_PEER_ID, prediction_id, int(prediction_entity.get("entity_generation", 0))
			)
			_prediction_entities.erase(prediction_id)
	_peer_generations.erase(peer_id)
	_peer_keepalive_deadlines.erase(peer_id)
	_moving_recipient_budgets.erase(peer_id)
	_moving_recipient_entities.erase(peer_id)
	_moving_recipient_pending.erase(peer_id)
	_projectile_recipient_budgets.erase(peer_id)
	_projectile_recipient_pending.erase(peer_id)
	_projectile_published_generations.erase(peer_id)
	_projectile_replica_samples.clear()
	_projectile_replica_generations.clear()
	_projectile_replica_ticks.clear()
	_projectile_replica_revision = 0
	_refresh_hosted_directory()
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
	receipt["reason"] = reason
	peer_disconnected.emit(peer_id, receipt.duplicate(true))
	if reason == &"timeout":
		peer_keepalive_timeout.emit(peer_id, receipt.duplicate(true))


func _on_server_disconnected() -> void:
	if not is_server():
		shutdown(&"server_disconnected")


func _seat_relationship_key(peer_id: int, avatar_id: StringName) -> String:
	return "%d:%s" % [peer_id, String(avatar_id)]


func _validate_seat_moving_frame(seat_record: Dictionary) -> StringName:
	var frame_id := StringName(seat_record.get("frame_id", &""))
	if frame_id.is_empty():
		return &""
	var requested_generation := int(seat_record.get("seat_generation", 0))
	for frame_variant in _moving_interior.get_snapshot().get("frames", []) as Array:
		var frame := frame_variant as Dictionary
		if StringName(frame.get("frame_id", &"")) == frame_id:
			if int(frame.get("frame_generation", 0)) != requested_generation:
				return &"moving_interior_frame_generation_mismatch"
			return &""
	return &"moving_interior_frame_unavailable"


func _relationship_for_seat_assignment(assignment: Dictionary) -> RefCounted:
	var frame_id := StringName(assignment.get("frame_id", &""))
	var frame_generation := 0
	if not frame_id.is_empty():
		for frame_variant in _moving_interior.get_snapshot().get("frames", []) as Array:
			var frame := frame_variant as Dictionary
			if StringName(frame.get("frame_id", &"")) == frame_id:
				frame_generation = int(frame.get("frame_generation", 0))
				break
	var server_tick := int(_moving_interior.get_snapshot().get("server_tick", 0))
	return MovingInteriorRelationship.create(
		server_tick,
		StringName(assignment.get("avatar_id", &"")),
		int(assignment.get("seat_generation", 0)),
		frame_id,
		frame_generation,
		Transform3D.IDENTITY,
		Vector3.ZERO,
		Vector3.ZERO,
		int(assignment.get("claim_sequence", 0))
	)


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
