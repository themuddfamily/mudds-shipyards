extends SceneTree

## Rendered review harness for the station cargo transfer lines.
##
## Every defect this family has produced so far — a hoist carriage detaching
## from its own beam, a sled sinking through its own rail — was invisible at
## rest and only appeared mid-travel. So this harness photographs each line from
## a walk-up framing at several points along the sled's travel rather than once.
##
## This box has no rendering device under `--headless`: the adapter name comes
## back empty, `get_texture().get_image()` returns null and
## `RenderingServer.frame_post_draw` never fires, so a headless capture hangs
## rather than failing. This script therefore *refuses* instead of awaiting a
## signal that will never arrive. Run it as:
##
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a godot \
##     --path . --rendering-driver vulkan --script res://tools/capture_cargo_lines.gd

const MAIN_SCENE := preload("res://scenes/main.tscn")

const OUTPUT_DIR := "res://artifacts/cargo_lines"
const CAPTURE_RESOLUTION := Vector2i(1280, 720)
## Seconds of activity clock to seek to. The sled travel is a sine, so 0.0 is a
## mid-rail crossing at speed, and the quarter phases are the two rail stops.
const DEFAULT_TRAVEL_SAMPLE_SECONDS: Array[float] = [0.0, 8.0, 16.0, 24.0, 32.0]

var _game: Node3D
var _camera: Camera3D
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if RenderingServer.get_video_adapter_name().is_empty():
		push_error("CARGO_LINE_CAPTURE: no rendering device. Run under xvfb-run with --rendering-driver vulkan.")
		quit(2)
		return
	DisplayServer.window_set_size(CAPTURE_RESOLUTION)
	root.content_scale_size = CAPTURE_RESOLUTION
	get_root().size = CAPTURE_RESOLUTION
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	_game = MAIN_SCENE.instantiate() as Node3D
	root.add_child(_game)
	await _settle(12)
	# The production tree boots into the title layer. Every `CanvasLayer` is
	# switched off rather than dismissed, so nothing about the world's state
	# depends on a simulated keypress.
	for candidate in _game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED
	await _settle(4)

	var world := _game.get_node_or_null(^"ShipyardWorld") as Node3D
	if world == null:
		push_error("CARGO_LINE_CAPTURE: ShipyardWorld missing")
		quit(3)
		return

	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.near = 0.05
	_camera.far = 900.0
	root.add_child(_camera)
	_camera.make_current()

	var activities: Array = []
	for candidate in _game.find_children("*", "StationOperationsActivity", true, false):
		activities.append(candidate)

	var samples: Array[float] = DEFAULT_TRAVEL_SAMPLE_SECONDS.duplicate()
	var sample_override := OS.get_environment("KETH_CARGO_SAMPLES")
	if not sample_override.is_empty():
		samples.clear()
		for value in sample_override.split(",", false):
			samples.append(value.to_float())

	var framings := _framings()
	for framing: Dictionary in framings:
		for seconds: float in samples:
			for activity in activities:
				activity.set_activity_time(seconds)
			await _settle(3)
			_camera.global_transform = Transform3D(
				Basis.looking_at((framing.look_at as Vector3) - (framing.eye as Vector3), Vector3.UP),
				framing.eye as Vector3
			)
			await _settle(2)
			_save("%s_t%0.1f.png" % [str(framing.name), seconds])

	print("CARGO_LINE_CAPTURE_FAILURES: ", _failures)
	quit(0 if _failures.is_empty() else 1)


## Camera framings, read from the environment so the same harness can be aimed
## at a line without editing it. `KETH_CARGO_FRAMINGS` is a `;`-separated list of
## `name,eyex,eyey,eyez,atx,aty,atz`.
func _framings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var spec := OS.get_environment("KETH_CARGO_FRAMINGS")
	for row in spec.split(";", false):
		var parts := row.split(",", false)
		if parts.size() != 7:
			continue
		result.append({
			"name": parts[0],
			"eye": Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float()),
			"look_at": Vector3(parts[4].to_float(), parts[5].to_float(), parts[6].to_float()),
		})
	return result


func _settle(frames: int) -> void:
	for _index in frames:
		await process_frame
		await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	var image := get_root().get_texture().get_image()
	if image == null:
		_failures.append("%s produced no image" % file_name)
		return
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image.save_png(path) != OK:
		_failures.append("%s failed to write" % file_name)
		return
	print("CARGO_LINE_CAPTURE: wrote ", path, " ", image.get_width(), "x", image.get_height())
