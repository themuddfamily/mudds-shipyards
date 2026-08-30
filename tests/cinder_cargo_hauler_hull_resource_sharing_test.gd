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
			and first_hull.mesh is ArrayMesh
			and first_hull.mesh.get_aabb().is_equal_approx(AABB(-Hauler.HULL_SIZE * 0.5, Hauler.HULL_SIZE))
			and _port_aperture_is_open(first_hull, Hauler.HULL_SIZE)
			and bool(first_hull.mesh.get_meta(&"closed_aperture_reveals", false))
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
		"sharing preserves the IndustrialHull outer silhouette, opens the bounded port route, and retains its material and renderer policy"
	)
	_check(
		_hull(second).mesh.get_surface_count() == 1
			and _hull(first).mesh.get_aabb().is_equal_approx(_hull(second).mesh.get_aabb()),
		"both visible hull copies retain the exact one-surface geometry"
	)
	var first_pod := _cargo_pod(first)
	var second_pod := _cargo_pod(second)
	var pod_material := first_pod.material_override as StandardMaterial3D \
		if first_pod != null else null
	_check(
		first_pod != null and second_pod != null
			and first_pod != second_pod
			and first_pod.mesh == second_pod.mesh
			and first_pod.material_override == second_pod.material_override
			and first_pod.mesh is ArrayMesh
			and first_pod.mesh.get_aabb().is_equal_approx(AABB(
				-Hauler.CARGO_POD_SIZE * 0.5, Hauler.CARGO_POD_SIZE
			))
			and first_pod.position.is_equal_approx(Hauler.CARGO_POD_POSITION)
			and _port_aperture_is_open(first_pod, Hauler.CARGO_POD_SIZE)
			and bool(first_pod.mesh.get_meta(&"closed_aperture_reveals", false))
			and first_pod.visible
			and first_pod.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and first_pod.layers == 1
			and not first_pod.mesh.resource_local_to_scene
			and pod_material != null
			and pod_material.albedo_color.is_equal_approx(Hauler.CARGO_COLOR)
			and is_equal_approx(pod_material.metallic, 0.45)
			and is_equal_approx(pod_material.roughness, 0.42)
			and not pod_material.resource_local_to_scene,
		"two production haulers retain exact cargo-pod bounds and an aligned port opening backed by one immutable geometry and paint recipe"
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
	var cockpit_view := first.get_cockpit_quality_report()
	var chase_view := first.get_chase_camera_self_hull_boundary_report()
	_check(
		bool(cockpit_view.get("forward_sight_clear", false))
			and int(cockpit_view.get("opaque_obstruction_count", -1)) == 0
			and int(cockpit_view.get("sight_sample_count", 0)) == 5
			and bool(chase_view.get("valid", false))
			and int(chase_view.get("sample_count", 0)) == 5,
		"production cockpit sight rays and chase-camera near-plane samples remain clear of opaque self-geometry"
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
		print("CINDER_CARGO_HULL_RESOURCE_SHARING: hull and cargo-pod immutable recipes are shared across two local renderers")
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


func _cargo_pod(craft: CinderCargoHauler) -> MeshInstance3D:
	var visual := craft.get_variant_visual_root()
	return visual.get_node_or_null(^"CargoPod") as MeshInstance3D \
		if visual != null else null


func _port_aperture_is_open(renderer: MeshInstance3D, expected_size: Vector3) -> bool:
	if renderer == null or renderer.mesh == null or renderer.mesh.get_surface_count() != 1:
		return false
	var arrays := renderer.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if vertices.is_empty() or indices.size() < 66 or indices.size() % 3 != 0:
		return false
	var left_x := -expected_size.x * 0.5
	for triangle_offset in range(0, indices.size(), 3):
		var a := vertices[indices[triangle_offset]] + renderer.position
		var b := vertices[indices[triangle_offset + 1]] + renderer.position
		var c := vertices[indices[triangle_offset + 2]] + renderer.position
		if is_equal_approx(a.x, left_x) \
				and is_equal_approx(b.x, left_x) \
				and is_equal_approx(c.x, left_x):
			var centre := (a + b + c) / 3.0
			if centre.y > Hauler.PORT_APERTURE_Y_MIN \
					and centre.y < Hauler.PORT_APERTURE_Y_MAX \
					and centre.z > Hauler.PORT_APERTURE_Z_MIN \
					and centre.z < Hauler.PORT_APERTURE_Z_MAX:
				return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
