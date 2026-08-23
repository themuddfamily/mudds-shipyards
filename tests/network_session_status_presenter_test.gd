extends SceneTree

const Presenter := preload("res://scripts/ui/network_session_status_presenter.gd")
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := Presenter.new()
	var connecting := presenter.present_snapshot({"state": &"connecting", "role": &"host"})
	_check(connecting.title == "Connecting" and connecting.actions[0].id == &"cancel" and connecting.actions[0].focusable, "connecting state exposes a focusable cancel action")
	var connected := presenter.present_snapshot({"state": &"connected", "role": &"client", "detail": "Joined Cinder Run."})
	_check(connected.message == "Joined Cinder Run." and connected.actions[0].id == &"disconnect", "connected state exposes readable detail and disconnect")
	_check(presenter.request_disconnect().accepted and not presenter.request_retry().accepted, "connected intents remain bounded to disconnect")
	var failed := presenter.present_snapshot({"state": &"failed", "detail": "Admission was refused.", "retryable": true})
	_check(failed.title == "Connection Failed" and failed.actions.size() == 2 and failed.actions[0].id == &"retry", "failed state exposes retry and cancel actions")
	_check(presenter.request_retry().accepted and presenter.request_cancel().accepted, "failure actions return external intents")
	var invalid := presenter.present_snapshot({"state": &"mystery"})
	_check(invalid.state == &"failed" and invalid.actions[0].focusable and not presenter.request_retry().accepted, "unknown state fails closed without retry authority")
	if _failures.is_empty():
		print("NETWORK_SESSION_STATUS_PRESENTER_TEST_OK: 6 assertions")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
