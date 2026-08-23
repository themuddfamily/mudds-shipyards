extends SceneTree

const Presenter := preload("res://scripts/ui/safe_start_recovery_presenter.gd")
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := Presenter.new()
	var snapshot := presenter.present_receipt({
		"graphics_recovery_receipt": {"consumed": false, "prior_values": {"graphics_profile": "high"}},
		"audio_recovery_receipt": {"consumed": false, "prior_values": {"music_volume": 0.6}},
		"stability_confirmed": true,
	})
	_check(snapshot.status == &"safe_mode_active" and snapshot.title == "Safe Settings Active", "recovery receipt becomes explicit safe-mode copy")
	_check(snapshot.actions.size() == 2 and snapshot.actions[0].focusable and snapshot.actions[1].focusable, "restore and keep-safe actions are controller-focusable")
	_check(presenter.request_restore().accepted and presenter.request_keep_safe().accepted, "recovery actions return external presentation intents")
	var detached := presenter.get_snapshot()
	(detached.details as Dictionary)["stability_confirmed"] = false
	_check(bool(presenter.get_snapshot().details.stability_confirmed), "presented recovery details are detached")
	var invalid := presenter.present_receipt({"graphics_recovery_receipt": {}})
	_check(invalid.status == &"invalid" and invalid.actions.size() == 1 and presenter.request_restore().accepted == false, "incomplete receipts fail closed to keep-safe only")
	if _failures.is_empty():
		print("SAFE_START_RECOVERY_PRESENTER_TEST_OK: 5 assertions")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
