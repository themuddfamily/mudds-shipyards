extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _requests: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var controls := hud.get("_settings_controls") as Dictionary
	_check(controls.has(&"reduced_dynamic_range"), "settings exposes reduced dynamic range control")
	var control := controls.get(&"reduced_dynamic_range") as CheckButton
	_check(control != null and control.focus_mode == Control.FOCUS_ALL, "control is controller-focusable")
	hud.setting_change_requested.connect(_on_setting_change_requested)
	control.button_pressed = true
	_check(_requests.size() == 1, "toggle emits one persistence-compatible change intent")
	_check(_requests[0].get("key") == &"reduced_dynamic_range", "intent preserves backend key")
	_check(bool(_requests[0].get("value", false)), "intent carries enabled state")
	hud.set_settings_snapshot({"captions_enabled": true})
	_check(control.button_pressed, "missing backend key retains compatible UI value")
	hud.set_settings_snapshot({"reduced_dynamic_range": false})
	_check(not control.button_pressed, "present backend key updates live snapshot")
	var tutorials := controls.get(&"show_tutorials") as CheckButton
	_check(tutorials != null and tutorials.button_pressed, "settings exposes tutorials enabled by default")
	hud.set_settings_snapshot({"show_tutorials": false})
	_check(not tutorials.button_pressed, "tutorial preference follows live settings snapshots")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("REDUCED_DYNAMIC_RANGE_SETTINGS_UI_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _on_setting_change_requested(key: StringName, value: Variant) -> void:
	_requests.append({"key": key, "value": value})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
