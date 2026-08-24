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
	_check(hud.apply_server_browser_result({"status": &"loading"}), "loading state is accepted")
	_check((hud.get("_server_browser_title") as Label).text == "REFRESHING SERVER LIST", "loading state is explicit")
	var result := hud.apply_server_browser_result({
		"accepted": true,
		"rows": [
			{"session_id": &"open", "title": "Open Run", "region_id": &"eu-west", "ping_ms": 42, "player_count": 1, "max_players": 4},
			{"session_id": &"full", "title": "Full Run", "region_id": &"us-east", "ping_ms": 85, "player_count": 4, "max_players": 4},
		],
	})
	_check(result, "discovery result is accepted")
	_check((hud.get("_server_browser_title") as Label).text == "AVAILABLE SESSIONS", "available state has a readable title")
	var rows := hud.get("_server_browser_rows") as VBoxContainer
	var full_row: Button
	for child in rows.get_children():
		if child is Button and "Full Run" in (child as Button).text:
			full_row = child as Button
	_check(rows.get_child_count() == 2 and full_row != null and full_row.disabled, "full sessions stay visible but cannot be selected")
	hud.apply_server_browser_result({
		"accepted": true,
		"rows": [{"session_id": &"full", "title": "Full Run", "region_id": &"us-east", "ping_ms": 85, "player_count": 4, "max_players": 4}],
	})
	_check((hud.get("_server_browser_title") as Label).text == "ALL SESSIONS FULL", "all-full results have an explicit state")
	_check("NEXT ACTION // REFRESH SERVER LIST OR RETURN" in (hud.get("_server_browser_detail") as Label).text
		and not (hud.get("_server_browser_detail") as Label).text.contains("SELECT A SESSION"),
		"all-full results direct controller users to the enabled refresh or return actions")
	hud.apply_server_browser_result({"accepted": true, "rows": []})
	_check((hud.get("_server_browser_title") as Label).text == "NO SESSIONS FOUND", "empty results have an explicit state")
	hud.apply_server_browser_result({"accepted": true, "rows": [{"session_id": &"open", "title": "Open Run", "region_id": &"eu-west", "ping_ms": 42, "player_count": 1, "max_players": 4}]})
	hud.request_server_browser_join(&"open")
	_check(_intents.size() == 1 and _intents[0].kind == &"server_browser" and _intents[0].payload.session_id == &"open", "join is forwarded as a caller-owned intent")
	hud.apply_server_browser_result({"accepted": false, "reason": &"directory_timeout", "message": "Directory timed out.", "retryable": true, "retry_after_milliseconds": 500})
	_check((hud.get("_server_browser_title") as Label).text == "SERVER LIST UNAVAILABLE", "error state is explicit")
	_check("500 ms" in (hud.get("_server_browser_detail") as Label).text, "exact caller retry timing is visible without relying on colour")
	var refresh_request := hud.request_server_browser_refresh()
	_check(_intents.size() == 2 and _intents[1].payload.action == &"refresh" and refresh_request.request_generation > 0, "refresh is forwarded as a generation-fenced caller-owned intent")
	_check((hud.get("_server_browser_title") as Label).text == "REFRESHING SERVER LIST", "manual refresh immediately exposes pending status")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SERVER_BROWSER_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _on_intent(kind: StringName, payload: Dictionary) -> void:
	_intents.append({"kind": kind, "payload": payload})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
