class_name PlanetarySurfaceAudioPolicy
extends RefCounted

## Pure recommendation policy for opaque planetary atmosphere audio routes.
##
## Configuration freezes one valid atmosphere profile and a private sampler.
## Evaluation accepts only explicit caller observations and returns detached
## route, gain, endpoint-mix, and intensity hints. This policy never resolves an
## audio profile ID, owns a voice or mixer, plays audio, advances a clock,
## validates actor state, or applies any result.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"planetary_surface_audio_v1"
const EQUATION_VERSION: StringName = &"density_max_airflow_hints_v1"
const ALTITUDE_DATUM: StringName = &"meters_from_profile_reference_surface"

## NEW game-scale policy tuning, not an authored atmosphere-profile field.
## Airborne movement reaches its normalized endpoint at this speed and remains
## clamped above it. Entry-effect speed thresholds are intentionally unrelated.
const FULL_MOVEMENT_AIRFLOW_SPEED_MPS := 100.0
const MAX_OBSERVED_SPEED_MPS := 100_000.0

const LISTENER_CONTEXTS := [
	&"exterior",
	&"interior",
	&"cabin",
]
const OBSERVATION_KEYS := [
	"altitude_m",
	"listener_context",
	"grounded",
	"speed_mps",
	"ambient_wind_scalar_unitless",
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
	"audio_profile_resolution": false,
	"audio_resource_loading": false,
	"playback": false,
	"voice_allocation": false,
	"bus_or_mixer": false,
	"smooth_crossfade": false,
	"crossfade_clock": false,
	"listener_context_truth": false,
	"grounded_truth": false,
	"weather_selection": false,
	"weather_clock": false,
	"wind_simulation": false,
	"movement": false,
	"physics": false,
	"streaming": false,
	"gameplay": false,
	"save": false,
	"network": false,
}
const CAPABILITIES := {
	"routing_gain_hint_implemented": true,
	"density_weighted_intensity_hint_implemented": true,
	"instantaneous_context_mix_endpoints_implemented": true,
	"cabin_aliases_interior": true,
	"audio_profile_resolution_implemented": false,
	"playback_implemented": false,
	"mixer_implemented": false,
	"smooth_crossfade_implemented": false,
	"clock_implemented": false,
	"weather_selection_implemented": false,
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
var _audio_hints: Dictionary = {}
var _sampler: PlanetaryAtmosphereSampler


## Freezes detached value snapshots from one currently valid atmosphere
## profile. Rejected configuration is retryable; accepted configuration is
## immutable and retains no caller Resource.
func configure(profile: PlanetaryAtmosphereProfile) -> Dictionary:
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
	var audio_hints := profile.get_audio_hint_snapshot()
	if not _frozen_contract_is_valid(
		profile_audit, geometry, weather, audio_hints
	):
		return _result(false, &"invalid_profile_snapshot")
	var sampler := PlanetaryAtmosphereSampler.new()
	var sampler_result := sampler.configure(profile)
	if not bool(sampler_result.get("accepted", false)) \
			or not bool(sampler.audit().get("valid", false)):
		return _result(false, &"sampler_configuration_failed")

	_configured = true
	_profile_id = profile_audit.get("profile_id", &"") as StringName
	_source_profile_schema_version = int(
		profile_audit.get("schema_version", 0)
	)
	_profile_snapshot = profile_audit.duplicate(true)
	_geometry = geometry.duplicate(true)
	_weather = weather.duplicate(true)
	_audio_hints = audio_hints.duplicate(true)
	_sampler = sampler
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


## Evaluates one complete caller observation. The dictionary shape is exact:
## altitude_m, listener_context, grounded, speed_mps, and
## ambient_wind_scalar_unitless. Shape and field-type failures take precedence
## over not_configured; configured profile bounds and sampling follow.
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
	var planet_radius := float(_geometry.get("planet_radius_m", NAN))
	if altitude < -planet_radius \
			or altitude \
			> PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M:
		return _result(false, &"altitude_out_of_bounds")

	var sample := _sampler.sample(
		altitude,
		0.0,
		0.0,
		float(input.get("ambient_wind_scalar_unitless", 0.0)),
		0.0
	)
	if not bool(sample.get("accepted", false)):
		return _result(
			false, StringName(sample.get("reason", &"sample_rejected"))
		)
	var evaluation := _build_evaluation(input, sample)
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
		"full_movement_airflow_speed_mps": (
			FULL_MOVEMENT_AIRFLOW_SPEED_MPS
		),
		"maximum_observed_speed_mps": MAX_OBSERVED_SPEED_MPS,
		"listener_contexts": LISTENER_CONTEXTS.duplicate(),
		"observation_keys": OBSERVATION_KEYS.duplicate(),
		"profile": _profile_snapshot.duplicate(true),
		"geometry": _geometry.duplicate(true),
		"weather": _weather.duplicate(true),
		"audio_hints": _audio_hints.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("surface_audio_policy_not_configured")
	else:
		if not _frozen_contract_is_valid(
			_profile_snapshot, _geometry, _weather, _audio_hints
		):
			errors.append("frozen_profile_contract_drift")
		if _sampler == null \
				or not bool(_sampler.audit().get("valid", false)) \
				or _sampler.get_snapshot().get("profile_id", &"") \
				!= _profile_id:
			errors.append("sampler_contract_drift")
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
			"listener_context": &"exterior_or_interior_with_cabin_alias",
			"altitude": &"profile_reference_surface_and_half_open_atmosphere_shell",
			"atmosphere_top": &"exact_zero_intensity_route_identity_retained",
			"below_reference": &"sampler_reference_density_clamp",
			"grounded": &"suppresses_movement_airflow_only",
			"movement_speed": &"linear_to_new_policy_endpoint_then_clamped",
			"airflow_merge": &"maximum_not_sum",
			"context_mix": &"instantaneous_endpoints_not_timed_crossfade",
			"gain": &"authored_exterior_plus_context_attenuation_clamped",
			"validation_priority": &"shape_type_range_then_configuration_then_profile_altitude",
		},
		"purity": {
			"stateless_evaluation": true,
			"delta_input": false,
			"clock_input": false,
			"retains_source_resource": false,
			"mutates_source_profile": false,
			"mutates_sampler_during_evaluate": false,
		},
		"limitations": {
			"profile_ids_are_opaque_unresolved_hints": true,
			"cabin_has_distinct_authored_profile": false,
			"mix_values_are_crossfade_timing": false,
			"caller_context_provenance_verified": false,
			"caller_grounded_provenance_verified": false,
			"caller_wind_provenance_verified": false,
			"playable_audio_produced": false,
		},
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
	var context: Variant = input.get("listener_context")
	if context is not StringName \
			or not LISTENER_CONTEXTS.has(context as StringName):
		return {"accepted": false, "reason": &"invalid_listener_context"}
	if input.get("grounded") is not bool:
		return {"accepted": false, "reason": &"invalid_grounded_state"}
	if not _is_finite_number(input.get("altitude_m")):
		return {"accepted": false, "reason": &"invalid_altitude"}
	if not _is_finite_range(
		input.get("speed_mps"), 0.0, MAX_OBSERVED_SPEED_MPS
	):
		return {"accepted": false, "reason": &"invalid_speed"}
	if not _is_finite_range(
		input.get("ambient_wind_scalar_unitless"), 0.0, 1.0
	):
		return {"accepted": false, "reason": &"invalid_wind_scalar"}
	return {
		"accepted": true,
		"reason": &"valid_observation",
		"input": {
			"altitude_m": float(input.get("altitude_m")),
			"listener_context": context as StringName,
			"grounded": bool(input.get("grounded")),
			"speed_mps": float(input.get("speed_mps")),
			"ambient_wind_scalar_unitless": float(
				input.get("ambient_wind_scalar_unitless")
			),
		}.duplicate(true),
	}


func _build_evaluation(input: Dictionary, sample: Dictionary) -> Dictionary:
	var context := input.get("listener_context", &"") as StringName
	var grounded := bool(input.get("grounded", false))
	var altitude := float(input.get("altitude_m", NAN))
	var speed := float(input.get("speed_mps", NAN))
	var wind_scalar := float(
		input.get("ambient_wind_scalar_unitless", NAN)
	)
	var density_ratio := float(sample.get("density_ratio", NAN))
	var movement_speed_factor := clampf(
		speed / FULL_MOVEMENT_AIRFLOW_SPEED_MPS, 0.0, 1.0
	)
	var movement_airflow := 0.0 if grounded else movement_speed_factor
	var authored_weather_intensity := float(
		_weather.get("weather_intensity_unitless", NAN)
	)
	var ambient_airflow := clampf(
		authored_weather_intensity * wind_scalar, 0.0, 1.0
	)
	var merged_airflow := maxf(movement_airflow, ambient_airflow)
	var intensity := clampf(density_ratio * merged_airflow, 0.0, 1.0)

	var uses_interior_route := context != &"exterior"
	var selected_profile_id: StringName = (
		_audio_hints.get("interior_audio_profile_id", &"") as StringName
		if uses_interior_route
		else _audio_hints.get("exterior_audio_profile_id", &"") as StringName
	)
	var exterior_gain := float(
		_audio_hints.get("exterior_wind_gain_db", NAN)
	)
	var context_attenuation := (
		float(_audio_hints.get("interior_attenuation_db", NAN))
		if uses_interior_route else 0.0
	)
	var unclamped_gain := exterior_gain + context_attenuation
	var recommended_gain := clampf(
		unclamped_gain,
		PlanetaryAtmosphereProfile.MIN_AUDIO_GAIN_DB,
		PlanetaryAtmosphereProfile.MAX_AUDIO_GAIN_DB
	)
	var reference_altitude := float(
		_geometry.get("reference_altitude_m", NAN)
	)
	var atmosphere_top := float(
		_geometry.get("atmosphere_top_altitude_m", NAN)
	)
	var shell_state: StringName
	if altitude < reference_altitude:
		shell_state = &"below_reference_surface"
	elif altitude == reference_altitude:
		shell_state = &"reference_surface_boundary"
	elif altitude < atmosphere_top:
		shell_state = &"within_atmosphere_shell"
	elif altitude == atmosphere_top:
		shell_state = &"atmosphere_top_boundary"
	else:
		shell_state = &"above_atmosphere_shell"

	return {
		"evaluation_schema_version": SCHEMA_VERSION,
		"profile_id": _profile_id,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"inputs": input.duplicate(true),
		"altitude": {
			"datum": ALTITUDE_DATUM,
			"state": shell_state,
			"reference_altitude_m": reference_altitude,
			"atmosphere_top_altitude_m": atmosphere_top,
			"inside_atmosphere": not bool(sample.get("vacuum", true)),
			"below_reference_altitude": bool(
				sample.get("below_reference_altitude", false)
			),
		}.duplicate(true),
		"routing": {
			"selected_audio_profile_id": selected_profile_id,
			"selected_route": (
				&"interior" if uses_interior_route else &"exterior"
			),
			"listener_context": context,
			"cabin_aliases_interior": context == &"cabin",
			"profile_id_resolved": false,
			"playback_requested": false,
			"available_profile_ids": {
				"exterior": _audio_hints.get(
					"exterior_audio_profile_id", &""
				),
				"interior": _audio_hints.get(
					"interior_audio_profile_id", &""
				),
			}.duplicate(true),
		}.duplicate(true),
		"gain": {
			"authored_exterior_gain_db": exterior_gain,
			"authored_interior_attenuation_db": float(
				_audio_hints.get("interior_attenuation_db", NAN)
			),
			"selected_base_gain_db": exterior_gain,
			"selected_context_attenuation_db": context_attenuation,
			"unclamped_recommended_gain_db": unclamped_gain,
			"recommended_gain_db": recommended_gain,
			"gain_clamped": recommended_gain != unclamped_gain,
		}.duplicate(true),
		"mix": {
			"exterior_route_unitless": 0.0 if uses_interior_route else 1.0,
			"interior_route_unitless": 1.0 if uses_interior_route else 0.0,
			"ground_contact_unitless": 1.0 if grounded else 0.0,
			"airborne_unitless": 0.0 if grounded else 1.0,
			"instantaneous_endpoints_only": true,
		}.duplicate(true),
		"intensity": {
			"density_ratio": density_ratio,
			"movement_speed_factor_unitless": movement_speed_factor,
			"movement_airflow_unitless": movement_airflow,
			"authored_weather_intensity_unitless": (
				authored_weather_intensity
			),
			"ambient_wind_unitless": ambient_airflow,
			"merged_airflow_unitless": merged_airflow,
			"recommended_intensity_unitless": intensity,
			"silence_recommended": intensity == 0.0,
		}.duplicate(true),
		"atmosphere_sample": sample.duplicate(true),
	}.duplicate(true)


func _evaluation_is_valid(evaluation: Dictionary) -> bool:
	if evaluation.get("profile_id", &"") != _profile_id \
			or evaluation.get("policy_version", &"") != POLICY_VERSION \
			or evaluation.get("equation_version", &"") != EQUATION_VERSION:
		return false
	if evaluation.get("inputs") is not Dictionary \
			or evaluation.get("altitude") is not Dictionary \
			or evaluation.get("routing") is not Dictionary \
			or evaluation.get("gain") is not Dictionary \
			or evaluation.get("mix") is not Dictionary \
			or evaluation.get("intensity") is not Dictionary \
			or evaluation.get("atmosphere_sample") is not Dictionary:
		return false
	var routing := evaluation.get("routing", {}) as Dictionary
	var gain := evaluation.get("gain", {}) as Dictionary
	var mix := evaluation.get("mix", {}) as Dictionary
	var intensity := evaluation.get("intensity", {}) as Dictionary
	var selected_id: Variant = routing.get("selected_audio_profile_id")
	if selected_id is not StringName \
			or not [
				_audio_hints.get("exterior_audio_profile_id", &""),
				_audio_hints.get("interior_audio_profile_id", &""),
			].has(selected_id):
		return false
	for key: String in [
		"authored_exterior_gain_db",
		"authored_interior_attenuation_db",
		"selected_base_gain_db",
		"selected_context_attenuation_db",
		"unclamped_recommended_gain_db",
		"recommended_gain_db",
	]:
		if not _is_finite_number(gain.get(key)):
			return false
	if not _is_finite_range(
		gain.get("recommended_gain_db"),
		PlanetaryAtmosphereProfile.MIN_AUDIO_GAIN_DB,
		PlanetaryAtmosphereProfile.MAX_AUDIO_GAIN_DB
	):
		return false
	for key: String in [
		"exterior_route_unitless",
		"interior_route_unitless",
		"ground_contact_unitless",
		"airborne_unitless",
	]:
		if not _is_finite_range(mix.get(key), 0.0, 1.0):
			return false
	for key: String in [
		"density_ratio",
		"movement_speed_factor_unitless",
		"movement_airflow_unitless",
		"authored_weather_intensity_unitless",
		"ambient_wind_unitless",
		"merged_airflow_unitless",
		"recommended_intensity_unitless",
	]:
		if not _is_finite_range(intensity.get(key), 0.0, 1.0):
			return false
	return routing.get("profile_id_resolved") is bool \
		and not bool(routing.get("profile_id_resolved", true)) \
		and routing.get("playback_requested") is bool \
		and not bool(routing.get("playback_requested", true)) \
		and bool(mix.get("instantaneous_endpoints_only", false)) \
		and bool(evaluation.get("atmosphere_sample", {}).get(
			"accepted", false
		))


func _frozen_contract_is_valid(
	profile_snapshot: Dictionary,
	geometry: Dictionary,
	weather: Dictionary,
	audio_hints: Dictionary
) -> bool:
	if not bool(profile_snapshot.get("valid", false)) \
			or int(profile_snapshot.get("schema_version", 0)) \
			!= PlanetaryAtmosphereProfile.SCHEMA_VERSION:
		return false
	var profile_id: Variant = profile_snapshot.get("profile_id")
	if profile_id is not StringName or (profile_id as StringName).is_empty():
		return false
	if _configured and profile_id != _profile_id:
		return false
	if not _is_finite_range(
		geometry.get("planet_radius_m"),
		PlanetaryAtmosphereProfile.MIN_PLANET_RADIUS_M,
		PlanetaryAtmosphereProfile.MAX_PLANET_RADIUS_M
	) or not _is_finite_range(
		geometry.get("reference_altitude_m"),
		0.0,
		PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M
	) or not _is_finite_range(
		geometry.get("atmosphere_top_altitude_m"),
		1.0,
		PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M
	):
		return false
	if float(geometry.get("reference_altitude_m")) \
			>= float(geometry.get("atmosphere_top_altitude_m")):
		return false
	if not _is_finite_range(
		weather.get("weather_intensity_unitless"), 0.0, 1.0
	):
		return false
	var exterior_id: Variant = audio_hints.get("exterior_audio_profile_id")
	var interior_id: Variant = audio_hints.get("interior_audio_profile_id")
	if exterior_id is not StringName or interior_id is not StringName \
			or (exterior_id as StringName).is_empty() \
			or (interior_id as StringName).is_empty():
		return false
	return _is_finite_range(
		audio_hints.get("exterior_wind_gain_db"),
		PlanetaryAtmosphereProfile.MIN_AUDIO_GAIN_DB,
		PlanetaryAtmosphereProfile.MAX_AUDIO_GAIN_DB
	) and _is_finite_range(
		audio_hints.get("interior_attenuation_db"),
		PlanetaryAtmosphereProfile.MIN_AUDIO_GAIN_DB,
		0.0
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
		"profile_id": _profile_id,
	}
	for key: Variant in details:
		result[key] = details[key]
	return result.duplicate(true)


static func _has_exact_zero_authority(value: Dictionary) -> bool:
	if value.size() != AUTHORITY.size():
		return false
	for key: String in AUTHORITY:
		if not value.has(key) or value[key] is not bool or bool(value[key]):
			return false
	return true


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


static func _is_finite_range(
	value: Variant,
	minimum: float,
	maximum: float
) -> bool:
	return _is_finite_number(value) \
		and float(value) >= minimum and float(value) <= maximum
