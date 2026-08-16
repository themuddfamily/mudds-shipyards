extends SceneTree

## Forward+ before/after evidence harness for the global art-direction pass.
##
## The presentation work on this station has repeatedly been judged locally
## correct and globally invisible: sub-7 m light pools, one module's materials,
## one berth's cues. This harness exists to make that failure mode visible before
## it is committed. Its frame list is deliberately weighted toward *wide* shots —
## four of the ten are taken from 100 m or further out, where nothing any
## previous pass touched had any reach at all — because that is the distance at
## which the player's complaint was made.
##
## It renders the live production Main. The only capture-only object is one
## Camera3D; no capture lighting, no capture geometry, no environment override.
## Production overlays are hidden so the frames show the world and not the HUD.
##
## Output goes to an external directory so a review pass never rewrites committed
## artifacts. Override with KETH_ART_CAPTURE_DIR.
##
## Alongside each PNG the harness prints a luminance summary. Two contrast
## numbers are reported, and the difference between them turned out to matter.
##
## `structure` is the standard deviation of the darkest 90% of the frame. That is
## the guard this project has used before, and on these frames it is misleading
## in one specific way: half of a wide shot of a station in vacuum is *empty
## space*, so the statistic is dominated by the background. Deepening the blacks
## - which is a straightforward improvement, and one this pass makes - removes
## variance from that background and drives `structure` down even when every
## surface in the frame gained contrast. Read it as a regression alarm, not as a
## score.
##
## `lit_structure` is the standard deviation of the 65th-to-98th percentile band:
## the lit structure, with the empty background below it and the emissive
## fixtures and star sprites above it both excluded. That is the population the
## art actually acts on.
##
## Either way the failure signature to watch for is the same one this project has
## already shipped and had rejected: mean rising while contrast falls. That is a
## gain knob wearing a costume.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
const OUTPUT_DIR_ENVIRONMENT_VARIABLE := "KETH_ART_CAPTURE_DIR"
const DEFAULT_OUTPUT_DIR := "user://art_direction_capture"

## file name, camera position, look-at target, fov
const EXTERIOR_SHOTS := [
	# The far approach. Nothing in any previous presentation pass reaches this
	# frame: every fixture practical, every mast cone and every normal map is
	# below its resolution. If a change is invisible here it is invisible in the
	# view the player spends most of their flight time looking at.
	["01_far_approach.png", Vector3(40.0, 26.0, -215.0), Vector3(-6.0, 4.0, 10.0), 55.0],
	# The depth stack: beacon mast at -145, target drones from -95 to -165, and
	# the station behind them. This is the frame that shows whether distance
	# separates anything from anything.
	["02_depth_stack.png", Vector3(-96.0, 18.0, -196.0), Vector3(-14.0, 2.0, -30.0), 58.0],
	["03_high_three_quarter.png", Vector3(64.0, 47.0, 59.0), Vector3(0.0, 0.4, -7.0), 55.0],
	["04_port_silhouette.png", Vector3(-120.0, 34.0, -40.0), Vector3(-6.0, 2.0, 30.0), 55.0],
	["05_fleet_overview.png", Vector3(-18.0, 68.0, 82.0), Vector3(-25.0, 1.0, 22.0), 57.0],
	# Deck level, standing height, looking down the lattice. The near/far read of
	# the station from inside itself.
	["06_deck_eye_level.png", Vector3(-6.0, 2.0, 34.0), Vector3(2.0, 3.0, -40.0), 62.0],
	["07_hero_berth.png", Vector3(-16.5, 6.5, -26.0), Vector3(0.0, 1.6, -8.0), 58.0],
]

var _failures: Array[String] = []
var _camera: Camera3D
var _output_dir := DEFAULT_OUTPUT_DIR
var _summary: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment(OUTPUT_DIR_ENVIRONMENT_VARIABLE)
	if _output_dir.is_empty():
		_output_dir = DEFAULT_OUTPUT_DIR
	DirAccess.make_dir_recursive_absolute(_output_dir)
	print("ART_CAPTURE_OUTPUT_DIR: ", ProjectSettings.globalize_path(_output_dir))

	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.call("start_shift")
	for _settle in 20:
		await physics_frame

	var layers := game.find_children("*", "CanvasLayer", true, false)
	for candidate in layers:
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED
	_check(not layers.is_empty(), "production overlays exist and are explicitly excluded")
	await process_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as Node3D
	_check(world != null, "capture world is the production ShipyardWorld")

	var player := game.get_node_or_null(^"Player") as PlayerController
	if player != null:
		player.set_camera_active(false)
		player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(-8.5, 0.6, 11.0)))

	_camera = Camera3D.new()
	_camera.name = "ArtEvidenceCamera"
	_camera.near = 0.08
	_camera.far = 6000.0
	game.add_child(_camera)
	_camera.current = true

	for shot in EXTERIOR_SHOTS:
		_frame_camera(shot[1] as Vector3, shot[2] as Vector3, float(shot[3]))
		for _settle in 6:
			await process_frame
		await _capture(shot[0] as String)

	# Two enclosed rooms. The sky hemisphere cannot see into either, so they are
	# the check that an exterior atmosphere change has not simply drained them.
	if world != null:
		var aft_module := world.get_node_or_null(^"AftJunctionStack") as Node3D
		_check(aft_module != null, "capture world contains the integrated aft junction module")
		if aft_module != null:
			_frame_camera(
				aft_module.to_global(Vector3(5.6, 2.35, 10.15)),
				aft_module.to_global(Vector3(5.6, 1.35, 15.4)),
				60.0
			)
			for _settle in 6:
				await process_frame
			await _capture("08_operations_room.png")

		var habitat := world.call("get_habitat_spine") as Node3D
		_check(habitat != null, "capture world contains the integrated habitat spine")
		if habitat != null:
			_frame_camera(
				habitat.to_global(Vector3(0.0, 2.55, 18.8)),
				habitat.to_global(Vector3(0.0, 1.75, 27.2)),
				60.0
			)
			for _settle in 6:
				await process_frame
			await _capture("09_habitat_common_room.png")

		var freight_berth := world.call("get_jovian_freight_berth") as Node3D
		_check(freight_berth != null, "capture world contains the integrated freight berth")
		if freight_berth != null:
			_frame_camera(
				freight_berth.to_global(Vector3(31.0, 15.5, -15.0)),
				freight_berth.to_global(Vector3(0.0, 2.0, 25.0)),
				58.0
			)
			for _settle in 6:
				await process_frame
			await _capture("10_freight_dock_approach.png")

	game.queue_free()
	await process_frame
	_finish()


func _frame_camera(from: Vector3, to: Vector3, fov: float) -> void:
	_camera.fov = fov
	_camera.global_position = from
	_camera.look_at(to, Vector3.UP)


func _capture(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_check(false, "%s produced a viewport image" % file_name)
		return
	var statistics := _sample_luminance_statistics(image)
	_check(
		float(statistics["range"]) >= 0.03,
		"%s is nonblank (luminance range %.5f)" % [file_name, float(statistics["range"])]
	)
	var line := (
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
	print(line)
	_summary.append(line)
	var path := "%s/%s" % [_output_dir, file_name]
	_check(image.save_png(path) == OK, "%s saves successfully" % file_name)


## Luminance summary over a regular sample grid.
##
## `structure` trims the top decile, which is emissive: fixture lenses, hazard
## legends and star sprites sit far above everything else and their variance
## swamps the surface detail. `lit_structure` additionally trims everything below
## the 65th percentile, which in a vacuum exterior is mostly empty background, so
## it reports the contrast of the lit structure rather than the contrast of the
## void behind it. See the class comment for why both are printed.
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


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	print("--- ART CAPTURE SUMMARY ---")
	for line in _summary:
		print(line)
	if _failures.is_empty():
		print("ART CAPTURE: PASS")
		quit(0)
		return
	print("ART CAPTURE: FAIL (%d)" % _failures.size())
	for failure in _failures:
		print("  ", failure)
	quit(1)
