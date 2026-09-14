extends SceneTree
const MAIN := preload("res://scenes/main.tscn")
const ARROW := preload("res://scenes/ships/arrow_recon_ship.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
const EXPEDITION := preload("res://scripts/game/aurora_expedition.gd")
const SUCCESS_MARKER := "AURORA_EXPEDITION_PRODUCTION_TEST_OK"
var _failures: Array[String] = []
var _assertions := 0

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
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

func _finish(game: GameFlow) -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_forward")
	Input.action_release(&"interact")
	paused = false
	game.queue_free()
	await process_frame
	await process_frame
	print("%s: %d assertions" % [SUCCESS_MARKER if _failures.is_empty() else "AURORA_EXPEDITION_PRODUCTION_TEST_FAILED", _assertions])
	quit(0 if _failures.is_empty() else 1)
