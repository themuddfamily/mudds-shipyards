extends "res://tests/in_flight_cabin_integration_test.gd"

func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	game.boarding_motion_time = 0.02
	game.disembarking_motion_time = 0.02
	var player := game.get_node("Player") as PlayerController
	var craft := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var bunk := craft.get_node("WalkableInterior/AftSystemsBay/PortSleepingBerth/ShipBunkInteraction") as ShipBunk
	player.teleport_to(bunk.get_exit_transform())
	game._sit_in_station_seat(bunk)
	_check(await _wait_until(func() -> bool: return player.is_sleeping(), 2.0), "landed bunk accepts sleep in approach phase")
	game.hud.set_paused(true)
	for tick in 3:
		await process_frame
	_check(player.is_sleeping() and game.hud._pause.visible and game.hud.layer > game._ship_rest_overlay.layer, "pause preserves sleep with menu above rest shade")
	game.hud.set_paused(false)
	root.remove_child(game)
	root.add_child(game)
	await process_frame
	await physics_frame
	_check(not player.is_sleeping() and player.is_control_enabled() and not game._ship_rest_overlay.visible and bunk.is_available(), "whole Main detach recovers sleeper and releases bunk")
	player.teleport_to(bunk.get_exit_transform())
	game._sit_in_station_seat(bunk)
	_check(await _wait_until(func() -> bool: return player.is_sleeping(), 2.0), "retained bunk accepts next sleep")
	bunk.queue_free()
	await process_frame
	await process_frame
	_check(not player.is_sleeping() and player.is_control_enabled() and not game._ship_rest_overlay.visible, "removing sleeping bunk recovers player")
	await _clean_up(game)
	print("REST_REVIEW_LIFECYCLE assertions=", _assertion_count, " failures=", _failures.size())
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_SLEEP_LIFECYCLE_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print("SHIP_SLEEP_LIFECYCLE_TEST_FAILED: %s" % "; ".join(_failures))
		quit(1)
