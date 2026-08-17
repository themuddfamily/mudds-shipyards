class_name PlanetarySunLightingPolicy
extends RefCounted

## Pure spherical-horizon and clear-sky/airless lighting hint policy.
##
## The caller owns observer/sun observations and every renderer value. This
## policy freezes only detached definition data and returns normalized bounded
## factors. It does not own an ephemeris, clock, orbit, terrain/cloud occlusion,
## calibrated photometry, renderer Resource, or application side effect.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"planetary_sun_lighting_v1"
const EQUATION_VERSION: StringName = &"spherical_horizon_clear_sky_proxy_v1"
const OBSERVATION_FRAME: StringName = &"planetary_body_local"
const UNIT_VECTOR_LENGTH_TOLERANCE := 0.0001
const ANGLE_BOUNDARY_TOLERANCE_RADIANS := 0.000001
const MIN_OBSERVER_RADIUS_M := 0.000001
const TWILIGHT_MIN_CLEARANCE_DEGREES := -6.0
const TWILIGHT_MIN_CLEARANCE_RADIANS := deg_to_rad(
	TWILIGHT_MIN_CLEARANCE_DEGREES
)
const DAY_AMBIENT_ENERGY_FACTOR := 0.25
const TWILIGHT_AMBIENT_ENERGY_FACTOR := 0.12
const LUMINANCE_WEIGHTS := Vector3(0.2126, 0.7152, 0.0722)
const OBSERVATION_KEYS := [
	"body_local_observer_m",
	"normalized_body_to_sun",
]
const AUTHORITY := {
	"renderer": false,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
	"physics": false,
	"world_generation": false,
	"terrain_generation": false,
	"collision_generation": false,
	"origin_shift": false,
	"weather_clock": false,
	"audio": false,
}
const ADJACENT_AUTHORITY := {
	"star_spectrum": false,
	"star_luminosity": false,
	"ephemeris": false,
	"time_or_day_night_clock": false,
	"directional_light": false,
	"environment": false,
	"sky_or_material": false,
	"renderer_application": false,
	"shadow_or_occlusion_query": false,
	"terrain_horizon": false,
	"terrain_albedo": false,
	"cloud_shadow": false,
	"weather_selection": false,
	"camera": false,
	"origin_or_rebase": false,
	"physics": false,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
}
const CAPABILITIES := {
	"spherical_reference_horizon_implemented": true,
	"airless_visibility_implemented": true,
	"bounded_clear_sky_attenuation_hint_implemented": true,
	"bounded_atmospheric_twilight_proxy_implemented": true,
	"calibrated_photometry_implemented": false,
	"star_spectrum_implemented": false,
	"finite_sun_disk_implemented": false,
	"terrain_shadow_implemented": false,
	"cloud_shadow_implemented": false,
	"multiple_scattering_implemented": false,
	"renderer_application_implemented": false,
	"clock_or_ephemeris_implemented": false,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}

var _configured := false
var _world_id: StringName = &""
var _source_world_schema_version := 0
var _source_atmosphere_schema_version := 0
var _body_radius_m := 0.0
var _has_atmosphere := false
var _atmosphere_profile_id: StringName = &""
var _world_snapshot: Dictionary = {}
var _atmosphere_snapshot: Dictionary = {}
var _atmosphere_geometry: Dictionary = {}
var _atmosphere_optics: Dictionary = {}
var _sampler: PlanetaryAtmosphereSampler
var _source_evidence: Dictionary = {}


## Configures once from one valid world and its optional resolved atmosphere.
## Atmospheric worlds require an exact ID/radius match; airless worlds require
## a null profile. Successful configuration retains no source Resource.
func configure(
	world: PlanetaryWorldDefinition,
	atmosphere: PlanetaryAtmosphereProfile = null
) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if world == null:
		return _result(false, &"missing_world_definition")
	var world_audit := world.get_audit_report()
	if not world.is_definition_valid() \
			or not bool(world_audit.get("valid", false)) \
			or not _has_exact_zero_authority(
				world_audit.get("authority", {}) as Dictionary
			):
		return _result(false, &"invalid_world_definition")
	var body := world_audit.get("body", {}) as Dictionary
	var has_atmosphere := bool(body.get("has_atmosphere", false))
	var atmosphere_audit := {}
	var atmosphere_geometry := {}
	var atmosphere_optics := {}
	var sampler: PlanetaryAtmosphereSampler = null
	if has_atmosphere:
		if atmosphere == null:
			return _result(false, &"missing_atmosphere_profile")
		atmosphere_audit = atmosphere.get_audit_report()
		if not atmosphere.is_definition_valid() \
				or not bool(atmosphere_audit.get("valid", false)) \
				or not _has_exact_zero_authority(
					atmosphere_audit.get("authority", {}) as Dictionary
				):
			return _result(false, &"invalid_atmosphere_profile")
		if atmosphere_audit.get("profile_id", &"") \
				!= body.get("atmosphere_definition_id", &""):
			return _result(false, &"atmosphere_profile_id_mismatch")
		atmosphere_geometry = atmosphere.get_geometry_snapshot()
		if float(atmosphere_geometry.get("planet_radius_m", NAN)) \
				!= float(body.get("radius_metres", NAN)):
			return _result(false, &"body_radius_mismatch")
		atmosphere_optics = atmosphere.get_optics_snapshot()
		sampler = PlanetaryAtmosphereSampler.new()
		var sampler_result := sampler.configure(atmosphere)
		if not bool(sampler_result.get("accepted", false)) \
				or not bool(sampler.audit().get("valid", false)):
			return _result(false, &"sampler_configuration_failed")
	elif atmosphere != null:
		return _result(false, &"unexpected_atmosphere_profile")

	if not _configuration_values_are_valid(
		world_audit,
		atmosphere_audit,
		atmosphere_geometry,
		atmosphere_optics,
		has_atmosphere
	):
		return _result(false, &"configuration_snapshot_mismatch")

	_configured = true
	_world_id = world_audit.get("world_id", &"") as StringName
	_source_world_schema_version = int(world_audit.get("schema_version", 0))
	_source_atmosphere_schema_version = (
		int(atmosphere_audit.get("schema_version", 0))
		if has_atmosphere else 0
	)
	_body_radius_m = float(body.get("radius_metres", 0.0))
	_has_atmosphere = has_atmosphere
	_atmosphere_profile_id = (
		atmosphere_audit.get("profile_id", &"") as StringName
		if has_atmosphere else &""
	)
	_world_snapshot = world_audit.duplicate(true)
	_atmosphere_snapshot = atmosphere_audit.duplicate(true)
	_atmosphere_geometry = atmosphere_geometry.duplicate(true)
	_atmosphere_optics = atmosphere_optics.duplicate(true)
	_sampler = sampler
	_source_evidence = {
		"world": (
			world_audit.get("evidence", {}) as Dictionary
		).duplicate(true),
		"atmosphere": (
			(atmosphere_audit.get("evidence", {}) as Dictionary).duplicate(true)
			if has_atmosphere else {}
		),
	}.duplicate(true)
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


## Evaluates one strict caller observation in planetary-body-local metres. The
## direction points from the body centre toward a distant sun. Neither value is
## sampled or advanced internally.
func evaluate(observation: Variant) -> Dictionary:
	var decoded := _decode_observation(observation)
	if not bool(decoded.get("accepted", false)):
		return _result(
			false, StringName(decoded.get("reason", &"invalid_observation"))
		)
	if not _configured:
		return _result(false, &"not_configured")
	var input := decoded.get("input", {}) as Dictionary
	var observer := input.get("body_local_observer_m", Vector3.INF) as Vector3
	var radius := observer.length()
	if not is_finite(radius):
		return _result(false, &"observer_radius_out_of_bounds")
	if radius <= MIN_OBSERVER_RADIUS_M:
		return _result(false, &"observer_radial_up_undefined")
	if radius < _body_radius_m:
		return _result(false, &"observer_inside_reference_sphere")
	var sun := (
		input.get("normalized_body_to_sun", Vector3.ZERO) as Vector3
	).normalized()
	var evaluation := _build_evaluation(observer, radius, sun)
	if not bool(evaluation.get("accepted", false)):
		return _result(
			false,
			StringName(evaluation.get("reason", &"evaluation_contract_mismatch"))
		)
	if not _evaluation_is_valid(evaluation):
		return _result(false, &"evaluation_contract_mismatch")
	return _result(true, &"evaluated", {
		"evaluation": evaluation.duplicate(true),
	})


func get_world_snapshot() -> Dictionary:
	return _world_snapshot.duplicate(true)


func get_atmosphere_snapshot() -> Dictionary:
	return _atmosphere_snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"configured": _configured,
		"world_id": _world_id,
		"source_world_schema_version": _source_world_schema_version,
		"source_atmosphere_schema_version": (
			_source_atmosphere_schema_version
		),
		"body_radius_m": _body_radius_m,
		"has_atmosphere": _has_atmosphere,
		"atmosphere_profile_id": _atmosphere_profile_id,
		"observation_frame": OBSERVATION_FRAME,
		"unit_vector_length_tolerance": UNIT_VECTOR_LENGTH_TOLERANCE,
		"angle_boundary_tolerance_radians": (
			ANGLE_BOUNDARY_TOLERANCE_RADIANS
		),
		"twilight_min_clearance_degrees": (
			TWILIGHT_MIN_CLEARANCE_DEGREES
		),
		"world": _world_snapshot.duplicate(true),
		"atmosphere": _atmosphere_snapshot.duplicate(true),
		"source_evidence": _source_evidence.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("sun_lighting_policy_not_configured")
	else:
		if not _configuration_values_are_valid(
			_world_snapshot,
			_atmosphere_snapshot,
			_atmosphere_geometry,
			_atmosphere_optics,
			_has_atmosphere
		):
			errors.append("frozen_configuration_contract_drift")
		if _has_atmosphere and (
			_sampler == null
			or not bool(_sampler.audit().get("valid", false))
			or _sampler.get_snapshot().get("profile_id", &"")
			!= _atmosphere_profile_id
		):
			errors.append("sampler_contract_drift")
		if not _has_atmosphere and _sampler != null:
			errors.append("airless_policy_gained_sampler")
	if not _has_exact_zero_authority(AUTHORITY):
		errors.append("authority_contract_drift")
	if not _evidence_contract_is_valid(EVIDENCE):
		errors.append("evidence_contract_drift")
	errors.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"boundary_policy": {
			"observer": &"on_or_outside_sea_level_reference_sphere",
			"horizon": &"spherical_reference_horizon_with_elevated_depression",
			"direct_visibility": &"clearance_above_named_angular_tolerance",
			"airless_or_vacuum": &"hard_terminator_no_twilight_or_ambient_proxy",
			"atmospheric_twilight": &"minus_six_degrees_inclusive_to_horizon",
			"atmosphere_shell": &"top_exclusive",
			"optical_path": &"ray_to_outer_sphere_capped_to_profile_visibility",
			"photometry": &"normalized_factors_not_lux",
		},
		"purity": {
			"stateless_evaluation": true,
			"delta_input": false,
			"clock_input": false,
			"retains_source_resource": false,
			"mutates_source_definitions": false,
			"origin_generation_required": false,
		},
		"limitations": {
			"caller_observation_freshness_verified": false,
			"star_spectrum_or_luminosity_known": false,
			"absolute_light_energy_or_lux_produced": false,
			"finite_sun_disk_modeled": false,
			"terrain_or_cloud_occlusion_modeled": false,
			"multiple_scattering_modeled": false,
			"renderer_values_applied": false,
		},
		"evidence": EVIDENCE.duplicate(true),
		"source_evidence": _source_evidence.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _decode_observation(observation: Variant) -> Dictionary:
	if observation is not Dictionary:
		return {"accepted": false, "reason": &"invalid_observation"}
	var input := observation as Dictionary
	if input.size() != OBSERVATION_KEYS.size():
		return {"accepted": false, "reason": &"invalid_observation_schema"}
	for key: String in OBSERVATION_KEYS:
		if not input.has(key):
			return {
				"accepted": false,
				"reason": &"invalid_observation_schema",
			}
	var observer: Variant = input.get("body_local_observer_m")
	if observer is not Vector3 or not (observer as Vector3).is_finite():
		return {"accepted": false, "reason": &"invalid_observer_position"}
	var position := observer as Vector3
	if absf(position.x) > PlanetaryCoordinateFrame.MAX_LOCAL_COMPONENT_METERS \
			or absf(position.y) \
			> PlanetaryCoordinateFrame.MAX_LOCAL_COMPONENT_METERS \
			or absf(position.z) \
			> PlanetaryCoordinateFrame.MAX_LOCAL_COMPONENT_METERS:
		return {"accepted": false, "reason": &"observer_position_out_of_bounds"}
	var direction: Variant = input.get("normalized_body_to_sun")
	if direction is not Vector3 or not (direction as Vector3).is_finite():
		return {"accepted": false, "reason": &"invalid_sun_direction"}
	var sun := direction as Vector3
	var sun_length := sun.length()
	if not is_finite(sun_length) or absf(sun_length - 1.0) \
			> UNIT_VECTOR_LENGTH_TOLERANCE:
		return {"accepted": false, "reason": &"invalid_sun_direction"}
	return {
		"accepted": true,
		"reason": &"valid_observation",
		"input": {
			"body_local_observer_m": position,
			"normalized_body_to_sun": sun,
		}.duplicate(true),
	}


func _build_evaluation(
	observer: Vector3,
	radius: float,
	sun: Vector3
) -> Dictionary:
	var surface_up := observer / radius
	var altitude := radius - _body_radius_m
	var elevation_sine := clampf(surface_up.dot(sun), -1.0, 1.0)
	var elevation_radians := asin(elevation_sine)
	var radius_ratio := clampf(_body_radius_m / radius, 0.0, 1.0)
	var horizon_sine := -sqrt(maxf(1.0 - radius_ratio * radius_ratio, 0.0))
	var horizon_elevation_radians := asin(clampf(horizon_sine, -1.0, 0.0))
	var clearance_radians := elevation_radians - horizon_elevation_radians
	var direct_visible := clearance_radians \
		> ANGLE_BOUNDARY_TOLERANCE_RADIANS
	var atmosphere_top := (
		float(_atmosphere_geometry.get("atmosphere_top_altitude_m", 0.0))
		if _has_atmosphere else 0.0
	)
	var atmosphere_active := _has_atmosphere and altitude < atmosphere_top
	var factors := _illumination_factors(
		clearance_radians, direct_visible, atmosphere_active
	)
	var optical := _optical_hints(
		altitude,
		radius,
		elevation_sine,
		direct_visible,
		atmosphere_active
	)
	if optical.has("contract_error"):
		return {
			"accepted": false,
			"reason": optical.get(
				"contract_error", &"optical_sample_rejected"
			),
		}.duplicate(true)
	var direct_transmittance := optical.get(
		"direct_transmittance_rgb", Color.WHITE
	) as Color
	var direct_scalar := float(
		optical.get("direct_transmittance_unitless", 1.0)
	)
	var directional_energy := (
		direct_scalar if direct_visible else 0.0
	)
	var directional_color := (
		_normalized_color(direct_transmittance, false)
		if direct_visible else Color.WHITE
	)
	var scattered_fraction := float(
		optical.get("horizon_scattered_fraction_unitless", 0.0)
	)
	var day_factor := float(factors.get("day_factor_unitless", 0.0))
	var twilight_factor := float(
		factors.get("twilight_factor_unitless", 0.0)
	)
	var ambient_energy := clampf(
		scattered_fraction * (
			DAY_AMBIENT_ENERGY_FACTOR * day_factor
			+ TWILIGHT_AMBIENT_ENERGY_FACTOR * twilight_factor
		),
		0.0,
		1.0
	)
	var sky_contribution := clampf(
		scattered_fraction * (day_factor + twilight_factor), 0.0, 1.0
	)
	var scattering_tint := (
		_scattering_tint() if atmosphere_active else Color.WHITE
	)
	return {
		"accepted": true,
		"reason": &"evaluated",
		"evaluation_schema_version": SCHEMA_VERSION,
		"world_id": _world_id,
		"atmosphere_profile_id": _atmosphere_profile_id,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"inputs": {
			"body_local_observer_m": observer,
			"normalized_body_to_sun": sun,
		}.duplicate(true),
		"geometry": {
			"frame": OBSERVATION_FRAME,
			"observer_radius_m": radius,
			"observer_altitude_m": altitude,
			"surface_up": surface_up,
			"sun_elevation_sine": elevation_sine,
			"sun_elevation_radians": elevation_radians,
			"sun_elevation_degrees": rad_to_deg(elevation_radians),
			"spherical_horizon_sine": horizon_sine,
			"spherical_horizon_elevation_radians": (
				horizon_elevation_radians
			),
			"spherical_horizon_elevation_degrees": rad_to_deg(
				horizon_elevation_radians
			),
			"sun_horizon_clearance_radians": clearance_radians,
			"sun_horizon_clearance_degrees": rad_to_deg(clearance_radians),
			"direct_sun_visible": direct_visible,
		}.duplicate(true),
		"classification": factors.duplicate(true),
		"directional_light_hint": {
			"color_space": &"linear_rgb_normalized_hint",
			"recommended_color": directional_color,
			"recommended_energy_factor_unitless": directional_energy,
			"direct_transmittance_rgb": direct_transmittance,
			"direct_transmittance_unitless": direct_scalar,
			"absolute_energy_or_lux": false,
		}.duplicate(true),
		"ambient_sky_hint": {
			"color_space": &"linear_rgb_normalized_hint",
			"recommended_ambient_color": scattering_tint,
			"recommended_ambient_energy_factor_unitless": ambient_energy,
			"recommended_sky_contribution_unitless": sky_contribution,
			"horizon_scattered_fraction_unitless": scattered_fraction,
			"multiple_scattering_physical": false,
		}.duplicate(true),
		"atmosphere": {
			"world_has_atmosphere": _has_atmosphere,
			"local_atmosphere_active": atmosphere_active,
			"atmosphere_top_altitude_m": atmosphere_top,
			"optical_hints": optical.duplicate(true),
		}.duplicate(true),
	}.duplicate(true)


func _illumination_factors(
	clearance_radians: float,
	direct_visible: bool,
	atmosphere_active: bool
) -> Dictionary:
	var day_factor := 0.0
	var twilight_factor := 0.0
	var night_factor := 0.0
	var state: StringName
	if direct_visible:
		day_factor = 1.0
		state = &"direct_daylight"
	elif absf(clearance_radians) <= ANGLE_BOUNDARY_TOLERANCE_RADIANS:
		if atmosphere_active:
			twilight_factor = 1.0
			state = &"atmospheric_horizon"
		else:
			night_factor = 1.0
			state = &"hard_horizon"
	elif atmosphere_active and clearance_radians \
			>= TWILIGHT_MIN_CLEARANCE_RADIANS \
			- ANGLE_BOUNDARY_TOLERANCE_RADIANS:
		var progress := clampf(
			(clearance_radians - TWILIGHT_MIN_CLEARANCE_RADIANS)
			/ -TWILIGHT_MIN_CLEARANCE_RADIANS,
			0.0,
			1.0
		)
		twilight_factor = progress * progress * (3.0 - 2.0 * progress)
		night_factor = 1.0 - twilight_factor
		state = (
			&"atmospheric_twilight_lower_boundary"
			if absf(
				clearance_radians - TWILIGHT_MIN_CLEARANCE_RADIANS
			) <= ANGLE_BOUNDARY_TOLERANCE_RADIANS
			else &"atmospheric_twilight"
		)
	else:
		night_factor = 1.0
		state = &"night"
	return {
		"state": state,
		"day_factor_unitless": day_factor,
		"twilight_factor_unitless": twilight_factor,
		"night_factor_unitless": night_factor,
		"atmospheric_twilight_available": atmosphere_active,
		"twilight_min_clearance_degrees": TWILIGHT_MIN_CLEARANCE_DEGREES,
		"factor_sum_unitless": day_factor + twilight_factor + night_factor,
	}.duplicate(true)


func _optical_hints(
	altitude: float,
	radius: float,
	elevation_sine: float,
	direct_visible: bool,
	atmosphere_active: bool
) -> Dictionary:
	var result := {
		"direct_path_distance_m": 0.0,
		"direct_path_uncapped_m": 0.0,
		"horizon_path_distance_m": 0.0,
		"horizon_path_uncapped_m": 0.0,
		"direct_transmittance_rgb": Color.WHITE,
		"direct_transmittance_unitless": 1.0,
		"horizon_transmittance_rgb": Color.WHITE,
		"horizon_transmittance_unitless": 1.0,
		"horizon_scattered_fraction_unitless": 0.0,
		"direct_sample": {},
		"horizon_sample": {},
	}
	if not atmosphere_active:
		return result.duplicate(true)
	var outer_radius := _body_radius_m + float(
		_atmosphere_geometry.get("atmosphere_top_altitude_m", 0.0)
	)
	var maximum_path := float(
		_atmosphere_optics.get("maximum_visibility_m", 0.0)
	)
	var horizon_uncapped := sqrt(maxf(
		outer_radius * outer_radius - radius * radius, 0.0
	))
	var horizon_path := minf(horizon_uncapped, maximum_path)
	var horizon_sample := _sampler.sample(
		altitude, horizon_path, 0.0, 0.0, 0.0
	)
	if not bool(horizon_sample.get("accepted", false)):
		return {"contract_error": &"horizon_sample_rejected"}
	var horizon_transmittance := horizon_sample.get(
		"optical_transmittance_rgb", Color.WHITE
	) as Color
	var horizon_scalar := _color_luminance(horizon_transmittance)
	result.horizon_path_uncapped_m = horizon_uncapped
	result.horizon_path_distance_m = horizon_path
	result.horizon_transmittance_rgb = horizon_transmittance
	result.horizon_transmittance_unitless = horizon_scalar
	result.horizon_scattered_fraction_unitless = clampf(
		1.0 - horizon_scalar, 0.0, 1.0
	)
	result.horizon_sample = horizon_sample.duplicate(true)
	if not direct_visible:
		return result.duplicate(true)
	var radial_projection := radius * elevation_sine
	var discriminant := maxf(
		radial_projection * radial_projection
		+ outer_radius * outer_radius - radius * radius,
		0.0
	)
	var direct_uncapped := maxf(
		-radial_projection + sqrt(discriminant), 0.0
	)
	var direct_path := minf(direct_uncapped, maximum_path)
	var direct_sample := _sampler.sample(
		altitude, direct_path, 0.0, 0.0, 0.0
	)
	if not bool(direct_sample.get("accepted", false)):
		return {"contract_error": &"direct_sample_rejected"}
	var direct_transmittance := direct_sample.get(
		"optical_transmittance_rgb", Color.WHITE
	) as Color
	result.direct_path_uncapped_m = direct_uncapped
	result.direct_path_distance_m = direct_path
	result.direct_transmittance_rgb = direct_transmittance
	result.direct_transmittance_unitless = _color_luminance(
		direct_transmittance
	)
	result.direct_sample = direct_sample.duplicate(true)
	return result.duplicate(true)


func _scattering_tint() -> Color:
	var rayleigh := _atmosphere_optics.get(
		"rayleigh_scattering_per_m", Color(0.0, 0.0, 0.0, 1.0)
	) as Color
	var mie := _atmosphere_optics.get(
		"mie_scattering_per_m", Color(0.0, 0.0, 0.0, 1.0)
	) as Color
	return _normalized_color(
		Color(
			rayleigh.r + mie.r,
			rayleigh.g + mie.g,
			rayleigh.b + mie.b,
			1.0
		),
		true
	)


func _normalized_color(value: Color, neutral_if_zero: bool) -> Color:
	var strongest := maxf(value.r, maxf(value.g, value.b))
	if strongest <= 0.0:
		return Color.WHITE if neutral_if_zero else Color(0.0, 0.0, 0.0, 1.0)
	return Color(
		clampf(value.r / strongest, 0.0, 1.0),
		clampf(value.g / strongest, 0.0, 1.0),
		clampf(value.b / strongest, 0.0, 1.0),
		1.0
	)


func _evaluation_is_valid(evaluation: Dictionary) -> bool:
	if not bool(evaluation.get("accepted", false)) \
			or evaluation.get("reason", &"") != &"evaluated" \
			or evaluation.get("world_id", &"") != _world_id \
			or evaluation.get("policy_version", &"") != POLICY_VERSION \
			or evaluation.get("equation_version", &"") != EQUATION_VERSION:
		return false
	if evaluation.get("geometry") is not Dictionary \
			or evaluation.get("classification") is not Dictionary \
			or evaluation.get("directional_light_hint") is not Dictionary \
			or evaluation.get("ambient_sky_hint") is not Dictionary \
			or evaluation.get("atmosphere") is not Dictionary:
		return false
	var geometry := evaluation.get("geometry", {}) as Dictionary
	var factors := evaluation.get("classification", {}) as Dictionary
	var directional := evaluation.get("directional_light_hint", {}) as Dictionary
	var ambient := evaluation.get("ambient_sky_hint", {}) as Dictionary
	for key: String in [
		"day_factor_unitless",
		"twilight_factor_unitless",
		"night_factor_unitless",
		"factor_sum_unitless",
	]:
		if not _is_finite_range(factors.get(key), 0.0, 1.0):
			return false
	if not is_equal_approx(float(factors.get("factor_sum_unitless")), 1.0):
		return false
	for key: String in [
		"observer_radius_m",
		"observer_altitude_m",
		"sun_elevation_sine",
		"sun_elevation_radians",
		"sun_elevation_degrees",
		"spherical_horizon_sine",
		"spherical_horizon_elevation_radians",
		"spherical_horizon_elevation_degrees",
		"sun_horizon_clearance_radians",
		"sun_horizon_clearance_degrees",
	]:
		if not _is_finite_number(geometry.get(key)):
			return false
	if geometry.get("surface_up") is not Vector3 \
			or not (geometry.get("surface_up") as Vector3).is_finite():
		return false
	if directional.get("recommended_color") is not Color \
			or ambient.get("recommended_ambient_color") is not Color:
		return false
	if not _color_is_bounded(
		directional.get("recommended_color") as Color
	) or not _color_is_bounded(
		ambient.get("recommended_ambient_color") as Color
	):
		return false
	for value: Variant in [
		directional.get("recommended_energy_factor_unitless"),
		directional.get("direct_transmittance_unitless"),
		ambient.get("recommended_ambient_energy_factor_unitless"),
		ambient.get("recommended_sky_contribution_unitless"),
		ambient.get("horizon_scattered_fraction_unitless"),
	]:
		if not _is_finite_range(value, 0.0, 1.0):
			return false
	return geometry.get("direct_sun_visible") is bool \
		and directional.get("absolute_energy_or_lux") is bool \
		and not bool(directional.get("absolute_energy_or_lux", true)) \
		and ambient.get("multiple_scattering_physical") is bool \
		and not bool(ambient.get("multiple_scattering_physical", true))


func _configuration_values_are_valid(
	world_snapshot: Dictionary,
	atmosphere_snapshot: Dictionary,
	atmosphere_geometry: Dictionary,
	atmosphere_optics: Dictionary,
	has_atmosphere: bool
) -> bool:
	if not bool(world_snapshot.get("valid", false)) \
			or int(world_snapshot.get("schema_version", 0)) \
			!= PlanetaryWorldDefinition.SCHEMA_VERSION:
		return false
	var body := world_snapshot.get("body", {}) as Dictionary
	if not _is_finite_range(
		body.get("radius_metres"),
		PlanetaryWorldDefinition.MIN_BODY_RADIUS_METRES,
		PlanetaryWorldDefinition.MAX_BODY_RADIUS_METRES
	) or bool(body.get("has_atmosphere", false)) != has_atmosphere:
		return false
	if _configured and (
		world_snapshot.get("world_id", &"") != _world_id
		or float(body.get("radius_metres", 0.0)) != _body_radius_m
	):
		return false
	if not has_atmosphere:
		return atmosphere_snapshot.is_empty() \
			and atmosphere_geometry.is_empty() and atmosphere_optics.is_empty()
	if not bool(atmosphere_snapshot.get("valid", false)) \
			or int(atmosphere_snapshot.get("schema_version", 0)) \
			!= PlanetaryAtmosphereProfile.SCHEMA_VERSION \
			or atmosphere_snapshot.get("profile_id", &"") \
			!= body.get("atmosphere_definition_id", &""):
		return false
	if atmosphere_snapshot.get("geometry") is not Dictionary \
			or atmosphere_snapshot.get("optics") is not Dictionary \
			or (atmosphere_snapshot.get("geometry") as Dictionary) \
			!= atmosphere_geometry \
			or (atmosphere_snapshot.get("optics") as Dictionary) \
			!= atmosphere_optics:
		return false
	if _configured and atmosphere_snapshot.get("profile_id", &"") \
			!= _atmosphere_profile_id:
		return false
	if float(atmosphere_geometry.get("planet_radius_m", NAN)) \
			!= float(body.get("radius_metres", NAN)):
		return false
	return _is_finite_range(
		atmosphere_geometry.get("atmosphere_top_altitude_m"),
		1.0,
		PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M
	) and _is_finite_range(
		atmosphere_optics.get("maximum_visibility_m"),
		0.1,
		PlanetaryAtmosphereProfile.MAX_VISIBILITY_M
	)


func _result(
	accepted: bool,
	reason: StringName,
	details: Dictionary = {}
) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"configured": _configured,
		"world_id": _world_id,
	}
	for key: Variant in details:
		result[key] = details[key]
	return result.duplicate(true)


static func _color_luminance(value: Color) -> float:
	return clampf(
		Vector3(value.r, value.g, value.b).dot(LUMINANCE_WEIGHTS),
		0.0,
		1.0
	)


static func _color_is_bounded(value: Color) -> bool:
	return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) \
		and value.r >= 0.0 and value.r <= 1.0 \
		and value.g >= 0.0 and value.g <= 1.0 \
		and value.b >= 0.0 and value.b <= 1.0 and value.a == 1.0


static func _has_exact_zero_authority(value: Dictionary) -> bool:
	if value.size() != AUTHORITY.size():
		return false
	for key: String in AUTHORITY:
		if not value.has(key) or value[key] is not bool or bool(value[key]):
			return false
	return true


static func _evidence_contract_is_valid(value: Dictionary) -> bool:
	return value.size() == 4 \
		and value.get("content_class") == &"NEW" \
		and value.get("content_class") is StringName \
		and value.get("status") == &"modern_interpretation" \
		and value.get("status") is StringName \
		and value.get("source_bounded") is bool \
		and not bool(value.get("source_bounded", true)) \
		and value.get("confidence") == &"none" \
		and value.get("confidence") is StringName


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_finite_range(
	value: Variant,
	minimum: float,
	maximum: float
) -> bool:
	return _is_finite_number(value) \
		and float(value) >= minimum and float(value) <= maximum
