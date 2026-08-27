extends SceneTree

## One bounded Forward+ review of the production Cinder Reach dock gate from a
## real ship approach distance. The harness owns only its camera/environment;
## route anchors, collision, activity state and gameplay authority remain live
## production composition and are not driven here.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const RESOLUTION := Vector2i(1600, 900)
const OUTPUT_DIR := "res://artifacts/cinder_dock_gate_readability"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus" \
			or RenderingServer.get_rendering_device() == null:
		push_error("CINDER_DOCK_GATE_CAPTURE_FAILED: Forward+ is required")
		quit(1)
		return
	DisplayServer.window_set_size(RESOLUTION)
	root.size = RESOLUTION
	root.msaa_3d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var stage := Node3D.new()
	stage.name = "CinderDockGateCaptureStage"
	root.add_child(stage)
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

	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	cluster.name = "ProductionNearbySectorCluster"
	stage.add_child(cluster)
	cluster.set_process(false)
	cluster.set_physics_process(false)

	var camera := Camera3D.new()
	camera.name = "ShipApproachCamera"
	camera.fov = 52.0
	camera.near = 0.08
	camera.far = 1200.0
	var platform := NearbySectorCluster.PLATFORM_ANCHOR
	# 127 m from the near frame: outside lamp range, where silhouette and
	# material hierarchy must do the navigation work before close-up detail.
	camera.position = platform + Vector3(18.0, 12.0, 222.0)
	camera.look_at_from_position(
		camera.position,
		platform + Vector3(0.0, NearbySectorCluster.GANTRY_CENTER_Y + 2.0, 70.0),
		Vector3.UP
	)
	camera.current = true
	stage.add_child(camera)

	for _frame in 10:
		await process_frame
	var image := root.get_texture().get_image()
	var output := "%s/gameplay_distance_forward_plus.png" % OUTPUT_DIR
	if image.is_empty() or image.get_width() != RESOLUTION.x or image.get_height() != RESOLUTION.y:
		push_error("CINDER_DOCK_GATE_CAPTURE_FAILED: renderer returned an invalid frame")
		quit(1)
		return
	var save_error := image.save_png(ProjectSettings.globalize_path(output))
	if save_error != OK:
		push_error("CINDER_DOCK_GATE_CAPTURE_FAILED: %s" % error_string(save_error))
		quit(1)
		return
	print(
		"CINDER_DOCK_GATE_CAPTURE_OK renderer=%s distance_to_near_frame=127m output=%s"
		% [RenderingServer.get_current_rendering_method(), output]
	)
	quit(0)
