extends SceneTree

## Focused retained-geometry proof for the real Cinder beacon traversal.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const BEACON_POSITIONS: Array[Vector3] = [
	Vector3(16.0, -9.0, -240.0),
	Vector3(32.0, -26.0, -372.0),
	Vector3(46.0, -44.0, -498.0),
	Vector3(30.0, -46.0, -600.0),
]
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
	var route_root := cluster.get_node(^"RouteBeacons") as Node3D
	var retained_ids := _beacon_visual_ids(route_root)
	var descendant_count := route_root.find_children("*", "", true, false).size()
	_assert_geometry_state(cluster, route_root, &"available", [
		&"available", &"available", &"available", &"available",
	])

	var started := binding.start_beacon_traversal(BEACON_POSITIONS[0])
	var first_generation := int(started.get("generation", -1))
	_check(
		bool(started.get("accepted", false)) and first_generation == 1,
		"the real traversal starts at the authored first beacon in one generation"
	)
	_assert_geometry_state(cluster, route_root, &"traversing", [
		&"next_target", &"pending", &"pending", &"pending",
	])
	_assert_target_geometry(route_root, 0, false)

	var alpha := binding.submit_beacon_traversal(0, BEACON_POSITIONS[0])
	_check(bool(alpha.get("accepted", false)), "the authoritative first beacon advances order")
	_assert_geometry_state(cluster, route_root, &"traversing", [
		&"cleared", &"next_target", &"pending", &"pending",
	])
	_assert_target_geometry(route_root, 1, false)

	var wrong := binding.submit_beacon_traversal(2, BEACON_POSITIONS[2])
	var wrong_state := cluster.get_beacon_traversal_presentation_state()
	_check(
		not bool(wrong.get("accepted", true))
		and wrong.get("reason") == &"out_of_order_beacon"
		and wrong_state.get("expected_beacon_name") == &"RouteBeaconBravo"
		and int(wrong_state.get("next_beacon_index", -1)) == 1,
		"wrong order names and retains the authoritative expected beacon without progress"
	)
	_assert_geometry_state(cluster, route_root, &"wrong_order", [
		&"cleared", &"wrong_order_no_progress", &"pending", &"pending",
	])
	_assert_target_geometry(route_root, 1, true)

	root.remove_child(cluster)
	await process_frame
	_check(
		_beacon_visual_ids(route_root) == retained_ids
		and cluster.get_beacon_traversal_presentation_state().get("state_id") == &"wrong_order",
		"detachment retains the exact wrong-order recovery silhouette without replay"
	)
	root.add_child(cluster)
	await process_frame
	await process_frame
	_check(
		_beacon_visual_ids(route_root) == retained_ids
		and cluster.get_beacon_traversal_presentation_state().get("state_id") == &"wrong_order"
		and cluster.get_beacon_traversal_presentation_state().get("expected_beacon_name") \
		== &"RouteBeaconBravo",
		"re-entry restores the generation-matched wrong-order recovery snapshot"
	)
	_assert_target_geometry(route_root, 1, true)

	for beacon_index in range(1, BEACON_POSITIONS.size()):
		var reached := binding.submit_beacon_traversal(
			beacon_index, BEACON_POSITIONS[beacon_index]
		)
		_check(
			bool(reached.get("accepted", false)),
			"authoritative beacon %d advances in order" % (beacon_index + 1)
		)
	var complete_state := cluster.get_beacon_traversal_presentation_state()
	_check(
		complete_state.get("state_id") == &"completed"
		and int(complete_state.get("generation", -1)) == first_generation,
		"the final beacon produces one generation-matched complete silhouette"
	)
	_assert_geometry_state(cluster, route_root, &"completed", [
		&"cleared", &"cleared", &"cleared", &"cleared",
	])
	for beacon_index in BEACON_POSITIONS.size():
		var beacon := route_root.get_node(NodePath(BEACON_NAMES[beacon_index])) as Node3D
		_check(
			(beacon.get_node(^"CounterVane") as MeshInstance3D).scale \
			.is_equal_approx(Vector3(1.6, 0.28, 1.6))
			and (beacon.get_node(^"VaneSpar") as MeshInstance3D).scale \
			.is_equal_approx(Vector3(1.6, 0.28, 1.6)),
			"completed beacon %d shares the flattened terminal plate" % (beacon_index + 1)
		)

	var reset := binding.reset_beacon_traversal()
	_check(
		bool(reset.get("accepted", false))
		and _beacon_visual_ids(route_root) == retained_ids
		and route_root.find_children("*", "", true, false).size() == descendant_count,
		"reset restores retained geometry without node growth"
	)
	_assert_geometry_state(cluster, route_root, &"reset", [
		&"reset", &"reset", &"reset", &"reset",
	])
	for beacon_index in BEACON_POSITIONS.size():
		var beacon := route_root.get_node(NodePath(BEACON_NAMES[beacon_index])) as Node3D
		_check(
			(beacon.get_node(^"CounterVane") as MeshInstance3D).scale.is_equal_approx(Vector3.ONE)
			and (beacon.get_node(^"CounterVane") as MeshInstance3D).position \
			.is_equal_approx(Vector3(0.0, -11.0, 0.0))
			and (beacon.get_node(^"VaneSpar") as MeshInstance3D).scale.is_equal_approx(Vector3.ONE),
			"reset beacon %d returns to its authored vane recipe" % (beacon_index + 1)
		)
	var restarted := binding.start_beacon_traversal(BEACON_POSITIONS[0])
	_check(
		bool(restarted.get("accepted", false))
		and int(restarted.get("generation", -1)) > first_generation
		and _beacon_visual_ids(route_root) == retained_ids,
		"a new generation reuses the exact beacon visual identities"
	)
	_assert_target_geometry(route_root, 0, false)
	var audit := cluster.get_beacon_traversal_presentation_audit()
	var state := cluster.get_beacon_traversal_presentation_state()
	_check(
		bool(audit.get("valid", false))
		and route_root.find_children("*", "CollisionObject3D", true, false).is_empty()
		and bool(state.get("static_geometry_only", false))
		and not bool(state.get("order_authority", true))
		and not bool(state.get("reward_authority", true)),
		"retained traversal geometry adds no collision, checkpoint-order, or reward authority"
	)

	cluster.queue_free()
	await process_frame
	_finish()


func _assert_geometry_state(
		cluster: NearbySectorCluster,
		route_root: Node3D,
		expected_state: StringName,
		expected_statuses: Array
	) -> void:
	var state := cluster.get_beacon_traversal_presentation_state()
	var beacons := state.get("beacons", []) as Array
	var actual_statuses: Array[StringName] = []
	for beacon_state in beacons:
		actual_statuses.append(StringName((beacon_state as Dictionary).get("status_id", &"")))
	_check(
		state.get("state_id") == expected_state
		and actual_statuses == expected_statuses
		and _geometry_matches_snapshot(route_root, beacons),
		"%s publishes and applies the exact four-beacon geometry roster" % String(expected_state)
	)


func _geometry_matches_snapshot(route_root: Node3D, states: Array) -> bool:
	if states.size() != BEACON_NAMES.size():
		return false
	for beacon_index in states.size():
		var state := states[beacon_index] as Dictionary
		var beacon := route_root.get_node(NodePath(BEACON_NAMES[beacon_index])) as Node3D
		var counter := beacon.get_node(^"CounterVane") as MeshInstance3D
		var spar := beacon.get_node(^"VaneSpar") as MeshInstance3D
		if not counter.scale.is_equal_approx(state.get("counter_scale") as Vector3) \
				or not spar.scale.is_equal_approx(state.get("spar_scale") as Vector3) \
				or not counter.position.is_equal_approx(state.get("counter_position") as Vector3) \
				or not spar.position.is_equal_approx(state.get("spar_position") as Vector3):
			return false
	return true


func _assert_target_geometry(route_root: Node3D, target_index: int, wrong_order: bool) -> void:
	var beacon := route_root.get_node(NodePath(BEACON_NAMES[target_index])) as Node3D
	var counter := beacon.get_node(^"CounterVane") as MeshInstance3D
	var spar := beacon.get_node(^"VaneSpar") as MeshInstance3D
	_check(
		(counter.position.x < -3.0 and spar.position.x > 3.0)
		if wrong_order else (
			counter.position.is_equal_approx(Vector3(0.0, -7.5, 0.0))
			and spar.scale.y >= 2.0
		),
		"expected beacon %d uses the %s hold silhouette" % [
			target_index + 1, "split recovery" if wrong_order else "open target",
		]
	)


func _beacon_visual_ids(route_root: Node3D) -> Array[int]:
	var ids: Array[int] = []
	for beacon_name in BEACON_NAMES:
		var beacon := route_root.get_node(NodePath(beacon_name)) as Node3D
		ids.append(beacon.get_instance_id())
		for child in beacon.get_children():
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
	print("CINDER_BEACON_TRAVERSAL_WORLD_GEOMETRY_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_BEACON_TRAVERSAL_WORLD_GEOMETRY_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_BEACON_TRAVERSAL_WORLD_GEOMETRY_TEST_FAILURE: ", failure)
	quit(1)
