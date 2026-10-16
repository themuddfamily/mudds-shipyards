extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")
const MAIN := preload("res://scenes/main.tscn")
const MemoryStoreFixture := preload("res://tests/ember_transit_movement_soak.gd")

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
	var jovian := HeroShip.new()
	jovian.display_name = "Jovian-class Light Freighter candidate"
	flow.hud = hud
	flow.runtime_settings = SettingsType.new("user://first_sortie_tutorial_game_flow_progression_test.cfg")
	_check(flow.publish_first_sortie_tutorial_phase(&"walk_interact", 0), "on-foot phase publishes through GameFlow")
	_check(hud.snapshots.back().step_id == &"walk_interact" and hud.snapshots.back().revision == 1, "initial prompt is the next on-foot action with an authoritative revision")
	_check(flow.publish_first_sortie_tutorial_phase(&"board", 0, jovian), "reaching a free-sortie craft publishes Board as the next action")
	_check(
		hud.snapshots.back().step_id == &"board"
		and hud.snapshots.back().revision == 2
		and hud.snapshots.back().craft_display_name \
			== "Jovian-class Light Freighter candidate"
		and flow._first_sortie_tutorial_board_context_matches(jovian),
		"boarding prompt carries the selected physical craft without claiming completion",
	)
	flow._detach_first_sortie_tutorial_presentation(&"game_flow_detached")
	_check(
		flow._republish_first_sortie_tutorial_presentation()
		and hud.snapshots.back().craft_display_name \
			== "Jovian-class Light Freighter candidate"
		and hud.snapshots.back().revision == 2,
		"retained HUD re-entry republishes the same fenced boarding-craft context",
	)
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
	jovian.free()
	await _check_actual_interceptor_publication()
	if _failures.is_empty():
		print("FIRST_SORTIE_TUTORIAL_GAME_FLOW_PROGRESSION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_actual_interceptor_publication() -> void:
	# Transition-focused component coverage, not a physical sortie claim.
	# Both normal range completion and the already-cleared launch path call
	# this same production transition; no phase, target ledger or hull is injected.
	for prior_step: StringName in [&"fire", &"launch"]:
		var game := MAIN.instantiate() as GameFlow
		game.configure_runtime_settings_persistence(MemoryStoreFixture.Store.new(
			"memory://fire-target.json", MemoryStoreFixture.MemoryFilesystem.new()), "memory://fire-target.cfg")
		root.add_child(game)
		await process_frame
		await physics_frame
		game.publish_first_sortie_tutorial_phase(prior_step)
		var presenter: Variant = game.hud.get("_first_sortie_tutorial_presenter")
		var before := presenter.get_snapshot() as Dictionary
		game._begin_interceptor_engagement()
		var live := presenter.get_snapshot() as Dictionary
		_check(game.phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT and game.opponent.is_active()
			and live.step_id == &"fire" and live.fire_target == &"live_interceptor"
			and live.generation == before.generation and live.revision == before.revision + 1
			and not live.prompt.contains("RANGE TARGET"),
			"actual interceptor transition replaces %s guidance with the current contact in a new revision" % prior_step)
		game._detach_first_sortie_tutorial_presentation(&"test_replay")
		_check(game._republish_first_sortie_tutorial_presentation()
			and presenter.get_snapshot() == live,
			"retained replay restores the same live target, glyphs and progress fence")
		game._advance_first_sortie_tutorial_source(&"test_source_retired")
		_check(game._first_sortie_tutorial_fire_target.is_empty() and presenter.get_snapshot().is_empty(),
			"source retirement clears retained combat guidance")
		game.queue_free()
		await process_frame
		await physics_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
