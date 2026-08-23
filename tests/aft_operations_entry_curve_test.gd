extends SceneTree

## Focused production contract for the curved Operations Access pressure header.
## The retained Aft module, StationDoor and frame collision remain authoritative.

const MODULE_SCENE := preload("res://scenes/world/modules/aft_junction_stack.tscn")
const PLAYER_RADIUS := 0.38
const PLAYER_HEIGHT := 1.94

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var module := MODULE_SCENE.instantiate() as AftJunctionStack
	_check(module != null, "production Aft Junction Stack instantiates for Operations Access")
	if module == null:
		_finish()
		return
	root.add_child(module)
	await process_frame
	await physics_frame
	await physics_frame

	_test_curved_operations_header(module)
	await _test_retained_door_clearance(module)

	module.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_curved_operations_header(module: AftJunctionStack) -> void:
	var door := module.get_operations_entrance()
	var header := door.get_node_or_null(^"FrameVisuals/Header") as MeshInstance3D if door != null else null
	var collision := door.get_node_or_null(^"FrameBody/HeaderCollision") as CollisionShape3D if door != null else null
	var shape := collision.shape as BoxShape3D if collision != null else null
	_check(
		door != null and header != null and header.mesh != null and shape != null,
		"Operations Access retains its rendered header and authoritative frame collision"
	)
	if door == null or header == null or header.mesh == null or shape == null:
		return

	var arrays := header.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	_check(
		header.mesh.resource_name == "aft_operations_capsule_access_header_v1"
		and header.mesh.get_surface_count() == 1
		and vertices.size() / 3 == 72,
		"visible access header uses one 72-triangle capsule surface instead of the 108-triangle shallow box"
	)
	_check(
		header.mesh.get_aabb().position.is_equal_approx(
			-AftJunctionStack.OPERATIONS_ENTRANCE_HEADER_SIZE * 0.5
		)
		and header.mesh.get_aabb().size.is_equal_approx(
			AftJunctionStack.OPERATIONS_ENTRANCE_HEADER_SIZE
		)
		and shape.size.is_equal_approx(AftJunctionStack.OPERATIONS_ENTRANCE_HEADER_SIZE)
		and header.position.is_equal_approx(Vector3(0.0, 3.65, 0.0))
		and collision.position.is_equal_approx(Vector3(0.0, 3.65, 0.0)),
		"curve and retained collider preserve the exact 4.2 x 0.5 x 0.72 m frame envelope"
	)
	var vip_header := module.get_vip_access().get_node_or_null(
		^"FrameVisuals/Header"
	) as MeshInstance3D
	var frame_visuals := header.get_parent()
	_check(
		vip_header != null
		and header.material_override == vip_header.material_override
		and header.get_child_count() == 0
		and frame_visuals.get_child_count() == 4,
		"header retains the station-door trim material and adds no node or renderer submission"
	)
	_check(
		str(header.get_meta("geometry_profile", "")) == "xy_extruded_capsule_header"
		and is_equal_approx(float(header.get_meta("end_radius_m", 0.0)), 0.25)
		and int(header.get_meta("curve_segments_per_end", 0)) == 8
		and str(header.get_meta("evidence_status", "")) == "modern_interpretation"
		and not bool(header.get_meta("authenticated_original_geometry", true)),
		"header publishes its bounded curve recipe and honest modern-interpretation label"
	)
	_check(
		_all_triangles_face_their_normals(vertices, normals),
		"caps, rim and curved ends retain outward front-face winding"
	)

	var sign := module.get_node_or_null(
		^"Structure/OperationsRoom/Sign_AFT_OPERATIONS"
	) as MeshInstance3D
	var sign_mesh := sign.mesh as TextMesh if sign != null else null
	_check(
		sign != null and sign_mesh != null and sign.visible
		and sign_mesh.text == "AFT OPERATIONS"
		and sign.position.is_equal_approx(Vector3(7.2, 3.7, 9.31))
		and sign.rotation_degrees.is_equal_approx(Vector3(0.0, 180.0, 0.0)),
		"AFT OPERATIONS signage remains readable at its exact approach transform"
	)
	var audit := module.get_audit_report()
	var evidence := module.get_evidence_metadata()
	_check(
		bool(audit.get("valid", false)) and bool(module.get_performance_contract().within_budget),
		"Aft module collision, route, lifecycle and component budgets remain green: %s"
		% [audit.get("errors", [])]
	)
	_check(
		str(evidence.get("evidence_status", "")) == "modern_interpretation"
		and "exact geometry" in str(evidence.get("content_note", ""))
		and "modern design" in str(evidence.get("content_note", "")),
		"module-level evidence continues to reject authenticated original geometry"
	)


func _test_retained_door_clearance(module: AftJunctionStack) -> void:
	var door := module.get_operations_entrance()
	_check(
		door != null and door.can_interact(module)
		and "OPERATIONS ACCESS" in door.get_interaction_prompt()
		and door.interact(module),
		"retained Operations Access StationDoor accepts its normal interaction"
	)
	if door == null:
		return
	for frame_index in 120:
		if door.is_open():
			break
		await physics_frame
	_check(
		door.is_open() and not door.is_portal_blocked(),
		"real Operations Access door reaches its fully clear state"
	)

	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, door.to_global(Vector3(0.0, 1.08, 0.0)))
	query.collision_mask = PhysicsLayers.WORLD
	query.collide_with_bodies = true
	query.collide_with_areas = false
	await physics_frame
	_check(
		module.get_world_3d().direct_space_state.intersect_shape(query, 32).is_empty(),
		"production player capsule retains exact passage beneath the curved header"
	)


func _all_triangles_face_their_normals(
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
	) -> bool:
	if vertices.is_empty() or vertices.size() != normals.size() or vertices.size() % 3 != 0:
		return false
	for index in range(0, vertices.size(), 3):
		var geometric := (vertices[index + 1] - vertices[index]).cross(
			vertices[index + 2] - vertices[index]
		).normalized()
		var declared := (
			normals[index] + normals[index + 1] + normals[index + 2]
		).normalized()
		if geometric.dot(declared) < 0.99:
			return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("AFT_OPERATIONS_ENTRY_CURVE_TEST_OK")
		quit(0)
	else:
		print("AFT_OPERATIONS_ENTRY_CURVE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
