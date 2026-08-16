class_name InputGlyphResolver
extends RefCounted

## Pure presentation resolver for InputBindingProfile descriptors. No method
## reads or mutates InputMap, and gamepad layout comes only from caller metadata.

const FAMILY_KEYBOARD := &"keyboard"
const FAMILY_MOUSE := &"mouse"
const FAMILY_GAMEPAD_GENERIC := &"gamepad_generic"
const FAMILY_GAMEPAD_XBOX := &"gamepad_xbox"
const FAMILY_GAMEPAD_PLAYSTATION := &"gamepad_playstation"
const FAMILY_GAMEPAD_NINTENDO := &"gamepad_nintendo"

const GAMEPAD_FAMILIES := [
	FAMILY_GAMEPAD_GENERIC,
	FAMILY_GAMEPAD_XBOX,
	FAMILY_GAMEPAD_PLAYSTATION,
	FAMILY_GAMEPAD_NINTENDO,
]
const VALID_FAMILIES := [
	FAMILY_KEYBOARD,
	FAMILY_MOUSE,
	FAMILY_GAMEPAD_GENERIC,
	FAMILY_GAMEPAD_XBOX,
	FAMILY_GAMEPAD_PLAYSTATION,
	FAMILY_GAMEPAD_NINTENDO,
]

const _KEY_NAMES := {
	KEY_SPACE: [&"space", "Space"],
	KEY_ENTER: [&"enter", "Enter"],
	KEY_ESCAPE: [&"escape", "Esc"],
	KEY_TAB: [&"tab", "Tab"],
	KEY_BACKSPACE: [&"backspace", "Backspace"],
	KEY_SHIFT: [&"shift", "Shift"],
	KEY_CTRL: [&"control", "Ctrl"],
	KEY_ALT: [&"alt", "Alt"],
	KEY_META: [&"meta", "Meta"],
	KEY_CAPSLOCK: [&"caps_lock", "Caps Lock"],
	KEY_UP: [&"arrow_up", "Up"],
	KEY_DOWN: [&"arrow_down", "Down"],
	KEY_LEFT: [&"arrow_left", "Left"],
	KEY_RIGHT: [&"arrow_right", "Right"],
	KEY_HOME: [&"home", "Home"],
	KEY_END: [&"end", "End"],
	KEY_PAGEUP: [&"page_up", "Page Up"],
	KEY_PAGEDOWN: [&"page_down", "Page Down"],
	KEY_INSERT: [&"insert", "Insert"],
	KEY_DELETE: [&"delete", "Delete"],
}

const _MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: [&"left", "Left Mouse"],
	MOUSE_BUTTON_RIGHT: [&"right", "Right Mouse"],
	MOUSE_BUTTON_MIDDLE: [&"middle", "Middle Mouse"],
	MOUSE_BUTTON_WHEEL_UP: [&"wheel_up", "Wheel Up"],
	MOUSE_BUTTON_WHEEL_DOWN: [&"wheel_down", "Wheel Down"],
	MOUSE_BUTTON_WHEEL_LEFT: [&"wheel_left", "Wheel Left"],
	MOUSE_BUTTON_WHEEL_RIGHT: [&"wheel_right", "Wheel Right"],
	MOUSE_BUTTON_XBUTTON1: [&"back", "Mouse Back"],
	MOUSE_BUTTON_XBUTTON2: [&"forward", "Mouse Forward"],
}

const _GENERIC_BUTTONS := {
	JOY_BUTTON_A: [&"face_bottom", "Bottom Face Button"],
	JOY_BUTTON_B: [&"face_right", "Right Face Button"],
	JOY_BUTTON_X: [&"face_left", "Left Face Button"],
	JOY_BUTTON_Y: [&"face_top", "Top Face Button"],
	JOY_BUTTON_BACK: [&"back", "Back"],
	JOY_BUTTON_GUIDE: [&"guide", "Guide"],
	JOY_BUTTON_START: [&"start", "Start"],
	JOY_BUTTON_LEFT_STICK: [&"left_stick", "Left Stick"],
	JOY_BUTTON_RIGHT_STICK: [&"right_stick", "Right Stick"],
	JOY_BUTTON_LEFT_SHOULDER: [&"left_bumper", "Left Bumper"],
	JOY_BUTTON_RIGHT_SHOULDER: [&"right_bumper", "Right Bumper"],
	JOY_BUTTON_DPAD_UP: [&"dpad_up", "D-pad Up"],
	JOY_BUTTON_DPAD_DOWN: [&"dpad_down", "D-pad Down"],
	JOY_BUTTON_DPAD_LEFT: [&"dpad_left", "D-pad Left"],
	JOY_BUTTON_DPAD_RIGHT: [&"dpad_right", "D-pad Right"],
	JOY_BUTTON_MISC1: [&"misc", "Misc Button"],
	JOY_BUTTON_PADDLE1: [&"paddle_1", "Paddle 1"],
	JOY_BUTTON_PADDLE2: [&"paddle_2", "Paddle 2"],
	JOY_BUTTON_PADDLE3: [&"paddle_3", "Paddle 3"],
	JOY_BUTTON_PADDLE4: [&"paddle_4", "Paddle 4"],
	JOY_BUTTON_TOUCHPAD: [&"touchpad", "Touchpad"],
}

const _XBOX_FACE := {
	JOY_BUTTON_A: [&"a", "A"], JOY_BUTTON_B: [&"b", "B"],
	JOY_BUTTON_X: [&"x", "X"], JOY_BUTTON_Y: [&"y", "Y"],
	JOY_BUTTON_BACK: [&"view", "View"], JOY_BUTTON_GUIDE: [&"xbox", "Xbox"],
	JOY_BUTTON_START: [&"menu", "Menu"],
	JOY_BUTTON_LEFT_STICK: [&"ls", "LS"], JOY_BUTTON_RIGHT_STICK: [&"rs", "RS"],
	JOY_BUTTON_LEFT_SHOULDER: [&"lb", "LB"], JOY_BUTTON_RIGHT_SHOULDER: [&"rb", "RB"],
}

const _PLAYSTATION_FACE := {
	JOY_BUTTON_A: [&"cross", "Cross"], JOY_BUTTON_B: [&"circle", "Circle"],
	JOY_BUTTON_X: [&"square", "Square"], JOY_BUTTON_Y: [&"triangle", "Triangle"],
	JOY_BUTTON_BACK: [&"create", "Create"], JOY_BUTTON_GUIDE: [&"ps", "PS"],
	JOY_BUTTON_START: [&"options", "Options"],
	JOY_BUTTON_LEFT_STICK: [&"l3", "L3"], JOY_BUTTON_RIGHT_STICK: [&"r3", "R3"],
	JOY_BUTTON_LEFT_SHOULDER: [&"l1", "L1"], JOY_BUTTON_RIGHT_SHOULDER: [&"r1", "R1"],
}

const _NINTENDO_FACE := {
	# Godot/SDL indices describe positions: bottom=A index, right=B index, etc.
	JOY_BUTTON_A: [&"b", "B"], JOY_BUTTON_B: [&"a", "A"],
	JOY_BUTTON_X: [&"y", "Y"], JOY_BUTTON_Y: [&"x", "X"],
	JOY_BUTTON_BACK: [&"minus", "−"], JOY_BUTTON_GUIDE: [&"home", "Home"],
	JOY_BUTTON_START: [&"plus", "+"],
	JOY_BUTTON_LEFT_STICK: [&"left_stick", "Left Stick"],
	JOY_BUTTON_RIGHT_STICK: [&"right_stick", "Right Stick"],
	JOY_BUTTON_LEFT_SHOULDER: [&"l", "L"], JOY_BUTTON_RIGHT_SHOULDER: [&"r", "R"],
}

var _last_active_family: StringName = FAMILY_KEYBOARD
var _explicit_family_override: StringName = &""


func set_explicit_device_family_override(family: StringName) -> bool:
	if family == &"":
		_explicit_family_override = &""
		return true
	if not VALID_FAMILIES.has(family):
		return false
	_explicit_family_override = family
	return true


func clear_explicit_device_family_override() -> void:
	_explicit_family_override = &""


func get_explicit_device_family_override() -> StringName:
	return _explicit_family_override


func get_last_active_device_family() -> StringName:
	return _last_active_family


func get_preferred_device_family() -> StringName:
	return _explicit_family_override if not _explicit_family_override.is_empty() else _last_active_family


## `strength` is the already-sampled magnitude for this descriptor. Axis noise at
## or below `deadzone` is presentation-inert and cannot steal glyph preference.
func observe_binding_activity(
		candidate: Variant,
		strength: float,
		deadzone: float = 0.18,
		device_metadata: Dictionary = {}
	) -> bool:
	var binding := InputBindingProfile.normalize_binding(candidate)
	if binding.is_empty() or not is_finite(strength):
		return false
	var threshold := clampf(deadzone, 0.0, 1.0) if binding.type == &"joy_motion" else 0.5
	if absf(strength) <= threshold:
		return false
	_last_active_family = _family_for_binding(binding, device_metadata)
	return true


func observe_input_event(
		event: InputEvent,
		deadzone: float = 0.18,
		device_metadata: Dictionary = {}
	) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo or key.physical_keycode <= 0:
			return false
		_last_active_family = FAMILY_KEYBOARD
		return true
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return false
		_last_active_family = FAMILY_MOUSE
		return true
	if event is InputEventJoypadButton:
		if not (event as InputEventJoypadButton).pressed:
			return false
		_last_active_family = gamepad_family_from_metadata(device_metadata)
		return true
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) <= clampf(deadzone, 0.0, 1.0):
			return false
		_last_active_family = gamepad_family_from_metadata(device_metadata)
		return true
	return false


func resolve_action(
		profile: InputBindingProfile,
		action: StringName,
		device_metadata: Dictionary = {}
	) -> Dictionary:
	if profile == null:
		return _unknown_result({}, get_preferred_device_family(), "profile unavailable")
	var bindings := profile.get_bindings(action)
	if bindings.is_empty():
		return _unknown_result({}, get_preferred_device_family(), "action has no binding")
	var preferred := get_preferred_device_family()
	var preferred_device := _profile_device_for_family(preferred)
	var selected: Dictionary = {}
	for binding in bindings:
		if StringName(binding.get("device", &"")) == preferred_device:
			selected = binding.duplicate(true)
			break
	if selected.is_empty():
		for fallback_device in _fallback_device_order(preferred_device):
			for binding in bindings:
				if StringName(binding.get("device", &"")) == fallback_device:
					selected = binding.duplicate(true)
					break
			if not selected.is_empty():
				break
	var result := resolve_binding(selected, preferred, device_metadata)
	result["action"] = action
	result["selection_family"] = preferred
	result["explicit_override"] = _explicit_family_override
	result["selected_by_fallback"] = StringName(selected.get("device", &"")) != preferred_device
	return result.duplicate(true)


static func resolve_binding(
		candidate: Variant,
		requested_family: StringName = FAMILY_KEYBOARD,
		device_metadata: Dictionary = {}
	) -> Dictionary:
	var binding := InputBindingProfile.normalize_binding(candidate)
	if binding.is_empty():
		return _unknown_result({}, requested_family, "invalid binding descriptor")
	match StringName(binding.type):
		&"key":
			return _resolve_key(binding)
		&"mouse_button":
			return _resolve_mouse(binding)
		&"joy_button":
			return _resolve_joy_button(binding, _resolved_gamepad_family(requested_family, device_metadata))
		&"joy_motion":
			return _resolve_joy_axis(binding, _resolved_gamepad_family(requested_family, device_metadata))
	return _unknown_result(binding, requested_family, "unsupported binding type")


func audit_profile(profile: InputBindingProfile, device_metadata: Dictionary = {}) -> Dictionary:
	if profile == null:
		return {"valid": false, "actions": [], "fingerprint": "", "errors": ["profile unavailable"]}
	var action_names := profile.bindings.keys()
	action_names.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	var actions: Array[Dictionary] = []
	for action_variant in action_names:
		var action := StringName(action_variant)
		var resolved_bindings: Array[Dictionary] = []
		for binding in profile.get_bindings(action):
			var family := _family_for_binding(binding, device_metadata)
			resolved_bindings.append(resolve_binding(binding, family, device_metadata).duplicate(true))
		actions.append({
			"action": action,
			"bindings": resolved_bindings,
			"options": profile.get_action_options(action),
		})
	var canonical := JSON.stringify(actions)
	return {
		"valid": true,
		"actions": actions.duplicate(true),
		"fingerprint": canonical.sha256_text(),
		"errors": PackedStringArray(),
	}


static func gamepad_family_from_metadata(metadata: Dictionary) -> StringName:
	var device_class := StringName(str(metadata.get("device_class", "gamepad")).to_lower())
	if device_class != &"gamepad":
		return FAMILY_GAMEPAD_GENERIC
	match str(metadata.get("layout", "generic")).strip_edges().to_lower():
		"xbox": return FAMILY_GAMEPAD_XBOX
		"playstation", "ps": return FAMILY_GAMEPAD_PLAYSTATION
		"nintendo", "switch": return FAMILY_GAMEPAD_NINTENDO
	return FAMILY_GAMEPAD_GENERIC


static func _resolved_gamepad_family(requested: StringName, metadata: Dictionary) -> StringName:
	if GAMEPAD_FAMILIES.has(requested):
		return requested
	return gamepad_family_from_metadata(metadata)


static func _family_for_binding(binding: Dictionary, metadata: Dictionary) -> StringName:
	match StringName(binding.get("device", &"")):
		InputBindingProfile.DEVICE_KEYBOARD: return FAMILY_KEYBOARD
		InputBindingProfile.DEVICE_MOUSE: return FAMILY_MOUSE
		InputBindingProfile.DEVICE_GAMEPAD: return gamepad_family_from_metadata(metadata)
	return FAMILY_KEYBOARD


static func _profile_device_for_family(family: StringName) -> StringName:
	if family == FAMILY_MOUSE:
		return InputBindingProfile.DEVICE_MOUSE
	if GAMEPAD_FAMILIES.has(family):
		return InputBindingProfile.DEVICE_GAMEPAD
	return InputBindingProfile.DEVICE_KEYBOARD


static func _fallback_device_order(preferred: StringName) -> Array[StringName]:
	if preferred == InputBindingProfile.DEVICE_MOUSE:
		return [InputBindingProfile.DEVICE_KEYBOARD, InputBindingProfile.DEVICE_GAMEPAD]
	if preferred == InputBindingProfile.DEVICE_GAMEPAD:
		return [InputBindingProfile.DEVICE_KEYBOARD, InputBindingProfile.DEVICE_MOUSE]
	return [InputBindingProfile.DEVICE_MOUSE, InputBindingProfile.DEVICE_GAMEPAD]


static func _resolve_key(binding: Dictionary) -> Dictionary:
	var code := int(binding.physical_keycode)
	var semantic := ""
	var fallback := ""
	if code >= KEY_A and code <= KEY_Z:
		semantic = char(code).to_lower()
		fallback = char(code)
	elif code >= KEY_0 and code <= KEY_9:
		semantic = char(code)
		fallback = char(code)
	elif _KEY_NAMES.has(code):
		var entry := _KEY_NAMES[code] as Array
		semantic = str(entry[0])
		fallback = str(entry[1])
	else:
		semantic = "physical_%d" % code
		fallback = OS.get_keycode_string(code)
		if fallback.is_empty():
			fallback = "Key %d" % code
	return _result(binding, FAMILY_KEYBOARD, "key.%s" % semantic, "input.key.%s" % semantic, fallback, semantic.begins_with("physical_"))


static func _resolve_mouse(binding: Dictionary) -> Dictionary:
	var button := int(binding.button_index)
	if _MOUSE_NAMES.has(button):
		var entry := _MOUSE_NAMES[button] as Array
		var semantic := str(entry[0])
		return _result(binding, FAMILY_MOUSE, "mouse.%s" % semantic, "input.mouse.%s" % semantic, str(entry[1]), false)
	return _result(binding, FAMILY_MOUSE, "mouse.button_%d" % button, "input.mouse.button", "Mouse Button %d" % button, true)


static func _resolve_joy_button(binding: Dictionary, family: StringName) -> Dictionary:
	var button := int(binding.button_index)
	var entry: Array = []
	if family == FAMILY_GAMEPAD_XBOX and _XBOX_FACE.has(button):
		entry = _XBOX_FACE[button] as Array
	elif family == FAMILY_GAMEPAD_PLAYSTATION and _PLAYSTATION_FACE.has(button):
		entry = _PLAYSTATION_FACE[button] as Array
	elif family == FAMILY_GAMEPAD_NINTENDO and _NINTENDO_FACE.has(button):
		entry = _NINTENDO_FACE[button] as Array
	elif _GENERIC_BUTTONS.has(button):
		entry = _GENERIC_BUTTONS[button] as Array
	if entry.is_empty():
		return _result(binding, FAMILY_GAMEPAD_GENERIC, "gamepad.generic.button_%d" % button, "input.gamepad.button", "Gamepad Button %d" % button, true)
	var semantic := str(entry[0])
	var family_slug := _family_slug(family)
	return _result(binding, family, "gamepad.%s.%s" % [family_slug, semantic], "input.gamepad.%s.%s" % [family_slug, semantic], str(entry[1]), false)


static func _resolve_joy_axis(binding: Dictionary, family: StringName) -> Dictionary:
	var axis := int(binding.axis)
	var positive := float(binding.axis_value) > 0.0
	var semantic := ""
	var fallback := ""
	match axis:
		JOY_AXIS_LEFT_X:
			semantic = "left_stick.%s" % ("right" if positive else "left")
			fallback = "Left Stick %s" % ("Right" if positive else "Left")
		JOY_AXIS_LEFT_Y:
			semantic = "left_stick.%s" % ("down" if positive else "up")
			fallback = "Left Stick %s" % ("Down" if positive else "Up")
		JOY_AXIS_RIGHT_X:
			semantic = "right_stick.%s" % ("right" if positive else "left")
			fallback = "Right Stick %s" % ("Right" if positive else "Left")
		JOY_AXIS_RIGHT_Y:
			semantic = "right_stick.%s" % ("down" if positive else "up")
			fallback = "Right Stick %s" % ("Down" if positive else "Up")
		JOY_AXIS_TRIGGER_LEFT:
			semantic = "left_trigger"
			fallback = _trigger_text(family, true)
		JOY_AXIS_TRIGGER_RIGHT:
			semantic = "right_trigger"
			fallback = _trigger_text(family, false)
		_:
			return _result(binding, FAMILY_GAMEPAD_GENERIC, "gamepad.generic.axis_%d.%s" % [axis, "positive" if positive else "negative"], "input.gamepad.axis", "Gamepad Axis %d %s" % [axis, "+" if positive else "−"], true)
	var family_slug := _family_slug(family)
	return _result(binding, family, "gamepad.%s.%s" % [family_slug, semantic], "input.gamepad.%s.%s" % [family_slug, semantic.replace(".", "_")], fallback, false)


static func _trigger_text(family: StringName, left: bool) -> String:
	if family == FAMILY_GAMEPAD_XBOX:
		return "LT" if left else "RT"
	if family == FAMILY_GAMEPAD_PLAYSTATION:
		return "L2" if left else "R2"
	if family == FAMILY_GAMEPAD_NINTENDO:
		return "ZL" if left else "ZR"
	return "Left Trigger" if left else "Right Trigger"


static func _family_slug(family: StringName) -> String:
	match family:
		FAMILY_GAMEPAD_XBOX: return "xbox"
		FAMILY_GAMEPAD_PLAYSTATION: return "playstation"
		FAMILY_GAMEPAD_NINTENDO: return "nintendo"
	return "generic"


static func _result(
		binding: Dictionary,
		family: StringName,
		token: String,
		localization_key: String,
		fallback_text: String,
		fallback_used: bool
	) -> Dictionary:
	return {
		"valid": true,
		"binding": binding.duplicate(true),
		"device_family": family,
		"glyph_token": StringName(token),
		"localization_key": StringName(localization_key),
		"text": _localized(localization_key, fallback_text),
		"fallback_text": fallback_text,
		"fallback_used": fallback_used,
	}


static func _unknown_result(binding: Dictionary, requested_family: StringName, reason: String) -> Dictionary:
	return {
		"valid": false,
		"binding": binding.duplicate(true),
		"device_family": requested_family,
		"glyph_token": &"input.unknown",
		"localization_key": &"input.unknown",
		"text": _localized("input.unknown", "Unbound Input"),
		"fallback_text": "Unbound Input",
		"fallback_used": true,
		"reason": reason,
	}


static func _localized(key: String, fallback: String) -> String:
	var translated := TranslationServer.translate(key)
	return fallback if translated == key or translated.is_empty() else translated
