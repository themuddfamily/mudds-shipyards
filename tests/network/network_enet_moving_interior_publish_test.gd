extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	adapter._is_server = true
	adapter._configured = true
	var published: Dictionary = adapter.publish_moving_interior_snapshot(_relationship().get_snapshot())
	_check(bool(published.get("accepted", false)), "server publishes a validated relationship")
	var packet: Dictionary = published.get("packet", {}) as Dictionary
	_check(int(packet.get("revision", 0)) == 1, "publication assigns an ordered revision")
	_check(int(packet.get("migration_generation", 0)) == 1, "publication carries migration generation")
	_check(int(published.get("recipients", -1)) == 0, "publication has no implicit unauthorised recipients")
	var rejected_peer: Dictionary = adapter.publish_moving_interior_snapshot(
		_relationship(2).get_snapshot(), [7]
	)
	_check(rejected_peer.get("status") == &"peer_not_admitted", "publication rejects unknown recipients")
	var malformed: Dictionary = _relationship().get_snapshot()
	malformed["linear_velocity"] = [INF, 0.0, 0.0]
	var rejected_payload: Dictionary = adapter.publish_moving_interior_snapshot(malformed)
	_check(rejected_payload.get("status") == &"invalid_moving_interior_relationship",
		"publication rejects non-finite relationship fields")
	adapter.free()
	if _failures.is_empty():
		print("OK: ENet moving interior publication (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _relationship(tick: int = 1) -> RefCounted:
	return Relationship.create(
		tick, &"crew_7", 1, &"halyard_frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0)),
		Vector3(0.5, 0.0, 0.0), Vector3.ZERO, tick
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
