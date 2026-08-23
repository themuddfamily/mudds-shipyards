extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.reset_snapshot_jitter(60).accepted, "interest consumer resets lifecycle state")
	var entered := adapter.consume_interest_snapshot(_packet(1, 7000, true, 10, {"position": 1}))
	_check(entered.accepted and entered.samples.size() == 1
		and bool((entered.samples[0] as Dictionary).entered), "interest entry starts a clean presentation cursor")
	var updated := adapter.consume_interest_snapshot(_packet(2, 7001, true, 11, {"position": 2}))
	_check(updated.accepted and not bool((updated.samples[0] as Dictionary).entered), "interest update reuses only the current cursor")
	var exited := adapter.consume_interest_snapshot(_packet(3, 7002, false, 12, {}))
	_check(exited.accepted and not bool((exited.samples[0] as Dictionary).in_interest), "interest exit retires presentation state")
	_check(adapter.consume_interest_snapshot(_packet(2, 7001, true, 11, {"position": 2})).status == &"stale_or_duplicate",
		"stale packet cannot resurrect an exited entity")
	var reentered := adapter.consume_interest_snapshot(_packet(4, 7003, true, 13, {"position": 4}))
	_check(reentered.accepted and bool((reentered.samples[0] as Dictionary).entered), "new interest entry starts clean after exit")
	_check(adapter.reset_snapshot_jitter(61).accepted, "migration reset clears interest presentation lifecycle")
	if _failures.is_empty():
		print("OK: ENet interest consumer (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, server_tick: int, in_interest: bool, state_revision: int, state: Dictionary) -> Dictionary:
	return {
		"revision": revision,
		"server_tick": server_tick,
		"interest": {
			"entity_id": &"asteroid_7",
			"in_interest": in_interest,
			"state_revision": state_revision,
			"state": state,
		},
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
