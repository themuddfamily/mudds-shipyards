extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.reset_snapshot_jitter(40).accepted, "boarding consumer resets timing state")
	_check(adapter.consume_boarding_ownership_snapshot(_packet(2, 5001, 8, true)).samples.is_empty(), "out-of-order seat snapshot waits")
	var baseline := adapter.consume_boarding_ownership_snapshot(_packet(1, 5000, 8, true))
	_check(baseline.accepted and baseline.samples.size() == 2, "delayed boarding predecessor releases in order")
	var dropped := adapter.consume_boarding_ownership_snapshot(_packet(4, 5003, 9, false))
	_check(dropped.accepted and dropped.status == &"boarding_waiting_for_gap"
		and bool(dropped.frozen) and int((dropped.samples[0] as Dictionary).owner_peer_id) == 8
		and bool((dropped.samples[0] as Dictionary).seat_occupied),
		"lost ownership snapshot freezes seat and owner presentation")
	_check(adapter.consume_boarding_ownership_snapshot(_packet(5, 4999, 10, false)).status == &"stale_server_tick",
		"stale boarding timing is rejected")
	var recovered := adapter.consume_boarding_ownership_snapshot(_packet(3, 5002, 9, false))
	_check(recovered.accepted and recovered.samples.size() == 2
		and int((recovered.samples[0] as Dictionary).owner_peer_id) == 9
		and not bool((recovered.samples[0] as Dictionary).seat_occupied),
		"boarding presentation resumes ownership and seat changes in order")
	_check(adapter.reset_snapshot_jitter(41).accepted, "migration reset clears boarding presentation state")
	if _failures.is_empty():
		print("OK: ENet boarding ownership consumer (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, server_tick: int, owner_peer_id: int, occupied: bool) -> Dictionary:
	return {
		"revision": revision,
		"server_tick": server_tick,
		"boarding": {
			"ship_id": &"ship_7",
			"seat_id": &"seat_pilot",
			"occupied": occupied,
		},
		"ownership": {"ship_id": &"ship_7", "owner_peer_id": owner_peer_id},
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
