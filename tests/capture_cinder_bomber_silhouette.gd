extends SceneTree

## Stable gameplay-distance presentation capture for the NEW Cinder bomber.
## The harness owns only its evidence camera and lighting; it does not exercise
## flight, collision, payload, berth, or gameplay authority.

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const RESOLUTION := Vector2i(1600, 900)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--lod-review"):
		await _run_lod_review()
		return
	var label := OS.get_environment("MUDDS_CINDER_BOMBER_CAPTURE_LABEL")
	if label.is_empty():
		label = "current"
	var output_dir := "res://artifacts/cinder_bomber_silhouette/%s" % label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	root.size = RESOLUTION
	var stage := Node3D.new()
	stage.name = "CinderBomberCaptureStage"
	root.add_child(stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("718ba3")
	environment.ambient_light_energy = 0.48
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0d5")
	key.light_energy = 2.4
	key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("6fc8ff")
	rim.light_energy = 0.72
	rim.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
	stage.add_child(rim)

	var bomber := Bomber.new() as CinderLongRangeBomber
	bomber.name = "CaptureCinderLongRangeBomber"
	stage.add_child(bomber)
	bomber.set_process(false)
	bomber.set_physics_process(false)

	var camera := Camera3D.new()
	camera.name = "GameplayDistanceChaseCamera"
	camera.fov = 42.0
	camera.near = 0.1
	camera.far = 160.0
	camera.position = Vector3(17.5, 10.5, 32.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.45, 1.5), Vector3.UP)
	camera.current = true
	stage.add_child(camera)

	for _frame in 8:
		await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/gameplay_distance_chase.png" % output_dir
	var save_error := image.save_png(ProjectSettings.globalize_path(path))
	if save_error != OK:
		push_error("Cinder bomber silhouette capture failed to save: %s" % error_string(save_error))
		quit(1)
		return
	print("CINDER_BOMBER_SILHOUETTE_CAPTURE %s" % path)
	quit(0)


## Opt-in native production-camera panels; the default capture above is unchanged.
func _run_lod_review() -> void:
	create_timer(270.0).timeout.connect(func() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		push_error("CINDER_BOMBER_LOD_REVIEW_TIMEOUT")
		quit(1))
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output = argument.trim_prefix("--output-dir=")
	_check(output.is_absolute_path(), "LOD review requires an absolute output directory")
	if not output.is_absolute_path():
		_finish()
		return
	_check(DirAccess.make_dir_recursive_absolute(output) == OK, "LOD output directory exists")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 720)
	await process_frame
	_check(root.size == Vector2i(1920, 720)
		and DisplayServer.window_get_size() == Vector2i(1920, 720)
		and root.content_scale_size == Vector2i.ZERO
		and root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED
		and root.get_visible_rect().size == Vector2(1920, 720),
		"native 1920x720 window and disabled content scaling match the declared layout")
	_check(RenderingServer.get_current_rendering_method() == &"forward_plus"
		and not RenderingServer.get_video_adapter_name().is_empty(),
		"LOD review uses a live Forward+ rendering device")
	var viewports: Array[SubViewport] = []
	var crafts: Array[CinderLongRangeBomber] = []
	var containers: Array[SubViewportContainer] = []
	var camera_fovs: Array[float] = []
	var names := ["near_40m", "far_150m", "cockpit"]
	for index in 3:
		var container := SubViewportContainer.new()
		container.name = "LODPanel" + str(index)
		container.position = Vector2(index * 640, 0)
		container.size = Vector2(640, 720)
		container.stretch = false
		root.add_child(container)
		containers.append(container)
		var viewport := SubViewport.new()
		viewport.name = "ProductionView" + str(index)
		viewport.size = Vector2i(640, 720)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_2X
		viewport.use_taa = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		viewports.append(viewport)
		var stage := Node3D.new()
		viewport.add_child(stage)
		_build_environment(stage)
		var craft := Bomber.new() as CinderLongRangeBomber
		stage.add_child(craft)
		crafts.append(craft)
		craft.set_process(false)
		craft.set_physics_process(false)
		craft.set_piloted(true)
		craft.set_cockpit_view(index == 2)
		# Only this fixture extends the production chase-distance ceiling.
		craft.maximum_chase_camera_distance = 150.0 if index == 1 else 40.0
		craft.set_chase_camera_distance(150.0 if index == 1 else 40.0)
		craft.call("_update_presentation", 10.0, ShipCommand.new())
		craft.get_camera().make_current()
		camera_fovs.append(craft.get_camera().fov)
	for _frame in 24:
		await physics_frame
		await process_frame
	for craft: CinderLongRangeBomber in crafts:
		# Freeze child CameraBoundaryMount as well as the HeroShip callback after
		# its real spring-arm sweep settles; rendering/camera ownership stay live.
		craft.process_mode = Node.PROCESS_MODE_DISABLED
		craft.call("_update_exterior_lod_from_current_camera")
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var panels: Array[Image] = []
	for index in 3:
		var viewport := viewports[index]
		var craft := crafts[index]
		var camera := viewport.get_camera_3d()
		var report := craft.get_exterior_lod_report()
		var distance := camera.global_position.distance_to(craft.get_variant_visual_root().global_position)
		var expected := 1 if index == 1 else 0
		_check(viewport.size == Vector2i(640, 720)
			and viewport.get_visible_rect().size == Vector2(640, 720)
			and containers[index].position == Vector2(index * 640, 0)
			and containers[index].size == Vector2(640, 720) and not containers[index].stretch,
			"panel %s has exact native viewport and unscaled 640x720 layout" % names[index])
		_check(camera == craft.get_camera() and camera.get_viewport() == viewport
			and craft.is_ancestor_of(camera) and camera.current
			and camera.name == (&"CockpitCamera" if index == 2 else &"ShipCamera")
			and is_equal_approx(camera.fov, camera_fovs[index])
			and report.valid and report.active_lod == expected,
			"panel %s selects the actual production camera and complete exterior" % names[index])
		if index < 2:
			_check((distance > 120.0 if index == 1 else distance < 100.0)
				and is_equal_approx(craft.get_chase_camera_distance(), 150.0 if index == 1 else 40.0),
				"panel %s uses requested production chase distance and actual threshold" % names[index])
			var visible_corners := 0
			for x in [-8.3, 8.3]:
				for y in [-1.6, 5.5]:
					for z in [-7.75, 8.7]:
						if camera.is_position_in_frustum(craft.to_global(Vector3(x, y, z))):
							visible_corners += 1
			_check(visible_corners == 8,
				"panel %s contains the complete authored bomber hull/wing/engine/cockpit envelope (%d/8)" % [names[index], visible_corners])
		else:
			var readout := craft.get("_cockpit_readout") as Label3D
			_check(readout != null and readout.is_visible_in_tree()
				and camera.near <= 0.05
				and (-camera.global_basis.z).dot(-craft.global_basis.z) > 0.999,
				"cockpit keeps its physical pilot eye, forward alignment and live instruments")
		var sensor_layer := CinderLongRangeBomber.EXTERIOR_SENSOR_VISUAL_LAYER
		_check(((camera.cull_mask & sensor_layer) == 0) == (index == 2),
			"actual production camera preserves the cockpit/exterior sensor mask")
		for representation: Node in [craft.get_variant_visual_root(), craft.get("_exterior_lod_far")]:
			for sensor_name in ["LongRangeSensor", "SensorProtectiveCowl"]:
				var sensor := representation.get_node(NodePath(sensor_name)) as GeometryInstance3D
				_check(sensor.layers == sensor_layer, "sensor and cowl retain their layer in each representation")
		print("CINDER_BOMBER_LOD_REVIEW_PANEL: name=", names[index], " actual_camera=", camera.get_path(),
			" distance=", distance, " fov=", camera.fov, " lod=", report.active_lod,
			" close_triangles=", report.close_triangles, " far_triangles=", report.far_triangles)
		var panel := viewport.get_texture().get_image()
		_check(panel != null and not panel.is_empty() and panel.get_size() == Vector2i(640, 720),
			"panel %s returns an actual unscaled 640x720 image" % names[index])
		if panel == null or panel.is_empty() or panel.get_size() != Vector2i(640, 720):
			continue
		panels.append(panel)
		var path := output.path_join(names[index] + ".png")
		_check(panel.save_png(path) == OK and Image.load_from_file(path).get_size() == Vector2i(640, 720),
			"panel %s saves a real 640x720 PNG" % names[index])
	if panels.size() == 3:
		var strip := Image.create(1920, 720, false, panels[0].get_format())
		for index in 3:
			strip.blit_rect(panels[index], Rect2i(0, 0, 640, 720), Vector2i(index * 640, 0))
		var strip_path := output.path_join("bomber_lod_review_strip.png")
		_check(strip.get_size() == Vector2i(1920, 720) and strip.save_png(strip_path) == OK
			and Image.load_from_file(strip_path).get_size() == Vector2i(1920, 720),
			"three native panels assemble and save an exact 1920x720 strip without resizing")
		for index in 3:
			_check(strip.get_region(Rect2i(index * 640, 0, 640, 720)).get_data() == panels[index].get_data(),
				"strip panel %s preserves every native source pixel" % names[index])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for container: SubViewportContainer in containers:
		container.queue_free()
	await process_frame
	_finish()


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7ea6b0")
	environment.ambient_light_energy = 0.36
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.5
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.name = "CabinReviewKey"
	key.rotation_degrees = Vector3(-38.0, -24.0, 0.0)
	key.light_color = Color("ffe3bf")
	key.light_energy = 1.55
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.name = "CabinReviewFill"
	fill.position = Vector3(-0.8, 1.0, 1.8)
	fill.light_color = Color("62d7df")
	fill.light_energy = 0.8
	fill.omni_range = 8.0
	fill.shadow_enabled = false
	stage.add_child(fill)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_BOMBER_LOD_REVIEW_OK")
		quit(0)
		return
	print("CINDER_BOMBER_LOD_REVIEW_FAILED: ", "; ".join(_failures))
	quit(1)
