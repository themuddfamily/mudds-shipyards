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

	var contract := module.get_trolley_wheel_batch_contract()
	_check(
		bool(contract.valid)
		and int(contract.legacy.renderer_submissions) == 4
		and int(contract.current.renderer_submissions) == 1
		and int(contract.current.visible_copies) == 4
		and int(contract.reductions.renderer_submissions) == 3
		and bool(contract.equipment_identity_retained),
		"four trolley wheels collapse to one exact renderer submission"
	)
	var trolley := module.get_node_or_null(^"FreightGantryCrane/AnimatedTrolley") as Node3D
	var batch := trolley.get_node_or_null(^"TrolleyWheelBatch") as MultiMeshInstance3D \
		if trolley != null else null
	_check(
		batch != null
		and batch.multimesh != null
		and batch.multimesh.instance_count == JovianFreightBerth.TROLLEY_WHEEL_COPY_COUNT
		and batch.material_override != null
		and batch.layers == 1
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and not batch.ignore_occlusion_culling
		and is_zero_approx(batch.extra_cull_margin),
		"the batch retains the wheel mesh, material, layer, shadow, and culling state"
	)
	_check(
		batch != null
		and _transforms_match(
			batch.get_meta("authored_instance_transforms", []) as Array,
			contract.authored_transforms as Array
		),
		"the four authored wheel transforms remain exact"
	)
	var retired_renderers := 0
	if trolley != null:
		for child in trolley.get_children():
			if child is MeshInstance3D and str(child.name).begins_with("TrolleyWheel"):
				retired_renderers += 1
	_check(
		retired_renderers == 0 and batch != null and batch.get_child_count() == 0,
		"no per-wheel renderer or child authority remains"
	)
	var collision := module.get_collision_contract()
	var authority := module.get_authority_contract()
	_check(
		int(collision.body_count) == 206
		and int(collision.shape_count) == 209
		and (authority.authority_ids as PackedStringArray).is_empty()
		and int(authority.lease_authority_count) == 0
		and int(authority.spawn_authority_count) == 0
		and module.get_cargo_unit_count() == 8
		and module.get_route_ids().size() == 7,
		"collision, lease, cargo, and navigation identities are unchanged"
	)
	var before := batch.global_position if batch != null else Vector3.ZERO
	module.advance_equipment_simulation(1.0)
	var after := batch.global_position if batch != null else Vector3.ZERO
	_check(
		module.get_animated_equipment_count() == 3
		and trolley != null
		and bool(trolley.get_meta("animated_station_equipment", false))
		and not before.is_equal_approx(after),
		"the batched wheels still inherit the existing animated trolley identity and motion"
	)

	var indicator_contract := module.get_cabinet_indicator_batch_contract()
	_check(
		bool(indicator_contract.valid)
		and int(indicator_contract.legacy.renderer_submissions) == 6
		and int(indicator_contract.current.renderer_submissions) == 1
		and int(indicator_contract.current.visible_copies) == 6
		and int(indicator_contract.current.anchor_nodes) == 6
		and int(indicator_contract.reductions.renderer_submissions) == 5
		and not bool(indicator_contract.collision_authority)
		and not bool(indicator_contract.traversal_authority)
		and not bool(indicator_contract.cargo_authority)
		and not bool(indicator_contract.berth_authority)
		and not bool(indicator_contract.lifecycle_authority),
		"six cabinet indicators collapse to one visual-only submission without berth authority"
	)
	var cargo_root := module.get_node_or_null(^"CargoInfrastructure") as Node3D
	var indicator_batch := cargo_root.get_node_or_null(^"CabinetIndicatorBatch") as MultiMeshInstance3D \
		if cargo_root != null else null
	var indicator_anchors := cargo_root.find_children("CabinetIndicator*", "MeshInstance3D", false, false) \
		if cargo_root != null else []
	_check(
		indicator_batch != null
		and indicator_batch.multimesh != null
		and indicator_batch.multimesh.instance_count == 6
		and indicator_batch.multimesh.visible_instance_count in [-1, 6]
		and indicator_batch.material_override != null
		and bool(indicator_batch.get_meta("visual_detail_only", false))
		and StringName(indicator_batch.get_meta("visual_batch_family_id", &"")) \
			== &"cargo-service-cabinet-indicators"
		and indicator_anchors.size() == 6
		and _transforms_match(
			indicator_batch.get_meta("authored_instance_transforms", []) as Array,
			indicator_contract.authored_transforms as Array
		),
		"the named indicator anchors and one batch retain all authored transforms and material"
	)
	var anchors_hidden := indicator_anchors.size() == 6
	for anchor in indicator_anchors:
		anchors_hidden = anchors_hidden and not (anchor as MeshInstance3D).visible
	_check(
		anchors_hidden
		and module.get_cargo_unit_count() == 8
		and module.get_route_ids().size() == 7,
		"hidden anchors preserve the service-detail roster while cargo and routes remain unchanged"
	)

	module.queue_free()
	await process_frame
	if _failures.is_empty():
		print("JOVIAN_FREIGHT_BERTH_TROLLEY_WHEEL_BATCH_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("JOVIAN_FREIGHT_BERTH_TROLLEY_WHEEL_BATCH_TEST_FAILED: ", _failures)
	quit(1)


func _transforms_match(left: Array, right: Array) -> bool:
	if left.is_empty() or left.size() != right.size():
		return false
	for index in left.size():
		if not (left[index] as Transform3D).is_equal_approx(right[index] as Transform3D):
			return false
	return true


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
