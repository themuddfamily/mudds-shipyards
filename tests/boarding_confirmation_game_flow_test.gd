extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.0
	game.start_shift()
	await process_frame
	_check(_presented_state(game) == &"approach", "real start_shift reaches the boarding presentation bridge")

	var player := game.player as PlayerController
	var ship := game.ship as HeroShip
	var area := ship.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	_check(
		player.begin_boarding(player.global_transform, ship.get_pilot_seat_anchor(), 0.0),
		"production player enters a conflicting seated state for the failure reproduction",
	)
	await process_frame
	# Freeze only the coordinator's idle prompt refresh so its ordinary AVAILABLE
	# repaint cannot overwrite the synchronous rejected receipt before inspection.
	game.set_process(false)
	game.call(&"_board_ship", ship)
	_check(
		await _wait_until(func() -> bool: return _presented_state(game) == &"rejected", 30),
		"failed production board reaches the rejected bridge state",
	)
	_check(
		area != null and not area.is_reserved() and area.get_reservation_token() == null,
		"failed production board releases the exact player reservation",
	)
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "failed production board returns to approach")

	player.force_recovery_to_on_foot(game.world.get_player_spawn())
	game.set_process(true)
	await process_frame
	game.call(&"_board_ship", ship)
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 60),
		"real production board reaches the pilot seat",
	)
	_check(_presented_state(game) == &"seated", "successful production board reaches the seated bridge state")
	_check(
		area.is_reserved() and area.get_reservation_token() == player,
		"successful bridge observation preserves ShipBoardingArea's exact token authority",
	)

	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BOARDING_CONFIRMATION_GAME_FLOW_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _presented_state(game: GameFlow) -> StringName:
	var report := game.get_boarding_confirmation_presentation_report()
	var adapter := report.get("adapter", {}) as Dictionary
	var view := adapter.get("view", {}) as Dictionary
	return StringName(view.get("state", &""))


func _wait_until(predicate: Callable, frame_budget: int) -> bool:
	for _frame in frame_budget:
		if bool(predicate.call()):
			return true
		await process_frame
		await physics_frame
	return bool(predicate.call())


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append("FAIL: " + message)
