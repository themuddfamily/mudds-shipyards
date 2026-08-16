extends SceneTree

## One-frame Forward+ witness for the twelve visual-only apron guide strips.
## KETH_JOVIAN_BATCH_CAPTURE selects the output path for before/after comparison.

const MODULE_SCENE := preload("res://scenes/world/modules/jovian_freight_berth.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if RenderingServer.get_current_rendering_method() != &"forward_plus":
		push_error("JOVIAN_DOCK_GUIDE_CAPTURE_FAILED: Forward+ is required")
		quit(1)
		return
	root.size = Vector2i(1200, 800)
	root.msaa_3d = Viewport.MSAA_2X
	root.use_taa = false
	var stage := Node3D.new()
	stage.name = "JovianDockGuideBatchWitness"
	root.add_child(stage)
	var module := MODULE_SCENE.instantiate() as JovianFreightBerth
	stage.add_child(module)
	await process_frame
	await physics_frame
	module.set_equipment_animation_enabled(false)
	_build_environment(stage)
	_build_lighting(stage)
	var camera := Camera3D.new()
	camera.name = "DockGuideCamera"
	camera.position = Vector3(22.0, 10.5, -4.0)
	camera.fov = 48.0
	camera.near = 0.08
	camera.far = 180.0
	camera.current = true
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 28.5), Vector3.UP)
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("JOVIAN_DOCK_GUIDE_CAPTURE_FAILED: empty viewport")
		quit(1)
		return
	var output := OS.get_environment("KETH_JOVIAN_BATCH_CAPTURE")
	if output.is_empty():
		output = "res://artifacts/jovian_dock_guides.png"
	var absolute := ProjectSettings.globalize_path(output)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("JOVIAN_DOCK_GUIDE_CAPTURE_FAILED: output directory")
		quit(1)
		return
	var save_error := image.save_png(absolute)
	if save_error != OK:
		push_error("JOVIAN_DOCK_GUIDE_CAPTURE_FAILED: save error %d" % save_error)
		quit(1)
		return
	print(
		"JOVIAN_DOCK_GUIDE_CAPTURE_OK: %s %dx%d"
		% [absolute, image.get_width(), image.get_height()]
	)
	stage.queue_free()
	await process_frame
	quit(0)


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071219")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("73aeb7")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.36
	environment.glow_bloom = 0.05
	environment.ssao_enabled = true
	environment.ssao_radius = 2.1
	environment.ssao_intensity = 1.7
	world_environment.environment = environment
	stage.add_child(world_environment)


func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_color = Color("d8f2f0")
	key.light_energy = 1.05
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 6.0, 27.0)
	fill.light_color = Color("68d9df")
	fill.light_energy = 1.1
	fill.omni_range = 34.0
	fill.shadow_enabled = false
	stage.add_child(fill)
