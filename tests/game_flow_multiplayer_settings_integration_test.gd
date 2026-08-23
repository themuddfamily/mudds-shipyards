extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")

class HudProbe extends CanvasLayer:
	var _server_browser_port := LineEdit.new()
	var _server_browser_player_name := LineEdit.new()
	var snapshots: Array[Dictionary] = []

	func set_settings_snapshot(snapshot: Dictionary) -> void:
		snapshots.append(snapshot.duplicate(true))

	func set_settings_status(_text: String, _accepted: bool = false) -> void:
		pass

	func toast(_title: String, _message: String, _duration: float) -> void:
		pass


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	var settings := SettingsType.new("user://game_flow_multiplayer_settings_test.cfg")
	var first_hud := HudProbe.new()
	flow.runtime_settings = settings
	flow.hud = first_hud
	settings.setting_changed.connect(flow._on_runtime_setting_changed)
	settings.multiplayer_display_name = "Dockmaster"
	settings.network_default_port = 28001
	flow._sync_runtime_settings_hud()
	_check(first_hud._server_browser_player_name.text == "Dockmaster", "loaded settings reach the retained browser name field")
	_check(first_hud._server_browser_port.text == "28001", "loaded settings reach the retained browser port field")
	settings.network_default_port = 29001
	flow._on_runtime_setting_changed(&"network_default_port", 29001)
	_check(first_hud._server_browser_port.text == "29001", "valid live port changes update browser defaults immediately")
	flow._on_setting_change_requested(&"multiplayer_display_name", "Captain")
	_check(first_hud._server_browser_player_name.text == "Captain", "valid live name changes update browser defaults")
	flow.hud = null
	var reentered_hud := HudProbe.new()
	flow.hud = reentered_hud
	flow._sync_runtime_settings_hud()
	_check(reentered_hud._server_browser_player_name.text == "Captain", "re-entry reapplies retained display name")
	_check(reentered_hud._server_browser_port.text == "29001", "re-entry reapplies retained default port")
	_check(first_hud.snapshots.size() == 1 and reentered_hud.snapshots.size() == 1, "settings snapshots remain caller-owned across re-entry")
	if _failures.is_empty():
		print("GAME_FLOW_MULTIPLAYER_SETTINGS_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
