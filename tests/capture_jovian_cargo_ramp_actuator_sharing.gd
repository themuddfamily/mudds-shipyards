extends SceneTree

## Stable HUD-free Forward+ comparison frame of the production Jovian's open
## port ramp. The two actuator leaves, their shadows, the boarding threshold and
## surrounding hull all remain in view. Pass `-- baseline` or `-- optimized` to
## write comparable frames without changing camera or environment state.

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const CAPTURE_RESOLUTION := Vector2i(1600, 900)
const OUTPUT_ROOT := "/tmp/mudds-wave32-jovian-ramp-actuator-"

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_2X
	root.use_taa = false
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture uses a live Forward+ rendering device",
	)

	var stage := Node3D.new()
	stage.name = &"JovianRampActuatorCapture"
	root.add_child(stage)
	_build_environment(stage)
	_build_deck(stage)

	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	_check(jovian != null, "production Jovian scene instantiates")
	if jovian == null:
		await _finish(stage, "invalid")
		return
	stage.add_child(jovian)
	await process_frame
	await physics_frame

	var actuators: Array[MeshInstance3D] = []
	var ramp := jovian.find_child("PortCargoRamp", true, false) as MeshInstance3D
	var visual_root: Node = ramp.get_parent() if ramp != null else null
	if visual_root != null:
		for candidate in visual_root.get_children():
			var actuator := candidate as MeshInstance3D
			if actuator != null and _is_actuator_transform(actuator.transform):
				actuators.append(actuator)
	_check(actuators.size() == 2, "both production cargo-ramp actuator leaves are present")
	var camera := Camera3D.new()
	camera.name = &"RampActuatorGameplayDistanceCamera"
	camera.position = Vector3(-15.8, 2.75, 10.8)
	camera.near = 0.08
	camera.far = 180.0
	camera.fov = 42.0
	stage.add_child(camera)
	camera.look_at(Vector3(-5.8, 0.4, 3.15), Vector3.UP)
	camera.current = true
	await process_frame
	var all_centres_in_frame := actuators.size() == 2
	for actuator_variant in actuators:
		var actuator := actuator_variant as MeshInstance3D
		all_centres_in_frame = all_centres_in_frame \
			and camera.is_position_in_frustum(actuator.global_position)
	_check(all_centres_in_frame, "gameplay-distance camera frames both actuator centres")

	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_RESOLUTION,
		"Forward+ frame renders at the requested gameplay-review resolution",
	)
	var label := _capture_label()
	var output_path := OUTPUT_ROOT + label + ".png"
	if image != null and not image.is_empty():
		_check(image.save_png(output_path) == OK, "comparison capture saves successfully")
		print("JOVIAN_CARGO_RAMP_ACTUATOR_CAPTURE: ", output_path)

	await _finish(stage, label)


func _capture_label() -> String:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0] in ["baseline", "optimized"]:
		return args[0]
	return "review"


func _is_actuator_transform(transform: Transform3D) -> bool:
	var expected_basis := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(20.0)))
	return transform.basis.is_equal_approx(expected_basis) \
		and (
			transform.origin.is_equal_approx(Vector3(-6.1, 0.12, 1.3))
			or transform.origin.is_equal_approx(Vector3(-6.1, 0.12, 5.1))
		)


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061019")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("829eaa")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 1.35
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -42.0, 0.0)
	key.light_color = Color("ffe5bd")
	key.light_energy = 2.1
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 80.0
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-16.0, 142.0, 0.0)
	fill.light_color = Color("5fbcdb")
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	stage.add_child(fill)


func _build_deck(stage: Node3D) -> void:
	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(52.0, 0.4, 48.0)
	var deck_material := StandardMaterial3D.new()
	deck_material.albedo_color = Color("24343c")
	deck_material.metallic = 0.58
	deck_material.roughness = 0.43
	deck_mesh.material = deck_material
	deck.mesh = deck_mesh
	deck.position.y = -1.45
	stage.add_child(deck)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish(stage: Node3D, label: String) -> void:
	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("JOVIAN_CARGO_RAMP_ACTUATOR_CAPTURE_OK: ", label)
		quit(0)
		return
	printerr("JOVIAN_CARGO_RAMP_ACTUATOR_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
