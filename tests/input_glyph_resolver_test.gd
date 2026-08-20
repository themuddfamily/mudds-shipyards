extends SceneTree

const Resolver := preload("res://scripts/ui/input_glyph_resolver.gd")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_keyboard_and_mouse_resolution()
	_test_gamepad_layouts_and_axes()
	_test_last_active_selection_and_override()
	_test_deadzone_and_event_observation()
	_test_deterministic_deep_copy_audit()
	_test_unknown_fallbacks()
	_finish()


func _test_keyboard_and_mouse_resolution() -> void:
	var key := Resolver.resolve_binding(_key(KEY_W), Resolver.FAMILY_KEYBOARD)
	_check(
		key.valid and key.glyph_token == &"key.w" and key.text == "W"
		and key.localization_key == &"input.key.w",
		"physical W resolves to a stable semantic key token and fallback text"
	)
	var space := Resolver.resolve_binding(_key(KEY_SPACE), Resolver.FAMILY_KEYBOARD)
	_check(
		space.glyph_token == &"key.space" and space.fallback_text == "Space",
		"named physical keys retain semantic localization keys"
	)
	var wheel := Resolver.resolve_binding(_mouse(MOUSE_BUTTON_WHEEL_UP), Resolver.FAMILY_MOUSE)
	_check(
		wheel.valid and wheel.glyph_token == &"mouse.wheel_up" and wheel.text == "Wheel Up",
		"mouse wheel direction resolves independently from ordinary buttons"
	)
	var side := Resolver.resolve_binding(_mouse(MOUSE_BUTTON_XBUTTON1), Resolver.FAMILY_MOUSE)
	_check(side.glyph_token == &"mouse.back", "mouse side button resolves to its semantic role")


func _test_gamepad_layouts_and_axes() -> void:
	var bottom := _joy_button(JOY_BUTTON_A)
	var generic := Resolver.resolve_binding(bottom, Resolver.FAMILY_GAMEPAD_GENERIC)
	var xbox := Resolver.resolve_binding(bottom, Resolver.FAMILY_GAMEPAD_XBOX)
	var playstation := Resolver.resolve_binding(bottom, Resolver.FAMILY_GAMEPAD_PLAYSTATION)
	var nintendo := Resolver.resolve_binding(bottom, Resolver.FAMILY_GAMEPAD_NINTENDO)
	_check(
		generic.glyph_token == &"gamepad.generic.face_bottom"
		and xbox.glyph_token == &"gamepad.xbox.a"
		and playstation.glyph_token == &"gamepad.playstation.cross"
		and nintendo.glyph_token == &"gamepad.nintendo.b",
		"standardized bottom-face position resolves for generic, Xbox, PlayStation, and Nintendo layouts"
	)
	var left := Resolver.resolve_binding(_joy_axis(JOY_AXIS_LEFT_X, -1.0), Resolver.FAMILY_GAMEPAD_XBOX)
	var down := Resolver.resolve_binding(_joy_axis(JOY_AXIS_LEFT_Y, 1.0), Resolver.FAMILY_GAMEPAD_PLAYSTATION)
	var trigger := Resolver.resolve_binding(_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), Resolver.FAMILY_GAMEPAD_NINTENDO)
	_check(
		left.glyph_token == &"gamepad.xbox.left_stick.left"
		and down.glyph_token == &"gamepad.playstation.left_stick.down"
		and trigger.glyph_token == &"gamepad.nintendo.right_trigger"
		and trigger.text == "ZR",
		"directional axes and family-specific trigger text resolve semantically"
	)
	var dpad := Resolver.resolve_binding(_joy_button(JOY_BUTTON_DPAD_UP), Resolver.FAMILY_GAMEPAD_PLAYSTATION)
	_check(
		dpad.glyph_token == &"gamepad.playstation.dpad_up" and dpad.text == "D-pad Up",
		"shared standardized buttons keep the requested gamepad family"
	)


func _test_last_active_selection_and_override() -> void:
	var profile := _profile()
	var resolver := Resolver.new()
	var initial := resolver.resolve_action(profile, &"fire", {"device_class": "gamepad", "layout": "xbox"})
	_check(initial.glyph_token == &"key.f" and initial.selection_family == Resolver.FAMILY_KEYBOARD, "keyboard is the deterministic initial family")
	_check(resolver.observe_binding_activity(_mouse(MOUSE_BUTTON_LEFT), 1.0), "active mouse binding updates presentation preference")
	var mouse := resolver.resolve_action(profile, &"fire")
	_check(mouse.glyph_token == &"mouse.left" and not mouse.selected_by_fallback, "last-active mouse selects the mouse binding")
	_check(
		resolver.observe_binding_activity(_joy_button(JOY_BUTTON_A), 1.0, 0.18, {"device_class": "gamepad", "layout": "xbox"}),
		"active gamepad button updates presentation preference from provided metadata"
	)
	var pad := resolver.resolve_action(profile, &"fire", {"device_class": "gamepad", "layout": "xbox"})
	_check(pad.glyph_token == &"gamepad.xbox.a", "last-active Xbox family selects and labels the gamepad binding")
	_check(resolver.set_explicit_device_family_override(Resolver.FAMILY_GAMEPAD_PLAYSTATION), "valid explicit family override is accepted")
	resolver.observe_binding_activity(_key(KEY_F), 1.0)
	var overridden := resolver.resolve_action(profile, &"fire")
	_check(
		overridden.glyph_token == &"gamepad.playstation.cross"
		and overridden.explicit_override == Resolver.FAMILY_GAMEPAD_PLAYSTATION,
		"later keyboard activity cannot replace an explicit PlayStation override"
	)
	_check(
		not resolver.set_explicit_device_family_override(&"invented_console")
		and resolver.get_explicit_device_family_override() == Resolver.FAMILY_GAMEPAD_PLAYSTATION,
		"invalid override is rejected without erasing the valid explicit choice"
	)
	resolver.clear_explicit_device_family_override()
	_check(resolver.get_preferred_device_family() == Resolver.FAMILY_KEYBOARD, "clearing override reveals the last-active keyboard family")


func _test_deadzone_and_event_observation() -> void:
	var resolver := Resolver.new()
	resolver.observe_binding_activity(_mouse(MOUSE_BUTTON_LEFT), 1.0)
	_check(
		not resolver.observe_binding_activity(
			_joy_axis(JOY_AXIS_LEFT_X, 1.0),
			0.17,
			0.18,
			{"device_class": "gamepad", "layout": "nintendo"}
		)
		and resolver.get_last_active_device_family() == Resolver.FAMILY_MOUSE,
		"axis noise below the action deadzone cannot switch device family"
	)
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.181
	_check(
		resolver.observe_input_event(motion, 0.18, {"device_class": "gamepad", "layout": "nintendo"})
		and resolver.get_last_active_device_family() == Resolver.FAMILY_GAMEPAD_NINTENDO,
		"directional axis activity above deadzone selects the metadata-provided family"
	)
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_W
	echo.pressed = true
	echo.echo = true
	_check(not resolver.observe_input_event(echo), "keyboard repeat does not masquerade as a new active-device transition")


func _test_deterministic_deep_copy_audit() -> void:
	var profile := _profile()
	var resolver := Resolver.new()
	var first := resolver.audit_profile(profile, {"device_class": "gamepad", "layout": "xbox"})
	var second := resolver.audit_profile(profile, {"device_class": "gamepad", "layout": "xbox"})
	_check(
		first.valid and first == second and first.fingerprint == second.fingerprint,
		"repeated audit is byte-order deterministic"
	)
	var original_code := int((profile.get_bindings(&"fire")[0] as Dictionary).physical_keycode)
	(((first.actions as Array)[0] as Dictionary).bindings[0] as Dictionary).binding.physical_keycode = KEY_G
	var third := resolver.audit_profile(profile, {"device_class": "gamepad", "layout": "xbox"})
	_check(
		int((profile.get_bindings(&"fire")[0] as Dictionary).physical_keycode) == original_code
		and third == second,
		"mutating an audit's nested descriptor cannot mutate the profile or a later audit"
	)
	_check(
		str((first.actions[0] as Dictionary).action) == "fire"
		and str((first.actions[1] as Dictionary).action) == "move_forward",
		"audit sorts action names independently of dictionary insertion order"
	)


func _test_unknown_fallbacks() -> void:
	_check(
		Resolver.gamepad_family_from_metadata({"device_class": "gamepad", "layout": "mystery_pad"})
		== Resolver.FAMILY_GAMEPAD_GENERIC,
		"unknown provided gamepad layout falls back to generic without platform guessing"
	)
	var unknown_button := Resolver.resolve_binding(
		_joy_button(77),
		Resolver.FAMILY_GAMEPAD_GENERIC,
		{"device_class": "gamepad", "layout": "mystery_pad"}
	)
	_check(
		unknown_button.valid and unknown_button.fallback_used
		and unknown_button.glyph_token == &"gamepad.generic.button_77"
		and unknown_button.text == "Gamepad Button 77",
		"unknown standardized button retains a stable generic token and readable fallback"
	)
	var invalid := Resolver.resolve_binding({"device": &"unknown", "type": &"key"})
	_check(
		not invalid.valid and invalid.glyph_token == &"input.unknown"
		and invalid.text == "Unbound Input",
		"invalid device descriptor returns the explicit unknown-input fallback"
	)
	var resolver := Resolver.new()
	resolver.set_explicit_device_family_override(Resolver.FAMILY_GAMEPAD_XBOX)
	var keyboard_only := resolver.resolve_action(_keyboard_only_profile(), &"interact")
	_check(
		keyboard_only.glyph_token == &"key.e" and keyboard_only.selected_by_fallback,
		"missing preferred-family binding falls back deterministically without altering override"
	)
	var source_profile := _profile()
	var all_bindings := resolver.resolve_action_bindings(source_profile, &"fire")
	_check(
		all_bindings.size() == 3
		and all_bindings[0].glyph_token == &"key.f"
		and all_bindings[1].glyph_token == &"mouse.left"
		and all_bindings[2].glyph_token == &"gamepad.generic.face_bottom",
		"accessible binding enumeration exposes every retained Fire glyph in profile order"
	)
	(all_bindings[0] as Dictionary).binding.physical_keycode = KEY_G
	_check(
		int((source_profile.get_bindings(&"fire")[0] as Dictionary).physical_keycode) == KEY_F,
		"enumerated glyph descriptors are detached from the source binding profile"
	)


func _profile() -> InputBindingProfile:
	# Deliberately insert move_forward before fire; audit must sort it.
	return InputBindingProfile.from_dictionary({
		"schema_version": InputBindingProfile.SCHEMA_VERSION,
		"bindings": {
			&"move_forward": [_key(KEY_W), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)],
			&"fire": [_key(KEY_F), _mouse(MOUSE_BUTTON_LEFT), _joy_button(JOY_BUTTON_A)],
		},
		"action_options": {
			&"move_forward": {"deadzone": 0.18, "curve": &"linear", "hold_mode": &"hold"},
			&"fire": {"deadzone": 0.18, "curve": &"linear", "hold_mode": &"hold"},
		},
	})


func _keyboard_only_profile() -> InputBindingProfile:
	return InputBindingProfile.from_dictionary({
		"schema_version": InputBindingProfile.SCHEMA_VERSION,
		"bindings": {&"interact": [_key(KEY_E)]},
		"action_options": {&"interact": {"deadzone": 0.18, "curve": &"linear", "hold_mode": &"hold"}},
	})


func _key(code: int) -> Dictionary:
	return {"device": &"keyboard", "type": &"key", "physical_keycode": code}


func _mouse(button: int) -> Dictionary:
	return {"device": &"mouse", "type": &"mouse_button", "button_index": button}


func _joy_button(button: int) -> Dictionary:
	return {"device": &"gamepad", "type": &"joy_button", "button_index": button}


func _joy_axis(axis: int, value: float) -> Dictionary:
	return {"device": &"gamepad", "type": &"joy_motion", "axis": axis, "axis_value": value}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty() and _assertions > 0:
		print("INPUT_GLYPH_RESOLVER_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		if _assertions == 0:
			_failures.append("no assertions executed")
		print("INPUT_GLYPH_RESOLVER_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
