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
	var batch := envelope.get_node_or_null(
		^"RoofVentLouvreBatch"
	) as MultiMeshInstance3D if envelope != null else null
	_check(envelope != null and batch != null, "roof-vent louvre batch exists in its authored envelope")
	if envelope != null:
		for index in AftJunctionStack.ROOF_VENT_LOUVRE_COPY_COUNT:
			var anchor := envelope.get_node_or_null(
				NodePath("VentLouvre%02d" % index)
			) as Marker3D
			_check(
				anchor != null
				and anchor.position.is_equal_approx(
					AftJunctionStack.ROOF_VENT_LOUVRE_POSITIONS[index] as Vector3
				)
				and anchor.get_child_count() == 0
				and bool(anchor.get_meta("presentation_only", false))
				and bool(anchor.get_meta("collision_free", false))
				and StringName(anchor.get_meta("detail_role", &"")) == &"roof_vent_louvre",
				"louvre %02d retains one childless visual-only transform anchor" % index
			)

	if batch != null and batch.multimesh != null:
		var multimesh := batch.multimesh
		var mesh := multimesh.mesh
		var material := batch.material_override as StandardMaterial3D
		_check(
			multimesh.instance_count == AftJunctionStack.ROOF_VENT_LOUVRE_COPY_COUNT
			and multimesh.visible_instance_count == AftJunctionStack.ROOF_VENT_LOUVRE_COPY_COUNT
			and mesh != null
			and mesh.get_surface_count() == 1
			and mesh.get_aabb().size.is_equal_approx(AftJunctionStack.ROOF_VENT_LOUVRE_SIZE),
			"one surface submission retains all six exact louvre copies and extents"
		)
		var expected_transforms: Array[Transform3D] = []
		for louvre_position in AftJunctionStack.ROOF_VENT_LOUVRE_POSITIONS:
			expected_transforms.append(Transform3D(Basis.IDENTITY, louvre_position as Vector3))
		_check(
			multimesh.buffer == _encode_transforms(expected_transforms),
			"the renderer buffer retains every authored louvre pose in order"
		)
		_check(
			material != null
			and material.albedo_color.is_equal_approx(Color("141d21"))
			and is_equal_approx(material.metallic, 0.48)
			and is_equal_approx(material.roughness, 0.47)
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and batch.layers == 1,
			"the batch retains the graphite material and renderer state"
		)
	else:
		_check(false, "roof-vent louvre MultiMesh resource exists")

	var census := module.get_pod_corner_collar_visual_allocation_audit()
	_check(
		bool(census.valid)
		and int(census.current.renderer_nodes) == AftJunctionStack.RENDERER_NODE_COUNT
		and int(census.current.surface_submissions) == AftJunctionStack.SURFACE_SUBMISSION_COUNT
		and int(census.current.drawn_copies) == AftJunctionStack.DRAWN_COPY_COUNT,
		"six visible copies remain while renderer and surface submissions fall by five"
	)

	module.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failed = true
		push_error("FAIL: " + message)


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
