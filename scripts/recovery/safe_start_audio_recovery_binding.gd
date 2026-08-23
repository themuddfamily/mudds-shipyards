class_name SafeStartAudioRecoveryBinding
extends RefCounted

## Caller-owned adapter for the bounded SafeStart audio fallback.
##
## This object owns no RuntimeSettings, store, or playback authority. It only
## fences calls into SafeStartProductionRecovery and retains detached results so
## a caller can safely detach/re-enter without replaying a recovery choice.

const Recovery := preload("res://scripts/recovery/safe_start_production_recovery.gd")

var _recovery: SafeStartProductionRecovery
var _persist_settings := Callable()
var _expected_startup_generation := -1
var _attached := true
var _last_status: Dictionary = {}


func configure(
		recovery: SafeStartProductionRecovery,
		persist_settings: Callable,
		expected_startup_generation: int
	) -> Dictionary:
	if recovery == null or not persist_settings.is_valid() or expected_startup_generation <= 0:
		return _status(false, &"invalid_configuration")
	_recovery = recovery
	_persist_settings = persist_settings
	_expected_startup_generation = expected_startup_generation
	_attached = true
	_last_status = _status(true, &"configured")
	return _last_status.duplicate(true)


func set_attached(attached: bool) -> void:
	_attached = attached


func is_attached() -> bool:
	return _attached


func get_recommendation() -> Dictionary:
	if not _ready_for_call():
		return _status(false, &"binding_unavailable")
	var report := _recovery.get_report()
	var snapshot := report.get("policy_snapshot", {}) as Dictionary
	if not bool(snapshot.get("recommendation_available", false)):
		return _status(false, &"audio_fallback_not_recommended")
	return _status(true, &"audio_fallback_available", {
		"startup_generation": _expected_startup_generation,
		"persisted": false,
		"prior_audio_restore_requires_stable": true,
	})


func apply_fallback() -> Dictionary:
	if not _ready_for_call():
		return _status(false, &"binding_unavailable")
	if not _generation_matches():
		return _status(false, &"stale_recovery_generation")
	_last_status = _recovery.apply_audio_recovery_fallback(_persist_settings).duplicate(true)
	return _last_status.duplicate(true)


func restore_after_stable() -> Dictionary:
	if not _ready_for_call():
		return _status(false, &"binding_unavailable")
	if not _generation_matches():
		return _status(false, &"stale_recovery_generation")
	_last_status = _recovery.restore_prior_audio_profile(_persist_settings).duplicate(true)
	return _last_status.duplicate(true)


func get_report() -> Dictionary:
	return {
		"schema_version": 1,
		"attached": _attached,
		"configured": _recovery != null,
		"expected_startup_generation": _expected_startup_generation,
		"last_status": _last_status.duplicate(true),
		"recovery_report": _recovery.get_report() if _recovery != null else {},
	}.duplicate(true)


func _ready_for_call() -> bool:
	return _attached and _recovery != null and _persist_settings.is_valid()


func _generation_matches() -> bool:
	return int(_recovery.get_report().get("startup_generation", -1)) == _expected_startup_generation


func _status(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key in extra:
		result[key] = extra[key]
	return result
