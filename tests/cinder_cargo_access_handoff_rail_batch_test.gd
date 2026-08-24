extends SceneTree

const ACCESS_SCENE := preload("res://scenes/world/components/cinder_cargo_access.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var access := ACCESS_SCENE.instantiate() as CinderCargoAccess
	root.add_child(access)
	await process_frame
	var audit := access.get_handoff_rail_visual_audit()
	var batch := access.get_node_or_null(^"Rails/HandoffRailBatch") as MultiMeshInstance3D
	_check(
		bool(audit.valid)
		and int(audit.visible_copy_count) == 2
		and int(audit.renderer_submissions) == 1
		and int(audit.before_renderer_submissions) == 2
		and int(audit.renderer_submission_delta) == -1
		and int(audit.renderer_node_delta) == -1,
		"paired handoff visuals resolve through one bounded renderer"
	)
	var collision_ids := {}
	var bodies_intact := true
	var expected_transforms := audit.authored_transforms as Array
	for rail_index in CinderCargoAccess.HANDOFF_RAIL_NODE_NAMES.size():
		var rail_name := CinderCargoAccess.HANDOFF_RAIL_NODE_NAMES[rail_index]
		var body := access.get_node_or_null(NodePath("Rails/%s" % rail_name)) as StaticBody3D
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D \
			if body != null else null
		bodies_intact = bodies_intact and body != null \
			and body.get_node_or_null(^"Mesh") == null \
			and collision != null and collision.shape is BoxShape3D \
			and body.transform.is_equal_approx(expected_transforms[rail_index] as Transform3D)
		if collision != null and collision.shape != null:
			collision_ids[collision.shape.get_instance_id()] = true
	_check(
		bodies_intact and collision_ids.size() == 2,
		"named handoff collision owners and private shapes remain unchanged"
	)
	var materials := access.get("_materials") as Dictionary
	_check(
		batch != null and batch.multimesh != null
		and batch.multimesh.transform_format == MultiMesh.TRANSFORM_3D
		and batch.multimesh.instance_count == 2
		and batch.multimesh.visible_instance_count == 2
		and batch.material_override == materials.frame
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and batch.multimesh.custom_aabb.has_volume(),
		"batch preserves the authored silhouette, material, and bounded culling"
	)
	var component_audit := access.audit()
	_check(
		bool(component_audit.valid)
		and int(component_audit.actual_budget.mesh_instances) == 13
		and int(component_audit.actual_budget.multimesh_instances) == 6
		and int(component_audit.actual_budget.geometry_submissions) == 19
		and access.get_route_snapshot().size() == 5
		and access.get_berth() != null
		and access.find_children("*", "Light3D", true, false).is_empty(),
		"route, berth, lighting, and reduced renderer budget stay valid"
	)
	access.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER CARGO ACCESS HANDOFF RAIL BATCH TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
