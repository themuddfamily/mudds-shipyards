extends SceneTree

const Presenter := preload("res://scripts/ui/network_session_status_presenter.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	var reconnecting := presenter.present_snapshot({
		"state": &"reconnecting",
		"role": &"client",
		"attempt": 4,
		"seconds_remaining": 12.5,
	})
	_check(reconnecting.title == "Reconnecting", "reconnect state has explicit title")
	_check(reconnecting.attempt == 4 and is_equal_approx(reconnecting.seconds_remaining, 12.5), "backoff receipt preserves bounded progress")
	_check(reconnecting.actions[0].id == &"cancel" and reconnecting.actions[0].focusable, "reconnect exposes controller-safe cancel")
	var bounded := presenter.present_snapshot({"state": &"reconnecting", "attempt": 1000, "seconds_remaining": 999.0})
	_check(bounded.attempt == 99 and bounded.seconds_remaining == 300.0, "backoff values are bounded")
	var connected := presenter.present_snapshot({"state": &"connected"})
	_check(connected.attempt == 0 and connected.seconds_remaining == 0.0 and not connected.backoff_active, "connected state resets backoff receipt")
	_check(presenter.request_disconnect().accepted and not presenter.request_retry().accepted, "ready state keeps only disconnect intent")
	if _failures.is_empty():
		print("NETWORK_RECONNECT_BACKOFF_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
