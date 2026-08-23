extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var controls := hud.get("_settings_controls") as Dictionary
	var flash := controls[&"reduced_flash"] as CheckButton
	var intensity := controls[&"payload_visual_intensity"] as OptionButton
	_check(flash.focus_mode == Control.FOCUS_ALL and not flash.tooltip_text.is_empty(), "reduced flash exposes focused accessible description")
	_check(flash.tooltip_text.contains("OFF"), "reduced flash description reflects disabled value")
	_check(intensity.focus_mode == Control.FOCUS_ALL and intensity.tooltip_text.contains("High"), "payload intensity description reflects default value")
	hud.set_settings_snapshot({"reduced_flash": true, "payload_visual_intensity": 0})
	_check(flash.tooltip_text.contains("ON"), "reduced flash description updates live")
	_check(intensity.tooltip_text.contains("Low"), "payload intensity description updates live")
	hud.apply_bomber_payload_snapshot({"generation": 1, "active": true, "ammo": 1, "cooldown_remaining": 0.0})
	var action_button := (hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) as Button
	_check(action_button.focus_mode == Control.FOCUS_ALL and action_button.tooltip_text.contains("Release bomber payload"), "bomber action exposes focused accessible description")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HUD_ACCESSIBILITY_DESCRIPTIONS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
