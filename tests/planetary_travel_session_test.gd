extends SceneTree

const SessionScript := preload("res://scripts/world/planetary_travel_session.gd")
const WorldScript := preload("res://scripts/world/definitions/planetary_world_definition.gd")
const AtmosphereScript := preload("res://scripts/world/definitions/planetary_atmosphere_profile.gd")
const TerrainScript := preload("res://scripts/world/planetary_terrain_profile.gd")
const RegionScript := preload("res://scripts/world/definitions/planetary_landing_region_definition.gd")
const FrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const LandingValidatorScript := preload("res://scripts/world/planetary_landing_composition_validator.gd")
const WorldValidatorScript := preload("res://scripts/world/planetary_world_composition_validator.gd")

const SESSION_ID: StringName = &"planetary_visit"
const WORLD_ID: StringName = &"ember_world"
const BODY_ID: StringName = &"ember_body"
const REGION_ID: StringName = &"ember_landing_region"
const TERRAIN_ID: StringName = &"default_planetary_terrain"
const ORBITAL_FRAME_ID: StringName = &"ember_system"
const BODY_RADIUS_METERS := 120_000.0
const CELL_SIZE_METERS := 10_000.0
const SHIFT_THRESHOLD_METERS := 5000.0

var _assertions := 0
var _failures := PackedStringArray()
var _signal_events: Array[Dictionary] = []
var _reentry_results: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_atmospheric_complete_loop_and_clock()
	_test_airless_branch_and_report_schema()
	await _test_absolute_coordinates_detach_reentry_and_rebase()
	_test_abort_fail_reset_and_deep_snapshots()
	_test_committed_signals_and_reentry_guard()
	_finish()


func _test_atmospheric_complete_loop_and_clock() -> void:
	var fixture := _fixture(true)
	var session := fixture.session as PlanetaryTravelSession
	var frame := fixture.frame as PlanetaryCoordinateFrame
	_check(session.is_configuration_valid(), "valid world and coordinate frame configure the session")
	_check(
		session.attach(WORLD_ID, frame, 1, 0, 0).accepted,
		"exact world/frame identity attaches generation zero",
	)
	var started := session.start(0, 1)
	_check(
		started.accepted and started.generation == 1
			and started.state_id == &"orbit_approach"
			and started.next_state_id == &"atmospheric_entry",
		"start commits generation one at atmospheric orbit approach",
	)
	var before_invalid := session.get_presentation_snapshot()
	for delta in [-0.01, NAN, INF, SessionScript.MAX_CALLER_PHYSICS_DELTA_SECONDS + 0.001]:
		_check(
			session.advance_physics(delta, 1, 1).reason == &"invalid_delta"
				and session.get_presentation_snapshot() == before_invalid,
			"invalid caller delta is rejected without state drift",
		)
	_check(
		session.advance_physics(0.0, 1, 1).reason == &"no_delta"
			and session.get_presentation_snapshot() == before_invalid,
		"zero caller delta freezes all clocks",
	)
	for delta in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
		_check(session.advance_physics(delta, 1, 1).accepted, "accepted physics delta advances")
	_check(
		is_equal_approx(float(session.get_presentation_snapshot().elapsed_seconds), 7.0 / 120.0),
		"mixed 30/60/120 Hz caller deltas accumulate deterministically",
	)
	var elapsed_30 := _elapsed_after_one_second(30)
	var elapsed_60 := _elapsed_after_one_second(60)
	var elapsed_120 := _elapsed_after_one_second(120)
	_check(
		is_equal_approx(elapsed_30, 1.0) and is_equal_approx(elapsed_60, 1.0)
			and is_equal_approx(elapsed_120, 1.0),
		"separate 30/60/120 Hz callers each commit exactly one physics second",
	)

	var orbit_anchor := _absolute(frame, Vector3(0.0, 220_000.0, 0.0))
	var atmosphere_edge := _absolute(frame, Vector3(0.0, 140_000.0, 0.0))
	var surface_flight_edge := _absolute(frame, Vector3(0.0, 122_500.0, 0.0))
	var before_order := session.get_presentation_snapshot()
	_check(
		session.submit_descent_sample(surface_flight_edge, 10.0, 1, 1, 1).reason
			== &"out_of_order" and session.get_presentation_snapshot() == before_order,
		"out-of-order absolute samples cannot skip a phase",
	)
	_check(
		session.submit_orbit_approach_sample(
			false, orbit_anchor, 300.0, 1, 1, 1
		).reason == &"orbit_approach_prerequisites_not_met",
		"an absolute position alone cannot claim orbital handoff",
	)
	_check(
		session.submit_orbit_approach_sample(true, orbit_anchor, 300.0, 1, 1, 1).accepted,
		"caller handoff plus canonical absolute observation enters atmosphere",
	)
	_check(
		session.submit_atmospheric_entry_sample(atmosphere_edge, 2500.0, 1, 1, 1).accepted,
		"composed atmosphere outer-shell boundary enters descent",
	)
	_check(
		session.submit_descent_sample(surface_flight_edge, 500.0, 1, 1, 1).reason
			== &"landing_composition_required",
		"descent cannot enter surface flight without a validated landing composition",
	)
	var report := fixture.report as Dictionary
	_check(
		session.bind_landing_composition_report(report, 1, 1).accepted,
		"the exact detached validator report binds the selected landing region",
	)
	_check(
		session.submit_descent_sample(surface_flight_edge, 500.0, 1, 1, 1).accepted,
		"descent enters surface flight only after report binding",
	)
	var identity := _landing_identity(report)
	_check(
		session.submit_landing_sample(false, identity, 1, 1).reason == &"landing_not_confirmed",
		"composition identity alone never claims the ship has landed",
	)
	_check(
		session.submit_landing_sample(true, identity, 1, 1).accepted,
		"caller-owned landed fact plus exact composition identity commits LANDED",
	)
	_check(
		session.submit_disembark_sample(true, true, 1, 1).accepted,
		"external on-foot and still-landed facts commit ON_FOOT",
	)
	_check(
		session.submit_reboard_sample(true, true, 1, 1).accepted,
		"external reboard and still-landed facts commit REBOARDED",
	)
	_check(
		session.submit_takeoff_sample(true, false, 1, 1).accepted,
		"external takeoff and not-landed facts commit TAKEOFF",
	)
	_check(
		session.submit_ascent_sample(
			true, _absolute(frame, Vector3(0.0, 128_500.0, 0.0)), 5.0, 1, 1, 1
		).accepted,
		"caller-confirmed surface clearance with absolute position commits ASCENT",
	)
	_check(
		session.submit_orbit_return_sample(orbit_anchor, 900.0, 1, 1, 1).accepted,
		"derived orbital altitude commits ORBIT_RETURN",
	)
	var completed := session.submit_completion_sample(true, orbit_anchor, 300.0, 1, 1, 1)
	_check(
		completed.accepted and completed.state_id == &"completed"
			and completed.transition_count == 10 and not completed.running,
		"return-anchor observation completes the exact atmospheric sequence once",
	)
	_check(
		session.submit_completion_sample(true, orbit_anchor, 0.0, 1, 1, 1).reason == &"not_running",
		"completed sessions cannot emit a second completion",
	)
	var audit := session.audit()
	_check(
		audit.valid and audit.uses_caller_physics_delta
			and audit.uses_absolute_orbital_coordinates
			and not audit.thresholds.landing_numeric_thresholds_defined
			and audit.thresholds.atmosphere_outer_radius_meters == 140_000.0
			and audit.thresholds.orbital_anchor_radius_meters == 220_000.0
			and not audit.gameplay_authority and not audit.ship_movement_authority
			and not audit.landing_authority and not audit.terrain_authority
			and not audit.reward_authority and not audit.streaming_authority
			and not audit.save_authority and not audit.render_authority,
		"audit derives shell/anchor boundaries, defines no numeric landing contract, and freezes zero authority",
	)
	var authority := audit.authority as Dictionary
	var exact_zero_authority := authority.size() == 12
	for key in SessionScript.LANDING_AUTHORITY_KEYS:
		exact_zero_authority = exact_zero_authority and authority.has(key) \
			and authority[key] is bool and not bool(authority[key])
	_check(exact_zero_authority, "session publishes the exact nested common 12-key zero-authority roster")


func _test_airless_branch_and_report_schema() -> void:
	var fixture := _fixture(false)
	var session := fixture.session as PlanetaryTravelSession
	var frame := fixture.frame as PlanetaryCoordinateFrame
	var report := fixture.report as Dictionary
	session.attach(WORLD_ID, frame, 1, 0, 0)
	session.start(0, 1)
	var approach := session.submit_orbit_approach_sample(
		true, _absolute(frame, Vector3(0.0, 220_000.0, 0.0)), 20.0, 1, 1, 1
	)
	_check(
		approach.accepted and approach.state_id == &"descent"
			and approach.branch_id == &"airless"
			and (approach.presentation as Dictionary).progress_total == 10,
		"airless approach skips atmospheric entry explicitly",
	)
	_check(
		session.submit_atmospheric_entry_sample({}, 0.0, 1, 1, 1).reason == &"out_of_order",
		"airless sessions cannot insert atmospheric entry",
	)
	var before_bad := session.get_presentation_snapshot()
	var malformed := _absolute(frame, Vector3(0.0, 122_500.0, 0.0))
	malformed["extra"] = true
	_check(
		session.submit_descent_sample(malformed, 0.0, 1, 1, 1).reason
			== &"invalid_orbital_coordinate"
			and session.get_presentation_snapshot() == before_bad,
		"noncanonical orbital-coordinate records are state preserving",
	)
	_check(
		session.submit_descent_sample(
			_absolute(frame, Vector3(0.0, 122_500.0, 0.0)), NAN, 1, 1, 1
		).reason == &"invalid_sample_speed",
		"non-finite speed observations fail closed",
	)
	var extra_report := report.duplicate(true)
	extra_report["unexpected"] = true
	_check(
		session.bind_landing_composition_report(extra_report, 1, 1).reason
			== &"invalid_landing_composition_schema",
		"landing reports reject extra fields instead of accepting lookalikes",
	)
	var world_report := fixture.world_report as Dictionary
	var world_report_snapshot := session.audit().world_composition as Dictionary
	world_report["world_id"] = &"foreign_world"
	_check(
		world_report_snapshot.world_id == WORLD_ID
			and session.is_configuration_valid(),
		"the validated world-composition report is frozen and detached at construction",
	)
	var forged_authority_report := world_report_snapshot.duplicate(true)
	(forged_authority_report.authority as Dictionary)["streaming"] = true
	var invalid_session := SessionScript.new(
		&"invalid_composition_session",
		fixture.world,
		frame,
		forged_authority_report,
	) as PlanetaryTravelSession
	_check(
		not invalid_session.is_configuration_valid()
			and invalid_session.attach(WORLD_ID, frame, 1, 0, 0).reason
			== &"invalid_configuration",
		"constructor rejects a world-composition report that claims authority",
	)
	var authority_report := report.duplicate(true)
	(authority_report.authority as Dictionary)["physics"] = true
	_check(
		session.bind_landing_composition_report(authority_report, 1, 1).reason
			== &"landing_composition_claims_authority",
		"a report forged to claim physics authority fails closed",
	)
	var foreign_report := report.duplicate(true)
	foreign_report["body_id"] = &"foreign_body"
	_check(
		session.bind_landing_composition_report(foreign_report, 1, 1).reason
			== &"landing_composition_identity_mismatch",
		"landing body identity must equal the configured coordinate frame",
	)
	_check(
		session.bind_landing_composition_report(report, 1, 1).accepted,
		"the unmodified exact airless report binds",
	)
	var wrong_identity := _landing_identity(report)
	wrong_identity["region_id"] = &"foreign_region"
	session.submit_descent_sample(
		_absolute(frame, Vector3(0.0, 122_500.0, 0.0)), 10.0, 1, 1, 1
	)
	_check(
		session.submit_landing_sample(true, wrong_identity, 1, 1).reason
			== &"landing_composition_identity_mismatch",
		"landing confirmation cannot substitute a different region identity",
	)


func _test_absolute_coordinates_detach_reentry_and_rebase() -> void:
	var fixture := _fixture(true)
	var session := fixture.session as PlanetaryTravelSession
	var frame := fixture.frame as PlanetaryCoordinateFrame
	session.attach(WORLD_ID, frame, 1, 0, 0)
	session.start(0, 1)
	session.advance_physics(0.2, 1, 1)
	var absolute_anchor := _absolute(frame, Vector3(0.0, 220_000.0, 0.0))
	session.submit_orbit_approach_sample(true, absolute_anchor, 20.0, 1, 1, 1)
	var before_detach := session.get_presentation_snapshot()
	var event_counter := {"count": 0}
	session.phase_changed.connect(
		func(_snapshot: Dictionary, _previous: StringName) -> void:
			event_counter["count"] = int(event_counter.count) + 1
	)
	_check(session.detach(1, 1).accepted, "active journey detaches explicitly")
	var detached := session.get_presentation_snapshot()
	_check(
		not detached.attached and detached.state_id == &"atmospheric_entry"
			and detached.elapsed_seconds == before_detach.elapsed_seconds
			and detached.last_sample == before_detach.last_sample,
		"detached snapshot preserves phase, time, and canonical absolute sample",
	)
	await process_frame
	await process_frame
	_check(session.get_presentation_snapshot() == detached, "scene-tree frames cannot advance a RefCounted session")
	_check(
		session.advance_physics(0.1, 1, 1).reason == &"not_attached",
		"detached caller time cannot mutate",
	)
	var replacement := _coordinate_frame()
	_check(
		session.attach(WORLD_ID, replacement, 1, 1, 1).reason == &"world_binding_mismatch",
		"a value-equivalent replacement frame cannot steal attachment",
	)
	var reattached := session.attach(WORLD_ID, frame, 1, 1, 1)
	_check(
		reattached.accepted and reattached.attachment_generation == 2
			and int(event_counter.count) == 0
			and reattached.elapsed_seconds == detached.elapsed_seconds,
		"same-frame reentry increments only attachment generation and replays no phase",
	)
	_check(
		session.submit_atmospheric_entry_sample(
			_absolute(frame, Vector3(0.0, 140_000.0, 0.0)), 20.0, 1, 1, 1
		).reason == &"stale_attachment_generation",
		"pre-detach producer tokens are retired",
	)

	var world_anchor_streaming := frame.orbital_to_world_streaming_position(absolute_anchor, 1)
	var request := frame.request_rebase(world_anchor_streaming.position, 1)
	var committed := frame.commit_rebase(int(request.request.request_id), 1)
	_check(request.accepted and committed.accepted and frame.get_generation() == 2, "fixture commits one coordinate-frame rebase")
	_check(
		session.submit_atmospheric_entry_sample(
			_absolute(frame, Vector3(0.0, 200_000.0, 0.0)), 20.0, 1, 1, 2
		).reason == &"stale_coordinate_frame_generation",
		"stale local-mapping generation is rejected after rebase",
	)
	var absolute_anchor_after := _absolute(frame, Vector3(0.0, 220_000.0, 0.0))
	_check(absolute_anchor_after == absolute_anchor, "canonical absolute orbital identity survives streaming-origin rebase")
	_check(
		session.submit_atmospheric_entry_sample(
			_absolute(frame, Vector3(0.0, 140_000.0, 0.0)), 20.0, 2, 1, 2
		).accepted,
		"current frame generation resumes using absolute observations",
	)
	var pre_rebase_report := fixture.report as Dictionary
	_check(
		session.bind_landing_composition_report(pre_rebase_report, 1, 2).accepted,
		"body-local landing composition remains identity-bound across streaming-origin rebase",
	)
	_check(
		session.submit_descent_sample(
			_absolute(frame, Vector3(0.0, 122_500.0, 0.0)), 20.0, 2, 1, 2
		).accepted
			and session.get_presentation_snapshot().coordinate_frame_generation == 2
			and session.get_presentation_snapshot().landing_composition.coordinate_frame_generation == 1,
		"current absolute sample generation and frozen body-local composition generation remain explicit",
	)


func _test_abort_fail_reset_and_deep_snapshots() -> void:
	var fixture := _fixture(false)
	var session := fixture.session as PlanetaryTravelSession
	var frame := fixture.frame as PlanetaryCoordinateFrame
	session.attach(WORLD_ID, frame, 1, 0, 0)
	session.bind_landing_composition_report(fixture.report, 0, 1)
	session.start(0, 1)
	_check(session.abort(&"", 1, 1).reason == &"invalid_terminal_reason", "terminal reasons require stable IDs")
	session.advance_physics(0.1, 1, 1)
	var aborted := session.abort(&"caller_cancelled", 1, 1)
	_check(
		aborted.accepted and aborted.state_id == &"aborted"
			and aborted.last_duration_seconds == aborted.elapsed_seconds,
		"abort commits a distinct terminal state and duration",
	)
	_check(session.fail(&"late_failure", 1, 1).reason == &"not_running", "terminal state admits no second fail result")
	var reset := session.reset(1, 1)
	_check(
		reset.accepted and reset.generation == 2 and reset.state_id == &"idle"
			and not reset.landing_composition_bound,
		"reset advances generation and clears per-journey landing composition",
	)
	var idle_snapshot := session.get_presentation_snapshot()
	_check(
		session.reset(2, 1).reason == &"already_idle"
			and session.get_presentation_snapshot() == idle_snapshot
			and session.get_generation() == 2,
		"reset from IDLE rejects without consuming a generation",
	)
	_check(
		session.fail(&"late_failure", 1, 1).reason == &"stale_generation",
		"reset tombstones delayed prior-generation terminal calls",
	)
	_check(session.start(2, 1).accepted and session.get_generation() == 3, "post-reset start allocates a fresh generation")
	var failed := session.fail(&"navigation_lost", 3, 1)
	_check(failed.accepted and failed.state_id == &"failed", "fail remains distinct from abort")

	var snapshot := session.get_presentation_snapshot()
	(snapshot.presentation as Dictionary)["objective"] = "tampered"
	(snapshot.last_sample as Dictionary)["forged"] = true
	(snapshot.landing_composition as Dictionary)["world_id"] = &"tampered"
	var audit := session.audit()
	(audit.world_definition as Dictionary)["world_id"] = &"tampered"
	var fresh := session.get_presentation_snapshot()
	var fresh_audit := session.audit()
	_check(
		(fresh.presentation as Dictionary).objective != "tampered"
			and not (fresh.last_sample as Dictionary).has("forged")
			and fresh.world_id == WORLD_ID
			and fresh_audit.world_definition.world_id == WORLD_ID,
		"presentation, samples, landing reports, and world audit are deeply detached",
	)


func _test_committed_signals_and_reentry_guard() -> void:
	_signal_events.clear()
	_reentry_results.clear()
	var fixture := _fixture(false)
	var session := fixture.session as PlanetaryTravelSession
	var frame := fixture.frame as PlanetaryCoordinateFrame
	var context := {
		"frame": frame,
		"report": fixture.report,
		"orbit": _absolute(frame, Vector3(0.0, 220_000.0, 0.0)),
	}
	session.session_started.connect(_on_started.bind(session, context))
	session.phase_changed.connect(_on_phase_changed.bind(session, context))
	session.session_completed.connect(_on_completed)
	session.attach(WORLD_ID, frame, 1, 0, 0)
	session.bind_landing_composition_report(fixture.report, 0, 1)
	session.start(0, 1)
	_complete_airless(session, frame, fixture.report)
	_check(
		_signal_events.size() == 11
			and _signal_events.front().kind == &"started"
			and _signal_events.front().state_id == &"orbit_approach"
			and _signal_events.back().kind == &"completed"
			and _signal_events.back().state_id == &"completed",
		"domain signals expose only committed states in exact lifecycle order",
	)
	var final_phase := _signal_events[_signal_events.size() - 2]
	_check(
		final_phase.kind == &"phase" and final_phase.previous == &"orbit_return"
			and final_phase.state_id == &"completed",
		"the final phase callback observes COMPLETED before session_completed",
	)
	var all_reentrant := not _reentry_results.is_empty()
	for result in _reentry_results:
		all_reentrant = all_reentrant and result.reason == &"reentrant_call"
	_check(all_reentrant, "every public mutator rejects synchronous subscriber reentry")


func _on_started(snapshot: Dictionary, session: PlanetaryTravelSession, context: Dictionary) -> void:
	_signal_events.append({"kind": &"started", "state_id": snapshot.state_id})
	_probe_reentry(session, context, snapshot)


func _on_phase_changed(
		snapshot: Dictionary,
		previous: StringName,
		session: PlanetaryTravelSession,
		context: Dictionary
	) -> void:
	_signal_events.append({"kind": &"phase", "state_id": snapshot.state_id, "previous": previous})
	_probe_reentry(session, context, snapshot)


func _on_completed(snapshot: Dictionary) -> void:
	_signal_events.append({"kind": &"completed", "state_id": snapshot.state_id})


func _probe_reentry(
		session: PlanetaryTravelSession,
		context: Dictionary,
		committed_snapshot: Dictionary
	) -> void:
	var generation := session.get_generation()
	var attachment_generation := session.get_attachment_generation()
	var frame := context.frame as PlanetaryCoordinateFrame
	var coordinate := context.orbit as Dictionary
	var identity := _landing_identity(context.report as Dictionary)
	_reentry_results.append(session.attach(WORLD_ID, frame, frame.get_generation(), generation, attachment_generation))
	_reentry_results.append(session.detach(generation, attachment_generation))
	_reentry_results.append(session.start(generation, attachment_generation))
	_reentry_results.append(session.advance_physics(0.01, generation, attachment_generation))
	_reentry_results.append(session.bind_landing_composition_report(context.report, generation, attachment_generation))
	_reentry_results.append(session.submit_orbit_approach_sample(true, coordinate, 0.0, frame.get_generation(), generation, attachment_generation))
	_reentry_results.append(session.submit_atmospheric_entry_sample(coordinate, 0.0, frame.get_generation(), generation, attachment_generation))
	_reentry_results.append(session.submit_descent_sample(coordinate, 0.0, frame.get_generation(), generation, attachment_generation))
	_reentry_results.append(session.submit_landing_sample(true, identity, generation, attachment_generation))
	_reentry_results.append(session.submit_disembark_sample(true, true, generation, attachment_generation))
	_reentry_results.append(session.submit_reboard_sample(true, true, generation, attachment_generation))
	_reentry_results.append(session.submit_takeoff_sample(true, false, generation, attachment_generation))
	_reentry_results.append(session.submit_ascent_sample(true, coordinate, 10.0, frame.get_generation(), generation, attachment_generation))
	_reentry_results.append(session.submit_orbit_return_sample(coordinate, 10.0, frame.get_generation(), generation, attachment_generation))
	_reentry_results.append(session.submit_completion_sample(true, coordinate, 0.0, frame.get_generation(), generation, attachment_generation))
	_reentry_results.append(session.abort(&"subscriber_abort", generation, attachment_generation))
	_reentry_results.append(session.fail(&"subscriber_fail", generation, attachment_generation))
	_reentry_results.append(session.reset(generation, attachment_generation))
	_check(session.get_presentation_snapshot() == committed_snapshot, "subscriber probes cannot alter committed signal snapshot")


func _complete_airless(
		session: PlanetaryTravelSession,
		frame: PlanetaryCoordinateFrame,
		report: Dictionary
	) -> void:
	var frame_generation := frame.get_generation()
	var session_generation := session.get_generation()
	var attachment_generation := session.get_attachment_generation()
	var orbit := _absolute(frame, Vector3(0.0, 220_000.0, 0.0))
	session.submit_orbit_approach_sample(true, orbit, 20.0, frame_generation, session_generation, attachment_generation)
	session.submit_descent_sample(_absolute(frame, Vector3(0.0, 122_500.0, 0.0)), 20.0, frame_generation, session_generation, attachment_generation)
	session.submit_landing_sample(true, _landing_identity(report), session_generation, attachment_generation)
	session.submit_disembark_sample(true, true, session_generation, attachment_generation)
	session.submit_reboard_sample(true, true, session_generation, attachment_generation)
	session.submit_takeoff_sample(true, false, session_generation, attachment_generation)
	session.submit_ascent_sample(true, _absolute(frame, Vector3(0.0, 128_500.0, 0.0)), 5.0, frame_generation, session_generation, attachment_generation)
	session.submit_orbit_return_sample(orbit, 500.0, frame_generation, session_generation, attachment_generation)
	session.submit_completion_sample(true, orbit, 20.0, frame_generation, session_generation, attachment_generation)


func _elapsed_after_one_second(rate: int) -> float:
	var fixture := _fixture(false)
	var session := fixture.session as PlanetaryTravelSession
	var frame := fixture.frame as PlanetaryCoordinateFrame
	session.attach(WORLD_ID, frame, frame.get_generation(), 0, 0)
	session.start(0, 1)
	for _step in rate:
		session.advance_physics(1.0 / float(rate), 1, 1)
	return float(session.get_presentation_snapshot().elapsed_seconds)


func _fixture(has_atmosphere: bool) -> Dictionary:
	var world := _world(has_atmosphere)
	var atmosphere: PlanetaryAtmosphereProfile = (
		AtmosphereScript.new() as PlanetaryAtmosphereProfile
		if has_atmosphere else null
	)
	var terrain := TerrainScript.new() as PlanetaryTerrainProfile
	var region := RegionScript.new() as PlanetaryLandingRegionDefinition
	region.world_id = WORLD_ID
	region.body_id = BODY_ID
	region.region_id = REGION_ID
	var frame := _coordinate_frame()
	var world_report := WorldValidatorScript.new().validate_composition(
		world,
		atmosphere,
		terrain,
	)
	var report := _landing_report(world, terrain, frame, region)
	return {
		"session": SessionScript.new(SESSION_ID, world, frame, world_report),
		"world": world,
		"atmosphere": atmosphere,
		"terrain": terrain,
		"region": region,
		"frame": frame,
		"world_report": world_report,
		"report": report,
	}


func _world(has_atmosphere: bool) -> PlanetaryWorldDefinition:
	var world := WorldScript.new() as PlanetaryWorldDefinition
	world.world_id = WORLD_ID
	world.display_name = "Ember World"
	world.sector_id = &"ember_sector"
	world.content_note = "Modern-interpretation travel-session fixture."
	world.scene_path = "res://scenes/world/planets/ember_world.tscn"
	world.scene_anchor_id = &"ember_scene"
	world.scene_anchor = Transform3D.IDENTITY
	world.navigation_anchor_id = &"ember_navigation"
	world.navigation_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, 150_000.0, 0.0))
	world.orbital_anchor_id = &"ember_orbit"
	world.orbital_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, 220_000.0, 0.0))
	world.surface_anchor_id = &"ember_surface"
	world.surface_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, BODY_RADIUS_METERS, 0.0))
	world.body_radius_metres = BODY_RADIUS_METERS
	world.has_atmosphere = has_atmosphere
	world.atmosphere_definition_id = &"temperate_game_scale" if has_atmosphere else &""
	world.terrain_definition_id = TERRAIN_ID
	world.landing_region_ids = PackedStringArray([REGION_ID])
	world.evidence_status = WorldScript.EvidenceStatus.MODERN_INTERPRETATION
	world.evidence_notes = "Modern-interpretation travel-session fixture."
	return world


func _coordinate_frame() -> PlanetaryCoordinateFrame:
	var frame := FrameScript.new() as PlanetaryCoordinateFrame
	var body_center := _orbital_coordinate(100, -200, 30, Vector3(0.125, -0.25, 0.5))
	var configured := frame.configure(
		BODY_ID,
		BODY_RADIUS_METERS,
		ORBITAL_FRAME_ID,
		CELL_SIZE_METERS,
		body_center,
		Vector3.UP,
		Vector3.FORWARD,
		SHIFT_THRESHOLD_METERS,
		body_center,
	)
	if not configured.accepted:
		_failures.append("coordinate frame fixture failed: %s" % configured)
	return frame


func _landing_report(
		world: PlanetaryWorldDefinition,
		terrain: PlanetaryTerrainProfile,
		frame: PlanetaryCoordinateFrame,
		region: PlanetaryLandingRegionDefinition
	) -> Dictionary:
	return LandingValidatorScript.new().validate_composition(
		world,
		terrain,
		frame.get_snapshot(),
		region,
	)


func _absolute(frame: PlanetaryCoordinateFrame, body_local: Vector3) -> Dictionary:
	var result := frame.body_local_to_orbital_position(body_local, frame.get_generation())
	if not result.accepted:
		_failures.append("absolute-coordinate fixture failed: %s" % result)
		return {}
	return (result.coordinate as Dictionary).duplicate(true)


func _orbital_coordinate(
		cell_x: int,
		cell_y: int,
		cell_z: int,
		offset: Vector3
	) -> Dictionary:
	return {
		"schema_version": FrameScript.COORDINATE_SCHEMA_VERSION,
		"frame_id": ORBITAL_FRAME_ID,
		"cell_x": cell_x,
		"cell_y": cell_y,
		"cell_z": cell_z,
		"offset_meters": offset,
	}


func _landing_identity(report: Dictionary) -> Dictionary:
	return {
		"world_id": report.world_id,
		"body_id": report.body_id,
		"region_id": report.region_id,
		"terrain_profile_id": report.terrain_profile_id,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	print("PLANETARY_TRAVEL_SESSION_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_TRAVEL_SESSION_TEST_OK")
		quit(0)
		return
	print("PLANETARY_TRAVEL_SESSION_TEST_FAILURES: %s" % _failures)
	quit(1)
