extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/jovian_freight_berth.tscn")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var module := MODULE_SCENE.instantiate() as JovianFreightBerth
	root.add_child(module)
	await process_frame
	await physics_frame

	var contract := module.get_staging_hatch_batch_contract()
	_check(
		bool(contract.valid)
		and int(contract.legacy.renderer_allocations) == 6
		and int(contract.current.renderer_allocations) == 1
		and int(contract.reductions.renderer_allocations) == 5
		and int(contract.legacy.renderer_submissions) == 6
		and int(contract.current.renderer_submissions) == 1
		and int(contract.reductions.renderer_submissions) == 5
		and int(contract.current.visible_copies) == 6,
		"six staging hatches collapse to one renderer allocation and submission"
	)

	var zones := module.get_node_or_null(^"HandlingZones") as Node3D
	var batch := zones.get_node_or_null(^"StagingBayHatchBatch") as MultiMeshInstance3D \
		if zones != null else null
	var border := zones.get_node_or_null(^"StagingBayEdgeXPortA") as MeshInstance3D \
		if zones != null else null
	_check(
		batch != null
		and batch.multimesh != null
		and batch.multimesh.instance_count == JovianFreightBerth.STAGING_HATCH_COPY_COUNT
		and batch.multimesh.mesh != null
		and batch.multimesh.mesh.get_aabb().size.is_equal_approx(
			JovianFreightBerth.STAGING_HATCH_SIZE
		)
		and border != null
		and batch.material_override == border.material_override
		and batch.layers == 1
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and not batch.ignore_occlusion_culling
		and is_zero_approx(batch.extra_cull_margin)
		and batch.get_child_count() == 0,
		"the batch retains exact hatch geometry, orange-glow hierarchy, and render state"
	)
	_check(
		batch != null
		and _authored_transforms_exact(
			batch.get_meta("authored_instance_transforms", []) as Array
		),
		"both bays retain all three exact hatch positions and rotations"
	)
	var retired := zones.find_children(
		"StagingBayHatch*", "MeshInstance3D", false, false
	) if zones != null else []
	_check(
		retired.is_empty()
		and not bool(contract.collision_authority)
		and not bool(contract.navigation_authority)
		and not bool(contract.interaction_authority)
		and not bool(contract.berth_authority)
		and not bool(contract.landing_authority)
		and not bool(contract.ramp_authority)
		and not bool(contract.light_authority)
		and not bool(contract.lifecycle_authority),
		"retired hatch renderers leave no collision, traversal, berth, ramp, light, or lifecycle authority"
	)

	var collision := module.get_collision_contract()
	var berth := module.get_berth_specification()
	var authority := module.get_authority_contract()
	var performance := module.get_performance_contract()
	_check(
		int(collision.body_count) == 206
		and int(collision.shape_count) == 209
		and bool(collision.all_layers_match_lifecycle)
		and bool(collision.all_shapes_present_and_enabled)
		and berth.berth_id == &"jovian_freight_berth"
		and (berth.landing_half_extents as Vector3).is_equal_approx(Vector3(14.0, 8.0, 21.5))
		and module.get_route_ids().size() == 7
		and module.get_cargo_unit_count() == 8
		and int(authority.ship_berth_count) == 0
		and int(authority.landing_or_interaction_area_count) == 1
		and int(authority.audio_node_count) == 0
		and bool(performance.within_budget)
		and bool(performance.staging_hatch_batching.valid),
		"collision, traversal, landing, cargo, interaction, and audio counts stay frozen"
	)
	module.set_module_enabled(false)
	await process_frame
	_check(
		not module.is_module_enabled()
		and batch != null
		and not batch.is_visible_in_tree()
		and bool(module.get_collision_contract().all_layers_match_lifecycle),
		"the hatch batch follows the module disabled lifecycle without owning it"
	)
	module.set_module_enabled(true)
	await process_frame
	_check(
		module.is_module_enabled()
		and batch != null
		and batch.is_visible_in_tree()
		and bool(module.get_staging_hatch_batch_contract().valid),
		"re-enabling restores the exact staging-hatch batch contract"
	)

	module.queue_free()
	await process_frame
	if _failures.is_empty():
		print("JOVIAN_FREIGHT_BERTH_STAGING_HATCH_BATCH_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("JOVIAN_FREIGHT_BERTH_STAGING_HATCH_BATCH_TEST_FAILED: ", _failures)
	quit(1)


func _authored_transforms_exact(authored: Array) -> bool:
	if authored.size() != JovianFreightBerth.STAGING_HATCH_COPY_COUNT:
		return false
	var expected: Array[Transform3D] = []
	for center in [
		JovianFreightBerth.STAGING_BAY_PORT_CENTER,
		JovianFreightBerth.STAGING_BAY_STARBOARD_CENTER,
	]:
		for hatch_index in 3:
			var hatch_z := lerpf(
				-JovianFreightBerth.STAGING_BAY_HALF_SIZE.y * 0.6,
				JovianFreightBerth.STAGING_BAY_HALF_SIZE.y * 0.6,
				float(hatch_index) * 0.5
			)
			expected.append(Transform3D(
				Basis.from_euler(Vector3(
					0.0,
					deg_to_rad(JovianFreightBerth.STAGING_HATCH_ROTATION_DEGREES.y),
					0.0
				)),
				center + Vector3(0.0, JovianFreightBerth.STAGING_HATCH_SIZE.y * 0.5, hatch_z)
			))
	for index in expected.size():
		if not (authored[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return true


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
