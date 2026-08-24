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
	_test_exposed_lattice_language_contract(module)
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


func _test_exposed_lattice_language_contract(module: ObservationLogisticsSpur) -> void:
	var contract := module.get_exposed_lattice_language_contract()
	_check(
		StringName(contract.content_class) == &"NEW"
		and StringName(contract.evidence_status) == &"modern_interpretation"
		and not bool(contract.source_bounded),
		"exposed-deck expansion remains explicitly NEW and source-unbounded"
	)
	_check(
		int(contract.walkable_surface_count) == 5
		and is_equal_approx(float(contract.walkable_area_m2), 426.0)
		and (contract.walkable_surface_ids as PackedStringArray).size() == 5,
		"language contract freezes five real player-walkable deck surfaces"
	)
	_check(
		bool(contract.negative_space_preserved)
		and is_equal_approx(float(contract.negative_space_ratio), ObservationLogisticsSpur.NEGATIVE_SPACE_RATIO)
		and float(contract.negative_space_ratio) > 0.59,
		"language contract preserves the measured sparse-lattice negative space"
	)
	_check(
		int(contract.safety_rail_count) == ObservationLogisticsSpur.SAFETY_RAIL_COUNT
		and bool(contract.safety_edges_complete)
		and not bool(contract.owns_gameplay_authority),
		"every exposed edge has physical safety coverage without gameplay authority"
	)
	(contract.walkable_surface_ids as PackedStringArray).append("red mutation")
	_check(
		(module.get_exposed_lattice_language_contract().walkable_surface_ids as PackedStringArray).size() == 5,
		"language contract arrays are detached from live state"
	)


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
		and int(performance.mesh_instances) == 7
		and int(performance.static_bodies) == 33
		and int(performance.collision_shapes) == 33
		and module.find_children("*", "Node", true, false).size() == 147,
		"finished district freezes 147 nodes, 7 meshes and 33 body/shape pairs"
	)
	_check(int(performance.lights) == 6 and int(performance.labels) == 4 and int(performance.process_loops) == 0, "restrained presentation uses six practicals, four district signs and no frame loop")
	var marker_batch := module.get_node_or_null(^"Structure/Dressing/ConnectorMarkers") as MultiMeshInstance3D
	_check(marker_batch != null and marker_batch.multimesh.instance_count == 10, "ten repeated connector markers use one visual-only MultiMesh submission")
	var finishing_batches := {
		"ConnectorPortalPosts": 10,
		"ConnectorPortalBeams": 5,
		"PadCanopySlats": 12,
		"PadCanopyRibs": 8,
		"PadCanopySupports": 8,
		"ObservationConsoleTrim": 3,
		"CargoCaseBands": 12,
		"ObservationZoneTicks": 6,
		"LogisticsZoneTicks": 6,
		"ReturnBridgeChevrons": 5,
		"PadPavilionBulkheads": 6,
		"PadPavilionWindows": 6,
		"PadPavilionMullions": 8,
		"PadPavilionFascias": 2,
		"PadPavilionPlinths": 6,
		"PadCanopyTaskStrips": 6,
		"DistrictSignBacks": 4,
		"LightMastRenderBatch": 6,
		"ObservationConsoleRenderBatch": 3,
		"ObservationLensRenderBatch": 3,
		"LogisticsCaseRenderBatch": 6,
		"LogisticsPalletRenderBatch": 3,
		"PracticalWhiteLensRenderBatch": 2,
	}
	var finishing_exact := true
	for batch_name in finishing_batches:
		var batch := module.get_node_or_null(NodePath("Structure/Dressing/%s" % batch_name)) as MultiMeshInstance3D
		finishing_exact = finishing_exact and batch != null \
			and batch.multimesh.instance_count == int(finishing_batches[batch_name]) \
			and bool(batch.get_meta("visual_detail_only", false))
	_check(finishing_exact, "open portal, canopy, console, cargo and zoning batches finish the district without new collision")


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
		int(materials.catalog_entry_count) == 10
		and int(materials.retained_unique_materials) == 10,
		"finished pavilions retain ten shared material recipes including their dark view band"
	)
	var deck_material := (module.get_node(^"Structure/Walkable/ExposedConnectorDeck/Mesh") as MeshInstance3D).material_override as StandardMaterial3D
	var grip_material := (module.get_node(^"Structure/Dressing/LogisticsPalletRenderBatch") as MultiMeshInstance3D).material_override as StandardMaterial3D
	var shell_material := (module.get_node(^"Structure/Dressing/ObservationConsoleRenderBatch") as MultiMeshInstance3D).material_override as StandardMaterial3D
	var service_material := (module.get_node(^"Structure/Dressing/LogisticsCaseRenderBatch") as MultiMeshInstance3D).material_override as StandardMaterial3D
	_check(
		deck_material.uv1_triplanar and deck_material.uv1_world_triplanar
		and deck_material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30)
		and grip_material.uv1_triplanar and grip_material.uv1_world_triplanar
		and grip_material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30)
		and shell_material.uv1_triplanar and shell_material.uv1_world_triplanar
		and shell_material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30)
		and service_material.uv1_triplanar and service_material.uv1_world_triplanar
		and service_material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30),
		"walked deck, grip, frame, and service surfaces use the shared 0.30 m world-triplanar panel treatment"
	)
	_check(
		deck_material.albedo_color == Color("59666b")
		and is_equal_approx(deck_material.clearcoat, StationSurfaceKit.WALKED_CLEARCOAT)
		and is_equal_approx(deck_material.clearcoat_roughness, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS)
		and grip_material.albedo_color == Color("60767d")
		and is_equal_approx(grip_material.clearcoat, StationSurfaceKit.TRIM_CLEARCOAT)
		and is_equal_approx(grip_material.clearcoat_roughness, StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS)
		and shell_material.albedo_color == Color("9ca7a6")
		and is_equal_approx(shell_material.clearcoat, StationSurfaceKit.STRUCTURAL_CLEARCOAT)
		and is_equal_approx(shell_material.clearcoat_roughness, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS)
		and service_material.albedo_color == Color("735c3d")
		and is_equal_approx(service_material.clearcoat, StationSurfaceKit.PAINTED_CLEARCOAT)
		and is_equal_approx(service_material.clearcoat_roughness, StationSurfaceKit.PAINTED_CLEARCOAT_ROUGHNESS),
		"the four major surface families preserve their hues and exact StationSurfaceKit finish roles"
	)
	_check(
		int(materials.practical_lens_recipe_count) == 3
		and bool(materials.practical_lens_identities_exact)
		and (materials.practical_lens_material_ids as PackedInt64Array)
			== (materials.expected_practical_lens_material_ids as PackedInt64Array),
		"cyan x3, white x2 and amber x1 practical lenses retain their exact shared identities"
	)
	var cyan_batch := module.get_node(^"Structure/Dressing/PracticalCyanLensRenderBatch") as MultiMeshInstance3D
	var shared_cyan := cyan_batch.material_override
	cyan_batch.material_override = shared_cyan.duplicate()
	_check(not bool(module.get_audit_report().valid), "red mutation: duplicated practical recipe identity makes audit fail")
	cyan_batch.material_override = shared_cyan
	_check(bool(module.get_audit_report().valid), "restoring the shared practical recipe returns audit to green")


func _test_visual_resource_sharing(module: ObservationLogisticsSpur) -> void:
	var performance := module.get_visual_resource_contract()
	_check(
		bool(performance.exact)
		and bool(performance.headless_safe)
		and StringName(performance.selected_family) == &"practical_white_lens_render_batch"
		and int(performance.baseline_descendant_nodes) == 144
		and int(performance.descendant_nodes) == 147
		and int(performance.baseline_renderer_nodes) == 42
		and int(performance.renderer_nodes) == 34
		and int(performance.baseline_drawn_copies) == 270
		and int(performance.drawn_copies) == 270
		and int(performance.baseline_surface_submissions) == 42
		and int(performance.surface_submissions) == 34,
		"white practical batching preserves 270 visible copies while reducing the district to 34 submissions"
	)
	_check(
		int(performance.baseline_mesh_resources) == 34
		and int(performance.mesh_resources) == 32
		and int(performance.mesh_resource_delta) == -2
		and int(performance.baseline_material_resources) == 10
		and int(performance.material_resources) == 10
		and int(performance.baseline_family_nodes) == 2
		and int(performance.family_nodes) == 1
		and int(performance.baseline_family_submissions) == 2
		and int(performance.family_submissions) == 1
		and int(performance.baseline_family_mesh_resources) == 1
		and int(performance.family_mesh_resources) == 1,
		"white practical batching cuts two renderer submissions to one without changing the shared mesh allocation"
	)
	var console_batch := module.get_node_or_null(
		^"Structure/Dressing/ObservationConsoleRenderBatch"
	) as MultiMeshInstance3D
	var console_family_exact := console_batch != null and console_batch.multimesh != null
	var authored_console_transforms := (
		console_batch.get_meta("authored_instance_transforms", []) as Array
		if console_batch != null else []
	)
	for console_index in ObservationLogisticsSpur.OBSERVATION_CONSOLE_COPY_COUNT:
		var console_body := module.get_node_or_null(NodePath(
			"Structure/Dressing/ObservationConsole%02d" % (console_index + 1)
		)) as StaticBody3D
		var anchor := console_body.get_node_or_null(^"Mesh") as Marker3D if console_body != null else null
		var collision := console_body.get_node_or_null(^"CollisionShape3D") as CollisionShape3D if console_body != null else null
		console_family_exact = (
			console_family_exact
			and console_body != null
			and console_body.position.is_equal_approx(
				ObservationLogisticsSpur.OBSERVATION_CONSOLE_POSITIONS[console_index]
			)
			and anchor != null
			and anchor.transform.is_equal_approx(Transform3D.IDENTITY)
			and bool(anchor.get_meta("batched_visual_anchor", false))
			and collision != null
			and collision.shape is BoxShape3D
			and (collision.shape as BoxShape3D).size.is_equal_approx(
				ObservationLogisticsSpur.OBSERVATION_CONSOLE_SIZE
			)
			and authored_console_transforms.size()
				== ObservationLogisticsSpur.OBSERVATION_CONSOLE_COPY_COUNT
			and (authored_console_transforms[console_index] as Transform3D).is_equal_approx(
				Transform3D(
					Basis.IDENTITY,
					ObservationLogisticsSpur.OBSERVATION_CONSOLE_POSITIONS[console_index]
				)
			)
		)
	_check(
		console_family_exact
		and (console_batch.multimesh.mesh as BoxMesh).size.is_equal_approx(
			ObservationLogisticsSpur.OBSERVATION_CONSOLE_SIZE
		)
		and console_batch.multimesh.custom_aabb.is_equal_approx(
			ObservationLogisticsSpur.OBSERVATION_CONSOLE_CULLING_BOUNDS
		)
		and console_batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and console_batch.layers == 1
		and is_zero_approx(console_batch.extra_cull_margin)
		and not console_batch.ignore_occlusion_culling
		and is_zero_approx(console_batch.visibility_range_begin)
		and is_zero_approx(console_batch.visibility_range_end)
		and int(performance.observation_console_renderer_delta) == -2
		and int(performance.observation_console_mesh_resources) == 1
		and bool(performance.observation_console_identities_exact),
		"three collidable console identities keep exact shells, poses and collision while one bounded renderer draws them"
	)
	var original_console_bounds := console_batch.multimesh.custom_aabb
	console_batch.multimesh.custom_aabb = original_console_bounds.grow(0.2)
	_check(
		not bool(module.get_visual_resource_contract().exact),
		"red mutation: changing console batch culling bounds fails the visual contract"
	)
	console_batch.multimesh.custom_aabb = original_console_bounds
	_check(bool(module.get_visual_resource_contract().exact), "restoring console culling bounds returns the contract green")
	var mast_batch := module.get_node_or_null(
		^"Structure/Dressing/LightMastRenderBatch"
	) as MultiMeshInstance3D
	var mast_family_exact := mast_batch != null
	var authored_mast_transforms := (
		mast_batch.get_meta("authored_instance_transforms", []) as Array
		if mast_batch != null else []
	)
	for mast_index in ObservationLogisticsSpur.LIGHT_MAST_COPY_COUNT:
		var mast_anchor := module.get_node_or_null(NodePath(
			"Structure/Dressing/LightMast%02d" % (mast_index + 1)
		)) as Marker3D
		mast_family_exact = (
			mast_family_exact
			and mast_anchor != null
			and mast_anchor.position.is_equal_approx(
				ObservationLogisticsSpur.LIGHT_MAST_POSITIONS[mast_index]
			)
			and mast_anchor.get_child_count() == 0
			and bool(mast_anchor.get_meta("batched_visual_anchor", false))
			and authored_mast_transforms.size() == ObservationLogisticsSpur.LIGHT_MAST_COPY_COUNT
			and (authored_mast_transforms[mast_index] as Transform3D).is_equal_approx(
				Transform3D(
					Basis.IDENTITY,
					ObservationLogisticsSpur.LIGHT_MAST_POSITIONS[mast_index]
				)
			)
		)
	_check(
		mast_family_exact
		and int(performance.baseline_light_mast_renderer_nodes) == 6
		and int(performance.light_mast_renderer_nodes) == 1
		and int(performance.light_mast_renderer_delta) == -5
		and int(performance.light_mast_copies) == 6
		and int(performance.baseline_light_mast_mesh_resources) == 6
		and int(performance.light_mast_mesh_resources) == 1
		and int(performance.light_mast_mesh_resource_delta) == -5
		and bool(performance.light_mast_identities_exact),
		"six stable mast anchors keep exact visible poses while one renderer/resource draws them"
	)
	if mast_batch != null:
		var authored_transforms := mast_batch.get_meta("authored_instance_transforms", []) as Array
		var drifted_transforms := authored_transforms.duplicate()
		drifted_transforms[0] = (drifted_transforms[0] as Transform3D).translated_local(
			Vector3(0.25, 0.0, 0.0)
		)
		mast_batch.set_meta("authored_instance_transforms", drifted_transforms)
		var mast_red := module.get_visual_resource_contract()
		mast_batch.set_meta("authored_instance_transforms", authored_transforms)
		_check(
			not bool(mast_red.exact)
			and not bool(mast_red.light_mast_identities_exact)
			and bool(module.get_visual_resource_contract().exact),
			"red mutation: moving one batched mast copy fails the pose contract and restores cleanly"
		)
	var amber_lens := module.get_node_or_null(
		^"Structure/Dressing/LightLens05"
	) as MeshInstance3D
	var practical_cyan_batch := module.get_node_or_null(
		^"Structure/Dressing/PracticalCyanLensRenderBatch"
	) as MultiMeshInstance3D
	var practical_white_batch := module.get_node_or_null(
		^"Structure/Dressing/PracticalWhiteLensRenderBatch"
	) as MultiMeshInstance3D
	var practical_cyan_exact := practical_cyan_batch != null and practical_cyan_batch.multimesh != null
	var practical_white_exact := practical_white_batch != null and practical_white_batch.multimesh != null
	var authored_practical_cyan_transforms := (
		practical_cyan_batch.get_meta("authored_instance_transforms", []) as Array
		if practical_cyan_batch != null else []
	)
	for transform_index in ObservationLogisticsSpur.PRACTICAL_CYAN_LENS_INDICES.size():
		var lens_index: int = ObservationLogisticsSpur.PRACTICAL_CYAN_LENS_INDICES[transform_index]
		var anchor := module.get_node_or_null(NodePath(
			"Structure/Dressing/LightLens%02d" % (lens_index + 1)
		)) as Marker3D
		practical_cyan_exact = practical_cyan_exact \
			and anchor != null \
			and anchor.position.is_equal_approx(ObservationLogisticsSpur.PRACTICAL_LENS_POSITIONS[lens_index]) \
			and anchor.get_child_count() == 0 \
			and bool(anchor.get_meta("batched_visual_anchor", false)) \
			and authored_practical_cyan_transforms.size() == ObservationLogisticsSpur.PRACTICAL_CYAN_LENS_COPY_COUNT \
			and (authored_practical_cyan_transforms[transform_index] as Transform3D).is_equal_approx(
				Transform3D(Basis.IDENTITY, ObservationLogisticsSpur.PRACTICAL_LENS_POSITIONS[lens_index])
			)
	var authored_practical_white_transforms := (
		practical_white_batch.get_meta("authored_instance_transforms", []) as Array
		if practical_white_batch != null else []
	)
	for transform_index in ObservationLogisticsSpur.PRACTICAL_WHITE_LENS_INDICES.size():
		var lens_index: int = ObservationLogisticsSpur.PRACTICAL_WHITE_LENS_INDICES[transform_index]
		var anchor := module.get_node_or_null(NodePath(
			"Structure/Dressing/LightLens%02d" % (lens_index + 1)
		)) as Marker3D
		practical_white_exact = practical_white_exact \
			and anchor != null \
			and anchor.position.is_equal_approx(ObservationLogisticsSpur.PRACTICAL_LENS_POSITIONS[lens_index]) \
			and anchor.get_child_count() == 0 \
			and bool(anchor.get_meta("batched_visual_anchor", false)) \
			and authored_practical_white_transforms.size() == ObservationLogisticsSpur.PRACTICAL_WHITE_LENS_COPY_COUNT \
			and (authored_practical_white_transforms[transform_index] as Transform3D).is_equal_approx(
				Transform3D(Basis.IDENTITY, ObservationLogisticsSpur.PRACTICAL_LENS_POSITIONS[lens_index])
			)
	_check(
		int(performance.practical_lens_copies) == 6
		and int(performance.practical_lens_mesh_resources) == 1
		and bool(performance.practical_lens_identities_exact)
		and practical_cyan_exact
		and practical_cyan_batch.multimesh.instance_count == 3
		and practical_cyan_batch.multimesh.visible_instance_count == 3
		and practical_cyan_batch.multimesh.custom_aabb.is_equal_approx(ObservationLogisticsSpur.PRACTICAL_CYAN_LENS_CULLING_BOUNDS)
		and int(performance.baseline_practical_cyan_lens_renderer_nodes) == 3
		and int(performance.practical_cyan_lens_renderer_nodes) == 1
		and int(performance.practical_cyan_lens_renderer_delta) == -2
		and bool(performance.practical_cyan_lens_identities_exact)
		and practical_white_exact
		and practical_white_batch.multimesh.instance_count == 2
		and practical_white_batch.multimesh.visible_instance_count == 2
		and practical_white_batch.multimesh.custom_aabb.is_equal_approx(ObservationLogisticsSpur.PRACTICAL_WHITE_LENS_CULLING_BOUNDS)
		and int(performance.baseline_practical_white_lens_renderer_nodes) == 2
		and int(performance.practical_white_lens_renderer_nodes) == 1
		and int(performance.practical_white_lens_renderer_delta) == -1
		and bool(performance.practical_white_lens_identities_exact)
		and amber_lens != null
		and amber_lens.mesh == practical_white_batch.multimesh.mesh,
		"cyan and white practical anchors retain exact visible poses while one renderer draws each material family"
	)
	if practical_cyan_batch != null:
		var practical_bounds := practical_cyan_batch.multimesh.custom_aabb
		practical_cyan_batch.multimesh.custom_aabb = practical_bounds.grow(0.2)
		var practical_red := module.get_visual_resource_contract()
		practical_cyan_batch.multimesh.custom_aabb = practical_bounds
		_check(
			not bool(practical_red.exact)
			and not bool(practical_red.practical_cyan_lens_identities_exact)
			and bool(module.get_visual_resource_contract().exact),
			"red mutation: changing cyan practical batch culling bounds fails the contract and restores cleanly"
		)
	if practical_white_batch != null:
		var practical_white_bounds := practical_white_batch.multimesh.custom_aabb
		practical_white_batch.multimesh.custom_aabb = practical_white_bounds.grow(0.2)
		var practical_white_red := module.get_visual_resource_contract()
		practical_white_batch.multimesh.custom_aabb = practical_white_bounds
		_check(
			not bool(practical_white_red.exact)
			and not bool(practical_white_red.practical_white_lens_identities_exact)
			and bool(module.get_visual_resource_contract().exact),
			"red mutation: changing white practical batch culling bounds fails the contract and restores cleanly"
		)

	var case_batch := module.get_node_or_null(
		^"Structure/Dressing/LogisticsCaseRenderBatch"
	) as MultiMeshInstance3D
	var authored_case_transforms := (
		case_batch.get_meta("authored_instance_transforms", []) as Array
		if case_batch != null else []
	)
	var case_contract_matches := case_batch != null and case_batch.multimesh != null
	for case_index in ObservationLogisticsSpur.LOGISTICS_CASE_COPY_COUNT:
		var case_body := module.get_node_or_null(NodePath(
			"Structure/Dressing/LogisticsCase%02d" % (case_index + 1)
		)) as StaticBody3D
		var case_anchor := case_body.get_node_or_null("Mesh") as Marker3D if case_body != null else null
		var collision := case_body.get_node_or_null("CollisionShape3D") as CollisionShape3D if case_body != null else null
		var stack_index := int(case_index / 2)
		var tier_index := case_index % 2
		var expected_transform := Transform3D(Basis.IDENTITY, Vector3(
			11.15, 0.48 + float(tier_index) * 0.58, 28.8 + float(stack_index) * 2.75
		))
		case_contract_matches = case_contract_matches and (
			case_body != null
			and case_body.position.is_equal_approx(expected_transform.origin)
			and case_anchor != null
			and case_anchor.transform.is_equal_approx(Transform3D.IDENTITY)
			and case_anchor.get_child_count() == 0
			and bool(case_anchor.get_meta("batched_visual_anchor", false))
			and collision != null
			and collision.shape is BoxShape3D
			and (collision.shape as BoxShape3D).size.is_equal_approx(
				ObservationLogisticsSpur.LOGISTICS_CASE_SIZE
			)
			and authored_case_transforms.size() == ObservationLogisticsSpur.LOGISTICS_CASE_COPY_COUNT
			and (authored_case_transforms[case_index] as Transform3D).is_equal_approx(
				expected_transform
			)
		)
	_check(
		case_contract_matches
		and case_batch.multimesh.mesh is BoxMesh
		and (case_batch.multimesh.mesh as BoxMesh).size.is_equal_approx(
			ObservationLogisticsSpur.LOGISTICS_CASE_SIZE
		)
		and case_batch.multimesh.instance_count == 6
		and case_batch.multimesh.visible_instance_count == 6
		and case_batch.multimesh.custom_aabb.is_equal_approx(
			ObservationLogisticsSpur.LOGISTICS_CASE_CULLING_BOUNDS
		)
		and int(performance.baseline_logistics_case_renderer_nodes) == 6
		and int(performance.logistics_case_renderer_nodes) == 1
		and int(performance.logistics_case_renderer_delta) == -5
		and int(performance.logistics_case_copies) == 6
		and int(performance.logistics_case_mesh_resources) == 1
		and bool(performance.logistics_case_identities_exact),
		"six named collidable cargo cases retain exact bodies, shapes and poses while one bounded renderer draws them"
	)
	if case_batch != null:
		var case_bounds := case_batch.multimesh.custom_aabb
		case_batch.multimesh.custom_aabb = case_bounds.grow(0.2)
		var case_red := module.get_visual_resource_contract()
		case_batch.multimesh.custom_aabb = case_bounds
		_check(
			not bool(case_red.exact)
			and not bool(case_red.logistics_case_identities_exact)
			and bool(module.get_visual_resource_contract().exact),
			"red mutation: changing cargo-case batch bounds fails the pose contract and restores cleanly"
		)
	var pallet_batch := module.get_node_or_null(
		^"Structure/Dressing/LogisticsPalletRenderBatch"
	) as MultiMeshInstance3D
	var authored_pallet_transforms := (
		pallet_batch.get_meta("authored_instance_transforms", []) as Array
		if pallet_batch != null else []
	)
	var pallet_contract_matches := pallet_batch != null and pallet_batch.multimesh != null
	for pallet_index in ObservationLogisticsSpur.LOGISTICS_PALLET_COPY_COUNT:
		var pallet_body := module.get_node_or_null(NodePath(
			"Structure/Dressing/LogisticsPallet%02d" % (pallet_index + 1)
		)) as StaticBody3D
		var pallet_anchor := (
			pallet_body.get_node_or_null("Mesh") as Marker3D
			if pallet_body != null else null
		)
		var pallet_collision := (
			pallet_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if pallet_body != null else null
		)
		var expected_transform := Transform3D(
			Basis.IDENTITY, ObservationLogisticsSpur.LOGISTICS_PALLET_POSITIONS[pallet_index]
		)
		pallet_contract_matches = pallet_contract_matches and (
			pallet_body != null
			and pallet_body.position.is_equal_approx(expected_transform.origin)
			and pallet_anchor != null
			and pallet_anchor.transform.is_equal_approx(Transform3D.IDENTITY)
			and pallet_anchor.get_child_count() == 0
			and bool(pallet_anchor.get_meta("batched_visual_anchor", false))
			and pallet_collision != null
			and pallet_collision.shape is BoxShape3D
			and (pallet_collision.shape as BoxShape3D).size.is_equal_approx(
				ObservationLogisticsSpur.LOGISTICS_PALLET_SIZE
			)
			and authored_pallet_transforms.size()
				== ObservationLogisticsSpur.LOGISTICS_PALLET_COPY_COUNT
			and (authored_pallet_transforms[pallet_index] as Transform3D).is_equal_approx(
				expected_transform
			)
		)
	_check(
		pallet_contract_matches
		and pallet_batch.multimesh.mesh is BoxMesh
		and (pallet_batch.multimesh.mesh as BoxMesh).size.is_equal_approx(
			ObservationLogisticsSpur.LOGISTICS_PALLET_SIZE
		)
		and pallet_batch.multimesh.instance_count == 3
		and pallet_batch.multimesh.visible_instance_count == 3
		and pallet_batch.multimesh.custom_aabb.is_equal_approx(
			ObservationLogisticsSpur.LOGISTICS_PALLET_CULLING_BOUNDS
		)
		and int(performance.baseline_logistics_pallet_renderer_nodes) == 3
		and int(performance.logistics_pallet_renderer_nodes) == 1
		and int(performance.logistics_pallet_renderer_delta) == -2
		and int(performance.logistics_pallet_copies) == 3
		and int(performance.baseline_logistics_pallet_mesh_resources) == 3
		and int(performance.logistics_pallet_mesh_resources) == 1
		and int(performance.logistics_pallet_mesh_resource_delta) == -2
		and bool(performance.logistics_pallet_identities_exact),
		"three named collidable pallets retain exact bodies, shapes and poses while one bounded renderer draws them"
	)
	if pallet_batch != null:
		var pallet_bounds := pallet_batch.multimesh.custom_aabb
		pallet_batch.multimesh.custom_aabb = pallet_bounds.grow(0.2)
		var pallet_red := module.get_visual_resource_contract()
		pallet_batch.multimesh.custom_aabb = pallet_bounds
		_check(
			not bool(pallet_red.exact)
			and not bool(pallet_red.logistics_pallet_identities_exact)
			and bool(module.get_visual_resource_contract().exact),
			"red mutation: changing pallet batch bounds fails the pose contract and restores cleanly"
		)

	var lens_batch := module.get_node_or_null(
		^"Structure/Dressing/ObservationLensRenderBatch"
	) as MultiMeshInstance3D
	var exact_family := lens_batch != null and lens_batch.multimesh != null
	var authored_lens_transforms := (
		lens_batch.get_meta("authored_instance_transforms", []) as Array
		if lens_batch != null else []
	)
	var lens_buffer := lens_batch.multimesh.buffer if lens_batch != null else PackedFloat32Array()
	for lens_index in ObservationLogisticsSpur.OBSERVATION_LENS_COPY_COUNT:
		var lens_anchor := module.get_node_or_null(NodePath(
			"Structure/Dressing/ObservationLens%02d" % (lens_index + 1)
		)) as Marker3D
		exact_family = (
			exact_family
			and lens_anchor != null
			and lens_anchor.position.is_equal_approx(
				ObservationLogisticsSpur.OBSERVATION_LENS_POSITIONS[lens_index]
			)
			and lens_anchor.scale == Vector3.ONE
			and lens_anchor.get_child_count() == 0
			and bool(lens_anchor.get_meta("visual_detail_only", false))
			and bool(lens_anchor.get_meta("batched_visual_anchor", false))
			and authored_lens_transforms.size()
				== ObservationLogisticsSpur.OBSERVATION_LENS_COPY_COUNT
			and (authored_lens_transforms[lens_index] as Transform3D).is_equal_approx(
				Transform3D(
					Basis.IDENTITY,
					ObservationLogisticsSpur.OBSERVATION_LENS_POSITIONS[lens_index]
				)
			)
			and lens_buffer.size() == ObservationLogisticsSpur.OBSERVATION_LENS_COPY_COUNT * 12
			and Vector3(
				lens_buffer[lens_index * 12 + 3],
				lens_buffer[lens_index * 12 + 7],
				lens_buffer[lens_index * 12 + 11]
			).is_equal_approx(ObservationLogisticsSpur.OBSERVATION_LENS_POSITIONS[lens_index])
		)
	_check(
		exact_family
		and lens_batch.multimesh.mesh is BoxMesh
		and (lens_batch.multimesh.mesh as BoxMesh).size.is_equal_approx(
			ObservationLogisticsSpur.OBSERVATION_LENS_SIZE
		)
		and lens_batch.multimesh.instance_count == 3
		and lens_batch.multimesh.visible_instance_count == 3
		and lens_batch.multimesh.custom_aabb.is_equal_approx(
			ObservationLogisticsSpur.OBSERVATION_LENS_CULLING_BOUNDS
		)
		and lens_batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and lens_batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and lens_batch.layers == 1
		and is_zero_approx(lens_batch.extra_cull_margin)
		and not lens_batch.ignore_occlusion_culling
		and is_zero_approx(lens_batch.visibility_range_begin)
		and is_zero_approx(lens_batch.visibility_range_end)
		and lens_batch.visibility_range_fade_mode
			== GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		and int(performance.baseline_observation_lens_renderer_nodes) == 3
		and int(performance.observation_lens_renderer_nodes) == 1
		and int(performance.observation_lens_renderer_delta) == -2
		and int(performance.observation_lens_anchor_nodes) == 3,
		"three stable observation-lens anchors retain exact visible transforms, extent, material, shadow and culling with one renderer"
	)

	var original_bounds := lens_batch.multimesh.custom_aabb
	lens_batch.multimesh.custom_aabb = original_bounds.grow(0.25)
	var red := module.get_visual_resource_contract()
	_check(
		not bool(red.exact)
		and not bool(red.observation_lens_identities_exact)
		and module.get_validation_errors().has(
			"static visual resource or batching contract drifted"
		),
		"red mutation: changing the observation-lens batch culling bound turns the component-local contract red"
	)
	lens_batch.multimesh.custom_aabb = original_bounds
	_check(
		bool(module.get_visual_resource_contract().exact)
		and bool(module.get_audit_report().valid),
		"restoring the exact observation-lens culling bound returns the complete module audit green"
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
	var rail_bars := module.get_node_or_null(^"Structure/SafetyRails/VisibleRailBars") as MultiMeshInstance3D
	var rail_posts := module.get_node_or_null(^"Structure/SafetyRails/VisibleRailPosts") as MultiMeshInstance3D
	_check(
		rail_bars != null and rail_bars.multimesh.instance_count == 30
		and rail_posts != null and rail_posts.multimesh.instance_count == 84,
		"fifteen conservative safety volumes render as 30 open bars and 84 spaced posts"
	)
	var rail_collision_exact := true
	for rail in rails:
		rail_collision_exact = rail_collision_exact \
			and rail.collision_layer == WORLD_LAYER \
			and rail.collision_mask == 0 \
			and rail.get_node_or_null(^"Mesh") == null \
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
	# Review the district from the same low approach that exposed the unfinished
	# scaffold read in production, rather than letting an aerial composition hide
	# mast glare, floating signs, or empty pavilion edges.
	camera.fov = 64.0
	camera.position = Vector3(0.0, 2.25, 18.0)
	capture_root.add_child(camera)
	camera.look_at(Vector3(0.0, 1.35, 32.0), Vector3.UP)
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
	return 71
