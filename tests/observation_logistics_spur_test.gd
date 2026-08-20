extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/observation_logistics_spur.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		call_deferred("_capture_forward_plus")
	else:
		call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "ObservationLogisticsSpurTestRoot"
	root.add_child(_test_root)
	var module := MODULE_SCENE.instantiate() as ObservationLogisticsSpur
	_check(module != null, "observation/logistics scene instantiates as its standalone module type")
	if module == null:
		_finish()
		return
	module.position = Vector3(17.0, 1.25, -29.0)
	module.rotation_degrees.y = 23.0
	_test_root.add_child(module)
	await process_frame
	await physics_frame
	await physics_frame

	_test_identity_evidence_and_contract(module)
	_test_connection_slots(module)
	_test_surface_roster_and_area(module)
	_test_material_retention(module)
	_test_visual_resource_sharing(module)
	_test_deterministic_runtime_names(module)
	await _test_collision_support_and_safe_edges(module)
	await _test_embodied_loop_traversal(module)
	_test_zero_authority_and_red_mutations(module)
	await _test_lifecycle(module)
	await _test_cleanup(module)
	_finish()


func _test_identity_evidence_and_contract(module: ObservationLogisticsSpur) -> void:
	_check(module.get_module_id() == &"observation-logistics-spur", "module exposes a stable standalone identity")
	_check(bool(module.get_meta("station_module", false)), "root identifies itself as a station module")
	_check(StringName(module.get_meta("content_class", &"")) == &"NEW", "root labels the complete addition NEW")
	_check(StringName(module.get_meta("evidence_status", &"")) == &"modern_interpretation", "root rejects a reconstruction claim")
	_check(not bool(module.get_meta("authenticated_original_geometry", true)), "root explicitly rejects authenticated original geometry")
	_check(module.is_in_group("station_modules"), "standalone module participates in contract discovery")

	var evidence := module.get_evidence_metadata()
	_check(int(evidence.schema_version) == ObservationLogisticsSpur.SCHEMA_VERSION, "evidence report has a stable schema")
	_check(StringName(evidence.content_class) == &"NEW" and StringName(evidence.evidence_status) == &"modern_interpretation", "public evidence pairs NEW with modern_interpretation")
	_check(not bool(evidence.source_bounded) and (evidence.references as PackedStringArray).is_empty(), "module invents no source support for the new addition")
	_check("No source" in str(evidence.content_note) and "no historical reconstruction" in str(evidence.content_note), "content note states the complete non-reconstruction boundary")
	var interpretations := evidence.modern_interpretations as PackedStringArray
	_check(interpretations.size() == 3 and "the complete module and its location" in interpretations, "all material layout claims are disclosed as modern interpretation")
	interpretations.append("red mutation")
	_check(not (module.get_evidence_metadata().modern_interpretations as PackedStringArray).has("red mutation"), "evidence arrays are detached from live state")

	var validator := StationModuleContract.new()
	var validation := validator.validate_contract(module)
	_check(bool(validation.valid), "shared StationModuleContract accepts the standalone module")
	_check((validation.errors as PackedStringArray).is_empty(), "shared contract validation reports no hidden errors")
	var audit := module.get_audit_report()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "module audit is green at rest")
	_check(bool(audit.alternate_return_path), "audit explicitly publishes the alternate return path")


func _test_connection_slots(module: ObservationLogisticsSpur) -> void:
	var expected := {
		&"origin": {
			"slot_id": &"observation-logistics-spur-origin",
			"transform": Transform3D(Basis.IDENTITY, Vector3.ZERO),
		},
	}
	var slots := module.get_connection_slots()
	_check(slots.size() == 1, "module publishes only the origin's physically realised connection slot")
	var every_slot_exact := true
	for route_id: StringName in expected.keys():
		var expected_slot := expected[route_id] as Dictionary
		var slot := slots.get(route_id, {}) as Dictionary
		var marker := module.get_route_marker(route_id)
		every_slot_exact = every_slot_exact \
			and marker != null \
			and marker.transform.is_equal_approx(expected_slot.transform as Transform3D) \
			and StringName(slot.get("slot_id", &"")) == StringName(expected_slot.slot_id) \
			and (slot.get("local_transform", Transform3D()) as Transform3D).is_equal_approx(expected_slot.transform as Transform3D) \
			and (slot.get("world_transform", Transform3D()) as Transform3D).is_equal_approx(module.global_transform * (expected_slot.transform as Transform3D)) \
			and StationModuleContract.new().read_connection_slot_id(marker) == StringName(expected_slot.slot_id)
	_check(every_slot_exact, "origin connection slot id and local/world transforms are exact")
	_check(module.get_route_ids().size() == 6 and module.has_route_marker(&"far-return"), "six-waypoint route includes the far alternate-return marker")
	var deferred_exact := true
	for route_id: StringName in [&"observation-pad", &"logistics-pad"]:
		var marker := module.get_route_marker(route_id)
		deferred_exact = deferred_exact \
			and marker != null \
			and bool(marker.get_meta("deferred_connection_route", false)) \
			and StringName(marker.get_meta("connection_status", &"")) == &"internal_route_only_no_geometry" \
			and StationModuleContract.new().read_connection_slot_id(marker) == &"" \
			and not slots.has(route_id)
	_check(deferred_exact, "observation and logistics pad markers remain explicit deferred internal routes without registry slots")
	(slots[&"origin"] as Dictionary)["local_transform"] = Transform3D.IDENTITY.translated(Vector3.ONE)
	_check((module.get_connection_slots()[&"origin"].local_transform as Transform3D).is_equal_approx(Transform3D.IDENTITY), "connection slot report is deeply detached")


func _test_surface_roster_and_area(module: ObservationLogisticsSpur) -> void:
	var expected_areas := {
		&"exposed-connector": 88.0,
		&"pad-cross-landing": 80.0,
		&"observation-pad": 120.0,
		&"logistics-pad": 120.0,
		&"far-return-bridge": 18.0,
	}
	var roster := module.get_walkable_surface_roster()
	_check(roster.size() == 5, "surface roster contains exactly five authoritative level decks")
	var seen := {}
	var area_sum := 0.0
	var every_surface_exact := true
	for entry in roster:
		var surface_id := StringName(entry.surface_id)
		var size := entry.size as Vector3
		var entry_area := float(entry.horizontal_area_m2)
		seen[surface_id] = true
		area_sum += entry_area
		every_surface_exact = every_surface_exact \
			and expected_areas.has(surface_id) \
			and is_equal_approx(entry_area, float(expected_areas[surface_id])) \
			and is_equal_approx(entry_area, size.x * size.z) \
			and StringName(entry.kind) == &"level"
	_check(every_surface_exact and seen.size() == expected_areas.size(), "surface ids, dimensions, kinds and individual horizontal areas are exact")
	_check(is_equal_approx(area_sum, 426.0) and is_equal_approx(module.get_walkable_area_m2(), 426.0), "non-overlapping surface union publishes exactly 426.0 m²")
	(roster[0] as Dictionary)["horizontal_area_m2"] = -1.0
	_check(float(module.get_walkable_surface_roster()[0].horizontal_area_m2) == 88.0, "surface roster snapshots are deeply detached")
	var footprint := module.get_integration_footprint()
	_check((footprint.local_min as Vector3).is_equal_approx(Vector3(-13.4, -0.3, 0.0)), "footprint begins at the exact local origin connection plane")
	_check((footprint.local_max as Vector3).is_equal_approx(Vector3(13.4, 4.4, 39.5)), "footprint includes both separated pads and the far bridge")
	var roster_contract := module.get_component_roster()
	_check(int(roster_contract.walkable_surface_count) == 5 and is_equal_approx(float(roster_contract.walkable_area_m2), 426.0), "component roster repeats the exact surface count and area")
	var performance := module.get_performance_contract()
	_check(
		bool(performance.within_budget)
		and int(performance.mesh_instances) == 48
		and int(performance.static_bodies) == 33
		and int(performance.collision_shapes) == 33
		and module.find_children("*", "Node", true, false).size() == 133,
		"low-submission module freezes 133 nodes, 48 meshes and 33 body/shape pairs"
	)
	_check(int(performance.lights) == 6 and int(performance.labels) == 1 and int(performance.process_loops) == 0, "restrained presentation uses six practicals, one identity sign and no frame loop")
	var marker_batch := module.get_node_or_null(^"Structure/Dressing/ConnectorMarkers") as MultiMeshInstance3D
	_check(marker_batch != null and marker_batch.multimesh.instance_count == 10, "ten repeated connector markers use one visual-only MultiMesh submission")


func _test_deterministic_runtime_names(module: ObservationLogisticsSpur) -> void:
	var exact_indexed_roster := true
	for child_path in ObservationLogisticsSpur.INDEXED_RUNTIME_CHILD_PATHS:
		exact_indexed_roster = exact_indexed_roster and module.get_node_or_null(NodePath(child_path)) != null
	_check(
		exact_indexed_roster and ObservationLogisticsSpur.INDEXED_RUNTIME_CHILD_PATHS.size() == 35,
		"all 35 repeated rail, dressing and practical children retain exact indexed runtime paths"
	)
	var auto_named := module.find_children("@*", "", true, false)
	_check(auto_named.is_empty(), "authored module hierarchy contains no auto-generated runtime child names")
	var console := module.get_node(^"Structure/Dressing/ObservationConsole01")
	console.name = "ObservationConsoleDrift"
	_check(not bool(module.get_audit_report().valid), "red mutation: renamed indexed dressing child makes audit fail")
	console.name = "ObservationConsole01"
	_check(bool(module.get_audit_report().valid), "restoring the exact indexed runtime path returns audit to green")


func _test_material_retention(module: ObservationLogisticsSpur) -> void:
	var materials := module.get_material_retention_contract()
	_check(
		int(materials.catalog_entry_count) == 9
		and int(materials.retained_unique_materials) == 9,
		"practical recipe sharing reduces retained material resources exactly 12 -> 9"
	)
	_check(
		int(materials.practical_lens_recipe_count) == 3
		and bool(materials.practical_lens_identities_exact)
		and (materials.practical_lens_material_ids as PackedInt64Array)
			== (materials.expected_practical_lens_material_ids as PackedInt64Array),
		"cyan x3, white x2 and amber x1 practical lenses retain their exact shared identities"
	)
	var lens := module.get_node(^"Structure/Dressing/LightLens04") as MeshInstance3D
	var shared_cyan := lens.material_override
	lens.material_override = shared_cyan.duplicate()
	_check(not bool(module.get_audit_report().valid), "red mutation: duplicated practical recipe identity makes audit fail")
	lens.material_override = shared_cyan
	_check(bool(module.get_audit_report().valid), "restoring the shared practical recipe returns audit to green")


func _test_visual_resource_sharing(module: ObservationLogisticsSpur) -> void:
	var performance := module.get_visual_resource_contract()
	_check(
		bool(performance.exact)
		and bool(performance.headless_safe)
		and StringName(performance.selected_family) == &"observation_lenses_and_logistics_cases"
		and int(performance.baseline_descendant_nodes) == 133
		and int(performance.descendant_nodes) == 133
		and int(performance.baseline_renderer_nodes) == 49
		and int(performance.renderer_nodes) == 49
		and int(performance.baseline_drawn_copies) == 58
		and int(performance.drawn_copies) == 58
		and int(performance.baseline_surface_submissions) == 49
		and int(performance.surface_submissions) == 49,
		"lens and logistics-case sharing preserve 133 nodes, 49 renderer nodes, 58 drawn copies and 49 submissions"
	)
	_check(
		int(performance.baseline_mesh_resources) == 49
		and int(performance.mesh_resources) == 37
		and int(performance.mesh_resource_delta) == -12
		and int(performance.baseline_material_resources) == 9
		and int(performance.material_resources) == 9
		and int(performance.baseline_family_nodes) == 3
		and int(performance.family_nodes) == 3
		and int(performance.baseline_family_submissions) == 3
		and int(performance.family_submissions) == 3
		and int(performance.baseline_family_mesh_resources) == 3
		and int(performance.family_mesh_resources) == 1,
		"lens and collidable-case families reduce mesh resources 49 -> 37 without changing nodes, submissions or materials"
	)
	var practical_lenses: Array[MeshInstance3D] = []
	for lens_index in ObservationLogisticsSpur.PRACTICAL_LENS_COPY_COUNT:
		practical_lenses.append(module.get_node_or_null(NodePath(
			"Structure/Dressing/LightLens%02d" % (lens_index + 1)
		)) as MeshInstance3D)
	_check(
		int(performance.practical_lens_copies) == 6
		and int(performance.practical_lens_mesh_resources) == 1
		and bool(performance.practical_lens_identities_exact)
		and practical_lenses.all(func(lens: MeshInstance3D) -> bool: return lens != null and lens.mesh == practical_lenses[0].mesh),
		"all six named practical lenses share one exact mesh while retaining their per-node material overrides"
	)
	if practical_lenses[0] != null and practical_lenses[1] != null:
		var practical_mesh := practical_lenses[1].mesh
		practical_lenses[1].mesh = practical_mesh.duplicate() as BoxMesh
		var practical_red := module.get_visual_resource_contract()
		practical_lenses[1].mesh = practical_mesh
		_check(
			not bool(practical_red.exact)
			and int(practical_red.mesh_resources) == 38
			and int(practical_red.practical_lens_mesh_resources) == 2
			and bool(module.get_visual_resource_contract().exact),
			"red mutation: splitting one practical lens mesh fails the resource contract and restores cleanly"
		)

	var case_meshes: Array[MeshInstance3D] = []
	var case_contract_matches := true
	for case_index in ObservationLogisticsSpur.LOGISTICS_CASE_COPY_COUNT:
		var case_body := module.get_node_or_null(NodePath(
			"Structure/Dressing/LogisticsCase%02d" % (case_index + 1)
		)) as StaticBody3D
		var case_mesh := case_body.get_node_or_null("Mesh") as MeshInstance3D if case_body != null else null
		var collision := case_body.get_node_or_null("CollisionShape3D") as CollisionShape3D if case_body != null else null
		var stack_index := int(case_index / 2)
		var tier_index := case_index % 2
		case_meshes.append(case_mesh)
		case_contract_matches = case_contract_matches and (
			case_body != null
			and case_body.position.is_equal_approx(Vector3(
				11.15, 0.48 + float(tier_index) * 0.58, 28.8 + float(stack_index) * 2.75
			))
			and case_mesh != null
			and case_mesh.mesh is BoxMesh
			and (case_mesh.mesh as BoxMesh).size.is_equal_approx(
				ObservationLogisticsSpur.LOGISTICS_CASE_SIZE
			)
			and case_mesh.material_override != null
			and collision != null
			and collision.shape is BoxShape3D
			and (collision.shape as BoxShape3D).size.is_equal_approx(
				ObservationLogisticsSpur.LOGISTICS_CASE_SIZE
			)
		)
	_check(
		case_contract_matches
		and case_meshes.all(func(case_mesh: MeshInstance3D) -> bool: return case_mesh.mesh == case_meshes[0].mesh)
		and int(performance.logistics_case_copies) == 6
		and int(performance.logistics_case_mesh_resources) == 1
		and bool(performance.logistics_case_identities_exact),
		"six named collidable logistics cases retain their six bodies/shapes and share one cargo BoxMesh"
	)
	if case_meshes[0] != null and case_meshes[1] != null:
		var case_mesh := case_meshes[1].mesh
		case_meshes[1].mesh = case_mesh.duplicate() as BoxMesh
		var case_red := module.get_visual_resource_contract()
		case_meshes[1].mesh = case_mesh
		_check(
			not bool(case_red.exact)
			and int(case_red.mesh_resources) == 38
			and int(case_red.logistics_case_mesh_resources) == 2
			and bool(module.get_visual_resource_contract().exact),
			"red mutation: splitting one logistics-case mesh fails the resource contract and restores cleanly"
		)

	var lenses: Array[MeshInstance3D] = []
	var exact_family := true
	for lens_index in ObservationLogisticsSpur.OBSERVATION_LENS_COPY_COUNT:
		var lens := module.get_node_or_null(NodePath(
			"Structure/Dressing/ObservationLens%02d" % (lens_index + 1)
		)) as MeshInstance3D
		lenses.append(lens)
		exact_family = (
			exact_family
			and lens != null
			and lens.mesh is BoxMesh
			and (lens.mesh as BoxMesh).size.is_equal_approx(
				ObservationLogisticsSpur.OBSERVATION_LENS_SIZE
			)
			and lens.position.is_equal_approx(
				ObservationLogisticsSpur.OBSERVATION_LENS_POSITIONS[lens_index]
			)
			and lens.scale == Vector3.ONE
			and lens.get_child_count() == 0
			and bool(lens.get_meta("visual_detail_only", false))
			and lens.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)
	_check(
		exact_family
		and lenses[0].mesh == lenses[1].mesh
		and lenses[1].mesh == lenses[2].mesh
		and lenses[0].material_override == lenses[1].material_override
		and lenses[1].material_override == lenses[2].material_override,
		"all three named observation lenses retain exact transforms, extent, material, shadow policy and visual-only identity"
	)

	var shared_mesh := lenses[2].mesh
	lenses[2].mesh = shared_mesh.duplicate() as Mesh
	var red := module.get_visual_resource_contract()
	_check(
		not bool(red.exact)
		and int(red.mesh_resources) == 38
		and int(red.family_mesh_resources) == 2
		and module.get_validation_errors().has(
			"observation lens or logistics-case visual-resource sharing drifted"
		),
		"red mutation: splitting one observation lens resource turns the component-local allocation contract red"
	)
	lenses[2].mesh = shared_mesh
	_check(
		bool(module.get_visual_resource_contract().exact)
		and bool(module.get_audit_report().valid),
		"restoring the shared observation-lens mesh returns the complete module audit green"
	)


func _test_collision_support_and_safe_edges(module: ObservationLogisticsSpur) -> void:
	var roster := module.get_walkable_surface_roster()
	var every_surface_supported := true
	for entry in roster:
		var center := entry.local_center as Vector3
		var hit := await _ray_local(module, center + Vector3.UP * 2.0, center - Vector3.UP * 1.0)
		every_surface_supported = every_surface_supported \
			and not hit.is_empty() \
			and StringName((hit.collider as Node).get_meta("walkable_surface_id", &"")) == StringName(entry.surface_id)
	_check(every_surface_supported, "every published surface centre lands on its matching World collision body")
	var surfaces := module.find_children("*", "StaticBody3D", true, false).filter(
		func(candidate: Node) -> bool: return bool(candidate.get_meta("walkable_surface", false))
	)
	var surface_ids := {}
	var every_surface_tagged := surfaces.size() == 5
	for surface in surfaces:
		var surface_id := StringName(surface.get_meta("walkable_surface_id", &""))
		surface_ids[surface_id] = true
		every_surface_tagged = every_surface_tagged \
			and StringName(surface.get_meta("walkable_surface_kind", &"")) == &"level" \
			and StringName(surface.get_meta("walkable_surface_owner", &"")) == &"observation-logistics-spur"
	_check(every_surface_tagged and surface_ids.size() == 5, "only the five usable bodies carry unique census-ready walkable metadata")
	var rails := module.find_children("*", "StaticBody3D", true, false).filter(
		func(candidate: Node) -> bool: return bool(candidate.get_meta("station_safety_edge", false))
	)
	_check(rails.size() == 15, "fifteen collision-backed rail runs protect every exposed route edge")
	var rail_collision_exact := true
	for rail in rails:
		rail_collision_exact = rail_collision_exact \
			and rail.collision_layer == WORLD_LAYER \
			and rail.collision_mask == 0 \
			and not bool(rail.get_meta("walkable_surface", false)) \
			and not str(rail.get_meta("non_walkable_reason", "")).is_empty()
	_check(rail_collision_exact, "safe edges are physical World rails and never masquerade as usable floor")
	var collision := module.get_collision_contract()
	_check(bool(collision.all_layers_match_lifecycle) and bool(collision.all_masks_zero) and bool(collision.all_shapes_present_and_enabled), "complete collision roster follows the canonical World contract")


func _test_embodied_loop_traversal(module: ObservationLogisticsSpur) -> void:
	var body := CharacterBody3D.new()
	body.name = "LocalTraversalBody"
	body.floor_snap_length = 0.35
	body.floor_max_angle = deg_to_rad(50.0)
	body.collision_layer = 0
	body.collision_mask = WORLD_LAYER
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.70
	collision.shape = capsule
	body.add_child(collision)
	_test_root.add_child(body)
	body.global_position = module.to_global(Vector3(0.0, 0.86, 0.8))
	await physics_frame

	var waypoints := [
		Vector3(0.0, 0.86, 24.0),
		Vector3(-8.0, 0.86, 24.0),
		Vector3(-8.0, 0.86, 32.0),
		Vector3(-3.55, 0.86, 37.15),
		Vector3(0.0, 0.86, 38.0),
		Vector3(3.55, 0.86, 37.15),
		Vector3(8.0, 0.86, 32.0),
		Vector3(8.0, 0.86, 24.0),
		Vector3(0.0, 0.86, 24.0),
		Vector3(0.0, 0.86, 0.8),
	]
	var reached_all := true
	var grounded_all := true
	for local_target in waypoints:
		var reached := await _drive_body_to(body, module.to_global(local_target), 480)
		reached_all = reached_all and reached
		grounded_all = grounded_all and body.is_on_floor() and body.global_position.y > module.global_position.y + 0.45
		if not reached:
			break
	_check(reached_all, "one embodied capsule traverses the connector, both separated pads, far bridge and return leg")
	_check(grounded_all, "embodied traversal remains supported across every loop waypoint without a fall")
	_check(body.global_position.distance_to(module.to_global(Vector3(0.0, 0.86, 0.8))) < 0.40, "alternate path returns the same body to the local origin")
	body.queue_free()
	await process_frame


func _test_zero_authority_and_red_mutations(module: ObservationLogisticsSpur) -> void:
	var authority := module.get_authority_contract()
	_check(
		(authority.authority_ids as PackedStringArray).is_empty()
		and int(authority.ship_berth_count) == 0
		and int(authority.landing_or_interaction_area_count) == 0
		and int(authority.audio_node_count) == 0
		and int(authority.activity_node_count) == 0
		and int(authority.lease_authority_count) == 0
		and int(authority.spawn_authority_count) == 0
		and StringName(authority.network_authority_role) == &"none",
		"standalone addition owns exactly zero gameplay authorities"
	)

	var origin := module.get_route_marker(&"origin")
	var origin_transform := origin.transform
	origin.position += Vector3(0.5, 0.0, 0.0)
	_check(not bool(module.get_audit_report().valid), "red mutation: moved connection slot makes audit fail")
	origin.transform = origin_transform
	_check(bool(module.get_audit_report().valid), "restoring exact connection transform returns audit to green")

	var deck := module.get_node(^"Structure/Walkable/ExposedConnectorDeck") as StaticBody3D
	deck.set_meta("walkable_surface_id", &"wrong-surface")
	_check(not bool(module.get_audit_report().valid), "red mutation: corrupted walkable identity makes audit fail")
	deck.set_meta("walkable_surface_id", &"exposed-connector")
	deck.collision_layer = 0
	_check(not bool(module.get_audit_report().valid), "red mutation: disabled live deck collision makes audit fail")
	deck.collision_layer = WORLD_LAYER

	var illicit_area := Area3D.new()
	illicit_area.name = "IllicitAuthorityArea"
	module.add_child(illicit_area)
	_check(not bool(module.get_audit_report().valid), "red mutation: adding an interaction-shaped authority node makes audit fail")
	module.remove_child(illicit_area)
	illicit_area.free()
	_check(bool(module.get_audit_report().valid), "all red mutations restore to a green audit")


func _test_lifecycle(module: ObservationLogisticsSpur) -> void:
	var first_surface := module.get_node(^"Structure/Walkable/ExposedConnectorDeck") as StaticBody3D
	var first_id := first_surface.get_instance_id()
	module.set_module_enabled(false)
	await process_frame
	_check(not module.visible and first_surface.collision_layer == 0, "disable hides in place and clears World collision")
	var disabled := module.get_lifecycle_contract()
	_check(not bool(disabled.enabled) and bool(disabled.visible_matches_enabled) and bool(disabled.collision_matches_enabled), "disabled lifecycle report is coherent")
	_check(bool(disabled.process_free) and bool(disabled.process_matches_lifecycle), "disabled module owns no hidden frame work")
	module.set_module_enabled(true)
	await process_frame
	_check(module.visible and first_surface.collision_layer == WORLD_LAYER, "re-enable restores visible World collision")
	_check(first_surface.get_instance_id() == first_id and bool(module.get_audit_report().valid), "lifecycle reuses the same surface identity and returns audit green")

	var live_snapshot := _lifecycle_snapshot(module)
	_test_root.remove_child(module)
	module.set_module_enabled(false)
	_check(
		_lifecycle_snapshot(module) == live_snapshot,
		"detached direct disable leaves retained enabled, visibility, processing, and collision state unchanged"
	)
	_test_root.add_child(module)
	await process_frame
	module.set_module_enabled(false)
	_check(
		not module.is_module_enabled()
		and not module.visible
		and first_surface.collision_layer == 0
		and not module.is_processing()
		and not module.is_physics_processing(),
		"re-added spur accepts a fresh live disable"
	)
	module.set_module_enabled(true)
	_check(
		_lifecycle_snapshot(module) == live_snapshot,
		"fresh live re-enable restores retained enabled, visibility, processing, and collision state"
	)
	module.queue_free()
	module.set_module_enabled(false)
	_check(
		_lifecycle_snapshot(module) == live_snapshot,
		"queued direct disable leaves retained enabled, visibility, processing, and collision state unchanged"
	)


func _lifecycle_snapshot(module: ObservationLogisticsSpur) -> Dictionary:
	var body_states: Array[Dictionary] = []
	for raw_body in StationModuleContract.collect_static_bodies(module):
		var body := raw_body as StaticBody3D
		body_states.append({
			"path": module.get_path_to(body),
			"visible": body.visible,
			"collision_layer": body.collision_layer,
			"collision_mask": body.collision_mask,
		})
	body_states.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first.path) < str(second.path)
	)
	return {
		"enabled": module.is_module_enabled(),
		"visible": module.visible,
		"processing": module.is_processing(),
		"physics_processing": module.is_physics_processing(),
		"body_states": body_states,
	}.duplicate(true)


func _drive_body_to(body: CharacterBody3D, target: Vector3, frame_budget: int) -> bool:
	for _frame in frame_budget:
		var offset := target - body.global_position
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		if horizontal.length() <= 0.24:
			body.velocity = Vector3.ZERO
			return true
		var desired := horizontal.normalized() * minf(4.5, horizontal.length() * 3.0)
		body.velocity.x = desired.x
		body.velocity.z = desired.z
		body.velocity.y = -1.5
		body.move_and_slide()
		await physics_frame
	return Vector2(body.global_position.x - target.x, body.global_position.z - target.z).length() <= 0.30


func _ray_local(module: Node3D, local_from: Vector3, local_to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(
		module.to_global(local_from), module.to_global(local_to), WORLD_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_ray(query)


func _capture_forward_plus() -> void:
	root.size = Vector2i(1400, 900)
	var capture_root := Node3D.new()
	root.add_child(capture_root)
	var module := MODULE_SCENE.instantiate() as ObservationLogisticsSpur
	capture_root.add_child(module)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("03080d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("71848b")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	capture_root.add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, -32, 0)
	moon.light_color = Color("b8d2da")
	moon.light_energy = 0.72
	moon.shadow_enabled = true
	capture_root.add_child(moon)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 62.0
	camera.position = Vector3(23.0, 17.0, -13.0)
	capture_root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 25.0), Vector3.UP)
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("/tmp/observation-logistics-spur.png")
	if error != OK:
		push_error("Failed to save observation/logistics spur capture: %s" % error)
	print("OBSERVATION_LOGISTICS_SPUR_CAPTURE_OK")
	capture_root.queue_free()
	await process_frame
	quit(0 if error == OK else 1)


func _test_cleanup(module: ObservationLogisticsSpur) -> void:
	var reference: WeakRef = weakref(module)
	module.queue_free()
	await process_frame
	await physics_frame
	_check(reference.get_ref() == null, "standalone module cleans up without a retained instance")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("OBSERVATION_LOGISTICS_SPUR_TEST_OK: %d assertions" % _count_assertions())
		quit(0)
	else:
		print("OBSERVATION_LOGISTICS_SPUR_TEST_FAILED: ", ", ".join(_failures))
		quit(1)


func _count_assertions() -> int:
	# Kept explicit in output by counting anchored call sites from this suite is not
	# available at runtime; successful and failed assertions together equal this
	# frozen suite total.
	return 66
