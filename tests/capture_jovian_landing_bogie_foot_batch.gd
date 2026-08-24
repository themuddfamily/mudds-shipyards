extends SceneTree

## One HUD-free Forward+ gameplay-distance review of the production Jovian's
## landing-bogie feet. The frame includes the deployed port ramp and surrounding
## deck so all four retained copies, their contact shadows, and boarding-side
## clearance can be reviewed without centring the forward cargo-guide silhouette.

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const CAPTURE_RESOLUTION := Vector2i(1600, 900)
const OUTPUT_PATH := "/tmp/mudds-wave31-jovian-landing-bogie-foot-batch.png"
const PARKED_CONTACT_Y := -1.25
const BOARDING_RAMP_BOUNDS := AABB(
	Vector3(-10.45, -1.25, 1.5), Vector3(4.725, 1.75, 3.4)
)

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
		"capture uses a live Forward+ rendering device",
	)

	var stage := Node3D.new()
	stage.name = &"JovianLandingBogieFootBatchCapture"
	root.add_child(stage)
	_build_environment(stage)
	_build_deck(stage)

	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	_check(jovian != null, "production Jovian scene instantiates")
	if jovian == null:
		await _finish(stage)
		return
	stage.add_child(jovian)
	await process_frame
	await physics_frame

	var visual := jovian.get_jovian_visual_root()
	var batch := visual.get_node_or_null(^"LandingBogieFootBatch") \
		as MultiMeshInstance3D if visual != null else null
	var multi := batch.multimesh if batch != null else null
	var transforms := batch.get_meta("authored_instance_transforms", []) as Array \
		if batch != null else []
	var foot_mesh_bounds := multi.mesh.get_aabb() \
		if multi != null and multi.mesh != null else AABB()
	var all_contact_aligned := transforms.size() \
		== JovianLightFreighter.LANDING_BOGIE_FOOT_COPY_COUNT
	var boarding_route_clear := all_contact_aligned
	for transform_variant in transforms:
		var transform := transform_variant as Transform3D
		var copy_bounds := transform * foot_mesh_bounds
		all_contact_aligned = all_contact_aligned \
			and absf(copy_bounds.position.y - PARKED_CONTACT_Y) <= 0.025
		boarding_route_clear = boarding_route_clear \
			and not copy_bounds.intersects(BOARDING_RAMP_BOUNDS)
	_check(
		batch != null and multi != null
			and batch.visible
			and multi.instance_count == JovianLightFreighter.LANDING_BOGIE_FOOT_COPY_COUNT
			and multi.visible_instance_count == -1
			and multi.mesh.get_aabb().size.is_equal_approx(
				JovianLightFreighter.LANDING_BOGIE_FOOT_SIZE
			)
			and multi.mesh.surface_get_material(0) == jovian.get("_jovian_materials").structure
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and is_zero_approx(batch.visibility_range_begin)
			and is_zero_approx(batch.visibility_range_end),
		"all four landing feet retain their structure material, shadows and non-ranged culling",
	)
	_check(all_contact_aligned, "all four foot bottoms align within 2.5 cm of the parked deck plane")
	_check(boarding_route_clear, "all four foot bounds remain clear of the deployed boarding ramp volume")
	var access := jovian.get_interior_access_marker()
	_check(
		access != null and access.position.is_equal_approx(Vector3(-10.05, -1.08, 3.2)),
		"production port-ramp boarding marker remains unchanged",
	)

	var camera := Camera3D.new()
	camera.name = &"LandingBogieGameplayDistanceCamera"
	camera.position = Vector3(-20.5, 2.6, 20.5)
	camera.near = 0.08
	camera.far = 180.0
	camera.fov = 48.0
	stage.add_child(camera)
	camera.look_at(Vector3(-0.2, -0.35, 0.5), Vector3.UP)
	camera.current = true
	await process_frame
	var all_centres_in_frame := transforms.size() \
		== JovianLightFreighter.LANDING_BOGIE_FOOT_COPY_COUNT
	for transform_variant in transforms:
		var foot_transform := transform_variant as Transform3D
		all_centres_in_frame = all_centres_in_frame and camera.is_position_in_frustum(
			jovian.to_global(foot_transform.origin)
		)
	_check(all_centres_in_frame, "the gameplay-distance evidence camera frames all four foot centres")

	for _frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_RESOLUTION,
		"Forward+ frame renders at the requested gameplay-review resolution",
	)
	if image != null and not image.is_empty():
		_check(image.save_png(OUTPUT_PATH) == OK, "landing-bogie review capture saves successfully")
		print("JOVIAN_LANDING_BOGIE_FOOT_BATCH_CAPTURE: ", OUTPUT_PATH)

	await _finish(stage)


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061019")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("829eaa")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 1.45
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-54.0, -36.0, 0.0)
	key.light_color = Color("ffe5bd")
	key.light_energy = 2.15
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 80.0
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 146.0, 0.0)
	fill.light_color = Color("5fbcdb")
	fill.light_energy = 0.48
	fill.shadow_enabled = false
	stage.add_child(fill)


func _build_deck(stage: Node3D) -> void:
	var deck := MeshInstance3D.new()
	deck.name = &"ParkedContactDeck"
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(52.0, 0.4, 48.0)
	var deck_material := StandardMaterial3D.new()
	deck_material.albedo_color = Color("24343c")
	deck_material.metallic = 0.58
	deck_material.roughness = 0.43
	deck_mesh.material = deck_material
	deck.mesh = deck_mesh
	deck.position.y = PARKED_CONTACT_Y - 0.2
	stage.add_child(deck)
	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color("51b6b5")
	line_material.emission_enabled = true
	line_material.emission = Color("1d5558")
	line_material.emission_energy_multiplier = 0.65
	for z_position in [-10.0, 0.0, 10.0]:
		var line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(28.0, 0.025, 0.08)
		line_mesh.material = line_material
		line.mesh = line_mesh
		line.position = Vector3(0.0, PARKED_CONTACT_Y + 0.015, z_position)
		stage.add_child(line)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish(stage: Node3D) -> void:
	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("JOVIAN_LANDING_BOGIE_FOOT_BATCH_CAPTURE_OK")
		quit(0)
		return
	print("JOVIAN_LANDING_BOGIE_FOOT_BATCH_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
