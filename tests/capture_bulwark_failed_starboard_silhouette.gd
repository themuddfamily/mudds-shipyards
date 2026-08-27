extends SceneTree

## Native Forward+ normal-chase comparison of the production Bulwark's retained
## nominal and failed starboard-weapon shoulder silhouettes.

const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")
const RESOLUTION := Vector2i(1280, 720)
const PANEL_SIZE := Vector2i(640, 720)
const OUTPUT_PATH := "res://artifacts/bulwark_failed_starboard_silhouette/forward_plus_chase_comparison.png"

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_4X
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and DisplayServer.get_name() == "X11",
		"capture uses native X11 Forward+"
	)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	root.add_child(row)
	var nominal := await _build_panel(row, false)
	var failed := await _build_panel(row, true)
	_add_label("NOMINAL // UPRIGHT SHOULDER VANE", Vector2(24.0, 22.0))
	_add_label("FAILED // OUTBOARD-CANTED VANE", Vector2(664.0, 22.0))
	for _frame in 16:
		await process_frame
	_check(
		nominal.get_component_damage_cue_snapshot().get("stage", &"") == &"nominal"
			and failed.get_component_damage_cue_snapshot().get("stage", &"") == &"failed"
			and failed.get_component_damage_cue_snapshot().get("silhouette_pose", &"") \
				== &"failed_outboard_canted",
		"production panels retain nominal and failed starboard-shoulder poses"
	)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == RESOLUTION,
		"capture returns one stable comparison frame"
	)
	if image != null and not image.is_empty():
		var output := ProjectSettings.globalize_path(OUTPUT_PATH)
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		_check(image.save_png(output) == OK, "Forward+ comparison saves successfully")
		print("BULWARK_FAILED_STARBOARD_SILHOUETTE_CAPTURE: ", output)
	row.queue_free()
	await process_frame
	_finish()


func _build_panel(row: HBoxContainer, is_failed: bool) -> BulwarkHeavyGunship:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = PANEL_SIZE
	container.stretch = true
	row.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = PANEL_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	_install_environment(stage)
	var craft := BULWARK_SCENE.instantiate() as BulwarkHeavyGunship
	stage.add_child(craft)
	await process_frame
	await physics_frame
	craft.set("_landed", false)
	if is_failed:
		var cue := craft.get_node(^"BulwarkHeavyGunshipVisual/StarboardWeaponShoulderDamageCue") as Node3D
		var scorch := cue.get_node(^"ShoulderBreachScorch") as MeshInstance3D
		var surface_hit := scorch.to_global(
			Vector3(0.0, BulwarkHeavyGunship.DAMAGE_SCORCH_SIZE.y * 0.5, 0.0)
		)
		craft.apply_damage(craft.maximum_hull * 0.15, surface_hit, Vector3.UP)
		craft.apply_damage(craft.maximum_hull * 0.10, surface_hit, Vector3.UP)
		await process_frame
	var camera := Camera3D.new()
	camera.position = Vector3(10.0, 5.6, 24.0)
	camera.fov = 48.0
	camera.near = 0.05
	camera.far = 80.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 1.35, 0.55), Vector3.UP)
	camera.current = true
	return craft


func _install_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050910")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8298ad")
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	for rotation in [Vector3(-32.0, -34.0, 0.0), Vector3(20.0, 150.0, 0.0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = rotation
		light.light_energy = 1.6
		stage.add_child(light)


func _add_label(value: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = value
	label.position = position
	label.add_theme_color_override("font_color", Color("dbe9ee"))
	label.add_theme_color_override("font_shadow_color", Color("020609"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 18)
	root.add_child(label)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("BULWARK_FAILED_STARBOARD_SILHOUETTE_CAPTURE_OK")
		quit(0)
		return
	print("BULWARK_FAILED_STARBOARD_SILHOUETTE_CAPTURE_FAILED: %s" % "; ".join(_failures))
	quit(1)
