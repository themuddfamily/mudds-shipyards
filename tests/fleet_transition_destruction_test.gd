extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_loss_during_opening_canopy()
	await _test_loss_during_player_boarding()
	await _test_loss_during_disembarking_and_reuse()
	_finish()


func _test_loss_during_opening_canopy() -> void:
	var fixture := await _new_fixture(0.45, 0.45, 0.45)
	var game := fixture.game as GameFlow
	var player := fixture.player as PlayerController
	var craft := fixture.craft as HeroShip
	var targets_before := _range_state(fixture.world)
	game.call("_board_ship", craft)
	await process_frame
	_check(game.phase == GameFlow.Phase.BOARDING and not player.is_seated(), "opening-canopy probe enters BOARDING before pilot authority")
	craft.apply_damage(craft.maximum_hull + 1.0, craft.global_position, Vector3.UP)
	await _wait_seconds(0.12)
	_assert_recovered_on_foot(fixture, "opening-canopy destruction")
	_check(_range_state(fixture.world) == targets_before, "opening-canopy destruction preserves the pending guided range")
	await _wait_seconds(1.1)
	_assert_recovered_on_foot(fixture, "stale opening-canopy continuation")
	await _free_fixture(game)


func _test_loss_during_player_boarding() -> void:
	var fixture := await _new_fixture(0.02, 0.55, 0.25)
	var game := fixture.game as GameFlow
	var player := fixture.player as PlayerController
	var craft := fixture.craft as HeroShip
	game.call("_board_ship", craft)
	await _wait_seconds(0.12)
	_check(
		game.phase == GameFlow.Phase.BOARDING
		and not player.is_seated()
		and player.collision_layer == 0,
		"player-motion probe reaches collision-disabled physical BOARDING"
	)
	craft.apply_damage(craft.maximum_hull + 1.0, craft.global_position, Vector3.UP)
	await _wait_seconds(0.12)
	_assert_recovered_on_foot(fixture, "mid-boarding destruction")
	await _wait_seconds(1.1)
	_assert_recovered_on_foot(fixture, "stale player-boarding continuation")
	await _free_fixture(game)


func _test_loss_during_disembarking_and_reuse() -> void:
	var fixture := await _new_fixture(0.02, 0.03, 0.55)
	var game := fixture.game as GameFlow
	var player := fixture.player as PlayerController
	var craft := fixture.craft as HeroShip
	var world := fixture.world as ShipyardWorld
	var original_instance_id := craft.get_instance_id()
	game.call("_board_ship", craft)
	_check(await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.7), "exit-race fixture reaches the physical pilot seat")
	_check(player.is_seated() and craft.is_piloted(), "exit-race fixture owns one seated pilot and piloted craft")
	game.call("_try_exit_ship")
	await _wait_seconds(0.12)
	_check(
		game.phase == GameFlow.Phase.DISEMBARKING
		and not player.is_seated()
		and player.collision_layer == 0,
		"exit-race probe reaches collision-disabled DISEMBARKING motion"
	)
	craft.apply_damage(craft.maximum_hull + 1.0, craft.global_position, Vector3.UP)
	await _wait_seconds(0.12)
	_assert_recovered_on_foot(fixture, "mid-disembark destruction")
	await _wait_seconds(1.1)
	_assert_recovered_on_foot(fixture, "stale disembarking continuation")

	_check(await _wait_until(func() -> bool: return not craft.is_destroyed(), 5.2), "destroyed transition craft regenerates within the production bound")
	var berth := world.get_berth_node(craft.get_home_berth_id())
	_check(craft.get_instance_id() == original_instance_id and game.get_flyable_ships().size() == 4, "transition recovery reuses the same craft and preserves the four-ship fleet")
	_check(
		berth != null
		and berth.get_occupant() == craft
		and berth.get_reservation_owner() == craft,
		"regenerated transition craft owns exactly one authoritative home lease"
	)
	_check(not bool(game.get("_regeneration_pending").has(original_instance_id)), "transition regeneration clears its pending lifecycle record")
	_check(craft.is_boardable(), "regenerated transition craft is physically boardable again")
	game.call("_board_ship", craft)
	_check(await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.8), "recovered transition craft completes a later physical reboard")
	_check(player.is_seated() and craft.is_piloted(), "later reboard establishes one coherent player/craft authority pair")
	await _free_fixture(game)


func _new_fixture(canopy_time: float, boarding_time: float, disembark_time: float) -> Dictionary:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = canopy_time
	game.boarding_motion_time = boarding_time
	game.disembarking_motion_time = disembark_time
	game.start_shift()
	await process_frame
	var craft := game.get_node("TorrentInterceptor") as HeroShip
	return {
		"game": game,
		"player": game.get_node("Player") as PlayerController,
		"craft": craft,
		"world": game.get_node("ShipyardWorld") as ShipyardWorld,
	}


func _assert_recovered_on_foot(fixture: Dictionary, context: String) -> void:
	var game := fixture.game as GameFlow
	var player := fixture.player as PlayerController
	var craft := fixture.craft as HeroShip
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "%s returns to the pending-guide phase" % context)
	_check(
		player.is_control_enabled()
		and not player.is_seated()
		and player.collision_layer == PhysicsLayers.PLAYER_BODY_LAYER,
		"%s restores one collision-enabled on-foot player" % context
	)
	_check(
		not craft.is_piloted()
		and not bool(game.get("_piloting"))
		and not bool(game.get("_transition_busy"))
		and not bool(game.get("_recovering")),
		"%s leaves no stale pilot or transition authority" % context
	)
	var piloted_count := 0
	for fleet_ship in game.get_flyable_ships():
		if fleet_ship.is_piloted():
			piloted_count += 1
	_check(piloted_count == 0 and not game.is_guided_activity_complete(), "%s preserves one pending guide with no piloted fleet craft" % context)


func _range_state(world: ShipyardWorld) -> Array[int]:
	return [world.get_target_count(), world.get_destroyed_target_count()]


func _wait_for_phase(game: GameFlow, expected: GameFlow.Phase, timeout: float) -> bool:
	return await _wait_until(func() -> bool: return game.phase == expected, timeout)


func _wait_until(predicate: Callable, timeout: float) -> bool:
	var deadline_msec := Time.get_ticks_msec() + int(ceil(timeout * 1000.0))
	while Time.get_ticks_msec() < deadline_msec:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout


func _free_fixture(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	Input.action_release(&"interact")
	Input.action_release(&"engine_start")
	Input.action_release(&"engine_stop")


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_TRANSITION_DESTRUCTION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("FLEET_TRANSITION_DESTRUCTION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
