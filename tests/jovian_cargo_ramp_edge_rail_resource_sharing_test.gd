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

	var ramp := jovian.find_child("PortCargoRamp", true, false) as MeshInstance3D
	var visual_root: Node = ramp.get_parent() if ramp != null else null
	var expected_transforms := _expected_transforms()
	var rail_nodes: Array[MeshInstance3D] = []
	if visual_root != null:
		for candidate in visual_root.get_children():
			var rail := candidate as MeshInstance3D
			if rail != null and _contains_transform(expected_transforms, rail.transform):
				rail_nodes.append(rail)
	var mesh_ids: Dictionary = {}
	var transforms: Array[Transform3D] = []
	var recipe_retained: bool = rail_nodes.size() \
		== JovianLightFreighter.CARGO_RAMP_EDGE_RAIL_COPY_COUNT
	var render_policy_retained: bool = recipe_retained
	var visual_only: bool = recipe_retained
	var common_parent: Node = rail_nodes[0].get_parent() if not rail_nodes.is_empty() else null
	for rail in rail_nodes:
		var mesh := rail.mesh as ArrayMesh
		transforms.append(rail.transform)
		if mesh == null:
			recipe_retained = false
			continue
		mesh_ids[mesh.get_instance_id()] = true
		recipe_retained = (
			recipe_retained
			and mesh.get_surface_count() == 1
			and mesh.get_aabb().size.is_equal_approx(
				JovianLightFreighter.CARGO_RAMP_EDGE_RAIL_SIZE
			)
			and mesh.surface_get_material(0) == jovian.get_variant_materials().get("amber")
			and rail.material_override == null
			and rail.material_overlay == null
		)
		render_policy_retained = (
			render_policy_retained
			and rail.visible
			and rail.layers == 1
			and rail.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and not rail.ignore_occlusion_culling
			and is_zero_approx(rail.extra_cull_margin)
		)
		visual_only = (
			visual_only
			and rail.get_parent() == common_parent
			and rail.get_child_count() == 0
			and rail.get_script() == null
			and rail.get_meta_list().is_empty()
			and rail.get_groups().is_empty()
			and not rail.is_processing()
			and not rail.is_physics_processing()
		)

	_check(
		rail_nodes.size() == JovianLightFreighter.CARGO_RAMP_EDGE_RAIL_COPY_COUNT
		and _transforms_match(transforms, expected_transforms),
		"both cargo-ramp edge rails retain their exact ramp-aligned transforms"
	)
	_check(
		recipe_retained and mesh_ids.size() == 1,
		"two identical amber rounded boxes share one exact mesh allocation"
	)
	_check(
		render_policy_retained and visual_only,
		"sharing preserves render policy and introduces no boarding or lifecycle authority"
	)
	_check(
		common_parent != null
		and common_parent.get_node_or_null(^"PortCargoRamp") is MeshInstance3D,
		"the shared visual rails remain siblings of the unchanged physical ramp presentation"
	)

	jovian.queue_free()
	await process_frame
	if _failures.is_empty():
		print(
			"JOVIAN_CARGO_RAMP_EDGE_RAIL_RESOURCE_SHARING_TEST_OK: "
			+ "%d assertions; mesh allocations 2->1" % _assertions
		)
		quit(0)
		return
	printerr("JOVIAN_CARGO_RAMP_EDGE_RAIL_RESOURCE_SHARING_TEST_FAILED: ", _failures)
	quit(1)


func _expected_transforms() -> Array[Transform3D]:
	return [
		Transform3D(Basis.from_euler(RAMP_ROTATION), Vector3(-7.9, -0.22, 1.62)),
		Transform3D(Basis.from_euler(RAMP_ROTATION), Vector3(-7.9, -0.22, 4.78)),
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
