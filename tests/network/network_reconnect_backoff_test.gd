extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	var first := adapter.schedule_reconnect_attempt(1000)
	_check(first.accepted and int(first.attempt) == 1 and int(first.delay_milliseconds) == 250,
		"first reconnect attempt uses the deterministic base delay")
	var early := adapter.schedule_reconnect_attempt(1100)
	_check(not early.accepted and early.status == &"reconnect_backoff_active"
		and int(early.retry_after_milliseconds) == 150, "caller cannot bypass active backoff")
	var second := adapter.schedule_reconnect_attempt(1250)
	_check(second.accepted and int(second.attempt) == 2 and int(second.delay_milliseconds) == 500,
		"retry backoff doubles at the next eligible caller attempt")
	var capped := adapter.schedule_reconnect_attempt(1750)
	_check(capped.accepted and int(capped.delay_milliseconds) == 1000, "backoff remains bounded and deterministic")
	_check(adapter.mark_reconnect_succeeded().accepted
		and int(adapter.get_reconnect_backoff_state().attempts) == 0,
		"successful reconnect clears retry state")
	var restart := adapter.schedule_reconnect_attempt(2000)
	_check(restart.accepted and int(restart.attempt) == 1, "a later reconnect starts from the base attempt")
	_check(adapter.reset_snapshot_jitter(72).accepted
		and int(adapter.get_reconnect_backoff_state().attempts) == 0,
		"migration reset clears reconnect backoff state")
	if _failures.is_empty():
		print("OK: reconnect backoff (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
