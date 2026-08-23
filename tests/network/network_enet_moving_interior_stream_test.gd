extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.consume_moving_interior_snapshot(_packet(1, 1, 0.0)).status == &"moving_interior_presented",
		"ordered moving-interior snapshot presents")
	_check(adapter.consume_moving_interior_snapshot(_packet(2, 5, 0.5)).status == &"moving_interior_waiting_for_gap",
		"delayed tick gap freezes the last pose")
	var stale_result := adapter.consume_moving_interior_snapshot(_packet(3, 5, 0.2))
	_check(stale_result.get("status") == &"stale_or_reordered_tick",
		"out-of-order tick is rejected")
	var resumed_result := adapter.consume_moving_interior_snapshot(_packet(4, 6, 0.6))
	_check(resumed_result.get("status") == &"moving_interior_presented",
		"ordered update resumes presentation")
	_check(bool(adapter.reset_snapshot_jitter(2).get("accepted", false)), "migration reset is accepted")
	_check(adapter.consume_moving_interior_snapshot(_packet(1, 1, 0.0), Transform3D.IDENTITY).status == &"moving_interior_presented",
		"post-migration stream accepts a fresh revision")
	var passed := _failures.is_empty()
	adapter.free()
	if passed:
		print("OK: ENet moving interior stream (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, tick: int, x: float) -> Dictionary:
	var relationship := Relationship.create(tick, &"crew_7", 1, &"halyard_frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0))).get_snapshot()
	return {"revision": revision, "server_tick": tick, "relationship": relationship}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
