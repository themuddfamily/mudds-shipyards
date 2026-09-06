extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _failures := PackedStringArray()
var _assertions := 0
var _events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	hud.setting_change_requested.connect(func(key: StringName, value: Variant) -> void:
		_events.append({"key": key, "value": value})
	)
	await process_frame
	var controls := hud.get("_settings_controls") as Dictionary
	for key: StringName in [&"window_mode", &"display_resolution", &"vsync_mode"]:
		var control := controls.get(key) as OptionButton
		_check(control != null and control.focus_mode == Control.FOCUS_ALL, "%s is a focusable production setting" % key)
		_check(control != null and control.item_count > 0, "%s exposes bounded choices" % key)
	hud.set_settings_snapshot({
		"window_mode": &"borderless",
		"display_resolution": "2560x1440",
		"vsync_mode": &"adaptive",
	})
	var presenter_snapshot: Dictionary = (hud.get("_runtime_display_settings_presenter") as RefCounted).get_snapshot()
	_check(presenter_snapshot.window_mode == &"borderless" and presenter_snapshot.display_resolution == &"2560x1440" and presenter_snapshot.vsync_mode == &"adaptive", "HUD refreshes presenter from persisted snapshot")
	hud.call("_on_setting_value_changed", &"window_mode", 2)
	hud.call("_on_setting_value_changed", &"display_resolution", 0)
	hud.call("_on_setting_value_changed", &"vsync_mode", 0)
	_check(_events.size() == 3, "display controls route exactly one transaction intent each")
	_check(_events[0].value == &"fullscreen" and _events[1].value == "1280x720" and _events[2].value == &"off", "display intents use stable persisted IDs")
	hud.call("show_display_settings_confirmation", 7, 15.0)
	var confirmation := hud.get("_display_confirmation_panel") as Control
	var confirmation_label := hud.get("_display_confirmation_label") as Label
	var summary_label := hud.get("_display_confirmation_summary_label") as Label
	var keep_button := hud.get("_display_confirmation_keep_button") as Button
	var revert_button := hud.get("_display_confirmation_revert_button") as Button
	_check(confirmation.visible and confirmation_label.text.contains("REVERT IN: 15 SECONDS"), "display preview exposes an explicit seconds countdown")
	_check(summary_label.text == "PENDING DISPLAY  //  1280 × 720  //  Fullscreen", "display preview names pending resolution and window mode")
	_check(keep_button.text == "KEEP DISPLAY" and revert_button.text == "REVERT DISPLAY", "display preview exposes text-first keep and revert actions")
	_check(keep_button.tooltip_text.contains("Keep") and revert_button.tooltip_text.contains("Revert"), "display actions expose nonvisual descriptions")
	_check(keep_button.focus_mode == Control.FOCUS_ALL and revert_button.focus_mode == Control.FOCUS_ALL, "display actions remain keyboard/controller focusable")
	hud.call("present_display_settings_result", "DISPLAY CHANGE REVERTED // TIMEOUT")
	_check(confirmation.visible and not confirmation_label.visible and (hud.get("_display_confirmation_result_label") as Label).text.contains("TIMEOUT"), "display timeout/revert result remains text-readable")
	hud.call("clear_display_settings_confirmation")
	_check(not confirmation.visible, "display confirmation clears on keep/revert completion")
	hud.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("DISPLAY_SETTINGS_HUD_INTEGRATION_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
