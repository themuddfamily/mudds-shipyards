extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")

class HudProbe extends CanvasLayer:
	var snapshots: Array[Dictionary] = []

	func apply_first_sortie_tutorial_snapshot(snapshot: Dictionary) -> bool:
		snapshots.append(snapshot.duplicate(true))
		return bool(snapshot.get("show_tutorials", true))


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
	_check(hud.snapshots.back().step_id == &"walk_interact", "published phase remains caller-readable")
	_check(flow.publish_first_sortie_tutorial_phase(&"board", 0), "board event publishes without UI auto-advance")
	flow._on_hud_presentation_intent_requested(&"tutorial", {
		"action": &"dismiss",
		"completion_intent": {"step_id": &"board", "persist": true},
	})
	_check(flow._first_sortie_tutorial_dismissed_generation == 0, "dismissal is retained by the caller generation")
	_check(not flow.publish_first_sortie_tutorial_phase(&"take_seat", 0), "dismissal blocks later phases in the same generation")
	flow._first_sortie_tutorial_generation = 1
	_check(flow.publish_first_sortie_tutorial_phase(&"take_seat", 0) == false, "stale generation cannot publish")
	_check(flow.publish_first_sortie_tutorial_phase(&"take_seat", 1), "new sortie generation can publish authoritative phase")
	flow._on_hud_presentation_intent_requested(&"tutorial", {
		"action": &"next",
		"completion_intent": {"step_id": &"walk_interact", "persist": true},
	})
	_check(not flow._first_sortie_tutorial_completed_steps.has(&"walk_interact"), "stale step completion is ignored")
	flow._on_hud_presentation_intent_requested(&"tutorial", {
		"action": &"next",
		"completion_intent": {"step_id": &"take_seat", "persist": true},
	})
	_check(flow._first_sortie_tutorial_completed_steps.get(&"take_seat") == 1, "completion intent persists only for the active phase")
	_check(not flow.publish_first_sortie_tutorial_phase(&"unknown", 1), "invalid phase cannot create a prompt")
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
