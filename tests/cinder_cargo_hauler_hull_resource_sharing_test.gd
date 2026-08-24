extends SceneTree

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var first := Hauler.new()
	var second := Hauler.new()
	root.add_child(first)
	root.add_child(second)
	await process_frame

	var first_hull := _hull(first)
	var second_hull := _hull(second)
	_check(
		first_hull != null and second_hull != null
			and first_hull != second_hull
			and first_hull.mesh == second_hull.mesh
			and first_hull.material_override == second_hull.material_override,
		"two production haulers retain separate hull renderers backed by one immutable recipe"
	)
	var material := first_hull.material_override as StandardMaterial3D \
		if first_hull != null else null
	_check(
		first_hull != null
			and first_hull.mesh is BoxMesh
			and (first_hull.mesh as BoxMesh).size.is_equal_approx(Hauler.HULL_SIZE)
			and first_hull.transform.is_equal_approx(Transform3D.IDENTITY)
			and first_hull.visible
			and first_hull.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and first_hull.layers == 1
			and first_hull.get_child_count() == 0
			and first_hull.get_script() == null
			and not first_hull.mesh.resource_local_to_scene
			and material != null
			and material.albedo_color.is_equal_approx(Hauler.HULL_COLOR)
			and is_equal_approx(material.metallic, 0.72)
			and is_equal_approx(material.roughness, 0.42)
			and not material.resource_local_to_scene,
		"sharing preserves the IndustrialHull silhouette, transform, material and renderer policy"
	)
	_check(
		_hull(second).mesh.get_surface_count() == 1
			and _hull(first).mesh.get_aabb().is_equal_approx(_hull(second).mesh.get_aabb()),
		"both visible hull copies retain the exact one-surface geometry"
	)
	_check(
		first.get_cockpit_seat_anchor() != null
			and second.get_cockpit_seat_anchor() != null
			and first.get_boarding_marker() != null
			and second.get_boarding_marker() != null
			and first.get_cargo_transfer_anchors().size() == Hauler.CARGO_CAPACITY
			and second.get_cargo_transfer_anchors().size() == Hauler.CARGO_CAPACITY
			and first.get_cargo_hold_root() != null
			and second.get_cargo_hold_root() != null,
		"cockpit, boarding and the cargo-access anchor bridge remain per craft"
	)
	var first_audit := first.get_audit_report()
	var second_audit := second.get_audit_report()
	_check(
		bool(first_audit.get("valid", false))
			and bool(second_audit.get("valid", false))
			and bool(first.get_landing_collision_report().get("valid", false))
			and bool(second.get_landing_collision_report().get("valid", false))
			and not bool(first_audit.get("cargo_transfer_authority", true))
			and not bool(second_audit.get("cargo_transfer_authority", true))
			and not bool(first_audit.get("network_authority", true))
			and not bool(second_audit.get("network_authority", true))
			and first.get_crew_role_authority() == null
			and second.get_crew_role_authority() == null,
		"sharing leaves collision, component lifecycle and gameplay authority unchanged"
	)

	first.queue_free()
	second.queue_free()
	await process_frame
	_check(
		not is_instance_valid(first) and not is_instance_valid(second),
		"both craft detach cleanly while immutable presentation resources remain process-owned"
	)

	if _failures.is_empty():
		print("CINDER_CARGO_HULL_RESOURCE_SHARING: meshes 2->1 materials 2->1 nodes 2->2 submissions 2->2")
		print("PASS cinder_cargo_hauler_hull_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _hull(craft: CinderCargoHauler) -> MeshInstance3D:
	var visual := craft.get_variant_visual_root()
	return visual.get_node_or_null(^"IndustrialHull") as MeshInstance3D \
		if visual != null else null


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
