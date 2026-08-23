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
	server._peer_generations[2] = 1
	for index in 8:
		var sent: Dictionary = server.publish_moving_interior_snapshot(_relationship(1, float(index)), [2], 1)
		_check(bool(sent.get("accepted", false)), "within-window publication is accepted")
	var coalesced: Dictionary = server.publish_moving_interior_snapshot(_relationship(1, 9.0), [2], 1)
	_check(coalesced.get("status") == &"moving_interior_snapshot_coalesced", "superseded presentation coalesces")
	var metrics: Dictionary = server.get_moving_interior_budget_snapshot(2)
	_check(int(metrics.get("coalesced_count", 0)) == 1, "coalesced metric is detached")
	_check(int(metrics.get("pending_count", 0)) == 1, "latest presentation remains pending")
	var forced_generation: Dictionary = server.publish_moving_interior_snapshot(_relationship(1, 10.0, 2), [2], 1)
	_check(bool(forced_generation.get("accepted", false)), "generation transition bypasses presentation budget")
	metrics = server.get_moving_interior_budget_snapshot(2)
	_check(int(metrics.get("forced_transition_count", 0)) >= 1, "forced transition metric is detached")
	var flushed: Dictionary = server.publish_moving_interior_snapshot(_relationship(11, 11.0, 2), [2], 11)
	_check(bool(flushed.get("accepted", false)), "new logical window flushes pending state")
	server._seat_moving_relationships["2:crew_7"] = _relationship(11, 11.0, 2)
	_check(server.publish_moving_interior_resync(2, 11).accepted, "resync records current entity set")
	server._seat_moving_relationships.erase("2:crew_7")
	var released: Dictionary = server.publish_moving_interior_resync(2, 11)
	_check(bool(released.get("accepted", false)), "release transition is never coalesced")
	_check(int(released.get("released_count", 0)) == 1, "resync preserves release transition")
	metrics = server.get_moving_interior_budget_snapshot(2)
	_check(int(metrics.get("transition_count", 0)) >= 2, "release and generation transitions are counted")
	server._on_peer_disconnected(2)
	_check(server.get_moving_interior_budget_snapshot(2).is_empty(), "disconnect clears recipient budget")
	server.free()
	if _failures.is_empty():
		print("OK: ENet moving interior budget (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _relationship(tick: int, x: float, generation: int = 1) -> Dictionary:
	return Relationship.create(
		tick, &"crew_7", generation, &"halyard_frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0))
	).get_snapshot()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
