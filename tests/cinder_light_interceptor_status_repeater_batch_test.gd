extends SceneTree

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var craft := Interceptor.new()
	root.add_child(craft)
	await process_frame

	var visual := craft.get_variant_visual_root()
	var cluster := visual.get_node_or_null(
		^"CockpitInterior/InstrumentCluster"
	) as Node3D if visual != null else null
	var batch := cluster.get_node_or_null(
		^"CinderStatusRepeaterBatch"
	) as MultiMeshInstance3D if cluster != null else null
	_check(
		batch != null
			and batch.multimesh != null
			and batch.multimesh.instance_count == Interceptor.STATUS_REPEATER_VISIBLE_COPIES
			and batch.multimesh.visible_instance_count == Interceptor.STATUS_REPEATER_VISIBLE_COPIES
			and batch.multimesh.mesh.get_surface_count() == Interceptor.STATUS_REPEATER_BATCH_SUBMISSIONS
			and Interceptor.STATUS_REPEATER_LEGACY_SUBMISSIONS == 2,
		"two cockpit status repeaters reduce their exact 2 -> 1 structural submissions"
	)

	if batch != null and batch.multimesh != null:
		var expected_transforms := _expected_transforms()
		var transforms: Array = batch.get_meta(&"authored_instance_transforms", [])
		var expected_bounds := _bounds(batch.multimesh.mesh.get_aabb(), expected_transforms)
		_check(
			PackedStringArray(batch.get_meta(&"authored_visual_names", PackedStringArray()))
				== PackedStringArray(Interceptor.STATUS_REPEATER_NAMES)
				and _transforms_match(transforms, expected_transforms)
				and batch.multimesh.custom_aabb.is_equal_approx(expected_bounds)
				and cluster.get_node_or_null(^"PortStatusRepeater") == null
				and cluster.get_node_or_null(^"StarboardStatusRepeater") == null,
			"the batch retains both authored identities, exact transforms, and aggregate culling bounds"
		)
		var material := batch.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
		_check(
			material != null
				and material.albedo_color.is_equal_approx(Color("16383e"))
				and material.emission_enabled
				and material.emission.is_equal_approx(Color("48dbe2"))
				and is_equal_approx(material.emission_energy_multiplier, 2.8)
				and batch.visible
				and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				and batch.layers == 1
				and not batch.ignore_occlusion_culling
				and is_equal_approx(batch.lod_bias, 1.0)
				and is_equal_approx(batch.extra_cull_margin, 0.0),
			"the cyan display finish, visibility, shadow, layer, LOD, and occlusion policy are unchanged"
		)
		_check(
			batch.get_child_count() == 0
				and batch.get_script() == null
				and bool(batch.get_meta(&"visual_detail_only", false))
				and bool(batch.get_meta(&"presentation_only", false))
				and not bool(batch.get_meta(&"gameplay_authority", true)),
			"the replacement remains childless presentation-only geometry with no gameplay authority"
		)

	var audit := craft.get_audit_report()
	var collision := craft.get_landing_collision_report()
	_check(
		bool(audit.get("valid", false))
			and bool(collision.get("valid", false))
			and int(collision.get("shape_count", 0)) == 1
			and craft.get_boarding_marker() != null
			and craft.get_cockpit_seat_anchor() != null
			and craft.get_weapon_definition().weapon_id == Interceptor.WEAPON_ID
			and not bool(audit.get("berth_authority", true))
			and not bool(audit.get("combat_authority", true))
			and not bool(audit.get("network_authority", true)),
		"batching leaves collision, boarding, cockpit, weapon, berth, combat, and network contracts intact"
	)

	craft.queue_free()
	await process_frame
	_check(not is_instance_valid(craft), "the craft and its presentation batch leave the lifecycle cleanly")

	if _failures.is_empty():
		print("CINDER_INTERCEPTOR_STATUS_REPEATERS: renderers 2->1 submissions 2->1 instances 2->2 unique_meshes 2->1 lights +0 collision +0")
		print("PASS cinder_light_interceptor_status_repeater_batch_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _transforms_match(actual: Array, expected: Array[Transform3D]) -> bool:
	if actual.size() != expected.size():
		return false
	for index in expected.size():
		if not (actual[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return true


func _expected_transforms() -> Array[Transform3D]:
	return [
		Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0)),
			Vector3(-0.57, 0.08, 0.11)
		),
		Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0)),
			Vector3(0.57, 0.08, 0.11)
		),
	]


func _bounds(mesh_bounds: AABB, transforms: Array[Transform3D]) -> AABB:
	var result := AABB()
	for index in transforms.size():
		var transformed := (transforms[index] * mesh_bounds).abs()
		result = transformed if index == 0 else result.merge(transformed)
	return result


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
