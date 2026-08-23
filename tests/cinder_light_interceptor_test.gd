extends SceneTree

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var craft := Interceptor.new()
	root.add_child(craft)
	await process_frame
	var audit := craft.get_audit_report()
	_check(bool(audit.get("valid", false)), "the interceptor builds a valid collision and lifecycle contract")
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the interceptor makes no historical claim")
	_check(craft.get_cockpit_seat_anchor() != null and craft.get_boarding_marker() != null, "the interceptor exposes physical cockpit and boarding anchors")
	_check(bool(craft is HeroShip) and bool(audit.get("flight_authority", false)) and not bool(audit.get("combat_authority", true)) and not bool(audit.get("weapon_authority", true)), "HeroShip owns flight while the component adds no duplicate combat or weapon authority")
	_test_console_toggle_batch(craft)
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
