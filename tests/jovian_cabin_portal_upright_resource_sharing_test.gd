extends SceneTree

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const EXPECTED_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(-1.45, 2.1, -7.48)),
	Transform3D(Basis.IDENTITY, Vector3(1.45, 2.1, -7.48)),
	Transform3D(Basis.IDENTITY, Vector3(-1.45, 2.1, -3.0)),
	Transform3D(Basis.IDENTITY, Vector3(1.45, 2.1, -3.0)),
]

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	root.add_child(jovian)
	await process_frame
	await physics_frame

	var cabin := jovian.get_passenger_cabin_root()
	var upright_nodes: Array[MeshInstance3D] = []
	if cabin != null:
		for candidate in cabin.get_children():
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance != null and _contains_transform(
				EXPECTED_TRANSFORMS, mesh_instance.transform
			):
				upright_nodes.append(mesh_instance)
	var mesh_ids: Dictionary = {}
	var transforms: Array[Transform3D] = []
	var recipe_retained := upright_nodes.size() \
		== JovianLightFreighter.CABIN_PORTAL_UPRIGHT_COPY_COUNT
	var render_policy_retained := recipe_retained
	var visual_only := recipe_retained
	for upright in upright_nodes:
		var mesh := upright.mesh as ArrayMesh
		if mesh == null:
			recipe_retained = false
			continue
		mesh_ids[mesh.get_instance_id()] = true
		transforms.append(upright.transform)
		recipe_retained = (
			recipe_retained
			and mesh.get_surface_count() == 1
			and mesh.get_aabb().size.is_equal_approx(
				JovianLightFreighter.CABIN_PORTAL_UPRIGHT_SIZE
			)
			and mesh.surface_get_material(0) == jovian.get_variant_materials().get("amber")
			and upright.material_override == null
			and upright.material_overlay == null
		)
		render_policy_retained = (
			render_policy_retained
			and upright.visible
			and upright.layers == 1
			and upright.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and not upright.ignore_occlusion_culling
			and is_zero_approx(upright.extra_cull_margin)
		)
		visual_only = (
			visual_only
			and upright.get_child_count() == 0
			and upright.get_script() == null
			and upright.get_meta_list().is_empty()
			and upright.get_groups().is_empty()
			and not upright.is_processing()
			and not upright.is_physics_processing()
		)

	_check(
		upright_nodes.size() == 4 and _transforms_match(transforms, EXPECTED_TRANSFORMS),
		"all four portal-upright renderers retain their exact local transforms"
	)
	_check(
		recipe_retained and mesh_ids.size() == 1,
		"four identical amber rounded boxes share one exact mesh allocation"
	)
	_check(
		render_policy_retained and visual_only,
		"sharing preserves render policy and introduces no collision, traversal, or lifecycle authority"
	)

	jovian.queue_free()
	await process_frame
	if _failures.is_empty():
		print(
			"JOVIAN_CABIN_PORTAL_UPRIGHT_RESOURCE_SHARING_TEST_OK: "
			+ "%d assertions; mesh allocations 4->1" % _assertions
		)
		quit(0)
		return
	printerr("JOVIAN_CABIN_PORTAL_UPRIGHT_RESOURCE_SHARING_TEST_FAILED: ", _failures)
	quit(1)


func _transforms_match(left: Array[Transform3D], right: Array[Transform3D]) -> bool:
	if left.size() != right.size():
		return false
	for expected in right:
		var matched := false
		for actual in left:
			if actual.is_equal_approx(expected):
				matched = true
				break
		if not matched:
			return false
	return true


func _contains_transform(transforms: Array[Transform3D], target: Transform3D) -> bool:
	for transform in transforms:
		if transform.is_equal_approx(target):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
