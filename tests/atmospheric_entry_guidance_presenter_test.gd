extends SceneTree

const Presenter := preload("res://scripts/ui/atmospheric_entry_guidance_presenter.gd")
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := Presenter.new()
	var critical := presenter.present_snapshot({
		"altitude_m": 412.0,
		"entry_intensity": 0.93,
		"landing_supported": false,
		"recovery_receipt": {"receipt_id": &"support-17"},
	})
	_check(critical.state == &"critical_entry" and critical.intensity_marker == &"!! ENTRY LOAD CRITICAL !!", "critical entry uses text-safe severity guidance")
	_check(critical.actions.size() == 2 and critical.actions[0].focusable and critical.actions[1].focusable, "critical entry exposes controller-focusable support and abort actions")
	_check(presenter.request_support().accepted and presenter.abort_landing().accepted, "landing actions return external intents")
	var ready := presenter.present_snapshot({"altitude_m": 18.0, "entry_intensity": 0.1, "landing_supported": true})
	_check(ready.state == &"landing_supported" and ready.actions.size() == 1 and not presenter.request_support().accepted, "supported nominal landing only exposes abort")
	var detached := presenter.get_snapshot()
	detached["guidance"] = "forged"
	_check(presenter.get_snapshot().guidance != "forged", "guidance snapshot is detached")
	if _failures.is_empty():
		print("ATMOSPHERIC_ENTRY_GUIDANCE_PRESENTER_TEST_OK: 5 assertions")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
