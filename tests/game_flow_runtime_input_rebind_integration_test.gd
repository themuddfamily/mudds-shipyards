extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")
const RebindServiceType := preload("res://scripts/settings/input_rebind_service.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var settings := SettingsType.new("user://game_flow_runtime_input_rebind_integration.cfg")
	var flow := GameFlowType.new()
	var hud := HudType.new()
	flow.runtime_settings = settings
	flow.hud = hud
	root.add_child(hud)
	await process_frame
	settings.setting_changed.connect(flow._on_runtime_setting_changed)
	hud.setting_change_requested.connect(flow._on_setting_change_requested)
	var profile := settings.get_input_binding_profile()
	_check(hud.begin_input_binding_capture(&"fire") == false, "closed HUD cannot author a remap")
	profile.set_bindings(&"fire", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_F13}])
	flow._on_setting_change_requested(&"input_binding_profile", profile)
	_check(
		settings.get_input_binding_profile().get_bindings(&"fire") == profile.get_bindings(&"fire"),
		"GameFlow commits the validated caller profile through RuntimeSettings"
	)
	_check(
		_input_map_has_key(&"fire", KEY_F13),
		"accepted remap applies immediately to the canonical InputMap"
	)
	var hud_profile: InputBindingProfile = hud.get("_input_binding_profile")
	_check(
		hud_profile.get_bindings(&"fire") == profile.get_bindings(&"fire")
			and str(hud.call("_action_bindings_text", &"fire")) == "F13",
		"GameFlow refreshes the retained HUD profile and glyph label"
	)
	var defaults := RebindServiceType.new().get_defaults()
	settings.set_input_binding_profile(defaults)
	var default_fire: Dictionary = defaults.get_bindings(&"fire")[0]
	_check(_input_map_has_binding(&"fire", default_fire), "reset profile restores the default InputMap binding")
	settings.setting_changed.disconnect(flow._on_runtime_setting_changed)
	hud.setting_change_requested.disconnect(flow._on_setting_change_requested)
	hud.queue_free()
	flow.free()
	settings = null
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_RUNTIME_INPUT_REBIND_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _input_map_has_key(action: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _input_map_has_binding(action: StringName, expected: Dictionary) -> bool:
	var expected_signature := RebindServiceType.binding_signature(expected)
	for event: InputEvent in InputMap.action_get_events(action):
		if RebindServiceType.binding_signature(RebindServiceType.event_to_binding(event)) == expected_signature:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
