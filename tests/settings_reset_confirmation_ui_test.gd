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
	hud.settings_reset_requested.connect(func() -> void: _reset_requests += 1)
	var controls := hud.get("_settings_controls") as Dictionary
	var captions := controls.get(&"captions_enabled") as CheckButton
	captions.button_pressed = not captions.button_pressed
	var reset := hud.get("_settings_page").find_child("SettingsResetButton", true, false) as Button
	reset.pressed.emit()
	var confirmation := hud.get("_settings_reset_confirmation") as Control
	_check(confirmation.visible, "dirty reset opens controller-focusable confirmation")
	var cancel := confirmation.find_child("CancelSettingsResetButton", true, false) as Button
	cancel.pressed.emit()
	_check(not confirmation.visible and _reset_requests == 0, "cancel preserves edits without reset intent")
	reset.pressed.emit()
	var confirm := confirmation.find_child("ConfirmSettingsResetButton", true, false) as Button
	confirm.pressed.emit()
	_check(not confirmation.visible and _reset_requests == 1, "confirm emits existing reset intent")
	_check(hud.has_unsaved_settings(), "confirmation does not pretend reset persistence completed")
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
