extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const EXPECTED_RAIL_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(-15.5, -9.0, 86.0)),
	Transform3D(Basis.IDENTITY, Vector3(-15.5, 17.0, 86.0)),
	Transform3D(Basis.IDENTITY, Vector3(15.5, -9.0, 86.0)),
	Transform3D(Basis.IDENTITY, Vector3(15.5, 17.0, 86.0)),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var rails := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/GantryRails"
	) as MultiMeshInstance3D
	_check(rails != null and rails.multimesh != null, "the platform exposes the gantry rail batch")
	if rails != null and rails.multimesh != null:
		var multimesh := rails.multimesh
		_check(
			multimesh.instance_count == 4
			and multimesh.visible_instance_count == -1
			and multimesh.buffer == _encode_transforms(EXPECTED_RAIL_TRANSFORMS),
			"the rail batch preserves the four authored tunnel transforms"
		)
		_check(
			rails.material_override != null
			and rails.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and rails.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"the batch retains presentation material while owning no shadows or collision"
		)
	var census := _census(cluster)
	_check(
		int(census["mesh_nodes"]) == 160
		and int(census["batch_nodes"]) == 3
		and int(census["submissions"]) == 163
		and int(census["visible_copies"]) == 688
		and int(census["triangles"]) == 117457,
		"the trim freezes 163 submissions while preserving all copies and triangles"
	)
	cluster.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NEARBY_SECTOR_CLUSTER_BATCH_TEST_OK")
		quit(0)
	else:
		print("NEARBY_SECTOR_CLUSTER_BATCH_TEST_FAILED: ", ", ".join(_failures))
		quit(1)


func _census(cluster: NearbySectorCluster) -> Dictionary:
	var mesh_nodes := cluster.find_children("*", "MeshInstance3D", true, false)
	var batch_nodes := cluster.find_children("*", "MultiMeshInstance3D", true, false)
	var triangles := 0
	var submissions := 0
	var visible_copies := 0
	for candidate in mesh_nodes:
		var instance := candidate as MeshInstance3D
		var mesh := instance.mesh
		if mesh == null:
			continue
		var mesh_triangles := _triangle_count(mesh)
		triangles += mesh_triangles
		submissions += mesh.get_surface_count()
		visible_copies += 1
	for candidate in batch_nodes:
		var instance := candidate as MultiMeshInstance3D
		var multimesh := instance.multimesh
		if multimesh == null or multimesh.mesh == null:
			continue
		var copy_count := multimesh.instance_count
		triangles += _triangle_count(multimesh.mesh) * copy_count
		submissions += multimesh.mesh.get_surface_count()
		visible_copies += copy_count
	return {
		"descendants": cluster.find_children("*", "", true, false).size(),
		"mesh_nodes": mesh_nodes.size(),
		"batch_nodes": batch_nodes.size(),
		"visible_copies": visible_copies,
		"submissions": submissions,
		"triangles": triangles,
		"static_bodies": cluster.find_children("*", "StaticBody3D", true, false).size(),
		"collision_shapes": cluster.find_children("*", "CollisionShape3D", true, false).size(),
		"lights": cluster.find_children("*", "Light3D", true, false).size(),
	}


func _encode_transforms(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var transform_value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = transform_value.basis.x.x
		buffer[offset + 1] = transform_value.basis.y.x
		buffer[offset + 2] = transform_value.basis.z.x
		buffer[offset + 3] = transform_value.origin.x
		buffer[offset + 4] = transform_value.basis.x.y
		buffer[offset + 5] = transform_value.basis.y.y
		buffer[offset + 6] = transform_value.basis.z.y
		buffer[offset + 7] = transform_value.origin.y
		buffer[offset + 8] = transform_value.basis.x.z
		buffer[offset + 9] = transform_value.basis.y.z
		buffer[offset + 10] = transform_value.basis.z.z
		buffer[offset + 11] = transform_value.origin.z
	return buffer


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("FAIL: " + description)


func _triangle_count(mesh: Mesh) -> int:
	return mesh.get_faces().size() / 3
