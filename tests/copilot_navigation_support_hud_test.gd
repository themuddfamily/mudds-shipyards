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
	hud.update_copilot_navigation_support({
		"role": "copilot",
		"occupant": "Mira",
		"selected_target": "Jovian Freight Berth",
		"selected_route": "BERTH-03",
		"request_state": "rejected",
		"reason": "helm occupied",
		"cargo_summary": "2 fabrication kits // 1 reserved",
		"berth_summary": "BERTH-03 // CLEARANCE PENDING",
	})
	var panel := hud.get("_runtime_status_panel") as Control
	var detail := hud.get("_runtime_status_detail") as Label
	var actions := hud.get("_runtime_status_actions") as HBoxContainer
	_check(panel.visible, "copilot support is visible in the production status surface")
	_check(detail.text.contains("ROLE // COPILOT") and detail.text.contains("OCCUPANT // Mira"), "role and occupant are text-readable")
	_check(detail.text.contains("TARGET // Jovian Freight Berth") and detail.text.contains("ROUTE // BERTH-03"), "target and route are text-readable")
	_check(detail.text.contains("REQUEST // REJECTED // HELM OCCUPIED"), "accepted or rejected reason is explicit")
	_check(detail.text.contains("CARGO // 2 fabrication kits // 1 reserved") and detail.text.contains("BERTH // BERTH-03 // CLEARANCE PENDING"), "cargo and berth summaries are read-only text")
	_check(detail.text.contains("NO HELM AUTHORITY") and detail.text.contains("NO CARGO AUTHORITY"), "authority boundaries are explicit and color-independent")
	_check(actions.get_child_count() == 1 and (actions.get_child(0) as Button).focus_mode == Control.FOCUS_ALL, "copilot review is controller and keyboard focusable")
	hud.clear_copilot_navigation_support()
	_check(not panel.visible, "copilot support clears on detach")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("COPILOT_NAVIGATION_SUPPORT_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
