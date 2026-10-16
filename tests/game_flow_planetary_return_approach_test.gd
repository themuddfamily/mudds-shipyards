## test-matrix-network: required
extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")


class ReturnComposition:
	extends Node
	var attached := true
	var reject_detach := false
	var detach_calls := 0
	var last_detach_result: Dictionary = {}
	var host_generation := 9
	var attachment_generation := 4
	var host_instance_id := 0
	func detach() -> Dictionary:
		detach_calls += 1
		if reject_detach or not attached:
			last_detach_result = {"accepted": false, "reason": &"composition_not_bound", "runtime": get_snapshot()}
			return last_detach_result
		attached = false
		return {"accepted": true, "reason": &"composition_detached"}
	func get_snapshot() -> Dictionary:
		return {
			"state": &"bound" if attached else &"detached",
			"host_generation": host_generation,
			"attachment_generation": attachment_generation,
			"adapter": {"host_instance_id": host_instance_id},
		}


class ReturnRelay:
	extends EmberStagingRelayProximityBinding
	var detach_calls := 0
	func detach() -> Dictionary:
		detach_calls += 1
		return super.detach()


class CompletedSurfaceBinding:
	extends EmberSurfaceLoopProductionBinding

	var take_calls := 0
	var intent_take_calls := 0
	var abort_calls := 0
	var detach_calls := 0
	var handback: Dictionary = {}
	var intent: Dictionary = {}
	var intent_delivered := false
	var retained_session_instance_id := 7001
	var snapshot_calls := 0
	var snapshots_after_delivery := 0

	func get_state() -> int:
		return State.HANDOFF_PENDING

	func has_pending_station_return_handoff() -> bool:
		return not intent.is_empty() and not intent_delivered

	func get_snapshot() -> Dictionary:
		snapshot_calls += 1
		if intent_delivered:
			snapshots_after_delivery += 1
		var host: Object = get("_host")
		return {
			"state_id": &"handoff_pending",
			"station_return_handoff_pending": (
				not intent.is_empty() and not intent_delivered
			),
			"station_return_handoff_delivered": intent_delivered,
			"station_return_handoff_intent": intent.duplicate(true),
			"retained_return_context": {
				"host_instance_id": host.get_instance_id() if host != null else 0,
				"host_generation": host.get_generation() if host != null else -1,
				"host_attachment_generation": (
					host.get_attachment_generation() if host != null else -1
				),
				"session_instance_id": retained_session_instance_id,
				"actor_instance_id": int(intent.get("actor_instance_id", 0)),
				"craft_instance_id": int(intent.get("craft_instance_id", 0)),
			}.duplicate(true),
		}.duplicate(true)

	func get_generation() -> int:
		return 9

	func take_completion_handback(_expected_generation: int) -> Dictionary:
		take_calls += 1
		if take_calls > 1:
			return {"accepted": false, "reason": &"handback_already_delivered"}
		set("_completion_handback", handback.duplicate(true))
		set("_completion_handback_delivered", true)
		return {
			"accepted": true,
			"reason": &"completion_handback_delivered",
			"runtime_ownership_return": handback.duplicate(true),
		}.duplicate(true)

	func take_planetary_station_return_handoff_intent(
			_expected_generation: int
		) -> Dictionary:
		intent_take_calls += 1
		if intent_delivered:
			return {
				"accepted": false,
				"reason": &"station_return_handoff_already_delivered",
			}
		intent_delivered = true
		return {
			"accepted": true,
			"reason": &"station_return_handoff_delivered",
			"intent": intent.duplicate(true),
		}.duplicate(true)

	func abort_planetary_relay_survey_return(
			request_reason: StringName = &"caller_aborted"
		) -> Dictionary:
		abort_calls += 1
		return {"accepted": true, "reason": request_reason}

	func get_planetary_surface_snapshot() -> Dictionary:
		var host: Object = get("_host")
		return {
			"attachment_generation": host.get_attachment_generation()
				if host != null else 0,
		}.duplicate(true)

	func detach_planetary_surface() -> Dictionary:
		detach_calls += 1
		return super.detach_planetary_surface()


class CadenceSurfaceBinding:
	extends EmberSurfaceLoopProductionBinding

	var fake_phase := EmberSurfaceLoopHost.Phase.ON_FOOT
	var pending := false
	var last_intent_serial := 0
	var actor_kinds: Array[StringName] = []
	var actor_instance_ids: Array[int] = []
	var disembark_calls := 0
	var reboard_calls := 0
	var takeoff_calls := 0
	var identities: Dictionary = {}
	var retained_return_context: Dictionary = {}
	var snapshot_calls := 0

	func get_state() -> int:
		return State.RUNNING

	func get_snapshot() -> Dictionary:
		snapshot_calls += 1
		return {
			"state_id": &"running",
			"identities": identities.duplicate(true),
			"generation": get_generation(),
			"retained_return_context": retained_return_context.duplicate(true),
			"last_intent_serial": last_intent_serial,
			"pending_envelope": {
				"physics_frame": int(Engine.get_physics_frames()),
			} if pending else {},
			"pending_intent": {},
		}.duplicate(true)

	func get_caller_snapshot() -> Dictionary:
		return get_snapshot()

	func get_tick_admission_snapshot() -> Dictionary:
		return {
			"state_id": &"running",
			"identities": {"location_generation": int(identities.get("location_generation", 0))},
		}

	func get_generation() -> int:
		return 9

	func get_host_phase() -> int:
		return fake_phase

	func advance_from_caller_sample(
		_caller_serial: int, _delta: float, actor_kind: StringName,
		actor_instance_id: int, _craft_instance_id: int, _position: Vector3,
		_velocity_mps: Vector3, _landed: bool, _reboarded: bool, _takeoff: bool,
		_origin_result: Variant, _coordinate_frame_generation: int,
		_location_generation: int, _expected_generation: int,
		_orbit_return_ready: bool = false, _occupied_receipt: Variant = {},
		_landing_return_contract: Object = null,
		_return_observation: Dictionary = {},
		_return_travel_session: Object = null,
	) -> Dictionary:
		actor_kinds.append(actor_kind)
		actor_instance_ids.append(actor_instance_id)
		pending = true
		return {"accepted": true, "reason": &"caller_sample_advanced"}

	func queue_disembark_intent(intent_serial: int, _expected_generation: int) -> Dictionary:
		if not pending:
			return {"accepted": false, "reason": &"intent_without_pending_tick"}
		disembark_calls += 1
		last_intent_serial = intent_serial
		pending = false
		return {"accepted": true, "reason": &"host_intent_queued"}

	func queue_reboard_intent(intent_serial: int, _expected_generation: int) -> Dictionary:
		if not pending:
			return {"accepted": false, "reason": &"intent_without_pending_tick"}
		reboard_calls += 1
		last_intent_serial = intent_serial
		pending = false
		return {"accepted": true, "reason": &"host_intent_queued"}

	func queue_takeoff_intent(intent_serial: int, _expected_generation: int) -> Dictionary:
		if not pending:
			return {"accepted": false, "reason": &"intent_without_pending_tick"}
		takeoff_calls += 1
		last_intent_serial = intent_serial
		pending = false
		return {"accepted": true, "reason": &"host_intent_queued"}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	for _index in 180:
		await process_frame
		await physics_frame
		if bool(game.get("_initialized")) and game.get_flyable_ships().size() == 9:
			break
	game.set_physics_process(false)
	_check_surface_detach_refusals()
	var craft := game.active_ship as HeroShip
	var area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
	game.player.teleport_to(area.global_transform)
	await physics_frame
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var cadence := CadenceSurfaceBinding.new()
	var host := game.ember_surface_loop_host
	var session := PlanetaryTravelSession.new(
		EmberSurfaceLoopHost.HOST_ID,
		load(EmberSurfaceLoopHost.WORLD_PATH) as PlanetaryWorldDefinition,
		frame,
	)
	host.set("_session", session)
	cadence.identities = {
		"location_generation": 1,
		"host_instance_id": host.get_instance_id(),
		"player_instance_id": game.player.get_instance_id(),
		"ship_instance_id": craft.get_instance_id(),
	}
	game.ember_surface_loop_production_binding = cadence
	var idle_reports_match := true
	for _index in 32:
		idle_reports_match = idle_reports_match and (
			game._consume_mudds_station_return_handoff_intent(frame.get_generation())
			== {"accepted": false, "reason": &"station_return_handoff_not_pending"}
		)
		idle_reports_match = idle_reports_match and (
			game._advance_mudds_return_approach_handoff(frame.get_generation())
			== {"accepted": false, "reason": &"return_approach_handoff_not_pending"}
		)
	print("HANDOFF_DIAGNOSTIC_CALLS idle_pairs=32 snapshots=%d" % cadence.snapshot_calls)
	_check(idle_reports_match
		and not bool(game.get("_mudds_station_return_intent_consumption_attempted"))
		and not bool(game.get("_mudds_return_handback_consumption_attempted")),
		"idle handoff observations retain exact reports and leave both consumption fences open")
	_check(cadence.snapshot_calls == 0,
		"idle handoff polling does not construct full binding diagnostics")
	game.set("_piloting", true)
	game.set("_ember_surface_journey_active", true)
	game.set("_ember_final_approach_handoff_ready", true)
	game.ember_surface_loop_host.set("_phase", EmberSurfaceLoopHost.Phase.ON_FOOT)
	game.ember_surface_loop_host.set("_surface_route_return_complete", true)
	var on_foot_sample := game._capture_cinder_actor_sample()
	var on_foot_tick := game._advance_ember_surface_loop_cadence(
		0.016,
		on_foot_sample,
		{
			"accepted": true,
			"reason": &"no_rebase_required",
			"actor_sample": on_foot_sample.duplicate(true),
			"coordinate_frame_generation": frame.get_generation(),
		},
		frame.get_generation(),
	)
	game._on_interact_requested()
	_check(
		cadence.reboard_calls == 0 and cadence.pending,
		"a nearby reboard press waits for survey return admission without consuming the pending tick",
	)
	# Model the binding's already-authenticated admission boundary with the
	# current host, session, actor and craft identities; keep the coordinator gate live.
	cadence.retained_return_context = {
		"host_instance_id": host.get_instance_id(),
		"host_generation": host.get_generation(),
		"host_attachment_generation": host.get_attachment_generation(),
		"session_instance_id": session.get_instance_id(),
		"actor_instance_id": game.player.get_instance_id(),
		"craft_instance_id": craft.get_instance_id(),
	}
	game._on_interact_requested()
	_check(
		bool(on_foot_tick.get("accepted", false))
			and cadence.actor_kinds == [&"player"]
			and cadence.actor_instance_ids == [game.player.get_instance_id()]
			and cadence.reboard_calls == 1,
		"the shared cadence follows the on-foot Player and routes one nearby reboard intent",
	)

	craft.set_piloted(true)
	_check_abandon_departure_intent(game, craft)
	game.ember_surface_loop_host.set("_phase", EmberSurfaceLoopHost.Phase.LANDED)
	cadence.fake_phase = EmberSurfaceLoopHost.Phase.LANDED
	var landed_sample := game._capture_cinder_actor_sample()
	var landed_tick := game._advance_ember_surface_loop_cadence(
		0.016,
		landed_sample,
		{
			"accepted": true,
			"reason": &"no_rebase_required",
			"actor_sample": landed_sample.duplicate(true),
			"coordinate_frame_generation": frame.get_generation(),
		},
		frame.get_generation(),
	)
	game.ember_surface_loop_host.set("_phase", EmberSurfaceLoopHost.Phase.REBOARDED)
	cadence.fake_phase = EmberSurfaceLoopHost.Phase.REBOARDED
	var reboarded_sample := game._capture_cinder_actor_sample()
	var reboarded_tick := game._advance_ember_surface_loop_cadence(
		0.016,
		reboarded_sample,
		{
			"accepted": true,
			"reason": &"no_rebase_required",
			"actor_sample": reboarded_sample.duplicate(true),
			"coordinate_frame_generation": frame.get_generation(),
		},
		frame.get_generation(),
	)
	_check(
		bool(landed_tick.get("accepted", false))
			and bool(reboarded_tick.get("accepted", false))
			and cadence.disembark_calls == 1
			and cadence.takeoff_calls == 1
			and cadence.actor_kinds == [&"player", &"ship", &"ship"],
		"offline landing and completed reboard queue one typed disembark and takeoff each",
	)
	game.ember_surface_loop_host.set("_phase", EmberSurfaceLoopHost.Phase.IDLE)
	game.ember_surface_loop_host.set("_surface_route_return_complete", false)
	craft.set_piloted(false)
	var reserved := area.try_reserve(game.player)
	var boarded: bool = game.player.begin_boarding(
		craft.get_boarding_entry_transform(), craft.get_pilot_seat_anchor(),
		0.0, craft,
	)
	craft.set_piloted(true)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.set("_ember_surface_journey_active", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT

	# The production yard registry was populated before the outbound origin shift.
	# Its current return target must follow the actual registered dock and marker.
	var cached_home: Transform3D = game.world.get_ship_spawn()
	var home_rebases_accepted := true
	# Rebase out and back, ending in a locally precise yard frame for the
	# existing physical exit below, as the real origin owner does on arrival.
	for focus: Vector3 in [Vector3(17000.0, 125000.0, -8000000.0), Vector3(-17000.0, -124880.0, 7999970.0)]:
		var home_commit := _commit_origin_translation(game, craft, focus)
		home_rebases_accepted = home_rebases_accepted and bool(home_commit.get("accepted", false))
	var live_home: Transform3D = game.world.get_berth_node(ShipyardWorld.CENTRAL_BERTH_ID).get_dock_transform()
	_check(home_rebases_accepted and game.world.get_ship_spawn() == live_home
		and game.world.ship_spawn.global_transform == live_home and live_home != cached_home,
		"a production yard rebase resolves home from the live registered berth instead of its construction cache")
	var home_transform := game.world.call(&"get_ship_spawn") as Transform3D
	craft.global_transform = Transform3D(
		home_transform.basis,
		home_transform * Vector3(0.0, 0.0, 50_000.0),
	)
	craft.velocity = Vector3.ZERO
	var parent_before := craft.get_parent()
	var transform_before := craft.global_transform
	var player_parent_before := game.player.get_parent()

	var surface := CompletedSurfaceBinding.new()
	var return_composition := ReturnComposition.new()
	game.add_child(return_composition)
	surface.set("_planetary_composition", return_composition)
	var return_relay := ReturnRelay.new()
	game.add_child(return_relay)
	return_relay.set("_configured", true)
	return_relay.set("_attached", true)
	surface.set("_staging_relay_proximity", return_relay)
	# The canonical cruise unloads the relay's authored access marker. Exercise
	# the binding's real retirement callback before the final home contract.
	surface.call(&"_physics_process", 0.0)
	_check(not bool(return_relay.get_snapshot().get("attached", true))
		and return_relay.detach_calls == 1,
		"streamed-out access marker retires its still-owned relay exactly once")
	game.ember_surface_loop_host.set("_generation", 9)
	game.ember_surface_loop_host.set("_attachment_generation", 4)
	game.ember_surface_loop_host.set("_coordinate_frame_generation", frame.get_generation())
	game.ember_surface_loop_host.set("_attached", true)
	game.ember_surface_loop_host.set("_phase", EmberSurfaceLoopHost.Phase.ORBIT_RETURN)
	game.ember_surface_loop_host.set("_player_instance_id", game.player.get_instance_id())
	game.ember_surface_loop_host.set("_ship_instance_id", craft.get_instance_id())
	surface.set("_host", game.ember_surface_loop_host)
	surface.set("_generation", 9)
	surface.set("_state", EmberSurfaceLoopProductionBinding.State.HANDOFF_PENDING)
	surface.set("_ship", craft)
	surface.set("_player", game.player)
	surface.set("_ship_instance_id", craft.get_instance_id())
	surface.set("_player_instance_id", game.player.get_instance_id())
	return_composition.host_instance_id = game.ember_surface_loop_host.get_instance_id()
	surface.intent = _station_return_intent(
		game, frame, 9, 4
	)
	var retired_source := LocalShipInputSource.new()
	surface.handback = {
		"schema_version": EmberSurfaceLoopHost.SCHEMA_VERSION,
		"host_id": EmberSurfaceLoopHost.HOST_ID,
		"generation": 9,
		"reason": &"runtime_ownership_returned",
		"ship_instance_id": craft.get_instance_id(),
		"player_instance_id": game.player.get_instance_id(),
		"command_source_restored": true,
		"boarding_reservation_retained": true,
		"ship_piloted": true,
		"player_seated": true,
		"host_attached": false,
		"retired_attachment_generation": 4,
		"current_attachment_generation": 5,
		"boarding_area_instance_id": area.get_instance_id(),
		"boarding_reservation_token_instance_id": game.player.get_instance_id(),
		"host_command_source_instance_id": retired_source.get_instance_id(),
		"restored_command_source_instance_id": craft.get_command_source().get_instance_id(),
	}.duplicate(true)
	retired_source.free()
	game.ember_surface_loop_production_binding = surface
	cadence.free()
	var forged_intent := surface.intent.duplicate(true)
	(forged_intent.authority as Dictionary)["movement"] = true
	surface.intent = forged_intent
	var forged_reason := game._mudds_station_return_handoff_rejection(
		forged_intent, surface.get_snapshot(), frame.get_generation()
	)
	var actor_drift_intent := _station_return_intent(game, frame, 9, 4)
	actor_drift_intent["craft_instance_id"] = craft.get_instance_id() + 1
	surface.intent = actor_drift_intent
	var actor_drift_reason := game._mudds_station_return_handoff_rejection(
		actor_drift_intent, surface.get_snapshot(), frame.get_generation()
	)
	surface.intent = _station_return_intent(game, frame, 9, 4)
	surface.retained_session_instance_id = 0
	var session_drift_reason := game._mudds_station_return_handoff_rejection(
		surface.intent, surface.get_snapshot(), frame.get_generation()
	)
	surface.retained_session_instance_id = 7001
	var stale_intent := game._consume_mudds_station_return_handoff_intent(
		frame.get_generation() + 1
	)
	_check(
		forged_reason == &"station_return_handoff_claims_authority"
			and actor_drift_reason == &"station_return_handoff_actor_drift"
			and session_drift_reason == &"station_return_handoff_session_drift"
			and stale_intent.get("reason") == &"station_return_handoff_frame_drift"
			and surface.abort_calls == 1
			and (game.get("_mudds_station_return_intent_receipt") as Dictionary).is_empty()
			and not bool(game.get("_mudds_return_approach_active"))
			and not bool(game.get("_planetary_return_physical_arrival_required"))
			and not bool(game.get("_landing_request_active")),
		"forged authority and craft/session/frame drift abort before cruise, landing, or berth admission",
	)
	game.set("_mudds_station_return_intent_consumption_attempted", false)
	game.set("_last_mudds_station_return_intent_result", {})
	surface.intent_delivered = false
	surface.intent_take_calls = 0
	surface.abort_calls = 0
	surface.snapshot_calls = 0
	surface.snapshots_after_delivery = 0
	var intent_consumed := game._consume_mudds_station_return_handoff_intent(
		frame.get_generation()
	)
	var intent_replay := game._consume_mudds_station_return_handoff_intent(
		frame.get_generation()
	)
	game.ember_surface_loop_host.set("_attachment_generation", 5)
	game.ember_surface_loop_host.set("_attached", false)
	var armed := game._advance_mudds_return_approach_handoff(
		frame.get_generation()
	)
	print("HANDOFF_DIAGNOSTIC_CALLS consumed_and_armed snapshots=%d after_delivery=%d" % [
		surface.snapshot_calls, surface.snapshots_after_delivery,
	])
	_check(surface.snapshot_calls == 1 and surface.snapshots_after_delivery == 0,
		"actual handoff retains one full detached pre-consumption report for authentication")
	var target_result := game._build_mudds_return_approach_target()
	var target := target_result.get("target", {}) as Dictionary
	var fleet_bounds := target.get("fleet_collision_bounds", {}) as Dictionary
	var exact_hulls := fleet_bounds.size() == 9 \
		and GameFlow.MUDDS_RETURN_FLEET_IDS \
		== PlanetaryCruisePhysicalController.RETURN_APPROACH_FLEET_IDS
	for fleet_ship in game.get_flyable_ships():
		if not GameFlow.MUDDS_RETURN_FLEET_IDS.has(fleet_ship.get_ship_id()):
			continue
		exact_hulls = exact_hulls \
			and fleet_bounds.get(fleet_ship.get_ship_id(), AABB()) \
			== fleet_ship.get_landing_collision_report().get("local_bounds", AABB())
	_check(
		reserved and boarded and bool(intent_consumed.get("accepted", false))
			and intent_consumed.get("reason") == &"station_return_handoff_consumed"
			and not bool(intent_replay.get("accepted", true))
			and intent_replay.get("reason") == &"station_return_handoff_already_observed"
			and surface.intent_take_calls == 1
			and surface.abort_calls == 0
			and bool(armed.get("accepted", false))
			and armed.get("reason") == &"return_approach_armed"
			and surface.take_calls == 1,
		"the authenticated Ember intent and completed ownership are each consumed once before arming the production return",
	)
	_check(
		bool(target_result.get("accepted", false))
			and target.get("home_target_id") == &"mudds_shipyards"
			and target.get("home_target_world_transform") == home_transform
			and (target.get("corridor_half_extents_m") as Vector3).z == 750_000.0
			and float(target.get("brake_shell_max_distance_m", 0.0)) == 65_000.0
			and exact_hulls,
		"the station owner and all nine live hull owners supply the detached route proof",
	)
	# The explicit rejection below builds its own diagnostic snapshot. Run it
	# after proving the ordinary handoff retained only its one authentic report.
	game.ember_surface_loop_host.set("_phase", EmberSurfaceLoopHost.Phase.COMPLETED)
	game.ember_surface_loop_host.set("_runtime_ownership_returned", true)
	game.ember_surface_loop_host.set("_last_runtime_ownership_return_receipt", surface.handback.duplicate(true))
	var surface_detached := return_composition.detach()
	var early_retirement := surface.retire_completed_planetary_return()
	_check(bool(surface_detached.get("accepted", false))
		and not bool(early_retirement.get("accepted", true))
		and early_retirement.get("reason") == &"planetary_station_return_not_completed"
		and return_composition.detach_calls == 1
		and surface.get("_planetary_composition") == return_composition,
		"strict surface cleanup may precede home but terminal retirement remains refused before physical arrival")

	var cruise := game.planetary_cruise_binding as PlanetaryCruiseProductionBinding
	var controller := cruise.get_node(^"PlanetaryCruisePhysicalController") \
		as PlanetaryCruisePhysicalController
	controller.set(
		"_final_approach_state",
		PlanetaryCruisePhysicalController.FinalApproachState.ACTIVE,
	)
	var next_tick := int(cruise.get_snapshot().get("last_caller_tick", 0)) + 1
	var completed := cruise.physics_tick_from_caller_sample(
		next_tick,
		{
			"available": true,
			"position": craft.global_position,
			"actor_kind": &"ship",
			"actor_instance_id": craft.get_instance_id(),
		},
		craft, frame.get_generation(), false, &"",
	)
	var handed_off := game._consume_mudds_return_approach_completion(completed)
	var replay := game._consume_mudds_return_approach_completion(completed)
	var binding_replay := cruise.consume_return_approach_completion(
		int(completed.get("target_generation", 0)), cruise.get_generation()
	)
	var proof := ((completed.get("controller_completion", {}) as Dictionary)
		.get("measurement", {}) as Dictionary)
	_check(
		completed.get("reason") == &"return_approach_handoff_ready"
			and bool(proof.get(
				"full_flyable_fleet_corridor_proven", false
			))
			and bool(handed_off.get("accepted", false))
			and handed_off.get("reason") == &"return_approach_handed_to_station_lifecycle"
			and game.phase == GameFlow.Phase.RETURN_TO_YARD,
		"the normal caller cadence yields once into the existing yard return phase",
	)
	_check(
		not bool(replay.get("accepted", true))
			and replay.get("reason") == &"return_approach_completion_replayed"
			and not bool(binding_replay.get("accepted", true))
			and binding_replay.get("reason") == &"return_approach_completion_replayed"
			and surface.take_calls == 1,
		"both handback and terminal completion retain their exact-once replay fences",
	)
	_check(
		craft.get_parent() == parent_before
			and craft.global_transform == transform_before
			and game.player.get_parent() == player_parent_before
			and not bool(game.get("_landing_request_active"))
			and not bool(game.get("_return_registered"))
			and int(craft.get_planetary_cruise_attachment_report()
				.get("controller_instance_id", -1)) == 0,
		"handoff neither moves nor reparents actors and leaves berth occupancy unclaimed",
	)

	# The ordinary local home leg crosses the 10 km origin threshold after the
	# corridor has relinquished cruise. Preserve its proof through the real owner.
	var journey = game.get("_planetary_journey")
	var original_shell := (journey.get("_mudds_return_approach_completion_receipt") as Dictionary).duplicate(true)
	# Keep the yard below the old world-space recall floor after this added real
	# translation, so the existing disembark/walking regression retains its setup.
	var home_shift := _commit_origin_translation(game, craft, craft.global_position + Vector3.UP * 120.0)
	var home_receipt := home_shift.get("receipt", {}) as Dictionary
	var forged_home_receipt := home_receipt.duplicate(true)
	forged_home_receipt["world_translation_delta"] = Vector3.ONE
	var forged_projection: Dictionary = journey._translate_pending_return_shell(forged_home_receipt)
	var shell_unchanged_after_forgery: bool = journey.get("_mudds_return_approach_completion_receipt") == original_shell
	var announcement: Dictionary = journey._announce_committed_origin_rebase(home_receipt)
	var projection := announcement.get("return_shell", {}) as Dictionary
	var current_shell := journey.get("_mudds_return_approach_completion_receipt") as Dictionary
	var projected_target := (current_shell.get("controller_completion", {}) as Dictionary).get("target", {}) as Dictionary
	var original_target := (original_shell.get("controller_completion", {}) as Dictionary).get("target", {}) as Dictionary
	var expected_home := original_target.get("home_target_world_transform", Transform3D.IDENTITY) as Transform3D
	expected_home.origin += home_receipt.get("world_translation_delta", Vector3.ZERO) as Vector3
	var projection_replay: Dictionary = journey._translate_pending_return_shell(home_receipt)
	_check(bool(home_shift.get("accepted", false))
		and bool(projection.get("accepted", false))
		and projection.get("reason") == &"return_shell_origin_translated"
		and not bool(forged_projection.get("accepted", true))
		and shell_unchanged_after_forgery
		and not bool(projection_replay.get("accepted", true))
		and current_shell.get("generation") == original_shell.get("generation")
		and current_shell.get("generation") == cruise.get_generation()
		and (cruise.get_snapshot().get("final_approach", {}) as Dictionary).get("completion_receipt", {}) == original_shell
		and current_shell.get("coordinate_frame_generation") == frame.get_generation()
		and projected_target.get("home_target_world_transform") == expected_home
		and projected_target.get("fleet_collision_bounds") == original_target.get("fleet_collision_bounds")
		and projected_target.get("fleet_corridor_proof") == original_target.get("fleet_corridor_proof")
		and not bool(game.get("_landing_request_active"))
		and not bool(game.get("_return_registered")),
		"RETURN_SHELL_ORIGIN_TRANSLATION_OK: committed local-home rebase preserves the exact shell and rejects forgery/replay before berth admission")

	var home_berth := game.world.call(
		&"get_berth_node", craft.get_home_berth_id()
	) as ShipBerth
	craft.global_transform = home_berth.get_dock_transform()
	craft.velocity = Vector3.ZERO
	var landing_parent_before := craft.get_parent()
	game._try_request_landing()
	var landing_started := craft.get_planetary_cruise_attachment_report()
	var landing_token := StringName(
		game.get("_berth_tokens").get(craft.get_instance_id(), &"")
	)
	if not bool(game.get("_planetary_return_physical_arrival_armed")):
		push_error("physical arrival arm result: %s identities=%s" % [
			game.get("_last_planetary_return_physical_arrival_result"),
			{
				"surface_generation": surface.get_generation(),
				"host_attachment": game.ember_surface_loop_host.get_attachment_generation(),
				"shell_generation": cruise.get_generation(),
				"frame_generation": frame.get_generation(),
				"token": landing_token,
				"actor": game.player.get_instance_id(),
				"craft": craft.get_instance_id(),
			},
		])
	_check(
		bool(game.get("_planetary_return_physical_arrival_required"))
			and bool(game.get("_planetary_return_physical_arrival_armed"))
			and bool(game.get("_landing_request_active"))
			and game.get("_active_landing_berth_id") == craft.get_home_berth_id()
			and not landing_token.is_empty()
			and home_berth.get_reservation_token(craft) == landing_token
			and landing_started.get("reason") == &"landing_started"
			and bool(landing_started.get("landing_active", false)),
		"the pending Ember return adopts GameFlow's exact home-berth landing lease",
	)
	var home_return_adapter: Object = surface.get("_return_berth_adapter")
	craft.call(
		&"_complete_landing",
		home_berth,
		home_berth.get_dock_transform().basis,
	)
	var terminal_result := game.get(
		"_last_planetary_return_physical_arrival_result"
	) as Dictionary
	var terminal_cleanup_valid: bool = (
		bool(terminal_result.get("accepted", false))
			and terminal_result.get("reason") == &"planetary_return_consumed"
			and game.phase == GameFlow.Phase.SHUT_DOWN
			and bool(game.get("_planetary_return_receipt_consumed"))
			and not bool(game.get("_planetary_return_physical_arrival_required"))
			and not bool(game.get("_planetary_return_physical_arrival_armed"))
			and home_berth.get_occupant() == craft
			and home_berth.get_reservation_token(craft) == landing_token
			and craft.get_parent() == landing_parent_before
			and surface.detach_calls == 1
			and return_composition.detach_calls == 1
			and return_relay.detach_calls == 1
			and surface.get("_planetary_composition") == null
			and surface.get("_staging_relay_proximity") == null
	)
	_check(
		terminal_cleanup_valid,
		"real HeroShip touchdown produces one consumed physical station receipt without reparent or second lease",
	)
	if not terminal_cleanup_valid:
		print("HOME_RETURN_TERMINAL_REJECTED: ", terminal_result)
	var terminal_replay := game.consume_planetary_return_receipt(
		{
			"accepted": true,
			"reason": &"returned_to_station",
		},
		surface,
		home_berth,
		craft,
		game.player,
	)
	var terminal_replay_rejected: bool = (
		not bool(terminal_replay.get("accepted", true))
			and terminal_replay.get("reason") == &"planetary_return_receipt_replayed"
			and surface.detach_calls == 1
			and return_composition.detach_calls == 1
			and return_relay.detach_calls == 1
	)
	_check(
		terminal_replay_rejected,
		"the terminal station handoff cannot detach or consume twice",
	)
	if terminal_cleanup_valid and terminal_replay_rejected:
		print("HOME_RETURN_STREAMED_RELAY_CLEANUP_OK: strict home contract retires its composition without detaching the streamed-out relay twice")
	if terminal_cleanup_valid:
		_check_return_detach_diagnostic(game, craft, home_berth, landing_token)
		_check_terminal_retirement(game, craft, surface.handback, home_return_adapter)

	for _index in 300:
		await physics_frame
		if str(craft.get_telemetry().get("engine_state", "ONLINE")).to_upper() \
				== "OFFLINE":
			break
	var engine_offline := str(
		craft.get_telemetry().get("engine_state", "ONLINE")
	).to_upper() == "OFFLINE"
	game._try_exit_ship()
	for _index in 300:
		await process_frame
		await physics_frame
		if not bool(game.get("_piloting")):
			break
	_check(
		engine_offline
			and not craft.is_piloted()
			and not bool(game.get("_piloting"))
			and not bool(game.player.call(&"is_seated"))
			and home_berth.get_occupant() == craft,
		"the consumed physical arrival reaches the existing automatic shutdown and disembark lifecycle",
	)

	for _tick in 240:
		await physics_frame
		await process_frame
		if game.player.is_control_enabled() and not bool(game.get("_transition_busy")):
			break
	var walk_start := game.player.global_position
	Input.action_press(&"move_back")
	for _tick in 20:
		await physics_frame
		await process_frame
	Input.action_release(&"move_back")
	var walk_distance := game.player.global_position.distance_to(walk_start)
	_check(walk_start.y < -24.0 and walk_distance > 0.25 and walk_distance < 5.0
		and game.player.is_control_enabled(),
		"the returned pilot walks normally on a yard translated below the old world-space recall floor")
	# A genuine below-deck fall still reaches the live station spawn. This is a
	# separate recovery witness after the physical return and walking assertion.
	game.player.global_position = game.world.to_global(Vector3(0.0, -30.0, 0.0))
	game.player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	_check(game.player.global_position.distance_to(game.world.get_player_spawn().origin) < 1.0,
		"the yard-relative recovery floor still recalls a genuine below-deck fall")

	game.ember_surface_loop_production_binding = null
	surface.free()
	game.queue_free()
	await process_frame
	await _check_shared_abandon_return()
	_finish()


func _check_abandon_departure_intent(game: GameFlow, craft: HeroShip) -> void:
	var previous_phase := game.phase
	var previous_departed: bool = game.get("_sortie_departed_berth")
	var previous_piloting: bool = game.get("_piloting")
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.set("_sortie_departed_berth", true)
	game.set("_piloting", true)
	var journey: Object = game.get("_planetary_journey")
	journey.set("_ember_abandon_return_arm_pending", true)
	journey.set("_ember_abandon_return_active", true)
	journey.call(&"_observe_abandon_return_departure_tick", {
		"accepted": false, "reason": &"obstacle_detected",
	})
	_check(journey.is_return_departure_pending(),
		"an initial terrain refusal retains the queued return before cruise propulsion")
	var previous_command: ShipCommand = craft.get("_last_ship_command")
	var manual := ShipCommand.new()
	manual.set("_throttle", 1.0)
	craft.set("_last_ship_command", manual)
	var attempts := int(journey.get("_ember_abandon_return_arm_attempts"))
	for _tick in 1000:
		journey.call(&"_retry_ember_abandon_return_approach", 1)
	_check(journey.is_return_departure_pending()
		and int(journey.get("_ember_abandon_return_arm_attempts")) == attempts,
		"held ordinary departure input preserves the queue without exhausting its retry budget")
	journey.call(&"_observe_abandon_return_departure_tick", {
		"accepted": false, "reason": &"ship_attachment_retired",
	})
	_check(journey.is_return_departure_pending(),
		"manual flight before propulsion can retire an armed attachment without losing departure intent")
	journey.call(&"_observe_abandon_return_departure_tick", {
		"accepted": false, "reason": &"coordinate_frame_generation_mismatch",
	})
	_check(not journey.is_return_departure_pending(),
		"fatal frame failure retires queued departure even while controls are held")
	craft.set("_last_ship_command", ShipCommand.new())
	var previous_cruise_state: StringName = craft.get("_planetary_cruise_state")
	craft.set("_planetary_cruise_state", HeroShip.PLANETARY_CRUISE_STATE_BRAKING)
	journey.set("_ember_abandon_return_arm_pending", true)
	var braking: Dictionary = journey.call(&"_retry_ember_abandon_return_approach", 1)
	_check(journey.is_return_departure_pending() and braking.get("reason") == &"braking_in_progress",
		"the existing fail-closed brake can settle before queued return admission retries")
	craft.set("_planetary_cruise_state", previous_cruise_state)
	craft.set("_last_ship_command", previous_command)
	journey.set("_ember_abandon_return_arm_pending", true)
	journey.set("_ember_abandon_return_active", true)
	var cancelled: Dictionary = journey.cancel_return_departure(&"player_cancelled", false)
	_check(bool(cancelled.get("accepted", false)) and not journey.is_return_departure_pending()
		and not bool(journey.get("_ember_abandon_return_active")),
		"explicit cancellation clears the queued return before a cruise attachment exists")
	journey.set("_ember_abandon_return_arm_pending", true)
	journey.set("_ember_abandon_return_active", true)
	journey.call(&"_observe_abandon_return_departure_tick", {
		"accepted": true, "controller": {"policy": {"desired_cruise_participation": true}},
	})
	journey.call(&"_observe_abandon_return_departure_tick", {
		"accepted": false, "reason": &"obstacle_detected",
	})
	_check(not journey.is_return_departure_pending(),
		"after first propulsion an interrupted return never recreates departure intent")
	journey.cancel_return_departure()
	journey.set("_ember_abandon_return_arm_pending", true)
	journey.set("_ember_abandon_return_arm_attempts", 900)
	journey.call(&"_retry_ember_abandon_return_approach", 1)
	_check(not journey.is_return_departure_pending()
		and journey.get("_last_ember_abandon_return_arm_result").get("reason") == &"abandon_return_arm_exhausted",
		"a permanently refused unattended return expires its bounded retry intent")
	journey.set("_ember_abandon_return_arm_attempts", 0)
	journey.set("_ember_abandon_return_arm_pending", true)
	craft.set_piloted(false)
	journey.call(&"_retry_ember_abandon_return_approach", 1)
	_check(not journey.is_return_departure_pending(),
		"pilot detachment retires queued departure instead of resuming on a later boarding")
	craft.set_piloted(true)
	journey.set("_ember_abandon_return_arm_pending", true)
	journey.set("_ember_abandon_return_active", true)
	journey.detach()
	_check(not journey.is_return_departure_pending()
		and not bool(journey.get("_ember_abandon_return_active")),
		"Main detachment clears pending and active return intent")
	journey.set("_ember_abandon_return_arm_pending", true)
	journey.call(&"_observe_abandon_return_departure_tick", {
		"accepted": true, "reason": &"return_approach_handoff_ready",
	})
	_check(not journey.is_return_departure_pending(),
		"an already arrived return handoff cannot rearm a second departure without propulsion")
	journey.set("_ember_abandon_return_arm_pending", true)
	craft.set("_last_ship_command", manual)
	var recovering: bool = game.get("_recovering")
	game.set("_recovering", true)
	journey.call(&"_retry_ember_abandon_return_approach", 1)
	_check(not journey.is_return_departure_pending(),
		"a recovery gate retires pending departure even while manual input is held")
	game.set("_recovering", recovering)
	craft.set("_last_ship_command", previous_command)
	game.phase = previous_phase
	game.set("_sortie_departed_berth", previous_departed)
	game.set("_piloting", previous_piloting)


func _check_shared_abandon_return() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	for _index in 180:
		await process_frame
		await physics_frame
		if bool(game.get("_initialized")) and game.get_flyable_ships().size() == 9:
			break
	game.set_physics_process(false)
	var craft := game.active_ship as HeroShip
	craft.set_physics_process(false)
	var area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
	var reservation: bool = area.try_reserve(game.player)
	var seated: bool = game.player.begin_boarding(craft.get_boarding_entry_transform(),
		craft.get_pilot_seat_anchor(), 0.0, craft)
	craft.set_piloted(true)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var home: Transform3D = game.world.get_ship_spawn()
	# As in the existing focused return case, stage the already-airborne contract.
	# The Host readiness/commit and cruise query below remain real production calls.
	craft.global_transform = Transform3D(home.basis, home * Vector3(0.0, 0.0, 50_000.0))
	craft.set("_landed", false)
	craft.set("_docked_latch", false)
	craft.velocity = Vector3.ZERO
	var hosted := game.host_network_session(43000 + OS.get_process_id() % 10000)
	var claim := game._claim_network_host_pilot_seat(craft)
	var bridge: RefCounted = game.get("_network_planetary_journey")
	var begun: Dictionary = bridge.call(&"begin")
	_check(reservation and seated and bool(hosted.get("accepted", false))
		and bool(claim.get("accepted", false)) and bool(begun.get("accepted", false)),
		"shared abandoned-return fixture retains real seated pilot, ENet session and ledger owner")
	if not bool(begun.get("accepted", false)):
		game.free()
		return
	(bridge.get("_state") as Dictionary)["phase"] = &"landed"
	var pilot_source := craft.get_command_source()
	var bootstrap := game.ember_streaming_bootstrap
	var frame := bootstrap.get_coordinate_frame_for_session()
	var origin_binding := game.ember_streaming_binding
	var origin_owner := game.common_world_origin_rebase_owner
	# Use the real owner/binding transaction to load the authored Ember root.
	# These are focused setup poses, not ordinary physical travel acceptance.
	craft.global_position = bootstrap.global_position
	var body_sample: Dictionary = game._capture_cinder_actor_sample()
	origin_binding.physics_tick_from_caller_sample(1.0 / 60.0, body_sample)
	var body_preview := origin_binding.preview_origin_rebase(frame.get_generation())
	var body_rebase := origin_owner.consume_rebase_preview(body_preview, body_sample)
	await process_frame
	await process_frame
	var streamed_scene := bootstrap.get_loaded_instance() as EmberMoonAuthoredScene
	if not bool(body_rebase.get("accepted", false)) or streamed_scene == null:
		_check(false, "shared abandoned-return setup loads its real published Ember scene")
		game.free()
		return
	var landing_root := streamed_scene.get_node(^"LandingRegion") as Node3D
	craft.global_transform = landing_root.global_transform * Transform3D(
		Basis.IDENTITY, EmberSurfaceLoopHost.APPROACH_ENTRY_REGION_LOCAL_M)
	var surface_sample: Dictionary = game._capture_cinder_actor_sample()
	origin_binding.physics_tick_from_caller_sample(1.0 / 60.0, surface_sample)
	var surface_preview := origin_binding.preview_origin_rebase(frame.get_generation())
	var surface_rebase := origin_owner.consume_rebase_preview(surface_preview, surface_sample)
	var host := game.ember_surface_loop_host
	game.ember_surface_berth.global_transform = landing_root.global_transform
	var attached := host.bind_dependencies(bootstrap, game.ember_surface_berth, craft,
		game.player as PlayerController, 1.62, bootstrap.get_location_generation(),
		host.get_generation(), host.get_attachment_generation(), game, origin_owner)
	var started := host.start(host.get_generation(), host.get_attachment_generation(), frame.get_generation())
	# The return test begins at the same staged ASCENT boundary, after real bind/start.
	host.set("_phase", EmberSurfaceLoopHost.Phase.ASCENT)
	host.set("_surface_clear_submitted", false)
	var valid_host: bool = bool(surface_rebase.get("accepted", false)) \
		and bool(attached.get("accepted", false)) and bool(started.get("accepted", false)) \
		and bool(host.audit().get("valid", false))
	_check(valid_host, "shared abandoned return begins with a valid real Host, published scene and current generations")
	if not valid_host:
		game.free()
		return
	var journey: RefCounted = game.get("_planetary_journey")
	journey.set("_ember_surface_journey_active", true)
	journey.set("_shared_ember_landing_active", true)
	journey.set("_shared_ember_surface_context", {
		"host_instance_id": host.get_instance_id(), "host_generation": host.get_generation(),
		"host_attachment_generation": host.get_attachment_generation(),
		"ship_instance_id": craft.get_instance_id(), "player_instance_id": game.player.get_instance_id(),
		"network_session_instance_id": game.network_session.get_instance_id(),
		"network_session_epoch": game.get("_network_hud_session_epoch"),
		"journey_epoch": game.get_network_planetary_journey_snapshot().journey_epoch,
	})
	var pending: Dictionary = journey.call(&"abandon_ember_surface_journey")
	_check(bool(attached.get("accepted", false)) and bool(started.get("accepted", false))
		and pending.get("reason") == &"ember_surface_abandon_pending_return"
		and not journey.call(&"shared_ember_abandon_return_was_admitted")
		and not journey.call(&"is_return_departure_pending"),
		"shared abandonment cannot queue home before the real Host surface-clear commitment")
	_check(not journey.call(&"shared_ember_abandon_handback_pending"),
		"pending surface work without an actual committed Host receipt cannot retain a stale shared boundary")
	var manual := ShipCommand.new()
	manual.set("_throttle", 1.0)
	craft.set("_last_ship_command", manual)
	host.set("_surface_clear_submitted", true)
	# Commit through the real late Host operation, before Main has observed it.
	var committed := host.advance_physics(1.0 / 60.0, host.get_generation(),
		host.get_attachment_generation(), frame.get_generation(), host.get_location_generation())
	var authentic_receipt := (host.get_abandon_snapshot().get("receipt", {}) as Dictionary).duplicate(true)
	var authentic_result := (host.get("_last_result") as Dictionary).duplicate(true)
	var boundary_epoch := int(game.get("_network_hud_session_epoch"))
	var boundary_journey := int(game.get_network_planetary_journey_snapshot().get("journey_epoch", 0))
	for boundary: StringName in [&"forged_receipt", &"stale_session_epoch", &"host_bind_result"]:
		if boundary == &"forged_receipt":
			var forged := authentic_receipt.duplicate(true)
			forged["retired_generation"] = int(forged.retired_generation) + 1
			host.set("_last_abandon_receipt", forged)
		elif boundary == &"stale_session_epoch":
			game.set("_network_hud_session_epoch", boundary_epoch + 1)
		else:
			host.set("_last_result", {"accepted": true, "reason": &"bound"})
		_check(not journey.call(&"shared_ember_abandon_handback_pending"),
			"%s cannot retain the pending shared handback boundary" % boundary)
		host.set("_last_abandon_receipt", authentic_receipt.duplicate(true))
		host.set("_last_result", authentic_result.duplicate(true))
		game.set("_network_hud_session_epoch", boundary_epoch)
	bridge.call(&"before_world_tick")
	_check(journey.call(&"shared_ember_abandon_handback_pending")
		and int(game.get_network_planetary_journey_snapshot().get("journey_epoch", 0)) == boundary_journey
		and bool(journey.get("_ember_surface_abandon_pending"))
		and not journey.call(&"shared_ember_abandon_return_was_admitted")
		and not journey.call(&"is_return_departure_pending")
		and craft.get_command_source() == pilot_source,
		"ordinary bridge pre-tick retains only the genuine unconsumed late Host handback without arming return")
	journey.call(&"_advance_ember_surface_abandon", frame.get_generation())
	bridge.call(&"after_world_tick")
	_check(bool(committed.get("accepted", false)) and host.is_attached()
		and bool(host.audit().get("valid", false))
		and journey.call(&"shared_ember_abandon_return_is_current")
		and journey.call(&"is_return_departure_pending")
		and game.get_network_planetary_journey_snapshot().get("phase") == &"returning"
		and craft.get_command_source() == pilot_source and game.player.is_seated_at(craft.get_pilot_seat_anchor())
		and (journey.get("_ember_survey_return_manifest") as Dictionary).is_empty()
		and (journey.get("_mudds_return_handback_receipt") as Dictionary).is_empty(),
		"genuine Host abandonment restores the same pilot and retains shared manual departure without fabricating completion")
	var committed_attachment := host.get_attachment_generation()
	# A homeward origin shift leaves Ember resident. Releasing the idle Host
	# must preserve its exact abandoned receipt rather than bind a new visit.
	var return_frame_generation := frame.get_generation()
	var return_rebase := _commit_origin_translation(game, craft, Vector3(0.0, 0.0, 11000.0))
	journey.call(&"_ensure_ember_surface_loop_host_bound", true)
	journey.call(&"_ensure_ember_surface_loop_host_bound", true)
	print("ABANDON_REBASE_RELEASE: ", {"rebase_reason": return_rebase.get("reason"),
		"source_frame": return_frame_generation, "frame": frame.get_generation(),
		"same_loaded_scene": bootstrap.get_loaded_instance() == streamed_scene,
		"host_attached": host.is_attached(), "attachment": host.get_attachment_generation(),
		"receipt_current": host.is_idle_abandon_release_current(authentic_receipt)})
	_check(bool(return_rebase.get("accepted", false))
		and frame.get_generation() == return_frame_generation + 1
		and bootstrap.get_loaded_instance() == streamed_scene
		and not host.is_attached() and host.get_attachment_generation() == committed_attachment + 1
		and host.is_idle_abandon_release_current(authentic_receipt)
		and journey.call(&"shared_ember_abandon_return_is_current")
		and craft.get_command_source() == pilot_source
		and game.player.is_seated_at(craft.get_pilot_seat_anchor()),
		"real homeward rebase preserves the released abandoned Host while its same Ember scene remains loaded")
	if not _failures.is_empty():
		game.free()
		return
	var station_coordinate := NearbySectorOrbitalRegistry.new().get_coordinate(
		NearbySectorOrbitalRegistry.STATION_DATUM_ID)
	var unloaded := bootstrap.update_absolute_focus(station_coordinate, frame.get_generation())
	journey.call(&"_ensure_ember_surface_loop_host_bound", true)
	bridge.call(&"before_world_tick")
	bridge.call(&"after_world_tick")
	var released_receipt := host.get_abandon_snapshot().get("receipt", {}) as Dictionary
	_check(bool(unloaded.get("accepted", false)) and bootstrap.get_loaded_instance() == null
		and not host.is_attached() and host.get_attachment_generation() == committed_attachment + 1
		and host.is_idle_abandon_release_current(released_receipt)
		and journey.call(&"shared_ember_abandon_return_is_current")
		and journey.call(&"is_return_departure_pending")
		and game.get_network_planetary_journey_snapshot().get("phase") == &"returning"
		and craft.get_command_source() == pilot_source and game.player.is_seated_at(craft.get_pilot_seat_anchor()),
		"real idle streamed-scene detach preserves the same authenticated shared abandoned return")
	var blocker := StaticBody3D.new()
	blocker.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	blocker.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100.0, 100.0, 100.0)
	collision.shape = box
	blocker.add_child(collision)
	game.add_child(blocker)
	blocker.global_position = craft.global_position
	await physics_frame
	craft.set("_last_ship_command", ShipCommand.new())
	var armed: Dictionary = journey.call(&"_retry_ember_abandon_return_approach", frame.get_generation())
	var binding := game.planetary_cruise_binding
	await physics_frame
	var refused := binding.physics_tick_from_caller_sample(Engine.get_physics_frames(), game._capture_cinder_actor_sample(),
		craft, frame.get_generation(), false, game._planetary_cruise_gate_reason(false))
	journey.call(&"_observe_abandon_return_departure_tick", refused)
	bridge.call(&"after_world_tick")
	_check(bool(armed.get("accepted", false)) and refused.get("reason") == &"obstacle_detected"
		and journey.call(&"is_return_departure_pending") and journey.call(&"shared_ember_abandon_return_is_current")
		and game.get_network_planetary_journey_snapshot().get("phase") == &"returning",
		"actual hull obstruction refuses shared abandoned propulsion while retaining the authenticated departure queue")
	blocker.free()
	craft.set_physics_process(true)
	var clear_tick: Dictionary = {}
	for _tick in 12:
		await physics_frame
		var retry: Dictionary = journey.call(&"_retry_ember_abandon_return_approach", frame.get_generation())
		if bool(retry.get("accepted", false)):
			clear_tick = binding.physics_tick_from_caller_sample(Engine.get_physics_frames(), game._capture_cinder_actor_sample(),
				craft, frame.get_generation(), false, game._planetary_cruise_gate_reason(false))
			journey.call(&"_observe_abandon_return_departure_tick", clear_tick)
			if bool(clear_tick.get("accepted", false)):
				break
	bridge.call(&"before_world_tick")
	bridge.call(&"after_world_tick")
	_check(bool(clear_tick.get("accepted", false)) and journey.call(&"shared_ember_abandon_return_is_current")
		and bool(binding.get_snapshot().get("engagement_requested", false))
		and game.get_network_planetary_journey_snapshot().get("phase") == &"returning",
		"fresh strict clearance resumes the same shared abandoned home owner after actual obstacle removal and publication")
	var context := (journey.get("_shared_ember_abandon_return_context") as Dictionary).duplicate(true)
	var hud_epoch := int(game.get("_network_hud_session_epoch"))
	var bridge_state := (bridge.get("_state") as Dictionary).duplicate(true)
	var host_generation := host.get_generation()
	var released_attachment := host.get_attachment_generation()
	var foreign_craft: HeroShip
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate != craft:
			foreign_craft = candidate
			break
	for stale: StringName in [&"session_epoch", &"journey_epoch", &"craft", &"pilot_source", &"host_generation", &"host_rebound", &"extra_attachment"]:
		journey.set("_shared_ember_abandon_return_context", context.duplicate(true))
		journey.set("_ember_abandon_return_arm_pending", true)
		if stale == &"session_epoch":
			game.set("_network_hud_session_epoch", hud_epoch + 1)
		elif stale == &"journey_epoch":
			(bridge.get("_state") as Dictionary)["journey_epoch"] = int(bridge_state.journey_epoch) + 1
		elif stale == &"craft":
			game.active_ship = foreign_craft
		elif stale == &"pilot_source":
			craft.set_command_source(foreign_craft.get_command_source())
		elif stale == &"host_rebound":
			# Fresh bind retains generation but restores attachment and clears release.
			host.set("_attached", true)
			host.set("_visit_released_detached", false)
		elif stale == &"extra_attachment":
			host.set("_attachment_generation", released_attachment + 1)
		else:
			host.set("_generation", host_generation + 1)
		var rejected: Dictionary = journey.call(&"_retry_ember_abandon_return_approach", frame.get_generation())
		_check(rejected.get("reason") == &"shared_abandon_return_owner_retired"
			and not journey.call(&"is_return_departure_pending")
			and not journey.call(&"shared_ember_abandon_return_was_admitted"),
			"stale %s retires shared abandoned return before admission" % stale)
		game.set("_network_hud_session_epoch", hud_epoch)
		bridge.set("_state", bridge_state.duplicate(true))
		game.active_ship = craft
		craft.set_command_source(pilot_source)
		host.set("_generation", host_generation)
		host.set("_attachment_generation", released_attachment)
		host.set("_attached", false)
		host.set("_visit_released_detached", true)
	journey.set("_shared_ember_abandon_return_context", context.duplicate(true))
	journey.set("_ember_abandon_return_arm_pending", true)
	var reloaded := bootstrap.update_absolute_focus(
		NearbySectorOrbitalRegistry.new().get_coordinate(NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID),
		frame.get_generation())
	await process_frame
	await process_frame
	var resident_scene := bootstrap.get_loaded_instance()
	journey.call(&"_ensure_ember_surface_loop_host_bound", true)
	var release_retained: bool = not host.is_attached() \
		and host.is_idle_abandon_release_current(authentic_receipt) \
		and journey.call(&"shared_ember_abandon_return_is_current")
	game.shutdown_network_session(&"shared_abandon_return_test_done")
	_check(release_retained and not journey.call(&"is_return_departure_pending")
		and not journey.call(&"shared_ember_abandon_return_was_admitted")
		and game.get_network_planetary_journey_snapshot().get("journey_epoch", 0) == 0,
		"actual session shutdown retires the retained abandoned return and its shared epoch synchronously")
	var rebound: Dictionary = journey.call(&"_ensure_ember_surface_loop_host_bound", true)
	_check(bool(reloaded.get("accepted", false)) and is_instance_valid(resident_scene)
		and bool(rebound.get("accepted", false)) and host.is_attached()
		and bootstrap.get_loaded_instance() == resident_scene
		and not journey.call(&"shared_ember_abandon_return_was_admitted")
		and craft.get_command_source() == pilot_source,
		"ending the authenticated abandoned return permits normal Host binding to the same resident scene")
	await _check_abandoned_typed_home_handoff(game, craft)
	game.free()


func _check_abandoned_typed_home_handoff(game: GameFlow, craft: HeroShip) -> void:
	# Stage only this focused shell observation, as in the completed-return case.
	# The production binding/controller still issue and consume the typed proof.
	craft.set_physics_process(false)
	var home: Transform3D = game.world.get_ship_spawn()
	craft.global_transform = Transform3D(home.basis, home * Vector3(0.0, 0.0, 50_000.0))
	craft.velocity = Vector3.ZERO
	craft.set("_last_ship_command", ShipCommand.new())
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var journey = game.get("_planetary_journey")
	var cruise := game.planetary_cruise_binding
	var target_result: Dictionary = journey.call(&"_build_mudds_return_approach_target")
	var engaged := cruise.request_engage(craft, frame.get_generation(), &"", cruise.get_generation(), true)
	var armed := cruise.request_return_approach(target_result.get("target", {}),
		frame.get_generation(), cruise.get_generation(), game.world.ship_spawn)
	journey.set("_mudds_return_approach_active", true)
	journey.set("_mudds_return_approach_completion_attempted", false)
	journey.set("_ember_abandon_return_active", true)
	var controller := cruise.get_node(^"PlanetaryCruisePhysicalController") as PlanetaryCruisePhysicalController
	controller.set("_final_approach_state", PlanetaryCruisePhysicalController.FinalApproachState.ACTIVE)
	var completed := cruise.physics_tick_from_caller_sample(
		int(cruise.get_snapshot().get("last_caller_tick", 0)) + 1,
		game._capture_cinder_actor_sample(), craft, frame.get_generation(), false, &"")
	var before_handoff := craft.global_transform
	var pilot_source := craft.get_command_source()
	var handed_off: Dictionary = journey.call(&"_consume_mudds_return_approach_completion", completed)
	var replay: Dictionary = journey.call(&"_consume_mudds_return_approach_completion", completed)
	print("ABANDON_TYPED_HOME_HANDOFF: ", {"engaged": engaged.get("accepted"),
		"armed": armed.get("accepted"), "completion": completed.get("reason"),
		"handoff": handed_off.get("reason"), "phase": game.phase})
	_check(bool(engaged.get("accepted", false)) and bool(armed.get("accepted", false))
		and completed.get("reason") == &"return_approach_handoff_ready"
		and handed_off.get("reason") == &"abandoned_return_handed_to_station_lifecycle"
		and game.phase == GameFlow.Phase.RETURN_TO_YARD
		and not bool(journey.get("_planetary_return_physical_arrival_required"))
		and not bool(journey.get("_planetary_return_receipt_consumed"))
		and not bool(game.get("_return_registered"))
		and craft.global_transform == before_handoff and craft.get_command_source() == pilot_source
		and craft.is_piloted() and game.player.is_seated_at(craft.get_pilot_seat_anchor())
		and (journey.get("_ember_survey_return_manifest") as Dictionary).is_empty()
		and replay.get("reason") == &"return_approach_completion_replayed",
		"authentic abandoned typed home completion enters ordinary yard return without successful arrival entitlement")


func _station_return_intent(
		game: GameFlow,
		frame: PlanetaryCoordinateFrame,
		session_generation: int,
		attachment_generation: int
	) -> Dictionary:
	return {
		"schema_version": 1,
		"intent_id": &"ember_station_return_handoff",
		"destination_id": &"mudds_shipyards",
		"activity_id": &"ember_beacon_survey",
		"activity_generation": 17,
		"actor_instance_id": game.player.get_instance_id(),
		"craft_instance_id": game.active_ship.get_instance_id(),
		"session_generation": session_generation,
		"attachment_generation": attachment_generation,
		"coordinate_frame_generation": frame.get_generation(),
		"orbital_coordinate": (
			frame.get_snapshot().get(
				"world_streaming_origin_orbital_coordinate", {}
			) as Dictionary
		).duplicate(true),
		"evidence_sequence": PackedStringArray([
			"reboard", "takeoff", "ascent", "orbit",
		]),
		"arrival_confirmed": false,
		"authority": {
			"movement": false,
			"teleport": false,
			"origin": false,
			"landing": false,
			"boarding": false,
			"berth": false,
			"reward": false,
			"arrival": false,
		}.duplicate(true),
	}.duplicate(true)


func _check_surface_detach_refusals() -> void:
	var binding := EmberSurfaceLoopProductionBinding.new()
	var composition := ReturnComposition.new()
	var relay := ReturnRelay.new()
	relay.set("_configured", true)
	relay.set("_attached", true)
	binding.set("_planetary_composition", composition)
	binding.set("_staging_relay_proximity", relay)
	composition.reject_detach = true
	var composition_refusal := binding.detach_planetary_surface()
	_check(not bool(composition_refusal.get("accepted", true))
		and composition_refusal.get("reason") == &"composition_not_bound"
		and relay.detach_calls == 0 and composition.attached,
		"strict composition detach refusal leaves the attached relay untouched")
	composition.reject_detach = false
	# A relay still claiming attachment must retain its real configure fence.
	relay.set("_configured", false)
	var relay_refusal := binding.detach_planetary_surface()
	_check(not bool(relay_refusal.get("accepted", true))
		and relay_refusal.get("reason") == &"staging_relay_not_attached"
		and relay.detach_calls == 1 and bool(relay.get_snapshot().get("attached", false))
		and binding.get("_planetary_composition") == composition,
		"a genuinely attached relay detach refusal still rejects ownership cleanup")
	relay.free()
	composition.free()
	binding.free()


func _check_terminal_retirement(
		game: GameFlow, craft: HeroShip, handback: Dictionary, adapter: Object
	) -> void:
	for already_detached: bool in [true, false]:
		var binding := EmberSurfaceLoopProductionBinding.new()
		var composition := ReturnComposition.new()
		var relay := ReturnRelay.new()
		game.add_child(composition)
		game.add_child(relay)
		composition.host_instance_id = game.ember_surface_loop_host.get_instance_id()
		relay.set("_configured", true)
		relay.set("_attached", true)
		binding.set("_state", EmberSurfaceLoopProductionBinding.State.HANDOFF_PENDING)
		binding.set("_generation", 9)
		binding.set("_host", game.ember_surface_loop_host)
		binding.set("_ship", craft)
		binding.set("_player", game.player)
		binding.set("_ship_instance_id", craft.get_instance_id())
		binding.set("_player_instance_id", game.player.get_instance_id())
		binding.set("_completion_handback", handback.duplicate(true))
		binding.set("_completion_handback_delivered", true)
		binding.set("_planetary_composition", composition)
		binding.set("_staging_relay_proximity", relay)
		binding.set("_return_berth_adapter", adapter)
		if already_detached:
			composition.detach()
		var prior_detach_calls := composition.detach_calls
		var forged := handback.duplicate(true)
		forged["player_instance_id"] = game.player.get_instance_id() + 1
		binding.set("_completion_handback", forged)
		var forged_retirement := binding.retire_completed_planetary_return()
		_check(not bool(forged_retirement.get("accepted", true))
			and forged_retirement.get("reason") == &"runtime_ownership_return_actor_mismatch"
			and composition.detach_calls == prior_detach_calls and relay.detach_calls == 0,
			"terminal retirement rejects a forged handback before bound or detached component cleanup")
		binding.set("_completion_handback", handback.duplicate(true))
		if already_detached:
			var host := game.ember_surface_loop_host
			var host_parent := host.get_parent()
			host_parent.remove_child(host)
			var removed_host := binding.retire_completed_planetary_return()
			host_parent.add_child(host)
			_check(not bool(removed_host.get("accepted", true))
				and removed_host.get("reason") == &"runtime_ownership_return_owner_not_current"
				and composition.detach_calls == 1 and relay.detach_calls == 0
				and binding.get("_planetary_composition") == composition,
				"a removed host retaining its completed handback cannot retire composition or relay")
			composition.host_generation += 1
			var stale := binding.retire_completed_planetary_return()
			_check(not bool(stale.get("accepted", true))
				and stale.get("reason") == &"planetary_station_return_composition_mismatch"
				and composition.detach_calls == 1 and relay.detach_calls == 0,
				"terminal retirement refuses a detached composition from another host generation")
			composition.host_generation -= 1
			relay.set("_configured", false)
			var relay_refusal := binding.retire_completed_planetary_return()
			_check(not bool(relay_refusal.get("accepted", true))
				and relay_refusal.get("reason") == &"staging_relay_not_attached"
				and relay.detach_calls == 1 and composition.detach_calls == 1
				and binding.get("_planetary_composition") == composition,
				"a detached surface cannot hide refusal by a relay still claiming attachment")
			relay.set("_configured", true)
		var prior_relay_calls := relay.detach_calls
		var retired := binding.retire_completed_planetary_return()
		var replay := binding.retire_completed_planetary_return()
		_check(bool(retired.get("accepted", false))
			and not bool(replay.get("accepted", true))
			and replay.get("reason") == &"planetary_composition_unavailable"
			and composition.detach_calls == 1 and not composition.attached
			and relay.detach_calls == prior_relay_calls + 1
			and not bool(relay.get_snapshot().get("attached", true))
			and binding.get("_planetary_composition") == null
			and binding.get("_staging_relay_proximity") == null,
			"exact completed home handback retires bound or detached composition and attached relay once, then refuses replay")
		binding.free()


func _check_return_detach_diagnostic(game: GameFlow, craft: HeroShip, berth: ShipBerth, token: StringName) -> void:
	# Use the actual occupied lease and seated actors, with an isolated consumer
	# so this refused cleanup cannot alter the successful home lifecycle above.
	var flow := GameFlow.new()
	flow.phase = GameFlow.Phase.RETURN_TO_YARD
	var binding := EmberSurfaceLoopProductionBinding.new()
	binding.set("_generation", 9)
	var composition := ReturnComposition.new()
	composition.reject_detach = true
	binding.set("_planetary_composition", composition)
	var refused: Dictionary = flow.consume_planetary_return_receipt({
		"accepted": true, "reason": &"returned_to_station",
		"contract_receipt": {"accepted": true},
		"berth_receipt": {
			"accepted": true, "reason": &"return_berth_occupied",
			"craft_instance_id": craft.get_instance_id(),
			"actor_instance_id": game.player.get_instance_id(),
			"session_generation": 9, "attachment_generation": 4,
			"token": token,
		},
	}, binding, berth, craft, game.player)
	var nested := refused.get("detach_result", {}) as Dictionary
	composition.last_detach_result["reason"] = &"producer_mutated_after_refusal"
	(composition.last_detach_result.get("runtime", {}) as Dictionary)["state"] = &"producer_mutated"
	_check(not bool(refused.get("accepted", true))
		and refused.get("reason") == &"planetary_return_attachment_detach_rejected"
		and nested.get("reason") == &"composition_not_bound"
		and (nested.get("runtime", {}) as Dictionary).get("state") == &"bound"
		and flow.phase == GameFlow.Phase.RETURN_TO_YARD
		and not bool(flow.get("_planetary_return_receipt_consumed"))
		and composition.attached and composition.detach_calls == 1
		and berth.get_occupant() == craft and berth.has_valid_lease(craft, token, craft.get_ship_id()),
		"home detach rejection preserves its concrete copied reason and snapshot without consuming the receipt or changing the lease")
	composition.free()
	binding.free()
	flow.free()


func _commit_origin_translation(game: GameFlow, craft: HeroShip, focus: Vector3) -> Dictionary:
	craft.global_position = focus
	var sample := {
		"available": true,
		"position": craft.global_position,
		"actor_kind": &"ship",
		"actor_instance_id": craft.get_instance_id(),
	}
	var tick := game.ember_streaming_binding.physics_tick_from_caller_sample(0.0, sample)
	var preview := game.ember_streaming_binding.preview_origin_rebase(
		int(tick.get("coordinate_frame_generation", 0))
	)
	return game.common_world_origin_rebase_owner.consume_rebase_preview(preview, sample)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition and message.begins_with("RETURN_SHELL_ORIGIN_TRANSLATION_OK:"):
		print(message)
	if not condition:
		_failures.append(message)
		push_error("GAME_FLOW_PLANETARY_RETURN_APPROACH_TEST: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_FLOW_PLANETARY_RETURN_APPROACH_TEST_OK: %d assertions" % _checks)
		quit(0)
		return
	print("GAME_FLOW_PLANETARY_RETURN_APPROACH_TEST_FAILED: %d/%d" % [
		_failures.size(), _checks,
	])
	quit(1)
