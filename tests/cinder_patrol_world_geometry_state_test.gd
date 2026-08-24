extends SceneTree

## Focused retained-marker proof for the real Cinder patrol binding.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const BEACON_NAMES := [
	"RouteBeaconAlpha", "RouteBeaconBravo", "RouteBeaconCharlie", "RouteBeaconDelta",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var patrol_actor := Node3D.new()
	root.add_child(patrol_actor)
	var route_root := cluster.get_node(^"RouteBeacons") as Node3D
	var retained_ids := _sign_board_ids(route_root)
	var descendant_count := route_root.find_children("*", "", true, false).size()
	var authored_transforms := _board_transforms(route_root)
	_assert_state(cluster, route_root, &"idle", [&"available", &"available", &"available", &"available"])

	var started := binding.start_patrol(patrol_actor)
	var first_generation := int(started.get("generation", -1))
	_check(
		bool(started.get("accepted", false)) and first_generation == 1,
		"the real patrol starts one authoritative generation"
	)
	_assert_state(cluster, route_root, &"active", [&"next_hold", &"pending", &"pending", &"pending"])

	var first_position := ROUTE.get_checkpoint_position(0)
	var partial := binding.advance_patrol(0.5, patrol_actor, first_position)
	var partial_state := cluster.get_patrol_marker_presentation_state()
	_check(
		bool(partial.get("accepted", false))
		and partial_state.get("phase_id") == &"dwell"
		and is_equal_approx(float(partial_state.get("dwell_fraction", -1.0)), 0.25),
		"the expected marker grows from the real continuous hold fraction"
	)
	_assert_state(cluster, route_root, &"active", [&"holding", &"pending", &"pending", &"pending"])
	var first_board := _board(route_root, 0)
	_check(
		is_equal_approx(first_board.scale.y, lerpf(0.55, 1.5, 0.25)),
		"partial hold is readable from board height without relying on color"
	)

	var outside := first_position + Vector3(ROUTE.checkpoint_radius + 1.0, 0.0, 0.0)
	var interrupted := binding.advance_patrol(0.25, patrol_actor, outside)
	var interrupted_state := cluster.get_patrol_marker_presentation_state()
	_check(
		interrupted.get("reason") == &"dwell_interrupted"
		and bool(interrupted_state.get("route_risk_interrupted", false))
		and interrupted_state.get("expected_marker_name") == &"RouteBeaconAlpha",
		"leaving the hold exposes route risk and retains the expected marker identity"
	)
	_assert_state(cluster, route_root, &"active", [&"hold_interrupted", &"pending", &"pending", &"pending"])
	_check(
		first_board.position.is_equal_approx(Vector3(0.0, 8.0, 0.0))
		and is_equal_approx(first_board.rotation_degrees.z, 45.0),
		"interruption raises and diagonally breaks the expected sign-board silhouette"
	)

	root.remove_child(cluster)
	await process_frame
	_check(
		_sign_board_ids(route_root) == retained_ids
		and cluster.get_patrol_marker_presentation_state().get("route_risk_interrupted"),
		"detachment freezes the exact interruption geometry without replay"
	)
	root.add_child(cluster)
	await process_frame
	await process_frame
	_check(
		_sign_board_ids(route_root) == retained_ids
		and cluster.get_patrol_marker_presentation_state().get("expected_marker_name") \
		== &"RouteBeaconAlpha"
		and bool(cluster.get_patrol_marker_presentation_state().get("route_risk_interrupted", false)),
		"re-entry restores the enriched generation-matched interruption snapshot"
	)

	var recovered := binding.advance_patrol(0.5, patrol_actor, first_position)
	_check(
		bool(recovered.get("accepted", false))
		and not bool(cluster.get_patrol_marker_presentation_state().get("route_risk_interrupted", true)),
		"returning to the authoritative volume restores the hold formation"
	)
	var first_complete := binding.advance_patrol(1.5, patrol_actor, first_position)
	_check(
		first_complete.get("reason") == &"dwell_completed"
		and int(first_complete.get("completed_checkpoint_count", -1)) == 1,
		"one uninterrupted two-second hold commits the first checkpoint"
	)
	_assert_state(cluster, route_root, &"active", [&"cleared", &"next_hold", &"pending", &"pending"])

	for checkpoint_index in range(1, 4):
		var progressed := binding.advance_patrol(
			NearbySectorActivityBinding.CINDER_PATROL_DWELL_SECONDS,
			patrol_actor,
			ROUTE.get_checkpoint_position(checkpoint_index)
		)
		_check(
			bool(progressed.get("accepted", false))
			and int(progressed.get("completed_checkpoint_count", -1)) == checkpoint_index + 1,
			"ordered hold %d compacts one more retained patrol marker" % (checkpoint_index + 1)
		)
	var return_state := cluster.get_patrol_marker_presentation_state()
	_assert_state(cluster, route_root, &"active", [&"cleared", &"cleared", &"cleared", &"platform_return"])
	_check(
		return_state.get("expected_marker_name") == &"CinderReachPlatform"
		and _board(route_root, 3).position.is_equal_approx(Vector3(0.0, 8.0, 0.0)),
		"the fourth board rises into a return formation for the real fifth platform checkpoint"
	)

	var completed := binding.advance_patrol(
		NearbySectorActivityBinding.CINDER_PATROL_DWELL_SECONDS,
		patrol_actor,
		ROUTE.get_checkpoint_position(4)
	)
	_check(
		completed.get("state_id") == &"completed"
		and int(completed.get("generation", -1)) == first_generation,
		"the platform hold completes the same patrol generation"
	)
	_assert_state(cluster, route_root, &"completed", [&"completed", &"completed", &"completed", &"completed"])
	for marker_index in BEACON_NAMES.size():
		_check(
			_board(route_root, marker_index).scale.is_equal_approx(Vector3(1.1, 1.1, 3.0)),
			"completed patrol marker %d shares the deep terminal slab" % (marker_index + 1)
		)

	var reset := binding.reset_patrol()
	var reset_generation := int(reset.get("generation", -1))
	_check(
		bool(reset.get("accepted", false))
		and reset_generation > first_generation
		and _sign_board_ids(route_root) == retained_ids
		and route_root.find_children("*", "", true, false).size() == descendant_count,
		"reset advances generation and restores the same retained marker roster"
	)
	_assert_state(cluster, route_root, &"reset", [&"reset", &"reset", &"reset", &"reset"])
	for marker_index in BEACON_NAMES.size():
		var board := _board(route_root, marker_index)
		_check(
			board.scale.is_equal_approx(Vector3.ONE)
			and board.position.is_equal_approx(Vector3(0.0, 5.4, 0.0))
			and board.rotation_degrees.is_equal_approx(Vector3.ZERO),
			"reset marker %d returns to its authored sign-board transform" % (marker_index + 1)
		)
	var restarted := binding.start_patrol(patrol_actor)
	var restarted_state := cluster.get_patrol_marker_presentation_state()
	_check(
		bool(restarted.get("accepted", false))
		and int(restarted_state.get("generation", -1)) > first_generation
		and _sign_board_ids(route_root) == retained_ids,
		"new-generation patrol reuse preserves all marker identities"
	)

	var failed := binding.fail_patrol(&"craft_unavailable")
	var failed_state := cluster.get_patrol_marker_presentation_state()
	var failed_transforms := _board_transforms(route_root)
	_check(
		bool(failed.get("accepted", false))
		and failed_state.get("state_id") == &"failed"
		and failed_state.get("terminal_state") == &"failed"
		and failed_state.get("failure_reason") == &"craft_unavailable",
		"the authoritative patrol failure reaches the retained world snapshot"
	)
	_assert_state(cluster, route_root, &"failed", [&"failed", &"failed", &"failed", &"failed"])
	_check(
		_board(route_root, 0).scale.is_equal_approx(Vector3(1.55, 0.28, 0.55))
		and _board(route_root, 1).rotation_degrees.is_equal_approx(Vector3(0.0, 0.0, 42.0))
		and failed_transforms != authored_transforms,
		"failure collapses and alternately crosses every route board without relying on colour"
	)

	root.remove_child(cluster)
	await process_frame
	root.add_child(cluster)
	await process_frame
	await process_frame
	_check(
		_sign_board_ids(route_root) == retained_ids
		and _board_transforms(route_root) == failed_transforms
		and cluster.get_patrol_marker_presentation_state().get("failure_reason") == &"craft_unavailable",
		"detach and re-entry retain the exact authoritative failure geometry"
	)

	var failed_reset := binding.reset_patrol()
	_check(
		bool(failed_reset.get("accepted", false))
		and _sign_board_ids(route_root) == retained_ids
		and _board_transforms(route_root) == authored_transforms,
		"failure reset restores every exact authored board transform"
	)
	var abort_start := binding.start_patrol(patrol_actor)
	var aborted := binding.abort_patrol(&"pilot_recalled")
	var aborted_state := cluster.get_patrol_marker_presentation_state()
	var aborted_transforms := _board_transforms(route_root)
	_check(
		bool(abort_start.get("accepted", false))
		and bool(aborted.get("accepted", false))
		and aborted_state.get("state_id") == &"aborted"
		and aborted_state.get("terminal_state") == &"aborted"
		and aborted_state.get("abort_reason") == &"pilot_recalled",
		"the authoritative patrol abort reaches the retained world snapshot"
	)
	_assert_state(cluster, route_root, &"aborted", [&"aborted", &"aborted", &"aborted", &"aborted"])
	_check(
		_board(route_root, 0).position.is_equal_approx(Vector3(-2.6, 7.8, 0.0))
		and _board(route_root, 1).position.is_equal_approx(Vector3(2.6, 7.8, 0.0))
		and aborted_transforms != failed_transforms
		and aborted_transforms != authored_transforms,
		"abort parts every route board into a distinct non-colour withdrawal silhouette"
	)
	root.remove_child(cluster)
	await process_frame
	root.add_child(cluster)
	await process_frame
	await process_frame
	_check(
		_sign_board_ids(route_root) == retained_ids
		and _board_transforms(route_root) == aborted_transforms
		and cluster.get_patrol_marker_presentation_state().get("abort_reason") == &"pilot_recalled",
		"detach and re-entry retain the exact authoritative abort geometry"
	)
	var abort_reset := binding.reset_patrol()
	var final_restart := binding.start_patrol(patrol_actor)
	_check(
		bool(abort_reset.get("accepted", false))
		and bool(final_restart.get("accepted", false))
		and _sign_board_ids(route_root) == retained_ids
		and _board_transforms(route_root)[0] != aborted_transforms[0]
		and _board(route_root, 0).scale.is_equal_approx(NearbySectorCluster.PATROL_SIGN_TARGET_SCALE),
		"abort reset and the next generation restore then reuse the exact retained board roster"
	)
	_check(
		route_root.find_children("*", "CollisionObject3D", true, false).is_empty()
		and bool(restarted_state.get("static_geometry_only", false))
		and not bool(restarted_state.get("checkpoint_authority", true))
		and not bool(aborted_state.get("activity_authority", true))
		and not bool(aborted_state.get("patrol_authority", true))
		and not bool(restarted_state.get("movement_authority", true))
		and not bool(aborted_state.get("reward_authority", true))
		and not bool(aborted_state.get("gameflow_authority", true))
		and not bool(aborted_state.get("network_authority", true))
		and int(aborted_state.get("node_delta", -1)) == 0
		and int(aborted_state.get("light_delta", -1)) == 0
		and int(aborted_state.get("submission_delta", -1)) == 0
		and int(aborted_state.get("collision_delta", -1)) == 0
		and route_root.find_children("*", "", true, false).size() == descendant_count,
		"terminal cues add no nodes, lights, submissions, collision, or gameplay authority"
	)

	cluster.queue_free()
	await process_frame
	_finish()


func _assert_state(
		cluster: NearbySectorCluster,
		route_root: Node3D,
		expected_state: StringName,
		expected_statuses: Array
	) -> void:
	var state := cluster.get_patrol_marker_presentation_state()
	var markers := state.get("markers", []) as Array
	var actual_statuses: Array[StringName] = []
	var geometry_matches := markers.size() == BEACON_NAMES.size()
	for marker_index in markers.size():
		var marker_state := markers[marker_index] as Dictionary
		actual_statuses.append(StringName(marker_state.get("status_id", &"")))
		var board := _board(route_root, marker_index)
		geometry_matches = geometry_matches \
			and board.scale.is_equal_approx(marker_state.get("board_scale") as Vector3) \
			and board.position.is_equal_approx(marker_state.get("board_position") as Vector3) \
			and board.rotation_degrees.is_equal_approx(
				marker_state.get("board_rotation_degrees") as Vector3
			)
	_check(
		state.get("state_id") == expected_state
		and actual_statuses == expected_statuses
		and geometry_matches,
		"%s publishes and applies the exact retained patrol-board formation" % String(expected_state)
	)


func _board(route_root: Node3D, marker_index: int) -> MeshInstance3D:
	return route_root.get_node(
		NodePath("%s/SignBoard" % BEACON_NAMES[marker_index])
	) as MeshInstance3D


func _sign_board_ids(route_root: Node3D) -> Array[int]:
	var ids: Array[int] = []
	for marker_index in BEACON_NAMES.size():
		ids.append(_board(route_root, marker_index).get_instance_id())
	return ids


func _board_transforms(route_root: Node3D) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for marker_index in BEACON_NAMES.size():
		transforms.append(_board(route_root, marker_index).transform)
	return transforms


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		print("FAIL: ", message)


func _finish() -> void:
	print("CINDER_PATROL_WORLD_GEOMETRY_STATE_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_PATROL_WORLD_GEOMETRY_STATE_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_PATROL_WORLD_GEOMETRY_STATE_TEST_FAILURE: ", failure)
	quit(1)
