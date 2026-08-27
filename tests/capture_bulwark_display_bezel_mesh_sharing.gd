extends SceneTree

## Native Forward+ capture used unchanged against the baseline and optimized
## worktrees. A byte-identical frame proves mesh sharing does not alter the
## cockpit bezel's geometry, material, pose, shadows, or culling.

const Ship := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const RESOLUTION := Vector2i(1280, 720)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus" \
		and DisplayServer.get_name() == "X11" \
		and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a native X11 Forward+ rendering device"
	)

	var stage := Node3D.new()
	stage.name = "BulwarkDisplayBezelCaptureStage"
	root.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("05090e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8ea0b2")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color("fff3df")
	key_light.light_energy = 1.7
	key_light.shadow_enabled = true
	key_light.rotation_degrees = Vector3(-52.0, 22.0, 0.0)
	stage.add_child(key_light)

	var craft := Ship.new() as HeroShip
	stage.add_child(craft)
	await process_frame
	craft.set_canopy_open(true, 0.0)
	_isolate_cockpit(craft)
	craft.set_process(false)
	craft.set_physics_process(false)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.82, 0.25)
	camera.fov = 34.0
	camera.near = 0.05
	camera.far = 80.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 2.56, -1.52), Vector3.UP)
	camera.current = true

	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == RESOLUTION,
		"capture returns a stable 1280x720 renderer frame"
	)
	if image != null and not image.is_empty():
		var output_path := OS.get_environment("BULWARK_BEZEL_CAPTURE_PATH")
		if output_path.is_empty():
			output_path = "/tmp/bulwark_display_bezel.png"
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		_check(image.save_png(output_path) == OK, "capture frame saves successfully")
		var non_background := _count_non_background_pixels(image)
		_check(non_background > 10000, "instrument panel is visibly represented in capture")
		print("BULWARK_DISPLAY_BEZEL_CAPTURE: %s pixels=%d" % [output_path, non_background])

	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BULWARK DISPLAY BEZEL CAPTURE OK")
		quit(0)
	else:
		quit(1)


func _isolate_cockpit(craft: HeroShip) -> void:
	var visual := craft.get_node_or_null(^"BulwarkHeavyGunshipVisual") as Node3D
	var cockpit := visual.get_node_or_null(^"CockpitInterior") as Node3D \
		if visual != null else null
	if visual == null or cockpit == null:
		return
	for child in visual.get_children():
		if child is Node3D and child != cockpit:
			(child as Node3D).visible = false


func _count_non_background_pixels(image: Image) -> int:
	var count := 0
	var background := Color("05090e")
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var difference := absf(pixel.r - background.r) \
				+ absf(pixel.g - background.g) \
				+ absf(pixel.b - background.b)
			if difference > 0.06:
				count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)
