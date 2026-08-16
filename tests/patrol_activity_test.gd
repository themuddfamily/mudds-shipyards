extends SceneTree

const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const Patrol := preload("res://scripts/activities/patrol_activity.gd")

var _failures: Array[String] = []
var _assertions := 0
var _events := PackedStringArray()
var _reentry_probes: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_patrol_lifecycle()
	_test_zero_dwell_signal_chronology()
	_test_invalid_input_overflow_and_configuration()
	_test_current_generation_checkpoint_mismatch()
	_finish()


func _test_patrol_lifecycle() -> void:
	var director := ActivityDirector.new()
	director.name = "PatrolDirector"
	_check(director.register_definition(ROUTE), "the fixture registers the existing Cinder route once")
	root.add_child(director)
	var patrol := Patrol.new(ROUTE, 1.0) as PatrolActivity
	_connect_observers(patrol, director)

	var audit := patrol.audit()
	_check(
		audit.valid
		and audit.route_resource_path == ROUTE.resource_path
		and audit.shares_activity_director_route
		and not audit.owns_checkpoint_geometry,
		"the patrol composes the exact shared route resource without checkpoint geometry"
	)
	_check(
		not audit.gameplay_authority
		and not audit.grants_rewards
		and not audit.ship_authority
		and not audit.combat_authority
		and not audit.berth_authority
		and not audit.save_authority
		and not audit.network_authority,
		"the patrol freezes zero gameplay, reward, ship, combat, berth, save, and network authority"
	)
	var unregistered := ActivityDirector.new()
	_check(
		patrol.attach(unregistered, 0).reason == &"route_not_registered"
		and patrol.attach(director, 0).accepted,
		"attachment requires a director registered with the exact route resource"
	)
	unregistered.free()

	var start := patrol.start(0)
	var generation := int(start.generation)
	_check(
		start.accepted
		and generation == 1
		and start.state_id == &"active"
		and start.phase_id == &"travel"
		and int(start.next_checkpoint_index) == 0,
		"an exact generation starts an ordered travel phase at checkpoint zero"
	)
	var after_start := patrol.get_presentation_snapshot()
	_check(
		patrol.start(0).reason == &"stale_generation"
		and patrol.start(generation).reason == &"already_running"
		and patrol.get_presentation_snapshot() == after_start,
		"stale and duplicate starts cannot replace a live patrol"
	)

	var travel_step := patrol.advance_physics(0.5, Vector3.ZERO, generation)
	_check(
		travel_step.accepted
		and travel_step.phase_id == &"travel"
		and is_equal_approx(float(travel_step.current_time_seconds), 0.5)
		and is_zero_approx(float(travel_step.dwell_elapsed_seconds)),
		"caller physics delta records travel time without inventing dwell"
	)
	var outside := patrol.submit_position(Vector3.ZERO, generation)
	_check(
		not outside.accepted
		and outside.reason == &"outside_checkpoint"
		and int(outside.next_checkpoint_index) == 0,
		"the shared route volume rejects an outside patrol position"
	)
	var arrived := patrol.submit_position(ROUTE.get_checkpoint_position(0), generation)
	_check(
		arrived.accepted
		and arrived.phase_id == &"dwell"
		and int(arrived.dwell_checkpoint_index) == 0
		and int(arrived.completed_checkpoint_count) == 0
		and int(director.get_activity_snapshot(ROUTE.activity_id).next_checkpoint_index) == 0,
		"shared-volume arrival opens dwell without prematurely committing director or patrol progress"
	)
	_check(
		patrol.submit_position(ROUTE.get_checkpoint_position(0), generation).reason
		== &"dwell_in_progress",
		"a second position submission cannot double-advance the director during dwell"
	)

	var before_process_frames := patrol.get_presentation_snapshot()
	await process_frame
	await process_frame
	_check(
		patrol.get_presentation_snapshot() == before_process_frames,
		"process frames do not advance caller-owned patrol physics time"
	)
	var zero_step := patrol.advance_physics(
		0.0, ROUTE.get_checkpoint_position(0), generation
	)
	_check(
		zero_step.accepted
		and zero_step.reason == &"no_delta"
		and patrol.get_presentation_snapshot() == before_process_frames,
		"zero-delta pause is an exact state-preserving no-op"
	)
	var partial_dwell := patrol.advance_physics(
		0.4, ROUTE.get_checkpoint_position(0), generation
	)
	_check(
		is_equal_approx(float(partial_dwell.dwell_elapsed_seconds), 0.4)
		and is_equal_approx(float(partial_dwell.dwell_remaining_seconds), 0.6)
		and partial_dwell.checkpoint_occupied,
		"continuous in-volume physics time accumulates an exact partial dwell"
	)
	var interrupted := patrol.advance_physics(
		0.2, ROUTE.get_checkpoint_position(1), generation
	)
	_check(
		interrupted.reason == &"dwell_interrupted"
		and is_zero_approx(float(interrupted.dwell_elapsed_seconds))
		and not interrupted.checkpoint_occupied,
		"leaving the shared checkpoint volume resets continuous dwell progress"
	)
	var first_dwell := patrol.advance_physics(
		1.0, ROUTE.get_checkpoint_position(0), generation
	)
	_check(
		first_dwell.reason == &"dwell_completed"
		and first_dwell.phase_id == &"travel"
		and int(first_dwell.completed_checkpoint_count) == 1
		and int(first_dwell.next_checkpoint_index) == 1
		and int(director.get_activity_snapshot(ROUTE.activity_id).next_checkpoint_index) == 1,
		"one uninterrupted dwell atomically commits director and patrol progress"
	)
	var ordered_before := patrol.get_presentation_snapshot()
	_check(
		patrol.submit_position(ROUTE.get_checkpoint_position(2), generation).reason
		== &"outside_checkpoint"
		and patrol.get_presentation_snapshot() == ordered_before,
		"a later Cinder beacon cannot bypass the director's ordered route"
	)
	_check(
		patrol.submit_position(ROUTE.get_checkpoint_position(1), generation).accepted
		and patrol.advance_physics(
			0.25, ROUTE.get_checkpoint_position(1), generation
		).accepted,
		"checkpoint one establishes partial dwell before lifecycle re-entry"
	)

	var detached := patrol.detach(generation)
	var director_id := director.get_instance_id()
	root.remove_child(director)
	await process_frame
	await process_frame
	_check(
		detached.accepted
		and not detached.attached
		and is_equal_approx(
			float(patrol.get_presentation_snapshot().current_time_seconds),
			float(detached.current_time_seconds)
		)
		and int(patrol.get_presentation_snapshot().dwell_checkpoint_index) == 1
		and is_equal_approx(
			float(patrol.get_presentation_snapshot().dwell_elapsed_seconds), 0.25
		),
		"detach and process frames preserve exact patrol clock and partial dwell"
	)
	root.add_child(director)
	await process_frame
	_check(
		director.get_instance_id() == director_id
		and patrol.attach(director, generation).accepted,
		"the same coherent director reattaches without restarting patrol identity"
	)
	_check(
		patrol.advance_physics(
			0.75, ROUTE.get_checkpoint_position(1), generation
		).reason == &"dwell_completed",
		"reattached caller physics resumes the preserved continuous dwell exactly"
	)

	for checkpoint_index in range(2, ROUTE.get_checkpoint_count()):
		_check(
			patrol.submit_position(
				ROUTE.get_checkpoint_position(checkpoint_index), generation
			).accepted,
			"ordered patrol checkpoint %d begins dwell" % checkpoint_index
		)
		_check(
			patrol.advance_physics(
				1.0, ROUTE.get_checkpoint_position(checkpoint_index), generation
			).accepted,
			"ordered patrol checkpoint %d completes dwell" % checkpoint_index
		)
	var completed := patrol.get_presentation_snapshot()
	_check(
		completed.state_id == &"completed"
		and completed.phase_id == &"complete"
		and int(completed.completed_checkpoint_count) == ROUTE.get_checkpoint_count()
		and int(completed.next_checkpoint_index) == ROUTE.get_checkpoint_count()
		and is_equal_approx(float(completed.last_duration_seconds), 6.1),
		"the final dwell completes one finite sweep with exact caller-physics duration"
	)
	_check(
		_events.slice(0, 12) == PackedStringArray([
			"start:travel",
			"arrived:0:dwell", "dwell:0:1:active",
			"arrived:1:dwell", "dwell:1:2:active",
			"arrived:2:dwell", "dwell:2:3:active",
			"arrived:3:dwell", "dwell:3:4:active",
			"arrived:4:dwell", "dwell:4:5:completed",
			"completed:5",
		]),
		"checkpoint arrival, committed dwell, and completion signals have one stable chronology"
	)
	var event_count_at_completion := _events.size()
	_check(
		patrol.advance_physics(1.0, ROUTE.get_checkpoint_position(4), generation).reason
		== &"not_running"
		and patrol.submit_position(ROUTE.get_checkpoint_position(0), generation).reason
		== &"not_running"
		and _events.size() == event_count_at_completion,
		"terminal patrol state cannot advance or complete twice"
	)
	var mutated_snapshot := completed.duplicate(true)
	mutated_snapshot["state_id"] = &"mutated"
	mutated_snapshot["current_time_seconds"] = INF
	_check(
		patrol.get_presentation_snapshot().state_id == &"completed"
		and is_equal_approx(
			float(patrol.get_presentation_snapshot().current_time_seconds), 6.1
		),
		"HUD-ready snapshots are detached values that cannot mutate authority state"
	)

	var reset := patrol.reset(generation)
	var reset_generation := int(reset.generation)
	_check(
		reset.accepted
		and reset_generation == generation + 1
		and reset.state_id == &"idle"
		and is_equal_approx(float(reset.last_duration_seconds), 6.1),
		"reset invalidates the completed generation while retaining last duration"
	)
	var stale_snapshot := patrol.get_presentation_snapshot()
	_check(
		patrol.start(generation).reason == &"stale_generation"
		and patrol.reset(generation).reason == &"stale_generation"
		and patrol.abort(&"stale_abort", generation).reason == &"stale_generation"
		and patrol.get_presentation_snapshot() == stale_snapshot,
		"retired generation start, reset, and abort callbacks leave replacement state unchanged"
	)

	var abort_start := patrol.start(reset_generation)
	var abort_generation := int(abort_start.generation)
	patrol.submit_position(ROUTE.get_checkpoint_position(0), abort_generation)
	patrol.advance_physics(0.25, ROUTE.get_checkpoint_position(0), abort_generation)
	var aborted := patrol.abort(&"pilot_recalled", abort_generation)
	_check(
		aborted.accepted
		and aborted.state_id == &"aborted"
		and aborted.abort_reason == &"pilot_recalled"
		and int(aborted.completed_checkpoint_count) == 0
		and int(director.get_activity_snapshot(ROUTE.activity_id).state)
		== CheckpointRouteActivity.State.FAILED,
		"abort terminalizes both mapped authorities during uncommitted dwell"
	)
	var failure_reset := patrol.reset(abort_generation)
	var failure_start := patrol.start(int(failure_reset.generation))
	var failure_generation := int(failure_start.generation)
	var failed := patrol.fail(&"craft_unavailable", failure_generation)
	_check(
		failed.accepted
		and failed.state_id == &"failed"
		and failed.failure_reason == &"craft_unavailable",
		"explicit failure records one current-generation typed reason"
	)
	var external_reset := patrol.reset(failure_generation)
	var external_start := patrol.start(int(external_reset.generation))
	var external_generation := int(external_start.generation)
	_check(
		director.fail_activity(
			ROUTE.activity_id, &"external_activity_failure", int(external_start.activity_generation)
		)
		and patrol.get_presentation_snapshot().state_id == &"failed"
		and patrol.get_presentation_snapshot().failure_reason == &"external_activity_failure",
		"a current director failure translates once into the attached patrol generation"
	)
	_check(
		patrol.reset(external_generation).accepted
		and patrol.close(patrol.get_generation()).accepted
		and patrol.get_presentation_snapshot().closed
		and not patrol.get_presentation_snapshot().attached,
		"reset recovery and close release the director connection without new authority"
	)

	var every_probe_rejected := true
	for observation: Dictionary in _reentry_probes:
		every_probe_rejected = (
			every_probe_rejected
			and bool(observation.all_reentrant)
			and bool(observation.snapshot_unchanged)
		)
	_check(
		every_probe_rejected,
		"every public mutator rejects signal-subscriber reentry without state change"
	)
	patrol = null
	director.free()


func _test_zero_dwell_signal_chronology() -> void:
	var director := ActivityDirector.new()
	director.register_definition(ROUTE)
	root.add_child(director)
	var patrol := Patrol.new(ROUTE, 0.0) as PatrolActivity
	var chronology := PackedStringArray()
	var probes: Array[Dictionary] = []
	patrol.checkpoint_arrived.connect(
		func(snapshot: Dictionary, checkpoint_index: int) -> void:
			chronology.append("arrived:%d:%s" % [checkpoint_index, snapshot.phase_id])
			probes.append(_probe_reentry(patrol, director))
	)
	patrol.checkpoint_dwell_completed.connect(
		func(snapshot: Dictionary, checkpoint_index: int) -> void:
			chronology.append("dwell:%d:%s" % [checkpoint_index, snapshot.state_id])
			probes.append(_probe_reentry(patrol, director))
	)
	patrol.patrol_completed.connect(
		func(_snapshot: Dictionary) -> void:
			chronology.append("completed")
			probes.append(_probe_reentry(patrol, director))
	)
	patrol.attach(director, 0)
	var generation := int(patrol.start(0).generation)
	for checkpoint_index in ROUTE.get_checkpoint_count():
		patrol.submit_position(
			ROUTE.get_checkpoint_position(checkpoint_index), generation
		)
	var every_probe_rejected := true
	for probe: Dictionary in probes:
		every_probe_rejected = (
			every_probe_rejected
			and bool(probe.all_reentrant)
			and bool(probe.snapshot_unchanged)
		)
	_check(
		chronology == PackedStringArray([
			"arrived:0:dwell", "dwell:0:active",
			"arrived:1:dwell", "dwell:1:active",
			"arrived:2:dwell", "dwell:2:active",
			"arrived:3:dwell", "dwell:3:active",
			"arrived:4:dwell", "dwell:4:completed", "completed",
		])
		and every_probe_rejected
		and patrol.get_presentation_snapshot().state_id == &"completed",
		"zero dwell preserves committed arrival-to-dwell-to-complete order under malicious callbacks"
	)
	patrol.close(generation)
	patrol = null
	director.free()


func _test_invalid_input_overflow_and_configuration() -> void:
	var invalid := Patrol.new(null, NAN) as PatrolActivity
	_check(
		not invalid.is_configuration_valid()
		and invalid.get_configuration_errors().size() == 2,
		"missing route and non-finite dwell configuration fail closed"
	)
	var director := ActivityDirector.new()
	director.register_definition(ROUTE)
	root.add_child(director)
	var patrol := Patrol.new(ROUTE, 1.0) as PatrolActivity
	patrol.attach(director, 0)
	var start := patrol.start(0)
	var generation := int(start.generation)
	var before_invalid := patrol.get_presentation_snapshot()
	_check(
		patrol.advance_physics(-0.1, Vector3.ZERO, generation).reason == &"invalid_delta"
		and patrol.advance_physics(NAN, Vector3.ZERO, generation).reason == &"invalid_delta"
		and patrol.advance_physics(0.1, Vector3(NAN, 0.0, 0.0), generation).reason
		== &"invalid_position"
		and patrol.submit_position(Vector3(INF, 0.0, 0.0), generation).reason
		== &"invalid_position"
		and patrol.get_presentation_snapshot() == before_invalid,
		"negative/non-finite deltas and positions cannot mutate patrol state"
	)
	_check(
		patrol.advance_physics(1.0e308, Vector3.ZERO, generation).accepted,
		"a very large finite caller-physics duration remains representable"
	)
	var before_overflow := patrol.get_presentation_snapshot()
	_check(
		patrol.advance_physics(1.0e308, Vector3.ZERO, generation).reason == &"time_overflow"
		and patrol.get_presentation_snapshot() == before_overflow
		and is_finite(float(before_overflow.current_time_seconds)),
		"finite addition overflow is rejected before an INF snapshot can be published"
	)
	patrol.close(generation)
	patrol = null
	director.free()


func _test_current_generation_checkpoint_mismatch() -> void:
	var director := ActivityDirector.new()
	director.register_definition(ROUTE)
	root.add_child(director)
	var patrol := Patrol.new(ROUTE, 1.0) as PatrolActivity
	patrol.attach(director, 0)
	var start := patrol.start(0)
	var injecting := false
	var inject_mismatch := func(
		activity_id: StringName,
		checkpoint_index: int,
		activity_generation: int
	) -> void:
		if injecting or checkpoint_index != 0:
			return
		injecting = true
		director.activity_checkpoint_reached.emit(
			activity_id, checkpoint_index + 2, activity_generation
		)
		injecting = false
	director.activity_checkpoint_reached.connect(inject_mismatch)
	var arrival := patrol.submit_position(
		ROUTE.get_checkpoint_position(0), int(start.generation)
	)
	var result := patrol.advance_physics(
		1.0, ROUTE.get_checkpoint_position(0), int(start.generation)
	)
	var activity_snapshot := director.get_activity_snapshot(ROUTE.activity_id)
	_check(
		arrival.accepted
		and not result.accepted
		and result.reason == &"authority_desynchronized"
		and result.state_id == &"failed"
		and result.failure_reason == &"activity_patrol_desynchronized"
		and int(result.completed_checkpoint_count) == 0,
		"a current-generation mismatched director checkpoint rejects its dwell-commit call fail-closed"
	)
	_check(
		int(activity_snapshot.state) == CheckpointRouteActivity.State.FAILED
		and activity_snapshot.failure_reason == &"activity_patrol_desynchronized"
		and int(activity_snapshot.generation) == int(result.activity_generation),
		"checkpoint mismatch terminalizes the exact mapped director generation"
	)
	director.activity_checkpoint_reached.disconnect(inject_mismatch)
	patrol.close(patrol.get_generation())
	patrol = null
	director.free()


func _connect_observers(patrol: PatrolActivity, director: ActivityDirector) -> void:
	patrol.patrol_started.connect(
		func(snapshot: Dictionary) -> void:
			_events.append("start:%s" % snapshot.phase_id)
			_reentry_probes.append(_probe_reentry(patrol, director))
	)
	patrol.checkpoint_arrived.connect(
		func(snapshot: Dictionary, checkpoint_index: int) -> void:
			_events.append("arrived:%d:%s" % [checkpoint_index, snapshot.phase_id])
			_reentry_probes.append(_probe_reentry(patrol, director))
	)
	patrol.checkpoint_dwell_completed.connect(
		func(snapshot: Dictionary, checkpoint_index: int) -> void:
			_events.append("dwell:%d:%d:%s" % [
				checkpoint_index,
				int(snapshot.completed_checkpoint_count),
				str(snapshot.state_id),
			])
			_reentry_probes.append(_probe_reentry(patrol, director))
	)
	patrol.patrol_completed.connect(
		func(snapshot: Dictionary) -> void:
			_events.append("completed:%d" % int(snapshot.completed_checkpoint_count))
			_reentry_probes.append(_probe_reentry(patrol, director))
	)
	patrol.patrol_aborted.connect(
		func(_snapshot: Dictionary) -> void:
			_events.append("aborted")
			_reentry_probes.append(_probe_reentry(patrol, director))
	)
	patrol.patrol_failed.connect(
		func(_snapshot: Dictionary) -> void:
			_events.append("failed")
			_reentry_probes.append(_probe_reentry(patrol, director))
	)
	patrol.patrol_reset.connect(
		func(_snapshot: Dictionary) -> void:
			_events.append("reset")
			_reentry_probes.append(_probe_reentry(patrol, director))
	)
	patrol.presentation_changed.connect(
		func(_snapshot: Dictionary) -> void:
			_reentry_probes.append(_probe_reentry(patrol, director))
	)


func _probe_reentry(patrol: PatrolActivity, director: ActivityDirector) -> Dictionary:
	var generation := patrol.get_generation()
	var before := patrol.get_presentation_snapshot()
	var results: Array[Dictionary] = [
		patrol.attach(director, generation),
		patrol.detach(generation),
		patrol.start(generation),
		patrol.submit_position(ROUTE.get_checkpoint_position(0), generation),
		patrol.advance_physics(0.1, ROUTE.get_checkpoint_position(0), generation),
		patrol.abort(&"reentrant_abort", generation),
		patrol.fail(&"reentrant_failure", generation),
		patrol.reset(generation),
		patrol.close(generation),
	]
	var all_reentrant := true
	for result: Dictionary in results:
		all_reentrant = (
			all_reentrant
			and not bool(result.accepted)
			and result.reason == &"reentrant_call"
		)
	return {
		"all_reentrant": all_reentrant,
		"snapshot_unchanged": patrol.get_presentation_snapshot() == before,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	print("PATROL_ACTIVITY_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("PATROL_ACTIVITY_TEST_OK")
		quit(0)
	else:
		print("PATROL_ACTIVITY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
