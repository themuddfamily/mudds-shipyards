extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.update_component_degradation({
		"engine_power": 0.0,
		"weapon_power": 0.45,
		"targeting_power": 0.92,
		"affected_component": "port engine",
		"repair_history": ["engine repair confirmed", "weapon repair pending", "sensor recalibrated", "older receipt", "ignored overflow"],
	})
	var panel := hud.get("_runtime_status_panel") as Control
	var detail := hud.get("_runtime_status_detail") as Label
	var actions := hud.get("_runtime_status_actions") as HBoxContainer
	_check(panel.visible, "component status is visible in the production HUD")
	_check(detail.text.contains("ENGINE MOBILITY // DISABLED 000%") and detail.text.contains("WEAPON FIRE // IMPAIRED 045%"), "mobility and fire states are text-first")
	_check(detail.text.contains("SENSOR TARGETING // NOMINAL 092%") and detail.text.contains("AFFECTED // PORT ENGINE"), "sensor percentage and affected component are explicit")
	_check(detail.text.contains("ENGINE REPAIR CONFIRMED") and detail.text.contains("SENSOR RECALIBRATED") and not detail.text.contains("IGNORED OVERFLOW"), "repair confirmation history is bounded and readable")
	_check(actions.get_child_count() == 1 and (actions.get_child(0) as Button).focus_mode == Control.FOCUS_ALL, "component review is controller and keyboard focusable")
	hud.clear_component_degradation()
	_check(not panel.visible, "component status clears on detach")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("COMPONENT_DEGRADATION_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
