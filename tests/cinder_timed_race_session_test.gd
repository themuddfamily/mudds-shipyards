extends SceneTree

const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const Session := preload("res://scripts/activities/cinder_timed_race_session.gd")

var _failures: Array[String] = []
var _events := PackedStringArray()
var _reentry_probes: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var director := ActivityDirector.new()
	director.name = "CinderSessionDirector"
	_check(director.register_definition(ROUTE), "the fixture registers the existing Cinder route once")
	root.add_child(director)
	var session := Session.new(2, 1.0, 10.0)
	_connect_session_observers(session, director)

	var audit := session.audit()
	_check(
		audit.valid
		and audit.route_resource_path == ROUTE.resource_path
		and int(audit.checkpoint_count) == ROUTE.get_checkpoint_count()
		and not bool(audit.owns_checkpoint_geometry),
		"the adapter references the shared route resource and duplicates no checkpoint geometry"
	)
	_check(
		not bool(audit.grants_rewards)
		and not bool(audit.ship_authority)
		and not bool(audit.berth_authority)
		and not bool(audit.combat_authority)
		and not bool(audit.network_authority),
		"the session freezes zero reward, ship, berth, combat, and network authority"
	)
	var unregistered_director := ActivityDirector.new()
	var unregistered_result := session.attach(unregistered_director, 0)
	unregistered_director.free()
	_check(
		not unregistered_result.accepted and session.attach(director, 0).accepted,
		"attachment requires a director registered with the exact shared route"
	)

	var start := session.start(0)
	var session_generation := int(start.session_generation)
	var first_activity_generation := int(start.activity_generation)
	_check(
		start.accepted
		and session_generation == 1
		and start.state_id == &"countdown"
		and first_activity_generation == 1,
		"start maps session generation one to the director and timed countdown"
	)
	var before_process_frames := session.get_presentation_snapshot()
	await process_frame
	await process_frame
	_check(
		session.get_presentation_snapshot() == before_process_frames,
		"process frames cannot advance a caller-physics-delta session"
	)
	_check(
		not session.advance_physics(1.0, 0).accepted
		and session.get_presentation_snapshot() == before_process_frames,
		"a stale session generation cannot advance countdown time"
	)
	var active := session.advance_physics(1.0, session_generation)
	_check(
		active.accepted
		and active.state_id == &"active"
		and is_zero_approx(float(active.current_time_seconds)),
		"caller physics delta performs the exact countdown to ACTIVE transition"
	)
	_check(
		not session.submit_position(Vector3.ZERO, session_generation).accepted,
		"the director rejects a position outside the expected shared checkpoint"
	)

	var before_invalid := session.get_presentation_snapshot()
	var route_before_invalid := director.get_activity_snapshot(ROUTE.activity_id)
	for invalid_position in [Vector3(NAN, 0, 0), Vector3(0, INF, 0), Vector3(0, 0, -INF)]:
		for _checkpoint_index in ROUTE.get_checkpoint_count():
			var rejected := session.submit_position(invalid_position, session_generation)
			_check(not rejected.accepted and rejected.reason == &"invalid_position",
				"the session rejects nonfinite positions through the shared route authority")
	var after_invalid := session.get_presentation_snapshot()
	for key in ["state_id", "lap_number", "next_checkpoint_index", "current_time_seconds", "last_time_seconds", "best_time_seconds"]:
		_check(after_invalid[key] == before_invalid[key], "nonfinite positions preserve session %s" % key)
	_check(director.get_activity_snapshot(ROUTE.activity_id) == route_before_invalid,
		"nonfinite session positions preserve the director route")

	for checkpoint_index in ROUTE.get_checkpoint_count():
		_check(
			session.submit_position(
				ROUTE.get_checkpoint_position(checkpoint_index), session_generation
			).accepted,
			"lap one translates shared checkpoint position %d" % checkpoint_index
		)
	var second_lap := session.get_presentation_snapshot()
	_check(
		int(second_lap.lap_number) == 2
		and int(second_lap.next_checkpoint_index) == 0
		and int(second_lap.activity_generation) == first_activity_generation + 1
		and int(second_lap.session_generation) == session_generation,
		"a completed director route rolls to a fresh mapped generation for lap two"
	)

	_check(
		session.submit_position(ROUTE.get_checkpoint_position(0), session_generation).accepted,
		"lap two accepts its first translated boundary"
	)
	var before_stale_signal := session.get_presentation_snapshot()
	director.activity_checkpoint_reached.emit(
		ROUTE.activity_id, 1, int(before_stale_signal.activity_generation) - 1
	)
	director.activity_completed.emit(
		ROUTE.activity_id, int(before_stale_signal.activity_generation) - 1
	)
	_check(
		session.get_presentation_snapshot() == before_stale_signal,
		"stale director checkpoint and completion signals cannot advance the mapped race"
	)

	var detached := session.detach(session_generation)
	_check(detached.accepted and not bool(detached.attached), "active-session detach preserves state and disconnects translation")
	root.remove_child(director)
	await process_frame
	root.add_child(director)
	await process_frame
	_check(
		session.get_presentation_snapshot().current_time_seconds
		== detached.current_time_seconds,
		"whole-tree director detach/re-entry adds no hidden session time"
	)
	_check(
		session.attach(director, session_generation).accepted,
		"the same coherent director generation reattaches without restarting progress"
	)
	var reattached := session.get_presentation_snapshot()
	_check(
		int(reattached.next_checkpoint_index) == 1
		and int(reattached.activity_generation) == int(detached.activity_generation),
		"reattachment preserves the exact in-lap boundary and activity generation"
	)

	session.advance_physics(2.0, session_generation)
	for checkpoint_index in range(1, ROUTE.get_checkpoint_count()):
		session.submit_position(
			ROUTE.get_checkpoint_position(checkpoint_index), session_generation
		)
	var completed := session.get_presentation_snapshot()
	_check(
		completed.state_id == &"completed"
		and is_equal_approx(float(completed.current_time_seconds), 2.0)
		and is_equal_approx(float(completed.last_time_seconds), 2.0)
		and is_equal_approx(float(completed.best_time_seconds), 2.0),
		"ordered final translation completes once with exact presentation timing"
	)
	_check(
		not session.submit_position(ROUTE.get_checkpoint_position(0), session_generation).accepted
		and _count_event(&"complete") == 1,
		"a completed session cannot accept or signal a duplicate finish"
	)
	var mutated_snapshot := completed.duplicate(true)
	mutated_snapshot["current_time_seconds"] = 999.0
	mutated_snapshot["state_id"] = &"mutated"
	_check(
		session.get_presentation_snapshot().state_id == &"completed"
		and is_equal_approx(
			float(session.get_presentation_snapshot().current_time_seconds), 2.0
		),
		"presentation snapshots are detached values a future HUD cannot mutate back"
	)

	var reset := session.reset(session_generation)
	_check(
		reset.accepted
		and int(reset.session_generation) == 2
		and reset.state_id == &"idle",
		"reset advances the session and both mapped authority generations"
	)
	var failure_start := session.start(int(reset.session_generation))
	var failure_generation := int(failure_start.session_generation)
	session.advance_physics(1.0, failure_generation)
	var timeout := session.apply_penalty(10.0, &"gate_contact", failure_generation)
	_check(
		timeout.accepted
		and timeout.state_id == &"failed"
		and timeout.failure_reason == &"timeout"
		and _events.slice(_events.size() - 2) == PackedStringArray(["penalty", "failed"]),
		"penalty timeout commits ordered penalty then synchronized failure"
	)
	var failed_activity := director.get_activity_snapshot(ROUTE.activity_id)
	_check(
		int(failed_activity.state) == CheckpointRouteActivity.State.FAILED
		and failed_activity.failure_reason == &"timeout"
		and int(failed_activity.generation) == int(timeout.activity_generation),
		"timed failure translates to the exact mapped ActivityDirector generation"
	)
	var failure_reset := session.reset(failure_generation)
	var manual_start := session.start(int(failure_reset.session_generation))
	var external_activity_failure := director.fail_activity(
		ROUTE.activity_id,
		&"caller_abort",
		int(manual_start.activity_generation)
	)
	var translated_failure := session.get_presentation_snapshot()
	_check(
		external_activity_failure
		and translated_failure.failure_reason == &"caller_abort"
		and translated_failure.state_id == &"failed"
		and _count_event(&"failed") == 2,
		"a current-generation ActivityDirector failure translates once after reset/retry"
	)

	var every_reentry_probe_rejected := true
	for probe: Dictionary in _reentry_probes:
		every_reentry_probe_rejected = (
			every_reentry_probe_rejected
			and bool(probe.all_reentrant)
			and bool(probe.snapshot_unchanged)
		)
	_check(
		every_reentry_probe_rejected,
		"every adapter signal rejects all public mutation reentry without state change"
	)
	_check(
		_events.slice(0, 10) == PackedStringArray([
			"started", "active", "checkpoint", "checkpoint", "checkpoint",
			"checkpoint", "checkpoint", "lap", "checkpoint", "checkpoint",
		]),
		"session chronology begins with start, ACTIVE, and ordered checkpoint/lap events"
	)

	var close_result := session.close(session.get_session_generation())
	_check(
		close_result.accepted and close_result.closed and not close_result.attached,
		"close releases both authority signal boundaries without changing result history"
	)
	_disconnect_session_observers(session)
	session = null
	director.free()
	await _test_countdown_checkpoint_rejection_and_reentry()
	_test_checkpoint_translation_mismatch_fails_closed()
	_finish()


func _connect_session_observers(
	session: CinderTimedRaceSession,
	director: ActivityDirector
) -> void:
	session.session_started.connect(
		func(_snapshot: Dictionary) -> void:
			_events.append("started")
			_reentry_probes.append(_probe_reentry(session, director))
	)
	session.session_active.connect(
		func(_snapshot: Dictionary) -> void:
			_events.append("active")
			_reentry_probes.append(_probe_reentry(session, director))
	)
	session.checkpoint_advanced.connect(
		func(_snapshot: Dictionary) -> void:
			_events.append("checkpoint")
			_reentry_probes.append(_probe_reentry(session, director))
	)
	session.lap_advanced.connect(
		func(_snapshot: Dictionary, _lap_time: float) -> void:
			_events.append("lap")
			_reentry_probes.append(_probe_reentry(session, director))
	)
	session.penalty_changed.connect(
		func(_snapshot: Dictionary) -> void:
			_events.append("penalty")
			_reentry_probes.append(_probe_reentry(session, director))
	)
	session.session_completed.connect(
		func(_snapshot: Dictionary) -> void:
			_events.append("complete")
			_reentry_probes.append(_probe_reentry(session, director))
	)
	session.session_failed.connect(
		func(_snapshot: Dictionary) -> void:
			_events.append("failed")
			_reentry_probes.append(_probe_reentry(session, director))
	)
	session.session_reset.connect(
		func(_snapshot: Dictionary) -> void:
			_events.append("reset")
			_reentry_probes.append(_probe_reentry(session, director))
	)
	session.presentation_changed.connect(
		func(_snapshot: Dictionary) -> void:
			_reentry_probes.append(_probe_reentry(session, director))
	)


func _probe_reentry(
	session: CinderTimedRaceSession,
	director: ActivityDirector
) -> Dictionary:
	var generation := session.get_session_generation()
	var before := session.get_presentation_snapshot()
	var results: Array[Dictionary] = [
		session.attach(director, generation),
		session.detach(generation),
		session.start(generation),
		session.advance_physics(0.0, generation),
		session.submit_position(ROUTE.get_checkpoint_position(0), generation),
		session.apply_penalty(0.25, &"reentry", generation),
		session.fail(&"reentry", generation),
		session.reset(generation),
		session.close(generation),
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
		"snapshot_unchanged": session.get_presentation_snapshot() == before,
	}


func _test_checkpoint_translation_mismatch_fails_closed() -> void:
	var director := ActivityDirector.new()
	director.register_definition(ROUTE)
	root.add_child(director)
	var injecting := false
	var inject_mismatch := func(
		activity_id: StringName,
		checkpoint_index: int,
		generation: int
	) -> void:
		if injecting or checkpoint_index != 0:
			return
		injecting = true
		director.activity_checkpoint_reached.emit(activity_id, 3, generation)
		injecting = false
	director.activity_checkpoint_reached.connect(inject_mismatch)
	var session := Session.new(1, 0.0, 10.0)
	session.attach(director, 0)
	var start := session.start(0)
	var result := session.submit_position(
		ROUTE.get_checkpoint_position(0), int(start.session_generation)
	)
	var activity_snapshot := director.get_activity_snapshot(ROUTE.activity_id)
	_check(
		not result.accepted
		and result.reason == &"authority_desynchronized"
		and result.state_id == &"failed"
		and result.failure_reason == &"activity_race_desynchronized",
		"a current-generation mismatched director index rejects its originating public call"
	)
	_check(
		int(activity_snapshot.state) == CheckpointRouteActivity.State.FAILED
		and activity_snapshot.failure_reason == &"activity_race_desynchronized"
		and int(activity_snapshot.generation) == int(result.activity_generation),
		"checkpoint translation mismatch terminally fails both mapped authorities"
	)
	director.activity_checkpoint_reached.disconnect(inject_mismatch)
	session.close(session.get_session_generation())
	session = null
	director.free()


func _test_countdown_checkpoint_rejection_and_reentry() -> void:
	var director := ActivityDirector.new()
	director.register_definition(ROUTE)
	root.add_child(director)
	var session := Session.new(1, 3.0, 10.0)
	_check(session.attach(director, 0).accepted, "countdown fixture attaches to the shared route authority")
	var start := session.start(0)
	var generation := int(start.session_generation)
	var before_early_checkpoint := session.get_presentation_snapshot()
	var early_checkpoint := session.submit_position(
		ROUTE.get_checkpoint_position(0), generation
	)
	var repeated_early_checkpoint := session.submit_position(
		ROUTE.get_checkpoint_position(0), generation
	)
	var director_after_early_checkpoint := director.get_activity_snapshot(ROUTE.activity_id)
	_check(
		start.accepted
		and not early_checkpoint.accepted
		and early_checkpoint.reason == &"countdown_in_progress"
		and early_checkpoint == repeated_early_checkpoint
		and early_checkpoint.state_id == &"countdown"
		and is_equal_approx(float(early_checkpoint.countdown_remaining_seconds), 3.0)
		and int(early_checkpoint.next_checkpoint_index) == 0
		and session.get_presentation_snapshot() == before_early_checkpoint
		and int(director_after_early_checkpoint.next_checkpoint_index) == 0,
		"a pre-start gate intent returns a stable countdown recovery state without consuming either authority"
	)
	var detached := session.detach(generation)
	var reattached := session.attach(director, generation)
	var activated := session.advance_physics(3.0, generation)
	var admitted_checkpoint := session.submit_position(
		ROUTE.get_checkpoint_position(0), generation
	)
	_check(
		detached.accepted
		and reattached.accepted
		and activated.accepted
		and activated.state_id == &"active"
		and admitted_checkpoint.accepted
		and admitted_checkpoint.state_id == &"active"
		and int(admitted_checkpoint.next_checkpoint_index) == 1,
		"countdown recovery preserves re-entry and admits the same first gate after the start signal"
	)
	session.close(session.get_session_generation())
	session = null
	director.free()


func _disconnect_session_observers(session: CinderTimedRaceSession) -> void:
	for session_signal: Signal in [
		session.session_started,
		session.session_active,
		session.checkpoint_advanced,
		session.lap_advanced,
		session.penalty_changed,
		session.session_completed,
		session.session_failed,
		session.session_reset,
		session.presentation_changed,
	]:
		for connection: Dictionary in session_signal.get_connections():
			session_signal.disconnect(connection.callable)


func _count_event(event: StringName) -> int:
	var count := 0
	for recorded: String in _events:
		if recorded == event:
			count += 1
	return count


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_TIMED_RACE_SESSION_TEST_OK")
		quit(0)
	else:
		print("CINDER_TIMED_RACE_SESSION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
