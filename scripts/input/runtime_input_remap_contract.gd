class_name RuntimeInputRemapContract
extends RefCounted

## Detached, revisioned runtime remapping seam.
##
## This contract owns neither InputMap nor UI/gameplay.  It makes a complete
## candidate profile before committing, reports every deterministic conflict,
## and requires the caller's revision token so stale menu callbacks cannot
## overwrite a newer remap.

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const RebindService := preload("res://scripts/settings/input_rebind_service.gd")

const CONFLICT_REJECT := RebindService.CONFLICT_REJECT
const CONFLICT_REPLACE := RebindService.CONFLICT_REPLACE
const MAX_REVISION := 9223372036854775807

var _service: InputRebindService
var _profile: InputBindingProfile
var _revision := 0


func _init(defaults: InputBindingProfile, initial: InputBindingProfile = null) -> void:
	if defaults == null:
		return
	_service = RebindService.new(defaults)
	var candidate := initial if initial != null else defaults
	if _service.is_profile_compatible_with_defaults(candidate):
		_profile = candidate.duplicate_profile()


func is_valid() -> bool:
	return _service != null and _profile != null


func get_revision() -> int:
	return _revision


func get_profile() -> InputBindingProfile:
	return _profile.duplicate_profile() if _profile != null else null


## Previews a remap without changing the retained profile or revision.
func preview(action: StringName, candidate: Variant, resolution: StringName = CONFLICT_REJECT) -> Dictionary:
	if not is_valid():
		return _result(false, &"invalid_contract")
	if action.is_empty() or not _profile.bindings.has(action) or InputBindingProfile.normalize_binding(candidate).is_empty():
		return _result(false, &"invalid_request")
	if resolution != CONFLICT_REJECT and resolution != CONFLICT_REPLACE:
		return _result(false, &"invalid_request")
	var proposed := _service.rebind(_profile, action, candidate, resolution)
	if not bool(proposed.get("ok", false)):
		var conflicts: Array[Dictionary] = proposed.get("conflicts", [])
		return _result(false, &"conflict", {"conflicts": conflicts}) if not conflicts.is_empty() else _result(false, &"invalid_request")
	var next := proposed.get("profile") as InputBindingProfile
	if next == null or not _service.is_profile_compatible_with_defaults(next):
		return _result(false, &"profile_incompatible")
	return _result(true, &"preview", {"profile": next.duplicate_profile(), "conflicts": proposed.get("conflicts", [])})


## Commits one preview-equivalent remap only at the caller's exact revision.
func commit(action: StringName, candidate: Variant, expected_revision: int, resolution: StringName = CONFLICT_REJECT) -> Dictionary:
	if not is_valid():
		return _result(false, &"invalid_contract")
	if expected_revision != _revision:
		return _result(false, &"stale_revision")
	if _revision == MAX_REVISION:
		return _result(false, &"revision_exhausted")
	var proposed := preview(action, candidate, resolution)
	if not bool(proposed.accepted):
		return proposed
	_profile = (proposed.profile as InputBindingProfile).duplicate_profile()
	_revision += 1
	return _result(true, &"committed", {"profile": get_profile(), "conflicts": proposed.conflicts})


func reset(expected_revision: int) -> Dictionary:
	if not is_valid():
		return _result(false, &"invalid_contract")
	if expected_revision != _revision:
		return _result(false, &"stale_revision")
	if _revision == MAX_REVISION:
		return _result(false, &"revision_exhausted")
	_profile = _service.reset_to_defaults()
	_revision += 1
	return _result(true, &"reset", {"profile": get_profile()})


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason, "revision": _revision}
	for key: Variant in extra:
		result[key] = extra[key]
	return result
