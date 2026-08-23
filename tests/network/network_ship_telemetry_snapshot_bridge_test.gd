extends SceneTree

const Bridge := preload("res://scripts/network/network_ship_telemetry_snapshot_bridge.gd")
const Snapshot := preload("res://scripts/network/network_authoritative_snapshot.gd")
const Hero := preload("res://scripts/ships/hero_ship.gd")

class AdapterProbe extends RefCounted:
	var packet: Dictionary = {}
	func publish_snapshot(_tick: int, movement: Array, _projectiles: Array, _respawn: Array) -> Dictionary:
		var authority := Snapshot.new(1)
		var published := authority.publish(1, _tick, 1, movement, [], [], [], [])
		packet = published.get("snapshot", {})
		return {"accepted": published.get("accepted", false), "status": &"snapshot_published", "packet": packet}

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var adapter := AdapterProbe.new()
	var ship := Hero.new()
	var bridge := Bridge.new()
	_check(bridge.attach(adapter, ship).accepted, "bridge attaches live HeroShip telemetry")
	_check(bridge.submit(10, 2, 1).accepted, "server submits one telemetry snapshot")
	var ownership := (adapter.packet.sections.movement as Array)[0] as Dictionary
	_check(float(ownership.engine_power) >= 0.0 and float(ownership.engine_power) <= 1.0 and ownership.has("velocity_world"), "snapshot carries bounded modifiers and velocity")
	_check(bridge.submit(10, 2, 1).status == &"stale_snapshot_identity", "replayed sequence is rejected")
	bridge.detach()
	_check(bridge.submit(11, 3, 2).status == &"detached", "detached bridge cannot publish")
	_check(bridge.attach(adapter, ship).accepted and bridge.submit(12, 3, 1).accepted, "re-entry starts a fresh generation")
	var replica := Snapshot.new(1)
	_check(replica.apply_replica(1, adapter.packet).accepted and float((replica.get_section(&"movement")[0] as Dictionary).targeting_power) >= 0.0, "replica presents server modifiers without mutation authority")
	if _failures.is_empty():
		print("OK: network ship telemetry snapshot bridge (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)

func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + description)
