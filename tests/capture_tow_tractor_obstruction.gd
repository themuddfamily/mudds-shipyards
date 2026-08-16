extends SceneTree

## Forward+ evidence for the tow tractor's obstruction fix.
##
## The deliverable of that fix is a vehicle that stops, so this harness does not
## photograph a static scene: it drives the shipped tractor at each obstacle with
## a real held throttle. Green runs settle against the blocker; red witnesses are
## frozen at their first measured overlap. Every frame is therefore a picture of
## an outcome rather than of a placement.
##
## Each obstacle is shot twice from the same camera, in a pair a reviewer can
## hold side by side: the fixed vehicle stopped against the thing, and the same
## drive with only the fix undone, which parks the vehicle inside the thing. The
## activity witnesses use `set_activity_enabled()` rather than mutating the
## world's sibling collision bodies behind their public lifecycle.
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
const RED_WITNESS_OVERLAP_TICKS := 6

var _failures: Array[String] = []
var _camera: Camera3D
var _evidence_banner: Label
var _output_dir := DEFAULT_OUTPUT_DIR


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Refuse to run blind rather than await a signal that will never arrive.
	var adapter := RenderingServer.get_video_adapter_name()
	var renderer := StringName(RenderingServer.get_current_rendering_method())
	var rendering_driver := RenderingServer.get_current_rendering_driver_name()
	var display_driver := DisplayServer.get_name()
	print("TRACTOR_CAPTURE_RENDERER: method=%s driver=%s display=%s adapter=%s" % [
		renderer, rendering_driver, display_driver, adapter,
	])
	_check(renderer == &"forward_plus", "capture uses the Forward+ rendering method")
	_check(not adapter.strip_edges().is_empty(), "capture resolves a real rendering adapter")
	if adapter.strip_edges().is_empty() or renderer != &"forward_plus":
		print("TRACTOR_CAPTURE_RENDERER_REJECTED: Forward+ and a nonempty adapter are required.")
		print("  Re-run with: VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a \\")
		print("    godot --path . --rendering-driver vulkan --script res://tests/capture_tow_tractor_obstruction.gd")
		quit(2)
		return

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
	_build_evidence_banner(game)

	await _capture_hull_pair(game, tractor)
	await _capture_central_gantry_pair(world, tractor)
	await _capture_aft_workpost_pair(world, tractor)

	RenderingServer.set_render_loop_enabled(true)
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
	# Frame from the reached green outcome. Targeting the hull's centre cropped the
	# tractor at the near edge; this wider port-quarter view keeps both bodies whole.
	var camera_position := tractor.global_position + Vector3(9.0, 4.2, 5.0)
	var camera_target := tractor.global_position + Vector3(0.0, 0.8, -3.0)
	await _shoot(
		"01_hull_green_stopped.png",
		camera_position,
		camera_target,
		"GREEN  /  SHIP HULL STOPS THE TOW",
		Color("77ed93")
	)

	tractor.collision_mask = PhysicsLayers.WORLD
	var red := await _drive_at(tractor, approach, Vector3.FORWARD, hull, true)
	_check(bool(red.entered_target), "hull red witness enters the saved hull bound")
	await _shoot(
		"02_hull_red_world_only_mask.png",
		camera_position,
		camera_target,
		"RED WITNESS  /  LEGACY WORLD-ONLY MASK ENTERS HULL",
		Color("ff665f")
	)
	# The tractor is frozen at the witnessed overlap. Restoring its production mask
	# is safe because the next drive moves it clear before restoring processing.
	tractor.collision_mask = PhysicsLayers.GROUND_VEHICLE_BODY_MASK


func _capture_central_gantry_pair(world: ShipyardWorld, tractor: TowTractor) -> void:
	var activity := world.get_node_or_null(
		^"OperationalLattice/Activities/CentralTowServiceActivity"
	) as StationOperationsActivity
	if activity == null:
		_check(false, "the Central tow-service activity resolves for capture")
		return
	var body := world.get_node_or_null(
		^"OperationalLattice/ActivityCollision/CentralTowServiceActivitySolids"
	) as StaticBody3D
	if body == null:
		_check(false, "the exact Central tow-service sibling solid body resolves")
		return
	var column: MeshInstance3D = null
	for candidate in activity.find_children("Column*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var mesh_name := str(mesh_instance.name)
		if not mesh_name.begins_with("Column") \
		or mesh_name.begins_with("ColumnEdge") \
		or mesh_instance.mesh == null:
			continue
		if column == null or mesh_instance.global_position.x < column.global_position.x:
			column = mesh_instance
	if column == null:
		_check(false, "the Central maintenance-gantry approach column resolves")
		return

	var drawn := column.global_transform * column.mesh.get_aabb()
	var approach := Vector3(drawn.position.x - APPROACH_GAP, 0.0, drawn.get_center().z)
	var camera_position := Vector3(
		drawn.get_center().x - 1.0,
		4.0,
		drawn.get_center().z - 11.0
	)
	var camera_target := Vector3(drawn.get_center().x - 0.9, 1.25, drawn.get_center().z)

	await _drive_at(tractor, approach, Vector3.RIGHT)
	await _shoot(
		"03_central_gantry_green_stopped.png",
		camera_position,
		camera_target,
		"GREEN  /  CENTRAL GANTRY COLUMN STOPS THE TOW",
		Color("77ed93")
	)

	# Public lifecycle red witness. It disables both presentation and the
	# world-owned sibling body; after the drive is frozen at the saved column bound,
	# the same public setter restores the presentation for an honest paired frame.
	activity.set_activity_enabled(false)
	await _advance(2)
	_check(
		not bool(activity.get_activity_state().visible)
		and body.collision_layer == PhysicsLayers.NONE,
		"Central public disable hides presentation and its sibling solids together"
	)
	var red := await _drive_at(tractor, approach, Vector3.RIGHT, drawn, true)
	_check(bool(red.entered_target), "Central gantry red witness enters the saved column bound")
	activity.set_activity_enabled(true)
	_check(
		bool(activity.get_activity_state().visible)
		and body.collision_layer == PhysicsLayers.WORLD_BODY_LAYER,
		"Central public re-enable restores presentation and its sibling solids together"
	)
	await _shoot(
		"04_central_gantry_red_disabled_lifecycle.png",
		camera_position,
		camera_target,
		"RED WITNESS  /  DISABLED ACTIVITY LETS TOW ENTER COLUMN",
		Color("ff665f")
	)


func _capture_aft_workpost_pair(world: ShipyardWorld, tractor: TowTractor) -> void:
	var activity := world.get_node_or_null(
		^"OperationalLattice/Activities/AftCrewWorkPost"
	) as StationOperationsActivity
	var body := world.get_node_or_null(
		^"OperationalLattice/ActivityCollision/AftCrewWorkPostSolids"
	) as StaticBody3D
	var crate := (
		activity.find_child("SupplyCrate", true, false) as MeshInstance3D
		if activity != null
		else null
	)
	if activity == null or body == null or crate == null or crate.mesh == null:
		_check(false, "the Aft workpost, sibling solid body, and east supply crate resolve")
		return
	var target := crate.global_transform * crate.mesh.get_aabb()
	var approach := Vector3(-5.36, 0.0, 52.0)
	var camera_position := target.get_center() + Vector3(8.0, 4.4, -8.5)
	var camera_target := target.get_center() + Vector3(0.0, 0.45, 0.0)

	await _drive_at(tractor, approach, Vector3.BACK)
	await _shoot(
		"05_aft_workpost_green_stopped.png",
		camera_position,
		camera_target,
		"GREEN  /  AFT RAMP RUN STOPS AT CREW WORKPOST",
		Color("77ed93")
	)

	activity.set_activity_enabled(false)
	await _advance(2)
	_check(
		not bool(activity.get_activity_state().visible)
		and body.collision_layer == PhysicsLayers.NONE,
		"Aft public disable hides workpost and its sibling solids together"
	)
	var red := await _drive_at(tractor, approach, Vector3.BACK, target, true)
	_check(
		bool(red.entered_target) and tractor.global_position.y >= 4.0,
		"Aft red witness climbs the real ramp and enters the saved crate bound"
	)
	activity.set_activity_enabled(true)
	_check(
		bool(activity.get_activity_state().visible)
		and body.collision_layer == PhysicsLayers.WORLD_BODY_LAYER,
		"Aft public re-enable restores workpost and its sibling solids together"
	)
	await _shoot(
		"06_aft_workpost_red_disabled_lifecycle.png",
		camera_position,
		camera_target,
		"RED WITNESS  /  DISABLED WORKPOST LETS TOW ENTER CRATE",
		Color("ff665f")
	)


## The same drive the regression suite runs, with a real held throttle. A red
## witness may stop on its first overlap with a saved visual bound; disabling the
## tractor's processing freezes that reached outcome for the software renderer.
func _drive_at(
	tractor: TowTractor,
	from: Vector3,
	heading: Vector3,
	target: AABB = AABB(),
	stop_on_target_entry: bool = false
	) -> Dictionary:
	await _reset_tractor(tractor, from, heading)
	var entered_target := false
	var overlap_ticks := 0
	var start := tractor.global_position
	tractor.set_driven(true)
	Input.action_press(&"move_forward")
	for _tick in DRIVE_TICKS:
		await physics_frame
		await process_frame
		if stop_on_target_entry:
			if entered_target:
				overlap_ticks += 1
				if overlap_ticks >= RED_WITNESS_OVERLAP_TICKS:
					break
			elif _chassis_world_aabb(tractor).intersects(target):
				entered_target = true
	Input.action_release(&"move_forward")
	tractor.set_driven(false)
	if stop_on_target_entry and entered_target:
		tractor.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		await _advance(SETTLE_TICKS)
	# The tractor's own chase camera takes `current` when it is driven; hand the
	# viewport back to the evidence camera before the shot.
	_camera.current = true
	await process_frame
	return {
		"entered_target": entered_target,
		"distance": start.distance_to(tractor.global_position),
		"position": tractor.global_position,
	}


func _reset_tractor(tractor: TowTractor, from: Vector3, heading: Vector3) -> void:
	var ground := _deck_under(tractor, from)
	tractor.set_driven(false)
	_release_inputs()
	tractor.velocity = Vector3.ZERO
	tractor.global_transform = Transform3D(
		Basis.looking_at(heading, Vector3.UP),
		Vector3(from.x, ground + 0.35, from.z)
	)
	tractor.reset_physics_interpolation()
	# Red frames leave the vehicle frozen at the witnessed overlap. Move it clear
	# before restoring production processing so no collider gets a staged response.
	tractor.process_mode = Node.PROCESS_MODE_INHERIT
	await _advance(SETTLE_TICKS)


func _shoot(
	file_name: String,
	from: Vector3,
	look_at: Vector3,
	banner_text: String,
	banner_colour: Color
	) -> void:
	_camera.current = true
	_camera.global_position = from
	if from.distance_to(look_at) > 0.05:
		_camera.look_at(look_at, Vector3.UP)
	_evidence_banner.text = banner_text
	_evidence_banner.add_theme_color_override("font_color", banner_colour)
	# Lavapipe is the correct Forward+ renderer, but rendering hundreds of unsaved
	# drive ticks would add no evidence. Render only the outcome frames we save.
	RenderingServer.set_render_loop_enabled(true)
	for _settle in 4:
		await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_check(false, "%s produced a viewport image" % file_name)
		RenderingServer.set_render_loop_enabled(false)
		return
	_check(
		_luminance_range(image) >= 0.03,
		"%s is nonblank (luminance range %.5f)" % [file_name, _luminance_range(image)]
	)
	var path := "%s/%s" % [_output_dir, file_name]
	_check(image.save_png(path) == OK, "%s saves successfully" % file_name)
	RenderingServer.set_render_loop_enabled(false)


func _build_evidence_banner(game: GameFlow) -> void:
	var layer := CanvasLayer.new()
	layer.name = "TractorEvidenceOverlay"
	layer.layer = 100
	game.add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(24.0, 22.0)
	panel.size = Vector2(910.0, 56.0)
	panel.color = Color(0.015, 0.025, 0.035, 0.88)
	layer.add_child(panel)
	_evidence_banner = Label.new()
	_evidence_banner.position = Vector2(20.0, 9.0)
	_evidence_banner.size = Vector2(870.0, 40.0)
	_evidence_banner.add_theme_font_size_override("font_size", 24)
	panel.add_child(_evidence_banner)
	# The first real frame is requested by `_shoot`; all route simulation between
	# captures now runs without spending CPU on unsaved software-Vulkan images.
	RenderingServer.set_render_loop_enabled(false)


func _chassis_world_aabb(tractor: TowTractor) -> AABB:
	var collision := tractor.get_node_or_null(^"ChassisCollision") as CollisionShape3D
	if collision == null or collision.shape == null:
		return AABB(tractor.global_position, Vector3.ZERO)
	return (
		tractor.global_transform * collision.transform
	) * collision.shape.get_debug_mesh().get_aabb()


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


func _release_inputs() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"brake"]:
		Input.action_release(action)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	_release_inputs()
	if _failures.is_empty():
		print("TOW_TRACTOR_OBSTRUCTION_CAPTURE_OK")
		quit(0)
	else:
		print("TOW_TRACTOR_OBSTRUCTION_CAPTURE_FAILED: ", "; ".join(_failures))
		quit(1)
