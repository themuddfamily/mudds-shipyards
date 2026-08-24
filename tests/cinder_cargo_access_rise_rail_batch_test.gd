extends SceneTree

const ACCESS_SCENE := preload("res://scenes/world/components/cinder_cargo_access.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var access := ACCESS_SCENE.instantiate() as CinderCargoAccess
	root.add_child(access)
	await process_frame
	var allocation := access.get_rise_rail_visual_audit()
	var batch := access.get_node_or_null(^"Rails/RiseRailBatch") as MultiMeshInstance3D
	_check(
		bool(allocation.valid)
		and int(allocation.visible_copy_count) == 2
		and int(allocation.renderer_submissions) == 1
		and int(allocation.before_renderer_submissions) == 2
		and int(allocation.renderer_submission_delta) == -1,
		"two immutable rise-rail visuals resolve through one renderer submission"
	)
	var bodies_intact := true
	var collision_ids := {}
	for rail_name in CinderCargoAccess.RISE_RAIL_NODE_NAMES:
		var body := access.get_node_or_null(NodePath("Rails/%s" % rail_name)) as StaticBody3D
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D \
			if body != null else null
		bodies_intact = bodies_intact and body != null \
			and body.get_node_or_null(^"Mesh") == null \
			and collision != null and collision.shape is BoxShape3D \
			and (collision.shape as BoxShape3D).size.is_equal_approx(
				CinderCargoAccess.RISE_RAIL_SIZE
			)
		if collision != null and collision.shape != null:
			collision_ids[collision.shape.get_instance_id()] = true
	_check(
		bodies_intact and collision_ids.size() == 2,
		"named rail collision owners and their private shapes remain intact"
	)
	var materials := access.get("_materials") as Dictionary
	_check(
		batch != null and batch.multimesh != null
		and batch.multimesh.transform_format == MultiMesh.TRANSFORM_3D
		and batch.multimesh.instance_count == 2
		and batch.material_override == materials.frame
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and (allocation.authored_transforms as Array).size() == 2,
		"batch preserves the exact transform roster, frame material, and shadow state"
	)
	var component_audit := access.audit()
	_check(
		bool(component_audit.valid)
		and (component_audit.actual_budget as Dictionary) == CinderCargoAccess.LOCAL_BUDGET
		and access.get_route_snapshot().size() == 5
		and access.get_berth() != null
		and access.find_children("*", "Light3D", true, false).is_empty(),
		"berth, traversable route, light budget, and component authority contract stay valid"
	)
	access.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER CARGO ACCESS RISE RAIL BATCH TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
