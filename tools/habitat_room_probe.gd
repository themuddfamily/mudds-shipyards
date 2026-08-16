extends SceneTree

## Habitat Spine room probe.
##
## MUST NOT be run with `--headless`: this box has no rendering device headless,
## `get_texture().get_image()` returns null and `RenderingServer.frame_post_draw`
## never fires, so a headless run hangs instead of failing. Working invocation:
##
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a godot \
##     --path . --rendering-driver vulkan --script res://tools/habitat_room_probe.gd
##
## Framings and luminance statistics are taken verbatim from
## `tools/interior_room_probe.gd` so the numbers mean the same thing. The two
## committed common-room framings are reproduced exactly; the rest are the
## habitat rooms that harness never looks at — the connector, the corridor, a
## bunk alcove at eye height, the galley and the wardroom.
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
		output_dir = "user://habitat_room_probe"
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

	var habitat := world.call("get_habitat_spine") as Node3D
	# Walking in from the station, standing on the connector deck.
	await _shot(output_dir, "h1_connector.png", habitat.to_global(Vector3(0.0, 1.68, -4.6)), habitat.to_global(Vector3(0.0, 2.1, 1.4)), 62.0)
	# Down the corridor from the vestibule, the framing a player entering has.
	await _shot(output_dir, "h2_corridor.png", habitat.to_global(Vector3(0.0, 1.68, 2.2)), habitat.to_global(Vector3(0.0, 1.5, 13.0)), 62.0)
	# Stepped into the port middle alcove's mouth, looking at the made berth.
	await _shot(output_dir, "h3_bunk_alcove.png", habitat.to_global(Vector3(-2.95, 1.55, 9.75)), habitat.to_global(Vector3(-5.30, 0.95, 10.75)), 66.0)
	# The free berth opposite, from the lane: stripped, shutter up, hook bare.
	await _shot(output_dir, "h3b_free_berth.png", habitat.to_global(Vector3(2.95, 1.55, 9.75)), habitat.to_global(Vector3(5.30, 0.95, 10.75)), 66.0)
	# The corridor's port service wall, looking aft along the cabinets.
	await _shot(output_dir, "h4_corridor_service.png", habitat.to_global(Vector3(1.9, 1.68, 16.6)), habitat.to_global(Vector3(-4.6, 1.5, 6.4)), 62.0)
	# Verbatim from the committed harness.
	await _shot(output_dir, "h5_common_room.png", habitat.to_global(Vector3(0.0, 2.55, 18.8)), habitat.to_global(Vector3(0.0, 1.75, 27.2)), 60.0)
	# Verbatim from the committed harness.
	await _shot(output_dir, "h6_common_reverse.png", habitat.to_global(Vector3(3.6, 1.55, 26.9)), habitat.to_global(Vector3(-1.6, 1.2, 19.4)), 62.0)
	# Standing behind the observation line looking down it, which is the framing
	# the chair backrests actually read in.
	await _shot(output_dir, "h7_chair_line.png", habitat.to_global(Vector3(-6.4, 1.62, 23.4)), habitat.to_global(Vector3(4.2, 1.3, 25.6)), 62.0)
	# The galley run head on, from where someone would walk up to it.
	await _shot(output_dir, "h8_galley.png", habitat.to_global(Vector3(-3.6, 1.62, 21.9)), habitat.to_global(Vector3(-7.0, 1.15, 19.9)), 66.0)
	# The mess table and the berth roster board beyond it.
	await _shot(output_dir, "h9_mess_and_roster.png", habitat.to_global(Vector3(2.2, 1.62, 26.3)), habitat.to_global(Vector3(5.7, 1.20, 20.6)), 66.0)
	# The room's front wall, which carries both legends, from where they are read.
	await _shot(output_dir, "h10_room_legends.png", habitat.to_global(Vector3(0.4, 2.30, 23.4)), habitat.to_global(Vector3(-1.6, 3.20, 18.3)), 66.0)
	# The side branch door from inside the common room, now that it opens.
	await _shot(output_dir, "h11_branch_door.png", habitat.to_global(Vector3(3.4, 1.68, 21.6)), habitat.to_global(Vector3(8.6, 1.45, 19.6)), 64.0)
	# Render the destination through the real open leaf. Teleporting the camera past
	# a still-closed door hid leaf/pocket and threshold defects in the first probe.
	var garden_access := habitat.call("get_deferred_branch_access") as StationDoor
	if garden_access == null or not garden_access.interact(habitat):
		print("ROOM_PROBE_FAIL: garden access did not accept its open interaction")
		quit(1)
		return
	for _frame in 90:
		if garden_access.is_open():
			break
		await physics_frame
	if not garden_access.is_open() or garden_access.is_portal_blocked():
		print("ROOM_PROBE_FAIL: garden access did not reach a clear open state")
		quit(1)
		return
	# Repeat the same-side branch view with the leaf open so its slide pocket and
	# final transform stay visually reviewable rather than hidden between shots.
	await _shot(output_dir, "h11b_branch_door_open.png", habitat.to_global(Vector3(3.4, 1.68, 21.6)), habitat.to_global(Vector3(8.6, 1.45, 19.6)), 64.0)
	# Walking out of the link into the garden bay.
	await _shot(output_dir, "h12_garden_entry.png", habitat.to_global(Vector3(9.6, 1.68, 20.0)), habitat.to_global(Vector3(16.8, 2.30, 21.9)), 70.0)
	# Standing under the cupola looking up past the column at the oculus.
	await _shot(output_dir, "h13_garden_cupola.png", habitat.to_global(Vector3(14.4, 1.62, 24.3)), habitat.to_global(Vector3(14.4, 6.30, 20.6)), 74.0)
	# The grow rack ring and the planting bed, from the bench side.
	await _shot(output_dir, "h14_garden_racks.png", habitat.to_global(Vector3(17.6, 1.62, 17.4)), habitat.to_global(Vector3(12.6, 1.10, 21.6)), 68.0)
	# The working end: potting bench, tools, seedlings.
	await _shot(output_dir, "h15_garden_service.png", habitat.to_global(Vector3(14.4, 1.62, 17.7)), habitat.to_global(Vector3(12.1, 1.05, 14.8)), 68.0)

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
