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
	hud.set_mode("piloting")
	hud.call("_set_help_text", hud.call("_help_rows_for_mode", &"piloting"))
	var panel := hud.get("_help_panel") as Control
	var previous := hud.get("_help_previous_button") as Button
	var next := hud.get("_help_next_button") as Button
	var close := hud.get("_help_close_button") as Button
	var page := hud.get("_help_page_label") as Label
	_check(panel != null and panel.visible, "controls help is available as a production panel")
	_check(previous != null and next != null and close != null and page != null, "help exposes previous, next, close, and page controls")
	_check(previous.focus_mode == Control.FOCUS_ALL and next.focus_mode == Control.FOCUS_ALL and close.focus_mode == Control.FOCUS_ALL, "help navigation is controller and keyboard focusable")
	_check(page.text == "PAGE 1 / 3" and previous.disabled and not next.disabled, "help starts on a bounded first page")
	var rows := hud.get("_help_row_controls") as Array
	var visible_first := 0
	for row_value in rows:
		if (row_value as Dictionary).line.visible:
			visible_first += 1
	_check(visible_first == 5, "help shows a bounded page of readable rows")
	hud.call("_next_help_page")
	_check(page.text == "PAGE 2 / 3" and not previous.disabled and not next.disabled, "next page has stable state and focus controls")
	hud.call("_previous_help_page")
	_check(page.text == "PAGE 1 / 3", "previous page returns deterministically")
	_check(not str((rows[0] as Dictionary).key.text).is_empty() and not str((rows[0] as Dictionary).detail.text).is_empty(), "help rows retain published device glyph/text pairs")
	var activity_rows := hud.call("_help_rows_with_role_context", &"piloting") as Array
	var activity_text := " ".join(activity_rows.map(func(row: Variant) -> String: return "%s %s" % [str((row as Array)[0]), str((row as Array)[1])]))
	_check("ACTIVITY BOARD" in activity_text and "INTERACT" in activity_text, "F1 help explains locating and starting activities")
	_check("REWARD PENDING" in activity_text and "FAILURE REASON" in activity_text and "HEAVY BREACH" in activity_text, "F1 help explains static activity outcomes and vocabulary")
	_check("HOST OR JOIN" in activity_text and "CONNECTING" in activity_text and "RECONNECTING" in activity_text, "F1 help explains current networking lifecycle states")
	_check("RETRY OR CANCEL" in activity_text and "DISCONNECT" in activity_text, "F1 help explains bounded network recovery actions")
	hud.update_copilot_navigation_support({"role": "copilot", "selected_target": "BERTH", "selected_route": "ROUTE-1", "request_state": "READY"})
	hud.update_loadmaster_telemetry({"role": "loadmaster", "manifest_state": "READY", "readiness_receipt": "SEALED"})
	hud.call("_set_help_text", hud.call("_help_rows_with_role_context", &"piloting"))
	var role_rows := hud.get("_help_rows") as Array
	var role_text := " ".join(role_rows.map(func(row: Variant) -> String: return "%s %s" % [str((row as Array)[0]), str((row as Array)[1])]))
	_check("COPILOT ROLE" in role_text and "LOADMASTER ROLE" in role_text, "F1 help includes published copilot and loadmaster role pages")
	_check("NO HELM AUTHORITY" in role_text and "NO INVENTORY TRANSFER" in role_text and "NO REWARD AUTHORITY" in role_text, "role help states nonvisual authority boundaries")
	hud.call("_close_help_panel")
	_check(not panel.visible, "close control dismisses help without animation dependency")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HELP_OVERLAY_ACCESSIBILITY_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
