extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _profile_events := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var options := hud.get("_binding_option_controls") as Dictionary
	_check(options.has(&"fire"), "fire action exposes option controls")
	var fire_controls := options[&"fire"] as Dictionary
	_check(fire_controls.deadzone.focus_mode == Control.FOCUS_ALL, "deadzone is controller-focusable")
	_check(fire_controls.curve.focus_mode == Control.FOCUS_ALL, "curve choice is controller-focusable")
	_check(fire_controls.hold_mode.focus_mode == Control.FOCUS_ALL, "hold mode is controller-focusable")
	hud.setting_change_requested.connect(func(key: StringName, _value: Variant) -> void:
		if key == &"input_binding_profile":
			_profile_events += 1
	)
	(fire_controls.deadzone as HSlider).set_value(0.33)
	(fire_controls.curve as OptionButton).select(1)
	(fire_controls.curve as OptionButton).item_selected.emit(1)
	(fire_controls.hold_mode as OptionButton).select(1)
	(fire_controls.hold_mode as OptionButton).item_selected.emit(1)
	await process_frame
	var profile: Variant = hud.get("_input_binding_profile")
	var action_options: Dictionary = profile.get_action_options(&"fire")
	_check(is_equal_approx(float(action_options.deadzone), 0.33), "deadzone persists through presenter commit")
	_check(action_options.curve == &"squared", "squared curve persists through presenter commit")
	_check(action_options.hold_mode == &"toggle", "toggle mode persists through presenter commit")
	_check(_profile_events >= 1, "option changes use standard profile persistence intent")
	var status := hud.get("_settings_status_label") as Label
	_check(
		status.visible
		and status.text == "INPUT OPTIONS  //  FIRE  //  TOGGLE  //  SQUARED CURVE  //  33% DEADZONE",
		"accepted option change immediately identifies the active controller behavior",
	)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("REMAPPING_OPTIONS_UI_TEST_OK (%d assertions)" % _assertions)
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
