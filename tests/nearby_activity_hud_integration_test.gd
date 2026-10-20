extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _assertions := 0
var _failures: Array[String] = []
var _intent: Dictionary = {}


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	hud.nearby_activity_intent_requested.connect(func(intent: Dictionary) -> void: _intent = intent.duplicate(true))
	await process_frame
	var feedback: Label = hud.get("_nearby_activity_feedback") as Label
	var feedback_identity: int = feedback.get_instance_id()
	hud.set_nearby_activity_snapshot({"binding_available": false})
	_check(feedback.text.contains("OUT OF STREAMING RANGE"), "unavailable binding explains the streaming limit")
	_check_status_palette(hud, &"_nearby_activity_feedback", feedback_identity, &"caution", "binding unavailable")
	var view := hud.set_nearby_activity_snapshot({"cargo": _cargo_snapshot(1, 0)})
	_check(bool(view.get("focusable", false)), "HUD accepts the detached presenter view")
	_check(int(hud.get_nearby_activity_report().get("row_count", 0)) == 10, "HUD retains one row per production nearby activity")
	_check(hud.open_activity_board(), "the existing pause Activity Board opens through its public route")
	var open_button := (
		hud.get("_activity_selection_page") as Control
	).find_child("NearbyActivityOpenButton", true, false) as Button
	_check(open_button != null, "the Activity Board exposes the Cinder Sector activity route")
	if open_button != null:
		open_button.emit_signal("pressed")
	var nearby_page := hud.get("_nearby_activity_page") as Control
	var selection_page := hud.get("_activity_selection_page") as Control
	_check(
		bool(hud.get_nearby_activity_report().get("visible", false))
		and nearby_page != null and nearby_page.visible
		and selection_page != null and not selection_page.visible
		and hud.get_viewport().gui_get_focus_owner() is BaseButton,
		"the production button opens one exclusive controller-focused Cinder page"
	)
	hud.apply_nearby_activity_action_result(
		&"start_requested", &"station_defense",
		{"accepted": false, "reason": &"out_of_range"},
	)
	_check(
		"REPORT ON FOOT TO THE MARKED DECK BOARD" in (
			hud.get("_nearby_activity_feedback") as Label
		).text,
		"a rejected remote station-defense start gives physical recovery guidance"
	)
	_check_status_palette(hud, &"_nearby_activity_feedback", feedback_identity, &"caution", "station defense recovery")
	hud.apply_nearby_activity_action_result(&"start_requested", &"cinder_relay_patrol", {"accepted": true})
	_check(feedback.text == "RELAY PATROL  //  STARTED", "accepted activity start remains explicit")
	_check_status_palette(hud, &"_nearby_activity_feedback", feedback_identity, &"nominal_soft", "activity started")
	hud.apply_nearby_activity_action_result(&"reset_requested", &"cinder_relay_patrol", {"accepted": true})
	_check(feedback.text == "RELAY PATROL  //  RESET", "accepted activity reset remains explicit")
	_check_status_palette(hud, &"_nearby_activity_feedback", feedback_identity, &"nominal_soft", "activity reset")
	hud.apply_nearby_activity_action_result(&"start_requested", &"cinder_derelict_structure_scan", {
		"accepted": true, "reason": &"reward_request_ready", "authority_result": {"accepted": true},
	})
	_check(feedback.text == "DERELICT SCAN  //  REWARD FILED", "accepted authority receipt is clearly filed")
	_check_status_palette(hud, &"_nearby_activity_feedback", feedback_identity, &"nominal_soft", "reward filed")
	hud.apply_nearby_activity_action_result(&"reset_requested", &"cinder_relay_patrol", {
		"accepted": false, "reason": &"unavailable",
	})
	_check(feedback.text == "RELAY PATROL NOT RESET  //  UNAVAILABLE", "generic refusal remains explicit")
	_check_status_palette(hud, &"_nearby_activity_feedback", feedback_identity, &"caution", "activity refused")
	hud.set_hud_palette(&"deuteranopia")
	_check_status_palette(hud, &"_nearby_activity_feedback", feedback_identity, &"caution", "refusal palette repaint")
	hud.set_high_contrast_hud(true)
	_check_status_palette(hud, &"_nearby_activity_feedback", feedback_identity, &"caution", "refusal contrast repaint")
	var row := _cargo_row(hud)
	var retained_row_id := row.get_instance_id() if row != null else 0
	_check(
		_cargo_text(row).contains("PICKUP 1/3: LOAD THE CINDER SUPPLY CRATE")
		and _cargo_text(row).contains("120.0s LEFT"),
		"the live cargo row begins with the authoritative pickup objective and deadline"
	)

	view = hud.set_nearby_activity_snapshot({"cargo": _cargo_snapshot(1, 1, &"", 84.5)})
	row = _cargo_row(hud)
	var transit := _cargo_card(view)
	_check(
		row != null and row.get_instance_id() == retained_row_id
		and _cargo_text(row).contains("TRANSIT 2/3: CLEAR THE CINDER DEPARTURE GATE")
		and StringName((transit.get("cargo_progress", {}) as Dictionary).get("stage_id", &"")) == &"transit",
		"phase progress updates the same retained HUD row to a clear transit objective"
	)

	view = hud.set_nearby_activity_snapshot({"cargo": _cargo_snapshot(1, 2, &"", 43.0)})
	row = _cargo_row(hud)
	_check(
		_cargo_text(row).contains("DELIVERY 3/3: DOCK AT THE CINDER PLATFORM"),
		"the authoritative dock phase becomes an explicit delivery objective"
	)

	view = hud.set_nearby_activity_snapshot({"cargo": _cargo_snapshot(2, 3)})
	row = _cargo_row(hud)
	var delivered := _cargo_card(view)
	_check(
		_cargo_text(row).contains("DELIVERED 3/3: CARGO TRANSFER CONFIRMED")
		and not bool(delivered.get("activity_authority", true))
		and not bool(delivered.get("reward_authority", true)),
		"a committed receipt is clearly confirmed without giving the HUD activity or reward authority"
	)

	view = hud.set_nearby_activity_snapshot({
		"cargo": _cargo_snapshot(3, 1, &"embodied_transfer_aborted", 0.0)
	})
	row = _cargo_row(hud)
	var failed := _cargo_card(view)
	_check(
		_cargo_text(row).contains("LOST 2/3: CARGO RUN LOST DURING TRANSIT")
		and _cargo_text(row).contains("RECOVER LOST CARGO: RETURN TO THE CINDER BERTH")
		and not bool((failed.get("cargo_progress", {}) as Dictionary).get("inventory_authority", true)),
		"failure retains the current lost-cargo recovery stage without claiming inventory authority"
	)

	var start := row.get_child(2) as Button if row != null else null
	if start != null:
		start.emit_signal("pressed")
	_check(_intent.get("reason", &"") == &"start_requested", "HUD forwards a start intent without invoking activity authority")
	hud.clear_nearby_activity_snapshot()
	_check(hud.get_nearby_activity_report().get("snapshot", {}) == {}, "detaching/clearing removes retained activity snapshot")
	hud.set_paused(false)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS nearby_activity_hud_integration_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _cargo_snapshot(
	state: int, next_phase_index: int, failure_reason: StringName = &"",
	deadline_remaining: float = 120.0
) -> Dictionary:
	return {
		"activity_id": &"cinder_platform_supply_run",
		"state": state,
		"generation": 4,
		"next_phase_index": next_phase_index,
		"phase_count": 3,
		"deadline_remaining_seconds": deadline_remaining,
		"failure_reason": failure_reason,
		"contract": {
			"ordered_phases": [&"load_crate", &"clear_gate", &"dock_platform"],
		},
	}.duplicate(true)


func _cargo_row(hud: GameHUD) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if "cinder_platform_supply_run" in str(candidate.name):
			return candidate as Control
	return null


func _cargo_text(row: Control) -> String:
	return str((row.get_child(0) as Label).text) if row != null else ""


func _cargo_card(view: Dictionary) -> Dictionary:
	for card in view.get("cards", []) as Array:
		if StringName((card as Dictionary).get("activity_id", &"")) \
			== &"cinder_platform_supply_run":
			return card as Dictionary
	return {}


func _check_status_palette(
	hud: GameHUD, field: StringName, identity: int, role: StringName, outcome: String
) -> void:
	var label: Label = hud.get(field) as Label
	var expected: Color = GameHUD.PaletteType.get_role_color(
		hud.get_hud_palette_id(), role, hud.is_high_contrast_hud()
	)
	var entries: int = 0
	var registered_role: StringName = &""
	var targets: Array = hud.get("_palette_targets") as Array
	for entry: Dictionary in targets:
		if entry.get("kind") == &"theme_color" and entry.get("node") == label \
				and entry.get("property") == &"font_color":
			entries += 1
			registered_role = StringName(entry.get("role", &""))
	_check(
		label.get_instance_id() == identity and entries == 1 and registered_role == role
		and label.modulate == Color.WHITE
		and label.get_theme_color("font_color") == expected
		and label.get_theme_color("font_color") * label.modulate == expected,
		outcome + " retains one current font role and applies its colour once"
	)
