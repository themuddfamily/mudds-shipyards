extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _failures: PackedStringArray = []
var _assertions := 0
var _requests: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var controls := hud.get("_settings_controls") as Dictionary
	var name_control := controls.get(&"multiplayer_display_name") as LineEdit
	var port_control := controls.get(&"network_default_port") as SpinBox
	var capacity_control := controls.get(&"multiplayer_max_players") as SpinBox
	_check(name_control != null and name_control.focus_mode == Control.FOCUS_ALL, "display name is controller-focusable")
	_check(port_control != null and port_control.focus_mode == Control.FOCUS_ALL, "port is controller-focusable")
	_check(capacity_control != null and capacity_control.focus_mode == Control.FOCUS_ALL, "host capacity is controller-focusable")
	hud.setting_change_requested.connect(_on_setting_change_requested)
	name_control.text = "Survey Team"
	name_control.emit_signal("text_submitted", name_control.text)
	port_control.value = 28000
	capacity_control.value = 12
	_check(_requests.size() == 3, "multiplayer controls emit caller-owned persistence intents")
	_check(_requests[0].key == &"multiplayer_display_name" and _requests[0].value == "Survey Team", "display-name intent preserves backend key")
	_check(_requests[1].key == &"network_default_port" and int(_requests[1].value) == 28000, "port intent preserves bounded value")
	_check(_requests[2].key == &"multiplayer_max_players" and int(_requests[2].value) == 12, "capacity intent preserves bounded value")
	hud.set_settings_snapshot({"multiplayer_display_name": "Captain", "network_default_port": 29000, "multiplayer_max_players": 16})
	_check(name_control.text == "Captain" and int(port_control.value) == 29000 and int(capacity_control.value) == 16, "server-browser defaults update from caller snapshots")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MULTIPLAYER_SETTINGS_UI_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _on_setting_change_requested(key: StringName, value: Variant) -> void:
	_requests.append({"key": key, "value": value})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
