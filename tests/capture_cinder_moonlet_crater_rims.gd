extends SceneTree

## One bounded Forward+ gameplay-distance witness for Cinder Reach's production
## moonlet. The frame keeps the complete moonlet and its six retained crater-rim
## transforms in-frustum while the Charlie/Delta route beacons remain readable
## to starboard. This is a visual review harness, not gameplay authority.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const DEFAULT_OUTPUT := "res://artifacts/nearby-sector/cinder_moonlet_crater_rim_batch.png"
const CAMERA_POSITION := Vector3(-105.0, 90.0, -250.0)
const CAMERA_TARGET := Vector3(-105.0, 0.0, -545.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if RenderingServer.get_current_rendering_method() != &"forward_plus":
		push_error("CINDER_MOONLET_CRATER_CAPTURE_FAILED: Forward+ is required")
		quit(1)
		return

	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	root.msaa_3d = Viewport.MSAA_2X
	root.use_taa = false
	var stage := Node3D.new()
	stage.name = "CinderMoonletCraterForwardWitness"
	root.add_child(stage)
	_build_environment(stage)
	_build_lighting(stage)

	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	stage.add_child(cluster)
	await process_frame
	await physics_frame

	var camera := Camera3D.new()
	camera.name = "MoonletGameplayDistanceCamera"
	camera.position = CAMERA_POSITION
	camera.fov = 58.0
	camera.near = 0.1
	camera.far = 1200.0
	camera.current = true
	stage.add_child(camera)
	camera.look_at(CAMERA_TARGET, Vector3.UP)

	var moonlet := cluster.get_node_or_null(^"Landmarks/ReachMoonlet") as StaticBody3D
	var batch := moonlet.get_node_or_null(^"MoonletCraterRims") as MeshInstance3D \
		if moonlet != null else null
	var material := batch.material_override as StandardMaterial3D if batch != null else null
	var transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
		if batch != null else []
	var rims_in_frustum := 0
	if moonlet != null:
		for transform_value in transforms:
			if camera.is_position_in_frustum(
				moonlet.to_global((transform_value as Transform3D).origin)
			):
				rims_in_frustum += 1

	var route_landmarks_in_frustum := 0
	for beacon_name in ["RouteBeaconCharlie", "RouteBeaconDelta"]:
		var beacon := cluster.get_node_or_null(
			NodePath("RouteBeacons/%s" % beacon_name)
		) as Node3D
		var ring := beacon.get_node_or_null(^"SignalRing") as MeshInstance3D \
			if beacon != null else null
		if ring != null and ring.visible and camera.is_position_in_frustum(ring.global_position):
			route_landmarks_in_frustum += 1

	var geometry_checks := {
		"nodes": moonlet != null and batch != null and batch.mesh != null,
		"visible": batch != null and batch.visible and batch.is_visible_in_tree(),
		"copies": transforms.size() == NearbySectorCluster.MOONLET_CRATER_COUNT,
		"rim_frustum": rims_in_frustum == NearbySectorCluster.MOONLET_CRATER_COUNT,
		"route_frustum": route_landmarks_in_frustum == 2,
		"material_identity": material != null and material == cluster._materials["moonlet_crater"],
		"material_color": material != null and material.albedo_color.is_equal_approx(
			NearbySectorCluster.MOONLET_TEAL.darkened(0.42)
		),
		"steady_material": material != null and not material.emission_enabled,
		"one_surface": batch != null and batch.mesh != null
			and batch.mesh.get_surface_count() == 1,
		"nonempty_bounds": batch != null and batch.mesh != null
			and batch.mesh.get_aabb().size.length_squared() > 0.0,
	}
	var failed_checks := PackedStringArray()
	for check_name: String in geometry_checks:
		if not bool(geometry_checks[check_name]):
			failed_checks.append(check_name)
	var valid: bool = failed_checks.is_empty()

	# The wide gameplay-distance panel proves the route relationship. Six
	# additional gameplay-distance views align once with each authored surface
	# normal so no back-face occlusion can hide a retained rim from human review.
	# All seven Forward+ frames are published as one bounded contact sheet.
	var panels: Array[Image] = []
	panels.append(await _capture_panel())
	var focused_rims_in_frustum := 0
	if moonlet != null:
		for transform_value in transforms:
			var crater_transform := transform_value as Transform3D
			var outward := crater_transform.basis.y.normalized()
			camera.global_position = moonlet.global_position + outward * 350.0
			camera.look_at(moonlet.global_position, Vector3.UP)
			if camera.is_position_in_frustum(
				moonlet.to_global(crater_transform.origin)
			):
				focused_rims_in_frustum += 1
			panels.append(await _capture_panel())
	var image := _compose_contact_sheet(panels)
	var output := OS.get_environment("KETH_CINDER_MOONLET_CRATER_CAPTURE")
	if output.is_empty():
		output = DEFAULT_OUTPUT
	var absolute := ProjectSettings.globalize_path(output)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	valid = valid and (directory_error == OK or directory_error == ERR_ALREADY_EXISTS)
	var image_contrast := 0.0
	var save_error := ERR_CANT_CREATE
	if image != null and not image.is_empty():
		image_contrast = _sample_luminance_range(image)
		save_error = image.save_png(absolute)
	valid = valid and panels.size() == 7 \
		and focused_rims_in_frustum == NearbySectorCluster.MOONLET_CRATER_COUNT \
		and save_error == OK and image != null and not image.is_empty() \
		and image.get_width() == 1600 and image.get_height() == 900 \
		and image_contrast >= 0.18

	print(
		(
			"CINDER_MOONLET_CRATER_CAPTURE: renderer=%s adapter=%s distance=%.3f "
			+ "rims=6/6 wide_frustum=%d focused_frustum=%d route_landmarks=%d material=%s "
			+ "surfaces=%d panels=%d contrast=%.4f output=%s passed=%s"
		)
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_video_adapter_name(),
			CAMERA_POSITION.distance_to(NearbySectorCluster.MOONLET_ANCHOR),
			rims_in_frustum,
			focused_rims_in_frustum,
			route_landmarks_in_frustum,
			material.albedo_color.to_html(false) if material != null else "missing",
			batch.mesh.get_surface_count() if batch != null and batch.mesh != null else 0,
			panels.size(),
			image_contrast,
			absolute,
			valid,
		]
	)
	print(
		"CINDER_MOONLET_CRATER_IMAGE: size=%s save=%d directory=%d"
		% [str(image.get_size() if image != null else Vector2i.ZERO), save_error, directory_error]
	)
	if not failed_checks.is_empty():
		print("CINDER_MOONLET_CRATER_CAPTURE_CHECKS_FAILED: ", failed_checks)
	if not valid:
		push_error(
			"CINDER_MOONLET_CRATER_CAPTURE_FAILED: production geometry, framing, or render drifted"
		)
	stage.queue_free()
	await process_frame
	quit(0 if valid else 1)


func _capture_panel() -> Image:
	for _frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	return image if image != null else Image.new()


func _compose_contact_sheet(panels: Array[Image]) -> Image:
	var sheet := Image.create(1600, 900, false, Image.FORMAT_RGB8)
	sheet.fill(Color("061019"))
	for index in mini(panels.size(), 9):
		var panel := panels[index]
		if panel == null or panel.is_empty():
			continue
		if panel.get_format() != Image.FORMAT_RGB8:
			panel.convert(Image.FORMAT_RGB8)
		panel.resize(533, 300, Image.INTERPOLATE_LANCZOS)
		var destination := Vector2i((index % 3) * 533, (index / 3) * 300)
		sheet.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), destination)
	return sheet


func _sample_luminance_range(image: Image) -> float:
	var minimum := INF
	var maximum := -INF
	for y in range(0, image.get_height(), 40):
		for x in range(0, image.get_width(), 40):
			var color := image.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	return maximum - minimum


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061019")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7897a6")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment.ssao_enabled = true
	environment.ssao_radius = 2.4
	environment.ssao_intensity = 1.4
	world_environment.environment = environment
	stage.add_child(world_environment)


func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -34.0, 0.0)
	key.light_color = Color("f2d8b7")
	key.light_energy = 1.2
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(24.0, 146.0, 0.0)
	rim.light_color = Color("5dcbd4")
	rim.light_energy = 0.55
	rim.shadow_enabled = false
	stage.add_child(rim)
