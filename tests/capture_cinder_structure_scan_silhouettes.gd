extends SceneTree

## One Forward+ gameplay-distance contact sheet for the production Cinder scan.
## It reapplies detached presentation snapshots only: scan anchors, volumes,
## timing, reward flow, persistence, and authority remain the live composition.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const OUTPUT := "res://artifacts/cinder_structure_scan_states/gameplay_distance_forward_plus.png"
const RESOLUTION := Vector2i(1600, 900)
const CAMERA_POSITION := Vector3(80.0, -45.0, -615.0)
const CAMERA_TARGET := Vector3(80.0, -50.0, -695.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if RenderingServer.get_current_rendering_method() != &"forward_plus" \
			or RenderingServer.get_rendering_device() == null:
		push_error("CINDER_STRUCTURE_SCAN_SILHOUETTE_CAPTURE_FAILED: Forward+ is required")
		quit(1)
		return
	DisplayServer.window_set_size(RESOLUTION)
	root.size = RESOLUTION
	root.msaa_3d = Viewport.MSAA_2X
	var stage := Node3D.new()
	stage.name = "CinderStructureScanSilhouetteCapture"
	root.add_child(stage)
	_add_environment(stage)
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	stage.add_child(cluster)
	var camera := Camera3D.new()
	camera.name = "CinderScanGameplayDistanceCamera"
	camera.position = CAMERA_POSITION
	camera.fov = 52.0
	camera.near = 0.1
	camera.far = 1000.0
	camera.current = true
	stage.add_child(camera)
	camera.look_at(CAMERA_TARGET, Vector3.UP)
	for _frame in 10:
		await process_frame

	var panels: Array[Image] = []
	for state in [&"available", &"scanning", &"completed"]:
		var result: Dictionary = cluster.call(
			"_apply_structure_scan_activity_presentation", _snapshot_for(state)
		)
		if not bool(result.get("accepted", false)):
			push_error("CINDER_STRUCTURE_SCAN_SILHOUETTE_CAPTURE_FAILED: %s state rejected" % state)
			quit(1)
			return
		for _frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var panel := root.get_texture().get_image()
		if panel == null or panel.is_empty():
			push_error("CINDER_STRUCTURE_SCAN_SILHOUETTE_CAPTURE_FAILED: %s frame is empty" % state)
			quit(1)
			return
		panels.append(panel)
	var contact_sheet := _contact_sheet(panels)
	var absolute_output := ProjectSettings.globalize_path(OUTPUT)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var save_error := contact_sheet.save_png(absolute_output)
	if (directory_error != OK and directory_error != ERR_ALREADY_EXISTS) or save_error != OK:
		push_error("CINDER_STRUCTURE_SCAN_SILHOUETTE_CAPTURE_FAILED: could not save contact sheet")
		quit(1)
		return
	print(
		"CINDER_STRUCTURE_SCAN_SILHOUETTE_CAPTURE_OK renderer=%s distance=%.1fm output=%s"
		% [RenderingServer.get_current_rendering_method(), CAMERA_POSITION.distance_to(CAMERA_TARGET), OUTPUT]
	)
	quit(0)


func _snapshot_for(state: StringName) -> Dictionary:
	var authority_state := CinderAbandonedStructureScanActivity.State.IDLE
	var elapsed := 0.0
	if state == &"scanning":
		authority_state = CinderAbandonedStructureScanActivity.State.SCANNING
		elapsed = 2.0
	elif state == &"completed":
		authority_state = CinderAbandonedStructureScanActivity.State.COMPLETE
		elapsed = 4.0
	return {
		"activity_id": CinderAbandonedStructureScanActivity.ACTIVITY_ID,
		"generation": 1,
		"state": authority_state,
		"elapsed_seconds": elapsed,
		"scan_seconds": CinderAbandonedStructureScanActivity.SCAN_SECONDS,
	}


func _contact_sheet(panels: Array[Image]) -> Image:
	var sheet := Image.create(RESOLUTION.x, RESOLUTION.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color("050b12"))
	for index in panels.size():
		var panel := panels[index].duplicate()
		panel.convert(Image.FORMAT_RGB8)
		panel.resize(RESOLUTION.x / 3, RESOLUTION.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), Vector2i(index * (RESOLUTION.x / 3), 0))
	return sheet


func _add_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050b12")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7894aa")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe0bc")
	key.light_energy = 1.45
	key.rotation_degrees = Vector3(-36.0, -30.0, 0.0)
	stage.add_child(key)
