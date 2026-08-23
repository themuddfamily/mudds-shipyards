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
	var presentation := cluster.get_node(
		^"ExtractionPlatform/CinderReachPlatform/MiningActivityPresentation"
	) as Node3D
	var initial_counts := _presentation_counts(presentation)
	var initial := cluster.get_mining_activity_presentation_state()
	_check(
		initial.state_id == &"available"
		and is_equal_approx(float(initial.port_energy), 0.7)
		and is_equal_approx(float(initial.starboard_energy), 0.7),
		"the production mining silhouette begins with a restrained available cue"
	)

	var started: Dictionary = binding.call(
		"start_mining_activity", CinderMiningPlatformActivity.APPROACH_ANCHOR
	)
	var active := cluster.get_mining_activity_presentation_state()
	_check(
		bool(started.get("accepted", false))
		and active.state_id == &"extracting"
		and is_equal_approx(float(active.progress), 0.0)
		and float(active.port_energy) < float(active.starboard_energy)
		and is_equal_approx(float(active.sign_scale), 2.55),
		"activity start makes extraction readable through asymmetric crown lights and the fixed sign"
	)
	root.remove_child(cluster)
	await process_frame
	root.add_child(cluster)
	await process_frame
	var half_step: Dictionary = binding.call("advance_mining_activity", 3.0)
	var halfway := cluster.get_mining_activity_presentation_state()
	_check(
		bool(half_step.get("accepted", false))
		and halfway.state_id == &"extracting"
		and is_equal_approx(float(halfway.progress), 0.5)
		and is_equal_approx(float(halfway.port_energy), float(halfway.starboard_energy)),
		"detach/re-entry retains authority state and caller progress crosses the two lights at midpoint"
	)
	var completed: Dictionary = binding.call("advance_mining_activity", 3.0)
	var secured := cluster.get_mining_activity_presentation_state()
	var secured_audit := cluster.get_mining_platform_presentation_audit()
	_check(
		bool(completed.get("accepted", false))
		and secured.state_id == &"secured"
		and is_equal_approx(float(secured.progress), 1.0)
		and is_equal_approx(float(secured.port_energy), 3.4)
		and is_equal_approx(float(secured.starboard_energy), 3.4)
		and (secured.port_color as Color).is_equal_approx(secured.starboard_color as Color)
		and is_equal_approx(float(secured.sign_scale), 2.75)
		and bool(secured_audit.valid),
		"completion resolves to two steady cyan practicals and a stronger secured silhouette"
	)
	var reward: Dictionary = binding.call("request_mining_reward")
	_check(
		bool(reward.get("accepted", false))
		and not bool((reward.get("reward_request", {}) as Dictionary).get("granted", true))
		and cluster.get_mining_activity_presentation_state() == secured,
		"reward request remains caller-owned and cannot mutate the completed presentation"
	)
	var reset: Dictionary = binding.call("reset_mining_activity")
	var reset_state := cluster.get_mining_activity_presentation_state()
	var audit := cluster.get_mining_platform_presentation_audit()
	_check(
		bool(reset.get("accepted", false))
		and reset_state.state_id == &"reset"
		and is_equal_approx(float(reset_state.port_energy), 0.35)
		and is_equal_approx(float(reset_state.starboard_energy), 0.35)
		and _presentation_counts(presentation) == initial_counts
		and bool(audit.valid)
		and int(audit.state_feedback.node_delta) == 0
		and int(audit.state_feedback.light_delta) == 0
		and int(audit.state_feedback.submission_delta) == 0,
		"reset dims the fixed roster with zero renderer, light, collision, or authority growth"
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
		print("CINDER_MINING_PRESENTATION_STATE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		quit(1)
