extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")

class HudProbe extends CanvasLayer:
	var snapshots: Array[Dictionary] = []
	var clears: Array[StringName] = []

	func apply_first_sortie_tutorial_snapshot(snapshot: Dictionary) -> bool:
		snapshots.append(snapshot.duplicate(true))
		return bool(snapshot.get("show_tutorials", true))

	func clear_first_sortie_tutorial(reason: StringName = &"detached") -> Dictionary:
		clears.append(reason)
		return {"accepted": true, "reason": reason}


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	var hud := HudProbe.new()
	flow.hud = hud
	flow.runtime_settings = SettingsType.new("user://first_sortie_tutorial_game_flow_progression_test.cfg")
	_check(flow.publish_first_sortie_tutorial_phase(&"walk_interact", 0), "on-foot phase publishes through GameFlow")
	_check(hud.snapshots.back().step_id == &"walk_interact" and hud.snapshots.back().revision == 1, "initial prompt is the next on-foot action with an authoritative revision")
	_check(flow.publish_first_sortie_tutorial_phase(&"board", 0), "reaching boarding range publishes Board as the next action")
	_check(hud.snapshots.back().step_id == &"board" and hud.snapshots.back().revision == 2, "boarding prompt follows completed approach without claiming completion")
	flow._advance_first_sortie_tutorial_source(&"boarding_actor_changed")
	_check(flow._first_sortie_tutorial_generation == 1 and flow._first_sortie_tutorial_revision == 0 and hud.clears.back() == &"boarding_actor_changed", "boarding actor change clears presentation and starts a fresh source fence")
	_check(flow.publish_first_sortie_tutorial_phase(&"launch", 1), "completed boarding publishes launch as the next action")
	_check(hud.snapshots.back().step_id == &"launch" and hud.snapshots.back().revision == 1, "new boarding generation starts revision one at launch")
	flow._detach_first_sortie_tutorial_presentation(&"game_flow_detached")
	_check(flow._republish_first_sortie_tutorial_presentation(), "retained GameFlow source republishes after session re-entry")
	_check(hud.snapshots.back().generation == 1 and hud.snapshots.back().revision == 1, "session reuse preserves the authoritative fence without advancing progress")
	_check(not flow.publish_first_sortie_tutorial_phase(&"fire", 0), "prior boarding generation cannot publish")
	_check(flow.publish_first_sortie_tutorial_phase(&"fire", 1), "completed launch publishes range targets as the next action")
	flow._on_hud_presentation_intent_requested(&"tutorial", {
		"action": &"next",
		"completion_intent": {"step_id": &"launch", "generation": 1, "revision": 1, "persist": true},
	})
	_check(not flow._first_sortie_tutorial_completed_steps.has(&"launch"), "stale revision completion is ignored")
	flow._on_hud_presentation_intent_requested(&"tutorial", {
		"action": &"next",
		"completion_intent": {"step_id": &"fire", "persist": true},
	})
	_check(not flow._first_sortie_tutorial_completed_steps.has(&"fire"), "unfenced completion intent cannot mutate GameFlow progress")
	flow._on_hud_presentation_intent_requested(&"tutorial", {
		"action": &"repeat",
		"completion_intent": {"step_id": &"fire", "generation": 1, "revision": 2, "persist": true},
	})
	_check(not flow._first_sortie_tutorial_completed_steps.has(&"fire"), "repeat remains presentation-only and cannot complete progress")
	flow._on_hud_presentation_intent_requested(&"tutorial", {
		"action": &"next",
		"completion_intent": {"step_id": &"fire", "generation": 1, "revision": 2, "persist": true},
	})
	_check(flow._first_sortie_tutorial_completed_steps.get(&"fire") == 1, "current fenced intent is persisted by GameFlow")
	_check(flow.publish_first_sortie_tutorial_phase(&"return_land", 1), "completed targets publish return as the next action")
	_check(flow.publish_first_sortie_tutorial_phase(&"exit", 1), "completed landing publishes exit as the next action")
	_check(hud.snapshots.back().step_id == &"exit" and hud.snapshots.back().revision == 4, "board-launch-target-return sequence advances one authoritative revision per prompt")
	flow._on_hud_presentation_intent_requested(&"tutorial", {
		"action": &"dismiss",
		"completion_intent": {"step_id": &"exit", "generation": 1, "revision": 4, "persist": true},
	})
	_check(flow._first_sortie_tutorial_dismissed_generation == 1, "dismissal is retained by the authoritative source generation")
	_check(not flow.publish_first_sortie_tutorial_phase(&"walk_interact", 1), "dismissal blocks later prompts in the same source generation")
	flow._advance_first_sortie_tutorial_source(&"pilot_disembarked")
	_check(flow.publish_first_sortie_tutorial_phase(&"walk_interact", 2), "completed exit publishes the next boarding approach in a fresh generation")
	flow._advance_first_sortie_tutorial_source(&"boarding_actor_changed")
	_check(flow.publish_first_sortie_tutorial_phase(&"launch", 3), "repeated exit to board cycle restarts at launch without revision conflict")
	_check(hud.snapshots.back().generation == 3 and hud.snapshots.back().revision == 1, "reused presenter source aligns boarding generation and revision")
	_check(not flow.publish_first_sortie_tutorial_phase(&"unknown", 3), "invalid phase cannot create a prompt")
	flow.free()
	hud.free()
	if _failures.is_empty():
		print("FIRST_SORTIE_TUTORIAL_GAME_FLOW_PROGRESSION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
