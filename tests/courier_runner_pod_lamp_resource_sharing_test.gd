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
	var first_mesh := first_lamps[0].mesh as SphereMesh if first_lamps.size() == 2 else null
	var second_mesh := second_lamps[0].mesh as SphereMesh if second_lamps.size() == 2 else null
	_check(
		first_mesh != null
			and second_mesh != null
			and first_lamps[1].mesh == first_mesh
			and second_lamps[1].mesh == second_mesh,
		"each courier shares one immutable pod-lamp mesh across both renderer nodes"
	)
	_check(
		first_mesh != second_mesh
			and is_equal_approx(first_mesh.radius, CourierRunnerOpponent.POD_LAMP_RADIUS)
			and is_equal_approx(first_mesh.height, CourierRunnerOpponent.POD_LAMP_RADIUS * 2.0)
			and first_mesh.radial_segments == 24
			and first_mesh.rings == 12
			and second_mesh.radius == first_mesh.radius
			and second_mesh.height == first_mesh.height,
		"the shared family stays instance-owned and retains the exact sphere silhouette"
	)
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
	for child in visual.get_children():
		if child is not MeshInstance3D:
			continue
		var candidate := child as MeshInstance3D
		var sphere := candidate.mesh as SphereMesh
		if sphere != null and is_equal_approx(sphere.radius, CourierRunnerOpponent.POD_LAMP_RADIUS):
			lamps.append(candidate)
	return lamps


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
