extends SceneTree

## Focused presentation contract for the upper-terrace turn into the inspection
## ramp. It deliberately observes only the six new visual strokes and the route,
## collision, light, and authority boundaries they must not change.

const MODULE_SCENE := preload("res://scenes/world/modules/salvage_terrace.tscn")
const CAPTURE_PATH := "/tmp/salvage-terrace-inspection-wayfinding.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "SalvageInspectionWayfindingStage"
	root.add_child(stage)
	var module := MODULE_SCENE.instantiate() as SalvageTerrace
	stage.add_child(module)
	await process_frame
	await physics_frame

	_test_wayfinding_batch(module)
	_test_route_and_authority_boundaries(module)
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture_forward_plus(stage)

	stage.queue_free()
	await process_frame
	_finish()


func _test_wayfinding_batch(module: SalvageTerrace) -> void:
	var batch := module.get_node_or_null(^"GeneratedRoot/ServiceBeaconBatch") as MultiMeshInstance3D
	var mesh := batch.multimesh.mesh as BoxMesh if batch != null and batch.multimesh != null else null
	_check(
		batch != null and batch.multimesh != null and batch.multimesh.instance_count == 10
		and batch.multimesh.visible_instance_count == -1
		and mesh != null and mesh.size.is_equal_approx(SalvageTerrace.SERVICE_BEACON_SIZE),
		"the existing ramp-cue submission now carries four gate fixtures and six deck strokes"
	)
	if batch == null or batch.multimesh == null or batch.multimesh.instance_count != 10:
		return

	var expected_scale := Vector3(
		SalvageTerrace.INSPECTION_ROUTE_CHEVRON_STROKE_SIZE.x / SalvageTerrace.SERVICE_BEACON_SIZE.x,
		SalvageTerrace.INSPECTION_ROUTE_CHEVRON_STROKE_SIZE.y / SalvageTerrace.SERVICE_BEACON_SIZE.y,
		SalvageTerrace.INSPECTION_ROUTE_CHEVRON_STROKE_SIZE.z / SalvageTerrace.SERVICE_BEACON_SIZE.z
	)
	var deck_strokes_exact := true
	var cue_index := 4
	for center in SalvageTerrace.INSPECTION_ROUTE_CHEVRON_CENTERS:
		for x_sign in [-1.0, 1.0]:
			var transform := _decode_transform(batch.multimesh.buffer, cue_index)
			var expected_origin := center as Vector3
			expected_origin += Vector3(
				SalvageTerrace.INSPECTION_ROUTE_CHEVRON_HALF_SPAN * x_sign,
				0.0,
				-SalvageTerrace.INSPECTION_ROUTE_CHEVRON_HALF_SPAN
			)
			var expected_basis := Basis(Vector3.UP, deg_to_rad(-45.0 * x_sign)).scaled(expected_scale)
			deck_strokes_exact = (
				deck_strokes_exact
				and transform.origin.is_equal_approx(expected_origin)
				and transform.basis.is_equal_approx(expected_basis)
			)
			cue_index += 1
	_check(
		deck_strokes_exact,
		"three exact two-stroke chevrons point from the main-ramp crest toward the inspection ramp"
	)
	_check(
		batch.get_child_count() == 0
		and str(batch.get_meta("non_walkable_reason", "")).contains("no dynamic light or authority"),
		"the flush deck cadence remains childless presentation with no hidden authority"
	)


func _test_route_and_authority_boundaries(module: SalvageTerrace) -> void:
	var expected_routes := {
		&"upper-pad": Vector3(18.0, 3.75, 5.0),
		&"inspection-ramp-base": Vector3(23.0, 3.75, 10.0),
		&"inspection-pad": Vector3(23.0, 5.55, 16.0),
	}
	var anchors_exact := module.get_route_ids().size() == 7
	for route_id: StringName in expected_routes:
		var marker := module.get_route_marker(route_id)
		anchors_exact = (
			anchors_exact
			and marker != null
			and marker.position.is_equal_approx(expected_routes[route_id] as Vector3)
		)
	var authority := module.get_authority_contract()
	var performance := module.get_performance_contract()
	_check(anchors_exact, "upper, ramp-base, and inspection route anchors retain their authored transforms")
	_check(
		module.find_children("*", "StaticBody3D", true, false).size() == 26
		and module.find_children("*", "CollisionShape3D", true, false).size() == 26
		and module.find_children("*", "OmniLight3D", true, false).size() == 3,
		"wayfinding adds no collision body, shape, or practical light"
	)
	_check(
		bool(performance.exact_census)
		and int(performance.geometry_submissions) == 38
		and int(performance.multimesh_instances) == 170
		and int(performance.visible_geometry_copies) == 206
		and bool(module.get_audit_report().valid),
		"six added strokes stay inside the existing submission and keep the exact module audit green"
	)
	_check(
		int(authority.ship_berth_count) == 0
		and int(authority.activity_node_count) == 0
		and int(authority.landing_or_interaction_area_count) == 0
		and int(authority.ship_authority_count) == 0
		and int(authority.berth_authority_count) == 0
		and int(authority.combat_authority_count) == 0
		and int(authority.interaction_authority_count) == 0
		and int(authority.station_activity_authority_count) == 0,
		"the presentation-only cue leaves berth, activity, interaction, and route authority empty"
	)


func _capture_forward_plus(stage: Node3D) -> void:
	root.size = Vector2i(1280, 720)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111820")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6d8290")
	environment.ambient_light_energy = 0.52
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-54.0, -38.0, 0.0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	stage.add_child(key_light)
	var camera := Camera3D.new()
	camera.position = Vector3(10.5, 7.4, -1.5)
	camera.look_at_from_position(camera.position, Vector3(21.5, 3.6, 8.7), Vector3.UP)
	camera.fov = 60.0
	camera.current = true
	stage.add_child(camera)

	for _frame in 12:
		await process_frame
	var image := root.get_texture().get_image()
	var save_error := image.save_png(CAPTURE_PATH) if image != null and not image.is_empty() else ERR_CANT_CREATE
	_check(
		RenderingServer.get_current_rendering_method() == &"gl_compatibility"
		or RenderingServer.get_current_rendering_method() == &"forward_plus",
		"capture uses a production rendering method"
	)
	_check(
		image != null and image.get_size() == Vector2i(1280, 720) and save_error == OK,
		"focused route capture writes a complete 1280x720 frame"
	)
	print("SALVAGE_INSPECTION_WAYFINDING_CAPTURE: ", CAPTURE_PATH)


func _decode_transform(buffer: PackedFloat32Array, index: int) -> Transform3D:
	var offset := index * 12
	return Transform3D(
		Basis(
			Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]),
			Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]),
			Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])
		),
		Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11])
	)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SALVAGE_TERRACE_INSPECTION_WAYFINDING_TEST_OK")
		quit(0)
	else:
		print("SALVAGE_TERRACE_INSPECTION_WAYFINDING_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
