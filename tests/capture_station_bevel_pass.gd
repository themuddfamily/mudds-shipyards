extends SceneTree

## Before/after evidence harness for the curved-and-bevelled authored geometry
## pass (ROADMAP Phase 2).
##
## The pass it exists for is an art change: it chamfers the flat structural slab
## stock of the fleet expansion berths and the Arrow's fitted box stock. Counts
## cannot say whether that worked, so the frames are the evidence and this
## harness is the only thing in the repository that takes them at the distances
## the claim is made at.
##
## Why it is not one of the existing capture scripts. `tests/capture_scenes.gd`
## is a fixed 27-frame gameplay walkthrough at 2560x1440 that writes into
## committed `res://artifacts`; `tests/capture_art_direction.gd` is seven wide
## lighting shots weighted at 100 m and further, and it exists to catch the
## opposite failure (a change that is locally right and globally invisible).
## Neither frames a walkway edge at 1.5 m or a cockpit sill at 0.5 m, and a
## chamfer that is 38 mm wide is below one pixel in every frame either of them
## takes. The twelve viewpoints below are each parked at the range a player
## actually stands at from the specific piece the pass altered.
##
## Everything is a live production Main. The only capture-only object is one
## `Camera3D`; production overlays are hidden so the frames show the world and
## not the HUD. Output goes outside the repository so a review pass never
## rewrites a committed artifact.
##
## Run one tag per build with `KETH_BEVEL_CAPTURE_TAG`, on each renderer:
##
##     godot --headless=false --rendering-method gl_compatibility ... \
##         --script tests/capture_station_bevel_pass.gd
##
## Two tags taken from the *same* build are the noise floor; the before/after
## difference is only readable against it.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAPTURE_RESOLUTION := Vector2i(1280, 720)
const OUTPUT_DIR_ENVIRONMENT_VARIABLE := "KETH_BEVEL_CAPTURE_DIR"
const TAG_ENVIRONMENT_VARIABLE := "KETH_BEVEL_CAPTURE_TAG"
const DEFAULT_OUTPUT_DIR := "user://station_bevel_capture"

## file name, eye, look-at target, fov. World-space, metres.
##
## Standing eye height on these decks is the walkway top plus 1.7 m; the two
## cockpit frames are at the Arrow's own seated eye. Nothing here is a wide
## establishing shot on purpose — a wide shot cannot answer this question.
const SHOTS := [
	# Fleet expansion berths: the pedestrian access circulation. The player
	# walks the length of every one of these decks with its 0.6 m edge under
	# their feet.
	["01_cargo_trunk_walkway.png", Vector3(4.0, 5.9, 79.65), Vector3(21.0, 4.6, 79.7), 62.0],
	["02_cargo_boarding_leg.png", Vector3(8.3, 5.9, 94.0), Vector3(8.25, 4.4, 86.0), 62.0],
	["03_bomber_berth_leg.png", Vector3(-2.0, 5.9, 49.7), Vector3(-19.0, 4.4, 49.7), 62.0],
	# The underframe: five chords and the support posts, seen from the apron
	# below looking up at what carries the walkway.
	["04_access_underframe.png", Vector3(4.0, 1.4, 88.0), Vector3(12.0, 3.1, 80.0), 62.0],
	# Dock 04: the cargo crane. Mast, jib and hoist, from the apron.
	["05_cargo_crane.png", Vector3(-1.5, 6.2, 90.5), Vector3(0.0, 12.0, 101.0), 60.0],
	# Dock 05: the ordnance gantry and the 24 m blast safety datum.
	["06_blast_datum.png", Vector3(-17.0, 6.6, 44.0), Vector3(-22.0, 5.0, 36.5), 60.0],
	["07_ordnance_gantry.png", Vector3(-4.0, 6.2, 52.3), Vector3(-11.0, 9.5, 52.3), 60.0],
	# Dock 06: the launch frame and the two 22 m launch rails.
	["08_launch_frame.png", Vector3(30.0, 6.4, 90.0), Vector3(30.0, 11.0, 71.0), 60.0],
	["09_launch_rail_walkup.png", Vector3(44.2, 5.6, 77.0), Vector3(46.2, 4.5, 68.5), 62.0],
	# The Arrow. Its fitted box stock was the only unchamfered stock in the
	# fleet; the cockpit surround is the closest a player ever gets to any of it.
	["10_arrow_cockpit.png", Vector3(-42.9, 3.88, 15.5), Vector3(-45.6, 3.42, 15.5), 66.0],
	["11_arrow_cockpit_sill.png", Vector3(-43.1, 3.95, 15.62), Vector3(-43.9, 3.45, 16.9), 66.0],
	["12_arrow_walkup.png", Vector3(-38.6, 2.5, 20.4), Vector3(-45.0, 2.4, 15.2), 60.0],
]

var _failures: Array[String] = []
var _camera: Camera3D
var _output_dir := DEFAULT_OUTPUT_DIR
var _tag := "untagged"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment(OUTPUT_DIR_ENVIRONMENT_VARIABLE)
	if _output_dir.is_empty():
		_output_dir = DEFAULT_OUTPUT_DIR
	var tag := OS.get_environment(TAG_ENVIRONMENT_VARIABLE)
	if not tag.is_empty():
		_tag = tag
	_output_dir = _output_dir.path_join(_tag)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	print("BEVEL_CAPTURE_TAG: ", _tag)
	print("BEVEL_CAPTURE_RENDERER: ", RenderingServer.get_current_rendering_method())
	print("BEVEL_CAPTURE_OUTPUT_DIR: ", ProjectSettings.globalize_path(_output_dir))

	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	# Temporal anti-aliasing and MSAA both resolve differently from frame to
	# frame, which would put the noise floor above the feature being measured.
	# A chamfer band is a geometric edge, so it is captured raw.
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED

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
		# Parked well clear of every framed piece so the pilot body never
		# occludes the geometry under test.
		player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(-8.5, 0.6, 11.0)))
	await process_frame

	_camera = Camera3D.new()
	_camera.name = "BevelEvidenceCamera"
	_camera.near = 0.05
	_camera.far = 6000.0
	game.add_child(_camera)
	_camera.current = true

	for shot in SHOTS:
		_camera.fov = float(shot[3])
		_camera.global_position = shot[1] as Vector3
		_camera.look_at(shot[2] as Vector3, Vector3.UP)
		for _settle in 8:
			await process_frame
		await _capture(shot[0] as String)

	game.queue_free()
	await process_frame
	_finish()


func _capture(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_check(false, "%s produced a viewport image" % file_name)
		return
	var path := _output_dir.path_join(file_name)
	var error := image.save_png(path)
	_check(error == OK, "%s was written" % file_name)
	var statistics := _luminance(image)
	_check(
		float(statistics["range"]) >= 0.03,
		"%s is nonblank (luminance range %.5f)" % [file_name, float(statistics["range"])]
	)
	print("BEVEL_FRAME %s mean=%.5f range=%.5f" % [
		file_name, float(statistics["mean"]), float(statistics["range"])
	])


func _luminance(image: Image) -> Dictionary:
	var total := 0.0
	var lowest := 1.0
	var highest := 0.0
	var samples := 0
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var colour := image.get_pixel(x, y)
			var luminance := colour.r * 0.2126 + colour.g * 0.7152 + colour.b * 0.0722
			total += luminance
			lowest = minf(lowest, luminance)
			highest = maxf(highest, luminance)
			samples += 1
	if samples == 0:
		return {"mean": 0.0, "range": 0.0}
	return {"mean": total / float(samples), "range": highest - lowest}


func _check(passed: bool, description: String) -> void:
	if passed:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		print("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("CAPTURE_STATION_BEVEL_PASS_OK: %d frames" % SHOTS.size())
		quit(0)
		return
	print("CAPTURE_STATION_BEVEL_PASS_FAILED: %d" % _failures.size())
	quit(1)
