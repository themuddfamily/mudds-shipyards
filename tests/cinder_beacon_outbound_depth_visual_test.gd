extends SceneTree

## Focused contract for the steady, colour-independent four-step silhouette read
## down Cinder Reach's real outbound beacon chain.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const BEACON_NAMES := [
	"RouteBeaconAlpha", "RouteBeaconBravo", "RouteBeaconCharlie", "RouteBeaconDelta",
]
const EXPECTED_ANGLES: Array[float] = [-36.0, -12.0, 12.0, 36.0]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var route := cluster.get_node(^"RouteBeacons") as Node3D
	var original_descendants := route.find_children("*", "", true, false).size()
	var original_lights := route.find_children("*", "Light3D", true, false).size()
	_assert_authored_depth_sequence(route)

	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var positions := cluster.get_route_beacon_positions()
	var started := binding.start_beacon_traversal(positions[0])
	_check(bool(started.get("accepted", false)), "the production traversal can target Alpha")
	_assert_authored_depth_sequence(route)
	var advanced := binding.submit_beacon_traversal(0, positions[0])
	_check(bool(advanced.get("accepted", false)), "the production traversal can advance to Bravo")
	_assert_authored_depth_sequence(route)
	var reset := binding.reset_beacon_traversal()
	_check(bool(reset.get("accepted", false)), "the production traversal resets")
	_assert_authored_depth_sequence(route)

	_check(
		route.find_children("*", "", true, false).size() == original_descendants
		and route.find_children("*", "Light3D", true, false).size() == original_lights
		and route.find_children("*", "CollisionObject3D", true, false).is_empty()
		and route.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the steady silhouette cue adds no nodes, lights, or collision authority"
	)
	cluster.queue_free()
	await process_frame
	_finish()


func _assert_authored_depth_sequence(route: Node3D) -> void:
	var anchors := NearbySectorCluster.ROUTE_BEACON_SPECS
	var previous_angle := -INF
	var exact := true
	for index in BEACON_NAMES.size():
		var beacon := route.get_node(NodePath(BEACON_NAMES[index])) as Node3D
		var counter := beacon.get_node(^"CounterVane") as MeshInstance3D
		var spar := beacon.get_node(^"VaneSpar") as MeshInstance3D
		var angle := float(beacon.get_meta(&"outbound_chevron_angle_degrees", INF))
		exact = exact \
			and beacon.position.is_equal_approx(anchors[index]["position"] as Vector3) \
			and is_equal_approx(angle, EXPECTED_ANGLES[index]) \
			and is_equal_approx(counter.rotation_degrees.z, angle) \
			and is_equal_approx(spar.rotation_degrees.z, -angle) \
			and angle > previous_angle \
			and absf(angle) <= 36.0
		previous_angle = angle
	_check(
		exact,
		"Alpha through Delta retain the ordered -36/-12/+12/+36 degree chevrons at unchanged anchors"
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_BEACON_OUTBOUND_DEPTH_VISUAL_TEST_OK assertions=%d" % _assertions)
		quit(0)
		return
	push_error(
		"CINDER_BEACON_OUTBOUND_DEPTH_VISUAL_TEST_FAILED assertions=%d failures=%d" % [
			_assertions, _failures.size(),
		]
	)
	quit(1)
