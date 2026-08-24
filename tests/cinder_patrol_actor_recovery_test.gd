extends SceneTree

## Production-binding proof that a physical patrol actor cannot disappear and
## leave the Cinder lifecycle active forever. Reset/start remains the sole
## generation-fenced recovery path for a replacement actor.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const Patrol := preload("res://scripts/activities/patrol_activity.gd")

var _assertions := 0
var _failures: Array[String] = []
var _presentations: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	binding.bind_patrol_presentation(_on_patrol_presentation)

	var legacy_start := binding.start_patrol()
	var legacy_advance := binding.advance_patrol(0.1, Vector3.ZERO)
	_check(
		bool(legacy_start.get("accepted", false))
		and bool(legacy_advance.get("accepted", false))
		and legacy_advance.get("state_id", &"") == &"active"
		and legacy_advance.get("patrol_actor_status_id", &"") == &"unbound",
		"legacy public start and position-only advance remain source compatible"
	)
	binding.reset_patrol()
	var pre_tick_actor := Node3D.new()
	root.add_child(pre_tick_actor)
	var pre_tick_start := binding.start_patrol(pre_tick_actor)
	pre_tick_actor.queue_free()
	await process_frame
	var pre_tick_loss := binding.get_snapshot().get("patrol", {}) as Dictionary
	_check(
		bool(pre_tick_start.get("accepted", false))
		and pre_tick_loss.get("state_id", &"") == &"failed"
		and pre_tick_loss.get("failure_reason", &"") == &"patrol_actor_lost"
		and is_zero_approx(float(pre_tick_loss.get("current_time_seconds", -1.0))),
		"the public binding arms actor loss before its first advance call"
	)
	binding.reset_patrol()
	var admitted_actor := Node3D.new()
	root.add_child(admitted_actor)
	var nonfinite_start := binding.start_patrol(admitted_actor)
	admitted_actor.position = Vector3.INF
	var nonfinite := binding.advance_patrol(0.25, admitted_actor, Vector3.ZERO)
	_check(
		bool(nonfinite_start.get("accepted", false))
		and bool(nonfinite.get("accepted", false))
		and nonfinite.get("state_id", &"") == &"failed"
		and nonfinite.get("failure_reason", &"") == &"patrol_actor_invalid_position"
		and nonfinite.get("recovery_action_id", &"") == &"reset_patrol_then_restart",
		"a non-finite live actor transform terminally fails instead of freezing"
	)
	binding.reset_patrol()
	admitted_actor.position = Vector3.ZERO
	var started := binding.start_patrol(admitted_actor)
	var invalid_actor := Node.new()
	var invalid := binding.advance_patrol(0.25, invalid_actor, Vector3.ZERO)
	invalid_actor.free()
	admitted_actor.queue_free()
	_check(
		bool(started.get("accepted", false))
		and bool(invalid.get("accepted", false))
		and invalid.get("reason", &"") == &"failed"
		and invalid.get("state_id", &"") == &"failed"
		and invalid.get("failure_reason", &"") == &"patrol_actor_invalid"
		and invalid.get("patrol_actor_status_id", &"") == &"invalid"
		and bool(invalid.get("actor_recovery_required", false))
		and invalid.get("recovery_action_id", &"") == &"reset_patrol_then_restart",
		"an invalid physical actor terminally fails with an explicit reset/restart action"
	)

	var reset := binding.reset_patrol()
	var replacement := Node3D.new()
	replacement.name = "RecoveredCinderPatrolActor"
	replacement.position = Vector3.ZERO
	root.add_child(replacement)
	var restarted := binding.start_patrol(replacement)
	var recovered := binding.advance_patrol(
		0.5, replacement, ROUTE.get_checkpoint_position(0)
	)
	_check(
		bool(reset.get("accepted", false))
		and bool(restarted.get("accepted", false))
		and bool(recovered.get("accepted", false))
		and recovered.get("state_id", &"") == &"active"
		and recovered.get("phase_id", &"") == &"dwell"
		and recovered.get("patrol_actor_status_id", &"") == &"tracked"
		and int(recovered.get("patrol_actor_instance_id", 0)) == replacement.get_instance_id(),
		"the fresh actor uses the exact captured sample rather than rereading its transform"
	)

	var presentations_before_loss := _presentations.size()
	replacement.queue_free()
	await process_frame
	var actor_lost := binding.get_snapshot().get("patrol", {}) as Dictionary
	var retained_loss: Dictionary = _presentations.back()
	_check(
		actor_lost.get("state_id", &"") == &"failed"
		and actor_lost.get("failure_reason", &"") == &"patrol_actor_lost"
		and actor_lost.get("presentation_reason", &"") == &"patrol_actor_lost"
		and actor_lost.get("patrol_actor_status_id", &"") == &"lost"
		and bool(actor_lost.get("actor_recovery_required", false))
		and actor_lost.get("recovery_action_id", &"") == &"reset_patrol_then_restart"
		and _presentations.size() == presentations_before_loss + 1
		and retained_loss.get("state_id", &"") == &"failed"
		and retained_loss.get("presentation_reason", &"") == &"patrol_actor_lost",
		"tree exit fails immediately without waiting for another patrol physics sample"
	)

	var loss_reset := binding.reset_patrol()
	var final_actor := Node3D.new()
	root.add_child(final_actor)
	var final_restart := binding.start_patrol(final_actor)
	_check(
		bool(loss_reset.get("accepted", false))
		and bool(final_restart.get("accepted", false))
		and final_restart.get("patrol_actor_status_id", &"") == &"tracked"
		and int(final_restart.get("patrol_actor_instance_id", 0)) == final_actor.get_instance_id()
		and not bool(final_restart.get("actor_recovery_required", true)),
		"reset clears lost identity before admitting a fresh patrol actor"
	)
	root.remove_child(cluster)
	await process_frame
	var binding_detached := binding.get_snapshot().get("patrol", {}) as Dictionary
	root.add_child(cluster)
	await process_frame
	await process_frame
	var binding_reentered := binding.get_snapshot().get("patrol", {}) as Dictionary
	_check(
		not bool(binding_detached.get("attached", true))
		and binding_detached.get("state_id", &"") == &"active"
		and bool(binding_reentered.get("attached", false))
		and binding_reentered.get("state_id", &"") == &"active"
		and int(binding_reentered.get("patrol_actor_instance_id", 0))
		== final_actor.get_instance_id(),
		"binding tree detach and re-entry forward the live patrol lifecycle"
	)
	root.remove_child(cluster)
	await process_frame
	binding.bind_patrol_presentation(_on_patrol_presentation)
	var presentations_before_reentry_loss := _presentations.size()
	final_actor.free()
	await process_frame
	root.add_child(cluster)
	await process_frame
	await process_frame
	var binding_terminal := binding.get_snapshot().get("patrol", {}) as Dictionary
	var terminal_publication: Dictionary = _presentations.back()
	_check(
		binding_terminal.get("state_id", &"") == &"failed"
		and binding_terminal.get("failure_reason", &"") == &"patrol_actor_lost"
		and _presentations.size() == presentations_before_reentry_loss + 1
		and terminal_publication.get("state_id", &"") == &"failed",
		"detached actor loss publishes exactly one terminal snapshot on binding re-entry"
	)
	await _test_detached_actor_loss()

	cluster.queue_free()
	for _frame in 4:
		await process_frame
	_finish()


func _test_detached_actor_loss() -> void:
	var director := ActivityDirector.new()
	director.name = "DetachedPatrolDirector"
	root.add_child(director)
	director.register_definition(ROUTE)
	var patrol := Patrol.new(ROUTE, 2.0) as PatrolActivity
	patrol.attach(director, patrol.get_generation())
	var queued_actor := Node3D.new()
	root.add_child(queued_actor)
	var queued_actor_id := queued_actor.get_instance_id()
	var queued_start := patrol.start(patrol.get_generation(), queued_actor)
	queued_actor.queue_free()
	await process_frame
	var queued_loss := patrol.get_presentation_snapshot()
	_check(
		bool(queued_start.get("accepted", false))
		and int(queued_start.get("patrol_actor_instance_id", 0)) == queued_actor_id
		and is_zero_approx(float(queued_loss.get("current_time_seconds", -1.0)))
		and queued_loss.get("state_id", &"") == &"failed"
		and queued_loss.get("failure_reason", &"") == &"patrol_actor_lost",
		"queue-free after accepted start fails before the first patrol physics sample"
	)
	patrol.reset(patrol.get_generation())
	var freed_actor := Node3D.new()
	root.add_child(freed_actor)
	var freed_start := patrol.start(patrol.get_generation(), freed_actor)
	freed_actor.free()
	await process_frame
	var freed_loss := patrol.get_presentation_snapshot()
	_check(
		bool(freed_start.get("accepted", false))
		and is_zero_approx(float(freed_loss.get("current_time_seconds", -1.0)))
		and freed_loss.get("state_id", &"") == &"failed"
		and freed_loss.get("failure_reason", &"") == &"patrol_actor_lost",
		"immediate free after accepted start fails before the first patrol physics sample"
	)
	patrol.reset(patrol.get_generation())
	var actor := Node3D.new()
	root.add_child(actor)
	patrol.start(patrol.get_generation(), actor)
	patrol.advance_actor_physics(
		0.25, actor, actor.global_position, patrol.get_generation()
	)
	var elapsed_before := float(
		patrol.get_presentation_snapshot().get("current_time_seconds", -1.0)
	)
	var generation := patrol.get_generation()
	patrol.detach(generation)
	root.remove_child(actor)
	actor.free()
	await process_frame
	var detached := patrol.get_presentation_snapshot()
	var director_detached := director.get_activity_snapshot(ROUTE.activity_id)
	_check(
		detached.get("state_id", &"") == &"active"
		and not bool(detached.get("attached", true))
		and bool(detached.get("patrol_actor_loss_pending", false))
		and detached.get("patrol_actor_pending_reason", &"") == &"patrol_actor_lost"
		and is_equal_approx(float(detached.get("current_time_seconds", -2.0)), elapsed_before)
		and int(director_detached.get("state", -1)) == CheckpointRouteActivity.State.ACTIVE,
		"detached actor exit latches loss without mutating patrol or director lifecycle"
	)
	var failures := {"count": 0}
	patrol.patrol_failed.connect(
		func(_snapshot: Dictionary) -> void:
			failures["count"] = int(failures["count"]) + 1
	)
	var reattached := patrol.attach(director, generation)
	var duplicate_attach := patrol.attach(director, generation)
	_check(
		bool(reattached.get("accepted", false))
		and reattached.get("state_id", &"") == &"failed"
		and reattached.get("failure_reason", &"") == &"patrol_actor_lost"
		and not bool(reattached.get("patrol_actor_loss_pending", true))
		and reattached.get("recovery_action_id", &"") == &"reset_patrol_then_restart"
		and int(failures["count"]) == 1
		and not bool(duplicate_attach.get("accepted", true))
		and int(director.get_activity_snapshot(ROUTE.activity_id).get("state", -1))
		== CheckpointRouteActivity.State.FAILED,
		"reattach immediately consumes latched loss through the same patrol authority"
	)
	patrol.close(generation)
	director.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _on_patrol_presentation(snapshot: Dictionary) -> void:
	_presentations.append(snapshot.duplicate(true))


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_PATROL_ACTOR_RECOVERY_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		quit(1)
