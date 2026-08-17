extends SceneTree

const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)
const SamplerScript := preload(
	"res://scripts/world/planetary_atmosphere_sampler.gd"
)

const EXPECTED_ASSERTIONS := 22
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configuration_snapshot_and_invalid_input()
	_test_density_optics_and_vacuum_boundaries()
	_test_cloud_wind_entry_and_optional_scalars()
	_test_timestep_independence_and_detached_audit()
	_finish()


func _test_configuration_snapshot_and_invalid_input() -> void:
	var unconfigured := SamplerScript.new() as PlanetaryAtmosphereSampler
	_check(
		unconfigured.sample(0.0, 0.0, 0.0).reason == &"not_configured"
			and not bool(unconfigured.audit().valid),
		"an unconfigured sampler rejects sampling and fails its audit closed"
	)
	var invalid_profile := _profile()
	invalid_profile.reference_density_kg_m3 = NAN
	var rejected := unconfigured.configure(invalid_profile)
	_check(
		rejected.reason == &"invalid_profile"
			and not unconfigured.is_configured(),
		"a non-finite source profile is rejected without partially configuring"
	)

	var profile := _profile()
	var original_density := profile.reference_density_kg_m3
	var original_wind := profile.wind_velocity_mps
	var sampler := SamplerScript.new() as PlanetaryAtmosphereSampler
	var configured := sampler.configure(profile)
	var before_reconfigure := sampler.get_snapshot()
	var duplicate := sampler.configure(_profile())
	_check(
		bool(configured.accepted)
			and configured.reason == &"configured"
			and sampler.is_configured()
			and duplicate.reason == &"already_configured"
			and float(before_reconfigure.geometry.planet_radius_m) == 120_000.0
			and float(before_reconfigure.geometry.atmosphere_top_altitude_m) \
				== 20_000.0
			and sampler.get_snapshot() == before_reconfigure,
		"the updated 120km body and 20km shell configure one immutable sampler exactly once"
	)
	profile.reference_density_kg_m3 = 99.0
	profile.wind_velocity_mps = Vector3(499.0, 0.0, 0.0)
	profile.cloud_coverage_unitless = 0.0
	var frozen_sample := sampler.sample(0.0, 0.0, 0.0)
	_check(
		is_equal_approx(float(frozen_sample.density_kg_m3), original_density)
			and (sampler.get_snapshot().weather as Dictionary).wind_velocity_mps \
				== original_wind
			and is_equal_approx(
				float((sampler.get_snapshot().weather as Dictionary).cloud_coverage_unitless),
				0.55
			),
		"the sampler retains detached values and never follows caller profile mutation"
	)

	var before_invalid := sampler.get_snapshot()
	var invalid_altitude := sampler.sample(NAN, 0.0, 0.0)
	var invalid_path := sampler.sample(0.0, INF, 0.0)
	var path_above_bound := sampler.sample(
		0.0, ProfileScript.MAX_VISIBILITY_M + 1.0, 0.0
	)
	var invalid_speed := sampler.sample(0.0, 0.0, -0.01)
	var speed_above_bound := sampler.sample(
		0.0, 0.0, ProfileScript.MAX_ENTRY_SPEED_MPS + 1.0
	)
	var altitude_below_body := sampler.sample(
		-float(sampler.get_snapshot().geometry.planet_radius_m) - 1.0,
		0.0,
		0.0
	)
	var invalid_weather := sampler.sample(0.0, 0.0, 0.0, INF)
	var invalid_cloud := sampler.sample(0.0, 0.0, 0.0, 0.5, 1.01)
	_check(
		invalid_altitude.reason == &"invalid_altitude"
			and invalid_path.reason == &"invalid_path_distance"
			and path_above_bound.reason == &"invalid_path_distance"
			and invalid_speed.reason == &"invalid_speed"
			and speed_above_bound.reason == &"invalid_speed"
			and altitude_below_body.reason == &"invalid_altitude"
			and invalid_weather.reason == &"invalid_weather_intensity"
			and invalid_cloud.reason == &"invalid_cloud_coverage"
			and sampler.get_snapshot() == before_invalid,
		"non-finite altitude/path, negative speed, and invalid optional scalars reject without drift"
	)


func _test_density_optics_and_vacuum_boundaries() -> void:
	var sampler := _sampler()
	var profile := _profile()
	var below := sampler.sample(-500.0, 0.0, 0.0, 0.0, 0.0)
	var optical_path_m := profile.maximum_visibility_m
	var reference := sampler.sample(
		profile.reference_altitude_m, optical_path_m, 0.0, 1.0, 0.0
	)
	_check(
		bool(below.below_reference_altitude)
			and is_equal_approx(float(below.density_ratio), 1.0)
			and is_equal_approx(
				float(below.density_kg_m3), profile.reference_density_kg_m3
			)
			and not bool(reference.below_reference_altitude)
			and is_equal_approx(float(reference.density_ratio), 1.0),
		"below-reference density clamps to the reference value and the exact reference is not below"
	)

	var one_scale_height := sampler.sample(
		profile.reference_altitude_m + profile.density_scale_height_m,
		0.0,
		0.0,
		0.0,
		0.0
	)
	var expected_ratio := exp(-1.0)
	_check(
		is_equal_approx(float(one_scale_height.density_ratio), expected_ratio)
			and is_equal_approx(
				float(one_scale_height.density_kg_m3),
				profile.reference_density_kg_m3 * expected_ratio
			),
		"one scale height follows the documented exponential falloff exactly"
	)

	var depth := reference.optical_depth_rgb as Color
	var expected_depth_r := (
		profile.rayleigh_scattering_per_m.r
		+ profile.mie_scattering_per_m.r
		+ profile.absorption_per_m.r
	) * optical_path_m
	var expected_depth_g := (
		profile.rayleigh_scattering_per_m.g
		+ profile.mie_scattering_per_m.g
		+ profile.absorption_per_m.g
	) * optical_path_m
	var expected_depth_b := (
		profile.rayleigh_scattering_per_m.b
		+ profile.mie_scattering_per_m.b
		+ profile.absorption_per_m.b
	) * optical_path_m
	var expected_luminance := Vector3(
		expected_depth_r, expected_depth_g, expected_depth_b
	).dot(SamplerScript.LUMINANCE_WEIGHTS)
	_check(
		is_equal_approx(depth.r, expected_depth_r)
			and is_equal_approx(depth.g, expected_depth_g)
			and is_equal_approx(depth.b, expected_depth_b)
			and is_equal_approx(
				float(reference.optical_depth_unitless), expected_luminance
			)
			and is_equal_approx(
				float(reference.optical_transmittance_unitless),
				exp(-expected_luminance)
			),
		"homogeneous path optical depth sums profile extinction channels and Beer-Lambert transmittance"
	)
	var zero_path := sampler.sample(
		profile.reference_altitude_m, 0.0, 0.0, 1.0, 0.0
	)
	var fog_start := sampler.sample(
		profile.reference_altitude_m,
		profile.fog_start_distance_m,
		0.0,
		1.0,
		0.0
	)
	_check(
		zero_path.optical_depth_rgb == Color(0.0, 0.0, 0.0, 1.0)
			and zero_path.optical_transmittance_rgb \
				== Color(1.0, 1.0, 1.0, 1.0)
			and zero_path.fog_factor == 0.0
			and fog_start.fog_factor == 0.0,
		"zero optical path and the exact fog-start boundary have zero depth and fog"
	)

	var fog_mid_path := (
		profile.fog_start_distance_m + profile.fog_end_distance_m
	) * 0.5
	var fog_mid := sampler.sample(
		profile.reference_altitude_m, fog_mid_path, 0.0, 0.5, 0.0
	)
	var expected_fog := 0.5 * profile.fog_density_unitless * 0.5
	var strongest_extinction := maxf(
		profile.rayleigh_scattering_per_m.r
			+ profile.mie_scattering_per_m.r
			+ profile.absorption_per_m.r,
		maxf(
			profile.rayleigh_scattering_per_m.g
				+ profile.mie_scattering_per_m.g
				+ profile.absorption_per_m.g,
			profile.rayleigh_scattering_per_m.b
				+ profile.mie_scattering_per_m.b
				+ profile.absorption_per_m.b
		)
	)
	var expected_visibility := minf(
		profile.maximum_visibility_m, 1.0 / strongest_extinction
	)
	_check(
		is_equal_approx(float(fog_mid.fog_factor), expected_fog)
			and is_equal_approx(float(reference.visibility_m), expected_visibility),
		"smooth path fog and one-optical-depth visibility follow the documented bounded equations"
	)
	var fog_end := sampler.sample(
		profile.reference_altitude_m,
		profile.fog_end_distance_m,
		0.0,
		1.0,
		0.0
	)
	_check(
		is_equal_approx(
			float(fog_end.fog_factor), profile.fog_density_unitless
		),
		"the exact fog-end boundary reaches the authored bounded density, not forced opacity"
	)

	var clear_profile := _profile()
	clear_profile.rayleigh_scattering_per_m = Color(0.0, 0.0, 0.0, 1.0)
	clear_profile.mie_scattering_per_m = Color(0.0, 0.0, 0.0, 1.0)
	clear_profile.absorption_per_m = Color(0.0, 0.0, 0.0, 1.0)
	var clear_sampler := SamplerScript.new() as PlanetaryAtmosphereSampler
	var clear_configured := clear_sampler.configure(clear_profile)
	var clear_sample := clear_sampler.sample(
		0.0, ProfileScript.MAX_VISIBILITY_M, 0.0, 0.0, 0.0
	)
	_check(
		bool(clear_configured.accepted)
			and clear_sample.extinction_per_m == Color(0.0, 0.0, 0.0, 1.0)
			and clear_sample.optical_depth_rgb == Color(0.0, 0.0, 0.0, 1.0)
			and clear_sample.optical_transmittance_rgb \
				== Color(1.0, 1.0, 1.0, 1.0)
			and clear_sample.visibility_m == clear_profile.maximum_visibility_m,
		"a valid zero-extinction profile yields unit transmittance and maximum visibility"
	)

	var just_below_top := sampler.sample(
		profile.atmosphere_top_altitude_m - 0.001,
		profile.maximum_visibility_m,
		profile.entry_effect_full_speed_mps,
		1.0,
		1.0
	)
	var exact_top := sampler.sample(
		profile.atmosphere_top_altitude_m,
		profile.maximum_visibility_m,
		profile.entry_effect_full_speed_mps,
		1.0,
		1.0
	)
	var above_top := sampler.sample(
		profile.atmosphere_top_altitude_m + 1000.0,
		profile.maximum_visibility_m,
		profile.entry_effect_full_speed_mps,
		1.0,
		1.0
	)
	_check(
		float(just_below_top.density_ratio) > 0.0
			and not bool(just_below_top.vacuum)
			and _is_exact_vacuum(exact_top, profile.maximum_visibility_m)
			and _is_exact_vacuum(above_top, profile.maximum_visibility_m),
		"the top boundary is exact vacuum while the representable point below remains atmospheric"
	)


func _test_cloud_wind_entry_and_optional_scalars() -> void:
	var sampler := _sampler()
	var profile := _profile()
	var below_cloud_base := sampler.sample(
		profile.cloud_base_altitude_m - 0.001, 0.0, 0.0, 0.0, 0.8
	)
	var cloud_base := sampler.sample(
		profile.cloud_base_altitude_m, 0.0, 0.0, 0.0, 0.8
	)
	var just_below_cloud_top := sampler.sample(
		profile.cloud_top_altitude_m - 0.001, 0.0, 0.0, 0.0, 0.8
	)
	var cloud_top := sampler.sample(
		profile.cloud_top_altitude_m, 0.0, 0.0, 0.0, 0.8
	)
	var expected_cloud := profile.cloud_coverage_unitless * 0.8
	_check(
		is_zero_approx(float(below_cloud_base.cloud_layer_factor))
			and is_equal_approx(
				float(cloud_base.cloud_layer_factor), expected_cloud
			)
			and is_equal_approx(
				float(just_below_cloud_top.cloud_layer_factor), expected_cloud
			)
			and is_zero_approx(float(cloud_top.cloud_layer_factor)),
		"the cloud box is base-inclusive, top-exclusive, and scales frozen profile coverage"
	)
	var profile_cloud := sampler.sample(
		profile.cloud_base_altitude_m, 0.0, 0.0
	)
	_check(
		is_equal_approx(
			float(profile_cloud.cloud_layer_factor),
			profile.cloud_coverage_unitless
		)
			and is_equal_approx(
				float(profile_cloud.inputs.effective_weather_intensity_unitless),
				profile.weather_intensity_unitless
			),
		"omitted normalized multipliers preserve the frozen profile weather and cloud hints"
	)
	var clear_weather := sampler.sample(
		profile.cloud_base_altitude_m, 0.0, 0.0, 0.0, 0.0
	)
	_check(
		clear_weather.wind_velocity_mps == Vector3.ZERO
			and clear_weather.cloud_layer_factor == 0.0
			and clear_weather.inputs.effective_weather_intensity_unitless == 0.0
			and clear_weather.inputs.effective_cloud_coverage_unitless == 0.0,
		"zero optional multipliers produce exact zero wind, cloud, and effective weather hints"
	)

	var wind_altitude := profile.density_scale_height_m
	var wind_sample := sampler.sample(wind_altitude, 0.0, 0.0, 0.5, 0.0)
	var expected_wind := profile.wind_velocity_mps * 0.5
	_check(
		(wind_sample.wind_velocity_mps as Vector3).is_equal_approx(expected_wind),
		"wind preserves the frozen metric direction and scales only by the explicit weather multiplier"
	)

	var middle_altitude := (
		profile.entry_effect_start_altitude_m
		+ profile.entry_effect_full_altitude_m
	) * 0.5
	var middle_speed := (
		profile.entry_effect_minimum_speed_mps
		+ profile.entry_effect_full_speed_mps
	) * 0.5
	var entry_middle := sampler.sample(middle_altitude, 0.0, middle_speed)
	var entry_start := sampler.sample(
		profile.entry_effect_start_altitude_m,
		0.0,
		profile.entry_effect_full_speed_mps
	)
	var entry_minimum := sampler.sample(
		profile.entry_effect_full_altitude_m,
		0.0,
		profile.entry_effect_minimum_speed_mps
	)
	var entry_full := sampler.sample(
		profile.entry_effect_full_altitude_m,
		0.0,
		profile.entry_effect_full_speed_mps
	)
	_check(
		is_equal_approx(float(entry_middle.entry_effect_intensity), 0.25)
			and is_zero_approx(float(entry_start.entry_effect_intensity))
			and is_zero_approx(float(entry_minimum.entry_effect_intensity))
			and is_equal_approx(float(entry_full.entry_effect_intensity), 1.0),
		"entry intensity multiplies exact linear altitude and speed envelopes"
	)

	var bounded := sampler.sample(
		-profile.planet_radius_m,
		ProfileScript.MAX_VISIBILITY_M,
		ProfileScript.MAX_ENTRY_SPEED_MPS,
		1.0,
		1.0
	)
	_check(
		bool(bounded.accepted)
			and _sample_outputs_are_bounded(bounded, profile),
		"maximum supported path/speed at the body-centre altitude still produces bounded outputs"
	)


func _test_timestep_independence_and_detached_audit() -> void:
	var sampler := _sampler()
	var sample_input := [333.25, 7_777.0, 287.5, 0.62, 0.41]
	var baseline := sampler.sample(
		sample_input[0], sample_input[1], sample_input[2],
		sample_input[3], sample_input[4]
	)
	var equivalent := true
	for sample_count in [30, 60, 120]:
		var latest: Dictionary = {}
		for _index in sample_count:
			latest = sampler.sample(
				sample_input[0], sample_input[1], sample_input[2],
				sample_input[3], sample_input[4]
			)
		equivalent = equivalent and latest == baseline
	_check(
		equivalent,
		"30, 60, and 120 equivalent calls return the same pure timestep-free sample"
	)

	var mutable_result := baseline.duplicate(true)
	(mutable_result.inputs as Dictionary)["altitude_m"] = NAN
	mutable_result["density_ratio"] = 99.0
	var snapshot := sampler.get_snapshot()
	(snapshot.weather as Dictionary)["weather_intensity_unitless"] = 99.0
	var audit := sampler.audit()
	(audit.snapshot as Dictionary)["profile_id"] = &"forged"
	(audit.authority as Dictionary)["renderer"] = true
	var repeated := sampler.sample(
		sample_input[0], sample_input[1], sample_input[2],
		sample_input[3], sample_input[4]
	)
	_check(
		repeated == baseline
			and is_equal_approx(
				float((sampler.get_snapshot().weather as Dictionary).weather_intensity_unitless),
				0.35
			)
			and sampler.get_snapshot().profile_id == &"sampler_profile"
			and not bool(sampler.audit().authority.renderer),
		"results, nested inputs, snapshots, and audits are deeply detached"
	)

	var authority := sampler.audit().authority as Dictionary
	var authority_free := true
	for key: String in authority:
		authority_free = authority_free and not bool(authority[key])
	_check(
		bool(sampler.audit().valid)
			and authority_free
			and not sampler.has_method("_process")
			and not sampler.has_method("_physics_process")
			and not bool(sampler.audit().purity.delta_or_clock_input)
			and not bool(sampler.audit().purity.mutates_source_profile)
			and not bool(sampler.audit().purity.mutates_sampler_during_sample),
		"the sampler has no lifecycle and owns zero renderer, physics, ship, gameplay, clock, audio, save, generation, or network authority"
	)


func _profile() -> PlanetaryAtmosphereProfile:
	var profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	profile.profile_id = &"sampler_profile"
	return profile


func _sampler() -> PlanetaryAtmosphereSampler:
	var sampler := SamplerScript.new() as PlanetaryAtmosphereSampler
	var configured := sampler.configure(_profile())
	if not bool(configured.get("accepted", false)):
		_failures.append("fixture failed to configure: %s" % configured)
	return sampler


func _is_exact_vacuum(candidate: Dictionary, maximum_visibility_m: float) -> bool:
	var extinction := candidate.extinction_per_m as Color
	var optical := candidate.optical_depth_rgb as Color
	var transmittance := candidate.optical_transmittance_rgb as Color
	return bool(candidate.vacuum) \
		and candidate.density_ratio == 0.0 \
		and candidate.density_kg_m3 == 0.0 \
		and extinction == Color(0.0, 0.0, 0.0, 1.0) \
		and optical == Color(0.0, 0.0, 0.0, 1.0) \
		and candidate.optical_depth_unitless == 0.0 \
		and transmittance == Color(1.0, 1.0, 1.0, 1.0) \
		and candidate.optical_transmittance_unitless == 1.0 \
		and candidate.visibility_m == maximum_visibility_m \
		and candidate.fog_factor == 0.0 \
		and candidate.cloud_layer_factor == 0.0 \
		and candidate.wind_velocity_mps == Vector3.ZERO \
		and candidate.entry_effect_intensity == 0.0


func _sample_outputs_are_bounded(
		candidate: Dictionary,
		profile: PlanetaryAtmosphereProfile
	) -> bool:
	var optical := candidate.optical_depth_rgb as Color
	var extinction := candidate.extinction_per_m as Color
	var transmittance := candidate.optical_transmittance_rgb as Color
	var wind := candidate.wind_velocity_mps as Vector3
	return float(candidate.density_ratio) >= 0.0 \
		and float(candidate.density_ratio) <= 1.0 \
		and float(candidate.density_kg_m3) >= 0.0 \
		and float(candidate.density_kg_m3) <= profile.reference_density_kg_m3 \
		and _color_is_finite(extinction) \
		and extinction.r >= 0.0 and extinction.r <= SamplerScript.MAX_EXTINCTION_PER_M \
		and extinction.g >= 0.0 and extinction.g <= SamplerScript.MAX_EXTINCTION_PER_M \
		and extinction.b >= 0.0 and extinction.b <= SamplerScript.MAX_EXTINCTION_PER_M \
		and _color_is_finite(optical) \
		and optical.r >= 0.0 and optical.r <= SamplerScript.MAX_OPTICAL_DEPTH_UNITLESS \
		and optical.g >= 0.0 and optical.g <= SamplerScript.MAX_OPTICAL_DEPTH_UNITLESS \
		and optical.b >= 0.0 and optical.b <= SamplerScript.MAX_OPTICAL_DEPTH_UNITLESS \
		and _color_is_finite(transmittance) \
		and transmittance.r >= 0.0 and transmittance.r <= 1.0 \
		and transmittance.g >= 0.0 and transmittance.g <= 1.0 \
		and transmittance.b >= 0.0 and transmittance.b <= 1.0 \
		and float(candidate.optical_transmittance_unitless) >= 0.0 \
		and float(candidate.optical_transmittance_unitless) <= 1.0 \
		and float(candidate.visibility_m) >= 0.0 \
		and float(candidate.visibility_m) <= profile.maximum_visibility_m \
		and float(candidate.fog_factor) >= 0.0 and float(candidate.fog_factor) <= 1.0 \
		and float(candidate.cloud_layer_factor) >= 0.0 \
		and float(candidate.cloud_layer_factor) <= 1.0 \
		and wind.is_finite() and wind.length() <= ProfileScript.MAX_WIND_SPEED_MPS \
		and float(candidate.entry_effect_intensity) >= 0.0 \
		and float(candidate.entry_effect_intensity) <= 1.0


func _color_is_finite(value: Color) -> bool:
	return is_finite(value.r) \
		and is_finite(value.g) \
		and is_finite(value.b) \
		and is_finite(value.a)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion harness expected %d checks but ran %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("PLANETARY_ATMOSPHERE_SAMPLER_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr(
		"PLANETARY_ATMOSPHERE_SAMPLER_TEST_FAILED: %d / %d assertions failed"
		% [_failures.size(), _assertions]
	)
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
