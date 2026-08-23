class_name NetworkShipTelemetrySnapshotBridge
extends RefCounted

## Caller-driven bridge from a live HeroShip telemetry sample to the detached
## authoritative snapshot boundary. It owns no cadence, physics, or authority.

const Snapshot := preload("res://scripts/network/network_authoritative_snapshot.gd")
const POLICY_VERSION: StringName = &"network_ship_telemetry_snapshot_bridge_v1"

var _adapter: Object
var _ship: Object
var _last_generation := 0
var _last_sequence := -1
var _detached := true


func attach(adapter: Object, ship: Object) -> Dictionary:
	if adapter == null or not is_instance_valid(adapter) or not adapter.has_method(&"publish_snapshot"):
		return _result(false, &"adapter_unavailable")
	if ship == null or not is_instance_valid(ship) or not ship.has_method(&"get_telemetry"):
		return _result(false, &"ship_unavailable")
	_adapter = adapter
	_ship = ship
	_detached = false
	return _result(true, &"attached")


func detach(reason: StringName = &"detached") -> Dictionary:
	_adapter = null
	_ship = null
	_detached = true
	_last_generation = 0
	_last_sequence = -1
	return _result(true, reason)


func submit(server_tick: int, ship_generation: int, event_sequence: int) -> Dictionary:
	if _detached or _adapter == null or _ship == null:
		return _result(false, &"detached")
	if server_tick < 0 or ship_generation <= 0 or event_sequence < 0:
		return _result(false, &"invalid_snapshot_identity")
	if ship_generation < _last_generation or (ship_generation == _last_generation and event_sequence <= _last_sequence):
		return _result(false, &"stale_snapshot_identity")
	var telemetry: Dictionary = _ship.get_telemetry()
	var sample := _sample_from_telemetry(telemetry, ship_generation)
	if sample.is_empty():
		return _result(false, &"invalid_ship_telemetry")
	var result: Dictionary = _adapter.publish_snapshot(server_tick, [sample], [], [])
	if bool(result.get("accepted", false)):
		_last_generation = ship_generation
		_last_sequence = event_sequence
	return _result(bool(result.get("accepted", false)), StringName(result.get("status", &"publish_failed")), {
		"packet": result.get("packet", {}), "event_sequence": event_sequence,
		"ship_generation": ship_generation,
	})


func _sample_from_telemetry(telemetry: Dictionary, generation: int) -> Dictionary:
	var ship_id := StringName(telemetry.get("ship_id", &""))
	var velocity: Variant = telemetry.get("velocity_world", Vector3.INF)
	if ship_id.is_empty() or not velocity is Vector3 or not (velocity as Vector3).is_finite():
		return {}
	var modifiers := {}
	for field in [&"engine_power", &"weapon_power", &"targeting_power"]:
		var value: Variant = telemetry.get(field, 1.0)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1.0:
			return {}
		modifiers[field] = float(value)
	for field in [&"engine_disabled", &"weapon_disabled", &"targeting_disabled"]:
		if telemetry.has(field) and not telemetry.get(field) is bool:
			return {}
		modifiers[field] = bool(telemetry.get(field, false))
	return {
		"entity_id": ship_id,
		"entity_generation": generation,
		"owner_peer_id": 1,
		"mode": &"ship",
		"position": telemetry.get("position", Vector3.ZERO),
		"velocity_world": velocity,
		"landed": bool(telemetry.get("landed", false)),
		"damage_status": telemetry.get("damage_status", &"healthy"),
		"component_generation": generation,
		"engine_power": modifiers.engine_power,
		"weapon_power": modifiers.weapon_power,
		"targeting_power": modifiers.targeting_power,
		"engine_disabled": modifiers.engine_disabled,
		"weapon_disabled": modifiers.weapon_disabled,
		"targeting_disabled": modifiers.targeting_disabled,
	}.duplicate(true)


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status, "policy_version": POLICY_VERSION}
	result.merge(extra)
	return result
