extends SceneTree

## Focused adversarial proof for the data-only station-defense authority. No
## combat resolver, spawner, damageable, ship, world, reward, HUD, or save owner
## participates in this fixture.

const ContractScript := preload("res://scripts/activities/station_defense_contract.gd")
const ActivityScript := preload("res://scripts/activities/station_defense_activity.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_ordered_simultaneous_waves_and_detach_reentry()
	_test_protected_asset_observations()
	_test_timeout_fail_abort_and_reset()
	_test_signal_reentry_and_hud_snapshot_detachment()
	_test_contract_validation_and_exact_authority_exclusions()
	_finish()


func _test_ordered_simultaneous_waves_and_detach_reentry() -> void:
	var activity := ActivityScript.new(_contract()) as StationDefenseActivity
	var chronology := PackedStringArray()
	var completion_count := {"value": 0}
	activity.activity_started.connect(func(snapshot: Dictionary) -> void:
		chronology.append("started:%d" % int(snapshot.generation))
	)
	activity.wave_started.connect(func(snapshot: Dictionary) -> void:
		chronology.append("wave_started:%d" % int(snapshot.current_wave_index))
	)
	activity.hostile_destruction_accepted.connect(
		func(snapshot: Dictionary, handle: Dictionary) -> void:
			chronology.append("hostile:%s:%d" % [str(handle.hostile_id), int(snapshot.current_wave_index)])
	)
	activity.wave_completed.connect(func(snapshot: Dictionary) -> void:
		chronology.append("wave_completed:%d" % int(snapshot.current_wave_index))
	)
	activity.activity_completed.connect(func(_snapshot: Dictionary) -> void:
		completion_count.value = int(completion_count.value) + 1
		chronology.append("completed")
	)

	var started := activity.start(0)
	var generation := int(started.generation)
	_check(
		started.accepted
		and generation == 1
		and int(started.state) == ActivityScript.State.ACTIVE
		and not bool(started.wave_active)
		and is_equal_approx(float(started.wave_delay_remaining_seconds), 2.0),
		"generation one starts at the first caller-timed wave delay"
	)
	_check(
		activity.start(generation).reason == &"already_active"
		and activity.advance(0.1, 0).reason == &"stale_generation"
		and activity.advance(NAN, generation).reason == &"invalid_delta"
		and activity.advance(-0.1, generation).reason == &"invalid_delta",
		"duplicate start, stale generation, and malformed deltas fail without progress"
	)
	var before_frames := activity.get_snapshot()
	await process_frame
	await process_frame
	_check(activity.get_snapshot() == before_frames, "process frames cannot age wave or timeout clocks")
	_check(
		activity.advance(0.0, generation).reason == &"no_delta"
		and activity.advance(1.25, generation).accepted
		and is_equal_approx(float(activity.get_snapshot().wave_delay_remaining_seconds), 0.75),
		"only accepted caller physics delta advances the wave delay"
	)
	var before_detach := activity.get_snapshot()
	_check(activity.detach(generation).accepted, "active authority can detach without resetting its objective")
	_check(
		activity.advance(10.0, generation).reason == &"detached"
		and activity.hostile_destroyed(_hostile(&"raider_a", 1), generation).reason == &"detached"
		and is_equal_approx(float(activity.get_snapshot().elapsed_seconds), float(before_detach.elapsed_seconds)),
		"detachment blocks observations and physics time without state drift"
	)
	_check(
		activity.reattach(0).reason == &"stale_generation"
		and activity.reattach(generation).accepted,
		"only the current activity generation can re-enter"
	)
	_check(
		activity.advance(0.75, generation).accepted
		and activity.get_snapshot().wave_active
		and (activity.get_snapshot().active_hostile_handles as Array).size() == 1
		and activity.get_snapshot().active_hostile_handles[0].hostile_id == &"raider_a",
		"finishing the first delay publishes only the next ordered hostile"
	)
	_check(
		activity.hostile_destroyed(_hostile(&"raider_b", 1), generation).reason == &"out_of_order"
		and activity.hostile_destroyed(_hostile(&"raider_c", 2), generation).reason == &"future_wave",
		"ordered and future-wave destruction observations cannot skip objective order"
	)
	_check(
		activity.hostile_destroyed(_hostile(&"raider_a", 2), generation).reason == &"stale_hostile_generation"
		and activity.hostile_destroyed(_hostile(&"missing", 1), generation).reason == &"unknown_hostile",
		"stable hostile identity distinguishes stale generations from unknown IDs"
	)
	_check(activity.hostile_destroyed(_hostile(&"raider_a", 1), generation).accepted, "the first exact ordered hostile advances")
	_check(
		activity.hostile_destroyed(_hostile(&"raider_a", 1), generation).reason == &"duplicate_hostile_event"
		and activity.get_snapshot().active_hostile_handles[0].hostile_id == &"raider_b",
		"an accepted hostile destruction cannot be replayed"
	)
	_check(
		activity.hostile_destroyed(_hostile(&"raider_b", 1), generation).accepted
		and int(activity.get_snapshot().current_wave_index) == 1
		and not bool(activity.get_snapshot().wave_active)
		and is_equal_approx(float(activity.get_snapshot().wave_delay_remaining_seconds), 1.0),
		"the ordered wave completes into the next caller-timed delay"
	)
	activity.advance(1.0, generation)
	var simultaneous := activity.get_snapshot()
	_check(
		simultaneous.wave_mode_id == "simultaneous"
		and (simultaneous.active_hostile_handles as Array).size() == 2,
		"simultaneous mode publishes every remaining current-wave hostile"
	)
	_check(activity.hostile_destroyed(_hostile(&"raider_d", 3), generation).accepted, "simultaneous wave accepts either hostile first")
	var completed := activity.hostile_destroyed(_hostile(&"raider_c", 2), generation)
	_check(
		completed.accepted
		and completed.reason == &"completed"
		and int(completed.state) == ActivityScript.State.COMPLETED
		and int(completed.remaining_hostile_count) == 0
		and int(completion_count.value) == 1,
		"the final exact hostile commits completion once"
	)
	_check(
		activity.hostile_destroyed(_hostile(&"raider_c", 2), generation).reason == &"duplicate_hostile_event"
		and activity.start(generation).reason == &"reset_required"
		and int(completion_count.value) == 1,
		"post-completion replay cannot emit completion again or implicitly restart"
	)
	_check(
		chronology == PackedStringArray([
			"started:1",
			"wave_started:0",
			"hostile:raider_a:0",
			"hostile:raider_b:0",
			"wave_completed:0",
			"wave_started:1",
			"hostile:raider_d:1",
			"hostile:raider_c:1",
			"wave_completed:1",
			"completed",
		]),
		"accepted wave lifecycle signals have deterministic post-state order"
	)
	_check(activity.audit().valid, "ordered/simultaneous completion finishes with a valid deterministic audit")


func _test_protected_asset_observations() -> void:
	var activity := ActivityScript.new(_contract()) as StationDefenseActivity
	var failed_count := {"value": 0}
	activity.activity_failed.connect(func(_snapshot: Dictionary) -> void:
		failed_count.value = int(failed_count.value) + 1
	)
	var generation := int(activity.start(0).generation)
	var first_damage := activity.protected_asset_damaged(
		_asset(&"command_core", 4), _event(&"damage_001", 7), generation
	)
	_check(
		first_damage.accepted
		and int(first_damage.accepted_asset_event_count) == 1
		and int(first_damage.protected_assets[0].damage_event_count) == 1,
		"a caller-observed damage event updates only bounded objective evidence"
	)
	_check(
		activity.protected_asset_damaged(
			_asset(&"dock_reactor", 2), _event(&"damage_001", 7), generation
		).reason == &"duplicate_protected_asset_event",
		"damage event identity cannot be replayed against a different asset"
	)
	_check(
		activity.protected_asset_damaged(
			_asset(&"command_core", 3), _event(&"damage_002", 7), generation
		).reason == &"stale_protected_asset_generation"
		and activity.protected_asset_damaged(
			_asset(&"unknown_asset", 1), _event(&"damage_002", 7), generation
		).reason == &"unknown_protected_asset",
		"protected-object handles reject stale generation and unknown stable identity"
	)
	_check(
		activity.protected_asset_damaged(
			_asset(&"command_core", 4), {"event_id": &"bad"}, generation
		).reason == &"invalid_event_handle",
		"malformed protected-object event handles fail closed"
	)
	var destroyed := activity.protected_asset_destroyed(
		_asset(&"dock_reactor", 2), _event(&"destroyed_001", 9), generation
	)
	_check(
		destroyed.accepted
		and destroyed.reason == &"protected_asset_destroyed"
		and int(destroyed.state) == ActivityScript.State.FAILED
		and destroyed.failure_reason == &"protected_asset_destroyed"
		and bool(destroyed.protected_assets[1].destroyed)
		and int(failed_count.value) == 1,
		"caller-observed protected asset destruction fails the objective without applying damage"
	)
	_check(
		activity.protected_asset_destroyed(
			_asset(&"dock_reactor", 2), _event(&"destroyed_001", 9), generation
		).reason == &"duplicate_protected_asset_event"
		and activity.protected_asset_destroyed(
			_asset(&"dock_reactor", 2), _event(&"destroyed_002", 9), generation
		).reason == &"protected_asset_already_destroyed"
		and int(failed_count.value) == 1,
		"duplicate destruction evidence cannot fail or signal twice"
	)
	_check(
		activity.protected_asset_damaged(
			_asset(&"command_core", 4), _event(&"damage_003", 7), generation
		).reason == &"not_active",
		"new asset evidence cannot mutate a terminal activity"
	)


func _test_timeout_fail_abort_and_reset() -> void:
	var timeout_contract := ContractScript.new(
		&"timed_defense",
		[_wave(&"late_wave", ContractScript.WaveMode.ORDERED, 20.0, [_hostile(&"late_raider", 1)])],
		[_asset(&"station_core", 1)],
		2.0
	) as StationDefenseContract
	var activity := ActivityScript.new(timeout_contract) as StationDefenseActivity
	var generation := int(activity.start(0).generation)
	_check(
		activity.advance(1.9, generation).accepted
		and activity.advance(0.1, generation).reason == &"timed_out"
		and int(activity.get_snapshot().state) == ActivityScript.State.TIMED_OUT
		and activity.get_snapshot().failure_reason == &"timeout",
		"the exact caller-physics timeout terminalizes a waiting wave"
	)
	_check(
		activity.advance(1.0, generation).reason == &"not_active"
		and activity.fail(&"late_failure", generation).reason == &"not_active"
		and activity.reset(0).reason == &"stale_generation",
		"timeout rejects late progression/failure and stale reset"
	)
	var reset := activity.reset(generation)
	var restarted := activity.start(int(reset.generation))
	_check(
		reset.accepted
		and int(reset.generation) == 2
		and restarted.accepted
		and int(restarted.generation) == 3,
		"explicit reset invalidates timeout callbacks before a fresh generation"
	)
	_check(
		activity.fail(&"hostiles_escaped", 3).accepted
		and int(activity.get_snapshot().state) == ActivityScript.State.FAILED
		and activity.get_snapshot().failure_reason == &"hostiles_escaped",
		"explicit fail accepts only a stable reason on the current active generation"
	)
	var reset_again := activity.reset(3)
	activity.start(int(reset_again.generation))
	_check(
		activity.abort(5).accepted
		and int(activity.get_snapshot().state) == ActivityScript.State.ABORTED
		and activity.get_snapshot().failure_reason == &"aborted",
		"abort is a distinct finite terminal state"
	)


func _test_signal_reentry_and_hud_snapshot_detachment() -> void:
	var contract := ContractScript.new(
		&"reentry_defense",
		[_wave(&"single", ContractScript.WaveMode.ORDERED, 0.0, [_hostile(&"single_raider", 1)])],
		[_asset(&"single_asset", 1)],
		30.0
	) as StationDefenseContract
	var activity := ActivityScript.new(contract) as StationDefenseActivity
	var observations: Array[Dictionary] = []
	activity.activity_started.connect(func(snapshot: Dictionary) -> void:
		observations.append(_probe_reentry(&"started", activity, snapshot))
	)
	activity.wave_started.connect(func(snapshot: Dictionary) -> void:
		observations.append(_probe_reentry(&"wave_started", activity, snapshot))
	)
	activity.protected_asset_damage_accepted.connect(
		func(snapshot: Dictionary, asset_handle: Dictionary, event_handle: Dictionary) -> void:
			asset_handle.clear()
			event_handle.clear()
			observations.append(_probe_reentry(&"asset_damage", activity, snapshot))
	)
	activity.hostile_destruction_accepted.connect(
		func(snapshot: Dictionary, hostile_handle: Dictionary) -> void:
			hostile_handle.clear()
			observations.append(_probe_reentry(&"hostile", activity, snapshot))
	)
	activity.wave_completed.connect(func(snapshot: Dictionary) -> void:
		observations.append(_probe_reentry(&"wave_completed", activity, snapshot))
	)
	activity.activity_completed.connect(func(snapshot: Dictionary) -> void:
		observations.append(_probe_reentry(&"completed", activity, snapshot))
	)
	activity.activity_reset.connect(func(snapshot: Dictionary) -> void:
		observations.append(_probe_reentry(&"reset", activity, snapshot))
	)
	var generation := int(activity.start(0).generation)
	activity.protected_asset_damaged(
		_asset(&"single_asset", 1), _event(&"probe_damage", 1), generation
	)
	activity.hostile_destroyed(_hostile(&"single_raider", 1), generation)
	activity.reset(generation)

	var failed_activity := ActivityScript.new(contract) as StationDefenseActivity
	failed_activity.protected_asset_destruction_accepted.connect(
		func(snapshot: Dictionary, asset_handle: Dictionary, event_handle: Dictionary) -> void:
			asset_handle.clear()
			event_handle.clear()
			observations.append(_probe_reentry(&"asset_destroyed", failed_activity, snapshot))
	)
	failed_activity.activity_failed.connect(func(snapshot: Dictionary) -> void:
		observations.append(_probe_reentry(&"failed", failed_activity, snapshot))
	)
	var failed_generation := int(failed_activity.start(0).generation)
	failed_activity.protected_asset_destroyed(
		_asset(&"single_asset", 1), _event(&"probe_destroyed", 1), failed_generation
	)

	var aborted_activity := ActivityScript.new(contract) as StationDefenseActivity
	aborted_activity.activity_aborted.connect(func(snapshot: Dictionary) -> void:
		observations.append(_probe_reentry(&"aborted", aborted_activity, snapshot))
	)
	var aborted_generation := int(aborted_activity.start(0).generation)
	aborted_activity.abort(aborted_generation)
	var labels := PackedStringArray()
	var all_guarded := true
	for observation in observations:
		labels.append(str(observation.label))
		all_guarded = all_guarded \
			and bool(observation.all_reentrant) \
			and bool(observation.snapshot_unchanged)
	_check(
		all_guarded,
		"every synchronous lifecycle signal rejects all mutator reentry without state change"
	)
	_check(
		labels == PackedStringArray([
			"started", "wave_started", "asset_damage", "hostile",
			"wave_completed", "completed", "reset", "asset_destroyed",
			"failed", "aborted",
		]),
		"signal dispatch is exact across start, evidence, completion, failure, abort, and reset"
	)
	_check(
		int(activity.get_snapshot().state) == ActivityScript.State.IDLE
		and int(activity.get_snapshot().generation) == 2
		and int(activity.get_snapshot().remaining_hostile_count) == 1
		and int(activity.get_snapshot().protected_assets[0].damage_event_count) == 0,
		"observer mutation cannot corrupt the HUD-ready reset snapshot"
	)
	var snapshot := activity.get_snapshot()
	(snapshot.protected_assets[0].handle as Dictionary).clear()
	(snapshot.protected_assets as Array).clear()
	(snapshot.active_hostile_handles as Array).append(_hostile(&"forged", 1))
	_check(
		(activity.get_snapshot().protected_assets as Array).size() == 1
		and (activity.get_snapshot().active_hostile_handles as Array).is_empty(),
		"nested HUD-ready snapshots are deeply detached"
	)


func _probe_reentry(
	label: StringName,
	activity: StationDefenseActivity,
	emitted: Dictionary
	) -> Dictionary:
	var generation := int(emitted.generation)
	var before := activity.get_snapshot()
	var results := [
		activity.start(generation),
		activity.advance(0.1, generation),
		activity.hostile_destroyed(_hostile(&"single_raider", 1), generation),
		activity.protected_asset_damaged(
			_asset(&"single_asset", 1), _event(&"reentry_damage", 1), generation
		),
		activity.protected_asset_destroyed(
			_asset(&"single_asset", 1), _event(&"reentry_destroy", 1), generation
		),
		activity.fail(&"observer_attack", generation),
		activity.abort(generation),
		activity.reset(generation),
		activity.detach(generation),
		activity.reattach(generation),
	]
	var all_reentrant := true
	for result: Dictionary in results:
		all_reentrant = all_reentrant and result.reason == &"reentrant_call"
	if not (emitted.protected_assets as Array).is_empty():
		((emitted.protected_assets as Array)[0] as Dictionary).clear()
	(emitted.active_hostile_handles as Array).clear()
	emitted["state"] = -100
	return {
		"label": label,
		"all_reentrant": all_reentrant,
		"snapshot_unchanged": activity.get_snapshot() == before,
	}


func _test_contract_validation_and_exact_authority_exclusions() -> void:
	var waves: Array[Dictionary] = [
		_wave(&"copy_wave", ContractScript.WaveMode.SIMULTANEOUS, 0.0, [_hostile(&"copy_hostile", 5)]),
	]
	var assets: Array[Dictionary] = [_asset(&"copy_asset", 8)]
	var contract := ContractScript.new(&"copy_defense", waves, assets, 12.0) as StationDefenseContract
	waves[0].wave_id = &"caller_mutation"
	(waves[0].hostile_handles as Array)[0].hostile_id = &"caller_mutation"
	assets[0].asset_id = &"caller_mutation"
	var first_snapshot := contract.get_snapshot()
	(first_snapshot.waves[0].hostile_handles[0] as Dictionary).clear()
	(first_snapshot.protected_asset_handles as Array).clear()
	_check(
		contract.is_configuration_valid()
		and contract.get_wave(0).wave_id == &"copy_wave"
		and contract.get_wave(0).hostile_handles[0].hostile_id == &"copy_hostile"
		and contract.get_protected_asset_handles()[0].asset_id == &"copy_asset",
		"contract construction and reads deeply detach all caller-supplied handle data"
	)
	var invalid_wave: Dictionary = {
		"wave_id": 42,
		"mode": "ordered",
		"delay_seconds": "soon",
		"hostile_handles": [{"hostile_id": 77, "generation": 1.5}],
		"unknown": true,
	}
	var invalid_waves: Array[Dictionary] = [invalid_wave, invalid_wave.duplicate(true)]
	var invalid_assets: Array[Dictionary] = [
		{"asset_id": &"same", "generation": 0},
		{"asset_id": &"same", "generation": 1},
	]
	var invalid := ContractScript.new(
		&"Bad Defense",
		invalid_waves,
		invalid_assets,
		NAN
	) as StationDefenseContract
	_check(
		not invalid.is_configuration_valid()
		and invalid.get_configuration_errors().size() >= 10
		and (ActivityScript.new(invalid) as StationDefenseActivity).start(0).reason == &"invalid_configuration",
		"malformed identities, types, duplicates, handles, modes, delay, and timeout fail closed"
	)
	var too_many_hostiles: Array[Dictionary] = []
	for index in ContractScript.MAX_HOSTILES_PER_WAVE + 1:
		too_many_hostiles.append(_hostile(StringName("bounded_%02d" % index), 1))
	var bounded := ContractScript.new(
		&"bounded_defense",
		[_wave(&"bounded_wave", ContractScript.WaveMode.SIMULTANEOUS, 0.0, too_many_hostiles)],
		[_asset(&"bounded_asset", 1)],
		10.0
	) as StationDefenseContract
	_check(
		not bounded.is_configuration_valid()
		and "hostiles per wave must be within 1..64" in bounded.get_configuration_errors(),
		"contract memory is explicitly bounded per wave"
	)
	var expected_authority := {
		"combat_resolution": false,
		"spawning": false,
		"damage": false,
		"rewards": false,
		"ships": false,
		"berths": false,
		"world_geometry": false,
		"hud": false,
		"game_flow": false,
		"main": false,
		"save": false,
		"network": false,
	}
	var activity := ActivityScript.new(contract) as StationDefenseActivity
	var audit_first := activity.audit()
	var audit_second := activity.audit()
	_check(
		audit_first == audit_second
		and audit_first.valid
		and audit_first.authority == expected_authority
		and contract.audit().authority == expected_authority,
		"contract and activity audits are deterministic and freeze exact authority exclusions"
	)
	(audit_first.authority as Dictionary)["combat_resolution"] = true
	(audit_first.snapshot as Dictionary)["generation"] = 999
	_check(
		activity.audit().authority == expected_authority
		and int(activity.get_snapshot().generation) == 0,
		"nested audit state and exclusions are deeply detached"
	)
	var activity_source := FileAccess.get_file_as_string(
		"res://scripts/activities/station_defense_activity.gd"
	)
	_check(
		not activity_source.contains("Time.")
		and not activity_source.contains("_process(")
		and not activity_source.contains("_physics_process("),
		"authority contains no wall-clock or hidden frame callback"
	)


func _contract() -> StationDefenseContract:
	return ContractScript.new(
		&"station_defense",
		[
			_wave(
				&"ordered_approach",
				ContractScript.WaveMode.ORDERED,
				2.0,
				[_hostile(&"raider_a", 1), _hostile(&"raider_b", 1)]
			),
			_wave(
				&"simultaneous_push",
				ContractScript.WaveMode.SIMULTANEOUS,
				1.0,
				[_hostile(&"raider_c", 2), _hostile(&"raider_d", 3)]
			),
		],
		[_asset(&"command_core", 4), _asset(&"dock_reactor", 2)],
		30.0
	) as StationDefenseContract


func _wave(
	wave_id: StringName,
	mode: int,
	delay_seconds: float,
	hostile_handles: Array[Dictionary]
	) -> Dictionary:
	return {
		"wave_id": wave_id,
		"mode": mode,
		"delay_seconds": delay_seconds,
		"hostile_handles": hostile_handles,
	}


func _hostile(hostile_id: StringName, generation: int) -> Dictionary:
	return {"hostile_id": hostile_id, "generation": generation}


func _asset(asset_id: StringName, generation: int) -> Dictionary:
	return {"asset_id": asset_id, "generation": generation}


func _event(event_id: StringName, generation: int) -> Dictionary:
	return {"event_id": event_id, "generation": generation}


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("STATION_DEFENSE_ACTIVITY_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("STATION_DEFENSE_ACTIVITY_TEST_OK")
		quit(0)
	else:
		print("STATION_DEFENSE_ACTIVITY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
