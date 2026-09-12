extends SceneTree

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	root.add_child(jovian)
	await process_frame
	await physics_frame

	jovian.set_physics_process(false)
	var actuators: Array[MeshInstance3D] = jovian.get("_cargo_ramp_actuators")
	var rods: Array[MeshInstance3D] = jovian.get("_cargo_ramp_rods")
	var expected_transforms: Array[Transform3D] = []
	for actuator in actuators:
		expected_transforms.append(actuator.transform)
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
			and rods.size() == actuators.size(),
		"both cargo-ramp actuators retain paired telescoping rods",
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
			and common_parent.get_node_or_null(^"CargoRampHinge/PortCargoRamp") is MeshInstance3D
			and jovian.get_interior_access_marker().position.is_equal_approx(
				Vector3(-10.05, -1.08, 3.2)
			),
		"actuators share the cargo access assembly and preserve the physical boarding marker",
	)

	var rod_mesh: Mesh = rods[0].mesh if rods.size() == 2 else null
	_check(rod_mesh != null and rods[1].mesh == rod_mesh
		and rod_mesh != actuators[0].mesh
		and rod_mesh.surface_get_material(0) == jovian.get_variant_materials().get("structure"),
		"both telescoping rods share a separate immutable mesh and the existing structural finish")
	var resources_retained := recipe_retained and rods.size() == 2
	var moved := false
	for fraction in [0.25, 0.5, 0.75, 1.0]:
		jovian.call("_set_cargo_ramp_fraction", fraction)
		for index in actuators.size():
			resources_retained = resources_retained and mesh_ids.has(actuators[index].mesh.get_instance_id()) \
				and rods[index].mesh == rod_mesh
			moved = moved or not actuators[index].transform.is_equal_approx(expected_transforms[index])
	jovian.reset_for_reuse(jovian.global_transform)
	await physics_frame
	actual_transforms.clear()
	for actuator in actuators:
		actual_transforms.append(actuator.transform)
	_check(resources_retained and moved and _transforms_match(actual_transforms, expected_transforms),
		"folding moves the actuator assemblies without replacing meshes, and reset restores their deployed poses")

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


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
