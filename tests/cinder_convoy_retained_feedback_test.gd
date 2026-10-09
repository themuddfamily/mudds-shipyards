extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame

	var view := hud.set_nearby_activity_snapshot({"host": {"activity": _convoy(54.0, true, 8.0)}})
	var row := _convoy_row(hud)
	var retained_id := row.get_instance_id() if row != null else 0
	_check(
		_convoy_text(row).contains("ESCORT SECURE  //  54m / 120m  //  LEG 2/4")
		and StringName((_convoy_card(view).convoy_feedback as Dictionary).threat_id) == &"secure",
		"the retained row shows safe escort range and authoritative route progress"
	)

	view = hud.set_nearby_activity_snapshot({"host": {"activity": _convoy(136.0, false, 3.0)}})
	row = _convoy_row(hud)
	var warning := _convoy_card(view)
	_check(
		row != null and row.get_instance_id() == retained_id
		and _convoy_text(row).contains("SEPARATION THREAT: REJOIN CONVOY  //  3.0s TO LOSS")
		and warning.semantic_cue_id == &"convoy_escort_separation_warning"
		and warning.caption_text == "Convoy separation warning. Rejoin convoy.",
		"crossing escort range updates the same row with an actionable warning and caption cue"
	)

	view = hud.set_nearby_activity_snapshot({"host": {"activity": _convoy(148.0, false, 0.8)}})
	row = _convoy_row(hud)
	var critical := _convoy_card(view)
	_check(
		_convoy_text(row).contains("CRITICAL SEPARATION: REJOIN NOW  //  0.8s TO LOSS")
		and critical.semantic_cue_id == &"convoy_escort_separation_critical",
		"the final grace window escalates to a distinct critical separation cue"
	)

	var failed_state := _convoy(148.0, false, 0.0)
	failed_state.state_id = &"failed"
	failed_state.terminal_reason = &"escort_separation_exceeded"
	view = hud.set_nearby_activity_snapshot({"host": {"activity": failed_state}})
	row = _convoy_row(hud)
	var failed := _convoy_card(view)
	_check(
		_convoy_text(row).contains("CONVOY LOST — ESCORT SEPARATION EXCEEDED")
		and failed.caption_text == "Convoy lost: escort separation exceeded"
		and not bool((failed.convoy_feedback as Dictionary).combat_authority)
		and not bool((failed.convoy_feedback as Dictionary).damage_authority)
		and not bool((failed.convoy_feedback as Dictionary).activity_authority),
		"terminal failure names the authoritative cause without adding combat, damage, or activity authority"
	)

	var actor_lost_state := _convoy(148.0, false, 0.0)
	actor_lost_state.state_id = &"failed"
	actor_lost_state.terminal_result_id = &"convoy_lost"
	actor_lost_state.terminal_reason = &"convoy_reported_lost"
	actor_lost_state.convoy_status_id = &"lost"
	view = hud.set_nearby_activity_snapshot({"host": {"activity": actor_lost_state}})
	row = _convoy_row(hud)
	var actor_lost := _convoy_card(view)
	_check(
		_convoy_text(row).contains("CONVOY ACTOR LOST  //  RESET ESCORT TO REDEPLOY")
			and actor_lost.recovery_text == "RECOVER: RESET ESCORT TO REDEPLOY CONVOY"
			and actor_lost.objective_text == "USE RESET TO REDEPLOY THE CONVOY AND RESTART THE ESCORT"
			and StringName((actor_lost.convoy_feedback as Dictionary).threat_id) == &"lost"
			and not bool((actor_lost.convoy_feedback as Dictionary).activity_authority),
		"an actor-loss terminal gives a color-independent reset and restart instruction without adding authority"
	)

	var paused := _convoy(148.0, false, 0.8)
	paused.runtime_rebind_pending = true
	paused.resume_craft_display_name = "Bulwark Heavy Gunship"
	var paused_before := paused.duplicate(true)
	view = hud.set_nearby_activity_snapshot({"host": {"activity": paused}})
	var paused_card := _convoy_card(view)
	_check(_convoy_text(_convoy_row(hud)).contains("SAVED ESCORT PAUSED")
		and not _convoy_text(_convoy_row(hud)).contains("TO LOSS")
		and paused_card.semantic_cue_id == &""
		and paused_card.convoy_feedback.threat_id == &"resume_pending"
		and paused == paused_before,
		"frozen critical samples give calm resume guidance without warning cues or authority mutation")
	paused.state_id = &"failed"
	paused.terminal_reason = &"escort_separation_exceeded"
	view = hud.set_nearby_activity_snapshot({"host": {"activity": paused}})
	_check(not _convoy_text(_convoy_row(hud)).contains("SAVED ESCORT PAUSED")
		and _convoy_card(view).semantic_cue_id == &"convoy_escort_lost",
		"terminal authority clears frozen guidance even if an old presentation flag remains")
	paused.state_id = &"idle"
	view = hud.set_nearby_activity_snapshot({"host": {"activity": paused}})
	_check(not _convoy_text(_convoy_row(hud)).contains("SAVED ESCORT PAUSED")
		and _convoy_text(_convoy_row(hud)).contains("RENDEZVOUS WITH SUPPLY TENDER"),
		"a reset clears frozen guidance and restores the ordinary rendezvous instruction")

	await _test_restored_convoy_resume_guidance()
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_CONVOY_RETAINED_FEEDBACK_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		quit(1)


func _test_restored_convoy_resume_guidance() -> void:
	var path := "user://convoy_resume_guidance_%d.json" % Time.get_ticks_usec()
	var first := await _make_main(path)
	first.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
	var bulwark := first.call("_find_flyable_ship_by_id", &"bulwark_heavy_gunship") as HeroShip
	_check(bulwark != null, "the resume fixture uses the registered Bulwark")
	if bulwark == null:
		await _retire_main(first)
		return
	_prepare_escort_flight(first, bulwark)
	await _load_cinder(first, bulwark)
	bulwark.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	var started := first.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	for _tick in 4:
		bulwark.global_position = first.cinder_convoy_host.get_snapshot().entity_position + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		first.call("_physics_process", 0.25)
	var saved := first.save_cinder_convoy_session()
	var saved_state := first.cinder_convoy_host.capture_persistence_state()
	var craft_name := bulwark.get_display_name()
	_check(bool(started.accepted) and bool(saved.accepted) and first.get_active_activity_snapshot().state_id == &"active",
		"actual Main saves an active Bulwark escort with a legitimate secure sample")
	await _retire_main(first)
	var second := await _make_main(path)
	var hud := second.hud as GameHUD
	var cold_text := _convoy_text(_convoy_row(hud))
	print("COLD_RESTORED_CONVOY_HUD: ", cold_text)
	print("COLD_RESTORED_CONVOY_OBJECTIVE: ", hud.get_activity_objective_report().get("text", ""))
	var instruction := "Board %s, launch and return to Cinder Reach to resume" % craft_name
	_check(bool(second.get_cinder_convoy_session_persistence_report().runtime_rebind_pending)
		and not is_instance_valid(second.cinder_streaming_bootstrap.get_loaded_instance())
		and second.active_ship.get_ship_id() != &"bulwark_heavy_gunship"
		and JSON.stringify(second.cinder_convoy_host.capture_persistence_state()) == JSON.stringify(saved_state),
		"cold Main retains the saved escort frozen at Mudds while the default craft is active")
	_check(cold_text.contains("SAVED ESCORT PAUSED") and cold_text.contains(instruction)
		and not cold_text.contains("TO LOSS") and not cold_text.contains("ESCORT SECURE")
		and (_convoy_row(hud).get_child(1) as Button).disabled,
		"the unloaded retained convoy row explains the frozen save and names the actual saved craft")
	var wrong_craft := second.active_ship
	_prepare_escort_flight(second, wrong_craft)
	await _load_cinder(second, wrong_craft)
	second.call("_sync_activity_hud")
	var frozen_state := second.cinder_convoy_host.capture_persistence_state()
	var frozen_text := _convoy_text(_convoy_row(hud))
	print("LOADED_FROZEN_CONVOY_HUD: ", frozen_text)
	_check(bool(second.get_cinder_convoy_session_persistence_report().runtime_rebind_pending)
		and frozen_text.contains("SAVED ESCORT PAUSED") and frozen_text.contains(instruction)
		and not frozen_text.contains("ESCORT SECURE") and not frozen_text.contains("TO LOSS")
		and not frozen_text.contains("m /"),
		"loading Cinder in another craft preserves resume guidance and suppresses stale range/threat")
	for _tick in 3:
		second.call("_physics_process", 0.25)
	_check(second.cinder_convoy_host.capture_persistence_state() == frozen_state,
		"presentation and wrong-craft samples do not thaw the saved authority")
	var restored_bulwark := second.call("_find_flyable_ship_by_id", &"bulwark_heavy_gunship") as HeroShip
	_prepare_escort_flight(second, restored_bulwark)
	restored_bulwark.global_position = second.cinder_convoy_host.get_snapshot().entity_position + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
	second.call("_physics_process", 0.25)
	second.call("_sync_activity_hud")
	var resumed_text := _convoy_text(_convoy_row(hud))
	_check(not bool(second.get_cinder_convoy_session_persistence_report().runtime_rebind_pending)
		and not resumed_text.contains("SAVED ESCORT PAUSED") and not resumed_text.contains(instruction)
		and resumed_text.contains("ESCORT SECURE")
		and float(second.get_active_activity_snapshot().elapsed_seconds) > float((frozen_state.activity_state as Dictionary).elapsed_seconds),
		"the existing accepted Bulwark rebind resumes its clock and automatically clears guidance")
	await _retire_main(second)


func _make_main(path: String) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(Store.new(path))
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	return game


func _prepare_escort_flight(game: GameFlow, craft: HeroShip) -> void:
	craft.set_piloted(true)
	game.active_ship = craft
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT


func _load_cinder(game: GameFlow, craft: HeroShip) -> void:
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
	for _attempt in 20:
		game.call("_physics_process", 0.1)
		if is_instance_valid(game.cinder_streaming_bootstrap.get_loaded_instance()):
			return
		await process_frame
	_check(false, "the existing Cinder stream loads through Main's physical ship sample")


func _retire_main(game: GameFlow) -> void:
	game.set("_piloting", false)
	game.queue_free()
	for _frame in 3:
		await process_frame


func _convoy(
	escort_distance: float, within_range: bool, separation_remaining: float
) -> Dictionary:
	return {
		"activity_id": &"cinder_reach_emberline_convoy",
		"state_id": &"active",
		"generation": 4,
		"has_entity_sample": true,
		"escort_distance": escort_distance,
		"escort_proximity_radius": 120.0,
		"escort_within_proximity": within_range,
		"separation_elapsed_seconds": 8.0 - separation_remaining,
		"maximum_separation_seconds": 8.0,
		"separation_remaining_seconds": separation_remaining,
		"completed_leg_count": 1,
		"leg_count": 4,
	}.duplicate(true)


func _convoy_row(hud: GameHUD) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if "cinder_reach_emberline_convoy" in str(candidate.name):
			return candidate as Control
	return null


func _convoy_text(row: Control) -> String:
	return str((row.get_child(0) as Label).text) if row != null else ""


func _convoy_card(view: Dictionary) -> Dictionary:
	for card in view.get("cards", []) as Array:
		if StringName((card as Dictionary).get("activity_id", &"")) \
			== &"cinder_reach_emberline_convoy":
			return card as Dictionary
	return {}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)
