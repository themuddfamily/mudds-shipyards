extends SceneTree

## One HUD-free Forward+ gameplay-distance witness for the Halyard's four
## batched landing pads. The craft is staged on a solid review deck at the
## production LandingGearCollision contact plane; the harness checks exact
## renderer, material, shadow, culling and collision alignment before capture.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const OUTPUT_PATH := "res://artifacts/halyard_landing_gear_foot_batch/gameplay_distance.png"
const CAPTURE_RESOLUTION := Vector2i(1600, 900)
const DECK_THICKNESS := 0.30

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
		"capture has a live Forward+ rendering device"
	)

	var world := Node3D.new()
	world.name = "HalyardLandingGearFootReviewWorld"
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

	var visual := craft.get_halyard_visual_root()
	var batch := visual.get_node_or_null(^"LandingGearFootBatch") as MultiMeshInstance3D \
		if visual != null else null
	var multi := batch.multimesh if batch != null else null
	var material := batch.material_override as StandardMaterial3D if batch != null else null
	var transforms := batch.get_meta("authored_instance_transforms", []) as Array \
		if batch != null else []
	_check(
		batch != null and multi != null and transforms.size() == 4
			and multi.instance_count == HalyardCrewTransport.LANDING_GEAR_FOOT_COPY_COUNT
			and multi.visible_instance_count == -1,
		"all four authored landing pads resolve through one visible batch"
	)
	_check(
		batch != null and material != null
			and material == craft.get_variant_materials().get("structure")
			and not material.albedo_color.is_equal_approx(Color.BLACK)
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and batch.visibility_range_begin == 0.0
			and batch.visibility_range_end == 0.0
			and multi.custom_aabb.size.x > 5.0
			and multi.custom_aabb.size.z > 11.0,
		"the structural material, shadows and unranged four-pad culling bounds remain intact"
	)

	var gear_collision := craft.get_node_or_null(^"LandingGearCollision") as CollisionShape3D
	var gear_shape := gear_collision.shape as BoxShape3D if gear_collision != null else null
	var contact_y := _landing_contact_y(gear_collision, gear_shape)
	_check(
		gear_collision != null and gear_shape != null and not gear_collision.disabled
			and gear_shape.size.is_equal_approx(Vector3(5.0, 0.70, 12.0))
			and is_equal_approx(contact_y, -1.08)
			and _pad_centres_align_with_collision(transforms, gear_collision, gear_shape),
		"the retained landing-gear collider contains every pad centre on the shared contact plane"
	)
	var deck := _build_deck(world, contact_y)
	_check(
		deck != null and is_equal_approx(
			deck.position.y + DECK_THICKNESS * 0.5,
			contact_y
		),
		"the solid review deck meets the production gear contact plane"
	)

	var camera := Camera3D.new()
	camera.name = "HalyardLandingGearFootBatchCaptureCamera"
	camera.near = 0.06
	camera.far = 300.0
	camera.fov = 48.0
	# Low diagonal on-foot height keeps both port and starboard pairs separated
	# beneath the hull instead of letting its belly hide the far-side pads.
	camera.position = Vector3(-14.0, 0.35, -20.5)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, -0.62, 0.0), Vector3.UP)
	camera.current = true

	for _frame in 18:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_RESOLUTION,
		"gameplay-distance landing-gear frame renders at the requested resolution"
	)
	if image != null and not image.is_empty():
		var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		_check(image.save_png(absolute) == OK, "capture saves successfully")
		print("HALYARD_LANDING_GEAR_FOOT_BATCH_CAPTURE: ", absolute)

	world.queue_free()
	await process_frame
	_finish()


func _build_environment(world: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07111a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7793a4")
	environment.ambient_light_energy = 0.46
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = false
	world_environment.environment = environment
	world.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-44.0, -34.0, 0.0)
	key.light_color = Color("ffe1bd")
	key.light_energy = 2.15
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(18.0, 144.0, 0.0)
	fill.light_color = Color("69a9c6")
	fill.light_energy = 0.72
	world.add_child(fill)


func _build_deck(world: Node3D, contact_y: float) -> MeshInstance3D:
	var deck := MeshInstance3D.new()
	deck.name = "LandingContactReviewDeck"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(18.0, DECK_THICKNESS, 32.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("24333b")
	material.metallic = 0.42
	material.roughness = 0.64
	mesh.material = material
	deck.mesh = mesh
	deck.position.y = contact_y - DECK_THICKNESS * 0.5
	world.add_child(deck)
	return deck


func _landing_contact_y(collider: CollisionShape3D, shape: BoxShape3D) -> float:
	if collider == null or shape == null:
		return NAN
	return collider.position.y - shape.size.y * 0.5


func _pad_centres_align_with_collision(
		transforms: Array,
		collider: CollisionShape3D,
		shape: BoxShape3D
	) -> bool:
	if transforms.size() != 4 or collider == null or shape == null:
		return false
	var half := shape.size * 0.5
	for raw_transform in transforms:
		var pad_transform := raw_transform as Transform3D
		var centre := pad_transform.origin
		if absf(centre.x - collider.position.x) > half.x \
				or absf(centre.z - collider.position.z) > half.z \
				or not is_equal_approx(
					centre.y - HalyardCrewTransport.LANDING_GEAR_FOOT_SIZE.y * 0.5,
					_landing_contact_y(collider, shape)
				):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HALYARD_LANDING_GEAR_FOOT_BATCH_CAPTURE_OK")
		quit(0)
		return
	print("HALYARD_LANDING_GEAR_FOOT_BATCH_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
