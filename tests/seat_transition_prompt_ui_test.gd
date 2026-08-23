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
	hud.present_seat_transition_prompt(&"board", "Torrent")
	var label := hud.get("_interaction_label") as Label
	var panel := hud.get("_interaction_panel") as Control
	_check(panel.visible, "boarding transition prompt is visible")
	_check(label.text.contains("BOARD") and label.text.contains("TORRENT"), "boarding prompt names transition and subject")
	_check(label.text.begins_with("["), "boarding prompt exposes a live glyph slot")
	hud._on_controller_glyph_family_selected(1)
	hud.present_seat_transition_prompt(&"exit")
	_check(label.text.contains("EXIT SEAT"), "exit-seat transition has explicit contextual copy")
	hud.dismiss_seat_transition_prompt()
	_check(not panel.visible, "explicit dismissal hides prompt without gameplay authority")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SEAT_TRANSITION_PROMPT_UI_TEST_OK (%d assertions)" % _assertions)
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
