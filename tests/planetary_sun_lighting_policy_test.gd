extends SceneTree

const PolicyScript := preload(
	"res://scripts/world/planetary_sun_lighting_policy.gd"
)
const WorldScript := preload(
	"res://scripts/world/definitions/planetary_world_definition.gd"
)
const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)
const BODY_RADIUS_M := 120_000.0
const EXPECTED_ASSERTIONS := 36
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"star_spectrum", "star_luminosity", "ephemeris",
	"time_or_day_night_clock", "directional_light", "environment",
	"sky_or_material", "renderer_application", "shadow_or_occlusion_query",
	"terrain_horizon", "terrain_albedo", "cloud_shadow", "weather_selection",
	"camera", "origin_or_rebase", "physics", "gameplay", "streaming",
	"save", "network",
]
const CAPABILITY_KEYS := [
	"spherical_reference_horizon_implemented",
	"airless_visibility_implemented",
	"bounded_clear_sky_attenuation_hint_implemented",
	"bounded_atmospheric_twilight_proxy_implemented",
	"calibrated_photometry_implemented",
	"star_spectrum_implemented",
	"finite_sun_disk_implemented",
	"terrain_shadow_implemented",
	"cloud_shadow_implemented",
	"multiple_scattering_implemented",
	"renderer_application_implemented",
	"clock_or_ephemeris_implemented",
]
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
	_test_configuration_matrix_and_freeze()
	_test_strict_observation_boundary()
	_test_airless_surface_geometry()
	_test_elevated_spherical_horizon()
	_test_atmospheric_twilight_boundaries()
	_test_clear_sky_optical_hints()
	_test_atmosphere_top_and_zero_scattering()
	_test_purity_detachment_authority_and_evidence()
	_finish()


func _test_configuration_matrix_and_freeze() -> void:
	var policy := PolicyScript.new() as PlanetarySunLightingPolicy
	_check(
		policy is RefCounted
		and not (policy as Object).is_class("Node")
		and policy.evaluate({}).reason == &"invalid_observation_schema"
		and policy.evaluate(_observation()).reason == &"not_configured"
		and not bool(policy.audit().valid),
		"pure policy applies strict input priority and fails closed before configuration"
	)
	var invalid_world := _world(false)
	invalid_world.scene_path = ""
	_check(
		policy.configure(null).reason == &"missing_world_definition"
		and policy.configure(invalid_world).reason == &"invalid_world_definition",
		"missing and malformed world definitions reject without partial configuration"
	)
	var atmosphere := ProfileScript.new() as PlanetaryAtmosphereProfile
	var invalid_atmosphere := ProfileScript.new() as PlanetaryAtmosphereProfile
	invalid_atmosphere.rayleigh_scattering_per_m = Color(NAN, 0.0, 0.0, 1.0)
	var wrong_id := ProfileScript.new() as PlanetaryAtmosphereProfile
	wrong_id.profile_id = &"wrong_atmosphere"
	var wrong_radius := ProfileScript.new() as PlanetaryAtmosphereProfile
	wrong_radius.planet_radius_m += 0.001
	_check(
		policy.configure(_world(true), null).reason == &"missing_atmosphere_profile"
		and policy.configure(_world(true), invalid_atmosphere).reason
			== &"invalid_atmosphere_profile"
		and policy.configure(_world(true), wrong_id).reason
			== &"atmosphere_profile_id_mismatch"
		and policy.configure(_world(true), wrong_radius).reason
			== &"body_radius_mismatch",
		"atmospheric worlds require a valid exact-ID and exact-radius profile"
	)
	_check(
		policy.configure(_world(false), atmosphere).reason
			== &"unexpected_atmosphere_profile",
		"airless worlds reject an invented atmosphere composition"
	)
	var configured := policy.configure(_world(true), atmosphere)
	var snapshot := policy.get_snapshot()
	_check(
		bool(configured.accepted) and configured.reason == &"configured"
		and policy.is_configured() and bool(policy.audit().valid)
		and snapshot.world_id == &"sun_policy_world"
		and bool(snapshot.has_atmosphere)
		and snapshot.atmosphere_profile_id == &"temperate_game_scale"
		and float(snapshot.body_radius_m) == BODY_RADIUS_M,
		"valid atmosphere composition freezes exact identity and sea-level radius"
	)
	_check(
		policy.configure(_world(true), ProfileScript.new()).reason
			== &"already_configured",
		"successful configuration is immutable"
	)
	var before := policy.get_snapshot()
	atmosphere.profile_id = &"caller_mutated"
	atmosphere.planet_radius_m = 130_000.0
	atmosphere.rayleigh_scattering_per_m = Color(1.0, 0.0, 0.0, 1.0)
	_check(
		policy.get_snapshot() == before
		and policy.evaluate(_observation()).evaluation.atmosphere_profile_id
			== &"temperate_game_scale",
		"caller Resource mutation cannot retune frozen atmosphere identity or optics"
	)
	var airless := PolicyScript.new() as PlanetarySunLightingPolicy
	var airless_configured := airless.configure(_world(false))
	_check(
		bool(airless_configured.accepted) and bool(airless.audit().valid)
		and not bool(airless.get_snapshot().has_atmosphere)
		and airless.get_atmosphere_snapshot().is_empty(),
		"airless configuration retains no sampler or synthetic atmosphere snapshot"
	)


func _test_strict_observation_boundary() -> void:
	var policy := _policy(false)
	var missing := _observation()
	missing.erase("normalized_body_to_sun")
	var extra := _observation()
	extra["time"] = 1.0
	_check(
		policy.evaluate(null).reason == &"invalid_observation"
		and policy.evaluate(missing).reason == &"invalid_observation_schema"
		and policy.evaluate(extra).reason == &"invalid_observation_schema",
		"observation schema rejects non-dictionaries, missing fields, and clock extras"
	)
	var wrong_position := _observation()
	wrong_position.body_local_observer_m = "surface"
	var nonfinite_position := _observation()
	nonfinite_position.body_local_observer_m = Vector3(NAN, 0.0, 0.0)
	var far_position := _observation()
	far_position.body_local_observer_m = Vector3(
		PlanetaryCoordinateFrame.MAX_LOCAL_COMPONENT_METERS + 256.0, 0.0, 0.0
	)
	_check(
		policy.evaluate(wrong_position).reason == &"invalid_observer_position"
		and policy.evaluate(nonfinite_position).reason == &"invalid_observer_position"
		and policy.evaluate(far_position).reason == &"observer_position_out_of_bounds",
		"observer position type, finiteness, and coordinate-frame component bound are strict"
	)
	var centre := _observation()
	centre.body_local_observer_m = Vector3.ZERO
	var interior := _observation()
	interior.body_local_observer_m = Vector3.UP * (BODY_RADIUS_M - 1.0)
	var surface := _observation()
	surface.body_local_observer_m = Vector3.UP * BODY_RADIUS_M
	_check(
		policy.evaluate(centre).reason == &"observer_radial_up_undefined"
		and policy.evaluate(interior).reason == &"observer_inside_reference_sphere"
		and bool(policy.evaluate(surface).accepted),
		"centre and reference-sphere interior reject while exact sea level is inclusive"
	)
	var wrong_direction := _observation()
	wrong_direction.normalized_body_to_sun = 1.0
	var zero_direction := _observation()
	zero_direction.normalized_body_to_sun = Vector3.ZERO
	var long_direction := _observation()
	long_direction.normalized_body_to_sun = Vector3.UP * 1.001
	var tolerated_direction := _observation()
	tolerated_direction.normalized_body_to_sun = Vector3.UP * 1.00005
	_check(
		policy.evaluate(wrong_direction).reason == &"invalid_sun_direction"
		and policy.evaluate(zero_direction).reason == &"invalid_sun_direction"
		and policy.evaluate(long_direction).reason == &"invalid_sun_direction"
		and bool(policy.evaluate(tolerated_direction).accepted),
		"sun direction requires finite unit length within the exact documented tolerance"
	)


func _test_airless_surface_geometry() -> void:
	var policy := _policy(false)
	var zenith: Dictionary = policy.evaluate(
		_observation(Vector3.UP, BODY_RADIUS_M)
	).evaluation
	_check(
		is_equal_approx(float(zenith.geometry.sun_elevation_sine), 1.0)
		and is_equal_approx(float(zenith.geometry.sun_elevation_degrees), 90.0)
		and float(zenith.geometry.spherical_horizon_elevation_degrees) == 0.0
		and bool(zenith.geometry.direct_sun_visible)
		and zenith.classification.state == &"direct_daylight",
		"surface zenith has exact 90-degree elevation and direct daylight"
	)
	_check(
		zenith.directional_light_hint.recommended_color == Color.WHITE
		and float(zenith.directional_light_hint.recommended_energy_factor_unitless)
			== 1.0
		and float(zenith.ambient_sky_hint.recommended_ambient_energy_factor_unitless)
			== 0.0
		and float(zenith.ambient_sky_hint.recommended_sky_contribution_unitless)
			== 0.0,
		"airless visible sun is exact white/unit energy with zero atmosphere proxy"
	)
	var horizon: Dictionary = policy.evaluate(
		_observation(Vector3.RIGHT, BODY_RADIUS_M)
	).evaluation
	_check(
		float(horizon.geometry.sun_horizon_clearance_degrees) == 0.0
		and not bool(horizon.geometry.direct_sun_visible)
		and horizon.classification.state == &"hard_horizon"
		and float(horizon.classification.day_factor_unitless) == 0.0
		and float(horizon.classification.twilight_factor_unitless) == 0.0
		and float(horizon.classification.night_factor_unitless) == 1.0,
		"airless exact horizon is a hard dark terminator with no twilight"
	)
	var anti_sun: Dictionary = policy.evaluate(
		_observation(Vector3.DOWN, BODY_RADIUS_M)
	).evaluation
	_check(
		is_equal_approx(float(anti_sun.geometry.sun_elevation_degrees), -90.0)
		and anti_sun.classification.state == &"night"
		and float(anti_sun.directional_light_hint.recommended_energy_factor_unitless)
			== 0.0,
		"airless anti-sun point is exact night with zero directional energy"
	)


func _test_elevated_spherical_horizon() -> void:
	var policy := _policy(false)
	var radius := BODY_RADIUS_M + 10_000.0
	var horizontal: Dictionary = policy.evaluate(
		_observation(Vector3.RIGHT, radius)
	).evaluation
	_check(
		float(horizontal.geometry.spherical_horizon_elevation_degrees) < 0.0
		and float(horizontal.geometry.sun_horizon_clearance_degrees) > 0.0
		and bool(horizontal.geometry.direct_sun_visible),
		"an elevated observer correctly sees a horizontal sun above the depressed horizon"
	)
	var horizon_elevation := asin(
		-sqrt(1.0 - pow(BODY_RADIUS_M / radius, 2.0))
	)
	var exact_horizon_direction := _sun_at_elevation(rad_to_deg(horizon_elevation))
	var exact_horizon: Dictionary = policy.evaluate(
		_observation(exact_horizon_direction, radius)
	).evaluation
	_check(
		absf(float(exact_horizon.geometry.sun_horizon_clearance_radians))
			<= PolicyScript.ANGLE_BOUNDARY_TOLERANCE_RADIANS
		and not bool(exact_horizon.geometry.direct_sun_visible)
		and exact_horizon.classification.state == &"hard_horizon",
		"constructed elevated spherical horizon is tolerance-classified and non-visible"
	)
	var one_degree_above: Dictionary = policy.evaluate(
		_observation(
			_sun_at_elevation(rad_to_deg(horizon_elevation) + 1.0), radius
		)
	).evaluation
	_check(
		bool(one_degree_above.geometry.direct_sun_visible)
		and one_degree_above.classification.state == &"direct_daylight",
		"one stable degree above the elevated horizon is direct daylight"
	)


func _test_atmospheric_twilight_boundaries() -> void:
	var policy := _policy(true)
	var horizon: Dictionary = policy.evaluate(
		_observation(_sun_at_elevation(0.0), BODY_RADIUS_M)
	).evaluation
	_check(
		horizon.classification.state == &"atmospheric_horizon"
		and float(horizon.classification.twilight_factor_unitless) == 1.0
		and float(horizon.classification.day_factor_unitless) == 0.0
		and float(horizon.classification.night_factor_unitless) == 0.0
		and not bool(horizon.geometry.direct_sun_visible),
		"atmospheric exact horizon is full proxy twilight with no direct sun"
	)
	var midpoint: Dictionary = policy.evaluate(
		_observation(_sun_at_elevation(-3.0), BODY_RADIUS_M)
	).evaluation
	_check(
		midpoint.classification.state == &"atmospheric_twilight"
		and is_equal_approx(float(midpoint.classification.twilight_factor_unitless), 0.5)
		and is_equal_approx(float(midpoint.classification.night_factor_unitless), 0.5)
		and is_equal_approx(float(midpoint.classification.factor_sum_unitless), 1.0),
		"minus-three-degree clearance is the exact smoothstep twilight midpoint"
	)
	var lower: Dictionary = policy.evaluate(
		_observation(_sun_at_elevation(-6.0), BODY_RADIUS_M)
	).evaluation
	var below: Dictionary = policy.evaluate(
		_observation(_sun_at_elevation(-6.01), BODY_RADIUS_M)
	).evaluation
	_check(
		lower.classification.state == &"atmospheric_twilight_lower_boundary"
		and float(lower.classification.twilight_factor_unitless) == 0.0
		and float(lower.classification.night_factor_unitless) == 1.0
		and below.classification.state == &"night",
		"minus-six-degree lower boundary is inclusive and a stable value below is night"
	)
	var above: Dictionary = policy.evaluate(
		_observation(_sun_at_elevation(0.01), BODY_RADIUS_M)
	).evaluation
	_check(
		above.classification.state == &"direct_daylight"
		and float(above.classification.day_factor_unitless) == 1.0
		and float(above.classification.twilight_factor_unitless) == 0.0,
		"a stable positive clearance switches to direct daylight without clock state"
	)
	var airless_twilight: Dictionary = _policy(false).evaluate(
		_observation(_sun_at_elevation(-3.0), BODY_RADIUS_M)
	).evaluation
	_check(
		airless_twilight.classification.state == &"night"
		and float(airless_twilight.classification.twilight_factor_unitless) == 0.0,
		"the same occulted direction has exact no-twilight behavior when airless"
	)


func _test_clear_sky_optical_hints() -> void:
	var policy := _policy(true)
	var zenith: Dictionary = policy.evaluate(
		_observation(Vector3.UP, BODY_RADIUS_M)
	).evaluation
	var optical := zenith.atmosphere.optical_hints as Dictionary
	_check(
		bool(zenith.atmosphere.local_atmosphere_active)
		and float(optical.direct_path_uncapped_m) == 20_000.0
		and float(optical.direct_path_distance_m) == 20_000.0
		and not (optical.direct_sample as Dictionary).is_empty()
		and float(zenith.directional_light_hint.direct_transmittance_unitless) < 1.0,
		"surface zenith uses the exact capped ray-to-shell sampler path"
	)
	_check(
		_color_bounded(zenith.directional_light_hint.recommended_color)
		and zenith.directional_light_hint.recommended_color != Color.WHITE
		and _unit(zenith.directional_light_hint.recommended_energy_factor_unitless)
		and not bool(zenith.directional_light_hint.absolute_energy_or_lux),
		"atmospheric coefficients yield only bounded normalized tint/energy hints, never lux"
	)
	var horizon: Dictionary = policy.evaluate(
		_observation(Vector3.RIGHT, BODY_RADIUS_M)
	).evaluation
	_check(
		float(horizon.atmosphere.optical_hints.horizon_path_distance_m) == 20_000.0
		and float(horizon.ambient_sky_hint.horizon_scattered_fraction_unitless) > 0.0
		and float(horizon.ambient_sky_hint.recommended_ambient_energy_factor_unitless)
			> 0.0
		and float(horizon.ambient_sky_hint.recommended_sky_contribution_unitless)
			> 0.0
		and not bool(horizon.ambient_sky_hint.multiple_scattering_physical),
		"horizon path produces an explicitly nonphysical bounded twilight ambient/sky proxy"
	)


func _test_atmosphere_top_and_zero_scattering() -> void:
	var policy := _policy(true)
	var just_below_radius := BODY_RADIUS_M + 19_999.0
	var just_below_horizon := _spherical_horizon_direction(just_below_radius)
	var just_below: Dictionary = policy.evaluate(
		_observation(just_below_horizon, just_below_radius)
	).evaluation
	_check(
		bool(just_below.atmosphere.local_atmosphere_active)
		and just_below.classification.state == &"atmospheric_horizon",
		"just below atmosphere top retains atmospheric horizon behavior"
	)
	var top_radius := BODY_RADIUS_M + 20_000.0
	var top: Dictionary = policy.evaluate(
		_observation(_spherical_horizon_direction(top_radius), top_radius)
	).evaluation
	_check(
		not bool(top.atmosphere.local_atmosphere_active)
		and top.classification.state == &"hard_horizon"
		and float(top.classification.twilight_factor_unitless) == 0.0
		and float(top.ambient_sky_hint.recommended_sky_contribution_unitless) == 0.0,
		"exact atmosphere top is vacuum with the hard no-twilight terminator"
	)
	var clear_profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	clear_profile.rayleigh_scattering_per_m = Color(0.0, 0.0, 0.0, 1.0)
	clear_profile.mie_scattering_per_m = Color(0.0, 0.0, 0.0, 1.0)
	clear_profile.absorption_per_m = Color(0.0, 0.0, 0.0, 1.0)
	var clear_policy := PolicyScript.new() as PlanetarySunLightingPolicy
	clear_policy.configure(_world(true), clear_profile)
	var clear_zenith: Dictionary = clear_policy.evaluate(
		_observation(Vector3.UP, BODY_RADIUS_M)
	).evaluation
	var clear_horizon: Dictionary = clear_policy.evaluate(
		_observation(Vector3.RIGHT, BODY_RADIUS_M)
	).evaluation
	_check(
		clear_zenith.directional_light_hint.recommended_color == Color.WHITE
		and float(clear_zenith.directional_light_hint.recommended_energy_factor_unitless)
			== 1.0
		and float(clear_horizon.ambient_sky_hint.horizon_scattered_fraction_unitless)
			== 0.0
		and float(clear_horizon.ambient_sky_hint.recommended_ambient_energy_factor_unitless)
			== 0.0,
		"valid zero coefficients produce exact white direct transmission and zero scatter proxy"
	)


func _test_purity_detachment_authority_and_evidence() -> void:
	var policy := _policy(true)
	var input := _observation(_sun_at_elevation(-3.0), BODY_RADIUS_M + 100.0)
	var before := policy.get_snapshot()
	var first := policy.evaluate(input)
	var second := policy.evaluate(input)
	_check(
		first == second and policy.get_snapshot() == before,
		"identical observations are deterministic, stateless, and cadence-independent"
	)
	input.body_local_observer_m = Vector3.ZERO
	first.evaluation.classification.state = &"mutated"
	first.evaluation.directional_light_hint.recommended_energy_factor_unitless = 99.0
	var after := policy.evaluate(
		_observation(_sun_at_elevation(-3.0), BODY_RADIUS_M + 100.0)
	)
	_check(
		after == second and after.evaluation.classification.state != &"mutated",
		"caller input and nested result mutation cannot alter future evaluation"
	)
	var audit := policy.audit()
	var mutated_audit := audit.duplicate(true)
	mutated_audit.snapshot.body_radius_m = 1.0
	mutated_audit.evidence.content_class = &"mutated"
	mutated_audit.authority.renderer = true
	_check(
		bool(audit.valid) and policy.audit() == audit
		and audit.evidence == EXPECTED_EVIDENCE
		and audit.snapshot.evidence == EXPECTED_EVIDENCE,
		"audit, snapshot, exact policy evidence, and source evidence are deeply detached"
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
		and not bool(audit.limitations.absolute_light_energy_or_lux_produced)
		and not bool(audit.limitations.star_spectrum_or_luminosity_known)
		and not bool(audit.limitations.terrain_or_cloud_occlusion_modeled)
		and not bool(audit.limitations.renderer_values_applied),
		"capabilities distinguish normalized hints from photometry, occlusion, and rendering"
	)
	_check(
		not _contains_live_object(policy.get_snapshot())
		and not _contains_live_object(policy.audit())
		and not _contains_live_object(second),
		"all public reports contain only detached transport-safe values"
	)


func _policy(atmospheric: bool) -> PlanetarySunLightingPolicy:
	var policy := PolicyScript.new() as PlanetarySunLightingPolicy
	var configured := policy.configure(
		_world(atmospheric),
		ProfileScript.new() if atmospheric else null
	)
	if not bool(configured.accepted):
		_failures.append("fixture failed to configure: %s" % configured.reason)
	return policy


func _world(atmospheric: bool) -> PlanetaryWorldDefinition:
	var world := WorldScript.new() as PlanetaryWorldDefinition
	world.world_id = &"sun_policy_world"
	world.display_name = "Sun Policy World"
	world.sector_id = &"sun_policy_sector"
	world.content_note = "Invented normalized sun-lighting policy fixture."
	world.scene_path = "res://scenes/world/planets/sun_policy_world.tscn"
	world.scene_anchor_id = &"sun_policy_scene"
	world.scene_anchor = Transform3D.IDENTITY
	world.navigation_anchor_id = &"sun_policy_navigation"
	world.navigation_anchor = Transform3D(
		Basis.IDENTITY, Vector3(0.0, BODY_RADIUS_M + 1_000.0, 0.0)
	)
	world.orbital_anchor_id = &"sun_policy_orbit"
	world.orbital_anchor = Transform3D(
		Basis.IDENTITY, Vector3(0.0, BODY_RADIUS_M + 20_000.0, 0.0)
	)
	world.surface_anchor_id = &"sun_policy_surface"
	world.surface_anchor = Transform3D(
		Basis.IDENTITY, Vector3(0.0, BODY_RADIUS_M, 0.0)
	)
	world.body_radius_metres = BODY_RADIUS_M
	world.has_atmosphere = atmospheric
	world.atmosphere_definition_id = (
		&"temperate_game_scale" if atmospheric else &""
	)
	world.terrain_definition_id = &"sun_policy_terrain"
	world.landing_region_ids = PackedStringArray(["sun_policy_landing"])
	world.evidence_status = WorldScript.EvidenceStatus.MODERN_INTERPRETATION
	world.evidence_notes = "Invented sun-lighting policy fixture."
	return world


func _observation(
	sun_direction: Vector3 = Vector3.UP,
	observer_radius_m: float = BODY_RADIUS_M
) -> Dictionary:
	return {
		"body_local_observer_m": Vector3.UP * observer_radius_m,
		"normalized_body_to_sun": sun_direction,
	}


func _sun_at_elevation(degrees: float) -> Vector3:
	var radians := deg_to_rad(degrees)
	return Vector3(cos(radians), sin(radians), 0.0).normalized()


func _spherical_horizon_direction(radius: float) -> Vector3:
	var horizon_sine := -sqrt(1.0 - pow(BODY_RADIUS_M / radius, 2.0))
	return Vector3(
		sqrt(maxf(1.0 - horizon_sine * horizon_sine, 0.0)),
		horizon_sine,
		0.0
	).normalized()


func _unit(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
		and float(value) >= 0.0 and float(value) <= 1.0


func _color_bounded(value: Variant) -> bool:
	if value is not Color:
		return false
	var color := value as Color
	return color.r >= 0.0 and color.r <= 1.0 \
		and color.g >= 0.0 and color.g <= 1.0 \
		and color.b >= 0.0 and color.b <= 1.0 and color.a == 1.0


func _exact_false_dictionary(value: Variant, keys: Array) -> bool:
	if value is not Dictionary:
		return false
	var dictionary := value as Dictionary
	if dictionary.size() != keys.size():
		return false
	for key: String in keys:
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
	return bool(capabilities.spherical_reference_horizon_implemented) \
		and bool(capabilities.airless_visibility_implemented) \
		and bool(capabilities.bounded_clear_sky_attenuation_hint_implemented) \
		and bool(capabilities.bounded_atmospheric_twilight_proxy_implemented) \
		and not bool(capabilities.calibrated_photometry_implemented) \
		and not bool(capabilities.star_spectrum_implemented) \
		and not bool(capabilities.finite_sun_disk_implemented) \
		and not bool(capabilities.terrain_shadow_implemented) \
		and not bool(capabilities.cloud_shadow_implemented) \
		and not bool(capabilities.multiple_scattering_implemented) \
		and not bool(capabilities.renderer_application_implemented) \
		and not bool(capabilities.clock_or_ephemeris_implemented)


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
	print("PLANETARY_SUN_LIGHTING_POLICY_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_SUN_LIGHTING_POLICY_TEST_OK")
		quit(0)
	else:
		print(
			"PLANETARY_SUN_LIGHTING_POLICY_TEST_FAILED: %s"
			% ", ".join(_failures)
		)
		quit(1)
