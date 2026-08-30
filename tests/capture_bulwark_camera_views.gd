extends SceneTree

## Focused production-camera review for the Bulwark. The three panels use the
## ship's own chase/cockpit cameras; no review-only camera substitutes for them.

const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")
const RESOLUTION := Vector2i(1920, 720)
const PANEL_SIZE := Vector2i(640, 720)
const OUTPUT_PATH := "/tmp/bulwark_camera_views.png"

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = RESOLUTION
	root.msaa_3d = Viewport.MSAA_4X
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	root.add_child(row)
	await _add_panel(row, &"CHASE // 14 M", false, 14.0)
	await _add_panel(row, &"CHASE // 32 M", false, 32.0)
	await _add_panel(row, &"COCKPIT // CLOSED", true, 14.0)
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "production-camera frame renders")
	if image != null and not image.is_empty():
		_check(image.save_png(OUTPUT_PATH) == OK, "production-camera frame saves")
		print("BULWARK_CAMERA_VIEWS_CAPTURE: ", OUTPUT_PATH)
	_finish()


func _add_panel(row: HBoxContainer, label_text: StringName, cockpit: bool, distance: float) -> void:
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
	var ship := BULWARK_SCENE.instantiate() as BulwarkHeavyGunship
	stage.add_child(ship)
	await process_frame
	await physics_frame
	ship.set(&"_landed", false)
	ship.set_piloted(true)
	ship.set_chase_camera_distance(distance)
	ship.set_cockpit_view(cockpit)
	for _frame in 12:
		await physics_frame
	var camera := ship.get_camera()
	_check(
		camera != null and camera.current
			and ((camera.name == &"CockpitCamera") == cockpit),
		"%s uses the production %s camera" % [label_text, "cockpit" if cockpit else "chase"]
	)
	if cockpit:
		_check_cockpit_clearance(ship)
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(18.0, 18.0)
	label.add_theme_color_override("font_color", Color("e8f3f5"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 20)
	container.add_child(label)


func _check_cockpit_clearance(ship: BulwarkHeavyGunship) -> void:
	var visual := ship.get_node(^"BulwarkHeavyGunshipVisual") as Node3D
	var cockpit := visual.get_node(^"CockpitInterior") as Node3D
	var slab := visual.get_node(^"ArmoredCentralSlab") as MeshInstance3D
	var nose := visual.get_node(^"ArmoredNose") as MeshInstance3D
	var spine := visual.get_node(^"CenterlineArmorSpine") as MeshInstance3D
	var floor := cockpit.get_node(^"CockpitFloor") as MeshInstance3D
	var rear_wall := cockpit.get_node(^"RearPressureWall") as MeshInstance3D
	var slab_bounds := slab.transform * slab.get_aabb()
	var nose_bounds := nose.transform * nose.get_aabb()
	var spine_bounds := spine.transform * spine.get_aabb()
	var floor_bounds := cockpit.transform * (floor.transform * floor.get_aabb())
	var rear_wall_bounds := cockpit.transform * (rear_wall.transform * rear_wall.get_aabb())
	_check(
		slab_bounds.end.y <= floor_bounds.position.y - 0.04
			and nose_bounds.end.y <= floor_bounds.position.y - 0.04,
		"the production slab and nose terminate below the physical cockpit floor"
	)
	_check(
		spine_bounds.position.z >= rear_wall_bounds.end.z + 0.4,
		"the dorsal spine terminates behind the cockpit rear pressure wall"
	)


func _install_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050912")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91a6ba")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46.0, -34.0, 0.0)
	key.light_energy = 1.8
	stage.add_child(key)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("BULWARK_CAMERA_VIEWS_CAPTURE_OK")
		quit(0)
		return
	quit(1)
