extends SceneTree

## Focused production contract for the curved amber threshold above the Jovian's
## physical cargo ramp. The ramp/cargo collision and boarding authorities remain
## the ship's existing sources of truth.

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const PLAYER_RADIUS := 0.38
const PLAYER_HEIGHT := 1.94

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ship := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	_check(ship != null, "production Jovian scene instantiates for cargo boarding")
	if ship == null:
		_finish()
		return
	root.add_child(ship)
	await process_frame
	await physics_frame
	await physics_frame

	_test_curved_threshold(ship)
	await _test_physical_boarding_clearance(ship)

	ship.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_curved_threshold(ship: JovianLightFreighter) -> void:
	var header := ship.find_child("CargoApertureHeader", true, false) as MeshInstance3D
	_check(header != null and header.mesh != null, "the deployed cargo entrance retains one visible header")
	if header == null or header.mesh == null:
		return
	var arrays := header.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	_check(
		header.mesh.resource_name == "jovian_cargo_aperture_capsule_header_v1"
		and header.mesh.get_surface_count() == 1
		and vertices.size() / 3 == 72,
		"the curved cargo threshold uses one 72-triangle surface instead of the 108-triangle shallow box"
	)
	_check(
		header.mesh.get_aabb().position.is_equal_approx(
			-JovianLightFreighter.CARGO_APERTURE_HEADER_SIZE * 0.5
		)
		and header.mesh.get_aabb().size.is_equal_approx(
			JovianLightFreighter.CARGO_APERTURE_HEADER_SIZE
		)
		and header.position.is_equal_approx(Vector3(-5.78, 4.22, 3.2)),
		"the capsule render keeps the exact 0.34 x 0.30 x 4.20 m threshold envelope and placement"
	)
	var winding_matches_normals := normals.size() == vertices.size()
	for triangle_start in range(0, vertices.size(), 3):
		var face_normal := (
			vertices[triangle_start + 1] - vertices[triangle_start]
		).cross(
			vertices[triangle_start + 2] - vertices[triangle_start]
		).normalized()
		var authored_normal := (
			normals[triangle_start]
			+ normals[triangle_start + 1]
			+ normals[triangle_start + 2]
		).normalized()
		# Godot's engine primitives use clockwise front faces, so this CCW cross
		# product must point opposite the authored outward shading normal.
		winding_matches_normals = winding_matches_normals and face_normal.dot(authored_normal) <= -0.99
	_check(winding_matches_normals, "all capsule caps and rim triangles face outward under back-face culling")
	var upright := ship.find_child("CargoApertureUpright", true, false) as MeshInstance3D
	_check(
		upright != null and upright.mesh != null
		and header.mesh.surface_get_material(0) == upright.mesh.surface_get_material(0)
		and header.get_child_count() == 0
		and header.get_parent().find_children("CargoApertureHeader", "MeshInstance3D", false, false).size() == 1,
		"the threshold retains the amber material and one childless renderer/submission"
	)
	_check(
		str(header.get_meta("geometry_profile", "")) == "yz_extruded_capsule"
		and is_equal_approx(float(header.get_meta("end_radius_m", 0.0)), 0.15)
		and int(header.get_meta("curve_segments_per_end", 0)) == 8
		and str(header.get_meta("evidence_status", "")) == "provisional"
		and not bool(header.get_meta("authenticated_historical_geometry", true))
		and bool(header.get_meta("visual_only", false)),
		"the curve keeps the Jovian's honest provisional, unauthenticated geometry status"
	)
	var evidence := ship.get_jovian_evidence_report()
	_check(
		str(evidence.get("evidence_status", "")) == "provisional"
		and str(evidence.get("name_to_model_status", "")) == "unknown"
		and not bool(evidence.get("authenticated_geometry", true)),
		"craft silhouette evidence remains provisional with unknown name-to-model mapping"
	)
	_check(
		bool(ship.get_jovian_audit_report().get("valid", false)),
		"the complete Jovian definition, interior, allocation and presentation audit remains green"
	)


func _test_physical_boarding_clearance(ship: JovianLightFreighter) -> void:
	var ramp_visual := ship.find_child("PortCargoRamp", true, false) as MeshInstance3D
	var ramp_collision := ship.get_node_or_null(^"PortCargoRampCollision") as CollisionShape3D
	var cargo_collision := ship.get_node_or_null(^"CargoDeckCollision") as CollisionShape3D
	_check(
		ramp_visual != null and ramp_visual.mesh != null
		and ramp_collision != null and ramp_collision.shape is ConvexPolygonShape3D
		and cargo_collision != null and cargo_collision.shape is BoxShape3D,
		"the retained visual ramp, true convex wedge and cargo-deck threshold are live"
	)
	if ramp_collision == null or not ramp_collision.shape is ConvexPolygonShape3D:
		return
	var ramp_points := (ramp_collision.shape as ConvexPolygonShape3D).points
	_check(
		ramp_points.size() == 8
		and ramp_visual.mesh.get_aabb().position.is_equal_approx(Vector3(-10.45, -1.25, 1.5))
		and ramp_visual.mesh.get_aabb().size.is_equal_approx(Vector3(4.725, 1.73, 3.4)),
		"ramp silhouette and eight-point physical wedge retain their exact boarding envelope"
	)

	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	var route_x := PackedFloat32Array([-10.0, -8.0, -6.0, -5.2])
	var every_sample_clear := true
	for x_position in route_x:
		var surface_y := lerpf(-1.25, 0.48, inverse_lerp(-10.45, -5.725, x_position))
		if x_position > -5.725:
			surface_y = 0.48
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = capsule
		params.transform = Transform3D(
			Basis.IDENTITY,
			ship.to_global(Vector3(x_position, surface_y + 1.05, 3.2))
		)
		params.collision_mask = PhysicsLayers.SHIP_BODY_LAYER
		params.collide_with_bodies = true
		params.collide_with_areas = false
		await physics_frame
		every_sample_clear = every_sample_clear and ship.get_world_3d().direct_space_state.intersect_shape(params, 32).is_empty()
	_check(every_sample_clear, "a production-sized player capsule clears the sloped ramp and cargo threshold")

	var boarding_area := ship.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	_check(
		boarding_area != null and boarding_area.get_ship() == ship and boarding_area.is_available()
		and ship.get_passenger_seat_anchors().size() == JovianLightFreighter.PASSENGER_SEAT_COUNT
		and ship.find_children("*", "StationDoor", true, false).is_empty(),
		"pilot boarding, six seat anchors and the cargo aperture's zero-door authority remain unchanged"
	)
	_check(
		bool(ship.get_berth_clearance_report().get("deployed_ramp_may_overlap_apron", false)),
		"ship clearance still identifies the deployed ramp as the sole permitted apron overlap"
	)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("JOVIAN_CARGO_ENTRY_CURVE_TEST_OK")
		quit(0)
	else:
		print("JOVIAN_CARGO_ENTRY_CURVE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
