extends SceneTree

## One deterministic gameplay-distance Forward+ frame, run unchanged against
## baseline and optimized source. Pixel identity proves that sharing immutable
## cargo-pylon geometry preserves the courier silhouette and shading.

const COURIER_SCENE := preload("res://scenes/ships/courier_runner_opponent.tscn")
const RESOLUTION := Vector2i(1280, 720)
const BACKGROUND := Color("05090e")

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
	stage.name = "CourierCargoPylonCaptureStage"
	root.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91a1af")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color("fff0dc")
	key_light.light_energy = 1.55
	key_light.shadow_enabled = true
	key_light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	stage.add_child(key_light)

	var courier := COURIER_SCENE.instantiate() as CourierRunnerOpponent
	courier.name = "CaptureCourierRunner"
	stage.add_child(courier)
	await process_frame
	var activation := courier.activate(Transform3D.IDENTITY)
	_check(bool(activation.get("accepted", false)), "production courier activates for capture")
	courier.set_process(false)
	courier.set_physics_process(false)
	_check(_pylon_contract_is_visible(courier), "both cargo pylons retain their production render contract")

	var camera := Camera3D.new()
	camera.name = "CourierCargoPylonCamera"
	camera.position = Vector3(0.0, 5.8, -15.0)
	camera.fov = 39.0
	camera.near = 0.08
	camera.far = 90.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, -0.05, 0.65), Vector3.UP)
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
		var output_path := OS.get_environment("COURIER_PYLON_CAPTURE_PATH")
		if output_path.is_empty():
			output_path = "/tmp/courier_runner_cargo_pylons.png"
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		_check(image.save_png(output_path) == OK, "capture frame saves successfully")
		var craft_pixels := _count_craft_pixels(image)
		_check(craft_pixels > 18000, "courier and bilateral freight frame are visibly represented")
		print("COURIER_CARGO_PYLON_CAPTURE: %s pixels=%d" % [output_path, craft_pixels])

	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("COURIER RUNNER CARGO PYLON CAPTURE OK")
		quit(0)
	else:
		quit(1)


func _pylon_contract_is_visible(courier: CourierRunnerOpponent) -> bool:
	var visual := courier.get_node_or_null(^"ContractCourierVisual") as Node3D
	if visual == null:
		return false
	var positions: Array[Vector3] = []
	for child in visual.get_children():
		if child is not MeshInstance3D:
			continue
		var instance := child as MeshInstance3D
		var box := instance.mesh as BoxMesh
		if box == null or not box.size.is_equal_approx(CourierRunnerOpponent.CARGO_PYLON_SIZE):
			continue
		if not instance.visible or instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			return false
		positions.append(instance.position)
	positions.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	return positions == [Vector3(-1.5, -0.2, 0.6), Vector3(1.5, -0.2, 0.6)]


func _count_craft_pixels(image: Image) -> int:
	var count := 0
	var background := image.get_pixel(0, 0)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var difference := absf(pixel.r - background.r) \
				+ absf(pixel.g - background.g) \
				+ absf(pixel.b - background.b)
			if difference > 0.055:
				count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)
