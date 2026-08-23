class_name ComponentDamageAudioBinding
extends RefCounted

## Presentation-only bridge from caller-owned resolved component damage to the
## existing ShipAudioRig. It never resolves health, repair, or ship authority.

const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const DAMAGE_STAGES := [&"nominal", &"degraded", &"critical", &"destroyed", &"repaired"]

var _rig: Node
var _attached := false
var _generation := 0
var _last_snapshot: Dictionary = {}
var _last_degradation := 0.0


func bind(rig: Node) -> Dictionary:
	if _attached:
		return _result(false, &"already_bound")
	if rig == null or not rig.has_method(&"get_component_id") \
			or rig.call(&"get_component_id") != &"ship-audio-rig":
		return _result(false, &"foreign_audio_rig")
	if not rig.has_method(&"set_engine_degradation") \
			or not rig.has_method(&"set_damage_alarm_active"):
		return _result(false, &"incomplete_audio_rig")
	_rig = rig
	_attached = true
	_last_snapshot.clear()
	_last_degradation = 0.0
	return _result(true, &"bound")


func present_damage_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached or not is_instance_valid(_rig):
		return _result(false, &"not_attached")
	var decoded := _decode_snapshot(snapshot)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_snapshot")))
	var degradation := float(decoded.degradation)
	var changed := not is_equal_approx(degradation, _last_degradation)
	if changed:
		_rig.call(&"set_engine_degradation", degradation)
	_rig.call(&"set_damage_alarm_active", degradation >= 0.75)
	_last_degradation = degradation
	_last_snapshot = snapshot.duplicate(true)
	return _result(true, &"damage_presented" if changed else &"damage_unchanged")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if is_instance_valid(_rig):
		_rig.call(&"set_engine_degradation", 0.0)
		_rig.call(&"set_damage_alarm_active", false)
	_attached = false
	_generation += 1
	_rig = null
	_last_snapshot.clear()
	_last_degradation = 0.0
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_snapshot": _last_snapshot.duplicate(true),
		"last_degradation": _last_degradation,
		"authority": {"damage": false, "repair": false, "ship": false, "audio_presentation": true},
	}.duplicate(true)


func _decode_snapshot(snapshot: Dictionary) -> Dictionary:
	var stage: Variant = snapshot.get("stage", &"nominal")
	var reset: Variant = snapshot.get("reset", false)
	if not stage is StringName or not DAMAGE_STAGES.has(stage as StringName) or not reset is bool:
		return _result(false, &"invalid_damage_state")
	var degradation: float
	if bool(reset) or stage == &"repaired":
		degradation = 0.0
	else:
		var raw_ratio: Variant = snapshot.get("health_ratio", 1.0)
		if not (raw_ratio is float or raw_ratio is int) or not is_finite(float(raw_ratio)) \
				or float(raw_ratio) < 0.0 or float(raw_ratio) > 1.0:
			return _result(false, &"invalid_health_ratio")
		degradation = 1.0 - float(raw_ratio)
		if stage == &"degraded":
			degradation = maxf(degradation, 0.25)
		elif stage in [&"critical", &"destroyed"]:
			degradation = maxf(degradation, 0.75)
	return {"accepted": true, "degradation": clampf(degradation, 0.0, 1.0)}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
