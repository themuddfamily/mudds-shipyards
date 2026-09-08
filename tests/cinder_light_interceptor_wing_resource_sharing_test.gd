extends SceneTree

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")

const WING_SIZE := Vector3(12.0, 0.55, 5.8)
const WING_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(0.0, -0.15, 0.55))

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var first := Interceptor.new()
	var second := Interceptor.new()
	root.add_child(first)
	root.add_child(second)
	await process_frame

	var first_wing := _wing(first)
	var second_wing := _wing(second)
	_check(
		first_wing != null and second_wing != null,
		"both production interceptor copies retain their rapid-response wing renderer"
	)
	if first_wing != null and second_wing != null:
		_check(
			first_wing.mesh == second_wing.mesh
				and first_wing.material_override == second_wing.material_override,
			"two interceptor copies share one immutable wing mesh and material identity"
		)
		var material := first_wing.material_override as StandardMaterial3D
		_check(
			first_wing.mesh is ArrayMesh
				and first_wing.mesh.get_aabb().size.is_equal_approx(WING_SIZE)
				and first_wing.mesh.get_surface_count() == 1
				and first_wing.transform.is_equal_approx(WING_TRANSFORM)
				and second_wing.transform.is_equal_approx(WING_TRANSFORM)
				and first_wing.visible
				and first_wing.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				and first_wing.get_child_count() == 0
				and first_wing.get_script() == null,
			"sharing preserves the exact wing silhouette, placement, renderer state, and visual-only ownership"
		)
		_check(
			material != null
				and material.albedo_color.is_equal_approx(Interceptor.WING_COLOR)
				and is_equal_approx(material.metallic, 0.12)
				and is_equal_approx(material.roughness, 0.62)
				and not first_wing.mesh.resource_local_to_scene
				and not material.resource_local_to_scene,
			"the shared resources retain the authored wing finish and cross-copy lifetime"
		)

		var vertices: PackedVector3Array = first_wing.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var rolled_crown := false
		var thin_trailing_edge := true
		for point in vertices:
			if absf(point.x) > 3.0 and absf(point.x) < 5.5 and point.z > -0.5 and point.z < 0.5:
				rolled_crown = rolled_crown or (point.y > 0.08 and point.y < 0.24)
			if is_equal_approx(point.z, WING_SIZE.z * 0.5):
				thin_trailing_edge = thin_trailing_edge and absf(point.y) < 0.04
		_check(rolled_crown and thin_trailing_edge,
			"the production response wing rolls from a load-bearing crown into a thin trailing closure")

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
		"both craft cleanly leave the lifecycle while immutable wing stock remains process-owned"
	)

	if _failures.is_empty():
		print("CINDER_INTERCEPTOR_WING_RESOURCE_SHARING: meshes 2->1 materials 2->1 nodes 2->2 submissions 2->2")
		print("PASS cinder_light_interceptor_wing_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _wing(craft: CinderLightInterceptor) -> MeshInstance3D:
	var visual := craft.get_variant_visual_root()
	return visual.get_node_or_null(^"RapidResponseWing") as MeshInstance3D if visual != null else null


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
