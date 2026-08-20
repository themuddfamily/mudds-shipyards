extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/jovian_freight_berth.tscn")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var module := MODULE_SCENE.instantiate() as JovianFreightBerth
	root.add_child(module)
	await process_frame
	await physics_frame
	var census := _census(module)
	print("JOVIAN_BATCH_CENSUS: ", census)
	var apron := module.get_node("LoadingApron")
	_check(
		census == JovianFreightBerth.DOCK_GUIDE_BATCH_CENSUS_AFTER,
		"standalone census freezes 920 -> 909 nodes and 439 -> 428 submissions with copies/triangles/collision exact"
	)
	var contract := module.get_dock_guide_batch_contract()
	_check(
		contract.census_before == JovianFreightBerth.DOCK_GUIDE_BATCH_CENSUS_BEFORE
		and contract.census_after == JovianFreightBerth.DOCK_GUIDE_BATCH_CENSUS_AFTER
		and bool(contract.visual_only)
		and not bool(contract.collision_backed)
		and not bool(contract.interaction_authority)
		and not bool(contract.gameplay_authority),
		"batch contract exposes the exact visual-only before/after boundary"
	)
	var batch := apron.get_node_or_null("DockGuideBatch") as MultiMeshInstance3D
	_check(
		batch != null
		and batch.multimesh != null
		and batch.multimesh.instance_count == JovianFreightBerth.DOCK_GUIDE_COPY_COUNT
		and batch.multimesh.mesh != null
		and batch.multimesh.mesh.get_aabb().size.is_equal_approx(JovianFreightBerth.DOCK_GUIDE_SIZE)
		and batch.material_override != null
		and batch.get_child_count() == 0
		and bool(batch.get_meta("visual_detail_only", false)),
		"one childless visual batch owns the exact twelve-copy mesh/material family"
	)
	if batch != null and batch.multimesh != null and batch.multimesh.mesh != null:
		_check(
			_mesh_triangles(batch.multimesh.mesh) == int(contract.triangles_per_copy)
			and _mesh_triangles(batch.multimesh.mesh) * batch.multimesh.instance_count
				== int(contract.drawn_triangles),
			"batch retains twelve copies of the exact 60-triangle chamfered guide"
		)
		_check(
			_exact_transforms(batch),
			"authored MultiMesh transforms preserve every former guide position and rotation"
		)
	_check(
		_retired_guide_meshes(apron).is_empty(),
		"no retired per-guide renderer nodes remain"
	)
	var collision := module.get_collision_contract()
	var authority := module.get_authority_contract()
	_check(
		int(collision.body_count) == 207
		and int(collision.shape_count) == 210
		and bool(collision.all_layers_match_lifecycle)
		and bool(collision.all_masks_zero)
		and bool(collision.all_shapes_present_and_enabled),
		"collision remains exactly 207 bodies/210 shapes with the lifecycle contract intact"
	)
	_check(
		(authority.authority_ids as PackedStringArray).is_empty()
		and int(authority.ship_berth_count) == 0
		and int(authority.landing_or_interaction_area_count) == 1
		and int(authority.audio_node_count) == 0
		and int(authority.activity_node_count) == 0
		and int(authority.lease_authority_count) == 0
		and int(authority.spawn_authority_count) == 0
		and authority.network_authority_role == &"none",
		"semantic authority is unchanged; only all_nodes_checked follows the eleven-node trim"
	)
	var lens_audit := module.get_guide_lens_visual_allocation_audit()
	_check(
		bool(lens_audit.valid)
			and int(lens_audit.node_count) == 18
			and int(lens_audit.structural_submission_count) == 18
			and int(lens_audit.mesh_resource_identity_count_before) == 18
			and int(lens_audit.mesh_resource_identity_count_after) == 1
			and int(lens_audit.mesh_resource_identity_delta) == -17
			and int(lens_audit.material_resource_identity_count_after) == 18
			and int(lens_audit.cyan_lens_count) == 12
			and int(lens_audit.amber_lens_count) == 6
			and int(lens_audit.housing_count) == 18
			and int(lens_audit.light_count) == 18
			and not bool(lens_audit.batched)
			and not bool(lens_audit.material_sharing)
			and not bool(lens_audit.collision_authority),
		"eighteen guide lenses share exactly one mesh while retaining their material, housing, light, and authority contract"
	)
	var lens := module.get_node_or_null(^"FreightPresentation/DockGuideLens18") as MeshInstance3D
	var shared_mesh := lens.mesh if lens != null else null
	if lens != null:
		lens.mesh = SphereMesh.new()
	var drifted_lens_audit := module.get_guide_lens_visual_allocation_audit()
	_check(
		lens != null
			and not bool(drifted_lens_audit.valid)
			and (drifted_lens_audit.errors as PackedStringArray).has("guide_lens_mesh_identity_count_drift"),
		"one guide lens escaping the shared mesh fails the allocation audit closed"
	)
	if lens != null:
		lens.mesh = shared_mesh
	_check(bool(module.get_guide_lens_visual_allocation_audit().valid), "restoring the shared mesh returns the guide-lens audit green")
	module.queue_free()
	await process_frame
	if _failures.is_empty():
		print("JOVIAN_FREIGHT_BERTH_BATCH_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("JOVIAN_FREIGHT_BERTH_BATCH_TEST_FAILED: ", _failures)
	quit(1)


func _census(module: Node) -> Dictionary:
	var meshes := module.find_children("*", "MeshInstance3D", true, false)
	var batches := module.find_children("*", "MultiMeshInstance3D", true, false)
	var triangles := 0
	var submissions := 0
	var visible_copies := meshes.size()
	for candidate in meshes:
		var mesh := (candidate as MeshInstance3D).mesh
		triangles += _mesh_triangles(mesh)
		submissions += mesh.get_surface_count() if mesh != null else 0
	for candidate in batches:
		var multi := (candidate as MultiMeshInstance3D).multimesh
		if multi == null or multi.mesh == null:
			continue
		var copies := multi.visible_instance_count
		if copies < 0:
			copies = multi.instance_count
		visible_copies += copies
		triangles += _mesh_triangles(multi.mesh) * copies
		submissions += multi.mesh.get_surface_count()
	return {
		"descendant_nodes": module.find_children("*", "", true, false).size(),
		"mesh_instance_nodes": meshes.size(),
		"multimesh_nodes": batches.size(),
		"geometry_submissions": submissions,
		"visible_geometry_copies": visible_copies,
		"drawn_triangles": triangles,
		"static_bodies": module.find_children("*", "StaticBody3D", true, false).size(),
		"collision_shapes": module.find_children("*", "CollisionShape3D", true, false).size(),
	}


func _mesh_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var count := 0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices != null and indices.size() > 0:
			count += indices.size() / 3
		else:
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			if vertices != null:
				count += vertices.size() / 3
	return count


func _exact_transforms(batch: MultiMeshInstance3D) -> bool:
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	if authored.size() != JovianFreightBerth.DOCK_GUIDE_COPY_COUNT:
		return false
	var expected: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for z_position in JovianFreightBerth.DOCK_GUIDE_Z_POSITIONS:
			expected.append(Transform3D(
				Basis.from_euler(Vector3(0.0, deg_to_rad(side * 18.0), 0.0)),
				Vector3(side * 8.7, 0.0525, float(z_position))
			))
	for index in expected.size():
		if not (authored[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return true


func _retired_guide_meshes(apron: Node) -> Array[Node]:
	var result: Array[Node] = []
	for node in apron.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("DockGuide"):
			result.append(node)
	return result


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
