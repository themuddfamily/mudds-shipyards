extends SceneTree

## Adversarial integration coverage for authority-sensitive fleet lifecycle
## edges. These checks intentionally exercise production GameFlow rather than
## isolated mocks: one pilot, two persistent craft, exclusive physical berths,
## mission-owned range contacts, and delayed same-world regeneration.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_engine_and_departure_authority()
	await _test_pre_guide_torrent_fire_is_phase_locked()
	await _test_inactive_loss_and_occupied_berth_retry()
	_finish()


func _test_engine_and_departure_authority() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "control-authority production scene instantiates")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	var player := game.get_node("Player") as PlayerController
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var arrow := game.get_node("ArrowReconShip") as HeroShip
	var berth := world.get_berth_node(arrow.get_home_berth_id())
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.disembarking_motion_time = 0.02
	game.start_shift()
	await process_frame

	# Use the real boarding coroutine so the transition guard is exercised at
	# the same authority handoff as live play. A hostile engine event injected
	# while the canopy/seat transition is busy must have no effect.
	game.call("_board_ship", arrow)
	_check(
		game.phase == GameFlow.Phase.BOARDING and bool(game.get("_transition_busy")),
		"Arrow boarding enters an atomic transition before pilot authority transfers"
	)
	_dispatch_pilot_action(game, &"engine_start")
	await physics_frame
	_check(
		str(arrow.get_telemetry().get("engine_state", &"")).to_upper() == "OFFLINE",
		"engine-start input is ignored during the live boarding transition"
	)
	_check(await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.5), "Arrow boarding reaches engine startup")
	_check(player.is_seated() and arrow.is_piloted(), "boarding transfers the same physical pilot into Arrow")

	# Also inject the event with pilot authority active but the atomic guard set;
	# this catches future input routing that might only happen after seating.
	game.set("_transition_busy", true)
	_dispatch_pilot_action(game, &"engine_start")
	await physics_frame
	_check(
		str(arrow.get_telemetry().get("engine_state", &"")).to_upper() == "OFFLINE",
		"transition guard rejects engine startup even after pilot authority exists"
	)
	game.set("_transition_busy", false)

	_check(
		berth != null
		and berth.get_occupant() == arrow
		and berth.get_reservation_owner() == arrow,
		"parked Arrow begins with one occupied authoritative berth lease"
	)
	arrow.engine_start_time = 0.02
	_dispatch_pilot_action(game, &"engine_start")
	_check(await _wait_for_engine_state(arrow, "ONLINE", 0.3), "authorized engine startup reaches ONLINE")
	await process_frame
	_check(game.phase == GameFlow.Phase.FREE_FLIGHT, "pre-guide Arrow startup enters its free sortie")
	_check(
		bool(arrow.get_telemetry().get("landed", false))
		and berth.get_occupant() == arrow
		and berth.get_reservation_owner() == arrow,
		"engine startup alone retains the parked craft's occupied berth"
	)

	# A landing request while still parked is adversarial but legal input. It
	# must not turn initial `landed == true` into a completed return or release the
	# lease before the ship has physically departed.
	_dispatch_pilot_action(game, &"landing_assist")
	await physics_frame
	await process_frame
	_check(game.phase == GameFlow.Phase.FREE_FLIGHT, "parked landing input cannot auto-complete a free sortie")
	_check(
		berth.get_occupant() == arrow and berth.get_reservation_owner() == arrow,
		"rejected parked landing input preserves the original berth lease"
	)

	var departure_origin := arrow.global_position
	Input.action_press(&"move_forward")
	for _step in 24:
		await physics_frame
		await process_frame
		if not bool(arrow.get_telemetry().get("landed", true)):
			break
	# The landed flag is the authoritative departure edge; allow several more
	# simulation ticks before separately asserting visible displacement.
	for _departure_settle in 4:
		await physics_frame
	Input.action_release(&"move_forward")
	await physics_frame
	await process_frame
	_check(not bool(arrow.get_telemetry().get("landed", true)), "authoritative thrust clears Arrow's landed state")
	_check(arrow.global_position.distance_to(departure_origin) > 0.01, "Arrow physically moves away from its parked transform")
	_check(
		berth.get_occupant() == null and berth.get_reservation_owner() == null,
		"berth lease releases only after authoritative physical departure"
	)

	# Complete one real return, shut the engine down, then inject a restart event
	# while GameFlow owns SHUT_DOWN. That phase must be a one-way safety gate until
	# the pilot exits rather than an accidental relaunch path.
	var berth_transform := world.get_berth_transform(arrow.get_home_berth_id())
	arrow.global_transform = berth_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	arrow.velocity = Vector3.ZERO
	await physics_frame
	_dispatch_pilot_action(game, &"landing_assist")
	_check(await _wait_for_phase(game, GameFlow.Phase.SHUT_DOWN, 3.0), "Arrow return reaches authoritative SHUT_DOWN")
	_dispatch_pilot_action(game, &"engine_stop")
	await physics_frame
	_check(
		str(arrow.get_telemetry().get("engine_state", &"")).to_upper() == "OFFLINE",
		"returned Arrow shuts down before the restart probe"
	)
	_dispatch_pilot_action(game, &"engine_start")
	await physics_frame
	await process_frame
	_check(
		game.phase == GameFlow.Phase.SHUT_DOWN
		and str(arrow.get_telemetry().get("engine_state", &"")).to_upper() == "OFFLINE",
		"engine-start input is ignored after docking reaches SHUT_DOWN"
	)
	_check(berth.get_occupant() == arrow, "SHUT_DOWN restart rejection preserves physical berth occupancy")

	await _clean_up(game)


func _test_pre_guide_torrent_fire_is_phase_locked() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "range-authority production scene instantiates")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	var arrow := game.get_node("ArrowReconShip") as HeroShip
	var targets := _get_live_range_targets(world)
	_check(not targets.is_empty(), "guided range exposes at least one authoritative target")
	if targets.is_empty():
		await _clean_up(game)
		return

	game.start_shift()
	await process_frame
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "guided test is pending before the hostile fire probe")
	game.active_ship = torrent
	var target := targets[0]
	var arena_origin := Vector3(240.0, 80.0, -260.0)
	torrent.global_transform = Transform3D(Basis.IDENTITY, arena_origin)
	arrow.global_position = arena_origin + Vector3(80.0, 0.0, 0.0)
	target.global_position = arena_origin + Vector3(0.0, 0.0, -30.0)
	target.set_meta("base_position", (target.get_parent() as Node3D).to_local(target.global_position))
	await physics_frame

	var health_before := float(target.get_meta("health", -1.0))
	var destroyed_before := world.get_destroyed_target_count()
	var progress_before := game.destroyed_targets
	var target_count_before := world.get_target_count()
	var shot_origin := torrent.global_position + Vector3(0.0, 0.5, -5.0)
	var any_authoritative_damage := false
	for _shot in 4:
		var shot_direction := (target.global_position - shot_origin).normalized()
		game.call("_on_projectile_fired", shot_origin, shot_direction, torrent)
		var result := game.get_last_player_shot_result()
		any_authoritative_damage = any_authoritative_damage \
			or bool(result.get("damaged", false)) \
			or bool(result.get("destroyed", false))
		await physics_frame

	_check(
		not any_authoritative_damage,
		"pre-guide Torrent shots outside LAUNCH/TARGET_PRACTICE receive no damage authority"
	)
	_check(
		not bool(target.get_meta("destroyed", false))
		and is_equal_approx(float(target.get_meta("health", -2.0)), health_before),
		"phase-locked Torrent fire preserves the range target's canonical health"
	)
	_check(
		world.get_destroyed_target_count() == destroyed_before
		and world.get_target_count() == target_count_before,
		"phase-locked Torrent fire cannot consume a physical guided range contact"
	)
	_check(game.destroyed_targets == progress_before, "phase-locked Torrent fire cannot mutate guided mission progress")
	_check(not game.is_guided_activity_complete(), "rejected pre-guide fire leaves the guided activity pending")

	await _clean_up(game)


func _test_inactive_loss_and_occupied_berth_retry() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "regeneration-authority production scene instantiates")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	var player := game.get_node("Player") as PlayerController
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	var arrow := game.get_node("ArrowReconShip") as HeroShip
	var arrow_berth := world.get_berth_node(arrow.get_home_berth_id())
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.start_shift()
	await process_frame
	game.call("_board_ship", torrent)
	_check(await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.5), "Torrent pilot is established before inactive-craft loss")
	_check(game.get_active_ship() == torrent and player.is_seated() and torrent.is_piloted(), "Torrent owns the live pilot and mission authority")

	var preserved_phase := game.phase
	var preserved_player_id := player.get_instance_id()
	var arrow_spawn := world.get_berth_transform(arrow.get_home_berth_id())
	arrow.apply_damage(arrow.maximum_hull + 1.0, arrow.global_position, Vector3.UP)
	await process_frame
	_check(arrow.is_destroyed(), "lethal parked damage destroys the inactive Arrow")
	_check(
		game.get_active_ship() == torrent
		and game.phase == preserved_phase
		and player.get_instance_id() == preserved_player_id
		and player.is_seated()
		and torrent.is_piloted(),
		"inactive fleet loss does not steal the active mission or pilot lifecycle"
	)
	_check(
		arrow_berth.get_occupant() == null and arrow_berth.get_reservation_owner() == null,
		"inactive destroyed craft immediately releases its stale berth lease"
	)

	# Claim the now-clear Arrow berth with a compatible stand-in before the four-
	# second replenishment window expires. A safe retry keeps Arrow destroyed and
	# collisionless instead of resetting it on top of the new occupant.
	var temporary_occupant := Node3D.new()
	temporary_occupant.name = "AdversarialBerthOccupant"
	game.add_child(temporary_occupant)
	var temporary_token := arrow_berth.try_reserve(temporary_occupant, arrow.get_ship_definition())
	_check(not temporary_token.is_empty(), "compatible stand-in can reserve the released Arrow berth")
	_check(
		not temporary_token.is_empty() and arrow_berth.occupy(temporary_occupant, temporary_token),
		"stand-in physically occupies Arrow's home berth during regeneration"
	)
	await create_timer(4.25).timeout
	await physics_frame
	_check(
		arrow.is_destroyed() and arrow.collision_layer == 0,
		"regeneration defers while the home berth is occupied"
	)
	_check(
		arrow_berth.get_occupant() == temporary_occupant
		and arrow_berth.get_reservation_owner() == temporary_occupant,
		"deferred regeneration cannot replace or overlap the berth's live occupant"
	)
	_check(
		game.get_active_ship() == torrent
		and game.phase == preserved_phase
		and player.is_seated()
		and torrent.is_piloted(),
		"deferred inactive regeneration leaves the active Torrent lifecycle untouched"
	)

	_check(
		arrow_berth.release(temporary_occupant, temporary_token),
		"test occupant can release its authoritative berth lease"
	)
	var regenerated := await _wait_for_ship_regeneration(arrow, 8.5)
	_check(regenerated, "inactive Arrow regenerates after its home berth becomes available")
	_check(
		regenerated
		and arrow.global_transform.is_equal_approx(arrow_spawn)
		and arrow.is_boardable(),
		"regenerated Arrow returns as a reusable craft at its exact home transform"
	)
	_check(
		regenerated
		and arrow_berth.get_occupant() == arrow
		and arrow_berth.get_reservation_owner() == arrow,
		"successful retry atomically restores Arrow's occupied berth lease"
	)
	_check(
		game.get_active_ship() == torrent
		and game.phase == preserved_phase
		and player.get_instance_id() == preserved_player_id
		and player.is_seated()
		and torrent.is_piloted(),
		"completed inactive regeneration preserves the original mission and pilot"
	)

	await _clean_up(game)


func _get_live_range_targets(world: Node) -> Array[StaticBody3D]:
	var targets: Array[StaticBody3D] = []
	for candidate in world.find_children("*", "StaticBody3D", true, false):
		if candidate.get_meta("is_shipyard_target", false):
			targets.append(candidate as StaticBody3D)
	return targets


func _dispatch_pilot_action(game: GameFlow, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func _wait_for_phase(game: GameFlow, expected_phase: GameFlow.Phase, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if game.phase == expected_phase:
			return true
		await physics_frame
		elapsed += 1.0 / 60.0
	return game.phase == expected_phase


func _wait_for_engine_state(ship: HeroShip, expected_state: String, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if str(ship.get_telemetry().get("engine_state", &"")).to_upper() == expected_state:
			return true
		await physics_frame
		elapsed += 1.0 / 60.0
	return str(ship.get_telemetry().get("engine_state", &"")).to_upper() == expected_state


func _wait_for_ship_regeneration(ship: HeroShip, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if not ship.is_destroyed():
			return true
		await physics_frame
		elapsed += 1.0 / 60.0
	return not ship.is_destroyed()


func _clean_up(game: Node) -> void:
	for action in [&"move_forward", &"engine_start", &"engine_stop", &"landing_assist"]:
		Input.action_release(action)
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_LIFECYCLE_SAFETY_TEST_OK")
		quit(0)
	else:
		print("FLEET_LIFECYCLE_SAFETY_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
