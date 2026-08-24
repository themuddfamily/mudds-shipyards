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

	var first_hull := _hull(first)
	var second_hull := _hull(second)
	var first_hash := _presentation_hash(first_hull)
	var second_hash := _presentation_hash(second_hull)
	print("CINDER_INTERCEPTOR_HULL_PRESENTATION_HASH: %s %s" % [first_hash, second_hash])
	_check(first_hull != null and second_hull != null, "both production interceptor copies retain their high-visibility hull renderer")
	_check(
		first_hull.mesh == second_hull.mesh
			and first_hull.material_override == second_hull.material_override,
		"two interceptor copies share one immutable hull mesh and material identity"
	)
	_check(
		first_hash == second_hash and not first_hash.is_empty(),
		"resource sharing preserves the exact hull presentation recipe hash"
	)
	_check(
		first_hull.mesh is BoxMesh
			and (first_hull.mesh as BoxMesh).size.is_equal_approx(Interceptor.HULL_SIZE)
			and first_hull.mesh.get_surface_count() == 1
			and first_hull.transform.is_equal_approx(Transform3D.IDENTITY)
			and first_hull.visible
			and first_hull.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and first_hull.get_child_count() == 0
			and first_hull.get_script() == null,
		"hull silhouette, transform, renderer state, and presentation-only ownership remain exact"
	)
	var material := first_hull.material_override as StandardMaterial3D
	_check(
		material != null
			and material.albedo_color.is_equal_approx(Interceptor.HULL_COLOR)
			and is_equal_approx(material.metallic, 0.62)
			and is_equal_approx(material.roughness, 0.36)
			and not first_hull.mesh.resource_local_to_scene
			and not material.resource_local_to_scene,
		"the cached mesh/material retain the authored hull recipe and cross-copy lifetime"
	)
	_check(
		bool(first.get_landing_collision_report().get("valid", false))
			and bool(second.get_landing_collision_report().get("valid", false))
			and first.get_boarding_marker() != null
			and second.get_boarding_marker() != null
			and first.get_weapon_definition().weapon_id == Interceptor.WEAPON_ID
			and second.get_weapon_definition().weapon_id == Interceptor.WEAPON_ID,
		"sharing leaves collision, boarding, and weapon definition contracts intact"
	)
	var first_audit := first.get_audit_report()
	var second_audit := second.get_audit_report()
	_check(
		bool(first_audit.get("valid", false))
			and bool(second_audit.get("valid", false))
			and first_audit.get("evidence_status", &"") == &"NEW"
			and second_audit.get("evidence_status", &"") == &"NEW"
			and not bool(first_audit.get("network_authority", true))
			and not bool(second_audit.get("combat_authority", true)),
		"sharing preserves lifecycle evidence tags and adds no network or combat authority"
	)

	first.queue_free()
	second.queue_free()
	await process_frame
	_check(not is_instance_valid(first) and not is_instance_valid(second), "both copies cleanly leave the lifecycle while immutable resources remain process-owned")

	if _failures.is_empty():
		print("CINDER_INTERCEPTOR_HULL_RESOURCE_SHARING: meshes 2->1 materials 2->1 nodes 2->2 submissions 2->2")
		print("PASS cinder_light_interceptor_hull_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _hull(craft: CinderLightInterceptor) -> MeshInstance3D:
	var visual := craft.get_variant_visual_root()
	return visual.get_node_or_null(^"HighVisibilityHull") as MeshInstance3D if visual != null else null


func _presentation_hash(hull: MeshInstance3D) -> String:
	if hull == null or hull.mesh == null:
		return ""
	var material := hull.material_override as StandardMaterial3D
	if material == null:
		return ""
	var recipe := PackedStringArray([
		str(hull.transform),
		str(hull.mesh.get_aabb()),
		str(hull.mesh.get_surface_count()),
		str(material.albedo_color),
		str(material.metallic),
		str(material.roughness),
		str(hull.visible),
		str(hull.cast_shadow),
		str(hull.layers),
	])
	return "|".join(recipe).sha256_text()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
