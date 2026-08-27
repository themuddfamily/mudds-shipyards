extends SceneTree

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const RAMP_ROTATION := Vector3(0.0, 0.0, deg_to_rad(20.0))

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	root.add_child(jovian)
	await process_frame
	await physics_frame

	var expected_transforms := _expected_transforms()
	var ramp := jovian.find_child("PortCargoRamp", true, false) as MeshInstance3D
	var visual_root: Node = ramp.get_parent() if ramp != null else null
	var actuators: Array[MeshInstance3D] = []
	if visual_root != null:
		for candidate in visual_root.get_children():
			var actuator := candidate as MeshInstance3D
			if actuator != null and _contains_transform(expected_transforms, actuator.transform):
				actuators.append(actuator)
	var mesh_ids: Dictionary = {}
	var actual_transforms: Array[Transform3D] = []
	var recipe_retained := actuators.size() \
		== JovianLightFreighter.CARGO_RAMP_ACTUATOR_COPY_COUNT
	var render_policy_retained := recipe_retained
	var cosmetic_leaves := recipe_retained
	var common_parent: Node = actuators[0].get_parent() if not actuators.is_empty() else null
	for actuator in actuators:
		actual_transforms.append(actuator.transform)
		var mesh := actuator.mesh as ArrayMesh
		if mesh == null:
			recipe_retained = false
			continue
		mesh_ids[mesh.get_instance_id()] = true
		recipe_retained = (
			recipe_retained
			and mesh.get_surface_count() == 1
			and mesh.get_aabb().size.is_equal_approx(
				JovianLightFreighter.CARGO_RAMP_ACTUATOR_SIZE
			)
			and mesh.surface_get_material(0) == jovian.get_variant_materials().get("structure")
			and actuator.material_override == null
			and actuator.material_overlay == null
		)
		render_policy_retained = (
			render_policy_retained
			and actuator.visible
			and actuator.layers == 1
			and actuator.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and not actuator.ignore_occlusion_culling
			and is_zero_approx(actuator.extra_cull_margin)
			and is_zero_approx(actuator.visibility_range_begin)
			and is_zero_approx(actuator.visibility_range_end)
		)
		cosmetic_leaves = (
			cosmetic_leaves
			and actuator.get_parent() == common_parent
			and actuator.get_child_count() == 0
			and actuator.get_script() == null
			and actuator.get_meta_list().is_empty()
			and actuator.get_groups().is_empty()
			and not actuator.is_processing()
			and not actuator.is_physics_processing()
		)

	_check(
		actuators.size() == JovianLightFreighter.CARGO_RAMP_ACTUATOR_COPY_COUNT
			and _transforms_match(actual_transforms, expected_transforms),
		"both cargo-ramp actuators retain their exact ramp-aligned transforms",
	)
	_check(
		recipe_retained and mesh_ids.size() == 1,
		"two identical structure-dark rounded boxes share one exact mesh allocation",
	)
	_check(
		render_policy_retained and cosmetic_leaves,
		"sharing preserves render policy and introduces no boarding or lifecycle authority",
	)
	_check(
		common_parent != null
			and common_parent.get_node_or_null(^"PortCargoRamp") is MeshInstance3D
			and jovian.get_interior_access_marker().position.is_equal_approx(
				Vector3(-10.05, -1.08, 3.2)
			),
		"actuators remain visual siblings of the unchanged physical ramp and boarding marker",
	)

	jovian.queue_free()
	await process_frame
	if _failures.is_empty():
		print(
			"JOVIAN_CARGO_RAMP_ACTUATOR_RESOURCE_SHARING_TEST_OK: "
			+ "%d assertions; mesh allocations 2->1" % _assertions
		)
		quit(0)
		return
	printerr("JOVIAN_CARGO_RAMP_ACTUATOR_RESOURCE_SHARING_TEST_FAILED: ", _failures)
	quit(1)


func _expected_transforms() -> Array[Transform3D]:
	return [
		Transform3D(Basis.from_euler(RAMP_ROTATION), Vector3(-6.1, 0.12, 1.3)),
		Transform3D(Basis.from_euler(RAMP_ROTATION), Vector3(-6.1, 0.12, 5.1)),
	]


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
