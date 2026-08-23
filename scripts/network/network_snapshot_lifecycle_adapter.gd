class_name NetworkSnapshotLifecycleAdapter
extends RefCounted

## Concrete session seam for the authoritative snapshot synchronizer.
##
## `NetworkDisconnectLifecycle` remains the owner of admission, peer
## generations, seat claims, ship ownership, and disconnect cleanup. This
## adapter feeds those committed session records into
## `NetworkAuthoritativeSnapshot` beside caller-supplied movement, projectile,
## and damage/respawn records. It owns no RPC, node, physics, or health state.

const Lifecycle := preload("res://scripts/network/network_disconnect_lifecycle.gd")
const Snapshot := preload("res://scripts/network/network_authoritative_snapshot.gd")

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_snapshot_lifecycle_adapter_v1"

var _authority_peer_id := 1
var _lifecycle
var _snapshot
var _last_snapshot_event_sequence := -1
var _snapshot_needs_publish := true
var _last_result: Dictionary = {}


func _init(
	p_authority_peer_id: int = 1,
	p_protocol_version: int = 1,
	p_package_generation: int = 1,
	p_session_generation: int = 1,
	p_max_updates_per_tick: int = 16
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_lifecycle = Lifecycle.new(
		_authority_peer_id,
		p_protocol_version,
		p_package_generation,
		p_session_generation,
		p_max_updates_per_tick
	)
	_snapshot = Snapshot.new(_authority_peer_id)
	_last_result = _result(false, &"uninitialized")


static func create_hello(
	p_peer_id: int,
	p_peer_generation: int,
	p_protocol_version: int,
	p_package_generation: int,
	p_session_generation: int,
	p_schema_version: int = 1
) -> Dictionary:
	return Lifecycle.create_hello(
		p_peer_id,
		p_peer_generation,
		p_protocol_version,
		p_package_generation,
		p_session_generation,
		p_schema_version
	)


func admit_peer(source_peer_id: int, wire: Dictionary) -> Dictionary:
	return _remember(_lifecycle.admit_peer(source_peer_id, wire))


func register_ship(
	source_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	owner_peer_id: int = 0
) -> Dictionary:
	return _remember(_lifecycle.register_ship(
		source_peer_id, ship_id, ship_generation, owner_peer_id
	))


func register_seat(
	source_peer_id: int,
	seat_id: StringName,
	vessel_id: StringName,
	role: StringName,
	frame_id: StringName = &"",
	seat_generation: int = 1
) -> Dictionary:
	return _remember(_lifecycle.register_seat(
		source_peer_id, seat_id, vessel_id, role, frame_id, seat_generation
	))


func claim_ship(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int,
	ship_id: StringName,
	ship_generation: int,
	request_sequence: int
) -> Dictionary:
	return _remember(_lifecycle.claim_ship(
		source_peer_id,
		peer_id,
		peer_generation,
		ship_id,
		ship_generation,
		request_sequence
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
	return _remember(_lifecycle.claim_seat(
		source_peer_id,
		peer_id,
		peer_generation,
		avatar_id,
		seat_id,
		role,
		request_sequence
	))


## Publishes session-owned ship/seat records together with movement,
## projectile, and respawn records from the other server authorities.
func publish_authority_snapshot(
	source_peer_id: int,
	server_tick: int,
	movement: Array,
	projectiles: Array,
	respawn: Array
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var lifecycle_snapshot: Dictionary = _lifecycle.get_snapshot()
	var lifecycle_event_sequence := int(lifecycle_snapshot.get("event_sequence", 0))
	var next_event_sequence := maxi(
		lifecycle_event_sequence,
		_last_snapshot_event_sequence + 1
	)
	var ownership := _ownership_records(lifecycle_snapshot)
	var boarding := _boarding_records(lifecycle_snapshot)
	var published: Dictionary = _snapshot.publish(
		_authority_peer_id,
		server_tick,
		next_event_sequence,
		movement,
		ownership,
		projectiles,
		boarding,
		respawn
	)
	if bool(published.get("accepted", false)):
		_last_snapshot_event_sequence = next_event_sequence
		_snapshot_needs_publish = false
		published["lifecycle_event_sequence"] = lifecycle_event_sequence
		published["session_generation"] = _session_generation(lifecycle_snapshot)
	return _remember(published)


## Replica adapters use the synchronizer's authenticated server boundary. The
## lifecycle remains available to the real transport adapter for peer admission
## and disconnect; this method only applies the detached gameplay packet.
func apply_replica_snapshot(source_peer_id: int, packet: Dictionary) -> Dictionary:
	var applied: Dictionary = _snapshot.apply_replica(source_peer_id, packet)
	return _remember(applied)


func disconnect_peer(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int
) -> Dictionary:
	var disconnected: Dictionary = _lifecycle.disconnect_peer(
		source_peer_id, peer_id, peer_generation
	)
	if bool(disconnected.get("accepted", false)):
		_snapshot_needs_publish = true
		disconnected["snapshot_requires_publish"] = true
	return _remember(disconnected)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"lifecycle": _lifecycle.get_snapshot(),
		"authoritative": _snapshot.get_snapshot(),
		"snapshot_needs_publish": _snapshot_needs_publish,
	}.duplicate(true)


func get_authoritative_snapshot() -> Dictionary:
	return _snapshot.get_snapshot()


func get_peer(peer_id: int) -> Dictionary:
	return _lifecycle.get_peer(peer_id)


func audit() -> Dictionary:
	var lifecycle_audit: Dictionary = _lifecycle.audit()
	var snapshot_audit: Dictionary = _snapshot.audit()
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"session_coordinator_policy": lifecycle_audit.get("policy_version", &""),
		"snapshot_policy": snapshot_audit.get("policy_version", &""),
		"server_owns_peer_lifecycle": true,
		"server_owns_snapshot_publication": true,
		"disconnect_requires_snapshot_refresh": true,
		"client_can_publish_snapshot": false,
		"snapshot_needs_publish": _snapshot_needs_publish,
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _ownership_records(lifecycle_snapshot: Dictionary) -> Array:
	var ships_state: Dictionary = lifecycle_snapshot.get("ships", {}) as Dictionary
	return (ships_state.get("ships", []) as Array).duplicate(true)


func _boarding_records(lifecycle_snapshot: Dictionary) -> Array:
	var seats_state: Dictionary = lifecycle_snapshot.get("seats", {}) as Dictionary
	return (seats_state.get("assignments", []) as Array).duplicate(true)


func _session_generation(lifecycle_snapshot: Dictionary) -> int:
	var session: Dictionary = lifecycle_snapshot.get("session", {}) as Dictionary
	return int(session.get("session_generation", 0))


func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"accepted": accepted,
		"status": status,
		"authority_peer_id": _authority_peer_id,
	}
	for key in payload:
		result[key] = payload[key]
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
