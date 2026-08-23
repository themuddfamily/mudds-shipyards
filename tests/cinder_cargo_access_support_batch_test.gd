extends SceneTree

const ACCESS_SCENE := preload("res://scenes/world/components/cinder_cargo_access.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var access := ACCESS_SCENE.instantiate() as CinderCargoAccess
	root.add_child(access)
	await process_frame
	var audit := access.get_terminal_approach_support_visual_audit()
	var batch := access.get_node_or_null(
		^"Structure/TerminalApproachSupportBatch"
	) as MultiMeshInstance3D
	_check(
		bool(audit.valid)
		and int(audit.visible_copy_count) == 2
		and int(audit.renderer_submissions) == 1
		and int(audit.before_renderer_submissions) == 2
		and int(audit.renderer_submission_delta) == -1,
		"two identical support visuals resolve through one bounded renderer submission"
	)
	var bodies_intact := true
	var private_collision_ids := {}
	for support_name in CinderCargoAccess.TERMINAL_APPROACH_SUPPORT_NODE_NAMES:
		var body := access.get_node_or_null(
			NodePath("Structure/%s" % support_name)
		) as StaticBody3D
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D \
			if body != null else null
		bodies_intact = bodies_intact and body != null \
			and body.get_node_or_null(^"Mesh") == null \
			and collision != null and collision.shape is BoxShape3D
		if collision != null and collision.shape != null:
			private_collision_ids[collision.shape.get_instance_id()] = true
	_check(
		bodies_intact and private_collision_ids.size() == 2,
		"named support bodies and both private collision identities remain intact"
	)
	_check(
		batch != null and batch.multimesh != null
		and batch.multimesh.transform_format == MultiMesh.TRANSFORM_3D
		and batch.multimesh.instance_count == 2
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and (audit.authored_transforms as Array).size() == 2,
		"batch preserves the exact 3D transform roster and shadow state"
	)
	_check(
		bool(access.audit().valid)
		and access.get_route_snapshot().size() == 5
		and access.get_berth() != null,
		"berth, collision-backed access route, and component contract stay valid"
	)
	access.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER CARGO ACCESS SUPPORT BATCH TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
