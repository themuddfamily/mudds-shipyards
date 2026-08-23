extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.reset_snapshot_jitter(20).accepted, "landing consumer resets timing state")
	var held := adapter.consume_landing_snapshot(_packet(2, 3001, Vector3(2.0, 0.0, 0.0)))
	_check(held.accepted and held.samples.is_empty(), "out-of-order landing snapshot waits")
	var baseline := adapter.consume_landing_snapshot(_packet(1, 3000, Vector3.ZERO))
	_check(baseline.accepted and baseline.samples.size() == 2, "delayed landing predecessor releases in order")
	var next := adapter.consume_landing_snapshot(_packet(3, 3002, Vector3(4.0, 0.0, 0.0)), 0.5)
	var next_samples: Array = next.get("samples", []) as Array
	_check(next.accepted and next_samples.size() == 1
		and is_equal_approx((next_samples[0] as Dictionary).position.x, 3.0)
		and (next_samples[0] as Dictionary).state == &"landed",
		"landing presentation interpolates while retaining authoritative state")
	var dropped := adapter.consume_landing_snapshot(_packet(5, 3004, Vector3(8.0, 0.0, 0.0)))
	_check(dropped.accepted and dropped.status == &"landing_waiting_for_gap"
		and bool(dropped.frozen) and is_equal_approx(
			(dropped.samples[0] as Dictionary).position.x, 3.0
		), "lost landing snapshot freezes its last presentation")
	_check(adapter.consume_landing_snapshot(_packet(6, 2999, Vector3(9.0, 0.0, 0.0))).status == &"stale_server_tick",
		"stale landing timing is rejected")
	var recovered := adapter.consume_landing_snapshot(_packet(4, 3003, Vector3(6.0, 0.0, 0.0)))
	_check(recovered.accepted and recovered.samples.size() == 2,
		"landing presentation resumes after the missing snapshot")
	_check(adapter.reset_snapshot_jitter(21).accepted,
		"migration reset clears landing presentation state")
	if _failures.is_empty():
		print("OK: ENet landing consumer (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, server_tick: int, position: Vector3) -> Dictionary:
	return {
		"revision": revision,
		"server_tick": server_tick,
		"landing": {
			"entity_id": &"lander_7",
			"position": position,
			"state": &"landed",
		},
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
