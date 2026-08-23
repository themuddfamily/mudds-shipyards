extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	var frame_transform := Transform3D(Basis.IDENTITY, Vector3(100.0, 0.0, 0.0))
	var first := Relationship.create(
		1200, &"pilot_7", 1, &"jovian_frame", 3,
		Transform3D(Basis.IDENTITY, Vector3(2.0, 0.0, 0.0))
	).get_snapshot()
	var second := Relationship.create(
		1201, &"pilot_7", 1, &"jovian_frame", 3,
		Transform3D(Basis.IDENTITY, Vector3(4.0, 0.0, 0.0))
	).get_snapshot()
	_check(adapter.reset_snapshot_jitter(7).accepted, "consumer resets its jitter/interpolation state")
	var held := adapter.consume_moving_interior_snapshot({
		"revision": 2, "server_tick": 1201, "relationship": second,
	}, frame_transform, 0.5)
	_check(held.samples.is_empty(), "out-of-order moving-interior sample is held")
	var released := adapter.consume_moving_interior_snapshot({
		"revision": 1, "server_tick": 1200, "relationship": first,
	}, frame_transform, 1.0)
	_check(released.accepted and released.samples.size() == 2, "baseline releases queued samples after delayed predecessor arrives")
	var next := adapter.consume_moving_interior_snapshot({
		"revision": 3, "server_tick": 1202,
		"relationship": Relationship.create(
			1202, &"pilot_7", 1, &"jovian_frame", 3,
			Transform3D(Basis.IDENTITY, Vector3(6.0, 0.0, 0.0))
		).get_snapshot(),
	}, frame_transform, 0.5)
	var samples: Array = next.get("samples", []) as Array
	var world_origin: Vector3 = Vector3.ZERO
	if not samples.is_empty():
		world_origin = (samples[0] as Dictionary).world_transform.origin
	_check(next.accepted and samples.size() == 1, "next snapshot releases in authoritative order")
	_check(is_equal_approx(world_origin.x, 105.0), "interpolation stays frame-local while resolving world position")
	_check(adapter.consume_moving_interior_snapshot({
		"revision": 4, "server_tick": 1199, "relationship": first,
	}, frame_transform).status == &"stale_server_tick", "stale delayed sample is rejected")
	if _failures.is_empty():
		print("OK: ENet moving interior consumer (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
