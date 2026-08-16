extends SceneTree

## Spawn-view probe for the central berth and the junction deck around it.
##
## MUST NOT be run with `--headless`. There is no rendering device under
## `--headless` on the development box: `get_texture().get_image()` returns null
## and `RenderingServer.frame_post_draw` never fires, so a headless run hangs
## instead of failing. Working invocation:
##
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a godot \
##     --path . --rendering-driver vulkan --script res://tools/central_berth_spawn_probe.gd
##
## Framing 00 is the one that matters: it is taken through the *player's own
## camera*, untouched, on the first settled frame after `start_shift()`. That is
## literally the first thing a player sees every session. The remaining framings
## walk the deck the player walks and drives.
##
## Luminance statistics are verbatim from `tests/capture_art_direction.gd` so the
## numbers mean the same thing across every probe in the repo.
##
## KETH_SPAWN_PROBE_DIR sets the output directory.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAPTURE_RESOLUTION := Vector2i(1280, 720)
const OUTPUT_DIR_ENVIRONMENT_VARIABLE := "KETH_SPAWN_PROBE_DIR"

var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := OS.get_environment(OUTPUT_DIR_ENVIRONMENT_VARIABLE)
	if output_dir.is_empty():
		output_dir = "user://central_berth_spawn_probe"
	DirAccess.make_dir_recursive_absolute(output_dir)
	print("SPAWN_PROBE_DIR: ", output_dir)
	print(
		"SPAWN_PROBE_RENDERER: method=%s adapter=[%s]"
		% [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()]
	)
	if RenderingServer.get_video_adapter_name().is_empty():
		push_error("no rendering device: this probe was run headless and cannot produce a frame")
		print("SPAWN_PROBE_FAIL: no rendering device")
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
	var player := game.get_node_or_null(^"Player") as Node3D

	# 00 — the actual first frame, through the player's own camera, with no
	# harness camera substituted and no transform authored by this probe.
	for _settle in 10:
		await process_frame
	_record("00_spawn_first_frame.png", output_dir)

	# Everything below is a harness camera; the player camera is retired first.
	if player != null:
		player.call("set_camera_active", false)
	_camera = Camera3D.new()
	_camera.name = "SpawnProbeCamera"
	_camera.near = 0.08
	_camera.far = 6000.0
	game.add_child(_camera)
	_camera.current = true

	# 01 — the same spawn stance, one step forward and looking down the deck
	# toward the berth mouth, which is where the player walks first.
	await _shot(
		output_dir,
		"01_spawn_deck_forward.png",
		world.to_global(Vector3(-8.5, 1.7, 9.5)),
		world.to_global(Vector3(-1.5, 1.1, -8.0)),
		72.0
	)
	# 02 — the junction deck read across the berth from the opposite flank, the
	# framing that shows whether the flanks carry anything at all.
	await _shot(
		output_dir,
		"02_junction_deck_crossing.png",
		world.to_global(Vector3(9.6, 2.4, 12.4)),
		world.to_global(Vector3(-6.0, 0.9, -6.0)),
		68.0
	)
	# 03 — eye height beside the berth edge looking aft along the flank, the
	# tow-tractor driving line.
	await _shot(
		output_dir,
		"03_berth_flank_drive_line.png",
		world.to_global(Vector3(-11.2, 1.7, -14.0)),
		world.to_global(Vector3(-9.0, 1.3, 10.0)),
		74.0
	)

	game.queue_free()
	await process_frame
	print("SPAWN_PROBE_OK")
	quit(0)


func _shot(output_dir: String, file_name: String, from: Vector3, to: Vector3, fov: float) -> void:
	_camera.fov = fov
	_camera.global_position = from
	_camera.look_at(to, Vector3.UP)
	_camera.current = true
	for _settle in 8:
		await process_frame
	_record(file_name, output_dir)


func _record(file_name: String, output_dir: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		print("SPAWN_PROBE_FAIL: %s produced no image" % file_name)
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
