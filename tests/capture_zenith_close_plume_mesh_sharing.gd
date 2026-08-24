extends SceneTree

## One bounded Forward+ aft view of two production Zenith instances. The left
## craft is online and the right craft is offline, proving both close plume
## copies remain readable while visibility and materials stay instance-local.

const ZENITH_SCENE := preload("res://scenes/ships/zenith_interceptor.tscn")
const OUTPUT_DIR := "/tmp/mudds-wave31-zenith-close-plumes"
const CAPTURE_SIZE := Vector2i(1600, 900)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_SIZE
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
		and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture uses a live Forward+ renderer"
	)

	var world := Node3D.new()
	root.add_child(world)
	_install_environment(world)

	var online := ZENITH_SCENE.instantiate() as ZenithInterceptor
	var offline := ZENITH_SCENE.instantiate() as ZenithInterceptor
	world.add_child(online)
	world.add_child(offline)
	online.position = Vector3(-8.2, 0.0, 0.0)
	offline.position = Vector3(8.2, 0.0, 0.0)
	online.rotation_degrees.y = 12.0
	offline.rotation_degrees.y = 12.0
	await process_frame
	await physics_frame
	online.engine_start_time = 0.01
	online.set_piloted(true)
	online.request_engine_start()
	await physics_frame
	online.velocity = Vector3(0.0, 0.0, -online.maximum_speed)
	online.call(&"_update_zenith_engine_presentation", 1.0)
	online.set_physics_process(false)
	offline.set_physics_process(false)

	var online_parts := _plume_parts(online)
	var offline_parts := _plume_parts(offline)
	var online_port := online_parts.get("port") as MeshInstance3D
	var online_starboard := online_parts.get("starboard") as MeshInstance3D
	var online_batch := online_parts.get("batch") as MultiMeshInstance3D
	var offline_port := offline_parts.get("port") as MeshInstance3D
	var offline_starboard := offline_parts.get("starboard") as MeshInstance3D
	var offline_batch := offline_parts.get("batch") as MultiMeshInstance3D
	var expect_shared := OS.get_environment(
		"MUDDS_ZENITH_EXPECT_SHARED"
	).strip_edges() != "0"
	_check(
		online_port != null and online_starboard != null
		and offline_port != null and offline_starboard != null
		and (online_port.mesh == online_starboard.mesh) == expect_shared
		and (offline_port.mesh == offline_starboard.mesh) == expect_shared,
		"both Zenith instances match the requested close-plume mesh-sharing state"
	)
	_check(
		online_batch != null and online_batch.multimesh != null
		and offline_batch != null and offline_batch.multimesh != null
		and online_batch.multimesh.instance_count == 2
		and offline_batch.multimesh.instance_count == 2
		and online_batch.visible and online_batch.multimesh.visible_instance_count == 2
		and not offline_batch.visible and offline_batch.multimesh.visible_instance_count == 0
		and online_port.visible and online_starboard.visible
		and not offline_port.visible and not offline_starboard.visible,
		"online craft renders both close plumes while the offline instance remains dark"
	)
	var online_material := online_port.material_override as StandardMaterial3D
	var offline_material := offline_port.material_override as StandardMaterial3D
	_check(
		online_material != null and offline_material != null
		and online_material != offline_material
		and online_port.material_override == online_starboard.material_override
		and offline_port.material_override == offline_starboard.material_override
		and online_material.albedo_color.is_equal_approx(offline_material.albedo_color)
		and online_material.emission.is_equal_approx(offline_material.emission)
		and is_equal_approx(
			online_material.emission_energy_multiplier,
			offline_material.emission_energy_multiplier
		),
		"equal plume recipes remain instance-local with no material-state leakage"
	)

	_add_label(world, "ONLINE — 2 DYNAMIC PLUMES", Vector3(-8.2, 5.0, 3.4))
	_add_label(world, "OFFLINE — PLUMES HIDDEN", Vector3(8.2, 5.0, 3.4))
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 8.5, 28.0)
	camera.near = 0.05
	camera.far = 120.0
	camera.fov = 49.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.9, 3.2), Vector3.UP)
	camera.current = true

	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_SIZE,
		"close aft comparison renders at 1600x900"
	)
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
		var variant := OS.get_environment("MUDDS_ZENITH_CAPTURE_VARIANT").strip_edges()
		if variant.is_empty():
			variant = "after"
		var output_path := OUTPUT_DIR.path_join("zenith_close_plumes_%s.png" % variant)
		var compare_path := OS.get_environment("MUDDS_ZENITH_COMPARE_PATH").strip_edges()
		if not compare_path.is_empty():
			var comparison := Image.load_from_file(compare_path)
			_check(
				comparison != null and not comparison.is_empty()
				and comparison.get_size() == image.get_size()
				and comparison.get_data() == image.get_data(),
				"before/after Forward+ pixels are exactly identical"
			)
		_check(image.save_png(output_path) == OK, "capture saves successfully")
		print("ZENITH_CLOSE_PLUME_CAPTURE: ", output_path)

	world.queue_free()
	await process_frame
	_finish()


func _plume_parts(craft: ZenithInterceptor) -> Dictionary:
	var asset := craft.get_zenith_authored_presentation().get_asset_root() as Node3D
	return {
		"port": asset.get_node_or_null(^"ModernSystems/LOD0/PortEnginePlume"),
		"starboard": asset.get_node_or_null(^"ModernSystems/LOD0/StarboardEnginePlume"),
		"batch": asset.get_node_or_null(^"ModernSystems/LOD0/CloseEnginePlumeBatch"),
	}


func _install_environment(world: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050b12")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7595ad")
	environment.ambient_light_energy = 0.36
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.48
	environment.glow_bloom = 0.08
	world_environment.environment = environment
	world.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -24.0, 0.0)
	key.light_color = Color("d8eaff")
	key.light_energy = 1.25
	key.shadow_enabled = true
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(18.0, 154.0, 0.0)
	rim.light_color = Color("6cd9e8")
	rim.light_energy = 0.65
	world.add_child(rim)


func _add_label(world: Node3D, text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = 48
	label.pixel_size = 0.006
	label.outline_size = 8
	label.modulate = Color("e8f4ff")
	label.no_depth_test = true
	world.add_child(label)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ZENITH_CLOSE_PLUME_CAPTURE_OK: ", OUTPUT_DIR)
		quit(0)
	else:
		quit(1)
