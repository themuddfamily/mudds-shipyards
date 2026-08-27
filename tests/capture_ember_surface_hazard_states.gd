extends SceneTree

## Focused Forward+ comparison at an on-foot viewing distance. Both frames use
## the same static production nodes: reduced-flash mode therefore retains every
## shape cue without introducing an alternate animated presentation.

const Presentation := preload("res://scripts/world/ember_surface_hazard_zone_presentation.gd")
const OUTPUT_DIR := "/tmp/mudds-wave32-ember-hazard/artifacts/ember_hazard_states"

var _viewport: SubViewport


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1600, 900)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(_viewport)

	var world := Node3D.new()
	_viewport.add_child(world)
	_add_environment(world)
	_add_ground(world)
	_add_hazard(world, Vector3(-5.0, 0.0, 0.0), &"clear", "SAFE / CLEAR")
	_add_hazard(world, Vector3.ZERO, &"warning", "WARNING")
	_add_hazard(world, Vector3(5.0, 0.0, 0.0), &"recovery_required", "RECOVERY")

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.0, 4.8, 11.8)
	camera.fov = 58.0
	camera.look_at(Vector3(0.0, 0.9, -0.6), Vector3.UP)
	camera.current = true

	var reduced_flash := "--reduced-flash" in OS.get_cmdline_user_args()
	var profile_label := Label.new()
	profile_label.position = Vector2(36.0, 28.0)
	profile_label.add_theme_font_size_override("font_size", 28)
	profile_label.add_theme_color_override("font_color", Color("e8f4ff"))
	profile_label.text = "EMBER HAZARD STATES  //  %s" % (
		"REDUCED FLASH (STATIC)" if reduced_flash else "STANDARD"
	)
	_viewport.add_child(profile_label)
	await _frames(8)
	_capture("reduced_flash.png" if reduced_flash else "standard.png")
	print("EMBER_HAZARD_STATE_CAPTURE_OK: ", OUTPUT_DIR)
	quit(0)


func _add_environment(world: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080b10")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("627182")
	environment.ambient_light_energy = 0.36
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.32
	world_environment.environment = environment
	world.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key.light_color = Color("ffd1aa")
	key.light_energy = 1.4
	key.shadow_enabled = true
	world.add_child(key)


func _add_ground(world: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(18.0, 12.0)
	ground.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("202833")
	material.metallic = 0.35
	material.roughness = 0.72
	ground.material_override = material
	world.add_child(ground)


func _add_hazard(world: Node3D, anchor: Vector3, state: StringName, label_text: String) -> void:
	var hazard := Presentation.new()
	world.add_child(hazard)
	hazard.configure({
		"id": StringName("hazard_" + String(state)),
		"display_name": label_text,
		"position_body_local_m": anchor,
	}, 1.7)
	hazard.configure_recovery_target({
		"id": StringName("target_" + String(state)),
		"position_body_local_m": anchor + Vector3(0.0, 0.0, -5.3),
	})
	if state != &"clear":
		var status := {"hazard_id": StringName("hazard_" + String(state)), "state": state}
		if state == &"recovery_required":
			status["recovery_request"] = {"generation": 1}
		hazard.apply_status(status)
	var label := Label3D.new()
	label.text = label_text
	label.position = anchor + Vector3(0.0, 3.9, 0.0)
	label.font_size = 32
	label.outline_size = 8
	label.modulate = Color("d9e8f4")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world.add_child(label)


func _capture(file_name: String) -> void:
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("capture produced no image: " + file_name)
		quit(1)
		return
	var output_path := OUTPUT_DIR.path_join(file_name)
	var error := image.save_png(output_path)
	if error != OK:
		push_error("capture save failed: " + output_path)
		quit(1)
		return
	print("CAPTURED: ", output_path)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame
