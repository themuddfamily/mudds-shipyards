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

	var contract := module.get_portal_chevron_batch_contract()
	_check(
		bool(contract.valid)
		and int(contract.legacy.renderer_allocations) == 6
		and int(contract.current.renderer_allocations) == 1
		and int(contract.reductions.renderer_allocations) == 5
		and int(contract.legacy.renderer_submissions) == 6
		and int(contract.current.renderer_submissions) == 1
		and int(contract.reductions.renderer_submissions) == 5
		and int(contract.current.visible_copies) == 6,
		"six portal chevrons collapse to one renderer allocation and submission"
	)

	var portal := module.get_node_or_null(^"ApproachPortal") as Node3D
	var batch := portal.get_node_or_null(^"PortalChevronBatch") as MultiMeshInstance3D \
		if portal != null else null
	_check(
		batch != null
		and batch.multimesh != null
		and batch.multimesh.instance_count == JovianFreightBerth.PORTAL_CHEVRON_COPY_COUNT
		and batch.multimesh.mesh != null
		and batch.multimesh.mesh.get_aabb().size.is_equal_approx(
			JovianFreightBerth.PORTAL_CHEVRON_SIZE
		)
		and batch.material_override != null
		and batch.layers == 1
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and not batch.ignore_occlusion_culling
		and is_zero_approx(batch.extra_cull_margin)
		and batch.get_child_count() == 0,
		"the batch retains the exact mesh bounds, material, and render state"
	)
	_check(
		batch != null
		and _authored_transforms_exact(
			batch.get_meta("authored_instance_transforms", []) as Array
		),
		"all six portal-local positions and rotations remain exact"
	)
	var retired := portal.find_children("PortalChevron", "MeshInstance3D", false, false) \
		if portal != null else []
	_check(
		retired.is_empty()
		and not bool(contract.collision_authority)
		and not bool(contract.navigation_authority)
		and not bool(contract.interaction_authority)
		and not bool(contract.berth_authority)
		and not bool(contract.landing_authority)
		and not bool(contract.lifecycle_authority),
		"no retired renderer or semantic authority remains in the visual family"
	)

	var collision := module.get_collision_contract()
	var berth := module.get_berth_specification()
	_check(
		int(collision.body_count) == 206
		and int(collision.shape_count) == 209
		and bool(collision.all_layers_match_lifecycle)
		and bool(collision.all_shapes_present_and_enabled)
		and berth.berth_id == &"jovian_freight_berth"
		and (berth.landing_half_extents as Vector3).is_equal_approx(Vector3(14.0, 8.0, 21.5))
		and module.get_route_ids().size() == 7
		and module.get_cargo_unit_count() == 8,
		"collision, landing, navigation, and cargo contracts remain unchanged"
	)
	module.set_module_enabled(false)
	await process_frame
	var disabled_collision := module.get_collision_contract()
	_check(
		not module.is_module_enabled()
		and batch != null
		and not batch.is_visible_in_tree()
		and bool(disabled_collision.all_layers_match_lifecycle),
		"the batch follows the existing disabled lifecycle without owning it"
	)
	module.set_module_enabled(true)
	await process_frame
	_check(
		module.is_module_enabled()
		and batch != null
		and batch.is_visible_in_tree()
		and bool(module.get_portal_chevron_batch_contract().valid),
		"re-enabling restores the exact portal batch contract"
	)

	module.queue_free()
	await process_frame
	if _failures.is_empty():
		print("JOVIAN_FREIGHT_BERTH_PORTAL_CHEVRON_BATCH_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("JOVIAN_FREIGHT_BERTH_PORTAL_CHEVRON_BATCH_TEST_FAILED: ", _failures)
	quit(1)


func _authored_transforms_exact(authored: Array) -> bool:
	if authored.size() != JovianFreightBerth.PORTAL_CHEVRON_COPY_COUNT:
		return false
	for index in JovianFreightBerth.PORTAL_CHEVRON_COPY_COUNT:
		var expected := Transform3D(
			Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(26.0))),
			Vector3(
				lerpf(-4.1, 4.1, float(index) / 5.0),
				5.95,
				JovianFreightBerth.PORTAL_Z - 0.42
			)
		)
		if not (authored[index] as Transform3D).is_equal_approx(expected):
			return false
	return true


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
