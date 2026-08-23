class_name NetworkShipAuthorityComposition
extends Node

## Caller-driven owner for the detached ship-network bridges. It does not
## schedule ticks, admit peers, mutate ships, or own transport authority.

const TelemetryBridge := preload("res://scripts/network/network_ship_telemetry_snapshot_bridge.gd")
const CinderBridge := preload("res://scripts/network/network_cinder_loadmaster_manifest_bridge.gd")
const CinderNavigatorBridge := preload("res://scripts/network/network_cinder_navigator_ping_bridge.gd")

signal cinder_navigator_ping_receipt_forwarded(result: Dictionary)
signal cinder_navigator_ping_tombstones_forwarded(result: Dictionary)

var _session: Object
var _ship: Object
var _telemetry_bridge: RefCounted
var _cinder_bridge: RefCounted
var _cinder_navigator_bridge: RefCounted
var _ship_generation := 0


func attach(session: Object, ship: Object, ship_generation: int = 1) -> Dictionary:
	if session == null or not is_instance_valid(session):
		return _result(false, &"session_unavailable")
	if ship == null or not is_instance_valid(ship):
		return _result(false, &"ship_unavailable")
	if ship_generation <= 0:
		return _result(false, &"invalid_ship_generation")
	detach(&"replacement")
	var telemetry := TelemetryBridge.new()
	var telemetry_result: Dictionary = telemetry.attach(session, ship)
	if not bool(telemetry_result.get("accepted", false)):
		return telemetry_result
	_session = session
	_ship = ship
	_ship_generation = ship_generation
	_telemetry_bridge = telemetry
	if ship.has_method(&"submit_crew_intent") and ship.has_method(&"get_crew_role_authority"):
		var cinder := CinderBridge.new()
		var cinder_result: Dictionary = cinder.attach(session, ship)
		if bool(cinder_result.get("accepted", false)):
			_cinder_bridge = cinder
		var navigator := CinderNavigatorBridge.new()
		var navigator_result: Dictionary = navigator.attach(session, ship, _ship_generation)
		if bool(navigator_result.get("accepted", false)):
			_cinder_navigator_bridge = navigator
	return _result(true, &"attached", {
		"ship_generation": _ship_generation,
		"cinder_attached": _cinder_bridge != null,
		"cinder_navigator_attached": _cinder_navigator_bridge != null,
	})


func detach(reason: StringName = &"detached") -> Dictionary:
	var navigator_result: Dictionary = {}
	if _telemetry_bridge != null:
		_telemetry_bridge.detach(reason)
	if _cinder_bridge != null:
		_cinder_bridge.detach(reason)
	if _cinder_navigator_bridge != null:
		navigator_result = _cinder_navigator_bridge.detach(reason)
		_forward_navigator_tombstones(navigator_result)
	_telemetry_bridge = null
	_cinder_bridge = null
	_cinder_navigator_bridge = null
	_session = null
	_ship = null
	_ship_generation = 0
	return _result(true, reason, {"cinder_navigator_ping": navigator_result.duplicate(true)})


func submit_server_physics_tick(server_tick: int, event_sequence: int) -> Dictionary:
	if _telemetry_bridge == null:
		return _result(false, &"detached")
	return _telemetry_bridge.submit(server_tick, _ship_generation, event_sequence)


func submit_cinder_manifest(peer_id: int, peer_generation: int, avatar_id: StringName, seat_generation: int, request_sequence: int, payload: Dictionary) -> Dictionary:
	if _cinder_bridge == null:
		return _result(false, &"cinder_unavailable")
	return _cinder_bridge.submit_manifest(peer_id, peer_generation, avatar_id, seat_generation, request_sequence, payload)


func submit_cinder_navigator_ping(
		peer_id: int,
		peer_generation: int,
		avatar_id: StringName,
		seat_generation: int,
		request_sequence: int,
		payload: Dictionary,
		server_tick: int,
		migration_generation: int
) -> Dictionary:
	if _cinder_navigator_bridge == null:
		return _result(false, &"cinder_navigator_unavailable")
	var result: Dictionary = _cinder_navigator_bridge.submit_ping(
		peer_id,
		peer_generation,
		avatar_id,
		seat_generation,
		request_sequence,
		payload,
		server_tick,
		migration_generation
	)
	if bool(result.get("accepted", false)):
		cinder_navigator_ping_receipt_forwarded.emit(result.duplicate(true))
	return result


func release_peer(peer_id: int) -> Dictionary:
	if peer_id <= 0:
		return _result(false, &"invalid_peer")
	var cinder_result := _result(true, &"cinder_unavailable")
	if _cinder_bridge != null:
		cinder_result = _cinder_bridge.release_peer(peer_id)
	var navigator_result := _result(true, &"cinder_navigator_unavailable")
	if _cinder_navigator_bridge != null:
		navigator_result = _cinder_navigator_bridge.release_peer(peer_id)
		_forward_navigator_tombstones(navigator_result)
	return _result(
		bool(cinder_result.get("accepted", false)) and bool(navigator_result.get("accepted", false)),
		&"peer_released",
		{
			"cinder": cinder_result.duplicate(true),
			"cinder_navigator_ping": navigator_result.duplicate(true),
		}
	)


func get_cinder_navigator_ping_snapshot() -> Dictionary:
	if _cinder_navigator_bridge == null:
		return {
			"attached": false,
			"tracked_actor_count": 0,
			"last_receipt_count": 0,
		}.duplicate(true)
	return _cinder_navigator_bridge.get_snapshot()


func _forward_navigator_tombstones(result: Dictionary) -> void:
	if not (result.get("tombstones", []) as Array).is_empty():
		cinder_navigator_ping_tombstones_forwarded.emit(result.duplicate(true))


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result
