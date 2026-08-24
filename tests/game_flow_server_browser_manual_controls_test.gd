extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SessionType := preload("res://scripts/network/network_enet_session_adapter.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")

class FlowProbe:
	extends GameFlowType

	func _ready() -> void:
		pass


class HudProbe extends CanvasLayer:
	var feedback: Array[Dictionary] = []
	var statuses: Array[Dictionary] = []

	func apply_server_browser_feedback(result: Dictionary) -> void:
		feedback.append(result.duplicate(true))

	func update_network_session_status(snapshot: Dictionary) -> void:
		statuses.append(snapshot.duplicate(true))


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := FlowProbe.new()
	var hud := HudProbe.new()
	var session := SessionType.new()
	var settings := SettingsType.new("user://game_flow_browser_controls_test.cfg")
	settings.network_default_port = 28111
	settings.multiplayer_max_players = 5
	flow.hud = hud
	flow.network_session = session
	flow.runtime_settings = settings
	flow.add_child(session)
	root.add_child(flow)
	flow._on_hud_presentation_intent_requested(&"server_browser", {
		"action": &"host_session",
		"port": 28111,
		"player_name": "Pilot",
	})
	_check(hud.statuses.size() == 1 and hud.statuses[0].state == &"connected", "host intent uses the adapter host path")
	_check(hud.feedback.size() == 1 and bool(hud.feedback[0].accepted), "host result returns normalized browser feedback")
	_check(int(session.get_session_capacity_snapshot().max_players) == 5, "host uses the persisted multiplayer capacity")
	settings.multiplayer_max_players = 12
	_check(int(session.get_session_capacity_snapshot().max_players) == 5, "live capacity edits do not mutate an active session")
	session.shutdown(&"test_cleanup")
	session.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	flow._on_hud_presentation_intent_requested(&"server_browser", {
		"action": &"manual_join",
		"address": "[]",
		"port": 28112,
		"player_name": "Pilot",
	})
	_check(hud.feedback.size() == 2 and not bool(hud.feedback[1].accepted), "manual join failure is returned to browser feedback")
	_check(str(hud.feedback[1].status) == "invalid_address", "manual join preserves adapter validation status")
	_check(session.get("_peer") == null, "invalid manual join is rejected before socket authority is allocated")
	_check(flow._network_session_port == 28111, "rejected endpoint cannot replace the retained session port")
	flow._on_hud_presentation_intent_requested(&"server_browser", {
		"action": &"manual_join",
		"address": "[::1]",
		"port": 28112,
		"player_name": "Pilot",
	})
	_check(hud.feedback.size() == 3 and bool(hud.feedback[2].accepted), "valid manual join reaches the adapter intent seam")
	_check(hud.feedback[2].address == "::1" and flow._network_session_address == "::1" and flow._network_session_port == 28112, "GameFlow retains the transport-normalized endpoint")
	session.shutdown(&"test_cleanup")
	flow.free()
	hud.free()
	if _failures.is_empty():
		print("GAME_FLOW_SERVER_BROWSER_MANUAL_CONTROLS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
