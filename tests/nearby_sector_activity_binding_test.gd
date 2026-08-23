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
	var binding: Node = cluster.get_node_or_null(^"ActivityBinding")
	_check(binding != null, "the authored nearby-sector scene owns one activity binding")
	if binding != null:
		var audit: Dictionary = binding.call("audit")
		_check(bool(audit.get("valid", false)), "the existing convoy host is valid inside the authored cluster envelope")
		_check(
			StringName(audit.get("activity_id", &"")) == &"cinder_reach_emberline_convoy"
			and not bool(audit.get("gameplay_authority", true)),
			"the binding publishes the convoy as a production activity without gameplay authority"
		)
		var started: Dictionary = binding.call("start_convoy")
		_check(bool(started.get("accepted", false)), "the cluster owner starts the existing convoy lifecycle")
		var advanced: Dictionary = binding.call("advance_convoy", 0.25, Vector3(84.0, -68.0, -724.0))
		_check(bool(advanced.get("accepted", false)), "the owner advances one caller-supplied convoy physics step")
		var reset: Dictionary = binding.call("reset_convoy")
		_check(bool(reset.get("accepted", false)), "the owner can reset the convoy without changing authored route data")
		var race_started: Dictionary = binding.call("start_race")
		_check(bool(race_started.get("accepted", false)), "the owner starts the existing authored beacon race")
		var race_advanced: Dictionary = binding.call("advance_race", 0.25)
		_check(bool(race_advanced.get("accepted", false)), "the owner advances the race on caller-supplied physics time")
		var race_checkpoint: Dictionary = binding.call("submit_race_position", Vector3(16.0, -9.0, -240.0))
		_check(bool(race_checkpoint.get("accepted", false)), "the owner submits the first authored beacon checkpoint")
		var race_reset: Dictionary = binding.call("reset_race")
		_check(bool(race_reset.get("accepted", false)), "the owner resets the race without changing its route")
		var patrol_started: Dictionary = binding.call("start_patrol")
		_check(bool(patrol_started.get("accepted", false)), "the owner starts the existing authored beacon patrol")
		var patrol_advanced: Dictionary = binding.call("advance_patrol", 0.25, Vector3(16.0, -9.0, -240.0))
		_check(bool(patrol_advanced.get("accepted", false)), "the owner advances patrol on caller-supplied physics time")
		var patrol_reset: Dictionary = binding.call("reset_patrol")
		_check(bool(patrol_reset.get("accepted", false)), "the owner resets patrol without changing its route")
	cluster.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS nearby_sector_activity_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
