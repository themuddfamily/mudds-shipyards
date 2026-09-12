extends SceneTree

const COURIER_SCENE := preload("res://scenes/ships/courier_runner_opponent.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var first := COURIER_SCENE.instantiate() as CourierRunnerOpponent
	var second := COURIER_SCENE.instantiate() as CourierRunnerOpponent
	host.add_child(first)
	host.add_child(second)
	await process_frame

	var first_lamps := _pod_lamps(first)
	var second_lamps := _pod_lamps(second)
	_check(
		first_lamps.size() == 2 and second_lamps.size() == 2,
		"both production couriers retain port and starboard cargo lamps"
	)
	var first_mesh := first_lamps[0].mesh as ArrayMesh if first_lamps.size() == 2 else null
	var second_mesh := second_lamps[0].mesh as ArrayMesh if second_lamps.size() == 2 else null
	_check(
		first_mesh != null
			and second_mesh != null
			and first_lamps[1].mesh == first_mesh
			and second_lamps[1].mesh == second_mesh,
		"each courier shares one immutable pod-lamp mesh across both renderer nodes"
	)
	_check(
		first_mesh != second_mesh
			and first_mesh.get_aabb().size.z < 0.05
			and first_mesh.get_aabb().size.x < CourierRunnerOpponent.POD_LAMP_RADIUS * 2.0
			and first_mesh.get_faces().size() / 3 == 144
			and second_mesh.get_aabb() == first_mesh.get_aabb(),
		"both couriers retain one shared shallow convex lens with fewer triangles than the old spheres"
	)
	_check_mounts(first, first_lamps)

	var lamp_material_id := int(
		(first.get_visual_resource_audit().identity_by_key as Dictionary).get(&"courier_lamp", 0)
	)
	_check(
		first_mesh != null
			and second_mesh != null
			and first_mesh.surface_get_material(0) != null
			and first_mesh.surface_get_material(0).get_instance_id() == lamp_material_id
			and second_mesh.surface_get_material(0) == first_mesh.surface_get_material(0),
		"both shared meshes retain the process-wide cargo-lamp material binding"
	)
	_check(
		_positions_are_exact(first_lamps)
			and _positions_are_exact(second_lamps)
			and first.get_node_or_null(^"PortPodCollision") is CollisionShape3D
			and first.get_node_or_null(^"StarboardPodCollision") is CollisionShape3D,
		"sharing preserves bilateral placement and independent cargo-pod collision"
	)
	if first_lamps.size() == 2:
		first_lamps[0].visible = true
		first_lamps[1].visible = false
	_check(
		first_lamps.size() == 2
			and first_lamps[0].visible
			and not first_lamps[1].visible,
		"shared geometry preserves independent lamp renderer presentation state"
	)
	var fittings := first.get_node(^"ContractCourierVisual/FittedArmourAndServices") as MeshInstance3D
	var static_mesh := fittings.mesh
	first.activate(Transform3D.IDENTITY)
	_check(first_lamps[0].visible and first_lamps[1].visible, "activation lights both mounted lenses")
	first.deactivate()
	_check(not first_lamps[0].visible and not first_lamps[1].visible and fittings.visible,
		"inactive optics switch off while their passive housings remain present")
	first.activate(Transform3D.IDENTITY)
	_check(first_lamps[0].mesh == first_mesh and fittings.mesh == static_mesh,
		"reactivation preserves the shared optics and static mount geometry")
	first.deactivate()
	var first_components := first.get_component_damage_snapshot()
	var second_components := second.get_component_damage_snapshot()
	_check(
		bool(first_components.get("configuration_current", false))
			and bool(second_components.get("configuration_current", false)),
		"the visual-only sharing leaves both production component-damage models configured"
	)
	_check(
		first.get_node_or_null(^"ContractCourierVisual/TailTurretLens") is MeshInstance3D
			and first.get_component_id() == CourierRunnerOpponent.COMPONENT_ID
			and first.get_weapon_id() == CourierRunnerOpponent.COURIER_WEAPON_ID
			and not first.is_combat_source_registered()
			and not second.is_combat_source_registered(),
		"the visual-only sharing leaves the tail telegraph, combat identity, and authority intact"
	)

	var unique_meshes := {
		first_mesh.get_instance_id() if first_mesh != null else 0: true,
		second_mesh.get_instance_id() if second_mesh != null else -1: true,
	}
	_check(
		unique_meshes.size() == 2,
		"two couriers reduce four legacy pod-lamp mesh allocations to two without batching renderers"
	)

	host.queue_free()
	await process_frame
	_check(
		not is_instance_valid(first) and not is_instance_valid(second),
		"couriers still leave the reuse lifecycle cleanly"
	)

	if _failures.is_empty():
		print("COURIER_RUNNER_POD_LAMP_SHARING: mesh_resources 4->2 renderer_nodes 4->4 geometry_submissions 4->4")
		print("PASS courier_runner_pod_lamp_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _pod_lamps(courier: CourierRunnerOpponent) -> Array[MeshInstance3D]:
	var lamps: Array[MeshInstance3D] = []
	var visual := courier.get_node_or_null(^"ContractCourierVisual")
	if visual == null:
		return lamps
	for candidate in courier.get("_cargo_lamps"):
		if candidate is MeshInstance3D and candidate.get_parent() == visual:
			lamps.append(candidate)

	return lamps


func _check_mounts(courier: CourierRunnerOpponent, lamps: Array[MeshInstance3D]) -> void:
	var fittings := courier.get_node(^"ContractCourierVisual/FittedArmourAndServices") as MeshInstance3D
	_check(fittings.mesh.get_surface_count() == 3,
		"both passive mounts join the existing three static material surfaces")
	var faces := fittings.mesh.get_faces()
	var mounted := true
	var winding := true
	for lamp in lamps:
		var lens_faces := lamp.mesh.get_faces()
		var arrays := lamp.mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for triangle in range(0, lens_faces.size(), 3):
			var front := (lens_faces[triangle + 2] - lens_faces[triangle]).cross(lens_faces[triangle + 1] - lens_faces[triangle]).normalized()
			winding = winding and front.dot(normals[triangle] + normals[triangle + 1] + normals[triangle + 2]) > 0.0
		# The lip is forward of the optical crown while the aperture's backing
		# is behind it. The upper pod saddle intersects a ray below the housing.
		var lip := _first_hit_z(faces, lamp.position.x + 0.14, lamp.position.y)
		var back := _first_hit_z(faces, lamp.position.x + 0.02, lamp.position.y)
		var saddle := _first_hit_z(faces, lamp.position.x, 0.0)
		var lens_front := lamp.position.z + lamp.mesh.get_aabb().position.z
		mounted = mounted and lip < lens_front and back > lens_front and back < -1.80 \
			and saddle > -1.90 and saddle < -1.60
	_check(mounted, "real bezel lips recess both lenses and the lower saddles connect their housings to the cargo end frames")
	_check(winding, "all convex lens triangles face their authored outward normals")


func _first_hit_z(faces: PackedVector3Array, x: float, y: float) -> float:
	var closest := INF
	for triangle in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(
			Vector3(x, y, -2.1), Vector3(x, y, -1.5),
			faces[triangle], faces[triangle + 1], faces[triangle + 2])
		if hit != null:
			closest = minf(closest, hit.z)
	return closest


func _positions_are_exact(lamps: Array[MeshInstance3D]) -> bool:
	if lamps.size() != 2:
		return false
	var positions := [lamps[0].position, lamps[1].position]
	positions.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	return (
		positions[0].is_equal_approx(Vector3(-2.5, 0.22, -1.9))
		and positions[1].is_equal_approx(Vector3(2.5, 0.22, -1.9))
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
