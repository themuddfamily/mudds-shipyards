extends SceneTree

## One stable Forward+ contact sheet, with each panel 85 m behind its beacon on
## that beacon's real incoming leg. The production cluster stays intact so all
## four stepped silhouettes are inspectable against their actual route depth,
## debris, moonlet, and destination rather than an isolated model stage.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const RESOLUTION := Vector2i(1600, 900)
const OUTPUT_DIR := "res://artifacts/cinder_beacon_outbound_depth_visual"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus" \
			or RenderingServer.get_rendering_device() == null:
		push_error("CINDER_BEACON_OUTBOUND_DEPTH_CAPTURE_FAILED: Forward+ is required")
		quit(1)
		return
	DisplayServer.window_set_size(RESOLUTION)
	root.size = RESOLUTION
	root.msaa_3d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var stage := Node3D.new()
	stage.name = "CinderBeaconOutboundDepthCaptureStage"
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050b12")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7192ad")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe0b0")
	key.light_energy = 1.55
	key.rotation_degrees = Vector3(-28.0, -34.0, 0.0)
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("69b8db")
	fill.light_energy = 0.42
	fill.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
	stage.add_child(fill)

	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	cluster.name = "ProductionNearbySectorCluster"
	stage.add_child(cluster)
	cluster.set_process(false)
	cluster.set_physics_process(false)

	var camera := Camera3D.new()
	camera.name = "OutboundShipCamera"
	camera.fov = 42.0
	camera.near = 0.08
	camera.far = 1200.0
	camera.current = true
	stage.add_child(camera)

	var sheet := Image.create(RESOLUTION.x, RESOLUTION.y, false, Image.FORMAT_RGBA8)
	var previous := Vector3(0.0, 8.0, -64.0)
	for index in NearbySectorCluster.ROUTE_BEACON_SPECS.size():
		var target := NearbySectorCluster.ROUTE_BEACON_SPECS[index]["position"] as Vector3
		camera.position = target + (previous - target).normalized() * 85.0
		camera.look_at_from_position(camera.position, target + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		previous = target
		for _frame in 6:
			await process_frame
		var panel := root.get_texture().get_image()
		if panel.is_empty() or panel.get_size() != RESOLUTION:
			push_error("CINDER_BEACON_OUTBOUND_DEPTH_CAPTURE_FAILED: renderer returned an invalid panel")
			quit(1)
			return
		panel.convert(Image.FORMAT_RGBA8)
		panel.resize(RESOLUTION.x / 2, RESOLUTION.y / 2, Image.INTERPOLATE_LANCZOS)
		var panel_origin := Vector2i(
			(index % 2) * panel.get_width(), (index / 2) * panel.get_height()
		)
		sheet.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), panel_origin)
	var output := "%s/gameplay_distance_forward_plus.png" % OUTPUT_DIR
	var save_error := sheet.save_png(ProjectSettings.globalize_path(output))
	if save_error != OK:
		push_error("CINDER_BEACON_OUTBOUND_DEPTH_CAPTURE_FAILED: %s" % error_string(save_error))
		quit(1)
		return
	print(
		"CINDER_BEACON_OUTBOUND_DEPTH_CAPTURE_OK renderer=%s panels=4 approach_distance=85m output=%s"
		% [RenderingServer.get_current_rendering_method(), output]
	)
	quit(0)
