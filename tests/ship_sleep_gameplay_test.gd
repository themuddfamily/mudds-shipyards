extends "res://tests/in_flight_cabin_integration_test.gd"

## Real Halyard launch, seat exit, aisle walk, E sleep/wake and pilot return.
## Reuses the existing bounded cabin input helpers, not a second test driver.
# The cockpit-to-bunk aisle is a 15.3 m walk. `_walk_until` advances one physics
# tick per iteration when the process is not starved; under matrix load the
# engine catches up several ticks per process frame, which is the only reason the
# shared 400-iteration budget used to suffice. Size the budget for the walk.
const AISLE_TICK_BUDGET := 1500


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var player := game.get_node("Player") as PlayerController
	var craft := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	game.canopy_motion_time = 0.02
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.08
	game.start_shift()
	await _board_with_real_interaction(game, player, craft)
	_check(craft.is_piloted(), "ordinary E boards the liveaboard craft")
	await _wake_engine_with_flight_demand(craft, "flight demand starts the Halyard")
	# Climb out of the Fleet Dock corridor before flying across the yard.
	var launch_origin := craft.global_position
	Input.action_press(&"move_forward")
	Input.action_press(&"pitch_up")
	var pitched := await _wait_until(func() -> bool: return -craft.global_basis.z.y >= 0.5, 4.0)
	Input.action_release(&"pitch_up")
	var cleared := await _wait_until(func() -> bool: return craft.global_position.distance_to(launch_origin) > 120.0, 12.0)
	Input.action_release(&"move_forward")
	_check(pitched and cleared and not bool(craft.get_telemetry().get("landed", false))
		and float(craft.get_telemetry().get("hull", 0.0)) == craft.maximum_hull,
		"normal climb-out clears the Halyard's berth without hull damage")
	await _idle_engine_offline(craft, "idle propulsion allows cabin access")
	await _press_live_action(&"interact", 1)
	var left_seat := await _wait_for_phase(game, GameFlow.Phase.IN_FLIGHT_CABIN, 2.0)
	# The phase flips at the start of the seat exit; the standing pose lands only
	# when the disembark motion completes and control returns. Turning the view
	# before that lets the motion overwrite the facing and walks the wrong way.
	left_seat = left_seat and await _wait_until(
		func() -> bool: return player.is_control_enabled() and not bool(game.get("_transition_busy")), 3.0)
	_check(left_seat, "E leaves the pilot seat into the cabin")
	if not left_seat:
		print("EXIT STATE: ", game.phase, " ", craft.get_telemetry())
		await _clean_up(game)
		_finish()
		return
	# Turning the view is the only adjustment after initial boarding placement.
	player.global_basis = craft.global_basis
	player._camera_yaw.rotation.y = 0.0
	_check(await _walk_until(&"move_back", false,
		func() -> bool: return craft.to_local(player.global_position).z >= 6.45, AISLE_TICK_BUDGET),
		"ordinary locomotion walks the connected aisle from cockpit to bunks")
	var bunk := craft.get_node("WalkableInterior/AftSystemsBay/PortSleepingBerth/ShipBunkInteraction") as ShipBunk
	player.global_basis = craft.global_basis * Basis(Vector3.UP, PI / 2.0)
	player._camera_yaw.rotation.y = 0.0
	await process_frame
	await physics_frame
	await process_frame
	_check(_hud_interaction_text(game).contains("SLEEP"), "physical bunk offers the visible sleep prompt")
	var camera_mode := player.get_camera_view_mode()
	await _press_live_action(&"interact", 1)
	var sleeping := await _wait_until(func() -> bool: return player.is_sleeping(), 2.0)
	_check(sleeping, "E lies down and enters sleep")
	if not sleeping:
		print("REST STATE: ", game.phase, " local=", craft.to_local(player.global_position), " candidate=", game.station_interaction_candidate, " prompt=", _hud_interaction_text(game))
		await _clean_up(game)
		_finish()
		return
	_check(bunk.is_reserved_for(player) and not craft.is_piloted(), "sleep reserves the bunk without granting ship controls")
	_check(game._ship_rest_overlay != null and game._ship_rest_overlay.visible, "rest has a visible wake instruction")
	var start := craft.global_position
	craft.velocity = craft.global_basis.x * 3.0
	Input.action_press(&"move_forward")
	for _tick in 45:
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	_check(craft.global_position.distance_to(start) > 0.2, "the hull actually moves while the passenger rests")
	_check(player.global_position.distance_to(bunk.get_seat_anchor().global_position) < 0.03,
		"resting body follows the moving bunk and ignores locomotion")
	_check(absf(player.global_basis.y.dot(craft.global_basis.y)) < 0.01, "sleeping body lies horizontally")
	await _press_live_action(&"interact", 1)
	_check(await _wait_until(func() -> bool: return not player.is_seated() and player.is_control_enabled(), 2.0),
		"the same E control wakes into a controllable body")
	for _tick in 8:
		await physics_frame
		await process_frame
	_check(not player.is_sleeping() and not game._ship_rest_overlay.visible and bunk.is_available(), "waking clears rest presentation and frees the berth")
	_check(player.is_on_floor() and player.is_cabin_containment_active(), "waking restores floor collision inside the moving cabin")
	_check(player.get_camera_view_mode() == camera_mode, "waking preserves the chosen camera view")
	player.global_basis = craft.global_basis
	player._camera_yaw.rotation.y = 0.0
	_check(await _walk_until(&"move_forward", false,
		func() -> bool: return craft.to_local(player.global_position).z < -8.8, AISLE_TICK_BUDGET), "the rested passenger walks back to the cockpit")
	await _press_live_action(&"interact", 1)
	_check(await _wait_until(func() -> bool: return game._piloting and player.is_seated() and craft.is_piloted(), 2.0),
		"ordinary E resumes piloting after sleep")
	# Return to the cabin and exercise destructive recovery with a real sleeper.
	await _press_live_action(&"interact", 1)
	await _wait_for_phase(game, GameFlow.Phase.IN_FLIGHT_CABIN, 2.0)
	await _wait_until(
		func() -> bool: return player.is_control_enabled() and not bool(game.get("_transition_busy")), 3.0)
	player.global_basis = craft.global_basis
	player._camera_yaw.rotation.y = 0.0
	await _walk_until(&"move_back", false,
		func() -> bool: return craft.to_local(player.global_position).z >= 6.45, AISLE_TICK_BUDGET)
	player.global_basis = craft.global_basis * Basis(Vector3.UP, PI / 2.0)
	await process_frame
	await _press_live_action(&"interact", 1)
	_check(await _wait_until(func() -> bool: return player.is_sleeping(), 2.0), "the same bunk can be used again")
	craft.apply_damage(craft.maximum_hull + 1.0, craft.global_position, Vector3.UP)
	_check(await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 2.0), "losing the ship while sleeping performs regeneration recall")
	_check(not player.is_sleeping() and not game._station_seated and not game._ship_rest_overlay.visible
		and player.is_control_enabled() and not player.is_seated()
		and player.global_position.distance_to(world.get_player_spawn().origin) < 3.0,
		"ship loss leaves no sleeping overlay, reserved player or stranded body")
	await _clean_up(game)
	print("SHIP_SLEEP_GAMEPLAY: %d assertions, %d failures" % [_assertion_count, _failures.size()])
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_SLEEP_GAMEPLAY_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print("SHIP_SLEEP_GAMEPLAY_TEST_FAILED: %s" % "; ".join(_failures))
		quit(1)


func _press_live_action(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, physics_ticks):
		await physics_frame
		await process_frame
	Input.action_release(action)
	await physics_frame
	await process_frame
