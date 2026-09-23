extends SceneTree

const SCENE := preload("res://scenes/world/planets/aurora_temperate_world.tscn")

var failures := PackedStringArray()
var assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := SCENE.instantiate() as AuroraTemperateAuthoredScene
	root.add_child(scene)
	await process_frame
	var atmosphere := scene.get_node("AuroraAtmosphereComposition") as PlanetaryAtmosphereComposition
	var configured := atmosphere.configure()
	check(configured.accepted, "production Aurora atmosphere configures")
	if not configured.accepted:
		_finish()
		return
	var rig := atmosphere.get_atmosphere_rig()
	var environment := atmosphere.get_world_environment().environment
	var sky := environment.sky.sky_material as ProceduralSkyMaterial
	var vacuum := _present(atmosphere, 30_000.0, configured.generation)
	var vacuum_ambient := environment.ambient_light_energy
	var vacuum_horizon := sky.sky_horizon_color
	var vacuum_fog := environment.fog_density
	check(vacuum.accepted and vacuum_ambient < 0.3 and vacuum_horizon.b < 0.1
		and is_zero_approx(vacuum_fog), "orbit has a dark sky, weak ambient fill, and no fog")
	var upper := _present(atmosphere, 10_000.0, configured.generation)
	var upper_ambient := environment.ambient_light_energy
	var upper_horizon := sky.sky_horizon_color
	var recipe := atmosphere.apply_retained_presentation_recipe(
		{"state": &"daylight", "sun_elevation_sine": 0.6, "twilight_factor_unitless": 0.0},
		{"intensity_unitless": 0.3, "cloud_opacity_unitless": 0.2, "altitude_m": 10_000.0}
	)
	var recipe_ambient := environment.ambient_light_energy
	var repeated := _present(atmosphere, 10_000.0, configured.generation)
	check(recipe.accepted and repeated.accepted and recipe_ambient < upper_ambient
		and is_equal_approx(environment.ambient_light_energy, recipe_ambient),
		"solar and weather updates retain altitude attenuation on repeated observations")
	var surface := _present(atmosphere, 100.0, configured.generation)
	var surface_ambient := environment.ambient_light_energy
	var surface_horizon := sky.sky_horizon_color
	check(upper.accepted and surface.accepted and vacuum_ambient < recipe_ambient
		and recipe_ambient < surface_ambient, "ambient fill rises continuously through the atmospheric descent")
	check(vacuum_horizon.b < upper_horizon.b and upper_horizon.b < surface_horizon.b
		and environment.fog_density > vacuum_fog,
		"Aurora's horizon brightens and coastal fog returns below the atmosphere")
	var invalid := _present(atmosphere, 100.0, configured.generation + 1)
	check(not invalid.accepted and is_equal_approx(environment.ambient_light_energy, surface_ambient),
		"stale observations cannot change the installed atmosphere")
	root.remove_child(scene)
	await process_frame
	root.add_child(scene)
	await process_frame
	check(atmosphere.get_world_environment().environment == environment
		and is_equal_approx(environment.ambient_light_energy, surface_ambient)
		and bool(atmosphere.audit().valid) and not atmosphere.is_processing()
		and not rig.is_processing(), "streamed scene re-entry retains the last altitude without a process loop")
	_finish()


func _present(atmosphere: PlanetaryAtmosphereComposition, altitude_m: float, generation: int) -> Dictionary:
	return atmosphere.present_observation({
		"body_local_observer_m": Vector3.UP * (120_000.0 + altitude_m),
		"view_direction_body_local": Vector3.FORWARD,
		"fog_path_distance_m": 12_000.0,
		"speed_mps": 0.0,
		"weather_scalar": 0.4,
		"cloud_scalar": 0.5,
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
	print("AURORA_ATMOSPHERE_ALTITUDE_ASSERTIONS: %d" % assertions)
	if failures.is_empty():
		print("AURORA_ATMOSPHERE_ALTITUDE_TEST_OK")
		quit(0)
	else:
		print("AURORA_ATMOSPHERE_ALTITUDE_TEST_FAILED: %s" % ", ".join(failures))
		quit(1)
