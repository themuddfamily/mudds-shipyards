extends SceneTree

## Forward+ evidence harness for the MAP-001/002/003 traversal fix.
##
## Renders the three places the fix changed geometry, plus a wide silhouette
## frame on each side of the station, so a reviewer can confirm that opening the
## routes did not deform the station's read. It adds one evidence camera and
## nothing else; no capture-only architecture, signage, or lighting.
##
## Output goes to an external directory so a review pass never rewrites committed
## artifacts. Override with KETH_MAP_CAPTURE_DIR.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
const OUTPUT_DIR_ENVIRONMENT_VARIABLE := "KETH_MAP_CAPTURE_DIR"
const DEFAULT_OUTPUT_DIR := "user://map_traversal_fix_capture"

## file name, camera position, look-at target
const SHOTS := [
	["01_aft_stair_gate.png", Vector3(6.5, 6.0, 45.0), Vector3(-5.0, 1.2, 52.5)],
	["02_aft_stair_base_landing.png", Vector3(2.0, 2.6, 48.0), Vector3(-5.6, 0.6, 53.0)],
	["03_aft_ramp_from_upper.png", Vector3(-5.2, 9.0, 70.0), Vector3(-5.4, 2.0, 54.0)],
	["04_registry_pod_threshold.png", Vector3(-52.0, 2.2, 19.0), Vector3(-39.0, 0.18, 23.2)],
	["05_registry_threshold_grazing.png", Vector3(-43.0, 1.5, 19.6), Vector3(-43.0, 0.18, 23.3)],
	["06_operations_pod_threshold.png", Vector3(58.0, 9.0, 12.0), Vector3(43.0, 0.3, 24.5)],
	["07_operations_threshold_grazing.png", Vector3(43.0, 2.6, 18.0), Vector3(43.0, 0.18, 23.4)],
	["08_silhouette_port.png", Vector3(-120.0, 34.0, -40.0), Vector3(-6.0, 2.0, 30.0)],
	["09_silhouette_starboard.png", Vector3(122.0, 34.0, -40.0), Vector3(6.0, 2.0, 30.0)],
	["10_silhouette_aft_high.png", Vector3(24.0, 46.0, 120.0), Vector3(-2.0, 2.0, 46.0)],
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
	print("MAP_CAPTURE_OUTPUT_DIR: ", ProjectSettings.globalize_path(_output_dir))

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

	# HUD-free evidence: the title card and every production overlay are disabled
	# so the frames show only the station.
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
	_camera.name = "MapEvidenceCamera"
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
		"%s is nonblank (luminance range %.5f)" % [file_name, float(statistics["range"])]
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
		print("CAPTURE_MAP_TRAVERSAL_FIX_OK")
		quit(0)
	else:
		print("CAPTURE_MAP_TRAVERSAL_FIX_FAILED: ", "; ".join(_failures))
		quit(1)
