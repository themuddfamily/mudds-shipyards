extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []


class TerminalReturnAdapter:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"physical_arrival_completed": true,
			"contract_completed": true,
		}.duplicate(true)


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	for _index in 120:
		await process_frame
		await physics_frame
		if bool(game.get("_initialized")):
			break
	game.set("_initialized", true)
	var ship := game.active_ship as HeroShip
	var player := game.player as PlayerController
	var area := ship.get_node(^"ShipBoardingArea") as ShipBoardingArea
	player.teleport_to(area.global_transform)
	await physics_frame
	var seated := area.try_reserve(player) and player.begin_boarding(
		ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(), 0.0, ship
	)
	ship.set_piloted(true)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT

	var cruise := game.planetary_cruise_binding as PlanetaryCruiseProductionBinding
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := cruise.get_snapshot().get(
		"canonical_destination_orbital", {}
	) as Dictionary
	var navigation := frame.orbital_to_world_streaming_position(
		canonical, frame.get_generation()
	).get("position", Vector3.INF) as Vector3
	ship.global_position = navigation + Vector3.BACK * 500.0
	ship.velocity = (navigation - ship.global_position).normalized() * 10.0
	game.set_physics_process(true)
	for _index in 180:
		await physics_frame
		if bool(game.ember_surface_loop_host.get_snapshot().get("attached", false)):
			break

	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var production := game.ember_surface_loop_production_binding \
		as EmberSurfaceLoopProductionBinding
	var first_host_id := host.get_instance_id()
	var first_binding_id := production.get_instance_id()
	var first := game.begin_ember_surface_journey(
		host, game.activity_director, Callable(self, &"_reward"), 1
	)
	var cancelled := game.cancel_ember_surface_journey()
	ship.velocity = Vector3.ZERO
	ship._physics_process(0.0)
	_check(
		seated and bool(first.get("accepted", false))
			and bool(cancelled.get("accepted", false)),
		"the first public station-to-Ember request uses the retained Main actors",
	)

	# Model only the already-covered terminal boundary: the real Host/session have
	# completed and returned runtime ownership, and the physical station receipt
	# has told the Ember binding to retire its visit-scoped composition. The
	# regression below is the previously missing production behavior: those same
	# retained Main identities must admit a fresh public journey.
	var session := host.get_travel_session_observation_source()
	session.set("_started_once", true)
	session.set("_generation", 1)
	session.set("_state", PlanetaryTravelSession.State.COMPLETED)
	host.set("_generation", 1)
	host.set("_phase", EmberSurfaceLoopHost.Phase.COMPLETED)
	var first_surface := production.get("_planetary_composition") as Node
	var adopted_start := first_surface.call(
		&"adopt_started_host_generation", 0, host.get_attachment_generation()
	) as Dictionary
	var detached := host.detach(host.get_generation(), host.get_attachment_generation())
	host.set("_runtime_ownership_returned", true)
	production.set("_return_berth_adapter", TerminalReturnAdapter.new())
	var terminal_detach := production.detach_planetary_surface()
	var rebound := game._ensure_ember_surface_loop_host_bound(true)
	var second := game.begin_ember_surface_journey(
		host, game.activity_director, Callable(self, &"_reward"), 2
	)
	var surface_snapshot := production.get_planetary_surface_snapshot()
	_check(
		bool(adopted_start.get("accepted", false))
			and bool(detached.get("accepted", false))
			and bool(terminal_detach.get("accepted", false))
			and bool(rebound.get("accepted", false))
			and bool(second.get("accepted", false))
			and host.get_instance_id() == first_host_id
			and production.get_instance_id() == first_binding_id
			and bool(host.get_snapshot().get("attached", false))
			and host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE
			and bool(production.get_snapshot().get("configured", false))
			and int(surface_snapshot.get("host_generation", -1)) \
				== host.get_generation(),
		"a completed station return rebinds the same Main Host/binding for cycle two",
	)

	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("EMBER_SURFACE_LOOP_REPEAT_CYCLE_TEST_OK: retained Main admits cycle two")
		quit(0)
		return
	quit(1)


func _reward(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"repeat_cycle_reward"}


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("EMBER_SURFACE_LOOP_REPEAT_CYCLE_TEST: %s" % message)
