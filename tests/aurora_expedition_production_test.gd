extends SceneTree
const MAIN := preload("res://scenes/main.tscn")
const ARROW := preload("res://scenes/ships/arrow_recon_ship.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
const EXPEDITION := preload("res://scripts/game/aurora_expedition.gd")
const SUCCESS_MARKER := "AURORA_EXPEDITION_PRODUCTION_TEST_OK"
var _failures: Array[String] = []
var _assertions := 0
var _outbound_fixture_ready := false
var _full_flight := false
var _travel_distance_m := 0.0
var _travel_rebases := 0
var _travel_max_step := 0.0

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	_full_flight = "--aurora-full-flight" in OS.get_cmdline_user_args()
	await _test_arrow_access_forwarding()
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	await process_frame
	var craft := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.01
	game.player.teleport_to(Transform3D(craft.global_basis, craft.get_boarding_position() + craft.global_basis.y * 0.01))
	for i in range(6):
		await physics_frame
		await process_frame
	await _press_interact()
	for i in range(240):
		await physics_frame
		if game._piloting:
			break
	_check(game._piloting and game.player.is_seated() and game.active_ship == craft, "ordinary boarding takes the Halyard pilot seat")
	var home_position := craft.global_position
	var owner = game.get("_aurora_expedition")
	game.call(&"_sync_planetary_cruise_hud")
	await _prepare_bounded_outbound(game)
	var row := _row(game)
	_check(bool(row.get("route_available", false)) and bool(row.get("action_enabled", false)), "Aurora is a selectable production destination: %s" % row.get("status_text"))
	if not bool(row.get("action_enabled", false)):
		await _finish(game)
		return
	await _press_destination(game)
	_check(owner.state == &"outbound" and not paused, "the visible Destination Board action starts the production cruise and resumes play")
	if not _full_flight:
		await _check_cancel_lifecycle_ownership(game, craft, owner)
	await _wait_state(owner, &"landed", 48_000 if _full_flight else 6500)
	_check(owner.state == &"landed", "physical landing completes at Aurora (state %s)" % owner.state)
	if owner.state != &"landed":
		await _finish(game)
		return
	var berth := owner.get("_berth") as ShipBerth
	var surface := owner.get("_surface") as Node3D
	_check(craft.global_position.distance_to(game.world.global_position) > 10000000.0 and berth.get_occupant() == craft and bool(craft.get_telemetry().get("landed", false)), "the same Halyard occupies the real Aurora surface berth")
	_check(surface.get_node_or_null("LandingRegion/CoastalExploration/CoastalLookoutSign") != null, "the visited world contains explorable lookout and standing stones")
	_check(int(owner.get_visit_snapshot().get("staging_events", -1)) == 0,
		"outbound expedition makes zero actor placements")
	_check(is_equal_approx(float(craft.get_telemetry().get("hull", 0)), float(craft.get_telemetry().get("maximum_hull", -1))),
		"physical arrival preserves full hull health")
	if _full_flight:
		_check(_travel_distance_m > 11_800_000.0 and _travel_rebases > 1100,
			"unstaged outbound physically crosses twelve million metres and over1100 rebases")
		print("AURORA_FULL_OUTBOUND distance=", _travel_distance_m, " rebases=", _travel_rebases, " max_step=", _travel_max_step, " hull=", craft.get_telemetry().get("hull"))
		await _finish(game)
		return
	await _press_interact()
	await _wait_state(owner, &"surface", 240)
	for i in range(30):
		await physics_frame
	_check(owner.state == &"surface" and not game.player.is_seated() and game.player.is_control_enabled() and game.player.is_on_floor(), "exit restores ordinary walking and physical surface support")
	_check(not bool(_row(game).get("action_enabled", true)), "return action asks the on-foot explorer to board first")
	# From the planet apron, walk through the actual hatch and aft to the berth.
	_check(await _walk_to_local(game.player, craft, Vector3(-3.1, 0.0, craft.AIRSTAIR_Z)), "walk from Aurora surface to the Halyard stair")
	_check(await _walk_to_local(game.player, craft, Vector3(-1.35, 0.52, craft.AIRSTAIR_Z)), "walk through the open physical hatch")
	_check(await _walk_to_local(game.player, craft, Vector3(0.0, 0.52, craft.AIRSTAIR_Z)), "enter the cabin aisle")
	_check(await _walk_to_local(game.player, craft, Vector3(-0.45, 0.52, 6.6)), "walk aft to the liveaboard bunk")
	var bunk := craft.get_node("WalkableInterior/AftSystemsBay/PortSleepingBerth/ShipBunkInteraction") as ShipBunk
	_look_toward(game.player, bunk.global_position)
	for i in range(4):
		await physics_frame
		await process_frame
	_check(game.station_interaction_candidate == bunk, "the physical bunk is the interaction target on Aurora")
	await _press_interact()
	for i in range(120):
		await physics_frame
		await process_frame
		if game.player.is_sleeping():
			break
	_check(game.player.is_sleeping() and game._station_seated and owner.state == &"surface", "E sleeps aboard the Halyard while visiting Aurora")
	await _press_interact()
	for i in range(120):
		await physics_frame
		await process_frame
		if not game._station_seated and game.player.is_control_enabled() and game.player.is_on_floor():
			break
	_check(not game.player.is_sleeping() and game.player.is_control_enabled() and game.player.is_on_floor(), "E wakes onto the cabin floor with usable controls")
	_check(await _walk_to_local(game.player, craft, Vector3(0.0, 0.52, craft.AIRSTAIR_Z)), "walk back from the bed to the hatch aisle")
	_check(await _walk_to_local(game.player, craft, Vector3(-1.35, 0.52, craft.AIRSTAIR_Z)), "approach the inside hatch")
	_check(await _walk_to_local(game.player, craft, craft.to_local(craft.get_boarding_position())), "walk down the airstair onto Aurora again")
	var exit_position := game.player.global_position
	_check(await _walk_to_local(game.player, craft, craft.to_local(exit_position) + Vector3(-3.0, 0.0, 0.0)), "explore the collidable ground beyond the ramp")
	_check(game.player.global_position.distance_to(exit_position) > 1.0, "the explorer physically leaves the ramp")
	_check(await _walk_to_local(game.player, craft, craft.to_local(craft.get_boarding_position())), "walk back to the same ship for return")
	await _press_interact()
	await _wait_state(owner, &"landed", 240)
	_check(game.player.is_seated() and game._piloting and game.active_ship == craft, "E reboards the same physical craft")
	var return_pose := craft.global_transform
	var return_berth := owner.get("_berth") as ShipBerth
	await _press_destination(game)
	for tick in 20:
		await physics_frame
		await process_frame
	_check(owner.state == &"return_cruise" and game._planetary_journey.is_return_departure_pending()
		and craft.global_transform == return_pose and return_berth.get_occupant() == craft,
		"return queues manual departure at the occupied surface berth without actor placement")
	# Full physical home cruise, registered docking, exit and walking live in the
	# explicit Aurora return soak; this bounded visit checks cancel/retry access.
	owner.cancel()
	_check(owner.state == &"idle" and game.player.is_seated() and game._piloting
		and craft.global_transform == return_pose and game.world.visible,
		"canceling queued return releases control at the current surface pose")
	game.call(&"_sync_planetary_cruise_hud")
	await _press_destination(game)
	_check(owner.state == &"outbound", "a further bounded visit is selectable after physical departure")
	# The same production entry point the board row calls, taken while the
	# approach is still outbound: a pilot may give up on a cruise in flight.
	Input.action_press(&"move_right")
	for i in 6:
		await physics_frame
		await process_frame
	_check(craft.has_manual_flight_intent() and not bool(game.planetary_cruise_binding.get_snapshot().get("engagement_requested", true)),
		"held manual input retains control instead of automatic transit retry")
	var cancel_pose := craft.global_transform
	var cancel_velocity := craft.velocity
	_check(
		bool(owner.runtime_state().get("action_enabled", false)) and owner.request(),
		"an outbound cruise can be abandoned from the same production control"
	)
	_check(owner.state == &"idle" and craft.global_transform == cancel_pose
		and craft.velocity == cancel_velocity and game.player.is_seated()
		and craft.is_piloted() and game.phase == GameFlow.Phase.FREE_FLIGHT,
		"abandoning outbound releases autopilot at the current pose with pilot control retained")
	Input.action_release(&"move_right")
	for i in 4:
		await physics_frame
		await process_frame
	_check(not bool(game.planetary_cruise_binding.get_snapshot().get("engagement_requested", true)),
		"explicit cancellation stays final after manual input is released")
	# Interrupt a live on-foot visit, then interrupt a second visit halfway
	# through its embodiment transition. Both recover usable controls and leases.
	for interrupted_state: StringName in [&"surface", &"disembarking"]:
		if not game._piloting:
			for i in range(300):
				await physics_frame
				if craft.is_boardable():
					break
			game.call(&"_board_ship", craft)
			for i in range(240):
				await physics_frame
				if game._piloting:
					break
		await _press_destination(game)
		await _wait_state(owner, &"landed", 6000)
		game.call(&"_try_exit_ship")
		await _wait_state(owner, interrupted_state, 240)
		_check(owner.state == interrupted_state, "cancellation begins from live %s" % interrupted_state)
		owner.cancel()
		# A cancel now hands the lane a bounded wind-down: the actors are home
		# immediately, and the production streaming coordinator commits the
		# rebase back to the yard and unloads Aurora on its own cadence.
		await _wait_state(owner, &"idle", 600)
		await _wait_landed(craft, 600)
		_check(owner.state == &"idle" and not game._piloting and not game._transition_busy and not game.player.is_seated() and game.player.is_control_enabled() and game.player.get_camera().current and game.player.global_position.distance_to(game.world.get_player_spawn().origin) < 400.0, "%s cancellation restores a controllable on-foot explorer at Mudds" % interrupted_state)
		_check((craft.get_node("ShipBoardingArea") as ShipBoardingArea).get_reservation_token() == null and bool(craft.get_telemetry().get("landed", false)), "%s cancellation releases the seat and physically restores home docking" % interrupted_state)
	await _finish(game)

## Exercise the actual expedition handoffs with a routed craft as well as the
## full Halyard voyage below. Freeze physics to inspect each live transition
## before it completes; the production Player still consumes every descriptor.
func _test_arrow_access_forwarding() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var ship := ARROW.instantiate() as ArrowReconShip
	fixture.add_child(ship)
	ship.set_physics_process(false)
	var player := PLAYER.instantiate() as PlayerController
	fixture.add_child(player)
	player.set_physics_process(false)
	player.set_control_enabled(false)
	var flow := GameFlow.new()
	flow.player = player
	var owner := EXPEDITION.new(flow)
	owner.set("_ship", ship)
	owner.state = &"landed"
	player.begin_boarding(ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(), 0.0, ship)
	await player.boarding_completed
	owner.request_exit()
	await _wait_state(owner, &"disembarking", 240)
	_check_forwarded_access_route(player, ship, ship.get_exterior_exit_waypoints(),
		"Aurora exit forwards every Arrow waypoint in the live ship frame")
	player.call("_update_embodiment", 0.6)
	await process_frame
	_check(not player.is_seated() and player.global_transform.is_equal_approx(ship.get_exit_transform()),
		"Aurora's routed exit reaches the actual Arrow exit marker")
	owner.state = &"surface"
	flow._transition_busy = false
	player.global_position += ship.global_basis.z * -0.5
	var expected := ship.get_exterior_boarding_waypoints(player.global_position)
	owner.call("_begin_boarding")
	await _wait_state(owner, &"boarding", 240)
	_check_forwarded_access_route(player, ship, expected,
		"Aurora reboarding forwards the Arrow route from the current player position")
	player.call("_update_embodiment", 0.7)
	await process_frame
	_check(player.is_seated(), "Aurora's routed boarding reaches the live Arrow seat")
	owner.set("_ship", null)
	flow.free()
	fixture.queue_free()
	await process_frame


func _check_forwarded_access_route(player: PlayerController, ship: HeroShip,
		expected: Array[Transform3D], description: String) -> void:
	var captured: Array = player.get("_transition_waypoints")
	var matches := not expected.is_empty() and captured.size() == expected.size()
	for index in mini(captured.size(), expected.size()):
		matches = matches and (captured[index] as Transform3D).is_equal_approx(expected[index])
	_check(matches and player.get("_transition_frame") == ship, description)


func _row(game: GameFlow) -> Dictionary:
	for row: Dictionary in game.get_planetary_destination_catalog_snapshot().get("destinations", []):
		if row.get("destination_id") == &"aurora_temperate_world":
			return row
	return {}

func _check_cancel_lifecycle_ownership(game: GameFlow, craft: HeroShip, owner: RefCounted) -> void:
	var pose := craft.global_transform
	var velocity := craft.velocity
	var prior_phase := game.phase
	var prior_landing := game._landing_request_active
	var prior_berth := game._active_landing_berth_id
	game._recovering = true
	game.phase = GameFlow.Phase.FAILED
	game._landing_request_active = true
	game._active_landing_berth_id = &"recovery_owner"
	owner.cancel()
	_check(game.phase == GameFlow.Phase.FAILED and game._landing_request_active
		and game._active_landing_berth_id == &"recovery_owner"
		and craft.global_transform == pose and craft.velocity == velocity,
		"outbound cancellation preserves recovery-owned lifecycle and actor pose")
	game._recovering = false
	game.phase = prior_phase
	game._landing_request_active = prior_landing
	game._active_landing_berth_id = prior_berth
	for i in 6:
		await physics_frame
		await process_frame
	_check(owner.request(), "fresh request after recovery-fence fixture reopens travel")
	pose = craft.global_transform
	velocity = craft.velocity
	game.active_ship = game.ship
	game.phase = GameFlow.Phase.SHUT_DOWN
	game._landing_request_active = true
	game._active_landing_berth_id = &"replacement_owner"
	owner.physics_tick(1.0 / 60.0)
	_check(owner.state == &"idle" and game.active_ship == game.ship
		and game.phase == GameFlow.Phase.SHUT_DOWN and game._landing_request_active
		and game._active_landing_berth_id == &"replacement_owner"
		and craft.global_transform == pose and craft.velocity == velocity,
		"stale voyage cancellation preserves the replacement craft's lifecycle")
	game.active_ship = craft
	game.phase = prior_phase
	game._landing_request_active = prior_landing
	game._active_landing_berth_id = prior_berth
	for i in 6:
		await physics_frame
		await process_frame
	_check(owner.request(), "fresh request after replacement-fence fixture reopens travel")


## Explicit bounded-test setup. Real boarding/departure precede this distance
## placement; production expedition movement begins only after it. Full 12 Mm
## travel is qualified separately and is never inferred from this fixture.
func _prepare_bounded_outbound(game: GameFlow) -> void:
	var owner: RefCounted = game.get("_aurora_expedition")
	if owner.is_active() or _outbound_fixture_ready:
		return
	var craft := game.active_ship as HeroShip
	if bool(craft.get_telemetry().get("landed", true)):
		_check(not bool(owner.runtime_state().get("action_enabled", true)),
			"parked Aurora action asks the pilot to physically depart first")
		Input.action_press(&"hover")
		Input.action_press(&"move_forward")
		# Hold controls for physics ticks, independent of render catch-up batches.
		for i in 180:
			await physics_frame
		Input.action_release(&"hover")
		Input.action_release(&"move_forward")
		for i in 4:
			await physics_frame
			await process_frame
	print("AURORA_DEPARTURE phase=", game.phase, " landed=", craft.get_telemetry().get("landed"), " departed=", game._sortie_departed_berth)
	_check(game.phase in [GameFlow.Phase.FREE_FLIGHT, GameFlow.Phase.SHUT_DOWN] and game._sortie_departed_berth and not bool(craft.get_telemetry().get("landed", true)),
		"held pilot controls physically depart the yard")
	# Isolate this arrival fixture from the unrelated automatically selected activity.
	var activity := game.cinder_race_session.get_presentation_snapshot()
	if bool(activity.get("running", false)):
		game.cinder_race_session.fail(&"arrival_fixture_activity_ended", game.cinder_race_session.get_session_generation())
	var bootstrap := game.aurora_streaming_bootstrap
	var frame := bootstrap.get_coordinate_frame_for_session()
	var encoded := frame.body_local_to_orbital_position(
		bootstrap.get_navigation_destination().get("body_local_position_meters"), frame.get_generation())
	var anchor := frame.orbital_to_world_streaming_position(
		encoded.get("coordinate"), frame.get_generation()).get("position", Vector3.INF) as Vector3
	if _full_flight:
		var departure_origin := craft.global_position
		Input.action_press(&"move_forward")
		for i in 1800:
			var climb_local := craft.global_basis.inverse() * Vector3(0.0, 0.8, -0.6)
			Input.action_release(&"pitch_up")
			Input.action_release(&"pitch_down")
			if absf(climb_local.y) > 0.01:
				Input.action_press(&"pitch_up" if climb_local.y > 0.0 else &"pitch_down", minf(absf(climb_local.y) * 2.0, 1.0))
			await physics_frame
			await process_frame
			if craft.global_position.distance_to(departure_origin) > 500.0:
				break
		Input.action_release(&"move_forward")
		Input.action_release(&"pitch_up")
		Input.action_release(&"pitch_down")
		_check(craft.global_position.distance_to(departure_origin) > 500.0,
			"pilot flies clear of the shipyard before turning toward Aurora")
		# Real pilot controls align the yard-departed craft toward Aurora at +X.
		var aligned := false
		for i in 900:
			var direction := (anchor - craft.global_position).normalized()
			var local_direction := craft.global_basis.inverse() * direction
			for action in [&"move_left", &"move_right", &"pitch_up", &"pitch_down"]:
				Input.action_release(action)
			if (-craft.global_basis.z).dot(direction) > 0.99995:
				aligned = true
				break
			Input.action_press(&"move_right" if local_direction.x > 0.0 else &"move_left", minf(absf(local_direction.x) * 2.0, 1.0))
			Input.action_press(&"pitch_up" if local_direction.y > 0.0 else &"pitch_down", minf(absf(local_direction.y) * 2.0, 1.0))
			await physics_frame
			await process_frame
		for action in [&"move_left", &"move_right", &"pitch_up", &"pitch_down"]:
			Input.action_release(action)
		for i in 4:
			await physics_frame
			await process_frame
		_check(aligned, "held pilot yaw and pitch physically align the craft toward Aurora")
		_outbound_fixture_ready = true
		return
	craft.global_transform = Transform3D(Basis.IDENTITY, anchor + Vector3.BACK * 70_000.0)
	craft.velocity = Vector3.ZERO
	craft.reset_physics_interpolation()
	for i in 2:
		await physics_frame
		await process_frame
	_outbound_fixture_ready = true
	print("AURORA_BOUNDED_FIXTURE: distance staged before request; outbound owner must make zero placements")


func _press_destination(game: GameFlow) -> void:
	await _prepare_bounded_outbound(game)
	game.call(&"_sync_planetary_cruise_hud")
	game.hud.open_planetary_destination_board()
	var button := game.hud.find_child("PlanetaryDestinationAction_aurora_temperate_world", true, false) as Button
	_check(button != null and not button.disabled, "Aurora's visible action is enabled")
	if button != null and not button.disabled:
		button.pressed.emit()
	_outbound_fixture_ready = false

func _wait_landed(craft: HeroShip, frames: int) -> void:
	for _index in range(frames):
		await physics_frame
		if bool(craft.get_telemetry().get("landed", false)):
			return


func _wait_state(owner: RefCounted, target: StringName, frames: int) -> void:
	var game := owner.get("_flow") as GameFlow
	var craft := owner.get("_ship") as HeroShip
	var samples := {"delta": Vector3.ZERO}
	var origin: CommonWorldOriginRebaseOwner = game.common_world_origin_rebase_owner if is_instance_valid(game) else null
	var receive_rebase := func(receipt: Dictionary) -> void:
		samples.delta = (samples.delta as Vector3) + (receipt.get("world_translation_delta", Vector3.ZERO) as Vector3)
		_travel_rebases += 1
	if is_instance_valid(origin):
		origin.rebase_committed.connect(receive_rebase)
	var fault := ""
	for i in frames:
		var physical: bool = owner.state in [&"outbound", &"corridor", &"landing"] and is_instance_valid(craft) and is_instance_valid(origin)
		var previous_ship := craft.global_position if physical else Vector3.ZERO
		var previous_player := game.player.global_position if physical else Vector3.ZERO
		var previous_speed := craft.velocity.length() if physical else 0.0
		var previous_basis := craft.global_basis if physical else Basis.IDENTITY
		var previous_tick := Engine.get_physics_frames()
		samples.delta = Vector3.ZERO
		# Endpoint speed bounds apply to one physics step, not a render batch
		# that can contain both acceleration and braking around a speed peak.
		await physics_frame
		if physical:
			var elapsed := float(Engine.get_physics_frames() - previous_tick) / float(Engine.physics_ticks_per_second)
			var translation := samples.delta as Vector3
			var ship_step := craft.global_position.distance_to(previous_ship + translation)
			_travel_distance_m += ship_step
			_travel_max_step = maxf(_travel_max_step, ship_step)
			if _full_flight and i % 600 == 0:
				print("AURORA_FULL_TICK tick=", i, " state=", owner.state, " distance=", _travel_distance_m, " rebases=", _travel_rebases, " speed=", craft.velocity.length(), " cruise=", game.planetary_cruise_binding.get_snapshot().get("last_reason"))
			var motion_bound := maxf(previous_speed, craft.velocity.length()) * elapsed + 0.25
			var seat_radius := craft.get_pilot_seat_anchor().global_position.distance_to(craft.global_position)
			var rotation_allowance := Quaternion(previous_basis).angle_to(Quaternion(craft.global_basis)) * seat_radius
			if craft.global_position.distance_to(previous_ship + translation) > motion_bound \
					or game.player.global_position.distance_to(previous_player + translation) > motion_bound + rotation_allowance:
				fault = "outbound actor moved beyond physical velocity and seat rotation"
			var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
			if not craft.is_piloted() or not game.player.is_seated_at(craft.get_pilot_seat_anchor()) \
					or area.get_reservation_token() != game.player:
				fault = "outbound lost the exact seated pilot reservation"
			if not fault.is_empty():
				break
		if owner.state == target:
			break
	if is_instance_valid(origin):
		origin.rebase_committed.disconnect(receive_rebase)
	_check(fault.is_empty(), "physical arrival preserves per-tick actor continuity and exact pilot ownership: " + fault)
	if owner.state != target:
		print("WAIT ENDED: ", owner.state, " wanted ", target, " snapshot=", owner.get_visit_snapshot() if owner.has_method("get_visit_snapshot") else {})


func _press_interact() -> void:
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	await physics_frame
	await process_frame

func _look_toward(player: PlayerController, target: Vector3) -> void:
	var direction := player.global_basis.inverse() * (target - player.global_position)
	(player.get_node("CameraRig/CameraYaw") as Node3D).rotation.y = atan2(-direction.x, -direction.z)

func _walk_to_local(player: PlayerController, craft: HeroShip, target: Vector3) -> bool:
	for i in range(360):
		var local := craft.to_local(player.global_position)
		if Vector2(local.x - target.x, local.z - target.z).length() < 0.22:
			break
		_look_toward(player, craft.to_global(target))
		Input.action_press(&"move_forward")
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	for i in range(8):
		await physics_frame
		await process_frame
	var final := craft.to_local(player.global_position)
	return Vector2(final.x - target.x, final.z - target.z).length() < 0.8 and player.is_on_floor()

func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append(message)
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)

func _completion_marker() -> String:
	return SUCCESS_MARKER

func _finish(game: GameFlow) -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_forward")
	Input.action_release(&"interact")
	paused = false
	game.queue_free()
	await process_frame
	await process_frame
	var marker := _completion_marker()
	print("%s: %d assertions" % [marker if _failures.is_empty() else marker.trim_suffix("_OK") + "_FAILED", _assertions])
	quit(0 if _failures.is_empty() else 1)
