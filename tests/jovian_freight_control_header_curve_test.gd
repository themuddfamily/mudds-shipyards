extends SceneTree

## Focused production contract for the curved freight-control lintel visible on
## the normal service-room approach. The test observes the retained module,
## StationDoor and collision authority rather than recreating any of them.

const MODULE_SCENE := preload("res://scenes/world/modules/jovian_freight_berth.tscn")
const PLAYER_RADIUS := 0.38
const PLAYER_HEIGHT := 1.94

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var module := MODULE_SCENE.instantiate() as JovianFreightBerth
	_check(module != null, "production Jovian Freight Berth instantiates for its service approach")
	if module == null:
		_finish()
		return
	root.add_child(module)
	await process_frame
	await physics_frame
	await physics_frame

	_test_curved_header(module)
	await _test_retained_door_clearance(module)

	module.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_curved_header(module: JovianFreightBerth) -> void:
	var header := module.get_node_or_null(^"FreightControlDoorHeader") as StaticBody3D
	var visual := header.get_node_or_null(^"Mesh") as MeshInstance3D if header != null else null
	var collision := header.get_node_or_null(^"Collision") as CollisionShape3D if header != null else null
	var shape := collision.shape as BoxShape3D if collision != null else null
	_check(
		header != null and visual != null and visual.mesh != null and shape != null,
		"freight control retains one rendered, collision-backed doorway header"
	)
	if header == null or visual == null or visual.mesh == null or shape == null:
		return

	var arrays := visual.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	_check(
		visual.mesh.resource_name == "jovian_freight_control_capsule_header_v1"
		and visual.mesh.get_surface_count() == 1
		and vertices.size() / 3 == 72,
		"visible lintel uses one 72-triangle capsule surface instead of the 108-triangle shallow box"
	)
	_check(
		visual.mesh.get_aabb().position.is_equal_approx(
			-JovianFreightBerth.FREIGHT_CONTROL_HEADER_SIZE * 0.5
		)
		and visual.mesh.get_aabb().size.is_equal_approx(
			JovianFreightBerth.FREIGHT_CONTROL_HEADER_SIZE
		)
		and shape.size.is_equal_approx(JovianFreightBerth.FREIGHT_CONTROL_HEADER_SIZE)
		and header.position.is_equal_approx(Vector3(16.3, 3.85, 29.0)),
		"curve, placement and box collider preserve the exact 0.42 x 1.30 x 4.05 m envelope"
	)
	var roof := module.get_node_or_null(^"FreightControlRoom/RoomRoof") as StaticBody3D
	var roof_visual := roof.get_node_or_null(^"Mesh") as MeshInstance3D if roof != null else null
	_check(
		roof_visual != null
		and visual.material_override == roof_visual.material_override
		and header.get_child_count() == 2
		and header.collision_layer == PhysicsLayers.WORLD
		and header.collision_mask == PhysicsLayers.NONE,
		"lintel retains ceramic material, two-child body and World-only collision authority"
	)
	_check(
		str(header.get_meta("geometry_profile", "")) == "yz_extruded_capsule_header"
		and is_equal_approx(float(header.get_meta("end_radius_m", 0.0)), 0.65)
		and int(header.get_meta("curve_segments_per_end", 0)) == 8
		and not bool(header.get_meta("authenticated_original_geometry", true))
		and str(header.get_meta("handling_fixture_class", "")) == "freight-control-door-header",
		"header publishes its bounded curve recipe and retains fixture identity"
	)
	_check(
		_all_triangles_face_their_normals(vertices, normals),
		"caps, rim and curved ends retain outward front-face winding"
	)

	var freight_sign: Label3D
	for candidate in module.find_children("*", "Label3D", true, false):
		var label := candidate as Label3D
		if label != null and label.text == "FREIGHT CONTROL":
			freight_sign = label
			break
	var fascia := module.get_node_or_null(^"FreightControlSignFascia") as MeshInstance3D
	_check(
		freight_sign != null and freight_sign.visible
		and freight_sign.position.is_equal_approx(Vector3(16.05, 3.95, 29.0))
		and freight_sign.rotation_degrees.is_equal_approx(Vector3(0.0, -90.0, 0.0))
		and fascia != null and fascia.position.is_equal_approx(Vector3(16.0, 3.95, 29.0)),
		"FREIGHT CONTROL legend and its contrast fascia remain at their readable approach transforms"
	)

	var evidence := module.get_evidence_metadata()
	var audit := module.get_audit_report()
	_check(
		str(evidence.get("evidence_status", "")) == "creator_roster_supported_modern_interpretation"
		and not bool(evidence.get("authenticated_original_geometry", true)),
		"curved treatment preserves the berth's honest modern-interpretation evidence boundary"
	)
	_check(
		bool(audit.get("valid", false)) and bool(module.get_performance_contract().within_budget),
		"production module geometry, collision, authority and component budgets remain green: %s"
		% [audit.get("errors", [])]
	)


func _test_retained_door_clearance(module: JovianFreightBerth) -> void:
	var door := module.get_service_access()
	_check(
		door != null and "FREIGHT CONTROL" in door.get_interaction_prompt()
		and door.interact(module),
		"retained FREIGHT CONTROL StationDoor accepts its normal opening interaction"
	)
	if door == null:
		return
	for frame_index in 120:
		if door.is_open():
			break
		await physics_frame
	_check(
		door.is_open() and not door.is_portal_blocked(),
		"real service door reaches its fully clear state beneath the curved lintel"
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
		"production player capsule retains exact clear passage through the open threshold"
	)


func _all_triangles_face_their_normals(
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
	) -> bool:
	if vertices.size() == 0 or vertices.size() != normals.size() or vertices.size() % 3 != 0:
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
		print("JOVIAN_FREIGHT_CONTROL_HEADER_CURVE_TEST_OK")
		quit(0)
	else:
		print("JOVIAN_FREIGHT_CONTROL_HEADER_CURVE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
