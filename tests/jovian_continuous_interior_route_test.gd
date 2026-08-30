extends SceneTree

## Focused embodied regression for the production Jovian's connected route.
## One staging teleport places the real player at the exterior ramp marker;
## every subsequent displacement is ordinary PlayerController locomotion.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var player := game.get_node_or_null(^"Player") as PlayerController
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var jovian := game.get_node_or_null(^"JovianLightFreighter") as JovianLightFreighter
	_check(player != null and world != null and jovian != null,
		"production player, world and Jovian are live")
	if player == null or world == null or jovian == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var berth := world.get_berth_node(jovian.get_home_berth_id())
	_check(
		berth != null
		and berth.get_occupant() == jovian
		and jovian.global_transform.is_equal_approx(
			world.get_berth_transform(jovian.get_home_berth_id())
		),
		"the walk uses the Jovian at its occupied production freight berth"
	)
	var access := jovian.get_interior_access_marker()
	var boarding_area := jovian.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	_check(
		access != null
		and boarding_area != null
		and boarding_area.get_ship() == jovian
		and access.global_position.distance_to(jovian.get_boarding_position()) > 10.0,
		"cargo-ramp access remains distinct from the exterior pilot-hatch authority"
	)

	game.start_shift()
	await process_frame
	player.teleport_to(Transform3D(
		jovian.global_basis.orthonormalized(),
		access.global_position + jovian.global_basis.y.normalized() * 0.01
	))
	for _index in 10:
		await physics_frame
	var start_local := jovian.to_local(player.global_position)
	_check(
		start_local.distance_to(access.position) < 0.03 and player.is_on_floor(),
		"the real player begins grounded at the exterior ramp marker"
	)

	var grounded_frames := 0
	var walked_frames := 0
	var checkpoints: Array[Vector3] = [start_local]
	# Ramp, aperture/cargo deck, aisle centring, passenger cabin, cockpit approach,
	# then one deliberate push against the visible pilot chair.
	var route := [
		[&"move_right", 50],
		[&"move_right", 72],
		[&"move_left", 22],
		[&"move_forward", 80],
		[&"move_forward", 38],
		[&"move_forward", 55],
	]
	for leg in route:
		Input.action_press(leg[0])
		for _index in int(leg[1]):
			await physics_frame
			walked_frames += 1
			if player.is_on_floor():
				grounded_frames += 1
		Input.action_release(leg[0])
		for _index in 3:
			await physics_frame
		checkpoints.append(jovian.to_local(player.global_position))

	var ramp := checkpoints[1]
	var cargo := checkpoints[2]
	var centred := checkpoints[3]
	var passenger := checkpoints[4]
	var cockpit := checkpoints[5]
	var pressed_chair := checkpoints[6]
	_check(
		ramp.x > -6.5 and ramp.x < -5.5 and absf(ramp.z - 3.2) < 0.35,
		"normal locomotion climbs the ship-owned ramp to its aperture"
	)
	_check(
		cargo.x > 0.5 and cargo.x < 1.6 and absf(cargo.z - 3.2) < 0.35,
		"the same uninterrupted walk crosses onto the physical cargo deck"
	)
	_check(
		absf(centred.x) < 0.2 and absf(centred.z - 3.2) < 0.35,
		"ordinary lateral movement centres the player in the cargo aisle"
	)
	_check(
		passenger.z < -3.5 and passenger.z > -6.0 and absf(passenger.x) < 0.5,
		"the continuous central-aisle walk enters the passenger cabin"
	)
	_check(
		cockpit.z > -7.4 and cockpit.z < -6.8 and absf(cockpit.x) < 0.45,
		"the same player reaches the cockpit pilot-seat approach without teleporting"
	)
	_check(
		pressed_chair.distance_to(cockpit) < 0.03,
		"the visible pilot chair, rather than a stray route blocker, stops forward motion"
	)
	var moving_frame := jovian.get_moving_interior_component()
	_check(
		grounded_frames == walked_frames
		and player.is_on_floor()
		and moving_frame != null
		and moving_frame.is_occupant_registered(player),
		"all %d locomotion frames stay supported and the player remains registered to the ship"
			% walked_frames
	)
	_check(
		not player.is_seated() and not jovian.is_piloted(),
		"interior traversal does not bypass or mutate pilot-hatch boarding authority"
	)

	print(
		"JOVIAN_CONTINUOUS_ROUTE: checkpoints=", checkpoints,
		" grounded=", grounded_frames, "/", walked_frames
	)
	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	for action in [&"move_right", &"move_left", &"move_forward"]:
		Input.action_release(action)
	if _failures.is_empty():
		print("jovian_continuous_interior_route_test: %d assertions" % _assertions)
		quit(0)
	else:
		print("JOVIAN_CONTINUOUS_INTERIOR_ROUTE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
