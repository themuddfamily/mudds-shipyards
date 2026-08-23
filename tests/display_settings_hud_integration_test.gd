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
	hud.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("display_settings_hud_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
