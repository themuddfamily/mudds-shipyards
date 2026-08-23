extends SceneTree

## Player-path proof for the nearby Cinder relay patrol. One call per physics
## sample must discover beacon arrival and advance continuous station keeping.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var initial := (binding.get_snapshot().get("patrol", {}) as Dictionary)
	_check(
		is_equal_approx(
			float(initial.get("dwell_seconds", 0.0)),
			NearbySectorActivityBinding.CINDER_PATROL_DWELL_SECONDS
		),
		"the Cinder patrol authors a two-second station-keeping stop at each route point"
	)

	var started := binding.start_patrol()
	var travel := binding.advance_patrol(0.5, Vector3.ZERO)
	_check(
		bool(started.get("accepted", false))
		and bool(travel.get("accepted", false))
		and travel.get("phase_id", &"") == &"travel"
		and int(travel.get("next_checkpoint_index", -1)) == 0,
		"flight outside the first beacon advances patrol time without inventing an arrival"
	)

	var first_point: Vector3 = ROUTE.get_checkpoint_position(0)
	var partial := binding.advance_patrol(0.75, first_point)
	_check(
		bool(partial.get("accepted", false))
		and partial.get("phase_id", &"") == &"dwell"
		and int(partial.get("dwell_checkpoint_index", -1)) == 0
		and is_equal_approx(float(partial.get("dwell_elapsed_seconds", -1.0)), 0.75),
		"one player physics sample enters the beacon and begins visible station keeping"
	)

	var interrupted := binding.advance_patrol(
		0.25, first_point + Vector3(ROUTE.checkpoint_radius + 1.0, 0.0, 0.0)
	)
	_check(
		interrupted.get("reason", &"") == &"dwell_interrupted"
		and is_zero_approx(float(interrupted.get("dwell_elapsed_seconds", -1.0)))
		and int(interrupted.get("completed_checkpoint_count", -1)) == 0,
		"leaving the beacon resets the continuous hold instead of crediting a fly-through"
	)

	var secured := binding.advance_patrol(
		NearbySectorActivityBinding.CINDER_PATROL_DWELL_SECONDS, first_point
	)
	_check(
		secured.get("reason", &"") == &"dwell_completed"
		and int(secured.get("next_checkpoint_index", -1)) == 1
		and int(secured.get("completed_checkpoint_count", -1)) == 1,
		"one uninterrupted two-second hold commits the first authored checkpoint"
	)

	var final: Dictionary = secured
	for checkpoint_index in range(1, ROUTE.get_checkpoint_count()):
		final = binding.advance_patrol(
			NearbySectorActivityBinding.CINDER_PATROL_DWELL_SECONDS,
			ROUTE.get_checkpoint_position(checkpoint_index)
		)
	_check(
		final.get("state_id", &"") == &"completed"
		and int(final.get("completed_checkpoint_count", -1)) == ROUTE.get_checkpoint_count()
		and int(final.get("next_checkpoint_index", -1)) == ROUTE.get_checkpoint_count(),
		"holding the complete Cinder beacon chain finishes the playable patrol once"
	)

	cluster.queue_free()
	for _frame in 4:
		await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_NEARBY_PATROL_STATION_KEEPING_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		quit(1)
