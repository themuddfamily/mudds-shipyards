extends SceneTree

const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const TimedRace := preload("res://scripts/activities/timed_checkpoint_race.gd")

var _failures: Array[String] = []
var _signals := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_timed_lap_lifecycle()
	_test_timeout_failure_and_validation()
	_test_signal_reentrancy_and_overflow()
	_finish()


func _test_timed_lap_lifecycle() -> void:
	var race := TimedRace.new(ROUTE, 2, 2.0, 20.0)
	_connect_signal_log(race)
	_check(race.is_configuration_valid(), "the timed authority accepts the existing Cinder checkpoint definition")
	var audit := race.audit()
	_check(
		audit.valid
		and audit.route_activity_id == ROUTE.activity_id
		and not bool(audit.owns_checkpoint_geometry),
		"the authority composes the shared route without claiming duplicate geometry"
	)
	_check(
		not bool(audit.gameplay_authority)
		and not bool(audit.grants_rewards)
		and not bool(audit.ship_authority)
		and not bool(audit.combat_authority)
		and not bool(audit.berth_authority)
		and not bool(audit.network_authority),
		"the bounded race owns no reward, ship, combat, berth, or network authority"
	)

	var first_start := race.start(0)
	var generation := int(first_start.generation)
	_check(
		first_start.accepted
		and generation == 1
		and int(first_start.state) == TimedRace.State.COUNTDOWN
		and is_equal_approx(float(first_start.countdown_remaining), 2.0),
		"an exact generation starts a deterministic two-second countdown"
	)
	_check(
		not bool(race.start(0).accepted)
		and race.start(generation).reason == &"already_running",
		"stale and duplicate starts cannot replace a live race"
	)
	var before_stale_step := race.get_snapshot()
	_check(
		not bool(race.advance_physics(1.0, 0).accepted)
		and race.get_snapshot() == before_stale_step,
		"a stale physics callback cannot mutate the new generation"
	)

	var before_pause := race.get_snapshot()
	await process_frame
	await process_frame
	_check(race.get_snapshot() == before_pause, "render/process frames cannot advance the physics-clock countdown")
	var zero_step := race.advance_physics(0.0, generation)
	_check(
		zero_step.accepted
		and zero_step.reason == &"no_delta"
		and race.get_snapshot() == before_pause,
		"paused zero-delta physics is an explicit state-preserving no-op"
	)
	var countdown_step := race.advance_physics(1.25, generation)
	_check(
		int(countdown_step.state) == TimedRace.State.COUNTDOWN
		and is_equal_approx(float(countdown_step.countdown_remaining), 0.75)
		and is_zero_approx(float(countdown_step.current_time_seconds)),
		"countdown time does not leak into the scored race clock"
	)
	var crossing_step := race.advance_physics(1.25, generation)
	_check(
		int(crossing_step.state) == TimedRace.State.ACTIVE
		and is_zero_approx(float(crossing_step.countdown_remaining))
		and is_equal_approx(float(crossing_step.current_time_seconds), 0.5),
		"a physics step crossing zero applies only its remainder to ACTIVE timing"
	)

	_check(
		race.submit_checkpoint(1, generation).reason == &"out_of_order",
		"a later checkpoint cannot advance the ordered route"
	)
	_check(
		race.submit_position(ROUTE.get_checkpoint_position(0), generation).accepted,
		"position submission reads the first boundary from the shared route contract"
	)
	_check(
		race.submit_checkpoint(0, generation).reason == &"duplicate_checkpoint",
		"a duplicate boundary event is rejected within the same lap"
	)
	for checkpoint_index in range(1, ROUTE.get_checkpoint_count()):
		_check(
			race.submit_checkpoint(checkpoint_index, generation).accepted,
			"lap one accepts ordered checkpoint %d" % checkpoint_index
		)
	_check(
		int(race.get_snapshot().current_lap) == 1
		and int(race.get_snapshot().next_checkpoint_index) == 0,
		"the first finish boundary opens the second lap on the same finite route"
	)
	race.advance_physics(1.5, generation)
	var penalty := race.apply_penalty(0.75, &"boundary_contact", generation)
	_check(
		penalty.accepted
		and is_equal_approx(float(penalty.penalty_seconds), 0.75)
		and is_equal_approx(float(penalty.current_time_seconds), 2.75),
		"a typed positive penalty contributes immediately to current race time"
	)
	_check(
		race.apply_penalty(-1.0, &"invalid", generation).reason == &"invalid_penalty"
		and race.apply_penalty(1.0, &"stale", generation - 1).reason == &"stale_generation",
		"invalid and stale penalties leave timing untouched"
	)
	race.advance_physics(0.25, generation)
	for checkpoint_index in ROUTE.get_checkpoint_count():
		race.submit_checkpoint(checkpoint_index, generation)
	var completed := race.get_snapshot()
	_check(
		int(completed.state) == TimedRace.State.COMPLETED
		and is_equal_approx(float(completed.current_time_seconds), 3.0)
		and is_equal_approx(float(completed.last_time_seconds), 3.0)
		and is_equal_approx(float(completed.best_time_seconds), 3.0),
		"completion freezes exact current, last, and first best time including penalties"
	)
	_check(
		race.submit_checkpoint(0, generation).reason == &"not_active",
		"completion is committed exactly once"
	)

	var reset := race.reset(generation)
	_check(
		reset.accepted
		and int(reset.generation) == generation + 1
		and int(reset.state) == TimedRace.State.IDLE
		and is_zero_approx(float(reset.current_time_seconds))
		and is_equal_approx(float(reset.last_time_seconds), 3.0)
		and is_equal_approx(float(reset.best_time_seconds), 3.0),
		"reset invalidates callbacks and clears live progress while retaining result history"
	)
	_check(
		not bool(race.reset(generation).accepted)
		and not bool(race.fail(&"stale_abort", generation).accepted),
		"the retired generation cannot reset or fail its replacement state"
	)
	var second_generation := int(race.start(int(reset.generation)).generation)
	race.advance_physics(3.0, second_generation)
	for lap in 2:
		for checkpoint_index in ROUTE.get_checkpoint_count():
			race.submit_checkpoint(checkpoint_index, second_generation)
	var faster := race.get_snapshot()
	_check(
		is_equal_approx(float(faster.last_time_seconds), 1.0)
		and is_equal_approx(float(faster.best_time_seconds), 1.0),
		"a later faster completion replaces best time deterministically"
	)
	_check(
		_signals == PackedStringArray([
			"countdown:1", "active:1",
			"checkpoint:1:1:0", "checkpoint:1:1:1", "checkpoint:1:1:2",
			"checkpoint:1:1:3", "checkpoint:1:1:4", "lap:1:1:0.500",
			"penalty:1:0.750", "checkpoint:1:2:0", "checkpoint:1:2:1",
			"checkpoint:1:2:2", "checkpoint:1:2:3", "checkpoint:1:2:4",
			"lap:1:2:2.500", "complete:1:3.000", "reset:2", "countdown:3",
			"active:3", "checkpoint:3:1:0", "checkpoint:3:1:1",
			"checkpoint:3:1:2", "checkpoint:3:1:3", "checkpoint:3:1:4",
			"lap:3:1:1.000", "checkpoint:3:2:0", "checkpoint:3:2:1",
			"checkpoint:3:2:2", "checkpoint:3:2:3", "checkpoint:3:2:4",
			"lap:3:2:0.000", "complete:3:1.000",
		]),
		"accepted transitions emit one stable, fully ordered signal chronology"
	)


func _test_timeout_failure_and_validation() -> void:
	var timeout_race := TimedRace.new(ROUTE, 1, 0.0, 2.0)
	var failures := PackedStringArray()
	timeout_race.failed.connect(
		func(_id: StringName, reason: StringName, generation: int) -> void:
			failures.append("%s:%d" % [reason, generation])
	)
	var generation := int(timeout_race.start(0).generation)
	timeout_race.advance_physics(1.5, generation)
	var timeout := timeout_race.apply_penalty(0.75, &"gate_contact", generation)
	_check(
		timeout.accepted
		and int(timeout.state) == TimedRace.State.FAILED
		and timeout.failure_reason == &"timeout"
		and is_equal_approx(float(timeout.current_time_seconds), 2.25)
		and failures == PackedStringArray(["timeout:1"]),
		"physics time plus penalty crosses timeout once with an exact failure snapshot"
	)
	_check(
		not bool(timeout_race.advance_physics(1.0, generation).accepted)
		and not bool(timeout_race.fail(&"duplicate", generation).accepted),
		"a timed-out race cannot advance or fail twice"
	)
	var reset_generation := int(timeout_race.reset(generation).generation)
	var manual_generation := int(timeout_race.start(reset_generation).generation)
	var manual_failure := timeout_race.fail(&"caller_abort", manual_generation)
	_check(
		manual_failure.accepted
		and manual_failure.failure_reason == &"caller_abort"
		and failures == PackedStringArray(["timeout:1", "caller_abort:3"]),
		"the explicit fail API records one caller-owned reason after recovery"
	)

	var invalid := TimedRace.new(ROUTE, 0, NAN, 0.0)
	_check(
		not invalid.is_configuration_valid()
		and invalid.get_configuration_errors().size() == 3
		and invalid.start(0).reason == &"invalid_configuration",
		"invalid laps and non-finite or non-positive clocks fail closed"
	)
	var invalid_delta := TimedRace.new(ROUTE, 1, 0.0, 5.0)
	var invalid_generation := int(invalid_delta.start(0).generation)
	var before_invalid := invalid_delta.get_snapshot()
	_check(
		invalid_delta.advance_physics(-0.1, invalid_generation).reason == &"invalid_delta"
		and invalid_delta.get_snapshot() == before_invalid,
		"negative physics delta cannot mutate timing state"
	)


func _test_signal_reentrancy_and_overflow() -> void:
	var race := TimedRace.new(ROUTE, 1, 0.0, 20.0)
	var observations: Array[Dictionary] = []
	race.countdown_started.connect(
		func(_id: StringName, _seconds: float, generation: int) -> void:
			observations.append(_probe_reentrant_mutators(&"countdown", race, generation))
	)
	race.race_started.connect(
		func(_id: StringName, generation: int) -> void:
			observations.append(_probe_reentrant_mutators(&"active", race, generation))
	)
	race.penalty_applied.connect(
		func(_id: StringName, _seconds: float, _reason: StringName, _total: float, generation: int) -> void:
			observations.append(_probe_reentrant_mutators(&"penalty", race, generation))
	)
	race.checkpoint_reached.connect(
		func(_id: StringName, _index: int, _lap: int, generation: int) -> void:
			observations.append(_probe_reentrant_mutators(&"checkpoint", race, generation))
	)
	race.lap_completed.connect(
		func(_id: StringName, _lap: int, _time: float, generation: int) -> void:
			observations.append(_probe_reentrant_mutators(&"lap", race, generation))
	)
	race.completed.connect(
		func(_id: StringName, _last: float, _best: float, generation: int) -> void:
			observations.append(_probe_reentrant_mutators(&"complete", race, generation))
	)
	race.race_reset.connect(
		func(_id: StringName, generation: int) -> void:
			observations.append(_probe_reentrant_mutators(&"reset", race, generation))
	)
	race.failed.connect(
		func(_id: StringName, _reason: StringName, generation: int) -> void:
			observations.append(_probe_reentrant_mutators(&"failed", race, generation))
	)

	var generation := int(race.start(0).generation)
	_check(
		int(race.get_snapshot().state) == TimedRace.State.ACTIVE
		and int(race.get_snapshot().generation) == 1,
		"a malicious zero-countdown subscriber cannot reset before ACTIVE commits"
	)
	race.apply_penalty(0.25, &"probe", generation)
	for checkpoint_index in ROUTE.get_checkpoint_count():
		race.submit_checkpoint(checkpoint_index, generation)
	var reset_generation := int(race.reset(generation).generation)
	var failure_generation := int(race.start(reset_generation).generation)
	race.fail(&"probe_failure", failure_generation)

	var labels := PackedStringArray()
	var every_probe_rejected := true
	for observation: Dictionary in observations:
		labels.append(str(observation.label))
		every_probe_rejected = (
			every_probe_rejected
			and bool(observation.all_reentrant)
			and bool(observation.snapshot_unchanged)
		)
	_check(
		every_probe_rejected,
		"every public mutator returns reentrant_call without changing signal-observer state"
	)
	_check(
		labels == PackedStringArray([
			"countdown", "active", "penalty", "checkpoint", "checkpoint",
			"checkpoint", "checkpoint", "checkpoint", "lap", "complete",
			"reset", "countdown", "active", "failed",
		]),
		"malicious subscribers preserve exact checkpoint to lap to complete signal order"
	)
	var initial_countdown := observations[0].snapshot as Dictionary
	var initial_active := observations[1].snapshot as Dictionary
	var penalty_state := observations[2].snapshot as Dictionary
	var final_checkpoint := observations[7].snapshot as Dictionary
	var lap_state := observations[8].snapshot as Dictionary
	var complete_state := observations[9].snapshot as Dictionary
	var reset_state := observations[10].snapshot as Dictionary
	var failed_state := observations[13].snapshot as Dictionary
	_check(
		int(initial_countdown.state) == TimedRace.State.COUNTDOWN
		and int(initial_countdown.generation) == 1
		and int(initial_active.state) == TimedRace.State.ACTIVE
		and int(initial_active.generation) == 1,
		"countdown and ACTIVE observers see committed generation one states"
	)
	_check(
		is_equal_approx(float(penalty_state.penalty_seconds), 0.25)
		and int(final_checkpoint.next_checkpoint_index) == ROUTE.get_checkpoint_count(),
		"penalty and checkpoint observers see their committed post-state"
	)
	_check(
		int(lap_state.state) == TimedRace.State.COMPLETED
		and int(lap_state.current_lap) == 1
		and int(lap_state.next_checkpoint_index) == 0
		and lap_state == complete_state,
		"final lap state is committed before lap_completed and remains exact for completed"
	)
	_check(
		int(reset_state.state) == TimedRace.State.IDLE
		and int(reset_state.generation) == 2
		and int(failed_state.state) == TimedRace.State.FAILED
		and int(failed_state.generation) == 3,
		"reset and failure observers see exact committed replacement generations"
	)

	var elapsed_overflow := TimedRace.new(ROUTE, 1, 0.0, 1.79e308)
	var elapsed_generation := int(elapsed_overflow.start(0).generation)
	_check(
		elapsed_overflow.advance_physics(1.0e308, elapsed_generation).accepted,
		"a very large but finite physics time remains representable"
	)
	var before_elapsed_overflow := elapsed_overflow.get_snapshot()
	_check(
		elapsed_overflow.advance_physics(1.0e308, elapsed_generation).reason == &"time_overflow"
		and elapsed_overflow.get_snapshot() == before_elapsed_overflow,
		"finite delta whose addition overflows is rejected before timing mutation"
	)
	var penalty_overflow := TimedRace.new(ROUTE, 1, 0.0, 1.79e308)
	var penalty_generation := int(penalty_overflow.start(0).generation)
	_check(
		penalty_overflow.apply_penalty(1.0e308, &"large", penalty_generation).accepted,
		"a very large but finite penalty remains representable"
	)
	var before_penalty_overflow := penalty_overflow.get_snapshot()
	_check(
		penalty_overflow.apply_penalty(1.0e308, &"overflow", penalty_generation).reason
		== &"time_overflow"
		and penalty_overflow.get_snapshot() == before_penalty_overflow,
		"finite penalty whose addition overflows is rejected without INF snapshot fields"
	)


func _probe_reentrant_mutators(
	label: StringName,
	race: TimedCheckpointRace,
	generation: int
) -> Dictionary:
	var before := race.get_snapshot()
	var results: Array[Dictionary] = [
		race.start(generation),
		race.advance_physics(0.25, generation),
		race.submit_checkpoint(0, generation),
		race.submit_position(ROUTE.get_checkpoint_position(0), generation),
		race.apply_penalty(0.25, &"reentrant_probe", generation),
		race.fail(&"reentrant_probe", generation),
		race.reset(generation),
	]
	var all_reentrant := true
	for result: Dictionary in results:
		all_reentrant = all_reentrant and not bool(result.accepted) and result.reason == &"reentrant_call"
	return {
		"label": label,
		"all_reentrant": all_reentrant,
		"snapshot_unchanged": race.get_snapshot() == before,
		"snapshot": before,
	}


func _connect_signal_log(race: TimedCheckpointRace) -> void:
	race.countdown_started.connect(
		func(_id: StringName, _seconds: float, generation: int) -> void:
			_signals.append("countdown:%d" % generation)
	)
	race.race_started.connect(
		func(_id: StringName, generation: int) -> void:
			_signals.append("active:%d" % generation)
	)
	race.checkpoint_reached.connect(
		func(_id: StringName, index: int, lap: int, generation: int) -> void:
			_signals.append("checkpoint:%d:%d:%d" % [generation, lap, index])
	)
	race.lap_completed.connect(
		func(_id: StringName, lap: int, lap_time: float, generation: int) -> void:
			_signals.append("lap:%d:%d:%.3f" % [generation, lap, lap_time])
	)
	race.penalty_applied.connect(
		func(_id: StringName, seconds: float, _reason: StringName, _total: float, generation: int) -> void:
			_signals.append("penalty:%d:%.3f" % [generation, seconds])
	)
	race.completed.connect(
		func(_id: StringName, last_time: float, _best_time: float, generation: int) -> void:
			_signals.append("complete:%d:%.3f" % [generation, last_time])
	)
	race.race_reset.connect(
		func(_id: StringName, generation: int) -> void:
			_signals.append("reset:%d" % generation)
	)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TIMED_CHECKPOINT_RACE_TEST_OK")
		quit(0)
	else:
		print("TIMED_CHECKPOINT_RACE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
