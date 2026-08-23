class_name AuroraSurfaceAudioBinding
extends RefCounted

## Presentation-only mix plan for detached Aurora environment snapshots.
## Weather, water, day/night, and ship perspective authority stay with callers.

const MAXIMUM_VOICES := 4
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

var _attached := false
var _generation := 0
var _last_source_generation := -1
var _last_snapshot: Dictionary = {}
var _mix := {"wind": 0.0, "distant_water": 0.0, "weather": 0.0, "settlement": 0.0, "low_pass_hz": 18_000.0, "pitch_scale": 1.0}
var _reduced_dynamic_range := false

func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_last_source_generation = -1
	_last_snapshot.clear()
	return _result(true, &"attached")

func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	if not _last_snapshot.is_empty():
		present_snapshot(_last_snapshot)
	return _result(true, &"mix_updated")

func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var generation: Variant = snapshot.get("generation", -1)
	var weather: Variant = snapshot.get("weather_intensity_unitless", 0.0)
	var water: Variant = snapshot.get("water_exposure_unitless", 0.0)
	var day: Variant = snapshot.get("day_night_unitless", 0.5)
	var settlement: Variant = snapshot.get("settlement_activity_unitless", 0.0)
	var perspective: Variant = snapshot.get("ship_perspective", &"exterior")
	if not generation is int or int(generation) < 0 or int(generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	if not _unitless(weather) or not _unitless(water) or not _unitless(day) or not _unitless(settlement):
		return _result(false, &"invalid_environment_snapshot")
	if perspective not in [&"cockpit", &"exterior"]:
		return _result(false, &"invalid_ship_perspective")
	if int(generation) < _last_source_generation:
		return _result(false, &"stale_generation")
	if int(generation) == _last_source_generation and snapshot == _last_snapshot:
		return _result(false, &"duplicate_snapshot")
	_last_source_generation = int(generation)
	var cabin := 0.62 if perspective == &"cockpit" else 1.0
	var dynamic := 0.75 if _reduced_dynamic_range else 1.0
	_mix = {
		"wind": clampf(float(weather) * cabin * dynamic, 0.0, 1.0),
		"distant_water": clampf(float(water) * (0.55 + 0.2 * float(day)) * dynamic, 0.0, 1.0),
		"weather": clampf(float(weather) * (0.4 + 0.6 * float(day)) * cabin * dynamic, 0.0, 1.0),
		"settlement": clampf(float(settlement) * (0.8 if perspective == &"cockpit" else 1.0) * dynamic, 0.0, 1.0),
		"low_pass_hz": lerpf(18_000.0, 3_200.0, float(weather) * (1.0 if perspective == &"exterior" else 0.7)),
		"pitch_scale": lerpf(0.97, 1.06, float(weather) * 0.7 + float(water) * 0.3),
	}
	_last_snapshot = snapshot.duplicate(true)
	return _result(true, &"snapshot_presented")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_last_source_generation = -1
	_last_snapshot.clear()
	_mix = {"wind": 0.0, "distant_water": 0.0, "weather": 0.0, "settlement": 0.0, "low_pass_hz": 18_000.0, "pitch_scale": 1.0}
	_generation += 1
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "last_source_generation": _last_source_generation, "mix": _mix.duplicate(true), "reduced_dynamic_range": _reduced_dynamic_range, "maximum_simultaneous_voices": MAXIMUM_VOICES, "authority": {"weather": false, "water": false, "day_night": false, "movement": false, "audio": true}}.duplicate(true)

func _unitless(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 1.0

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
