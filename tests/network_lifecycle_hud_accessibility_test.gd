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
	hud.update_network_session_status({
		"generation": 4,
		"peer_generation": 9,
		"session_generation": 12,
		"state": "rejected",
		"detail": "Protocol mismatch.",
		"retryable": true,
		"history": ["connecting", "protocol mismatch", "rejected", "ignored overflow", "ignored too"],
	})
	var panel := hud.get("_runtime_status_panel") as Control
	var title := hud.get("_runtime_status_title") as Label
	var detail := hud.get("_runtime_status_detail") as Label
	var actions := hud.get("_runtime_status_actions") as HBoxContainer
	_check(panel.visible and title.text == "Connection Rejected", "rejected lifecycle state is explicit")
	_check(detail.text.contains("Protocol mismatch.") and detail.text.contains("PEER 9  //  SESSION 12"), "reason and generation summary are text-readable")
	_check(detail.text.contains("HISTORY // PROTOCOL MISMATCH") and detail.text.contains("HISTORY // REJECTED") and not detail.text.contains("HISTORY // CONNECTING"), "lifecycle history is bounded")
	_check(actions.get_child_count() == 2 and (actions.get_child(0) as Button).text == "Retry Connection" and (actions.get_child(1) as Button).text == "Cancel", "retry and cancel are focusable recovery intents")
	hud.update_network_session_status({"generation": 5, "state": "connected", "detail": "Connected."})
	_check((hud.get("_runtime_status_title") as Label).text == "Connected", "connected transition clears rejection presentation")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_LIFECYCLE_HUD_ACCESSIBILITY_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
