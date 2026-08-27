extends SceneTree

## Focused retained-geometry proof for the Cinder race return landmark.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const ROUTE: ActivityDefinition = preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const PLATFORM_PATH := ^"ExtractionPlatform/CinderReachPlatform"
const SUPPORTS_PATH := ^"RaceReturnCrownSupports"
const HEADER_PATH := ^"RaceReturnCrownHeader"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding")
	var platform := cluster.get_node(PLATFORM_PATH) as Node3D
	var supports := platform.get_node(SUPPORTS_PATH) as MultiMeshInstance3D
	var header := platform.get_node(HEADER_PATH) as MeshInstance3D
	var retained_ids := [supports.get_instance_id(), header.get_instance_id()]
	var initial_counts := _roster(platform)
	var idle := _shape(supports, header)
	_check(
		idle.id == &"idle" and is_equal_approx(idle.rake_degrees, 21.0)
			and header.position.is_equal_approx(NearbySectorCluster.RACE_RETURN_CROWN_HEADER_POSITION),
		"idle keeps the tall outward-raked endpoint arch"
	)

	_check(bool((binding.call("start_race") as Dictionary).accepted), "authority starts the retained race")
	var active := _shape(supports, header)
	_check(
		active.id == &"active" and is_equal_approx(active.rake_degrees, 7.0)
			and header.position.is_equal_approx(NearbySectorCluster.RACE_RETURN_CROWN_ACTIVE_HEADER_POSITION)
			and active.transforms != idle.transforms,
		"countdown/active lowers the same crown into a compact flight portal"
	)
	_check(bool((binding.call("advance_race", 3.0) as Dictionary).accepted), "authority enters active flight")
	for checkpoint_index in range(4):
		_check(bool((binding.call(
			"submit_race_position", ROUTE.get_checkpoint_position(checkpoint_index)
		) as Dictionary).accepted), "authority accepts ordered checkpoint %d" % (checkpoint_index + 1))
	var returning := _shape(supports, header)
	_check(
		returning.id == &"return" and is_equal_approx(returning.rake_degrees, -27.0)
			and returning.transforms != active.transforms,
		"the actual platform return checkpoint closes the supports into a pointed finish arch"
	)
	_check(bool((binding.call(
		"submit_race_position", ROUTE.get_checkpoint_position(4)
	) as Dictionary).accepted), "authority accepts the real platform finish")
	var completed := _shape(supports, header)
	_check(
		completed.id == &"completed" and is_equal_approx(completed.rake_degrees, 0.0)
			and header.position.is_equal_approx(NearbySectorCluster.RACE_RETURN_CROWN_COMPLETED_HEADER_POSITION)
			and completed.transforms != returning.transforms,
		"completion lifts the retained header over a square upright completion frame"
	)
	_check(
		[supports.get_instance_id(), header.get_instance_id()] == retained_ids
			and _roster(platform) == initial_counts
			and supports.multimesh.instance_count == 2,
		"all state silhouettes reuse the actual two-support/header roster without growth"
	)

	cluster.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("CINDER_RACE_RETURN_STATE_SHAPE_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("CINDER_RACE_RETURN_STATE_SHAPE_TEST_OK")
	quit(0 if _failures.is_empty() else 1)


func _shape(supports: MultiMeshInstance3D, header: MeshInstance3D) -> Dictionary:
	var transforms: Array = supports.get_meta(&"presentation_instance_transforms", []) as Array
	var first := transforms[0] as Transform3D
	return {
		"id": supports.get_meta(&"presentation_shape_id", &""),
		"rake_degrees": rad_to_deg(atan2(-first.basis.y.x, first.basis.y.y)),
		"transforms": transforms,
		"header_position": header.position,
	}


func _roster(platform: Node3D) -> Dictionary:
	return {
		"nodes": platform.find_children("RaceReturnCrown*", "", true, false).size(),
		"meshes": platform.find_children("RaceReturnCrown*", "MeshInstance3D", true, false).size(),
		"lights": platform.find_children("RaceReturnCrown*", "Light3D", true, false).size(),
		"collisions": platform.find_children("RaceReturnCrown*", "CollisionObject3D", true, false).size(),
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		print("FAIL: ", message)
