extends SceneTree
const MAIN_SCENE := preload("res://scenes/main.tscn")
func _init() -> void: call_deferred(&"_run")
func _run() -> void:
	var main := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(main)
	for _i in 120:
		await process_frame
		await physics_frame
		if bool(main.get("_initialized")): break
	main.set("_initialized", true)
	var ship := main.active_ship
	var area := ship.get_node(^"ShipBoardingArea") as ShipBoardingArea
	main.player.teleport_to(area.global_transform)
	await physics_frame
	var reserved := area.try_reserve(main.player)
	var boarded: bool = main.player.begin_boarding(ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(), 0.0, ship)
	ship.set_piloted(true)
	main.set("_piloting", true)
	main.set("_sortie_departed_berth", true)
	main.phase = GameFlow.Phase.FREE_FLIGHT
	main.set_physics_process(true)
	var host := main.get_node(^"EmberSurfaceLoopHost") as EmberSurfaceLoopHost
	var begin := main.begin_ember_surface_journey(host, main.activity_director, Callable(self, &"_reward"), 1)
	var cruise: Dictionary = main.planetary_cruise_binding.get_snapshot()
	var frame := main.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	ship.global_position = frame.orbital_to_world_streaming_position(cruise.get("canonical_destination_orbital", {}), frame.get_generation()).get("position", Vector3.INF)
	for _i in 60: await physics_frame
	var stream: Dictionary = main.ember_streaming_binding.get_snapshot()
	var coordinator: Dictionary = (main.ember_streaming_bootstrap.get_snapshot().get("coordinator", {}) as Dictionary)
	var hs: Dictionary = host.get_snapshot()
	var valid: bool = reserved and boarded and bool(begin.get("accepted", false)) and int(coordinator.get("load_request_count", 0)) == 1 and bool(main.ember_streaming_bootstrap.get_loaded_instance() != null) and bool(hs.get("attached", false)) and int(stream.get("bound_coordinate_frame_generation", 0)) == 2
	if not valid:
		push_error("Ember stream activation failed: %s / %s / %s / %s" % [reserved, boarded, begin, hs])
		quit(1)
		return
	print("EMBER_SURFACE_LOOP_STREAM_ACTIVATION_TEST_OK")
	main.free()
	quit(0)
func _reward(_receipt: Dictionary) -> Dictionary: return {"accepted": true}
