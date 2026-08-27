extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const BindingType := preload("res://scripts/world/nearby_sector_activity_binding.gd")
const ConvoyHostType := preload("res://scripts/activities/cinder_convoy_escort_host.gd")
const ScanActivityType := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	var binding := BindingType.new() as NearbySectorActivityBinding
	binding.add_child(ConvoyHostType.new())
	root.add_child(binding)
	await process_frame

	var initial_scan := (
		binding.get_snapshot().get("structure_scan", {}) as Dictionary
	).duplicate(true)
	var view := hud.set_nearby_activity_snapshot(binding.get_snapshot())
	var row := _scan_row(hud)
	var retained_id := row.get_instance_id() if row != null else 0
	_check(
		_scan_text(row).contains("SCAN READY  //  APPROACH DERELICT DATUM")
		and str(_scan_card(view).get("objective_text", "")).contains("MARKED STRUCTURE SCAN APPROACH"),
		"idle scan state gives a clear approach objective",
	)

	var expected_rejection := initial_scan.duplicate(true)
	expected_rejection.erase("presentation_reason")
	expected_rejection["accepted"] = false
	expected_rejection["reason"] = &"outside_scan_approach"
	var rejected := binding.start_structure_scan(Vector3.ZERO)
	var rejected_snapshot := binding.get_snapshot()
	view = hud.set_nearby_activity_snapshot(rejected_snapshot)
	var rejected_feedback := _scan_card(view).get("scan_feedback", {}) as Dictionary
	_check(
		rejected == expected_rejection
			and StringName(
				(rejected_snapshot.get("structure_scan", {}) as Dictionary).get(
					"presentation_reason", &""
				)
			) == &"outside_scan_approach"
			and _scan_text(_scan_row(hud)).contains(
				"WRONG POSITION  //  MOVE TO DERELICT SCAN MARKER"
			)
			and StringName(rejected_feedback.get("stage_id", &"")) == &"wrong_position"
			and str(_scan_card(view).get("objective_text", "")).contains(
				"DERELICT SCAN MARKER"
			),
		"the exact rejected receipt is retained only as public recovery presentation",
	)

	root.remove_child(binding)
	await process_frame
	root.add_child(binding)
	for _frame in 2:
		await process_frame
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(
		StringName(
			(binding.get_snapshot().get("structure_scan", {}) as Dictionary).get(
				"presentation_reason", &"stale"
			)
		).is_empty()
			and _scan_text(_scan_row(hud)).contains("SCAN READY  //  APPROACH DERELICT DATUM"),
		"detach and re-entry clear rejected-position presentation memory",
	)

	binding.start_structure_scan(Vector3.ZERO)
	var accepted := binding.start_structure_scan(ScanActivityType.APPROACH_ANCHOR)
	var accepted_snapshot := binding.get_snapshot()
	view = hud.set_nearby_activity_snapshot(accepted_snapshot)
	_check(
		bool(accepted.get("accepted", false))
			and StringName(accepted.get("reason", &"")) == &"started"
			and int(accepted.get("generation", 0)) == 1
			and StringName(
				(accepted_snapshot.get("structure_scan", {}) as Dictionary).get(
					"presentation_reason", &"stale"
				)
			).is_empty()
			and _scan_text(_scan_row(hud)).contains("SCANNING STRUCTURE  //  0%"),
		"an accepted replacement generation clears stale rejection guidance",
	)

	var reset := binding.reset_structure_scan()
	var reset_snapshot := binding.get_snapshot()
	view = hud.set_nearby_activity_snapshot(reset_snapshot)
	_check(
		bool(reset.get("accepted", false))
			and StringName(reset.get("reason", &"")) == &"reset"
			and StringName(
				(reset_snapshot.get("structure_scan", {}) as Dictionary).get(
					"presentation_reason", &"stale"
				)
			).is_empty()
			and _scan_text(_scan_row(hud)).contains(
				"INTERRUPTED  //  PROGRESS RESET  //  RETURN TO SCAN MARKER"
			),
		"reset clears rejection guidance without altering its authority receipt",
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

	binding.queue_free()
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
