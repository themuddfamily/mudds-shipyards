extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.reset_snapshot_jitter(50).accepted, "migration consumer resets timing state")
	_check(adapter.consume_migration_session_snapshot(_packet(2, 6001, 50, 7)).samples.is_empty(), "out-of-order migration state waits")
	var baseline := adapter.consume_migration_session_snapshot(_packet(1, 6000, 50, 7))
	_check(baseline.accepted and baseline.samples.size() == 2, "delayed migration predecessor releases in order")
	var dropped := adapter.consume_migration_session_snapshot(_packet(4, 6003, 50, 8))
	_check(dropped.accepted and dropped.status == &"migration_waiting_for_gap"
		and bool(dropped.frozen) and int((dropped.samples[0] as Dictionary).host_peer_id) == 7,
		"lost migration state freezes the prior host presentation")
	_check(adapter.consume_migration_session_snapshot(_packet(5, 5999, 50, 9)).status == &"stale_server_tick",
		"stale migration timing is rejected")
	var recovered := adapter.consume_migration_session_snapshot(_packet(3, 6002, 50, 8))
	_check(recovered.accepted and recovered.samples.size() == 2
		and int((recovered.samples[0] as Dictionary).host_peer_id) == 8,
		"migration state resumes after the missing revision")
	var changed := adapter.consume_migration_session_snapshot(_packet(1, 6100, 51, 9))
	_check(changed.accepted and changed.samples.size() == 1
		and int((changed.samples[0] as Dictionary).migration_generation) == 51,
		"new migration generation clears stale cursors")
	_check(adapter.consume_migration_session_snapshot(_packet(2, 6101, 50, 7)).status == &"stale_migration_generation",
		"old migration generation is rejected after handoff")
	if _failures.is_empty():
		print("OK: ENet migration consumer (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, server_tick: int, generation: int, host_peer_id: int) -> Dictionary:
	return {
		"revision": revision,
		"server_tick": server_tick,
		"migration_generation": generation,
		"session": {"host_peer_id": host_peer_id, "admitted_peer_count": 2},
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
