extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding")
	var route := cluster.get_node(^"RouteBeacons") as Node3D
	var initial_counts := _presentation_counts(route)
	var available := cluster.get_beacon_traversal_presentation_state()
	_check(
		available.state_id == &"available"
		and int(available.next_beacon_index) == 0
		and (available.beacons as Array).all(
			func(beacon: Dictionary) -> bool: return beacon.status_id == &"available"
		),
		"the four production guides begin in a detached available state"
	)

	var started: Dictionary = binding.call(
		"start_beacon_traversal", CinderBeaconTraversalActivity.BEACONS[0]
	)
	var alpha_target := cluster.get_beacon_traversal_presentation_state()
	var start_beacons := alpha_target.beacons as Array
	_check(
		bool(started.get("accepted", false))
		and alpha_target.state_id == &"traversing"
		and int(alpha_target.next_beacon_index) == 0
		and (start_beacons[0] as Dictionary).status_id == &"next_target"
		and (start_beacons[1] as Dictionary).status_id == &"pending"
		and float((start_beacons[0] as Dictionary).outbound_energy) \
			> float((start_beacons[1] as Dictionary).outbound_energy),
		"start identifies Alpha as the sole next target and dims later guides"
	)

	var alpha: Dictionary = binding.call(
		"submit_beacon_traversal", 0, CinderBeaconTraversalActivity.BEACONS[0]
	)
	var bravo_target := cluster.get_beacon_traversal_presentation_state()
	var bravo_beacons := bravo_target.beacons as Array
	_check(
		bool(alpha.get("accepted", false))
		and int(bravo_target.next_beacon_index) == 1
		and (bravo_beacons[0] as Dictionary).status_id == &"cleared"
		and (bravo_beacons[1] as Dictionary).status_id == &"next_target",
		"an authoritative Alpha receipt marks Alpha cleared and advances the cue to Bravo"
	)
	var wrong: Dictionary = binding.call(
		"submit_beacon_traversal", 2, CinderBeaconTraversalActivity.BEACONS[2]
	)
	var no_progress := cluster.get_beacon_traversal_presentation_state()
	var no_progress_beacons := no_progress.beacons as Array
	_check(
		not bool(wrong.get("accepted", true))
		and StringName(wrong.get("reason", &"")) == &"out_of_order_beacon"
		and no_progress.state_id == &"wrong_order"
		and int(no_progress.next_beacon_index) == 1
		and (no_progress_beacons[0] as Dictionary).status_id == &"cleared"
		and (no_progress_beacons[1] as Dictionary).status_id == &"wrong_order_no_progress",
		"the rejected Charlie attempt shows no progress while retaining Bravo as next"
	)

	root.remove_child(cluster)
	await process_frame
	root.add_child(cluster)
	await process_frame
	_check(
		cluster.get_beacon_traversal_presentation_state() == no_progress,
		"detach/re-entry retains the detached wrong-order presentation record"
	)
	for index in range(1, CinderBeaconTraversalActivity.BEACONS.size()):
		var result: Dictionary = binding.call(
			"submit_beacon_traversal", index, CinderBeaconTraversalActivity.BEACONS[index]
		)
		_check(bool(result.get("accepted", false)), "ordered beacon %d is accepted" % index)
	var completed := cluster.get_beacon_traversal_presentation_state()
	var completed_beacons := completed.beacons as Array
	var completed_audit := cluster.get_beacon_traversal_presentation_audit()
	_check(
		completed.state_id == &"completed"
		and int(completed.next_beacon_index) == 4
		and completed_beacons.all(func(beacon: Dictionary) -> bool: return \
			beacon.status_id == &"cleared" \
			and is_equal_approx(float(beacon.outbound_energy), 2.8))
		and bool(completed_audit.valid),
		"Delta completion resolves all four fixed guides to a steady cleared cue"
	)
	var reward: Dictionary = binding.call("request_beacon_traversal_reward")
	_check(
		bool(reward.get("accepted", false))
		and not bool((reward.get("reward_request", {}) as Dictionary).get("granted", true))
		and cluster.get_beacon_traversal_presentation_state() == completed,
		"reward request remains caller-owned and cannot mutate completed guides"
	)
	var reset: Dictionary = binding.call("reset_beacon_traversal")
	var reset_state := cluster.get_beacon_traversal_presentation_state()
	var reset_audit := cluster.get_beacon_traversal_presentation_audit()
	_check(
		bool(reset.get("accepted", false))
		and reset_state.state_id == &"reset"
		and int(reset_state.next_beacon_index) == 0
		and (reset_state.beacons as Array).all(func(beacon: Dictionary) -> bool: return \
			beacon.status_id == &"reset" \
			and is_equal_approx(float(beacon.foot_energy), 0.2))
		and _presentation_counts(route) == initial_counts
		and bool(reset_audit.valid)
		and int(reset_audit.state_feedback.node_delta) == 0
		and int(reset_audit.state_feedback.light_delta) == 0
		and int(reset_audit.state_feedback.submission_delta) == 0,
		"reset dims the fixed guide roster with zero renderer, light, collision, or authority growth"
	)

	cluster.queue_free()
	for _frame in 5:
		await process_frame
	_finish()


func _presentation_counts(presentation: Node3D) -> Dictionary:
	return {
		"descendants": presentation.find_children("*", "", true, false).size(),
		"meshes": presentation.find_children("*", "MeshInstance3D", true, false).size(),
		"batches": presentation.find_children("*", "MultiMeshInstance3D", true, false).size(),
		"lights": presentation.find_children("*", "Light3D", true, false).size(),
		"collision_objects": presentation.find_children("*", "CollisionObject3D", true, false).size(),
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_BEACON_TRAVERSAL_PRESENTATION_STATE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		quit(1)
