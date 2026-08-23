extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	for _index in 120:
		await process_frame
		await physics_frame
		if bool(game.get("_initialized")):
			break
	game.set("_initialized", true)
	var ship := game.active_ship as HeroShip
	var area := ship.get_node(^"ShipBoardingArea") as ShipBoardingArea
	game.player.teleport_to(area.global_transform)
	await physics_frame
	var reserved := area.try_reserve(game.player)
	var boarded: bool = game.player.begin_boarding(
		ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(),
		0.0, ship
	)
	ship.set_piloted(true)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.set_physics_process(true)
	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var begun := game.begin_ember_surface_journey(
		host, game.activity_director, Callable(self, &"_reward"), 1
	)
	var cruise := game.planetary_cruise_binding as PlanetaryCruiseProductionBinding
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := cruise.get_snapshot().get("canonical_destination_orbital", {}) as Dictionary
	var navigation_world := frame.orbital_to_world_streaming_position(
		canonical, frame.get_generation()
	).get("position", Vector3.INF) as Vector3
	ship.global_position = navigation_world + Vector3.BACK * 500.0
	ship.velocity = (navigation_world - ship.global_position).normalized() * 10.0
	for _index in 90:
		await physics_frame
		if int((cruise.get_snapshot().get("final_approach", {}) as Dictionary)
				.get("target_generation", 0)) > 0:
			break
	_check(reserved and boarded and bool(begun.get("accepted", false)),
		"production journey reserves and retains the exact seated Arrow")
	_check(
		int((cruise.get_snapshot().get("final_approach", {}) as Dictionary)
			.get("target_generation", 0)) == 1
			and game.ember_surface_loop_production_binding.get_state() \
				== EmberSurfaceLoopProductionBinding.State.IDLE,
		"loaded Host arms generation one without starting outside its envelope",
	)

	game.set_physics_process(false)
	var cancelled := game.cancel_ember_surface_journey()
	ship.velocity = Vector3.ZERO
	ship._physics_process(0.0)
	_check(
		bool(cancelled.get("accepted", false))
			and not bool(game.get("_ember_surface_journey_active"))
			and not bool(cruise.get_snapshot().get("engagement_requested", true))
			and int((cruise.get_snapshot().get("final_approach", {}) as Dictionary)
				.get("target_generation", -1)) == 0,
		"admitted non-pending cancellation disengages and clears final approach",
	)

	var loaded := game.ember_streaming_bootstrap.get_loaded_instance()
	var landing_root := loaded.get_node(^"LandingRegion") as Node3D
	var host_snapshot := host.get_snapshot()
	var envelope := (host_snapshot.get("approach_entry", {}) as Dictionary) \
		.get("envelope", {}) as Dictionary
	_check(bool(game.engage_planetary_cruise().get("accepted", false)),
		"cruise re-engages cleanly after admitted cancellation")
	var stale_arm := cruise.request_final_approach(
		host, landing_root, envelope,
		int(host_snapshot.get("coordinate_frame_generation", 0)),
		int(host_snapshot.get("location_generation", 0)),
		int(host_snapshot.get("generation", -1)),
		int(host_snapshot.get("attachment_generation", 0)) + 1,
		cruise.get_generation(),
	)
	_check(
		not bool(stale_arm.get("accepted", true))
			and stale_arm.get("reason") == &"final_approach_host_generation_mismatch",
		"stale Host attachment pair cannot arm a target",
	)
	var armed := _arm_current(cruise, host, landing_root, envelope)
	var original_attachment := host.get_attachment_generation()
	host.set("_attachment_generation", original_attachment + 1)
	var drift_tick := _binding_tick(game, cruise, host)
	host.set("_attachment_generation", original_attachment)
	ship.velocity = Vector3.ZERO
	ship._physics_process(0.0)
	_check(
		bool(armed.get("accepted", false))
			and not bool(drift_tick.get("accepted", true))
			and drift_tick.get("reason") == &"final_approach_host_generation_drift"
			and not bool(cruise.get_snapshot().get("engagement_requested", true)),
		"N to N+1 Host attachment drift aborts and releases the approach",
	)

	# Complete once under exact tokens, then change Host location before GameFlow
	# consumes it. Freshness is checked on the unconsumed receipt and stale state
	# is explicitly discarded without starting the Host.
	_check(bool(game.engage_planetary_cruise().get("accepted", false)),
		"post-drift cruise can bind a fresh controller epoch")
	_check(bool(_arm_current(cruise, host, landing_root, envelope).get("accepted", false)),
		"post-drift target arms with restored exact Host tokens")
	_check(bool(_activate_current(game, cruise, host).get("accepted", false)),
		"post-drift target activates through the existing brake-shell policy")
	ship.global_transform = landing_root.global_transform \
		* (envelope.get("corridor_transform_region_local_m") as Transform3D)
	ship.velocity = Vector3.ZERO
	var stale_completion := _binding_tick(game, cruise, host)
	var original_location := int(host.get_snapshot().get("location_generation", 0))
	host.set("_location_generation", original_location + 1)
	var stale_is_current := game._ember_final_approach_completion_is_current(
		stale_completion
	)
	var discarded := cruise.discard_final_approach_completion(
		int(stale_completion.get("target_generation", 0)),
		cruise.get_generation(), &"test_stale_completion",
	)
	host.set("_location_generation", original_location)
	_check(
		stale_completion.get("reason") == &"final_approach_handoff_ready"
			and not stale_is_current
			and bool(discarded.get("accepted", false))
			and host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE
			and game.ember_surface_loop_production_binding.get_state() \
				== EmberSurfaceLoopProductionBinding.State.IDLE,
		"completion followed by location drift is discarded before Host.start",
	)

	_check(bool(game.engage_planetary_cruise().get("accepted", false)),
		"discarded stale completion permits a fresh engagement")
	_check(bool(_arm_current(cruise, host, landing_root, envelope).get("accepted", false)),
		"final production target re-arms after explicit stale discard")
	_check(bool(_activate_current(game, cruise, host).get("accepted", false)),
		"final production target reaches FINAL_APPROACH before completion")
	ship.global_transform = landing_root.global_transform \
		* (envelope.get("corridor_transform_region_local_m") as Transform3D)
	ship.velocity = Vector3.ZERO
	var final_completion := _binding_tick(game, cruise, host)
	var consumed_final := game._consume_ember_final_approach_completion(
		final_completion
	)
	game.set("_planetary_cruise_caller_tick", int(
		cruise.get_snapshot().get("last_caller_tick", 0)
	))
	game.set("_ember_surface_journey_active", true)
	game.set_physics_process(true)
	for _index in 20:
		await physics_frame
		if host.get_phase() == EmberSurfaceLoopHost.Phase.ORBIT_APPROACH:
			break
	var production := game.ember_surface_loop_production_binding
	var production_snapshot := production.get_snapshot()
	var audio := production.get_planetary_travel_audio_snapshot()
	var completion_receipt := game.get(
		"_ember_final_approach_completion_receipt"
	) as Dictionary
	_check(
		bool(consumed_final.get("accepted", false))
			and host.get_phase() == EmberSurfaceLoopHost.Phase.ORBIT_APPROACH
			and int(production_snapshot.get("start_count", 0)) == 1
			and int(audio.get("emitted_cue_count", 0)) == 1
			and audio.get("last_cue_id") == &"planetary_orbit_approach",
		"valid receipt releases cruise then starts one ORBIT_APPROACH with one cue",
	)
	var replay := cruise.consume_final_approach_completion(
		int(completion_receipt.get("target_generation", 0)),
		cruise.get_generation(),
	)
	await physics_frame
	var after_replay := production.get_snapshot()
	var audio_after_replay := production.get_planetary_travel_audio_snapshot()
	_check(
		not bool(replay.get("accepted", true))
			and replay.get("reason") == &"final_approach_completion_replayed"
			and int(after_replay.get("start_count", 0)) == 1
			and int(audio_after_replay.get("emitted_cue_count", 0)) == 1,
		"replayed completion cannot start Host or emit its cue twice",
	)

	game.queue_free()
	await process_frame
	_finish()


func _arm_current(
		cruise: PlanetaryCruiseProductionBinding,
		host: EmberSurfaceLoopHost,
		landing_root: Node3D,
		envelope: Dictionary,
	) -> Dictionary:
	var snapshot := host.get_snapshot()
	return cruise.request_final_approach(
		host, landing_root, envelope,
		int(snapshot.get("coordinate_frame_generation", 0)),
		int(snapshot.get("location_generation", 0)),
		int(snapshot.get("generation", -1)),
		int(snapshot.get("attachment_generation", 0)),
		cruise.get_generation(),
	)


func _binding_tick(
		game: GameFlow,
		cruise: PlanetaryCruiseProductionBinding,
		host: EmberSurfaceLoopHost,
	) -> Dictionary:
	var tick := int(cruise.get_snapshot().get("last_caller_tick", 0)) + 1
	var host_snapshot := host.get_snapshot()
	return cruise.physics_tick_from_caller_sample(
		tick,
		{
			"available": true,
			"position": game.active_ship.global_position,
			"actor_kind": &"ship",
			"actor_instance_id": game.active_ship.get_instance_id(),
		},
		game.active_ship,
		int(host_snapshot.get("coordinate_frame_generation", 0)),
		false, &"",
		int(host_snapshot.get("location_generation", 0)),
	)


func _activate_current(
		game: GameFlow,
		cruise: PlanetaryCruiseProductionBinding,
		host: EmberSurfaceLoopHost,
	) -> Dictionary:
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := cruise.get_snapshot().get("canonical_destination_orbital", {}) as Dictionary
	var navigation := frame.orbital_to_world_streaming_position(
		canonical, frame.get_generation()
	).get("position", Vector3.INF) as Vector3
	game.active_ship.global_position = navigation + Vector3.BACK * 500.0
	game.active_ship.global_basis = Basis.IDENTITY
	game.active_ship.velocity = (
		navigation - game.active_ship.global_position
	).normalized() * 10.0
	return _binding_tick(game, cruise, host)


func _reward(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true}


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("EMBER_FINAL_APPROACH_PRODUCTION_HANDOFF_TEST: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_FINAL_APPROACH_PRODUCTION_HANDOFF_TEST_OK: %d assertions" % _checks)
		quit(0)
		return
	print("EMBER_FINAL_APPROACH_PRODUCTION_HANDOFF_TEST_FAILED: %d/%d" % [
		_failures.size(), _checks,
	])
	quit(1)
