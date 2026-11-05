extends SceneTree

const DEFAULT_OUTPUT_DIR := "res://artifacts"
var _output_override := OS.get_environment("MUDDS_CAPTURE_OUTPUT_DIR")
var OUTPUT_DIR := DEFAULT_OUTPUT_DIR if _output_override.is_empty() else _output_override
const FREIGHTER_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")

var _failures: Array[String] = []
var _viewport: SubViewport
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--lod-review"):
		await _run_lod_review()
		return
	# An explicit override must name one canonical local filesystem directory.
	var absolute_output := OUTPUT_DIR.begins_with("/") and not OUTPUT_DIR.begins_with("//")
	if OS.get_name() == "Windows":
		absolute_output = OUTPUT_DIR.length() > 3 and OUTPUT_DIR.substr(1, 2) == ":/" \
			and "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(OUTPUT_DIR.left(1).to_upper())
	if not _output_override.is_empty() and (not absolute_output \
			or OUTPUT_DIR.contains("\\") or OUTPUT_DIR.ends_with("/") \
			or OUTPUT_DIR != OUTPUT_DIR.strip_edges() or OUTPUT_DIR != OUTPUT_DIR.simplify_path()):
		push_error("MUDDS_CAPTURE_OUTPUT_DIR must be a canonical absolute local directory")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_viewport = SubViewport.new()
	_viewport.name = "JovianForwardEvidenceViewport"
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(_viewport)
	var world := Node3D.new()
	world.name = "JovianEvidenceWorld"
	_viewport.add_child(world)

	var environment := WorldEnvironment.new()
	var resource := Environment.new()
	resource.background_mode = Environment.BG_COLOR
	resource.background_color = Color("071522")
	resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	resource.ambient_light_color = Color("90adc0")
	resource.ambient_light_energy = 0.34
	resource.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	resource.tonemap_mode = Environment.TONE_MAPPER_AGX
	resource.glow_enabled = true
	resource.glow_intensity = 0.28
	environment.environment = resource
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-36.0, -38.0, 0.0)
	key.light_color = Color("f5e6c9")
	key.light_energy = 1.9
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20.0, 145.0, 0.0)
	fill.light_color = Color("68a9c8")
	fill.light_energy = 0.7
	world.add_child(fill)

	var floor := StaticBody3D.new()
	floor.name = "EvidenceLandingDeck"
	floor.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	world.add_child(floor)
	var floor_mesh := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(70, 0.25, 60)
	var deck_material := StandardMaterial3D.new()
	deck_material.albedo_color = Color("182b35")
	deck_material.metallic = 0.62
	deck_material.roughness = 0.4
	deck_mesh.material = deck_material
	floor_mesh.mesh = deck_mesh
	floor_mesh.position.y = -1.43
	floor.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(70, 0.25, 60)
	floor_collision.shape = floor_box
	floor_collision.position.y = -1.43
	floor.add_child(floor_collision)
	for line_x in [-22.0, -11.0, 0.0, 11.0, 22.0]:
		var line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(0.15, 0.04, 55.0)
		var line_material := StandardMaterial3D.new()
		line_material.albedo_color = Color("3bc9c1")
		line_material.emission_enabled = true
		line_material.emission = Color("1a7775")
		line_material.emission_energy_multiplier = 1.1
		line_mesh.material = line_material
		line.mesh = line_mesh
		line.position = Vector3(line_x, -1.28, 0.0)
		world.add_child(line)

	var jovian := FREIGHTER_SCENE.instantiate() as JovianLightFreighter
	world.add_child(jovian)
	await _frames(8)
	_check(jovian.get_jovian_audit_report().valid, "evidence scene uses an audited Jovian candidate")
	_camera = Camera3D.new()
	_camera.name = "EvidenceCamera"
	_camera.near = 0.08
	_camera.far = 1000.0
	world.add_child(_camera)
	_camera.current = true

	_frame_camera(Vector3(24.5, 13.5, -25.0), Vector3(0.0, 1.35, -0.5), 48.0)
	await _frames(8)
	await _capture("jovian_freighter_exterior.png")

	_frame_camera(Vector3(-18.0, 5.5, 10.0), Vector3(-4.8, 1.25, 3.0), 52.0)
	await _frames(8)
	await _capture("jovian_cargo_ramp.png")

	_frame_camera(jovian.to_global(Vector3(0.0, 2.05, 8.05)), jovian.to_global(Vector3(0.0, 1.45, -2.65)), 67.0)
	await _frames(8)
	await _capture("jovian_cargo_interior.png")

	_frame_camera(jovian.to_global(Vector3(0.0, 1.85, -6.9)), jovian.to_global(Vector3(0.0, 1.5, -2.55)), 68.0)
	await _frames(8)
	await _capture("jovian_passenger_cabin.png")

	await _dispose(world)
	if _failures.is_empty():
		print("JOVIAN_FORWARD_CAPTURES_OK: 4 rendered states")
		quit(0)
	else:
		print("JOVIAN_FORWARD_CAPTURES_FAILED: ", ", ".join(_failures))
		quit(1)


func _frame_camera(position: Vector3, target: Vector3, field_of_view: float) -> void:
	_camera.global_position = position
	_camera.look_at(target, Vector3.UP)
	_camera.fov = field_of_view


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("%s produced no image" % file_name)
		return
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(path)
	if error != OK:
		_fail("%s could not be saved" % file_name)
		return
	var absolute := ProjectSettings.globalize_path(path)
	var size := FileAccess.get_file_as_bytes(absolute).size()
	_check(image.get_width() == 1280 and image.get_height() == 720, "%s has target dimensions" % file_name)
	_check(size > 16384, "%s contains substantive rendered evidence" % file_name)
	print("CAPTURED: ", absolute, " (", size, " bytes)")


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _dispose(node: Node) -> void:
	node.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("FAIL: " + description)


## Opt-in native production-camera panels; the default capture above is unchanged.
func _run_lod_review() -> void:
	create_timer(270.0).timeout.connect(func() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		push_error("JOVIAN_LOD_REVIEW_TIMEOUT")
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
	var crafts: Array[JovianLightFreighter] = []
	var containers: Array[SubViewportContainer] = []
	var camera_fovs: Array[float] = []
	var names := ["near_70m", "far_150m", "cockpit"]
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
		var craft := FREIGHTER_SCENE.instantiate() as JovianLightFreighter
		stage.add_child(craft)
		crafts.append(craft)
		craft.set_process(false)
		craft.set_physics_process(false)
		craft.set_piloted(true)
		craft.set_cockpit_view(index == 2)
		# Only this fixture extends the production chase-distance ceiling.
		craft.maximum_chase_camera_distance = 150.0 if index == 1 else 70.0
		craft.set_chase_camera_distance(150.0 if index == 1 else 70.0)
		craft.call("_update_presentation", 10.0, ShipCommand.new())
		craft.get_camera().make_current()
		camera_fovs.append(craft.get_camera().fov)
	for _frame in 24:
		await physics_frame
		await process_frame
	for craft: JovianLightFreighter in crafts:
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
				and is_equal_approx(craft.get_chase_camera_distance(), 150.0 if index == 1 else 70.0),
				"panel %s uses requested production chase distance and actual threshold" % names[index])
			var visible_corners := 0
			for x in [-10.6, 8.5]:
				for y in [-1.36, 4.95]:
					for z in [-14.1, 14.45]:
						if camera.is_position_in_frustum(craft.to_global(Vector3(x, y, z))):
							visible_corners += 1
			_check(visible_corners == 8,
				"panel %s contains the complete authored jovian hull/wing/engine/cockpit envelope (%d/8)" % [names[index], visible_corners])
		else:
			var readout := craft.get("_cockpit_readout") as Label3D
			_check(readout != null and readout.is_visible_in_tree()
				and camera.near <= 0.05
				and (-camera.global_basis.z).dot(-craft.global_basis.z) > 0.999
				and craft.get_cockpit_quality_report().forward_sight_clear,
				"cockpit keeps its physical pilot eye, forward alignment and live instruments")
		print("JOVIAN_LOD_REVIEW_PANEL: name=", names[index], " actual_camera=", camera.get_path(),
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
		var strip_path := output.path_join("jovian_lod_review_strip.png")
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


func _finish() -> void:
	if _failures.is_empty():
		print("JOVIAN_LOD_REVIEW_OK")
		quit(0)
		return
	print("JOVIAN_LOD_REVIEW_FAILED: ", "; ".join(_failures))
	quit(1)
