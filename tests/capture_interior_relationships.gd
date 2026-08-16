extends SceneTree

## Forward+ review harness for the interior-relationship pass: the comb dock
## arms, the regeneration/registry pod, and the central observation platform.
##
## It adds one evidence camera and nothing else — no capture-only architecture,
## signage, or lighting — and renders each room from the height and approach a
## player actually reaches it from, plus one grazing frame per room so a piece
## that hovers off its mount is visible against the surface it should be resting
## on. Every significant defect in this area was found by looking; this is the
## looking.
##
## Output goes to an external directory so a review pass never rewrites committed
## artifacts. Override with KETH_INTERIOR_CAPTURE_DIR.
##
##   godot --headless --path . --script tests/capture_interior_relationships.gd

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
## This box renders through llvmpipe, where a 2560x1440 TAA frame of the whole
## station costs minutes rather than seconds. Reviewing twelve rooms twice at
## that size is not a budget a working pass can pay, so the frame size is
## overridable and the review runs were taken at 1600x900. Nothing about the
## geometry depends on it; the smaller frame is a slower-machine concession, not
## a claim that original-resolution inspection happened.
const RESOLUTION_ENVIRONMENT_VARIABLE := "KETH_INTERIOR_CAPTURE_HEIGHT"
const OUTPUT_DIR_ENVIRONMENT_VARIABLE := "KETH_INTERIOR_CAPTURE_DIR"
const DEFAULT_OUTPUT_DIR := "user://interior_relationship_capture"

## file name, camera position, look-at target
const SHOTS := [
	# Dock-arm family. The comb sits at (12, 4.2, 68.3) yawed 90 degrees, so its
	# trunk runs along world +X at z = 68.3 and every slab hangs off it toward
	# lower z. Frames are taken from trunk eye height walking out along a rung.
	["01_comb_trunk_along.png", Vector3(14.5, 5.9, 68.3), Vector3(54.0, 4.6, 68.3)],
	["02_dock01_assigned.png", Vector3(28.5, 6.6, 63.5), Vector3(20.5, 4.6, 53.3)],
	["03_dock02_deferred_approach.png", Vector3(37.0, 5.9, 66.5), Vector3(37.0, 4.5, 53.3)],
	["04_dock02_deck_grazing.png", Vector3(37.0, 4.55, 61.5), Vector3(37.0, 4.30, 51.5)],
	["05_dock03_upper.png", Vector3(52.0, 8.6, 64.0), Vector3(52.0, 6.9, 53.3)],
	["06_comb_from_outboard.png", Vector3(34.0, 12.0, 40.0), Vector3(36.0, 4.6, 58.0)],
	# Regeneration family. The registry pod deck is at (-43, 0.18, 27) and is
	# approached from the lattice at lower z.
	["07_registry_pod_approach.png", Vector3(-43.0, 1.7, 18.5), Vector3(-43.0, 1.5, 26.0)],
	["08_registry_terminal.png", Vector3(-46.5, 1.75, 21.0), Vector3(-42.6, 1.5, 24.8)],
	["09_registry_deck_grazing.png", Vector3(-48.5, 0.55, 24.0), Vector3(-38.0, 0.45, 27.5)],
	# Platform family. The observation landing at (-11.5, 3.05, 3.0) is reached by
	# the seven-tread junction ramp from the spawn deck at higher z.
	["10_observation_landing_approach.png", Vector3(-11.5, 4.6, 14.0), Vector3(-11.5, 3.5, 3.5)],
	["11_observation_landing_on_deck.png", Vector3(-11.5, 5.0, 5.6), Vector3(-6.0, 2.4, 22.0)],
	["12_observation_landing_grazing.png", Vector3(-16.5, 3.55, 6.0), Vector3(-8.0, 3.35, 1.5)],
	# Room family, and the frame that shows OPS-GLAZING-001: the pod's starboard
	# corner, where a 4.7 m pane used to stand 2.83 m out in open space.
	["13_operations_pod_corner.png", Vector3(56.0, 4.6, 15.0), Vector3(45.0, 3.0, 23.4)],
	["14_operations_pod_frontage.png", Vector3(43.0, 2.4, 15.5), Vector3(43.0, 3.2, 23.0)],
]

var _failures: Array[String] = []
var _camera: Camera3D
var _output_dir := DEFAULT_OUTPUT_DIR


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment(OUTPUT_DIR_ENVIRONMENT_VARIABLE)
	if _output_dir.is_empty():
		_output_dir = DEFAULT_OUTPUT_DIR
	DirAccess.make_dir_recursive_absolute(_output_dir)
	print("INTERIOR_CAPTURE_OUTPUT_DIR: ", ProjectSettings.globalize_path(_output_dir))

	var capture_size := CAPTURE_RESOLUTION
	var requested_height := int(OS.get_environment(RESOLUTION_ENVIRONMENT_VARIABLE))
	if requested_height >= 240:
		capture_size = Vector2i(int(round(float(requested_height) * 16.0 / 9.0)), requested_height)
	print("INTERIOR_CAPTURE_RESOLUTION: ", capture_size)
	root.size = capture_size
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

	var player := game.get_node_or_null(^"Player") as PlayerController
	if player != null:
		player.set_camera_active(false)
		player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(-8.5, 0.6, 11.0)))

	_camera = Camera3D.new()
	_camera.name = "InteriorRelationshipEvidenceCamera"
	_camera.fov = 62.0
	_camera.far = 6000.0
	game.add_child(_camera)
	_camera.current = true

	for shot in SHOTS:
		_camera.global_position = shot[1] as Vector3
		_camera.look_at(shot[2] as Vector3, Vector3.UP)
		for _settle in 4:
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
	var statistics := _sample_luminance_statistics(image)
	_check(
		float(statistics["range"]) >= 0.03,
		"%s is nonblank (luminance range %.5f, mean %.5f)" % [
			file_name, float(statistics["range"]), float(statistics["mean"])
		]
	)
	var path := "%s/%s" % [_output_dir, file_name]
	_check(image.save_png(path) == OK, "%s saves successfully" % file_name)


func _sample_luminance_statistics(image: Image) -> Dictionary:
	var minimum := 1.0
	var maximum := 0.0
	var total := 0.0
	var samples := 0
	var step_x: int = maxi(1, image.get_width() / 160)
	var step_y: int = maxi(1, image.get_height() / 90)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			var luminance := image.get_pixel(x, y).get_luminance()
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
			total += luminance
			samples += 1
	return {
		"range": maximum - minimum,
		"mean": total / maxf(1.0, float(samples)),
	}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("CAPTURE_INTERIOR_RELATIONSHIPS_OK")
		quit(0)
	else:
		print("CAPTURE_INTERIOR_RELATIONSHIPS_FAILED: ", "; ".join(_failures))
		quit(1)
