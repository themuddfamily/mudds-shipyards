extends SceneTree

const OPPONENT_SCENE := preload("res://scenes/ships/range_opponent.tscn")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var target := Node3D.new()
	target.name = "PressureTurnTarget"
	target.position = Vector3(0.0, 0.0, -48.0)
	root.add_child(target)
	var opponent := OPPONENT_SCENE.instantiate() as RangeOpponent
	# The production coordinator binds this exact stable defender identity.
	opponent.name = "RangeOpponent"
	opponent.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(opponent)
	await process_frame
	opponent.activate(Transform3D.IDENTITY)
	opponent.set_target(target)
	var shots: Array[Dictionary] = []
	opponent.projectile_fired.connect(
		func(origin: Vector3, direction: Vector3) -> void:
			shots.append({"origin": origin, "direction": direction})
	)

	var opening := opponent.get_pressure_turn_snapshot()
	_fire_cycle(opponent, target)
	var after_first := opponent.get_pressure_turn_snapshot()
	_fire_cycle(opponent, target)
	var after_second := opponent.get_pressure_turn_snapshot()
	_start_cycle(opponent, target)
	opponent.call("_update_presentation", 0.0)
	var announced := opponent.get_pressure_turn_snapshot()
	var announced_scales := _weapon_telegraph_scales(opponent)
	var direction_before_cancel := float(opponent.get("_orbit_sign"))
	var target_direction := (target.global_position - opponent.global_position).normalized()
	opponent.call(
		"_update_weapon",
		target.global_position,
		-target_direction,
		opponent.global_position.distance_to(target.global_position),
		0.0
	)
	var cancelled := opponent.get_pressure_turn_snapshot()
	var shots_after_cancel := shots.size()
	var orbit_after_cancel := float(opponent.get("_orbit_sign"))

	_start_cycle(opponent, target)
	opponent.call("_update_presentation", 0.0)
	var retried_scales := _weapon_telegraph_scales(opponent)
	_finish_cycle(opponent, target)
	var active := opponent.get_pressure_turn_snapshot()
	var shots_after_turn := shots.size()
	var turn_direction := opponent.call(
		"_choose_motion_direction",
		target_direction,
		opponent.global_position.distance_to(target.global_position)
	) as Vector3
	var expected_lateral := Vector3.UP.cross(target_direction).normalized() * -1.0

	root.remove_child(opponent)
	await process_frame
	var detached := opponent.get_pressure_turn_snapshot()
	root.add_child(opponent)
	await process_frame
	var reentered := opponent.get_pressure_turn_snapshot()
	opponent.apply_damage(34.0, opponent.global_position)
	var damaged_modifiers := opponent.get_operational_modifiers()
	opponent.call(
		"_update_pressure_turn_state",
		0.2,
		damaged_modifiers
	)
	var damaged_active := opponent.get_pressure_turn_snapshot()
	opponent.set_target(null)
	opponent.call("_update_pressure_turn_state", 0.1, damaged_modifiers)
	var awareness_cancelled := opponent.get_pressure_turn_snapshot()

	var previous_generation := int(awareness_cancelled.activation_generation)
	opponent.deactivate()
	opponent.activate(Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.0, 0.0)))
	opponent.set_target(target)
	var reused := opponent.get_pressure_turn_snapshot()
	var role_pattern := opponent.configure_firing_pattern(
		RangeOpponent.FIRE_PATTERN_SINGLE_SHOT
	)
	for cycle in RangeOpponent.PRESSURE_TURN_CYCLE_INTERVAL:
		_fire_cycle(opponent, target)
	var explicitly_configured := opponent.get_pressure_turn_snapshot()

	_check(
		bool(opening.automatic_enabled)
		and int(opening.cycles_until_turn) == RangeOpponent.PRESSURE_TURN_CYCLE_INTERVAL
		and int(after_first.cycles_until_turn) == 2
		and int(after_second.cycles_until_turn) == 1
		and after_first.state_id == &"idle"
		and after_second.state_id == &"idle",
		"two ordinary single-shot cycles leave a readable recovery cadence before the turn"
	)
	_check(
		announced.state_id == &"telegraph"
		and int(announced.cycles_until_turn) == 0
		and announced.pre_discharge_telegraph_id == RangeOpponent.PRESSURE_TURN_TELEGRAPH_ID
		and announced_scales.size() == 2
		and (announced_scales[0] as Vector3).x > (announced_scales[1] as Vector3).x
		and bool(announced.pre_discharge_uses_static_geometry)
		and not bool(announced.pre_discharge_color_only)
		and not bool(announced.pre_discharge_motion_added),
		"the third charge shows its side with unequal static twin-lens geometry before acting"
	)
	_check(
		cancelled.state_id == &"cancelled"
		and shots_after_cancel == 2
		and shots_after_turn == 3
		and is_equal_approx(orbit_after_cancel, 1.0)
		and is_equal_approx(direction_before_cancel, 1.0)
		and retried_scales == announced_scales,
		"breaking the committed aim cancels the turn and the next valid charge repeats the same tell"
	)
	_check(
		active.state_id == &"active"
		and int(active.completed_single_shot_cycles) == 3
		and is_equal_approx(float(active.direction_sign), -1.0)
		and turn_direction.dot(expected_lateral) > 0.9
		and bool(active.uses_existing_movement_authority)
		and bool(active.uses_existing_projectile_signal)
		and not bool(active.combat_authority)
		and not bool(active.damage_authority),
		"one normal projectile commits a short outward turn through existing movement and fire authority"
	)
	_check(
		detached == reentered
		and damaged_active.state_id == &"active"
		and is_equal_approx(
			float(damaged_active.last_mobility_multiplier),
			float(damaged_modifiers.mobility_multiplier)
		)
		and float(damaged_active.last_mobility_multiplier) < 1.0
		and awareness_cancelled.state_id == &"cancelled",
		"detach/re-entry cannot replay the maneuver, while real engine damage scales it and awareness loss cancels it"
	)
	_check(
		int(reused.activation_generation) == previous_generation + 1
		and reused.state_id == &"idle"
		and int(reused.completed_single_shot_cycles) == 0
		and bool(reused.automatic_enabled)
		and role_pattern.accepted
		and not bool(explicitly_configured.automatic_enabled)
		and explicitly_configured.state_id == &"idle"
		and int(explicitly_configured.completed_single_shot_cycles) == 0,
		"activation reuse clears tactic state and explicit encounter cadence cleanly supersedes the automatic turn"
	)

	opponent.deactivate()
	root.remove_child(opponent)
	opponent.queue_free()
	root.remove_child(target)
	target.queue_free()
	await process_frame
	_finish()


func _start_cycle(opponent: RangeOpponent, target: Node3D) -> void:
	var direction := (target.global_position - opponent.global_position).normalized()
	opponent.set("_cooldown_remaining", 0.0)
	opponent.set("_telegraph_remaining", 0.0)
	opponent.call(
		"_update_weapon",
		target.global_position,
		direction,
		opponent.global_position.distance_to(target.global_position),
		0.0
	)


func _finish_cycle(opponent: RangeOpponent, target: Node3D) -> void:
	var direction := (target.global_position - opponent.global_position).normalized()
	opponent.call(
		"_update_weapon",
		target.global_position,
		direction,
		opponent.global_position.distance_to(target.global_position),
		opponent.telegraph_time
	)


func _fire_cycle(opponent: RangeOpponent, target: Node3D) -> void:
	_start_cycle(opponent, target)
	_finish_cycle(opponent, target)


func _weapon_telegraph_scales(opponent: RangeOpponent) -> Array[Vector3]:
	var scales: Array[Vector3] = []
	var mesh := opponent.get("_weapon_telegraph_mesh") as SphereMesh
	for raw_lens in opponent.get("_warning_lenses") as Array:
		var lens := raw_lens as MeshInstance3D
		if lens != null and lens.mesh == mesh:
			scales.append(lens.scale)
	return scales


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: range opponent pressure turn (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
