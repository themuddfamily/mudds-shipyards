class_name PlanetaryWeatherField
extends RefCounted

## Reusable, deterministic weather/cloud evaluator for one atmosphere profile.
##
## The caller supplies absolute sample position and time. This object owns no
## clock, weather state, renderer, audio, physics, network, or persistence
## authority; it only freezes profile values and returns bounded presentation
## hints suitable for cloud, wind, fog, and surface-audio consumers.

const SCHEMA_VERSION := 1
const EQUATION_VERSION: StringName = &"game_scale_weather_field_v1"
const MAX_TIME_SECONDS := 9_007_199_254_740_991.0
const MAX_POSITION_M := 1.0e12

var _configured := false
var _profile_id: StringName = &""
var _geometry: Dictionary = {}
var _optics: Dictionary = {}
var _weather: Dictionary = {}


func configure(profile: PlanetaryAtmosphereProfile) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if profile == null:
		return _result(false, &"missing_profile")
	var audit := profile.get_audit_report()
	if not profile.is_definition_valid() or not bool(audit.get("valid", false)):
		return _result(false, &"invalid_profile")
	_configured = true
	_profile_id = StringName(audit.get("profile_id", &""))
	_geometry = profile.get_geometry_snapshot().duplicate(true)
	_optics = profile.get_optics_snapshot().duplicate(true)
	_weather = profile.get_weather_snapshot().duplicate(true)
	return _result(true, &"configured")


func is_configured() -> bool:
	return _configured


## Samples a caller-owned world position (metres), altitude (metres), sight
## distance (metres), and time (seconds). Time is an input, never accumulated.
func sample(
		altitude_m: float,
		position_m: Vector3,
		sight_distance_m: float,
		caller_time_seconds: float
	) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not is_finite(altitude_m) or altitude_m < -float(_geometry.planet_radius_m) \
			or altitude_m > float(_geometry.atmosphere_top_altitude_m):
		return _result(false, &"invalid_altitude")
	if not _vector_is_finite(position_m) or position_m.length() > MAX_POSITION_M:
		return _result(false, &"invalid_position")
	if not is_finite(sight_distance_m) or sight_distance_m < 0.0 \
			or sight_distance_m > float(_optics.maximum_visibility_m):
		return _result(false, &"invalid_sight_distance")
	if not is_finite(caller_time_seconds) or caller_time_seconds < 0.0 \
			or caller_time_seconds > MAX_TIME_SECONDS:
		return _result(false, &"invalid_caller_time")

	var cloud_base := float(_weather.cloud_base_altitude_m)
	var cloud_top := float(_weather.cloud_top_altitude_m)
	var cloud_layer := 0.0
	if altitude_m >= cloud_base and altitude_m < cloud_top:
		cloud_layer = (altitude_m - cloud_base) / (cloud_top - cloud_base)
	var fog := 0.0
	var fog_start := float(_optics.fog_start_distance_m)
	var fog_end := float(_optics.fog_end_distance_m)
	if sight_distance_m > fog_start:
		fog = clampf((sight_distance_m - fog_start) / (fog_end - fog_start), 0.0, 1.0)
	var phase := sin(position_m.x * 0.00017 + position_m.z * 0.00011 + caller_time_seconds * 0.035)
	var gust := clampf(1.0 + phase * 0.25 * float(_weather.weather_intensity_unitless), 0.0, 1.25)
	var coverage := clampf(float(_weather.cloud_coverage_unitless) * gust, 0.0, 1.0)
	var wind: Vector3 = _weather.wind_velocity_mps * gust
	return _result(true, &"sampled", {
		"altitude_m": altitude_m,
		"cloud_layer_factor_unitless": cloud_layer,
		"cloud_coverage_unitless": coverage,
		"fog_factor_unitless": fog * float(_optics.fog_density_unitless),
		"wind_velocity_mps": wind,
		"weather_gust_factor_unitless": gust,
		"caller_time_seconds": caller_time_seconds,
	})


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured or _profile_id.is_empty():
		errors.append("weather field is not configured")
	return {
		"schema_version": SCHEMA_VERSION,
		"equation_version": EQUATION_VERSION,
		"profile_id": _profile_id,
		"valid": errors.is_empty(),
		"errors": errors,
		"authority": {"clock": false, "renderer": false, "gameplay": false, "audio": false, "network": false, "save": false},
		"boundary_policy": {"cloud_layer": &"base_inclusive_top_exclusive", "fog": &"linear_clamped", "time": &"caller_owned"},
	}.duplicate(true)


func _result(accepted: bool, reason: StringName, values: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	result.merge(values, true)
	return result


func _vector_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
