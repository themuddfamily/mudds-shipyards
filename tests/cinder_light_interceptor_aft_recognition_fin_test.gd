extends SceneTree

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var first := Interceptor.new()
	var second := Interceptor.new()
	root.add_child(first)
	root.add_child(second)
	await process_frame

	var first_fin := _fin(first)
	var second_fin := _fin(second)
	_check(
		first_fin != null and second_fin != null,
		"both production interceptor copies retain the aft recognition fin"
	)
	if first_fin != null and second_fin != null:
		var mesh := first_fin.mesh as PrismMesh
		var material := first_fin.material_override as StandardMaterial3D
		_check(
			mesh != null
				and mesh == second_fin.mesh
				and material != null
				and material == second_fin.material_override
				and not mesh.resource_local_to_scene
				and not material.resource_local_to_scene,
			"the fin shares one immutable prism and the existing wing finish across copies"
		)
		_check(
			mesh != null
				and mesh.size.is_equal_approx(Interceptor.AFT_RECOGNITION_FIN_SIZE)
				and mesh.get_surface_count() == 1
				and first_fin.position.is_equal_approx(Interceptor.AFT_RECOGNITION_FIN_POSITION)
				and is_equal_approx(first_fin.rotation.y, Interceptor.AFT_RECOGNITION_FIN_ROTATION_Y)
				and first_fin.transform.is_equal_approx(second_fin.transform)
				and bool(first_fin.get_meta(&"visual_detail_only", false))
				and first_fin.visible
				and first_fin.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				and first_fin.layers == 1
				and first_fin.get_child_count() == 0
				and first_fin.get_script() == null,
			"the swept aft silhouette and presentation-only renderer state remain exact"
		)
		_check(
			material.albedo_color.is_equal_approx(Interceptor.WING_COLOR)
				and is_equal_approx(material.metallic, 0.5)
				and is_equal_approx(material.roughness, 0.36),
			"the recognition fin remains visually tied to the rapid-response wing family"
		)

	_check(
		bool(first.get_audit_report().get("valid", false))
			and bool(second.get_audit_report().get("valid", false))
			and bool(first.get_landing_collision_report().get("valid", false))
			and bool(second.get_landing_collision_report().get("valid", false))
			and first.get_cockpit_seat_anchor() != null
			and second.get_cockpit_seat_anchor() != null
			and first.get_boarding_marker() != null
			and second.get_boarding_marker() != null
			and first.get_weapon_definition().weapon_id == Interceptor.WEAPON_ID
			and second.get_weapon_definition().weapon_id == Interceptor.WEAPON_ID
			and not bool(first.get_audit_report().get("berth_authority", true))
			and not bool(first.get_audit_report().get("network_authority", true)),
		"visual polish leaves collision, cockpit, boarding, weapon, berth, and network contracts intact"
	)

	first.queue_free()
	second.queue_free()
	await process_frame
	_check(
		not is_instance_valid(first) and not is_instance_valid(second),
		"both craft cleanly leave the lifecycle while immutable fin stock remains process-owned"
	)

	if _failures.is_empty():
		print("PASS cinder_light_interceptor_aft_recognition_fin_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _fin(craft: CinderLightInterceptor) -> MeshInstance3D:
	var visual := craft.get_variant_visual_root()
	return visual.get_node_or_null(^"AftRecognitionFin") as MeshInstance3D if visual != null else null


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
