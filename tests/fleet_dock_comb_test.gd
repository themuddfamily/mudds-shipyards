extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/fleet_dock_comb.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "FleetDockCombTestRoot"
	root.add_child(_test_root)
	var module := MODULE_SCENE.instantiate() as FleetDockComb
	_check(module != null, "fleet dock comb scene instantiates with its typed root")
	if module == null:
		_finish()
		return
	module.position = Vector3(31.0, 6.0, -47.0)
	module.rotation_degrees.y = 23.0
	_test_root.add_child(module)
	await process_frame
	await physics_frame
	await physics_frame

	_test_evidence_roster_and_audit(module)
	_test_footprint_routes_and_authority(module)
	_test_walked_plate_material_finish(module)
	await _test_collision_backed_comb_and_voids(module)
	_test_trunk_expansion_joint_batch(module)
	_test_trunk_route_light_batch(module)
	_test_slab_corner_beacon_batch(module)
	_test_slab_support_batch(module)
	_test_rung_edge_cue_batch(module)
	_test_mooring_cleat_pad_batch(module)
	_test_mooring_cleat_bollard_batch(module)
	_test_dock_mast_cap_batch(module)
	_test_dock_service_mast_batch(module)
	_test_dock_service_bracket_batch(module)
	_test_performance_contract(module)
	_test_dock_arm_service_hardware(module)
	await _test_reversible_lifecycle(module)
	await _test_cleanup(module)
	_finish()


func _test_evidence_roster_and_audit(module: FleetDockComb) -> void:
	_check(module.get_module_id() == &"fleet-dock-comb", "module publishes its stable fleet-dock-comb identity")
	_check(bool(module.get_meta("station_module", false)) and module.is_in_group("station_modules"), "root participates in station-module discovery")
	_check(str(module.get_meta("evidence_status", "")) == "modern_interpretation", "root rejects an authenticated-original geometry claim")
	var evidence := module.get_evidence_metadata()
	var claim_ids := evidence.claim_ids as PackedStringArray
	_check(claim_ids == PackedStringArray(["OE-B2-COMB", "OE-B2-SLABS", "OE-B2-BERTHS"]), "evidence API names the exact three B2 topology claims")
	_check(not bool(evidence.authenticated_original_geometry) and "not recovered original geometry" in str(evidence.content_note), "evidence boundary states that exact geometry is modern")

	var roster := module.get_component_roster()
	_check(int(roster.walkable_surface_count) == 7, "roster exposes exactly seven collision-backed walkable surfaces")
	_check(int(roster.rung_count) == 3 and int(roster.dock_slab_count) == 3, "roster contains exactly three rungs and three broad end slabs")
	_check(int(roster.vertical_transition_count) == 1, "roster contains exactly one short vertical transition")
	_check(int(roster.assigned_dock_count) == 3 and int(roster.deferred_dock_count) == 0, "roster exposes three external assignments with no deferred empty dock")
	_check(roster.surface_ids == roster.expected_surface_ids, "actual surface identities exactly match the public roster")
	var audit := module.get_audit_report()
	_check(int(audit.schema_version) == 2 and bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "fresh module passes its complete v2 assignment-aware public audit")
	(audit.roster as Dictionary)["walkable_surface_count"] = -1
	_check(int(module.get_audit_report().roster.walkable_surface_count) == 7, "audit snapshots are deeply detached from live module state")


func _test_footprint_routes_and_authority(module: FleetDockComb) -> void:
	var footprint := module.get_integration_footprint()
	_check((footprint.local_min as Vector3).is_equal_approx(Vector3(-2.6, -2.5, 0.0)), "declared footprint begins at the compact root connection plane")
	_check((footprint.local_max as Vector3).is_equal_approx(Vector3(21.0, 5.0, 48.0)), "declared footprint contains the complete starboard-biased comb")
	_check(
		(footprint.get("assigned_dock_01_walkable_aabb", AABB()) as AABB).is_equal_approx(
			AABB(Vector3(9.0, -0.6, 1.0), Vector3(12.0, 0.6, 15.0))
		),
		"assigned dock 01 publishes its exact widened collision-backed boarding apron"
	)
	_check(bool(footprint.starboard_biased) and (footprint.comb_teeth_axis_local as Vector3) == Vector3.RIGHT, "integration contract keeps every tooth on local +X")
	_check(module.get_module_anchor().global_transform.is_equal_approx(module.global_transform), "module anchor is the exact root connection transform")
	_check(module.get_route_ids().size() == 9, "nine explicit approach, trunk, threshold, and vertical route markers are registered")
	for route_id in [&"approach", &"trunk-forward", &"dock-01-threshold", &"trunk-mid", &"dock-02-threshold", &"trunk-aft", &"vertical-base", &"vertical-top", &"dock-03-threshold"]:
		_check(module.has_route_marker(route_id) and module.get_route_marker(route_id) != null, "route marker resolves: %s" % route_id)

	var docks := module.get_deferred_dock_roster()
	_check(docks.is_empty(), "Dock 03 is no longer deferred after the Bulwark production assignment")
	var assigned := module.get_assigned_dock_roster()
	var assigned_dock_01 := _find_assigned_dock(assigned, &"assigned-dock-01")
	# Dock 02 keeps its original `deferred-dock-02` marker id after promotion.
	var assigned_dock_02 := _find_assigned_dock(assigned, &"deferred-dock-02")
	_check(
		assigned.size() == 3
		and not assigned_dock_01.is_empty()
		and assigned_dock_01.ship_assignment == &"zenith_b7_observed"
		and assigned_dock_01.berth_id == &"zenith_fleet_dock_berth"
		and not bool(assigned_dock_01.owns_berth_authority)
		and not bool(assigned_dock_01.historical_class_to_berth_mapping),
		"dock 01 exposes one modern external Zenith assignment without owning authority"
	)
	_check(
		not assigned_dock_02.is_empty()
		and assigned_dock_02.ship_assignment == &"halyard_new_design"
		and assigned_dock_02.berth_id == &"halyard_fleet_dock_berth"
		and not bool(assigned_dock_02.owns_berth_authority)
		and not bool(assigned_dock_02.historical_class_to_berth_mapping),
		"dock 02 exposes one modern external Halyard assignment without owning authority"
	)
	var assigned_dock_03 := _find_assigned_dock(assigned, &"deferred-dock-03")
	_check(
		not assigned_dock_03.is_empty()
		and assigned_dock_03.ship_assignment == &"bulwark_heavy_gunship"
		and assigned_dock_03.berth_id == &"bulwark_fleet_dock_berth"
		and not bool(assigned_dock_03.owns_berth_authority)
		and not bool(assigned_dock_03.historical_class_to_berth_mapping),
		"dock 03 exposes one modern external Bulwark assignment without owning authority"
	)
	var dock_03_surface := module.find_child("DockSlab03Upper", true, false) as StaticBody3D
	_check(
		dock_03_surface != null
		and StringName(dock_03_surface.get_meta("surface_role", &"")) == &"broad-assigned-slab",
		"dock 03's live walkable-surface role agrees with its Bulwark assignment"
	)
	var dock_02_surface := module.find_child("DockSlab02", true, false) as StaticBody3D
	_check(
		dock_02_surface != null
		and StringName(dock_02_surface.get_meta("surface_role", &"")) == &"broad-assigned-slab",
		"dock 02's live walkable-surface role agrees with its Halyard assignment"
	)
	_check(module.get_dock_roster().size() == 3, "combined roster preserves all three physical dock landmarks")
	var authority := module.get_authority_contract()
	_check(int(authority.ship_berth_count) == 0 and int(authority.landing_or_interaction_area_count) == 0, "module owns no ShipBerth, landing, boarding, or interaction area")
	_check(int(authority.audio_node_count) == 0 and int(authority.activity_node_count) == 0, "module owns no audio or station-activity component")
	_check(int(authority.lease_authority_count) == 0 and int(authority.spawn_authority_count) == 0, "module owns no lease or spawning authority")


## The approach's broad, player-facing plates use the station's walked finish,
## not the generic structural clear layer. The same material instances remain
## bound to the same meshes; this pins only their manufactured surface response.
func _test_walked_plate_material_finish(module: FleetDockComb) -> void:
	var walked_nodes := [
		"Trunk", "Rung01", "DockSlab01", "Rung02", "DockSlab02",
		"Rung03Vertical", "DockSlab03Upper",
	]
	var every_surface_is_walked_plate := true
	for node_name in walked_nodes:
		var body := module.find_child(node_name, true, false) as StaticBody3D
		var mesh_instance := body.get_node_or_null(^"Mesh") as MeshInstance3D if body != null else null
		var material := mesh_instance.material_override as StandardMaterial3D if mesh_instance != null else null
		every_surface_is_walked_plate = (
			every_surface_is_walked_plate
			and material != null
			and material.albedo_texture != null
			and material.normal_enabled
			and material.normal_texture != null
			and material.roughness_texture != null
			and material.uv1_triplanar
			and material.uv1_world_triplanar
			and material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30)
			and is_equal_approx(material.clearcoat, StationSurfaceKit.WALKED_CLEARCOAT)
			and is_equal_approx(
				material.clearcoat_roughness,
				StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS
			)
		)
	_check(
		walked_nodes.size() == 7 and every_surface_is_walked_plate,
		"all seven approach plates retain the station maps and use the walked-deck finish"
	)

	var slab_insets := module.find_children("SlabInset*", "MeshInstance3D", true, false)
	var every_inset_is_walked_plate := slab_insets.size() == 3
	for raw_node in slab_insets:
		var inset := raw_node as MeshInstance3D
		var inset_material := inset.material_override as StandardMaterial3D
		every_inset_is_walked_plate = (
			every_inset_is_walked_plate
			and inset_material != null
			and is_equal_approx(inset_material.clearcoat, StationSurfaceKit.WALKED_CLEARCOAT)
			and is_equal_approx(
				inset_material.clearcoat_roughness,
				StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS
			)
		)
	_check(every_inset_is_walked_plate, "all three broad slab grip insets share the walked-deck finish")


func _test_collision_backed_comb_and_voids(module: FleetDockComb) -> void:
	var surface_samples := [
		[Vector3(0, 2.0, 4.0), 0.0, "narrow trunk"],
		[Vector3(6.0, 2.0, 10.0), 0.0, "first orthogonal rung"],
		[Vector3(15.0, 2.0, 10.0), 0.0, "first broad slab"],
		[Vector3(15.0, 2.0, 2.15), 0.0, "Zenith exit-side boarding apron"],
		[Vector3(6.0, 2.0, 25.0), 0.0, "second orthogonal rung"],
		[Vector3(15.0, 2.0, 25.0), 0.0, "second broad slab"],
		[Vector3(5.5, 4.0, 40.0), 1.2, "third rising rung"],
		[Vector3(15.0, 5.0, 40.0), 2.4, "upper broad slab"],
	]
	for sample in surface_samples:
		var local_point := sample[0] as Vector3
		var hit := await _ray_local(module, local_point, Vector3(local_point.x, -4.0, local_point.z))
		_check(not hit.is_empty(), "%s has real World collision" % str(sample[2]))
		if not hit.is_empty():
			var local_hit := module.to_local(hit.position)
			_check(absf(local_hit.y - float(sample[1])) < 0.08, "%s collision matches its declared elevation" % str(sample[2]))

	var every_void_empty := true
	for local_void in module.get_negative_space_samples():
		var void_hit := await _ray_local(module, local_void + Vector3.UP * 5.0, local_void + Vector3.DOWN * 5.0)
		every_void_empty = every_void_empty and void_hit.is_empty()
	_check(every_void_empty, "all five published footprint samples remain genuine physics voids")
	var collision := module.get_collision_contract()
	_check(int(collision.body_count) == 7 and int(collision.shape_count) == 7, "collision roster is exactly one body and shape per walkable surface")
	_check(bool(collision.all_layers_match_lifecycle) and bool(collision.all_masks_zero), "all collision uses the canonical World layer with zero static mask")
	_check(not bool(collision.full_footprint_floor_present), "collision audit proves no hidden full-footprint floor exists")
	_test_chamfered_meshes_do_not_move_collision(module)


## Every walkable surface renders a chamfered box, and chamfering must remain a
## purely visual edge treatment. This is the guard for that: each surface body's
## rendered mesh must still report exactly the extent of its own `BoxShape3D`, so
## no chamfer can shrink, grow or offset a collidable deck.
func _test_chamfered_meshes_do_not_move_collision(module: FleetDockComb) -> void:
	var checked := 0
	var every_mesh_matches_its_shape := true
	for candidate in module.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		var mesh_instance := body.get_node_or_null(^"Mesh") as MeshInstance3D
		var collision_shape := body.get_node_or_null(^"Collision") as CollisionShape3D
		var box_shape := collision_shape.shape as BoxShape3D if collision_shape != null else null
		if mesh_instance == null or mesh_instance.mesh == null or box_shape == null:
			every_mesh_matches_its_shape = false
			continue
		var bounds := mesh_instance.mesh.get_aabb()
		every_mesh_matches_its_shape = (
			every_mesh_matches_its_shape
			and bounds.size.is_equal_approx(box_shape.size)
			and bounds.get_center().is_zero_approx()
		)
		checked += 1
	_check(
		checked == 7 and every_mesh_matches_its_shape,
		"all seven chamfered surface meshes report exactly their collider extent and centre"
	)


func _test_trunk_expansion_joint_batch(module: FleetDockComb) -> void:
	var detail := module.get_node_or_null(^"GeneratedComb/SurfaceDetail") as Node3D
	var batch := module.get_node_or_null(
		^"GeneratedComb/SurfaceDetail/TrunkExpansionJoints"
	) as MultiMeshInstance3D
	_check(
		detail != null and batch != null and batch.multimesh != null,
		"twelve trunk expansion strips resolve as one SurfaceDetail MultiMesh"
	)
	if detail == null or batch == null or batch.multimesh == null:
		return
	var multi := batch.multimesh
	var expected: Array[Transform3D] = []
	for z_position in [2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0]:
		expected.append(
			Transform3D(Basis.IDENTITY, Vector3(0, 0.018, float(z_position)))
		)
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (authored[index] as Transform3D).is_equal_approx(expected[index])
	_check(
		multi.instance_count == FleetDockComb.TRUNK_EXPANSION_JOINT_COPY_COUNT
		and multi.visible_instance_count == -1
		and authored_exact,
		"batch preserves all twelve authored transforms and ordering"
	)
	if not RenderingServer.get_video_adapter_name().is_empty():
		var renderer_exact := multi.instance_count == expected.size()
		for index in expected.size():
			renderer_exact = renderer_exact and multi.get_instance_transform(index).is_equal_approx(expected[index])
		_check(renderer_exact, "Forward+ renderer transforms preserve all twelve joint strips")

	var old_candidate_nodes := 0
	for raw_node in detail.get_children():
		var instance := raw_node as MeshInstance3D
		if (
			instance != null
			and instance.mesh != null
			and instance.mesh.get_aabb().size.is_equal_approx(Vector3(4.25, 0.035, 0.06))
		):
			old_candidate_nodes += 1
	var grip_reference := detail.get_node_or_null(^"SlabInset01") as MeshInstance3D
	_check(
		old_candidate_nodes == 0
		and batch.get_child_count() == 0
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
		and batch.find_children("*", "Area3D", true, false).is_empty(),
		"the batched family remains childless, visual-only and non-colliding"
	)
	_check(
		multi.mesh.get_aabb().size.is_equal_approx(Vector3(4.25, 0.035, 0.06))
		and multi.mesh.get_surface_count() == 1
		and grip_reference != null
		and batch.material_override == grip_reference.material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1,
		"batch preserves mesh extent, surface, grip material, shadows and render layer"
	)

	var trunk := module.get_node(^"GeneratedComb/WalkableSurfaces/Trunk") as StaticBody3D
	var trunk_mesh := trunk.get_node(^"Mesh") as MeshInstance3D
	var trunk_box := (trunk.transform * trunk_mesh.mesh.get_aabb()).abs()
	var every_strip_mounted := true
	for transform_value in expected:
		var strip_box := (transform_value * multi.mesh.get_aabb()).abs()
		every_strip_mounted = every_strip_mounted and strip_box.grow(0.001).intersects(trunk_box)
	_check(every_strip_mounted, "every batched expansion strip remains mounted into the trunk deck")

	var render := module.get_render_batch_contract()
	_check(
		int(render.descendant_nodes) == 142
		and int(render.mesh_instances) == 89
		and int(render.multimesh_batches) == 10,
		"renderer census includes all ten bounded visual-detail batches"
	)
	_check(
		int(render.drawn_copies) == 101
		and int(render.geometry_submissions) == 53
		and int(render.trunk_expansion_joint_copies) == 12,
		"drawn copies remain 101 while surface submissions become 53"
	)
	_check(
		int(render.trunk_renderer_buffer_floats) == 144
		and int(render.renderer_buffer_floats) == 696
		and bool(render.renderer_buffer_matches_authored)
		and bool(render.bounds_match_authored)
		and bool(render.exact_counts),
		"all renderer buffers freeze at 696 floats with exact authored culling unions"
	)
	var collision := module.get_collision_contract()
	var authority := module.get_authority_contract()
	_check(
		int(render.static_bodies) == 7
		and int(render.collision_shapes) == 7
		and int(render.route_markers) == 9
		and int(render.dock_landmarks) == 3
		and int(collision.body_count) == 7
		and int(collision.shape_count) == 7,
		"batching leaves bodies, shapes, route markers and dock landmarks exact"
	)
	_check(
		int(authority.ship_berth_count) == 0
		and int(authority.landing_or_interaction_area_count) == 0
		and module.get_assigned_dock_roster().size() == 3
		and module.get_deferred_dock_roster().is_empty(),
		"batching leaves berth and interaction authority absent and preserves three assigned docks"
	)

	var detached := render.authored_joint_transforms as Array
	detached[0] = Transform3D.IDENTITY
	_check(
		not ((module.get_render_batch_contract().authored_joint_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"render contract returns a detached authored-transform roster"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has("comb trunk-joint renderer buffer drifted from its authored roster"),
		"mutating one live renderer transform is rejected by the module audit"
	)
	multi.buffer = original_buffer
	var original_bounds := multi.custom_aabb
	multi.custom_aabb = original_bounds.grow(0.25)
	_check(
		module.get_validation_errors().has("comb trunk-joint batch bounds drifted from its authored copies"),
		"mutating the explicit culling bounds is rejected by the module audit"
	)
	multi.custom_aabb = original_bounds
	_check(module.get_validation_errors().is_empty(), "restoring the exact batch payload restores a clean module audit")


func _test_trunk_route_light_batch(module: FleetDockComb) -> void:
	var detail := module.get_node_or_null(^"GeneratedComb/SurfaceDetail") as Node3D
	var batch := module.get_node_or_null(
		^"GeneratedComb/SurfaceDetail/TrunkRouteLights"
	) as MultiMeshInstance3D
	_check(
		detail != null and batch != null and batch.multimesh != null,
		"three trunk route-light inlays resolve as one SurfaceDetail MultiMesh"
	)
	if detail == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = []
	for z_position in [5.0, 20.0, 35.0]:
		expected.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.020, float(z_position))))
	var anchors: Array[MeshInstance3D] = []
	for raw_node in detail.get_children():
		var anchor := raw_node as MeshInstance3D
		if (
			anchor != null
			and anchor.mesh != null
			and anchor.mesh.get_aabb().size.is_equal_approx(Vector3(0.22, 0.05, 1.25))
			and not anchor.visible
		):
			anchors.append(anchor)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = (
			anchors_exact
			and anchors[index].transform.is_equal_approx(expected[index])
			and not anchors[index].visible
			and anchors[index].mesh != null
			and anchors[index].mesh.get_aabb().size.is_equal_approx(Vector3(0.22, 0.05, 1.25))
			and anchors[index].get_child_count() == 0
			and anchors[index].get_script() == null
		)
	var multi := batch.multimesh
	var render := module.get_render_batch_contract()
	_check(
		anchors_exact
		and multi.instance_count == FleetDockComb.TRUNK_ROUTE_LIGHT_COPY_COUNT
		and multi.visible_instance_count == -1
		and multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.22, 0.05, 1.25))
		and multi.mesh.get_surface_count() == 1
		and batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and batch.material_override == anchors[0].material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.get_child_count() == 0
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
		and batch.find_children("*", "Area3D", true, false).is_empty(),
		"route-light batch preserves transforms, cyan material, shadows, culling layer and visual-only ownership"
	)
	var trunk := module.get_node(^"GeneratedComb/WalkableSurfaces/Trunk") as StaticBody3D
	var trunk_mesh := trunk.get_node(^"Mesh") as MeshInstance3D
	var trunk_box := (trunk.transform * trunk_mesh.mesh.get_aabb()).abs()
	var every_inlay_mounted := true
	for transform_value in expected:
		var light_box := (transform_value * multi.mesh.get_aabb()).abs()
		every_inlay_mounted = every_inlay_mounted and light_box.grow(0.001).intersects(trunk_box)
	_check(every_inlay_mounted, "all three batched route-light inlays remain mounted into the trunk deck")
	_check(
		int(render.trunk_route_light_submissions_before) == 3
		and int(render.trunk_route_light_submissions_after) == 1
		and int(render.geometry_submissions_before_trunk_route_light_batch) == 66
		and int(render.geometry_submissions) == 53
		and int(render.drawn_copies) == 101
		and int(render.trunk_route_light_renderer_buffer_floats) == 36
		and bool(render.trunk_route_light_renderer_buffer_matches_authored)
		and bool(render.trunk_route_light_bounds_match_authored)
		and bool(render.trunk_route_light_contract_matches)
		and int(render.static_bodies) == 7
		and int(render.collision_shapes) == 7
		and int(render.route_markers) == 9
		and int(render.dock_landmarks) == 3,
		"route lights reduce 3 -> 1 submissions without changing copies, physics, routes or dock identities"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has("comb trunk-route-light renderer buffer drifted from its authored roster"),
		"mutating one live route-light transform is rejected by the production audit"
	)
	multi.buffer = original_buffer
	_check(module.get_validation_errors().is_empty(), "restoring the route-light batch restores a clean module audit")


func _test_slab_corner_beacon_batch(module: FleetDockComb) -> void:
	var detail := module.get_node_or_null(^"GeneratedComb/SurfaceDetail") as Node3D
	var batch := module.get_node_or_null(
		^"GeneratedComb/SurfaceDetail/SlabCornerBeacons"
	) as MultiMeshInstance3D
	_check(
		detail != null and batch != null and batch.multimesh != null,
		"twelve slab corner beacons resolve as one SurfaceDetail MultiMesh"
	)
	if detail == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = []
	for slab in [
		[8.5, 0.08],
		[25.0, 0.08],
		[40.0, 2.48],
	]:
		for corner in [Vector2(-5.1, -5.1), Vector2(-5.1, 5.1), Vector2(5.1, -5.1), Vector2(5.1, 5.1)]:
			expected.append(Transform3D(
				Basis.IDENTITY,
				Vector3(15.0 + corner.x, float(slab[1]), float(slab[0]) + corner.y)
			))

	var anchors: Array[MeshInstance3D] = []
	for raw_node in detail.get_children():
		var instance := raw_node as MeshInstance3D
		if (
			instance != null
			and instance.mesh != null
			and instance.mesh.get_aabb().size.is_equal_approx(Vector3(0.48, 0.12, 0.48))
			and not instance.visible
		):
			anchors.append(instance)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = (
			anchors_exact
			and anchors[index].transform.is_equal_approx(expected[index])
			and anchors[index].get_child_count() == 0
			and anchors[index].get_script() == null
			and anchors[index].material_override == anchors[0].material_override
		)
	_check(
		anchors_exact,
		"all twelve legacy beacon anchors retain exact transforms, mesh, material and childless paths"
	)
	var multi := batch.multimesh
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (authored[index] as Transform3D).is_equal_approx(expected[index])
	_check(
		multi.instance_count == FleetDockComb.SLAB_CORNER_BEACON_COPY_COUNT
		and multi.visible_instance_count == -1
		and authored_exact
		and multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.48, 0.12, 0.48))
		and anchors.size() == 12
		and batch.material_override == anchors[0].material_override
		and batch.get_child_count() == 0
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"batch preserves every copy, extent and amber material with no collision descendants"
	)

	var render := module.get_render_batch_contract()
	_check(
		int(render.slab_corner_beacon_submissions_before) == 12
		and int(render.slab_corner_beacon_submissions_after) == 1
		and int(render.geometry_submissions_before_slab_beacon_batch) == 90
		and int(render.geometry_submissions) == 53
		and int(render.geometry_submissions_removed) == 37
		and int(render.slab_corner_beacon_renderer_buffer_floats) == 144,
		"corner-beacon and later batches preserve the 12 -> 1 beacon reduction and reach 53 overall"
	)
	_check(
		bool(render.slab_corner_beacon_renderer_buffer_matches_authored)
		and bool(render.slab_corner_beacon_bounds_match_authored)
		and int(render.static_bodies) == 7
		and int(render.collision_shapes) == 7
		and int(render.route_markers) == 9
		and int(render.dock_landmarks) == 3,
		"batch preserves authored transforms, bounds, collision, routes and dock landmarks"
	)
	var detached := render.authored_slab_corner_beacon_transforms as Array
	detached[0] = Transform3D.IDENTITY
	_check(
		not ((module.get_render_batch_contract().authored_slab_corner_beacon_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"slab beacon render contract returns a detached transform roster"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has("comb slab-corner-beacon renderer buffer drifted from its authored roster"),
		"mutating one live beacon renderer transform is rejected by the module audit"
	)
	multi.buffer = original_buffer
	_check(module.get_validation_errors().is_empty(), "restoring the exact beacon batch restores a clean module audit")


func _test_slab_support_batch(module: FleetDockComb) -> void:
	var underframe := module.get_node_or_null(
		^"GeneratedComb/VisualUnderframe"
	) as Node3D
	var batch := module.get_node_or_null(
		^"GeneratedComb/VisualUnderframe/SlabSupports"
	) as MultiMeshInstance3D
	_check(
		underframe != null and batch != null and batch.multimesh != null,
		"six slab underframe supports resolve as one VisualUnderframe MultiMesh"
	)
	if underframe == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = []
	for slab_spec in [[8.5, -1.75], [25.0, -1.75], [40.0, 0.65]]:
		for support_x in [11.0, 19.0]:
			expected.append(Transform3D(
				Basis.IDENTITY,
				Vector3(float(support_x), float(slab_spec[1]), float(slab_spec[0]))
			))
	var anchors: Array[MeshInstance3D] = []
	for raw_node in underframe.get_children():
		var instance := raw_node as MeshInstance3D
		if (
			instance != null
			and instance.mesh != null
			and instance.mesh.get_aabb().size.is_equal_approx(Vector3(0.55, 2.5, 0.55))
			and not instance.visible
		):
			anchors.append(instance)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = (
			anchors_exact
			and anchors[index].transform.is_equal_approx(expected[index])
			and anchors[index].mesh != null
			and anchors[index].mesh.get_aabb().size.is_equal_approx(Vector3(0.55, 2.5, 0.55))
			and not anchors[index].visible
			and anchors[index].get_child_count() == 0
			and anchors[index].get_script() == null
		)
	_check(
		anchors_exact,
		"all six slab-support MeshInstance anchors retain exact transforms and geometry"
	)
	var multi := batch.multimesh
	var render := module.get_render_batch_contract()
	_check(
		multi.instance_count == FleetDockComb.SLAB_SUPPORT_COPY_COUNT
		and multi.visible_instance_count == -1
		and batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.55, 2.5, 0.55))
		and multi.mesh.get_surface_count() == 1
		and anchors.size() == FleetDockComb.SLAB_SUPPORT_COPY_COUNT
		and (anchors.is_empty() or batch.material_override == anchors[0].material_override)
		and batch.get_child_count() == 0
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"support batch preserves copies, frame material, root transform and collision-free ownership"
	)
	_check(
		int(render.slab_support_submissions_before) == 6
		and int(render.slab_support_submissions_after) == 1
		and int(render.geometry_submissions_before_slab_support_batch) == 79
		and int(render.geometry_submissions) == 53
		and int(render.slab_support_renderer_buffer_floats) == 72
		and bool(render.slab_support_renderer_buffer_matches_authored)
		and bool(render.slab_support_bounds_match_authored)
		and bool(render.slab_support_contract_matches)
		and bool(render.exact_counts),
		"support family measures 6 -> 1 submissions and freezes its exact buffer and culling union"
	)
	var detached := render.authored_slab_support_transforms as Array
	if not detached.is_empty():
		detached[0] = Transform3D.IDENTITY
	_check(
		detached.is_empty() or not ((module.get_render_batch_contract().authored_slab_support_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"support render contract returns a detached authored-transform roster"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has("comb slab-support renderer buffer drifted from its authored roster"),
		"mutating one live support transform is rejected by the production audit"
	)
	multi.buffer = original_buffer
	var original_bounds := multi.custom_aabb
	multi.custom_aabb = original_bounds.grow(0.25)
	_check(
		module.get_validation_errors().has("comb slab-support batch bounds drifted from its authored copies"),
		"mutating support culling bounds is rejected by the production audit"
	)
	multi.custom_aabb = original_bounds
	var original_transform := batch.transform
	batch.position.x += 0.25
	_check(
		module.get_validation_errors().has("comb slab-support renderer contract drifted"),
		"moving the batch root away from stable anchors is rejected by the production audit"
	)
	batch.transform = original_transform
	_check(module.get_validation_errors().is_empty(), "restoring the support batch restores a clean module audit")


func _test_rung_edge_cue_batch(module: FleetDockComb) -> void:
	var detail := module.get_node_or_null(^"GeneratedComb/SurfaceDetail") as Node3D
	var batch := module.get_node_or_null(
		^"GeneratedComb/SurfaceDetail/RungEdgeCues"
	) as MultiMeshInstance3D
	_check(
		detail != null and batch != null and batch.multimesh != null,
		"four rung edge cues resolve as one SurfaceDetail MultiMesh"
	)
	if detail == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = []
	for rung_z in [10.0, 25.0]:
		for side in [-1.0, 1.0]:
			expected.append(Transform3D(
				Basis.IDENTITY,
				Vector3(5.5, 0.025, float(rung_z) + float(side) * 1.62)
			))
	var anchors: Array[MeshInstance3D] = []
	for raw_node in detail.get_children():
		var instance := raw_node as MeshInstance3D
		if (
			instance != null
			and instance.mesh != null
			and instance.mesh.get_aabb().size.is_equal_approx(Vector3(6.7, 0.06, 0.1))
			and not instance.visible
		):
			anchors.append(instance)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = (
			anchors_exact
			and anchors[index].transform.is_equal_approx(expected[index])
			and anchors[index].get_child_count() == 0
			and anchors[index].get_script() == null
		)
	var multi := batch.multimesh
	var render := module.get_render_batch_contract()
	_check(
		anchors_exact
		and multi.instance_count == FleetDockComb.RUNG_EDGE_CUE_COPY_COUNT
		and multi.visible_instance_count == -1
		and multi.mesh.get_aabb().size.is_equal_approx(Vector3(6.7, 0.06, 0.1))
		and multi.mesh.get_surface_count() == 1
		and batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and (anchors.is_empty() or batch.material_override == anchors[0].material_override)
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.get_child_count() == 0
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
		and batch.find_children("*", "Area3D", true, false).is_empty(),
		"batch preserves all four transforms, amber material, culling/shadow state, and visual-only ownership"
	)
	_check(
		int(render.rung_edge_cue_submissions_before) == 4
		and int(render.rung_edge_cue_submissions_after) == 1
		and int(render.geometry_submissions_before_rung_edge_cue_batch) == 74
		and int(render.geometry_submissions) == 53
		and int(render.drawn_copies) == 101
		and int(render.rung_edge_cue_renderer_buffer_floats) == 48
		and bool(render.rung_edge_cue_renderer_buffer_matches_authored)
		and bool(render.rung_edge_cue_bounds_match_authored)
		and bool(render.rung_edge_cue_contract_matches)
		and int(render.static_bodies) == 7
		and int(render.collision_shapes) == 7
		and int(render.route_markers) == 9
		and int(render.dock_landmarks) == 3,
		"rung cues measure 4 -> 1 submissions with exact visible count and unchanged physics/semantics"
	)
	var authored := render.authored_rung_edge_cue_transforms as Array
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (authored[index] as Transform3D).is_equal_approx(expected[index])
	_check(authored_exact, "rung cue render contract exposes the exact detached authored transform roster")
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has("comb rung-edge-cue renderer buffer drifted from its authored roster"),
		"mutating one live rung-cue transform is rejected by the production audit"
	)
	multi.buffer = original_buffer
	_check(module.get_validation_errors().is_empty(), "restoring the rung-cue batch restores a clean module audit")


func _test_mooring_cleat_pad_batch(module: FleetDockComb) -> void:
	var service := module.get_node_or_null(^"GeneratedComb/SurfaceDetail/DockArmService") as Node3D
	var batch := module.get_node_or_null(
		^"GeneratedComb/SurfaceDetail/DockArmService/DockMooringCleatPads"
	) as MultiMeshInstance3D
	_check(
		service != null and batch != null and batch.multimesh != null,
		"six mooring cleat pads resolve as one dock-service MultiMesh"
	)
	if service == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = []
	var expected_names := PackedStringArray()
	var slab_specs: Array[Vector2] = [Vector2(8.5, 0.02), Vector2(25.0, 0.02), Vector2(40.0, 2.42)]
	for slab_index in 3:
		var slab_spec := slab_specs[slab_index]
		for side: float in [-1.0, 1.0]:
			expected.append(Transform3D(
				Basis.IDENTITY,
				Vector3(9.5, slab_spec.y, slab_spec.x + side * 4.4)
			))
			expected_names.append(
				"DockMooringCleatPad%02d_%s" % [slab_index + 1, "A" if side < 0.0 else "B"]
			)
	var anchors: Array[MeshInstance3D] = []
	for raw_node in service.get_children():
		if str(raw_node.name).begins_with("DockMooringCleatPad"):
			var anchor := raw_node as MeshInstance3D
			if anchor != null:
				anchors.append(anchor)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = (
			anchors_exact
			and str(anchors[index].name) == expected_names[index]
			and anchors[index].transform.is_equal_approx(expected[index])
			and not anchors[index].visible
			and anchors[index].mesh != null
			and anchors[index].mesh.get_aabb().size.is_equal_approx(Vector3(0.66, 0.05, 0.66))
			and anchors[index].get_child_count() == 0
			and anchors[index].get_script() == null
		)
	var multi := batch.multimesh
	var render := module.get_render_batch_contract()
	_check(
		anchors_exact
		and multi.instance_count == FleetDockComb.MOORING_CLEAT_PAD_COPY_COUNT
		and multi.visible_instance_count == -1
		and multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.66, 0.05, 0.66))
		and multi.mesh.get_surface_count() == 1
		and batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and batch.material_override == anchors[0].material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.get_child_count() == 0
		and service.find_children("*", "CollisionObject3D", true, false).is_empty()
		and service.find_children("*", "Area3D", true, false).is_empty(),
		"cleat-pad batch preserves exact transforms, grip material, shadows, culling layer and visual-only ownership"
	)
	_check(
		int(render.mooring_cleat_pad_submissions_before) == 6
		and int(render.mooring_cleat_pad_submissions_after) == 1
		and int(render.geometry_submissions_before_mooring_cleat_pad_batch) == 71
		and int(render.geometry_submissions) == 53
		and int(render.drawn_copies) == 101
		and int(render.mooring_cleat_pad_renderer_buffer_floats) == 72
		and bool(render.mooring_cleat_pad_renderer_buffer_matches_authored)
		and bool(render.mooring_cleat_pad_bounds_match_authored)
		and bool(render.mooring_cleat_pad_contract_matches)
		and int(render.static_bodies) == 7
		and int(render.collision_shapes) == 7
		and int(render.route_markers) == 9
		and int(render.dock_landmarks) == 3,
		"cleat pads reduce 6 -> 1 submissions without changing copies, physics, routes or dock identities"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has("comb mooring-cleat-pad renderer buffer drifted from its authored roster"),
		"mutating one live cleat-pad transform is rejected by the production audit"
	)
	multi.buffer = original_buffer
	_check(module.get_validation_errors().is_empty(), "restoring the cleat-pad batch restores a clean module audit")


func _test_mooring_cleat_bollard_batch(module: FleetDockComb) -> void:
	var service := module.get_node_or_null(^"GeneratedComb/SurfaceDetail/DockArmService") as Node3D
	var batch := module.get_node_or_null(
		^"GeneratedComb/SurfaceDetail/DockArmService/MooringCleatBollardBatch"
	) as MultiMeshInstance3D
	_check(
		service != null and batch != null and batch.multimesh != null,
		"six mooring cleat bollards resolve as one dock-service MultiMesh"
	)
	if service == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = []
	var expected_names := PackedStringArray()
	var slab_specs: Array[Vector2] = [Vector2(8.5, 0.10), Vector2(25.0, 0.10), Vector2(40.0, 2.50)]
	for slab_index in 3:
		var slab_spec := slab_specs[slab_index]
		for side: float in [-1.0, 1.0]:
			expected.append(Transform3D(
				Basis.IDENTITY,
				Vector3(9.5, slab_spec.y, slab_spec.x + side * 4.4)
			))
			expected_names.append(
				"DockMooringCleatBollard%02d_%s" % [slab_index + 1, "A" if side < 0.0 else "B"]
			)
	var anchors: Array[MeshInstance3D] = []
	for raw_node in service.get_children():
		if str(raw_node.name).begins_with("DockMooringCleatBollard"):
			var anchor := raw_node as MeshInstance3D
			if anchor != null:
				anchors.append(anchor)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = (
			anchors_exact
			and str(anchors[index].name) == expected_names[index]
			and anchors[index].transform.is_equal_approx(expected[index])
			and not anchors[index].visible
			and anchors[index].mesh != null
			and anchors[index].mesh.get_aabb().size.is_equal_approx(Vector3(0.4, 0.17, 0.4))
			and anchors[index].get_child_count() == 0
			and anchors[index].get_script() == null
		)
	var multi := batch.multimesh
	var render := module.get_render_batch_contract()
	_check(
		anchors_exact
		and multi.instance_count == FleetDockComb.MOORING_CLEAT_BOLLARD_COPY_COUNT
		and multi.visible_instance_count == -1
		and multi.mesh == anchors[0].mesh
		and multi.mesh.get_surface_count() == 1
		and batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and batch.material_override == anchors[0].material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.get_child_count() == 0
		and service.find_children("*", "CollisionObject3D", true, false).is_empty()
		and service.find_children("*", "Area3D", true, false).is_empty(),
		"bollard batch preserves exact cylinder mesh, transforms, underframe material and visual-only ownership"
	)
	_check(
		int(render.mooring_cleat_bollard_submissions_before) == 6
		and int(render.mooring_cleat_bollard_submissions_after) == 1
		and int(render.geometry_submissions_before_mooring_cleat_bollard_batch) == 62
		and int(render.geometry_submissions) == 53
		and int(render.drawn_copies) == 101
		and int(render.mooring_cleat_bollard_renderer_buffer_floats) == 72
		and bool(render.mooring_cleat_bollard_renderer_buffer_matches_authored)
		and bool(render.mooring_cleat_bollard_bounds_match_authored)
		and bool(render.mooring_cleat_bollard_contract_matches)
		and int(render.static_bodies) == 7
		and int(render.collision_shapes) == 7
		and int(render.route_markers) == 9
		and int(render.dock_landmarks) == 3,
		"bollards reduce 6 -> 1 submissions without changing copies, physics, routes or dock identities"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has("comb mooring-cleat-bollard renderer buffer drifted from its authored roster"),
		"mutating one live bollard transform is rejected by the production audit"
	)
	multi.buffer = original_buffer
	_check(module.get_validation_errors().is_empty(), "restoring the bollard batch restores a clean module audit")


func _test_dock_mast_cap_batch(module: FleetDockComb) -> void:
	var service := module.get_node_or_null(^"GeneratedComb/SurfaceDetail/DockArmService") as Node3D
	var batch := module.get_node_or_null(
		^"GeneratedComb/SurfaceDetail/DockArmService/DockMastCaps"
	) as MultiMeshInstance3D
	_check(service != null and batch != null and batch.multimesh != null, "three dock mast caps resolve as one service MultiMesh")
	if service == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = []
	for cap_spec in [[8.5, 3.98], [25.0, 3.98], [40.0, 6.38]]:
		expected.append(Transform3D(Basis.IDENTITY, Vector3(21.9, float(cap_spec[1]), float(cap_spec[0]))))
	var anchors: Array[MeshInstance3D] = []
	for raw_node in service.get_children():
		if str(raw_node.name).begins_with("DockMastCap"):
			var anchor := raw_node as MeshInstance3D
			if anchor != null:
				anchors.append(anchor)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = (
			anchors_exact
			and str(anchors[index].name) == "DockMastCap%02d" % (index + 1)
			and anchors[index].transform.is_equal_approx(expected[index])
			and not anchors[index].visible
			and anchors[index].mesh != null
			and anchors[index].mesh.get_aabb().size.is_equal_approx(Vector3(0.86, 0.22, 0.86))
			and anchors[index].get_child_count() == 0
			and anchors[index].get_script() == null
		)
	var multi := batch.multimesh
	var render := module.get_render_batch_contract()
	_check(
		anchors_exact
		and multi.instance_count == FleetDockComb.DOCK_MAST_CAP_COPY_COUNT
		and multi.visible_instance_count == -1
		and multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.86, 0.22, 0.86))
		and multi.mesh.get_surface_count() == 1
		and batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and batch.material_override == anchors[0].material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.get_child_count() == 0
		and service.find_children("*", "CollisionObject3D", true, false).is_empty()
		and service.find_children("*", "Area3D", true, false).is_empty(),
		"mast-cap batch preserves exact transforms, deck-light material, shadows, culling layer and visual-only ownership"
	)
	_check(
		int(render.dock_mast_cap_copies) == 3
		and int(render.dock_mast_cap_renderer_buffer_floats) == 36
		and int(render.geometry_submissions) == 53
		and int(render.drawn_copies) == 101
		and bool(render.dock_mast_cap_renderer_buffer_matches_authored)
		and bool(render.dock_mast_cap_bounds_match_authored)
		and bool(render.dock_mast_cap_contract_matches),
		"mast caps reduce three visual submissions to one without changing rendered copies"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has("comb dock-mast-cap renderer buffer drifted from its authored roster"),
		"mutating one mast-cap transform is rejected by the production audit"
	)
	multi.buffer = original_buffer
	_check(module.get_validation_errors().is_empty(), "restoring the mast-cap batch restores a clean module audit")


func _test_dock_service_mast_batch(module: FleetDockComb) -> void:
	var service := module.get_node_or_null(^"GeneratedComb/SurfaceDetail/DockArmService") as Node3D
	var batch := module.get_node_or_null(
		^"GeneratedComb/SurfaceDetail/DockArmService/ServiceMastBatch"
	) as MultiMeshInstance3D
	_check(service != null and batch != null and batch.multimesh != null, "three dock service masts resolve as one service MultiMesh")
	if service == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(21.9, 1.8, 8.5)),
		Transform3D(Basis.IDENTITY, Vector3(21.9, 1.8, 25.0)),
		Transform3D(Basis.IDENTITY, Vector3(21.9, 4.2, 40.0)),
	]
	var anchors: Array[MeshInstance3D] = []
	for raw_node in service.get_children():
		if str(raw_node.name).begins_with("DockServiceMast"):
			var anchor := raw_node as MeshInstance3D
			if anchor != null:
				anchors.append(anchor)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = (
			anchors_exact
			and str(anchors[index].name) == "DockServiceMast%02d" % (index + 1)
			and anchors[index].transform.is_equal_approx(expected[index])
			and not anchors[index].visible
			and anchors[index].mesh != null
			and anchors[index].mesh.get_aabb().size.is_equal_approx(Vector3(0.52, 4.2, 0.52))
			and bool(anchors[index].get_meta("visual_detail_only", false))
			and bool(anchors[index].get_meta("non_authoritative_visual", false))
			and str(anchors[index].get_meta("non_walkable_reason", "")).contains("outboard")
			and anchors[index].get_child_count() == 0
			and anchors[index].get_script() == null
		)
	var multi := batch.multimesh
	var render := module.get_render_batch_contract()
	_check(
		anchors_exact
		and multi.instance_count == FleetDockComb.DOCK_SERVICE_MAST_COPY_COUNT
		and multi.visible_instance_count == -1
		and multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.52, 4.2, 0.52))
		and multi.mesh.get_surface_count() == 1
		and batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and batch.material_override == anchors[0].material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.get_child_count() == 0
		and service.find_children("*", "CollisionObject3D", true, false).is_empty()
		and service.find_children("*", "Area3D", true, false).is_empty(),
		"service-mast batch preserves exact cylinders, transforms, deck-light material and visual-only outboard ownership"
	)
	_check(
		int(render.dock_service_mast_copies) == 3
		and int(render.dock_service_mast_submissions_before) == 3
		and int(render.dock_service_mast_submissions_after) == 1
		and int(render.geometry_submissions_before_dock_service_mast_batch) == 57
		and int(render.geometry_submissions) == 53
		and int(render.drawn_copies) == 101
		and int(render.dock_service_mast_renderer_buffer_floats) == 36
		and bool(render.dock_service_mast_renderer_buffer_matches_authored)
		and bool(render.dock_service_mast_bounds_match_authored)
		and bool(render.dock_service_mast_contract_matches)
		and int(render.static_bodies) == 7
		and int(render.collision_shapes) == 7
		and int(render.route_markers) == 9
		and int(render.dock_landmarks) == 3,
		"service masts reduce 3 -> 1 submissions without changing copies, physics, routes or dock identities"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has("comb dock-service-mast renderer buffer drifted from its authored roster"),
		"mutating one live service-mast transform is rejected by the production audit"
	)
	multi.buffer = original_buffer
	_check(module.get_validation_errors().is_empty(), "restoring the service-mast batch restores a clean module audit")


func _test_dock_service_bracket_batch(module: FleetDockComb) -> void:
	var service := module.get_node_or_null(^"GeneratedComb/SurfaceDetail/DockArmService") as Node3D
	var batch := module.get_node_or_null(
		^"GeneratedComb/SurfaceDetail/DockArmService/DockServiceBrackets"
	) as MultiMeshInstance3D
	_check(service != null and batch != null and batch.multimesh != null, "three dock service brackets resolve as one service MultiMesh")
	if service == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(20.9, -0.3, 8.5)),
		Transform3D(Basis.IDENTITY, Vector3(20.9, -0.3, 25.0)),
		Transform3D(Basis.IDENTITY, Vector3(20.9, 2.1, 40.0)),
	]
	var anchors: Array[MeshInstance3D] = []
	for raw_node in service.get_children():
		if str(raw_node.name).begins_with("DockServiceBracket"):
			var anchor := raw_node as MeshInstance3D
			if anchor != null:
				anchors.append(anchor)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = (
			anchors_exact
			and str(anchors[index].name) == "DockServiceBracket%02d" % (index + 1)
			and anchors[index].transform.is_equal_approx(expected[index])
			and not anchors[index].visible
			and anchors[index].mesh != null
			and anchors[index].mesh.get_aabb().size.is_equal_approx(Vector3(2.6, 0.34, 0.90))
			and bool(anchors[index].get_meta("visual_detail_only", false))
			and bool(anchors[index].get_meta("non_authoritative_visual", false))
			and str(anchors[index].get_meta("non_walkable_reason", "")).contains("outboard")
			and anchors[index].get_child_count() == 0
			and anchors[index].get_script() == null
		)
	var multi := batch.multimesh
	var render := module.get_render_batch_contract()
	_check(
		anchors_exact
		and multi.instance_count == FleetDockComb.DOCK_SERVICE_BRACKET_COPY_COUNT
		and multi.visible_instance_count == -1
		and multi.mesh.get_aabb().size.is_equal_approx(Vector3(2.6, 0.34, 0.90))
		and multi.mesh.get_surface_count() == 1
		and batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and batch.material_override == anchors[0].material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.get_child_count() == 0
		and service.find_children("*", "CollisionObject3D", true, false).is_empty()
		and service.find_children("*", "Area3D", true, false).is_empty(),
		"service-bracket batch preserves exact transforms, frame material and visual-only outboard ownership"
	)
	_check(
		int(render.dock_service_bracket_copies) == 3
		and int(render.dock_service_bracket_submissions_before) == 3
		and int(render.dock_service_bracket_submissions_after) == 1
		and int(render.geometry_submissions_before_dock_service_bracket_batch) == 55
		and int(render.geometry_submissions) == 53
		and int(render.drawn_copies) == 101
		and int(render.dock_service_bracket_renderer_buffer_floats) == 36
		and bool(render.dock_service_bracket_renderer_buffer_matches_authored)
		and bool(render.dock_service_bracket_bounds_match_authored)
		and bool(render.dock_service_bracket_contract_matches)
		and int(render.static_bodies) == 7
		and int(render.collision_shapes) == 7
		and int(render.route_markers) == 9
		and int(render.dock_landmarks) == 3,
		"service brackets reduce 3 -> 1 submissions without changing copies, physics, routes or dock identities"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has("comb dock-service-bracket renderer buffer drifted from its authored roster"),
		"mutating one service-bracket transform is rejected by the production audit"
	)
	multi.buffer = original_buffer
	_check(module.get_validation_errors().is_empty(), "restoring the service-bracket batch restores a clean module audit")


## Re-frozen in the open twice: light count 0 -> 4, then 4 -> 7, everything else
## unchanged. Both equalities stayed exact; neither was widened into a range.
##
## The 4 -> 7 step belongs to the dock-arm service pass, and it is the same
## mechanism as the 0 -> 4 step below: each arm's new mast status lens is an
## emissive mesh, emission illuminates nothing in Forward+, so without a
## practical the lens is one more glowing decal on unlit plate. The three
## additions are one amber spill per mast head. The mesh-instance ceiling moved
## with them (64 -> 107 against a built 58 -> 100) and is asserted through
## `within_budget`; the collision, label, marker and loop figures below are
## untouched and still exact, which is the claim that matters — the pass added no
## body, no shape, no label and no process loop.
##
## The comb was the only station module carrying no light at all, so its status
## stripes, corner beacons, rung edge cues and trunk route lights rendered as
## flat painted decals on unlit plate — emission does not illuminate anything in
## Forward+, and the glow pass only convolves the finished image. The four are
## one amber practical over each of the three dock slabs and one over the trunk's
## middle route light. The equality stays exact rather than becoming a ceiling,
## and the properties that made this module cheap are asserted separately below:
## every light must be shadowless and range-bounded, and both loop budgets stay
## at zero.
func _test_performance_contract(module: FleetDockComb) -> void:
	var performance := module.get_performance_contract()
	_check(bool(performance.within_budget), "module stays within every fixed geometry and processing budget")
	_check(int(performance.static_bodies) == 7 and int(performance.collision_shapes) == 7, "performance report agrees with the exact collision roster")
	_check(int(performance.labels) == 3 and int(performance.lights) == 7, "presentation contains exactly three labels and seven practical light nodes")
	_check(int(performance.process_loops) == 0, "static module allocates no frame or physics process loop")
	var practicals_are_restrained := true
	var lights := module.find_children("*", "Light3D", true, false)
	for raw_light in lights:
		var light := raw_light as OmniLight3D
		practicals_are_restrained = practicals_are_restrained \
			and light != null \
			and not light.shadow_enabled \
			and light.distance_fade_enabled \
			and light.omni_range <= 8.0 \
			and bool(light.get_meta("fixture_practical", false))
	_check(
		lights.size() == 7 and practicals_are_restrained,
		"every comb light is a shadowless, range-bounded, distance-faded fixture practical"
	)


## The dock-arm service pass, asserted on its three design rules rather than on
## a mesh count.
##
## 1. Every generated individual surface-detail MeshInstance — the new service
##    hardware *and* the deck cues that were already there — shares volume with
##    some other mesh in the module. The batched trunk joints are checked against
##    the trunk explicitly above. This is the "random objects floating in the
##    air" class stated as an assertion, and it is worth having here rather than
##    only in the world-level witness roster for two reasons: the module is instantiated in
##    isolation, so there is no other geometry for a floater to accidentally
##    touch; and the world-level roster is a curated list of paths, which cannot
##    see a new floater nobody thought to add to it. It is deliberately widened
##    past the new hardware because widening it is what found COMB-DECK-CUE-001 —
##    three trunk route lights hovering 0.020 m and four rung edge cues 0.025 m
##    over decks they are supposed to be inlaid into, live since the cues were
##    authored and invisible to every check in the project.
## 2. Nothing tall stands on a walking plate. The module carries no collision on
##    dressing, so a waist-height object on a slab would be a solid-looking thing
##    a player walks through. Anything rising more than 0.25 m above its slab must
##    therefore be outboard of the slab's own x extent, over the void.
## 3. The service group stays presentation. No body, no shape, no area.
##
## Rule 2 is the structured-red target: move any mast inboard onto the plate and
## this turns red while every count above stays green.
func _test_dock_arm_service_hardware(module: FleetDockComb) -> void:
	var roster := module.get_component_roster()
	# `deployed_service_boom_count` was 1 and is now 2, re-frozen in the open: the
	# Halyard berth pass put a 28 m crew transport on arm 02 and the module already
	# counts that arm as an external assignment, but the hardware kept testing the
	# slab index instead of the dock's status and so stayed stowed and blanked under
	# a berthed craft. All three assigned arms run their booms out.
	_check(
		int(roster.dock_service_mast_count) == 3
		and int(roster.dock_mooring_cleat_count) == 6
		and int(roster.deployed_service_boom_count) == 3,
		"every arm carries a service mast and two mooring cleats, and all three assigned arms are run out"
	)
	_check(
		int(roster.deployed_service_boom_count) == int(roster.assigned_dock_count),
		"the number of arms run out is the number of arms with a craft assigned to them"
	)

	var service := module.find_child("DockArmService", true, false) as Node3D
	_check(service != null, "generated dock-service group resolves under the surface detail root")
	if service == null:
		return
	_check(
		service.find_children("*", "CollisionObject3D", true, false).is_empty()
		and service.find_children("*", "Area3D", true, false).is_empty(),
		"dock-arm service hardware introduces no collision body, shape or area"
	)

	var module_boxes: Array[AABB] = []
	var module_geometry_owners: Array[GeometryInstance3D] = []
	for raw in module.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		module_geometry_owners.append(mesh_instance)
		module_boxes.append((mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs())
	# MultiMesh copies are equally real presentation geometry. Include each exact
	# authored copy so neighbouring cap/lamp mounting checks still see the mast
	# after its visible cylinder moves out of the individual MeshInstance roster.
	for raw in module.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := raw as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null or not batch.is_visible_in_tree():
			continue
		var authored := batch.get_meta("authored_instance_transforms", []) as Array
		for transform_value in authored:
			module_geometry_owners.append(batch)
			module_boxes.append(
				(batch.global_transform * (transform_value as Transform3D) * batch.multimesh.mesh.get_aabb()).abs()
			)

	var detail := service.get_parent() as Node3D
	_check(detail != null and detail.name == &"SurfaceDetail", "service group hangs under the generated surface-detail root")
	if detail == null:
		return

	var floating := PackedStringArray()
	var standing_on_a_plate := PackedStringArray()
	# Local x extent of every walkable plate in the module: the trunk reaches
	# x = 2.4, the rungs x = 9.0, the slabs x = 21.0.
	var outboard_of_every_plate := 21.0
	for raw in detail.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		# Rule 2 is scoped to the service group, whose node names are all authored
		# and unique. The older repeated cues are renamed by the engine to
		# `@MeshInstance3D@N`, and a generated name can contain "03" by accident,
		# which would score a slab-03 beacon against the lower deck and flag it.
		var in_service_group := service.is_ancestor_of(mesh_instance)
		var local_box := AABB()
		var first_corner := true
		for x_ratio in [0.0, 1.0]:
			for y_ratio in [0.0, 1.0]:
				for z_ratio in [0.0, 1.0]:
					var mesh_aabb := mesh_instance.mesh.get_aabb()
					var corner := mesh_aabb.position + mesh_aabb.size * Vector3(x_ratio, y_ratio, z_ratio)
					var local_point := module.global_transform.affine_inverse() \
						* (mesh_instance.global_transform * corner)
					if first_corner:
						local_box = AABB(local_point, Vector3.ZERO)
						first_corner = false
					else:
						local_box = local_box.expand(local_point)
		# The part's own arm decides its reference plate: arms 01 and 02 walk at
		# y = 0 and arm 03 at y = 2.4. Reading it from the name rather than from
		# the geometry matters, because arm 03's bracket is *buried inside* its
		# slab section and a "nearest plate below" rule would score it against the
		# lower deck 2.4 m away and flag it.
		var plate_top := 2.4 if str(mesh_instance.name).contains("03") else 0.0
		if in_service_group and local_box.end.y - plate_top > 0.25 and local_box.position.x < outboard_of_every_plate:
			standing_on_a_plate.append("%s @ %s" % [str(mesh_instance.name), str(local_box)])

		var world_box := (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs()
		var grown := world_box.grow(0.001)
		var touched := false
		for index in module_boxes.size():
			if module_geometry_owners[index] == mesh_instance:
				continue
			if grown.intersects(module_boxes[index]):
				touched = true
				break
		if not touched:
			floating.append("%s @ %s" % [str(mesh_instance.name), str(world_box)])
	floating.sort()
	standing_on_a_plate.sort()
	print("COMB_SERVICE_FLOATING: ", floating)
	print("COMB_SERVICE_ON_PLATE: ", standing_on_a_plate)
	_check(floating.is_empty(), "every generated comb surface-detail mesh shares volume with the geometry it is mounted to")
	_check(
		standing_on_a_plate.is_empty(),
		"nothing over 0.25 m tall stands on a walkable plate the module does not collide"
	)


func _test_reversible_lifecycle(module: FleetDockComb) -> void:
	var initial := module.get_lifecycle_contract()
	var initial_ids := initial.surface_instance_ids as PackedInt64Array
	_check(bool(initial.enabled) and bool(initial.visible_matches_enabled) and bool(initial.collision_matches_enabled), "fresh lifecycle is visibly and physically enabled")
	module.set_module_enabled(false)
	await physics_frame
	var disabled := module.get_lifecycle_contract()
	_check(not bool(disabled.enabled) and bool(disabled.visible_matches_enabled) and bool(disabled.collision_matches_enabled), "disabled lifecycle hides geometry and clears collision atomically")
	_check(int(module.get_collision_contract().active_body_count) == 0 and bool(module.get_audit_report().valid), "intentional disabled state remains valid with no active bodies")
	var disabled_hit := await _ray_local(module, Vector3(0, 2, 4), Vector3(0, -2, 4))
	_check(disabled_hit.is_empty(), "disabled lifecycle removes the trunk from World collision")

	module.set_module_enabled(true)
	await physics_frame
	var restored := module.get_lifecycle_contract()
	_check(bool(restored.enabled) and restored.surface_instance_ids == initial_ids, "re-enable restores the exact original surfaces without rebuilding")
	_check(int(restored.build_generation) == 1 and not bool(restored.runtime_rebuild_allowed), "lifecycle remains a single-build identity-preserving component")
	var restored_hit := await _ray_local(module, Vector3(0, 2, 4), Vector3(0, -2, 4))
	_check(not restored_hit.is_empty(), "re-enabled lifecycle restores physical trunk collision")

	var live_snapshot := _lifecycle_snapshot(module)
	_test_root.remove_child(module)
	module.set_module_enabled(false)
	_check(
		_lifecycle_snapshot(module) == live_snapshot,
		"detached direct disable leaves retained enabled, generated visibility, and surface collision state unchanged"
	)
	_test_root.add_child(module)
	await process_frame
	await physics_frame
	_check(module.get_lifecycle_contract().surface_instance_ids == initial_ids and bool(module.get_audit_report().valid), "detach and re-add preserves identities and a valid lifecycle")
	module.set_module_enabled(false)
	_check(
		not module.is_module_enabled()
		and bool(module.get_lifecycle_contract().visible_matches_enabled)
		and bool(module.get_lifecycle_contract().collision_matches_enabled),
		"re-added comb accepts a fresh live disable"
	)
	module.set_module_enabled(true)
	_check(
		_lifecycle_snapshot(module) == live_snapshot,
		"fresh live re-enable restores retained enabled, generated visibility, and surface collision state"
	)
	module.queue_free()
	module.set_module_enabled(false)
	_check(
		_lifecycle_snapshot(module) == live_snapshot,
		"queued direct disable leaves retained enabled, generated visibility, and surface collision state unchanged"
	)


func _lifecycle_snapshot(module: FleetDockComb) -> Dictionary:
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
	var generated := module.get_node_or_null(^"GeneratedComb") as Node3D
	return {
		"enabled": module.is_module_enabled(),
		"generated_visible": generated.visible if generated != null else false,
		"body_states": body_states,
	}.duplicate(true)


func _test_cleanup(module: FleetDockComb) -> void:
	var module_reference: WeakRef = weakref(module)
	var surface_reference: WeakRef = weakref(module.find_child("Trunk", true, false))
	module.queue_free()
	module = null
	await process_frame
	await physics_frame
	await process_frame
	_check(module_reference.get_ref() == null and surface_reference.get_ref() == null, "module and generated surfaces release cleanly without retained lifecycle state")
	_test_root.queue_free()
	await process_frame


## More than one dock is assigned now, so rows are selected by their stable dock
## id instead of by roster position.
func _find_assigned_dock(assigned: Array[Dictionary], dock_id: StringName) -> Dictionary:
	for entry in assigned:
		if entry.get("dock_id", &"") == dock_id:
			return entry
	return {}


func _ray_local(module: FleetDockComb, local_from: Vector3, local_to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(module.to_global(local_from), module.to_global(local_to), WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_ray(query)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_DOCK_COMB_TEST_OK")
		quit(0)
	else:
		print("FLEET_DOCK_COMB_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
