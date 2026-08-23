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
	var view := hud.set_nearby_activity_snapshot({"cargo": _cargo_snapshot(1, 0)})
	_check(bool(view.get("focusable", false)), "HUD accepts the detached presenter view")
	_check(int(hud.get_nearby_activity_report().get("row_count", 0)) == 7, "HUD retains one focusable row per nearby activity")
	hud.show_nearby_activity_page()
	_check(bool(hud.get_nearby_activity_report().get("visible", false)), "nearby activity page can be shown explicitly")
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
		_cargo_text(row).contains("FAILED 2/3: DELIVERY FAILED DURING TRANSIT")
		and _cargo_text(row).contains("RECOVER: EMBODIED TRANSFER ABORTED")
		and not bool((failed.get("cargo_progress", {}) as Dictionary).get("inventory_authority", true)),
		"failure retains the interrupted stage and recovery reason without claiming inventory authority"
	)

	var start := row.get_child(2) as Button if row != null else null
	if start != null:
		start.emit_signal("pressed")
	_check(_intent.get("reason", &"") == &"start_requested", "HUD forwards a start intent without invoking activity authority")
	hud.clear_nearby_activity_snapshot()
	_check(hud.get_nearby_activity_report().get("snapshot", {}) == {}, "detaching/clearing removes retained activity snapshot")
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
