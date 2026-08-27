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

	var first_pylons := _cargo_pylons(first)
	var second_pylons := _cargo_pylons(second)
	_check(
		first_pylons.size() == 2 and second_pylons.size() == 2,
		"both production couriers retain two cargo-pylon renderer nodes"
	)
	var first_mesh := first_pylons[0].mesh as BoxMesh if first_pylons.size() == 2 else null
	var second_mesh := second_pylons[0].mesh as BoxMesh if second_pylons.size() == 2 else null
	_check(
		first_mesh != null and second_mesh != null
			and first_pylons[1].mesh == first_mesh
			and second_pylons[1].mesh == second_mesh,
		"each courier shares one immutable cargo-pylon mesh across both renderers"
	)
	_check(
		first_mesh != second_mesh
			and first_mesh.size.is_equal_approx(CourierRunnerOpponent.CARGO_PYLON_SIZE)
			and second_mesh.size.is_equal_approx(CourierRunnerOpponent.CARGO_PYLON_SIZE)
			and first_mesh.get_surface_count() == 1
			and second_mesh.get_surface_count() == 1,
		"shared stock remains courier-local and preserves the exact box silhouette"
	)
	var shadow_id := int(
		(first.get_visual_resource_audit().identity_by_key as Dictionary).get(&"courier_shadow", 0)
	)
	_check(
		first_mesh != null and second_mesh != null
			and first_mesh.surface_get_material(0) != null
			and first_mesh.surface_get_material(0).get_instance_id() == shadow_id
			and second_mesh.surface_get_material(0) == first_mesh.surface_get_material(0),
		"both shared pylon meshes retain the process-wide shadow material binding"
	)
	_check(
		_pylon_renderers_are_exact(first_pylons)
			and _pylon_renderers_are_exact(second_pylons),
		"sharing preserves exact bilateral transforms, visibility, shadows, layers, and culling"
	)
	_check(
		first.get_node_or_null(^"PortPodCollision") is CollisionShape3D
			and first.get_node_or_null(^"StarboardPodCollision") is CollisionShape3D
			and first.get_node_or_null(^"ContractCourierVisual/EnginePod") is MeshInstance3D
			and first.get_node_or_null(^"ContractCourierVisual/TailTurretLens") is MeshInstance3D,
		"visual sharing leaves pod collision, engines, and tail telegraph intact"
	)
	var first_audit := first.get_visual_resource_audit()
	var second_audit := second.get_visual_resource_audit()
	_check(
		bool(first_audit.catalog_shared)
			and bool(second_audit.catalog_shared)
			and int((first_audit.counts as Dictionary).material_bindings)
				== int((first_audit.counts as Dictionary).geometry_submissions)
			and int((second_audit.counts as Dictionary).material_bindings)
				== int((second_audit.counts as Dictionary).geometry_submissions)
			and first.get_weapon_id() == CourierRunnerOpponent.COURIER_WEAPON_ID
			and not first.is_combat_source_registered()
			and not second.is_combat_source_registered(),
		"visual sharing leaves material, combat identity, and dormant authority contracts valid"
	)

	host.queue_free()
	await process_frame
	_check(
		not is_instance_valid(first) and not is_instance_valid(second),
		"both couriers still leave the lifecycle cleanly"
	)

	if _failures.is_empty():
		print("COURIER_RUNNER_CARGO_PYLON_SHARING: mesh_resources 4->2 renderer_nodes 4->4 submissions 4->4")
		print("PASS courier_runner_cargo_pylon_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _cargo_pylons(courier: CourierRunnerOpponent) -> Array[MeshInstance3D]:
	var pylons: Array[MeshInstance3D] = []
	var visual := courier.get_node_or_null(^"ContractCourierVisual") as Node3D
	if visual == null:
		return pylons
	for child in visual.get_children():
		if child is not MeshInstance3D:
			continue
		var candidate := child as MeshInstance3D
		var box := candidate.mesh as BoxMesh
		if box != null and box.size.is_equal_approx(CourierRunnerOpponent.CARGO_PYLON_SIZE):
			pylons.append(candidate)
	return pylons


func _pylon_renderers_are_exact(pylons: Array[MeshInstance3D]) -> bool:
	if pylons.size() != 2:
		return false
	var positions := [pylons[0].position, pylons[1].position]
	positions.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	for pylon in pylons:
		if pylon.get_child_count() != 0 or pylon.get_script() != null \
				or not pylon.visible \
				or pylon.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or pylon.layers != 1 \
				or not is_zero_approx(pylon.extra_cull_margin) \
				or pylon.ignore_occlusion_culling \
				or not is_equal_approx(pylon.lod_bias, 1.0) \
				or not pylon.basis.is_equal_approx(Basis.IDENTITY):
			return false
	return (
		positions[0].is_equal_approx(Vector3(-1.5, -0.2, 0.6))
		and positions[1].is_equal_approx(Vector3(1.5, -0.2, 0.6))
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
