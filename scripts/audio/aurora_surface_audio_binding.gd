class_name AuroraSurfaceAudioBinding
extends RefCounted

## Presentation-only mix plan for detached Aurora environment snapshots.
## Weather, water, day/night, and ship perspective authority stay with callers.
##
## Exterior wind timbre tracks the authored wind state specifically (falling
## back to the general weather intensity when a caller has no distinct wind
## reading yet): calm air is quiet and muffled, strong wind is louder and
## brighter, and the pitch drifts up with it. Every value here is a continuous
## function of its inputs, so a caller that re-presents a smoothly changing
## wind reading every tick (as the authored weather field already produces)
## gets a smoothly interpolated mix with no internal state or discontinuity.
##
## Interior/exterior is a continuous blend, not a switch. A caller may supply
## `interior_blend_unitless` (0 = standing outside, 1 = sealed cabin), which
## PlanetaryAtmosphereFlightEffects eases over about a second whenever the pilot
## boards, disembarks, opens the canopy or walks into a craft's cabin. The blend
## quiets the exterior, raises the cabin bed and sweeps the exterior low-pass
## down (log-frequency) to a sealed-cabin ceiling. Without it the blend is taken
## from `ship_perspective` (cockpit = 1, exterior = 0), exactly as before.

const MAXIMUM_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const WIND_CALM_LOW_PASS_HZ := 900.0
const WIND_STRONG_LOW_PASS_HZ := 18_000.0
const WIND_CALM_PITCH_SCALE := 0.97
## Highest exterior cutoff heard through a sealed cockpit or cabin wall.
const SEALED_CABIN_LOW_PASS_HZ := 1_400.0
const WIND_STRONG_PITCH_SCALE := 1.06

var _attached := false
var _generation := 0
var _last_source_generation := -1
var _last_snapshot: Dictionary = {}
var _mix := {"wind": 0.0, "distant_water": 0.0, "weather": 0.0, "settlement": 0.0, "low_pass_hz": 18_000.0, "pitch_scale": 1.0}
var _interior_blend := 0.0
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
		_last_source_generation = -1
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
	# The authored wind reading is the primary driver of exterior timbre. A
	# caller with no distinct wind sample yet falls back to weather intensity,
	# which keeps every existing caller's behaviour unchanged.
	var wind: Variant = snapshot.get("wind_strength_unitless", weather)
	var perspective: Variant = snapshot.get("ship_perspective", &"exterior")
	var altitude: Variant = snapshot.get("altitude_m", 0.0)
	if not generation is int or int(generation) < 0 or int(generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	if not _unitless(weather) or not _unitless(water) or not _unitless(day) \
			or not _unitless(settlement) or not _unitless(wind):
		return _result(false, &"invalid_environment_snapshot")
	if perspective not in [&"cockpit", &"exterior"]:
		return _result(false, &"invalid_ship_perspective")
	var interior: Variant = snapshot.get(
		"interior_blend_unitless", 1.0 if perspective == &"cockpit" else 0.0
	)
	if not _unitless(interior):
		return _result(false, &"invalid_interior_blend")
	if not (altitude is float or altitude is int) or not is_finite(float(altitude)) or float(altitude) < 0.0:
		return _result(false, &"invalid_altitude")
	if int(generation) < _last_source_generation:
		return _result(false, &"stale_generation")
	if int(generation) == _last_source_generation and snapshot == _last_snapshot:
		return _result(false, &"duplicate_snapshot")
	_last_source_generation = int(generation)
	var blend := float(interior)
	var cabin := lerpf(1.0, 0.62, blend)
	# Sealing in the cockpit both quiets and further muffles the exterior wind,
	# same direction as real cabin insulation. The cutoff sweeps in log
	# frequency so the fade sounds even from open air to a closed hatch.
	var open_air_cutoff := clampf(
		lerpf(WIND_CALM_LOW_PASS_HZ, WIND_STRONG_LOW_PASS_HZ, float(wind)),
		200.0, WIND_STRONG_LOW_PASS_HZ,
	)
	var sealed_cutoff := clampf(
		minf(open_air_cutoff * 0.55, SEALED_CABIN_LOW_PASS_HZ),
		200.0, WIND_STRONG_LOW_PASS_HZ,
	)
	var dynamic := 0.75 if _reduced_dynamic_range else 1.0
	var surface_presence := 1.0 - clampf(float(altitude) / 2500.0, 0.0, 1.0)
	_mix = {
		"wind": clampf(float(wind) * cabin * dynamic * surface_presence, 0.0, 1.0),
		"distant_water": clampf(float(water) * (0.55 + 0.2 * float(day)) * dynamic * surface_presence, 0.0, 1.0),
		"weather": clampf(float(weather) * (0.4 + 0.6 * float(day)) * cabin * dynamic, 0.0, 1.0),
		"settlement": clampf(float(settlement) * lerpf(1.0, 0.8, blend) * dynamic, 0.0, 1.0),
		"low_pass_hz": clampf(
			exp(lerpf(log(open_air_cutoff), log(sealed_cutoff), blend)),
			200.0, WIND_STRONG_LOW_PASS_HZ,
		),
		"pitch_scale": lerpf(
			WIND_CALM_PITCH_SCALE, WIND_STRONG_PITCH_SCALE,
			clampf(float(wind) * 0.7 + float(water) * 0.3, 0.0, 1.0),
		),
	}
	_interior_blend = blend
	_last_snapshot = snapshot.duplicate(true)
	return _result(true, &"snapshot_presented")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_last_source_generation = -1
	_last_snapshot.clear()
	_mix = {"wind": 0.0, "distant_water": 0.0, "weather": 0.0, "settlement": 0.0, "low_pass_hz": 18_000.0, "pitch_scale": 1.0}
	_interior_blend = 0.0
	_generation += 1
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "last_source_generation": _last_source_generation, "ship_perspective": _last_snapshot.get("ship_perspective", &"exterior"), "interior_blend": _interior_blend, "mix": _mix.duplicate(true), "reduced_dynamic_range": _reduced_dynamic_range, "maximum_simultaneous_voices": MAXIMUM_VOICES, "authority": {"weather": false, "water": false, "day_night": false, "movement": false, "audio": true}}.duplicate(true)

func _unitless(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 1.0

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
