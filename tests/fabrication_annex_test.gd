extends SceneTree

const ANNEX_SCENE := preload("res://scenes/world/modules/fabrication_annex.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "FabricationAnnexTestStage"
	root.add_child(stage)
	var annex := ANNEX_SCENE.instantiate() as FabricationAnnex
	stage.add_child(annex)
	await process_frame
	await physics_frame

	_test_contract(annex)
	_test_area_and_surface_census(annex)
	await _test_collision_and_edges(stage, annex)
	await _test_physical_roof_columns(stage, annex)
	await _test_embodied_traversal(stage, annex)
	await _test_structured_red_mutations(annex)
	_test_lifecycle(annex)
	if OS.get_cmdline_user_args().has("--capture-fabrication-annex"):
		await _capture_one_forward_plus_frame(stage, annex)

	Input.action_release(&"move_forward")
	Input.action_release(&"sprint_boost")
	stage.queue_free()
	await process_frame
	_finish()


func _test_contract(annex: FabricationAnnex) -> void:
	var report := StationModuleContract.new().validate_contract(annex)
	if not bool(report.valid):
		print("FABRICATION_ANNEX_CONTRACT_ERRORS: ", report.errors)
		print("FABRICATION_ANNEX_MODULE_ERRORS: ", annex.get_validation_errors())
	_check(bool(report.valid), "the standalone station-module contract validates")
	_check(annex.get_module_id() == &"fabrication_annex", "the module publishes its stable identity")
	_check(bool(annex.get_meta(&"station_module", false)) and annex.is_in_group(&"station_modules"), "production discovery metadata and station_modules group identify the module root")
	var route_ids: Array[StringName] = annex.get_route_ids()
	_check(route_ids.size() == 7, "the annex publishes one connector and six internal/deferred route markers through the integrated-module Array API")

	var expected_slots := {
		&"fabrication_annex_inbound": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.15, 0.0)),
	}
	var slots := annex.get_connection_slots()
	_check(slots.size() == 1, "only the real inbound peer is declared as a connection slot")
	for slot in slots:
		var slot_id := StringName(slot.slot_id)
		_check(expected_slots.has(slot_id), "connection slot %s is expected" % slot_id)
		if expected_slots.has(slot_id):
			_check((slot.local_transform as Transform3D).is_equal_approx(expected_slots[slot_id]), "slot %s keeps its exact local Transform3D basis and origin" % slot_id)
	_check(
		StationModuleContract.new().read_connection_slot_id(annex.get_route_marker(&"annex_port_service")).is_empty()
		and StationModuleContract.new().read_connection_slot_id(annex.get_route_marker(&"annex_starboard_service")).is_empty(),
		"port and starboard service routes remain internal/deferred and cannot create dangling adjacency"
	)

	var evidence := annex.get_evidence_metadata()
	_check(str(evidence.evidence_status) == "modern_interpretation", "evidence status is modern_interpretation")
	_check(str(evidence.interpretation_label) == "new", "the topology element is labelled new")
	_check(str(evidence.source_confidence) == "none", "source confidence is none")
	_check(not bool(evidence.authenticated_original_geometry), "the annex claims no authenticated original geometry")
	_check((evidence.registered_evidence_anchors as PackedStringArray).is_empty(), "the annex cites no invented evidence anchor")

	var authority := annex.get_authority_contract()
	_check(int(authority.ship_berth_count) == 0, "the annex owns no ship or berth authority")
	_check(int(authority.activity_node_count) == 0 and int(authority.landing_or_interaction_area_count) == 0, "the annex owns no activity or interaction authority")
	_check(str(authority.combat_authority) == "none" and str(authority.reward_authority) == "none", "the annex owns no combat or reward authority")


func _test_area_and_surface_census(annex: FabricationAnnex) -> void:
	var area := annex.get_walkable_area_contract()
	_check(is_equal_approx(float(area.station_census_contribution_m2), 480.0), "live non-overlapping level collision union contributes exactly 480.00 m² to the station census")
	_check(is_equal_approx(float(area.gross_horizontal_area_m2), 480.0), "live level surface union is exactly 480.00 m²")
	_check(is_equal_approx(float(area.fixed_equipment_footprint_m2), 69.30), "live fixed equipment including eight columns occupies exactly 69.30 m²")
	_check(is_equal_approx(float(area.floor_after_fixed_equipment_m2), 410.70), "floor after fixed equipment is exactly 410.70 m²")
	_check(not bool(area.full_clear_walkable_area_claimed), "the module does not mislabel floor-after-equipment as fully clear walkable area")
	_check(float(area.true_ramp_area_m2) == 0.0 and float(area.projected_ramp_area_m2) == 0.0, "the level annex publishes no invented ramp area")
	_check(str(area.station_census_scope) == "authoritative_usable_level_collision_surface_union", "the census contribution is scoped to authoritative usable level collision")

	var roster := annex.get_standable_surface_roster()
	_check(roster.size() == 7, "all seven non-overlapping standable level surfaces are rostered")
	var sum := 0.0
	for entry in roster:
		sum += float(entry.horizontal_area_m2)
	_check(is_equal_approx(sum, 480.0), "the published surface roster sums exactly to its union")

	var tagged := annex.find_children("*", "StaticBody3D", true, false).filter(
		func(body: Node) -> bool: return bool(body.get_meta(&"walkable_surface", false))
	)
	_check(tagged.size() == 7, "only the seven authoritative deck bodies carry census tags")
	var ids := {}
	for raw_body in tagged:
		var body := raw_body as StaticBody3D
		var id := StringName(body.get_meta(&"walkable_surface_id", &""))
		ids[id] = true
		_check(StringName(body.get_meta(&"walkable_surface_kind", &"")) == &"level", "walkable body %s is classified level" % id)
		_check(StringName(body.get_meta(&"walkable_surface_owner", &"")) == annex.get_module_id(), "walkable body %s publishes its module owner" % id)
	_check(ids.size() == 7, "walkable surface IDs are stable and unique")
	var equipment := annex.get_fixed_equipment_footprint_roster()
	_check(equipment.size() == 20, "four fabricators, four benches, four racks, and eight physical columns are footprint-rostered")
	var equipment_sum := 0.0
	for entry in equipment:
		equipment_sum += float(entry.horizontal_footprint_m2)
	_check(is_equal_approx(equipment_sum, 69.30), "fixed-equipment area is derived from live collision shapes and transforms")

	var performance := annex.get_performance_contract()
	print("FABRICATION_ANNEX_BUDGET: meshes=%d multimeshes=%d drawn=%d submissions=%d copies=%d bodies=%d shapes=%d lights=%d labels=%d nodes=%d" % [
		performance.mesh_instances, performance.multi_mesh_instances, performance.multi_mesh_drawn_copies,
		performance.geometry_instances, performance.visible_geometry_copies,
		performance.static_bodies, performance.collision_shapes, performance.lights,
		performance.labels, performance.nodes,
	])
	_check(bool(performance.within_budget), "mesh, collision, light, callback, and node counts remain inside published budgets")
	_check(int(performance.static_bodies) <= int(performance.budgets.static_bodies), "static-body budget is explicit")
	_check(int(performance.collision_shapes) <= int(performance.budgets.collision_shapes), "collision-shape budget is explicit")
	_check(int(performance.mesh_instances) <= int(performance.budgets.mesh_instances), "mesh budget is explicit")
	_check(int(performance.lights) <= int(performance.budgets.lights), "light budget is explicit")
	_check(int(performance.nodes) <= int(performance.budgets.nodes), "node budget is explicit")
	var lighting := annex.get_lighting_contract()
	_check(
		int(lighting.source_practical_count) == 6
		and int(lighting.paired_pool_count) == 3
		and int(lighting.luminaire_count) == 6
		and bool(lighting.exact_pool_roster)
		and bool(lighting.luminaires_exact),
		"three exact paired pools retain all six authored luminaire copies"
	)
	_check(
		is_equal_approx(float(lighting.source_range_m), 8.0)
		and is_equal_approx(float(lighting.pair_midpoint_offset_m), 3.75)
		and is_equal_approx(float(lighting.pool_range_m), 11.75)
		and is_equal_approx(float(lighting.pool_energy), 4.8)
		and is_equal_approx(float(lighting.attenuation), 1.0)
		and bool(lighting.coverage_preserved),
		"each 11.75 m pool geometrically contains both former 8 m source volumes"
	)
	var expected_pools := {
		&"port": [Vector3(-8.5, 4.6, 10.75), Color("ffe0b0")],
		&"central": [Vector3(0.0, 4.6, 10.75), Color("c9e2dd")],
		&"starboard": [Vector3(8.5, 4.6, 10.75), Color("ffe0b0")],
	}
	var pools_exact := (lighting.pools as Array).size() == expected_pools.size()
	for pool_variant in lighting.pools as Array:
		var pool := pool_variant as Dictionary
		var pool_id := StringName(pool.pool_id)
		pools_exact = pools_exact and expected_pools.has(pool_id)
		if expected_pools.has(pool_id):
			var expected := expected_pools[pool_id] as Array
			pools_exact = pools_exact \
				and (pool.position as Vector3).is_equal_approx(expected[0] as Vector3) \
				and (pool.color as Color).is_equal_approx(expected[1] as Color) \
				and is_equal_approx(float(pool.attenuation), 1.0) \
				and is_equal_approx(float(pool.fade_begin_m), 18.0) \
				and is_equal_approx(float(pool.fade_length_m), 8.0) \
				and not bool(pool.shadow_enabled) \
				and (pool.source_positions as Array).size() == 2 \
				and bool(pool.sources_geometrically_contained)
	_check(pools_exact, "warm side pairs and the cool central pair retain exact midpoint identities and colours")
	var render := annex.get_render_submission_contract()
	print("FABRICATION_ANNEX_BUFFER: floats=%d authored=%d matches=%s keys=%d" % [render.forward_plus_buffer_float_count, render.authored_transform_count, render.forward_plus_buffers_match_authored, (render.batch_keys as PackedStringArray).size()])
	_check(int(render.multi_mesh_batches) == 12 and int(render.multi_mesh_drawn_copies) == 94, "twelve batches store all 94 non-colliding drawn copies")
	_check(int(render.geometry_submissions) == 46 and int(render.visible_geometry_copies) == 128, "46 submissions draw the frozen 128 visible geometry copies")
	_check(int(render.authored_transform_count) == 94, "every MultiMesh copy retains an authored transform")
	_check(int(render.forward_plus_buffer_float_count) == 1128 and bool(render.forward_plus_buffers_match_authored), "Forward+ transform buffers contain exactly 94 valid 3D transforms")
	var naming := annex.get_deterministic_naming_contract()
	print("FABRICATION_ANNEX_NAMING: nodes=%d allocations=%d fallbacks=%d duplicates=%d paths=%s" % [naming.node_count, naming.generated_name_allocation_count, naming.auto_generated_fallback_path_count, naming.duplicate_sibling_name_count, naming.auto_generated_fallback_paths])
	_check(int(naming.node_count) == 129 and int(naming.generated_name_allocation_count) == 46, "all 129 nodes and 46 generated allocations are frozen deterministically")
	_check(int(naming.auto_generated_fallback_path_count) == 0 and int(naming.duplicate_sibling_name_count) == 0, "no runtime path contains an auto-generated @ fallback or duplicate sibling name")

	var mapped_materials := {}
	for raw_mesh in annex.find_children("*", "MeshInstance3D", true, false):
		var material := (raw_mesh as MeshInstance3D).material_override as StandardMaterial3D
		if material != null and material.uv1_world_triplanar:
			mapped_materials[material.get_instance_id()] = material
	var compliant_scale := not mapped_materials.is_empty()
	for material in mapped_materials.values():
		compliant_scale = compliant_scale and (material as StandardMaterial3D).uv1_scale.is_equal_approx(Vector3.ONE * 0.30)
	_check(compliant_scale, "every mapped annex panel uses the accepted 0.30 production station scale")


func _test_collision_and_edges(stage: Node3D, annex: FabricationAnnex) -> void:
	for sample in [Vector3(0, 2, 1), Vector3(0, 2, 11), Vector3(-7, 2, 11), Vector3(7, 2, 11), Vector3(-12.5, 2, 11), Vector3(12.5, 2, 11), Vector3(0, 2, 19)]:
		var hit := await _ray(stage, sample, sample + Vector3.DOWN * 4.0)
		_check(not hit.is_empty() and absf((hit.position as Vector3).y) < 0.03, "standable surface supports sample %s at deck height" % sample)

	var port_edge := await _ray(stage, Vector3(-13.0, 0.8, 7.0), Vector3(-15.0, 0.8, 7.0))
	var starboard_edge := await _ray(stage, Vector3(13.0, 0.8, 17.0), Vector3(15.0, 0.8, 17.0))
	var rear_edge := await _ray(stage, Vector3(0.0, 0.8, 19.0), Vector3(0.0, 0.8, 21.0))
	_check(not port_edge.is_empty() and not starboard_edge.is_empty() and not rear_edge.is_empty(), "guardrail collision protects both side edges and the rear edge")

	var port_gate := await _ray(stage, Vector3(-13.0, 0.8, 12.0), Vector3(-15.0, 0.8, 12.0))
	var starboard_gate := await _ray(stage, Vector3(13.0, 0.8, 12.0), Vector3(15.0, 0.8, 12.0))
	_check(port_gate.is_empty() and starboard_gate.is_empty(), "the side-route connection gates stay physically open")


func _test_physical_roof_columns(stage: Node3D, annex: FabricationAnnex) -> void:
	var columns: Array[Node] = []
	for raw_body in annex.find_children("*", "StaticBody3D", true, false):
		if str(raw_body.get_meta(&"fixed_equipment_id", "")).begins_with("roof_column_"):
			columns.append(raw_body)
	_check(columns.size() == 8, "all eight solid-looking roof columns are physical StaticBody3D members")
	var every_column_hit := true
	for raw_column in columns:
		var column := raw_column as StaticBody3D
		var from := column.global_position + Vector3(-0.8, -1.5, 0.0)
		var to := column.global_position + Vector3(0.8, -1.5, 0.0)
		var hit := await _ray(stage, from, to)
		every_column_hit = every_column_hit and not hit.is_empty() and hit.collider == column
	_check(every_column_hit, "embodied-height rays hit every visible structural column")


func _test_embodied_traversal(stage: Node3D, annex: FabricationAnnex) -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	stage.add_child(player)
	player.set_control_enabled(true)
	# Local +Z is the through-route; Godot's body forward is -basis.z.
	player.teleport_to(Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), Vector3(0.0, 0.18, 0.8)))
	await physics_frame
	var reached_rear := await _drive_forward(player, func() -> bool: return player.global_position.z >= 18.2, 300)
	_check(reached_rear, "production PlayerController traverses the wide central aisle from origin to rear cross-aisle")
	_check(absf(player.global_position.x) < 0.45 and player.global_position.y > -0.15, "central embodied traversal neither snags nor falls")

	player.teleport_to(Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), Vector3(-12.5, 0.18, 5.0)))
	await physics_frame
	var reached_bypass := await _drive_forward(player, func() -> bool: return player.global_position.z >= 17.5, 240)
	_check(reached_bypass, "production PlayerController traverses the useful port-side bypass")
	_check(absf(player.global_position.x + 12.5) < 0.45 and player.global_position.y > -0.15, "side-route traversal stays supported between equipment and guardrail")

	player.teleport_to(Transform3D(Basis.looking_at(Vector3.LEFT, Vector3.UP), Vector3(-0.5, 0.18, 11.0)))
	await physics_frame
	var entered_port_bay := await _drive_forward(player, func() -> bool: return player.global_position.x <= -6.2, 140)
	_check(entered_port_bay, "production PlayerController enters the port work bay through the equipment gap")
	_check(player.global_position.y > -0.15, "bay access remains an embodied supported route")
	player.queue_free()
	await process_frame


func _test_structured_red_mutations(annex: FabricationAnnex) -> void:
	var inbound_slot := annex.get_route_marker(&"annex_inbound")
	var original_slot_transform := inbound_slot.transform
	inbound_slot.rotate_y(0.15)
	_check(not bool(annex.get_audit_report().valid), "structured-red: a connection-slot yaw mutation fails full Transform3D audit")
	inbound_slot.transform = original_slot_transform

	var slab := annex.find_child("CentralThroughAisle", true, false) as StaticBody3D
	var slab_shape := (slab.find_child("*", false, false) as CollisionShape3D).shape as BoxShape3D
	var slab_size := slab_shape.size
	slab_shape.size.x += 0.25
	_check(not bool(annex.get_audit_report().valid), "structured-red: live slab collision area drift fails census audit")
	slab_shape.size = slab_size

	var workbench := annex.find_child("WorkBench", true, false) as StaticBody3D
	var workbench_shape := (workbench.find_child("*", false, false) as CollisionShape3D).shape as BoxShape3D
	var workbench_size := workbench_shape.size
	workbench_shape.size.z += 0.2
	_check(not bool(annex.get_audit_report().valid), "structured-red: live fixed-equipment footprint drift fails area audit")
	workbench_shape.size = workbench_size

	var body := annex.find_child("ConnectorApron", true, false) as StaticBody3D
	body.collision_layer = 0
	_check(not bool(annex.get_audit_report().valid), "structured-red: a collision-layer mutation fails audit")
	body.collision_layer = WORLD_LAYER

	var forbidden := Area3D.new()
	forbidden.name = "ForbiddenActivityAuthority"
	forbidden.set_meta(&"station_activity", true)
	annex.add_child(forbidden)
	_check(not bool(annex.get_audit_report().valid), "structured-red: injected activity/interaction authority fails audit")
	forbidden.queue_free()
	await process_frame

	annex.set_process(true)
	_check(not bool(annex.get_audit_report().valid), "structured-red: an unbudgeted process loop fails audit")
	annex.set_process(false)

	var pool := annex.get_node(^"GeneratedAnnex/PracticalPoolCentral") as OmniLight3D
	var pool_position := pool.position
	pool.position.z += 0.25
	_check(not bool(annex.get_audit_report().valid), "structured-red: moving a paired light pool fails the exact lighting audit")
	pool.position = pool_position

	var batch := annex.find_children("*", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D
	var authored_buffer := RenderingServer.multimesh_get_buffer(batch.multimesh.get_rid())
	var mutated_buffer := authored_buffer.duplicate()
	mutated_buffer[3] += 0.1
	batch.multimesh.buffer = mutated_buffer
	_check(not bool(annex.get_audit_report().valid), "structured-red: a Forward+ buffer transform mutation fails authored-buffer audit")
	batch.multimesh.buffer = authored_buffer

	_check(bool(annex.get_audit_report().valid), "audit returns green after every mutation is restored")


func _test_lifecycle(annex: FabricationAnnex) -> void:
	var before := annex.get_lifecycle_contract().surface_instance_ids as PackedInt64Array
	annex.set_module_enabled(false)
	var disabled := annex.get_lifecycle_contract()
	_check(not annex.is_module_enabled() and bool(disabled.visible_matches_enabled) and bool(disabled.collision_matches_enabled), "disable hides geometry and removes world collision without rebuilding")
	annex.set_module_enabled(true)
	var restored := annex.get_lifecycle_contract()
	_check(bool(restored.visible_matches_enabled) and bool(restored.collision_matches_enabled), "enable restores the visible collision state")
	_check(before == (restored.surface_instance_ids as PackedInt64Array), "enable/disable preserves static-body identity")
	_check(bool(annex.get_audit_report().valid), "lifecycle round-trip leaves the annex valid")


func _drive_forward(player: PlayerController, reached: Callable, frame_budget: int) -> bool:
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint_boost")
	for _frame in frame_budget:
		if reached.call():
			break
		await physics_frame
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint_boost")
	await physics_frame
	return bool(reached.call())


func _ray(stage: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	query.collide_with_areas = false
	return stage.get_world_3d().direct_space_state.intersect_ray(query)


func _capture_one_forward_plus_frame(stage: Node3D, annex: FabricationAnnex) -> void:
	_check(bool(annex.get_render_submission_contract().forward_plus_buffers_match_authored), "Forward+ capture begins with every MultiMesh buffer matching its authored transforms")
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111820")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("607586")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(25.0, 17.0, -10.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.4, 11.0), Vector3.UP)
	camera.current = true
	camera.fov = 58.0
	stage.add_child(camera)
	for _frame in 8:
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png("/tmp/fabrication-annex-forward-plus.png")
	_check(error == OK and image.get_width() >= 1280 and image.get_height() >= 720, "one normal-resolution Forward+ overview frame is captured")
	print("FABRICATION_ANNEX_FRAME: /tmp/fabrication-annex-forward-plus.png ", image.get_size())


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("FABRICATION_ANNEX_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("FABRICATION_ANNEX_TEST: %d/%d assertions failed" % [_failures.size(), _assertions])
		for failure in _failures:
			print("  - ", failure)
		quit(1)
