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

	module.queue_free()
	await process_frame
	if _failures.is_empty():
		print("JOVIAN_FREIGHT_BERTH_TROLLEY_WHEEL_BATCH_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("JOVIAN_FREIGHT_BERTH_TROLLEY_WHEEL_BATCH_TEST_FAILED: ", _failures)
	quit(1)


func _transforms_match(left: Array, right: Array) -> bool:
	if left.size() != JovianFreightBerth.TROLLEY_WHEEL_COPY_COUNT or left.size() != right.size():
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
