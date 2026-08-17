extends SceneTree

## Production proof for the streamed Cinder convoy composition. The host is a
## lifetime-stable Main child while every movement/proximity decision continues
## to use the existing route and caller physics time.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ROUTE := preload(
	"res://assets/activities/cinder_reach_emberline_convoy_route.tres"
)
const EXPECTED_ROUTE := [
	Vector3(84.0, -68.0, -724.0),
	Vector3(104.0, -64.0, -770.0),
	Vector3(139.0, -58.0, -824.0),
	Vector3(178.0, -54.0, -870.0),
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)

	var host := game.get_node_or_null(
		^"CinderConvoyEscortHost"
	) as CinderConvoyEscortHost
	var binding := game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var ship := game.get_flyable_ships()[1] as HeroShip
	_check(
		host != null and binding != null and bootstrap != null
		and hud != null and ship != null,
		"production Main resolves convoy, streaming, HUD, and one physical escort craft"
	)
	if host == null or binding == null or bootstrap == null or hud == null or ship == null:
		await _cleanup(game)
		_finish()
		return

	await _test_topology_board_and_rollback(game, host, binding, hud)
	await _test_exact_activation_and_shared_sampling(
		game, host, binding, bootstrap, hud, ship
	)
	await _test_reentry_completion_and_lifecycle_failures(
		game, host, bootstrap, hud, ship
	)

	await _cleanup(game)
	_finish()


func _test_topology_board_and_rollback(
	game: GameFlow,
	host: CinderConvoyEscortHost,
	binding: CinderStreamingProductionBinding,
	hud: GameHUD
	) -> void:
	var integration := game.get_activity_integration_report()
	var binding_snapshot := binding.get_snapshot()
	var board := hud.get_activity_selection_report()
	var buttons := board.get("buttons", {}) as Dictionary
	_check(
		int(integration.get("convoy_host_count", 0)) == 1
		and int(integration.get("convoy_host_instance_id", 0)) == host.get_instance_id()
		and bool(integration.get("convoy_host_parent_is_main", false))
		and (integration.get("convoy_host_transform") as Transform3D)
		== Transform3D.IDENTITY
		and host.get_parent() == game,
		"one identity host is a direct Main child, never a streamed cluster child"
	)
	_check(
		bool(binding_snapshot.get("caller_sample_mode", false))
		and not bool(binding_snapshot.get("provider_bound", true))
		and not bool(binding_snapshot.get("physics_processing", true))
		and binding.audit().get("update_authority")
		== &"one_physics_tick_from_caller_sample",
		"production streaming is caller-sampled and cannot run a competing physics sampler"
	)
	_check(
		buttons.size() == 4
		and buttons.has(&"timed_race")
		and buttons.has(&"patrol")
		and buttons.has(&"cargo_delivery")
		and buttons.has(&"convoy_escort"),
		"Activity Board publishes the four exact production choices"
	)

	# A structured failed preflight must restore the prior shared-route owner.
	var host_index := host.get_index()
	game.remove_child(host)
	await process_frame
	var rejected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
	var rolled_back := game.get_activity_integration_report()
	_check(
		not bool(rejected.get("accepted", true))
		and rejected.get("reason", &"") == &"activity_attach_failed"
		and rolled_back.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_TIMED_RACE
		and int(rolled_back.get("attached_route_owner_count", 0)) == 1,
		"a missing-host selection atomically rolls back to the prior route owner"
	)
	game.add_child(host)
	game.move_child(host, mini(host_index, game.get_child_count() - 1))
	await process_frame
	var convoy_button := hud.find_child(
		"ConvoyEscortActivityButton", true, false
	) as Button
	convoy_button.emit_signal("pressed")
	var selected := game.get_activity_integration_report()
	_check(
		selected.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_CONVOY_ESCORT
		and int(selected.get("attached_route_owner_count", -1)) == 0
		and not bool(selected.get("selection_locked", true)),
		"the real fourth button selects the private convoy composition before launch"
	)


func _test_exact_activation_and_shared_sampling(
	game: GameFlow,
	host: CinderConvoyEscortHost,
	binding: CinderStreamingProductionBinding,
	bootstrap: CinderStreamingBootstrap,
	hud: GameHUD,
	ship: HeroShip
	) -> void:
	ship.set_piloted(true)
	game.active_ship = ship
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.set("_sortie_departed_berth", false)
	ship.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	var berth_before := (game.get("_berth_tokens") as Dictionary).duplicate(true)
	var not_departed := game.request_activity_start(
		GameFlow.CINDER_CONVOY_ACTIVITY_ID
	)
	_check(
		not bool(not_departed.get("accepted", true))
		and not_departed.get("reason", &"") == &"sortie_not_departed",
		"an otherwise exact rendezvous cannot start before physical berth departure"
	)
	game.set("_sortie_departed_berth", true)

	# Load Cinder from a point just outside the activation boundary. The first
	# manual GameFlow tick is the sole actor sample and sole streaming policy tick.
	ship.global_position = (
		GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
	)
	var actor_before := int(
		game.get_activity_integration_report().get("actor_position_sample_count", -1)
	)
	var caller_before := int(binding.get_snapshot().get("caller_sample_count", -1))
	game.call("_physics_process", 0.1)
	_check(
		await _wait_until(func() -> bool: return bootstrap.get_loaded_instance() != null, 20),
		"the shared sample loads the current Cinder generation within a finite idle budget"
	)
	var actor_after := int(
		game.get_activity_integration_report().get("actor_position_sample_count", -1)
	)
	var caller_after := int(binding.get_snapshot().get("caller_sample_count", -1))
	_check(
		actor_after == actor_before + 1
		and caller_after == caller_before + 1
		and int(binding.get_snapshot().get("physics_tick_count", -1))
		== caller_after,
		"one GameFlow world-position read feeds exactly one streaming tick"
	)
	_check(
		(host.get_snapshot().get("activity") as Dictionary).get("state_id", &"")
		== &"idle",
		"4.01 metres from the audited centre remains strictly outside activation"
	)

	ship.global_position = (
		GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(3.99, 0.0, 0.0)
	)
	var tender_before := host.get_snapshot().get("entity_position") as Vector3
	var samples_before := int(
		game.get_activity_integration_report().get("position_sample_count", -1)
	)
	game.call("_physics_process", 0.1)
	var active := game.get_active_activity_snapshot()
	var stream := bootstrap.get_snapshot()
	_check(
		active.get("state_id", &"") == &"active"
		and int(active.get("session_generation", -1)) == 1
		and int(active.get("stream_generation", -1))
		== int(stream.get("loaded_generation", -2))
		and int(active.get("stream_instance_id", 0))
		== int(stream.get("loaded_instance_id", -1))
		and (host.get_snapshot().get("entity_position") as Vector3)
		!= tender_before
		and int(game.get_activity_integration_report().get("position_sample_count", -1))
		== samples_before + 1,
		"3.99 metres starts the current loaded generation and advances it from the same tick sample"
	)
	_check(
		Array(ROUTE.checkpoint_positions) == EXPECTED_ROUTE
		and Array(active.get("route_positions") as PackedVector3Array) == EXPECTED_ROUTE
		and active.get("escort_lane_offset") == Vector3(0.0, 20.0, 0.0)
		and active.get("activation_center")
		== EXPECTED_ROUTE[0] + Vector3(0.0, 20.0, 0.0),
		"the tender keeps its raw authored route while the player trigger publishes the audited +20m lane"
	)
	var locked := game.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	_check(
		not bool(locked.get("accepted", true))
		and locked.get("reason", &"") == &"selection_locked"
		and game.get_activity_integration_report().get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_CONVOY_ESCORT,
		"accepted activation locks the fourth selection without handing its generation elsewhere"
	)
	var hud_active := hud.get_activity_objective_report()
	_check(
		bool(hud_active.get("visible", false))
		and hud_active.get("activity_kind", &"") == &"convoy_escort"
		and "CONVOY  L" in str(hud_active.get("text", ""))
		and "REWARD" not in str(hud_active.get("text", "")).to_upper()
		and (game.get("_berth_tokens") as Dictionary) == berth_before,
		"HUD reads leg/proximity/time while convoy start changes no berth or reward state"
	)


func _test_reentry_completion_and_lifecycle_failures(
	game: GameFlow,
	host: CinderConvoyEscortHost,
	bootstrap: CinderStreamingBootstrap,
	hud: GameHUD,
	ship: HeroShip
	) -> void:
	var host_id := host.get_instance_id()
	var generation := host.get_generation()
	var before_detach := game.get_active_activity_snapshot()
	root.remove_child(game)
	await process_frame
	_check(
		not bool(host.get_snapshot().get("attached", true))
		and host.get_generation() == generation
		and host.get_snapshot().get("movement_distance")
		== before_detach.get("movement_distance"),
		"whole-Main detach freezes the current host generation without streaming ownership"
	)
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_physics_process(false)
	var after_reentry := game.get_activity_integration_report()
	_check(
		int(after_reentry.get("convoy_host_count", 0)) == 1
		and int(after_reentry.get("convoy_host_instance_id", 0)) == host_id
		and host.get_generation() == generation
		and game.get_active_activity_snapshot().get("state_id", &"") == &"active",
		"re-entry restores the same one host and current activity identity"
	)

	var budget := 40
	while game.get_active_activity_snapshot().get("state_id", &"") == &"active" and budget > 0:
		ship.global_position = (
			host.get_snapshot().get("entity_position") as Vector3
		) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		game.call("_physics_process", 0.25)
		budget -= 1
	var completed := game.get_active_activity_snapshot()
	_check(
		budget > 0
		and completed.get("state_id", &"") == &"completed"
		and int(completed.get("completed_checkpoint_count", 0)) == 4
		and float(completed.get("current_time_seconds", 0.0)) > 0.0
		and "CONVOY  ARRIVED" in str(hud.get_activity_objective_report().get("text", "")),
		"the real host traverses all four raw points beside the +20m lane and presents safe arrival"
	)

	# Generation replacement is fail-closed even if a stale observer tries to
	# report against the prior completed incarnation.
	_check(game.reset_active_activity(), "completed convoy resets explicitly")
	ship.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	var replacement_start := game.request_activity_start(
		GameFlow.CINDER_CONVOY_ACTIVITY_ID
	)
	var replacement_generation := host.get_generation()
	var stale := host.report_convoy_lost(generation)
	_check(
		bool(replacement_start.get("accepted", false))
		and not bool(stale.get("accepted", true))
		and stale.get("reason", &"") == &"stale_generation"
		and game.get_active_activity_snapshot().get("state_id", &"") == &"active",
		"a prior host generation cannot fail the current escort"
	)
	var loaded := bootstrap.get_loaded_instance()
	game.call(
		"_on_cinder_location_loaded",
		CinderStreamingBootstrap.LOCATION_ID,
		int(bootstrap.get_snapshot().get("loaded_generation", 0)) + 1,
		loaded
	)
	_check(
		game.get_active_activity_snapshot().get("state_id", &"") == &"failed"
		and game.get_active_activity_snapshot().get("terminal_reason", &"")
		== &"cinder_stream_replaced"
		and host.get_generation() == replacement_generation,
		"a loaded-generation mismatch fails the exact current convoy generation"
	)

	_check(game.reset_active_activity(), "stream replacement failure resets explicitly")
	ship.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	_check(
		bool(game.request_activity_start(
			GameFlow.CINDER_CONVOY_ACTIVITY_ID
		).get("accepted", false)),
		"the still-current loaded scene can start one fresh post-reset generation"
	)
	game.set("_piloting", false)
	game.call("_physics_process", 0.1)
	_check(
		game.get_active_activity_snapshot().get("state_id", &"") == &"failed"
		and game.get_active_activity_snapshot().get("terminal_reason", &"")
		== &"pilot_unseated",
		"loss of the piloted production authority hard-fails the current escort"
	)
	game.set("_piloting", true)
	ship.set_piloted(true)

	_check(game.reset_active_activity(), "unpilot failure resets explicitly")
	ship.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	_check(
		bool(game.request_activity_start(
			GameFlow.CINDER_CONVOY_ACTIVITY_ID
		).get("accepted", false)),
		"a final current generation starts before the real unload witness"
	)
	var coordinator := bootstrap.get_node_or_null(
		^"WorldStreamingCoordinator"
	) as WorldStreamingCoordinator
	var unloaded := coordinator.request_unload(CinderStreamingBootstrap.LOCATION_ID)
	_check(
		bool(unloaded.get("accepted", false))
		and game.get_active_activity_snapshot().get("state_id", &"") == &"failed"
		and game.get_active_activity_snapshot().get("terminal_reason", &"")
		== &"cinder_stream_unloaded"
		and not host.visible
		and not bool(game.get_activity_integration_report().get("grants_rewards", true))
		and not bool(game.get_activity_integration_report().get("berth_authority", true)),
		"real streamed unload synchronously fails and hides the host without reward or berth authority"
	)


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame in maximum_frames:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _cleanup(game: GameFlow) -> void:
	paused = false
	game.set("_piloting", false)
	game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("CINDER_CONVOY_PRODUCTION_INTEGRATION_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_CONVOY_PRODUCTION_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print(
			"CINDER_CONVOY_PRODUCTION_INTEGRATION_TEST_FAILED: ",
			", ".join(_failures)
		)
		quit(1)
