extends SceneTree

const Replica := preload("res://scripts/network/network_moving_interior_replica.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var replica := Replica.new(1, 2, 0.0, 0.25, 4.0)
	_check(replica.accept_snapshot(1, _packet(1, 1, 0.0, 1.0), 1, 0.0).accepted,
		"first authoritative sample is accepted")
	_check(replica.accept_snapshot(1, _packet(2, 2, 1.0, 1.0), 1, 1.0).accepted,
		"second authoritative sample is accepted")
	var interpolated: Dictionary = replica.sample(&"crew_7", 0.5)
	_check(interpolated.get("status") == &"interpolated", "samples interpolate at caller time")
	_check(is_equal_approx((interpolated.get("transform", Transform3D.IDENTITY) as Transform3D).origin.x, 0.5),
		"interpolation uses frame-local pose")
	var stale: Dictionary = replica.accept_snapshot(1, _packet(3, 2, 2.0, 1.0), 1, 1.5)
	_check(stale.get("status") == &"stale_or_reordered_tick", "reordered ticks are rejected")
	var gap: Dictionary = replica.accept_snapshot(1, _packet(4, 5, 2.0, 0.0), 1, 2.0)
	_check(gap.get("status") == &"gap_hold", "large gaps freeze presentation")
	_check(replica.sample(&"crew_7", 3.0).get("status") == &"frozen", "frozen sample does not extrapolate")
	var teleported: Dictionary = replica.accept_snapshot(1, _packet(5, 6, 20.0, 0.0), 1, 3.0)
	_check(teleported.get("status") == &"teleported", "large displacement snaps without interpolation")
	_check(replica.reset_migration(1, 2).accepted, "generation change resets replica")
	_check(replica.sample(&"crew_7", 4.0).get("status") == &"entity_not_tracked", "reset clears stale entity")
	_check(replica.accept_snapshot(1, _packet(1, 1, 3.0, 0.0), 2, 4.0).accepted,
		"new generation re-enters cleanly")
	_check(replica.detach_entity(&"crew_7").accepted, "detach retires presentation state")
	_check(replica.sample(&"crew_7", 5.0).get("status") == &"entity_not_tracked", "detached entity cannot resurrect")
	if _failures.is_empty():
		print("OK: moving interior replica (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, tick: int, x: float, velocity: float) -> Dictionary:
	var relationship := Relationship.create(
		tick, &"crew_7", 1, &"halyard_frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0)),
		Vector3(velocity, 0.0, 0.0), Vector3.ZERO, revision
	)
	return relationship.get_snapshot()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
