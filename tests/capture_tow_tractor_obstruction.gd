extends SceneTree

## Forward+ evidence for the tow tractor's obstruction fix.
##
## The deliverable of that fix is a vehicle that stops, so this harness does not
## photograph a static scene: it drives the shipped tractor at each obstacle with
## a real held throttle, lets it come to rest, and photographs where it ended up.
## Every frame is therefore a picture of an outcome rather than of a placement.
##
## Each obstacle is shot twice, in a pair a reviewer can hold side by side: the
## fixed vehicle stopped against the thing, and the same drive with only the fix
## undone, which parks the vehicle inside the thing.
##
## Output goes to an external directory so a review pass never rewrites committed
## artifacts. Override with KETH_TRACTOR_CAPTURE_DIR.
##
## ## Running this
##
## `--headless` on the current build box has no rendering device at all: the
## adapter name is empty and `RenderingServer.frame_post_draw` never fires, so a
## capture run under it hangs rather than failing. This harness refuses to start
## in that state instead of waiting forever. Run it as:
##
##     VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a godot \
##       --path . --rendering-driver vulkan --script res://tests/capture_tow_tractor_obstruction.gd

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAPTURE_RESOLUTION := Vector2i(1600, 900)
const OUTPUT_DIR_ENVIRONMENT_VARIABLE := "KETH_TRACTOR_CAPTURE_DIR"
const DEFAULT_OUTPUT_DIR := "user://tow_tractor_obstruction_capture"

const APPROACH_GAP := 7.0
const DRIVE_TICKS := 150
const SETTLE_TICKS := 8

var _failures: Array[String] = []
var _camera: Camera3D
var _output_dir := DEFAULT_OUTPUT_DIR


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Refuse to run blind rather than await a signal that will never arrive.
	var adapter := RenderingServer.get_video_adapter_name()
	if adapter.strip_edges().is_empty():
		print("TRACTOR_CAPTURE_NO_RENDERING_DEVICE: this build has no video adapter.")
		print("  Re-run with: VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a \\")
		print("    godot --path . --rendering-driver vulkan --script res://tests/capture_tow_tractor_obstruction.gd")
		quit(2)
		return
	print("TRACTOR_CAPTURE_ADAPTER: ", adapter)

	_output_dir = OS.get_environment(OUTPUT_DIR_ENVIRONMENT_VARIABLE)
	if _output_dir.is_empty():
		_output_dir = DEFAULT_OUTPUT_DIR
	DirAccess.make_dir_recursive_absolute(_output_dir)
	print("TRACTOR_CAPTURE_OUTPUT_DIR: ", ProjectSettings.globalize_path(_output_dir))

	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_2X

	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await _advance(4)
	game.start_shift()
	await _advance(12)

	for candidate in game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED

	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var tractor := game.get_tow_tractor()
	var player := game.get_node_or_null(^"Player") as PlayerController
	if player != null:
		player.set_camera_active(false)
		player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(-8.5, 0.6, 11.0)))

	_camera = Camera3D.new()
	_camera.name = "TractorEvidenceCamera"
	_camera.fov = 58.0
	_camera.far = 6000.0
	game.add_child(_camera)
	_camera.current = true

	await _capture_hull_pair(game, tractor)
	await _capture_column_pair(world, tractor)
	await _capture_dock_02(world)

	game.queue_free()
	await _advance(2)
	_finish()


func _capture_hull_pair(game: GameFlow, tractor: TowTractor) -> void:
	var torrent := game.get_node_or_null(^"TorrentInterceptor") as CharacterBody3D
	if torrent == null:
		_check(false, "the Torrent resolves as a hull to drive into")
		return
	var hull := _body_world_aabb(torrent)
	var approach := Vector3(hull.get_center().x, 0.0, hull.end.z + APPROACH_GAP)

	await _drive_at(tractor, approach, Vector3.FORWARD)
	await _shoot(
		"01_hull_stopped.png",
		tractor.global_position + Vector3(9.0, 4.2, 5.0),
		tractor.global_position + Vector3(0.0, 0.8, -3.0)
	)
	await _shoot(
		"02_hull_stopped_grazing.png",
		tractor.global_position + Vector3(-7.5, 1.1, 1.0),
		tractor.global_position + Vector3(0.0, 0.9, -4.0)
	)

	tractor.collision_mask = PhysicsLayers.WORLD
	await _drive_at(tractor, approach, Vector3.FORWARD)
	tractor.collision_mask = PhysicsLayers.GROUND_VEHICLE_BODY_MASK
	await _shoot(
		"03_hull_red_witness.png",
		Vector3(hull.get_center().x + 9.0, 4.2, hull.end.z + 5.0),
		Vector3(hull.get_center().x, 0.8, hull.get_center().z)
	)


func _capture_column_pair(world: ShipyardWorld, tractor: TowTractor) -> void:
	var column: MeshInstance3D = null
	var activity: StationOperationsActivity = null
	for candidate in world.find_children("*", "StationOperationsActivity", true, false):
		var vignette := candidate as StationOperationsActivity
		if vignette.global_position.distance_to(tractor.get_home_transform().origin) > 12.0:
			continue
		for mesh_candidate in vignette.find_children("Column*", "MeshInstance3D", true, false):
			var mesh_instance := mesh_candidate as MeshInstance3D
			if not str(mesh_instance.name).begins_with("Column") or mesh_instance.mesh == null:
				continue
			if column == null or mesh_instance.global_position.x < column.global_position.x:
				column = mesh_instance
				activity = vignette
	if column == null or activity == null:
		_check(false, "a maintenance-gantry column resolves within driving range")
		return

	var drawn := column.global_transform * column.mesh.get_aabb()
	var approach := Vector3(drawn.position.x - APPROACH_GAP, 0.0, drawn.get_center().z)

	await _drive_at(tractor, approach, Vector3.RIGHT)
	await _shoot(
		"04_column_stopped.png",
		tractor.global_position + Vector3(-3.0, 3.4, -8.0),
		drawn.get_center() - Vector3(0.0, 1.4, 0.0)
	)
	await _shoot(
		"05_column_stopped_grazing.png",
		tractor.global_position + Vector3(-1.0, 1.0, -6.5),
		Vector3(drawn.get_center().x, 0.9, drawn.get_center().z)
	)

	var bodies := world.find_children("%sSolids" % activity.name, "StaticBody3D", true, false)
	if bodies.is_empty():
		_check(false, "the world built a solid-volume body for this vignette to switch off")
		return
	var solid_volume_body := bodies[0] as StaticBody3D
	solid_volume_body.collision_layer = PhysicsLayers.NONE
	await _drive_at(tractor, approach, Vector3.RIGHT)
	solid_volume_body.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	# Framed side-on to the drive line with the column and the tractor's resting
	# place both in shot, because the failure is that the vehicle finished *past*
	# the pole rather than against it.
	var midpoint := (tractor.global_position + drawn.get_center()) * 0.5
	await _shoot(
		"06_column_red_witness.png",
		Vector3(midpoint.x, 4.0, drawn.get_center().z - 11.0),
		Vector3(midpoint.x, 1.2, drawn.get_center().z)
	)


## Fleet Dock 02 after the promotion pass: cyan assigned paint and label under the
## Halyard instead of the deferred red, the arm's boom run out with its hose
## dropped, and no toe kerb lying across the middle of the widened pad. Shot from
## above for the paint and the missing lip, and at grazing deck height because a
## 0.13 m lip is invisible from anywhere else.
func _capture_dock_02(world: ShipyardWorld) -> void:
	var comb := world.get_node_or_null(^"FleetDockComb") as FleetDockComb
	if comb == null:
		_check(false, "the fleet dock comb resolves for the dock 02 evidence")
		return
	var pad_centre := comb.to_global(Vector3(15.0, 0.0, 25.0))
	await _shoot(
		"07_dock_02_plan.png",
		pad_centre + Vector3(0.0, 26.0, -13.0),
		pad_centre
	)
	# Along the seam the removed kerb used to stand on, at deck height.
	await _shoot(
		"08_dock_02_seam_grazing.png",
		pad_centre + Vector3(-11.0, 1.0, -10.5),
		pad_centre + Vector3(9.0, 0.35, -6.0)
	)


## The same drive the regression suite runs, with a real held throttle.
func _drive_at(tractor: TowTractor, from: Vector3, heading: Vector3) -> void:
	var ground := _deck_under(tractor, from)
	tractor.set_driven(false)
	tractor.velocity = Vector3.ZERO
	tractor.global_transform = Transform3D(
		Basis.looking_at(heading, Vector3.UP),
		Vector3(from.x, ground + 0.35, from.z)
	)
	tractor.reset_physics_interpolation()
	await _advance(SETTLE_TICKS)
	tractor.set_driven(true)
	Input.action_press(&"move_forward")
	await _advance(DRIVE_TICKS)
	Input.action_release(&"move_forward")
	await _advance(SETTLE_TICKS)
	tractor.set_driven(false)
	# The tractor's own chase camera takes `current` when it is driven; hand the
	# viewport back to the evidence camera before the shot.
	_camera.current = true
	await process_frame


func _shoot(file_name: String, from: Vector3, look_at: Vector3) -> void:
	_camera.global_position = from
	if from.distance_to(look_at) > 0.05:
		_camera.look_at(look_at, Vector3.UP)
	for _settle in 4:
		await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_check(false, "%s produced a viewport image" % file_name)
		return
	_check(
		_luminance_range(image) >= 0.03,
		"%s is nonblank (luminance range %.5f)" % [file_name, _luminance_range(image)]
	)
	var path := "%s/%s" % [_output_dir, file_name]
	_check(image.save_png(path) == OK, "%s saves successfully" % file_name)


func _luminance_range(image: Image) -> float:
	var minimum := 1.0
	var maximum := 0.0
	var step := maxi(1, image.get_width() / 96)
	for x in range(0, image.get_width(), step):
		for y in range(0, image.get_height(), step):
			var luminance := image.get_pixel(x, y).get_luminance()
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	return maximum - minimum


func _body_world_aabb(body: CollisionObject3D) -> AABB:
	var result := AABB()
	var first := true
	for candidate in body.get_children():
		var collision := candidate as CollisionShape3D
		if collision == null or collision.shape == null or collision.disabled:
			continue
		var world := (body.global_transform * collision.transform) * collision.shape.get_debug_mesh().get_aabb()
		if first:
			result = world
			first = false
		else:
			result = result.merge(world)
	return result


func _deck_under(tractor: TowTractor, point: Vector3) -> float:
	var space := tractor.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x, point.y + 8.0, point.z),
		Vector3(point.x, point.y - 12.0, point.z),
		PhysicsLayers.WORLD
	)
	query.collide_with_areas = false
	query.exclude = [tractor.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return point.y
	return (hit.position as Vector3).y


func _advance(frames: int) -> void:
	for _frame in maxi(1, frames):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"brake"]:
		Input.action_release(action)
	if _failures.is_empty():
		print("TOW_TRACTOR_OBSTRUCTION_CAPTURE_OK")
		quit(0)
	else:
		print("TOW_TRACTOR_OBSTRUCTION_CAPTURE_FAILED: ", "; ".join(_failures))
		quit(1)
