extends SceneTree

## Rime's atmosphere attenuates with altitude against its own 14 km top, the
## way Aurora's does against 20 km: above the top the sky is orbital-dark with
## weak ambient fill and no fog, and the retained recipe's aerial ramp and the
## composition audit are Rime's own. Rime's streaming bootstrap also exposes the
## optional flight-effects seams Aurora's has.

const RIME_SCENE := preload("res://scenes/world/planets/rime_glacial_world.tscn")
const AURORA_COMPOSITION := preload("res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn")
const AURORA_WORLD := preload("res://assets/world/planets/aurora_temperate_world.tres")
const RIME_BODY_RADIUS_M := 120_000.0

var failures := PackedStringArray()
var assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RIME_SCENE.instantiate() as RimeGlacialAuthoredScene
	root.add_child(scene)
	await process_frame
	var atmosphere := scene.get_node("RimeAtmosphereComposition") as PlanetaryAtmosphereComposition
	var top := atmosphere.atmosphere_profile.atmosphere_top_altitude_m
	check(is_equal_approx(top, 14_000.0), "Rime's own atmosphere top is 14 km")
	var audit := atmosphere.audit()
	check(bool(audit.valid) and (audit.authored_scene_errors as PackedStringArray).is_empty()
		and audit.world_id == &"rime_glacial_world",
		"Rime's composition audits valid against its own world and scene, not Aurora's path")
	var configured := atmosphere.configure()
	check(configured.accepted, "production Rime atmosphere configures")
	if not configured.accepted:
		_finish()
		return
	var environment := atmosphere.get_world_environment().environment
	var sky := environment.sky.sky_material as ProceduralSkyMaterial

	var high_orbit := _present(atmosphere, 30_000.0, configured.generation)
	var high_ambient := environment.ambient_light_energy
	var above_top := _present(atmosphere, 15_000.0, configured.generation)
	var above_ambient := environment.ambient_light_energy
	var above_horizon := sky.sky_horizon_color
	var above_fog := environment.fog_density
	check(high_orbit.accepted and above_top.accepted
		and is_equal_approx(above_ambient, high_ambient) and is_zero_approx(above_fog),
		"15 km is already above Rime's air: ambient is at its orbital floor and fog is gone")

	var upper := _present(atmosphere, 8_000.0, configured.generation)
	var upper_ambient := environment.ambient_light_energy
	var upper_horizon := sky.sky_horizon_color
	var surface := _present(atmosphere, 100.0, configured.generation)
	var surface_ambient := environment.ambient_light_energy
	var surface_horizon := sky.sky_horizon_color
	check(upper.accepted and surface.accepted and above_ambient < upper_ambient
		and upper_ambient < surface_ambient and above_ambient < surface_ambient * 0.3,
		"ambient fill rises continuously from Rime's orbital floor down to the ice")
	check(above_horizon.b < upper_horizon.b and upper_horizon.b <= surface_horizon.b
		and environment.fog_density > above_fog,
		"Rime's horizon brightens and the ice haze returns below its atmosphere top")

	var recipe := atmosphere.apply_retained_presentation_recipe(
		{"state": &"daylight", "sun_elevation_sine": 0.6, "twilight_factor_unitless": 0.0},
		{"intensity_unitless": 0.3, "cloud_opacity_unitless": 0.2, "altitude_m": 7_000.0}
	)
	check(recipe.accepted and is_equal_approx(float(recipe.aerial_factor_unitless), 0.5),
		"the recipe's aerial ramp is relative to Rime's 14 km top (7 km is halfway)")

	# The same altitude is still inside Aurora's taller atmosphere.
	var aurora := AURORA_COMPOSITION.instantiate() as PlanetaryAtmosphereComposition
	root.add_child(aurora)
	await process_frame
	var aurora_configured := aurora.configure()
	var aurora_environment := aurora.get_world_environment().environment
	_present(aurora, 30_000.0, aurora_configured.generation, 12_000.0)
	var aurora_orbit_ambient := aurora_environment.ambient_light_energy
	_present(aurora, 15_000.0, aurora_configured.generation, 12_000.0)
	check(aurora_configured.accepted and bool(aurora.audit().valid)
		and aurora_environment.ambient_light_energy > aurora_orbit_ambient,
		"at 15 km Aurora is still inside its 20 km atmosphere while Rime is not")

	# A composition naming another world's resources is not Rime's contract.
	atmosphere.world_definition = AURORA_WORLD
	var mismatched := atmosphere.audit()
	check(not bool(mismatched.valid)
		and (mismatched.authored_scene_errors as PackedStringArray).has("atmosphere_profile_not_world_atmosphere")
		and (mismatched.authored_scene_errors as PackedStringArray).has("composition_outside_its_world_scene"),
		"the audit rejects a Rime composition wired to Aurora's world definition")
	atmosphere.world_definition = load("res://assets/world/planets/rime_glacial_world.tres")
	check(bool(atmosphere.audit().valid), "restoring Rime's own definition restores the contract")

	# Rime's bootstrap exposes the optional flight-effects seams.
	var bootstrap := RimeGlacialStreamingBootstrap.new()
	root.add_child(bootstrap)
	await process_frame
	check(bootstrap.has_method(&"get_atmosphere_weather_scalar")
		and is_equal_approx(bootstrap.get_atmosphere_weather_scalar(), 0.66),
		"Rime presents the flight effects its own heavier weather scalar")
	var accepted := bootstrap.set_surface_atmosphere_state(0.4, 0.9, 12.5)
	var rejected := bootstrap.set_surface_atmosphere_state(1.5, 0.2, 1.0)
	var audio := bootstrap.get_snapshot().get("surface_audio", {}) as Dictionary
	check(accepted.accepted and not rejected.accepted
		and is_equal_approx(float(audio.get("interior_blend", -1.0)), 0.4)
		and is_equal_approx(float(audio.get("wind_strength", -1.0)), 0.9)
		and is_equal_approx(float(audio.get("weather_clock_seconds", -1.0)), 12.5),
		"Rime accepts the smoothed interior blend, gust and weather clock and refuses bad state")
	bootstrap.clear_surface_atmosphere_state()
	audio = bootstrap.get_snapshot().get("surface_audio", {}) as Dictionary
	check(float(audio.get("interior_blend", 0.0)) < 0.0
		and float(audio.get("wind_strength", 0.0)) < 0.0
		and is_zero_approx(float(audio.get("weather_clock_seconds", 1.0))),
		"clearing returns Rime's surface atmosphere state to not-supplied")

	bootstrap.queue_free()
	aurora.queue_free()
	scene.queue_free()
	await process_frame
	_finish()


func _present(
		atmosphere: PlanetaryAtmosphereComposition, altitude_m: float, generation: int,
		fog_path_m := 6_000.0,
	) -> Dictionary:
	return atmosphere.present_observation({
		"body_local_observer_m": Vector3.UP * (RIME_BODY_RADIUS_M + altitude_m),
		"view_direction_body_local": Vector3.FORWARD,
		"fog_path_distance_m": fog_path_m,
		"speed_mps": 0.0,
		"weather_scalar": 0.66,
		"cloud_scalar": 0.74,
		"caller_time_seconds": 0.0,
	}, generation)


func check(condition: bool, label: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % label)
	else:
		failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	print("RIME_ATMOSPHERE_ALTITUDE_ASSERTIONS: %d" % assertions)
	if failures.is_empty():
		print("RIME_ATMOSPHERE_ALTITUDE_TEST_OK")
		quit(0)
	else:
		print("RIME_ATMOSPHERE_ALTITUDE_TEST_FAILED: %s" % ", ".join(failures))
		quit(1)
