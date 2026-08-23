extends SceneTree

## Focused renderer contract for the base defender's two immutable gun-housing
## shells. Weapon, collision, damage and reuse authority remain outside the
## presentation-only batch.

const OPPONENT_SCENE := preload("res://scenes/ships/range_opponent.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var opponent := OPPONENT_SCENE.instantiate() as RangeOpponent
	root.add_child(opponent)
	await process_frame

	var visual := opponent.get_node_or_null(^"RangeInterceptorVisual") as Node3D
	var batch := visual.get_node_or_null(^"GunHousingBatch") as MultiMeshInstance3D \
		if visual != null else null
	var multi := batch.multimesh if batch != null else null
	var transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
		if batch != null else []
	var names := batch.get_meta(&"authored_visual_names", PackedStringArray()) as PackedStringArray \
		if batch != null else PackedStringArray()
	var expected_basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	var expected_transforms: Array[Transform3D] = [
		Transform3D(expected_basis, Vector3(-2.65, -0.08, -4.35)),
		Transform3D(expected_basis, Vector3(2.65, -0.08, -4.35)),
	]
	var expected_bounds := AABB()
	if multi != null and multi.mesh != null:
		for index in expected_transforms.size():
			var instance_bounds := (expected_transforms[index] * multi.mesh.get_aabb()).abs()
			expected_bounds = instance_bounds if index == 0 else expected_bounds.merge(instance_bounds)
	var material := multi.mesh.surface_get_material(0) as StandardMaterial3D \
		if multi != null and multi.mesh != null else null
	_check(
		multi != null
			and multi.transform_format == MultiMesh.TRANSFORM_3D
			and multi.instance_count == 2
			and multi.visible_instance_count == -1
			and multi.mesh.get_surface_count() == 1,
		"the two gun-housing shells use one bounded 3D MultiMesh submission"
	)
	_check(
		transforms == expected_transforms
			and multi.custom_aabb.is_equal_approx(expected_bounds)
			and names == PackedStringArray(["PortGunHousing", "StarboardGunHousing"]),
		"the batch preserves both exact transforms, culling bounds and semantic identities"
	)
	_check(
		batch.layers == 1
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and material != null
			and material.albedo_color.is_equal_approx(RangeOpponent.FRAME_DARK)
			and is_equal_approx(material.metallic, 0.58)
			and is_equal_approx(material.roughness, 0.35)
			and bool(batch.get_meta(&"presentation_only", false))
			and batch.get_child_count() == 0,
		"material, render layers, shadow policy and authority-free ownership remain exact"
	)

	var ordinary_housings := 0
	for child in visual.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and (
			mesh_instance.position.is_equal_approx(Vector3(-2.65, -0.08, -4.35))
				or mesh_instance.position.is_equal_approx(Vector3(2.65, -0.08, -4.35))
		):
			ordinary_housings += 1
	_check(ordinary_housings == 0, "the retired ordinary housing renderers do not remain alongside the batch")

	var colliders := opponent.find_children("*", "CollisionShape3D", false, false)
	_check(
		colliders.size() == 7
			and opponent.get_node_or_null(^"PortMuzzle") is Marker3D
			and opponent.get_node_or_null(^"StarboardMuzzle") is Marker3D,
		"all seven hull colliders and both authoritative weapon muzzles remain independent"
	)

	var activated := opponent.activate_with_result(Transform3D(Basis.IDENTITY, Vector3(4.0, 2.0, -8.0)))
	var maximum_health := opponent.get_maximum_health()
	opponent.apply_damage(maximum_health * 0.7, opponent.global_position)
	var smoke := opponent.get_node_or_null(^"EngineSmoke") as CPUParticles3D
	var damaged_and_reused := opponent.is_active() and smoke != null and smoke.emitting
	opponent.deactivate()
	activated = opponent.activate_with_result(Transform3D(Basis.IDENTITY, Vector3(-3.0, 1.0, 6.0)))
	_check(
		damaged_and_reused
			and bool(activated.get("accepted", false))
			and opponent.is_active()
			and is_equal_approx(opponent.get_health(), maximum_health)
			and smoke != null
			and not smoke.emitting
			and batch.visible,
		"staged damage and deactivate/reactivate reuse remain intact around the visual batch"
	)

	opponent.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RANGE_OPPONENT_GUN_HOUSING_MULTIMESH_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
