extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const RebindService := preload("res://scripts/settings/input_rebind_service.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var presenter: Variant = hud.get("_runtime_input_glyph_presenter")
	var interact_actions: Array[StringName] = [&"interact"]
	_check(presenter != null, "HUD retains the runtime glyph presenter")
	_check(str(hud.call("_action_prompts", interact_actions)) != "Unbound Input", "controls overlay reads the attached keyboard glyph")
	presenter.set_device_family(&"gamepad_xbox")
	var xbox_prompt := str(hud.call("_action_prompts", interact_actions))
	_check(xbox_prompt != "Unbound Input", "controls overlay refreshes for Xbox-style device family")
	var profile: InputBindingProfile = hud.get("_input_binding_profile").duplicate_profile()
	profile.set_bindings(&"interact", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_TAB}])
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	presenter.set_device_family(&"keyboard")
	_check(str(hud.call("_action_prompts", interact_actions)) == "Tab", "controls overlay refreshes after remapped profile snapshot")
	var selector := (hud.get("_settings_page") as Control).find_child("ControllerGlyphFamilyControl", true, false) as OptionButton
	selector.select(4)
	selector.item_selected.emit(4)
	var controller_profile: InputBindingProfile = RebindService.new().get_defaults()
	controller_profile.set_bindings(&"interact", [{"device": &"gamepad", "type": &"joy_button", "button_index": JOY_BUTTON_A}])
	presenter.refresh(controller_profile)
	_check(str(hud.call("_action_prompts", interact_actions)) == "B", "Nintendo selector preserves physical south action semantics")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RUNTIME_INPUT_GLYPH_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
