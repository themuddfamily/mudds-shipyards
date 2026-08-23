extends SceneTree

## Focused production contract for the curved structural trim along Fleet Dock
## 03's raised drop edge. The trim remains visual-only over the collision-backed
## slab; route, dock marker and berth authority remain separate and unchanged.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const EXPECTED_TRIM_AABB := AABB(
	Vector3(-0.14, -0.07, -5.2),
	Vector3(0.28, 0.14, 10.4)
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production ShipyardWorld instantiates with Fleet Dock 03")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame

	var module := world.get_fleet_dock_comb()
	var service := module.get_node_or_null(
		^"GeneratedComb/SurfaceDetail/DockArmService"
	) as Node3D if module != null else null
	var trim := service.get_node_or_null(^"DockEdgeKerb03") as MeshInstance3D if service != null else null
	var dock_01_trim := service.get_node_or_null(^"DockEdgeKerb01") as MeshInstance3D if service != null else null
	_check(
		trim != null
		and trim.position.is_equal_approx(Vector3(20.86, 2.46, 40.0))
		and trim.transform.basis.is_equal_approx(Basis.IDENTITY)
		and trim.get_child_count() == 0
		and trim.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"Dock 03 keeps the exact named one-node presentation trim transform"
	)
	_check(
		trim != null
		and trim.mesh is ArrayMesh
		and trim.mesh.resource_name == "fleet_dock_03_capsule_edge_trim_v1"
		and trim.mesh.get_surface_count() == 1
		and trim.mesh.get_faces().size() / 3 == 72
		and trim.mesh.get_aabb().is_equal_approx(EXPECTED_TRIM_AABB)
		and dock_01_trim != null
		and trim.material_override == dock_01_trim.material_override,
		"the 10.4 m frame trim is one bounded 72-triangle capsule instead of the 108-triangle shallow box"
	)
	_check(
		trim != null
		and StringName(trim.get_meta("geometry_profile", &"")) == &"yz_extruded_capsule_edge_trim"
		and is_equal_approx(float(trim.get_meta("end_radius_m", 0.0)), 0.07)
		and int(trim.get_meta("curve_segments_per_end", 0)) == 8
		and StringName(trim.get_meta("evidence_status", &"")) == &"modern_interpretation"
		and not bool(trim.get_meta("historical_form_identified", true))
		and not bool(trim.get_meta("authenticated_original_geometry", true)),
		"edge trim publishes its curve recipe and honest modern-interpretation boundary"
	)
	_check(trim != null and _mesh_normals_follow_winding(trim.mesh), "curved trim retains outward winding")

	var route_threshold := module.get_route_marker(&"dock-03-threshold") if module != null else null
	var dock_marker := module.get_dock_marker(&"deferred-dock-03") if module != null else null
	var label := module.get_node_or_null(
		^"GeneratedComb/DockLandmarks/AssignedDockLabel03"
	) as Label3D if module != null else null
	_check(
		route_threshold != null
		and route_threshold.position.is_equal_approx(Vector3(9.25, 2.55, 40.0))
		and dock_marker != null
		and dock_marker.position.is_equal_approx(Vector3(15.0, 2.55, 40.0))
		and StringName(dock_marker.get_meta("dock_status", &"")) == &"assigned_external"
		and not bool(dock_marker.get_meta("owns_berth_authority", true))
		and label != null
		and label.text == "BULWARK // MODERN DESIGN"
		and label.position.is_equal_approx(Vector3(15.0, 2.58, 34.55)),
		"Dock 03 threshold, stable marker key, non-authority and signage remain exact"
	)

	var slab := module.find_child("DockSlab03Upper", true, false) as StaticBody3D if module != null else null
	var slab_visual := slab.get_node_or_null(^"Mesh") as MeshInstance3D if slab != null else null
	var slab_collision := slab.get_node_or_null(^"Collision") as CollisionShape3D if slab != null else null
	var slab_shape := slab_collision.shape as BoxShape3D if slab_collision != null else null
	_check(
		slab != null
		and slab.position.is_equal_approx(Vector3(15.0, 2.1, 40.0))
		and slab_visual != null
		and slab_visual.mesh.get_aabb().size.is_equal_approx(Vector3(12.0, 0.6, 12.0))
		and slab_shape != null
		and slab_shape.size.is_equal_approx(Vector3(12.0, 0.6, 12.0)),
		"raised Dock 03 route and ship slab retain exact rendered and collision clearance"
	)

	var berth := world.get_berth_node(&"bulwark_fleet_dock_berth")
	var authority := module.get_authority_contract() if module != null else {}
	_check(
		berth != null
		and berth.global_position.is_equal_approx(Vector3(52.0, 5.28, 53.3))
		and berth.get_landing_half_extents().is_equal_approx(Vector3(6.0, 4.5, 6.4))
		and int(authority.get("ship_berth_count", -1)) == 0
		and int(authority.get("landing_or_interaction_area_count", -1)) == 0,
		"world retains exact Bulwark berth clearance while the comb owns no landing authority"
	)

	var renderer := module.get_render_batch_contract() if module != null else {}
	_check(
		bool(renderer.get("exact_counts", false))
		and int(renderer.get("descendant_nodes", -1)) == FleetDockComb.RENDER_DESCENDANT_COUNT
		and int(renderer.get("mesh_instances", -1)) == FleetDockComb.RENDER_MESH_INSTANCE_COUNT
		and int(renderer.get("geometry_submissions", -1)) == FleetDockComb.RENDER_GEOMETRY_SUBMISSION_COUNT,
		"Fleet Dock retains its exact node and submission budgets"
	)

	world.queue_free()
	for frame in 3:
		await process_frame
		await physics_frame
	_finish()


func _mesh_normals_follow_winding(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() != 1:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	if vertices.size() < 3 or vertices.size() != normals.size() or vertices.size() % 3 != 0:
		return false
	for index in range(0, vertices.size(), 3):
		var geometric := (vertices[index + 1] - vertices[index]).cross(
			vertices[index + 2] - vertices[index]
		).normalized()
		var declared := (
			normals[index] + normals[index + 1] + normals[index + 2]
		).normalized()
		if geometric.dot(declared) < 0.99:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_DOCK_03_EDGE_TRIM_CURVE_TEST_OK")
		quit(0)
	else:
		push_error("%d Fleet Dock 03 edge-trim assertion(s) failed" % _failures.size())
		quit(1)
