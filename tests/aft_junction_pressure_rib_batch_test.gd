extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/aft_junction_stack.tscn")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var module := MODULE_SCENE.instantiate() as AftJunctionStack
	root.add_child(module)
	await process_frame

	var envelope := module.get_node_or_null(
		^"Structure/OperationsRoom/VisualPressureEnvelope"
	) as Node3D
	_check(envelope != null, "the production pressure envelope exists")
	if envelope == null:
		quit(1)
		return

	for rib_index in AftJunctionStack.PRESSURE_RIB_COPY_COUNT:
		var anchor := envelope.get_node_or_null(
			NodePath("PressureRib%02d" % rib_index)
		) as Node3D
		_check(
			anchor != null
			and anchor.get_child_count() == 0
			and bool(anchor.get_meta("visual_detail_only", false))
			and bool(anchor.get_meta("presentation_only", false)),
			"pressure rib %02d retains one inert named envelope anchor" % rib_index
		)

	var batch := envelope.get_node_or_null(^"PressureRibArcBatch") as MultiMeshInstance3D
	var multimesh := batch.multimesh if batch != null else null
	var mesh := multimesh.mesh if multimesh != null else null
	var expected: Array[Transform3D] = []
	for rib_index in AftJunctionStack.PRESSURE_RIB_COPY_COUNT:
		expected.append(Transform3D(Basis.IDENTITY, Vector3(
			0.0, 0.0, AftJunctionStack.PRESSURE_RIB_Z_START
				+ float(rib_index) * AftJunctionStack.PRESSURE_RIB_Z_STEP
		)))
	_check(
		batch != null and multimesh != null and mesh != null
		and multimesh.instance_count == AftJunctionStack.PRESSURE_RIB_COPY_COUNT
		and multimesh.visible_instance_count == AftJunctionStack.PRESSURE_RIB_COPY_COUNT
		and multimesh.buffer == _encode_transforms(expected)
		and multimesh.custom_aabb.is_equal_approx(_transformed_bounds(mesh.get_aabb(), expected))
		and mesh.get_surface_count() == 1
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1 and batch.material_override != null
		and batch.material_override.albedo_color.is_equal_approx(Color("cbd0ce"))
		and batch.visibility_range_begin == 0.0 and batch.visibility_range_end == 0.0
		and batch.get_child_count() == 0 and batch.get_script() == null
		and bool(batch.get_meta("visual_detail_only", false)),
		"five exact arc copies share one inert envelope-owned renderer and submission"
	)
	if mesh != null:
		_test_exact_arc_geometry(mesh)
	_check(
		envelope.find_children("PressureRibSegmentBatch*", "MultiMeshInstance3D", true, false).is_empty()
		and envelope.find_children("TubeSegment*", "MeshInstance3D", true, false).is_empty(),
		"the fourteen segment renderers and seventy legacy child renderers are absent"
	)

	var census := module.get_pod_corner_collar_visual_allocation_audit()
	_check(
		bool(census.valid)
		and int(census.current.descendant_nodes) == AftJunctionStack.RENDER_DESCENDANT_NODE_COUNT
		and int(census.current.renderer_nodes) == AftJunctionStack.RENDERER_NODE_COUNT
		and int(census.current.drawn_copies) == AftJunctionStack.DRAWN_COPY_COUNT
		and int(census.current.surface_submissions) == AftJunctionStack.SURFACE_SUBMISSION_COUNT,
		"the production Aft census records thirteen fewer nodes and submissions"
	)

	if multimesh != null:
		multimesh.visible_instance_count = 4
		_check(not bool(module.get_pod_corner_collar_visual_allocation_audit().valid),
			"the production allocation contract rejects one missing rib plane")
		multimesh.visible_instance_count = 5
		var identity := batch.get_instance_id()
		module.set_module_enabled(false)
		_check(not batch.is_visible_in_tree(), "the owner disables the complete arc batch")
		module.set_module_enabled(true)
		root.remove_child(module)
		root.add_child(module)
		await process_frame
		_check(batch.is_visible_in_tree() and batch.get_instance_id() == identity
			and bool(module.get_pod_corner_collar_visual_allocation_audit().valid),
			"owner reentry restores the same exact renderer without rebuilding")

	module.queue_free()
	await process_frame
	if not _failed:
		print("AFT_JUNCTION_PRESSURE_RIB_BATCH_TEST_OK")
	quit(1 if _failed else 0)


func _expected_transforms_by_segment() -> Array[Array]:
	var result: Array[Array] = []
	var half_width := (
		AftJunctionStack.PRESSURE_RIB_X_MAX - AftJunctionStack.PRESSURE_RIB_X_MIN
	) * 0.5
	var center_x := (
		AftJunctionStack.PRESSURE_RIB_X_MAX + AftJunctionStack.PRESSURE_RIB_X_MIN
	) * 0.5
	var previous_points: Array[Vector3] = []
	for rib_index in AftJunctionStack.PRESSURE_RIB_COPY_COUNT:
		previous_points.append(Vector3(
			AftJunctionStack.PRESSURE_RIB_X_MIN,
			AftJunctionStack.PRESSURE_RIB_SPRING_HEIGHT,
			AftJunctionStack.PRESSURE_RIB_Z_START
				+ float(rib_index) * AftJunctionStack.PRESSURE_RIB_Z_STEP
		))
	for segment_index in AftJunctionStack.PRESSURE_RIB_SEGMENT_COUNT:
		var progress := float(segment_index + 1) / float(AftJunctionStack.PRESSURE_RIB_SEGMENT_COUNT)
		var x_position := lerpf(
			AftJunctionStack.PRESSURE_RIB_X_MIN,
			AftJunctionStack.PRESSURE_RIB_X_MAX,
			progress
		)
		var normalized_x := (x_position - center_x) / half_width
		var curve_height := AftJunctionStack.PRESSURE_RIB_SPRING_HEIGHT + (
			AftJunctionStack.PRESSURE_RIB_CROWN_HEIGHT
			- AftJunctionStack.PRESSURE_RIB_SPRING_HEIGHT
		) * sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
		var segment_transforms: Array[Transform3D] = []
		for rib_index in AftJunctionStack.PRESSURE_RIB_COPY_COUNT:
			var current := Vector3(
				x_position,
				curve_height,
				AftJunctionStack.PRESSURE_RIB_Z_START
					+ float(rib_index) * AftJunctionStack.PRESSURE_RIB_Z_STEP
			)
			var previous := previous_points[rib_index]
			var direction := current - previous
			segment_transforms.append(Transform3D(
				Basis(Quaternion(Vector3.UP, direction.normalized())),
				(previous + current) * 0.5
			))
			previous_points[rib_index] = current
		result.append(segment_transforms)
	return result


func _test_exact_arc_geometry(mesh: Mesh) -> void:
	var actual := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = actual[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = actual[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = actual[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = actual[Mesh.ARRAY_TANGENT]
	var expected_by_segment := _expected_transforms_by_segment()
	var previous := Vector3(AftJunctionStack.PRESSURE_RIB_X_MIN,
		AftJunctionStack.PRESSURE_RIB_SPRING_HEIGHT, 0.0)
	var offset := 0
	var exact := true
	for segment_index in AftJunctionStack.PRESSURE_RIB_SEGMENT_COUNT:
		var placement: Transform3D = expected_by_segment[segment_index][0]
		placement.origin.z = 0.0
		var direction := (placement.origin - previous) * 2.0
		var source := StationSurfaceKit.chamfered_cylinder_mesh(
			AftJunctionStack.PRESSURE_RIB_RADIUS, AftJunctionStack.PRESSURE_RIB_RADIUS,
			direction.length(), StationSurfaceKit.radial_segments_for(
				AftJunctionStack.PRESSURE_RIB_RADIUS, AftJunctionStack.PRESSURE_RIB_NEAREST_VIEW_METRES))
		var arrays := source.surface_get_arrays(0)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var source_tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for index in source_vertices.size():
			if offset + index >= vertices.size():
				exact = false
				break
			var expected_normal := (placement.basis * source_normals[index]).normalized()
			var tangent_offset := index * 4
			var expected_tangent := placement.basis * Vector3(source_tangents[tangent_offset],
				source_tangents[tangent_offset + 1], source_tangents[tangent_offset + 2])
			var actual_tangent_offset := (offset + index) * 4
			var actual_tangent := Vector3(tangents[actual_tangent_offset],
				tangents[actual_tangent_offset + 1], tangents[actual_tangent_offset + 2])
			exact = exact and vertices[offset + index].distance_to(placement * source_vertices[index]) < 0.00001
			exact = exact and normals[offset + index].distance_to(expected_normal) < 0.0002
			exact = exact and actual_tangent.distance_to(expected_tangent) < 0.0002
			exact = exact and tangents[actual_tangent_offset + 3] == source_tangents[tangent_offset + 3]
			exact = exact and uvs[offset + index].is_equal_approx(source_uvs[index])
		offset += source_vertices.size()
		previous += direction
	_check(exact and vertices.size() == offset and actual[Mesh.ARRAY_INDEX] == null,
		"all fourteen original tube triangles retain order, vertices, UVs, normals and tangent handedness")


func _encode_transforms(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


func _transformed_bounds(mesh_bounds: AABB, transforms: Array[Transform3D]) -> AABB:
	var result := AABB()
	for index in transforms.size():
		var piece := (transforms[index] * mesh_bounds).abs()
		result = piece if index == 0 else result.merge(piece)
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failed = true
		push_error("FAIL: " + message)
