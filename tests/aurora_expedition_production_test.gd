extends SceneTree
const MAIN := preload("res://scenes/main.tscn")
const SUCCESS_MARKER := "AURORA_EXPEDITION_PRODUCTION_TEST_OK"
var _failures: Array[String] = []
var _assertions := 0

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	await process_frame
	var craft := game.get_node("HalyardCrewTransport") as HeroShip
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.01
	game.call(&"_board_ship", craft)
	for i in range(240):
		await physics_frame
		if game._piloting:
			break
	_check(game._piloting and game.player.is_seated() and game.active_ship == craft, "ordinary boarding takes the Halyard pilot seat")
	var home_position := craft.global_position
	var owner = game.get("_aurora_expedition")
	game.call(&"_sync_planetary_cruise_hud")
	var row := _row(game)
	_check(bool(row.get("route_available", false)) and bool(row.get("action_enabled", false)), "Aurora is a selectable production destination: %s" % row.get("status_text"))
	if not bool(row.get("action_enabled", false)):
		await _finish(game)
		return
	_press_destination(game)
	_check(owner.state == &"outbound_jump" and not paused, "the visible Destination Board action starts the jump and resumes play")
	await _wait_state(owner, &"landed", 4000)
	_check(owner.state == &"landed", "physical landing completes at Aurora (state %s)" % owner.state)
	if owner.state != &"landed":
		await _finish(game)
		return
	var berth := owner.get("_berth") as ShipBerth
	var surface := owner.get("_surface") as Node3D
	_check(craft.global_position.distance_to(home_position) > 10000.0 and berth.get_occupant() == craft and bool(craft.get_telemetry().get("landed", false)), "the same Halyard occupies the real Aurora surface berth")
	_check(surface.get_node_or_null("LandingRegion/CoastalExploration/CoastalLookoutSign") != null, "the visited world contains explorable lookout and standing stones")
	game.call(&"_try_exit_ship")
	await _wait_state(owner, &"surface", 240)
	for i in range(30):
		await physics_frame
	_check(owner.state == &"surface" and not game.player.is_seated() and game.player.is_control_enabled() and game.player.is_on_floor(), "exit restores ordinary walking and physical surface support")
	var exit_position := game.player.global_position
	# Ordinary move input drives locomotion; no journey completion is synthesized.
	Input.action_press(&"move_right")
	for i in range(45):
		await physics_frame
	Input.action_release(&"move_right")
	_check(game.player.global_position.distance_to(exit_position) > 1.0, "the explorer can walk away from the ship with normal movement input")
	_check(not bool(_row(game).get("action_enabled", true)), "return action asks the on-foot explorer to board first")
	# Approach setup is bounded to the physical boarding volume; E still owns
	# reservation and the complete animated embodiment transition.
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	game.player.teleport_to(Transform3D(Basis.IDENTITY, area.global_position))
	for i in range(4):
		await physics_frame
	game.call(&"_on_interact_requested")
	await _wait_state(owner, &"landed", 240)
	_check(game.player.is_seated() and game._piloting and game.active_ship == craft, "E reboards the same physical craft")
	_press_destination(game)
	await _wait_state(owner, &"idle", 4000)
	_check(owner.state == &"idle" and craft.global_position.distance_to(home_position) < 1.0 and bool(craft.get_telemetry().get("landed", false)), "return action physically docks the craft at its original home berth")
	_check(game.player.is_seated() and game._piloting and game.world.visible and not is_instance_valid(owner.get("_surface")), "round trip restores station presentation and seated controls and unloads Aurora")
	game.call(&"_sync_planetary_cruise_hud")
	_press_destination(game)
	_check(owner.state == &"outbound_jump", "a second trip is immediately selectable")
	_press_destination(game)
	await _wait_state(owner, &"idle", 4000)
	_check(owner.state == &"idle" and bool(craft.get_telemetry().get("landed", false)), "cancelling the second outbound jump returns through the same home landing path")
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
		_press_destination(game)
		await _wait_state(owner, &"landed", 4000)
		game.call(&"_try_exit_ship")
		await _wait_state(owner, interrupted_state, 240)
		_check(owner.state == interrupted_state, "cancellation begins from live %s" % interrupted_state)
		owner.cancel()
		for i in range(30):
			await physics_frame
		_check(owner.state == &"idle" and not game._piloting and not game._transition_busy and not game.player.is_seated() and game.player.is_control_enabled() and game.player.get_camera().current and game.player.global_position.distance_to(home_position) < 40.0, "%s cancellation restores a controllable on-foot explorer at Mudds" % interrupted_state)
		_check((craft.get_node("ShipBoardingArea") as ShipBoardingArea).get_reservation_token() == null and bool(craft.get_telemetry().get("landed", false)), "%s cancellation releases the seat and physically restores home docking" % interrupted_state)
	await _finish(game)

func _row(game: GameFlow) -> Dictionary:
	for row: Dictionary in game.get_planetary_destination_catalog_snapshot().get("destinations", []):
		if row.get("destination_id") == &"aurora_temperate_world":
			return row
	return {}

func _press_destination(game: GameFlow) -> void:
	game.call(&"_sync_planetary_cruise_hud")
	game.hud.open_planetary_destination_board()
	var button := game.hud.find_child("PlanetaryDestinationAction_aurora_temperate_world", true, false) as Button
	_check(button != null and not button.disabled, "Aurora's visible action is enabled")
	if button != null and not button.disabled:
		button.pressed.emit()

func _wait_state(owner: RefCounted, target: StringName, frames: int) -> void:
	for i in range(frames):
		await physics_frame
		if owner.get("state") == target:
			return
	print("WAIT ENDED: ", owner.get("state"), " wanted ", target)

func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append(message)
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)

func _finish(game: GameFlow) -> void:
	Input.action_release(&"move_right")
	paused = false
	game.queue_free()
	await process_frame
	await process_frame
	print("%s: %d assertions" % [SUCCESS_MARKER if _failures.is_empty() else "AURORA_EXPEDITION_PRODUCTION_TEST_FAILED", _assertions])
	quit(0 if _failures.is_empty() else 1)
