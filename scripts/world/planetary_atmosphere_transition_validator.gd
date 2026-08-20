class_name PlanetaryAtmosphereTransitionValidator
extends RefCounted

## Pure cross-check for one atmosphere sampler and its spatial presentation
## envelope. The validator freezes detached value snapshots, proves that their
## exact atmosphere/cloud boundaries agree, and exposes one combined sample
## for a later caller-owned renderer or entry/audio consumer.
##
## It owns no Resource reference, renderer, clock, delta, hysteresis, weather
## selection, physics, gameplay, streaming, persistence, or network authority.

const SamplerScript := preload("res://scripts/world/planetary_atmosphere_sampler.gd")
const EnvelopeScript := preload(
	"res://scripts/world/planetary_atmosphere_presentation_envelope.gd"
)

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"planetary_atmosphere_transition_validator_v1"
const UNIT_SYSTEM: StringName = &"game_scale_si"
const REQUIRED_WIDTH_KEYS := [
	"atmosphere_top_width_m",
	"cloud_base_width_m",
	"cloud_top_width_m",
	"sun_visibility_width_radians",
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
const CAPABILITIES := {
	"sampler_and_envelope_cross_check_implemented": true,
	"exact_atmosphere_top_agreement_implemented": true,
	"exact_cloud_endpoint_agreement_implemented": true,
	"detached_combined_sample_implemented": true,
	"temporal_fade_implemented": false,
	"renderer_application_implemented": false,
	"weather_selection_implemented": false,
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
var _sampler_snapshot: Dictionary = {}
var _envelope_snapshot: Dictionary = {}
var _geometry: Dictionary = {}
var _weather: Dictionary = {}
var _entry_effects: Dictionary = {}
var _widths: Dictionary = {}
var _sampler
var _envelope


## Freezes one validated profile and four positive presentation widths. The
## sampler and envelope are both configured before this validator commits, so
## rejected input leaves the object retryable and side-effect free.
func configure(
	profile: PlanetaryAtmosphereProfile,
	transition_widths: Dictionary
) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if profile == null:
		return _result(false, &"missing_profile")
	if not _width_schema_is_valid(transition_widths):
		return _result(false, &"invalid_transition_width_schema")
	var sampler := SamplerScript.new() as PlanetaryAtmosphereSampler
	var sampler_result := sampler.configure(profile)
	if not bool(sampler_result.get("accepted", false)):
		return _result(false, &"invalid_profile", {
			"sampler_reason": sampler_result.get("reason", &"invalid_profile"),
			"profile_errors": sampler_result.get("profile_errors", PackedStringArray()),
		})
	var envelope := EnvelopeScript.new() \
		as PlanetaryAtmospherePresentationEnvelope
	var envelope_result := envelope.configure(
		profile,
		transition_widths.get("atmosphere_top_width_m"),
		transition_widths.get("cloud_base_width_m"),
		transition_widths.get("cloud_top_width_m"),
		transition_widths.get("sun_visibility_width_radians")
	)
	if not bool(envelope_result.get("accepted", false)):
		return _result(false, &"invalid_transition_widths", {
			"envelope_reason": envelope_result.get("reason", &"invalid_widths"),
		})
	var geometry := sampler.get_snapshot().get("geometry", {}) as Dictionary
	var weather := sampler.get_snapshot().get("weather", {}) as Dictionary
	var entry_effects := sampler.get_snapshot().get(
		"entry_effects", {}
	) as Dictionary
	if not _transition_contract_is_valid(sampler, envelope, geometry, weather):
		return _result(false, &"transition_contract_mismatch")
	_configured = true
	_profile_id = sampler.get_snapshot().get("profile_id", &"") as StringName
	_profile_snapshot = profile.get_audit_report().duplicate(true)
	_sampler_snapshot = sampler.get_snapshot().duplicate(true)
	_envelope_snapshot = envelope.get_snapshot().duplicate(true)
	_geometry = geometry.duplicate(true)
	_weather = weather.duplicate(true)
	_entry_effects = entry_effects.duplicate(true)
	_widths = transition_widths.duplicate(true)
	_sampler = sampler
	_envelope = envelope
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


## Returns a deterministic, detached sample from both coupled policy layers.
## `sun_horizon_clearance_radians` remains a caller-owned spherical-horizon
## observation; this validator never derives an ephemeris or radial frame.
func evaluate(
	altitude_m: float,
	path_distance_m: float,
	speed_mps: float,
	weather_scalar: float = 1.0,
	cloud_scalar: float = 1.0,
	sun_horizon_clearance_radians: float = 0.0
) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not is_finite(sun_horizon_clearance_radians) \
			or sun_horizon_clearance_radians < -PI \
			or sun_horizon_clearance_radians > PI:
		return _result(false, &"invalid_sun_clearance")
	var sample = _sampler.sample(
		altitude_m,
		path_distance_m,
		speed_mps,
		weather_scalar,
		cloud_scalar
	)
	if not bool(sample.get("accepted", false)):
		return _result(false, &"sampler_rejected_observation", {
			"sampler_reason": sample.get("reason", &"invalid_observation"),
		})
	var envelope = _envelope.evaluate({
		"altitude_m": altitude_m,
		"sun_horizon_clearance_radians": sun_horizon_clearance_radians,
	})
	if not bool(envelope.get("accepted", false)):
		return _result(false, &"envelope_rejected_observation", {
			"envelope_reason": envelope.get("reason", &"invalid_observation"),
		})
	var sample_data := (sample.get("sample", {}) as Dictionary).duplicate(true)
	if sample_data.is_empty():
		# PlanetaryAtmosphereSampler returns its payload at the result root.
		sample_data = sample.duplicate(true)
	var envelope_data := (
		envelope.get("evaluation", {}) as Dictionary
	).duplicate(true)
	return _result(true, &"evaluated", {
		"sample": sample_data,
		"envelope": envelope_data,
		"phase": _phase_for_altitude(altitude_m),
	})


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"unit_system": UNIT_SYSTEM,
		"configured": _configured,
		"profile_id": _profile_id,
		"profile": _profile_snapshot.duplicate(true),
		"sampler": _sampler_snapshot.duplicate(true),
		"envelope": _envelope_snapshot.duplicate(true),
		"geometry": _geometry.duplicate(true),
		"weather": _weather.duplicate(true),
		"entry_effects": _entry_effects.duplicate(true),
		"transition_widths": _widths.duplicate(true),
		"boundary_policy": _boundary_policy(),
		"authority": AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("transition_validator_not_configured")
	else:
		if _sampler == null or _envelope == null \
				or not bool(_sampler.audit().get("valid", false)) \
				or not bool(_envelope.audit().get("valid", false)):
			errors.append("frozen_policy_contract_invalid")
		if not _transition_contract_is_valid(
			_sampler, _envelope, _geometry, _weather
		):
			errors.append("frozen_transition_contract_invalid")
	if not _has_exact_zero_authority(AUTHORITY):
		errors.append("authority_contract_drift")
	if not _capabilities_are_valid():
		errors.append("capability_contract_drift")
	errors.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"unit_system": UNIT_SYSTEM,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"boundary_policy": _boundary_policy(),
		"purity": {
			"delta_or_clock_input": false,
			"retains_source_resource": false,
			"mutates_source_profile": false,
			"mutates_sampler_or_envelope_during_evaluate": false,
		}.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _transition_contract_is_valid(
	sampler,
	envelope,
	geometry: Dictionary,
	weather: Dictionary
) -> bool:
	if sampler == null or envelope == null \
			or geometry.size() != 3 or weather.size() != 5:
		return false
	var atmosphere_top := float(geometry.get("atmosphere_top_altitude_m", NAN))
	var reference_altitude := float(geometry.get("reference_altitude_m", NAN))
	var cloud_base := float(weather.get("cloud_base_altitude_m", NAN))
	var cloud_top := float(weather.get("cloud_top_altitude_m", NAN))
	if not is_finite(atmosphere_top) or not is_finite(reference_altitude) \
			or not is_finite(cloud_base) or not is_finite(cloud_top) \
			or reference_altitude >= cloud_base \
			or cloud_base >= cloud_top or cloud_top >= atmosphere_top:
		return false
	var vacuum = sampler.sample(atmosphere_top, 0.0, 0.0)
	var vacuum_data = vacuum.duplicate(true)
	if not bool(vacuum_data.get("accepted", false)) \
			or not bool(vacuum_data.get("vacuum", false)) \
			or float(vacuum_data.get("density_ratio", -1.0)) != 0.0 \
			or float(vacuum_data.get("fog_factor", -1.0)) != 0.0 \
			or float(vacuum_data.get("cloud_layer_factor", -1.0)) != 0.0:
		return false
	var top_envelope = envelope.evaluate({
		"altitude_m": atmosphere_top,
		"sun_horizon_clearance_radians": 0.0,
	})
	if not bool(top_envelope.get("accepted", false)):
		return false
	var top_evaluation := top_envelope.get("evaluation", {}) as Dictionary
	var top_raw := top_evaluation.get("raw_boundaries", {}) as Dictionary
	var top_weights := top_evaluation.get("weights", {}) as Dictionary
	if bool(top_raw.get("inside_atmosphere", true)) \
			or not bool(top_raw.get("vacuum", false)) \
			or float(top_weights.get("atmosphere_unitless", -1.0)) != 0.0:
		return false
	var base_sample = sampler.sample(cloud_base, 0.0, 0.0)
	var top_cloud_sample = sampler.sample(cloud_top, 0.0, 0.0)
	if not bool(base_sample.get("accepted", false)) \
			or not bool(top_cloud_sample.get("accepted", false)) \
			or float(base_sample.get("cloud_layer_factor", -1.0)) <= 0.0 \
			or float(top_cloud_sample.get("cloud_layer_factor", -1.0)) != 0.0:
		return false
	for altitude: float in [cloud_base, cloud_top]:
		var edge = envelope.evaluate({
			"altitude_m": altitude,
			"sun_horizon_clearance_radians": 0.0,
		})
		if not bool(edge.get("accepted", false)):
			return false
		var raw := (edge.get("evaluation", {}) as Dictionary).get(
			"raw_boundaries", {}
		) as Dictionary
		var weights := (edge.get("evaluation", {}) as Dictionary).get(
			"weights", {}
		) as Dictionary
		var expected_inside_cloud := altitude == cloud_base
		if bool(raw.get("inside_cloud_layer", false)) != expected_inside_cloud \
				or float(weights.get("cloud_observer_unitless", -1.0)) != 0.0:
			return false
	return true


func _phase_for_altitude(altitude_m: float) -> StringName:
	var reference_altitude := float(_geometry.get("reference_altitude_m", 0.0))
	var atmosphere_top := float(
		_geometry.get("atmosphere_top_altitude_m", 0.0)
	)
	var cloud_base := float(_weather.get("cloud_base_altitude_m", 0.0))
	var cloud_top := float(_weather.get("cloud_top_altitude_m", 0.0))
	if altitude_m >= atmosphere_top:
		return &"space_vacuum"
	if altitude_m < reference_altitude:
		return &"below_reference_surface"
	if altitude_m < cloud_base:
		return &"lower_atmosphere"
	if altitude_m == cloud_base:
		return &"cloud_base_boundary"
	if altitude_m < cloud_top:
		return &"cloud_layer"
	if altitude_m == cloud_top:
		return &"cloud_top_boundary"
	return &"upper_atmosphere"


func _boundary_policy() -> Dictionary:
	return {
		"unit_system": UNIT_SYSTEM,
		"atmosphere": &"sampler_and_envelope_share_top; altitude_below_top",
		"cloud": &"sampler_base_inclusive_top_exclusive; envelope_edges_zero",
		"fog_and_optics": &"sampler_path_distance_in_metres",
		"entry_effect": &"sampler_altitude_and_speed_in_metres_and_mps",
		"sun": &"envelope_clearance_signed_radians; caller_owned",
	}.duplicate(true)


func _width_schema_is_valid(widths: Dictionary) -> bool:
	if widths.size() != REQUIRED_WIDTH_KEYS.size():
		return false
	for key: String in REQUIRED_WIDTH_KEYS:
		if not widths.has(key) or not _is_finite_positive(widths.get(key)):
			return false
	return true


func _is_finite_positive(value: Variant) -> bool:
	if value is not float and value is not int:
		return false
	var number := float(value)
	return is_finite(number) and number > 0.0


func _has_exact_zero_authority(authority: Dictionary) -> bool:
	if authority.size() != AUTHORITY.size():
		return false
	for key: String in AUTHORITY:
		if authority.get(key) != false:
			return false
	return true


func _capabilities_are_valid() -> bool:
	for key: String in CAPABILITIES:
		if CAPABILITIES.get(key) is not bool:
			return false
	return true


func _result(accepted: bool, reason: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: String in payload:
		result[key] = payload.get(key)
	return result.duplicate(true)
