extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _intents: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.presentation_intent_requested.connect(_on_intent)
	hud.request_server_browser_host()
	_check(_intents.size() == 1 and _intents[0].action == &"host_session", "Host Session forwards caller-owned intent")
	hud.request_server_browser_manual_join()
	_check(_intents.size() == 2 and _intents[1].action == &"manual_join", "Manual Join forwards caller-owned intent")
	var address := hud.get("_server_browser_address") as LineEdit
	address.text = "[fe80::1"
	var malformed := hud.request_server_browser_manual_join()
	_check(not malformed.accepted and malformed.reason == &"invalid_address", "invalid IPv6 manual join is rejected before intent emission")
	_check(root.get_viewport().gui_get_focus_owner() == address, "manual address rejection restores keyboard focus to the invalid field")
	var port := hud.get("_server_browser_port") as LineEdit
	port.text = "70000"
	var rejected := hud.request_server_browser_host()
	_check(not rejected.accepted and rejected.reason == &"invalid_port", "invalid host port is rejected before intent emission")
	_check((hud.get("_server_browser_feedback") as Label).text.contains("between"), "validation error is visible and readable")
	hud.apply_server_browser_feedback({"accepted": true, "message": "Session host ready."})
	_check((hud.get("_server_browser_feedback") as Label).text == "Session host ready.", "caller-applied session result updates feedback")
	hud.apply_server_browser_result({"accepted": true, "rows": []})
	_check((hud.get("_server_browser_feedback") as Label).text == "", "fresh directory result clears stale request feedback")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SERVER_BROWSER_MANUAL_CONTROLS_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _on_intent(kind: StringName, payload: Dictionary) -> void:
	if kind == &"server_browser":
		_intents.append(payload.duplicate(true))


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
