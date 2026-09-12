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

		var lids_seated := true
		var carrier_seated := true
		var lids_clear_of_rail := true
		for side in [-1.0, 1.0]:
			var tag := "Port" if side < 0 else "Starboard"
			var visual := first.get_variant_visual_root()
			var carrier := visual.get_node(tag + "WingArmor") as MeshInstance3D
			for index in 3:
				var station: float = [-0.08, 0.90, 1.48][index]
				var old_name := tag + "WingService" + str([-0.2, 0.6, 1.4][index]).replace(".", "_")
				var seal := visual.get_node(old_name + "Gasket") as MeshInstance3D
				var lid := visual.get_node(old_name + "Panel") as MeshInstance3D
				var at := Vector3(side * 4.39, 0, station)
				var wing_hits := _vertical_hits(first_wing.mesh, first_wing.transform, at)
				var carrier_hits := _vertical_hits(carrier.mesh, carrier.transform, at)
				var seal_hits := _vertical_hits(seal.mesh, seal.transform, at)
				var lid_hits := _vertical_hits(lid.mesh, lid.transform, at)
				var frame_hits := _vertical_hits(carrier.mesh, carrier.transform, at + Vector3(side * 0.34, 0, 0))
				var frame_wing_hits := _vertical_hits(first_wing.mesh, first_wing.transform, at + Vector3(side * 0.34, 0, 0))
				var has_contact_geometry := not frame_wing_hits.is_empty() and not wing_hits.is_empty() and not carrier_hits.is_empty() and not seal_hits.is_empty() and not lid_hits.is_empty() and not frame_hits.is_empty()
				lids_seated = lids_seated and has_contact_geometry
				carrier_seated = carrier_seated and has_contact_geometry
				if has_contact_geometry:
					carrier_seated = carrier_seated and carrier_hits.min() <= wing_hits.max() + 0.002
					lids_seated = lids_seated and seal_hits.min() <= carrier_hits.max() + 0.003 and lid_hits.min() <= seal_hits.max() and lid_hits.max() - wing_hits.max() < frame_hits.max() - frame_wing_hits.max()
				for span in [-0.27, 0.0, 0.27]:
					for chord in [-0.18, 0.0, 0.18]:
						for placement: Transform3D in rails.get_meta(&"authored_instance_transforms"):
							lids_clear_of_rail = lids_clear_of_rail and _vertical_hits(rails.multimesh.mesh, placement, at + Vector3(span, 0, chord)).is_empty()
		_check(carrier_seated and lids_seated,
			"all six service lids nest below the formed carrier rims with connected wing/carrier/seal/lid interfaces")
		_check(lids_clear_of_rail,
			"the structural response rails leave all six removable service lids accessible")

		var fairings_valid := true
		var fairings_connected := true
		for side in [-1.0, 1.0]:
			var tag := "Port" if side < 0 else "Starboard"
			var visual := first.get_variant_visual_root()
			var fairing := visual.get_node(tag + "EngineBoom") as MeshInstance3D
			var armor := visual.get_node(tag + "WingArmor") as MeshInstance3D
			var cannon := visual.get_node(tag + "CannonMount") as MeshInstance3D
			var nacelle := visual.get_node(tag + "IntakeShoulder") as MeshInstance3D
			fairings_valid = fairings_valid and _fairing_geometry_valid(fairing.mesh)
			for z in [0.5, 1.1, 1.7]:
				var at := Vector3(side * 3.6, 0, z)
				fairings_connected = fairings_connected and _skins_overlap(fairing, first_wing, at) and _skins_overlap(fairing, armor, at)
			for z in [-0.75, -0.2, 0.4]:
				fairings_connected = fairings_connected and _skins_overlap(fairing, cannon, Vector3(side * 3.15, 0, z))
			for z in [0.9, 1.5]:
				fairings_connected = fairings_connected and _skins_overlap(fairing, nacelle, Vector3(side * 2.71, 0, z))
		_check(fairings_valid,
			"both crowned saddle fairings have outward triangles, finite unit normals, UVs and tangent frames, a rounded thin aft closure and the retained span")
		_check(fairings_connected,
			"both fairings intersect the real wing, service carrier, cannon cradle and nacelle skins at their structural interfaces")

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


func _skins_overlap(first: MeshInstance3D, second: MeshInstance3D, at: Vector3) -> bool:
	var a := _vertical_hits(first.mesh, first.transform, at)
	var b := _vertical_hits(second.mesh, second.transform, at)
	return not a.is_empty() and not b.is_empty() and a.min() <= b.max() + 0.002 and b.min() <= a.max() + 0.002


func _fairing_geometry_valid(mesh: Mesh) -> bool:
	if mesh.get_surface_count() != 1 or mesh.get_aabb().size.x > 1.601:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var aft_min := Vector3(INF, INF, INF)
	var aft_max := Vector3(-INF, -INF, -INF)
	for point in points:
		if is_equal_approx(point.z, 2.2):
			aft_min = aft_min.min(point)
			aft_max = aft_max.max(point)
	if not aft_min.is_finite() or aft_max.x - aft_min.x > 0.081 or aft_max.y - aft_min.y > 0.061:
		return false
	if points.is_empty() or points.size() % 3 != 0 or points.size() != normals.size() or points.size() != uv.size() or tangents.size() != points.size() * 4:
		return false
	for index in range(0, points.size(), 3):
		var face := (points[index + 2] - points[index]).cross(points[index + 1] - points[index])
		if face.length_squared() < 0.0000000001:
			return false
		for corner in 3:
			var vertex := index + corner
			var normal := normals[vertex]
			var tangent := Vector3(tangents[vertex * 4], tangents[vertex * 4 + 1], tangents[vertex * 4 + 2])
			if not points[vertex].is_finite() or not normal.is_finite() or not uv[vertex].is_finite() or not tangent.is_finite():
				return false
			var handedness := tangents[vertex * 4 + 3]
			if not is_equal_approx(normal.length(), 1.0) or not is_equal_approx(tangent.length(), 1.0) or face.dot(normal) <= 0.0:
				return false
			if absf(normal.dot(tangent)) > 0.002 or not is_finite(handedness) or not is_equal_approx(absf(handedness), 1.0):
				return false
	return true
