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

	var first_canopy := _canopy(first)
	var second_canopy := _canopy(second)
	_check(
		first_canopy != null and second_canopy != null,
		"both production interceptor copies retain their canopy renderer"
	)
	if first_canopy != null and second_canopy != null:
		_check(
			first_canopy.mesh == second_canopy.mesh
				and first_canopy.material_override == second_canopy.material_override,
			"two interceptor copies share one immutable canopy mesh and material identity"
		)
		var mesh := first_canopy.mesh as SphereMesh
		_check(
			mesh != null
				and is_equal_approx(mesh.radius, Interceptor.CANOPY_RADIUS)
				and is_equal_approx(mesh.height, Interceptor.CANOPY_HEIGHT)
				and mesh.get_surface_count() == 1
				and first_canopy.position.is_equal_approx(Interceptor.CANOPY_POSITION)
				and second_canopy.position.is_equal_approx(Interceptor.CANOPY_POSITION)
				and first_canopy.visible
				and first_canopy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				and first_canopy.layers == 1
				and first_canopy.get_child_count() == 0
				and first_canopy.get_script() == null,
			"sharing preserves the exact canopy silhouette, placement, renderer state, and visual-only ownership"
		)
		var material := first_canopy.material_override as StandardMaterial3D
		_check(
			material != null
				and material.albedo_color.is_equal_approx(Interceptor.CANOPY_COLOR)
				and is_equal_approx(material.metallic, 0.15)
				and is_equal_approx(material.roughness, 0.36)
				and material.emission_enabled
				and material.emission.is_equal_approx(Interceptor.CANOPY_COLOR)
				and is_equal_approx(material.emission_energy_multiplier, 2.0)
				and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
				and material.diffuse_mode == BaseMaterial3D.DIFFUSE_BURLEY
				and material.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX
				and not mesh.resource_local_to_scene
				and not material.resource_local_to_scene,
			"the shared resources retain the authored emissive finish and renderer policy"
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
			and second.get_weapon_definition().weapon_id == Interceptor.WEAPON_ID,
		"resource sharing leaves component, collision, cockpit, boarding, and weapon contracts intact"
	)

	first.queue_free()
	second.queue_free()
	await process_frame
	_check(
		not is_instance_valid(first) and not is_instance_valid(second),
		"both craft cleanly leave the lifecycle while immutable canopy stock remains process-owned"
	)

	if _failures.is_empty():
		print("CINDER_INTERCEPTOR_CANOPY_RESOURCE_SHARING: meshes 2->1 materials 2->1 nodes 2->2 submissions 2->2")
		print("PASS cinder_light_interceptor_canopy_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _canopy(craft: CinderLightInterceptor) -> MeshInstance3D:
	var visual := craft.get_variant_visual_root()
	return visual.get_node_or_null(^"Canopy") as MeshInstance3D if visual != null else null


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
