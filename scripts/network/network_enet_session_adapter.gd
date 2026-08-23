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

signal session_started(mode: StringName)
signal session_stopped(reason: StringName)
signal peer_admitted(peer_id: int, receipt: Dictionary)
signal peer_disconnected(peer_id: int, receipt: Dictionary)
signal snapshot_published(packet: Dictionary)
signal snapshot_applied(result: Dictionary)
signal transport_rejected(status: StringName)
signal movement_intent_result(result: Dictionary)
signal boarding_intent_result(result: Dictionary)

const DEFAULT_PORT := 27101
const DEFAULT_MAX_CLIENTS := 8
const AUTHORITY_PEER_ID := 1

var _peer: ENetMultiplayerPeer
var _lifecycle
var _transport
var _movement
var _boarding
var _is_server := false
var _configured := false
var _peer_generations: Dictionary = {}
var _last_result: Dictionary = {}
var _server_offer: Dictionary = {}
var _bound_port := 0


func _init() -> void:
	_lifecycle = LifecycleAdapter.new(AUTHORITY_PEER_ID)
	_transport = TransportSecurity.new(AUTHORITY_PEER_ID)
	_movement = MovementAuthority.new(AUTHORITY_PEER_ID)
	_boarding = BoardingAuthority.new(AUTHORITY_PEER_ID)
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
	_peer_generations.erase(peer_id)
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
