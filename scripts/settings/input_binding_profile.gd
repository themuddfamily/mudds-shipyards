class_name InputBindingProfile
extends Resource

## Versioned, side-effect-free input binding data.
##
## The profile deliberately stores portable binding descriptors rather than live
## InputEvent instances. This makes validation deterministic, persistence-ready,
## and prevents menu code from altering the engine InputMap by accident.

const SCHEMA_VERSION := 1
const MINIMUM_SUPPORTED_SCHEMA_VERSION := 1

const DEVICE_KEYBOARD := &"keyboard"
const DEVICE_MOUSE := &"mouse"
const DEVICE_GAMEPAD := &"gamepad"

const CURVE_LINEAR := &"linear"
const CURVE_SQUARED := &"squared"
const HOLD := &"hold"
const TOGGLE := &"toggle"

const _VALID_DEVICES := [DEVICE_KEYBOARD, DEVICE_MOUSE, DEVICE_GAMEPAD]
const _VALID_CURVES := [CURVE_LINEAR, CURVE_SQUARED]
const _VALID_HOLD_MODES := [HOLD, TOGGLE]

var schema_version: int = SCHEMA_VERSION
var bindings: Dictionary = {}
var action_options: Dictionary = {}


static func from_dictionary(source: Variant) -> InputBindingProfile:
	if not source is Dictionary:
		return null
	var raw := source as Dictionary
	if not raw.has("schema_version") or not raw.has("bindings") or not raw.has("action_options"):
		return null
	if not raw.schema_version is int:
		return null
	var version := int(raw.schema_version)
	if version < MINIMUM_SUPPORTED_SCHEMA_VERSION or version > SCHEMA_VERSION:
		return null
	if not raw.bindings is Dictionary or not raw.action_options is Dictionary:
		return null
	var profile := InputBindingProfile.new()
	profile.schema_version = version
	for raw_action: Variant in (raw.bindings as Dictionary):
		if not raw_action is StringName and not raw_action is String:
			return null
		var action := StringName(raw_action)
		if action.is_empty() or not (raw.bindings as Dictionary)[raw_action] is Array:
			return null
		var action_bindings: Array[Dictionary] = []
		for candidate: Variant in ((raw.bindings as Dictionary)[raw_action] as Array):
			var binding := normalize_binding(candidate)
			if binding.is_empty():
				return null
			action_bindings.append(binding)
		profile.bindings[action] = action_bindings
	for raw_action: Variant in (raw.action_options as Dictionary):
		if not raw_action is StringName and not raw_action is String:
			return null
		var action := StringName(raw_action)
		if action.is_empty():
			return null
		var options := normalize_action_options((raw.action_options as Dictionary)[raw_action])
		if options.is_empty():
			return null
		profile.action_options[action] = options
	for action: StringName in profile.bindings:
		if not profile.action_options.has(action):
			profile.action_options[action] = default_action_options()
	return profile


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"bindings": bindings.duplicate(true),
		"action_options": action_options.duplicate(true),
	}


func duplicate_profile() -> InputBindingProfile:
	return InputBindingProfile.from_dictionary(to_dictionary())


func get_bindings(action: StringName) -> Array[Dictionary]:
	if not bindings.has(action):
		return []
	return (bindings[action] as Array).duplicate(true)


func get_action_options(action: StringName) -> Dictionary:
	if not action_options.has(action):
		return {}
	return (action_options[action] as Dictionary).duplicate(true)


func set_bindings(action: StringName, candidates: Variant) -> bool:
	if action.is_empty() or not candidates is Array:
		return false
	var normalized: Array[Dictionary] = []
	for candidate: Variant in candidates as Array:
		var binding := normalize_binding(candidate)
		if binding.is_empty():
			return false
		normalized.append(binding)
	bindings[action] = normalized
	if not action_options.has(action):
		action_options[action] = default_action_options()
	return true


func set_action_options(action: StringName, candidate: Variant) -> bool:
	if action.is_empty():
		return false
	var normalized := normalize_action_options(candidate)
	if normalized.is_empty():
		return false
	action_options[action] = normalized
	if not bindings.has(action):
		bindings[action] = []
	return true


static func default_action_options() -> Dictionary:
	return {"deadzone": 0.18, "curve": CURVE_LINEAR, "hold_mode": HOLD}


static func normalize_action_options(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return {}
	var raw := candidate as Dictionary
	if not raw.has("deadzone") or not raw.has("curve") or not raw.has("hold_mode"):
		return {}
	if not raw.deadzone is float and not raw.deadzone is int:
		return {}
	var deadzone := float(raw.deadzone)
	if is_nan(deadzone) or is_inf(deadzone) or deadzone < 0.0 or deadzone > 1.0:
		return {}
	var curve := StringName(raw.curve)
	var hold_mode := StringName(raw.hold_mode)
	if not curve in _VALID_CURVES or not hold_mode in _VALID_HOLD_MODES:
		return {}
	return {"deadzone": deadzone, "curve": curve, "hold_mode": hold_mode}


static func normalize_binding(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return {}
	var raw := candidate as Dictionary
	if not raw.has("device") or not raw.has("type"):
		return {}
	var device := StringName(raw.device)
	var type := StringName(raw.type)
	if not device in _VALID_DEVICES:
		return {}
	match type:
		&"key":
			if device != DEVICE_KEYBOARD or not raw.has("physical_keycode") or not raw.physical_keycode is int or int(raw.physical_keycode) <= 0:
				return {}
			return {"device": device, "type": type, "physical_keycode": int(raw.physical_keycode)}
		&"mouse_button":
			if device != DEVICE_MOUSE or not raw.has("button_index") or not raw.button_index is int or int(raw.button_index) <= 0:
				return {}
			return {"device": device, "type": type, "button_index": int(raw.button_index)}
		&"joy_button":
			if device != DEVICE_GAMEPAD or not raw.has("button_index") or not raw.button_index is int or int(raw.button_index) < 0:
				return {}
			return {"device": device, "type": type, "button_index": int(raw.button_index)}
		&"joy_motion":
			if device != DEVICE_GAMEPAD or not raw.has("axis") or not raw.has("axis_value") or not raw.axis is int:
				return {}
			var axis_value := float(raw.axis_value)
			if int(raw.axis) < 0 or (not is_equal_approx(axis_value, -1.0) and not is_equal_approx(axis_value, 1.0)):
				return {}
			return {"device": device, "type": type, "axis": int(raw.axis), "axis_value": axis_value}
	return {}
