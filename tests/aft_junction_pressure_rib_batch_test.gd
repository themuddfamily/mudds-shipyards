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

	var expected_by_segment := _expected_transforms_by_segment()
	var visible_copies := 0
	var surface_submissions := 0
	var renderer_nodes := 0
	for segment_index in AftJunctionStack.PRESSURE_RIB_SEGMENT_COUNT:
		var batch := envelope.get_node_or_null(
			NodePath("PressureRibSegmentBatch%02d" % segment_index)
		) as MultiMeshInstance3D
		var multimesh := batch.multimesh if batch != null else null
		var mesh := multimesh.mesh if multimesh != null else null
		var expected: Array[Transform3D] = expected_by_segment[segment_index]
		_check(
			batch != null
			and multimesh != null
			and mesh != null
			and multimesh.instance_count == AftJunctionStack.PRESSURE_RIB_COPY_COUNT
			and multimesh.visible_instance_count == AftJunctionStack.PRESSURE_RIB_COPY_COUNT
			and multimesh.buffer == _encode_transforms(expected)
			and multimesh.custom_aabb.is_equal_approx(_transformed_bounds(mesh.get_aabb(), expected))
			and mesh.get_surface_count() == 1
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and batch.layers == 1
			and batch.material_override != null
			and batch.get_child_count() == 0
			and batch.get_script() == null
			and bool(batch.get_meta("visual_detail_only", false)),
			"segment recipe %02d keeps five exact visible copies in one inert submission" % segment_index
		)
		if multimesh != null and mesh != null:
			renderer_nodes += 1
			visible_copies += multimesh.visible_instance_count
			surface_submissions += mesh.get_surface_count()

	_check(
		renderer_nodes == AftJunctionStack.PRESSURE_RIB_SEGMENT_COUNT
		and visible_copies == AftJunctionStack.PRESSURE_RIB_VISIBLE_COPY_COUNT
		and surface_submissions == AftJunctionStack.PRESSURE_RIB_SEGMENT_COUNT,
		"70 roof-rib tube copies use 14 renderer nodes and 14 surface submissions"
	)
	_check(
		envelope.find_children("TubeSegment*", "MeshInstance3D", true, false).is_empty(),
		"the 70 legacy child renderers are absent"
	)

	var census := module.get_pod_corner_collar_visual_allocation_audit()
	_check(
		bool(census.valid)
		and int(census.current.descendant_nodes) == AftJunctionStack.RENDER_DESCENDANT_NODE_COUNT
		and int(census.current.renderer_nodes) == AftJunctionStack.RENDERER_NODE_COUNT
		and int(census.current.drawn_copies) == AftJunctionStack.DRAWN_COPY_COUNT
		and int(census.current.surface_submissions) == AftJunctionStack.SURFACE_SUBMISSION_COUNT,
		"the production Aft census records the exact 56-node and 56-submission reduction"
	)

	module.queue_free()
	await process_frame
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
