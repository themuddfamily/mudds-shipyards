extends SceneTree

const TrailScript := preload("res://scripts/world/planetary_surface_route_trail_presentation.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var trail := TrailScript.new()
	root.add_child(trail)
	var points: Array = [
		Vector3(4.0, 8.0, 12.0),
		Vector3(10.0, 9.0, -2.0),
		Vector3(-6.0, 3.0, 14.0),
		Vector3(7.0, -1.0, 5.0),
		Vector3(20.0, 2.0, 1.0),
	]
	var configured: Dictionary = trail.configure(points)
	var medium: Dictionary = trail.apply_graphics_profile(&"medium")
	var applied: Dictionary = trail.apply_presentation_recipe(
		{"sun_elevation_sine": -1.0}, {}
	)
	var batches := trail.find_children("*", "MultiMeshInstance3D", true, false)
	var legacy_markers := trail.find_children("*", "MeshInstance3D", true, false)
	if not configured.accepted or not medium.accepted or not applied.accepted \
			or batches.size() != 1 or not legacy_markers.is_empty():
		_fail("route trail did not consolidate its identical marker renderers")
		return
	var batch := batches[0] as MultiMeshInstance3D
	var multi := batch.multimesh
	var buffer := multi.buffer if multi != null else PackedFloat32Array()
	var expected_bounds := (Transform3D(Basis.IDENTITY, points[0]) * multi.mesh.get_aabb()).abs()
	for point in [points[2], points[4]]:
		expected_bounds = expected_bounds.merge(
			(Transform3D(Basis.IDENTITY, point) * multi.mesh.get_aabb()).abs()
		)
	if multi == null or multi.instance_count != points.size() \
			or multi.visible_instance_count != 3 \
			or multi.mesh == null or batch.material_override == null \
			or multi.custom_aabb != expected_bounds \
			or buffer.size() != points.size() * 12 \
			or Vector3(buffer[3], buffer[7], buffer[11]) != points[0] \
			or Vector3(buffer[15], buffer[19], buffer[23]) != points[2] \
			or Vector3(buffer[27], buffer[31], buffer[35]) != points[4]:
		_fail("route trail batch drifted from the medium-profile marker geometry")
		return
	var detached: Dictionary = trail.detach()
	var detached_snapshot: Dictionary = trail.get_snapshot()
	var reentered: Dictionary = trail.reenter()
	var snapshot: Dictionary = trail.get_snapshot()
	if not detached.accepted or detached_snapshot.visible_marker_count != 0 \
			or not reentered.accepted or snapshot.visible_marker_count != 3 \
			or snapshot.points_body_local_m != points \
			or snapshot.authority.navigation \
			or not trail.find_children("*", "CollisionObject3D", true, false).is_empty() \
			or not trail.find_children("*", "NavigationRegion3D", true, false).is_empty():
		_fail("route trail batch changed lifecycle, route, or authority state")
		return
	print("PLANETARY_SURFACE_ROUTE_TRAIL_PRESENTATION_TEST_OK: one inert batch preserves route copies")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
