class_name InputRebindService
extends RefCounted

## Explicit runtime adapter for InputBindingProfile. Nothing invokes this
## service automatically; gameplay retains the project's existing InputMap
## until a future settings owner opts in.

const CONFLICT_REJECT := &"reject"
const CONFLICT_REPLACE := &"replace"

var _defaults: InputBindingProfile


func _init(defaults: InputBindingProfile = null) -> void:
	_defaults = (
		defaults.duplicate_profile()
		if defaults != null
		else capture_input_map(_get_project_actions())
	)


func get_defaults() -> InputBindingProfile:
	return _defaults.duplicate_profile()


func reset_to_defaults() -> InputBindingProfile:
	return get_defaults()


## A persisted settings profile must describe the same action inventory captured
## from the project. This prevents a damaged file from silently deleting whole
## actions or injecting arbitrary ones. Authored cross-action overlaps (for
## example the context-dependent A button shared by jump and hover) remain
## valid, while a new overlap introduced by corrupted/manual data does not.
func is_profile_compatible_with_defaults(profile: InputBindingProfile) -> bool:
	var validated := _validated_copy(profile)
	if validated == null:
		return false
	if _sorted_actions(validated.bindings) != _sorted_actions(_defaults.bindings):
		return false
	if _sorted_actions(validated.action_options) != _sorted_actions(_defaults.action_options):
		return false
	return _has_only_authored_conflicts(validated)


func capture_input_map(actions: PackedStringArray = PackedStringArray()) -> InputBindingProfile:
	var raw_bindings := {}
	var raw_options := {}
	var selected: Array[StringName] = []
	if actions.is_empty():
		for action: StringName in _get_project_actions():
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
		# InputMap stores this as a 32-bit float. Canonicalizing its harmless
		# promotion noise (0.18 -> 0.180000007...) keeps ConfigFile round-trips
		# byte-stable without changing any meaningful controller calibration.
		var deadzone := snappedf(InputMap.action_get_deadzone(action), 0.000001)
		raw_options[action] = {"deadzone": deadzone, "curve": InputBindingProfile.CURVE_LINEAR, "hold_mode": InputBindingProfile.HOLD}
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
	var validated := _validated_copy(profile)
	if validated == null:
		return false

	# Build every event before touching InputMap. Normal schema validation should
	# make conversion infallible, but keeping mutation behind a complete plan is
	# what makes the adapter atomic if a future descriptor type is added to one
	# side before the other.
	var actions := _sorted_actions(validated.bindings)
	var apply_plan: Array[Dictionary] = []
	for action: StringName in actions:
		var events: Array[InputEvent] = []
		for binding: Dictionary in validated.get_bindings(action):
			var event := binding_to_event(binding)
			if event == null:
				return false
			events.append(event)
		apply_plan.append({
			"action": action,
			"deadzone": float(validated.get_action_options(action).deadzone),
			"events": events,
		})

	for entry: Dictionary in apply_plan:
		var action: StringName = entry.action
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action, float(entry.deadzone))
		for event: InputEvent in entry.events:
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


func _has_only_authored_conflicts(profile: InputBindingProfile) -> bool:
	var defaults_by_signature := _actions_by_signature(_defaults)
	var candidate_by_signature := _actions_by_signature(profile)
	for signature: String in candidate_by_signature:
		var candidate_actions: PackedStringArray = candidate_by_signature[signature]
		if signature.begins_with("duplicate:"):
			return false
		if candidate_actions.size() < 2:
			continue
		if (
			not defaults_by_signature.has(signature)
			or defaults_by_signature[signature] != candidate_actions
		):
			return false
	return true


static func _actions_by_signature(profile: InputBindingProfile) -> Dictionary:
	var result := {}
	for action: StringName in _sorted_actions(profile.bindings):
		var seen_for_action := {}
		for binding: Dictionary in profile.get_bindings(action):
			var signature := binding_signature(binding)
			if signature.is_empty() or seen_for_action.has(signature):
				# A duplicate within one action is always malformed. Represent it as
				# a collision that cannot match a captured default signature group.
				result["duplicate:%s:%s" % [action, signature]] = PackedStringArray([
					String(action), String(action)
				])
				continue
			seen_for_action[signature] = true
			if not result.has(signature):
				result[signature] = PackedStringArray()
			var signature_actions: PackedStringArray = result[signature]
			signature_actions.append(String(action))
			result[signature] = signature_actions
	return result


static func _sorted_actions(source: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for action: Variant in source:
		result.append(String(action))
	result.sort()
	return result


static func _get_project_actions() -> PackedStringArray:
	var actions := PackedStringArray()
	for action: StringName in InputMap.get_actions():
		# Godot registers its built-in `ui_*` fallback actions in
		# ProjectSettings too. They are engine navigation policy, not this game's
		# authored remap inventory, and capturing our portable subset would erase
		# their logical-key events on apply.
		if (
			not String(action).begins_with("ui_")
			and ProjectSettings.has_setting("input/%s" % action)
		):
			actions.append(String(action))
	actions.sort()
	return actions


static func _validated_copy(profile: InputBindingProfile) -> InputBindingProfile:
	if profile == null:
		return null
	return InputBindingProfile.from_dictionary(profile.to_dictionary())
