class_name InputRebindService
extends RefCounted

## Explicit runtime adapter for InputBindingProfile. Nothing invokes this
## service automatically; gameplay retains the project's existing InputMap
## until a future settings owner opts in.

const CONFLICT_REJECT := &"reject"
const CONFLICT_REPLACE := &"replace"

var _defaults: InputBindingProfile


func _init(defaults: InputBindingProfile = null) -> void:
	_defaults = defaults.duplicate_profile() if defaults != null else capture_input_map()


func get_defaults() -> InputBindingProfile:
	return _defaults.duplicate_profile()


func reset_to_defaults() -> InputBindingProfile:
	return get_defaults()


func capture_input_map(actions: PackedStringArray = PackedStringArray()) -> InputBindingProfile:
	var raw_bindings := {}
	var raw_options := {}
	var selected: Array[StringName] = []
	if actions.is_empty():
		for action: StringName in InputMap.get_actions():
			selected.append(action)
	else:
		for action: StringName in actions:
			selected.append(action)
	selected.sort()
	for action: StringName in selected:
		if not InputMap.has_action(action):
			continue
		var descriptors: Array[Dictionary] = []
		for event: InputEvent in InputMap.action_get_events(action):
			var descriptor := event_to_binding(event)
			if not descriptor.is_empty():
				descriptors.append(descriptor)
		raw_bindings[action] = descriptors
		raw_options[action] = {"deadzone": InputMap.action_get_deadzone(action), "curve": InputBindingProfile.CURVE_LINEAR, "hold_mode": InputBindingProfile.HOLD}
	return InputBindingProfile.from_dictionary({"schema_version": InputBindingProfile.SCHEMA_VERSION, "bindings": raw_bindings, "action_options": raw_options})


func find_conflicts(profile: InputBindingProfile, action: StringName, candidate: Variant) -> Array[Dictionary]:
	var binding := InputBindingProfile.normalize_binding(candidate)
	if profile == null or action.is_empty() or binding.is_empty():
		return []
	var conflicts: Array[Dictionary] = []
	var actions: Array[StringName] = []
	for mapped_action: StringName in profile.bindings:
		actions.append(mapped_action)
	actions.sort()
	for mapped_action: StringName in actions:
		if mapped_action == action:
			continue
		var index := 0
		for existing: Dictionary in profile.get_bindings(mapped_action):
			if binding_signature(existing) == binding_signature(binding):
				conflicts.append({"action": mapped_action, "binding_index": index, "binding": existing})
			index += 1
	return conflicts


## Replaces or rejects a conflicting binding without partially mutating profile.
func rebind(profile: InputBindingProfile, action: StringName, candidate: Variant, resolution: StringName = CONFLICT_REJECT) -> Dictionary:
	var binding := InputBindingProfile.normalize_binding(candidate)
	if profile == null or action.is_empty() or binding.is_empty() or (resolution != CONFLICT_REJECT and resolution != CONFLICT_REPLACE):
		return {"ok": false, "profile": profile, "conflicts": []}
	var conflicts := find_conflicts(profile, action, binding)
	if not conflicts.is_empty() and resolution == CONFLICT_REJECT:
		return {"ok": false, "profile": profile, "conflicts": conflicts}
	var updated := profile.duplicate_profile()
	if not conflicts.is_empty():
		for conflict: Dictionary in conflicts:
			var remaining: Array[Dictionary] = []
			for existing: Dictionary in updated.get_bindings(conflict.action):
				if binding_signature(existing) != binding_signature(binding):
					remaining.append(existing)
			updated.set_bindings(conflict.action, remaining)
	var action_bindings := updated.get_bindings(action)
	if not _has_binding(action_bindings, binding):
		action_bindings.append(binding)
	updated.set_bindings(action, action_bindings)
	return {"ok": true, "profile": updated, "conflicts": conflicts}


func apply_profile(profile: InputBindingProfile) -> bool:
	if profile == null or InputBindingProfile.from_dictionary(profile.to_dictionary()) == null:
		return false
	var actions: Array[StringName] = []
	for action: StringName in profile.bindings:
		actions.append(action)
	actions.sort()
	for action: StringName in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var options := profile.get_action_options(action)
		InputMap.action_set_deadzone(action, float(options.deadzone))
		for binding: Dictionary in profile.get_bindings(action):
			var event := binding_to_event(binding)
			if event == null:
				return false
			InputMap.action_add_event(action, event)
	return true


static func binding_signature(candidate: Variant) -> String:
	var binding := InputBindingProfile.normalize_binding(candidate)
	if binding.is_empty():
		return ""
	match binding.type:
		&"key": return "%s:key:%d" % [binding.device, binding.physical_keycode]
		&"mouse_button", &"joy_button": return "%s:%s:%d" % [binding.device, binding.type, binding.button_index]
		&"joy_motion": return "%s:joy_motion:%d:%+.1f" % [binding.device, binding.axis, binding.axis_value]
	return ""


static func event_to_binding(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode > 0:
			return {"device": InputBindingProfile.DEVICE_KEYBOARD, "type": &"key", "physical_keycode": key.physical_keycode}
	elif event is InputEventMouseButton:
		return {"device": InputBindingProfile.DEVICE_MOUSE, "type": &"mouse_button", "button_index": (event as InputEventMouseButton).button_index}
	elif event is InputEventJoypadButton:
		return {"device": InputBindingProfile.DEVICE_GAMEPAD, "type": &"joy_button", "button_index": (event as InputEventJoypadButton).button_index}
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if is_equal_approx(absf(motion.axis_value), 1.0):
			return {"device": InputBindingProfile.DEVICE_GAMEPAD, "type": &"joy_motion", "axis": motion.axis, "axis_value": signf(motion.axis_value)}
	return {}


static func binding_to_event(candidate: Variant) -> InputEvent:
	var binding := InputBindingProfile.normalize_binding(candidate)
	if binding.is_empty():
		return null
	match binding.type:
		&"key":
			var key := InputEventKey.new()
			key.physical_keycode = binding.physical_keycode
			return key
		&"mouse_button":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = binding.button_index
			return mouse
		&"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = binding.button_index
			return button
		&"joy_motion":
			var motion := InputEventJoypadMotion.new()
			motion.axis = binding.axis
			motion.axis_value = binding.axis_value
			return motion
	return null


static func _has_binding(bindings: Array[Dictionary], candidate: Dictionary) -> bool:
	var signature := binding_signature(candidate)
	for existing: Dictionary in bindings:
		if binding_signature(existing) == signature:
			return true
	return false
