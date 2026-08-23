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
		and core.material_override != nominal_core_material,
		"a nonlethal live hit visibly stages damage at the authored frame and core"
	)

	var lethal_result := adapter.apply_damage(
		maximum_health,
		target.global_position,
		Vector3.FORWARD,
		{"source_id": 1101, "sequence": 1}
	)
	var duplicate_result := adapter.apply_damage(
		maximum_health,
		target.global_position,
		Vector3.FORWARD,
		{"source_id": 1101, "sequence": 2}
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
