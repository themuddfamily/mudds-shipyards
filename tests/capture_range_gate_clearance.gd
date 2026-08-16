extends SceneTree

## HUD-free Forward+ evidence for the exterior range gate's clearance cue.
##
## The defect this exists to show is the one assertions kept missing: a review
## flight hit the range's own header beam at 46 m/s, and the reason it could is
## not measurable in a physics query. The beam was a 63 m unlit bar against
## vacuum, carrying no lamp, no marking and no legend, and the station's own
## published outbound aim pointed straight at it.
##
## Every frame is shot from the outbound centreline at the published clearance
## aim, at the distances a pilot actually sees the gate from, and each is
## captured **twice** — once with the cue and once with the cue hidden — so the
## pair is a before/after of the same camera rather than a claim about one image.
## `tests/outbound_route_clearance_test.gd` owns the numbers; this owns the look.
##
## Run:
##   xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . \
##     --display-driver x11 --rendering-driver vulkan \
##     --script tests/capture_range_gate_clearance.gd --audio-driver Dummy

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://artifacts/range-gate"
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)

## Node-name prefixes of everything the clearance cue adds. Hiding exactly these
## is what makes the "before" frame honest.
const CUE_PREFIXES := [
	"RangeHeaderClearanceStripe",
	"RangeHeaderClearanceChevron",
	"Sign_CLEARANCE",
]

var _failures: Array[String] = []
var _written: Array[String] = []
var _headless := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(CAPTURE_RESOLUTION)
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_headless = DisplayServer.get_name() == "headless"
	print(
		"RANGE_GATE_RENDERER: method=%s display=%s"
		% [RenderingServer.get_current_rendering_method(), DisplayServer.get_name()]
	)

	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	for _settle in 6:
		await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	if world == null:
		_fail("production Main exposed no ShipyardWorld")
		_finish()
		return
	if game.hud != null:
		game.hud.visible = false

	var band: Dictionary = world.get_outbound_clearance_band()
	var aim := float(band["aim_y"])
	print(
		"CLEARANCE_BAND: floor=%.2f ceiling=%.2f aim=%.2f launch_gate=%s"
		% [float(band["floor"]), float(band["ceiling"]), aim, str(world.get_launch_gate_transform().origin)]
	)

	var camera := Camera3D.new()
	camera.name = "RangeGateEvidenceCamera"
	camera.far = 3000.0
	game.add_child(camera)

	var shots := [
		{
			"name": "outbound_from_the_launch_gate",
			"from": Vector3(0.0, aim, -64.0),
			"look": Vector3(0.0, 9.0, -120.0),
			"fov": 62.0,
		},
		{
			"name": "outbound_100m_out",
			"from": Vector3(0.0, aim, -20.0),
			"look": Vector3(0.0, 9.0, -120.0),
			"fov": 62.0,
		},
		{
			"name": "under_the_beam",
			"from": Vector3(0.0, aim, -108.0),
			"look": Vector3(0.0, 9.0, -120.0),
			"fov": 70.0,
		},
		{
			"name": "beam_face_close",
			"from": Vector3(2.0, 7.6, -108.0),
			"look": Vector3(0.0, 9.0, -119.4),
			"fov": 40.0,
		},
		{
			"name": "clear_lane_from_the_side",
			"from": Vector3(58.0, 6.0, -96.0),
			"look": Vector3(0.0, 6.5, -120.0),
			"fov": 46.0,
		},
	]

	var exterior := world.get_node_or_null(^"ExteriorTargetRange") as Node3D
	for pass_index in 2:
		var with_cue := pass_index == 0
		_set_cue_visible(exterior, with_cue)
		await _frames(3)
		for index in shots.size():
			var shot: Dictionary = shots[index]
			camera.fov = float(shot["fov"])
			camera.global_position = shot["from"] as Vector3
			camera.look_at(shot["look"] as Vector3, Vector3.UP)
			camera.current = true
			await _frames(4)
			await _capture(
				"%02d_%s_%s.png"
				% [index + 1, shot["name"], "after" if with_cue else "before"]
			)
	_set_cue_visible(exterior, true)

	# The old aim, from the same seat, so the pair shows what the marker used to
	# point at. Nothing is changed to take it; the camera is simply put where the
	# marker used to be.
	camera.fov = 62.0
	camera.global_position = Vector3(0.0, 8.0, -64.0)
	camera.look_at(Vector3(0.0, 9.0, -120.0), Vector3.UP)
	camera.current = true
	await _frames(4)
	await _capture("06_old_aim_y8_collision_course.png")

	camera.queue_free()
	game.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _set_cue_visible(exterior: Node3D, visible_state: bool) -> void:
	if exterior == null:
		return
	var touched := 0
	for candidate in exterior.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		for prefix: String in CUE_PREFIXES:
			if mesh.name.begins_with(prefix):
				mesh.visible = visible_state
				touched += 1
				break
	# The obstruction lamps are lens + OmniLight pairs the guide-light helper adds
	# at the beam; they are matched by position because the helper names them all
	# the same and the engine renames the duplicates.
	for candidate in exterior.find_children("*", "OmniLight3D", true, false):
		var light := candidate as OmniLight3D
		if absf(light.global_position.y - 8.5) < 0.6 and light.global_position.z < -118.0:
			light.visible = visible_state
			touched += 1
	for candidate in exterior.find_children("*", "MeshInstance3D", true, false):
		var lens := candidate as MeshInstance3D
		if not lens.name.begins_with("GuideLens") and not lens.name.begins_with("@MeshInstance3D"):
			continue
		if absf(lens.global_position.y - 8.5) < 0.6 and lens.global_position.z < -118.0:
			lens.visible = visible_state
			touched += 1
	print("CUE_VISIBILITY: %s on %d pieces" % [str(visible_state), touched])


func _frames(count: int) -> void:
	for _index in count:
		await process_frame


func _capture(file_name: String) -> void:
	if _headless:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport image for " + file_name)
		return
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image.save_png(path) != OK:
		_fail("could not write " + path)
		return
	_written.append(file_name)
	print("WROTE ", path)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("CAPTURE FAIL: " + description)


func _finish() -> void:
	print("RANGE_GATE_FRAMES: ", ", ".join(_written))
	if _failures.is_empty():
		print("RANGE_GATE_CLEARANCE_CAPTURE_OK: %d frames" % _written.size())
		quit(0)
	else:
		print("RANGE_GATE_CLEARANCE_CAPTURE_FAILED: ", ", ".join(_failures))
		quit(1)
