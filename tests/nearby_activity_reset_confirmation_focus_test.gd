extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _assertions := 0
var _failures: Array[String] = []
var _intents: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	hud.nearby_activity_intent_requested.connect(func(intent: Dictionary) -> void:
		_intents.append(intent.duplicate(true)))
	await process_frame
	hud.set_nearby_activity_snapshot(_snapshot(4, 12.0, 1))
	(hud.get("_nearby_activity_page") as Control).visible = true
	await process_frame
	var cargo_row := _row(hud, &"cinder_platform_supply_run")
	var retained_id := cargo_row.get_instance_id()
	var reset := cargo_row.get_child(3) as Button
	reset.grab_focus()
	reset.emit_signal("pressed")
	await process_frame
	_check(_intents.is_empty() and reset.text == "CONFIRM RESET"
		and _row(hud, &"cinder_platform_supply_run").get_instance_id() == retained_id,
		"first critical reset press changes the retained action without emitting an intent")
	_check(hud.get_viewport().gui_get_focus_owner() == reset,
		"arming confirmation preserves controller focus")

	reset.emit_signal("pressed")
	await process_frame
	_check(_intents.size() == 1 and _intents[0].reason == &"reset_requested"
		and _intents[0].activity_id == &"cinder_platform_supply_run"
		and reset.text == "RESET" and hud.get_viewport().gui_get_focus_owner() == reset,
		"second activation emits the existing reset request and clears confirmation")

	reset.emit_signal("pressed")
	var patrol_row := _row(hud, &"cinder_relay_patrol")
	(patrol_row.get_child(1) as Button).emit_signal("pressed")
	await process_frame
	_check(reset.text == "RESET" and _intents.size() == 2
		and _intents[1].reason == &"selected" and _intents[1].activity_id == &"cinder_relay_patrol",
		"selecting another activity cancels the armed reset")

	reset.emit_signal("pressed")
	_check(reset.text == "CONFIRM RESET", "critical reset can be armed again")
	hud.set_nearby_activity_snapshot(_snapshot(5, 12.0, 1))
	await process_frame
	cargo_row = _row(hud, &"cinder_platform_supply_run")
	reset = cargo_row.get_child(3) as Button
	_check(reset.text == "RESET" and cargo_row.get_instance_id() == retained_id,
		"a refreshed activity generation cancels confirmation without recreating the row")

	reset.grab_focus()
	reset.emit_signal("pressed")
	_check(reset.text == "CONFIRM RESET", "new generation requires its own first confirmation step")
	hud.set_nearby_activity_snapshot(_snapshot(5, 0.0, 2))
	await process_frame
	cargo_row = _row(hud, &"cinder_platform_supply_run")
	reset = cargo_row.get_child(3) as Button
	_check(reset.text == "RESET" and hud.get_viewport().gui_get_focus_owner() == reset,
		"terminal completion cancels confirmation while preserving focused control")

	hud.queue_free()
	await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty(): print("NEARBY_ACTIVITY_RESET_CONFIRMATION_FOCUS_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _snapshot(generation: int, remaining: float, cargo_state: int) -> Dictionary:
	return {
		"patrol": {"state_id": &"active", "generation": 2, "phase_id": &"travel", "checkpoint_count": 5},
		"cargo": {"state": cargo_state, "generation": generation, "next_phase_index": 1,
			"phase_count": 3, "deadline_seconds": 120.0,
			"deadline_remaining_seconds": remaining,
			"contract": {"ordered_phases": [&"load_crate", &"clear_gate", &"dock_platform"]}},
	}

func _row(hud: GameHUD, activity_id: StringName) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for child in rows.get_children():
		if StringName(child.get_meta(&"activity_id", &"")) == activity_id: return child as Control
	return null

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
