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
		^"ExtractionPlatform/CinderReachPlatform/AbandonedStructureScanPresentation"
	) as Node3D
	var initial_counts := _presentation_counts(presentation)
	var initial := cluster.get_structure_scan_presentation_state()
	_check(
		initial.state_id == &"available"
		and is_equal_approx(float(initial.port_energy), 0.45)
		and is_equal_approx(float(initial.starboard_energy), 0.45),
		"the production derelict silhouette begins with a restrained available cue"
	)

	var started: Dictionary = binding.call(
		"start_structure_scan", CinderAbandonedStructureScanActivity.APPROACH_ANCHOR
	)
	var active := cluster.get_structure_scan_presentation_state()
	_check(
		bool(started.get("accepted", false))
		and active.state_id == &"scanning"
		and is_equal_approx(float(active.progress), 0.0)
		and float(active.port_energy) > float(active.starboard_energy)
		and is_equal_approx(float(active.sign_scale), 2.15),
		"scan start makes progress readable through the fixed datum lights and sign"
	)
	root.remove_child(cluster)
	await process_frame
	root.add_child(cluster)
	await process_frame
	var half_step: Dictionary = binding.call("advance_structure_scan", 2.0)
	var halfway := cluster.get_structure_scan_presentation_state()
	_check(
		bool(half_step.get("accepted", false))
		and halfway.state_id == &"scanning"
		and is_equal_approx(float(halfway.progress), 0.5)
		and is_equal_approx(float(halfway.port_energy), float(halfway.starboard_energy)),
		"detach/re-entry retains authority state and progress crosses the datum lights at midpoint"
	)
	var completed: Dictionary = binding.call("advance_structure_scan", 2.0)
	var resolved := cluster.get_structure_scan_presentation_state()
	var resolved_audit := cluster.get_structure_scan_presentation_audit()
	_check(
		bool(completed.get("accepted", false))
		and resolved.state_id == &"completed"
		and is_equal_approx(float(resolved.progress), 1.0)
		and is_equal_approx(float(resolved.port_energy), 2.8)
		and is_equal_approx(float(resolved.starboard_energy), 2.8)
		and (resolved.port_color as Color).is_equal_approx(resolved.starboard_color as Color)
		and is_equal_approx(float(resolved.sign_scale), 2.35)
		and bool(resolved_audit.valid),
		"completion resolves to two steady cyan practicals and a stronger completed silhouette"
	)
	var reward: Dictionary = binding.call("request_structure_scan_reward")
	_check(
		bool(reward.get("accepted", false))
		and not bool((reward.get("reward_request", {}) as Dictionary).get("granted", true))
		and cluster.get_structure_scan_presentation_state() == resolved,
		"reward request remains caller-owned and cannot mutate completed presentation"
	)
	var reset: Dictionary = binding.call("reset_structure_scan")
	var reset_state := cluster.get_structure_scan_presentation_state()
	var audit := cluster.get_structure_scan_presentation_audit()
	_check(
		bool(reset.get("accepted", false))
		and reset_state.state_id == &"reset"
		and is_equal_approx(float(reset_state.port_energy), 0.2)
		and is_equal_approx(float(reset_state.starboard_energy), 0.2)
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
		print("CINDER_STRUCTURE_SCAN_PRESENTATION_STATE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		quit(1)
