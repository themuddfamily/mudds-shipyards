extends SceneTree

const Presenter := preload("res://scripts/ui/first_sortie_tutorial_presenter.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	var board := presenter.present_snapshot({"step_id": &"board", "input_family": &"controller", "glyphs": {&"interact": "X"}})
	_check(board.title == "Board" and board.prompt.contains("X"), "controller board prompt resolves glyph")
	_check(board.actions.size() == 3 and board.actions[2].focusable, "tutorial actions are controller-focusable")
	var fire := presenter.present_snapshot({"step_id": &"fire", "input_family": &"keyboard"})
	_check(fire.prompt.contains("LMB") and fire.step_index == 4, "keyboard fire prompt is readable")
	var accessible := presenter.present_snapshot({"step_id": &"return_land", "accessible": true})
	_check(accessible.prompt == accessible.accessible_prompt, "accessible mode uses descriptive prompt")
	var dismiss := presenter.request(&"dismiss")
	_check(dismiss.accepted and dismiss.completion_intent.persist, "dismiss returns caller-owned completion intent")
	var invalid := presenter.present_snapshot({"step_id": &"combat"})
	_check(not invalid.accepted, "unknown tutorial step fails closed")
	if _failures.is_empty():
		print("FIRST_SORTIE_TUTORIAL_PRESENTER_TEST_OK (%d assertions)" % _assertions)
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
