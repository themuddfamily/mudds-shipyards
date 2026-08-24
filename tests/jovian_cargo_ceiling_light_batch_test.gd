extends SceneTree

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const EXPECTED_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(0.0, 4.36, -1.25)),
	Transform3D(Basis.IDENTITY, Vector3(0.0, 4.36, 2.85)),
	Transform3D(Basis.IDENTITY, Vector3(0.0, 4.36, 6.95)),
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

	var cargo_bay := jovian.get_cargo_bay_root()
	var batch := cargo_bay.get_node_or_null(^"CargoCeilingLightBatch") \
		as MultiMeshInstance3D if cargo_bay != null else null
	var multi := batch.multimesh if batch != null else null
	var authored_transforms := batch.get_meta("authored_instance_transforms", []) \
		as Array if batch != null else []
	var mesh := multi.mesh as ArrayMesh if multi != null else null
	_check(
		batch != null
		and multi != null
		and multi.instance_count == JovianLightFreighter.CARGO_CEILING_LIGHT_COPY_COUNT
		and multi.visible_instance_count in [-1, 3]
		and _transforms_match(authored_transforms, EXPECTED_TRANSFORMS)
		and multi.custom_aabb.is_equal_approx(AABB(
			Vector3(-1.05, 4.335, -1.34), Vector3(2.1, 0.05, 8.38)
		)),
		"three cargo ceiling strips retain their exact ship-local transforms in one batch"
	)
	_check(
		mesh != null
		and mesh.get_surface_count() == 1
		and mesh.get_aabb().size.is_equal_approx(
			JovianLightFreighter.CARGO_CEILING_LIGHT_SIZE
		)
		and mesh.surface_get_material(0) == jovian.get_variant_materials().get(
			"interior_light"
		),
		"the batch retains the exact emissive rounded-box recipe and material"
	)
	var retired_renderers := cargo_bay.find_children(
		"CargoCeilingLight", "MeshInstance3D", false, false
	) if cargo_bay != null else []
	_check(
		retired_renderers.is_empty()
		and batch.layers == 1
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and not batch.ignore_occlusion_culling
		and is_zero_approx(batch.extra_cull_margin)
		and batch.material_override == null
		and batch.material_overlay == null,
		"renderer submissions fall from three to one without render-policy drift"
	)

	var practicals := cargo_bay.find_children(
		"*", "OmniLight3D", false, false
	) if cargo_bay != null else []
	var practical_positions: Array[Transform3D] = []
	var practical_recipe_retained := practicals.size() == 3
	for practical in practicals:
		var light := practical as OmniLight3D
		practical_positions.append(light.transform)
		practical_recipe_retained = (
			practical_recipe_retained
			and light.light_color.is_equal_approx(Color("d7fff2"))
			and is_equal_approx(light.light_energy, 1.1)
			and is_equal_approx(light.omni_range, 6.8)
			and light.shadow_enabled
		)
	var expected_practical_transforms: Array[Transform3D] = []
	for transform in EXPECTED_TRANSFORMS:
		expected_practical_transforms.append(Transform3D(
			Basis.IDENTITY, transform.origin + Vector3(0.0, -0.24, 0.0)
		))
	_check(
		practical_recipe_retained
		and _transforms_match(practical_positions, expected_practical_transforms),
		"all three practical lights retain their illumination nodes and exact transforms"
	)

	var interior := jovian.get_walkable_interior_report()
	var copilot := jovian.get_copilot_navigation_state()
	var engineer_anchor := jovian.get_engineer_seat_anchor()
	_check(
		batch.get_parent() == cargo_bay
		and batch.get_child_count() == 0
		and batch.get_script() == null
		and batch.get_groups().is_empty()
		and not batch.is_processing()
		and not batch.is_physics_processing()
		and bool(batch.get_meta("visual_detail_only", false))
		and cargo_bay.get_parent() == jovian.get_interior_root()
		and int(interior.cargo_hardpoint_count) == 4
		and int(interior.passenger_seat_count) == 6
		and bool(interior.physical_deck_collision)
		and bool(interior.moving_occupant_compensation)
		and int(copilot.cargo_status.hardpoint_count) == 4
		and not bool(copilot.cargo_status.mutation_authority)
		and engineer_anchor != null
		and engineer_anchor.get_parent().get_parent() == jovian.get_passenger_cabin_root()
		and jovian.get_component_damage() != null,
		"the batch remains visual-only inside the moving cargo bay without traversal, cargo, or engineer authority"
	)

	jovian.queue_free()
	await process_frame
	if _failures.is_empty():
		print(
			"JOVIAN_CARGO_CEILING_LIGHT_BATCH_TEST_OK: %d assertions; " % _assertions
			+ "renderer nodes/submissions 3->1"
		)
		quit(0)
		return
	printerr("JOVIAN_CARGO_CEILING_LIGHT_BATCH_TEST_FAILED: ", _failures)
	quit(1)


func _transforms_match(left: Array, right: Array[Transform3D]) -> bool:
	if left.size() != right.size():
		return false
	for expected in right:
		var matched := false
		for value in left:
			if (value as Transform3D).is_equal_approx(expected):
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
