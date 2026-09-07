extends "res://tests/halyard_continuous_role_route_test.gd"

func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var player := game.get_node("Player") as PlayerController
	var craft := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var hatch := craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	game.start_shift()
	await process_frame
	player.teleport_to(Transform3D(craft.global_basis, craft.get_boarding_position() + Vector3.UP * 0.01))
	for _i in 12:
		await physics_frame
		await process_frame
	_check(game.boarding_candidate == craft and game.station_interaction_candidate != hatch,
		"exterior boarding point keeps its ordinary pilot-seat interaction")
	_check(not craft.is_canopy_open(), "landed cabin starts physically closed")
	await _walk_to(player, craft, Vector3(-3.10, 0.0, craft.AIRSTAIR_Z), 120)
	await _press_hatch(game, player, craft, hatch, true)
	var inside := await _walk_to(player, craft, Vector3(-1.35, 0.52, craft.AIRSTAIR_Z), 120)
	_check(bool(inside.reached) and bool(inside.grounded), "normal walking crosses opened hatch onto cabin deck")
	await _press_hatch(game, player, craft, hatch, false)
	await _press_hatch(game, player, craft, hatch, true)
	var outside := await _walk_to(player, craft, craft.to_local(craft.get_boarding_position()), 180)
	_check(bool(outside.reached) and bool(outside.grounded), "normal walking returns down airstair to exterior")
	_check(not player.is_seated() and not craft.is_piloted(), "hatch use never takes pilot seat")
	game.queue_free()
	await process_frame
	_finish()


func _press_hatch(game: GameFlow, player: PlayerController, craft: HalyardCrewTransport, hatch: ShipCabinHatch, expected_open: bool) -> void:
	var delta := craft.to_local(hatch.global_position) - craft.to_local(player.global_position)
	var yaw := player.get_node("CameraRig/CameraYaw") as Node3D
	yaw.rotation.y = atan2(-delta.x, -delta.z)
	for _i in 4:
		await physics_frame
		await process_frame
	_check(game.station_interaction_candidate == hatch, "looking at physical hatch discovers normal interaction")
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	for _i in 30:
		await physics_frame
		await process_frame
	_check(craft.is_canopy_open() == expected_open, "real E toggles cabin hatch through ship canopy lifecycle")
