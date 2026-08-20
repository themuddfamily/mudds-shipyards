extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. This is a frame count, never a wall-clock grace. See
## [method _wait_until] for why every wait in this suite is budgeted in frames.
const FRAME_BUDGET_GRACE := 30

## Nominal simulated seconds a transition probe is allowed to reach the state it
## is about to be asserted on, and the nominal seconds a destroyed craft is
## allowed to hand authority back to the on-foot player.
const PROBE_SETTLE_SECONDS := 0.12

## Nominal simulated seconds every stale canopy/boarding/disembark continuation
## queued before a destruction is given to run. The assertion after it is a
## negative one, so this settle deliberately spends its frame budget in full.
const STALE_CONTINUATION_SETTLE_SECONDS := 1.1

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_loss_during_opening_canopy()
	await _test_loss_during_player_boarding()
	await _test_loss_during_disembarking_and_reuse()
	await _test_detached_player_completion_defers_authority_handoff()
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
	_check(
		await _wait_for_on_foot_recovery(fixture, PROBE_SETTLE_SECONDS),
		"opening-canopy destruction recovers on foot inside its bounded budget"
	)
	_assert_recovered_on_foot(fixture, "opening-canopy destruction")
	_check(_range_state(fixture.world) == targets_before, "opening-canopy destruction preserves the pending guided range")
	await _wait_seconds(STALE_CONTINUATION_SETTLE_SECONDS)
	_assert_recovered_on_foot(fixture, "stale opening-canopy continuation")
	await _free_fixture(game)


func _test_loss_during_player_boarding() -> void:
	var fixture := await _new_fixture(0.02, 0.55, 0.25)
	var game := fixture.game as GameFlow
	var player := fixture.player as PlayerController
	var craft := fixture.craft as HeroShip
	game.call("_board_ship", craft)
	var boarding_probe_reached := await _wait_until(
		func() -> bool:
			return (
				game.phase == GameFlow.Phase.BOARDING
				and not player.is_seated()
				and player.collision_layer == 0
			),
		PROBE_SETTLE_SECONDS
	)
	_check(
		boarding_probe_reached,
		"player-motion probe reaches collision-disabled physical BOARDING inside its bounded budget"
	)
	_check(
		game.phase == GameFlow.Phase.BOARDING
		and not player.is_seated()
		and player.collision_layer == 0,
		"player-motion probe reaches collision-disabled physical BOARDING"
	)
	craft.apply_damage(craft.maximum_hull + 1.0, craft.global_position, Vector3.UP)
	_check(
		await _wait_for_on_foot_recovery(fixture, PROBE_SETTLE_SECONDS),
		"mid-boarding destruction recovers on foot inside its bounded budget"
	)
	_assert_recovered_on_foot(fixture, "mid-boarding destruction")
	await _wait_seconds(STALE_CONTINUATION_SETTLE_SECONDS)
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
	var disembark_probe_reached := await _wait_until(
		func() -> bool:
			return (
				game.phase == GameFlow.Phase.DISEMBARKING
				and not player.is_seated()
				and player.collision_layer == 0
			),
		PROBE_SETTLE_SECONDS
	)
	_check(
		disembark_probe_reached,
		"exit-race probe reaches collision-disabled DISEMBARKING motion inside its bounded budget"
	)
	_check(
		game.phase == GameFlow.Phase.DISEMBARKING
		and not player.is_seated()
		and player.collision_layer == 0,
		"exit-race probe reaches collision-disabled DISEMBARKING motion"
	)
	craft.apply_damage(craft.maximum_hull + 1.0, craft.global_position, Vector3.UP)
	_check(
		await _wait_for_on_foot_recovery(fixture, PROBE_SETTLE_SECONDS),
		"mid-disembark destruction recovers on foot inside its bounded budget"
	)
	_assert_recovered_on_foot(fixture, "mid-disembark destruction")
	await _wait_seconds(STALE_CONTINUATION_SETTLE_SECONDS)
	_assert_recovered_on_foot(fixture, "stale disembarking continuation")

	_check(await _wait_until(func() -> bool: return not craft.is_destroyed(), 5.2), "destroyed transition craft regenerates within the production bound")
	var berth := world.get_berth_node(craft.get_home_berth_id())
	_check(craft.get_instance_id() == original_instance_id and game.get_flyable_ships().size() == 5, "transition recovery reuses the same craft and preserves the five-ship fleet")
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


func _test_detached_player_completion_defers_authority_handoff() -> void:
	var fixture := await _new_fixture(0.0, 0.0, 0.25)
	var game := fixture.game as GameFlow
	var player := fixture.player as PlayerController
	var craft := fixture.craft as HeroShip
	var completion_events: Array[int] = []
	player.boarding_completed.connect(func() -> void: completion_events.append(1))
	game.call("_board_ship", craft)
	# The first canopy edge starts the zero-duration Player transition and queues
	# its completion. Detach before that deferred delivery can resume GameFlow.
	craft.canopy_motion_finished.emit(true)
	root.remove_child(game)
	await process_frame
	await process_frame
	_check(
		player.is_seated()
		and completion_events.is_empty()
		and not craft.is_piloted()
		and not bool(game.get("_piloting"))
		and bool(game.get("_transition_busy"))
		and game.phase == GameFlow.Phase.BOARDING,
		"detached Player completion cannot hand pilot authority to the retained GameFlow"
	)
	root.add_child(game)
	_check(
		await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.7),
		"retained Player delivers its queued boarding completion after hierarchy re-entry"
	)
	_check(
		completion_events.size() == 1
		and player.is_seated()
		and craft.is_piloted()
		and bool(game.get("_piloting"))
		and not bool(game.get("_transition_busy")),
		"re-entry consumes exactly one deferred Player completion and restores pilot authority"
	)
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


## Waits for `predicate` on a finite simulation-frame budget.
##
## Canopy, boarding and disembarking motion, the destruction recovery that
## interrupts them, and the regeneration that follows are all advanced by
## `GameFlow` from its frame callbacks, while regeneration is released against a
## monotonic deadline. Under load Godot drops physics steps rather than letting
## the simulation spiral while the wall clock keeps running, so a
## wall-clock deadline abandons a transition that is still progressing perfectly
## well. `timeout` is kept as the nominal simulated duration and becomes a finite
## frame budget, so a genuinely stuck transition still fails the suite.
func _wait_until(predicate: Callable, timeout: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(timeout, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	for _frame in frame_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


## Waits for the on-foot recovery the destruction is expected to produce, and
## reports whether it actually arrived so the caller can assert on the budget
## instead of assuming it was never reached. The full
## [method _assert_recovered_on_foot] battery still runs afterwards unchanged.
func _wait_for_on_foot_recovery(fixture: Dictionary, seconds: float) -> bool:
	var game := fixture.game as GameFlow
	var player := fixture.player as PlayerController
	return await _wait_until(
		func() -> bool:
			return (
				game.phase == GameFlow.Phase.APPROACH_SHIP
				and not player.is_seated()
				and player.is_control_enabled()
				and not bool(game.get("_transition_busy"))
				and not bool(game.get("_recovering"))
			),
		seconds
	)


## Spends `duration` of *both* simulated frames and wall clock without waiting on
## any condition, for the negative assertions that need every stale continuation
## to have had its chance to run. A `SceneTree` timer measures smoothed engine
## delta rather than the simulation steps that resume those continuations.
func _wait_seconds(duration: float) -> void:
	await _wait_until(func() -> bool: return false, duration)


func _free_fixture(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	Input.action_release(&"interact")


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
