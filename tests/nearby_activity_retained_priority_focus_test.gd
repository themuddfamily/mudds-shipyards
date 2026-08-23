extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	var first_view := hud.set_nearby_activity_snapshot(_first_snapshot())
	(hud.get("_nearby_activity_page") as Control).visible = true
	await process_frame
	_check(_card_ids(first_view).slice(0, 4) == [
		&"cinder_debris_beacon_traversal", &"cinder_platform_supply_run",
		&"cinder_platform_mining_run", &"cinder_relay_patrol",
	], "critical items lead in stable authored order, followed by reward pending and active")
	_check(_row_ids(hud) == _card_ids(first_view),
		"retained list initially follows presenter priority order")

	var retained_instances := _row_instances(hud)
	var cargo_row := _row(hud, &"cinder_platform_supply_run")
	var focused_button := cargo_row.get_child(2) as Button
	focused_button.grab_focus()
	var station_row := _row(hud, &"station_defense")
	(station_row.get_child(1) as Button).emit_signal("pressed")
	await process_frame
	_check(hud.get_viewport().gui_get_focus_owner() == focused_button,
		"test establishes focus on the retained cargo row")

	var second_view := hud.set_nearby_activity_snapshot(_second_snapshot())
	await process_frame
	var second_ids := _card_ids(second_view)
	_check(second_ids.slice(0, 3) == [
		&"cinder_relay_patrol", &"cinder_platform_mining_run",
		&"cinder_platform_supply_run",
	] and _row_ids(hud) == second_ids,
		"changed priorities move retained rows into critical, reward, active order")
	_check(_row_instances(hud) == retained_instances
		and hud.get_viewport().gui_get_focus_owner() == focused_button,
		"reordering preserves every row node and the focused control")
	_check(StringName(second_view.selected_activity) == &"station_defense"
		and bool(_card(second_view, &"station_defense").selected),
		"selected activity identity survives priority reordering")
	_check(second_ids.slice(3) == [
		&"cinder_reach_emberline_convoy", &"cinder_reach_checkpoint_route",
		&"cinder_derelict_structure_scan", &"cinder_debris_beacon_traversal",
		&"station_defense",
	], "standard available and completed items retain deterministic authored order")

	hud.queue_free()
	await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty(): print("NEARBY_ACTIVITY_RETAINED_PRIORITY_FOCUS_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _first_snapshot() -> Dictionary:
	return {
		"host": {"activity": {"state_id": &"idle"}},
		"race": {"state_id": &"completed"},
		"patrol": {"state_id": &"active", "phase_id": &"travel", "checkpoint_count": 5},
		"mining": {"state": 2, "reward_requested": true},
		"structure_scan": {"state": 0},
		"beacon_traversal": {"state": 1, "presentation_reason": &"out_of_order_beacon", "beacon_count": 4},
		"cargo": _cargo(12.0),
		"station_defense": {"state_id": &"completed", "protected_assets": []},
	}

func _second_snapshot() -> Dictionary:
	return {
		"host": {"activity": {"state_id": &"idle"}},
		"race": {"state_id": &"completed"},
		"patrol": {"state_id": &"failed", "terminal_reason": &"route_lost", "checkpoint_count": 5},
		"mining": {"state": 2, "reward_requested": true},
		"structure_scan": {"state": 0},
		"beacon_traversal": {"state": 2, "beacon_count": 4},
		"cargo": _cargo(60.0),
		"station_defense": {"state_id": &"completed", "protected_assets": []},
	}

func _cargo(remaining: float) -> Dictionary:
	return {"state": 1, "next_phase_index": 1, "phase_count": 3,
		"deadline_seconds": 120.0, "deadline_remaining_seconds": remaining,
		"contract": {"ordered_phases": [&"load_crate", &"clear_gate", &"dock_platform"]}}

func _card_ids(view: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for candidate in view.get("cards", []) as Array:
		ids.append(StringName((candidate as Dictionary).activity_id))
	return ids

func _row_ids(hud: GameHUD) -> Array[StringName]:
	var ids: Array[StringName] = []
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for child in rows.get_children(): ids.append(StringName(child.get_meta(&"activity_id", &"")))
	return ids

func _row_instances(hud: GameHUD) -> Dictionary:
	var instances := {}
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for child in rows.get_children(): instances[StringName(child.get_meta(&"activity_id", &""))] = child.get_instance_id()
	return instances

func _row(hud: GameHUD, activity_id: StringName) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for child in rows.get_children():
		if StringName(child.get_meta(&"activity_id", &"")) == activity_id: return child as Control
	return null

func _card(view: Dictionary, activity_id: StringName) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.activity_id) == activity_id: return card
	return {}

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
