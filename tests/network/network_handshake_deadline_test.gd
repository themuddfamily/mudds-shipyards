extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	var started := adapter.begin_handshake(1000, 3, 8, 1000)
	_check(started.accepted and int(started.deadline.deadline_milliseconds) == 2000,
		"handshake deadline starts with the bounded caller timeout")
	var pending := adapter.check_handshake_deadline(1500, 3, 8)
	_check(pending.accepted and pending.status == &"handshake_pending"
		and int(pending.remaining_milliseconds) == 500, "caller can inspect remaining handshake time")
	var stale := adapter.check_handshake_deadline(1500, 2, 8)
	_check(not stale.accepted and stale.status == &"stale_handshake_generation", "stale peer generation cannot advance handshake")
	var expired := adapter.check_handshake_deadline(2000, 3, 8)
	_check(not expired.accepted and expired.status == &"handshake_timeout"
		and adapter.get_session_end_reason_snapshot().reason == &"timeout", "deadline normalizes expiration as timeout")
	_check(adapter.begin_handshake(3000, 4, 9, 1000).accepted
		and adapter.accept_handshake(4, 9).accepted
		and not bool(adapter.get_handshake_deadline_state().active), "accepted handshake clears its deadline")
	_check(adapter.begin_handshake(4000, 5, 10, 1000).accepted
		and adapter.reset_snapshot_jitter(11).accepted
		and not bool(adapter.get_handshake_deadline_state().active), "migration reset clears pending handshake")
	if _failures.is_empty():
		print("OK: handshake deadline (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
