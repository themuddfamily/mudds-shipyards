extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const ROUTE: ActivityDefinition = preload("res://assets/activities/cinder_reach_checkpoint_route.tres")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding")
	var route_root := cluster.get_node(^"RouteBeacons") as Node3D
	var gates := _gates(route_root)
	var retained_ids := gates.map(func(gate: Node3D) -> int: return gate.get_instance_id())
	var authored_ring_transforms := _ring_transforms(gates)
	var initial_counts := _route_counts(route_root)
	var initial := cluster.get_race_gate_presentation_state()
	_check(
		initial.state_id == &"idle"
		and int(initial.generation) == 0
		and _ring_scale(gates[0], ^"SignalRing").is_equal_approx(Vector3.ONE)
		and _ring_position(gates[0], ^"SignalRing").is_equal_approx(Vector3(0.0, 12.0, 0.0)),
		"the retained race gates begin at their authored available geometry"
	)

	var started: Dictionary = binding.call("start_race")
	var countdown := cluster.get_race_gate_presentation_state()
	_check(
		bool(started.get("accepted", false))
		and countdown.state_id == &"countdown"
		and int(countdown.generation) == 1
		and (countdown.gates as Array)[0].status_id == &"next_gate"
		and _ring_scale(gates[0], ^"SignalRing").is_equal_approx(Vector3.ONE * 1.28)
		and _ring_scale(gates[1], ^"SignalRing").is_equal_approx(Vector3.ONE * 0.84),
		"countdown opens only the first ordered gate while later gates remain compact"
	)
	_check(bool((binding.call("advance_race", 3.0) as Dictionary).get("accepted", false)),
		"caller physics advances the real race into its active state")
	var missed: Dictionary = binding.call("submit_race_position", Vector3.ZERO)
	var missed_state := cluster.get_race_gate_presentation_state()
	_check(
		not bool(missed.get("accepted", false))
		and missed.get("reason") == &"outside_checkpoint"
		and bool(missed_state.missed_gate_recovery)
		and (missed_state.gates as Array)[0].status_id == &"missed_expected_gate"
		and _ring_position(gates[0], ^"SignalRing").is_equal_approx(Vector3(0.0, 15.0, 0.0))
		and _ring_position(gates[0], ^"TrimRing").is_equal_approx(Vector3(0.0, 9.0, 0.0))
		and _ring_scale(gates[0], ^"SignalRing").is_equal_approx(Vector3.ONE * 1.52)
		and _ring_scale(gates[0], ^"TrimRing").is_equal_approx(Vector3.ONE * 0.64),
		"an authoritative missed gate splits the expected retained rings into a recovery silhouette"
	)

	root.remove_child(cluster)
	await process_frame
	root.add_child(cluster)
	await process_frame
	await process_frame
	gates = _gates(route_root)
	_check(
		bool(cluster.get_race_gate_presentation_state().missed_gate_recovery)
		and _gate_ids(gates) == retained_ids
		and _ring_position(gates[0], ^"SignalRing").is_equal_approx(Vector3(0.0, 15.0, 0.0)),
		"detach and re-entry retain both gate identity and missed-gate recovery geometry"
	)

	var gate_one: Dictionary = binding.call(
		"submit_race_position", ROUTE.get_checkpoint_position(0)
	)
	var recovered := cluster.get_race_gate_presentation_state()
	_check(
		bool(gate_one.get("accepted", false))
		and not bool(recovered.missed_gate_recovery)
		and int(recovered.next_checkpoint_index) == 1
		and (recovered.gates as Array)[0].status_id == &"cleared"
		and (recovered.gates as Array)[1].status_id == &"next_gate"
		and _ring_position(gates[0], ^"SignalRing").is_equal_approx(Vector3(0.0, 12.0, 0.0))
		and _ring_scale(gates[0], ^"SignalRing").is_equal_approx(Vector3.ONE * 0.72)
		and _ring_scale(gates[1], ^"SignalRing").is_equal_approx(Vector3.ONE * 1.28),
		"accepting the expected gate recenters recovery geometry and advances the open target"
	)
	for checkpoint_index in range(1, ROUTE.get_checkpoint_count()):
		_check(bool((binding.call(
			"submit_race_position", ROUTE.get_checkpoint_position(checkpoint_index)
		) as Dictionary).get("accepted", false)),
		"race authority accepts ordered checkpoint %d" % (checkpoint_index + 1))
	var completed := cluster.get_race_gate_presentation_state()
	var all_complete: bool = completed.state_id == &"completed"
	for gate_index in gates.size():
		all_complete = all_complete \
			and (completed.gates as Array)[gate_index].status_id == &"completed" \
			and _ring_scale(gates[gate_index], ^"SignalRing").is_equal_approx(Vector3.ONE * 1.22) \
			and _ring_position(gates[gate_index], ^"SignalRing").is_equal_approx(Vector3(0.0, 13.5, 0.0)) \
			and _ring_position(gates[gate_index], ^"TrimRing").is_equal_approx(Vector3(0.0, 10.5, 0.0))
	_check(
		all_complete
		and _route_counts(route_root) == initial_counts
		and not bool(completed.checkpoint_authority)
		and not bool(completed.gameplay_authority)
		and not bool(completed.reward_authority),
		"completion gives every retained gate a wide double-ring silhouette without authority or node growth"
	)

	var reset: Dictionary = binding.call("reset_race")
	var reset_state := cluster.get_race_gate_presentation_state()
	_check(
		bool(reset.get("accepted", false))
		and reset_state.state_id == &"reset"
		and _gate_ids(gates) == retained_ids
		and _ring_scale(gates[0], ^"SignalRing").is_equal_approx(Vector3.ONE)
		and _ring_position(gates[0], ^"SignalRing").is_equal_approx(Vector3(0.0, 12.0, 0.0)),
		"reset restores authored transforms on the same collision-free gate roster"
	)
	var restarted: Dictionary = binding.call("start_race")
	var restarted_state := cluster.get_race_gate_presentation_state()
	_check(
		bool(restarted.get("accepted", false))
		and int(restarted_state.generation) > int(reset_state.generation)
		and _gate_ids(gates) == retained_ids
		and _route_counts(route_root) == initial_counts,
		"a new race generation reuses the exact retained gate nodes and frozen roster"
	)
	_check(bool((binding.call("advance_race", 123.0) as Dictionary).get("accepted", false)),
		"caller physics produces the authoritative timeout snapshot")
	var timed_out := cluster.get_race_gate_presentation_state()
	var timeout_geometry := _ring_transforms(gates)
	_check(
		timed_out.state_id == &"failed"
		and timed_out.terminal_state == &"timed_out"
		and timed_out.failure_reason == &"timeout"
		and _every_gate_has_status(timed_out, &"timed_out")
		and _ring_scale(gates[0], ^"SignalRing").is_equal_approx(Vector3(1.34, 0.28, 1.34))
		and _ring_scale(gates[3], ^"TrimRing").is_equal_approx(Vector3(0.66, 1.42, 0.66))
		and timeout_geometry != authored_ring_transforms,
		"timeout compresses every retained route gate into a distinct non-colour hourglass silhouette"
	)

	var failed_snapshot := _terminal_snapshot(timed_out, &"failed", &"engine_failure")
	_check(bool((cluster.call("_apply_race_gate_presentation", failed_snapshot) as Dictionary).accepted),
		"the presenter consumes a detached generic-failure snapshot")
	var failed_state := cluster.get_race_gate_presentation_state()
	var failed_geometry := _ring_transforms(gates)
	_check(
		failed_state.terminal_state == &"failed"
		and _every_gate_has_status(failed_state, &"failed")
		and _ring_scale(gates[0], ^"SignalRing").is_equal_approx(Vector3(1.36, 0.42, 0.74))
		and failed_geometry != timeout_geometry,
		"generic failure crosses the proportions of every retained route gate"
	)

	var aborted_snapshot := _terminal_snapshot(timed_out, &"aborted", &"caller_abort")
	_check(bool((cluster.call("_apply_race_gate_presentation", aborted_snapshot) as Dictionary).accepted),
		"the presenter consumes a detached aborted snapshot")
	var aborted_state := cluster.get_race_gate_presentation_state()
	var aborted_geometry := _ring_transforms(gates)
	_check(
		aborted_state.terminal_state == &"aborted"
		and _every_gate_has_status(aborted_state, &"aborted")
		and _ring_position(gates[0], ^"SignalRing").is_equal_approx(Vector3(-2.8, 14.0, 0.0))
		and (gates[3].get_node(^"TrimRing") as MeshInstance3D).rotation_degrees.is_equal_approx(
			Vector3(90.0, 0.0, 24.0)
		)
		and aborted_geometry != failed_geometry,
		"abort splits and tilts every retained route gate into a third non-colour silhouette"
	)
	_check(
		_gate_ids(gates) == retained_ids
		and _route_counts(route_root) == initial_counts
		and int(aborted_state.node_delta) == 0
		and int(aborted_state.light_delta) == 0
		and int(aborted_state.collision_delta) == 0,
		"all terminal cues reuse the exact route roster without nodes, lights, or collision"
	)

	var failure_reset: Dictionary = binding.call("reset_race")
	_check(
		bool(failure_reset.get("accepted", false))
		and _gate_ids(gates) == retained_ids
		and _ring_transforms(gates) == authored_ring_transforms,
		"failure reset restores every exact authored ring transform on the retained gate nodes"
	)
	var failure_restart: Dictionary = binding.call("start_race")
	_check(
		bool(failure_restart.get("accepted", false))
		and int(cluster.get_race_gate_presentation_state().generation) > int(timed_out.generation)
		and _gate_ids(gates) == retained_ids,
		"the next authority generation starts on the same restored gate nodes"
	)

	cluster.queue_free()
	for _frame in 5:
		await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("CINDER_RACE_GATE_PRESENTATION_STATE_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _gates(route_root: Node3D) -> Array[Node3D]:
	var gates: Array[Node3D] = []
	for gate_name in [
		^"RouteBeaconAlpha", ^"RouteBeaconBravo", ^"RouteBeaconCharlie", ^"RouteBeaconDelta"
	]:
		gates.append(route_root.get_node(gate_name) as Node3D)
	return gates


func _gate_ids(gates: Array[Node3D]) -> Array:
	return gates.map(func(gate: Node3D) -> int: return gate.get_instance_id())


func _ring_scale(gate: Node3D, ring_path: NodePath) -> Vector3:
	return (gate.get_node(ring_path) as MeshInstance3D).scale


func _ring_position(gate: Node3D, ring_path: NodePath) -> Vector3:
	return (gate.get_node(ring_path) as MeshInstance3D).position


func _route_counts(route_root: Node3D) -> Dictionary:
	return {
		"descendants": route_root.find_children("*", "", true, false).size(),
		"meshes": route_root.find_children("*", "MeshInstance3D", true, false).size(),
		"lights": route_root.find_children("*", "Light3D", true, false).size(),
		"collision_objects": route_root.find_children("*", "CollisionObject3D", true, false).size(),
	}


func _ring_transforms(gates: Array[Node3D]) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for gate in gates:
		transforms.append((gate.get_node(^"SignalRing") as MeshInstance3D).transform)
		transforms.append((gate.get_node(^"TrimRing") as MeshInstance3D).transform)
	return transforms


func _every_gate_has_status(snapshot: Dictionary, status_id: StringName) -> bool:
	for gate_state: Dictionary in snapshot.get("gates", []) as Array:
		if StringName(gate_state.get("status_id", &"")) != status_id:
			return false
	return (snapshot.get("gates", []) as Array).size() == gates_count()


func gates_count() -> int:
	return 4


func _terminal_snapshot(source: Dictionary, state_id: StringName, reason: StringName) -> Dictionary:
	return {
		"activity_id": &"cinder_reach_checkpoint_route",
		"state_id": state_id,
		"session_generation": int(source.generation),
		"next_checkpoint_index": int(source.next_checkpoint_index),
		"checkpoint_count": int(source.checkpoint_count),
		"failure_reason": reason,
	}.duplicate(true)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)
