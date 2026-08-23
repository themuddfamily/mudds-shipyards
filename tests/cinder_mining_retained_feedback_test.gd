extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame

	var view := hud.set_nearby_activity_snapshot({"mining": _mining(1, 1.5, false)})
	var row := _mining_row(hud)
	var retained_id := row.get_instance_id() if row != null else 0
	var feedback := _mining_card(view).get("mining_feedback", {}) as Dictionary
	_check(
		_mining_text(row).contains("EXTRACTING ORE  //  25%  //  4.5s REMAINING")
		and is_equal_approx(float(feedback.get("progress", -1.0)), 0.25)
		and str(_mining_card(view).get("objective_text", "")) == "HOLD EXTRACTION UNTIL 100%",
		"active extraction shows authoritative percentage, remaining time, and objective",
	)

	view = hud.set_nearby_activity_snapshot({"mining": _mining(1, 4.5, false)})
	row = _mining_row(hud)
	_check(
		row != null and row.get_instance_id() == retained_id
		and _mining_text(row).contains("EXTRACTING ORE  //  75%  //  1.5s REMAINING"),
		"progress updates the same retained HUD row",
	)

	view = hud.set_nearby_activity_snapshot({"mining": _mining(3, 0.0, false)})
	feedback = _mining_card(view).get("mining_feedback", {}) as Dictionary
	_check(
		_mining_text(_mining_row(hud)).contains("INTERRUPTED  //  EXTRACTION INTERRUPTED  //  PROGRESS RESET")
		and StringName(feedback.get("stage_id", &"")) == &"interrupted"
		and str(_mining_card(view).get("objective_text", "")).contains("RETURN TO THE APPROACH MARKER"),
		"the authority reset state becomes a clear interruption and restart cue",
	)

	view = hud.set_nearby_activity_snapshot({"mining": _mining(2, 6.0, false)})
	_check(
		_mining_text(_mining_row(hud)).contains("EXTRACTION COMPLETE  //  ORE SAMPLE READY"),
		"completion identifies the ore sample as ready before reward request",
	)

	view = hud.set_nearby_activity_snapshot({"mining": _mining(2, 6.0, true)})
	var pending_text := _mining_text(_mining_row(hud))
	feedback = _mining_card(view).get("mining_feedback", {}) as Dictionary
	_check(
		pending_text.contains("EXTRACTION COMPLETE  //  REWARD PENDING")
		and pending_text.count("REWARD PENDING") == 1
		and bool(feedback.get("reward_pending", false))
		and not bool(feedback.get("activity_authority", true))
		and not bool(feedback.get("reward_authority", true)),
		"reward-request state is readable once without granting or duplicating authority",
	)

	hud.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("CINDER_MINING_RETAINED_FEEDBACK_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _mining(state: int, elapsed: float, reward_pending: bool) -> Dictionary:
	return {
		"activity_id": &"cinder_platform_mining_run",
		"state": state,
		"generation": 3,
		"elapsed_seconds": elapsed,
		"extraction_seconds": 6.0,
		"reward_requested": reward_pending,
	}.duplicate(true)


func _mining_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == &"cinder_platform_mining_run":
			return card
	return {}


func _mining_row(hud: GameHUD) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if "cinder_platform_mining_run" in str(candidate.name):
			return candidate as Control
	return null


func _mining_text(row: Control) -> String:
	return str((row.get_child(0) as Label).text) if row != null else ""


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures.append(message)
