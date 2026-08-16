extends SceneTree

## Focused adversarial contract for the production-neutral convoy lifecycle.

const ConvoyScript := preload("res://scripts/activities/convoy_escort_activity.gd")

const LEG_ALPHA := Vector3(20.0, 0.0, -100.0)
const LEG_BETA := Vector3(80.0, -5.0, -220.0)
const LEG_GAMMA := Vector3(140.0, -10.0, -340.0)
const CONVOY_ID: StringName = &"protected_ore_convoy"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_configuration_snapshot_and_authority_boundary()
	await _test_ordered_legs_safe_arrival_and_signal_guards()
	await _test_destroyed_lost_timeout_abort_and_reset()
	await _test_detach_reentry_and_time_overflow()
	_finish()


func _test_configuration_snapshot_and_authority_boundary() -> void:
	var fixture := _fixture()
	var activity := fixture.activity as ConvoyEscortActivity
	var definition := fixture.definition as ActivityDefinition
	var report := activity.audit()
	_check(
		bool(report.get("valid", false))
			and report.get("activity_id") == &"convoy_escort_fixture"
			and int(report.get("leg_count", -1)) == 3
			and report.get("definition_snapshot_policy")
				== &"deep_copy_from_activity_director_registration"
			and report.get("clock_policy") == &"caller_physics_delta_only",
		"a valid director registration becomes a detached ordered-leg escort configuration"
	)
	definition.activity_id = &"caller_mutated_definition"
	definition.checkpoint_positions = PackedVector3Array([Vector3(999.0, 999.0, 999.0)])
	var after_mutation := activity.get_snapshot()
	_check(
		after_mutation.get("activity_id") == &"convoy_escort_fixture"
			and int(after_mutation.get("leg_count", -1)) == 3
			and after_mutation.get("next_leg_position") == Vector3.ZERO,
		"caller mutation cannot change the frozen activity identity or legs"
	)
	_check(
		not activity.is_processing()
			and not activity.is_physics_processing()
			and not bool(report.get("entity_movement_authority", true))
			and not bool(report.get("combat_authority", true))
			and not bool(report.get("damage_authority", true))
			and not bool(report.get("gameplay_authority", true))
			and not bool(report.get("grants_rewards", true))
			and not bool(report.get("cargo_authority", true))
			and not bool(report.get("ship_authority", true))
			and not bool(report.get("berth_authority", true))
			and not bool(report.get("game_flow_authority", true))
			and not bool(report.get("hud_authority", true))
			and not bool(report.get("save_authority", true))
			and not bool(report.get("network_authority", true)),
		"the component owns lifecycle only, with no movement, combat, reward, cargo, ship, berth, integration, save, or network authority"
	)
	var mutable := activity.audit()
	mutable["state_id"] = &"forged"
	(mutable.get("errors") as PackedStringArray).append("forged")
	var fresh := activity.audit()
	_check(
		fresh.get("state_id") == &"idle"
			and (fresh.get("errors") as PackedStringArray).is_empty(),
		"HUD-ready snapshots and audit collections are detached"
	)
	await _free_fixture(fixture)

	var invalid_director := ActivityDirector.new()
	root.add_child(invalid_director)
	var missing := ConvoyScript.new(invalid_director, &"missing_definition") as ConvoyEscortActivity
	root.add_child(missing)
	_check(
		not missing.is_configuration_valid()
			and missing.get_configuration_errors().has(
				"a valid director-registered ActivityDefinition is required"
			),
		"an unknown director definition is rejected"
	)
	var one_leg := _definition(&"one_leg_convoy", PackedVector3Array([LEG_ALPHA]))
	var duplicate_legs := _definition(
		&"duplicate_leg_convoy", PackedVector3Array([LEG_ALPHA, LEG_ALPHA])
	)
	var changed_identity := _definition(
		&"changed_identity_convoy", PackedVector3Array([LEG_ALPHA, LEG_BETA])
	)
	invalid_director.register_definition(one_leg)
	invalid_director.register_definition(duplicate_legs)
	invalid_director.register_definition(changed_identity)
	changed_identity.activity_id = &"mutated_after_registration"
	var too_short := ConvoyScript.new(invalid_director, one_leg.activity_id) as ConvoyEscortActivity
	var duplicate := ConvoyScript.new(
		invalid_director, duplicate_legs.activity_id
	) as ConvoyEscortActivity
	var invalid_limits := ConvoyScript.new(
		invalid_director, one_leg.activity_id, NAN, 0.0, INF
	) as ConvoyEscortActivity
	var mismatched_identity := ConvoyScript.new(
		invalid_director, &"changed_identity_convoy"
	) as ConvoyEscortActivity
	root.add_child(too_short)
	root.add_child(duplicate)
	root.add_child(invalid_limits)
	root.add_child(mismatched_identity)
	_check(
		not too_short.is_configuration_valid()
			and too_short.get_configuration_errors().has(
				"convoy escort requires at least two ordered legs"
			)
			and not duplicate.is_configuration_valid()
			and duplicate.get_configuration_errors().has(
				"ordered convoy legs cannot duplicate consecutive positions"
			)
			and not invalid_limits.is_configuration_valid()
			and mismatched_identity.get_configuration_errors().has(
				"director registration identity changed before composition"
			),
		"short, duplicate, non-finite, and registration-mutated configurations fail closed"
	)
	invalid_director.queue_free()
	missing.queue_free()
	too_short.queue_free()
	duplicate.queue_free()
	invalid_limits.queue_free()
	mismatched_identity.queue_free()
	await process_frame


func _test_ordered_legs_safe_arrival_and_signal_guards() -> void:
	var fixture := _fixture(50.0, 3.0, 20.0)
	var activity := fixture.activity as ConvoyEscortActivity
	var probe := _attach_reentry_probe(activity)
	_check(
		not bool(activity.start(&"Bad Convoy ID", -1, 0).get("accepted", true)),
		"invalid protected-convoy identity and generation are rejected"
	)
	var started := activity.start(CONVOY_ID, 12, 0)
	var generation := int(started.get("generation", -1))
	_check(
		bool(started.get("accepted", false))
			and generation == 1
			and int(started.get("state", -1)) == ConvoyEscortActivity.State.ACTIVE
			and started.get("convoy_id") == CONVOY_ID
			and int(started.get("convoy_generation", -1)) == 12,
		"start binds one exact protected convoy to a fresh activity generation"
	)
	_check(
		activity.start(CONVOY_ID, 12, generation).get("reason") == &"already_active"
			and activity.submit_entity_sample(
				&"wrong_convoy", 12, LEG_ALPHA, LEG_ALPHA, ConvoyEscortActivity.EntityStatus.ACTIVE, generation
			).get("reason") == &"wrong_convoy_identity"
			and activity.submit_entity_sample(
				CONVOY_ID, 11, LEG_ALPHA, LEG_ALPHA, ConvoyEscortActivity.EntityStatus.ACTIVE, generation
			).get("reason") == &"stale_convoy_generation"
			and activity.submit_entity_sample(
				CONVOY_ID, 12, Vector3.INF, LEG_ALPHA, ConvoyEscortActivity.EntityStatus.ACTIVE, generation
			).get("reason") == &"invalid_position"
			and activity.submit_entity_sample(
				CONVOY_ID, 12, LEG_ALPHA, LEG_ALPHA, 99, generation
			).get("reason") == &"invalid_entity_status"
			and activity.submit_entity_sample(
				CONVOY_ID, 12, Vector3(1.0e20, 0.0, 0.0),
				Vector3(-1.0e20, 0.0, 0.0),
				ConvoyEscortActivity.EntityStatus.ACTIVE, generation
			).get("reason") == &"distance_overflow"
			and int(activity.get_snapshot().get("sample_count", -1)) == 0,
		"wrong identity, stale entity generation, and malformed or overflowing samples cannot drift state"
	)

	var alpha := activity.submit_entity_sample(
		CONVOY_ID, 12, LEG_ALPHA, LEG_ALPHA + Vector3(10.0, 0.0, 0.0),
		ConvoyEscortActivity.EntityStatus.ACTIVE, generation
	)
	var out_of_order := activity.submit_entity_sample(
		CONVOY_ID, 12, LEG_GAMMA, LEG_GAMMA,
		ConvoyEscortActivity.EntityStatus.ACTIVE, generation
	)
	var beta := activity.submit_entity_sample(
		CONVOY_ID, 12, LEG_BETA, LEG_BETA + Vector3(20.0, 0.0, 0.0),
		ConvoyEscortActivity.EntityStatus.ACTIVE, generation
	)
	_check(
		alpha.get("reason") == &"leg_reached"
			and out_of_order.get("reason") == &"sample_recorded"
			and int(out_of_order.get("completed_leg_count", -1)) == 1
			and beta.get("reason") == &"leg_reached"
			and int(beta.get("completed_leg_count", -1)) == 2,
		"only the next ordered convoy leg can advance progress"
	)
	var waiting := activity.submit_entity_sample(
		CONVOY_ID, 12, LEG_GAMMA, LEG_GAMMA + Vector3(60.0, 0.0, 0.0),
		ConvoyEscortActivity.EntityStatus.ACTIVE, generation
	)
	_check(
		waiting.get("reason") == &"final_leg_waiting_for_escort"
			and int(waiting.get("state", -1)) == ConvoyEscortActivity.State.ACTIVE
			and int(waiting.get("completed_leg_count", -1)) == 2
			and is_zero_approx(float(waiting.get("elapsed_seconds", -1.0))),
		"the final leg cannot become safe arrival while the escort is outside proximity, and samples advance no time"
	)
	var separated := activity.advance_physics(2.5, generation)
	_check(
		bool(separated.get("accepted", false))
			and is_equal_approx(float(separated.get("separation_elapsed_seconds", -1.0)), 2.5)
			and int(separated.get("state", -1)) == ConvoyEscortActivity.State.ACTIVE,
		"caller physics delta alone advances bounded separation time"
	)
	var arrived := activity.submit_entity_sample(
		CONVOY_ID, 12, LEG_GAMMA, LEG_GAMMA + Vector3(50.0, 0.0, 0.0),
		ConvoyEscortActivity.EntityStatus.ACTIVE, generation
	)
	_check(
		arrived.get("reason") == &"safely_arrived"
			and int(arrived.get("state", -1)) == ConvoyEscortActivity.State.COMPLETED
			and arrived.get("terminal_result_id") == &"safely_arrived"
			and is_zero_approx(float(arrived.get("separation_elapsed_seconds", -1.0)))
			and is_equal_approx(float(arrived.get("progress_fraction", -1.0)), 1.0),
		"escort proximity is inclusive and commits safe arrival at the final ordered leg"
	)
	_check(
		activity.submit_entity_sample(
			CONVOY_ID, 12, LEG_GAMMA, LEG_GAMMA,
			ConvoyEscortActivity.EntityStatus.ACTIVE, generation
		).get("reason") == &"not_active",
		"terminal completion cannot emit or complete twice"
	)
	_check(
		(probe.get("kinds") as Array) == [
			&"started", &"leg_reached", &"leg_reached", &"leg_reached", &"safely_arrived"
		]
			and (probe.get("states") as Array) == [
				&"active", &"active", &"active", &"completed", &"completed"
			]
			and _probe_reentry_was_strict(probe),
		"all lifecycle signals observe committed state and reject nested mutation"
	)
	await _free_fixture(fixture)


func _test_destroyed_lost_timeout_abort_and_reset() -> void:
	var fixture := _fixture(40.0, 3.0, 10.0)
	var activity := fixture.activity as ConvoyEscortActivity
	var probe := _attach_reentry_probe(activity)
	var start_destroyed := activity.start(CONVOY_ID, 20, 0)
	var destroyed_generation := int(start_destroyed.get("generation", -1))
	var destroyed := activity.submit_entity_sample(
		CONVOY_ID, 20, Vector3.ZERO, Vector3.ZERO,
		ConvoyEscortActivity.EntityStatus.DESTROYED, destroyed_generation
	)
	_check(
		destroyed.get("reason") == &"convoy_destroyed"
			and destroyed.get("terminal_result_id") == &"convoy_destroyed"
			and int(destroyed.get("state", -1)) == ConvoyEscortActivity.State.FAILED,
		"a caller-reported destroyed convoy commits its distinct terminal result"
	)
	var reset_destroyed := activity.reset(destroyed_generation)
	var reset_generation := int(reset_destroyed.get("generation", -1))
	_check(
		bool(reset_destroyed.get("accepted", false))
			and int(reset_destroyed.get("state", -1)) == ConvoyEscortActivity.State.IDLE
			and reset_destroyed.get("convoy_id") == &""
			and activity.submit_entity_sample(
				CONVOY_ID, 20, Vector3.ZERO, Vector3.ZERO,
				ConvoyEscortActivity.EntityStatus.ACTIVE, destroyed_generation
			).get("reason") == &"stale_generation",
		"reset clears the convoy binding and tombstones delayed samples"
	)

	var lost_start := activity.start(CONVOY_ID, 21, reset_generation)
	var lost_generation := int(lost_start.get("generation", -1))
	var reported_lost := activity.submit_entity_sample(
		CONVOY_ID, 21, Vector3.ZERO, Vector3.ZERO,
		ConvoyEscortActivity.EntityStatus.LOST, lost_generation
	)
	_check(
		reported_lost.get("terminal_result_id") == &"convoy_lost"
			and reported_lost.get("terminal_reason") == &"convoy_reported_lost",
		"caller-reported convoy loss remains distinct from destruction"
	)
	var after_lost_reset := activity.reset(lost_generation)
	var separation_start := activity.start(
		CONVOY_ID, 22, int(after_lost_reset.get("generation", -1))
	)
	var separation_generation := int(separation_start.get("generation", -1))
	activity.submit_entity_sample(
		CONVOY_ID, 22, Vector3.ZERO, Vector3(41.0, 0.0, 0.0),
		ConvoyEscortActivity.EntityStatus.ACTIVE, separation_generation
	)
	await process_frame
	await process_frame
	_check(
		is_zero_approx(float(activity.get_snapshot().get("elapsed_seconds", -1.0)))
			and is_zero_approx(float(activity.get_snapshot().get("separation_elapsed_seconds", -1.0))),
		"samples and tree frames cannot advance timeout or separation clocks"
	)
	activity.advance_physics(2.99, separation_generation)
	var separation_failure := activity.advance_physics(0.01, separation_generation)
	_check(
		separation_failure.get("terminal_result_id") == &"convoy_lost"
			and separation_failure.get("terminal_reason") == &"escort_separation_exceeded",
		"continuous separation fails exactly at its configured physics-time bound"
	)

	var timeout_reset := activity.reset(separation_generation)
	var timeout_start := activity.start(
		CONVOY_ID, 23, int(timeout_reset.get("generation", -1))
	)
	var timeout_generation := int(timeout_start.get("generation", -1))
	activity.submit_entity_sample(
		CONVOY_ID, 23, Vector3.ZERO, Vector3.ZERO,
		ConvoyEscortActivity.EntityStatus.ACTIVE, timeout_generation
	)
	activity.advance_physics(9.99, timeout_generation)
	var timeout := activity.advance_physics(0.01, timeout_generation)
	_check(
		timeout.get("terminal_result_id") == &"timeout"
			and timeout.get("terminal_reason") == &"timeout"
			and is_equal_approx(float(timeout.get("elapsed_seconds", -1.0)), 10.0),
		"overall timeout is physics-only and terminal exactly at its bound"
	)

	var abort_reset := activity.reset(timeout_generation)
	var abort_start := activity.start(
		CONVOY_ID, 24, int(abort_reset.get("generation", -1))
	)
	var abort_generation := int(abort_start.get("generation", -1))
	var aborted := activity.abort(&"operator_returned_to_station", abort_generation)
	var final_reset := activity.reset(abort_generation)
	_check(
		aborted.get("terminal_result_id") == &"aborted"
			and aborted.get("terminal_reason") == &"operator_returned_to_station"
			and int(aborted.get("state", -1)) == ConvoyEscortActivity.State.ABORTED
			and int(final_reset.get("state", -1)) == ConvoyEscortActivity.State.IDLE,
		"abort publishes its reason and reset returns to a clean reusable idle state"
	)
	_check(
		(probe.get("kinds") as Array).has(&"failed")
			and (probe.get("kinds") as Array).has(&"aborted")
			and (probe.get("kinds") as Array).has(&"reset")
			and _probe_reentry_was_strict(probe),
		"failure, abort, and reset signals also reject every reentrant mutation"
	)
	await _free_fixture(fixture)


func _test_detach_reentry_and_time_overflow() -> void:
	var fixture := _fixture(60.0, 5.0, 30.0)
	var director := fixture.director as ActivityDirector
	var activity := fixture.activity as ConvoyEscortActivity
	var signal_counter := {"value": 0}
	activity.leg_reached.connect(
		func(_id: StringName, _index: int, _generation: int) -> void:
			signal_counter["value"] = int(signal_counter.get("value", 0)) + 1
	)
	var started := activity.start(CONVOY_ID, 30, 0)
	var generation := int(started.get("generation", -1))
	activity.submit_entity_sample(
		CONVOY_ID, 30, LEG_ALPHA, LEG_ALPHA,
		ConvoyEscortActivity.EntityStatus.ACTIVE, generation
	)
	activity.advance_physics(1.0, generation)
	var before_detach := activity.get_snapshot()
	root.remove_child(activity)
	root.remove_child(director)
	await process_frame
	await process_frame
	_check(
		activity.get_snapshot() == before_detach and int(signal_counter.get("value", -1)) == 1,
		"whole activity/director detach preserves exact state and replays no signal"
	)
	root.add_child(director)
	root.add_child(activity)
	await process_frame
	await process_frame
	var after_reentry := activity.submit_entity_sample(
		CONVOY_ID, 30, LEG_BETA, LEG_BETA,
		ConvoyEscortActivity.EntityStatus.ACTIVE, generation
	)
	_check(
		after_reentry.get("reason") == &"leg_reached"
			and int(after_reentry.get("completed_leg_count", -1)) == 2
			and int(signal_counter.get("value", -1)) == 2,
		"re-entry resumes the same generation without duplicate progress"
	)
	await _free_fixture(fixture)

	var overflow_fixture := _fixture(60.0, 1.7e308, 1.7e308)
	var overflow_activity := overflow_fixture.activity as ConvoyEscortActivity
	var overflow_start := overflow_activity.start(CONVOY_ID, 31, 0)
	var overflow_generation := int(overflow_start.get("generation", -1))
	var first_huge := overflow_activity.advance_physics(1.0e308, overflow_generation)
	var before_overflow := overflow_activity.get_snapshot()
	var overflow := overflow_activity.advance_physics(1.0e308, overflow_generation)
	_check(
		bool(first_huge.get("accepted", false))
			and overflow.get("reason") == &"time_overflow"
			and overflow_activity.get_snapshot() == before_overflow,
		"finite physics-time overflow is rejected before any state mutation"
	)
	await _free_fixture(overflow_fixture)


func _fixture(
	proximity_radius: float = 50.0,
	separation_seconds: float = 3.0,
	configured_timeout_seconds: float = 20.0
) -> Dictionary:
	var director := ActivityDirector.new()
	director.name = "ConvoyActivityDirector"
	root.add_child(director)
	var definition := _definition(
		&"convoy_escort_fixture", PackedVector3Array([LEG_ALPHA, LEG_BETA, LEG_GAMMA])
	)
	_check(director.register_definition(definition), "fixture definition registers with ActivityDirector")
	var activity := ConvoyScript.new(
		director,
		definition.activity_id,
		proximity_radius,
		separation_seconds,
		configured_timeout_seconds
	) as ConvoyEscortActivity
	activity.name = "ConvoyEscortActivity"
	root.add_child(activity)
	return {
		"director": director,
		"definition": definition,
		"activity": activity,
	}


func _free_fixture(fixture: Dictionary) -> void:
	var activity := fixture.get("activity") as ConvoyEscortActivity
	var director := fixture.get("director") as ActivityDirector
	if is_instance_valid(activity):
		activity.queue_free()
	if is_instance_valid(director):
		director.queue_free()
	await process_frame


func _definition(activity_id: StringName, legs: PackedVector3Array) -> ActivityDefinition:
	var location := WorldLocationDefinition.new()
	location.location_id = &"convoy_test_location"
	location.display_name = "Convoy test location"
	location.sector_id = &"convoy_test_sector"
	location.content_note = "Focused production-neutral convoy escort fixture."
	location.anchor_source_id = &"convoy_test_anchor"
	location.anchor_position = Vector3.ZERO
	location.scene_origin_position = Vector3.ZERO
	var definition := ActivityDefinition.new()
	definition.activity_id = activity_id
	definition.display_name = "Focused convoy escort"
	definition.activity_kind = ActivityDefinition.ACTIVITY_KIND_CHECKPOINT_ROUTE
	definition.content_note = "Ordered test legs only; no production route or geometry claim."
	definition.location = location
	definition.checkpoint_positions = legs
	definition.checkpoint_radius = 15.0
	return definition


func _attach_reentry_probe(activity: ConvoyEscortActivity) -> Dictionary:
	var probe := {
		"kinds": [],
		"states": [],
		"nested_results": [],
	}
	var observe := func(kind: StringName) -> void:
		var snapshot := activity.get_snapshot()
		var generation := int(snapshot.get("generation", -1))
		(probe.get("kinds") as Array).append(kind)
		(probe.get("states") as Array).append(snapshot.get("state_id"))
		(probe.get("nested_results") as Array).append([
			activity.start(&"nested_convoy", 99, generation),
			activity.submit_entity_sample(
				&"nested_convoy", 99, Vector3.ZERO, Vector3.ZERO,
				ConvoyEscortActivity.EntityStatus.ACTIVE, generation
			),
			activity.advance_physics(0.1, generation),
			activity.abort(&"nested_abort", generation),
			activity.reset(generation),
		])
	activity.started.connect(
		func(_id: StringName, _generation: int, _convoy_id: StringName, _convoy_gen: int) -> void:
			observe.call(&"started")
	)
	activity.leg_reached.connect(
		func(_id: StringName, _index: int, _generation: int) -> void:
			observe.call(&"leg_reached")
	)
	activity.safely_arrived.connect(
		func(_id: StringName, _generation: int) -> void:
			observe.call(&"safely_arrived")
	)
	activity.failed.connect(
		func(_id: StringName, _result: int, _reason: StringName, _generation: int) -> void:
			observe.call(&"failed")
	)
	activity.aborted.connect(
		func(_id: StringName, _reason: StringName, _generation: int) -> void:
			observe.call(&"aborted")
	)
	activity.escort_reset.connect(
		func(_id: StringName, _generation: int) -> void:
			observe.call(&"reset")
	)
	return probe


func _probe_reentry_was_strict(probe: Dictionary) -> bool:
	for result_group in probe.get("nested_results", []) as Array:
		for result in result_group as Array:
			var outcome := result as Dictionary
			if bool(outcome.get("accepted", true)) or outcome.get("reason") != &"reentrant_call":
				return false
	return not (probe.get("nested_results", []) as Array).is_empty()


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("CONVOY_ESCORT_ACTIVITY_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CONVOY_ESCORT_ACTIVITY_TEST_OK")
		quit(0)
	else:
		print("CONVOY_ESCORT_ACTIVITY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
