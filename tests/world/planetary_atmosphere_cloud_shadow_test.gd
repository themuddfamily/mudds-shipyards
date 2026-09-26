extends SceneTree

const CompositionScene := preload("res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn")
const AuroraScene := preload("res://scenes/world/planets/aurora_temperate_world.tscn")
const SOLAR := {"state": &"daylight", "sun_elevation_sine": 0.7, "twilight_factor_unitless": 0.0}
const CAPTURE_DIR_ENV := "MUDDS_CLOUD_SHADOW_CAPTURE_DIR"

var failures := PackedStringArray()
var assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var standalone := CompositionScene.instantiate() as PlanetaryAtmosphereComposition
	root.add_child(standalone)
	await process_frame
	_check(standalone.configure().accepted, "standalone composition configures")
	var standalone_shadow := standalone.get_node(^"OwnedCloudShadowProjection") as MeshInstance3D
	_check(standalone_shadow != null and is_equal_approx(
		standalone_shadow.position.y, standalone.world_definition.body_radius_metres + 0.06
	), "standalone projection has a surface-height fallback")
	standalone.queue_free()
	await process_frame

	var scene := AuroraScene.instantiate() as AuroraTemperateAuthoredScene
	root.add_child(scene)
	await process_frame
	var composition := scene.get_node(^"AuroraAtmosphereComposition") as PlanetaryAtmosphereComposition
	var landing := scene.get_node(^"LandingRegion") as Node3D
	var shadow := composition.get_node(^"OwnedCloudShadowProjection") as MeshInstance3D
	var configured := composition.configure()
	_check(configured.accepted, "production Aurora atmosphere configures")
	_check(shadow != null and shadow.mesh is QuadMesh and (shadow.mesh as QuadMesh).size == Vector2(64.0, 64.0),
		"owned ground projection retains its 64 m footprint")
	_check(shadow != null and shadow.global_position.distance_to(
		landing.to_global(Vector3.UP * 0.06)
	) < 0.02, "projection clears the authored pad by 0.02 m")
	var original_scene_position := scene.position
	scene.position += Vector3(1234.0, 200.0, -2345.0)
	_check(shadow.global_position.distance_to(landing.to_global(Vector3.UP * 0.06)) < 0.02,
		"projection follows a production-world origin shift")
	scene.position = original_scene_position
	var anchored_transform := shadow.transform
	var upper := _present(composition, 10_000.0, int(configured.generation))
	var surface := _present(composition, 100.0, int(configured.generation))
	_check(upper.accepted and surface.accepted and shadow.transform == anchored_transform,
		"altitude transitions retain the ground projection frame and scale")

	var material := shadow.material_override as ShaderMaterial
	var wind := Vector3(15.0, 0.0, -5.0)
	var windy := composition.apply_retained_presentation_recipe(SOLAR, _weather(wind))
	_check(windy.accepted and shadow.visible and composition.is_processing(),
		"authored wind reaches the visible projection")
	var high_opacity := float(material.get_shader_parameter("shadow_opacity"))
	var initial_offset := material.get_shader_parameter("wind_offset_m") as Vector2
	composition._process(3599.0)
	composition._process(2.0)
	var long_offset := material.get_shader_parameter("wind_offset_m") as Vector2
	var expected_long_offset := Vector2(
		fposmod(initial_offset.x + wind.x * 3601.0, 64.0),
		fposmod(initial_offset.y + wind.z * 3601.0, 64.0)
	)
	_check(long_offset.is_equal_approx(expected_long_offset)
		and long_offset.x >= 0.0 and long_offset.x < 64.0
		and long_offset.y >= 0.0 and long_offset.y < 64.0,
		"ground phase stays bounded across the former 3600-second shader rollover")
	var changed_wind := Vector3(-8.0, 0.0, 2.0)
	_check(composition.apply_retained_presentation_recipe(SOLAR, _weather(changed_wind)).accepted
		and (material.get_shader_parameter("wind_offset_m") as Vector2).is_equal_approx(long_offset),
		"changing wind preserves the current ground phase")
	composition._process(0.5)
	var changed_offset := material.get_shader_parameter("wind_offset_m") as Vector2
	_check(changed_offset.is_equal_approx(Vector2(
		fposmod(long_offset.x + changed_wind.x * 0.5, 64.0),
		fposmod(long_offset.y + changed_wind.z * 0.5, 64.0)
	)), "changed wind advects from the retained phase")
	composition.apply_retained_presentation_recipe(SOLAR, _weather(wind))
	_check(composition.apply_graphics_profile(&"medium").accepted and shadow.visible
		and is_equal_approx(float(material.get_shader_parameter("shadow_opacity")), high_opacity * 0.6),
		"medium profile dims the moving pattern")
	_check(composition.apply_graphics_profile(&"low").accepted and not shadow.visible,
		"low profile omits the projection")
	_check(composition.apply_graphics_profile(&"high").accepted and shadow.visible
		and is_equal_approx(float(material.get_shader_parameter("shadow_opacity")), high_opacity),
		"high profile restores the pattern strength")
	var still := composition.apply_retained_presentation_recipe(SOLAR, _weather(Vector3.ZERO))
	_check(still.accepted and not composition.is_processing()
		and (material.get_shader_parameter("wind_offset_m") as Vector2).is_equal_approx(changed_offset),
		"zero wind freezes the projection phase")
	var capture_dir := OS.get_environment(CAPTURE_DIR_ENV)
	if not capture_dir.is_empty():
		await _capture_motion(scene, composition, shadow, material, capture_dir, wind)
	else:
		print("CLOUD_SHADOW_RENDER_NOT_RUN: set %s under isolated X11" % CAPTURE_DIR_ENV)
	composition.apply_retained_presentation_recipe(SOLAR, _weather(wind))

	root.remove_child(scene)
	await process_frame
	root.add_child(scene)
	await process_frame
	_check(shadow.global_position.distance_to(landing.to_global(Vector3.UP * 0.06)) < 0.02
		and shadow.visible and composition.is_processing()
		and bool(composition.audit().valid),
		"streamed re-entry retains the surface anchor and wind recipe")

	print("PLANETARY_ATMOSPHERE_CLOUD_SHADOW_ASSERTIONS: %d" % assertions)
	if failures.is_empty():
		print("PLANETARY_ATMOSPHERE_CLOUD_SHADOW_TEST_OK")
		quit(0)
	else:
		print("PLANETARY_ATMOSPHERE_CLOUD_SHADOW_TEST_FAILED: %s" % ", ".join(failures))
		quit(1)


func _weather(wind: Vector3) -> Dictionary:
	return {
		"intensity_unitless": 0.8,
		"cloud_opacity_unitless": 0.95,
		"gust_factor_unitless": 1.1,
		"shelter_scalar": 0.0,
		"wind_velocity_mps": wind,
	}


func _present(composition: PlanetaryAtmosphereComposition, altitude_m: float, generation: int) -> Dictionary:
	return composition.present_observation({
		"body_local_observer_m": Vector3.UP * (120_000.0 + altitude_m),
		"view_direction_body_local": Vector3.FORWARD,
		"fog_path_distance_m": 12_000.0,
		"speed_mps": 0.0,
		"weather_scalar": 0.4,
		"cloud_scalar": 0.5,
		"caller_time_seconds": 0.0,
	}, generation)


func _capture_motion(
		scene: AuroraTemperateAuthoredScene, composition: PlanetaryAtmosphereComposition,
		shadow: MeshInstance3D, material: ShaderMaterial, capture_dir: String,
		wind: Vector3
	) -> void:
	if DisplayServer.get_name() != "X11":
		_check(false, "render capture runs on isolated X11")
		return
	root.size = Vector2i(960, 720)
	var landing := scene.get_node(^"LandingRegion") as Node3D
	var camera := Camera3D.new()
	camera.near = 0.1
	camera.far = 2000.0
	camera.fov = 62.0
	scene.add_child(camera)
	camera.global_position = landing.global_position + Vector3(0.0, 26.0, 25.0)
	camera.look_at(landing.global_position)
	camera.current = true
	await _settle_draws(5)
	var calm_a := root.get_texture().get_image()
	await create_timer(0.65).timeout
	await _settle_draws(2)
	var calm_b := root.get_texture().get_image()
	var calm_difference := _image_difference(calm_a, calm_b)
	_check(calm_difference < 0.002, "zero-wind ground pattern stays still in rendered frames")
	_check(composition.apply_retained_presentation_recipe(SOLAR, _weather(wind)).accepted
		and shadow.visible and composition.is_processing(),
		"render capture uses the retained authored wind")
	await _settle_draws(5)
	var windy_a := root.get_texture().get_image()
	await create_timer(0.65).timeout
	await _settle_draws(2)
	var windy_b := root.get_texture().get_image()
	var windy_difference := _image_difference(windy_a, windy_b)
	_check(windy_difference > calm_difference + 0.003,
		"wind visibly advects the projected ground pattern")
	var moving_offset := material.get_shader_parameter("wind_offset_m") as Vector2
	paused = true
	await create_timer(0.35, true, false, true).timeout
	await _settle_draws(2)
	_check((material.get_shader_parameter("wind_offset_m") as Vector2).is_equal_approx(moving_offset),
		"scene pause freezes the wind phase")
	paused = false
	Engine.time_scale = 0.0
	var unscaled_offset := material.get_shader_parameter("wind_offset_m") as Vector2
	await create_timer(0.35, true, false, true).timeout
	await _settle_draws(2)
	_check((material.get_shader_parameter("wind_offset_m") as Vector2).is_equal_approx(unscaled_offset),
		"zero game time scale freezes the wind phase")
	Engine.time_scale = 1.0
	_check(composition.apply_retained_presentation_recipe(SOLAR, _weather(Vector3.ZERO)).accepted,
		"wind can stop after moving across the ground")
	await _settle_draws(2)
	var stopped_a := root.get_texture().get_image()
	await create_timer(0.65).timeout
	await _settle_draws(2)
	var stopped_b := root.get_texture().get_image()
	var stopped_difference := _image_difference(stopped_a, stopped_b)
	_check(stopped_difference < 0.002, "zero wind freezes the last advected pattern")
	_check(_image_difference(windy_b, stopped_a) < 0.002,
		"stopping wind does not jump to a different pattern")
	var retained_offset := material.get_shader_parameter("wind_offset_m") as Vector2
	material.set_shader_parameter("wind_offset_m", retained_offset + Vector2(64.0, 64.0))
	await _settle_draws(2)
	var tiled_phase := root.get_texture().get_image()
	_check(_image_difference(stopped_b, tiled_phase) < 0.002,
		"one full ground-pattern period has no visible seam")
	material.set_shader_parameter("wind_offset_m", retained_offset)
	var directory := DirAccess.open(capture_dir)
	_check(directory != null, "capture directory exists")
	if directory != null:
		_check(windy_a.save_png(capture_dir.path_join("cloud_shadow_wind_t0.png")) == OK,
			"first production-scene capture saves")
		_check(windy_b.save_png(capture_dir.path_join("cloud_shadow_wind_t1.png")) == OK,
			"second production-scene capture saves")
	print("CLOUD_SHADOW_RENDER_DIFFERENCE: calm=%.6f windy=%.6f stopped=%.6f transition=%.6f" % [
		calm_difference, windy_difference, stopped_difference, _image_difference(windy_b, stopped_a)
	])
	camera.queue_free()


func _settle_draws(count: int) -> void:
	for index in count:
		await RenderingServer.frame_post_draw


func _image_difference(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return INF
	var total := 0.0
	var samples := 0
	for y in range(a.get_height() / 4, a.get_height() * 3 / 4, 4):
		for x in range(a.get_width() / 4, a.get_width() * 3 / 4, 4):
			var one := a.get_pixel(x, y)
			var two := b.get_pixel(x, y)
			total += absf(one.r - two.r) + absf(one.g - two.g) + absf(one.b - two.b)
			samples += 3
	return total / float(samples)


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: %s" % label)
