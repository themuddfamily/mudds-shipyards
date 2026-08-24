extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

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

	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_CONVOY_RETAINED_FEEDBACK_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		quit(1)


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
