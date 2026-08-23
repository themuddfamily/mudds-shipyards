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
	var captions := controls.get(&"captions_enabled") as CheckButton
	captions.button_pressed = not captions.button_pressed
	_check(hud.has_unsaved_settings(), "live setting edit marks settings unsaved")
	_check(
		not hud.present_settings_persistence_result({"accepted": false, "reason": &"disk_unavailable"}),
		"save failure remains rejected"
	)
	_check(hud.has_unsaved_settings(), "save failure preserves unsaved state")
	var status_label := hud.get("_settings_status_label") as Label
	_check(str(status_label.text).begins_with("SAVE FAILED"), "save failure is explicitly readable")
	_check(
		hud.present_settings_persistence_result({"accepted": true}, &"save"),
		"accepted save clears persistence feedback"
	)
	_check(not hud.has_unsaved_settings(), "accepted save clears unsaved state")
	_check(status_label.text == "SETTINGS SAVED", "accepted save has clear confirmation")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SETTINGS_PERSISTENCE_FEEDBACK_UI_TEST_OK (%d assertions)" % _assertions)
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
