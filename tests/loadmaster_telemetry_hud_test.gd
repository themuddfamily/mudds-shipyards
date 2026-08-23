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
	hud.update_loadmaster_telemetry({
		"role": "loadmaster",
		"occupant": "Rhea",
		"manifest_state": "blocked",
		"route": "JOVIAN-BERTH-03",
		"readiness_receipt": "manifest sealed // berth clearance pending",
		"history": ["manifest checked", "cargo receipt ready", "reward receipt pending", "old receipt", "ignored overflow"],
	})
	var panel := hud.get("_runtime_status_panel") as Control
	var detail := hud.get("_runtime_status_detail") as Label
	var actions := hud.get("_runtime_status_actions") as HBoxContainer
	_check(panel.visible, "loadmaster status is visible in the production HUD")
	_check(detail.text.contains("ROLE // LOADMASTER") and detail.text.contains("OCCUPANT // Rhea"), "role and occupant are readable")
	_check(detail.text.contains("MANIFEST // BLOCKED") and detail.text.contains("ROUTE // JOVIAN-BERTH-03"), "manifest and route state are explicit")
	_check(detail.text.contains("READINESS // manifest sealed // berth clearance pending"), "readiness receipt is text-first")
	_check(detail.text.contains("MANIFEST CHECKED") and detail.text.contains("OLD RECEIPT") and not detail.text.contains("IGNORED OVERFLOW"), "receipt history is bounded")
	_check(detail.text.contains("NO INVENTORY TRANSFER") and detail.text.contains("NO REWARD AUTHORITY") and detail.text.contains("NO HELM AUTHORITY"), "authority boundaries are explicit")
	_check(actions.get_child_count() == 1 and (actions.get_child(0) as Button).focus_mode == Control.FOCUS_ALL, "loadmaster review is controller and keyboard focusable")
	hud.clear_loadmaster_telemetry()
	_check(not panel.visible, "loadmaster status clears on detach")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("LOADMASTER_TELEMETRY_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
