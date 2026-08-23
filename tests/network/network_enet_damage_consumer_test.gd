extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.reset_snapshot_jitter(30).accepted, "damage consumer resets timing state")
	_check(adapter.consume_damage_respawn_snapshot(_packet(2, 4001, 80.0)).samples.is_empty(), "out-of-order damage snapshot waits")
	var baseline := adapter.consume_damage_respawn_snapshot(_packet(1, 4000, 100.0))
	_check(baseline.accepted and baseline.samples.size() == 2, "delayed damage predecessor releases in order")
	var next := adapter.consume_damage_respawn_snapshot(_packet(3, 4002, 60.0), 0.5)
	var next_samples: Array = next.get("samples", []) as Array
	_check(next.accepted and next_samples.size() == 1
		and is_equal_approx(float((next_samples[0] as Dictionary).health), 70.0)
		and (next_samples[0] as Dictionary).state == &"respawning",
		"damage presentation interpolates health without mutating authority")
	var dropped := adapter.consume_damage_respawn_snapshot(_packet(5, 4004, 40.0))
	_check(dropped.accepted and dropped.status == &"damage_waiting_for_gap"
		and bool(dropped.frozen) and is_equal_approx(float((dropped.samples[0] as Dictionary).health), 70.0),
		"lost damage snapshot freezes the last presentation")
	_check(adapter.consume_damage_respawn_snapshot(_packet(6, 3999, 20.0)).status == &"stale_server_tick",
		"stale damage timing is rejected")
	var recovered := adapter.consume_damage_respawn_snapshot(_packet(4, 4003, 50.0))
	_check(recovered.accepted and recovered.samples.size() == 2, "damage presentation resumes after the missing snapshot")
	_check(adapter.reset_snapshot_jitter(31).accepted, "migration reset clears damage presentation state")
	if _failures.is_empty():
		print("OK: ENet damage consumer (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, server_tick: int, health: float) -> Dictionary:
	return {
		"revision": revision,
		"server_tick": server_tick,
		"damage": {"entity_id": &"ship_7", "health": health, "state": &"respawning"},
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
