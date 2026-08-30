extends SceneTree

const BOOTSTRAP_SCENE := preload(
	"res://scenes/world/components/ember_moon_streaming_bootstrap.tscn"
)
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PHYSICS_DELTA := 1.0 / 12.0
const TEST_TIME_SCALE := 5.0

var _failures := PackedStringArray()
var _original_time_scale := 1.0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_original_time_scale = Engine.time_scale
	Engine.time_scale = TEST_TIME_SCALE
	await _test_berth_configuration_requires_empty_lease()
	await _test_read_only_approach_ready_probe()
	await _test_shared_composition_and_measured_entry()
	await _test_committed_origin_receipt_adoption()
	await _test_normal_public_actor_loop()
	await _test_queued_host_lifecycle_currentness()
	await _test_active_command_source_replacement()
	await _test_command_source_currentness()
	await _test_exact_generation_and_loaded_root_freshness()
	await _test_tangent_frame_and_continuous_support_fail_closed()
	await _test_synchronous_destruction_first_wins()
	for phase in [
		EmberSurfaceLoopHost.Phase.DISEMBARKING,
		EmberSurfaceLoopHost.Phase.BOARDING,
	]:
		await _test_transition_terminal_atomicity(phase, &"detach")
		await _test_transition_terminal_atomicity(phase, &"lease_loss")
		await _test_transition_terminal_atomicity(phase, &"queued_surface")
	Engine.time_scale = _original_time_scale
	_finish()


func _test_berth_configuration_requires_empty_lease() -> void:
	var fixture_root := Node3D.new()
	fixture_root.name = "BerthConfigurationLeaseFixture"
	root.add_child(fixture_root)
	var berth := EmberSurfaceBerth.new()
	fixture_root.add_child(berth)
	var ship := ARROW_SCENE.instantiate() as ArrowReconShip
	fixture_root.add_child(ship)
	await process_frame
	await physics_frame
	var definition := ship.get_ship_definition()
	var token := berth.try_reserve(ship, definition)
	var dock_before_leased_configuration := berth.dock_transform
	var while_leased := berth.configure_for_ship(ship)
	var contract_unchanged_while_leased := berth.dock_transform == dock_before_leased_configuration
	var released := berth.release(ship, token)
	var after_release := berth.configure_for_ship(ship)
	_check(
		definition != null and not token.is_empty()
			and not bool(while_leased.get("accepted", true))
			and while_leased.get("reason", &"") == &"berth_lease_active"
			and contract_unchanged_while_leased
			and released and bool(after_release.get("accepted", false))
			and after_release.get("reason", &"") == &"configured",
		"surface berth cannot rewrite the landing contract under a reserved re-entry craft",
	)
	fixture_root.queue_free()
	await process_frame


func _test_read_only_approach_ready_probe() -> void:
	var fixture := await _fixture(false, true, true)
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var player := fixture.player as PlayerController
	var berth := fixture.berth as EmberSurfaceBerth
	var area := fixture.area as ShipBoardingArea
	var original_source := fixture.original_source as ShipCommandSource
	_place_entry_actor(
		fixture,
		Vector3(8.0, 5.0, -20.0),
		Basis(Vector3.UP, deg_to_rad(5.0)),
		Vector3(0.0, 0.0, -4.0)
	)
	var before_transform := ship.global_transform
	var before_velocity := ship.velocity
	var before_snapshot := host.get_snapshot()
	var probe := host.probe_approach_ready(
		host.get_generation(),
		host.get_attachment_generation(),
		int(before_snapshot.coordinate_frame_generation),
		int(before_snapshot.location_generation)
	)
	var measurement := probe.get("measurement", {}) as Dictionary
	var probe_snapshot := probe.get("snapshot", {}) as Dictionary
	var probe_audit := probe.get("audit", {}) as Dictionary
	var authority := probe.get("authority", {}) as Dictionary
	_check(
		int(probe.get("schema_version", 0))
			== EmberSurfaceLoopHost.APPROACH_READY_PROBE_SCHEMA_VERSION
			and bool(probe.get("accepted", false))
			and probe.get("reason", &"") == &"approach_entry_accepted"
			and bool(measurement.get("accepted", false))
			and bool((measurement.get("measurement", {}) as Dictionary).get(
				"full_hull_inside_authored_corridor", false
			))
			and int(probe_snapshot.get("phase", -1)) == EmberSurfaceLoopHost.Phase.IDLE
			and bool(probe_audit.get("valid", false)),
		"read-only probe returns the existing typed accepted approach measurement with detached snapshot and audit"
	)
	_check(
		bool(authority.get("measurement_only", false))
			and int(authority.get("actor_transform_writes", -1)) == 0
			and int(authority.get("actor_velocity_writes", -1)) == 0
			and int(authority.get("actor_reparent_calls", -1)) == 0
			and int(authority.get("command_source_changes", -1)) == 0
			and int(authority.get("boarding_reservation_mutations", -1)) == 0
			and int(authority.get("berth_lease_mutations", -1)) == 0
			and ship.global_transform == before_transform
			and ship.velocity == before_velocity
			and ship.get_command_source() == original_source
			and area.get_reservation_token() == player
			and berth.get_reservation_owner() == null
			and berth.get_occupant() == null
			and (host.get_snapshot().approach_entry as Dictionary).accepted_measurement.is_empty(),
		"accepted probe changes no actor, command, Player reservation, berth lease, or Host start evidence"
	)
	measurement["reason"] = &"forged_measurement"
	probe_snapshot["phase"] = EmberSurfaceLoopHost.Phase.FAILED
	probe_audit["valid"] = false
	var repeat_probe := host.probe_approach_ready(
		host.get_generation(),
		host.get_attachment_generation(),
		int(before_snapshot.coordinate_frame_generation),
		int(before_snapshot.location_generation)
	)
	_check(
		bool(repeat_probe.get("accepted", false))
			and repeat_probe.get("reason", &"") == &"approach_entry_accepted"
			and int((repeat_probe.get("snapshot", {}) as Dictionary).get("phase", -1))
				== EmberSurfaceLoopHost.Phase.IDLE
			and bool((repeat_probe.get("audit", {}) as Dictionary).get("valid", false)),
		"probe result, snapshot, and audit are detached and cannot mutate Host state"
	)
	var stale_location := host.probe_approach_ready(
		host.get_generation(),
		host.get_attachment_generation(),
		int(before_snapshot.coordinate_frame_generation),
		int(before_snapshot.location_generation) + 1
	)
	_check(
		not bool(stale_location.get("accepted", true))
			and stale_location.get("reason", &"") == &"stale_location_generation"
			and (stale_location.get("measurement", {}) as Dictionary).is_empty()
			and ship.get_command_source() == original_source
			and area.get_reservation_token() == player,
		"probe rejects a caller-stale streamed generation without remeasuring or acquiring ownership"
	)
	_place_entry_actor(
		fixture,
		Vector3(EmberSurfaceLoopHost.APPROACH_ENTRY_POSITION_HALF_EXTENTS_M.x + 0.1, 0.0, 0.0),
		Basis.IDENTITY,
		Vector3.ZERO
	)
	before_transform = ship.global_transform
	before_velocity = ship.velocity
	var out_of_bounds := host.probe_approach_ready(
		host.get_generation(),
		host.get_attachment_generation(),
		int(before_snapshot.coordinate_frame_generation),
		int(before_snapshot.location_generation)
	)
	_check(
		not bool(out_of_bounds.get("accepted", true))
			and out_of_bounds.get("reason", &"") == &"approach_entry_position_out_of_bounds"
			and ship.global_transform == before_transform and ship.velocity == before_velocity
			and host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE
			and (host.get_snapshot().approach_entry as Dictionary).accepted_measurement.is_empty(),
		"probe reuses the authored envelope's bounded position rejection without starting the Host"
	)
	await _cleanup(fixture)


func _test_shared_composition_and_measured_entry() -> void:
	var fixture := await _fixture(false, true, false)
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var composition_root := fixture.world as Node3D
	var original_source := fixture.original_source as ShipCommandSource
	var area := fixture.area as ShipBoardingArea
	var player := fixture.player as PlayerController
	var wrong_root := Node3D.new()
	wrong_root.name = "WrongCompositionRoot"
	root.add_child(wrong_root)
	var wrong_bind := _bind_fixture(fixture, wrong_root)
	_check(
		wrong_bind.reason == &"composition_root_mismatch"
			and ship.get_command_source() == original_source,
		"bind rejects a root that is not the exact shared direct parent without changing actors",
	)
	wrong_root.queue_free()
	var bound := _bind_fixture(fixture, composition_root)
	_check(
		bound.accepted,
		"production-shaped Host/Bootstrap/Berth/Arrow/Player siblings bind under one explicit root",
	)
	if not bool(bound.get("accepted", false)):
		await _cleanup(fixture)
		return
	var prepared := host.get_snapshot().approach_entry as Dictionary
	_check(
		ship.get_command_source() == original_source
			and area.get_reservation_token() == player
			and not bool(prepared.command_source_installed)
			and not bool(prepared.boarding_cleanup_owned),
		"binding prepares the typed envelope without acquiring command or reservation cleanup ownership",
	)

	_place_entry_actor(
		fixture,
		Vector3(EmberSurfaceLoopHost.APPROACH_ENTRY_POSITION_HALF_EXTENTS_M.x + 0.1, 0.0, 0.0),
		Basis.IDENTITY,
		Vector3.ZERO
	)
	var before_pose := ship.global_transform
	var before_velocity := ship.velocity
	var rejected := _start_host(fixture)
	_check(
		rejected.reason == &"approach_entry_position_out_of_bounds"
			and ship.global_transform == before_pose and ship.velocity == before_velocity
			and ship.get_command_source() == original_source
			and area.get_reservation_token() == player
			and not bool((host.get_snapshot().approach_entry as Dictionary).boarding_cleanup_owned),
		"measured entry rejection is atomic across actor, command source and the caller-owned reservation",
	)

	_place_entry_actor(
		fixture,
		Vector3(41.9, 0.0, 0.0),
		Basis.IDENTITY,
		Vector3.ZERO
	)
	before_pose = ship.global_transform
	before_velocity = ship.velocity
	rejected = _start_host(fixture)
	_check(
		rejected.reason == &"approach_entry_hull_outside_corridor"
			and ship.global_transform == before_pose and ship.velocity == before_velocity,
		"root-inside candidate rejects when the exact Arrow hull crosses the authored corridor",
	)

	_place_entry_actor(
		fixture,
		Vector3.ZERO,
		Basis.IDENTITY,
		Vector3(0.0, 0.0, -EmberSurfaceLoopHost.APPROACH_ENTRY_MAXIMUM_SPEED_MPS - 0.1)
	)
	rejected = _start_host(fixture)
	_check(
		rejected.reason == &"approach_entry_speed_out_of_bounds",
		"measured entry rejects finite excess speed at the authored corridor",
	)

	_place_entry_actor(
		fixture, Vector3.ZERO, Basis.IDENTITY, Vector3(NAN, 0.0, 0.0)
	)
	rejected = _start_host(fixture)
	_check(
		rejected.reason == &"approach_entry_nonfinite_measurement",
		"measured entry rejects non-finite actor velocity before any session mutation",
	)

	_place_entry_actor(
		fixture,
		Vector3.ZERO,
		Basis(
			Vector3.UP,
			deg_to_rad(EmberSurfaceLoopHost.APPROACH_ENTRY_MAXIMUM_ATTITUDE_DEGREES + 0.5)
		),
		Vector3.ZERO
	)
	rejected = _start_host(fixture)
	_check(
		rejected.reason == &"approach_entry_attitude_out_of_bounds",
		"measured entry rejects excess attitude relative to the authored corridor basis",
	)

	_place_entry_actor(fixture, Vector3.ZERO, Basis.IDENTITY, Vector3.ZERO)
	(fixture.scene as Node).set_meta(EmberSurfaceLoopHost.LOCATION_GENERATION_META, 2)
	rejected = _start_host(fixture)
	_check(
		rejected.reason == &"approach_entry_location_generation_mismatch",
		"measured entry rejects a live loaded-root location generation mismatch",
	)
	(fixture.scene as Node).set_meta(EmberSurfaceLoopHost.LOCATION_GENERATION_META, 1)

	var prestart_foreign := EmberSurfaceLoopCommandSource.new()
	prestart_foreign.name = "PrestartForeignCommandSource"
	composition_root.add_child(prestart_foreign)
	var prestart_foreign_attach := prestart_foreign.attach(0)
	if not bool(prestart_foreign_attach.get("accepted", false)):
		_check(false, "entry ownership red attaches its foreign source witness")
		await _cleanup(fixture)
		return
	ship.set_command_source(prestart_foreign)
	_place_entry_actor(fixture, Vector3.ZERO, Basis.IDENTITY, Vector3.ZERO)
	rejected = _start_host(fixture)
	_check(
		rejected.reason == &"command_source_ownership_changed"
			and ship.get_command_source() == prestart_foreign
			and area.get_reservation_token() == player
			and not bool((host.get_snapshot().approach_entry as Dictionary).boarding_cleanup_owned),
		"post-measure ownership rejection preserves the foreign command source and caller Player token",
	)
	ship.set_command_source(original_source)
	prestart_foreign.detach(prestart_foreign.get_generation())
	prestart_foreign.queue_free()
	await process_frame

	_place_entry_actor(
		fixture,
		Vector3(8.0, 5.0, -20.0),
		Basis(Vector3.UP, deg_to_rad(5.0)),
		Vector3(0.0, 0.0, -4.0)
	)
	before_pose = ship.global_transform
	before_velocity = ship.velocity
	var started := _start_host(fixture)
	var snapshot := host.get_snapshot()
	var composition := snapshot.composition as Dictionary
	var entry := snapshot.approach_entry as Dictionary
	var measurement := (entry.accepted_measurement as Dictionary).measurement as Dictionary
	var gravity_binding := ship.get_planetary_surface_gravity_report()
	_check(
		started.accepted and host.get_phase() == EmberSurfaceLoopHost.Phase.ORBIT_APPROACH
			and ship.global_transform == before_pose and ship.velocity == before_velocity
			and ship.get_command_source() != original_source
			and area.get_reservation_token() == player
			and bool((snapshot.approach_entry as Dictionary).boarding_cleanup_owned)
			and bool(gravity_binding.get("attached", false))
			and int(gravity_binding.get("source_instance_id", 0)) == host.get_instance_id()
			and int(gravity_binding.get("source_generation", 0)) == host.get_generation(),
		"accepted measured entry transfers command, reservation cleanup, and value-only gravity ingress without actor writes",
	)
	_check(
		int(composition.root_instance_id) == composition_root.get_instance_id()
			and not bool(composition.standalone_root_is_host)
			and bool(composition.dependencies_are_direct_children)
			and bool(measurement.root_inside_entry_volume)
			and bool(measurement.full_hull_inside_authored_corridor)
			and is_equal_approx(float(measurement.speed_mps), 4.0),
		"snapshot freezes exact shared-root identity and detached measured corridor proof",
	)
	var return_before_completion := host.get_snapshot()
	var early_return := host.return_runtime_ownership(
		host.get_generation(), host.get_attachment_generation()
	)
	_check(
		early_return.reason == &"runtime_ownership_return_out_of_order"
			and host.get_snapshot() == return_before_completion,
		"runtime ownership return is completion-only and state-preserving while the loop runs",
	)
	_check(
		host.detach(host.get_generation(), host.get_attachment_generation()).accepted
			and ship.get_command_source() == original_source
			and area.get_reservation_token() == null
			and not bool(ship.get_planetary_surface_gravity_report().get(
				"attached", true
			)),
		"ordinary detach restores command and releases reservation cleanup plus gravity ingress",
	)
	await _cleanup(fixture)

	fixture = await _fixture(false, true, true)
	if fixture.is_empty():
		return
	host = fixture.host as EmberSurfaceLoopHost
	ship = fixture.ship as ArrowReconShip
	ship.reparent(host, true)
	rejected = _start_host(fixture)
	_check(
		rejected.reason == &"approach_entry_composition_root_mismatch",
		"measured entry rejects a dependency moved below the frozen shared root",
	)
	await _cleanup(fixture)

	fixture = await _fixture(false, true, true)
	if fixture.is_empty():
		return
	host = fixture.host as EmberSurfaceLoopHost
	var frame := fixture.frame as PlanetaryCoordinateFrame
	var rebase := frame.request_rebase(Vector3(12_000.0, 0.0, 0.0), frame.get_generation())
	_check(
		bool(rebase.get("accepted", false))
			and bool(frame.commit_rebase(rebase.request.request_id, frame.get_generation()).get("accepted", false)),
		"entry red fixture advances the live frame after binding",
	)
	rejected = _start_host(fixture)
	_check(
		rejected.reason == &"approach_entry_frame_generation_mismatch"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE,
		"measured entry rejects current frame drift without starting the session",
	)
	await _cleanup(fixture)

	fixture = await _fixture(false, true, true)
	if fixture.is_empty():
		return
	host = fixture.host as EmberSurfaceLoopHost
	frame = fixture.frame as PlanetaryCoordinateFrame
	var bootstrap := fixture.bootstrap as EmberMoonStreamingBootstrap
	var original_loaded_id := (fixture.scene as Node).get_instance_id()
	var far := _absolute(frame, Vector3(0.0, 300_001.0, 0.0))
	_check(
		bootstrap.update_absolute_focus(far, frame.get_generation()).accepted,
		"entry identity red unloads the frozen loaded root to N+1",
	)
	var unloaded := await _wait_for_bootstrap_identity(
		bootstrap, 2, 0, original_loaded_id, 120
	)
	_check(
		unloaded,
		"entry identity red observes completed N+1 unload with no loaded instance",
	)
	if not unloaded:
		await _cleanup(fixture)
		return
	var near := _absolute(frame, Vector3(0.0, 250_000.0, 0.0))
	_check(
		bootstrap.update_absolute_focus(near, frame.get_generation()).accepted,
		"entry identity red loads a distinct root at N+2",
	)
	var reloaded := await _wait_for_bootstrap_identity(
		bootstrap, 3, -1, original_loaded_id, 120
	)
	_check(
		reloaded,
		"entry identity red observes completed N+2 reload with a distinct instance",
	)
	if not reloaded:
		await _cleanup(fixture)
		return
	rejected = _start_host(fixture)
	_check(
		rejected.reason == &"approach_entry_loaded_root_mismatch"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE,
		"measured entry rejects a current N+2 loaded-root identity swap before session start",
	)
	await _cleanup(fixture)


func _test_committed_origin_receipt_adoption() -> void:
	var fixture := await _fixture(true, true, true)
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var player := fixture.player as PlayerController
	var area := fixture.area as ShipBoardingArea
	var source := ship.get_command_source()
	var source_generation := int(host.get_snapshot().coordinate_frame_generation)
	var receipt := _commit_shared_origin_rebase(fixture, Vector3(12_000.0, 0.0, 0.0))
	if receipt.is_empty():
		await _cleanup(fixture)
		return
	var before_rejection := host.get_snapshot()
	var missing_coverage := receipt.duplicate(true)
	var covered := missing_coverage.covered_instance_ids as PackedInt64Array
	var walkable_index := covered.find(
		(fixture.walkable as StaticBody3D).get_instance_id()
	)
	if walkable_index < 0:
		_check(false, "origin fixture receipt covers the exact walkable body")
		await _cleanup(fixture)
		return
	covered[walkable_index] = -1
	missing_coverage.covered_instance_ids = covered
	var rejected := host.adopt_committed_origin_rebase(
		missing_coverage,
		host.get_generation(),
		host.get_attachment_generation(),
		1,
	)
	_check(
		rejected.reason == &"origin_owner_receipt_mismatch"
			and host.get_snapshot() == before_rejection,
		"committed-origin adoption rejects a roster not present in the exact owner's last receipt",
	)
	var forged_absolute := receipt.duplicate(true)
	var forged_sample := forged_absolute.adjusted_actor_sample as Dictionary
	forged_sample.position = (forged_sample.position as Vector3) + Vector3(1.0, 0.0, 0.0)
	forged_absolute.adjusted_actor_sample = forged_sample
	rejected = host.adopt_committed_origin_rebase(
		forged_absolute,
		host.get_generation(),
		host.get_attachment_generation(),
		1,
	)
	_check(
		rejected.reason == &"origin_owner_receipt_mismatch"
			and host.get_snapshot() == before_rejection,
		"committed-origin adoption rejects a forged adjusted position before changing its frame fence",
	)

	var adopted := host.adopt_committed_origin_rebase(
		receipt,
		host.get_generation(),
		host.get_attachment_generation(),
		1,
	)
	var target_generation := int(receipt.target_generation)
	var after := host.get_snapshot()
	var adoption := after.origin_rebase as Dictionary
	var identities := after.identities as Dictionary
	var owner_snapshot := (
		fixture.origin_owner as CommonWorldOriginRebaseOwner
	).get_snapshot()
	_check(
		adopted.accepted
			and source_generation + 1 == target_generation
			and int(after.coordinate_frame_generation) == target_generation
			and int(adoption.adoption_count) == 1
			and host.get_phase() == EmberSurfaceLoopHost.Phase.ORBIT_APPROACH
			and ship.get_command_source() == source
			and area.get_reservation_token() == player
			and int(identities.origin_owner_instance_id) \
				== (fixture.origin_owner as CommonWorldOriginRebaseOwner).get_instance_id()
			and int(identities.origin_binding_instance_id) \
				== (fixture.origin_binding as EmberMoonStreamingProductionBinding).get_instance_id()
			and owner_snapshot.get("last_receipt", {}) == receipt,
		"exact owner-linked N-to-N+1 receipt advances only the frame fence and preserves runtime ownership",
	)
	var converted := (fixture.frame as PlanetaryCoordinateFrame) \
		.world_streaming_to_orbital_position(ship.global_position, target_generation)
	_check(
		bool(converted.get("accepted", false))
			and converted.get("coordinate", {}) == receipt.absolute_coordinate
			and bool((host.audit().owned_capabilities as Dictionary).get(
				"coordinate_frame_generation_adoption", false
			))
			and not bool((host.audit().adjacent_authority as Dictionary).origin_shift),
		"adoption proves absolute observation invariance without gaining origin authority",
	)
	var replay_before := host.get_snapshot()
	var replay := host.adopt_committed_origin_rebase(
		receipt,
		host.get_generation(),
		host.get_attachment_generation(),
		1,
	)
	_check(
		replay.reason == &"origin_receipt_generation_mismatch"
			and host.get_snapshot() == replay_before,
		"a committed receipt is single-generation evidence and cannot replay",
	)
	(receipt.root_roster as Array).clear()
	_check(
		not ((host.get_snapshot().origin_rebase as Dictionary).last_adopted_receipt as Dictionary).root_roster.is_empty(),
		"stored committed-origin evidence is deeply detached from caller mutation",
	)
	await _cleanup(fixture)


func _test_normal_public_actor_loop() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var player := fixture.player as PlayerController
	var berth := fixture.berth as EmberSurfaceBerth
	var area := fixture.area as ShipBoardingArea
	var original_source := fixture.original_source as ShipCommandSource
	var reached_landed := await _drive_to_phase(
		fixture, EmberSurfaceLoopHost.Phase.LANDED, 660
	)
	_check(
		reached_landed,
		"real Arrow command/physics and strict berth lease reach LANDED",
	)
	if not reached_landed:
		await _cleanup(fixture)
		return
	var terrain_focus := (
		fixture.scene as EmberMoonAuthoredScene
	).get_terrain_clipmap_snapshot()
	_check(
		int(terrain_focus.get("revision", 0)) > 1
			and (terrain_focus.get(
				"collision_focus_radial_up", Vector3.ZERO
			) as Vector3).is_equal_approx(Vector3.UP)
			and bool(terrain_focus.get("collision_reused", false)),
		"the authenticated Host actor sample recentres visible terrain while reusing fixed landing collision",
	)
	var landed_report := ship.get_landing_contract_report()
	var gravity_snapshot := host.get_snapshot().gravity as Dictionary
	var ship_gravity_report := gravity_snapshot.ship_report as Dictionary
	_check(
		bool(ship.get_telemetry().get("landed", false))
			and bool(landed_report.get("strict_dock_acceptance", false))
			and berth.get_occupant() == ship
			and not berth.get_reservation_token(ship).is_empty(),
		"TravelSession landing follows exact public telemetry, hull acceptance, occupant and token",
	)
	_check(
		int(gravity_snapshot.get("sample_count", 0)) > 0
			and int(gravity_snapshot.get("ship_submission_count", 0))
				== int(gravity_snapshot.get("sample_count", -1))
			and int(ship_gravity_report.get("application_count", 0)) > 0
			and (ship_gravity_report.get(
				"last_applied_vector_world", Vector3.ZERO
			) as Vector3).length() > 0.0
			and bool(ship_gravity_report.get("body_owns_velocity", false)),
		"real approach samples Ember gravity every Host tick and HeroShip applies it inside its sole mover",
	)
	_check(
		host.request_disembark(host.get_generation(), host.get_attachment_generation()).accepted,
		"ordered disembark intent is accepted once",
	)
	var reached_surface := await _drive_to_phase(
		fixture, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, 300
	)
	_check(
		reached_surface,
		"public Player disembark completes with embodied collision",
	)
	if not reached_surface:
		await _cleanup(fixture)
		return
	_check(
		not player.is_seated() and player.collision_layer != 0
			and area.get_reservation_token() == null,
		"disembark releases the exact initial boarding reservation",
	)
	var reached_staging := await _walk_outbound_route(fixture)
	_check(
		reached_staging,
		"real Player locomotion crosses ordered egress then staging on live support",
	)
	if not reached_staging:
		await _cleanup(fixture)
		return
	var return_ready := await _walk_return_to_boarding(fixture)
	_check(return_ready, "return route reaches egress then the exact live BoardingArea")

	var thief := Node.new()
	thief.name = "CompetingBoardingReservation"
	(fixture.world as Node).add_child(thief)
	_check(area.try_reserve(thief), "competing token can claim the unreserved seat")
	var before_conflict := host.get_snapshot()
	var conflict := host.request_reboard(
		host.get_generation(), host.get_attachment_generation()
	)
	_check(
		conflict.reason == &"boarding_reservation_unavailable"
			and host.get_snapshot() == before_conflict
			and area.get_reservation_token() == thief,
		"reboard conflict is state-preserving and cannot steal another exact token",
	)
	_check(area.release_reservation(thief), "competing token releases exactly")
	thief.queue_free()
	_check(
		host.request_reboard(host.get_generation(), host.get_attachment_generation()).accepted,
		"current Player acquires the real BoardingArea and begins public boarding",
	)
	_check(
		await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.REBOARDED, 20)
			and player.is_seated() and ship.is_piloted()
			and area.get_reservation_token() == player,
		"public reboard completes seated/piloted with the exact Player reservation",
	)
	_check(
		host.request_takeoff(host.get_generation(), host.get_attachment_generation()).accepted,
		"ordered takeoff intent is accepted once",
	)
	var takeoff_lease_seen := false
	var completed := false
	for _index in 2700:
		var was_landed := bool(ship.get_telemetry().get("landed", true))
		var token_before := berth.get_reservation_token(ship)
		var tick := await _tick(fixture)
		if was_landed and not token_before.is_empty():
			takeoff_lease_seen = true
		if not bool(tick.get("accepted", false)):
			break
		if host.get_phase() == EmberSurfaceLoopHost.Phase.COMPLETED:
			completed = true
			break
	_check(
		completed and takeoff_lease_seen
			and not bool(ship.get_telemetry().get("landed", true))
			and berth.get_reservation_token(ship).is_empty(),
		"real takeoff keeps the berth through landed=true then releases it before orbit completion",
	)
	var audit := host.audit()
	var route_snapshot := host.get_snapshot().surface_route as Dictionary
	_check(
		bool(audit.get("valid", false))
			and route_snapshot.coordinate_space == &"gravity_policy_reference_tangent"
			and route_snapshot.reference_tangent_basis_body_local == Basis.IDENTITY
			and int(route_snapshot.walkable_body_instance_id)
				== (fixture.walkable as StaticBody3D).get_instance_id(),
		"completed audit freezes tangent identity and exact loaded support body",
	)
	var retired_attachment := host.get_attachment_generation()
	var returned := host.return_runtime_ownership(
		host.get_generation(), retired_attachment
	)
	var return_receipt := returned.get(
		"runtime_ownership_return", {}
	) as Dictionary
	_check(
		returned.accepted
			and not bool(host.get_snapshot().attached)
			and host.get_attachment_generation() == retired_attachment + 1
			and ship.get_command_source() == original_source
			and area.get_reservation_token() == player
			and bool(return_receipt.get("boarding_reservation_retained", false))
			and bool(return_receipt.get("command_source_restored", false))
			and int(return_receipt.get("ship_instance_id", 0)) == ship.get_instance_id()
			and int(return_receipt.get("player_instance_id", 0)) == player.get_instance_id()
			and not bool(ship.get_planetary_surface_gravity_report().get(
				"attached", true
			)),
		"completion atomically returns command and gravity ownership while continuously retaining the seated Player reservation",
	)
	return_receipt["ship_instance_id"] = -1
	_check(
		int(((host.get_snapshot().runtime_ownership_return as Dictionary).last_receipt as Dictionary).ship_instance_id)
			== ship.get_instance_id(),
		"runtime ownership return receipt is deeply detached for a later production owner",
	)
	var replay := host.return_runtime_ownership(
		host.get_generation(), retired_attachment
	)
	_check(
		replay.reason == &"stale_attachment_generation"
			and ship.get_command_source() == original_source
			and area.get_reservation_token() == player,
		"retired attachment cannot repeat or drop an already returned reservation",
	)
	await _cleanup(fixture)


func _test_queued_host_lifecycle_currentness() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var reached_landed := await _drive_to_phase(
		fixture, EmberSurfaceLoopHost.Phase.LANDED, 660
	)
	if not reached_landed:
		_check(false, "queued Host fixture reaches LANDED before lifecycle admission")
		await _cleanup(fixture)
		return
	_check(
		bool(host.request_disembark(
			host.get_generation(), host.get_attachment_generation()
		).get("accepted", false)),
		"live Host still admits its ordered disembark intent",
	)
	await _cleanup(fixture)

	fixture = await _fixture()
	if fixture.is_empty():
		return
	host = fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var player := fixture.player as PlayerController
	var area := fixture.area as ShipBoardingArea
	var berth := fixture.berth as EmberSurfaceBerth
	reached_landed = await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.LANDED, 660)
	if not reached_landed:
		_check(false, "queued Host red fixture reaches LANDED before lifecycle admission")
		await _cleanup(fixture)
		return
	var current_source := ship.get_command_source()
	host.queue_free()
	var before := host.get_snapshot()
	var queued_intent := host.request_disembark(
		host.get_generation(), host.get_attachment_generation()
	)
	var queued_advance := host.advance_physics(
		PHYSICS_DELTA,
		host.get_generation(),
		host.get_attachment_generation(),
		(fixture.frame as PlanetaryCoordinateFrame).get_generation(),
		1
	)
	_check(
		host.is_inside_tree() and host.is_queued_for_deletion()
			and queued_intent.get("reason", &"") == &"host_detached"
			and queued_advance.get("reason", &"") == &"host_detached"
			and host.get_snapshot() == before
			and host.get_phase() == EmberSurfaceLoopHost.Phase.LANDED
			and ship.get_command_source() == current_source
			and player.is_seated() and not player.is_control_enabled()
			and area.get_reservation_token() == player
			and berth.get_occupant() == ship,
		"queued Host rejects direct intent and physics before consuming lifecycle time or mutating live ownership",
	)
	await _cleanup(fixture)


func _test_active_command_source_replacement() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var area := fixture.area as ShipBoardingArea
	var foreign := EmberSurfaceLoopCommandSource.new()
	foreign.name = "ForeignCommandSource"
	(fixture.world as Node).add_child(foreign)
	var attached := foreign.attach(0)
	if not bool(attached.get("accepted", false)):
		_check(false, "foreign command-source witness attaches")
		await _cleanup(fixture)
		return
	ship.set_command_source(foreign)
	var result := await _tick(fixture)
	_check(
		not bool(result.get("accepted", true))
			and result.get("reason") == &"command_source_replaced"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED
			and ship.get_command_source() == foreign,
		"active foreign command-source replacement terminalizes without clobbering the replacement",
	)
	_check(
		area.get_reservation_token() == null
			and bool(foreign.get_snapshot().get("attached", false)),
		"foreign-source retirement releases only the Host-owned Player token and never detaches foreign authority",
	)
	await _cleanup(fixture)


func _test_command_source_currentness() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var source := ship.get_command_source() as EmberSurfaceLoopCommandSource
	if source == null:
		_check(false, "started Ember host installs its exact command-source witness")
		await _cleanup(fixture)
		return

	var detached_probe := EmberSurfaceLoopCommandSource.new()
	var detached_before := detached_probe.get_snapshot()
	var detached_delivery_generation := detached_probe.get_delivery_generation()
	var detached_stream_id := detached_probe.get_stream_id()
	var detached_attach := detached_probe.attach(0)
	_check(
		not bool(detached_attach.get("accepted", true))
			and detached_attach.get("reason", &"") == &"command_source_detached"
			and detached_probe.get_snapshot() == detached_before
			and detached_probe.get_delivery_generation() == detached_delivery_generation
			and detached_probe.get_stream_id() == detached_stream_id,
		"off-tree command-source attach rejects atomically before resetting its transport",
	)

	var detached_before_mutation := source.get_snapshot()
	host.remove_child(source)
	var detached_mode := source.set_mode(
		EmberSurfaceLoopCommandSource.Mode.BRAKE, source.get_generation()
	)
	var detached_detach := source.detach(source.get_generation())
	var detached_command := source.next_command()
	_check(
		not bool(detached_mode.get("accepted", true))
			and detached_mode.get("reason", &"") == &"command_source_detached"
			and not bool(detached_detach.get("accepted", true))
			and detached_detach.get("reason", &"") == &"command_source_detached"
			and not detached_command.brake
			and is_zero_approx(detached_command.throttle)
			and source.get_snapshot() == detached_before_mutation,
		"detached installed source rejects mode and detach while sampling an atomic neutral command",
	)
	host.add_child(source)
	var reentered_mode := source.set_mode(
		EmberSurfaceLoopCommandSource.Mode.BRAKE, source.get_generation()
	)
	var reentered_command := source.next_command()
	_check(
		bool(reentered_mode.get("accepted", false))
			and reentered_command.brake,
		"readded installed source accepts a fresh mode and resumes its command stream",
	)

	host.add_child(detached_probe)
	var attached_probe := detached_probe.attach(0)
	detached_probe.set_mode(
		EmberSurfaceLoopCommandSource.Mode.BRAKE, detached_probe.get_generation()
	)
	detached_probe.queue_free()
	var queued_before := detached_probe.get_snapshot()
	var queued_mode := detached_probe.set_mode(
		EmberSurfaceLoopCommandSource.Mode.APPROACH, detached_probe.get_generation()
	)
	var queued_detach := detached_probe.detach(detached_probe.get_generation())
	var queued_command := detached_probe.next_command()
	_check(
		bool(attached_probe.get("accepted", false))
			and detached_probe.is_inside_tree()
			and detached_probe.is_queued_for_deletion()
			and not bool(queued_mode.get("accepted", true))
			and queued_mode.get("reason", &"") == &"command_source_detached"
			and not bool(queued_detach.get("accepted", true))
			and queued_detach.get("reason", &"") == &"command_source_detached"
			and not queued_command.brake
			and is_zero_approx(queued_command.throttle)
			and detached_probe.get_snapshot() == queued_before,
		"queued command source rejects lifecycle and mode mutation while retaining atomic neutral sampling",
	)
	await process_frame
	await _cleanup(fixture)


func _test_exact_generation_and_loaded_root_freshness() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var frame := fixture.frame as PlanetaryCoordinateFrame
	var before := host.get_snapshot()
	for mutation in [
		{"generation": host.get_generation() + 1, "attachment": host.get_attachment_generation(), "frame": frame.get_generation(), "location": 1},
		{"generation": host.get_generation(), "attachment": host.get_attachment_generation() + 1, "frame": frame.get_generation(), "location": 1},
		{"generation": host.get_generation(), "attachment": host.get_attachment_generation(), "frame": frame.get_generation() + 1, "location": 1},
		{"generation": host.get_generation(), "attachment": host.get_attachment_generation(), "frame": frame.get_generation(), "location": 2},
	]:
		var rejected := host.advance_physics(
			PHYSICS_DELTA, mutation.generation, mutation.attachment,
			mutation.frame, mutation.location
		)
		_check(
			not bool(rejected.get("accepted", true)) and host.get_snapshot() == before,
			"stale host/attachment/frame/location caller token is state-preserving",
		)
	var request := frame.request_rebase(Vector3(12_000.0, 0.0, 0.0), frame.get_generation())
	_check(bool(request.get("accepted", false)), "coordinate frame accepts an external rebase request")
	var committed := frame.commit_rebase(request.request.request_id, frame.get_generation())
	_check(bool(committed.get("accepted", false)), "external rebase advances the frame generation")
	var stale_frame := host.advance_physics(
		PHYSICS_DELTA, host.get_generation(), host.get_attachment_generation(),
		before.coordinate_frame_generation, 1
	)
	_check(
		stale_frame.reason == &"stale_coordinate_frame_generation"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED,
		"current frame generation drift terminates instead of replaying the old frame",
	)
	await _cleanup(fixture)

	fixture = await _fixture()
	if fixture.is_empty():
		return
	host = fixture.host as EmberSurfaceLoopHost
	var bootstrap := fixture.bootstrap as EmberMoonStreamingBootstrap
	frame = fixture.frame as PlanetaryCoordinateFrame
	var far := _absolute(frame, Vector3(0.0, 300_001.0, 0.0))
	_check(bootstrap.update_absolute_focus(far, frame.get_generation()).accepted, "loaded root unload advances to N+1")
	await process_frame
	_check(
		host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED
			and host.get_snapshot().terminal_reason == &"loaded_scene_detached",
		"N+1 unload immediately fails the current session with its first terminal reason",
	)
	var near := _absolute(frame, Vector3(0.0, 250_000.0, 0.0))
	_check(bootstrap.update_absolute_focus(near, frame.get_generation()).accepted, "loaded root reload advances to N+2")
	await process_frame
	await process_frame
	var replay := host.advance_physics(
		PHYSICS_DELTA, host.get_generation(), host.get_attachment_generation(),
		frame.get_generation(), 1
	)
	_check(
		replay.reason == &"not_running"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED
			and host.get_snapshot().terminal_reason == &"loaded_scene_detached",
		"N to N+2 loaded-root replacement cannot replay the original session",
	)
	await _cleanup(fixture)


func _test_tangent_frame_and_continuous_support_fail_closed() -> void:
	var fixture := await _fixture_at_surface_outbound()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var landing_root := fixture.landing_root as Node3D
	landing_root.rotation.y = 0.01
	var transformed := await _tick(fixture)
	_check(
		transformed.reason == &"landing_surface_frame_drift"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED,
		"live landing-frame mutation invalidates tangent route and gravity composition",
	)
	await _cleanup(fixture)

	fixture = await _fixture_at_surface_outbound()
	if fixture.is_empty():
		return
	host = fixture.host as EmberSurfaceLoopHost
	var walkable := fixture.walkable as StaticBody3D
	walkable.collision_layer = PhysicsLayers.NONE
	await physics_frame
	var unsupported := host.advance_physics(
		PHYSICS_DELTA, host.get_generation(), host.get_attachment_generation(),
		(fixture.frame as PlanetaryCoordinateFrame).get_generation(), 1
	)
	_check(
		unsupported.reason == &"surface_support_lost"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED,
		"missing exact live WalkablePatch support fails between route endpoints",
	)
	await _cleanup(fixture)


func _test_synchronous_destruction_first_wins() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var berth := fixture.berth as EmberSurfaceBerth
	var callback := func(owner: Node, token: StringName) -> void:
		if owner == ship and not token.is_empty():
			ship.apply_damage(ship.maximum_hull + 1.0, ship.global_position, Vector3.UP)
	berth.reservation_changed.connect(callback)
	var final_result := {}
	for _index in 660:
		final_result = await _tick(fixture)
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			break
	_check(
		host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED
			and final_result.get("reason") == &"ship_destroyed"
			and host.get_snapshot().terminal_reason == &"ship_destroyed"
			and berth.get_reservation_owner() == null,
		"synchronous destruction in reservation signal commits first-wins failure before outer success",
	)
	await _cleanup(fixture)


func _test_transition_terminal_atomicity(phase: int, trigger: StringName) -> void:
	var fixture := await _fixture_at_transition(phase)
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var player := fixture.player as PlayerController
	var berth := fixture.berth as EmberSurfaceBerth
	var area := fixture.area as ShipBoardingArea
	var old_attachment := host.get_attachment_generation()
	var result := {}
	match trigger:
		&"detach":
			result = host.detach(host.get_generation(), old_attachment)
		&"lease_loss":
			var token := berth.get_reservation_token(ship)
			_check(not token.is_empty() and berth.release(ship, token), "exact live berth lease can be retired adversarially")
			result = await _tick(fixture)
		&"queued_surface":
			(fixture.scene as Node).queue_free()
			await process_frame
			result = host.get_snapshot()
		_:
			_check(false, "unknown transition terminal trigger")
	var detached := trigger == &"detach"
	_check(
		(detached and bool(result.get("accepted", false))
				and host.get_attachment_generation() == old_attachment + 1)
			or (not detached and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED),
		"%s during transition phase %d commits one terminal generation" % [trigger, phase],
	)
	_check(
		not player.is_seated() and player.collision_layer != 0
			and not ship.is_piloted()
			and ship.get_command_source() == fixture.original_source
			and berth.get_reservation_owner() == null
			and area.get_reservation_token() == null,
		"%s during transition phase %d cancels embodiment and restores command/piloted/collision/tokens atomically" % [trigger, phase],
	)
	if trigger != &"queued_surface":
		await physics_frame
		await physics_frame
		_check(
			player.get_camera().current and player.is_control_enabled()
				and _player_has_live_surface_support(fixture),
			"current-surface %s recovery restores camera/control/live support" % trigger,
		)
	if detached:
		var replay := host.advance_physics(
			PHYSICS_DELTA, host.get_generation(), old_attachment,
			(fixture.frame as PlanetaryCoordinateFrame).get_generation(), 1
		)
		_check(replay.reason == &"stale_attachment_generation", "old attachment cannot resurrect a detached transition")
	await _cleanup(fixture)


func _fixture_at_surface_outbound() -> Dictionary:
	var fixture := await _fixture()
	if fixture.is_empty():
		return fixture
	if not await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.LANDED, 660):
		_check(false, "fixture reaches LANDED before surface setup")
		return {}
	var host := fixture.host as EmberSurfaceLoopHost
	host.request_disembark(host.get_generation(), host.get_attachment_generation())
	if not await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, 300):
		_check(false, "fixture reaches SURFACE_OUTBOUND through public disembark")
		return {}
	return fixture


func _fixture_at_transition(phase: int) -> Dictionary:
	var fixture := {}
	if phase == EmberSurfaceLoopHost.Phase.DISEMBARKING:
		fixture = await _fixture()
	else:
		fixture = await _fixture_at_surface_outbound()
	if fixture.is_empty():
		return fixture
	var host := fixture.host as EmberSurfaceLoopHost
	if phase == EmberSurfaceLoopHost.Phase.DISEMBARKING:
		if not await _drive_to_phase(
			fixture, EmberSurfaceLoopHost.Phase.LANDED, 660
		):
			_check(false, "transition fixture reaches LANDED")
			return {}
		host = fixture.host as EmberSurfaceLoopHost
		host.request_disembark(host.get_generation(), host.get_attachment_generation())
		if not await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.DISEMBARKING, 300):
			_check(false, "transition fixture enters DISEMBARKING")
			return {}
		return fixture

	if not await _walk_outbound_route(fixture):
		_check(false, "transition fixture reaches ON_FOOT through real locomotion")
		return {}
	var area := fixture.area as ShipBoardingArea
	var player := fixture.player as PlayerController
	if not await _walk_return_to_boarding(fixture) \
			or not _player_near(area, player):
		_check(false, "transition fixture returns through egress to BoardingArea")
		return {}
	var boarded := host.request_reboard(host.get_generation(), host.get_attachment_generation())
	if not bool(boarded.get("accepted", false)) \
			or host.get_phase() != EmberSurfaceLoopHost.Phase.BOARDING:
		_check(false, "transition fixture enters BOARDING")
		return {}
	return fixture


func _fixture(
	auto_start: bool = true,
	shared_composition_root: bool = false,
	bind_now: bool = true
) -> Dictionary:
	var world: Node3D
	var host := EmberSurfaceLoopHost.new()
	host.name = "EmberSurfaceLoopHost"
	if shared_composition_root:
		world = Node3D.new()
		world.name = "SharedCompositionRoot"
		root.add_child(world)
	else:
		world = host
		root.add_child(world)
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as EmberMoonStreamingBootstrap
	bootstrap.name = "EmberMoonStreamingBootstrap"
	world.add_child(bootstrap)
	var frame := bootstrap.get_coordinate_frame_for_session()
	var origin_binding: EmberMoonStreamingProductionBinding
	var origin_owner: CommonWorldOriginRebaseOwner
	var origin_probe: Node3D
	if shared_composition_root:
		origin_binding = EmberMoonStreamingProductionBinding.new()
		origin_binding.name = "EmberMoonStreamingProductionBinding"
		world.add_child(origin_binding)
		origin_owner = CommonWorldOriginRebaseOwner.new()
		origin_owner.name = "CommonWorldOriginRebaseOwner"
		world.add_child(origin_owner)
		origin_probe = Node3D.new()
		origin_probe.name = "OriginActorProbe"
		world.add_child(origin_probe)
		await process_frame
		await process_frame
		if not bool(origin_binding.audit().get("valid", false)) \
				or not bool(origin_owner.audit().get("valid", false)):
			_check(false, "shared fixture activates the exact Ember binding and common-origin owner")
			return {}
		origin_probe.global_position = bootstrap.global_position
		if not bool(_consume_real_origin_rebase(
			origin_binding, origin_owner, origin_probe
		).get("accepted", false)):
			_check(false, "shared fixture consumes the required real Ember origin transaction")
			return {}
	else:
		var rebase := frame.request_rebase(bootstrap.position, frame.get_generation())
		if not bool(rebase.get("accepted", false)):
			_check(false, "fixture obtains the required Ember origin rebase")
			return {}
		bootstrap.position += rebase.request.world_translation_delta
		if not bool(frame.commit_rebase(rebase.request.request_id, 1).get("accepted", false)):
			_check(false, "fixture commits Ember frame generation two")
			return {}
		var body_coordinate := NearbySectorOrbitalRegistry.new().get_coordinate(
			NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
		)
		if not bool(bootstrap.update_absolute_focus(body_coordinate, 2).get("accepted", false)):
			_check(false, "fixture loads current Ember generation one")
			return {}
	await process_frame
	await process_frame
	var scene := bootstrap.get_loaded_instance() as EmberMoonAuthoredScene
	if scene == null:
		_check(false, "fixture resolves the current authored Ember root")
		return {}
	if shared_composition_root:
		origin_probe.global_position = (
			scene.get_node(^"LandingRegion") as Node3D
		).global_position
		if not bool(_consume_real_origin_rebase(
			origin_binding, origin_owner, origin_probe
		).get("accepted", false)):
			_check(false, "shared fixture consumes the real surface-local origin transaction")
			return {}
		origin_probe.queue_free()
		await process_frame
		world.add_child(host)
	else:
		var surface_rebase := frame.request_rebase(
			(scene.get_node(^"LandingRegion") as Node3D).global_position,
			frame.get_generation()
		)
		if not bool(surface_rebase.get("accepted", false)):
			_check(false, "fixture requests the caller-owned surface-local rebase")
			return {}
		bootstrap.position += surface_rebase.request.world_translation_delta
		if not bool(frame.commit_rebase(
			surface_rebase.request.request_id, 2
		).get("accepted", false)):
			_check(false, "fixture commits surface-local frame generation three")
			return {}

	var berth := EmberSurfaceBerth.new()
	world.add_child(berth)
	berth.global_transform = (scene.get_node(^"LandingRegion") as Node3D).global_transform
	var ship := ARROW_SCENE.instantiate() as ArrowReconShip
	ship.name = "ArrowReconShip"
	world.add_child(ship)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	world.add_child(player)
	await process_frame
	await physics_frame
	var original_source := ship.get_command_source()
	ship.global_transform = (scene.get_node(^"LandingRegion") as Node3D).global_transform \
		* Transform3D(
			Basis.IDENTITY,
			EmberSurfaceLoopHost.APPROACH_ENTRY_REGION_LOCAL_M
	)
	ship.velocity = Vector3.ZERO
	var area := ship.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	player.teleport_to(area.global_transform)
	await physics_frame
	await physics_frame
	_check(_player_near(area, player), "initial fixture physically discovers the exact Arrow BoardingArea")
	if not area.try_reserve(player) or not player.begin_boarding(
		ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(), 0.0, ship
	):
		_check(false, "initial fixture establishes public seated/reservation state")
		return {}
	ship.set_piloted(true)
	var fixture := {
		"world": world,
		"host": host,
		"composition_root": world,
		"bootstrap": bootstrap,
		"frame": frame,
		"scene": scene,
		"landing_root": scene.get_node(^"LandingRegion"),
		"walkable": scene.get_node(^"LandingRegion/WalkablePatch"),
		"berth": berth,
		"ship": ship,
		"player": player,
		"area": area,
		"original_source": original_source,
		"origin_binding": origin_binding,
		"origin_owner": origin_owner,
	}
	if not bind_now:
		return fixture
	var bound := _bind_fixture(fixture, world)
	if not bool(bound.get("accepted", false)):
		_check(false, "exact current dependencies bind: %s" % bound.get("reason", &""))
		return {}
	if auto_start:
		var started := _start_host(fixture)
		if not bool(started.get("accepted", false)):
			_check(false, "one measured staged fixture starts: %s" % started.get("reason", &""))
			return {}
	return fixture


func _bind_fixture(fixture: Dictionary, composition_root: Node) -> Dictionary:
	var host := fixture.host as EmberSurfaceLoopHost
	if composition_root == host:
		return host.bind_dependencies(
			fixture.bootstrap as EmberMoonStreamingBootstrap,
			fixture.berth as EmberSurfaceBerth,
			fixture.ship as ArrowReconShip,
			fixture.player as PlayerController,
			1.62, 1, 0, 0
		)
	return host.bind_dependencies(
		fixture.bootstrap as EmberMoonStreamingBootstrap,
		fixture.berth as EmberSurfaceBerth,
		fixture.ship as ArrowReconShip,
		fixture.player as PlayerController,
		1.62, 1, 0, 0, composition_root,
		fixture.origin_owner as CommonWorldOriginRebaseOwner
	)


func _start_host(fixture: Dictionary) -> Dictionary:
	var host := fixture.host as EmberSurfaceLoopHost
	return host.start(
		host.get_generation(),
		host.get_attachment_generation(),
		int(host.get_snapshot().coordinate_frame_generation)
	)


func _place_entry_actor(
	fixture: Dictionary,
	entry_offset_local_m: Vector3,
	attitude_region_local: Basis,
	velocity_region_local_mps: Vector3
) -> void:
	var landing_root := fixture.landing_root as Node3D
	var ship := fixture.ship as ArrowReconShip
	ship.global_transform = landing_root.global_transform * Transform3D(
		attitude_region_local,
		EmberSurfaceLoopHost.APPROACH_ENTRY_REGION_LOCAL_M + entry_offset_local_m
	)
	ship.velocity = landing_root.global_basis * velocity_region_local_mps


func _drive_to_phase(fixture: Dictionary, phase: int, frame_budget: int) -> bool:
	var host := fixture.host as EmberSurfaceLoopHost
	var last_result := {}
	for _index in frame_budget:
		if host.get_phase() == phase:
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			break
		last_result = await _tick(fixture)
		if not bool(last_result.get("accepted", false)):
			break
	var reached := host.get_phase() == phase
	if not reached:
		var ship := fixture.ship as ArrowReconShip
		var player := fixture.player as PlayerController
		push_error(
			"DRIVE target=%d phase=%d reason=%s ship=%s speed=%.3f player=%s player_velocity=%s control=%s floor=%s telemetry=%s" % [
				phase, host.get_phase(), last_result.get("reason", &"budget_exhausted"),
				ship.global_position, ship.velocity.length(), player.global_position,
				player.velocity, player.is_control_enabled(), player.is_on_floor(),
				ship.get_telemetry(),
			]
		)
	return reached


func _walk_outbound_route(fixture: Dictionary) -> bool:
	if not await _walk_until(
		fixture, &"move_back", func(local: Vector3) -> bool: return local.x <= -9.0, 60
	):
		return false
	if not await _walk_until(
		fixture, &"move_right", func(local: Vector3) -> bool: return local.z >= 8.0, 90
	):
		return false
	if not await _walk_until(
		fixture, &"move_forward", func(local: Vector3) -> bool: return local.x >= 17.5, 120
	):
		return false
	if not await _walk_until(
		fixture, &"move_left", func(local: Vector3) -> bool: return local.z <= 0.5, 90
	):
		return false
	if not await _walk_until(
		fixture, &"move_forward", func(local: Vector3) -> bool: return local.x >= 41.5, 120
	):
		return false
	return (fixture.host as EmberSurfaceLoopHost).get_phase() \
		== EmberSurfaceLoopHost.Phase.ON_FOOT


func _walk_return_to_boarding(fixture: Dictionary) -> bool:
	var host := fixture.host as EmberSurfaceLoopHost
	var player := fixture.player as PlayerController
	var area := fixture.area as ShipBoardingArea
	if not await _walk_until(
		fixture, &"move_back", func(local: Vector3) -> bool: return local.x <= 18.5, 120
	):
		return false
	if not bool((host.get_snapshot().surface_route as Dictionary).return_complete):
		return false
	if not await _walk_until(
		fixture, &"move_right", func(local: Vector3) -> bool: return local.z >= 8.0, 90
	):
		return false
	if not await _walk_until(
		fixture, &"move_back", func(local: Vector3) -> bool: return local.x <= -9.0, 120
	):
		return false
	if not await _walk_until(
		fixture, &"move_left", func(local: Vector3) -> bool: return local.z <= 0.5, 90
	):
		return false
	if not await _walk_until(
		fixture, &"move_forward", func(_local: Vector3) -> bool: return _player_near(area, player), 60
	):
		return false
	return _player_near(area, player)


func _walk_until(
	fixture: Dictionary,
	action: StringName,
	reached: Callable,
	frame_budget: int
) -> bool:
	var landing_root := fixture.landing_root as Node3D
	Input.action_press(action)
	for _index in frame_budget:
		var tick := await _tick(fixture)
		if not bool(tick.get("accepted", false)):
			Input.action_release(action)
			push_error("WALK action=%s rejected=%s phase=%d local=%s" % [
				action, tick.get("reason", &""),
				(fixture.host as EmberSurfaceLoopHost).get_phase(),
				landing_root.to_local((fixture.player as PlayerController).global_position),
			])
			return false
		if bool(reached.call(landing_root.to_local(
			(fixture.player as PlayerController).global_position
		))):
			Input.action_release(action)
			return true
	Input.action_release(action)
	var player := fixture.player as PlayerController
	var collisions: Array[String] = []
	for collision_index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(collision_index)
		collisions.append("%s:%s" % [collision.get_collider(), collision.get_normal()])
	push_error("WALK action=%s exhausted phase=%d local=%s velocity=%s" % [
		action, (fixture.host as EmberSurfaceLoopHost).get_phase(),
		landing_root.to_local(player.global_position), player.velocity,
	])
	push_error("WALK_COLLISIONS %s" % [collisions])
	return false


func _tick(fixture: Dictionary) -> Dictionary:
	await physics_frame
	var host := fixture.host as EmberSurfaceLoopHost
	return host.advance_physics(
		PHYSICS_DELTA,
		host.get_generation(),
		host.get_attachment_generation(),
		(fixture.frame as PlanetaryCoordinateFrame).get_generation(),
		1
	)


func _absolute(frame: PlanetaryCoordinateFrame, body_local: Vector3) -> Dictionary:
	var encoded := frame.encode_body_local_position(body_local, frame.get_generation())
	return (encoded.coordinate as Dictionary).orbital_coordinate as Dictionary


func _commit_shared_origin_rebase(
	fixture: Dictionary,
	physical_ship_translation: Vector3
) -> Dictionary:
	var ship := fixture.ship as ArrowReconShip
	var player := fixture.player as PlayerController
	ship.global_position += physical_ship_translation
	player.teleport_to(ship.get_pilot_seat_anchor().global_transform)
	var result := _consume_real_origin_rebase(
		fixture.origin_binding as EmberMoonStreamingProductionBinding,
		fixture.origin_owner as CommonWorldOriginRebaseOwner,
		ship,
	)
	if not bool(result.get("accepted", false)):
		_check(false, "origin fixture commits through the exact common-world owner")
		return {}
	return (result.get("receipt", {}) as Dictionary).duplicate(true)


func _consume_real_origin_rebase(
	binding: EmberMoonStreamingProductionBinding,
	owner: CommonWorldOriginRebaseOwner,
	actor: Node3D
) -> Dictionary:
	var sample := {
		"available": true,
		"position": actor.global_position,
		"actor_kind": &"ship",
		"actor_instance_id": actor.get_instance_id(),
	}
	binding.physics_tick_from_caller_sample(PHYSICS_DELTA, sample)
	var generation := int(
		binding.get_snapshot().get("bound_coordinate_frame_generation", 0)
	)
	var preview := binding.preview_origin_rebase(generation)
	if not bool(preview.get("accepted", false)) \
			or not bool(preview.get("rebase_required", false)):
		return {
			"accepted": false,
			"reason": preview.get("reason", &"origin_preview_rejected"),
		}
	return owner.consume_rebase_preview(preview, sample)


func _wait_for_bootstrap_identity(
	bootstrap: EmberMoonStreamingBootstrap,
	expected_location_generation: int,
	expected_loaded_instance_id: int,
	excluded_loaded_instance_id: int,
	frame_budget: int
) -> bool:
	for _index in frame_budget:
		var snapshot := bootstrap.get_snapshot()
		var loaded_id := int(snapshot.get("loaded_instance_id", -1))
		if int(snapshot.get("location_generation", -1)) == expected_location_generation \
				and (
					expected_loaded_instance_id < 0 and loaded_id > 0 \
					or loaded_id == expected_loaded_instance_id
				) and loaded_id != excluded_loaded_instance_id:
			return true
		await process_frame
	return false


func _player_near(area: ShipBoardingArea, player: PlayerController) -> bool:
	return area in player.get_nearby_interactables()


func _player_has_live_surface_support(fixture: Dictionary) -> bool:
	var player := fixture.player as PlayerController
	var landing_root := fixture.landing_root as Node3D
	var walkable := fixture.walkable as StaticBody3D
	var surface_up := landing_root.global_basis.y.normalized()
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + surface_up * 0.5,
		player.global_position - surface_up * 2.5,
		PhysicsLayers.WORLD_BODY_LAYER
	)
	query.exclude = [player.get_rid(), (fixture.ship as ArrowReconShip).get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == walkable \
		and (hit.get("normal", Vector3.ZERO) as Vector3).dot(surface_up) >= 0.9


func _cleanup(fixture: Dictionary) -> void:
	for action in [
		&"move_left", &"move_right", &"move_forward", &"move_back",
		&"sprint_boost",
	]:
		Input.action_release(action)
	var world := fixture.get("world") as Node
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_SURFACE_LOOP_HOST_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("EMBER_SURFACE_LOOP_HOST_TEST: " + failure)
	quit(1)
