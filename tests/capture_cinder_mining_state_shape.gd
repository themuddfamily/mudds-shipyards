extends SceneTree

## Three HUD-free Forward+ panels of the Cinder mining platform at one normal
## ship-approach camera: available, active extraction, and completed/capacity-full.
## Run under Xvfb Vulkan Forward+; authority transitions come only from the
## production binding and the harness adds no gameplay state or geometry.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const RESOLUTION := Vector2i(1600, 900)
const OUTPUT_DIRECTORY := "res://artifacts/cinder_mining_state_shape"
const PANEL_PATHS := [
	OUTPUT_DIRECTORY + "/gameplay_distance_available.png",
	OUTPUT_DIRECTORY + "/gameplay_distance_active.png",
	OUTPUT_DIRECTORY + "/gameplay_distance_capacity_full.png",
]
const TRIPTYCH_PATH := OUTPUT_DIRECTORY + "/gameplay_distance_state_triptych.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus" \
			or RenderingServer.get_rendering_device() == null:
		push_error("CINDER_MINING_STATE_SHAPE_CAPTURE_FAILED: Xvfb Vulkan Forward+ is required")
		quit(1)
		return
	DisplayServer.window_set_size(RESOLUTION)
	root.size = RESOLUTION
	root.msaa_3d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))

	var stage := Node3D.new()
	root.add_child(stage)
	_add_lighting(stage)
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	stage.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	_add_gameplay_distance_camera(stage)

	var panels: Array[Image] = []
	var available := cluster.get_mining_activity_presentation_state()
	if available.get("state_id", &"") != &"available" \
			or available.get("shape_id", &"") != &"open_gate":
		_fail("available panel did not apply")
		return
	panels.append(await _capture_panel(PANEL_PATHS[0]))
	if panels.back() == null:
		return

	var started := binding.start_mining_activity(CinderMiningPlatformActivity.APPROACH_ANCHOR)
	var active := cluster.get_mining_activity_presentation_state()
	if not bool(started.get("accepted", false)) \
			or active.get("state_id", &"") != &"extracting" \
			or active.get("shape_id", &"") != &"crossed_x":
		_fail("active panel did not apply")
		return
	panels.append(await _capture_panel(PANEL_PATHS[1]))
	if panels.back() == null:
		return

	var completed := binding.advance_mining_activity(CinderMiningPlatformActivity.EXTRACTION_SECONDS)
	var capacity_full := cluster.get_mining_activity_presentation_state()
	if not bool(completed.get("accepted", false)) \
			or capacity_full.get("state_id", &"") != &"secured" \
			or capacity_full.get("shape_id", &"") != &"locked_roof" \
			or not bool(capacity_full.get("capacity_ready_geometry", false)):
		_fail("completed/capacity-full panel did not apply")
		return
	panels.append(await _capture_panel(PANEL_PATHS[2]))
	if panels.back() == null:
		return

	if panels[0].get_data() == panels[1].get_data() \
			or panels[1].get_data() == panels[2].get_data() \
			or panels[0].get_data() == panels[2].get_data():
		_fail("all three state panels must render distinct frames")
		return
	var triptych := Image.create(
		RESOLUTION.x * panels.size(), RESOLUTION.y, false, panels[0].get_format()
	)
	for panel_index in panels.size():
		triptych.blit_rect(
			panels[panel_index], Rect2i(Vector2i.ZERO, RESOLUTION),
			Vector2i(panel_index * RESOLUTION.x, 0)
		)
	var save_error := triptych.save_png(ProjectSettings.globalize_path(TRIPTYCH_PATH))
	if save_error != OK:
		_fail("could not save triptych: %s" % error_string(save_error))
		return
	print("CINDER_MINING_STATE_SHAPE_CAPTURE_OK: available | active | capacity-full -> %s" % TRIPTYCH_PATH)
	quit(0)


func _capture_panel(output_path: String) -> Image:
	for _frame in 8:
		await process_frame
	var image := root.get_texture().get_image()
	if image.is_empty() or image.get_size() != RESOLUTION or image.get_used_rect().size == Vector2i.ZERO:
		_fail("renderer returned an invalid panel for %s" % output_path)
		return null
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		_fail("could not save %s: %s" % [output_path, error_string(save_error)])
		return null
	return image


func _add_gameplay_distance_camera(stage: Node3D) -> void:
	var camera := Camera3D.new()
	camera.fov = 52.0
	camera.near = 0.08
	camera.far = 1200.0
	var platform := NearbySectorCluster.PLATFORM_ANCHOR
	# A 190 m starboard-high approach keeps the detached dock gate from
	# occluding the headframe while remaining at real piloting distance.
	camera.position = platform + Vector3(48.0, 32.0, 180.0)
	camera.look_at_from_position(
		camera.position,
		platform + Vector3(0.0, 22.0, -4.0),
		Vector3.UP
	)
	camera.current = true
	stage.add_child(camera)


func _fail(message: String) -> void:
	push_error("CINDER_MINING_STATE_SHAPE_CAPTURE_FAILED: %s" % message)
	quit(1)


func _add_lighting(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050b12")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7690a9")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe4bf")
	key.light_energy = 1.7
	key.rotation_degrees = Vector3(-34.0, -28.0, 0.0)
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("68bce0")
	fill.light_energy = 0.48
	fill.rotation_degrees = Vector3(-12.0, 145.0, 0.0)
	stage.add_child(fill)
