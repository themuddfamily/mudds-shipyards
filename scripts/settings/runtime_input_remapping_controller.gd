class_name RuntimeInputRemappingController
extends RefCounted

## Runtime owner for the detached remap/option contracts.
##
## Previews never touch InputMap. A successful commit applies the complete
## validated profile atomically through InputRebindService and retains the
## shared revision guard. The controller family is descriptive metadata for
## glyph/UI callers; it does not alter binding semantics.

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const RebindService := preload("res://scripts/settings/input_rebind_service.gd")
const Contract := preload("res://scripts/input/input_curve_hold_remap_contract.gd")

signal profile_changed(result: Dictionary)
signal conflict_detected(result: Dictionary)

const CONFLICT_REJECT := Contract.CONFLICT_REJECT
const CONFLICT_REPLACE := Contract.CONFLICT_REPLACE
const CONTROLLER_UNKNOWN := &"unknown"

var _service: InputRebindService
var _contract: InputCurveHoldRemapContract
var _controller_family: StringName = CONTROLLER_UNKNOWN


func _init(
	defaults: InputBindingProfile,
	initial: InputBindingProfile = null,
	controller_family: StringName = CONTROLLER_UNKNOWN
	) -> void:
	_controller_family = controller_family if not controller_family.is_empty() else CONTROLLER_UNKNOWN
	if defaults == null:
		return
	_service = RebindService.new(defaults)
	_contract = Contract.new(defaults, initial)
	if not _contract.is_valid():
		_service = null


func is_valid() -> bool:
	return _contract != null and _contract.is_valid() and _service != null


func get_controller_family() -> StringName:
	return _controller_family


func get_revision() -> int:
	return _contract.get_revision() if _contract != null else 0


func get_profile() -> InputBindingProfile:
	return _contract.get_profile() if _contract != null else null


func preview_binding(action: StringName, candidate: Variant, resolution: StringName = Contract.CONFLICT_REJECT) -> Dictionary:
	var result := _contract.preview_binding(action, candidate, resolution) if _contract != null else _invalid()
	if result.reason == &"conflict":
		conflict_detected.emit(_decorate(result))
	return _decorate(result)


func commit_binding(action: StringName, candidate: Variant, expected_revision: int, resolution: StringName = Contract.CONFLICT_REJECT) -> Dictionary:
	if not is_valid() or expected_revision != get_revision():
		return _decorate({"accepted": false, "reason": &"stale_revision" if is_valid() else &"invalid_contract", "revision": get_revision()})
	return _commit_preview(
		_contract.preview_binding(action, candidate, resolution) if _contract != null else _invalid(),
		func() -> Dictionary: return _contract.commit_binding(action, candidate, expected_revision, resolution)
	)


func preview_options(action: StringName, deadzone: Variant, curve: StringName, hold_mode: StringName) -> Dictionary:
	var result := _contract.preview_options(action, deadzone, curve, hold_mode) if _contract != null else _invalid()
	return _decorate(result)


func commit_options(action: StringName, deadzone: Variant, curve: StringName, hold_mode: StringName, expected_revision: int) -> Dictionary:
	if not is_valid() or expected_revision != get_revision():
		return _decorate({"accepted": false, "reason": &"stale_revision" if is_valid() else &"invalid_contract", "revision": get_revision()})
	return _commit_preview(
		_contract.preview_options(action, deadzone, curve, hold_mode) if _contract != null else _invalid(),
		func() -> Dictionary: return _contract.commit_options(action, deadzone, curve, hold_mode, expected_revision)
	)


func reset(expected_revision: int) -> Dictionary:
	if not is_valid() or expected_revision != get_revision():
		return _decorate({"accepted": false, "reason": &"stale_revision" if is_valid() else &"invalid_contract", "revision": get_revision()})
	var before := get_profile()
	var result := _contract.reset(expected_revision)
	if not bool(result.get("accepted", false)):
		return _decorate(result)
	if not _service.apply_profile(result.profile):
		_contract = Contract.new(_service.get_defaults(), before)
		return _decorate({"accepted": false, "reason": &"apply_failed", "revision": get_revision()})
	var decorated := _decorate(result)
	profile_changed.emit(decorated)
	return decorated


func _commit_preview(preview: Dictionary, commit: Callable) -> Dictionary:
	var decorated_preview := _decorate(preview)
	if not bool(preview.get("accepted", false)):
		if preview.get("reason") == &"conflict":
			conflict_detected.emit(decorated_preview)
		return decorated_preview
	var before := get_profile()
	if not _service.apply_profile(preview.profile):
		return _decorate({"accepted": false, "reason": &"apply_failed", "revision": get_revision()})
	var result: Dictionary = commit.call()
	if not bool(result.get("accepted", false)):
		_service.apply_profile(before)
		return _decorate(result)
	var decorated := _decorate(result)
	profile_changed.emit(decorated)
	return decorated


func _decorate(result: Dictionary) -> Dictionary:
	var decorated := result.duplicate(true)
	decorated["controller_family"] = _controller_family
	return decorated


func _invalid() -> Dictionary:
	return {"accepted": false, "reason": &"invalid_contract", "revision": get_revision()}
