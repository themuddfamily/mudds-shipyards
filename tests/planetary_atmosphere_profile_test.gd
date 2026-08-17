extends SceneTree

const ProfileScript := preload("res://scripts/world/definitions/planetary_atmosphere_profile.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_valid_profile_and_units()
	_test_strict_bounds_and_relationships()
	_test_detached_snapshots_and_zero_authority()
	_test_resource_round_trip()
	_finish()


func _test_valid_profile_and_units() -> void:
	var profile := _profile()
	_check(profile is Resource, "profile is a reusable Godot Resource")
	_check(profile.is_definition_valid(), "a complete game-scale atmosphere validates")
	var audit: Dictionary = profile.get_audit_report()
	_check(int(audit.schema_version) == ProfileScript.SCHEMA_VERSION, "audit publishes a stable schema version")
	_check(audit.unit_system == &"game_scale_si", "audit freezes the deterministic unit system")
	_check(audit.content_class == &"NEW" and audit.evidence_status == &"modern_interpretation", "evidence rejects a recovered historical claim")
	_check(audit.evidence_scope == &"game_scale_atmosphere_parameters", "evidence is scoped to atmosphere tuning data")
	var geometry := audit.geometry as Dictionary
	var density := audit.density as Dictionary
	var optics := audit.optics as Dictionary
	var weather := audit.weather as Dictionary
	var entry := audit.entry_effects as Dictionary
	var audio := audit.audio_hints as Dictionary
	_check(geometry.planet_radius_m == 6_000.0 and geometry.reference_altitude_m == 0.0 and geometry.atmosphere_top_altitude_m == 1_200.0, "geometry snapshot uses explicit metre fields")
	_check(density.reference_density_kg_m3 == 1.225 and density.density_scale_height_m == 240.0, "density snapshot uses kilograms per cubic metre and metres")
	_check((optics.rayleigh_scattering_per_m as Color).b > 0.0 and optics.maximum_visibility_m == 2_000.0, "optics snapshot carries inverse-metre coefficients and metre visibility")
	_check(weather.wind_velocity_mps == Vector3(12.0, 0.0, -4.0) and weather.weather_intensity_unitless == 0.35, "weather snapshot separates metric wind from normalized intensity")
	_check(entry.start_altitude_m == 1_000.0 and entry.full_altitude_m == 520.0 and entry.minimum_speed_mps == 160.0, "entry-effect thresholds expose altitude and speed units")
	_check(audio.exterior_audio_profile_id == &"temperate_exterior" and audio.interior_attenuation_db == -18.0, "audio values remain stable hints with decibel units")


func _test_strict_bounds_and_relationships() -> void:
	var invalid_id := _profile()
	invalid_id.profile_id = &"Planet-Profile"
	_check(_has_error(invalid_id.get_validation_errors(), "profile_id"), "profile identity rejects non-snake-case IDs")

	var invalid_evidence := _profile()
	invalid_evidence.evidence_references = PackedStringArray(["source_a", "source_a", " padded"])
	var evidence_errors := invalid_evidence.get_validation_errors()
	_check(_has_error(evidence_errors, "duplicated") and _has_error(evidence_errors, "trimmed"), "evidence references reject duplicates and padded data")

	var non_finite := _profile()
	non_finite.planet_radius_m = NAN
	non_finite.wind_velocity_mps = Vector3(0.0, INF, 0.0)
	non_finite.rayleigh_scattering_per_m = Color(NAN, 0.0, 0.0, 1.0)
	var finite_errors := non_finite.get_validation_errors()
	_check(_has_error(finite_errors, "planet_radius_m") and _has_error(finite_errors, "wind_velocity_mps") and _has_error(finite_errors, "rayleigh_scattering_per_m"), "non-finite scalar, vector, and colour data fail closed")

	var out_of_bounds := _profile()
	out_of_bounds.reference_density_kg_m3 = 0.0
	out_of_bounds.fog_density_unitless = 1.1
	out_of_bounds.cloud_coverage_unitless = -0.1
	out_of_bounds.weather_intensity_unitless = 1.01
	out_of_bounds.exterior_wind_gain_db = 25.0
	var range_errors := out_of_bounds.get_validation_errors()
	_check(_has_error(range_errors, "reference_density_kg_m3") and _has_error(range_errors, "fog_density_unitless"), "density and fog bounds are strict")
	_check(_has_error(range_errors, "cloud_coverage_unitless") and _has_error(range_errors, "weather_intensity_unitless"), "cloud and weather normalized bounds are strict")
	_check(_has_error(range_errors, "exterior_wind_gain_db"), "audio hint gains remain bounded")

	var invalid_layers := _profile()
	invalid_layers.reference_altitude_m = 1_200.0
	invalid_layers.cloud_base_altitude_m = 800.0
	invalid_layers.cloud_top_altitude_m = 700.0
	invalid_layers.entry_effect_full_altitude_m = 1_050.0
	invalid_layers.entry_effect_start_altitude_m = 1_000.0
	invalid_layers.entry_effect_minimum_speed_mps = 400.0
	invalid_layers.entry_effect_full_speed_mps = 340.0
	var layer_errors := invalid_layers.get_validation_errors()
	_check(_has_error(layer_errors, "reference_altitude_m must be below") and _has_error(layer_errors, "cloud_base_altitude_m"), "reference and cloud altitude ordering fail closed")
	_check(_has_error(layer_errors, "entry_effect_full_altitude_m") and _has_error(layer_errors, "entry_effect_minimum_speed_mps"), "entry altitude and speed ordering fail closed")

	var invalid_fog := _profile()
	invalid_fog.fog_start_distance_m = 1_800.0
	invalid_fog.fog_end_distance_m = 1_600.0
	invalid_fog.maximum_visibility_m = 1_500.0
	var fog_errors := invalid_fog.get_validation_errors()
	_check(_has_error(fog_errors, "fog_start_distance_m must be below") and _has_error(fog_errors, "fog_end_distance_m must not exceed"), "fog ordering and visibility ceiling fail closed")

	var invalid_ceiling := _profile()
	invalid_ceiling.planet_radius_m = 1_100.0
	invalid_ceiling.cloud_top_altitude_m = 1_250.0
	invalid_ceiling.entry_effect_start_altitude_m = 1_300.0
	var ceiling_errors := invalid_ceiling.get_validation_errors()
	_check(_has_error(ceiling_errors, "atmosphere_top_altitude_m must not exceed planet_radius_m"), "atmosphere height stays within the game-scale body radius")
	_check(_has_error(ceiling_errors, "cloud_top_altitude_m must not exceed") and _has_error(ceiling_errors, "entry_effect_start_altitude_m must not exceed"), "cloud and entry thresholds stay within the atmosphere")

	var invalid_optics := _profile()
	invalid_optics.absorption_per_m = Color(-0.1, 0.0, 0.0, 0.5)
	_check(_has_error(invalid_optics.get_validation_errors(), "absorption_per_m"), "optical coefficients reject negative channels and semantic alpha")

	var invalid_wind := _profile()
	invalid_wind.wind_velocity_mps = Vector3(ProfileScript.MAX_WIND_SPEED_MPS + 0.1, 0.0, 0.0)
	_check(_has_error(invalid_wind.get_validation_errors(), "wind_velocity_mps"), "wind magnitude has a finite game-scale ceiling")

	var invalid_audio_id := _profile()
	invalid_audio_id.interior_audio_profile_id = &"Interior Bus"
	_check(_has_error(invalid_audio_id.get_validation_errors(), "interior_audio_profile_id"), "audio lookup hints use stable IDs")


func _test_detached_snapshots_and_zero_authority() -> void:
	var profile := _profile()
	var audit := profile.get_audit_report()
	(audit.geometry as Dictionary)["planet_radius_m"] = -1.0
	(audit.weather as Dictionary)["cloud_coverage_unitless"] = 9.0
	(audit.evidence_references as PackedStringArray).append("mutation")
	(audit.authority as Dictionary)["renderer"] = true
	var fresh := profile.get_audit_report()
	_check((fresh.geometry as Dictionary).planet_radius_m == 6_000.0, "nested geometry audit data is detached")
	_check((fresh.weather as Dictionary).cloud_coverage_unitless == 0.55, "nested weather audit data is detached")
	_check(not (fresh.evidence_references as PackedStringArray).has("mutation"), "evidence arrays are detached")
	_check(not bool((fresh.authority as Dictionary).renderer), "authority audit mutation cannot alter the profile")

	var weather := profile.get_weather_snapshot()
	weather["weather_intensity_unitless"] = 99.0
	_check(profile.get_weather_snapshot().weather_intensity_unitless == 0.35, "public snapshots are detached from Resource state")

	var authority := profile.get_authority_report()
	var expected_keys := PackedStringArray(["renderer", "gameplay", "weather_clock", "save", "audio", "physics", "world_generation", "network"])
	var all_zero := authority.size() == expected_keys.size()
	for key in expected_keys:
		all_zero = all_zero and authority.has(key) and authority[key] is bool and not bool(authority[key])
	_check(all_zero, "profile explicitly owns zero renderer, gameplay, weather-clock, save, audio, physics, world-generation, or network authority")
	_check(not profile.has_method("_process") and not profile.has_method("_physics_process"), "data profile has no frame or physics lifecycle")


func _test_resource_round_trip() -> void:
	var profile := _profile()
	profile.profile_id = &"round_trip_atmosphere"
	profile.wind_velocity_mps = Vector3(-8.0, 1.5, 2.25)
	profile.evidence_references = PackedStringArray(["phase_10_design_note"])
	var resource_path := "user://planetary_atmosphere_profile_test_%d.tres" % Time.get_ticks_usec()
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var save_error := ResourceSaver.save(profile, resource_path)
	_check(save_error == OK, "profile saves as a normal typed Godot Resource")
	var loaded := ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PlanetaryAtmosphereProfile
	_check(loaded != null, "saved profile reloads with its concrete type")
	if loaded != null:
		_check(loaded.profile_id == &"round_trip_atmosphere" and loaded.wind_velocity_mps == Vector3(-8.0, 1.5, 2.25), "round trip preserves identity and deterministic units")
		_check(loaded.is_definition_valid() and loaded.get_authority_report() == profile.get_authority_report(), "round trip preserves validation and zero authority")
	if FileAccess.file_exists(resource_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		_check(remove_error == OK, "temporary profile Resource is removed")


func _profile() -> PlanetaryAtmosphereProfile:
	return ProfileScript.new() as PlanetaryAtmosphereProfile


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_ATMOSPHERE_PROFILE_TEST_OK")
		quit(0)
	else:
		print("PLANETARY_ATMOSPHERE_PROFILE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
