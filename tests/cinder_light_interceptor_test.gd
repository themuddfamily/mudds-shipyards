extends SceneTree

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var craft := Interceptor.new()
	root.add_child(craft)
	await process_frame
	_test_recessed_exhaust(craft)
	var audit := craft.get_audit_report()
	_check(bool(audit.get("valid", false)), "the interceptor builds a valid collision and lifecycle contract")
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the interceptor makes no historical claim")
	_check(craft.get_cockpit_seat_anchor() != null and craft.get_boarding_marker() != null, "the interceptor exposes physical cockpit and boarding anchors")
	_check(bool(craft is HeroShip) and bool(audit.get("flight_authority", false)) and not bool(audit.get("combat_authority", true)) and not bool(audit.get("weapon_authority", true)), "HeroShip owns flight while the component adds no duplicate combat or weapon authority")
	_test_closed_cockpit_fairing(craft)
	_test_console_toggle_batch(craft)
	_test_console_key_batch(craft)
	_test_console_center_key_batch(craft)
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
		and fairing.mesh.get_aabb().size.is_equal_approx(Vector3(3.55, 1.542, 6.8))
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
