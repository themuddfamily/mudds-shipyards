class_name PlanetaryAtmospherePresentationEnvelope
extends RefCounted

## Pure spatial presentation envelope for hard atmosphere boundaries.
##
## Configuration freezes one validated atmosphere profile plus four explicit
## presentation-only widths. Evaluation consumes a complete caller observation
## and returns detached smoothstep weights. The raw sampler/profile boundaries
## remain published unchanged. This policy owns no renderer, adapter, clock,
## delta, hysteresis, world, gameplay, or streaming state.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"planetary_atmosphere_presentation_envelope_v1"
const EQUATION_VERSION: StringName = &"one_sided_spatial_smoothstep_v1"
const ALTITUDE_DATUM: StringName = &"meters_from_profile_reference_surface"
const SUN_CLEARANCE_DATUM: StringName = &"signed_radians_above_spherical_horizon"
const MAX_SUN_CLEARANCE_RADIANS := PI
const SUN_DIRECT_VISIBILITY_BOUNDARY_RADIANS := (
	PlanetarySunLightingPolicy.ANGLE_BOUNDARY_TOLERANCE_RADIANS
)
const OBSERVATION_KEYS := [
	"altitude_m",
	"sun_horizon_clearance_radians",
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
	"atmosphere_sampler": false,
	"profile_endpoint_mutation": false,
	"presentation_adapter": false,
	"renderer_application": false,
	"environment": false,
	"sky_or_material": false,
	"directional_light": false,
	"visible_cloud_layer": false,
	"time_or_clock": false,
	"delta_or_cadence": false,
	"hysteresis": false,
	"weather_selection": false,
	"ephemeris": false,
	"physics": false,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
	"origin_or_rebase": false,
}
const CAPABILITIES := {
	"one_sided_atmosphere_weight_implemented": true,
	"one_sided_cloud_base_weight_implemented": true,
	"one_sided_cloud_top_weight_implemented": true,
	"one_sided_sun_visibility_weight_implemented": true,
	"smoothstep_endpoint_derivatives_zero": true,
	"raw_boundary_truth_published": true,
	"stateless_cadence_independent_evaluation": true,
	"temporal_fade_implemented": false,
	"hysteresis_implemented": false,
	"renderer_adapter_integration_implemented": false,
	"renderer_application_implemented": false,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}

var _configured := false
var _profile_id: StringName = &""
var _source_profile_schema_version := 0
var _profile_snapshot: Dictionary = {}
var _geometry: Dictionary = {}
var _weather: Dictionary = {}
var _widths: Dictionary = {}


## Freezes one valid profile and four finite, positive, presentation-only
## widths. Rejected configuration remains retryable; successful configuration
## is immutable and retains no source Resource.
func configure(
	profile: PlanetaryAtmosphereProfile,
	atmosphere_top_width_m: Variant,
	cloud_base_width_m: Variant,
	cloud_top_width_m: Variant,
	sun_visibility_width_radians: Variant
) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if profile == null:
		return _result(false, &"missing_profile")
	var profile_audit := profile.get_audit_report()
	if not profile.is_definition_valid() \
			or not bool(profile_audit.get("valid", false)) \
			or not _has_exact_zero_authority(
				profile_audit.get("authority", {}) as Dictionary
			):
		return _result(false, &"invalid_profile", {
			"profile_errors": (
				profile_audit.get("errors", PackedStringArray()) \
					as PackedStringArray
			).duplicate(),
		})
	var geometry := profile.get_geometry_snapshot()
	var weather := profile.get_weather_snapshot()
	if not _profile_snapshots_are_valid(profile_audit, geometry, weather):
		return _result(false, &"invalid_profile_snapshot")

	var atmosphere_width := _decode_positive_width(
		atmosphere_top_width_m
	)
	if not bool(atmosphere_width.get("accepted", false)):
		return _result(false, &"invalid_atmosphere_top_width")
	var base_width := _decode_positive_width(cloud_base_width_m)
	if not bool(base_width.get("accepted", false)):
		return _result(false, &"invalid_cloud_base_width")
	var top_width := _decode_positive_width(cloud_top_width_m)
	if not bool(top_width.get("accepted", false)):
		return _result(false, &"invalid_cloud_top_width")
	var sun_width := _decode_positive_width(sun_visibility_width_radians)
	if not bool(sun_width.get("accepted", false)):
		return _result(false, &"invalid_sun_visibility_width")

	var reference_altitude := float(geometry.get("reference_altitude_m", NAN))
	var atmosphere_top := float(
		geometry.get("atmosphere_top_altitude_m", NAN)
	)
	var cloud_base := float(weather.get("cloud_base_altitude_m", NAN))
	var cloud_top := float(weather.get("cloud_top_altitude_m", NAN))
	var atmosphere_span := atmosphere_top - reference_altitude
	var cloud_span := cloud_top - cloud_base
	var atmosphere_width_value := float(atmosphere_width.get("value", NAN))
	var base_width_value := float(base_width.get("value", NAN))
	var top_width_value := float(top_width.get("value", NAN))
	var sun_width_value := float(sun_width.get("value", NAN))
	if atmosphere_width_value > atmosphere_span:
		return _result(false, &"atmosphere_top_width_out_of_bounds")
	if base_width_value > cloud_span:
		return _result(false, &"cloud_base_width_out_of_bounds")
	if top_width_value > cloud_span:
		return _result(false, &"cloud_top_width_out_of_bounds")
	if base_width_value + top_width_value > cloud_span:
		return _result(false, &"cloud_transition_overlap")
	if sun_width_value > (
		MAX_SUN_CLEARANCE_RADIANS
		- SUN_DIRECT_VISIBILITY_BOUNDARY_RADIANS
	):
		return _result(false, &"sun_visibility_width_out_of_bounds")

	var widths := {
		"atmosphere_top_width_m": atmosphere_width_value,
		"cloud_base_width_m": base_width_value,
		"cloud_top_width_m": top_width_value,
		"sun_visibility_width_radians": sun_width_value,
	}.duplicate(true)
	if not _width_contract_is_valid(widths, geometry, weather):
		return _result(false, &"width_contract_mismatch")

	_configured = true
	_profile_id = profile_audit.get("profile_id", &"") as StringName
	_source_profile_schema_version = int(
		profile_audit.get("schema_version", 0)
	)
	_profile_snapshot = profile_audit.duplicate(true)
	_geometry = geometry.duplicate(true)
	_weather = weather.duplicate(true)
	_widths = widths.duplicate(true)
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


## Evaluates one exact caller observation. Altitude is profile-relative metres;
## sun clearance is the signed radian result from the spherical-horizon policy.
## Validation and evaluation never retain or advance the observation.
func evaluate(observation: Variant) -> Dictionary:
	var decoded := _decode_observation(observation)
	if not bool(decoded.get("accepted", false)):
		return _result(
			false, StringName(decoded.get("reason", &"invalid_observation"))
		)
	if not _configured:
		return _result(false, &"not_configured")
	var input := decoded.get("input", {}) as Dictionary
	var altitude := float(input.get("altitude_m", NAN))
	var minimum_altitude := -float(_geometry.get("planet_radius_m", NAN))
	if altitude < minimum_altitude \
			or altitude > PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M:
		return _result(false, &"altitude_out_of_bounds")
	var evaluation := _build_evaluation(input)
	if not _evaluation_is_valid(evaluation):
		return _result(false, &"evaluation_contract_mismatch")
	return _result(true, &"evaluated", {
		"evaluation": evaluation.duplicate(true),
	})


func get_profile_snapshot() -> Dictionary:
	return _profile_snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"configured": _configured,
		"profile_id": _profile_id,
		"source_profile_schema_version": _source_profile_schema_version,
		"altitude_datum": ALTITUDE_DATUM,
		"sun_clearance_datum": SUN_CLEARANCE_DATUM,
		"observation_keys": OBSERVATION_KEYS.duplicate(),
		"profile": _profile_snapshot.duplicate(true),
		"geometry": _geometry.duplicate(true),
		"weather": _weather.duplicate(true),
		"widths": _widths.duplicate(true),
		"raw_boundaries": _raw_boundary_snapshot(),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("presentation_envelope_not_configured")
	else:
		if not _profile_snapshots_are_valid(
			_profile_snapshot, _geometry, _weather
		):
			errors.append("frozen_profile_contract_drift")
		if not _width_contract_is_valid(_widths, _geometry, _weather):
			errors.append("frozen_width_contract_drift")
	if not _has_exact_zero_authority(AUTHORITY):
		errors.append("authority_contract_drift")
	if not _has_exact_zero_adjacent_authority(ADJACENT_AUTHORITY):
		errors.append("adjacent_authority_contract_drift")
	if not _capability_contract_is_valid(CAPABILITIES):
		errors.append("capability_contract_drift")
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
		"equations": {
			"smoothstep": &"x_squared_times_three_minus_two_x",
			"atmosphere_coordinate": &"clamp_atmosphere_top_minus_altitude_over_width",
			"cloud_base_coordinate": &"clamp_altitude_minus_cloud_base_over_width",
			"cloud_top_coordinate": &"clamp_cloud_top_minus_altitude_over_width",
			"cloud_observer_weight": &"smooth_base_times_smooth_top",
			"sun_coordinate": &"clamp_clearance_minus_direct_boundary_over_width",
		}.duplicate(true),
		"boundary_policy": {
			"raw_atmosphere": &"altitude_below_top",
			"raw_cloud": &"base_inclusive_top_exclusive",
			"raw_direct_sun": &"clearance_strictly_above_policy_tolerance",
			"atmosphere_envelope": &"one_sided_inside_shell",
			"cloud_envelope": &"one_sided_inside_layer_non_overlapping",
			"sun_envelope": &"one_sided_visible_side",
		}.duplicate(true),
		"purity": {
			"stateless_evaluation": true,
			"delta_input": false,
			"clock_input": false,
			"retains_source_resource": false,
			"mutates_source_profile": false,
			"mutates_sampler_or_profile_endpoints": false,
		}.duplicate(true),
		"limitations": {
			"renderer_values_produced": false,
			"renderer_adapter_integrated": false,
			"transition_widths_are_physical_profile_fields": false,
			"temporal_teleport_smoothing_implemented": false,
			"hysteresis_implemented": false,
			"caller_observation_provenance_verified": false,
		}.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
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
	if not _is_finite_number(input.get("altitude_m")):
		return {"accepted": false, "reason": &"invalid_altitude"}
	if not _is_finite_range(
		input.get("sun_horizon_clearance_radians"),
		-MAX_SUN_CLEARANCE_RADIANS,
		MAX_SUN_CLEARANCE_RADIANS
	):
		return {"accepted": false, "reason": &"invalid_sun_clearance"}
	return {
		"accepted": true,
		"reason": &"valid_observation",
		"input": {
			"altitude_m": float(input.get("altitude_m")),
			"sun_horizon_clearance_radians": float(
				input.get("sun_horizon_clearance_radians")
			),
		}.duplicate(true),
	}


func _build_evaluation(input: Dictionary) -> Dictionary:
	var altitude := float(input.get("altitude_m", NAN))
	var clearance := float(
		input.get("sun_horizon_clearance_radians", NAN)
	)
	var atmosphere_top := float(
		_geometry.get("atmosphere_top_altitude_m", NAN)
	)
	var cloud_base := float(_weather.get("cloud_base_altitude_m", NAN))
	var cloud_top := float(_weather.get("cloud_top_altitude_m", NAN))
	var atmosphere_coordinate := clampf(
		(atmosphere_top - altitude)
		/ float(_widths.get("atmosphere_top_width_m", NAN)),
		0.0,
		1.0
	)
	var cloud_base_coordinate := clampf(
		(altitude - cloud_base)
		/ float(_widths.get("cloud_base_width_m", NAN)),
		0.0,
		1.0
	)
	var cloud_top_coordinate := clampf(
		(cloud_top - altitude)
		/ float(_widths.get("cloud_top_width_m", NAN)),
		0.0,
		1.0
	)
	var sun_coordinate := clampf(
		(clearance - SUN_DIRECT_VISIBILITY_BOUNDARY_RADIANS)
		/ float(_widths.get("sun_visibility_width_radians", NAN)),
		0.0,
		1.0
	)
	var atmosphere_weight := _smoothstep(atmosphere_coordinate)
	var cloud_base_weight := _smoothstep(cloud_base_coordinate)
	var cloud_top_weight := _smoothstep(cloud_top_coordinate)
	var sun_weight := _smoothstep(sun_coordinate)
	return {
		"evaluation_schema_version": SCHEMA_VERSION,
		"profile_id": _profile_id,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"inputs": input.duplicate(true),
		"raw_boundaries": {
			"inside_atmosphere": altitude < atmosphere_top,
			"vacuum": altitude >= atmosphere_top,
			"inside_cloud_layer": altitude >= cloud_base \
				and altitude < cloud_top,
			"direct_sun_visible": clearance \
				> SUN_DIRECT_VISIBILITY_BOUNDARY_RADIANS,
		}.duplicate(true),
		"normalized_coordinates": {
			"atmosphere_interior": atmosphere_coordinate,
			"cloud_base_interior": cloud_base_coordinate,
			"cloud_top_interior": cloud_top_coordinate,
			"sun_visible_side": sun_coordinate,
		}.duplicate(true),
		"weights": {
			"atmosphere_unitless": atmosphere_weight,
			"cloud_base_unitless": cloud_base_weight,
			"cloud_top_unitless": cloud_top_weight,
			"cloud_observer_unitless": clampf(
				cloud_base_weight * cloud_top_weight, 0.0, 1.0
			),
			"sun_visibility_unitless": sun_weight,
		}.duplicate(true),
	}.duplicate(true)


func _evaluation_is_valid(evaluation: Dictionary) -> bool:
	if evaluation.size() != 8 \
			or int(evaluation.get("evaluation_schema_version", 0)) \
			!= SCHEMA_VERSION \
			or evaluation.get("profile_id", &"") != _profile_id \
			or evaluation.get("policy_version", &"") != POLICY_VERSION \
			or evaluation.get("equation_version", &"") != EQUATION_VERSION \
			or evaluation.get("inputs") is not Dictionary \
			or evaluation.get("raw_boundaries") is not Dictionary \
			or evaluation.get("normalized_coordinates") is not Dictionary \
			or evaluation.get("weights") is not Dictionary:
		return false
	var raw := evaluation.get("raw_boundaries", {}) as Dictionary
	if raw.size() != 4:
		return false
	for key: String in raw:
		if raw.get(key) is not bool:
			return false
	var coordinates := evaluation.get(
		"normalized_coordinates", {}
	) as Dictionary
	var weights := evaluation.get("weights", {}) as Dictionary
	if coordinates.size() != 4 or weights.size() != 5:
		return false
	for value: Variant in coordinates.values():
		if not _is_finite_range(value, 0.0, 1.0):
			return false
	for value: Variant in weights.values():
		if not _is_finite_range(value, 0.0, 1.0):
			return false
	return true


func _raw_boundary_snapshot() -> Dictionary:
	if not _configured:
		return {}
	return {
		"reference_altitude_m": float(
			_geometry.get("reference_altitude_m", NAN)
		),
		"atmosphere_top_altitude_m": float(
			_geometry.get("atmosphere_top_altitude_m", NAN)
		),
		"cloud_base_altitude_m": float(
			_weather.get("cloud_base_altitude_m", NAN)
		),
		"cloud_top_altitude_m": float(
			_weather.get("cloud_top_altitude_m", NAN)
		),
		"sun_direct_visibility_boundary_radians": (
			SUN_DIRECT_VISIBILITY_BOUNDARY_RADIANS
		),
	}.duplicate(true)


func _profile_snapshots_are_valid(
	profile_snapshot: Dictionary,
	geometry: Dictionary,
	weather: Dictionary
) -> bool:
	if not bool(profile_snapshot.get("valid", false)) \
			or int(profile_snapshot.get("schema_version", 0)) \
			!= PlanetaryAtmosphereProfile.SCHEMA_VERSION \
			or not _has_exact_zero_authority(
				profile_snapshot.get("authority", {}) as Dictionary
			):
		return false
	var profile_id: Variant = profile_snapshot.get("profile_id")
	if profile_id is not StringName or (profile_id as StringName).is_empty():
		return false
	if _configured and profile_id != _profile_id:
		return false
	if profile_snapshot.get("geometry") is not Dictionary \
			or profile_snapshot.get("weather") is not Dictionary \
			or geometry != profile_snapshot.get("geometry") \
			or weather != profile_snapshot.get("weather"):
		return false
	if geometry.size() != 3 \
			or not _is_finite_range(
				geometry.get("planet_radius_m"),
				PlanetaryAtmosphereProfile.MIN_PLANET_RADIUS_M,
				PlanetaryAtmosphereProfile.MAX_PLANET_RADIUS_M
			) \
			or not _is_finite_range(
				geometry.get("reference_altitude_m"),
				0.0,
				PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M
			) \
			or not _is_finite_range(
				geometry.get("atmosphere_top_altitude_m"),
				1.0,
				PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M
			):
		return false
	var reference_altitude := float(geometry.get("reference_altitude_m"))
	var atmosphere_top := float(geometry.get("atmosphere_top_altitude_m"))
	if reference_altitude >= atmosphere_top:
		return false
	if not _is_finite_range(
		weather.get("cloud_base_altitude_m"),
		0.0,
		PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M
	) or not _is_finite_range(
		weather.get("cloud_top_altitude_m"),
		0.0,
		PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M
	):
		return false
	var cloud_base := float(weather.get("cloud_base_altitude_m"))
	var cloud_top := float(weather.get("cloud_top_altitude_m"))
	return cloud_base < cloud_top and cloud_top <= atmosphere_top


func _width_contract_is_valid(
	widths: Dictionary,
	geometry: Dictionary,
	weather: Dictionary
) -> bool:
	if widths.size() != 4:
		return false
	for key: String in [
		"atmosphere_top_width_m",
		"cloud_base_width_m",
		"cloud_top_width_m",
		"sun_visibility_width_radians",
	]:
		if not _is_finite_positive(widths.get(key)):
			return false
	var atmosphere_span := float(
		geometry.get("atmosphere_top_altitude_m", NAN)
	) - float(geometry.get("reference_altitude_m", NAN))
	var cloud_span := float(
		weather.get("cloud_top_altitude_m", NAN)
	) - float(weather.get("cloud_base_altitude_m", NAN))
	var atmosphere_width := float(widths.get("atmosphere_top_width_m"))
	var base_width := float(widths.get("cloud_base_width_m"))
	var top_width := float(widths.get("cloud_top_width_m"))
	var sun_width := float(widths.get("sun_visibility_width_radians"))
	return is_finite(atmosphere_span) and atmosphere_span > 0.0 \
		and is_finite(cloud_span) and cloud_span > 0.0 \
		and atmosphere_width <= atmosphere_span \
		and base_width <= cloud_span \
		and top_width <= cloud_span \
		and base_width + top_width <= cloud_span \
		and sun_width <= MAX_SUN_CLEARANCE_RADIANS \
			- SUN_DIRECT_VISIBILITY_BOUNDARY_RADIANS


func _result(
	accepted: bool,
	reason: StringName,
	details: Dictionary = {}
) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"configured": _configured,
		"profile_id": _profile_id,
	}
	for key: Variant in details:
		result[key] = details[key]
	return result.duplicate(true)


static func _decode_positive_width(value: Variant) -> Dictionary:
	if not _is_finite_positive(value):
		return {"accepted": false}
	return {"accepted": true, "value": float(value)}


static func _smoothstep(coordinate: float) -> float:
	var x := clampf(coordinate, 0.0, 1.0)
	return clampf(x * x * (3.0 - 2.0 * x), 0.0, 1.0)


static func _has_exact_zero_authority(value: Dictionary) -> bool:
	var keys := [
		"renderer", "gameplay", "streaming", "save", "network", "physics",
		"world_generation", "terrain_generation", "collision_generation",
		"origin_shift", "weather_clock", "audio",
	]
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key) or value.get(key) is not bool \
				or bool(value.get(key)):
			return false
	return true


static func _has_exact_zero_adjacent_authority(value: Dictionary) -> bool:
	var keys := [
		"atmosphere_sampler", "profile_endpoint_mutation",
		"presentation_adapter", "renderer_application", "environment",
		"sky_or_material", "directional_light", "visible_cloud_layer",
		"time_or_clock", "delta_or_cadence", "hysteresis",
		"weather_selection", "ephemeris", "physics", "gameplay",
		"streaming", "save", "network", "origin_or_rebase",
	]
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key) or value.get(key) is not bool \
				or bool(value.get(key)):
			return false
	return true


static func _capability_contract_is_valid(value: Dictionary) -> bool:
	return value == {
		"one_sided_atmosphere_weight_implemented": true,
		"one_sided_cloud_base_weight_implemented": true,
		"one_sided_cloud_top_weight_implemented": true,
		"one_sided_sun_visibility_weight_implemented": true,
		"smoothstep_endpoint_derivatives_zero": true,
		"raw_boundary_truth_published": true,
		"stateless_cadence_independent_evaluation": true,
		"temporal_fade_implemented": false,
		"hysteresis_implemented": false,
		"renderer_adapter_integration_implemented": false,
		"renderer_application_implemented": false,
	}


static func _evidence_contract_is_valid(value: Dictionary) -> bool:
	return value.size() == 4 \
		and value.get("content_class") is StringName \
		and value.get("content_class") == &"NEW" \
		and value.get("status") is StringName \
		and value.get("status") == &"modern_interpretation" \
		and value.get("source_bounded") is bool \
		and not bool(value.get("source_bounded", true)) \
		and value.get("confidence") is StringName \
		and value.get("confidence") == &"none"


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_finite_positive(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) > 0.0


static func _is_finite_range(
	value: Variant,
	minimum: float,
	maximum: float
) -> bool:
	return _is_finite_number(value) \
		and float(value) >= minimum and float(value) <= maximum
