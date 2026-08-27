extends SceneTree

## Stable Forward+ witness for the Halyard's two open cabin pressure frames.
## Run once before and once after the renderer-only portal-upright batch; the
## same two on-foot camera transforms must remain pixel equivalent.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const CAPTURE_RESOLUTION := Vector2i(1600, 900)
const DEFAULT_OUTPUT_DIR := "user://halyard_cabin_portal_upright_batch"
const OUTPUT_DIR_ENVIRONMENT_VARIABLE := "HALYARD_PORTAL_CAPTURE_DIR"

const SHOTS := [
	{
		"file": "forward_portal.png",
		"camera": Vector3(0.0, 1.72, -5.35),
		"target": Vector3(0.0, 1.82, -9.70),
	},
	{
		"file": "aft_portal.png",
		"camera": Vector3(0.0, 1.72, -1.10),
		"target": Vector3(0.0, 1.82, 2.50),
	},
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_2X
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture uses a live Forward+ rendering device"
	)

	var output_dir := OS.get_environment(OUTPUT_DIR_ENVIRONMENT_VARIABLE)
	if output_dir.is_empty():
		output_dir = DEFAULT_OUTPUT_DIR
	var absolute_output_dir := ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(absolute_output_dir)

	var world := Node3D.new()
	world.name = "HalyardCabinPortalReviewWorld"
	root.add_child(world)
	_build_environment(world)

	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	_check(craft != null, "production Halyard instantiates")
	if craft == null:
		_finish()
		return
	world.add_child(craft)
	await process_frame
	await physics_frame

	var cabin := craft.get_node_or_null(^"WalkableInterior/CrewCabin") as Node3D
	_check(cabin != null, "production crew cabin resolves")
	if cabin == null:
		_finish()
		return

	var camera := Camera3D.new()
	camera.name = "HalyardCabinPortalReviewCamera"
	camera.near = 0.05
	camera.far = 100.0
	camera.fov = 67.0
	world.add_child(camera)
	camera.current = true

	for shot in SHOTS:
		camera.global_position = cabin.to_global(shot.camera as Vector3)
		camera.look_at(cabin.to_global(shot.target as Vector3), cabin.global_basis.y.normalized())
		for _frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(
			image != null and not image.is_empty() and image.get_size() == CAPTURE_RESOLUTION,
			"%s renders at the requested resolution" % shot.file
		)
		if image != null and not image.is_empty():
			_check(
				image.save_png(absolute_output_dir.path_join(shot.file as String)) == OK,
				"%s saves successfully" % shot.file
			)

	world.queue_free()
	await process_frame
	print("HALYARD_CABIN_PORTAL_CAPTURE_DIR: ", absolute_output_dir)
	_finish()


func _build_environment(world: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07111a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("99abb0")
	environment.ambient_light_energy = 0.34
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = false
	world_environment.environment = environment
	world.add_child(world_environment)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HALYARD_CABIN_PORTAL_UPRIGHT_CAPTURE_OK")
		quit(0)
		return
	push_error("HALYARD_CABIN_PORTAL_UPRIGHT_CAPTURE_FAILED: %s" % "; ".join(_failures))
	quit(1)
