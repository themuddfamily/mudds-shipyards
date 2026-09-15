extends SceneTree

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var craft := Interceptor.new()
	root.add_child(craft)
	await process_frame
	_test_induction_cassettes(craft)
	_test_recessed_exhaust(craft)
	_test_fitted_canopy(craft)
	_test_formed_cockpit_walls(craft)
	await _test_armor_instance_finish(craft)
	var audit := craft.get_audit_report()
	_check(bool(audit.get("valid", false)), "the interceptor builds a valid collision and lifecycle contract")
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the interceptor makes no historical claim")
	_check(craft.get_cockpit_seat_anchor() != null and craft.get_boarding_marker() != null, "the interceptor exposes physical cockpit and boarding anchors")
	_check(bool(craft is HeroShip) and bool(audit.get("flight_authority", false)) and not bool(audit.get("combat_authority", true)) and not bool(audit.get("weapon_authority", true)), "HeroShip owns flight while the component adds no duplicate combat or weapon authority")
	_test_closed_cockpit_fairing(craft)
	_test_console_toggle_batch(craft)
	_test_console_key_batch(craft)
	_test_console_center_key_batch(craft)
	await _test_shared_damage_presentation(craft)
	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_light_interceptor_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _test_closed_cockpit_fairing(craft: CinderLightInterceptor) -> void:
	var visual := craft.get_variant_visual_root()
	var hull := visual.get_node_or_null(^"HighVisibilityHull") as MeshInstance3D
	var fairing := visual.get_node_or_null(^"ClosedCockpitFairing") as MeshInstance3D
	var cockpit_floor := visual.get_node_or_null(
		^"CockpitInterior/CockpitFloor"
	) as MeshInstance3D
	var canopy := visual.get_node_or_null(^"Canopy") as MeshInstance3D
	var hull_bounds := (hull.transform * hull.mesh.get_aabb()).abs() if hull != null else AABB()
	var fairing_bounds := (fairing.transform * fairing.mesh.get_aabb()).abs() \
		if fairing != null else AABB()
	var floor_bounds := (cockpit_floor.transform * cockpit_floor.mesh.get_aabb()).abs() \
		if cockpit_floor != null else AABB()
	var canopy_bounds := (canopy.transform * canopy.mesh.get_aabb()).abs() \
		if canopy != null else AABB()
	_check(
		hull != null
		and fairing != null
		and cockpit_floor != null
		and canopy != null
		and fairing.mesh is ArrayMesh
		and fairing_bounds.size.x <= 3.55
		and is_equal_approx(fairing_bounds.position.z, -4.35)
		and is_equal_approx(fairing_bounds.end.z, 3.1)
		and fairing_bounds.position.y < hull_bounds.end.y
		and is_equal_approx(fairing_bounds.end.y, floor_bounds.position.y + 0.02)
		and fairing_bounds.intersects(canopy_bounds)
		and fairing.material_override == hull.material_override
		and fairing.layers == 1
		and fairing.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and fairing.get_child_count() == 0
		and bool(fairing.get_meta(&"visual_detail_only", false))
		and not bool(fairing.get_meta(&"gameplay_authority", true))
		and fairing.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"one closed visual-only fairing joins the hull crown, canopy and cockpit floor without collision authority"
	)

	var cap_seated := true
	var fairing_points: PackedVector3Array = fairing.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point in fairing_points:
		var at := fairing.transform * point
		if is_equal_approx(at.z, fairing_bounds.position.z):
			cap_seated = cap_seated and at.y < _skin_height(hull, at)
	_check(cap_seated, "the elongated fairing's forward cap remains buried inside the primary nose skin")
	var plate_seated := true
	var plate_exposed := true
	var plate_points: PackedVector3Array = canopy.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point in plate_points:
		var at := canopy.transform * point
		var gap := at.y - _skin_height(fairing, at)
		if point.z > 0.0:
			plate_seated = plate_seated and gap >= -0.01 and gap <= 0.005
		else:
			plate_exposed = plate_exposed and gap > 0.025 and gap < 0.055
	_check(plate_seated and plate_exposed, "all four optical-plate underside corners seat in the formed ramp while its front face remains exposed")


func _skin_height(skin: MeshInstance3D, at: Vector3) -> float:
	var arrays := skin.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for index in points.size():
			indices.append(index)
	var height := -INF
	for triangle in range(0, indices.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(
			Vector3(at.x, 8.0, at.z), Vector3.DOWN,
			skin.transform * points[indices[triangle]],
			skin.transform * points[indices[triangle + 1]],
			skin.transform * points[indices[triangle + 2]])
		if hit != null:
			height = maxf(height, hit.y)
	return height


func _test_console_toggle_batch(craft: CinderLightInterceptor) -> void:
	var cockpit := craft.get_variant_visual_root().get_node_or_null("CockpitInterior") as Node3D
	var batch := cockpit.get_node_or_null("CinderConsoleToggleBatch") as MultiMeshInstance3D if cockpit != null else null
	var authored_names := PackedStringArray()
	var authored_transforms: Array = []
	if batch != null:
		authored_names = batch.get_meta(&"authored_visual_names", PackedStringArray())
		authored_transforms = batch.get_meta(&"authored_instance_transforms", [])
	var expected_transforms: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for toggle_index in 4:
			expected_transforms.append(Transform3D(
				Basis.from_euler(Vector3(0.0, 0.0, side * deg_to_rad(12.0))),
				Vector3(side * 0.82, 2.45, -0.72 + toggle_index * 0.2)
			))
	var transforms_match := authored_transforms.size() == expected_transforms.size()
	if transforms_match:
		for index in expected_transforms.size():
			if not (authored_transforms[index] as Transform3D).is_equal_approx(expected_transforms[index]):
				transforms_match = false
				break
	var material: StandardMaterial3D = null
	if batch != null and batch.multimesh != null and batch.multimesh.mesh != null:
		material = batch.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
	var toggle_mesh_bounds := AABB(Vector3(-0.025, -0.045, -0.025), Vector3(0.05, 0.09, 0.05))
	var expected_bounds := AABB()
	for index in expected_transforms.size():
		var transformed := (expected_transforms[index] * toggle_mesh_bounds).abs()
		expected_bounds = transformed if index == 0 else expected_bounds.merge(transformed)
	_check(
		batch != null
		and batch.multimesh != null
		and batch.multimesh.instance_count == Interceptor.CONSOLE_TOGGLE_VISIBLE_COPIES
		and batch.multimesh.visible_instance_count == Interceptor.CONSOLE_TOGGLE_VISIBLE_COPIES
		and batch.multimesh.mesh.get_surface_count() == Interceptor.CONSOLE_TOGGLE_BATCH_SUBMISSIONS
		and Interceptor.CONSOLE_TOGGLE_LEGACY_SUBMISSIONS == 8,
		"eight cockpit-toggle copies reduce their exact 8 -> 1 structural submissions through one bounded batch"
	)
	_check(
		authored_names == PackedStringArray(Interceptor.CONSOLE_TOGGLE_NAMES)
		and transforms_match
		and bool(batch.get_meta(&"visual_detail_only", false))
		and cockpit.find_children("*ConsoleToggle*", "MeshInstance3D", false, false).is_empty(),
		"the visual-only batch retains all eight authored toggle identities and exact local transforms"
	)
	_check(
		material != null
		and material.albedo_color.is_equal_approx(Color("b9c4c1"))
		and is_equal_approx(material.metallic, 0.76)
		and is_equal_approx(material.roughness, 0.2)
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and is_equal_approx(batch.extra_cull_margin, 0.0)
		and batch.multimesh.custom_aabb.is_equal_approx(expected_bounds),
		"toggle material, shadow, layers, and exact aggregate culling bounds are unchanged"
	)


func _test_console_key_batch(craft: CinderLightInterceptor) -> void:
	var cockpit := craft.get_variant_visual_root().get_node_or_null("CockpitInterior") as Node3D
	var batch := cockpit.get_node_or_null("CinderConsoleKeyBatch") as MultiMeshInstance3D if cockpit != null else null
	var authored_names := PackedStringArray()
	var authored_transforms: Array = []
	if batch != null:
		authored_names = batch.get_meta(&"authored_visual_names", PackedStringArray())
		authored_transforms = batch.get_meta(&"authored_instance_transforms", [])
	var expected_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(-0.76, 2.41, -0.88)),
		Transform3D(Basis.IDENTITY, Vector3(-0.67, 2.41, -0.24)),
		Transform3D(Basis.IDENTITY, Vector3(0.76, 2.41, -0.88)),
		Transform3D(Basis.IDENTITY, Vector3(0.85, 2.41, -0.24)),
	]
	var transforms_match := authored_transforms.size() == expected_transforms.size()
	if transforms_match:
		for index in expected_transforms.size():
			if not (authored_transforms[index] as Transform3D).is_equal_approx(expected_transforms[index]):
				transforms_match = false
				break
	var material: StandardMaterial3D = null
	if batch != null and batch.multimesh != null and batch.multimesh.mesh != null:
		material = batch.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
	var key_mesh_bounds := AABB(Vector3(-0.06, -0.0175, -0.06), Vector3(0.12, 0.035, 0.12))
	var expected_bounds := AABB()
	for index in expected_transforms.size():
		var transformed := (expected_transforms[index] * key_mesh_bounds).abs()
		expected_bounds = transformed if index == 0 else expected_bounds.merge(transformed)
	_check(
		batch != null
		and batch.multimesh != null
		and batch.multimesh.instance_count == Interceptor.CONSOLE_KEY_VISIBLE_COPIES
		and batch.multimesh.visible_instance_count == Interceptor.CONSOLE_KEY_VISIBLE_COPIES
		and batch.multimesh.mesh.get_surface_count() == Interceptor.CONSOLE_KEY_BATCH_SUBMISSIONS
		and Interceptor.CONSOLE_KEY_LEGACY_SUBMISSIONS == 4,
		"four cyan console-key copies reduce their exact 4 -> 1 structural submissions through one bounded batch"
	)
	_check(
		authored_names == PackedStringArray(Interceptor.CONSOLE_KEY_NAMES)
		and transforms_match
		and bool(batch.get_meta(&"visual_detail_only", false))
		and cockpit.get_node_or_null("PortConsoleKey00") == null
		and cockpit.get_node_or_null("PortConsoleKey02") == null
		and cockpit.get_node_or_null("StarboardConsoleKey00") == null
		and cockpit.get_node_or_null("StarboardConsoleKey02") == null
		and cockpit.get_node_or_null("PortConsoleKey01") == null
		and cockpit.get_node_or_null("StarboardConsoleKey01") == null,
		"the visual-only batch retains four authored key identities/transforms while the gold centre-key batch owns its separate family"
	)
	_check(
		material != null
		and material.albedo_color.is_equal_approx(Color("0a1820"))
		and is_equal_approx(material.metallic, 0.08)
		and is_equal_approx(material.roughness, 0.34)
		and material.emission.is_equal_approx(Color("48dbe2"))
		and is_equal_approx(material.emission_energy_multiplier, 0.85)
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.visible
		and not batch.ignore_occlusion_culling
		and is_equal_approx(batch.lod_bias, 1.0)
		and is_equal_approx(batch.extra_cull_margin, 0.0)
		and batch.multimesh.custom_aabb.is_equal_approx(expected_bounds),
		"cyan key material, shadow, layers, and exact aggregate culling bounds are unchanged"
	)


func _test_console_center_key_batch(craft: CinderLightInterceptor) -> void:
	var cockpit := craft.get_variant_visual_root().get_node_or_null("CockpitInterior") as Node3D
	var batch := cockpit.get_node_or_null("CinderConsoleCenterKeyBatch") as MultiMeshInstance3D if cockpit != null else null
	var authored_names := PackedStringArray()
	var authored_transforms: Array = []
	if batch != null:
		authored_names = batch.get_meta(&"authored_visual_names", PackedStringArray())
		authored_transforms = batch.get_meta(&"authored_instance_transforms", [])
	var expected_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(-0.715, 2.41, -0.56)),
		Transform3D(Basis.IDENTITY, Vector3(0.805, 2.41, -0.56)),
	]
	var transforms_match := authored_transforms.size() == expected_transforms.size()
	if transforms_match:
		for index in expected_transforms.size():
			if not (authored_transforms[index] as Transform3D).is_equal_approx(expected_transforms[index]):
				transforms_match = false
				break
	var material: StandardMaterial3D = null
	if batch != null and batch.multimesh != null and batch.multimesh.mesh != null:
		material = batch.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
	var key_mesh_bounds := AABB(Vector3(-0.06, -0.0175, -0.06), Vector3(0.12, 0.035, 0.12))
	var expected_bounds := AABB()
	for index in expected_transforms.size():
		var transformed := (expected_transforms[index] * key_mesh_bounds).abs()
		expected_bounds = transformed if index == 0 else expected_bounds.merge(transformed)
	_check(
		batch != null
		and batch.multimesh != null
		and batch.multimesh.instance_count == Interceptor.CONSOLE_CENTER_KEY_VISIBLE_COPIES
		and batch.multimesh.visible_instance_count == Interceptor.CONSOLE_CENTER_KEY_VISIBLE_COPIES
		and batch.multimesh.mesh.get_surface_count() == Interceptor.CONSOLE_CENTER_KEY_BATCH_SUBMISSIONS
		and Interceptor.CONSOLE_CENTER_KEY_LEGACY_SUBMISSIONS == 2,
		"two gold centre-key copies reduce their exact 2 -> 1 structural submissions through one bounded batch"
	)
	_check(
		authored_names == PackedStringArray(Interceptor.CONSOLE_CENTER_KEY_NAMES)
		and transforms_match
		and bool(batch.get_meta(&"visual_detail_only", false))
		and cockpit.find_children("*ConsoleKey*", "MeshInstance3D", false, false).is_empty(),
		"the visual-only batch retains both gold key identities and exact local transforms without leaving duplicate renderers"
	)
	_check(
		material != null
		and material.albedo_color.is_equal_approx(Color("f0b94d").darkened(0.68))
		and is_equal_approx(material.metallic, 0.16)
		and is_equal_approx(material.roughness, 0.28)
		and material.emission_enabled
		and material.emission.is_equal_approx(Color("f0b94d"))
		and is_equal_approx(material.emission_energy_multiplier, 0.9)
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.visible
		and not batch.ignore_occlusion_culling
		and is_equal_approx(batch.lod_bias, 1.0)
		and is_equal_approx(batch.extra_cull_margin, 0.0)
		and batch.multimesh.custom_aabb.is_equal_approx(expected_bounds),
		"gold key material, renderer policy, and exact aggregate culling bounds are unchanged"
	)


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
	for node in [hub, annulus, bell, visual.get_node("PortChamberBack")]:
		_test_exhaust_surface(node.mesh, node.name)
	_test_exhaust_surface(port.multimesh.mesh, port.name)


func _test_exhaust_surface(mesh: ArrayMesh, label: String) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var valid_frames := uv.size() == points.size() and normals.size() == points.size() and tangents.size() == points.size() * 4
	if valid_frames:
		for index in points.size():
			var tangent := Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
			valid_frames = valid_frames and uv[index].is_finite() and tangent.is_finite() \
				and is_equal_approx(tangent.length(), 1.0) and absf(tangent.dot(normals[index])) < 0.001 \
				and is_equal_approx(absf(tangents[index * 4 + 3]), 1.0)
	_check(valid_frames, label + " has complete finite orthonormal UV/tangent frames")
	var valid_triangles := not indices.is_empty() and indices.size() % 3 == 0
	var valid_uv := uv.size() == points.size()
	for offset in range(0, indices.size(), 3):
		var a := indices[offset]
		var b := indices[offset + 1]
		var c := indices[offset + 2]
		valid_triangles = valid_triangles and (points[b] - points[a]).cross(points[c] - points[a]).length_squared() > 0.000000000001
		if valid_uv:
			valid_uv = absf((uv[b] - uv[a]).cross(uv[c] - uv[a])) > 0.00000001
	_check(valid_triangles and valid_uv, label + " has no collapsed geometric or UV triangles, including cap poles")


func _test_induction_cassettes(craft: Node3D) -> void:
	var valid := true
	for tag in ["InductionDuct", "InductionMouth/Intake"]:
		var port: MeshInstance3D
		var starboard: MeshInstance3D
		if tag.contains("/"):
			port = craft.find_child("PortInductionMouth", true, false).get_node("IntakeFrame")
			starboard = craft.find_child("StarboardInductionMouth", true, false).get_node("IntakeFrame")
		else:
			port = craft.find_child("PortInductionDuctFrame", true, false)
			starboard = craft.find_child("StarboardInductionDuctFrame", true, false)
		valid = valid and port != null and starboard != null and port.mesh == starboard.mesh and port.mesh.surface_get_material(0) == null
		if port != null:
			var prefix := String(port.name).trim_suffix("Frame")
			var vanes := port.get_parent().get_node(prefix + "Vanes") as MeshInstance3D
			var back := port.get_parent().get_node(prefix + "Recess") as MeshInstance3D
			valid = valid and vanes != null and back != null and vanes.position == port.position and back.position.is_equal_approx(port.position + Vector3(0, 0.025, 0))
	_check(valid, "paired roof and forward induction cassettes share their fitted material-free stocks and recessed backing")
	_check(craft.find_children("*Louver*", "MeshInstance3D", true, false).is_empty(), "formed induction assemblies replace all twenty isolated louver bars")


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


func _test_formed_cockpit_walls(craft: HeroShip) -> void:
	var visual := craft.get_variant_visual_root()
	var cockpit := visual.get_node("CockpitInterior")
	var fairing := visual.get_node("ClosedCockpitFairing") as MeshInstance3D
	var names := ["PortSidewall", "StarboardSidewall", "ForwardPressureWall", "RearPressureWall"]
	var contact_points := [Vector3(-1.54, 0, -0.555), Vector3(1.54, 0, -0.555), Vector3(0, 0, -2.45), Vector3(0, 0, 1.32)]
	var triangles := 0
	for index in names.size():
		var wall := cockpit.get_node(names[index]) as MeshInstance3D
		_check(wall.mesh is ArrayMesh and wall.mesh.get_surface_count() == 1 and wall.mesh.surface_get_material(0) == null,
			"formed cockpit armor keeps one surface per existing owner and no material in shared geometry")
		_check(wall.material_override == fairing.material_override and wall.get_child_count() == 0,
			"formed cockpit armor uses the owning craft finish with no additional scene or collision nodes")
		var faces := wall.mesh.get_faces()
		triangles += faces.size() / 3
		var levels: Dictionary = {}
		var contact := Vector3.INF
		for vertex in faces:
			var at := wall.transform * vertex
			levels[snappedf(at.y, 0.001)] = true
			if absf(at.x - contact_points[index].x) < 0.001 and absf(at.z - contact_points[index].z) < 0.001:
				if at.y < contact.y: contact = at
		_check(levels.size() >= 9, "armor has a substantial rolled profile below the retained seal land")
		var height := -INF
		var skin_faces := fairing.mesh.get_faces()
		for triangle in range(0, skin_faces.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(Vector3(contact.x, 8, contact.z), Vector3.DOWN,
				fairing.transform * skin_faces[triangle], fairing.transform * skin_faces[triangle + 1], fairing.transform * skin_faces[triangle + 2])
			if hit != null: height = maxf(height, hit.y)
		_check(is_finite(height) and height - contact.y > 0.025 and height - contact.y < 0.045,
			"the emitted armor toe seats inside actual fairing triangles, including the widest cheek and fore/aft center")
	_check(triangles <= 600, "four formed wall owners stay within 600 triangles and four submissions")


func _test_armor_instance_finish(craft: HeroShip) -> void:
	var second := Interceptor.new()
	root.add_child(second)
	await process_frame
	var first_wall := craft.get_variant_visual_root().get_node("CockpitInterior/PortSidewall") as MeshInstance3D
	var second_cockpit := second.get_variant_visual_root().get_node("CockpitInterior") as Node3D
	var original_finish := first_wall.material_override
	var alternate_finish := StandardMaterial3D.new()
	alternate_finish.albedo_color = Color.RED
	# Exercise the populated geometry cache with a different owner's finish.
	preload("res://scripts/ships/cinder_cockpit_armor_shell.gd").install(second_cockpit, alternate_finish, &"light_interceptor", 1.54, [])
	var second_wall := second_cockpit.get_node("PortSidewall") as MeshInstance3D
	_check(first_wall.mesh == second_wall.mesh and first_wall.material_override == original_finish
		and second_wall.material_override == alternate_finish and second_wall.mesh.surface_get_material(0) == null,
		"two live craft share armor geometry while retaining independent finish ownership")
	second.queue_free()
	await process_frame


## Phase 6 fleet damage/repair/recovery coverage for the shared presentation.
##
## This craft is composed from script by its production binding rather than
## instanced from a `scenes/ships/*.tscn`, so it used to raise none of the shared
## channels a player sees on every authored craft. It now attaches the same
## `scenes/effects/hero_damage_presentation.tscn`, and this drives the whole
## lifecycle through it: staged hull sparks, engine smoke and engine-failure
## sparks on this hull's own anchors, the damage and engine-failure practicals,
## the localized rig the shared `component_damage_*` seam routes, the degraded
## engine exhaust grade, the reduced-flash impact clamp, a destruction burst
## detached out of the craft, and a regeneration that clears every one of them.
func _test_shared_damage_presentation(craft: CinderLightInterceptor) -> void:
	var presentation := craft.get_damage_presentation()
	_check(
		presentation != null,
		"the interceptor carries the fleet's shared damage presentation"
	)
	if presentation == null:
		return
	var sparks := presentation.get_node_or_null(^"DamageSparks") as CPUParticles3D
	var engine_sparks := presentation.get_node_or_null(^"EngineFailureSparks") as CPUParticles3D
	var smoke := presentation.get_node_or_null(^"EngineSmoke") as CPUParticles3D
	var warning := presentation.get_node_or_null(^"DamageWarningLight") as OmniLight3D
	var engine_light := presentation.get_node_or_null(^"EngineFailureLight") as OmniLight3D
	_check(
		presentation.get_script() == load("res://scripts/effects/hero_damage_presentation.gd")
		and presentation.spark_anchor.is_equal_approx(CinderLightInterceptor.DAMAGE_SPARK_ANCHOR)
		and presentation.smoke_anchor.is_equal_approx(CinderLightInterceptor.DAMAGE_SMOKE_ANCHOR)
		and presentation.warning_anchor.is_equal_approx(CinderLightInterceptor.DAMAGE_WARNING_ANCHOR)
		and presentation.destruction_debris_count == CinderLightInterceptor.DAMAGE_DEBRIS_COUNT
		and sparks != null and engine_sparks != null and smoke != null
		and warning != null and engine_light != null
		and sparks.position.is_equal_approx(CinderLightInterceptor.DAMAGE_SPARK_ANCHOR)
		and smoke.position.is_equal_approx(CinderLightInterceptor.DAMAGE_SMOKE_ANCHOR)
		and engine_sparks.position.is_equal_approx(CinderLightInterceptor.DAMAGE_SMOKE_ANCHOR)
		and warning.position.is_equal_approx(CinderLightInterceptor.DAMAGE_WARNING_ANCHOR)
		and engine_light.position.is_equal_approx(CinderLightInterceptor.DAMAGE_SMOKE_ANCHOR),
		"the shared rig anchors its spark, smoke, warning and engine channels on this hull's own geometry"
	)
	_check(
		not sparks.emitting and not smoke.emitting and not engine_sparks.emitting
		and is_zero_approx(warning.light_energy)
		and is_zero_approx(engine_light.light_energy)
		and not warning.shadow_enabled and not engine_light.shadow_enabled
		and presentation.get_live_world_effect_count() == 0
		and presentation.get_status() == &"healthy",
		"an undamaged craft draws none of those channels and casts no extra shadow"
	)

	craft.set_physics_process(false)
	craft.set("_landed", false)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
	craft.call("_sync_damage_presentation")

	# Damaged: hull sparks and the amber damage practical, plus one world impact.
	craft.apply_damage(
		craft.maximum_hull * 0.45,
		craft.to_global(CinderLightInterceptor.DAMAGE_SPARK_ANCHOR),
		Vector3.UP
	)
	await process_frame
	await process_frame
	_check(
		presentation.get_status() == &"damaged"
		and sparks.emitting and sparks.visible
		and presentation.is_alarm_active()
		and warning.light_energy > 0.0
		and presentation.get_live_world_effect_count() == 1
		and not smoke.emitting,
		"damage raises the hull sparks and the damage warning light with one impact burst"
	)

	# Critical: engine smoke, engine-failure sparks and the cyan failure practical.
	craft.apply_damage(
		craft.maximum_hull * 0.35,
		craft.to_global(CinderLightInterceptor.DAMAGE_SMOKE_ANCHOR),
		Vector3.UP
	)
	await process_frame
	await process_frame
	_check(
		presentation.get_status() == &"critical"
		and smoke.emitting and smoke.visible
		and engine_sparks.emitting and engine_sparks.visible
		and presentation.is_engine_failure_active()
		and engine_light.light_energy > 0.0
		and presentation.get_engine_power_multiplier() < 1.0,
		"critical damage raises engine smoke, engine-failure sparks and the degraded engine cue"
	)

	# The already-authoritative component roster drives the localized rig and the
	# static exhaust grade; neither is decided here.
	var model := craft.get_component_damage()
	var engine_anchor := _component_local_position(
		craft, ShipComponentDamage.COMPONENT_ENGINE_BAY
	)
	var guard := 0
	while model.get_component_state(ShipComponentDamage.COMPONENT_ENGINE_BAY) \
			< ShipComponentDamage.ComponentState.FAILED and guard < 4:
		model.record_damage(craft.maximum_hull * 2.0, engine_anchor)
		guard += 1
	craft.call("_sync_component_damage", 0.01)
	craft.call("_sync_engine_visuals_immediately")
	await process_frame
	var rig := presentation.get_node_or_null(
		"ComponentDamage_%s" % String(ShipComponentDamage.COMPONENT_ENGINE_BAY)
	) as Node3D
	var exhaust := craft.get_engine_exhaust_damage_presentation_profile()
	var visible_plumes := 0
	for plume_value in craft.get("_engine_glows") as Array:
		if is_instance_valid(plume_value) and (plume_value as MeshInstance3D).visible:
			visible_plumes += 1
	_check(
		rig != null
		and rig.position.is_equal_approx(engine_anchor)
		and presentation.get_failed_component_effect_ids().has(
			ShipComponentDamage.COMPONENT_ENGINE_BAY
		)
		and exhaust.get("stage") == &"failed"
		and visible_plumes == 0
		and not bool(exhaust.get("flashing", true))
		and not bool(exhaust.get("gameplay_authority", true)),
		"a failed engine bay shows the shared localized rig and puts out this craft's real plumes"
	)

	# Reduced flash: whatever intensity the caller resolved, the impact practical
	# is clamped to 1.6x peak and from there only decays, and the core only ever
	# expands and fades inside its authored band. There is no pulse in it.
	var world_effects_before: Dictionary = {}
	for existing in root.get_children():
		world_effects_before[existing.get_instance_id()] = true
	presentation.present_impact(craft.global_position, Vector3.UP, 4.0)
	var impact := _impact_effect_added_since(world_effects_before)
	var impact_flash := impact.get_node_or_null(^"ImpactFlash") as MeshInstance3D \
		if impact != null else null
	var impact_light := impact.get_node_or_null(^"ImpactLight") as OmniLight3D \
		if impact != null else null
	var peak_energy := impact_light.light_energy if impact_light != null else -1.0
	var previous_energy := peak_energy
	var previous_transparency := impact_flash.transparency if impact_flash != null else 0.0
	var decays_without_pulsing := impact_light != null and impact_flash != null
	for _flash_step in 8:
		await process_frame
		if not is_instance_valid(impact_light) or not is_instance_valid(impact_flash):
			break
		if impact_light.light_energy > previous_energy + 0.0001 \
				or impact_flash.transparency < previous_transparency - 0.0001 \
				or impact_flash.scale.x > HeroDamagePresentation.IMPACT_FLASH_MAXIMUM_SCALE * 1.22 + 0.0001 \
				or impact_light.omni_range > HeroDamagePresentation.IMPACT_LIGHT_MAXIMUM_RANGE + 0.0001:
			decays_without_pulsing = false
		previous_energy = impact_light.light_energy
		previous_transparency = impact_flash.transparency
	_check(
		impact_flash != null and impact_light != null
		and is_equal_approx(peak_energy, 5.2 * 1.6)
		and decays_without_pulsing
		and previous_energy < peak_energy
		and not impact_light.shadow_enabled
		and impact_flash.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"the shared impact practical stays inside the reduced-flash clamp and only decays at any intensity"
	)

	# Destruction: the burst and its debris detach out of the craft so a hidden or
	# recycled hull cannot drag them along.
	craft.apply_damage(craft.maximum_hull * 2.0, craft.global_position, Vector3.UP)
	await process_frame
	await process_frame
	var destruction := presentation.get_destruction_effect_root()
	var debris := 0
	if destruction != null:
		for child in destruction.get_children():
			if str(child.name).begins_with("HeroHullDebris"):
				debris += 1
	_check(
		craft.is_destroyed()
		and destruction != null
		and not craft.is_ancestor_of(destruction)
		and debris == CinderLightInterceptor.DAMAGE_DEBRIS_COUNT
		and presentation.get_status() == &"destroyed",
		"destruction detaches the shared burst out of the craft with its full debris count"
	)

	# Regeneration: the berth's reuse path clears every channel it raised.
	var reset := craft.reset_for_reuse(craft.global_transform)
	await process_frame
	await process_frame
	_check(
		bool(reset.get("accepted", false))
		and presentation.get_status() == &"healthy"
		and not sparks.emitting and not smoke.emitting and not engine_sparks.emitting
		and is_zero_approx(warning.light_energy)
		and is_zero_approx(engine_light.light_energy)
		and presentation.get_destruction_effect_root() == null
		and presentation.get_live_world_effect_count() == 0
		and presentation.get_active_component_effect_count() == 0
		and presentation.get_node_or_null(
			"ComponentDamage_%s" % String(ShipComponentDamage.COMPONENT_ENGINE_BAY)
		) == null,
		"regeneration clears every damage, component, and destruction channel it raised"
	)


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


## The shared presentation detaches its impacts into the scene-tree root by
## design, and a colliding sibling there is renamed by the engine, so the burst
## one call raised is found as the root child that was not there before it.
func _impact_effect_added_since(before: Dictionary) -> Node3D:
	for candidate in root.get_children():
		if before.has(candidate.get_instance_id()):
			continue
		if candidate is Node3D and candidate.get_node_or_null(^"ImpactLight") != null:
			return candidate as Node3D
	return null
