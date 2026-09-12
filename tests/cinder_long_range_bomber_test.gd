extends SceneTree

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var bomber := Bomber.new()
	root.add_child(bomber)
	await process_frame
	_test_recessed_exhaust(bomber)
	_test_fitted_canopy(bomber)
	_test_service_cassettes(bomber)
	_test_forward_pressure_body(bomber)
	var audit := bomber.get_audit_report()
	var definition := bomber.get_ship_definition()
	_check(bool(audit.get("valid", false)), "the bomber builds a valid collision and payload contract")
	_check(
		definition != null
		and definition.is_definition_valid()
		and definition.get_ship_id() == &"cinder_long_range_bomber"
		and is_equal_approx(bomber.maximum_speed, definition.maximum_speed)
		and is_equal_approx(bomber.engine_start_time, definition.engine_start_time)
		and is_equal_approx(bomber.maximum_hull, definition.maximum_hull),
		"the live bomber consumes its authored 72 m/s, 3.6 s startup, and 240-hull profile"
	)
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the bomber makes no historical claim")
	_check(bomber.get_cockpit_seat_anchor() != null and bomber.get_boarding_marker() != null, "the bomber exposes physical cockpit and boarding anchors")
	_check(bomber.get_payload_hardpoints().size() == 4, "the bomber exposes four caller-owned payload hardpoints")
	_check(bool(bomber is HeroShip) and bool(audit.get("flight_authority", false)) and not bool(audit.get("combat_authority", true)) and not bool(audit.get("ordnance_authority", true)), "HeroShip owns flight while the component adds no duplicate combat or ordnance authority")
	var visual := bomber.get_variant_visual_root()
	var hull := visual.get_node_or_null(^"LongRangeHull") as MeshInstance3D
	var fairing := visual.get_node_or_null(^"CockpitSupportFairing") as MeshInstance3D
	var cockpit_floor := visual.get_node_or_null(^"CockpitInterior/CockpitFloor") as MeshInstance3D
	var fairing_mesh := fairing.mesh as ArrayMesh if fairing != null else null
	var hull_mesh := hull.mesh as ArrayMesh if hull != null else null
	var cockpit_floor_mesh := cockpit_floor.mesh if cockpit_floor != null else null
	_check(
		fairing != null
		and fairing_mesh != null
		and fairing.position.is_equal_approx(CinderLongRangeBomber.COCKPIT_SUPPORT_FAIRING_POSITION)
		and fairing_mesh.get_aabb().size.is_equal_approx(Vector3(3.9, 1.416, 6.8)),
		"the bomber builds the exact closed cockpit support fairing"
	)
	var hull_top := hull.position.y + hull_mesh.get_aabb().size.y * 0.5 \
			if hull != null and hull_mesh != null else INF
	var fairing_bottom := fairing.position.y + fairing_mesh.get_aabb().position.y \
			if fairing != null and fairing_mesh != null else INF
	var fairing_top := fairing.position.y + fairing_mesh.get_aabb().end.y \
			if fairing != null and fairing_mesh != null else -INF
	var cockpit_floor_bottom := cockpit_floor.position.y + cockpit_floor.get_aabb().position.y \
			if cockpit_floor != null and cockpit_floor_mesh != null else -INF
	var hull_overlap := hull_top - fairing_bottom
	var cockpit_overlap := fairing_top - cockpit_floor_bottom
	_check(
		hull_overlap > 0.02
		and absf(cockpit_overlap - 0.02) <= 0.0001,
		"the continuous shoulder enters the hull and seats 20 mm into the cockpit floor (%.4f m / %.4f m)" % [
			hull_overlap, cockpit_overlap
		]
	)
	_check(
		fairing != null
		and hull != null
		and fairing_mesh != null
		and fairing.visible
		and fairing.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and fairing.material_override == hull.material_override
		and not fairing_mesh.resource_local_to_scene
		and fairing.get_child_count() == 0
		and fairing.get_script() == null
		and fairing.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the fairing is one shared hull-material renderer with no collision or gameplay authority"
	)
	var sensor_audit := bomber.get_sensor_resource_sharing_audit()
	_check(
		bool(sensor_audit.get("valid", false))
		and bool(sensor_audit.get("chase_retains_sensor", false))
		and bool(sensor_audit.get("cockpit_omits_sensor", false)),
		"the fairing leaves the exterior sensor and cockpit/chase layer split unchanged"
	)
	bomber.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_long_range_bomber_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _test_recessed_exhaust(craft: HeroShip) -> void:
	var visual: Node3D = craft.call("get_variant_visual_root")
	var port := visual.get_node("PortGuideVanes") as MultiMeshInstance3D
	var starboard := visual.get_node("StarboardGuideVanes") as MultiMeshInstance3D
	var hub := visual.get_node("PortThrustPlug") as MeshInstance3D
	var lip := visual.get_node("PortNozzleLip") as MeshInstance3D
	var annulus := visual.get_node("PortCombustorAnnulus") as MeshInstance3D
	var bell := visual.get_node("PortExhaustBell") as MeshInstance3D
	var opposite_bell := visual.get_node("StarboardExhaustBell") as MeshInstance3D
	_check(port.multimesh.mesh is ArrayMesh and port.multimesh.instance_count == 12
		and port.multimesh.mesh == starboard.multimesh.mesh and bell.mesh == opposite_bell.mesh,
		"formed bells and twelve curved stator vanes retain immutable mesh sharing across paired engines")
	var vane_bounds := port.transform * port.multimesh.mesh.get_aabb()
	var hub_bounds := hub.transform * hub.mesh.get_aabb()
	_check(vane_bounds.end.z < lip.position.z and hub_bounds.end.z < lip.position.z
		and vane_bounds.size.z > port.scale.z * 0.2,
		"thick stator airfoils and the turned hub remain recessed inside the open bell")
	_check(not (annulus.material_override as StandardMaterial3D).emission_enabled
		and not (hub.material_override as StandardMaterial3D).emission_enabled
		and port.get_script() == null and hub.get_script() == null,
		"unpowered machinery has a passive metallic finish and adds no engine-state controller")


func _test_service_cassettes(craft: HeroShip) -> void:
	var visual: Node3D = craft.call("get_variant_visual_root")
	for tag in ["ThermalService", "RamScoop/Scoop"]:
		var port := visual.get_node("Port" + tag + "Frame") as MeshInstance3D
		var starboard := visual.get_node("Starboard" + tag + "Frame") as MeshInstance3D
		var vanes := visual.get_node("Port" + tag + "Vanes") as MeshInstance3D
		var opposite_vanes := visual.get_node("Starboard" + tag + "Vanes") as MeshInstance3D
		var backing := visual.get_node("Port" + tag + "Recess") as MeshInstance3D
		_check(port.mesh is ArrayMesh and vanes.mesh is ArrayMesh
			and port.mesh == starboard.mesh and vanes.mesh == opposite_vanes.mesh
			and backing.mesh == (visual.get_node("Starboard" + tag + "Recess") as MeshInstance3D).mesh,
			"paired %s cassettes share their three immutable renderer stocks" % tag)
		_check(vanes.mesh.get_faces().size() == 960 and port.mesh.get_faces().size() > 36
			and port.material_override != null and vanes.material_override != null
			and port.get_script() == null and port.get_child_count() == 0,
			"%s has five closed curved vanes and a continuous frame without gameplay nodes" % tag)
		var foot := visual.global_transform.affine_inverse() * port.global_transform * port.mesh.get_aabb()
		_check(foot.position.y < 1.18 and foot.end.y > 1.18
			and foot.position.z > -2.8 and foot.end.z < 3.8,
			"%s frame foot seats into the shoulder crown clear of nose optics and payload lanes" % tag)
	_check(visual.find_children("*Louver*", "MeshInstance3D", true, false).is_empty()
		and visual.find_children("*ThermalServiceRim*", "MeshInstance3D", true, false).is_empty(),
		"service grilles replace the former stacked bars and separate rails")


func _test_forward_pressure_body(craft: HeroShip) -> void:
	var visual: Node3D = craft.call("get_variant_visual_root")
	var hull := visual.get_node("LongRangeHull") as MeshInstance3D
	var cowl := visual.get_node("SensorProtectiveCowl") as MeshInstance3D
	var optics := visual.get_node("LongRangeSensor") as MeshInstance3D
	var hull_faces := hull.mesh.get_faces()
	# The four existing saddle feet must enter the pressure skin, with their
	# tops exposed. A bounding box alone cannot detect the old floating nose.
	for side in [-1.0, 1.0]:
		for local_z in [-0.46, 0.75]:
			var at := cowl.position + Vector3(side * 0.82, -0.10, local_z)
			var skin_y := _pressure_skin_height(hull_faces, at.x, at.z)
			_check(skin_y > at.y - 0.065 and skin_y < at.y + 0.065,
				"forward pressure skin seats the targeting saddle foot at %s (skin %.4f)" % [at, skin_y])
	var lenses_clear := true
	for vertex in optics.mesh.get_faces():
		var point: Vector3 = optics.transform * vertex
		lenses_clear = lenses_clear and point.y > _pressure_skin_height(hull_faces, point.x, point.z) + 0.015
	_check(lenses_clear, "both recessed targeting lenses remain fully above the formed nose skin")
	_check(hull.mesh.get_aabb().size.is_equal_approx(Vector3(5.6, 2.65, 15.5))
		and hull.mesh.get_surface_count() == 1
		and hull.transform.is_equal_approx(Transform3D.IDENTITY),
		"the formed bow retains the original primary hull envelope and single renderer surface")

	var shoulder_drop := _pressure_skin_height(hull_faces, 0.0, -1.0) - _pressure_skin_height(hull_faces, 1.8, -1.0)
	_check(shoulder_drop > 0.12 and shoulder_drop < 0.3,
		"the primary shoulder curves below its central equipment landing rather than retaining a slab crown")
	var terminal_seal_small := true
	var terminal_vertices := 0
	for point in hull_faces:
		if is_equal_approx(point.z, -7.75):
			terminal_vertices += 1
			terminal_seal_small = terminal_seal_small and absf(point.x) < 0.02 and absf(point.y) < 0.025
	_check(terminal_vertices > 0 and terminal_seal_small and hull_faces.size() / 3 <= 2200,
		"the rounded bow closes with a small terminal seal within the 2200-triangle primary skin budget")
	var mirrored_faces := hull_faces.duplicate()
	for index in mirrored_faces.size():
		mirrored_faces[index].y = -mirrored_faces[index].y
	for side in ["Port", "Starboard"]:
		var shoulder := visual.get_node(side + "PressureShoulder") as MeshInstance3D
		var cap_embedded := true
		var cap_vertices := 0
		for local in shoulder.mesh.get_faces():
			if is_equal_approx(local.z, -6.4):
				cap_vertices += 1
				var point: Vector3 = shoulder.transform * local
				cap_embedded = cap_embedded and point.y < _pressure_skin_height(hull_faces, point.x, point.z) - 0.01 \
					and point.y > -_pressure_skin_height(mirrored_faces, point.x, point.z) + 0.01
		_check(cap_vertices > 0 and cap_embedded, "%s nacelle nose cap enters the rolled main skin without a detached tooth" % side)
	var arrays := hull.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var frames_valid := normals.size() == vertices.size() and uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4
	for index in vertices.size():
		var tangent := Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
		frames_valid = frames_valid and normals[index].is_finite() and normals[index].length_squared() > 0.99 \
			and uvs[index].is_finite() and tangent.is_finite() and tangent.length_squared() > 0.99 \
			and absf(tangent.dot(normals[index])) < 0.01
	_check(frames_valid, "formed bow and shoulders retain complete UVs and finite orthogonal normal/tangent frames")


func _pressure_skin_height(faces: PackedVector3Array, x: float, z: float) -> float:
	var highest := -INF
	var above := Vector3(x, 3.0, z)
	var below := Vector3(x, -3.0, z)
	for index in range(0, faces.size(), 3):
		var hit = Geometry3D.segment_intersects_triangle(above, below, faces[index], faces[index + 1], faces[index + 2])
		if hit != null:
			highest = maxf(highest, hit.y)
	return highest


func _test_fitted_canopy(craft: HeroShip) -> void:
	var hinge := craft.get_variant_visual_root().get_node("CanopyHinge") as Node3D
	var glass := hinge.get_node("CanopyGlass") as MeshInstance3D
	var vertices: PackedVector3Array = glass.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var upper_only := true
	for index in range(0, vertices.size(), 3):
		var normal := (vertices[index + 2] - vertices[index]).cross(vertices[index + 1] - vertices[index]).normalized()
		upper_only = upper_only and normal.y > -0.95
	var pillar := hinge.get_node("PortCanopyNoseFrame") as MeshInstance3D
	var broad_pillar := true
	var sampled := false
	for vertex: Vector3 in pillar.mesh.get_faces():
		var point := hinge.position + pillar.transform * vertex
		if point.y > 2.90 and point.y < 3.45:
			sampled = true
			broad_pillar = broad_pillar and absf(point.x) > 1.025
	_check(upper_only and sampled and broad_pillar and bool(glass.get_meta("upper_pressure_enclosure", false)),
		"the fitted windscreen keeps pillars outside the forward instrument view and has no glass floor")
	var attached_keepers := true
	for side in ["Port", "Starboard"]:
		var keeper := hinge.get_node(side + "CanopyLatchHook") as MeshInstance3D
		var bounds := keeper.transform * keeper.mesh.get_aabb()
		attached_keepers = attached_keepers and bounds.end.y > 0.10 and bounds.position.y <= -0.119 and bounds.size.x > 0.30
	_check(attached_keepers, "both moving latch keepers reach from the lower lid rails to the retained striker contacts")
	var glass_stock := glass.mesh
	craft.set_canopy_open(true, 0.0)
	_check(hinge.rotation.x > 1.0 and glass.mesh == glass_stock and glass.is_visible_in_tree(),
		"the common functional hinge opens the complete fitted upper lid")
	craft.set_canopy_open(false, 0.0)
