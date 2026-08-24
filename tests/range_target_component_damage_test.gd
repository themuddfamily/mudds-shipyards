extends SceneTree

const LiveCombatAuthorityScript := preload("res://scripts/combat/live_combat_authority.gd")
const RangeTargetDamageableAdapterScript := preload(
	"res://scripts/combat/range_target_damageable_adapter.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/world/shipyard_world.tscn") as PackedScene
	var world := packed.instantiate() as Node3D if packed != null else null
	_check(world != null, "production ShipyardWorld instantiates for range-target component combat")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame
	await physics_frame

	var authority := LiveCombatAuthorityScript.new() as LiveCombatAuthority
	root.add_child(authority)
	var attached := authority.attach_range_targets(world)
	var targets := _get_live_range_targets(world)
	_check(
		targets.size() == 4 and attached == 4,
		"all four physical world-owned targets consume the production damage adapter"
	)
	for target in targets:
		var adapter := target.get_node_or_null("AuthoritativeDamageable") as RangeTargetDamageableAdapter
		var snapshot := adapter.get_component_snapshot() if adapter != null else {}
		_check(
			adapter != null
			and snapshot.get("component_order", []) == [&"frame", &"core"]
			and int(snapshot.get("generation", 0)) == 1,
			"%s owns one active shared frame/core condition roster" % target.name
		)

	if targets.is_empty():
		world.queue_free()
		authority.queue_free()
		await process_frame
		_finish()
		return

	var target := targets[0]
	var adapter := target.get_node("AuthoritativeDamageable") as RangeTargetDamageableAdapter
	var visual := target.get_node("DroneVisual") as Node3D
	var core := visual.get_node("Core") as MeshInstance3D
	var frame := visual.get_node("OuterRing") as MeshInstance3D
	var nominal_core_material := core.material_override
	var nominal_frame_material := frame.material_override
	var nominal_core_scale := core.scale
	var nominal_frame_scale := frame.scale
	var collision_shape := target.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D
	var nominal_collision_transform := collision_shape.transform
	var original_component_model := adapter.get("_component_damage_model") as ComponentDamageModel
	var original_model_instance_id := original_component_model.get_instance_id()
	var original_generation := int(adapter.get_component_snapshot().get("generation", 0))
	var maximum_health := float(target.get_meta("health", 0.0))
	var nonlethal_damage := maximum_health * 0.34
	var first_result := adapter.apply_damage(
		nonlethal_damage,
		target.global_position,
		Vector3.FORWARD,
		{"source_id": 1101, "sequence": 0}
	)
	var staged_by_id := _component_states_by_id(adapter.get_component_snapshot())
	_check(
		bool(first_result.get("accepted", false))
		and is_equal_approx(float(target.get_meta("health", -1.0)), maximum_health - nonlethal_damage)
		and not bool(target.get_meta("destroyed", false))
		and world.get_destroyed_target_count() == 0,
		"component staging leaves metadata as the sole target health and mission authority"
	)
	_check(
		_component_stage(staged_by_id, &"frame") != &"nominal"
		and _component_stage(staged_by_id, &"core") != &"nominal"
		and frame.get_meta("component_stage", &"nominal") != &"nominal"
		and core.get_meta("component_stage", &"nominal") != &"nominal"
		and frame.material_override != nominal_frame_material
		and core.material_override != nominal_core_material
		and not frame.scale.is_equal_approx(nominal_frame_scale)
		and not core.scale.is_equal_approx(nominal_core_scale)
		and collision_shape.transform.is_equal_approx(nominal_collision_transform),
		"a nonlethal live hit stages color-independent frame/core silhouettes without changing collision"
	)
	var damaged_core_scale := core.scale
	var second_nonlethal_result := adapter.apply_damage(
		maximum_health * 0.20,
		target.global_position,
		Vector3.FORWARD,
		{"source_id": 1101, "sequence": 1}
	)
	var critical_by_id := _component_states_by_id(adapter.get_component_snapshot())
	_check(
		bool(second_nonlethal_result.get("accepted", false))
		and not bool(second_nonlethal_result.get("destroyed", true))
		and _component_stage(critical_by_id, &"core") == &"critical"
		and not core.scale.is_equal_approx(damaged_core_scale)
		and collision_shape.transform.is_equal_approx(nominal_collision_transform),
		"critical core damage has a second static silhouette distinct from damaged and nominal"
	)

	root.remove_child(world)
	await process_frame
	root.add_child(world)
	await process_frame
	await process_frame
	var restored_snapshot := adapter.get_component_snapshot()
	var restored_model := adapter.get("_component_damage_model") as ComponentDamageModel
	_check(
		adapter.is_inside_tree()
		and restored_model.get_instance_id() == original_model_instance_id
		and int(restored_snapshot.get("generation", 0)) == original_generation + 1
		and is_equal_approx(float(target.get_meta("health", -1.0)), maximum_health)
		and frame.get_meta("component_stage", &"") == &"nominal"
		and core.get_meta("component_stage", &"") == &"nominal"
		and frame.material_override == nominal_frame_material
		and core.material_override == nominal_core_material
		and frame.scale.is_equal_approx(nominal_frame_scale)
		and core.scale.is_equal_approx(nominal_core_scale)
		and collision_shape.transform.is_equal_approx(nominal_collision_transform)
		and world.get_destroyed_target_count() == 0,
		"whole-world re-entry reuses one model and restores nominal material and silhouette"
	)
	var stale_reset := adapter.reset_for_reuse(original_generation)
	_check(
		not bool(stale_reset.get("accepted", true))
		and stale_reset.get("reason") == &"stale_generation"
		and adapter.get("_component_damage_model") == restored_model
		and int(adapter.get_component_snapshot().get("generation", 0)) == original_generation + 1,
		"a stale component lifecycle event cannot replace or advance the reused model"
	)

	var lethal_result := adapter.apply_damage(
		maximum_health,
		target.global_position,
		Vector3.FORWARD,
		{"source_id": 1101, "sequence": 2}
	)
	var duplicate_result := adapter.apply_damage(
		maximum_health,
		target.global_position,
		Vector3.FORWARD,
		{"source_id": 1101, "sequence": 3}
	)
	_check(
		bool(lethal_result.get("destroyed", false))
		and bool(target.get_meta("destroyed", false))
		and target.collision_layer == 0
		and world.get_destroyed_target_count() == 1
		and not bool(duplicate_result.get("accepted", true))
		and world.get_destroyed_target_count() == 1,
		"existing world destruction and mission count remain authoritative exactly once"
	)
	root.remove_child(world)
	await process_frame
	root.add_child(world)
	await process_frame
	await process_frame
	_check(
		bool(target.get_meta("destroyed", false))
		and world.get_destroyed_target_count() == 1
		and adapter.get("_component_damage_model") == restored_model
		and int(adapter.get_component_snapshot().get("generation", 0)) == original_generation + 1,
		"re-entry never resurrects an authorized target or duplicates its model and mission count"
	)

	var destroyed_generation := int(adapter.get_component_snapshot().get("generation", 0))
	var destroyed_residue_before_reset := world.find_children(
		"TargetBurst", "Node3D", true, false
	).size()
	var regenerated: Dictionary = world.reset_range_target_for_reuse(target)
	await process_frame
	var recovery: Dictionary = world.get_range_target_component_recovery_report(target)
	_check(
		bool(regenerated.get("accepted", false))
		and bool(recovery.get("valid", false))
		and destroyed_residue_before_reset > 0
		and world.find_children("TargetBurst", "Node3D", true, false).is_empty()
		and int(adapter.get_component_snapshot().get("generation", 0)) == destroyed_generation + 1
		and is_equal_approx(float(target.get_meta("health", -1.0)), maximum_health)
		and not bool(target.get_meta("destroyed", true))
		and target.collision_layer != 0
		and not collision_shape.disabled
		and visual.visible
		and visual.scale.is_equal_approx(Vector3.ONE)
		and frame.get_meta("component_stage", &"") == &"nominal"
		and core.get_meta("component_stage", &"") == &"nominal"
		and world.get_destroyed_target_count() == 1,
		"destroyed target regeneration restores frame/core, collision, visuals, and clears burst residue without duplicating mission authority"
	)

	var deferred_receipt := 7101
	var deferred_result := adapter.apply_damage(
		maximum_health * 0.34,
		target.global_position,
		Vector3.FORWARD,
		{"presentation_receipt_id": deferred_receipt, "source_id": 1101}
	)
	var duplicate_admission: bool = world.defer_target_damage_presentation(
		deferred_receipt,
		target,
		StringName(target.get_meta("target_id", &"UNKNOWN")),
		target.global_position,
		false
	)
	_check(
		bool(deferred_result.get("accepted", false))
		and world.get_pending_target_damage_presentation_count() == 1
		and frame.get_meta("component_stage", &"") == &"nominal"
		and core.get_meta("component_stage", &"") == &"nominal"
		and not duplicate_admission,
		"component authority commits before receipt-timed localized presentation and duplicate receipt admission is inert"
	)
	_check(
		world.commit_deferred_damage_presentation(deferred_receipt)
		and not world.commit_deferred_damage_presentation(deferred_receipt)
		and frame.get_meta("component_stage", &"nominal") != &"nominal"
		and core.get_meta("component_stage", &"nominal") != &"nominal",
		"one matching receipt presents current frame/core state exactly once"
	)

	var stale_receipt := 7102
	adapter.apply_damage(
		maximum_health * 0.10,
		target.global_position,
		Vector3.FORWARD,
		{"presentation_receipt_id": stale_receipt, "source_id": 1101}
	)
	var generation_before_fence := int(adapter.get_component_snapshot().get("generation", 0))
	var fenced_reset: Dictionary = world.reset_range_target_for_reuse(target)
	_check(
		bool(fenced_reset.get("accepted", false))
		and int(adapter.get_component_snapshot().get("generation", 0)) == generation_before_fence + 1
		and not world.commit_deferred_damage_presentation(stale_receipt)
		and world.get_pending_target_damage_presentation_count() == 0
		and bool(world.get_range_target_component_recovery_report(target).get("valid", false)),
		"regeneration discards stale generation-bound receipts before they can replay component presentation"
	)

	var reused_lethal := adapter.apply_damage(
		maximum_health,
		target.global_position,
		Vector3.FORWARD,
		{"source_id": 1101, "sequence": 99}
	)
	_check(
		bool(reused_lethal.get("destroyed", false))
		and bool(target.get_meta("destroyed", false))
		and world.get_destroyed_target_count() == 1,
		"destroying a regenerated training target reuses collision/destruction authority without a second mission reward"
	)
	var final_reset: Dictionary = world.reset_range_target_for_reuse(target)
	await process_frame
	_check(
		bool(final_reset.get("accepted", false))
		and bool(world.get_range_target_component_recovery_report(target).get("valid", false))
		and world.find_children("TargetBurst", "Node3D", true, false).is_empty()
		and world.get_destroyed_target_count() == 1,
		"repeat regeneration ends with a clean reusable target and no component or destruction residue"
	)

	await create_timer(0.6).timeout
	world.queue_free()
	authority.queue_free()
	await process_frame
	_finish()


func _get_live_range_targets(world: Node) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	for candidate in world.find_children("*", "StaticBody3D", true, false):
		if candidate.get_meta("is_shipyard_target", false):
			result.append(candidate as StaticBody3D)
	return result


func _component_states_by_id(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_state in snapshot.get("components", []) as Array:
		var state := raw_state as Dictionary
		result[StringName(state.get("component_id", &""))] = state
	return result


func _component_stage(states: Dictionary, component_id: StringName) -> StringName:
	var state := states.get(component_id, {}) as Dictionary
	var stage := state.get("stage", {}) as Dictionary
	return StringName(stage.get("stage_id", &""))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("RANGE_TARGET_COMPONENT_DAMAGE_TEST_PASSED")
		quit(0)
	else:
		print("RANGE_TARGET_COMPONENT_DAMAGE_TEST_FAILED: %s" % "; ".join(_failures))
		quit(1)
