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
	hud.set_interaction("[ E ]  BOARD TORRENT", true)
	var label := hud.get("_interaction_label") as Label
	_check(label.text.contains("BOARD TORRENT"), "boarding interaction remains contextually readable")
	_check(label.text.begins_with("["), "interaction prompt retains an explicit control glyph")
	hud._on_controller_glyph_family_selected(1)
	hud.set_interaction("[ E ]  BOARD TORRENT", true)
	_check(label.text.contains("BOARD TORRENT"), "controller glyph change preserves boarding intent")
	_check(label.text != "[ E ]  BOARD TORRENT", "controller-aware prompt remains distinct from keyboard fallback")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CONTEXTUAL_INTERACTION_PROMPT_UI_TEST_OK (%d assertions)" % _assertions)
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
