extends SceneTree

## Rendered review of the VIP reception suite.
##
## MUST NOT be run with `--headless`: this box has no rendering device under
## `--headless`, `get_texture().get_image()` returns null and
## `RenderingServer.frame_post_draw` never fires, so a headless run hangs at
## about 1% CPU instead of failing. Run it exactly like the room probe beside it:
##
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a godot \
##     --path . --rendering-driver vulkan --script res://tools/vip_reception_probe.gd
##
## KETH_VIP_PROBE_DIR sets the output directory.
##
## Framings and luminance statistics are taken verbatim from
## `tools/interior_room_probe.gd` so the numbers mean the same thing across the
## station's interiors: `structure` is the mean of the darkest 90% of samples and
## `lit_structure` the mean of the brightest 10%, which is what tells a lit room
## from a tinted one.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAPTURE_RESOLUTION := Vector2i(1280, 720)
const OUTPUT_DIR_ENVIRONMENT_VARIABLE := "KETH_VIP_PROBE_DIR"

var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := OS.get_environment(OUTPUT_DIR_ENVIRONMENT_VARIABLE)
	if output_dir.is_empty():
		output_dir = "user://vip_reception_probe"
	DirAccess.make_dir_recursive_absolute(output_dir)
	print("VIP_PROBE_DIR: ", output_dir)
	print(
		"VIP_PROBE_RENDERER: method=%s adapter=[%s]"
		% [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()]
	)
	if RenderingServer.get_video_adapter_name().is_empty():
		push_error("no rendering device: this probe was run headless and cannot produce a frame")
		print("VIP_PROBE_FAIL: no rendering device")
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
	var suite := world.get_node_or_null(^"VipReceptionSuite") as Node3D
	if suite == null:
		print("VIP_PROBE_FAIL: suite is not in the production world")
		quit(1)
		return

	# Open the landmark for the entry framing, through the door's own interaction
	# path rather than by writing its state.
	var door := world.get_node_or_null(^"AftJunctionStack/VIPAccess")
	if door != null and door.call("can_interact", suite):
		door.call("interact", suite)
	for _travel in 60:
		await physics_frame

	_camera = Camera3D.new()
	_camera.name = "VipProbeCamera"
	_camera.near = 0.08
	_camera.far = 6000.0
	game.add_child(_camera)
	_camera.current = true

	# 1. The threshold, from the aft upper deck outside the red landmark.
	await _shot(output_dir, "01_landmark_approach.png", Vector3(-5.15, 5.95, 64.6), suite.to_global(Vector3(0.0, 1.9, 3.0)), 62.0)
	# 2. Through the reveal into the room: the compression-and-release framing.
	await _shot(output_dir, "02_threshold_release.png", suite.to_global(Vector3(0.0, 1.7, 1.1)), suite.to_global(Vector3(-1.4, 1.4, 9.5)), 66.0)
	# 3. Across the sunken well to the outboard glazing.
	await _shot(output_dir, "03_well_and_view.png", suite.to_global(Vector3(1.9, 1.85, 4.4)), suite.to_global(Vector3(-2.6, 0.9, 12.4)), 62.0)
	# 4. Seated in the well, looking out. Eye height of someone on the banquette.
	await _shot(output_dir, "04_seated_outboard.png", suite.to_global(Vector3(-1.6, 0.75, 6.6)), suite.to_global(Vector3(-1.6, 1.4, 14.4)), 60.0)
	# 5. Reverse: from the glazing back across the room at the servery and the
	#    threshold, which is the half the entry framing cannot see.
	await _shot(output_dir, "05_reverse_servery.png", suite.to_global(Vector3(-2.2, 1.75, 12.9)), suite.to_global(Vector3(-5.6, 1.1, 5.2)), 64.0)
	# 6. Outside: the cantilever, the mast and the stays, from the aft deck.
	await _shot(output_dir, "06_exterior_cantilever.png", Vector3(-26.0, 13.5, 60.0), Vector3(-7.0, 7.6, 77.0), 55.0)

	game.queue_free()
	await process_frame
	print("VIP_PROBE_OK")
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
		print("VIP_PROBE_FAIL: %s produced no image" % file_name)
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


## Verbatim from `tools/interior_room_probe.gd` so the two agree.
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
	var lit_total := 0.0
	var lit_count: int = maxi(1, count - structural_count)
	for index in range(structural_count, count):
		lit_total += float(sorted[index])
	return {
		"mean": total / float(maxi(1, count)),
		"structure": structural_total / float(structural_count),
		"lit_structure": lit_total / float(lit_count),
		"lit_mean": lit_total / float(lit_count),
		"p50": float(sorted[count / 2]),
		"range": maximum - minimum,
	}
