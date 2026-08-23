extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_activity_objective("Cargo transfer", {
		"activity_id": &"cargo_transfer", "state_id": &"active", "activity_kind": &"cargo_transfer",
		"phase_id": &"terminal", "completed_steps": 2, "total_steps": 5,
	})
	var cargo_text := str(hud.get_activity_objective_report().get("text", ""))
	_check("USE CARGO TERMINAL" in cargo_text and "2/5" in cargo_text, "cargo board shows physical terminal step and progress")
	hud.set_activity_objective("Station defense", {
		"activity_id": &"station_defense", "state_id": &"active", "activity_kind": &"station_defense",
		"current_wave_index": 1, "wave_count": 3,
		"protected_assets": [{"damage_event_count": 1, "destroyed": false}],
		"next_step": "Protect east perimeter",
	})
	var defense_text := str(hud.get_activity_objective_report().get("text", ""))
	_check("WAVE 2/3" in defense_text and "PROTECT EAST PERIMETER" in defense_text, "defense board shows wave and next step")
	_check("DAMAGED 1" in defense_text and "DESTROYED 0" in defense_text, "defense board shows protected-asset state")
	hud.set_activity_objective("Cargo transfer", {
		"activity_id": &"cargo_transfer", "state_id": &"failed", "activity_kind": &"cargo_transfer",
		"failure_reason": &"terminal_unavailable",
	})
	_check("RECOVER: RETURN TO TERMINAL" in str(hud.get_activity_objective_report().get("text", "")), "failed cargo state exposes recovery step")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ACTIVITY_BOARD_OBJECTIVE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
