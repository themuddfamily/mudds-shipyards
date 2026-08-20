class_name NetworkLifecycleIntegration
extends RefCounted

## Bounded server-adapter ledger for the first multiplayer lifecycle slice.
##
## This contract composes the existing detached authorities; it does not
## replace them or create a second source of truth.  A production session
## adapter can use the receipts here to prove that admission, seat/ship
## ownership, replication interest, prediction correction, migration rebind,
## and disconnect cleanup happen in an explicit order.  No MultiplayerPeer,
## node, physics, render, audio, or gameplay simulation is created here.

const Lifecycle := preload("res://scripts/network/network_disconnect_lifecycle.gd")
const Migration := preload("res://scripts/network/network_session_migration.gd")
const Prediction := preload("res://scripts/network/network_prediction_correction_guard.gd")

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_lifecycle_integration_v1"
const DEFAULT_AUTHORITY_PEER_ID := 99
const DEFAULT_PROTOCOL_VERSION := 4
const DEFAULT_PACKAGE_GENERATION := 12
const DEFAULT_SESSION_GENERATION := 3
const DEFAULT_MIGRATION_GENERATION := 1

var _authority_peer_id := DEFAULT_AUTHORITY_PEER_ID
var _protocol_version := DEFAULT_PROTOCOL_VERSION
var _package_generation := DEFAULT_PACKAGE_GENERATION
var _session_generation := DEFAULT_SESSION_GENERATION
var _migration_generation := DEFAULT_MIGRATION_GENERATION
var _lifecycle
var _migration
var _prediction
var _phase: StringName = &"empty"
var _event_sequence := 0
var _peer_id := 0
var _peer_generation := 0
var _avatar_id: StringName = &""
var _entity_id: StringName = &""
var _entity_generation := 0
var _ship_id: StringName = &""
var _ship_generation := 0
var _seat_id: StringName = &""
var _seat_generation := 0
var _migration_attached := false
var _last_result: Dictionary = {}
var _events: Array = []


func _init(
	p_authority_peer_id: int = DEFAULT_AUTHORITY_PEER_ID,
	p_protocol_version: int = DEFAULT_PROTOCOL_VERSION,
	p_package_generation: int = DEFAULT_PACKAGE_GENERATION,
	p_session_generation: int = DEFAULT_SESSION_GENERATION,
	p_migration_generation: int = DEFAULT_MIGRATION_GENERATION
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_protocol_version = maxi(1, p_protocol_version)
	_package_generation = maxi(1, p_package_generation)
	_session_generation = maxi(1, p_session_generation)
	_migration_generation = maxi(1, p_migration_generation)
	_lifecycle = Lifecycle.new(
		_authority_peer_id,
		_protocol_version,
		_package_generation,
		_session_generation,
		1
	)
	_migration = Migration.new(
		_authority_peer_id,
		_protocol_version,
		_package_generation,
		_session_generation,
		_migration_generation
	)
	_prediction = Prediction.new(_authority_peer_id)
	_last_result = _result(false, &"uninitialized")


## Server-owned registration helpers intentionally stay narrow: they seed the
## detached ledgers that the integration path consumes.
func register_seat(
	seat_id: StringName,
	vessel_id: StringName,
	role: StringName,
	frame_id: StringName,
	seat_generation: int = 1
) -> Dictionary:
	return _remember(_lifecycle.register_seat(
		_authority_peer_id, seat_id, vessel_id, role, frame_id, seat_generation
	))


func register_ship(ship_id: StringName, ship_generation: int) -> Dictionary:
	return _remember(_lifecycle.register_ship(
		_authority_peer_id, ship_id, ship_generation
	))


func register_entity(
	entity_id: StringName,
	entity_generation: int,
	owner_peer_id: int,
	position: Vector3,
	replication_radius: float = 1000.0
) -> Dictionary:
	var result: Dictionary = _lifecycle.register_entity(
		_authority_peer_id,
		entity_id,
		entity_generation,
		owner_peer_id,
		position,
		replication_radius
	)
	if bool(result.get("accepted", false)):
		_prediction.register_entity(
			_authority_peer_id, entity_id, entity_generation, owner_peer_id
		)
	return _remember(result)


func publish_entity_state(
	entity_id: StringName,
	entity_generation: int,
	server_tick: int,
	position: Vector3,
	state: Dictionary
) -> Dictionary:
	return _remember(_lifecycle.publish_entity_state(
		_authority_peer_id,
		entity_id,
		entity_generation,
		server_tick,
		position,
		state
	))


static func create_hello(
	p_peer_id: int,
	p_peer_generation: int,
	p_protocol_version: int = DEFAULT_PROTOCOL_VERSION,
	p_package_generation: int = DEFAULT_PACKAGE_GENERATION,
	p_session_generation: int = DEFAULT_SESSION_GENERATION
) -> Dictionary:
	return Lifecycle.create_hello(
		p_peer_id,
		p_peer_generation,
		p_protocol_version,
		p_package_generation,
		p_session_generation
	)


## Joins through the handshake first, then commits the seat, ship, interest,
## and migration attachment.  A failed later step rolls the lifecycle peer
## back so a partial join cannot remain visible as an active peer.
func join_peer(
	source_peer_id: int,
	wire: Dictionary,
	avatar_id: StringName,
	seat_id: StringName,
	role: StringName,
	ship_id: StringName,
	ship_generation: int,
	interest_center: Vector3,
	interest_radius: float,
	interest_max_entities: int = 512,
	entity_id: StringName = &"",
	entity_generation: int = 0
) -> Dictionary:
	if _phase != &"empty" and _phase != &"disconnected":
		return _remember(_result(false, &"join_already_active"))
	var admitted: Dictionary = _lifecycle.admit_peer(source_peer_id, wire)
	if not bool(admitted.get("accepted", false)):
		return _remember(_result(false, &"handshake_rejected", {"handshake": admitted}))
	var peer: Dictionary = admitted.get("peer", {})
	_peer_id = int(peer.get("peer_id", 0))
	_peer_generation = int(peer.get("peer_generation", 0))
	_avatar_id = avatar_id
	_seat_id = seat_id
	_seat_generation = _seat_generation_for(seat_id)
	_ship_id = ship_id
	_ship_generation = ship_generation
	_entity_id = entity_id
	_entity_generation = entity_generation
	var registration: Dictionary = _migration.register_peer(
		_authority_peer_id, _peer_id, _peer_generation
	)
	if not bool(registration.get("accepted", false)):
		_rollback_join()
		return _remember(_result(false, &"migration_registration_rejected", {
			"migration": registration,
		}))
	var claim_seat: Dictionary = _lifecycle.claim_seat(
		_authority_peer_id,
		_peer_id,
		_peer_generation,
		avatar_id,
		seat_id,
		role,
		1
	)
	if not bool(claim_seat.get("accepted", false)):
		_rollback_join()
		return _remember(_result(false, &"seat_claim_rejected", {"seat": claim_seat}))
	var claim_ship: Dictionary = _lifecycle.claim_ship(
		_authority_peer_id,
		_peer_id,
		_peer_generation,
		ship_id,
		ship_generation,
		1
	)
	if not bool(claim_ship.get("accepted", false)):
		_rollback_join()
		return _remember(_result(false, &"ship_claim_rejected", {"ship": claim_ship}))
	var interest: Dictionary = _lifecycle.set_interest(
		_authority_peer_id,
		_peer_id,
		_peer_generation,
		interest_center,
		interest_radius,
		interest_max_entities
	)
	if not bool(interest.get("accepted", false)):
		_rollback_join()
		return _remember(_result(false, &"interest_rejected", {"interest": interest}))
	var binding: Dictionary = _migration.bind_attachment(
		_authority_peer_id,
		_peer_id,
		_peer_generation,
		seat_id,
		_seat_generation,
		ship_id,
		ship_generation,
		interest_center,
		interest_radius,
		interest_max_entities
	)
	if not bool(binding.get("accepted", false)):
		_rollback_join()
		return _remember(_result(false, &"migration_attachment_rejected", {
			"migration": binding,
		}))
	_migration_attached = true
	_phase = &"active"
	_record_event(&"joined", {
		"peer_id": _peer_id,
		"peer_generation": _peer_generation,
		"seat_id": seat_id,
		"ship_id": ship_id,
		"entity_id": entity_id,
	})
	return _remember(_result(true, &"joined", {
		"peer": peer.duplicate(true),
		"seat": claim_seat,
		"ship": claim_ship,
		"interest": interest,
		"migration": binding,
	}))


func replicate(server_tick: int) -> Dictionary:
	if _phase != &"active":
		return _remember(_result(false, &"peer_not_active"))
	return _remember(_lifecycle.replicate(
		_authority_peer_id, _peer_id, _peer_generation, server_tick
	))


func accept_prediction(
	client_peer_id: int,
	client_tick: int,
	predicted_state: Dictionary,
	server_tick: int,
	event_sequence: int,
	position: Vector3,
	velocity: Vector3
) -> Dictionary:
	var snapshot := Prediction.create_snapshot(
		_authority_peer_id,
		_entity_id,
		_entity_generation,
		_peer_id,
		server_tick,
		event_sequence,
		position,
		velocity
	)
	return _remember(_prediction.accept_snapshot(
		_authority_peer_id,
		client_peer_id,
		client_tick,
		predicted_state,
		snapshot
	))


## Rotation is one explicit boundary for both epoch contracts. The migration
## receipt retains attachments while the live lifecycle clears active claims.
func rotate_session(next_package_generation: int = -1) -> Dictionary:
	if _phase != &"active":
		return _remember(_result(false, &"peer_not_active"))
	var migration_result: Dictionary = _migration.rotate_server(
		_authority_peer_id, next_package_generation
	)
	if not bool(migration_result.get("accepted", false)):
		return _remember(_result(false, &"migration_rotation_rejected", {
			"migration": migration_result,
		}))
	var lifecycle_result: Dictionary = _lifecycle.rotate_session(
		_authority_peer_id, next_package_generation
	)
	if not bool(lifecycle_result.get("accepted", false)):
		return _remember(_result(false, &"lifecycle_rotation_rejected", {
			"lifecycle": lifecycle_result,
		}))
	_package_generation = int(migration_result.get("package_generation", _package_generation))
	_session_generation = int(migration_result.get("session_generation", _session_generation + 1))
	_migration_generation = int(migration_result.get("migration_generation", _migration_generation + 1))
	_phase = &"migration_pending"
	_migration_attached = false
	_record_event(&"rotated", {
		"package_generation": _package_generation,
		"session_generation": _session_generation,
		"migration_generation": _migration_generation,
	})
	return _remember(_result(true, &"rotated", {
		"migration": migration_result,
		"lifecycle": lifecycle_result,
	}))


## Rebind performs the current-epoch handshake, migration receipt restore, and
## fresh seat/ship/interest commits. The retained entity generation is not
## re-registered, so destruction/respawn IDs remain generation-fenced.
func rebind_peer(
	source_peer_id: int,
	next_peer_generation: int,
	interest_center: Vector3 = Vector3.ZERO,
	interest_radius: float = 20.0,
	interest_max_entities: int = 512
) -> Dictionary:
	if _phase != &"migration_pending":
		return _remember(_result(false, &"rebind_not_pending"))
	var hello := create_hello(
		_peer_id,
		next_peer_generation,
		_protocol_version,
		_package_generation,
		_session_generation
	)
	var admitted: Dictionary = _lifecycle.admit_peer(source_peer_id, hello)
	if not bool(admitted.get("accepted", false)):
		return _remember(_result(false, &"rebind_handshake_rejected", {"handshake": admitted}))
	var packet: Dictionary = _migration.make_packet(
		_peer_id, next_peer_generation, 0, &"rebind"
	)
	var rebound: Dictionary = _migration.rebind_peer(_peer_id, packet)
	if not bool(rebound.get("accepted", false)):
		_lifecycle.disconnect_peer(_authority_peer_id, _peer_id, next_peer_generation)
		return _remember(_result(false, &"migration_rebind_rejected", {"migration": rebound}))
	_peer_generation = next_peer_generation
	var seat: Dictionary = _lifecycle.claim_seat(
		_authority_peer_id,
		_peer_id,
		_peer_generation,
		_avatar_id,
		_seat_id,
		_role_for_seat(),
		2
	)
	var ship: Dictionary = _lifecycle.claim_ship(
		_authority_peer_id,
		_peer_id,
		_peer_generation,
		_ship_id,
		_ship_generation,
		2
	)
	var interest: Dictionary = _lifecycle.set_interest(
		_authority_peer_id,
		_peer_id,
		_peer_generation,
		interest_center,
		interest_radius,
		interest_max_entities
	)
	if not bool(seat.get("accepted", false)) or not bool(ship.get("accepted", false)) \
		or not bool(interest.get("accepted", false)):
		return _remember(_result(false, &"rebind_attachment_restore_rejected", {
			"seat": seat, "ship": ship, "interest": interest,
		}))
	_migration_attached = true
	_phase = &"active"
	_record_event(&"rebound", {"peer_generation": _peer_generation})
	return _remember(_result(true, &"rebound", {
		"handshake": admitted,
		"migration": rebound,
		"seat": seat,
		"ship": ship,
		"interest": interest,
	}))


## Disconnect clears live seat/ship/interest state through the existing
## lifecycle authority. Migration attachment is marked detached here; the
## transport adapter owns the actual socket teardown.
func disconnect_peer(source_peer_id: int) -> Dictionary:
	if _phase != &"active":
		return _remember(_result(false, &"peer_not_active"))
	var disconnected: Dictionary = _lifecycle.disconnect_peer(
		 source_peer_id, _peer_id, _peer_generation
	)
	if not bool(disconnected.get("accepted", false)):
		return _remember(_result(false, &"disconnect_rejected", {
			"lifecycle": disconnected,
		}))
	_migration_attached = false
	# A true disconnect has no pending rebind receipt. Retire this bounded
	# adapter ledger so the next connection cannot consume stale transport
	# state; the transport owns actual socket teardown.
	_reset_migration_ledger()
	_phase = &"disconnected"
	_record_event(&"disconnected", {"peer_id": _peer_id})
	return _remember(_result(true, &"disconnected", {
		"lifecycle": disconnected,
		"migration_transport_detached": true,
	}))


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"phase": _phase,
		"event_sequence": _event_sequence,
		"peer_id": _peer_id,
		"peer_generation": _peer_generation,
		"package_generation": _package_generation,
		"session_generation": _session_generation,
		"migration_generation": _migration_generation,
		"migration_attached": _migration_attached,
		"events": _events.duplicate(true),
		"lifecycle": _lifecycle.get_snapshot(),
		"migration": _migration.get_snapshot(),
		"prediction": _prediction.audit(),
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0 and _phase != &"empty",
		"server_owns_join_handshake": true,
		"server_owns_migration_epochs": true,
		"server_owns_disconnect_cleanup": true,
		"server_owns_prediction_correction": true,
		"server_owns_replication_interest": true,
		"server_owns_seat_and_ship_ownership": true,
		"client_prediction_is_presentation_only": true,
		"client_can_mutate_authority": false,
		"migration_requires_new_peer_generation": true,
		"event_count": _events.size(),
		"phase": _phase,
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _rollback_join() -> void:
	if _peer_id > 0 and not _lifecycle.get_peer(_peer_id).is_empty():
		_lifecycle.disconnect_peer(_authority_peer_id, _peer_id, _peer_generation)
	_reset_migration_ledger()
	_migration_attached = false
	_phase = &"empty"
	_peer_id = 0
	_peer_generation = 0


func _reset_migration_ledger() -> void:
	_migration = Migration.new(
		_authority_peer_id,
		_protocol_version,
		_package_generation,
		_session_generation,
		_migration_generation
	)


func _seat_generation_for(seat_id: StringName) -> int:
	var seats: Array = _lifecycle.get_snapshot().get("seats", {}).get("seats", [])
	for value in seats:
		var seat := value as Dictionary
		if StringName(seat.get("seat_id", &"")) == seat_id:
			return int(seat.get("seat_generation", 1))
	return 1


func _role_for_seat() -> StringName:
	var seats: Array = _lifecycle.get_snapshot().get("seats", {}).get("seats", [])
	for value in seats:
		var seat := value as Dictionary
		if StringName(seat.get("seat_id", &"")) == _seat_id:
			return StringName(seat.get("role", &"passenger"))
	return &"passenger"


func _record_event(kind: StringName, payload: Dictionary = {}) -> void:
	_event_sequence += 1
	_events.append({
		"sequence": _event_sequence,
		"kind": kind,
		"payload": payload.duplicate(true),
	})


func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(payload)
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result
