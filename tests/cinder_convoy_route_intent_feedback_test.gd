extends SceneTree

## Focused regression for the retained world-space convoy route-intent vane.

const HostScript := preload("res://scripts/activities/cinder_convoy_escort_host.gd")
const ROUTE: ActivityDefinition = preload(
	"res://assets/activities/cinder_reach_emberline_convoy_route.tres"
)

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := HostScript.new() as CinderConvoyEscortHost
	root.add_child(host)
	await process_frame
	var entity := host.get_node(^"EmberlineSupplyTender") as Node3D
	var cue := entity.get_node(^"NavigationBeacon") as MeshInstance3D
	var cue_node_id := cue.get_instance_id()
	var cue_mesh_id := cue.mesh.get_instance_id()
	var cue_material_id := cue.material_override.get_instance_id()
	var activity_failure_feedback: Array[Dictionary] = []
	var activity := host.get_node(^"ConvoyEscortActivity") as ConvoyEscortActivity
	activity.failed.connect(func(
		_activity_id: StringName,
		_terminal_result: int,
		_reason: StringName,
		_activity_generation: int
	) -> void:
		activity_failure_feedback.append(
			host.get_snapshot().get("visual_feedback", {}).duplicate(true)
		)
	)
	_assert_cue_recipe(cue)
	_assert_route_intent(host, cue, &"standby", 1)

	var started := host.start(0)
	var generation := host.get_generation()
	_check(
		bool(started.get("accepted", false)) and generation == 1,
		"the route vane observes one real authoritative convoy generation"
	)
	_assert_route_intent(host, cue, &"next_leg", 1)
	host.position = Vector3(13.0, -7.0, 21.0)
	host.rotation = Vector3(0.23, -0.71, 0.16)
	host.scale = Vector3(1.7, 0.65, 2.4)
	var current_position := host.get_snapshot().get("entity_position") as Vector3
	host.advance_physics(0.1, current_position, generation)
	_assert_route_intent(host, cue, &"next_leg", 1)

	current_position = host.get_snapshot().get("entity_position") as Vector3
	var threatened := host.advance_physics(
		1.0,
		current_position + Vector3(800.0, 0.0, 0.0),
		generation
	)
	var threatened_feedback := threatened.get("visual_feedback", {}) as Dictionary
	_check(
		threatened_feedback.get("geometry_state") == &"separation_warning"
		and threatened_feedback.get("route_intent_state") == &"next_leg"
		and cue.get_instance_id() == cue_node_id
		and cue.mesh.get_instance_id() == cue_mesh_id
		and cue.material_override.get_instance_id() == cue_material_id
		and cue.scale.is_equal_approx(Vector3(1.0, 1.8, 1.0)),
		"threat pressure lengthens the same steady route vane without replacing its resources"
	)
	_assert_route_intent(host, cue, &"next_leg", 1)

	root.remove_child(host)
	await process_frame
	_check(
		cue.get_instance_id() == cue_node_id
		and cue.mesh.get_instance_id() == cue_mesh_id
		and host.get_snapshot().get("visual_feedback", {}).get("route_intent_state") \
		== &"next_leg",
		"detachment retains the route cue and its last authoritative intent"
	)
	root.add_child(host)
	await process_frame
	current_position = host.get_snapshot().get("entity_position") as Vector3
	host.advance_physics(0.1, current_position, generation)
	_check(
		cue.get_instance_id() == cue_node_id
		and cue.mesh.get_instance_id() == cue_mesh_id
		and cue.scale.is_equal_approx(Vector3.ONE),
		"tree re-entry and escort recovery restore the same vane to its healthy retained shape"
	)
	_assert_route_intent(host, cue, &"next_leg", 1)

	current_position = host.get_snapshot().get("entity_position") as Vector3
	entity.queue_free()
	await process_frame
	var lost := host.advance_physics(0.1, current_position, generation)
	var lost_feedback := lost.get("visual_feedback", {}) as Dictionary
	_check(
		bool(lost.get("accepted", false))
		and lost.get("reason") == &"convoy_actor_lost"
		and lost.get("activity", {}).get("state_id") == &"failed"
		and not bool(lost.get("entity_available", true))
		and lost_feedback.get("route_intent_state") == &"unavailable"
		and not bool(lost_feedback.get("route_intent_active", true))
		and int(lost_feedback.get("route_target_index", 0)) == -1
		and (lost_feedback.get("route_target_local_position") as Vector3) == Vector3.ZERO
		and (lost_feedback.get("route_target_world_position") as Vector3) == Vector3.ZERO
		and (lost_feedback.get("route_direction_local") as Vector3) == Vector3.ZERO
		and (lost_feedback.get("route_direction_world") as Vector3) == Vector3.ZERO
		and activity_failure_feedback.size() == 1
		and not bool(activity_failure_feedback[0].get("route_intent_active", true))
		and int(activity_failure_feedback[0].get("route_target_index", 0)) == -1
		and (activity_failure_feedback[0].get("route_direction_world") as Vector3) \
		== Vector3.ZERO,
		"actor loss synchronously publishes failed state with all route intent cleared"
	)
	var reset := host.reset(generation)
	var restored_entity := host.get_node(^"EmberlineSupplyTender") as Node3D
	var restored_cue := restored_entity.get_node(^"NavigationBeacon") as MeshInstance3D
	_check(
		bool(reset.get("accepted", false))
		and restored_entity.get_child_count() == 7
		and restored_entity.find_children(
			"NavigationBeacon", "MeshInstance3D", true, false
		).size() == 1
		and restored_cue.get_instance_id() != cue_node_id,
		"reset rebuilds exactly one vane for the fresh actor incarnation"
	)
	_assert_cue_recipe(restored_cue)
	_assert_route_intent(host, restored_cue, &"standby", 1)
	var authority := host.get_snapshot().get("visual_feedback", {}) as Dictionary
	_check(
		bool(authority.get("retained_world_space_cue", false))
		and bool(authority.get("steady_state_only", false))
		and not bool(authority.get("uses_timers", true))
		and not bool(authority.get("uses_raw_input", true))
		and not bool(authority.get("movement_authority", true))
		and not bool(authority.get("combat_authority", true))
		and not bool(authority.get("reward_authority", true)),
		"the route vane explicitly owns no input, timing, movement, combat, or reward authority"
	)

	host.queue_free()
	await process_frame
	_finish()


func _assert_cue_recipe(cue: MeshInstance3D) -> void:
	var mesh := cue.mesh as CylinderMesh
	_check(
		mesh != null
		and is_zero_approx(mesh.top_radius)
		and is_equal_approx(mesh.bottom_radius, 0.42)
		and is_equal_approx(mesh.height, 2.8)
		and mesh.radial_segments == 12
		and cue.position.is_equal_approx(Vector3(0.0, 1.2, -1.9))
		and cue.rotation.is_equal_approx(Vector3(-PI * 0.5, 0.0, 0.0))
		and not cue.is_processing()
		and not cue.is_physics_processing(),
		"one bounded non-processing cone forms the retained forward route vane"
	)


func _assert_route_intent(
	host: CinderConvoyEscortHost,
	cue: MeshInstance3D,
	expected_state: StringName,
	expected_target_index: int
	) -> void:
	var feedback := host.get_snapshot().get("visual_feedback", {}) as Dictionary
	var expected_local_target := ROUTE.get_checkpoint_position(expected_target_index)
	var expected_local_direction := (
		expected_local_target - cue.get_parent_node_3d().position
	).normalized()
	var expected_world_target := host.to_global(expected_local_target)
	var expected_world_direction := (
		expected_world_target - cue.get_parent_node_3d().global_position
	).normalized()
	var visible_arrow_direction := cue.global_basis.y.normalized()
	_check(
		feedback.get("route_intent_cue_id") == &"emberline_route_vane"
		and feedback.get("route_intent_state") == expected_state
		and bool(feedback.get("route_intent_active", false))
		and int(feedback.get("route_target_index", -1)) == expected_target_index
		and (feedback.get("route_target_position") as Vector3).is_equal_approx(
			expected_local_target
		)
		and (feedback.get("route_target_local_position") as Vector3).is_equal_approx(
			expected_local_target
		)
		and (feedback.get("route_target_world_position") as Vector3).is_equal_approx(
			expected_world_target
		)
		and (feedback.get("route_direction_local") as Vector3).is_equal_approx(
			expected_local_direction
		)
		and (feedback.get("route_direction_world") as Vector3).is_equal_approx(
			expected_world_direction
		)
		and visible_arrow_direction.is_equal_approx(expected_world_direction),
		"%s route intent visibly aligns the retained vane with authoritative leg %d"
		% [String(expected_state), expected_target_index + 1]
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		print("FAIL: ", message)


func _finish() -> void:
	print("CINDER_CONVOY_ROUTE_INTENT_FEEDBACK_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_CONVOY_ROUTE_INTENT_FEEDBACK_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_CONVOY_ROUTE_INTENT_FEEDBACK_TEST_FAILURE: ", failure)
	quit(1)
