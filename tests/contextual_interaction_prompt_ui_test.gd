extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_interaction("[ E ]  BOARD TORRENT", true)
	var label := hud.get("_interaction_label") as Label
	_check(label.text.contains("BOARD TORRENT"), "boarding interaction remains contextually readable")
	_check(label.text.begins_with("["), "interaction prompt retains an explicit control glyph")
	hud._on_controller_glyph_family_selected(1)
	hud.set_interaction("[ E ]  BOARD TORRENT", true)
	_check(label.text.contains("BOARD TORRENT"), "controller glyph change preserves boarding intent")
	_check(label.text != "[ E ]  BOARD TORRENT", "controller-aware prompt remains distinct from keyboard fallback")
	await _test_active_device_interactions(hud)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CONTEXTUAL_INTERACTION_PROMPT_UI_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)


## Activity and planetary interactions retain their authored intent while the
## available Interact binding follows the active device, including remaps.
func _test_active_device_interactions(hud: GameHUD) -> void:
	var label := hud.get("_interaction_label") as Label
	var defaults: InputBindingProfile = hud.get("_input_binding_defaults").duplicate_profile()
	var profile := defaults.duplicate_profile()
	var keyboard_binding := [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_TAB}]
	var mouse_binding := [{"device": &"mouse", "type": &"mouse_button", "button_index": MOUSE_BUTTON_MIDDLE}]
	var controller_binding := [{"device": &"gamepad", "type": &"joy_button", "button_index": JOY_BUTTON_A}]
	for intent: String in ["START COASTAL SURVEY", "LOG BUNKER / GANTRY SURVEY"]:
		hud.set_interaction("[ E ]  " + intent, true)
		profile.set_bindings(&"interact", keyboard_binding)
		_apply_profile(hud, profile)
		hud._on_controller_glyph_family_selected(1)
		_check(label.text == "[ Unbound Input ]  " + intent,
			"controller interaction never advertises a keyboard-only remap: " + intent)
		await _return_to_keyboard(hud)
		_check(label.text == "[ Tab ]  " + intent,
			"returning to keyboard refreshes the retained interaction: " + intent)
		profile.set_bindings(&"interact", controller_binding)
		_apply_profile(hud, profile)
		_check(label.text == "[ Unbound Input ]  " + intent,
			"keyboard interaction never advertises a controller-only binding: " + intent)
		hud._on_controller_glyph_family_selected(1)
		_check(label.text == "[ A ]  " + intent,
			"the retained interaction shows its available Xbox binding: " + intent)
		profile.set_bindings(&"interact", [])
		_apply_profile(hud, profile)
		_check(label.text == "[ Unbound Input ]  " + intent,
			"fully unbound interaction is explicit on controller: " + intent)
		await _return_to_keyboard(hud)
		_check(label.text == "[ Unbound Input ]  " + intent,
			"fully unbound interaction is explicit on keyboard: " + intent)
		profile.set_bindings(&"interact", mouse_binding)
		_apply_profile(hud, profile)
		_check(label.text == "[ Middle Mouse ]  " + intent,
			"desktop interaction accepts its mouse remap: " + intent)
		hud._on_controller_glyph_family_selected(1)
		_check(label.text == "[ Unbound Input ]  " + intent,
			"controller interaction never advertises a mouse-only binding: " + intent)
		await _return_to_keyboard(hud)
		_check(label.text == "[ Middle Mouse ]  " + intent,
			"returning to desktop restores its mouse alternative: " + intent)
		_apply_profile(hud, defaults)
		_check(label.text == "[ E ]  " + intent,
			"restoring defaults preserves authored interaction copy: " + intent)


func _apply_profile(hud: GameHUD, profile: InputBindingProfile) -> void:
	var service: InputRebindService = hud.get("_input_rebind_service")
	var compatible := service.is_profile_compatible_with_defaults(profile)
	_check(compatible, "interaction fixture preserves the complete action inventory")
	if not compatible:
		return
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	_check((hud.get("_input_binding_profile") as InputBindingProfile).to_dictionary() == profile.to_dictionary(),
		"the HUD accepts the interaction fixture before prompt assertions")


func _return_to_keyboard(hud: GameHUD) -> void:
	hud._on_controller_glyph_family_selected(0)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_I
	keyboard.pressed = true
	root.push_input(keyboard)
	await process_frame
