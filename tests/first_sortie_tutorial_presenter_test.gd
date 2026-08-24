extends SceneTree

const Presenter := preload("res://scripts/ui/first_sortie_tutorial_presenter.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	var board := presenter.present_snapshot({"step_id": &"board", "generation": 4, "input_family": &"controller", "glyphs": {&"interact": "X"}})
	_check(board.title == "Board" and board.prompt.contains("X"), "controller board prompt resolves glyph")
	_check(board.actions.size() == 3 and board.actions[2].focusable, "tutorial actions are controller-focusable")
	_check(
		board.color_independent
		and board.prompt.contains("PROGRESS // STEP 2 OF 7")
		and board.prompt.contains("NEXT ACTION // BOARD CRAFT // INTERACT")
		and board.prompt.contains("RECOVERY // OUT OF RANGE"),
		"board prompt exposes textual progress, next action, and recovery"
	)
	var board_redraw := presenter.present_snapshot({"step_id": &"board", "generation": 4, "input_family": &"keyboard", "glyphs": {&"interact": "Tab"}})
	_check(board_redraw.accepted and board_redraw.prompt.contains("Tab"), "same-step glyph redraw preserves authoritative progress")
	var launch := presenter.present_snapshot({"step_id": &"launch", "generation": 4})
	_check(launch.prompt.contains("CLEAR BAY // APPLY THRUST") and launch.revision == 3, "launch prompt names its next action")
	var fire := presenter.present_snapshot({"step_id": &"fire", "generation": 4, "input_family": &"keyboard", "glyphs": {&"fire": "LMB"}})
	_check(fire.prompt.contains("LMB") and fire.prompt.contains("REACQUIRE THE MARKED RANGE TARGET"), "range target prompt resolves glyph and recovery")
	var accessible := presenter.present_snapshot({"step_id": &"return_land", "generation": 4, "accessible": true})
	_check(accessible.prompt == accessible.accessible_prompt and accessible.prompt.contains("FOLLOW RETURN VECTOR"), "accessible return prompt retains descriptive next-action status")
	var stale_revision := presenter.present_snapshot({"step_id": &"board", "generation": 4})
	_check(not stale_revision.accepted and stale_revision.reason == &"stale_revision" and presenter.get_snapshot().step_id == &"return_land", "older step cannot replace newer authoritative progress")
	var stale_generation := presenter.present_snapshot({"step_id": &"exit", "generation": 3})
	_check(not stale_generation.accepted and stale_generation.reason == &"stale_generation", "older sortie generation is fenced")
	var dismiss := presenter.request(&"dismiss")
	_check(
		dismiss.accepted
		and dismiss.completion_intent.generation == 4
		and dismiss.completion_intent.persist
		and not dismiss.tutorial_progress_authority
		and not dismiss.gameplay_authority
		and not dismiss.input_authority
		and not dismiss.timer_authority
		and not dismiss.process_authority,
		"dismiss returns a caller-owned fenced intent without progression or runtime authority"
	)
	var actor_loss := presenter.present_snapshot({"step_id": &"exit", "generation": 4, "actor_attached": false})
	_check(not actor_loss.accepted and actor_loss.reason == &"actor_unavailable" and presenter.get_snapshot().is_empty() and not presenter.request(&"repeat").accepted, "actor loss clears retained prompt and actions")
	var reused := presenter.present_snapshot({"step_id": &"board", "generation": 0})
	_check(reused.accepted and reused.generation == 0, "cleared presenter can be reused for a new tutorial source")
	var detached := presenter.detach(&"session_lost")
	_check(not detached.attached and detached.reason == &"session_lost" and presenter.get_snapshot().is_empty(), "session detach clears retained source and fence")
	var disabled := presenter.present_snapshot({"step_id": &"board", "generation": 1, "show_tutorials": false})
	_check(not disabled.accepted and disabled.reason == &"tutorials_disabled" and not disabled.has("completion_intent"), "disabled tutorial policy hides prompts without completion")
	var invalid := presenter.present_snapshot({"step_id": &"combat", "generation": 1})
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
