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
	var tactic_profile_before := skirmisher.get_tactics_profile()
	var visual := skirmisher.get_node(^"WingSkirmisherVisual") as Node3D
	var intent_vane := visual.get_node(^"RoleLamp/RearCrossDirectionVane") as MeshInstance3D
	var intent_material := intent_vane.get_active_material(0) as StandardMaterial3D
	var nominal_cue := skirmisher.get_rear_cross_intent_cue_snapshot()
	_check(
		not bool(nominal_cue.visible)
		and nominal_cue.cue_id == &"rear_cross_destination_vane"
		and nominal_cue.derived_from_tactic_id == &"rear_cross"
		and int(nominal_cue.renderer_nodes) == 1
		and int(nominal_cue.mesh_resources) == 1
		and int(nominal_cue.material_resources) == 1
		and intent_vane.process_mode == Node.PROCESS_MODE_DISABLED
		and not intent_vane.is_processing()
		and not intent_vane.is_physics_processing()
		and intent_vane.get_child_count() == 0
		and intent_vane.find_children("*", "Timer", true, false).is_empty()
		and intent_vane.find_children("*", "Light3D", true, false).is_empty()
		and intent_vane.find_children("*", "CollisionObject3D", true, false).is_empty()
		and intent_vane.mesh is ArrayMesh
		and not intent_vane.mesh.resource_local_to_scene
		and intent_material != null
		and not intent_material.resource_local_to_scene
		and intent_material.emission_enabled
		and intent_material.emission.is_equal_approx(
			FlankingSkirmisherOpponent.REAR_CROSS_CUE_COLOR
		),
		"the retained dorsal vane boots hidden as one immutable, steady, authority-free renderer recipe"
	)
	# The inherited resolver owns this shot. The tactic observes the accepted
	# result only after resolution, then changes the next movement request.
	skirmisher.call("_fire_at_target", target.global_position)
	var first_result := skirmisher.get_last_shot_result()
	var first_cross := skirmisher.get_rear_cross_snapshot()
	var first_cue := skirmisher.get_rear_cross_intent_cue_snapshot()
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
	var first_cue_bounds := first_cue.local_bounds as AABB
	_check(
		bool(first_cue.visible)
		and first_cue.state_id == first_cross.state_id
		and is_equal_approx(
			float(first_cue.destination_side), float(first_cross.destination_side)
		)
		and int(first_cue.intent_activation_generation)
			== int(first_cue.activation_generation)
		and (-intent_vane.basis.z).dot(Vector3.LEFT) > 0.99
		and first_cue_bounds.size.x >= 4.7
		and float(first_cue.long_axis_meters) >= 4.8
		and bool(first_cue.steady_state_only)
		and not bool(first_cue.flashes)
		and not bool(first_cue.processes)
		and not bool(first_cue.uses_timer),
		"the accepted rear-cross state reveals a combat-distance-readable steady vane toward the authoritative destination side"
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
	_check(
		bool(first_cue.presentation_only)
		and not bool(first_cue.movement_authority)
		and not bool(first_cue.target_authority)
		and not bool(first_cue.fire_authority)
		and not bool(first_cue.combat_authority)
		and not bool(first_cue.damage_authority)
		and not bool(first_cue.reward_authority)
		and skirmisher.get_tactics_profile() == tactic_profile_before,
		"the vane observes tactic state without changing movement, target, fire, damage, reward, or opponent-balance authority"
	)
	var retained_vane_id := intent_vane.get_instance_id()
	var retained_mesh_id := intent_vane.mesh.get_instance_id()
	var retained_material_id := intent_material.get_instance_id()
	var retained_transform := intent_vane.transform
	for _frame in 3:
		await process_frame
	var steady_cue := skirmisher.get_rear_cross_intent_cue_snapshot()
	_check(
		bool(steady_cue.visible)
		and intent_vane.get_instance_id() == retained_vane_id
		and intent_vane.mesh.get_instance_id() == retained_mesh_id
		and intent_vane.get_active_material(0).get_instance_id() == retained_material_id
		and intent_vane.transform.is_equal_approx(retained_transform)
		and int(steady_cue.mesh_resource_id) == retained_mesh_id
		and int(steady_cue.material_resource_id) == retained_material_id,
		"the active intent remains perfectly steady on the same bounded node, mesh, material, and transform"
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
	var completed_cue := skirmisher.get_rear_cross_intent_cue_snapshot()
	skirmisher.call("_fire_at_target", target.global_position)
	var return_cross := skirmisher.get_rear_cross_snapshot()
	var return_cue := skirmisher.get_rear_cross_intent_cue_snapshot()
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
	_check(
		not bool(completed_cue.visible)
		and bool(return_cue.visible)
		and (-intent_vane.basis.z).dot(Vector3.RIGHT) > 0.99
		and intent_vane.get_instance_id() == retained_vane_id
		and intent_vane.mesh.get_instance_id() == retained_mesh_id
		and intent_vane.get_active_material(0).get_instance_id() == retained_material_id,
		"completion clears the vane and the opposite pass repoints the same retained renderer toward starboard"
	)

	# A coordinator role swap ends the flanker-only maneuver. Anchor fire still
	# resolves normally but cannot inherit or restart the rear pass.
	skirmisher.assign_wing_role(WingCoordinator.ROLE_ANCHOR)
	var role_swapped := skirmisher.get_rear_cross_snapshot()
	var role_swapped_cue := skirmisher.get_rear_cross_intent_cue_snapshot()
	skirmisher.call("_fire_at_target", target.global_position)
	var anchor_shot := skirmisher.get_rear_cross_snapshot()
	_check(
		role_swapped.state_id == &"idle"
		and not bool(role_swapped_cue.visible)
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
	var detached_cue := skirmisher.get_rear_cross_intent_cue_snapshot()
	host.add_child(skirmisher)
	await process_frame
	await process_frame
	var reentered := skirmisher.get_rear_cross_snapshot()
	_check(
		before_detach.state_id == &"active"
		and detached.state_id == &"idle"
		and not bool(detached_cue.visible)
		and reentered.state_id == &"idle"
		and skirmisher.is_combat_source_registered()
		and resolver.get_registered_source_count() == registered_sources_before,
		"detach and re-entry restore one resolver registration without replaying the pass"
	)

	# Pool-style deactivate/activate reuse also returns to an unassigned, idle
	# tactic while retaining the inherited activation and damage lifecycle.
	skirmisher.deactivate()
	var dormant := skirmisher.get_rear_cross_snapshot()
	var dormant_cue := skirmisher.get_rear_cross_intent_cue_snapshot()
	var reused_activation := skirmisher.activate(spawn)
	var reused := skirmisher.get_rear_cross_snapshot()
	var reused_cue := skirmisher.get_rear_cross_intent_cue_snapshot()
	_check(
		dormant.state_id == &"idle"
		and not bool(dormant_cue.visible)
		and bool(reused_activation.accepted)
		and reused.state_id == &"idle"
		and not bool(reused_cue.visible)
		and int(reused.completed_crosses) == 0
		and skirmisher.get_wing_role() == WingCoordinator.ROLE_UNASSIGNED
		and is_equal_approx(skirmisher.get_health(), starting_health),
		"deactivate and activation reuse clear all pass state through the existing lifecycle"
	)

	# Explicit target loss, a new activation generation, and terminal damage all
	# converge on the same hidden idle presentation without replacing resources.
	skirmisher.set_target(target)
	skirmisher.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	skirmisher.call("_fire_at_target", target.global_position)
	var before_target_loss := skirmisher.get_rear_cross_intent_cue_snapshot()
	skirmisher.set_target(null)
	var after_target_loss := skirmisher.get_rear_cross_intent_cue_snapshot()
	_check(
		bool(before_target_loss.visible)
		and not bool(after_target_loss.visible)
		and after_target_loss.state_id == &"idle"
		and int(after_target_loss.intent_activation_generation) == 0,
		"losing the authoritative target immediately clears committed flanking intent"
	)

	skirmisher.set_target(target)
	skirmisher.call("_fire_at_target", target.global_position)
	var before_generation := skirmisher.get_rear_cross_intent_cue_snapshot()
	var next_generation_activation := skirmisher.activate(spawn)
	var after_generation := skirmisher.get_rear_cross_intent_cue_snapshot()
	_check(
		bool(before_generation.visible)
		and bool(next_generation_activation.accepted)
		and int(after_generation.activation_generation)
			> int(before_generation.activation_generation)
		and int(after_generation.intent_activation_generation) == 0
		and after_generation.state_id == &"idle"
		and not bool(after_generation.visible),
		"a fresh activation generation cannot inherit or replay the previous generation's vane"
	)

	skirmisher.set_target(target)
	skirmisher.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	skirmisher.call("_fire_at_target", target.global_position)
	var before_terminal := skirmisher.get_rear_cross_intent_cue_snapshot()
	skirmisher.apply_damage(skirmisher.maximum_health, skirmisher.global_position)
	var after_terminal := skirmisher.get_rear_cross_intent_cue_snapshot()
	_check(
		bool(before_terminal.visible)
		and not skirmisher.is_active()
		and is_zero_approx(skirmisher.get_health())
		and after_terminal.state_id == &"idle"
		and not bool(after_terminal.visible)
		and intent_vane.get_instance_id() == retained_vane_id
		and intent_vane.mesh.get_instance_id() == retained_mesh_id
		and intent_vane.get_active_material(0).get_instance_id() == retained_material_id,
		"terminal destruction clears the vane while retaining the bounded presentation resources for safe teardown"
	)

	# A rotated/translated parent plus a moving and turning target defeats a
	# hull-local left/right arrow. The production tactic update must instead
	# align the retained vane with the newly recomputed world cross station.
	var transformed_host := Node3D.new()
	transformed_host.name = "TransformedRearCrossWorld"
	transformed_host.transform = Transform3D(
		Basis.from_euler(Vector3(0.18, 0.63, -0.12)),
		Vector3(126.0, -18.0, 74.0)
	)
	root.add_child(transformed_host)
	var transformed_authority := AUTHORITY_SCRIPT.new() as LiveCombatAuthority
	transformed_authority.name = "CombatAuthority"
	transformed_host.add_child(transformed_authority)
	var moving_target := Node3D.new()
	moving_target.name = "MovingRearCrossTarget"
	moving_target.transform = Transform3D(
		Basis.from_euler(Vector3(-0.08, 0.31, 0.14)),
		Vector3(11.0, 4.0, -9.0)
	)
	transformed_host.add_child(moving_target)
	var initial_target_forward := (-moving_target.global_basis.z).normalized()
	var initial_target_right := moving_target.global_basis.x.normalized()
	var transformed_spawn_position := (
		moving_target.global_position
			- initial_target_forward * 36.0
			+ initial_target_right * 18.0
	)
	var transformed_spawn_basis := Basis.looking_at(
		(moving_target.global_position - transformed_spawn_position).normalized(),
		Vector3.UP
	)
	var transformed_skirmisher := (
		SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	)
	transformed_skirmisher.name = "TransformedRearCrossSkirmisher"
	transformed_skirmisher.process_mode = Node.PROCESS_MODE_DISABLED
	transformed_skirmisher.combat_authority_path = NodePath("../CombatAuthority")
	transformed_skirmisher.pulse_presentation_path = NodePath("../MissingPulsePresentation")
	transformed_skirmisher.combat_audio_path = NodePath("../MissingCombatAudio")
	transformed_skirmisher.hud_path = NodePath("../MissingHud")
	transformed_skirmisher.scenario_director_path = NodePath("../MissingScenarioDirector")
	transformed_host.add_child(transformed_skirmisher)
	await process_frame
	var transformed_activation := transformed_skirmisher.activate(
		Transform3D(transformed_spawn_basis, transformed_spawn_position)
	)
	transformed_skirmisher.set_target(moving_target)
	transformed_skirmisher.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	transformed_skirmisher.call("_fire_at_target", moving_target.global_position)
	var transformed_cue := transformed_skirmisher.get_node(
		^"WingSkirmisherVisual/RoleLamp/RearCrossDirectionVane"
	) as MeshInstance3D
	var transformed_cue_mesh_id := transformed_cue.mesh.get_instance_id()
	var transformed_cue_material_id := (
		transformed_cue.get_active_material(0).get_instance_id()
	)

	# Move and rotate after commitment, then let a real inherited physics tick
	# recompute movement and rotate the hull. The following presentation pass
	# must correct the child vane after that attitude mutation, not merely before.
	moving_target.transform = Transform3D(
		Basis.from_euler(Vector3(-0.27, 1.04, 0.21)),
		Vector3(-17.0, 9.0, 28.0)
	)
	var hull_basis_before_physics := transformed_skirmisher.global_basis
	# Exercise the complete production callbacks deterministically: physics owns
	# movement/attitude inside a real physics phase, then presentation observes
	# their committed result. Disabling again prevents a second automatic tick.
	transformed_skirmisher.process_mode = Node.PROCESS_MODE_INHERIT
	await physics_frame
	transformed_skirmisher.call("_physics_process", 1.0 / 60.0)
	transformed_skirmisher.process_mode = Node.PROCESS_MODE_DISABLED
	transformed_skirmisher.call("_update_presentation", 1.0 / 60.0)
	var transformed_state := transformed_skirmisher.get_rear_cross_snapshot()
	var transformed_cue_state := (
		transformed_skirmisher.get_rear_cross_intent_cue_snapshot()
	)
	var moved_target_forward := (-moving_target.global_basis.z).normalized()
	var moved_target_right := moving_target.global_basis.x.normalized()
	var expected_cross_station := (
		moving_target.global_position
			- moved_target_forward * transformed_skirmisher.flank_station_range
			+ moved_target_right
				* transformed_skirmisher.rear_cross_lateral_offset
				* float(transformed_state.destination_side)
	)
	var expected_world_direction := (
		expected_cross_station - transformed_skirmisher.global_position
	).normalized()
	var presented_world_direction := (-transformed_cue.global_basis.z).normalized()
	_check(
		bool(transformed_activation.accepted)
		and transformed_state.state_id == &"active"
		and bool(transformed_cue_state.visible)
		and not transformed_host.global_basis.is_equal_approx(Basis.IDENTITY)
		and not transformed_skirmisher.global_basis.is_equal_approx(
			hull_basis_before_physics
		)
		and presented_world_direction.dot(expected_world_direction) > 0.9999
		and transformed_cue.mesh.get_instance_id() == transformed_cue_mesh_id
		and transformed_cue.get_active_material(0).get_instance_id()
			== transformed_cue_material_id
		and not bool(transformed_cue_state.movement_authority)
		and not bool(transformed_cue_state.target_authority),
		"the post-attitude presentation pass tracks the true moving world cross station after production hull rotation without gaining authority"
	)

	transformed_skirmisher.deactivate()
	transformed_host.remove_child(transformed_skirmisher)
	transformed_skirmisher.queue_free()
	root.remove_child(transformed_host)
	transformed_host.queue_free()

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
