extends SceneTree

const AUTHORITY_SCRIPT := preload("res://scripts/combat/live_combat_authority.gd")
const SKIRMISHER_SCENE := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "RearCrossWorld"
	root.add_child(host)

	var authority := AUTHORITY_SCRIPT.new() as LiveCombatAuthority
	authority.name = "CombatAuthority"
	host.add_child(authority)

	var target := Node3D.new()
	target.name = "RearCrossTarget"
	host.add_child(target)

	var skirmisher := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	skirmisher.name = "RearCrossSkirmisher"
	skirmisher.process_mode = Node.PROCESS_MODE_DISABLED
	skirmisher.combat_authority_path = NodePath("../CombatAuthority")
	skirmisher.pulse_presentation_path = NodePath("../MissingPulsePresentation")
	skirmisher.combat_audio_path = NodePath("../MissingCombatAudio")
	skirmisher.hud_path = NodePath("../MissingHud")
	skirmisher.scenario_director_path = NodePath("../MissingScenarioDirector")
	host.add_child(skirmisher)
	await process_frame

	var spawn := Transform3D(Basis.IDENTITY, Vector3(18.0, 0.0, 34.0))
	var activation := skirmisher.activate(spawn)
	skirmisher.set_target(target)
	skirmisher.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	var resolver := authority.get_resolver()
	var registered_sources_before := resolver.get_registered_source_count()
	var starting_health := skirmisher.get_health()

	# The inherited resolver owns this shot. The tactic observes the accepted
	# result only after resolution, then changes the next movement request.
	skirmisher.call("_fire_at_target", target.global_position)
	var first_result := skirmisher.get_last_shot_result()
	var first_cross := skirmisher.get_rear_cross_snapshot()
	var target_direction := (target.global_position - skirmisher.global_position).normalized()
	var cross_direction := skirmisher.call(
		"_choose_motion_direction",
		target_direction,
		skirmisher.global_position.distance_to(target.global_position)
	) as Vector3

	_check(
		bool(activation.accepted)
		and bool(first_result.get("accepted", false))
		and bool(first_result.get("resolved", false))
		and skirmisher.get_shots_fired() == 1
		and int(first_cross.completed_crosses) == 0
		and first_cross.state_id == &"active",
		"one resolver-owned rear discharge starts one rear-cross pass"
	)
	_check(
		is_equal_approx(float(first_cross.destination_side), -1.0)
		and cross_direction.dot(Vector3.LEFT) > 0.98,
		"a shot from the player's right rear shoulder sends the flanker visibly across the wake"
	)
	_check(
		bool(first_cross.uses_existing_movement_authority)
		and bool(first_cross.uses_existing_resolver_authority)
		and not bool(first_cross.combat_authority)
		and not bool(first_cross.damage_authority)
		and not bool(first_cross.physics_authority)
		and resolver.get_registered_source_count() == registered_sources_before
		and is_equal_approx(skirmisher.get_health(), starting_health),
		"the pass adds no combat, damage, registration, or physics authority"
	)

	# Arriving at the opposite authored shoulder ends the pass. Its next shot
	# reverses the destination, creating a readable alternating attack rhythm.
	skirmisher.global_position = Vector3(-skirmisher.rear_cross_lateral_offset, 0.0, 34.0)
	target_direction = (target.global_position - skirmisher.global_position).normalized()
	skirmisher.call(
		"_choose_motion_direction",
		target_direction,
		skirmisher.global_position.distance_to(target.global_position)
	)
	var completed := skirmisher.get_rear_cross_snapshot()
	skirmisher.call("_fire_at_target", target.global_position)
	var return_cross := skirmisher.get_rear_cross_snapshot()
	skirmisher.call("_fire_at_target", target.global_position)
	var repeated_during_cross := skirmisher.get_rear_cross_snapshot()
	_check(
		completed.state_id == &"completed"
		and int(completed.completed_crosses) == 1
		and return_cross.state_id == &"active"
		and is_equal_approx(float(return_cross.destination_side), 1.0)
		and repeated_during_cross.state_id == &"active"
		and is_equal_approx(float(repeated_during_cross.destination_side), 1.0)
		and skirmisher.get_shots_fired() == 3,
		"successive completed passes alternate shoulders and cannot restart mid-cross"
	)

	# A coordinator role swap ends the flanker-only maneuver. Anchor fire still
	# resolves normally but cannot inherit or restart the rear pass.
	skirmisher.assign_wing_role(WingCoordinator.ROLE_ANCHOR)
	var role_swapped := skirmisher.get_rear_cross_snapshot()
	skirmisher.call("_fire_at_target", target.global_position)
	var anchor_shot := skirmisher.get_rear_cross_snapshot()
	_check(
		role_swapped.state_id == &"idle"
		and anchor_shot.state_id == &"idle"
		and skirmisher.get_shots_fired() == 4,
		"a role swap clears the pass and anchor fire never starts flanker movement"
	)

	# Streaming this active craft out and back in preserves the base registration
	# lifecycle without replaying a partially observed maneuver.
	skirmisher.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	skirmisher.call("_fire_at_target", target.global_position)
	var before_detach := skirmisher.get_rear_cross_snapshot()
	host.remove_child(skirmisher)
	var detached := skirmisher.get_rear_cross_snapshot()
	host.add_child(skirmisher)
	await process_frame
	await process_frame
	var reentered := skirmisher.get_rear_cross_snapshot()
	_check(
		before_detach.state_id == &"active"
		and detached.state_id == &"idle"
		and reentered.state_id == &"idle"
		and skirmisher.is_combat_source_registered()
		and resolver.get_registered_source_count() == registered_sources_before,
		"detach and re-entry restore one resolver registration without replaying the pass"
	)

	# Pool-style deactivate/activate reuse also returns to an unassigned, idle
	# tactic while retaining the inherited activation and damage lifecycle.
	skirmisher.deactivate()
	var dormant := skirmisher.get_rear_cross_snapshot()
	var reused_activation := skirmisher.activate(spawn)
	var reused := skirmisher.get_rear_cross_snapshot()
	_check(
		dormant.state_id == &"idle"
		and bool(reused_activation.accepted)
		and reused.state_id == &"idle"
		and int(reused.completed_crosses) == 0
		and skirmisher.get_wing_role() == WingCoordinator.ROLE_UNASSIGNED
		and is_equal_approx(skirmisher.get_health(), starting_health),
		"deactivate and activation reuse clear all pass state through the existing lifecycle"
	)

	skirmisher.deactivate()
	host.remove_child(skirmisher)
	skirmisher.queue_free()
	root.remove_child(host)
	host.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flanking skirmisher rear cross (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
