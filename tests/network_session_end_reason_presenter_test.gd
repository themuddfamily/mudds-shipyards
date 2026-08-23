extends SceneTree

const Presenter := preload("res://scripts/ui/network_session_status_presenter.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	var reasons := [
		[&"timeout", "Session timed out."],
		[&"rejected", "Session request was rejected."],
		[&"protocol_mismatch", "Session protocol is incompatible."],
		[&"host_migration", "Session host changed."],
		[&"manual_leave", "You left the session."],
	]
	for reason_pair in reasons:
		var snapshot := presenter.present_snapshot({"state": &"disconnected", "end_reason": reason_pair[0]})
		_check(snapshot.end_reason == reason_pair[0] and snapshot.message == reason_pair[1], "reason %s maps to concise message" % reason_pair[0])
	var unknown := presenter.present_snapshot({"state": &"disconnected", "end_reason": &"new_reason"})
	_check(unknown.end_reason == &"unknown" and unknown.message == "Session ended.", "unknown reason fails closed")
	var reconnecting := presenter.present_snapshot({"state": &"reconnecting", "end_reason": &"timeout"})
	_check(reconnecting.end_reason == &"" and not reconnecting.message.contains("timed out"), "reconnect clears stale end reason")
	if _failures.is_empty():
		print("NETWORK_SESSION_END_REASON_PRESENTER_TEST_OK (%d assertions)" % _assertions)
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
