extends SceneTree

## Native Forward+ before/after witness for the Habitat mess-table trestle feet.
## The fixed common-room camera first draws two ordinary MeshInstance3D copies,
## then the production MultiMesh. Full-frame identity and a bounded table-foot
## region prove the renderer trim does not move or alter visible geometry.

const MODULE_SCENE := preload("res://scenes/world/modules/habitat_spine.tscn")
const RESOLUTION := Vector2i(1600, 900)
const OUTPUT_DIR := "res://artifacts/habitat_mess_trestle_foot_batch"
const BEFORE_PATH := OUTPUT_DIR + "/before_individual_feet.png"
const AFTER_PATH := OUTPUT_DIR + "/after_batched_feet.png"
const CAMERA_POSITION := Vector3(3.0, 0.72, 18.20)
const CAMERA_TARGET := Vector3(5.55, 0.22, 23.30)

var _failures: Array[String] = []
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and DisplayServer.get_name() == "X11"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a native X11 Forward+ rendering device"
	)

	var stage := Node3D.new()
	stage.name = "HabitatMessTrestleReviewStage"
	root.add_child(stage)
	_build_environment(stage)
	var habitat := MODULE_SCENE.instantiate() as HabitatSpine
	_check(habitat != null, "production Habitat Spine instantiates")
	if habitat == null:
		_finish()
		return
	stage.add_child(habitat)
	await process_frame
	await physics_frame

	var mess := habitat.get_node_or_null(
		^"Structure/ObservationCommon/CommonMess"
	) as Node3D
	var batch := mess.get_node_or_null(^"MessTrestleFeet") as MultiMeshInstance3D \
		if mess != null else null
	_check(
		batch != null and batch.multimesh != null
			and batch.multimesh.instance_count
				== HabitatSpine.MESS_TRESTLE_FOOT_COPY_COUNT,
		"production mess owns the exact two-copy trestle-foot batch"
	)
	if batch == null or batch.multimesh == null:
		_finish()
		return

	var baseline := Node3D.new()
	baseline.name = "BeforeIndividualTrestleFeet"
	mess.add_child(baseline)
	var authored := batch.get_meta(&"authored_instance_transforms", []) as Array
	for index in authored.size():
		var renderer := MeshInstance3D.new()
		renderer.name = "BeforeMessTrestleFoot%02d" % (index + 1)
		renderer.mesh = batch.multimesh.mesh
		renderer.material_override = batch.material_override
		renderer.transform = authored[index] as Transform3D
		renderer.cast_shadow = batch.cast_shadow
		renderer.layers = batch.layers
		baseline.add_child(renderer)

	_camera = Camera3D.new()
	_camera.name = "HabitatMessTrestleCaptureCamera"
	_camera.position = CAMERA_POSITION
	_camera.near = 0.06
	_camera.far = 80.0
	_camera.fov = 38.0
	stage.add_child(_camera)
	_camera.look_at(CAMERA_TARGET, Vector3.UP)
	_camera.current = true
	_check(
		_camera.position.distance_to(CAMERA_TARGET) > 5.5
			and _camera.position.distance_to(CAMERA_TARGET) < 6.0,
		"fixed common-room camera remains at gameplay review distance"
	)

	batch.visible = false
	baseline.visible = true
	var before := await _capture(BEFORE_PATH)
	baseline.visible = false
	batch.visible = true
	var after := await _capture(AFTER_PATH)
	_check(
		before != null and after != null and before.get_data() == after.get_data(),
		"individual and batched trestle-foot frames are pixel-identical"
	)
	if before != null and after != null:
		var region := _foot_region()
		var before_region := before.get_region(region)
		var after_region := after.get_region(region)
		_check(
			before_region.get_data() == after_region.get_data()
				and _region_has_visible_detail(before_region),
			"bounded mess-table foot region remains visible and pixel-identical"
		)

	stage.queue_free()
	await process_frame
	_finish()


func _capture(path: String) -> Image:
	for _frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == RESOLUTION,
		"capture returns a stable 1600x900 renderer frame"
	)
	if image == null or image.is_empty():
		return null
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	_check(image.save_png(absolute) == OK, "capture frame saves successfully")
	print("HABITAT_MESS_TRESTLE_CAPTURE: ", absolute)
	return image


func _foot_region() -> Rect2i:
	var centers := [
		_camera.unproject_position(Vector3(5.55, 0.035, 22.45)),
		_camera.unproject_position(Vector3(5.55, 0.035, 24.15)),
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for center in centers:
		minimum = minimum.min(center - Vector2(55.0, 44.0))
		maximum = maximum.max(center + Vector2(55.0, 44.0))
	var top_left := Vector2i(minimum.floor())
	var bottom_right := Vector2i(maximum.ceil())
	top_left.x = clampi(top_left.x, 0, RESOLUTION.x - 1)
	top_left.y = clampi(top_left.y, 0, RESOLUTION.y - 1)
	bottom_right.x = clampi(bottom_right.x, top_left.x + 1, RESOLUTION.x)
	bottom_right.y = clampi(bottom_right.y, top_left.y + 1, RESOLUTION.y)
	return Rect2i(top_left, bottom_right - top_left)


func _region_has_visible_detail(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var pixel := image.get_pixel(x, y)
			minimum = minimum.min(Vector3(pixel.r, pixel.g, pixel.b))
			maximum = maximum.max(Vector3(pixel.r, pixel.g, pixel.b))
	return (maximum - minimum).length() > 0.10


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061019")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7894a5")
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = false
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-47.0, -36.0, 0.0)
	key.light_color = Color("ffe1bb")
	key.light_energy = 1.55
	key.shadow_enabled = true
	stage.add_child(key)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HABITAT_MESS_TRESTLE_CAPTURE_OK")
		quit(0)
		return
	print("HABITAT_MESS_TRESTLE_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
