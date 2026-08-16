extends SceneTree

## Render probe and node census for the Aft Junction Stack's own interiors.
##
## MUST NOT be run with `--headless`. There is no rendering device under
## `--headless` on this box: `get_texture().get_image()` returns null and
## `RenderingServer.frame_post_draw` never fires, so a capture harness hangs at
## idle rather than failing. Working invocation:
##
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a godot \
##     --path . --rendering-driver vulkan --script res://tools/aft_operations_probe.gd
##
## `tools/interior_room_probe.gd` frames the operations room from its doorway and
## from the window end, which is what the lighting pass needed. This one exists
## because the content pass put apparatus in the room's southern third, down its
## west wall and at the head of its stair, and none of those are in any committed
## framing. Luminance statistics are taken verbatim from
## `tests/capture_art_direction.gd` so the numbers mean the same thing everywhere.
##
## It also prints the module's own performance contract, because the aft light,
## mesh, body and shape ceilings are frozen at their exact built counts and the
## next author has to be able to read the built figures without a debugger.
##
## KETH_AFT_PROBE_DIR sets the output directory.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAPTURE_RESOLUTION := Vector2i(1280, 720)
const OUTPUT_DIR_ENVIRONMENT_VARIABLE := "KETH_AFT_PROBE_DIR"

## Local-space camera framings inside the aft module. Each entry is
## [file name, eye, target, fov].
const FRAMINGS := [
	["a_door_entry.png", Vector3(2.5, 1.68, 10.35), Vector3(7.6, 1.25, 11.4), 72.0],
	["b_plot_and_status_board.png", Vector3(6.9, 1.72, 14.3), Vector3(6.9, 2.55, 9.45), 64.0],
	["c_console_line.png", Vector3(2.9, 1.62, 10.6), Vector3(7.6, 1.30, 15.7), 70.0],
	["d_room_overview.png", Vector3(8.7, 1.62, 12.1), Vector3(1.3, 1.15, 16.5), 68.0],
	# The west wall carries the chart press, the notice board and the refreshment
	# stand, and no committed framing looks at it.
	["e_west_wall.png", Vector3(5.4, 1.60, 13.9), Vector3(0.9, 1.35, 15.7), 66.0],
	# Face-on at the north glazing from the middle of the room, clear of the chairs
	# at z = 13.55 and clear of the plot table at z = 11.6.
	["f_window_glass.png", Vector3(4.55, 1.72, 12.55), Vector3(4.85, 2.25, 17.3), 62.0],
	# The north-west corner pocket, which the west-wall framing above cannot see
	# past the first console plinth.
	["h_refreshment_corner.png", Vector3(2.60, 1.55, 14.00), Vector3(1.32, 1.05, 16.60), 66.0],
	# The stair-head muster locker from the top of the stair, which is where a
	# player finishing the climb stands and the face the locker is authored toward.
	["g_stair_head.png", Vector3(-2.55, 6.30, 10.40), Vector3(-2.55, 5.50, 13.40), 62.0],
]

var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := OS.get_environment(OUTPUT_DIR_ENVIRONMENT_VARIABLE)
	if output_dir.is_empty():
		output_dir = "user://aft_operations_probe"
	DirAccess.make_dir_recursive_absolute(output_dir)
	print("AFT_PROBE_DIR: ", output_dir)
	print(
		"AFT_PROBE_RENDERER: method=%s adapter=[%s]"
		% [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()]
	)
	if RenderingServer.get_video_adapter_name().is_empty():
		push_error("no rendering device: this probe was run headless and cannot produce a frame")
		print("AFT_PROBE_FAIL: no rendering device")
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
	_camera.name = "AftProbeCamera"
	_camera.near = 0.08
	_camera.far = 6000.0
	game.add_child(_camera)
	_camera.current = true

	var aft := world.get_node_or_null(^"AftJunctionStack") as Node3D
	if aft == null:
		print("AFT_PROBE_FAIL: AftJunctionStack is not in the live world")
		quit(1)
		return
	_report_contract(aft)
	for framing in FRAMINGS:
		await _shot(
			output_dir,
			str(framing[0]),
			aft.to_global(framing[1] as Vector3),
			aft.to_global(framing[2] as Vector3),
			float(framing[3])
		)

	game.queue_free()
	await process_frame
	print("AFT_PROBE_OK")
	quit(0)


func _report_contract(aft: Node3D) -> void:
	var performance: Dictionary = aft.call("get_performance_contract")
	print(
		"AFT_BUILT_COUNTS: meshes=%d bodies=%d shapes=%d labels=%d lights=%d process=%d physics=%d within_budget=%s"
		% [
			int(performance["mesh_instances"]),
			int(performance["static_bodies"]),
			int(performance["collision_shapes"]),
			int(performance["labels"]),
			int(performance["lights"]),
			int(performance["process_loops"]),
			int(performance["physics_process_loops"]),
			str(performance["within_budget"]),
		]
	)
	print("AFT_BUDGETS: ", performance["budgets"])
	var errors: PackedStringArray = aft.call("get_validation_errors")
	print("AFT_VALIDATION_ERRORS: ", errors)


func _shot(output_dir: String, file_name: String, from: Vector3, to: Vector3, fov: float) -> void:
	_camera.fov = fov
	_camera.global_position = from
	_camera.look_at(to, Vector3.UP)
	_camera.current = true
	for _settle in 8:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		print("AFT_PROBE_FAIL: %s produced no image" % file_name)
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


## Verbatim from `tests/capture_art_direction.gd` so every framing in the project
## reports the same statistics.
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
