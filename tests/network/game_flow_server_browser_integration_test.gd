extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SessionType := preload("res://scripts/network/network_enet_session_adapter.gd")

class HudProbe extends CanvasLayer:
	var browser_results: Array[Dictionary] = []
	var network_results: Array[Dictionary] = []

	func apply_server_browser_result(result: Dictionary) -> void:
		browser_results.append(result.duplicate(true))

	func update_network_session_status(snapshot: Dictionary) -> void:
		network_results.append(snapshot.duplicate(true))


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	var hud := HudProbe.new()
	flow.hud = hud
	var session := SessionType.new()
	root.add_child(session)
	flow.network_session = session
	flow._connect_signal_once(session, &"server_browser_result", flow._on_server_browser_result)
	var applied: Dictionary = session.apply_server_directory_snapshot(4, 12, [{
		"session_id": &"open_run",
		"host_peer_id": 7,
		"title": "Open Run",
		"region_id": &"eu-west",
		"ping_ms": 42,
		"player_count": 1,
		"max_players": 4,
	}])
	_check(bool(applied.get("accepted", false)), "adapter accepts detached discovery snapshot")
	_check(hud.browser_results.size() == 1 and hud.browser_results[0].rows.size() == 1
		and hud.browser_results[0].directory_generation == 4
		and hud.browser_results[0].server_tick == 12
		and hud.browser_results[0].snapshot_sequence > 0,
		"GameFlow forwards adapter listings with the complete production directory cursor")
	flow._on_hud_presentation_intent_requested(&"server_browser", {
		"action": &"refresh",
		"request": {"request_generation": 9},
	})
	_check(hud.browser_results.size() == 2 and hud.browser_results.back().rows.size() == 1
		and hud.browser_results.back().request_generation == 9,
		"refresh reads the current detached listings and echoes the HUD request fence")
	var expired := session.expire_server_directory(43)
	_check(expired.accepted and hud.browser_results.size() == 3
		and hud.browser_results.back().rows.is_empty()
		and hud.browser_results.back().directory_generation == 4
		and hud.browser_results.back().snapshot_sequence > hud.browser_results[0].snapshot_sequence,
		"clock expiry reaches the HUD with empty rows and a complete advanced cursor")
	_check(session.apply_server_directory_snapshot(5, 43, [{
		"session_id": &"open_run",
		"host_peer_id": 7,
		"title": "Open Run",
		"region_id": &"eu-west",
		"ping_ms": 42,
		"player_count": 1,
		"max_players": 4,
	}]).accepted, "a fresh directory publication restores the join fixture after expiry")
	flow._on_hud_presentation_intent_requested(&"server_browser", {"action": &"join", "session_id": &"open_run"})
	_check(hud.network_results.size() == 1 and hud.network_results.back().state == &"connecting", "join intent uses the adapter's validated join path")
	_check(bool(session.get("_configured")), "validated join starts through ENet adapter")
	session.shutdown(&"test_cleanup")
	session.queue_free()
	if _failures.is_empty():
		print("GAME_FLOW_SERVER_BROWSER_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
