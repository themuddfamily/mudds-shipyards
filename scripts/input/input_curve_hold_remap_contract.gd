class_name InputCurveHoldRemapContract
extends RefCounted

## Detached, revisioned input-option/remap transaction seam.
##
## This is deliberately a menu-facing data contract: it owns neither InputMap
## nor runtime sampling.  Binding and deadzone/curve/hold-toggle changes share
## one revision token so a stale settings callback cannot commit half of an
## input profile.

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const RebindService := preload("res://scripts/settings/input_rebind_service.gd")

const CONFLICT_REJECT := RebindService.CONFLICT_REJECT
const CONFLICT_REPLACE := RebindService.CONFLICT_REPLACE
const MAX_REVISION := 9223372036854775807

var _defaults: InputBindingProfile
var _profile: InputBindingProfile
var _service: InputRebindService
var _revision := 0


func _init(defaults: InputBindingProfile, initial: InputBindingProfile = null) -> void:
	if defaults == null:
		return
	_defaults = defaults.duplicate_profile()
	_service = RebindService.new(_defaults)
	var candidate := initial if initial != null else _defaults
	if _service.is_profile_compatible_with_defaults(candidate):
		_profile = candidate.duplicate_profile()


func is_valid() -> bool:
	return _defaults != null and _profile != null and _service != null


func get_revision() -> int:
	return _revision


func get_profile() -> InputBindingProfile:
	return _profile.duplicate_profile() if _profile != null else null


func preview_options(action: StringName, deadzone: Variant, curve: Variant, hold_mode: Variant) -> Dictionary:
	if not is_valid() or action.is_empty() or not _profile.bindings.has(action):
		return _result(false, &"invalid_request")
	var options := Profile.normalize_action_options({
		"deadzone": deadzone,
		"curve": curve,
		"hold_mode": hold_mode,
	})
	if options.is_empty():
		return _result(false, &"invalid_options")
	var candidate := _profile.duplicate_profile()
	if not candidate.set_action_options(action, options):
		return _result(false, &"invalid_options")
	return _result(true, &"preview", {"profile": candidate, "options": options})


func commit_options(action: StringName, deadzone: Variant, curve: Variant, hold_mode: Variant, expected_revision: int) -> Dictionary:
	if not is_valid():
		return _result(false, &"invalid_contract")
	if expected_revision != _revision:
		return _result(false, &"stale_revision")
	if _revision == MAX_REVISION:
		return _result(false, &"revision_exhausted")
	var preview_result := preview_options(action, deadzone, curve, hold_mode)
	if not bool(preview_result.accepted):
		return preview_result
	_profile = (preview_result.profile as InputBindingProfile).duplicate_profile()
	_revision += 1
	return _result(true, &"committed", {"profile": get_profile(), "options": preview_result.options})


func preview_binding(action: StringName, candidate_binding: Variant, resolution: StringName = CONFLICT_REJECT) -> Dictionary:
	if not is_valid() or action.is_empty() or not _profile.bindings.has(action):
		return _result(false, &"invalid_request")
	if resolution != CONFLICT_REJECT and resolution != CONFLICT_REPLACE:
		return _result(false, &"invalid_request")
	if Profile.normalize_binding(candidate_binding).is_empty():
		return _result(false, &"invalid_request")
	var proposed := _service.rebind(_profile, action, candidate_binding, resolution)
	if not bool(proposed.get("ok", false)):
		var conflicts: Array[Dictionary] = proposed.get("conflicts", [])
		return _result(false, &"conflict", {"conflicts": conflicts}) if not conflicts.is_empty() else _result(false, &"invalid_request")
	var next := proposed.get("profile") as InputBindingProfile
	if next == null or not _service.is_profile_compatible_with_defaults(next):
		return _result(false, &"profile_incompatible")
	return _result(true, &"preview", {"profile": next.duplicate_profile(), "conflicts": proposed.get("conflicts", [])})


func commit_binding(action: StringName, candidate_binding: Variant, expected_revision: int, resolution: StringName = CONFLICT_REJECT) -> Dictionary:
	if not is_valid():
		return _result(false, &"invalid_contract")
	if expected_revision != _revision:
		return _result(false, &"stale_revision")
	if _revision == MAX_REVISION:
		return _result(false, &"revision_exhausted")
	var preview_result := preview_binding(action, candidate_binding, resolution)
	if not bool(preview_result.accepted):
		return preview_result
	_profile = (preview_result.profile as InputBindingProfile).duplicate_profile()
	_revision += 1
	return _result(true, &"committed", {"profile": get_profile(), "conflicts": preview_result.conflicts})


func reset(expected_revision: int) -> Dictionary:
	if not is_valid():
		return _result(false, &"invalid_contract")
	if expected_revision != _revision:
		return _result(false, &"stale_revision")
	if _revision == MAX_REVISION:
		return _result(false, &"revision_exhausted")
	_profile = _defaults.duplicate_profile()
	_revision += 1
	return _result(true, &"reset", {"profile": get_profile()})


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason, "revision": _revision}
	for key: Variant in extra:
		result[key] = extra[key]
	return result
