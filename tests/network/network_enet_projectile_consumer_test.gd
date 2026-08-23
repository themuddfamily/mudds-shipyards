extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.reset_snapshot_jitter(12).accepted, "projectile consumer resets timing state")
	var held := adapter.consume_projectile_snapshot(_packet(2, 2001, Vector3(2.0, 0.0, 0.0)))
	_check(held.accepted and held.samples.is_empty(), "out-of-order projectile snapshot waits for its predecessor")
	var baseline := adapter.consume_projectile_snapshot(_packet(1, 2000, Vector3.ZERO))
	_check(baseline.accepted and baseline.samples.size() == 2, "delayed predecessor releases projectile snapshots in order")
	var next := adapter.consume_projectile_snapshot(_packet(3, 2002, Vector3(4.0, 0.0, 0.0)), 0.5)
	var next_samples: Array = next.get("samples", []) as Array
	_check(next.accepted and next_samples.size() == 1
		and is_equal_approx((next_samples[0] as Dictionary).position.x, 3.0),
		"projectile presentation interpolates without changing server state")
	var dropped := adapter.consume_projectile_snapshot(_packet(5, 2004, Vector3(8.0, 0.0, 0.0)))
	_check(dropped.accepted and dropped.status == &"projectile_waiting_for_gap"
		and bool(dropped.frozen) and is_equal_approx(
			(dropped.samples[0] as Dictionary).position.x, 3.0
		), "lost projectile snapshot freezes its last presentation")
	_check(adapter.consume_projectile_snapshot(_packet(6, 1999, Vector3(9.0, 0.0, 0.0))).status == &"stale_server_tick",
		"stale projectile timing is rejected")
	var recovered := adapter.consume_projectile_snapshot(_packet(4, 2003, Vector3(6.0, 0.0, 0.0)))
	_check(recovered.accepted and recovered.samples.size() == 2,
		"projectile presentation resumes after the missing snapshot arrives")
	_check(adapter.reset_snapshot_jitter(13).accepted
		and adapter.get_snapshot_jitter_state().next_revision == 1,
		"migration reset clears projectile and shared timing cursors")
	if _failures.is_empty():
		print("OK: ENet projectile consumer (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, server_tick: int, position: Vector3) -> Dictionary:
	return {
		"revision": revision,
		"server_tick": server_tick,
		"projectile": {
			"projectile_id": &"projectile_7",
			"position": position,
		},
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
