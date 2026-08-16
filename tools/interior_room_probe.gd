extends SceneTree

## Interior room probe for the two enclosed rooms.
##
## MUST NOT be run with `--headless`. See the note at the bottom of this file.
##
## Framings and luminance statistics are taken verbatim from
## `tests/capture_art_direction.gd` so the numbers mean the same thing, with two
## extra reverse framings added because the committed harness looks into each
## room from its doorway only and cannot see the far corners, the coordinator
## chair, or the room's front third — which is the volume this pass is about.
##
## KETH_ROOM_PROBE_DIR sets the output directory.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAPTURE_RESOLUTION := Vector2i(1280, 720)
const OUTPUT_DIR_ENVIRONMENT_VARIABLE := "KETH_ROOM_PROBE_DIR"

var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := OS.get_environment(OUTPUT_DIR_ENVIRONMENT_VARIABLE)
	if output_dir.is_empty():
		output_dir = "user://interior_room_probe"
	DirAccess.make_dir_recursive_absolute(output_dir)
	print("ROOM_PROBE_DIR: ", output_dir)
	print(
		"ROOM_PROBE_RENDERER: method=%s adapter=[%s]"
		% [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()]
	)
	if RenderingServer.get_video_adapter_name().is_empty():
		push_error("no rendering device: this probe was run headless and cannot produce a frame")
		print("ROOM_PROBE_FAIL: no rendering device")
		quit(1)
		return

	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.call("start_shift")
	for _settle in 12:
		await physics_frame
	for candidate in game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED

	var world := game.get_node_or_null(^"ShipyardWorld") as Node3D
	var player := game.get_node_or_null(^"Player")
	if player != null:
		player.call("set_camera_active", false)
	_camera = Camera3D.new()
	_camera.name = "RoomProbeCamera"
	_camera.near = 0.08
	_camera.far = 6000.0
	game.add_child(_camera)
	_camera.current = true

	var aft := world.get_node_or_null(^"AftJunctionStack") as Node3D
	# Verbatim from the committed harness.
	await _shot(
		output_dir,
		"08_operations_room.png",
		aft.to_global(Vector3(5.6, 2.35, 10.15)),
		aft.to_global(Vector3(5.6, 1.35, 15.4)),
		60.0
	)
	# Standing at the window end looking back across the seating, the coordinator
	# chair and the door — the half of the room the doorway framing cannot see.
	await _shot(
		output_dir,
		"08b_operations_reverse.png",
		aft.to_global(Vector3(6.4, 1.62, 16.9)),
		aft.to_global(Vector3(3.4, 1.05, 10.4)),
		62.0
	)
	var habitat := world.call("get_habitat_spine") as Node3D
	# Verbatim from the committed harness.
	await _shot(
		output_dir,
		"09_habitat_common_room.png",
		habitat.to_global(Vector3(0.0, 2.55, 18.8)),
		habitat.to_global(Vector3(0.0, 1.75, 27.2)),
		60.0
	)
	# Seated on the observation line looking back past the table at the room's
	# front third, which was outside every lamp before this pass.
	await _shot(
		output_dir,
		"09b_habitat_common_reverse.png",
		habitat.to_global(Vector3(3.6, 1.55, 26.9)),
		habitat.to_global(Vector3(-1.6, 1.2, 19.4)),
		62.0
	)

	game.queue_free()
	await process_frame
	print("ROOM_PROBE_OK")
	quit(0)


func _shot(output_dir: String, file_name: String, from: Vector3, to: Vector3, fov: float) -> void:
	_camera.fov = fov
	_camera.global_position = from
	_camera.look_at(to, Vector3.UP)
	_camera.current = true
	for _settle in 8:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		print("ROOM_PROBE_FAIL: %s produced no image" % file_name)
		return
	var statistics := _sample_luminance_statistics(image)
	print(
		"METRIC %s mean=%.5f structure=%.5f lit_structure=%.5f lit_mean=%.5f p50=%.5f range=%.5f"
		% [
			file_name,
			float(statistics["mean"]),
			float(statistics["structure"]),
			float(statistics["lit_structure"]),
			float(statistics["lit_mean"]),
			float(statistics["p50"]),
			float(statistics["range"]),
		]
	)
	image.save_png("%s/%s" % [output_dir, file_name])


## Verbatim from `tests/capture_art_direction.gd` so the two agree.
func _sample_luminance_statistics(image: Image) -> Dictionary:
	var samples := PackedFloat32Array()
	var minimum := 1.0
	var maximum := 0.0
	var total := 0.0
	var step_x: int = maxi(1, image.get_width() / 320)
	var step_y: int = maxi(1, image.get_height() / 180)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			var luminance := image.get_pixel(x, y).get_luminance()
			samples.append(luminance)
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
			total += luminance
	var sorted := Array(samples)
	sorted.sort()
	var count := sorted.size()
	var structural_count: int = maxi(1, int(float(count) * 0.9))
	var structural_total := 0.0
	for index in structural_count:
		structural_total += float(sorted[index])
	var structural_mean := structural_total / float(structural_count)
	var structural_variance := 0.0
	for index in structural_count:
		var delta := float(sorted[index]) - structural_mean
		structural_variance += delta * delta
	structural_variance /= float(structural_count)
	var lit_first: int = clampi(int(float(count) * 0.65), 0, count - 1)
	var lit_last: int = clampi(int(float(count) * 0.98), lit_first + 1, count)
	var lit_total := 0.0
	for index in range(lit_first, lit_last):
		lit_total += float(sorted[index])
	var lit_mean := lit_total / float(lit_last - lit_first)
	var lit_variance := 0.0
	for index in range(lit_first, lit_last):
		var lit_delta := float(sorted[index]) - lit_mean
		lit_variance += lit_delta * lit_delta
	lit_variance /= float(lit_last - lit_first)
	return {
		"range": maximum - minimum,
		"mean": total / maxf(1.0, float(count)),
		"structure": sqrt(structural_variance),
		"lit_mean": lit_mean,
		"lit_structure": sqrt(lit_variance),
		"p50": float(sorted[clampi(int(float(count) * 0.5), 0, count - 1)]),
	}
