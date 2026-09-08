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

		var rails := first.get_variant_visual_root().get_node(^"InterceptorSpeedRailBatch") as MultiMeshInstance3D
		var rail_contact := true
		var rail_crown_visible := true
		for placement: Transform3D in rails.get_meta(&"authored_instance_transforms"):
			for span in [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5]:
				for chord in [-0.025, 0.0, 0.025]:
					var at := placement * Vector3(span, 0, chord)
					var wing_hits := _vertical_hits(first_wing.mesh, first_wing.transform, at)
					var rail_hits := _vertical_hits(rails.multimesh.mesh, placement, at)
					rail_contact = rail_contact and not wing_hits.is_empty() and not rail_hits.is_empty()
					if not wing_hits.is_empty() and not rail_hits.is_empty():
						rail_contact = rail_contact and rail_hits.min() <= wing_hits.max() + 0.002
						if is_zero_approx(span) and is_zero_approx(chord):
							rail_crown_visible = rail_crown_visible and rail_hits.max() > wing_hits.max() + 0.085
		_check(rail_contact and rail_crown_visible,
			"both shared rails contact the real wing triangles along their span while their crowns remain visible")
		var blades := first.get_variant_visual_root().get_node(^"InterceptorWingtipBladeBatch") as MultiMeshInstance3D
		var blade_contact := true
		var seated_stations := 0
		var blade_points: PackedVector3Array = blades.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for placement: Transform3D in blades.get_meta(&"authored_instance_transforms"):
			var roots := {}
			for point in blade_points:
				var world_point := placement * point
				if not roots.has(point.z) or world_point.y < (roots[point.z] as Vector3).y:
					roots[point.z] = world_point
			for root_point: Vector3 in roots.values():
				var hits := _vertical_hits(first_wing.mesh, first_wing.transform, root_point)
				# The leading blade tip intentionally projects beyond the swept wing.
				if not hits.is_empty():
					seated_stations += 1
					blade_contact = blade_contact and root_point.y <= hits.max() + 0.002
		_check(blade_contact and seated_stations >= 20,
			"both blade roots meet the wing through their supported length and trailing closure")

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


## Intersect the rendered triangles, including their formed section and actual
## instance pose, so contact cannot pass by checking only nominal box bounds.
func _vertical_hits(mesh: Mesh, placement: Transform3D, at: Vector3) -> Array[float]:
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var hits: Array[float] = []
	for index in range(0, points.size(), 3):
		var hit = Geometry3D.segment_intersects_triangle(Vector3(at.x, 2, at.z), Vector3(at.x, -2, at.z),
			placement * points[index], placement * points[index + 1], placement * points[index + 2])
		if hit != null:
			hits.append((hit as Vector3).y)
	return hits
