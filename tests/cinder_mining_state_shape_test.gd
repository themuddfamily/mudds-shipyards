extends SceneTree

## Focused production proof for the Cinder headframe's non-colour state read.
## Classification is derived from the retained meshes' live transforms: labels
## alone cannot claim that an intersecting X has become a closed horizontal bar.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var presentation := cluster.get_node(
		^"ExtractionPlatform/CinderReachPlatform/MiningActivityPresentation"
	) as Node3D
	var legs := presentation.get_node(^"MiningHeadframeLegs") as MultiMeshInstance3D
	var leg_id := legs.get_instance_id()
	var counts := _counts(presentation)

	var available_geometry := _classify_legs(legs)
	print("CINDER_MINING_AVAILABLE_GEOMETRY: ", available_geometry)
	_check(
		available_geometry.orientation == &"vertical"
			and not bool(available_geometry.intersects)
			and float(available_geometry.surface_gap) > 20.0,
		"available holds two full-height open-gate uprights"
	)

	var started := binding.start_mining_activity(CinderMiningPlatformActivity.APPROACH_ANCHOR)
	var extracting_geometry := _classify_legs(legs)
	print("CINDER_MINING_ACTIVE_GEOMETRY: ", extracting_geometry)
	_check(
		bool(started.get("accepted", false))
			and extracting_geometry.orientation == &"opposed_diagonal"
			and bool(extracting_geometry.intersects),
		"active extraction crosses the same full-height legs into an X"
	)

	var completed := binding.advance_mining_activity(CinderMiningPlatformActivity.EXTRACTION_SECONDS)
	var secured := cluster.get_mining_activity_presentation_state()
	var secured_geometry := _classify_legs(legs)
	print("CINDER_MINING_CAPACITY_FULL_GEOMETRY: ", secured_geometry)
	_check(
		bool(completed.get("accepted", false))
			and secured_geometry.orientation == &"horizontal"
			and not bool(secured_geometry.intersects)
			and float(secured_geometry.surface_gap) >= 0.9
			and bool(secured.get("capacity_ready_geometry", false)),
		"capacity-full completion closes into two separated horizontal roof bars"
	)
	_check(
		legs.get_instance_id() == leg_id
			and _counts(presentation) == counts
			and bool(secured_geometry.within_landmark_bounds)
			and legs.find_children("*", "CollisionObject3D", true, false).is_empty()
			and bool(cluster.get_mining_platform_presentation_audit().get("valid", false)),
		"all state silhouettes reuse the retained batch with no authority or budget growth"
	)

	cluster.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_MINING_STATE_SHAPE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		quit(1)


func _counts(presentation: Node3D) -> Dictionary:
	return {
		"descendants": presentation.find_children("*", "", true, false).size(),
		"meshes": presentation.find_children("*", "MeshInstance3D", true, false).size(),
		"batches": presentation.find_children("*", "MultiMeshInstance3D", true, false).size(),
		"lights": presentation.find_children("*", "Light3D", true, false).size(),
	}


func _classify_legs(legs: MultiMeshInstance3D) -> Dictionary:
	var mesh_bounds := legs.multimesh.mesh.get_aabb()
	var half_length := mesh_bounds.size.y * 0.5
	var half_width := mesh_bounds.size.x * 0.5
	var transforms: Array[Transform3D] = []
	var centres: Array[Vector2] = []
	var directions: Array[Vector2] = []
	var within_bounds := true
	for index in legs.multimesh.instance_count:
		var transform_value := _transform_from_buffer(legs.multimesh.buffer, index)
		transforms.append(transform_value)
		centres.append(Vector2(transform_value.origin.x, transform_value.origin.y))
		directions.append(Vector2(
			transform_value.basis.y.x, transform_value.basis.y.y
		).normalized())
		within_bounds = within_bounds and NearbySectorCluster.MINING_PRESENTATION_LOCAL_BOUNDS.encloses(
			(transform_value * mesh_bounds).abs()
		)
	var first_start := centres[0] - directions[0] * half_length
	var first_end := centres[0] + directions[0] * half_length
	var second_start := centres[1] - directions[1] * half_length
	var second_end := centres[1] + directions[1] * half_length
	var intersects := _segments_intersect(first_start, first_end, second_start, second_end)
	var cross := directions[0].cross(directions[1])
	var orientation: StringName = &"mixed"
	if absf(directions[0].y) > 0.98 and absf(directions[1].y) > 0.98:
		orientation = &"vertical"
	elif absf(directions[0].x) > 0.98 and absf(directions[1].x) > 0.98:
		orientation = &"horizontal"
	elif absf(cross) > 0.5 and absf(directions[0].x) > 0.5 \
			and absf(directions[1].x) > 0.5:
		orientation = &"opposed_diagonal"
	var surface_gap := -1.0
	if absf(cross) < 0.001:
		var normal := Vector2(-directions[0].y, directions[0].x)
		surface_gap = absf((centres[1] - centres[0]).dot(normal)) - half_width * 2.0
	return {
		"orientation": orientation,
		"intersects": intersects,
		"surface_gap": surface_gap,
		"within_landmark_bounds": within_bounds,
		"centres": centres,
		"directions": directions,
	}


func _transform_from_buffer(buffer: PackedFloat32Array, instance_index: int) -> Transform3D:
	var offset := instance_index * 12
	return Transform3D(
		Basis(
			Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]),
			Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]),
			Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])
		),
		Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11])
	)


func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var denominator := ab.cross(cd)
	if absf(denominator) < 0.0001:
		return false
	var offset := c - a
	var first_fraction := offset.cross(cd) / denominator
	var second_fraction := offset.cross(ab) / denominator
	return first_fraction >= 0.0 and first_fraction <= 1.0 \
		and second_fraction >= 0.0 and second_fraction <= 1.0


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)
