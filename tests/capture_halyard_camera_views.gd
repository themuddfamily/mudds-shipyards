extends SceneTree

## Focused review of the Halyard through its own production chase and cockpit
## cameras. This intentionally avoids substituting a staged review camera.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const RESOLUTION := Vector2i(5120, 720)
const PANEL_SIZE := Vector2i(1280, 720)
const OUTPUT_PATH := "/tmp/halyard_camera_views.png"

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
	await _add_panel(row, &"CHASE // 20 M", &"chase_near", false, 20.0, false)
	await _add_panel(row, &"CHASE // 44 M", &"chase_far", false, 44.0, false)
	await _add_panel(row, &"IMPAIRED // 44 M", &"impaired_far", false, 44.0, true)
	await _add_panel(row, &"COCKPIT // FLIGHT DECK", &"cockpit", true, 20.0, false)
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "production-camera frame renders")
	if image != null and not image.is_empty():
		_check(image.save_png(OUTPUT_PATH) == OK, "production-camera frame saves")
		print("HALYARD_CAMERA_VIEWS_CAPTURE: ", OUTPUT_PATH)
	_finish()


func _add_panel(
		row: HBoxContainer,
		label_text: StringName,
		file_stem: StringName,
		cockpit: bool,
		distance: float,
		impaired: bool
	) -> void:
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
	_add_sight_targets(stage)
	var ship := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	stage.add_child(ship)
	await process_frame
	await physics_frame
	ship.set(&"_landed", false)
	ship.set_piloted(true)
	Input.action_press(&"hover")
	await physics_frame
	Input.action_release(&"hover")
	_check(
		StringName(ship.get_telemetry().get("engine_state", &"")) == HeroShip.ENGINE_ONLINE,
		"%s observes the production powered-flight presentation" % label_text
	)
	ship.set_chase_camera_distance(distance)
	ship.set_cockpit_view(cockpit)
	if impaired:
		ship.apply_damage(
			ship.maximum_hull * 0.10,
			ship.to_global(Vector3(0.0, 1.55, 11.2)),
			ship.global_basis.z
		)
	for _frame in 16:
		await physics_frame
	await RenderingServer.frame_post_draw
	var panel_image := viewport.get_texture().get_image()
	_check(
		panel_image != null and not panel_image.is_empty()
			and panel_image.save_png("/tmp/halyard_camera_%s.png" % file_stem) == OK,
		"%s saves a standalone 16:9 review frame" % label_text
	)
	var camera := ship.get_camera()
	_check(
		camera != null and camera.current
			and ((camera.name == &"CockpitCamera") == cockpit),
		"%s uses the production %s camera" % [label_text, "cockpit" if cockpit else "chase"]
	)
	if impaired:
		var vane := ship.get_node(
			^"HalyardTransportVisual/EngineDamageIsolationVane"
		) as MeshInstance3D
		_check(
			vane.get_meta(&"damage_state", &"") == &"impaired",
			"the far critical-state frame comes from the production engine ledger"
		)
	if cockpit:
		_check_flight_deck_floor_clearance(ship)
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(18.0, 18.0)
	label.add_theme_color_override("font_color", Color("e8f3f5"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 20)
	container.add_child(label)


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


func _add_sight_targets(stage: Node3D) -> void:
	# Three small fixed targets make a blocked or over-dark cockpit sightline
	# visible without replacing the production camera or adding anything to the ship.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d8f1f6")
	material.emission_enabled = true
	material.emission = Color("68d8ef")
	material.emission_energy_multiplier = 3.0
	for x in [-5.0, 0.0, 5.0]:
		var target := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.7
		mesh.height = 1.4
		mesh.material = material
		target.mesh = mesh
		target.position = Vector3(x, 1.85, -48.0)
		stage.add_child(target)


func _check_flight_deck_floor_clearance(ship: HalyardCrewTransport) -> void:
	var floor := ship.get_node(
		^"WalkableInterior/CockpitInterior/CockpitFloor"
	) as MeshInstance3D
	var nose_belly := ship.get_node(
		^"HalyardTransportVisual/NoseBelly"
	) as MeshInstance3D
	var nose_cap_belly := ship.get_node(
		^"HalyardTransportVisual/NoseCapBelly"
	) as MeshInstance3D
	var floor_bounds := _ship_local_bounds(ship, floor)
	var nose_bounds := _ship_local_bounds(ship, nose_belly)
	var cap_bounds := _ship_local_bounds(ship, nose_cap_belly)
	_check(
		_ranges_overlap(
			floor_bounds.position.z, floor_bounds.end.z,
			nose_bounds.position.z, nose_bounds.end.z
		)
			and _ranges_overlap(
				floor_bounds.position.z, floor_bounds.end.z,
				cap_bounds.position.z, cap_bounds.end.z
			)
			and floor_bounds.position.y - nose_bounds.end.y >= 0.039
			and floor_bounds.position.y - cap_bounds.end.y >= 0.039,
		"both overlapping nose-belly shells terminate below the physical flight-deck floor"
	)


func _ship_local_bounds(
		ship: HalyardCrewTransport,
		mesh: MeshInstance3D
	) -> AABB:
	return (
		ship.global_transform.affine_inverse() * mesh.global_transform
		* mesh.get_aabb()
	).abs()


func _ranges_overlap(first_min: float, first_max: float, second_min: float, second_max: float) -> bool:
	return minf(first_max, second_max) > maxf(first_min, second_min)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HALYARD_CAMERA_VIEWS_CAPTURE_OK")
		quit(0)
		return
	quit(1)
