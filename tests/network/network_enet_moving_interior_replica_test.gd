extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

## Relationship arrivals are recorded on the replica's real-seconds axis, so a
## caller's sample time is seconds too: `TICK_SECONDS` converts the tick numbers
## this suite publishes into the same axis. A raw tick number here would sample
## whole seconds past every arrival and read as extrapolation.
const TICK_SECONDS := Adapter.MOVING_INTERIOR_SERVER_TICK_SECONDS

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.consume_moving_interior_snapshot(_packet(1, 1, 0.0)).accepted,
		"accepted relationship feeds the replica")
	_check(adapter.consume_moving_interior_snapshot(_packet(2, 2, 1.0)).accepted,
		"ordered relationship advances the replica")
	var sampled: Dictionary = adapter.sample_moving_interior_replica(&"crew_7", 1.5 * TICK_SECONDS)
	_check(sampled.get("status") == &"interpolated", "caller time samples interpolated pose")
	_check(is_equal_approx((sampled.get("transform", Transform3D.IDENTITY) as Transform3D).origin.x, 0.5),
		"adapter exposes frame-local interpolated pose")
	_check(adapter.sample_moving_interior_replica(&"unknown", 1.5 * TICK_SECONDS).get("status") == &"entity_not_tracked",
		"unknown entities remain detached")
	_check(adapter.reset_snapshot_jitter(2).accepted, "migration resets the replica generation")
	_check(adapter.consume_moving_interior_snapshot(_packet(1, 1, 3.0)).accepted,
		"fresh generation re-enters the replica")
	_check(adapter.detach_moving_interior_replica(&"crew_7").accepted, "caller detach clears replica state")
	_check(adapter.sample_moving_interior_replica(&"crew_7", 2.0 * TICK_SECONDS).get("status") == &"entity_not_tracked",
		"detached entity cannot reappear")
	adapter.free()
	if _failures.is_empty():
		print("OK: ENet moving interior replica (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, tick: int, x: float) -> Dictionary:
	var relationship := Relationship.create(
		tick, &"crew_7", 1, &"halyard_frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0))
	).get_snapshot()
	return {"revision": revision, "server_tick": tick, "relationship": relationship}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
