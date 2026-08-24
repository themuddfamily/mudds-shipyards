extends SceneTree

## Native Forward+ close-up of the production Cinder cockpit instrument cluster.
## Exterior siblings are hidden only on the capture stage, keeping speed rails
## and wingtip blades out of frame while the production status-repeater batch,
## material, transforms, and culling bounds remain unchanged.

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")
const RESOLUTION := Vector2i(1280, 720)
const OUTPUT_PATH := "res://artifacts/cinder_interceptor_status_repeaters/forward_plus_cockpit.png"
const CYAN_SCAN_RADIUS := 42

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and DisplayServer.get_name() == "X11"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a native X11 Forward+ rendering device"
	)

	var stage := Node3D.new()
	stage.name = "CinderStatusRepeaterCaptureStage"
	root.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("05090e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8ca0b2")
	environment.ambient_light_energy = 0.44
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color("fff1dc")
	key_light.light_energy = 1.35
	key_light.shadow_enabled = false
	key_light.rotation_degrees = Vector3(-48.0, 18.0, 0.0)
	stage.add_child(key_light)

	var craft := Interceptor.new() as CinderLightInterceptor
	craft.name = "CaptureCinderLightInterceptor"
	stage.add_child(craft)
	await process_frame
	craft.set_canopy_open(true, 0.0)
	_isolate_cockpit(craft)
	craft.set_process(false)
	craft.set_physics_process(false)

	var visual := craft.get_variant_visual_root()
	var cluster := visual.get_node_or_null(
		^"CockpitInterior/InstrumentCluster"
	) as Node3D if visual != null else null
	var batch := cluster.get_node_or_null(
		^"CinderStatusRepeaterBatch"
	) as MultiMeshInstance3D if cluster != null else null
	_check_batch(batch)

	var camera := Camera3D.new()
	camera.name = "CinderStatusRepeaterCaptureCamera"
	camera.position = Vector3(0.0, 2.72, 0.28)
	camera.fov = 39.0
	camera.near = 0.04
	camera.far = 40.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 2.54, -1.42), Vector3.UP)
	camera.current = true

	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == RESOLUTION,
		"capture returns one stable 1280x720 Forward+ frame"
	)
	if image != null and not image.is_empty() and batch != null and cluster != null:
		var projected := _projected_repeater_centres(camera, cluster, batch)
		_check(
			projected.size() == 2
				and not camera.is_position_behind(cluster.to_global(
					(batch.get_meta(&"authored_instance_transforms", [])[0] as Transform3D).origin
				))
				and projected[0].distance_to(projected[1]) > 120.0,
			"both authored repeater centres are separately projected in front of the cockpit camera"
		)
		if projected.size() == 2:
			var port_pixels := _count_cyan_pixels(image, projected[0], CYAN_SCAN_RADIUS)
			var starboard_pixels := _count_cyan_pixels(image, projected[1], CYAN_SCAN_RADIUS)
			_check(
				port_pixels >= 24 and starboard_pixels >= 24,
				"both port and starboard repeater regions retain visible cyan renderer pixels"
			)
			print(
				"CINDER_STATUS_REPEATER_CAPTURE_PIXELS port=%d starboard=%d separation=%.1f" % [
					port_pixels,
					starboard_pixels,
					projected[0].distance_to(projected[1]),
				]
			)
		var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		_check(image.save_png(absolute) == OK, "Forward+ cockpit capture saves successfully")
		print("CINDER_STATUS_REPEATER_CAPTURE: ", absolute)

	stage.queue_free()
	await process_frame
	_finish()


func _check_batch(batch: MultiMeshInstance3D) -> void:
	var valid := batch != null and batch.multimesh != null
	var transforms: Array = batch.get_meta(&"authored_instance_transforms", []) if valid else []
	var material := batch.multimesh.mesh.surface_get_material(0) as StandardMaterial3D \
		if valid else null
	var expected_bounds := CinderLightInterceptor._visual_bounds(
		batch.multimesh.mesh.get_aabb(),
		_transforms_typed(transforms)
	) if valid else AABB()
	_check(
		valid
			and batch.multimesh.instance_count == 2
			and batch.multimesh.visible_instance_count == 2
			and transforms.size() == 2
			and PackedStringArray(batch.get_meta(&"authored_visual_names", PackedStringArray()))
				== PackedStringArray(Interceptor.STATUS_REPEATER_NAMES)
			and batch.multimesh.custom_aabb.is_equal_approx(expected_bounds)
			and material != null
			and material.emission_enabled
			and material.emission.is_equal_approx(Color("48dbe2"))
			and is_equal_approx(material.emission_energy_multiplier, 2.8),
		"production batch retains two named cyan instances, exact material, and aggregate culling bounds"
	)


func _isolate_cockpit(craft: CinderLightInterceptor) -> void:
	var visual := craft.get_variant_visual_root()
	var cockpit := visual.get_node_or_null(^"CockpitInterior") as Node3D \
		if visual != null else null
	if visual == null or cockpit == null:
		return
	for child in visual.get_children():
		if child is Node3D and child != cockpit:
			(child as Node3D).visible = false


func _projected_repeater_centres(
		camera: Camera3D,
		cluster: Node3D,
		batch: MultiMeshInstance3D
		) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for value in batch.get_meta(&"authored_instance_transforms", []):
		result.append(camera.unproject_position(cluster.to_global((value as Transform3D).origin)))
	return result


func _count_cyan_pixels(image: Image, centre: Vector2, radius: int) -> int:
	var count := 0
	var centre_pixel := Vector2i(roundi(centre.x), roundi(centre.y))
	for y in range(maxi(0, centre_pixel.y - radius), mini(image.get_height(), centre_pixel.y + radius + 1)):
		for x in range(maxi(0, centre_pixel.x - radius), mini(image.get_width(), centre_pixel.x + radius + 1)):
			var offset := Vector2i(x, y) - centre_pixel
			if offset.length_squared() > radius * radius:
				continue
			var pixel := image.get_pixel(x, y)
			if pixel.g > 0.4 and pixel.b > 0.4 and pixel.r < pixel.g * 0.82:
				count += 1
	return count


func _transforms_typed(values: Array) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for value in values:
		result.append(value as Transform3D)
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_INTERCEPTOR_STATUS_REPEATER_CAPTURE_OK")
		quit(0)
		return
	print("CINDER_INTERCEPTOR_STATUS_REPEATER_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
