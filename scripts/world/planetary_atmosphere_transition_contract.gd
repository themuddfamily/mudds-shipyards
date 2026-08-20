class_name PlanetaryAtmosphereTransitionContract
extends RefCounted

## Pure, caller-owned contract for one space-to-surface atmosphere observation.
##
## This is the documented game-scale seam for ROADMAP 1094. It composes the
## existing SI sampler, spatial presentation envelope, and opaque surface
## audio policy, then publishes one detached bounded observation. It does not
## create sky/cloud geometry, orient a light, resolve or play audio, simulate
## heat/compression, select weather, or own a clock/transition tween.

const SamplerScript := preload("res://scripts/world/planetary_atmosphere_sampler.gd")
const EnvelopeScript := preload(
	"res://scripts/world/planetary_atmosphere_presentation_envelope.gd"
)
const AudioPolicyScript := preload(
	"res://scripts/world/planetary_surface_audio_policy.gd"
)

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"planetary_atmosphere_transition_v1"
const EQUATION_VERSION: StringName = &"density_visibility_horizon_entry_audio_v1"
const UNIT_SYSTEM: StringName = &"game_scale_si"
const ALTITUDE_DATUM: StringName = &"meters_from_profile_reference_surface"
const DEFAULT_TRANSITION_WIDTHS := {
	"atmosphere_top_width_m": 1_000.0,
	"cloud_base_width_m": 500.0,
	"cloud_top_width_m": 500.0,
	"sun_visibility_width_radians": 0.02,
}
const OBSERVATION_KEYS := [
	"altitude_m",
	"path_distance_m",
	"speed_mps",
	"weather_scalar",
	"cloud_scalar",
	"sun_horizon_clearance_radians",
	"listener_context",
	"grounded",
	"ambient_wind_scalar_unitless",
]
const MAX_COMPRESSION_REFERENCE_SPEED_MPS := 340.0
const MAX_COMPRESSION_UNITLESS := 1.0
const CLOUD_SHADOWS_ARE_HINT_ONLY := true
const AUTHORITY := {
	"renderer": false,
	"physics": false,
	"audio": false,
	"weather_clock": false,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
	"world_generation": false,
	"origin_shift": false,
}
const CAPABILITIES := {
	"space_to_sky_transition_weight": true,
	"altitude_density_visibility": true,
	"horizon_and_aerial_perspective": true,
	"cloud_layer_and_shadow_hint": true,
	"entry_heat_and_compression_hints": true,
	"wind_weather_response": true,
	"interior_exterior_audio_routes": true,
	"renderer_application": false,
	"audio_playback": false,
	"physical_heat_or_compression": false,
	"cloud_shadow_renderer_application": false,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"scope": &"game_scale_atmosphere_transition_contract",
	"confidence": &"none",
}

var _configured := false
var _profile_id: StringName = &""
var _profile_snapshot: Dictionary = {}
var _geometry: Dictionary = {}
var _density: Dictionary = {}
var _weather: Dictionary = {}
var _entry_effects: Dictionary = {}
var _audio_hints: Dictionary = {}
var _widths: Dictionary = {}
var _sampler
var _envelope
var _audio_policy


## Configures all three policy layers atomically from one validated profile.
## The profile Resource is not retained after a successful configuration.
func configure(
	profile: PlanetaryAtmosphereProfile,
	transition_widths: Dictionary = {}
) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if profile == null:
		return _result(false, &"missing_profile")
	var widths := DEFAULT_TRANSITION_WIDTHS.duplicate(true)
	if not transition_widths.is_empty():
		widths = transition_widths.duplicate(true)
	var profile_audit := profile.get_audit_report()
	if not profile.is_definition_valid() or not bool(profile_audit.get("valid", false)):
		return _result(false, &"invalid_profile", {
			"profile_errors": (
				profile_audit.get("errors", PackedStringArray())
				as PackedStringArray
			).duplicate(),
		})
	var sampler = SamplerScript.new()
	var sampler_result: Dictionary = sampler.configure(profile)
	if not bool(sampler_result.get("accepted", false)):
		return _result(false, &"sampler_configuration_failed")
	var envelope = EnvelopeScript.new()
	var envelope_result: Dictionary = envelope.configure(
		profile,
		widths.get("atmosphere_top_width_m", NAN),
		widths.get("cloud_base_width_m", NAN),
		widths.get("cloud_top_width_m", NAN),
		widths.get("sun_visibility_width_radians", NAN)
	)
	if not bool(envelope_result.get("accepted", false)):
		return _result(false, &"envelope_configuration_failed", {
			"envelope_reason": envelope_result.get("reason", &"invalid_widths"),
		})
	var audio_policy = AudioPolicyScript.new()
	var audio_result: Dictionary = audio_policy.configure(profile)
	if not bool(audio_result.get("accepted", false)):
		return _result(false, &"audio_policy_configuration_failed")
	var sampler_snapshot := sampler.get_snapshot()
	var geometry := sampler_snapshot.get("geometry", {}) as Dictionary
	var density := sampler_snapshot.get("density", {}) as Dictionary
	var weather := sampler_snapshot.get("weather", {}) as Dictionary
	var entry_effects := sampler_snapshot.get("entry_effects", {}) as Dictionary
	var audio_snapshot := audio_policy.get_snapshot()
	var audio_hints := audio_snapshot.get("audio_hints", {}) as Dictionary
	if not _configuration_contract_is_valid(
		profile_audit, geometry, density, weather, entry_effects,
		audio_hints, widths
	):
		return _result(false, &"configuration_contract_mismatch")
	_configured = true
	_profile_id = profile_audit.get("profile_id", &"") as StringName
	_profile_snapshot = profile_audit.duplicate(true)
	_geometry = geometry.duplicate(true)
	_density = density.duplicate(true)
	_weather = weather.duplicate(true)
	_entry_effects = entry_effects.duplicate(true)
	_audio_hints = audio_hints.duplicate(true)
	_widths = widths.duplicate(true)
	_sampler = sampler
	_envelope = envelope
	_audio_policy = audio_policy
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


## Evaluates one explicit observation. All values are instantaneous hints and
## are safe to sample at any caller cadence; no state is advanced or retained.
func evaluate(observation: Variant) -> Dictionary:
	var decoded := _decode_observation(observation)
	if not bool(decoded.get("accepted", false)):
		return _result(false, decoded.get("reason", &"invalid_observation"))
	if not _configured:
		return _result(false, &"not_configured")
	var input := decoded.get("input", {}) as Dictionary
	var sample: Dictionary = _sampler.sample(
		input.get("altitude_m"),
		input.get("path_distance_m"),
		input.get("speed_mps"),
		input.get("weather_scalar"),
		input.get("cloud_scalar")
	)
	if not bool(sample.get("accepted", false)):
		return _result(false, &"sampler_rejected_observation", {
			"sampler_reason": sample.get("reason", &"invalid_observation"),
		})
	var envelope_result: Dictionary = _envelope.evaluate({
		"altitude_m": input.get("altitude_m"),
		"sun_horizon_clearance_radians": input.get(
			"sun_horizon_clearance_radians"
		),
	})
	if not bool(envelope_result.get("accepted", false)):
		return _result(false, &"envelope_rejected_observation")
	var audio_result: Dictionary = _audio_policy.evaluate({
		"altitude_m": input.get("altitude_m"),
		"listener_context": input.get("listener_context"),
		"grounded": input.get("grounded"),
		"speed_mps": input.get("speed_mps"),
		"ambient_wind_scalar_unitless": input.get(
			"ambient_wind_scalar_unitless"
		),
	})
	if not bool(audio_result.get("accepted", false)):
		return _result(false, &"audio_policy_rejected_observation")
	var envelope_data := envelope_result.get("evaluation", {}) as Dictionary
	var audio_data := audio_result.get("evaluation", {}) as Dictionary
	var evaluation := _build_evaluation(
		input,
		sample,
		envelope_data,
		audio_data
	)
	if not _evaluation_is_valid(evaluation):
		return _result(false, &"evaluation_contract_mismatch")
	return _result(true, &"evaluated", {"evaluation": evaluation})


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"unit_system": UNIT_SYSTEM,
		"altitude_datum": ALTITUDE_DATUM,
		"configured": _configured,
		"profile_id": _profile_id,
		"profile": _profile_snapshot.duplicate(true),
		"geometry": _geometry.duplicate(true),
		"density": _density.duplicate(true),
		"weather": _weather.duplicate(true),
		"entry_effects": _entry_effects.duplicate(true),
		"audio_hints": _audio_hints.duplicate(true),
		"transition_widths": _widths.duplicate(true),
		"observation_keys": OBSERVATION_KEYS.duplicate(),
		"authority": AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("transition_contract_not_configured")
	else:
		if _sampler == null or _envelope == null or _audio_policy == null:
			errors.append("policy_layer_missing")
		elif not bool(_sampler.audit().get("valid", false)) \
				or not bool(_envelope.audit().get("valid", false)) \
				or not bool(_audio_policy.audit().get("valid", false)):
			errors.append("policy_layer_audit_invalid")
		if not _configuration_contract_is_valid(
			_profile_snapshot,
			_geometry,
			_density,
			_weather,
			_entry_effects,
			_audio_hints,
			_widths
		):
			errors.append("frozen_configuration_invalid")
	if not _has_exact_zero_authority(AUTHORITY):
		errors.append("authority_contract_drift")
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"units": {
			"altitude": &"metres",
			"path_distance": &"metres",
			"speed": &"metres_per_second",
			"density": &"kilograms_per_cubic_metre",
			"horizon_clearance": &"signed_radians",
			"audio_gain": &"decibels",
			"normalized_fields": &"unitless_0_to_1",
		}.duplicate(true),
		"boundary_policy": {
			"space_to_sky": &"atmosphere_top_is_vacuum; envelope_weight_fades_below_top",
			"density": &"exponential_scale_height; reference_clamp; exact_zero_at_top",
			"aerial_perspective": &"path_distance_and_density_weighted_fog_and_transmittance",
			"clouds": &"base_inclusive_top_exclusive; shadow_is_normalized_hint_only",
			"entry": &"heat_from_profile_entry_effect; compression=density*speed_ratio",
			"wind_weather": &"profile_wind_times_weather_scalar; bounded_vector",
			"audio": &"interior_and_cabin_route_to_interior; exterior_route_is_distinct",
		}.duplicate(true),
		"performance": {
			"evaluation_complexity": &"constant_time",
			"allocates_cloud_or_terrain_geometry": false,
			"iterates_particles_or_voxels": false,
			"caller_owns_sampling_cadence": true,
		}.duplicate(true),
		"limitations": {
			"renderer_application": false,
			"audio_playback": false,
			"physical_heat_or_compression": false,
			"cloud_shadow_renderer_application": false,
			"weather_selection_or_clock": false,
		}.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _build_evaluation(
	input: Dictionary,
	sample: Dictionary,
	envelope: Dictionary,
	audio: Dictionary
) -> Dictionary:
	var density_ratio := clampf(float(sample.get("density_ratio", 0.0)), 0.0, 1.0)
	var speed := float(input.get("speed_mps", 0.0))
	var speed_ratio := clampf(
		speed / MAX_COMPRESSION_REFERENCE_SPEED_MPS, 0.0, 1.0
	)
	var heat := clampf(float(sample.get("entry_effect_intensity", 0.0)), 0.0, 1.0)
	var compression := clampf(
		density_ratio * speed_ratio, 0.0, MAX_COMPRESSION_UNITLESS
	)
	var weights := envelope.get("weights", {}) as Dictionary
	var cloud_factor := clampf(
		float(sample.get("cloud_layer_factor", 0.0)), 0.0, 1.0
	)
	var weather_scalar := float(input.get("weather_scalar", 0.0))
	var wind := sample.get("wind_velocity_mps", Vector3.ZERO) as Vector3
	var audio_routing := audio.get("routing", {}) as Dictionary
	var audio_mix := audio.get("mix", {}) as Dictionary
	return {
		"evaluation_schema_version": SCHEMA_VERSION,
		"profile_id": _profile_id,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"inputs": input.duplicate(true),
		"space_to_sky": {
			"phase": _phase_for_altitude(float(input.get("altitude_m"))),
			"inside_atmosphere": not bool(sample.get("vacuum", true)),
			"atmosphere_weight_unitless": clampf(
				float(weights.get("atmosphere_unitless", 0.0)), 0.0, 1.0
			),
			"horizon_visibility_weight_unitless": clampf(
				float(weights.get("sun_visibility_unitless", 0.0)), 0.0, 1.0
			),
		}.duplicate(true),
		"density_visibility": {
			"density_ratio": density_ratio,
			"density_kg_m3": clampf(float(sample.get("density_kg_m3", 0.0)), 0.0, 100.0),
			"visibility_m": maxf(float(sample.get("visibility_m", 0.0)), 0.0),
			"fog_factor_unitless": clampf(float(sample.get("fog_factor", 0.0)), 0.0, 1.0),
			"optical_transmittance_unitless": clampf(
				float(sample.get("optical_transmittance_unitless", 0.0)), 0.0, 1.0
			),
			"path_distance_m": float(input.get("path_distance_m")),
		}.duplicate(true),
		"clouds": {
			"layer_factor_unitless": cloud_factor,
			"shadow_factor_unitless": cloud_factor,
			"base_inclusive_top_exclusive": true,
			"shadow_hint_only": CLOUD_SHADOWS_ARE_HINT_ONLY,
			"renderer_shadow_applied": false,
			"weather_scalar": weather_scalar,
		}.duplicate(true),
		"entry": {
			"heat_intensity_unitless": heat,
			"compression_intensity_unitless": compression,
			"speed_ratio_unitless": speed_ratio,
			"physical_effect_applied": false,
		}.duplicate(true),
		"wind_weather": {
			"wind_velocity_mps": wind,
			"weather_scalar": weather_scalar,
			"effective_weather_intensity_unitless": clampf(
				float((sample.get("inputs", {}) as Dictionary).get(
					"effective_weather_intensity_unitless", 0.0
				)), 0.0, 1.0
			),
			"wind_response_bounded": true,
		}.duplicate(true),
		"audio": {
			"selected_route": audio_routing.get("selected_route", &""),
			"selected_audio_profile_id": audio_routing.get(
				"selected_audio_profile_id", &""
			),
			"interior_route_unitless": clampf(
				float(audio_mix.get("interior_route_unitless", 0.0)), 0.0, 1.0
			),
			"exterior_route_unitless": clampf(
				float(audio_mix.get("exterior_route_unitless", 0.0)), 0.0, 1.0
			),
			"recommended_gain_db": float(
				(audio.get("gain", {}) as Dictionary).get(
					"recommended_gain_db", 0.0
				)
			),
			"playback_requested": false,
		}.duplicate(true),
		"sampler": sample.duplicate(true),
		"envelope": envelope.duplicate(true),
		"audio_policy": audio.duplicate(true),
	}.duplicate(true)


func _phase_for_altitude(altitude_m: float) -> StringName:
	var reference := float(_geometry.get("reference_altitude_m", 0.0))
	var top := float(_geometry.get("atmosphere_top_altitude_m", 0.0))
	var cloud_base := float(_weather.get("cloud_base_altitude_m", 0.0))
	var cloud_top := float(_weather.get("cloud_top_altitude_m", 0.0))
	if altitude_m >= top:
		return &"space_vacuum"
	if altitude_m < reference:
		return &"below_reference_surface"
	if altitude_m < cloud_base:
		return &"lower_atmosphere"
	if altitude_m < cloud_top:
		return &"cloud_layer"
	return &"upper_atmosphere"


func _decode_observation(observation: Variant) -> Dictionary:
	if observation is not Dictionary:
		return {"accepted": false, "reason": &"invalid_observation_schema"}
	var source := observation as Dictionary
	if source.size() != OBSERVATION_KEYS.size():
		return {"accepted": false, "reason": &"invalid_observation_schema"}
	for key: String in OBSERVATION_KEYS:
		if not source.has(key):
			return {"accepted": false, "reason": &"invalid_observation_schema"}
	for key: String in [
		"altitude_m", "path_distance_m", "speed_mps", "weather_scalar",
		"cloud_scalar", "sun_horizon_clearance_radians",
		"ambient_wind_scalar_unitless",
	]:
		if not _is_finite_number(source.get(key)):
			return {"accepted": false, "reason": &"invalid_observation_value"}
	var context: Variant = source.get("listener_context")
	if context is not StringName or not [ &"exterior", &"interior", &"cabin" ].has(context):
		return {"accepted": false, "reason": &"invalid_listener_context"}
	if source.get("grounded") is not bool:
		return {"accepted": false, "reason": &"invalid_grounded_state"}
	var input := source.duplicate(true)
	for key: String in [
		"altitude_m", "path_distance_m", "speed_mps", "weather_scalar",
		"cloud_scalar", "sun_horizon_clearance_radians",
		"ambient_wind_scalar_unitless",
	]:
		input[key] = float(input.get(key))
	return {"accepted": true, "reason": &"valid_observation", "input": input}


func _configuration_contract_is_valid(
	profile_snapshot: Dictionary,
	geometry: Dictionary,
	density: Dictionary,
	weather: Dictionary,
	entry_effects: Dictionary,
	audio_hints: Dictionary,
	widths: Dictionary
) -> bool:
	if not bool(profile_snapshot.get("valid", false)) \
			or profile_snapshot.get("profile_id", &"") is not StringName:
		return false
	if geometry.size() != 3 or density.size() != 3 \
			or weather.size() != 5 or entry_effects.size() != 4:
		return false
	var reference := float(geometry.get("reference_altitude_m", NAN))
	var top := float(geometry.get("atmosphere_top_altitude_m", NAN))
	var cloud_base := float(weather.get("cloud_base_altitude_m", NAN))
	var cloud_top := float(weather.get("cloud_top_altitude_m", NAN))
	if not is_finite(reference) or not is_finite(top) or not is_finite(cloud_base) \
			or not is_finite(cloud_top) or reference >= cloud_base \
			or cloud_base >= cloud_top or cloud_top >= top:
		return false
	for key: String in [
		"atmosphere_top_width_m", "cloud_base_width_m", "cloud_top_width_m",
		"sun_visibility_width_radians",
	]:
		if not _is_finite_positive(widths.get(key)):
			return false
	var exterior: Variant = audio_hints.get("exterior_audio_profile_id")
	var interior: Variant = audio_hints.get("interior_audio_profile_id")
	return exterior is StringName and interior is StringName \
			and not (exterior as StringName).is_empty() \
			and not (interior as StringName).is_empty()


func _evaluation_is_valid(value: Dictionary) -> bool:
	if value.get("profile_id", &"") != _profile_id \
			or value.get("policy_version", &"") != POLICY_VERSION:
		return false
	for key: String in [
		"space_to_sky", "density_visibility", "clouds", "entry",
		"wind_weather", "audio", "sampler", "envelope", "audio_policy",
	]:
		if value.get(key) is not Dictionary:
			return false
	var space := value.get("space_to_sky", {}) as Dictionary
	var density := value.get("density_visibility", {}) as Dictionary
	var entry := value.get("entry", {}) as Dictionary
	for key: String in [
		"atmosphere_weight_unitless", "horizon_visibility_weight_unitless",
	]:
		if not _is_unit_interval(space.get(key)):
			return false
	for key: String in [
		"density_ratio", "fog_factor_unitless",
		"optical_transmittance_unitless",
	]:
		if not _is_unit_interval(density.get(key)):
			return false
	for key: String in [
		"heat_intensity_unitless", "compression_intensity_unitless",
		"speed_ratio_unitless",
	]:
		if not _is_unit_interval(entry.get(key)):
			return false
	return true


func _has_exact_zero_authority(value: Dictionary) -> bool:
	if value.size() != AUTHORITY.size():
		return false
	for key: String in AUTHORITY:
		if value.get(key) != false:
			return false
	return true


func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


func _is_finite_positive(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) > 0.0


func _is_unit_interval(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) >= 0.0 and float(value) <= 1.0


func _result(accepted: bool, reason: StringName, details: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"configured": _configured,
		"profile_id": _profile_id,
	}
	for key: Variant in details:
		result[key] = details[key]
	return result.duplicate(true)
