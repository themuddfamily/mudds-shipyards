extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")


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

	func get_snapshot() -> Dictionary:
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
		return {"accepted": true, "reason": &"detached"}


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

	func get_snapshot() -> Dictionary:
		return {
			"state_id": &"running",
			"identities": {"location_generation": 1},
			"last_intent_serial": last_intent_serial,
			"pending_envelope": {
				"physics_frame": int(Engine.get_physics_frames()),
			} if pending else {},
			"pending_intent": {},
		}.duplicate(true)

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
	var craft := game.active_ship as HeroShip
	var area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
	game.player.teleport_to(area.global_transform)
	await physics_frame
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var cadence := CadenceSurfaceBinding.new()
	game.ember_surface_loop_production_binding = cadence
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
		bool(on_foot_tick.get("accepted", false))
			and cadence.actor_kinds == [&"player"]
			and cadence.actor_instance_ids == [game.player.get_instance_id()]
			and cadence.reboard_calls == 1,
		"the shared cadence follows the on-foot Player and routes one nearby reboard intent",
	)

	craft.set_piloted(true)
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
	game.ember_surface_loop_host.set("_generation", 9)
	game.ember_surface_loop_host.set("_attachment_generation", 4)
	game.ember_surface_loop_host.set("_coordinate_frame_generation", frame.get_generation())
	game.ember_surface_loop_host.set("_attached", true)
	game.ember_surface_loop_host.set("_phase", EmberSurfaceLoopHost.Phase.ORBIT_RETURN)
	game.ember_surface_loop_host.set("_player_instance_id", game.player.get_instance_id())
	game.ember_surface_loop_host.set("_ship_instance_id", craft.get_instance_id())
	surface.set("_host", game.ember_surface_loop_host)
	surface.set("_generation", 9)
	surface.intent = _station_return_intent(
		game, frame, 9, 4
	)
	surface.handback = {
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
	}.duplicate(true)
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
	craft.call(
		&"_complete_landing",
		home_berth,
		home_berth.get_dock_transform().basis,
	)
	var terminal_result := game.get(
		"_last_planetary_return_physical_arrival_result"
	) as Dictionary
	_check(
		bool(terminal_result.get("accepted", false))
			and terminal_result.get("reason") == &"planetary_return_consumed"
			and game.phase == GameFlow.Phase.SHUT_DOWN
			and bool(game.get("_planetary_return_receipt_consumed"))
			and not bool(game.get("_planetary_return_physical_arrival_required"))
			and not bool(game.get("_planetary_return_physical_arrival_armed"))
			and home_berth.get_occupant() == craft
			and home_berth.get_reservation_token(craft) == landing_token
			and craft.get_parent() == landing_parent_before
			and surface.detach_calls == 1,
		"real HeroShip touchdown produces one consumed physical station receipt without reparent or second lease",
	)
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
	_check(
		not bool(terminal_replay.get("accepted", true))
			and terminal_replay.get("reason") == &"planetary_return_receipt_replayed"
			and surface.detach_calls == 1,
		"the terminal station handoff cannot detach or consume twice",
	)

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

	game.ember_surface_loop_production_binding = null
	surface.free()
	game.queue_free()
	await process_frame
	_finish()


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


func _check(condition: bool, message: String) -> void:
	_checks += 1
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
