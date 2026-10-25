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
	hud.apply_nearby_activity_action_result(&"start_requested", &"station_defense", {
		"accepted": true, "reason": &"launch_armed",
	})
	_check(feedback.text == "STATION DEFENSE  //  ARMED  //  BOARD A CRAFT AND DEPART",
		"accepted station-defense arm explains boarding and departure before combat starts")
	_check_status_palette(hud, &"_nearby_activity_feedback", feedback_identity, &"nominal_soft", "station defense armed")
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
	await _check_nearby_small_viewport(hud)
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


func _check_nearby_small_viewport(hud: GameHUD) -> void:
	var previous_size := root.size
	var previous_content_size := root.content_scale_size
	var previous_aspect := root.content_scale_aspect
	var previous_scale := hud.get_ui_scale()
	var previous_snapshot := (hud.get_nearby_activity_report().get("snapshot", {}) as Dictionary).duplicate(true)
	var requests: Array[Dictionary] = []
	var briefings: Array[StringName] = []
	var on_request := func(intent: Dictionary) -> void: requests.append(intent.duplicate(true))
	var on_briefing := func(site_id: StringName) -> void: briefings.append(site_id)
	hud.nearby_activity_intent_requested.connect(on_request)
	hud.sector_site_briefing_requested.connect(on_briefing)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1024, 768)
	root.size = Vector2i(1024, 768)
	hud.set_ui_scale(GameHUD.MAX_UI_SCALE)
	# Use the existing cargo progress payload and the production hulk briefing
	# state. The presenter supplies its ordinary other eight activity rows.
	var snapshot := {"cargo": _cargo_snapshot(1, 0), "hulk_power": {"hulk_loaded": true}}
	hud.set_nearby_activity_snapshot(snapshot)
	hud.show_nearby_activity_page()
	await process_frame
	await process_frame
	var page := hud.get("_nearby_activity_page") as Control
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	var feedback := hud.get("_nearby_activity_feedback") as Label
	var effective := GameHUD.compute_effective_pause_ui_scale(GameHUD.MAX_UI_SCALE, Vector2(1024, 768))
	var safe := preload("res://scripts/ui/ultrawide_safe_area_contract.gd").safe_rect(Vector2(1024, 768), effective)
	var scroll: ScrollContainer
	var ancestor := rows.get_parent()
	while ancestor != null and ancestor != page:
		if ancestor is ScrollContainer:
			scroll = ancestor as ScrollContainer
			break
		ancestor = ancestor.get_parent()
	print("MEASURED: ten-row NearbyActivityPage 1024x768 request %.2f -> effective %.6f page %s"
		% [GameHUD.MAX_UI_SCALE, effective, page.get_global_rect()])
	_check(root.get_visible_rect().size == Vector2(1024, 768)
		and is_equal_approx(hud.get_ui_scale(), GameHUD.MAX_UI_SCALE),
		"Nearby cell uses actual 1024x768 and the authored maximum request")
	_check(rows.get_child_count() == 10, "Nearby cell retains all ten production presenter rows")
	_check(safe.grow(0.75).encloses(page.get_global_rect()),
		"Nearby ten-row page fits the 1024x768 readable bounds")
	_check(scroll != null, "Nearby ten-row list supplies bounded authored scrolling")
	for candidate: Node in page.find_children("*", "Label", true, false):
		if not rows.is_ancestor_of(candidate):
			var label := candidate as Label
			_check(safe.grow(0.75).encloses(label.get_global_rect()),
				"Nearby fixed header or feedback stays inside readable bounds: %s" % label.text)
			_check_nearby_label_fits(label)
	for button_name in ["NearbyActivitySaveButton", "NearbyActivityLoadButton", "NearbyActivityBackButton"]:
		var button := page.find_child(button_name, true, false) as Button
		_check(button != null and not button.disabled
			and safe.grow(0.75).encloses(button.get_global_rect())
			and button.size.x + 0.75 >= button.get_minimum_size().x,
			"Nearby fixed footer action stays completely readable: %s" % button_name)
	for child: Node in rows.get_children():
		var row := child as Control
		if scroll != null:
			scroll.ensure_control_visible(row)
			await process_frame
			await process_frame
		var readable := safe if scroll == null else scroll.get_global_rect()
		_check(safe.grow(0.75).encloses(readable)
			and readable.grow(0.75).encloses(row.get_global_rect())
			and not row.get_global_rect().intersects(feedback.get_global_rect()),
			"Nearby complete row is readable through scrolling: %s" % row.name)
		var label := row.get_child(0) as Label
		_check(row.get_global_rect().grow(0.75).encloses(label.get_global_rect()),
			"Nearby row contains its essential copy: %s" % row.name)
		_check_nearby_label_fits(label)
		for action: Node in row.get_children():
			if action is Button:
				var button := action as Button
				_check(row.get_global_rect().grow(0.75).encloses(button.get_global_rect())
					and button.size.x + 0.75 >= button.get_minimum_size().x,
					"Nearby row contains its complete action: %s/%s" % [row.name, button.text])
	# Focus-follow itself must reveal enabled top, middle and bottom actions.
	# Do not manually scroll to the target in this loop.
	# Row inspection leaves the original opener focused while scrolling away.
	# Depart to fixed Back so the first SELECT is a real focus transition too.
	var focus_departure := page.find_child("NearbyActivityBackButton", true, false) as Button
	focus_departure.grab_focus()
	_check(root.gui_get_focus_owner() == focus_departure,
		"Nearby focus-follow setup departs to fixed Back before row focus transitions")
	for index in [0, 4, 9]:
		var row := rows.get_child(index) as Control
		for action: Node in row.get_children():
			if action is Button and not (action as Button).disabled:
				var button := action as Button
				button.grab_focus()
				await process_frame
				await process_frame
				_check(root.gui_get_focus_owner() == button
					and _nearby_readable_region(rows, safe).grow(0.75).encloses(row.get_global_rect()),
					"Nearby enabled focus reveals the complete row: %s/%s" % [row.name, button.text])
	var cargo := _cargo_row(hud)
	var cargo_identity := cargo.get_instance_id()
	var focused := cargo.get_child(2) as Button
	focused.grab_focus()
	await process_frame
	await process_frame
	_check(cargo.get_index() == 0 and root.gui_get_focus_owner() == focused,
		"Nearby priority refresh starts with focused active cargo at list top")
	# Retain focus while active cargo moves from first to its authored standard
	# position. The new scroll region must reveal that retained focused row
	# after container layout, without another focus-entered event.
	for cargo_state in [_cargo_snapshot(2, 3), _cargo_snapshot(1, 1, &"", 84.5),
		_cargo_snapshot(1, 2, &"", 43.0), _cargo_snapshot(3, 1, &"embodied_transfer_aborted", 0.0)]:
		snapshot["cargo"] = cargo_state
		hud.set_nearby_activity_snapshot(snapshot)
		await process_frame
		await process_frame
		await process_frame
		cargo = _cargo_row(hud)
		_check(cargo.get_instance_id() == cargo_identity and root.gui_get_focus_owner() == focused
			and _nearby_readable_region(rows, safe).grow(0.75).encloses(cargo.get_global_rect()),
			"Nearby retained cargo focus stays visible after priority/progress/terminal refresh: state %d phase %d"
			% [int(cargo_state.state), int(cargo_state.next_phase_index)])
		_check_nearby_label_fits(cargo.get_child(0) as Label)
	hud.apply_nearby_activity_action_result(&"start_requested", &"station_defense", {"accepted": false, "reason": &"out_of_range"})
	await process_frame
	await process_frame
	_check(safe.grow(0.75).encloses(feedback.get_global_rect())
		and "REPORT ON FOOT TO THE MARKED DECK BOARD" in feedback.text,
		"Nearby rejected-start recovery guidance stays completely inside readable bounds")
	_check_nearby_label_fits(feedback)
	for button_name in ["NearbyActivitySaveButton", "NearbyActivityLoadButton", "NearbyActivityBackButton"]:
		var button := page.find_child(button_name, true, false) as Button
		button.grab_focus()
		await process_frame
		_check(root.gui_get_focus_owner() == button
			and safe.grow(0.75).encloses(button.get_global_rect()),
			"Nearby footer retains enabled visible focus: %s" % button_name)
	var back := page.find_child("NearbyActivityBackButton", true, false) as Button
	# Queue a real priority refresh, then leave in the same frame. A deferred
	# reveal must respect the newer Back transition and leave the hidden list alone.
	focused.grab_focus()
	snapshot["cargo"] = _cargo_snapshot(2, 3)
	hud.set_nearby_activity_snapshot(snapshot)
	var scroll_before_back := scroll.scroll_vertical if scroll != null else 0
	back.emit_signal("pressed")
	await process_frame
	await process_frame
	await process_frame
	var selection := hud.get("_activity_selection_page") as Control
	var opener := selection.find_child("NearbyActivityOpenButton", true, false) as Button
	_check(selection.visible and not page.visible and root.gui_get_focus_owner() == opener,
		"Nearby Back restores the Activity Board and exact opener focus in the selected cell")
	_check((scroll == null or scroll.scroll_vertical == scroll_before_back)
		and root.gui_get_focus_owner() == opener,
		"Nearby queued refresh respects newer Back focus and leaves hidden-page scrolling unchanged")
	hud.show_nearby_activity_page()
	_check(requests.is_empty() and briefings.is_empty(),
		"Nearby layout, scrolling, focus and snapshot refresh emit no activity, persistence or site briefing intent")
	hud.nearby_activity_intent_requested.disconnect(on_request)
	hud.sector_site_briefing_requested.disconnect(on_briefing)
	hud.set_nearby_activity_snapshot(previous_snapshot)
	root.content_scale_aspect = previous_aspect
	root.content_scale_size = previous_content_size
	root.size = previous_size
	hud.set_ui_scale(previous_scale)
	await process_frame
	await process_frame


func _nearby_readable_region(rows: Control, fallback: Rect2) -> Rect2:
	var ancestor := rows.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return (ancestor as Control).get_global_rect()
		ancestor = ancestor.get_parent()
	return fallback


func _check_nearby_label_fits(label: Label) -> void:
	var fits := label.get_visible_line_count() == label.get_line_count()
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		fits = fits and label.size.x + 0.75 >= label.get_minimum_size().x
	_check(fits, "Nearby essential text is not clipped: %s" % label.text)


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
