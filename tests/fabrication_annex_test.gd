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
	_test_finishing_pass(annex)
	_test_inbound_portal_threshold(annex)
	await _test_collision_and_edges(stage, annex)
	await _test_physical_roof_columns(stage, annex)
	await _test_embodied_traversal(stage, annex)
	if OS.get_cmdline_user_args().has("--capture-fabrication-annex"):
		await _capture_one_forward_plus_frame(stage, annex)
	await _test_observation_gate_variant(stage)
	await _test_structured_red_mutations(annex)
	await _test_lifecycle(annex)

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
	_check(int(render.multi_mesh_batches) == 32 and int(render.multi_mesh_drawn_copies) == 185, "32 restrained batches store all 185 remaining MultiMesh-authored architectural and equipment copies")
	_check(int(render.geometry_submissions) == 35 and int(render.visible_geometry_copies) == 205, "35 submissions draw the frozen 205 visible geometry copies")
	_check(int(render.authored_transform_count) == 185, "every remaining MultiMesh copy retains an authored transform")
	_check(int(render.forward_plus_buffer_float_count) == 2220 and bool(render.forward_plus_buffers_match_authored), "Forward+ transform buffers contain exactly 185 valid 3D transforms")
	var floor_render := annex.get_floor_render_optimization_contract()
	_check(
		bool(floor_render.valid)
		and int(floor_render.before.renderer_submissions) == 5
		and int(floor_render.after.renderer_submissions) == 1
		and int(floor_render.delta.renderer_submissions) == -4
		and int(floor_render.before.presentation_nodes) == 5
		and int(floor_render.after.presentation_nodes) == 1
		and int(floor_render.delta.presentation_nodes) == -4,
		"five immutable non-work-bay deck renderers combine into one surface submission and node"
	)
	_check(
		int(floor_render.before.visible_geometry_copies) == 5
		and int(floor_render.after.visible_geometry_copies) == 5
		and int(floor_render.before.retained_mesh_resources) == 4
		and int(floor_render.after.retained_mesh_resources) == 1
		and int(floor_render.delta.retained_mesh_resources) == -3
		and int(floor_render.combined_vertex_count) == 1620
		and bool(floor_render.visual_parts_exact)
		and bool(floor_render.render_state_and_combined_geometry_exact),
		"all five deck copies, exact transforms, walked finish, shadows, bevel topology and extents survive with one retained mesh"
	)
	_check(
		int(floor_render.collision_body_count) == 5
		and bool(floor_render.collision_transforms_and_shapes_exact),
		"the five independently identified walkable collision bodies keep their exact transforms and shapes"
	)
	var overhead := annex.get_overhead_structure_render_optimization_contract()
	_check(
		bool(overhead.valid)
		and int(overhead.before.renderer_submissions) == 2
		and int(overhead.after.renderer_submissions) == 1
		and int(overhead.delta.renderer_submissions) == -1
		and int(overhead.before.presentation_nodes) == 2
		and int(overhead.after.presentation_nodes) == 1
		and int(overhead.delta.presentation_nodes) == -1,
		"crossbeams and roof spines combine from two size-keyed submissions into one immutable structural surface"
	)
	_check(
		int(overhead.before.visible_geometry_copies) == 7
		and int(overhead.after.visible_geometry_copies) == 7
		and int(overhead.delta.retained_mesh_resources) == -1
		and int(overhead.delta.multi_mesh_transform_buffer_floats) == -84
		and int(overhead.combined_vertex_count) == 2268
		and bool(overhead.visual_parts_exact)
		and bool(overhead.render_state_and_combined_geometry_exact),
		"all seven exact overhead poses, rounded topology, structural finish, shadows and visibility survive without transform-buffer storage"
	)
	var ceiling_portal := annex.get_ceiling_portal_render_optimization_contract()
	_check(
		bool(ceiling_portal.valid)
		and int(ceiling_portal.before.renderer_submissions) == 2
		and int(ceiling_portal.after.renderer_submissions) == 1
		and int(ceiling_portal.delta.renderer_submissions) == -1
		and int(ceiling_portal.before.multi_mesh_transform_buffer_floats) == 96
		and int(ceiling_portal.after.multi_mesh_transform_buffer_floats) == 0,
		"six ceiling coffers and two portal fascia panels share one immutable ceiling-finish submission"
	)
	_check(
		int(ceiling_portal.before.visible_geometry_copies) == 8
		and int(ceiling_portal.after.visible_geometry_copies) == 8
		and int(ceiling_portal.combined_vertex_count) == 2592
		and bool(ceiling_portal.visual_parts_exact)
		and bool(ceiling_portal.render_state_and_combined_geometry_exact),
		"all eight exact ceiling and portal poses, rounded topology, finish, shadows, and visibility survive the shared renderer"
	)
	var work_bay_surfaces := annex.get_work_bay_surface_render_optimization_contract()
	_check(
		bool(work_bay_surfaces.valid)
		and int(work_bay_surfaces.before.renderer_submissions) == 2
		and int(work_bay_surfaces.after.renderer_submissions) == 1
		and int(work_bay_surfaces.delta.renderer_submissions) == -1
		and int(work_bay_surfaces.before.visible_geometry_copies) == 2
		and int(work_bay_surfaces.after.visible_geometry_copies) == 2
		and int(work_bay_surfaces.before.primitive_mesh_resources) == 1
		and int(work_bay_surfaces.after.primitive_mesh_resources) == 1,
		"the paired work-bay deck renderers reduce submissions 2-to-1 without removing a visible copy or shared mesh"
	)
	_check(
		bool(work_bay_surfaces.visual_transforms_exact)
		and bool(work_bay_surfaces.render_state_exact)
		and bool(work_bay_surfaces.collision_transforms_and_shapes_exact)
		and int(work_bay_surfaces.collision_body_count) == 2,
		"both deck poses, walked finish, shadows, collision bodies, and 8 x 0.4 x 14 m shapes remain exact"
	)
	var columns := annex.get_roof_column_render_optimization_contract()
	_check(
		bool(columns.valid)
		and int(columns.before.renderer_submissions) == 8
		and int(columns.after.renderer_submissions) == 1
		and int(columns.delta.renderer_submissions) == -7
		and int(columns.before.presentation_nodes) == 8
		and int(columns.after.presentation_nodes) == 1
		and int(columns.delta.presentation_nodes) == -7,
		"roof-column batching freezes the measured 8-to-1 submission and presentation-node reduction"
	)
	_check(
		int(columns.before.visible_geometry_copies) == 8
		and int(columns.after.visible_geometry_copies) == 8
		and int(columns.before.primitive_mesh_resources) == 1
		and int(columns.after.primitive_mesh_resources) == 1
		and bool(columns.visual_transforms_exact)
		and bool(columns.collision_names_transforms_and_shapes_exact),
		"all eight column poses and physical identities survive while the one cached mesh resource remains one"
	)
	var bases := annex.get_fabricator_base_render_optimization_contract()
	_check(
		bool(bases.valid)
		and int(bases.before.renderer_submissions) == 4
		and int(bases.after.renderer_submissions) == 1
		and int(bases.delta.renderer_submissions) == -3
		and int(bases.before.visible_geometry_copies) == 4
		and int(bases.after.visible_geometry_copies) == 4,
		"fabricator-base batching freezes the measured 4-to-1 submission reduction without removing a visible copy"
	)
	_check(
		bool(bases.visual_transforms_exact)
		and bool(bases.render_state_exact)
		and bool(bases.collision_names_transforms_and_shapes_exact),
		"all four base transforms, cached mesh, material, culling, shadows, and physical identities remain exact"
	)
	var benches := annex.get_work_bench_render_optimization_contract()
	_check(
		bool(benches.valid)
		and int(benches.before.renderer_submissions) == 4
		and int(benches.after.renderer_submissions) == 1
		and int(benches.delta.renderer_submissions) == -3
		and int(benches.before.visible_geometry_copies) == 4
		and int(benches.after.visible_geometry_copies) == 4
		and bool(benches.visual_transforms_exact)
		and bool(benches.render_state_exact)
		and bool(benches.collision_names_transforms_shapes_and_ids_exact),
		"work-bench batching preserves all four exact visible poses, render state, collisions, and fixed-equipment identities while reducing submissions 4-to-1"
	)
	_test_material_rack_batch(annex)
	var naming := annex.get_deterministic_naming_contract()
	print("FABRICATION_ANNEX_NAMING: nodes=%d allocations=%d fallbacks=%d duplicates=%d paths=%s" % [naming.node_count, naming.generated_name_allocation_count, naming.auto_generated_fallback_path_count, naming.duplicate_sibling_name_count, naming.auto_generated_fallback_paths])
	_check(int(naming.node_count) == 121 and int(naming.generated_name_allocation_count) == 66, "all 121 nodes and 66 generated allocations are frozen deterministically")
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
	_test_manufactured_material_roles(annex)


func _test_manufactured_material_roles(annex: FabricationAnnex) -> void:
	var materials := annex.get("_materials") as Dictionary
	var specs := {
		&"deck": [Color("34414a"), 0.72, 0.45, StationSurfaceKit.WALKED_CLEARCOAT, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS],
		&"floor_inlay": [Color("19353b"), 0.64, 0.28, StationSurfaceKit.WALKED_CLEARCOAT, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS],
		&"structure": [Color("202a31"), 0.76, 0.45, StationSurfaceKit.STRUCTURAL_CLEARCOAT, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS],
		&"ceiling": [Color("151d23"), 0.86, 0.32, StationSurfaceKit.STRUCTURAL_CLEARCOAT, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS],
		&"machine": [Color("68727a"), 0.62, 0.5, StationSurfaceKit.PAINTED_CLEARCOAT, StationSurfaceKit.PAINTED_CLEARCOAT_ROUGHNESS],
		&"hazard": [Color("d58b27"), 0.5, 0.35, StationSurfaceKit.PAINTED_CLEARCOAT, StationSurfaceKit.PAINTED_CLEARCOAT_ROUGHNESS],
		&"rail": [Color("aeb9bc"), 0.5, 0.55, StationSurfaceKit.TRIM_CLEARCOAT, StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS],
		&"accent": [Color("3b9ca2"), 0.38, 0.4, StationSurfaceKit.TRIM_CLEARCOAT, StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS],
	}
	var roles_exact := materials.size() == specs.size() + 1 # The ninth material is emissive status light.
	for material_id in specs:
		var material := materials.get(material_id) as StandardMaterial3D
		var spec := specs[material_id] as Array
		roles_exact = (
			roles_exact
			and material != null
			and material.albedo_color.is_equal_approx(spec[0] as Color)
			and is_equal_approx(material.roughness, float(spec[1]))
			and is_equal_approx(material.metallic, float(spec[2]))
			and material.albedo_texture != null
			and material.normal_enabled
			and material.normal_texture != null
			and material.roughness_texture != null
			and material.uv1_triplanar
			and material.uv1_world_triplanar
			and material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30)
			and material.clearcoat_enabled
			and is_equal_approx(material.clearcoat, float(spec[3]))
			and is_equal_approx(material.clearcoat_roughness, float(spec[4]))
		)
	_check(
		roles_exact,
		"walked, structural, painted-machine, and metal-trim surfaces keep their hues and exact StationSurfaceKit finish roles"
	)


func _test_finishing_pass(annex: FabricationAnnex) -> void:
	var rail_colliders := annex.find_children("GuardrailCollider*", "StaticBody3D", true, false)
	var collision_is_invisible := rail_colliders.size() == 7
	for raw_collider in rail_colliders:
		collision_is_invisible = collision_is_invisible and raw_collider.find_children("*", "MeshInstance3D", false, false).is_empty()
	_check(collision_is_invisible, "guardrails retain conservative collision without rendering it as opaque wall slabs")
	var required_batches := [
		"ClerestoryRibBatch",
		"RoofColumnBatch",
		"EntryJambBatch", "EntryHeaderBatch",
		"MainSignBackingBatch", "BayGuideLineBatch", "AisleGuideBatch",
		"FabricatorDeckBatch", "FabricatorControlBatch", "FabricatorStatusBatch",
		"BenchBackboardBatch", "ToolDockBatch", "RackCanisterBatch",
	]
	var complete := true
	for node_name in required_batches:
		complete = complete and annex.find_child(node_name, true, false) is MultiMeshInstance3D
	complete = complete \
		and annex.find_child("OverheadStructureRenderBatch", true, false) is MeshInstance3D \
		and annex.find_child("CeilingPortalRenderBatch", true, false) is MeshInstance3D
	_check(complete, "roof, facade, deck zoning, controls, benches, and material racks all carry their finishing geometry")

	var labels := annex.find_children("*", "Label3D", true, false)
	var culled_faces := labels.size() == 6
	for raw_label in labels:
		culled_faces = culled_faces and not (raw_label as Label3D).double_sided
	_check(culled_faces, "three signs use six individually culled faces instead of mirrored rear-face text")
	var entry_front := annex.find_child("FabricationAnnexFront", true, false) as Label3D
	var entry_rear := annex.find_child("FabricationAnnexRear", true, false) as Label3D
	_check(
		entry_front != null and entry_rear != null
		and is_equal_approx(entry_front.rotation.y, PI)
		and is_zero_approx(entry_rear.rotation.y)
		and entry_front.text == entry_rear.text,
		"the FABRICATION ANNEX legend has correctly oriented front and rear faces"
	)
	var status_batch := annex.find_child("FabricatorStatusBatch", true, false) as MultiMeshInstance3D
	var status_material := status_batch.material_override as StandardMaterial3D if status_batch != null else null
	_check(status_material != null and status_material.emission_enabled, "fabricator status strips and aisle guides use a grounded emissive material")


func _test_inbound_portal_threshold(annex: FabricationAnnex) -> void:
	var batch := annex.find_child("BayCrossMarkBatch", true, false) as MultiMeshInstance3D
	var expected_thresholds := [
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 4.18)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 4.52)),
	]
	var authored := annex.get("_authored_batch_transforms") as Dictionary
	var transforms := authored.get("hazard:4.720:0.027:0.090", []) as Array
	var exact := batch != null and batch.multimesh != null and batch.multimesh.instance_count == 10
	for expected in expected_thresholds:
		var found := false
		for transform_variant in transforms:
			if (transform_variant as Transform3D).is_equal_approx(expected as Transform3D):
				found = true
				break
		exact = exact and found
	_check(
		exact,
		"two flush amber threshold bars align the inbound route with its portal inside the existing collisionless cross-mark batch"
	)


func _test_material_rack_batch(annex: FabricationAnnex) -> void:
	var rack_batch := annex.find_child("MaterialRackBatch", true, false) as MultiMeshInstance3D
	var expected_positions := [
		Vector3(-10.6, 1.1, 7.0), Vector3(-10.6, 1.1, 15.0),
		Vector3(10.6, 1.1, 7.0), Vector3(10.6, 1.1, 15.0),
	]
	var visible_poses_exact := rack_batch != null and rack_batch.multimesh != null \
		and rack_batch.multimesh.instance_count == expected_positions.size()
	if visible_poses_exact:
		var render_buffer := RenderingServer.multimesh_get_buffer(rack_batch.multimesh.get_rid())
		visible_poses_exact = render_buffer.size() == expected_positions.size() * 12
		for index in expected_positions.size():
			var offset := index * 12
			var expected := expected_positions[index] as Vector3
			visible_poses_exact = visible_poses_exact \
				and is_equal_approx(render_buffer[offset + 0], 1.0) \
				and is_zero_approx(render_buffer[offset + 1]) \
				and is_zero_approx(render_buffer[offset + 2]) \
				and is_equal_approx(render_buffer[offset + 3], expected.x) \
				and is_zero_approx(render_buffer[offset + 4]) \
				and is_equal_approx(render_buffer[offset + 5], 1.0) \
				and is_zero_approx(render_buffer[offset + 6]) \
				and is_equal_approx(render_buffer[offset + 7], expected.y) \
				and is_zero_approx(render_buffer[offset + 8]) \
				and is_zero_approx(render_buffer[offset + 9]) \
				and is_equal_approx(render_buffer[offset + 10], 1.0) \
				and is_equal_approx(render_buffer[offset + 11], expected.z)
	var rack_bodies := annex.find_children("MaterialRack*", "StaticBody3D", true, false)
	var structure_reference := annex.find_child("RoofColumnBatch", true, false) as MultiMeshInstance3D
	var render_state_exact := rack_batch != null and rack_batch.multimesh != null \
		and rack_batch.multimesh.mesh != null \
		and rack_batch.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(0.8, 2.2, 2.4)) \
		and structure_reference != null \
		and rack_batch.material_override == structure_reference.material_override \
		and rack_batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		and is_zero_approx(rack_batch.visibility_range_begin) \
		and is_zero_approx(rack_batch.visibility_range_end)
	var collision_exact := rack_bodies.size() == expected_positions.size()
	for index in mini(rack_bodies.size(), expected_positions.size()):
		var body := rack_bodies[index] as StaticBody3D
		var shape_node := body.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := shape_node.shape as BoxShape3D if shape_node != null else null
		collision_exact = collision_exact \
			and body.position.is_equal_approx(expected_positions[index] as Vector3) \
			and shape != null and shape.size.is_equal_approx(Vector3(0.8, 2.2, 2.4)) \
			and body.find_children("*", "MeshInstance3D", false, false).is_empty()
	print("FABRICATION_MATERIAL_RACK_BATCH: batch=%s copies=%d poses=%s render=%s bodies=%d collision=%s" % [
		rack_batch != null,
		rack_batch.multimesh.instance_count if rack_batch != null and rack_batch.multimesh != null else 0,
		visible_poses_exact,
		render_state_exact,
		rack_bodies.size(),
		collision_exact,
	])
	_check(
		visible_poses_exact and collision_exact,
		"four material racks keep exact visible poses and physical collision while one batch replaces four renderer nodes"
	)
	_check(render_state_exact, "the rack batch retains the exact 0.8 x 2.2 x 2.4 m rounded box, station-structure material, shadows, and unbounded visibility")


func _test_observation_gate_variant(stage: Node3D) -> void:
	var gate_annex := ANNEX_SCENE.instantiate() as FabricationAnnex
	gate_annex.observation_rear_gate_open = true
	stage.add_child(gate_annex)
	await process_frame
	var performance := gate_annex.get_performance_contract()
	_check(
		int(performance.mesh_instances) == 3
		and int(performance.multi_mesh_instances) == 32
		and int(performance.visible_geometry_copies) == 206
		and int(performance.nodes) == 123,
		"the integrated Observation-gate variant retains its exact finished rendering budget"
	)
	_check(bool(gate_annex.get_audit_report().valid), "the finished Observation-gate variant retains its production integration contract")
	gate_annex.queue_free()
	await process_frame


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

	var live_snapshot := _lifecycle_snapshot(annex)
	var stage := annex.get_parent()
	stage.remove_child(annex)
	annex.set_module_enabled(false)
	_check(
		_lifecycle_snapshot(annex) == live_snapshot,
		"detached direct disable leaves retained enabled, visibility, and collision state unchanged"
	)
	stage.add_child(annex)
	await process_frame
	annex.set_module_enabled(false)
	_check(
		not annex.is_module_enabled()
		and bool(annex.get_lifecycle_contract().visible_matches_enabled)
		and bool(annex.get_lifecycle_contract().collision_matches_enabled),
		"re-added annex accepts a fresh live disable"
	)
	annex.set_module_enabled(true)
	_check(
		_lifecycle_snapshot(annex) == live_snapshot,
		"fresh live re-enable restores the retained enabled, visibility, and collision state"
	)
	annex.queue_free()
	annex.set_module_enabled(false)
	_check(
		_lifecycle_snapshot(annex) == live_snapshot,
		"queued direct disable leaves retained enabled, visibility, and collision state unchanged"
	)


func _lifecycle_snapshot(annex: FabricationAnnex) -> Dictionary:
	var body_states: Array[Dictionary] = []
	for raw_body in StationModuleContract.collect_static_bodies(annex):
		var body := raw_body as StaticBody3D
		body_states.append({
			"path": annex.get_path_to(body),
			"visible": body.visible,
			"collision_layer": body.collision_layer,
			"collision_mask": body.collision_mask,
		})
	body_states.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first.path) < str(second.path)
	)
	var generated := annex.get_node_or_null(^"GeneratedAnnex") as Node3D
	return {
		"enabled": annex.is_module_enabled(),
		"generated_visible": generated.visible if generated != null else false,
		"body_states": body_states,
	}.duplicate(true)


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
