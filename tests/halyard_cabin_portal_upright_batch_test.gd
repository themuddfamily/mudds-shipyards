extends SceneTree

## Focused renderer regression for the four childless Halyard cabin pressure-
## frame uprights. Traversal and occupancy authority remain separate production
## nodes; this verifies only exact visual copies and allocation reduction.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame

	var cabin := craft.get_node_or_null(^"WalkableInterior/CrewCabin") as Node3D
	var batch := cabin.get_node_or_null(^"CabinPortalUprightBatch") as MultiMeshInstance3D \
		if cabin != null else null
	_check(batch != null and batch.multimesh != null, "one renderer owns all four cabin portal uprights")
	if batch != null and batch.multimesh != null:
		var expected_transforms: Array[Transform3D] = []
		var expected_names := PackedStringArray()
		for portal_z in [-9.70, 2.50]:
			for side in [-1.0, 1.0]:
				expected_transforms.append(Transform3D(
					Basis.IDENTITY,
					Vector3(side * 1.28, 1.90, portal_z)
				))
				expected_names.append(
					("Forward" if portal_z < 0.0 else "Aft")
						+ ("Port" if side < 0.0 else "Starboard")
						+ "CabinPortalUpright"
				)
		var authored := batch.get_meta("authored_instance_transforms", []) as Array
		var transforms_match := authored.size() == expected_transforms.size()
		for index in mini(authored.size(), expected_transforms.size()):
			transforms_match = transforms_match \
				and (authored[index] as Transform3D).is_equal_approx(expected_transforms[index])
		_check(
			batch.multimesh.instance_count == HalyardCrewTransport.CABIN_PORTAL_UPRIGHT_COPY_COUNT
				and batch.multimesh.visible_instance_count == -1
				and batch.multimesh.mesh.get_aabb().size.is_equal_approx(
					HalyardCrewTransport.CABIN_PORTAL_UPRIGHT_SIZE
				)
				and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_names
				and transforms_match,
			"the batch preserves all four named pressure-frame silhouettes at exact transforms"
		)
		_check(
			batch.material_override == craft.get_variant_materials().get("accent")
				and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				and batch.layers == 1
				and batch.visibility_range_begin == 0.0
				and batch.visibility_range_end == 0.0
				and batch.multimesh.custom_aabb.is_equal_approx(
					_transformed_bounds(batch.multimesh.mesh.get_aabb(), expected_transforms)
				),
			"material, shadows, layers and union culling bounds remain unchanged"
		)
		_check(
			cabin.find_children("*CabinPortalUpright", "MeshInstance3D", true, false).is_empty()
				and batch.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"the four replaced leaves were cosmetic and the batch remains collision-free"
		)

	_check(
		craft.get_node_or_null(^"WalkableInterior/InteriorAccessMarker") is Marker3D
			and craft.get_node_or_null(^"WalkableInterior/InteriorDeckMarker") is Marker3D
			and craft.get_node_or_null(^"WalkableInterior/CrewCabin/AirstairInnerLanding") is MeshInstance3D
			and craft.get_node_or_null(^"WalkableInterior/CrewCabin/AirstairRouteBranch") is MeshInstance3D,
		"boarding and route anchors remain separate production nodes"
	)

	var report := craft.get_halyard_render_allocation_report()
	_check(
		int(report.get("descendant_nodes", -1)) == 115
			and int(report.get("mesh_instances", -1)) == 102
			and int(report.get("multimesh_batches", -1)) == 8
			and int(report.get("drawn_copies", -1)) == 168
			and int(report.get("geometry_submissions", -1)) == 110
			and int(report.get("unique_mesh_resources", -1)) == 67
			and bool(report.get("exact_counts", false)),
		"the separate exterior allocation freeze remains exact"
	)
	var full_counts := _full_render_counts(craft)
	_check(
		int(full_counts.mesh_instances) == 246
			and int(full_counts.multimesh_batches) == 13
			and int(full_counts.drawn_copies) == 348
			and int(full_counts.geometry_submissions) == 259,
		"all 348 craft copies remain while full-craft nodes and submissions fall by three"
	)

	craft.queue_free()
	await process_frame
	_finish()


func _transformed_bounds(mesh_bounds: AABB, transforms: Array[Transform3D]) -> AABB:
	var bounds := transforms[0] * mesh_bounds
	for index in range(1, transforms.size()):
		bounds = bounds.merge(transforms[index] * mesh_bounds)
	return bounds


func _full_render_counts(craft: Node) -> Dictionary:
	var meshes := craft.find_children("*", "MeshInstance3D", true, false)
	var batches := craft.find_children("*", "MultiMeshInstance3D", true, false)
	var submissions := 0
	var drawn_copies := 0
	for raw_mesh in meshes:
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh != null:
			submissions += mesh_instance.mesh.get_surface_count()
			drawn_copies += 1
	for raw_batch in batches:
		var batch_instance := raw_batch as MultiMeshInstance3D
		if batch_instance.multimesh != null and batch_instance.multimesh.mesh != null:
			submissions += batch_instance.multimesh.mesh.get_surface_count()
			var visible := batch_instance.multimesh.visible_instance_count
			drawn_copies += batch_instance.multimesh.instance_count if visible < 0 else visible
	return {
		"mesh_instances": meshes.size(),
		"multimesh_batches": batches.size(),
		"drawn_copies": drawn_copies,
		"geometry_submissions": submissions,
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HALYARD_CABIN_PORTAL_UPRIGHT_BATCH_TEST_PASSED: %d assertions" % _assertions)
		quit(0)
		return
	push_error("HALYARD_CABIN_PORTAL_UPRIGHT_BATCH_TEST_FAILED: %d/%d assertions failed: %s" % [
		_failures.size(), _assertions, "; ".join(_failures)
	])
	quit(1)
