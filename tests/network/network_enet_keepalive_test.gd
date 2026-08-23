extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _timeouts: Array[int] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	root.add_child(adapter)
	_check(adapter.host(29126, 2).accepted, "server starts keepalive session")
	_check(adapter.configure_peer_keepalive(10).accepted, "keepalive timeout is bounded and configured")
	adapter.peer_keepalive_timeout.connect(func(peer_id: int, _receipt: Dictionary) -> void: _timeouts.append(peer_id))
	adapter._peer_generations[7] = 3
	_check(adapter.refresh_peer_keepalive(1, 7, 3, 100).accepted, "admitted peer heartbeat refreshes deadline")
	_check(adapter.check_peer_keepalives(1, 109).timed_out_peer_ids.is_empty(), "live heartbeat is retained")
	var checked := adapter.check_peer_keepalives(1, 110)
	_check(checked.timed_out_peer_ids == [7] and _timeouts == [7], "expired peer is normalized as timeout")
	_check(not adapter._peer_generations.has(7), "timeout releases peer capacity and authority state")
	_check(adapter.refresh_peer_keepalive(1, 7, 3, 200).status == &"stale_peer_generation", "retired generation cannot refresh")
	adapter.shutdown(&"test_complete")
	if _failures.is_empty():
		print("OK: ENet keepalive (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
