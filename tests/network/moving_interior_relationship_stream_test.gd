extends SceneTree

const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const Stream := preload("res://scripts/network/moving_interior_relationship_stream.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stream := Stream.new(1, 2)
	var first := _snapshot(1, 0.0)
	var resumed := _snapshot(2, 0.1)
	var delayed := _snapshot(5, 0.5)
	_check(stream.accept_snapshot(1, first).accepted, "ordered sample is accepted")
	_check(stream.accept_snapshot(1, delayed).status == &"gap_hold", "large delayed gap freezes presentation")
	_check(stream.get_presentation(&"crew_7", Transform3D.IDENTITY).frozen, "gap keeps last stable pose")
	_check(stream.accept_snapshot(1, _snapshot(2, 0.2)).status == &"stale_or_reordered_tick", "out-of-order sample is rejected")
	_check(stream.accept_snapshot(1, _snapshot(6, 0.6)).status == &"resumed", "ordered updates resume presentation")
	_check(stream.accept_snapshot(1, _snapshot(7, 0.7)).accepted, "post-resume sample remains ordered")
	_check(not stream.get_presentation(&"crew_7", Transform3D.IDENTITY).frozen, "resume clears freeze")
	_check(stream.reset_migration(1, 2).accepted and stream.get_snapshot().tracked_entities == 0, "migration reset clears lifecycle state")
	_check(stream.accept_snapshot(1, resumed, 1).status == &"stale_migration_generation", "old generation cannot re-enter")
	if _failures.is_empty():
		print("OK: moving interior relationship stream (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _snapshot(tick: int, x: float) -> Dictionary:
	return Relationship.create(tick, &"crew_7", 1, &"halyard_frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0))).get_snapshot()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
