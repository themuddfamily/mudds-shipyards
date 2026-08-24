extends SceneTree

const ACTIVITY_SCENE := preload(
	"res://scenes/world/components/station_operations_activity.tscn"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var first := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	var peer := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	root.add_child(first)
	root.add_child(peer)
	await process_frame

	var first_meshes := _visual_meshes_by_path(first)
	var peer_meshes := _visual_meshes_by_path(peer)
	var all_corresponding_resources_shared := first_meshes.size() == peer_meshes.size()
	var retained_resource_ids := {}
	for path: String in first_meshes:
		var first_mesh := first_meshes[path] as Mesh
		var peer_mesh := peer_meshes.get(path) as Mesh
		all_corresponding_resources_shared = (
			all_corresponding_resources_shared
			and first_mesh != null
			and peer_mesh != null
			and first_mesh == peer_mesh
			and first_mesh.get_aabb().is_equal_approx(peer_mesh.get_aabb())
		)
		if first_mesh != null:
			retained_resource_ids[first_mesh.get_instance_id()] = true
		if peer_mesh != null:
			retained_resource_ids[peer_mesh.get_instance_id()] = true

	var first_unique_ids := {}
	for mesh: Mesh in first_meshes.values():
		first_unique_ids[mesh.get_instance_id()] = true

	_check(
		first_meshes.size() == 65 and all_corresponding_resources_shared,
		"two FULL activities keep all 65 geometry submissions while corresponding immutable meshes share one allocation"
	)
	_check(
		retained_resource_ids.size() == first_unique_ids.size()
		and retained_resource_ids.size() == 35,
		"two FULL activities retain 35 meshes rather than 69: the second adds zero instead of 34 allocations"
	)
	var first_counts := first.get_performance_audit().counts as Dictionary
	var peer_counts := peer.get_performance_audit().counts as Dictionary
	_check(
		bool(first.get_audit_report().valid)
		and bool(peer.get_audit_report().valid)
		and first_counts == peer_counts
		and int(first_counts.geometry_submissions) == 65
		and int(first_counts.drawn_copies) == 79,
		"sharing preserves the complete activity contract and exact visible/submission budgets"
	)

	print(
		"METRIC: two FULL activities retain %d unique meshes for %d visual references (34 allocations removed)"
		% [retained_resource_ids.size(), first_meshes.size() + peer_meshes.size()]
	)
	if _failures.is_empty():
		print("STATION_OPERATIONS_ACTIVITY_MESH_SHARING_TEST_OK")
		quit(0)
	else:
		quit(1)


func _visual_meshes_by_path(activity: StationOperationsActivity) -> Dictionary:
	var result := {}
	for candidate in activity.get_node(^"PresentationRoot").find_children(
		"*", "", true, false
	):
		var mesh: Mesh = null
		if candidate is MeshInstance3D:
			mesh = (candidate as MeshInstance3D).mesh
		elif candidate is MultiMeshInstance3D:
			var batch := candidate as MultiMeshInstance3D
			if batch.multimesh != null:
				mesh = batch.multimesh.mesh
		if mesh != null:
			result[str(activity.get_path_to(candidate))] = mesh
	return result


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
