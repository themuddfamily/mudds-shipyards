extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")

var _assertions := 0
var _failures: Array[String] = []
var _mining_presentations: Array[Dictionary] = []
var _structure_scan_presentations: Array[Dictionary] = []
var _beacon_traversal_presentations: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node_or_null(^"ActivityBinding") as NearbySectorActivityBinding
	_check(binding != null, "the authored nearby-sector scene owns one activity binding")
	if binding != null:
		var production_observers := binding.get_presentation_observer_snapshot()
		_check(
			int(production_observers.mining_observers) == 2
			and int(production_observers.structure_scan_observers) == 2
			and int(production_observers.beacon_traversal_observers) == 2
			and int(production_observers.observer_limit) == 3
			and not bool(production_observers.activity_authority)
			and not bool(production_observers.reward_authority)
			and not bool(production_observers.audio_authority)
			and not bool(production_observers.visual_authority),
			"bounded presentation fan-out starts with one audio and one visual observer without authority"
		)
		var mining_probe := Callable(self, "_on_mining_presentation")
		var scan_probe := Callable(self, "_on_structure_scan_presentation")
		var beacon_probe := Callable(self, "_on_beacon_traversal_presentation")
		var mining_bound := binding.bind_mining_presentation(mining_probe)
		var scan_bound := binding.bind_structure_scan_presentation(scan_probe)
		var beacon_bound := binding.bind_beacon_traversal_presentation(beacon_probe)
		_check(
			bool(mining_bound.accepted) and bool(scan_bound.accepted) and bool(beacon_bound.accepted)
			and bool(mining_bound.initial_snapshot_delivered)
			and bool(scan_bound.initial_snapshot_delivered)
			and bool(beacon_bound.initial_snapshot_delivered)
			and _mining_presentations.size() == 1
			and _structure_scan_presentations.size() == 1
			and _beacon_traversal_presentations.size() == 1,
			"each added observer receives exactly one detached current snapshot"
		)
		var duplicate_mining := binding.bind_mining_presentation(mining_probe)
		var duplicate_scan := binding.bind_structure_scan_presentation(scan_probe)
		var duplicate_beacon := binding.bind_beacon_traversal_presentation(beacon_probe)
		_check(
			not bool(duplicate_mining.accepted) and duplicate_mining.reason == &"observer_already_bound"
			and not bool(duplicate_scan.accepted) and duplicate_scan.reason == &"observer_already_bound"
			and not bool(duplicate_beacon.accepted) and duplicate_beacon.reason == &"observer_already_bound"
			and _mining_presentations.size() == 1
			and _structure_scan_presentations.size() == 1
			and _beacon_traversal_presentations.size() == 1,
			"duplicate observer registration is rejected without replay"
		)
		var mining_overflow := binding.bind_mining_presentation(scan_probe)
		var scan_overflow := binding.bind_structure_scan_presentation(beacon_probe)
		var beacon_overflow := binding.bind_beacon_traversal_presentation(mining_probe)
		_check(
			not bool(mining_overflow.accepted) and mining_overflow.reason == &"observer_limit_reached"
			and not bool(scan_overflow.accepted) and scan_overflow.reason == &"observer_limit_reached"
			and not bool(beacon_overflow.accepted) and beacon_overflow.reason == &"observer_limit_reached"
			and _mining_presentations.size() == 1
			and _structure_scan_presentations.size() == 1
			and _beacon_traversal_presentations.size() == 1,
			"the explicit three-observer bound rejects overflow without delivery"
		)
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
		var cargo_started: Dictionary = binding.call("start_cargo_run")
		_check(
			not bool(cargo_started.get("accepted", true))
			and cargo_started.get("reason", &"") == &"not_ready",
			"an unoccupied production berth cannot start a cargo delivery activity"
		)
		var cargo_loaded: Dictionary = binding.call("submit_cargo_phase", &"load_crate")
		_check(not bool(cargo_loaded.get("accepted", true)), "cargo phases fail closed without a live source craft")
		var cargo_cleared: Dictionary = binding.call("submit_cargo_phase", &"clear_gate")
		_check(not bool(cargo_cleared.get("accepted", true)), "the route gate cannot advance an unavailable cargo run")
		var cargo_docked: Dictionary = binding.call("submit_cargo_phase", &"dock_platform")
		_check(not bool(cargo_docked.get("accepted", true)), "the platform phase cannot invent cargo source authority")
		var cargo_reset: Dictionary = binding.call("reset_cargo_run")
		_check(not bool(cargo_reset.get("accepted", true)), "an unavailable cargo run remains fail-closed on reset")
		var station_unbound: Dictionary = binding.call("start_station_defense")
		_check(
			not bool(station_unbound.get("accepted", true))
			and station_unbound.get("reason", &"") == &"station_defense_unbound",
			"station defense remains fail-closed until Main injects its existing encounter authority"
		)
		var fake_director := Node.new()
		var fake_target := Node3D.new()
		var fake_anchor := Node3D.new()
		cluster.add_child(fake_director)
		cluster.add_child(fake_target)
		cluster.add_child(fake_anchor)
		var rejected_binding: Dictionary = binding.call(
			"bind_station_defense", fake_director, fake_target, fake_anchor
		)
		_check(
			not bool(rejected_binding.get("accepted", true))
			and rejected_binding.get("reason", &"") == &"wrong_encounter_authority",
			"the binding refuses to replace the existing EncounterScenarioDirector authority"
		)
		var mining_start: Dictionary = binding.call(
			"start_mining_activity", Vector3(60.0, -66.0, -605.0)
		)
		_check(bool(mining_start.get("accepted", false)), "the owner starts the bounded modern mining activity at its authored approach")
		var mining_step: Dictionary = binding.call("advance_mining_activity", 6.0)
		_check(bool(mining_step.get("accepted", false)), "the mining activity completes on caller-supplied extraction time")
		var reward: Dictionary = binding.call("request_mining_reward")
		_check(
			bool(reward.get("accepted", false))
			and not bool((reward.get("reward_request", {}) as Dictionary).get("granted", true)),
			"completion emits a caller-owned reward request without granting inventory"
		)
		var mining_reset: Dictionary = binding.call("reset_mining_activity")
		_check(bool(mining_reset.get("accepted", false)), "the mining activity resets its progress and reward request")
		var scan_start: Dictionary = binding.call(
			"start_structure_scan", Vector3(60.0, -66.0, -680.0)
		)
		_check(bool(scan_start.get("accepted", false)), "the owner starts the bounded abandoned-structure scan")
		var scan_step: Dictionary = binding.call("advance_structure_scan", 4.0)
		_check(bool(scan_step.get("accepted", false)), "the scan completes on caller-supplied time")
		var scan_reward: Dictionary = binding.call("request_structure_scan_reward")
		_check(
			bool(scan_reward.get("accepted", false))
			and not bool((scan_reward.get("reward_request", {}) as Dictionary).get("granted", true)),
			"the scan emits a non-granting caller-owned reward request"
		)
		var scan_reset: Dictionary = binding.call("reset_structure_scan")
		_check(bool(scan_reset.get("accepted", false)), "the scan resets without changing the authored anchor")
		var beacon_start: Dictionary = binding.call("start_beacon_traversal", Vector3(16.0, -9.0, -240.0))
		_check(bool(beacon_start.get("accepted", false)), "the owner starts the authored beacon traversal")
		for index in 4:
			var beacon_positions: Array[Vector3] = [Vector3(16.0, -9.0, -240.0), Vector3(32.0, -26.0, -372.0), Vector3(46.0, -44.0, -498.0), Vector3(30.0, -46.0, -600.0)]
			var beacon_position: Vector3 = beacon_positions[index]
			var beacon_step: Dictionary = binding.call("submit_beacon_traversal", index, beacon_position)
			_check(bool(beacon_step.get("accepted", false)), "the traversal accepts authored beacon %d" % (index + 1))
		var beacon_reward: Dictionary = binding.call("request_beacon_traversal_reward")
		_check(bool(beacon_reward.get("accepted", false)), "the completed traversal emits a reward request")
		var beacon_reset: Dictionary = binding.call("reset_beacon_traversal")
		_check(bool(beacon_reset.get("accepted", false)), "the traversal resets without changing beacon anchors")
		_check(
			_mining_presentations.size() == 5
			and _structure_scan_presentations.size() == 5
			and _beacon_traversal_presentations.size() == 8
			and StringName(_mining_presentations[-1].activity_id) == &"cinder_platform_mining_run"
			and StringName(_structure_scan_presentations[-1].activity_id) == &"cinder_derelict_structure_scan"
			and StringName(_beacon_traversal_presentations[-1].activity_id) == &"cinder_debris_beacon_traversal",
			"each observer receives exactly one snapshot per mining, scan, and traversal update"
		)
		_check(
			bool(binding.unbind_mining_presentation(mining_probe).accepted)
			and bool(binding.unbind_structure_scan_presentation(scan_probe).accepted)
			and bool(binding.unbind_beacon_traversal_presentation(beacon_probe).accepted),
			"explicit unbind removes each caller-owned presentation observer"
		)
		var production_parent := cluster.get_parent()
		production_parent.remove_child(cluster)
		await process_frame
		var detached_observers := binding.get_presentation_observer_snapshot()
		_check(
			int(detached_observers.mining_observers) == 0
			and int(detached_observers.structure_scan_observers) == 0
			and int(detached_observers.beacon_traversal_observers) == 0,
			"whole-cluster detach clears every presentation observer"
		)
		production_parent.add_child(cluster)
		await process_frame
		await process_frame
		var reentered_observers := binding.get_presentation_observer_snapshot()
		_check(
			int(reentered_observers.mining_observers) == 2
			and int(reentered_observers.structure_scan_observers) == 2
			and int(reentered_observers.beacon_traversal_observers) == 2
			and bool(binding.get_cinder_field_audio_binding_snapshot().attached)
			and bool(cluster.get_mining_platform_presentation_audit().valid)
			and bool(cluster.get_structure_scan_presentation_audit().valid)
			and bool(cluster.get_beacon_traversal_presentation_audit().valid),
			"re-entry restores one audio and one visual observer with current presentation state"
		)
	cluster.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _on_mining_presentation(snapshot: Dictionary) -> void:
	_mining_presentations.append(snapshot)


func _on_structure_scan_presentation(snapshot: Dictionary) -> void:
	_structure_scan_presentations.append(snapshot)


func _on_beacon_traversal_presentation(snapshot: Dictionary) -> void:
	_beacon_traversal_presentations.append(snapshot)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS nearby_sector_activity_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
