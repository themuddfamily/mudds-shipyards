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
	await _test_intro_start_prompt(hud)
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


## The button hint must follow the same interact/jump actions consumed by the
## startup input handler, including restored settings and later device changes.
func _test_intro_start_prompt(hud: GameHUD) -> void:
	var start := hud.find_child("IntroBeginShiftButton", true, false) as Button
	var defaults: InputBindingProfile = hud.get("_input_binding_defaults").duplicate_profile()
	var profile := defaults.duplicate_profile()
	_check(start != null and start.text == "BEGIN SHIFT   [ E ]", "startup keeps the authored default desktop hint")
	if start == null:
		return
	profile.set_bindings(&"interact", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_T}])
	_apply_start_profile(hud, profile)
	_check(start.text == "BEGIN SHIFT   [ T / Space ]", "a restored interact remap updates the startup button with accepted alternatives")
	profile.set_bindings(&"jump", [])
	_apply_start_profile(hud, profile)
	_check(start.text == "BEGIN SHIFT   [ T ]", "an available interact binding suffices without an unbound jump hint")
	profile.set_bindings(&"interact", [])
	profile.set_bindings(&"jump", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_N}])
	_apply_start_profile(hud, profile)
	_check(start.text == "BEGIN SHIFT   [ N ]", "a jump-only startup binding remains available")
	profile.set_bindings(&"jump", [])
	_apply_start_profile(hud, profile)
	_check(start.text == "BEGIN SHIFT   [ Unbound Input ]" and not start.disabled, "missing startup action bindings never advertise E and keep the clickable button usable")
	profile.set_bindings(&"interact", [{"device": &"mouse", "type": &"mouse_button", "button_index": MOUSE_BUTTON_MIDDLE}])
	_apply_start_profile(hud, profile)
	_check(start.text == "BEGIN SHIFT   [ Middle Mouse ]", "the startup hint accepts a remapped mouse binding")
	_apply_start_profile(hud, defaults)
	hud._on_controller_glyph_family_selected(1)
	var controller_start := "%s / %s" % [hud.get_action_prompt(&"interact"), hud.get_action_prompt(&"jump")]
	_check(start.text == "BEGIN SHIFT   [ %s ]" % controller_start and not start.text.contains("[ E ]"),
		"a device switch refreshes the existing startup button without republishing it")
	profile = defaults.duplicate_profile()
	profile.set_bindings(&"interact", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_T}])
	profile.set_bindings(&"jump", [])
	_apply_start_profile(hud, profile)
	_check(start.text == "BEGIN SHIFT   [ Unbound Input ]", "controller startup hints do not fall back onto a desktop remap")
	hud._on_controller_glyph_family_selected(0)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_I
	keyboard.pressed = true
	root.push_input(keyboard)
	await process_frame
	_check(start.text == "BEGIN SHIFT   [ T ]", "returning to keyboard refreshes the retained startup button")
	_apply_start_profile(hud, defaults)
	_check(start.text == "BEGIN SHIFT   [ E ]", "restoring defaults restores exact startup copy")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_GUIDE
	pad.pressed = true
	root.push_input(pad)
	await process_frame
	var resolver: InputGlyphResolver = hud.get("_input_glyph_resolver")
	_check(resolver.get_preferred_device_family() == &"gamepad_generic",
		"native pad input selects controller prompts before the mouse handover")
	pad.pressed = false
	root.push_input(pad)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(4.0, -2.0)
	root.push_input(motion)
	await process_frame
	_check(resolver.get_preferred_device_family() == &"mouse",
		"native mouse look reaches the retained HUD resolver without a click")
	_check(hud.get_action_prompt(&"fire") == "Left Mouse",
		"the retained HUD refreshes Fire to the mouse binding on mouse look")


func _apply_start_profile(hud: GameHUD, profile: InputBindingProfile) -> void:
	var service: InputRebindService = hud.get("_input_rebind_service")
	var compatible := service.is_profile_compatible_with_defaults(profile)
	_check(compatible, "startup fixture is compatible with the complete action inventory")
	if not compatible:
		return
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	_check((hud.get("_input_binding_profile") as InputBindingProfile).to_dictionary() == profile.to_dictionary(),
		"the HUD applies the startup fixture before hint assertions")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
