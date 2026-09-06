extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 4
	server._seat_moving_relationships["2:crew_7"] = _relationship(5, 1.0).duplicate(true)
	var published: Dictionary = server.publish_moving_interior_resync(2)
	_check(bool(published.get("accepted", false)), "admitted peer receives bounded resync")
	_check(int(published.get("relationship_count", 0)) == 1, "resync contains one current relationship")
	var packet: Dictionary = published.get("packet", {}) as Dictionary
	_check(int(packet.get("migration_generation", 0)) == 1, "resync carries migration generation")
	var client := Adapter.new()
	var applied: Dictionary = client._apply_moving_interior_resync(packet)
	_check(bool(applied.get("accepted", false)), "client applies current resync")
	_check(client.sample_moving_interior_replica(&"crew_7", 5.0).get("status") != &"entity_not_tracked",
		"resync populates the client replica")
	var stale_packet := packet.duplicate(true)
	stale_packet["relationships"] = [_relationship(2, 0.0)]
	_check(client._apply_moving_interior_resync(stale_packet).get("status") == &"stale_or_reordered_tick",
		"older same-generation relationship is rejected")
	var foreign_packet := packet.duplicate(true)
	foreign_packet["authority_peer_id"] = 9
	_check(client._apply_moving_interior_resync(foreign_packet).get("status") == &"foreign_moving_interior_resync",
		"foreign authority is rejected")
	var oversized := packet.duplicate(true)
	var many: Array = []
	for index in 129:
		many.append({})
	oversized["relationships"] = many
	_check(client._apply_moving_interior_resync(oversized).get("status") == &"invalid_moving_interior_resync",
		"oversized relationship list is rejected")
	var later_resync := packet.duplicate(true)
	later_resync["revision"] = 99
	later_resync["relationships"] = []
	_check(client._apply_moving_interior_resync(later_resync).accepted, "empty resync advances current generation fence")
	var migrated := packet.duplicate(true)
	migrated["migration_generation"] = 2
	migrated["relationships"] = [_relationship(1, 3.0)]
	_check(client._apply_moving_interior_resync(migrated).get("accepted", false), "new generation replaces stale replica state")
	_check(server.publish_moving_interior_resync(8).get("status") == &"peer_not_admitted",
		"server rejects resync to unknown peer")
	server.free()
	client.free()
	if _failures.is_empty():
		print("OK: ENet moving interior resync (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _relationship(tick: int, x: float) -> Dictionary:
	return Relationship.create(
		tick, &"crew_7", 1, &"halyard_frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0))
	).get_snapshot()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
