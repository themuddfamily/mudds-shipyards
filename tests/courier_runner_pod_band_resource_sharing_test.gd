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

	var first_bands := _pod_bands(first)
	var second_bands := _pod_bands(second)
	_check(
		first_bands.size() == 2 and second_bands.size() == 2,
		"both production couriers retain port and starboard cargo bands"
	)
	var first_mesh := first_bands[0].mesh as BoxMesh if first_bands.size() == 2 else null
	var second_mesh := second_bands[0].mesh as BoxMesh if second_bands.size() == 2 else null
	_check(
		first_mesh != null
			and second_mesh != null
			and first_bands[1].mesh == first_mesh
			and second_bands[1].mesh == second_mesh,
		"each courier shares one immutable pod-band mesh across both renderer nodes"
	)
	_check(
		first_mesh != second_mesh
			and first_mesh.size.is_equal_approx(CourierRunnerOpponent.POD_BAND_SIZE)
			and second_mesh.size.is_equal_approx(CourierRunnerOpponent.POD_BAND_SIZE)
			and first_mesh.get_surface_count() == 1
			and second_mesh.get_surface_count() == 1,
		"the shared family stays instance-owned and retains the exact box silhouette"
	)
	var rust_id := int((first.get_visual_resource_audit().identity_by_key as Dictionary).get(&"courier_rust", 0))
	_check(
		first_mesh != null
			and second_mesh != null
			and first_mesh.surface_get_material(0) != null
			and first_mesh.surface_get_material(0).get_instance_id() == rust_id
			and second_mesh.surface_get_material(0) == first_mesh.surface_get_material(0),
		"both shared meshes retain the process-wide rust material binding"
	)
	_check(
		_positions_are_exact(first_bands)
			and _positions_are_exact(second_bands)
			and first.get_node_or_null(^"PortPodCollision") is CollisionShape3D
			and first.get_node_or_null(^"StarboardPodCollision") is CollisionShape3D,
		"sharing preserves bilateral placement and independent cargo-pod collision"
	)
	var first_components := first.get_component_damage_snapshot()
	var second_components := second.get_component_damage_snapshot()
	_check(
		bool(first_components.get("configuration_current", false))
			and bool(second_components.get("configuration_current", false)),
		"the visual-only sharing leaves both production component-damage models configured"
	)
	_check(
		first.get_node_or_null(^"ContractCourierVisual/TailTurretLens") is MeshInstance3D,
		"the visual-only sharing leaves the tail-turret telegraph intact"
	)
	_check(
		first.get_component_id() == CourierRunnerOpponent.COMPONENT_ID
			and second.get_component_id() == CourierRunnerOpponent.COMPONENT_ID
			and first.get_weapon_id() == CourierRunnerOpponent.COURIER_WEAPON_ID
			and second.get_weapon_id() == CourierRunnerOpponent.COURIER_WEAPON_ID
			and not first.is_combat_source_registered()
			and not second.is_combat_source_registered(),
		"the visual-only sharing leaves combat/component identity and authority unchanged"
	)

	var unique_meshes := {
		first_mesh.get_instance_id() if first_mesh != null else 0: true,
		second_mesh.get_instance_id() if second_mesh != null else -1: true,
	}
	_check(
		unique_meshes.size() == 2,
		"two couriers reduce four legacy pod-band mesh allocations to two without batching renderers"
	)

	host.queue_free()
	await process_frame
	_check(
		not is_instance_valid(first) and not is_instance_valid(second),
		"couriers still leave the reuse lifecycle cleanly"
	)

	if _failures.is_empty():
		print("COURIER_RUNNER_POD_BAND_SHARING: mesh_resources 4->2 renderer_nodes 4->4 geometry_submissions 4->4")
		print("PASS courier_runner_pod_band_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _pod_bands(courier: CourierRunnerOpponent) -> Array[MeshInstance3D]:
	var bands: Array[MeshInstance3D] = []
	var visual := courier.get_node_or_null(^"ContractCourierVisual")
	if visual == null:
		return bands
	for child in visual.get_children():
		if child is not MeshInstance3D:
			continue
		var candidate := child as MeshInstance3D
		var box := candidate.mesh as BoxMesh
		if box != null and box.size.is_equal_approx(CourierRunnerOpponent.POD_BAND_SIZE):
			bands.append(candidate)
	return bands


func _positions_are_exact(bands: Array[MeshInstance3D]) -> bool:
	if bands.size() != 2:
		return false
	var positions := [bands[0].position, bands[1].position]
	positions.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	return (
		positions[0].is_equal_approx(Vector3(-2.5, -0.34, -0.8))
		and positions[1].is_equal_approx(Vector3(2.5, -0.34, -0.8))
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
