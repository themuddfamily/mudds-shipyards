extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame

	var view := hud.set_nearby_activity_snapshot({"structure_scan": _scan(0, 0.0, false)})
	var row := _scan_row(hud)
	var retained_id := row.get_instance_id() if row != null else 0
	_check(
		_scan_text(row).contains("SCAN READY  //  APPROACH DERELICT DATUM")
		and str(_scan_card(view).get("objective_text", "")).contains("MARKED STRUCTURE SCAN APPROACH"),
		"idle scan state gives a clear approach objective",
	)

	var wrong_position := _scan(0, 0.0, false)
	wrong_position.accepted = false
	wrong_position.reason = &"outside_scan_approach"
	view = hud.set_nearby_activity_snapshot({"structure_scan": wrong_position})
	_check(
		_scan_text(_scan_row(hud)).contains("WRONG POSITION  //  MOVE TO DERELICT SCAN MARKER")
		and StringName((_scan_card(view).scan_feedback as Dictionary).stage_id) == &"wrong_position"
		and str(_scan_card(view).get("objective_text", "")).contains("DERELICT SCAN MARKER"),
		"the authoritative rejected-position result names the recovery position",
	)

	view = hud.set_nearby_activity_snapshot({"structure_scan": _scan(1, 1.0, false)})
	row = _scan_row(hud)
	var feedback := _scan_card(view).get("scan_feedback", {}) as Dictionary
	_check(
		row != null and row.get_instance_id() == retained_id
		and _scan_text(row).contains("SCANNING STRUCTURE  //  25%  //  3.0s REMAINING")
		and is_equal_approx(float(feedback.get("progress", -1.0)), 0.25),
		"scan progress updates percentage and remaining time on the same retained row",
	)

	view = hud.set_nearby_activity_snapshot({"structure_scan": _scan(3, 0.0, false)})
	_check(
		_scan_text(_scan_row(hud)).contains("INTERRUPTED  //  PROGRESS RESET  //  RETURN TO SCAN MARKER")
		and str(_scan_card(view).get("objective_text", "")).contains("RETURN TO THE SCAN MARKER"),
		"reset is presented as an interruption with restart guidance",
	)

	view = hud.set_nearby_activity_snapshot({"structure_scan": _scan(2, 4.0, false)})
	_check(
		_scan_text(_scan_row(hud)).contains("COMPLETED  //  MATERIAL SAMPLE READY"),
		"completion names the material sample before reward request",
	)

	view = hud.set_nearby_activity_snapshot({"structure_scan": _scan(2, 4.0, true)})
	var pending_text := _scan_text(_scan_row(hud))
	feedback = _scan_card(view).get("scan_feedback", {}) as Dictionary
	_check(
		pending_text.contains("COMPLETED  //  REWARD PENDING")
		and pending_text.count("REWARD PENDING") == 1
		and bool(feedback.get("reward_pending", false))
		and not bool(feedback.get("scan_authority", true))
		and not bool(feedback.get("reward_authority", true)),
		"reward-pending state is readable once without adding scan or grant authority",
	)

	hud.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("CINDER_STRUCTURE_SCAN_RETAINED_FEEDBACK_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _scan(state: int, elapsed: float, reward_pending: bool) -> Dictionary:
	return {
		"activity_id": &"cinder_derelict_structure_scan",
		"state": state,
		"generation": 2,
		"elapsed_seconds": elapsed,
		"scan_seconds": 4.0,
		"reward_requested": reward_pending,
	}.duplicate(true)


func _scan_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == &"cinder_derelict_structure_scan":
			return card
	return {}


func _scan_row(hud: GameHUD) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if "cinder_derelict_structure_scan" in str(candidate.name):
			return candidate as Control
	return null


func _scan_text(row: Control) -> String:
	return str((row.get_child(0) as Label).text) if row != null else ""


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures.append(message)
