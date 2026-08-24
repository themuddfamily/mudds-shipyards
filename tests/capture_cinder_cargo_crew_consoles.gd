extends SceneTree

## One HUD-free Forward+ gameplay-distance witness for the Cinder hauler's
## paired crew-console batch. The complete production craft supplies both
## consoles, seats, cabin, station metadata, materials and shadows; this
## harness adds only neutral review lighting and a camera.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const OUTPUT_PATH := "res://artifacts/cinder_cargo_crew_consoles/gameplay_distance_forward_plus.png"
const CAPTURE_RESOLUTION := Vector2i(1600, 900)
const EXPECTED_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(0.95, 0.20, 0.42)),
	Transform3D(Basis.IDENTITY, Vector3(-0.95, 0.20, 0.42)),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_2X
	root.use_taa = true
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a live Forward+ rendering device"
	)

	var stage := Node3D.new()
	stage.name = "CinderCrewConsoleCaptureStage"
	root.add_child(stage)
	_build_environment(stage)

	var craft := Hauler.new() as CinderCargoHauler
	stage.add_child(craft)
	await process_frame
	await physics_frame
	craft.set_process(false)
	craft.set_physics_process(false)
	var exterior := craft.get_variant_visual_root()
	if exterior != null:
		exterior.visible = false

	var cabin := craft.get_node_or_null(^"WalkableInterior/LoadmasterCabin") as Node3D
	var batch := cabin.get_node_or_null(^"CrewConsoleBatch") as MultiMeshInstance3D \
		if cabin != null else null
	var multi := batch.multimesh if batch != null else null
	var mesh := multi.mesh as BoxMesh if multi != null else null
	_check(
		batch != null
			and multi != null
			and multi.instance_count == 2
			and multi.visible_instance_count == -1
			and mesh != null
			and mesh.size.is_equal_approx(Vector3(0.92, 0.58, 0.08))
			and batch.visible
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"both production console copies use one visible shadow-casting renderer"
	)
	_check(
		batch != null
			and batch.get_meta(&"authored_visual_names", PackedStringArray())
				== PackedStringArray(["LoadmasterConsole", "NavigatorConsole"])
			and batch.get_meta(&"authored_station_ids", PackedStringArray())
				== PackedStringArray([
					Hauler.LOADMASTER_STATION_SEAT_ID,
					Hauler.NAVIGATOR_STATION_SEAT_ID,
				])
			and batch.get_meta(&"authored_instance_transforms", []) == EXPECTED_TRANSFORMS,
		"left and right copies retain distinct loadmaster and navigator identities"
	)
	var material := batch.material_override as StandardMaterial3D if batch != null else null
	_check(
		multi != null
			and not multi.use_colors
			and not multi.use_custom_data
			and multi.get_instance_transform(0).is_equal_approx(EXPECTED_TRANSFORMS[0])
			and multi.get_instance_transform(1).is_equal_approx(EXPECTED_TRANSFORMS[1])
			and material != null
			and material.albedo_color.is_equal_approx(Hauler.ACCENT_COLOR)
			and is_equal_approx(material.metallic, 0.42)
			and is_equal_approx(material.roughness, 0.62),
		"instances retain independent transforms while sharing one immutable paint recipe"
	)
	_check(
		multi != null
			and mesh != null
			and multi.custom_aabb.has_point(EXPECTED_TRANSFORMS[0].origin + mesh.size * 0.5)
			and multi.custom_aabb.has_point(EXPECTED_TRANSFORMS[0].origin - mesh.size * 0.5)
			and multi.custom_aabb.has_point(EXPECTED_TRANSFORMS[1].origin + mesh.size * 0.5)
			and multi.custom_aabb.has_point(EXPECTED_TRANSFORMS[1].origin - mesh.size * 0.5)
			and is_zero_approx(batch.visibility_range_begin)
			and is_zero_approx(batch.visibility_range_end)
			and is_zero_approx(batch.extra_cull_margin),
		"one exact batch bound contains both copies without per-copy culling leakage"
	)
	_check(
		craft.get_loadmaster_station_anchor() != null
			and craft.get_navigator_station_anchor() != null
			and craft.get_cargo_transfer_anchors().size() == Hauler.CARGO_CAPACITY
			and bool(craft.get_landing_collision_report().get("valid", false)),
		"the rendered cabin retains both physical stations, cargo anchors and landing collision"
	)

	var camera := Camera3D.new()
	camera.name = "CinderCrewConsoleCaptureCamera"
	camera.fov = 48.0
	camera.near = 0.05
	camera.far = 40.0
	camera.position = Vector3(0.0, 0.72, -1.72)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.15, 0.58), Vector3.UP)
	camera.current = true
	for _frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw

	var loadmaster_screen := camera.unproject_position(EXPECTED_TRANSFORMS[0].origin)
	var navigator_screen := camera.unproject_position(EXPECTED_TRANSFORMS[1].origin)
	var loadmaster_size := _projected_face_size(camera, EXPECTED_TRANSFORMS[0], mesh.size) \
		if mesh != null else Vector2.ZERO
	var navigator_size := _projected_face_size(camera, EXPECTED_TRANSFORMS[1], mesh.size) \
		if mesh != null else Vector2.ZERO
	_check(
		camera.is_position_in_frustum(EXPECTED_TRANSFORMS[0].origin)
			and camera.is_position_in_frustum(EXPECTED_TRANSFORMS[1].origin)
			and loadmaster_screen.x > 0.0 and loadmaster_screen.x < CAPTURE_RESOLUTION.x
			and navigator_screen.x > 0.0 and navigator_screen.x < CAPTURE_RESOLUTION.x
			and loadmaster_screen.distance_to(navigator_screen) >= 250.0
			and loadmaster_size.x >= 200.0 and loadmaster_size.y >= 100.0
			and navigator_size.x >= 200.0 and navigator_size.y >= 100.0,
		"both station copies resolve separately at the gameplay-distance review camera"
	)
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_RESOLUTION,
		"Forward+ returns the requested non-empty cabin frame"
	)
	if image != null and not image.is_empty():
		var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		_check(image.save_png(absolute) == OK, "capture saves successfully")
		print("CINDER_CARGO_CREW_CONSOLE_CAPTURE: ", absolute)

	craft.queue_free()
	await process_frame
	_finish()


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7ea6b0")
	environment.ambient_light_energy = 0.36
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.5
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.name = "CabinReviewKey"
	key.rotation_degrees = Vector3(-38.0, -24.0, 0.0)
	key.light_color = Color("ffe3bf")
	key.light_energy = 1.55
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.name = "CabinReviewFill"
	fill.position = Vector3(-0.8, 1.0, 1.8)
	fill.light_color = Color("62d7df")
	fill.light_energy = 0.8
	fill.omni_range = 8.0
	fill.shadow_enabled = false
	stage.add_child(fill)


func _projected_face_size(
		camera: Camera3D,
		transform: Transform3D,
		size: Vector3
	) -> Vector2:
	var half := size * 0.5
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for offset in [
		Vector3(-half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, -half.z),
		Vector3(-half.x, half.y, -half.z),
		Vector3(half.x, half.y, -half.z),
	]:
		var screen := camera.unproject_position(transform * offset)
		minimum = minimum.min(screen)
		maximum = maximum.max(screen)
	return maximum - minimum


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_CARGO_CREW_CONSOLE_CAPTURE_OK")
		quit(0)
		return
	print("CINDER_CARGO_CREW_CONSOLE_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
