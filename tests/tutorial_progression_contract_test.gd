extends SceneTree

const Contract := preload("res://scripts/ui/tutorial_progression_contract.gd")
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tutorial := Contract.new()
	var definitions := [
		{"id": &"look", "checkpoint_id": &"look_seen", "title": "Look around", "controller_prompt": "Right Stick: look around", "keyboard_prompt": "Mouse: look around", "accessible_prompt": "Look around using your preferred camera control."},
		{"id": &"board", "checkpoint_id": &"board_seen", "controller_prompt": "{confirm}: board spacecraft", "keyboard_prompt": "E: board spacecraft", "accessible_prompt": "Board the spacecraft when the boarding prompt is visible."},
	]
	var configured := tutorial.configure(definitions)
	_check(configured.accepted and configured.step_count == 2, "two authored onboarding steps configure")
	var audit := tutorial.audit()
	_check(audit.valid and audit.controller_first_default and audit.checkpointed and audit.accessibility_prompt_variant, "audit exposes controller-first checkpoint and accessibility guarantees")
	_check(not audit.reads_input_map and not audit.gameplay_authority and not audit.player_authority and not audit.ship_authority and not audit.save_authority, "tutorial owns no input, gameplay, ship, player, or save authority")
	var started := tutorial.start()
	_check(started.accepted and tutorial.current_step().id == &"look", "start selects the first checkpointed step")
	_check(tutorial.current_prompt() == "Right Stick: look around", "default prompt family is controller-first")
	_check(tutorial.current_prompt(true) == "Look around using your preferred camera control.", "accessible prompt replaces device-specific instruction")
	_check(tutorial.set_controller_glyphs({&"confirm": "Cross"}).accepted and tutorial.current_prompt() == "Right Stick: look around", "live glyph metadata leaves unrelated controller prompts unchanged")
	_check(tutorial.set_preferred_input_family(&"keyboard").accepted and tutorial.current_prompt() == "Mouse: look around", "keyboard prompt is an explicit presentation choice")
	_check(tutorial.set_preferred_input_family(&"controller").accepted and tutorial.current_prompt() == "Right Stick: look around", "controller family can be restored after keyboard presentation")
	_check(not tutorial.checkpoint(&"board").accepted and tutorial.current_step().id == &"look", "out-of-order checkpoints cannot skip onboarding")
	var first := tutorial.checkpoint(&"look")
	_check(first.accepted and tutorial.current_step().id == &"board" and tutorial.current_prompt() == "Cross: board spacecraft", "accepted checkpoint advances with the live controller glyph")
	var prompt_bundle := tutorial.get_current_prompt_bundle()
	_check(prompt_bundle.prompt == "Cross: board spacecraft" and prompt_bundle.actions.size() == 2 and prompt_bundle.actions[0].focusable and prompt_bundle.actions[1].focusable, "current tutorial step exposes controller-focusable next and repeat intents")
	_check(tutorial.request_next().accepted and tutorial.request_repeat().accepted, "next and repeat remain external presentation intents")
	var snapshot := tutorial.get_snapshot()
	_check(snapshot.completed == [&"look"] and snapshot.presentation_only, "checkpoint snapshot is detached and presentation-only")
	_check(tutorial.checkpoint(&"board").accepted and tutorial.current_step().is_empty(), "final checkpoint reaches a completed state")
	_check(tutorial.restore(snapshot).accepted and tutorial.current_step().id == &"board", "same-generation snapshot restores re-entry progress")
	var stale := snapshot.duplicate(true)
	stale["generation"] = -1
	_check(not tutorial.restore(stale).accepted and tutorial.current_step().id == &"board", "stale snapshots fail closed without changing progress")
	var invalid := Contract.new()
	_check(not invalid.configure([{ "id": &"bad", "checkpoint_id": &"bad" }]).accepted, "missing prompt variants fail closed")
	if _failures.is_empty():
		print("TUTORIAL_PROGRESSION_CONTRACT_TEST_OK: 20 assertions")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
