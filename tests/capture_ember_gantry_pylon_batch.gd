extends SceneTree

## One HUD-free Forward+ gameplay-distance frame of the Ember derelict gantry.
## The harness verifies the pylon batch and surviving collision alignment before
## capturing both pylons, the surrounding gantry, and the nearby sample rack.

const EMBER_SCENE := preload("res://scenes/world/planets/ember_moon.tscn")
const OUTPUT_PATH := "res://artifacts/ember_gantry_pylon_batch/gameplay_distance.png"
const CAPTURE_RESOLUTION := Vector2i(1600, 900)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a live Forward+ rendering device",
	)

	var world := Node3D.new()
	root.add_child(world)
	var ember := EMBER_SCENE.instantiate() as EmberMoonAuthoredScene
	_check(ember != null, "authored Ember surface instantiates")
	if ember == null:
		_finish()
		return
	world.add_child(ember)
	await process_frame

	var gantry := ember.get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry"
	) as StaticBody3D
	var pylons := gantry.get_node_or_null(^"GantryPylonVisuals") as MultiMeshInstance3D \
		if gantry != null else null
	var multi := pylons.multimesh if pylons != null else null
	var transforms: Array = pylons.get_meta("authored_transforms", []) as Array \
		if pylons != null else []
	var pylon_material := pylons.material_override as StandardMaterial3D \
		if pylons != null else null
	_check(
		gantry != null and pylons != null and multi != null
			and multi.instance_count == 2
			and multi.custom_aabb.is_equal_approx(AABB(
				Vector3(-0.6, -0.05, -6.2), Vector3(1.2, 7.3, 12.4)
			))
			and transforms.size() == 2
			and (transforms[0] as Transform3D).origin == Vector3(0.0, 3.6, -5.2)
			and (transforms[1] as Transform3D).origin == Vector3(0.0, 3.6, 5.2)
			and pylon_material != null
			and not pylon_material.albedo_color.is_equal_approx(Color.BLACK)
			and pylons.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and pylons.visibility_range_begin == 0.0
			and pylons.visibility_range_end == 0.0,
		"both pylon transforms, structural material, and non-ranged culling contract are intact",
	)
	_check(
		gantry != null
			and gantry.get_node_or_null(^"PortPylonVisual") == null
			and gantry.get_node_or_null(^"StarboardPylonVisual") == null
			and _collision_matches(
				gantry.get_node_or_null(^"PortPylonCollision") as CollisionShape3D,
				transforms[0] as Transform3D if transforms.size() == 2 else Transform3D.IDENTITY,
			)
			and _collision_matches(
				gantry.get_node_or_null(^"StarboardPylonCollision") as CollisionShape3D,
				transforms[1] as Transform3D if transforms.size() == 2 else Transform3D.IDENTITY,
			),
		"source renderers are retired while both exact solid pylon collisions remain aligned",
	)
	var rack_vane := ember.get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/SampleRack/IdentityVaneVisuals"
	) as MultiMeshInstance3D
	_check(
		rack_vane != null and rack_vane.multimesh != null
			and rack_vane.multimesh.instance_count == 9
			and rack_vane.visible,
		"the excluded sample-rack identity vane remains intact",
	)

	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("08090d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("596472")
	settings.ambient_light_energy = 0.4
	settings.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.environment = settings
	world.add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffd1a6")
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.rotation = Vector3(-0.78, -0.62, 0.0)
	world.add_child(sun)

	var camera := Camera3D.new()
	camera.name = &"EmberGantryPylonBatchCaptureCamera"
	camera.position = Vector3(9.0, 120_006.5, -25.0)
	camera.near = 0.06
	camera.far = 500.0
	camera.fov = 59.0
	world.add_child(camera)
	camera.look_at(Vector3(32.0, 120_005.0, 0.0), Vector3.UP)
	camera.current = true

	for _frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_RESOLUTION,
		"gameplay-distance Ember gantry frame renders at the requested resolution",
	)
	if image != null and not image.is_empty():
		var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		_check(image.save_png(absolute) == OK, "capture saves successfully")
		print("EMBER_GANTRY_PYLON_BATCH_CAPTURE: ", absolute)

	world.queue_free()
	await process_frame
	_finish()


func _collision_matches(collider: CollisionShape3D, visual_transform: Transform3D) -> bool:
	var shape := collider.shape as BoxShape3D if collider != null else null
	return collider != null and shape != null \
		and shape.size == Vector3(1.2, 7.2, 1.4) \
		and collider.transform.is_equal_approx(visual_transform) \
		and not collider.disabled


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_GANTRY_PYLON_BATCH_CAPTURE_OK")
		quit(0)
		return
	print("EMBER_GANTRY_PYLON_BATCH_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
