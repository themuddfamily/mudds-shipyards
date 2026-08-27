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
	) as MeshInstance3D
	_check(rails != null and rails.mesh != null, "the platform exposes the gantry rail batch")
	if rails != null and rails.mesh != null:
		var transforms := rails.get_meta(&"authored_instance_transforms", []) as Array
		_check(
			transforms == EXPECTED_RAIL_TRANSFORMS
			and int(rails.get_meta(&"authored_visible_copy_count", -1)) == 4
			and rails.mesh.get_surface_count() == 1
			and rails.mesh.get_faces().size() / 3 == 432
			and not rails.mesh.resource_local_to_scene,
			"the combined rail mesh preserves the four authored tunnel transforms"
		)
		_check(
			rails.material_override != null
			and rails.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and rails.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"the combined mesh retains presentation material while owning no shadows or collision"
		)
	var census := _census(cluster)
	_check(
		int(census["mesh_nodes"]) == 192
		and int(census["batch_nodes"]) == 17
		and int(census["submissions"]) == 209
		and int(census["visible_copies"]) == 758
		and int(census["triangles"]) == 127002,
		"the combined rail trim keeps 209 submissions and 127002 triangles within 192 Mesh + 17 MultiMesh renderers"
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
		triangles += _triangle_count(mesh)
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
		"mesh_nodes": mesh_nodes.size(),
		"batch_nodes": batch_nodes.size(),
		"visible_copies": visible_copies,
		"submissions": submissions,
		"triangles": triangles,
	}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("FAIL: " + description)


func _triangle_count(mesh: Mesh) -> int:
	return mesh.get_faces().size() / 3
