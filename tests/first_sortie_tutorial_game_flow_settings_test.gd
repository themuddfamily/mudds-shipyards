extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")

class HudProbe extends CanvasLayer:
	var snapshots: Array[Dictionary] = []

	func apply_first_sortie_tutorial_snapshot(snapshot: Dictionary) -> bool:
		snapshots.append(snapshot.duplicate(true))
		return bool(snapshot.get("show_tutorials", true))


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	var hud := HudProbe.new()
	flow.hud = hud
	flow.runtime_settings = SettingsType.new("user://first_sortie_tutorial_game_flow_settings_test.cfg")
	_check(flow.apply_first_sortie_tutorial_snapshot({"step_id": &"board"}), "enabled tutorial policy reaches retained HUD")
	_check(hud.snapshots.back().show_tutorials, "default policy is enabled before prompt formatting")
	flow.runtime_settings.show_tutorials = false
	_check(not flow.apply_first_sortie_tutorial_snapshot({"step_id": &"board"}), "disabled policy suppresses prompt at GameFlow boundary")
	_check(not hud.snapshots.back().show_tutorials, "live disabled policy is forwarded immediately")
	flow.runtime_settings.show_tutorials = true
	_check(flow.apply_first_sortie_tutorial_snapshot({"step_id": &"board"}), "valid live change re-enables prompts")
	_check(GameFlowType.RUNTIME_SETTING_KEYS.has(&"show_tutorials"), "tutorial policy participates in validated setting changes")
	if _failures.is_empty():
		print("FIRST_SORTIE_TUTORIAL_GAME_FLOW_SETTINGS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
