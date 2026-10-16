extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _reset_requests := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_paused(true)
	hud.call("_show_settings_page")
	await process_frame
	hud.settings_reset_requested.connect(func() -> void:
		_reset_requests += 1
		hud.set_settings_status(
			"DEFAULTS ACTIVE  //  SAVE FAILED" if _reset_requests == 1 else "DEFAULTS RESTORED + SAVED",
			_reset_requests > 1
		)
	)
	var controls := hud.get("_settings_controls") as Dictionary
	var captions := controls.get(&"captions_enabled") as CheckButton
	captions.button_pressed = not captions.button_pressed
	var reset := hud.get("_settings_page").find_child("SettingsResetButton", true, false) as Button
	reset.pressed.emit()
	var confirmation := hud.get("_settings_reset_confirmation") as Control
	var confirm := confirmation.find_child("ConfirmSettingsResetButton", true, false) as Button
	_check(confirmation.visible and confirm.has_focus(), "dirty reset opens controller-focusable confirmation")
	var cancel := confirmation.find_child("CancelSettingsResetButton", true, false) as Button
	cancel.pressed.emit()
	_check(not confirmation.visible and _reset_requests == 0, "cancel preserves edits without reset intent")
	reset.pressed.emit()
	confirm.pressed.emit()
	_check(not confirmation.visible and _reset_requests == 1, "confirm emits existing reset intent")
	var status_label := hud.get("_settings_status_label") as Label
	_check(status_label.text == "DEFAULTS ACTIVE  //  SAVE FAILED", "confirmed reset preserves synchronous failure feedback")
	_check(reset.has_focus(), "confirm returns controller focus to the visible settings reset control")
	hud.call("_show_pause_main")
	hud.call("_show_settings_page")
	await process_frame
	_check(reset.has_focus(), "settings re-entry retains the reset entry instead of the hidden confirmation")
	reset.pressed.emit()
	_check(confirm.has_focus() and confirmation.visible, "restored reset control can reopen confirmation")
	cancel.pressed.emit()
	_check(reset.has_focus() and _reset_requests == 1, "cancel after confirmed reset retains navigation without another intent")
	_check(hud.has_unsaved_settings(), "confirmation does not pretend reset persistence completed")
	reset.pressed.emit()
	confirm.pressed.emit()
	_check(_reset_requests == 2 and status_label.text == "DEFAULTS RESTORED + SAVED", "confirmed reset preserves synchronous success feedback")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SETTINGS_RESET_CONFIRMATION_UI_TEST_OK (%d assertions)" % _assertions)
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
