extends SceneTree

const PolicyScript := preload(
	"res://scripts/world/planetary_surface_audio_policy.gd"
)
const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)
const EXPECTED_ASSERTIONS := 33
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"audio_profile_resolution", "audio_resource_loading", "playback",
	"voice_allocation", "bus_or_mixer", "smooth_crossfade",
	"crossfade_clock", "listener_context_truth", "grounded_truth",
	"weather_selection", "weather_clock", "wind_simulation", "movement",
	"physics", "streaming", "gameplay", "save", "network",
]
const CAPABILITY_KEYS := [
	"routing_gain_hint_implemented",
	"density_weighted_intensity_hint_implemented",
	"instantaneous_context_mix_endpoints_implemented",
	"cabin_aliases_interior",
	"audio_profile_resolution_implemented",
	"playback_implemented",
	"mixer_implemented",
	"smooth_crossfade_implemented",
	"clock_implemented",
	"weather_selection_implemented",
]
const EXPECTED_POLICY_EVIDENCE := {
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
	_test_configuration_and_freeze()
	_test_observation_schema_and_priority()
	_test_context_routes_gains_and_endpoints()
	_test_altitude_boundaries()
	_test_grounded_speed_wind_equation()
	_test_gain_clamp_and_profile_variants()
	_test_purity_detachment_audit_and_authority()
	_finish()


func _test_configuration_and_freeze() -> void:
	var policy := PolicyScript.new() as PlanetarySurfaceAudioPolicy
	_check(
		policy is RefCounted
		and not (policy as Object).is_class("Node")
		and policy.evaluate({}).reason == &"invalid_observation_schema"
		and policy.evaluate(_observation()).reason == &"not_configured"
		and not bool(policy.audit().valid),
		"the pure policy applies schema priority and fails closed before configuration"
	)
	var invalid := ProfileScript.new() as PlanetaryAtmosphereProfile
	invalid.exterior_audio_profile_id = &"Invalid Route"
	_check(
		policy.configure(null).reason == &"missing_profile"
		and policy.configure(invalid).reason == &"invalid_profile"
		and not policy.is_configured(),
		"missing and malformed atmosphere profiles reject without partial state"
	)
	var profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	var configured := policy.configure(profile)
	var snapshot := policy.get_snapshot()
	_check(
		bool(configured.accepted) and configured.reason == &"configured"
		and policy.is_configured() and bool(policy.audit().valid)
		and snapshot.profile_id == &"temperate_game_scale"
		and snapshot.policy_version == &"planetary_surface_audio_v1"
		and snapshot.equation_version == &"density_max_airflow_hints_v1"
		and float(snapshot.full_movement_airflow_speed_mps) == 100.0,
		"valid configuration freezes exact identity and versioned NEW speed tuning"
	)
	_check(
		(snapshot.audio_hints as Dictionary).exterior_audio_profile_id
			== &"temperate_exterior"
		and (snapshot.audio_hints as Dictionary).interior_audio_profile_id
			== &"temperate_interior"
		and float((snapshot.audio_hints as Dictionary).exterior_wind_gain_db)
			== -6.0
		and float((snapshot.audio_hints as Dictionary).interior_attenuation_db)
			== -18.0,
		"the exact two opaque authored IDs and two gain hints are frozen"
	)
	_check(
		policy.configure(ProfileScript.new()).reason == &"already_configured",
		"successful configuration is immutable"
	)
	profile.profile_id = &"caller_mutated"
	profile.exterior_audio_profile_id = &"mutated_exterior"
	profile.interior_audio_profile_id = &"mutated_interior"
	profile.exterior_wind_gain_db = 12.0
	profile.interior_attenuation_db = -2.0
	profile.weather_intensity_unitless = 1.0
	_check(
		policy.get_snapshot() == snapshot
		and policy.evaluate(_observation()).evaluation.routing \
			.selected_audio_profile_id == &"temperate_exterior",
		"caller Resource mutation cannot retune frozen routes, gains, or weather"
	)


func _test_observation_schema_and_priority() -> void:
	var policy := _policy()
	var missing := _observation()
	missing.erase("speed_mps")
	var extra := _observation()
	extra["delta"] = 0.016
	_check(
		policy.evaluate(null).reason == &"invalid_observation"
		and policy.evaluate(missing).reason == &"invalid_observation_schema"
		and policy.evaluate(extra).reason == &"invalid_observation_schema",
		"the observation boundary rejects non-dictionaries, missing keys, and extras"
	)
	var string_context := _observation()
	string_context.listener_context = "exterior"
	var unknown_context := _observation()
	unknown_context.listener_context = &"hangar"
	_check(
		policy.evaluate(string_context).reason == &"invalid_listener_context"
		and policy.evaluate(unknown_context).reason == &"invalid_listener_context",
		"listener context requires the exact StringName exterior/interior/cabin roster"
	)
	var invalid_grounded := _observation()
	invalid_grounded.grounded = 1
	var invalid_altitude := _observation()
	invalid_altitude.altitude_m = NAN
	_check(
		policy.evaluate(invalid_grounded).reason == &"invalid_grounded_state"
		and policy.evaluate(invalid_altitude).reason == &"invalid_altitude",
		"grounded truth is strictly boolean and altitude rejects nonfinite values"
	)
	var negative_speed := _observation()
	negative_speed.speed_mps = -0.001
	var infinite_speed := _observation()
	infinite_speed.speed_mps = INF
	var above_speed := _observation()
	above_speed.speed_mps = PolicyScript.MAX_OBSERVED_SPEED_MPS + 0.001
	_check(
		policy.evaluate(negative_speed).reason == &"invalid_speed"
		and policy.evaluate(infinite_speed).reason == &"invalid_speed"
		and policy.evaluate(above_speed).reason == &"invalid_speed",
		"speed rejects negative, nonfinite, and above-bound observations"
	)
	var negative_wind := _observation()
	negative_wind.ambient_wind_scalar_unitless = -0.001
	var above_wind := _observation()
	above_wind.ambient_wind_scalar_unitless = 1.001
	_check(
		policy.evaluate(negative_wind).reason == &"invalid_wind_scalar"
		and policy.evaluate(above_wind).reason == &"invalid_wind_scalar",
		"caller wind intensity is an exact closed unit interval"
	)


func _test_context_routes_gains_and_endpoints() -> void:
	var policy := _policy()
	var exterior := policy.evaluate(_observation(&"exterior", 0.0, true, 0.0, 0.0))
	var exterior_evaluation := exterior.evaluation as Dictionary
	_check(
		bool(exterior.accepted)
		and (exterior_evaluation.routing as Dictionary).selected_audio_profile_id
			== &"temperate_exterior"
		and (exterior_evaluation.routing as Dictionary).selected_route
			== &"exterior"
		and float((exterior_evaluation.gain as Dictionary).recommended_gain_db)
			== -6.0,
		"exterior selects the exact exterior opaque route and authored base gain"
	)
	_check(
		float((exterior_evaluation.mix as Dictionary).exterior_route_unitless)
			== 1.0
		and float((exterior_evaluation.mix as Dictionary).interior_route_unitless)
			== 0.0
		and float((exterior_evaluation.mix as Dictionary).ground_contact_unitless)
			== 1.0
		and float((exterior_evaluation.mix as Dictionary).airborne_unitless)
			== 0.0
		and bool((exterior_evaluation.mix as Dictionary).instantaneous_endpoints_only),
		"context and grounded mixes are exact endpoints, never timed crossfade state"
	)
	var interior := policy.evaluate(_observation(&"interior", 0.0, false, 0.0, 0.0))
	var interior_evaluation := interior.evaluation as Dictionary
	_check(
		(interior_evaluation.routing as Dictionary).selected_audio_profile_id
			== &"temperate_interior"
		and (interior_evaluation.routing as Dictionary).selected_route == &"interior"
		and float((interior_evaluation.gain as Dictionary).selected_base_gain_db)
			== -6.0
		and float((interior_evaluation.gain as Dictionary).selected_context_attenuation_db)
			== -18.0
		and float((interior_evaluation.gain as Dictionary).recommended_gain_db)
			== -24.0,
		"interior combines exterior base with the authored relative attenuation"
	)
	var cabin := policy.evaluate(_observation(&"cabin", 0.0, false, 0.0, 0.0))
	var cabin_evaluation := cabin.evaluation as Dictionary
	_check(
		(cabin_evaluation.routing as Dictionary).selected_audio_profile_id
			== &"temperate_interior"
		and (cabin_evaluation.routing as Dictionary).listener_context == &"cabin"
		and bool((cabin_evaluation.routing as Dictionary).cabin_aliases_interior)
		and cabin_evaluation.gain == interior_evaluation.gain
		and cabin_evaluation.mix == interior_evaluation.mix,
		"cabin truthfully aliases the sole interior route without inventing a third asset"
	)
	_check(
		not bool((cabin_evaluation.routing as Dictionary).profile_id_resolved)
		and not bool((cabin_evaluation.routing as Dictionary).playback_requested)
		and (cabin_evaluation.routing as Dictionary).available_profile_ids \
			.exterior == &"temperate_exterior"
		and (cabin_evaluation.routing as Dictionary).available_profile_ids \
			.interior == &"temperate_interior",
		"route IDs remain opaque unresolved hints and evaluation never requests playback"
	)


func _test_altitude_boundaries() -> void:
	var policy := _policy()
	var below: Dictionary = policy.evaluate(
		_observation(&"exterior", -1.0, true, 0.0, 1.0)
	).evaluation
	var surface: Dictionary = policy.evaluate(
		_observation(&"exterior", 0.0, true, 0.0, 1.0)
	).evaluation
	_check(
		(below.altitude as Dictionary).state == &"below_reference_surface"
		and bool((below.altitude as Dictionary).below_reference_altitude)
		and float((below.intensity as Dictionary).density_ratio) == 1.0
		and (surface.altitude as Dictionary).state == &"reference_surface_boundary"
		and float((surface.intensity as Dictionary).density_ratio) == 1.0,
		"below-reference and exact-surface observations use the sampler reference-density clamp"
	)
	var below_top: Dictionary = policy.evaluate(
		_observation(&"exterior", 19_999.999, true, 0.0, 1.0)
	).evaluation
	var at_top: Dictionary = policy.evaluate(
		_observation(&"exterior", 20_000.0, true, 0.0, 1.0)
	).evaluation
	_check(
		(below_top.altitude as Dictionary).state == &"within_atmosphere_shell"
		and float((below_top.intensity as Dictionary).density_ratio) > 0.0
		and float((below_top.intensity as Dictionary).recommended_intensity_unitless)
			> 0.0
		and (at_top.altitude as Dictionary).state == &"atmosphere_top_boundary"
		and not bool((at_top.altitude as Dictionary).inside_atmosphere)
		and float((at_top.intensity as Dictionary).recommended_intensity_unitless)
			== 0.0,
		"the atmosphere shell is half-open and exact top recommends silence"
	)
	var above: Dictionary = policy.evaluate(
		_observation(&"interior", 20_000.001, false, 100.0, 1.0)
	).evaluation
	_check(
		(above.altitude as Dictionary).state == &"above_atmosphere_shell"
		and float((above.intensity as Dictionary).density_ratio) == 0.0
		and bool((above.intensity as Dictionary).silence_recommended)
		and (above.routing as Dictionary).selected_audio_profile_id
			== &"temperate_interior",
		"vacuum preserves opaque routing identity while every intensity hint is silent"
	)
	var body_center := policy.evaluate(
		_observation(&"exterior", -120_000.0, true, 0.0, 0.0)
	)
	var below_center := policy.evaluate(
		_observation(&"exterior", -120_000.001, true, 0.0, 0.0)
	)
	var maximum := policy.evaluate(
		_observation(
			&"exterior",
			ProfileScript.MAX_ATMOSPHERE_ALTITUDE_M,
			true,
			0.0,
			0.0
		)
	)
	_check(
		bool(body_center.accepted)
		and below_center.reason == &"altitude_out_of_bounds"
		and bool(maximum.accepted)
		and bool((maximum.evaluation.intensity as Dictionary).silence_recommended),
		"body-centre and global altitude endpoints are inclusive with one-step-beyond rejection"
	)


func _test_grounded_speed_wind_equation() -> void:
	var policy := _policy()
	var grounded_fast: Dictionary = policy.evaluate(
		_observation(&"exterior", 0.0, true, 100_000.0, 0.0)
	).evaluation
	_check(
		float((grounded_fast.intensity as Dictionary).movement_speed_factor_unitless)
			== 1.0
		and float((grounded_fast.intensity as Dictionary).movement_airflow_unitless)
			== 0.0
		and float(
			(grounded_fast.atmosphere_sample as Dictionary)
				.entry_effect_intensity
		) == 1.0
		and bool((grounded_fast.intensity as Dictionary).silence_recommended),
		"grounded truth suppresses movement airflow while entry sampling retains caller speed"
	)
	var half_speed: Dictionary = policy.evaluate(
		_observation(&"exterior", 0.0, false, 50.0, 0.0)
	).evaluation
	var full_speed: Dictionary = policy.evaluate(
		_observation(&"exterior", 0.0, false, 100.0, 0.0)
	).evaluation
	var clamped_speed: Dictionary = policy.evaluate(
		_observation(&"exterior", 0.0, false, 101.0, 0.0)
	).evaluation
	_check(
		float((half_speed.intensity as Dictionary).movement_speed_factor_unitless)
			== 0.5
		and float((half_speed.intensity as Dictionary).recommended_intensity_unitless)
			== 0.5
		and float((full_speed.intensity as Dictionary).movement_speed_factor_unitless)
			== 1.0
		and float((clamped_speed.intensity as Dictionary).movement_speed_factor_unitless)
			== 1.0,
		"airborne movement is linear through the exact NEW 100m/s endpoint then clamps"
	)
	var ambient: Dictionary = policy.evaluate(
		_observation(&"exterior", 0.0, true, 0.0, 1.0)
	).evaluation
	_check(
		float((ambient.intensity as Dictionary).authored_weather_intensity_unitless)
			== 0.35
		and float((ambient.intensity as Dictionary).ambient_wind_unitless) == 0.35
		and float((ambient.intensity as Dictionary).recommended_intensity_unitless)
			== 0.35,
		"full caller wind retains the authored weather intensity at reference density"
	)
	_check(
		float((ambient.atmosphere_sample as Dictionary).entry_effect_intensity)
			== 0.0,
		"neutral speed keeps the sampler entry effect at zero"
	)
	var ambient_dominates: Dictionary = policy.evaluate(
		_observation(&"exterior", 0.0, false, 20.0, 1.0)
	).evaluation
	var motion_dominates: Dictionary = policy.evaluate(
		_observation(&"exterior", 0.0, false, 50.0, 1.0)
	).evaluation
	_check(
		float((ambient_dominates.intensity as Dictionary).movement_airflow_unitless)
			== 0.2
		and float((ambient_dominates.intensity as Dictionary).merged_airflow_unitless)
			== 0.35
		and float((motion_dominates.intensity as Dictionary).merged_airflow_unitless)
			== 0.5,
		"ambient and movement airflow use deterministic maximum priority, never a sum"
	)


func _test_gain_clamp_and_profile_variants() -> void:
	var quiet_profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	quiet_profile.exterior_wind_gain_db = -70.0
	quiet_profile.interior_attenuation_db = -20.0
	var quiet := PolicyScript.new() as PlanetarySurfaceAudioPolicy
	quiet.configure(quiet_profile)
	var interior: Dictionary = quiet.evaluate(
		_observation(&"interior")
	).evaluation
	_check(
		float((interior.gain as Dictionary).unclamped_recommended_gain_db) == -90.0
		and float((interior.gain as Dictionary).recommended_gain_db) == -80.0
		and bool((interior.gain as Dictionary).gain_clamped),
		"derived interior gain clamps exactly to the profile's finite minimum"
	)
	var loud_profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	loud_profile.exterior_wind_gain_db = 24.0
	loud_profile.interior_attenuation_db = 0.0
	var loud := PolicyScript.new() as PlanetarySurfaceAudioPolicy
	loud.configure(loud_profile)
	var exterior: Dictionary = loud.evaluate(
		_observation(&"exterior")
	).evaluation
	var cabin: Dictionary = loud.evaluate(_observation(&"cabin")).evaluation
	_check(
		float((exterior.gain as Dictionary).recommended_gain_db) == 24.0
		and float((cabin.gain as Dictionary).recommended_gain_db) == 24.0
		and not bool((cabin.gain as Dictionary).gain_clamped),
		"maximum authored exterior gain and zero interior attenuation stay finite and exact"
	)


func _test_purity_detachment_audit_and_authority() -> void:
	var policy := _policy()
	var input := _observation(&"cabin", 1000.0, false, 25.0, 0.5)
	var before := policy.get_snapshot()
	var first := policy.evaluate(input)
	var second := policy.evaluate(input)
	_check(
		first == second and policy.get_snapshot() == before,
		"identical complete observations are deterministic and stateless"
	)
	input.listener_context = &"exterior"
	input.speed_mps = 100_000.0
	first.evaluation.routing.selected_audio_profile_id = &"mutated"
	first.evaluation.intensity.recommended_intensity_unitless = 99.0
	var after_mutation := policy.evaluate(
		_observation(&"cabin", 1000.0, false, 25.0, 0.5)
	)
	_check(
		after_mutation == second
		and after_mutation.evaluation.routing.selected_audio_profile_id
			== &"temperate_interior",
		"caller input and nested result mutation cannot alter future evaluation"
	)
	var audit := policy.audit()
	var audit_copy := audit.duplicate(true)
	audit_copy.snapshot.audio_hints.exterior_audio_profile_id = &"mutated"
	audit_copy.authority.audio = true
	_check(
		bool(audit.valid) and policy.audit() == audit
		and policy.get_profile_snapshot().profile_id == &"temperate_game_scale"
		and audit.evidence == EXPECTED_POLICY_EVIDENCE
		and audit.snapshot.evidence == EXPECTED_POLICY_EVIDENCE,
		"snapshot, audit, profile report, and exact policy evidence are deeply detached"
	)
	_check(
		_exact_false_dictionary(audit.authority, COMMON_AUTHORITY_KEYS)
		and _exact_false_dictionary(
			audit.adjacent_authority, ADJACENT_AUTHORITY_KEYS
		),
		"common and adjacent authority rosters are exact booleans and all false"
	)
	_check(
		_exact_capabilities(audit.capabilities)
		and bool(audit.limitations.profile_ids_are_opaque_unresolved_hints)
		and not bool(audit.limitations.cabin_has_distinct_authored_profile)
		and not bool(audit.limitations.mix_values_are_crossfade_timing)
		and not bool(audit.limitations.playable_audio_produced),
		"capabilities separate hints from resolution, playback, and smooth crossfade"
	)
	_check(
		not _contains_live_object(policy.get_snapshot())
		and not _contains_live_object(policy.audit())
		and not _contains_live_object(second),
		"all public reports contain only detached transport-safe values"
	)


func _policy() -> PlanetarySurfaceAudioPolicy:
	var policy := PolicyScript.new() as PlanetarySurfaceAudioPolicy
	var configured := policy.configure(ProfileScript.new())
	if not bool(configured.accepted):
		_failures.append("fixture policy failed to configure: %s" % configured.reason)
	return policy


func _observation(
	listener_context: StringName = &"exterior",
	altitude_m: float = 0.0,
	grounded: bool = true,
	speed_mps: float = 0.0,
	ambient_wind_scalar_unitless: float = 0.0
) -> Dictionary:
	return {
		"altitude_m": altitude_m,
		"listener_context": listener_context,
		"grounded": grounded,
		"speed_mps": speed_mps,
		"ambient_wind_scalar_unitless": ambient_wind_scalar_unitless,
	}


func _exact_false_dictionary(value: Variant, expected_keys: Array) -> bool:
	if value is not Dictionary:
		return false
	var dictionary := value as Dictionary
	if dictionary.size() != expected_keys.size():
		return false
	for key: String in expected_keys:
		if not dictionary.has(key) or dictionary[key] is not bool \
				or bool(dictionary[key]):
			return false
	return true


func _exact_capabilities(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	var capabilities := value as Dictionary
	if capabilities.size() != CAPABILITY_KEYS.size():
		return false
	for key: String in CAPABILITY_KEYS:
		if not capabilities.has(key) or capabilities[key] is not bool:
			return false
	return bool(capabilities.routing_gain_hint_implemented) \
		and bool(capabilities.density_weighted_intensity_hint_implemented) \
		and bool(capabilities.instantaneous_context_mix_endpoints_implemented) \
		and bool(capabilities.cabin_aliases_interior) \
		and not bool(capabilities.audio_profile_resolution_implemented) \
		and not bool(capabilities.playback_implemented) \
		and not bool(capabilities.mixer_implemented) \
		and not bool(capabilities.smooth_crossfade_implemented) \
		and not bool(capabilities.clock_implemented) \
		and not bool(capabilities.weather_selection_implemented)


func _contains_live_object(value: Variant) -> bool:
	if value is Object or value is Callable or value is Signal:
		return true
	if value is Dictionary:
		for key: Variant in value:
			if _contains_live_object(key) or _contains_live_object(value[key]):
				return true
	elif value is Array:
		for entry: Variant in value:
			if _contains_live_object(entry):
				return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion count drifted: expected %d got %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	print("PLANETARY_SURFACE_AUDIO_POLICY_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_SURFACE_AUDIO_POLICY_TEST_OK")
		quit(0)
	else:
		print(
			"PLANETARY_SURFACE_AUDIO_POLICY_TEST_FAILED: %s"
			% ", ".join(_failures)
		)
		quit(1)
