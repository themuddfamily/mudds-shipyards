extends SceneTree

## Focused retained-geometry regression for authoritative convoy formation state.

const HostScript := preload("res://scripts/activities/cinder_convoy_escort_host.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := HostScript.new() as CinderConvoyEscortHost
	root.add_child(host)
	await process_frame
	var entity := host.get_node(^"EmberlineSupplyTender") as Node3D
	var retained_ids := _visual_ids(entity)
	var baseline_count := entity.get_child_count()
	_assert_state(host, entity, &"idle", 0.0, Vector3.ONE, Vector3.ONE)

	var started := host.start(0)
	var generation := host.get_generation()
	_check(
		bool(started.get("accepted", false)) and generation == 1,
		"the real convoy activity starts one authoritative generation"
	)
	_assert_state(host, entity, &"formation_stable", 0.0, Vector3.ONE, Vector3.ONE)

	var current_position := host.get_snapshot().get("entity_position") as Vector3
	host.advance_physics(0.25, current_position, generation)
	_assert_state(host, entity, &"formation_stable", 0.0, Vector3.ONE, Vector3.ONE)

	var far_offset := Vector3(800.0, 0.0, 0.0)
	current_position = host.get_snapshot().get("entity_position") as Vector3
	var warning := host.advance_physics(1.0, current_position + far_offset, generation)
	var warning_feedback := warning.get("visual_feedback", {}) as Dictionary
	_check(
		warning_feedback.get("geometry_state") == &"separation_warning"
		and float(warning_feedback.get("separation_fraction", 0.0)) > 0.0
		and float(warning_feedback.get("separation_fraction", 1.0)) < 0.75,
		"authoritative off-formation time opens the retained warning silhouette"
	)
	_assert_geometry_matches_snapshot(host, entity)

	current_position = host.get_snapshot().get("entity_position") as Vector3
	var critical := host.advance_physics(1.3, current_position + far_offset, generation)
	var critical_feedback := critical.get("visual_feedback", {}) as Dictionary
	_check(
		critical_feedback.get("geometry_state") == &"separation_critical"
		and float(critical_feedback.get("separation_fraction", 0.0)) >= 0.75
		and is_equal_approx(float(critical_feedback.get("pod_spread", 0.0)), 2.2),
		"the pre-failure grace edge has a distinct maximum-spread critical formation"
	)
	_assert_geometry_matches_snapshot(host, entity)

	root.remove_child(host)
	await process_frame
	_check(
		_visual_ids(entity) == retained_ids
		and host.get_snapshot().get("visual_feedback", {}).get("geometry_state")
		== &"separation_critical",
		"detachment retains the exact critical geometry without replay or node growth"
	)
	root.add_child(host)
	await process_frame
	_check(
		_visual_ids(entity) == retained_ids and host.get_generation() == generation,
		"tree re-entry preserves retained visual and activity generation identity"
	)

	current_position = host.get_snapshot().get("entity_position") as Vector3
	host.advance_physics(0.1, current_position, generation)
	_assert_state(host, entity, &"formation_stable", 0.0, Vector3.ONE, Vector3.ONE)

	var step_budget := 100
	while host.get_snapshot().get("activity", {}).get("state_id") == &"active" \
			and step_budget > 0:
		current_position = host.get_snapshot().get("entity_position") as Vector3
		host.advance_physics(0.25, current_position, generation)
		step_budget -= 1
	var completed := host.get_snapshot()
	var completed_feedback := completed.get("visual_feedback", {}) as Dictionary
	_check(
		step_budget > 0
		and completed.get("activity", {}).get("state_id") == &"completed"
		and completed_feedback.get("geometry_state") == &"convoy_complete"
		and completed_feedback.get("engine_state") == &"safe"
		and completed_feedback.get("formation_state") == &"secured"
		and completed_feedback.get("arrival_response_id")
		== &"engines_safe_formation_secured"
		and bool(completed_feedback.get("arrival_response_active", false))
		and int(completed_feedback.get("arrival_response_serial", 0)) == 1
		and is_equal_approx(float(completed_feedback.get("pod_spread", 0.0)), -0.75),
		"safe arrival secures formation and safes engines in one distinct retained silhouette"
	)
	var repeated_completed := host.get_snapshot().get("visual_feedback", {}) as Dictionary
	_check(
		int(repeated_completed.get("arrival_response_serial", 0)) == 1,
		"reading the completed receipt cannot replay the arrival response",
	)
	_assert_geometry_matches_snapshot(host, entity)

	var reset := host.reset(generation)
	var reset_generation := host.get_generation()
	_check(
		bool(reset.get("accepted", false))
		and reset_generation > generation
		and _visual_ids(entity) == retained_ids
		and entity.get_child_count() == baseline_count,
		"reset restores retained geometry in place and advances authority generation"
	)
	_assert_state(host, entity, &"idle", 0.0, Vector3.ONE, Vector3.ONE)
	_check(
		not bool(host.get_snapshot().get("visual_feedback", {}).get(
			"arrival_response_active", true
		)),
		"reset clears the engines-safe formation response",
	)
	host.start(reset_generation)
	_assert_state(host, entity, &"formation_stable", 0.0, Vector3.ONE, Vector3.ONE)
	_check(
		_visual_ids(entity) == retained_ids
		and entity.find_children("*", "CollisionObject3D", true, false).is_empty()
		and bool(host.get_cargo_pod_visual_allocation_audit().get("valid", false)),
		"new-generation reuse adds neither visual nodes nor collision authority"
	)
	var authority := host.get_snapshot().get("visual_feedback", {}) as Dictionary
	_check(
		bool(authority.get("uses_authoritative_activity_snapshot", false))
		and bool(authority.get("static_geometry_only", false))
		and not bool(authority.get("movement_authority", true))
		and not bool(authority.get("combat_authority", true))
		and not bool(authority.get("reward_authority", true)),
		"formation feedback explicitly retains no movement, combat, or reward authority"
	)

	host.queue_free()
	await process_frame
	_finish()


func _assert_state(
		host: CinderConvoyEscortHost,
		entity: Node3D,
		expected_state: StringName,
		expected_spread: float,
		expected_drive_scale: Vector3,
		expected_beacon_scale: Vector3
	) -> void:
	var feedback := host.get_snapshot().get("visual_feedback", {}) as Dictionary
	_check(
		feedback.get("geometry_state") == expected_state
		and is_equal_approx(float(feedback.get("pod_spread", NAN)), expected_spread)
		and (feedback.get("drive_scale", Vector3.ZERO) as Vector3).is_equal_approx(
			expected_drive_scale
		)
		and (feedback.get("beacon_scale", Vector3.ZERO) as Vector3).is_equal_approx(
			expected_beacon_scale
		),
		"%s publishes its exact retained non-color geometry recipe" % String(expected_state)
	)
	_assert_geometry_matches_snapshot(host, entity)


func _assert_geometry_matches_snapshot(
		host: CinderConvoyEscortHost,
		entity: Node3D
	) -> void:
	var feedback := host.get_snapshot().get("visual_feedback", {}) as Dictionary
	var spread := float(feedback.get("pod_spread", NAN))
	var pod_batch := entity.get_node(^"PortCargoPod") as MultiMeshInstance3D
	var starboard_anchor := entity.get_node(^"StarboardCargoPod") as Node3D
	var drive_glow := entity.get_node(^"DriveGlow") as MeshInstance3D
	var beacon := entity.get_node(^"NavigationBeacon") as MeshInstance3D
	_check(
		is_equal_approx(pod_batch.multimesh.buffer[3], -spread)
		and is_equal_approx(pod_batch.multimesh.buffer[15], 6.7 + spread)
		and starboard_anchor.position.is_equal_approx(Vector3(3.35 + spread, 0.05, 0.4))
		and drive_glow.scale.is_equal_approx(feedback.get("drive_scale") as Vector3)
		and beacon.scale.is_equal_approx(feedback.get("beacon_scale") as Vector3)
		and bool(host.get_cargo_pod_visual_allocation_audit().get("valid", false)),
		"published formation state matches the retained pod, drive, and beacon geometry"
	)


func _visual_ids(entity: Node3D) -> Array[int]:
	var ids: Array[int] = []
	for child in entity.get_children():
		ids.append((child as Node).get_instance_id())
	return ids


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		print("FAIL: ", message)


func _finish() -> void:
	print("CINDER_CONVOY_WORLD_FORMATION_STATE_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_CONVOY_WORLD_FORMATION_STATE_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_CONVOY_WORLD_FORMATION_STATE_TEST_FAILURE: ", failure)
	quit(1)
