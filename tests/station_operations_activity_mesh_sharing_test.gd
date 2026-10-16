extends SceneTree

const ACTIVITY_SCENE := preload(
	"res://scenes/world/components/station_operations_activity.tscn"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--benchmark" in OS.get_cmdline_user_args():
		_benchmark_production_roster()
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
		first_meshes.size() == 66 and all_corresponding_resources_shared,
		"two FULL activities keep all 66 geometry submissions while corresponding immutable meshes share one allocation"
	)
	_check(
		retained_resource_ids.size() == first_unique_ids.size()
		and retained_resource_ids.size() == 36,
		"two FULL activities retain 36 meshes including the shared shadow batch: the second adds zero allocations"
	)
	var first_counts := first.get_performance_audit().counts as Dictionary
	var peer_counts := peer.get_performance_audit().counts as Dictionary
	_check(
		bool(first.get_audit_report().valid)
		and bool(peer.get_audit_report().valid)
		and first_counts == peer_counts
		and int(first_counts.geometry_submissions) == 66
		and int(first_counts.drawn_copies) == 79,
		"sharing preserves the complete activity contract and exact visible/submission budgets"
	)

	print(
		"METRIC: two FULL activities retain %d unique meshes for %d visual references (corresponding resources shared)"
		% [retained_resource_ids.size(), first_meshes.size() + peer_meshes.size()]
	)
	_test_exact_recipe_identity(first)
	_test_recipe_reuse_and_drift(first)
	if _failures.is_empty():
		print("STATION_OPERATIONS_ACTIVITY_MESH_SHARING_TEST_OK")
		quit(0)
	else:
		quit(1)


func _test_exact_recipe_identity(owner: StationOperationsActivity) -> void:
	var first := owner.PresentationBuilder.new()
	var peer := owner.PresentationBuilder.new()
	first._resolve_visual_mesh_recipe = owner._resolve_visual_mesh_recipe
	peer._resolve_visual_mesh_recipe = owner._resolve_visual_mesh_recipe
	# Each pair collides under the old per-builder rounded key. Those local
	# semantics must never become an alias between distinct builds.
	var pairs := [
		[first._rounded_box_mesh(Vector3(0.844441, 0.7, 0.6)),
			peer._rounded_box_mesh(Vector3(0.844442, 0.7, 0.6))],
		[first._chamfered_cylinder_mesh(0.344441, 0.7),
			peer._chamfered_cylinder_mesh(0.344442, 0.7)],
		[first._crate_mesh(Vector3(0.944441, 0.7, 0.6), false),
			peer._crate_mesh(Vector3(0.944442, 0.7, 0.6), false)],
	]
	var exact_recipes_remain_distinct := true
	for pair: Array in pairs:
		var left := pair[0] as ArrayMesh
		var right := pair[1] as ArrayMesh
		exact_recipes_remain_distinct = exact_recipes_remain_distinct and (
			left != right
			and var_to_bytes(left.surface_get_arrays(0)) != var_to_bytes(right.surface_get_arrays(0))
		)
	_check(exact_recipes_remain_distinct,
		"cross-build box, cylinder and crate recipe keys retain exact parameters despite local rounded-key collisions")


func _test_recipe_reuse_and_drift(owner: StationOperationsActivity) -> void:
	var cargo := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	cargo.activity_profile = StationOperationsActivity.ActivityProfile.CARGO_LINE
	root.add_child(cargo)
	var emissions := {"count": 0}
	for profile: StringName in [&"full", &"cargo_line"]:
		var presentation := Node3D.new()
		var builder := owner.PresentationBuilder.new()
		builder.build(presentation, profile, owner.DRONE_COUNT, owner.BEACON_SEAT_HEIGHT,
			owner._materials, func(recipe: String, factory: Callable) -> ArrayMesh:
				return owner._resolve_visual_mesh_recipe(recipe, func() -> ArrayMesh:
					emissions.count += 1
					return factory.call() as ArrayMesh
				)
		)
		presentation.free()
	_check(emissions.count == 0,
		"warm FULL and CARGO_LINE builders reuse canonical recipes before any box, cylinder or crate geometry emission")

	var dirty_meshes: Array[ArrayMesh] = [
		owner._presentation_builder._rounded_box_cache.values()[0],
		owner._presentation_builder._chamfered_cylinder_cache.values()[0],
		cargo._presentation_builder._crate_mesh_cache.values()[0],
		owner._presentation_builder._safety_beacon_base_mesh(),
	]
	for mesh_index in dirty_meshes.size():
		var dirty := dirty_meshes[mesh_index]
		var expected_arrays: Array = []
		for surface in dirty.get_surface_count():
			expected_arrays.append(dirty.surface_get_arrays(surface))
		var original_key := owner._visual_mesh_cache_key(dirty)
		# Modify the same live resource already retained by earlier activities.
		dirty.clear_surfaces()
		var rebuilt := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
		rebuilt.activity_profile = (StationOperationsActivity.ActivityProfile.CARGO_LINE
			if mesh_index == 2 else StationOperationsActivity.ActivityProfile.FULL)
		root.add_child(rebuilt)
		var restored := false
		for fresh: Mesh in _visual_meshes_by_path(rebuilt).values():
			if owner._visual_mesh_cache_key(fresh) == original_key:
				var actual_arrays: Array = []
				for surface in fresh.get_surface_count():
					actual_arrays.append(fresh.surface_get_arrays(surface))
				restored = fresh != dirty and var_to_bytes(actual_arrays) == var_to_bytes(expected_arrays)
				break
		_check(restored and bool(rebuilt.get_audit_report().valid),
			"recipe family %d quarantines external geometry drift and rebuilds exact original arrays" % mesh_index)
		rebuilt.free()
	_check(not bool(owner.get_audit_report().valid) and not bool(cargo.get_audit_report().valid),
		"existing users still report their externally mutated shared resources")
	cargo.free()


func _benchmark_production_roster() -> void:
	# Same ten profiles and order as ShipyardWorld's production placements.
	var profiles := [0, 2, 3, 1, 4, 8, 8, 7, 6, 5]
	var elapsed: Array[int] = []
	var all_profiles_valid := true
	for iteration in 8:
		var activities: Array[StationOperationsActivity] = []
		var started := Time.get_ticks_usec()
		for profile: int in profiles:
			var activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
			activity.activity_profile = profile
			root.add_child(activity)
			activities.append(activity)
		elapsed.append(Time.get_ticks_usec() - started)
		for activity in activities:
			all_profiles_valid = all_profiles_valid and bool(activity.get_audit_report().valid)
			activity.free()
	_check(all_profiles_valid, "all benchmarked activities preserve their exact profile contracts")
	print("WHOLE_ACTIVITY_ROSTER_USEC ", elapsed)


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
