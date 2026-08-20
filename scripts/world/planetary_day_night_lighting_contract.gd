class_name PlanetaryDayNightLightingContract
extends RefCounted

## Caller-driven, renderer-free day/night lighting contract for a planetary
## surface.  The caller supplies current sun/moon directions and occlusion
## observations; this policy derives deterministic solar phase, twilight,
## bounded moonlight and shadow hints.  It owns no clock, ephemeris, light,
## environment, cloud query, renderer resource, audio, gameplay, or physics.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"planetary_day_night_lighting_v1"
const EQUATION_VERSION: StringName = &"spherical_sun_moon_phase_v1"
const OBSERVATION_FRAME: StringName = &"planetary_body_local"
const UNIT_VECTOR_TOLERANCE := 0.0001
const ANGLE_TOLERANCE_RADIANS := 0.000001
const MIN_BODY_RADIUS_M := 0.000001
const MAX_BODY_RADIUS_M := 1.0e12
const MIN_TWILIGHT_DEGREES := -18.0
const MAX_TWILIGHT_DEGREES := -0.001
const DEFAULT_TWILIGHT_DEGREES := -6.0
const MAX_MOONLIGHT_ENERGY_FACTOR := 0.25
const MAX_INTERIOR_SKY_FACTOR := 1.0
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"clock_or_ephemeris", "sun_direction_source", "moon_direction_source",
	"star_luminosity", "moon_albedo", "absolute_lux", "directional_light",
	"environment_or_sky", "renderer_application", "cloud_query",
	"terrain_horizon_query", "shadow_map", "shadow_application", "camera",
	"interior_probe", "interior_audio", "physics", "gameplay", "streaming",
	"save", "network", "origin_or_rebase",
]
const CAPABILITIES := {
	"deterministic_solar_phase_implemented": true,
	"spherical_horizon_implemented": true,
	"bounded_atmospheric_twilight_implemented": true,
	"bounded_moon_phase_lighting_implemented": true,
	"interior_exterior_transition_implemented": true,
	"shadow_hints_implemented": true,
	"renderer_application_implemented": false,
	"clock_or_ephemeris_implemented": false,
	"terrain_or_cloud_shadow_query_implemented": false,
	"absolute_energy_or_lux_implemented": false,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}

var _configured := false
var _world_id: StringName = &""
var _body_radius_m := 0.0
var _twilight_min_clearance_radians := deg_to_rad(DEFAULT_TWILIGHT_DEGREES)
var _moonlight_energy_factor := 0.0
var _interior_sky_factor := 0.0
var _snapshot: Dictionary = {}


## Freezes a detached definition.  No clock is accepted here: elapsed time and
## ephemeris belong to the caller that creates each observation.
func configure(definition: Variant) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if definition is not Dictionary:
		return _result(false, &"invalid_definition")
	var source := definition as Dictionary
	const REQUIRED_KEYS := [
		"world_id", "body_radius_m", "twilight_min_clearance_degrees",
		"moonlight_energy_factor_unitless", "interior_sky_factor_unitless",
	]
	if source.size() != REQUIRED_KEYS.size():
		return _result(false, &"invalid_definition_schema")
	for key: String in REQUIRED_KEYS:
		if not source.has(key):
			return _result(false, &"invalid_definition_schema")
	var world_id: Variant = source.get("world_id")
	if not world_id is StringName or (world_id as StringName).is_empty():
		return _result(false, &"invalid_world_id")
	var radius_result := _finite_positive(source.get("body_radius_m"))
	if not bool(radius_result.get("accepted", false)) \
			or float(radius_result.value) > MAX_BODY_RADIUS_M:
		return _result(false, &"invalid_body_radius")
	var twilight: Variant = source.get("twilight_min_clearance_degrees")
	if not _finite_number(twilight) \
			or float(twilight) < MIN_TWILIGHT_DEGREES \
			or float(twilight) > MAX_TWILIGHT_DEGREES:
		return _result(false, &"invalid_twilight_boundary")
	var moonlight: Variant = source.get("moonlight_energy_factor_unitless")
	if not _unit_number(moonlight) or float(moonlight) > MAX_MOONLIGHT_ENERGY_FACTOR:
		return _result(false, &"invalid_moonlight_factor")
	var interior: Variant = source.get("interior_sky_factor_unitless")
	if not _unit_number(interior) or float(interior) > MAX_INTERIOR_SKY_FACTOR:
		return _result(false, &"invalid_interior_sky_factor")
	_world_id = world_id as StringName
	_body_radius_m = float(radius_result.value)
	_twilight_min_clearance_radians = deg_to_rad(float(twilight))
	_moonlight_energy_factor = float(moonlight)
	_interior_sky_factor = float(interior)
	_snapshot = {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"configured": true,
		"world_id": _world_id,
		"body_radius_m": _body_radius_m,
		"twilight_min_clearance_degrees": float(twilight),
		"twilight_min_clearance_radians": _twilight_min_clearance_radians,
		"moonlight_energy_factor_unitless": _moonlight_energy_factor,
		"interior_sky_factor_unitless": _interior_sky_factor,
		"observation_frame": OBSERVATION_FRAME,
		"authority": _authority(),
		"adjacent_authority": _adjacent_authority(),
		"capabilities": CAPABILITIES.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)
	_configured = true
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


## Evaluates one strict, current observation.  `location_mode` is `exterior` or
## `interior`; interior values suppress direct celestial sources and retain a
## bounded authored sky factor.  Occlusion values are caller-produced hints,
## never queried by this contract.
func evaluate(observation: Variant) -> Dictionary:
	var decoded := _decode_observation(observation)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_observation")))
	if not _configured:
		return _result(false, &"not_configured")
	var input := decoded.input as Dictionary
	var observer := input.body_local_observer_m as Vector3
	var radius := observer.length()
	if radius <= MIN_BODY_RADIUS_M:
		return _result(false, &"observer_radial_up_undefined")
	if radius < _body_radius_m:
		return _result(false, &"observer_inside_reference_sphere")
	var sun := input.normalized_body_to_sun as Vector3
	var moon := input.normalized_body_to_moon as Vector3
	var surface_up := observer / radius
	var sun_elevation := asin(clampf(surface_up.dot(sun), -1.0, 1.0))
	var moon_elevation := asin(clampf(surface_up.dot(moon), -1.0, 1.0))
	var radius_ratio := clampf(_body_radius_m / radius, 0.0, 1.0)
	var horizon := asin(-sqrt(maxf(1.0 - radius_ratio * radius_ratio, 0.0)))
	var sun_clearance := sun_elevation - horizon
	var moon_clearance := moon_elevation - horizon
	var sun_visible := sun_clearance > ANGLE_TOLERANCE_RADIANS
	var moon_visible := moon_clearance > ANGLE_TOLERANCE_RADIANS
	var interior: bool = input.location_mode == &"interior"
	var twilight := _twilight_factor(sun_clearance, sun_visible)
	var day := 1.0 if sun_visible else 0.0
	var night := clampf(1.0 - day - twilight, 0.0, 1.0)
	var exterior_factor := 0.0 if interior else 1.0
	var interior_sky := _interior_sky_factor if interior else 0.0
	var sun_shadow := 0.0
	if sun_visible and not interior:
		sun_shadow = clampf(1.0 - float(input.sun_occlusion_unitless), 0.0, 1.0)
	var moon_shadow := 0.0
	if moon_visible and not interior:
		moon_shadow = clampf(1.0 - float(input.moon_occlusion_unitless), 0.0, 1.0)
	var moon_phase := float(input.moon_phase_unitless)
	var moon_energy := (
		_moonlight_energy_factor * moon_phase * moon_shadow
		if moon_visible and not interior else 0.0
	)
	var ambient := clampf(
		interior_sky + exterior_factor * (
			0.25 * day + 0.12 * twilight + 0.05 * night * moon_energy
		), 0.0, 1.0
	)
	var state: StringName
	if interior:
		state = &"interior"
	elif day > 0.0:
		state = &"direct_daylight"
	elif twilight > 0.0:
		state = &"atmospheric_twilight"
	else:
		state = &"night"
	var evaluation := {
		"accepted": true,
		"reason": &"evaluated",
		"evaluation_schema_version": SCHEMA_VERSION,
		"world_id": _world_id,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"inputs": input.duplicate(true),
		"classification": {
			"state": state,
			"day_factor_unitless": day,
			"twilight_factor_unitless": twilight,
			"night_factor_unitless": night,
			"interior_factor_unitless": 1.0 if interior else 0.0,
			"factor_sum_unitless": day + twilight + night,
		}.duplicate(true),
		"solar_phase": {
			"sun_elevation_radians": sun_elevation,
			"sun_horizon_clearance_radians": sun_clearance,
			"direct_sun_visible": sun_visible and not interior,
			"spherical_horizon_elevation_radians": horizon,
		}.duplicate(true),
		"moon_phase": {
			"moon_elevation_radians": moon_elevation,
			"moon_horizon_clearance_radians": moon_clearance,
			"direct_moon_visible": moon_visible and not interior,
			"illumination_unitless": moon_phase,
			"recommended_energy_factor_unitless": moon_energy,
		}.duplicate(true),
		"lighting_hints": {
			"recommended_sun_energy_factor_unitless": (
				sun_shadow if sun_visible and not interior else 0.0
			),
			"recommended_moon_energy_factor_unitless": moon_energy,
			"recommended_ambient_energy_factor_unitless": ambient,
			"interior_sky_factor_unitless": interior_sky,
			"absolute_energy_or_lux": false,
		}.duplicate(true),
		"shadow_hints": {
			"sun_shadow_receiver_factor_unitless": sun_shadow,
			"moon_shadow_receiver_factor_unitless": moon_shadow,
			"sun_occluded_by_caller": float(input.sun_occlusion_unitless) > 0.0,
			"moon_occluded_by_caller": float(input.moon_occlusion_unitless) > 0.0,
			"terrain_or_cloud_query_performed": false,
			"renderer_shadow_map_consulted": false,
		}.duplicate(true),
		"transition": {
			"location_mode": input.location_mode,
			"exterior_factor_unitless": exterior_factor,
			"interior_sky_factor_unitless": interior_sky,
			"direct_sources_suppressed": interior,
		}.duplicate(true),
	}.duplicate(true)
	return _result(true, &"evaluated", {"evaluation": evaluation})


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("day_night_contract_not_configured")
	if not _authority().values().all(func(value: Variant) -> bool: return not bool(value)):
		errors.append("authority_contract_drift")
	if not _evidence_valid(EVIDENCE):
		errors.append("evidence_contract_drift")
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"purity": {
			"stateless_evaluation": true,
			"clock_input": false,
			"renderer_resource": false,
			"renderer_application": false,
			"source_resource_retained": false,
		}.duplicate(true),
	}.duplicate(true)


func _decode_observation(observation: Variant) -> Dictionary:
	if observation is not Dictionary:
		return {"accepted": false, "reason": &"invalid_observation"}
	var input := observation as Dictionary
	const KEYS := [
		"body_local_observer_m", "normalized_body_to_sun",
		"normalized_body_to_moon", "moon_phase_unitless",
		"sun_occlusion_unitless", "moon_occlusion_unitless", "location_mode",
	]
	if input.size() != KEYS.size():
		return {"accepted": false, "reason": &"invalid_observation_schema"}
	for key: String in KEYS:
		if not input.has(key):
			return {"accepted": false, "reason": &"invalid_observation_schema"}
	var observer: Variant = input.get("body_local_observer_m")
	if observer is not Vector3 or not (observer as Vector3).is_finite():
		return {"accepted": false, "reason": &"invalid_observer_position"}
	if not _unit_vector(input.get("normalized_body_to_sun")) \
			or not _unit_vector(input.get("normalized_body_to_moon")):
		return {"accepted": false, "reason": &"invalid_celestial_direction"}
	for key: String in ["moon_phase_unitless", "sun_occlusion_unitless", "moon_occlusion_unitless"]:
		if not _unit_number(input.get(key)):
			return {"accepted": false, "reason": &"invalid_%s" % key}
	var mode: Variant = input.get("location_mode")
	if not mode is StringName or not (mode == &"exterior" or mode == &"interior"):
		return {"accepted": false, "reason": &"invalid_location_mode"}
	return {
		"accepted": true,
		"reason": &"valid_observation",
		"input": {
			"body_local_observer_m": observer as Vector3,
			"normalized_body_to_sun": input.normalized_body_to_sun as Vector3,
			"normalized_body_to_moon": input.normalized_body_to_moon as Vector3,
			"moon_phase_unitless": float(input.moon_phase_unitless),
			"sun_occlusion_unitless": float(input.sun_occlusion_unitless),
			"moon_occlusion_unitless": float(input.moon_occlusion_unitless),
			"location_mode": mode as StringName,
		}.duplicate(true),
	}


func _twilight_factor(clearance: float, sun_visible: bool) -> float:
	if sun_visible or clearance < _twilight_min_clearance_radians:
		return 0.0
	var span := -_twilight_min_clearance_radians
	if span <= 0.0:
		return 0.0
	return clampf((clearance - _twilight_min_clearance_radians) / span, 0.0, 1.0)


func _authority() -> Dictionary:
	var result := {}
	for key: String in COMMON_AUTHORITY_KEYS:
		result[key] = false
	return result


func _adjacent_authority() -> Dictionary:
	var result := {}
	for key: String in ADJACENT_AUTHORITY_KEYS:
		result[key] = false
	return result


func _finite_positive(value: Variant) -> Dictionary:
	if not _finite_number(value) or float(value) <= 0.0:
		return {"accepted": false}
	return {"accepted": true, "value": float(value)}


func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


func _unit_number(value: Variant) -> bool:
	return _finite_number(value) and float(value) >= 0.0 and float(value) <= 1.0


func _unit_vector(value: Variant) -> bool:
	if value is not Vector3 or not (value as Vector3).is_finite():
		return false
	var length := (value as Vector3).length()
	return is_finite(length) and absf(length - 1.0) <= UNIT_VECTOR_TOLERANCE


func _evidence_valid(value: Dictionary) -> bool:
	return value.get("content_class", &"") == &"NEW" \
			and value.get("status", &"") == &"modern_interpretation" \
			and value.get("source_bounded", true) == false \
			and value.get("confidence", &"") == &"none"


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: String in extra:
		result[key] = extra[key]
	return result
