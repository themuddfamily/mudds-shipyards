extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/salvage_terrace.tscn")
const SLOPED_RAIL_NAMES := [
	&"MainRampForward", &"MainRampAft",
	&"InspectionRampPort", &"InspectionRampStarboard",
]

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var module := MODULE_SCENE.instantiate() as SalvageTerrace
	root.add_child(module)
	await process_frame

	var rails: Array[StaticBody3D] = []
	var visuals: Array[MeshInstance3D] = []
	var collision_shape_ids := {}
	for rail_name in SLOPED_RAIL_NAMES:
		var rail := module.get_node_or_null(
			NodePath("GeneratedRoot/%s" % rail_name)
		) as StaticBody3D
		if rail == null:
			continue
		rails.append(rail)
		var visual := rail.get_node_or_null(^"Mesh") as MeshInstance3D
		var collision := rail.get_node_or_null(^"Collision") as CollisionShape3D
		if visual != null:
			visuals.append(visual)
		if collision != null and collision.shape != null:
			collision_shape_ids[collision.shape.get_instance_id()] = true

	_check(
		rails.size() == 4 and visuals.size() == 4,
		"all four production sloped safety rails retain their stable bodies and visual paths"
	)
	if rails.size() != 4 or visuals.size() != 4:
		_finish(module)
		return

	var main_mesh := visuals[0].mesh as BoxMesh
	var inspection_mesh := visuals[2].mesh as BoxMesh
	_check(
		main_mesh != null
			and inspection_mesh != null
			and visuals[1].mesh == main_mesh
			and visuals[3].mesh == inspection_mesh
			and main_mesh != inspection_mesh,
		"each port/starboard ramp pair shares one exact immutable visual mesh"
	)
	_check(
		main_mesh.size.is_equal_approx(Vector3(0.16, 1.3, Vector3(8.0, 3.6, 0.0).length()))
			and inspection_mesh.size.is_equal_approx(Vector3(0.16, 1.3, Vector3(0.0, 1.8, 4.0).length()))
			and not main_mesh.resource_local_to_scene
			and not inspection_mesh.resource_local_to_scene,
		"the two shared resources preserve the authored ramp-length envelopes"
	)
	var rail_material := visuals[0].material_override
	var visual_recipe_exact := true
	for visual in visuals:
		visual_recipe_exact = (
			visual_recipe_exact
			and visual.material_override == rail_material
			and not visual.visible
			and visual.transform.is_equal_approx(Transform3D.IDENTITY)
			and visual.get_child_count() == 0
			and visual.get_script() == null
		)
	_check(
		visual_recipe_exact,
		"sharing retains the hidden conservative renderer state, rail material and local transforms"
	)
	_check(
		rails[0].basis.is_equal_approx(rails[1].basis)
			and rails[0].position.is_equal_approx(Vector3(10.0, 2.45, 2.0))
			and rails[1].position.is_equal_approx(Vector3(10.0, 2.45, 8.0))
			and rails[2].basis.is_equal_approx(rails[3].basis)
			and rails[2].position.is_equal_approx(Vector3(20.0, 5.15, 12.0))
			and rails[3].position.is_equal_approx(Vector3(26.0, 5.15, 12.0)),
		"all four physical rail transforms preserve the authored ramp-side placement"
	)
	_check(
		collision_shape_ids.size() == 4
			and module.find_children("*", "CollisionShape3D", true, false).size() == 26
			and module.get_component_roster().safety_rail_count == 20,
		"four independent collision resources and every physical safety rail remain intact"
	)

	var audit := module.get_sloped_rail_visual_allocation_audit()
	_check(
		bool(audit.valid)
			and int(audit.visual_copies) == 4
			and int(audit.mesh_resource_allocations) == 2
			and int(audit.legacy_mesh_resource_allocations) == 4
			and int(audit.mesh_resource_allocation_delta) == -2
			and int(audit.renderer_nodes) == 4
			and int(audit.geometry_submissions) == 4
			and bool(audit.visual_aabbs_match_collision)
			and not bool(audit.batched),
		"the family audit proves mesh allocations 4 -> 2 without changing nodes or submissions"
	)
	var performance := module.get_performance_contract()
	var unit_box_batches := module.get_unit_box_batch_mesh_allocation_audit()
	_check(
		bool(performance.within_budget)
			and bool(performance.resource_sharing_matches_authored)
			and int(performance.mesh_instances) == 36
			and int(performance.multimesh_batches) == 6
			and int(performance.geometry_submissions) == 42
			and int(performance.visible_geometry_copies) == 200,
		"the exact production census and all six established structural batches remain unchanged"
	)
	_check(
		bool(unit_box_batches.valid)
			and int(unit_box_batches.batch_count) == 3
			and int(unit_box_batches.geometry_submissions) == 3
			and int(unit_box_batches.visible_geometry_copies) == 144
			and int(unit_box_batches.mesh_resource_allocations) == 1
			and int(unit_box_batches.legacy_mesh_resource_allocations) == 3
			and int(unit_box_batches.mesh_resource_allocation_delta) == -2
			and int(unit_box_batches.multimesh_resource_allocations) == 3
			and bool(unit_box_batches.batched),
		"three transform-scaled structural batches share one immutable unit-box mesh without merging submissions or copies"
	)
	var authority := module.get_authority_contract()
	var roster := module.get_component_roster()
	_check(
		int(authority.interaction_authority_count) == 0
			and int(authority.station_activity_authority_count) == 0
			and int(roster.work_light_count) == 3
			and bool(roster.salvage_work_bay_present),
		"visual resource reuse leaves interactions, authority, lights and work-bay machinery unchanged"
	)

	var original_mesh := visuals[1].mesh
	visuals[1].mesh = BoxMesh.new()
	_check(
		not bool(module.get_sloped_rail_visual_allocation_audit().valid)
			and not bool(module.get_performance_contract().within_budget),
		"breaking one pair's shared identity turns both focused and production audits red"
	)
	visuals[1].mesh = original_mesh
	_check(
		bool(module.get_sloped_rail_visual_allocation_audit().valid),
		"restoring the shared resource restores the live component contract"
	)

	var frame_batch := module.get_node(^"GeneratedRoot/SalvageFrameBatch") as MultiMeshInstance3D
	var original_batch_mesh := frame_batch.multimesh.mesh
	frame_batch.multimesh.mesh = BoxMesh.new()
	_check(
		not bool(module.get_unit_box_batch_mesh_allocation_audit().valid)
			and not bool(module.get_performance_contract().within_budget),
		"breaking the unit-box mesh identity turns both focused and production audits red"
	)
	frame_batch.multimesh.mesh = original_batch_mesh
	_check(
		bool(module.get_unit_box_batch_mesh_allocation_audit().valid),
		"restoring the shared unit-box mesh restores the live component contract"
	)

	_finish(module)


func _finish(module: SalvageTerrace) -> void:
	module.queue_free()
	await process_frame
	_check(not is_instance_valid(module), "the optimized terrace still exits the lifecycle cleanly")
	if _failures.is_empty():
		print("SALVAGE_TERRACE_SLOPED_RAIL_SHARING: mesh_resources 4->2 renderer_nodes 4->4 geometry_submissions 4->4")
		print("SALVAGE_TERRACE_UNIT_BOX_BATCH_SHARING: mesh_resources 3->1 batches 3->3 visible_copies 144->144")
		print("PASS salvage_terrace_sloped_rail_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
