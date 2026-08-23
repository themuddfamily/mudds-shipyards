class_name RuntimeInputRebindPresenter
extends RefCounted

## Detached settings presentation for input rebinding.  It prepares profiles
## and intents for a caller-owned settings service; it never mutates InputMap
## or persists a profile itself.

const RebindService := preload("res://scripts/settings/input_rebind_service.gd")
const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Resolver := preload("res://scripts/ui/input_glyph_resolver.gd")

const SCHEMA_VERSION := 1
const CONFLICT_REJECT := &"reject"
const CONFLICT_REPLACE := &"replace"

var _service: InputRebindService
var _resolver: InputGlyphResolver
var _profile: InputBindingProfile
var _attached := false
var _generation := 0
var _capture_action: StringName = &""
var _capture_generation := -1
var _pending_conflict: Dictionary = {}
var _status: StringName = &"detached"


func _init(service: InputRebindService = null, resolver: InputGlyphResolver = null) -> void:
	_service = service if service != null else RebindService.new()
	_resolver = resolver if resolver != null else Resolver.new()


func attach(profile: InputBindingProfile) -> Dictionary:
	if profile == null or not _service.is_profile_compatible_with_defaults(profile):
		return _reject(&"invalid_profile")
	_profile = profile.duplicate_profile()
	_attached = true
	_generation += 1
	_clear_capture()
	_status = &"ready"
	return get_snapshot()


func detach() -> Dictionary:
	_profile = null
	_attached = false
	_generation += 1
	_clear_capture()
	_status = &"detached"
	return get_snapshot()


func set_device_family(family: StringName) -> Dictionary:
	if not _resolver.set_explicit_device_family_override(family):
		return _reject(&"invalid_device_family")
	return get_snapshot()


func clear_device_family_override() -> Dictionary:
	_resolver.clear_explicit_device_family_override()
	return get_snapshot()


func begin_capture(action: StringName, expected_generation: int = -1) -> Dictionary:
	var rejected := _validate_request(action, expected_generation)
	if not rejected.is_empty():
		return rejected
	_capture_action = action
	_capture_generation = _generation
	_pending_conflict = {}
	_status = &"capturing"
	return _result(true, &"capture_requested")


func capture_replacement(action: StringName, candidate: Variant, expected_generation: int, resolution: StringName = CONFLICT_REJECT) -> Dictionary:
	var rejected := _validate_request(action, expected_generation)
	if not rejected.is_empty():
		return rejected
	if _capture_action != action or _capture_generation != _generation:
		return _reject(&"no_active_capture")
	var binding := Profile.normalize_binding(candidate)
	if binding.is_empty():
		return _reject(&"invalid_binding")
	if resolution != CONFLICT_REJECT and resolution != CONFLICT_REPLACE:
		return _reject(&"invalid_conflict_resolution")
	var outcome := _service.rebind(_profile, action, binding, resolution)
	if not bool(outcome.get("ok", false)):
		var conflicts: Array[Dictionary] = outcome.get("conflicts", [])
		if not conflicts.is_empty():
			_pending_conflict = {"action": action, "binding": binding, "conflicts": conflicts, "generation": _generation}
			_status = &"conflict"
			return _result(false, &"conflict", {"conflicts": conflicts, "choices": _conflict_choices()})
		return _reject(&"rebind_failed")
	_profile = outcome.profile
	_clear_capture()
	_status = &"applied"
	return _result(true, &"profile_changed", {"profile": _profile.to_dictionary()})


func resolve_conflict(choice: StringName, expected_generation: int) -> Dictionary:
	if not _attached or expected_generation != _generation:
		return _reject(&"stale_generation")
	if _pending_conflict.is_empty():
		return _reject(&"no_pending_conflict")
	if choice == &"cancel":
		_clear_capture()
		_status = &"ready"
		return _result(true, &"conflict_cancelled")
	if choice != CONFLICT_REPLACE:
		return _reject(&"invalid_conflict_choice")
	return capture_replacement(_pending_conflict.action, _pending_conflict.binding, _generation, CONFLICT_REPLACE)


func reset_action(action: StringName, expected_generation: int = -1) -> Dictionary:
	var rejected := _validate_request(action, expected_generation)
	if not rejected.is_empty():
		return rejected
	var updated := _service.reset_action_to_defaults(_profile, action)
	if updated == null:
		return _reject(&"reset_failed")
	_profile = updated
	_clear_capture()
	_status = &"reset"
	return _result(true, &"profile_changed", {"profile": _profile.to_dictionary()})


func reset(expected_generation: int = -1) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	if expected_generation >= 0 and expected_generation != _generation:
		return _reject(&"stale_generation")
	_profile = _service.reset_to_defaults()
	_clear_capture()
	_status = &"reset"
	return _result(true, &"profile_changed", {"profile": _profile.to_dictionary()})


func get_snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	if _attached and _profile != null:
		var actions: Array[StringName] = []
		for action: StringName in _profile.bindings:
			actions.append(action)
		actions.sort()
		for action: StringName in actions:
			var resolved := _resolver.resolve_action(_profile, action)
			rows.append({"action": action, "label": _label(action), "bindings": _profile.get_bindings(action), "text": str(resolved.get("text", "Unbound Input")), "glyph_token": resolved.get("glyph_token", &"input.unknown"), "valid": bool(resolved.get("valid", false)), "device_family": resolved.get("device_family", &"unknown")})
	var pending := _pending_conflict.duplicate(true)
	if not pending.is_empty():
		pending["choices"] = _conflict_choices()
	return {"schema_version": SCHEMA_VERSION, "attached": _attached, "generation": _generation, "status": _status, "capture_action": _capture_action, "capture_generation": _capture_generation, "pending_conflict": pending, "rows": rows, "profile": _profile.to_dictionary() if _profile != null else {}, "device_family": _resolver.get_preferred_device_family(), "presentation_only": true, "input_authority": false, "persistence_owned_by_caller": true}.duplicate(true)


func _validate_request(action: StringName, expected_generation: int) -> Dictionary:
	if not _attached or _profile == null:
		return _reject(&"detached")
	if expected_generation >= 0 and expected_generation != _generation:
		return _reject(&"stale_generation")
	if action.is_empty() or not _profile.bindings.has(action):
		return _reject(&"unknown_action")
	return {}


func _conflict_choices() -> Array[Dictionary]:
	return [{"id": CONFLICT_REPLACE, "label": "Replace conflicting binding"}, {"id": &"cancel", "label": "Cancel"}]


func _clear_capture() -> void:
	_capture_action = &""
	_capture_generation = -1
	_pending_conflict = {}


func _result(accepted: bool, intent: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "intent": intent, "generation": _generation, "presentation_only": true, "input_authority": false}
	for key: Variant in extra:
		result[key] = extra[key]
	result["snapshot"] = get_snapshot()
	return result


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true, "input_authority": false}


func _label(action: StringName) -> String:
	return String(action).replace("_", " ").capitalize()
