extends SceneTree

const EnvelopeScript := preload(
	"res://scripts/world/planetary_atmosphere_presentation_envelope.gd"
)
const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)
const SamplerScript := preload(
	"res://scripts/world/planetary_atmosphere_sampler.gd"
)
const EXPECTED_ASSERTIONS := 31
const EXPECTED_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const EXPECTED_ADJACENT_AUTHORITY_KEYS := [
	"atmosphere_sampler", "profile_endpoint_mutation",
	"presentation_adapter", "renderer_application", "environment",
	"sky_or_material", "directional_light", "visible_cloud_layer",
	"time_or_clock", "delta_or_cadence", "hysteresis",
	"weather_selection", "ephemeris", "physics", "gameplay",
	"streaming", "save", "network", "origin_or_rebase",
]
const EXPECTED_CAPABILITIES := {
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
const EXPECTED_EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_configuration_and_profile_freeze()
	_test_width_validation_is_atomic()
	_test_atmosphere_envelope_and_raw_endpoint()
	_test_cloud_envelope_and_raw_endpoints()
	_test_sun_visibility_envelope_and_raw_endpoint()
	_test_observation_validation_is_atomic()
	_test_purity_detachment_and_exact_contracts()
	_test_structured_red_audit()
	_finish()


func _test_configuration_and_profile_freeze() -> void:
	var envelope := EnvelopeScript.new() as PlanetaryAtmospherePresentationEnvelope
	_check(
		envelope is RefCounted
		and not (envelope as Object).is_class("Node")
		and envelope.evaluate({}).reason == &"invalid_observation_schema"
		and envelope.evaluate(_observation()).reason == &"not_configured"
		and not bool(envelope.audit().valid),
		"the envelope is a pure RefCounted with validation priority and fail-closed audit"
	)
	var invalid_profile := _profile()
	invalid_profile.cloud_top_altitude_m = invalid_profile.cloud_base_altitude_m
	_check(
		envelope.configure(null, 1000.0, 500.0, 500.0, 0.02).reason
		== &"missing_profile"
		and envelope.configure(
			invalid_profile, 1000.0, 500.0, 500.0, 0.02
		).reason == &"invalid_profile"
		and not envelope.is_configured(),
		"missing and invalid profiles reject before any configuration state commits"
	)
	var profile := _profile()
	var configured := envelope.configure(
		profile, 1000.0, 500.0, 500.0, 0.02
	)
	var snapshot := envelope.get_snapshot()
	_check(
		bool(configured.accepted) and configured.reason == &"configured"
		and envelope.is_configured() and bool(envelope.audit().valid)
		and snapshot.profile_id == &"temperate_game_scale"
		and snapshot.policy_version \
			== &"planetary_atmosphere_presentation_envelope_v1"
		and snapshot.equation_version == &"one_sided_spatial_smoothstep_v1"
		and snapshot.widths == {
			"atmosphere_top_width_m": 1000.0,
			"cloud_base_width_m": 500.0,
			"cloud_top_width_m": 500.0,
			"sun_visibility_width_radians": 0.02,
		},
		"valid configuration freezes the exact profile identity, equation, and four widths"
	)
	_check(
		envelope.configure(_profile(), 1.0, 1.0, 1.0, 0.01).reason
		== &"already_configured",
		"successful configuration is immutable"
	)
	var before_evaluation := envelope.evaluate(_observation(19500.0, 0.01))
	profile.profile_id = &"caller_mutated"
	profile.atmosphere_top_altitude_m = 12000.0
	profile.cloud_base_altitude_m = 100.0
	profile.cloud_top_altitude_m = 200.0
	_check(
		envelope.get_snapshot() == snapshot
		and envelope.evaluate(_observation(19500.0, 0.01)) \
		== before_evaluation,
		"caller Resource mutation cannot retune frozen endpoints, widths, or output"
	)
	_check(
		snapshot.raw_boundaries == {
			"reference_altitude_m": 0.0,
			"atmosphere_top_altitude_m": 20000.0,
			"cloud_base_altitude_m": 3000.0,
			"cloud_top_altitude_m": 6000.0,
			"sun_direct_visibility_boundary_radians": 0.000001,
		},
		"snapshot publishes the unmodified profile and sun-policy endpoints exactly"
	)


func _test_width_validation_is_atomic() -> void:
	var cases := [
		[0.0, 500.0, 500.0, 0.02, &"invalid_atmosphere_top_width"],
		[NAN, 500.0, 500.0, 0.02, &"invalid_atmosphere_top_width"],
		[1000.0, -1.0, 500.0, 0.02, &"invalid_cloud_base_width"],
		[1000.0, 500.0, INF, 0.02, &"invalid_cloud_top_width"],
		[1000.0, 500.0, 500.0, 0.0, &"invalid_sun_visibility_width"],
		[20001.0, 500.0, 500.0, 0.02, &"atmosphere_top_width_out_of_bounds"],
		[1000.0, 3001.0, 1.0, 0.02, &"cloud_base_width_out_of_bounds"],
		[1000.0, 1.0, 3001.0, 0.02, &"cloud_top_width_out_of_bounds"],
		[1000.0, 1600.0, 1600.0, 0.02, &"cloud_transition_overlap"],
		[1000.0, 500.0, 500.0, PI, &"sun_visibility_width_out_of_bounds"],
	]
	var rejected_atomically := true
	for spec: Array in cases:
		var envelope := EnvelopeScript.new() \
			as PlanetaryAtmospherePresentationEnvelope
		var before := envelope.get_snapshot()
		var result := envelope.configure(
			_profile(), spec[0], spec[1], spec[2], spec[3]
		)
		rejected_atomically = rejected_atomically \
			and not bool(result.accepted) and result.reason == spec[4] \
			and not envelope.is_configured() \
			and envelope.get_snapshot() == before
	_check(
		rejected_atomically,
		"zero, nonfinite, negative, out-of-span, overlapping, and over-angle widths reject atomically"
	)
	var touching := EnvelopeScript.new() \
		as PlanetaryAtmospherePresentationEnvelope
	var accepted := touching.configure(
		_profile(), 20000.0, 1500.0, 1500.0,
		EnvelopeScript.MAX_SUN_CLEARANCE_RADIANS
			- EnvelopeScript.SUN_DIRECT_VISIBILITY_BOUNDARY_RADIANS
	)
	_check(
		bool(accepted.accepted) and bool(touching.audit().valid),
		"exact atmosphere span, touching cloud ramps, and maximum bounded sun width are valid non-overlapping endpoints"
	)


func _test_atmosphere_envelope_and_raw_endpoint() -> void:
	var envelope := _envelope()
	var inner := _evaluation(envelope, 19000.0, 0.1)
	var midpoint := _evaluation(envelope, 19500.0, 0.1)
	var just_below := _evaluation(envelope, 19999.999, 0.1)
	var exact_top := _evaluation(envelope, 20000.0, 0.1)
	var above := _evaluation(envelope, 21000.0, 0.1)
	_check(
		inner.weights.atmosphere_unitless == 1.0
		and midpoint.normalized_coordinates.atmosphere_interior == 0.5
		and midpoint.weights.atmosphere_unitless == 0.5
		and just_below.weights.atmosphere_unitless > 0.0
		and just_below.weights.atmosphere_unitless < 0.000001,
		"atmosphere envelope is exact one inside, exact smoothstep midpoint, and tends to zero from below"
	)
	_check(
		not bool(just_below.raw_boundaries.vacuum)
		and bool(just_below.raw_boundaries.inside_atmosphere)
		and bool(exact_top.raw_boundaries.vacuum)
		and not bool(exact_top.raw_boundaries.inside_atmosphere)
		and exact_top.weights.atmosphere_unitless == 0.0
		and above.weights.atmosphere_unitless == 0.0,
		"raw atmosphere remains altitude-below-top while exact and above top have zero presentation weight"
	)
	var sampler := SamplerScript.new() as PlanetaryAtmosphereSampler
	var profile := _profile()
	sampler.configure(profile)
	var sampler_below := sampler.sample(19999.999, 0.0, 0.0)
	var sampler_top := sampler.sample(20000.0, 0.0, 0.0)
	_check(
		bool(just_below.raw_boundaries.vacuum) == bool(sampler_below.vacuum)
		and bool(exact_top.raw_boundaries.vacuum) == bool(sampler_top.vacuum),
		"published raw atmosphere truth matches the sampler's exact top endpoint"
	)
	var previous := 1.0
	var monotonic := true
	for altitude in [19000.0, 19250.0, 19500.0, 19750.0, 20000.0]:
		var weight := float(
			_evaluation(envelope, altitude, 0.1).weights.atmosphere_unitless
		)
		monotonic = monotonic and weight <= previous
		previous = weight
	_check(monotonic, "atmosphere weight is monotone toward the top boundary")


func _test_cloud_envelope_and_raw_endpoints() -> void:
	var envelope := _envelope()
	var below := _evaluation(envelope, 2999.999, 0.1)
	var base := _evaluation(envelope, 3000.0, 0.1)
	var base_mid := _evaluation(envelope, 3250.0, 0.1)
	var base_inner := _evaluation(envelope, 3500.0, 0.1)
	var top_inner := _evaluation(envelope, 5500.0, 0.1)
	var top_mid := _evaluation(envelope, 5750.0, 0.1)
	var just_below_top := _evaluation(envelope, 5999.999, 0.1)
	var top := _evaluation(envelope, 6000.0, 0.1)
	_check(
		below.weights.cloud_observer_unitless == 0.0
		and base.weights.cloud_observer_unitless == 0.0
		and base_mid.weights.cloud_base_unitless == 0.5
		and base_mid.weights.cloud_observer_unitless == 0.5
		and base_inner.weights.cloud_observer_unitless == 1.0,
		"cloud base is zero outside/at the raw endpoint and smoothsteps to one only inside"
	)
	_check(
		top_inner.weights.cloud_observer_unitless == 1.0
		and top_mid.weights.cloud_top_unitless == 0.5
		and top_mid.weights.cloud_observer_unitless == 0.5
		and just_below_top.weights.cloud_observer_unitless > 0.0
		and top.weights.cloud_observer_unitless == 0.0,
		"cloud top remains one before its interior band, smoothsteps down, and is exact zero at top"
	)
	_check(
		not bool(below.raw_boundaries.inside_cloud_layer)
		and bool(base.raw_boundaries.inside_cloud_layer)
		and bool(just_below_top.raw_boundaries.inside_cloud_layer)
		and not bool(top.raw_boundaries.inside_cloud_layer),
		"raw cloud truth remains the profile's base-inclusive, top-exclusive box"
	)
	var touching := EnvelopeScript.new() \
		as PlanetaryAtmospherePresentationEnvelope
	touching.configure(_profile(), 1000.0, 1500.0, 1500.0, 0.02)
	_check(
		_evaluation(touching, 4500.0, 0.1).weights.cloud_observer_unitless
		== 1.0,
		"non-overlapping cloud widths may touch at one exact full-weight interior point"
	)
	var sampler := SamplerScript.new() as PlanetaryAtmosphereSampler
	sampler.configure(_profile())
	_check(
		bool(base.raw_boundaries.inside_cloud_layer)
		== (float(sampler.sample(3000.0, 0.0, 0.0).cloud_layer_factor) > 0.0)
		and bool(top.raw_boundaries.inside_cloud_layer)
		== (float(sampler.sample(6000.0, 0.0, 0.0).cloud_layer_factor) > 0.0),
		"published cloud membership preserves both sampler endpoints exactly"
	)


func _test_sun_visibility_envelope_and_raw_endpoint() -> void:
	var envelope := _envelope()
	var boundary := EnvelopeScript.SUN_DIRECT_VISIBILITY_BOUNDARY_RADIANS
	var occulted := _evaluation(envelope, 1000.0, boundary - 0.001)
	var exact := _evaluation(envelope, 1000.0, boundary)
	var just_visible := _evaluation(envelope, 1000.0, boundary + 0.000001)
	var midpoint := _evaluation(envelope, 1000.0, boundary + 0.01)
	var full := _evaluation(envelope, 1000.0, boundary + 0.02)
	_check(
		occulted.weights.sun_visibility_unitless == 0.0
		and exact.weights.sun_visibility_unitless == 0.0
		and just_visible.weights.sun_visibility_unitless > 0.0
		and just_visible.weights.sun_visibility_unitless < 0.000001
		and midpoint.weights.sun_visibility_unitless == 0.5
		and full.weights.sun_visibility_unitless == 1.0,
		"sun weight is zero through the strict visibility endpoint and smoothsteps only on the visible side"
	)
	_check(
		not bool(occulted.raw_boundaries.direct_sun_visible)
		and not bool(exact.raw_boundaries.direct_sun_visible)
		and bool(just_visible.raw_boundaries.direct_sun_visible),
		"raw sun visibility preserves the policy's strict greater-than angular tolerance"
	)
	_check(
		bool(envelope.evaluate(_observation(0.0, -PI)).accepted)
		and bool(envelope.evaluate(_observation(0.0, PI)).accepted),
		"the complete finite signed angular-clearance domain is inclusive"
	)


func _test_observation_validation_is_atomic() -> void:
	var envelope := _envelope()
	var before := envelope.get_snapshot()
	var missing := _observation()
	missing.erase("altitude_m")
	var extra := _observation()
	extra["delta"] = 0.016
	_check(
		envelope.evaluate(null).reason == &"invalid_observation"
		and envelope.evaluate(missing).reason == &"invalid_observation_schema"
		and envelope.evaluate(extra).reason == &"invalid_observation_schema",
		"observation boundary rejects non-dictionaries, missing fields, and extras"
	)
	var invalid_altitude := _observation()
	invalid_altitude.altitude_m = NAN
	var boolean_altitude := _observation()
	boolean_altitude.altitude_m = true
	var invalid_clearance := _observation()
	invalid_clearance.sun_horizon_clearance_radians = INF
	var beyond_clearance := _observation()
	beyond_clearance.sun_horizon_clearance_radians = PI + 0.000001
	_check(
		envelope.evaluate(invalid_altitude).reason == &"invalid_altitude"
		and envelope.evaluate(boolean_altitude).reason == &"invalid_altitude"
		and envelope.evaluate(invalid_clearance).reason == &"invalid_sun_clearance"
		and envelope.evaluate(beyond_clearance).reason == &"invalid_sun_clearance",
		"wrong-type, nonfinite, and over-domain scalar observations reject"
	)
	_check(
		envelope.evaluate(_observation(-120000.001, 0.0)).reason
		== &"altitude_out_of_bounds"
		and envelope.evaluate(_observation(
			ProfileScript.MAX_ATMOSPHERE_ALTITUDE_M + 1.0, 0.0
		)).reason == &"altitude_out_of_bounds"
		and envelope.get_snapshot() == before,
		"profile-relative altitude bounds reject without mutating frozen state"
	)


func _test_purity_detachment_and_exact_contracts() -> void:
	var envelope := _envelope()
	var input := _observation(19500.0, 0.010001)
	var before := envelope.get_snapshot()
	var baseline := envelope.evaluate(input)
	var cadence_equal := true
	for count in [30, 60, 120]:
		var latest := {}
		for _index in count:
			latest = envelope.evaluate(input)
		cadence_equal = cadence_equal and latest == baseline
	_check(
		cadence_equal and envelope.get_snapshot() == before,
		"equal observations at 30/60/120-equivalent call counts are byte-stable and stateless"
	)
	input.altitude_m = NAN
	baseline.evaluation.weights.atmosphere_unitless = 99.0
	var mutated_snapshot := envelope.get_snapshot()
	mutated_snapshot.widths.atmosphere_top_width_m = 99.0
	var repeated := envelope.evaluate(_observation(19500.0, 0.010001))
	_check(
		repeated.evaluation.weights.atmosphere_unitless == 0.5
		and envelope.get_snapshot() == before,
		"caller input/result/snapshot mutation cannot affect retained configuration or later output"
	)
	var audit := envelope.audit()
	var mutated_audit := audit.duplicate(true)
	mutated_audit.snapshot.geometry.atmosphere_top_altitude_m = 1.0
	mutated_audit.authority.renderer = true
	mutated_audit.evidence.status = &"mutated"
	_check(
		bool(audit.valid) and envelope.audit() == audit
		and _exact_false_dictionary(audit.authority, EXPECTED_AUTHORITY_KEYS)
		and _exact_false_dictionary(
			audit.adjacent_authority, EXPECTED_ADJACENT_AUTHORITY_KEYS
		)
		and audit.capabilities == EXPECTED_CAPABILITIES
		and audit.evidence == EXPECTED_EVIDENCE,
		"audit is detached and freezes exact capabilities, evidence, and zero-authority rosters"
	)
	_check(
		not _contains_live_object(envelope.get_snapshot())
		and not _contains_live_object(envelope.audit())
		and not _contains_live_object(repeated),
		"all snapshots, audits, and evaluations contain detached transport-safe values"
	)


func _test_structured_red_audit() -> void:
	var envelope := _envelope()
	var original_widths := envelope._widths.duplicate(true)
	envelope._widths.atmosphere_top_width_m = 0.0
	_check(
		not bool(envelope.audit().valid)
		and (envelope.audit().errors as PackedStringArray).has(
			"frozen_width_contract_drift"
		),
		"zero-width structured red invalidates the frozen envelope contract"
	)
	envelope._widths = original_widths.duplicate(true)
	envelope._widths.cloud_base_width_m = 2000.0
	envelope._widths.cloud_top_width_m = 2000.0
	_check(
		not bool(envelope.audit().valid)
		and (envelope.audit().errors as PackedStringArray).has(
			"frozen_width_contract_drift"
		),
		"overlapping cloud-width structured red is visible to audit"
	)
	envelope._widths = original_widths.duplicate(true)
	var original_geometry := envelope._geometry.duplicate(true)
	envelope._geometry.atmosphere_top_altitude_m = 19000.0
	_check(
		not bool(envelope.audit().valid)
		and (envelope.audit().errors as PackedStringArray).has(
			"frozen_profile_contract_drift"
		),
		"profile-endpoint structured red cannot silently retune the frozen source"
	)
	envelope._geometry = original_geometry.duplicate(true)
	_check(
		bool(envelope.audit().valid),
		"every mutable frozen-state structured red restoration returns the exact baseline audit"
	)


func _envelope() -> PlanetaryAtmospherePresentationEnvelope:
	var envelope := EnvelopeScript.new() \
		as PlanetaryAtmospherePresentationEnvelope
	var configured := envelope.configure(
		_profile(), 1000.0, 500.0, 500.0, 0.02
	)
	if not bool(configured.accepted):
		_failures.append("fixture envelope failed to configure: %s" % configured)
	return envelope


func _profile() -> PlanetaryAtmosphereProfile:
	return ProfileScript.new() as PlanetaryAtmosphereProfile


func _observation(
	altitude_m: float = 0.0,
	sun_horizon_clearance_radians: float = 0.0
) -> Dictionary:
	return {
		"altitude_m": altitude_m,
		"sun_horizon_clearance_radians": sun_horizon_clearance_radians,
	}


func _evaluation(
	envelope: PlanetaryAtmospherePresentationEnvelope,
	altitude_m: float,
	clearance_radians: float
) -> Dictionary:
	var result := envelope.evaluate(
		_observation(altitude_m, clearance_radians)
	)
	if not bool(result.accepted):
		_failures.append("fixture evaluation rejected: %s" % result)
	return (result.get("evaluation", {}) as Dictionary).duplicate(true)


func _exact_false_dictionary(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key) or value.get(key) is not bool \
				or bool(value.get(key)):
			return false
	return true


func _contains_live_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Dictionary:
		for key: Variant in (value as Dictionary):
			if _contains_live_object(key) \
					or _contains_live_object((value as Dictionary)[key]):
				return true
	elif value is Array:
		for item: Variant in value as Array:
			if _contains_live_object(item):
				return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"expected %d assertions, ran %d" % [
				EXPECTED_ASSERTIONS, _assertions,
			]
		)
	if _failures.is_empty():
		print(
			"PLANETARY_ATMOSPHERE_PRESENTATION_ENVELOPE_TEST_OK: %d assertions"
			% _assertions
		)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	printerr("PLANETARY_ATMOSPHERE_PRESENTATION_ENVELOPE_TEST_FAILED")
	quit(1)
