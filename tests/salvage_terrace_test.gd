extends SceneTree

## Focused contract, mutation, and embodied traversal proof for Salvage Terrace.

const MODULE_SCENE := preload("res://scenes/world/modules/salvage_terrace.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WORLD_LAYER := 1
const CAPTURE_PATH := "/tmp/salvage-terrace-forward-plus.png"

var _failures: Array[String] = []
var _assertions := 0
var _test_root: Node3D


func _init() -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		call_deferred("_capture_forward_plus")
	else:
		call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "SalvageTerraceTestRoot"
	root.add_child(_test_root)
	var module := MODULE_SCENE.instantiate() as SalvageTerrace
	_test_root.add_child(module)
	await process_frame
	await physics_frame

	_check(module != null, "standalone Salvage Terrace scene instantiates")
	if module == null:
		_finish()
		return

	_test_evidence_and_shared_contract(module)
	_test_origin_slot_and_routes(module)
	await _test_exact_surface_union(module)
	_test_rails_dressing_and_authority(module)
	_test_short_side_rail_visual_sharing(module)
	_test_performance_and_lifecycle(module)
	await _test_queued_module_enable_guard()
	await _test_real_player_ramp_traversal(module)
	await _test_mutations_turn_audit_red(module)
	await _test_cleanup(module)
	_finish()


func _test_evidence_and_shared_contract(module: SalvageTerrace) -> void:
	var audit := module.get_audit_report()
	var evidence := module.get_evidence_metadata()
	_check(bool(audit.valid), "fresh standalone module passes its complete audit")
	_check(module.get_module_id() == &"salvage-terrace", "module publishes its stable integration id")
	_check(
		evidence.element_status == &"new"
		and evidence.evidence_status == &"modern_interpretation"
		and evidence.source_confidence == &"none"
		and not bool(evidence.source_bounded),
		"entire module is explicitly NEW modern interpretation at confidence none"
	)
	_check(
		not bool(evidence.authenticated_original_geometry)
		and not bool(evidence.authenticated_original_function)
		and (evidence.references as PackedStringArray).is_empty()
		and (evidence.claim_ids as PackedStringArray).is_empty(),
		"module makes no recovered geometry, function, reference, or claim-id assertion"
	)
	var shared := StationModuleContract.new().validate_contract(module)
	_check(bool(shared.valid), "module satisfies the reusable StationModuleContract surface")
	_check(
		bool(module.get_meta("station_module", false))
		and module.get_meta("element_status") == &"new"
		and module.get_meta("evidence_status") == &"modern_interpretation"
		and not bool(module.get_meta("source_bounded", true))
		and not module.is_in_group(&"source_bounded_station_modules"),
		"discovery metadata preserves the NEW evidence boundary"
	)


func _test_origin_slot_and_routes(module: SalvageTerrace) -> void:
	var expected_routes: Array[StringName] = [
		&"connector", &"entry", &"lower-pad", &"main-ramp-base", &"upper-pad",
		&"inspection-ramp-base", &"inspection-pad",
	]
	_check(module.get_route_ids() == expected_routes, "route API publishes the exact ordered seven-node local path")
	for route_id in expected_routes:
		_check(
			module.has_route_marker(route_id)
			and module.get_route_marker(route_id) != null
			and module.get_route_transform(route_id).is_equal_approx(
				module.get_route_marker(route_id).global_transform
			),
			"route marker resolves exactly: %s" % route_id
		)
	_check(not module.has_route_marker(&"invented"), "unknown route has no invented fallback")
	var slot := StationModuleContract.new().capture_connection_slot(module, &"connector")
	var slots: Array = module.get_connection_slot_contract()
	_check(
		slots.size() == 1
		and slot.slot_id == &"hub-salvage-terrace"
		and slot.route_id == &"connector"
		and module.get_module_anchor().transform.is_equal_approx(Transform3D.IDENTITY)
		and module.get_route_marker(&"connector").position.is_equal_approx(Vector3(0, 0.15, 0)),
		"one named connection slot sits exactly on the clear local-origin plane"
	)
	var footprint := module.get_integration_footprint()
	_check(
		bool(footprint.connection_at_local_origin)
		and footprint.connection_plane_local == Transform3D.IDENTITY
		and footprint.approach_axis_local == Vector3.FORWARD
		and (footprint.local_min as Vector3).is_equal_approx(Vector3(-18.1, -1.8, -0.7))
		and (footprint.local_size as Vector3).is_equal_approx(Vector3(45.4, 8.9, 18.8)),
		"integration footprint and local-origin approach convention are finite and exact"
	)


func _test_exact_surface_union(module: SalvageTerrace) -> void:
	var surfaces := module.get_standable_surface_contract()
	var expected_ids := PackedStringArray([
		"connection-apron", "lower-salvage-pad", "main-service-ramp",
		"upper-inspection-pad", "inspection-ramp", "top-inspection-pad",
	])
	var live_ids := PackedStringArray()
	var projected_sum := 0.0
	var true_sum := 0.0
	var unique_bodies := {}
	var all_supported := true
	for surface in surfaces:
		var surface_id := StringName(surface.surface_id)
		live_ids.append(str(surface_id))
		projected_sum += float(surface.horizontal_area_m2)
		true_sum += float(surface.true_area_m2)
		var body := module.get_node(surface.body_path as NodePath) as StaticBody3D
		if body != null:
			unique_bodies[body.get_instance_id()] = true
		all_supported = all_supported and body != null
		all_supported = all_supported and bool(body.get_meta("walkable_surface", false))
		all_supported = all_supported and StringName(body.get_meta("walkable_surface_id", &"")) == surface_id
		all_supported = all_supported and StringName(body.get_meta("walkable_surface_kind", &"")) == surface.kind
		all_supported = all_supported and StringName(body.get_meta("walkable_surface_owner", &"")) == &"salvage-terrace"
		if body != null:
			var center := body.global_position
			var hit := await _ray(module, center + Vector3.UP * 4.0, center + Vector3.DOWN * 4.0)
			all_supported = all_supported and hit.get("collider") == body
	live_ids.sort()
	expected_ids.sort()
	_check(
		surfaces.size() == 6 and unique_bodies.size() == 6 and live_ids == expected_ids,
		"every standable surface has one unique stable id and collision body"
	)
	_check(all_supported, "all six authoritative usable bodies carry exact census tags and real World support")
	var area := module.get_walkable_area_contract()
	print("SALVAGE_TERRACE_AREA: ", area)
	_check(
		area.surface_union == &"non_overlapping_shared_boundaries_only"
		and bool(area.live_geometry_derived)
		and bool(area.live_geometry_valid)
		and bool(area.projection_axis_aligned)
		and bool(area.non_overlapping)
		and is_equal_approx(float(area.projected_surface_sum_m2), 456.0)
		and is_equal_approx(float(area.level_area_m2), 384.0)
		and is_equal_approx(float(area.ramp_projected_area_m2), 72.0)
		and is_equal_approx(float(area.horizontal_walkable_area_m2), 456.0)
		and is_equal_approx(projected_sum, 456.0),
		"non-overlapping horizontal union is exactly 456.0 square metres"
	)
	_check(
		is_equal_approx(float(area.main_ramp_true_area_m2), 52.636109)
		and is_equal_approx(float(area.inspection_ramp_true_area_m2), 26.318054)
		and is_equal_approx(float(area.ramp_true_area_m2), 78.954163)
		and is_equal_approx(true_sum, 462.954163)
		and not bool(area.baseline_share_claimed),
		"true ramp areas are explicit and no unsupported station-baseline percentage is claimed"
	)
	var roster := module.get_component_roster()
	_check(
		int(roster.usable_pad_count) == 3
		and (roster.usable_pad_ids as PackedStringArray) == PackedStringArray([
			"lower-salvage-pad", "upper-inspection-pad", "top-inspection-pad",
		])
		and int(roster.ramp_count) == 2,
		"three spatially distinct usable pads are joined by two declared broad ramps"
	)
	var by_surface := area.by_surface as Dictionary
	_check(
		float((by_surface[&"main-service-ramp"] as Dictionary).horizontal_area_m2) == 48.0
		and float((by_surface[&"inspection-ramp"] as Dictionary).horizontal_area_m2) == 24.0,
		"both broad ramps publish exact projected contribution rather than hidden stair area"
	)


func _test_rails_dressing_and_authority(module: SalvageTerrace) -> void:
	var roster := module.get_component_roster()
	var collision := module.get_collision_contract()
	_check(
		int(roster.safety_rail_count) == 20
		and int(collision.safety_rail_count) == 20
		and bool(collision.all_layers_match_lifecycle)
		and bool(collision.all_masks_zero),
		"twenty continuous physical rail segments guard exposed terrace and ramp edges"
	)
	var rail_shapes_valid := true
	for raw_rail in module.find_children("*", "StaticBody3D", true, false):
		var rail := raw_rail as StaticBody3D
		if bool(rail.get_meta("safety_rail", false)):
			rail_shapes_valid = rail_shapes_valid and rail.find_children("*", "CollisionShape3D", true, false).size() == 1
	_check(rail_shapes_valid, "every safety rail is a real one-shape World barrier, not presentation trim")
	_check(
		int(roster.multimesh_batch_count) == 6
		and module.find_children("*", "MultiMeshInstance3D", true, false).size() == 6,
		"supports, stock, markers, open rails, framing, and sorting machinery use six bounded batches"
	)
	var rail_detail := module.get_node_or_null(^"GeneratedRoot/RailDetailBatch") as MultiMeshInstance3D
	var hidden_rail_colliders := true
	for raw_rail in module.find_children("*", "StaticBody3D", true, false):
		var rail_body := raw_rail as StaticBody3D
		if bool(rail_body.get_meta("safety_rail", false)):
			var visual_path_node := rail_body.get_node(^"Mesh") as Node3D
			hidden_rail_colliders = hidden_rail_colliders and (
				(visual_path_node is Marker3D and bool(
					visual_path_node.get_meta("renderer_elided_anchor", false)
				))
				or (visual_path_node is MeshInstance3D and not (
					visual_path_node as MeshInstance3D
				).visible)
			)
	_check(
		hidden_rail_colliders and rail_detail != null and rail_detail.multimesh != null
		and rail_detail.multimesh.instance_count == 126,
		"conservative rail colliders are invisible while one batch draws open top/mid rails and regular posts"
	)
	_check(
		bool(roster.salvage_work_bay_present)
		and int(roster.work_light_count) == 3
		and module.get_node_or_null(^"GeneratedRoot/LowerBayRoof") != null
		and module.get_node_or_null(^"GeneratedRoot/CraneBridge") != null
		and module.get_node_or_null(^"GeneratedRoot/SortingMachineryBatch") != null
		and module.get_node_or_null(^"GeneratedRoot/UpperInspectionConsole") != null,
		"finished terrace reads as a covered salvage work bay with crane, sorting line, inspection console, and three local work lights"
	)
	var work_lights := module.find_children("*", "OmniLight3D", true, false)
	var lights_are_bounded := work_lights.size() == 3
	for raw_light in work_lights:
		var light := raw_light as OmniLight3D
		lights_are_bounded = lights_are_bounded and not light.shadow_enabled \
			and light.omni_range <= 6.5 and light.light_energy <= 1.4
	_check(lights_are_bounded, "work lighting is local, shadow-free, and bounded to the salvage terraces")
	var reasons_complete := true
	for visual in module.find_children("*", "MeshInstance3D", true, false):
		var mesh := visual as MeshInstance3D
		if mesh.get_parent() == module.get_node(^"GeneratedRoot"):
			reasons_complete = reasons_complete and not str(mesh.get_meta("non_walkable_reason", "")).is_empty()
	_check(reasons_complete, "every collision-free dressing mesh states why it is non-walkable")
	var sign_back := module.get_node(^"GeneratedRoot/IdentitySignBack") as MeshInstance3D
	_check(
		sign_back != null
		and sign_back.position.is_equal_approx(Vector3(-4.0, 2.1, -0.5))
		and bool(sign_back.get_meta("outside_walkable_union", false))
		and sign_back.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"collision-free identity sign is explicitly behind the entry rail and outside usable floor"
	)
	var support_batch := module.get_node(^"GeneratedRoot/TerraceSupportBatch") as MultiMeshInstance3D
	var upper_supports_meet_deck := support_batch != null and support_batch.multimesh != null
	if upper_supports_meet_deck:
		var support_mesh := support_batch.multimesh.mesh as BoxMesh
		var support_buffer := support_batch.multimesh.buffer
		for support_index in range(4, 8):
			var support_top := support_buffer[support_index * 12 + 7] + support_mesh.size.y * 0.5
			upper_supports_meet_deck = upper_supports_meet_deck and is_equal_approx(support_top, 3.3)
	_check(upper_supports_meet_deck, "four upper-pad support columns meet the live deck underside without a visible gap")
	var authority := module.get_authority_contract()
	_check(
		int(authority.ship_berth_count) == 0
		and int(authority.landing_or_interaction_area_count) == 0
		and int(authority.audio_node_count) == 0
		and int(authority.activity_node_count) == 0
		and int(authority.ship_authority_count) == 0
		and int(authority.berth_authority_count) == 0
		and int(authority.combat_authority_count) == 0
		and int(authority.interaction_authority_count) == 0
		and int(authority.station_activity_authority_count) == 0,
		"module owns zero ship, berth, combat, interaction, audio, and station-activity authority"
	)


func _test_short_side_rail_visual_sharing(module: SalvageTerrace) -> void:
	var report := module.get_short_side_rail_visual_allocation_audit()
	print(
		"SALVAGE_TERRACE_SHORT_SIDE_RAIL_VISUALS: "
		+ "renderers %d->%d submissions %d->%d mesh_resources %d->%d copies %d->%d" % [
			int(report.before.renderer_nodes), int(report.current.renderer_nodes),
			int(report.before.structural_submissions),
			int(report.current.structural_submissions),
			int(report.before.mesh_resource_allocations),
			int(report.current.mesh_resource_allocations),
			int(report.before.visible_geometry_copies),
			int(report.current.visible_geometry_copies),
		]
	)
	_check(
		bool(report.valid)
		and report.before == {
			"stable_path_nodes": 4,
			"renderer_nodes": 4,
			"visible_geometry_copies": 0,
			"structural_submissions": 4,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
			"physical_rail_bodies": 4,
			"collision_shapes": 4,
			"collision_resource_allocations": 4,
		}
		and report.current == {
			"stable_path_nodes": 4,
			"renderer_nodes": 0,
			"visible_geometry_copies": 0,
			"structural_submissions": 0,
			"mesh_resource_allocations": 0,
			"material_resource_allocations": 0,
			"physical_rail_bodies": 4,
			"collision_shapes": 4,
			"collision_resource_allocations": 4,
		},
		"four short-side paths stay exact while hidden renderers/submissions drop 4->0 and mesh resources 1->0"
	)
	_check(
		report.reductions.stable_path_nodes == 0
		and report.reductions.renderer_nodes == 4
		and report.reductions.structural_submissions == 4
		and report.reductions.mesh_resource_allocations == 1
		and report.reductions.physical_rail_bodies == 0
		and report.reductions.collision_shapes == 0
		and not bool(report.batched)
		and bool(report.renderer_elided)
		and not bool(report.frame_time_claimed)
		and not bool(report.gpu_draw_call_claimed)
		and not bool(report.vram_claimed)
		and not bool(report.whole_scene_budget_claimed)
		and not bool(report.pixel_equivalence_claimed),
		"allocation evidence records renderer elision without timing, GPU, VRAM, whole-scene, or pixel claims"
	)

	var anchors: Array[Marker3D] = []
	var bodies: Array[StaticBody3D] = []
	var collision_resource_ids := {}
	for rail_name in [
		"EntryPortForward", "EntryStarboardForward",
		"UpperInboardForward", "UpperInboardAft",
	]:
		var body := module.get_node(NodePath("GeneratedRoot/%s" % rail_name)) as StaticBody3D
		var anchor := body.get_node(^"Mesh") as Marker3D
		var collision := body.get_node(^"Collision") as CollisionShape3D
		bodies.append(body)
		anchors.append(anchor)
		collision_resource_ids[collision.shape.get_instance_id()] = true
	var exact_paths_and_resources := true
	for index in anchors.size():
		exact_paths_and_resources = (
			exact_paths_and_resources
			and anchors[index] != null
			and anchors[index].transform.is_equal_approx(Transform3D.IDENTITY)
			and bool(anchors[index].get_meta("renderer_elided_anchor", false))
			and bodies[index].get_child_count() == 2
			and bool(bodies[index].get_meta("safety_rail", false))
		)
	_check(
		exact_paths_and_resources
		and collision_resource_ids.size() == 4,
		"four stable Mesh anchor paths retain exact transforms and four private colliders without renderers"
	)
	_check(
		int(report.scripted_node_count) == 0
		and int(report.foreign_authority_node_count) == 0
		and int(report.processing_node_count) == 0,
		"renderer-elided paths add no script, processing loop, or foreign gameplay authority"
	)
	var long_report := module.get_long_rail_visual_allocation_audit()
	_check(
		bool(long_report.valid)
		and int(long_report.visual_copies) == 3
		and int(long_report.legacy_mesh_resource_allocations) == 3
		and int(long_report.mesh_resource_allocations) == 1
		and int(long_report.mesh_resource_allocation_delta) == -2
		and int(long_report.collision_resource_allocations) == 3,
		"three long safety rails share 3->1 visual meshes while retaining three private collision shapes"
	)
	var four_meter_report := module.get_four_meter_rail_visual_allocation_audit()
	_check(
		bool(four_meter_report.valid)
		and int(four_meter_report.visual_copies) == 4
		and int(four_meter_report.legacy_mesh_resource_allocations) == 4
		and int(four_meter_report.mesh_resource_allocations) == 2
		and int(four_meter_report.mesh_resource_allocation_delta) == -2
		and int(four_meter_report.collision_resource_allocations) == 4,
		"four 4 m safety rails share orientation-compatible visuals 4->2 while retaining four private collision shapes"
	)
	var four_meter_meshes := {}
	var four_meter_collision_ids := {}
	for rail_name in ["EntryFrontPort", "EntryFrontStarboard", "TopPort", "TopStarboard"]:
		var rail := module.get_node(NodePath("GeneratedRoot/%s" % rail_name)) as StaticBody3D
		var visual := rail.get_node(^"Mesh") as MeshInstance3D
		var collision := rail.get_node(^"Collision") as CollisionShape3D
		four_meter_meshes[visual.mesh.get_instance_id()] = true
		four_meter_collision_ids[collision.shape.get_instance_id()] = true
	_check(
		four_meter_meshes.size() == 2
		and four_meter_collision_ids.size() == 4
		and bool(four_meter_report.visual_aabbs_match_collision),
		"four 4 m rail paths preserve exact visual/collision AABBs and private collision resources with two oriented meshes"
	)
	var top_port := module.get_node(^"GeneratedRoot/TopPort/Mesh") as MeshInstance3D
	var entry_port := module.get_node(^"GeneratedRoot/EntryFrontPort/Mesh") as MeshInstance3D
	if top_port != null and entry_port != null:
		var original_top_port_mesh := top_port.mesh
		top_port.mesh = entry_port.mesh
		var aabb_red := module.get_four_meter_rail_visual_allocation_audit()
		var aabb_full_audit_red := module.get_audit_report()
		top_port.mesh = original_top_port_mesh
		_check(
			not bool(aabb_red.valid)
			and (aabb_red.errors as PackedStringArray).has("four_meter_rail_visual_aabb_drift")
			and not bool(aabb_red.visual_aabbs_match_collision)
			and not bool(aabb_full_audit_red.valid)
			and bool(module.get_four_meter_rail_visual_allocation_audit().valid)
			and bool(module.get_audit_report().valid),
			"MUTATION: assigning an X-oriented mesh to one Z-oriented rail turns the AABB and full audits red"
		)
	if top_port != null:
		var original_four_meter_mesh := top_port.mesh
		top_port.mesh = original_four_meter_mesh.duplicate() as BoxMesh
		var four_meter_red := module.get_four_meter_rail_visual_allocation_audit()
		var four_meter_full_audit_red := module.get_audit_report()
		top_port.mesh = original_four_meter_mesh
		_check(
			not bool(four_meter_red.valid)
			and (four_meter_red.errors as PackedStringArray).has("four_meter_rail_visual_mesh_count_drift")
			and not bool(four_meter_full_audit_red.valid)
			and bool(module.get_four_meter_rail_visual_allocation_audit().valid)
			and bool(module.get_audit_report().valid),
			"splitting one oriented 4 m rail visual mesh turns the full audit red and restores cleanly"
		)
	var long_aft := module.get_node(^"GeneratedRoot/LowerAft/Mesh") as MeshInstance3D
	if long_aft != null:
		var original_long_mesh := long_aft.mesh
		long_aft.mesh = original_long_mesh.duplicate() as BoxMesh
		var long_red := module.get_long_rail_visual_allocation_audit()
		var full_audit_red := module.get_audit_report()
		long_aft.mesh = original_long_mesh
		_check(
			not bool(long_red.valid)
			and (long_red.errors as PackedStringArray).has("long_rail_visual_mesh_count_drift")
			and not bool(full_audit_red.valid)
			and bool(module.get_long_rail_visual_allocation_audit().valid)
			and bool(module.get_audit_report().valid),
			"splitting one long-rail visual mesh turns the full audit red and restores cleanly"
		)

	(report.current as Dictionary)["mesh_resource_allocations"] = -1
	(report.behavior_rows as Array).clear()
	var detached := module.get_short_side_rail_visual_allocation_audit()
	_check(
		int(detached.current.mesh_resource_allocations) == 0
		and (detached.behavior_rows as Array).size() == 4,
		"component-local allocation evidence is deeply detached from caller mutation"
	)

	var original_anchor_transform := anchors[1].transform
	anchors[1].position.x += 0.01
	var anchor_mutation := module.get_short_side_rail_visual_allocation_audit()
	_check(
		not bool(anchor_mutation.valid)
		and (anchor_mutation.errors as PackedStringArray).has(
			"short_side_rail_visual_anchor_state_drift"
		)
		and _errors_include(
			module.get_validation_errors(),
			"shared safety-rail visual allocation contract"
		),
		"MUTATION: moving one stable renderer-elision anchor turns the module audit red"
	)
	anchors[1].transform = original_anchor_transform
	_check(
		bool(module.get_audit_report().valid),
		"restoring the exact stable anchor transform returns the full module audit green"
	)


func _test_performance_and_lifecycle(module: SalvageTerrace) -> void:
	var performance := module.get_performance_contract()
	print("SALVAGE_TERRACE_PERFORMANCE: ", performance)
	_check(bool(performance.within_budget) and bool(performance.exact_census), "module exactly matches every published performance count")
	_check(
		int(performance.mesh_instances) == 36
		and int(performance.static_bodies) == 26
		and int(performance.collision_shapes) == 26
		and int(performance.lights) == 3
		and int(performance.labels) == 1
		and int(performance.multimesh_batches) == 6
		and int(performance.multimesh_instances) == 164
		and int(performance.multimesh_drawn_copies) == 164
		and int(performance.multimesh_buffer_floats) == 1968
		and int(performance.geometry_submissions) == 42
		and int(performance.visible_geometry_copies) == 200
		and int(performance.nodes) == 112
		and int(performance.process_loops) == 0
		and int(performance.physics_process_loops) == 0,
		"exact census freezes 42 submissions, 200 authored copies, 26 bodies/shapes, 112 nodes, one label, three bounded lights, and zero loops"
	)
	_check(
		bool(performance.buffers_match_authored)
		and (performance.batch_instance_counts as Dictionary) == {
			&"TerraceSupportBatch": 10,
			&"SalvageCageBatch": 6,
			&"ServiceBeaconBatch": 4,
			&"SalvageFrameBatch": 10,
			&"SortingMachineryBatch": 8,
			&"RailDetailBatch": 126,
		},
		"six MultiMesh batches freeze all 164 structural, machinery, and open-rail transforms in 1968 raw buffer floats"
	)
	var before := module.get_lifecycle_contract()
	module.set_module_enabled(false)
	var disabled := module.get_lifecycle_contract()
	_check(
		not module.is_module_enabled()
		and bool(disabled.reversible)
		and bool(disabled.visible_matches_enabled)
		and bool(disabled.collision_matches_enabled)
		and not module.get_node(^"GeneratedRoot").visible,
		"disable hides presentation and clears collision without rebuilding"
	)
	module.set_module_enabled(true)
	var restored := module.get_lifecycle_contract()
	_check(
		module.is_module_enabled()
		and restored.surface_instance_ids == before.surface_instance_ids
		and int(restored.build_generation) == 1
		and bool(module.get_short_side_rail_visual_allocation_audit().valid)
		and bool(module.get_audit_report().valid),
		"re-enable restores identical nodes, shared rail resources, World collision, and a green audit"
	)


func _test_queued_module_enable_guard() -> void:
	var module := MODULE_SCENE.instantiate() as SalvageTerrace
	module.set_module_enabled(false)
	_check(
		not module.is_module_enabled(),
		"detached pre-tree module enable configuration remains supported"
	)
	module.set_module_enabled(true)
	_test_root.add_child(module)
	await process_frame
	var generated_root := module.get_node_or_null(^"GeneratedRoot") as Node3D
	module.set_module_enabled(false)
	_check(
		not module.is_module_enabled()
		and generated_root != null and not generated_root.visible
		and bool(module.get_lifecycle_contract().collision_matches_enabled),
		"live module enable control still hides presentation and clears collision"
	)
	module.set_module_enabled(true)
	var detached_snapshot := module.get_lifecycle_contract()
	var detached_visibility := generated_root.visible if generated_root != null else false
	_test_root.remove_child(module)
	module.set_module_enabled(false)
	_check(
		not module.is_inside_tree()
		and module.is_module_enabled()
		and module.get_lifecycle_contract() == detached_snapshot
		and generated_root != null and generated_root.visible == detached_visibility,
		"initialized detached module enable request is inert before visibility or collision mutation"
	)
	_test_root.add_child(module)
	await process_frame
	module.set_module_enabled(false)
	_check(
		not module.is_module_enabled()
		and generated_root != null and not generated_root.visible
		and bool(module.get_lifecycle_contract().collision_matches_enabled),
		"reentered module accepts a fresh live disable after detached rejection"
	)
	module.set_module_enabled(true)
	var live_snapshot := module.get_lifecycle_contract()
	var live_visibility := generated_root.visible if generated_root != null else false
	module.queue_free()
	module.set_module_enabled(false)
	_check(
		module.is_inside_tree()
		and module.is_queued_for_deletion()
		and module.is_module_enabled()
		and module.get_lifecycle_contract() == live_snapshot
		and generated_root != null and generated_root.visible == live_visibility,
		"queued module enable request is inert before visibility or collision mutation"
	)
	await process_frame
	_check(not is_instance_valid(module), "queued module-enable fixture releases cleanly")


func _test_real_player_ramp_traversal(module: SalvageTerrace) -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	_test_root.add_child(player)
	await process_frame
	player.set_camera_active(false)
	player.set_control_enabled(true)
	_release_actions()
	var connector := module.get_route_marker(&"connector")
	var ingress_basis := Basis.looking_at(module.global_basis * Vector3.BACK, Vector3.UP)
	player.teleport_to(Transform3D(ingress_basis, connector.global_position - module.global_basis.y * 0.07))
	for _settle in 8:
		await physics_frame
	var ingress_start := module.to_local(player.global_position)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint_boost")
	var apron_reached := await _wait_until(
		func() -> bool: return module.to_local(player.global_position).z >= 4.7,
		100
	)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint_boost")
	await physics_frame
	player.global_basis = Basis.looking_at(module.global_basis * Vector3.RIGHT, Vector3.UP)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint_boost")
	var main_reached := await _wait_until(
		func() -> bool:
			var local := module.to_local(player.global_position)
			return local.x >= 15.0 and local.y >= 3.45,
		150
	)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint_boost")
	await physics_frame
	var after_main := module.to_local(player.global_position)
	_check(
		ingress_start.x >= -0.2 and ingress_start.x <= 0.2
		and ingress_start.z >= -0.2 and ingress_start.z <= 0.2
		and apron_reached and main_reached
		and after_main.x >= 15.0 and after_main.y >= 3.45 and player.is_on_floor(),
		"real production player enters at the connector, crosses the apron, and climbs the 6 m-wide main ramp without jump input"
	)

	# Re-orient in place on the upper pad, then cross and climb the second ramp.
	# No position teleport occurs between ramps: the same body completes the route.
	player.global_basis = Basis.looking_at(module.global_basis * Vector3.RIGHT, Vector3.UP)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint_boost")
	var crossed_upper := await _wait_until(
		func() -> bool: return module.to_local(player.global_position).x >= 22.8,
		120
	)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint_boost")
	await physics_frame
	player.global_basis = Basis.looking_at(module.global_basis * Vector3.BACK, Vector3.UP)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint_boost")
	var inspection_reached := await _wait_until(
		func() -> bool:
			var local := module.to_local(player.global_position)
			return local.z >= 14.5 and local.y >= 5.2,
		140
	)
	_release_actions()
	await physics_frame
	var final_local := module.to_local(player.global_position)
	print("SALVAGE_TERRACE_PLAYER_TRAVERSAL: ", {
		"main_reached": main_reached,
		"crossed_upper": crossed_upper,
		"inspection_reached": inspection_reached,
		"final_local": final_local,
	})
	_check(
		crossed_upper and inspection_reached
		and final_local.z >= 14.5 and final_local.y >= 5.2 and player.is_on_floor(),
		"same player crosses the upper pad and climbs the second broad ramp without jumping"
	)
	player.queue_free()
	await process_frame
	await physics_frame


func _test_mutations_turn_audit_red(module: SalvageTerrace) -> void:
	var connector := module.get_route_marker(&"connector")
	var original_slot: Variant = connector.get_meta(StationModuleContract.CONNECTION_SLOT_META)
	connector.remove_meta(StationModuleContract.CONNECTION_SLOT_META)
	_check(_errors_include(module.get_validation_errors(), "connector slot"), "MUTATION: removing the origin slot turns the audit red")
	connector.set_meta(StationModuleContract.CONNECTION_SLOT_META, original_slot)
	_check(bool(module.get_audit_report().valid), "restoring the exact slot returns the audit to green")

	var surface_contract := module.get_standable_surface_contract()[0]
	var surface := module.get_node(surface_contract.body_path as NodePath) as StaticBody3D
	var surface_mesh := (surface.get_node(^"Mesh") as MeshInstance3D).mesh as BoxMesh
	var surface_shape := (surface.get_node(^"Collision") as CollisionShape3D).shape as BoxShape3D
	var original_size := surface_mesh.size
	var original_shape_size := surface_shape.size
	surface_mesh.size.x += 0.5
	surface_shape.size.x += 0.5
	var widened_area := module.get_walkable_area_contract()
	_check(
		not is_equal_approx(float(widened_area.projected_surface_sum_m2), 456.0)
		and _errors_include(module.get_validation_errors(), "live walkable-area union"),
		"MUTATION: widening the live collision shape changes derived area and turns the union audit red"
	)
	surface_mesh.size = original_size
	surface_shape.size = original_shape_size
	_check(bool(module.get_audit_report().valid), "restoring surface geometry returns the audit to green")

	var lower_surface := module.get_node(
		(module.get_standable_surface_contract()[1] as Dictionary).body_path as NodePath
	) as StaticBody3D
	var original_lower_transform := lower_surface.transform
	lower_surface.position.x += 4.0
	var overlapping_area := module.get_walkable_area_contract()
	_check(
		not bool(overlapping_area.non_overlapping)
		and float(overlapping_area.horizontal_walkable_area_m2) < 456.0
		and _errors_include(module.get_validation_errors(), "live walkable-area union"),
		"MUTATION: overlapping one live surface transform reduces the derived union and turns audit red"
	)
	lower_surface.transform = original_lower_transform
	_check(bool(module.get_audit_report().valid), "restoring the exact surface transform returns the live union to green")

	var collision := surface.get_node(^"Collision") as CollisionShape3D
	collision.disabled = true
	await physics_frame
	_check(_errors_include(module.get_validation_errors(), "static collision"), "MUTATION: disabling one walkable collider turns the audit red")
	collision.disabled = false
	await physics_frame
	_check(bool(module.get_audit_report().valid), "restoring walkable collision returns the audit to green")

	var rail: StaticBody3D = null
	for raw_body in module.find_children("*", "StaticBody3D", true, false):
		if bool(raw_body.get_meta("safety_rail", false)):
			rail = raw_body as StaticBody3D
			break
	if rail != null:
		rail.collision_layer = 0
		_check(_errors_include(module.get_validation_errors(), "safety rails"), "MUTATION: making one exposed edge rail nonphysical turns the audit red")
		rail.collision_layer = WORLD_LAYER
		_check(bool(module.get_audit_report().valid), "restoring rail collision returns the audit to green")

	var support_batch := module.get_node(^"GeneratedRoot/TerraceSupportBatch") as MultiMeshInstance3D
	var support_multimesh := support_batch.multimesh
	var support_buffer := support_multimesh.buffer.duplicate()
	var support_count := support_multimesh.instance_count
	support_multimesh.instance_count -= 1
	_check(
		_errors_include(module.get_validation_errors(), "exact renderer and physics performance census")
		and _errors_include(module.get_validation_errors(), "MultiMesh batch counts"),
		"MUTATION: dropping one drawn MultiMesh copy turns exact census and raw-buffer audits red"
	)
	support_multimesh.instance_count = support_count
	support_multimesh.buffer = support_buffer
	_check(bool(module.get_audit_report().valid), "restoring the exact MultiMesh count and transforms returns audit green")
	var shifted_support_buffer := support_buffer.duplicate()
	shifted_support_buffer[3] += 0.25
	support_multimesh.buffer = shifted_support_buffer
	_check(
		_errors_include(module.get_validation_errors(), "MultiMesh batch counts"),
		"MUTATION: changing one stored MultiMesh transform turns its raw-buffer audit red"
	)
	support_multimesh.buffer = support_buffer
	_check(bool(module.get_audit_report().valid), "restoring the exact MultiMesh buffer returns audit green")

	var intruder := Area3D.new()
	intruder.name = "InventedAuthority"
	module.get_node(^"GeneratedRoot").add_child(intruder)
	await process_frame
	_check(_errors_include(module.get_validation_errors(), "zero ship, berth, combat"), "MUTATION: adding interaction authority turns the audit red")
	intruder.queue_free()
	await process_frame
	_check(bool(module.get_audit_report().valid), "removing foreign authority returns the audit to green")

	var detached := module.get_audit_report()
	(detached.walkable_area as Dictionary).clear()
	_check(not module.get_walkable_area_contract().is_empty(), "public audit dictionaries are detached from live module state")


func _test_cleanup(module: SalvageTerrace) -> void:
	var module_ref: WeakRef = weakref(module)
	module.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	_check(module_ref.get_ref() == null, "standalone module releases without retained runtime state")
	_test_root.queue_free()
	await process_frame


func _capture_forward_plus() -> void:
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	stage.name = "SalvageTerraceForwardPlusCapture"
	root.add_child(stage)
	var module := MODULE_SCENE.instantiate() as SalvageTerrace
	stage.add_child(module)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111820")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6d8290")
	environment.ambient_light_energy = 0.48
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key_light.light_energy = 1.25
	key_light.shadow_enabled = true
	stage.add_child(key_light)
	var camera := Camera3D.new()
	camera.position = Vector3(45.0, 27.0, -30.0)
	camera.look_at_from_position(camera.position, Vector3(5.0, 2.0, 9.0), Vector3.UP)
	camera.fov = 56.0
	camera.current = true
	stage.add_child(camera)

	for _frame in 10:
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var renderer := RenderingServer.get_current_rendering_method()
	var image := root.get_texture().get_image()
	var save_error := image.save_png(CAPTURE_PATH) if image != null and not image.is_empty() else ERR_CANT_CREATE
	var valid := (
		renderer == &"forward_plus"
		and image != null
		and image.get_size() == Vector2i(1280, 720)
		and save_error == OK
	)
	print("SALVAGE_TERRACE_FORWARD_PLUS_CAPTURE: ", {
		"renderer": renderer,
		"size": image.get_size() if image != null else Vector2i.ZERO,
		"path": CAPTURE_PATH,
		"save_error": save_error,
	})
	stage.queue_free()
	await process_frame
	quit(0 if valid else 1)


func _ray(module: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_ray(query)


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame in maximum_frames:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _release_actions() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)


func _errors_include(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	_release_actions()
	if _failures.is_empty():
		print("SALVAGE_TERRACE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("SALVAGE_TERRACE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
