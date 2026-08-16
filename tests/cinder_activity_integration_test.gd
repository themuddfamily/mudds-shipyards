extends SceneTree

## Focused production integration for the first player-facing nearby activity.
## It uses the real Main, director resource, active physical ship, and HUD, but
## deliberately does not run the guided combat sortie or any reward path.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates with the activity integration")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var director := game.get_activity_director()
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var combat_before := game.get_combat_authority()
	_check(
		director != null and hud != null and combat_before != null,
		"production Main exposes its one activity director beside the existing HUD and combat authority"
	)
	if director == null or hud == null or combat_before == null:
		await _clean_up(game)
		_finish()
		return

	_test_scene_and_authority_boundary(game, director, hud)
	await _test_start_progress_reentry_and_completion(game, director, hud, combat_before)
	_test_fail_reset_and_generation_recovery(game, director, hud)

	await _clean_up(game)
	_finish()


func _test_scene_and_authority_boundary(
	game: GameFlow,
	director: ActivityDirector,
	hud: GameHUD
	) -> void:
	var integration := game.get_activity_integration_report()
	var audit := director.audit()
	_check(
		int(integration.get("director_count", 0)) == 1
		and director.get_definition(ROUTE.activity_id) == ROUTE,
		"Main owns exactly one director with the published Cinder route resource registered"
	)
	_check(
		not bool(integration.get("gameplay_authority", true))
		and not bool(integration.get("grants_rewards", true))
		and not bool(integration.get("combat_authority", true))
		and not bool(integration.get("ship_authority", true))
		and not bool(integration.get("berth_authority", true))
		and not bool(audit.get("gameplay_authority", true))
		and not bool(audit.get("grants_rewards", true)),
		"the production integration and director claim no reward, combat, ship, berth, or general gameplay authority"
	)
	var rejected := game.request_activity_start(ROUTE.activity_id)
	_check(
		not bool(rejected.get("accepted", true))
		and rejected.get("reason", &"") == &"not_in_free_flight",
		"an on-foot or guided phase cannot start the free-flight route"
	)
	_check(
		not bool(hud.get_activity_objective_report().get("visible", true)),
		"the activity HUD line stays hidden before a route starts"
	)


func _test_start_progress_reentry_and_completion(
	game: GameFlow,
	director: ActivityDirector,
	hud: GameHUD,
	combat_before: LiveCombatAuthority
	) -> void:
	# Stand in for the completed physical boarding/engine transition while leaving
	# the real production ship as the position source. The integration's public
	# start gate still sees exactly the state a normal sandbox flight produces.
	var fleet := game.get_flyable_ships()
	var route_ship := fleet[1] as HeroShip
	game.active_ship = route_ship
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.call("_start_default_free_flight_activity")
	var started := game.get_active_activity_snapshot()
	var generation := int(started.get("generation", -1))
	_check(
		int(started.get("state", -1)) == CheckpointRouteActivity.State.ACTIVE
		and generation == 1,
		"a normal free-flight state starts the published route at generation one"
	)
	game.call("_start_default_free_flight_activity")
	_check(
		int(game.get_active_activity_snapshot().get("generation", -1)) == generation,
		"re-observing the same free-flight state cannot duplicate or restart the active route"
	)
	var hud_started := hud.get_activity_objective_report()
	_check(
		bool(hud_started.get("visible", false))
		and int(hud_started.get("state", -1)) == CheckpointRouteActivity.State.ACTIVE
		and int(hud_started.get("next_checkpoint_index", -1)) == 0
		and "CHECKPOINT 1 / 5" in str(hud_started.get("text", "")),
		"the HUD consumes the live snapshot as checkpoint one of five"
	)

	# A later published anchor is physically occupied first. Sampling the active
	# ship must preserve route order rather than choosing the nearest anchor.
	route_ship.global_position = ROUTE.get_checkpoint_position(1)
	await physics_frame
	await physics_frame
	_check(
		int(game.get_active_activity_snapshot().get("next_checkpoint_index", -1)) == 0,
		"the production ship-position sampler rejects an out-of-order anchor"
	)
	route_ship.global_position = ROUTE.get_checkpoint_position(0)
	await physics_frame
	await physics_frame
	_check(
		int(game.get_active_activity_snapshot().get("next_checkpoint_index", -1)) == 1
		and "CHECKPOINT 2 / 5" in str(hud.get_activity_objective_report().get("text", "")),
		"occupying the first published anchor advances both director and HUD once"
	)

	var director_id := director.get_instance_id()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	_check(
		int(director.get_activity_snapshot(ROUTE.activity_id).get("generation", -1)) == generation
		and int(director.get_activity_snapshot(ROUTE.activity_id).get("next_checkpoint_index", -1)) == 1,
		"whole-Main detach preserves the live route generation and ordered progress"
	)
	parent.add_child(game)
	await process_frame
	await process_frame
	var after_reentry := game.get_activity_integration_report()
	var hud_after_reentry := hud.get_activity_objective_report()
	_check(
		game.get_activity_director().get_instance_id() == director_id
		and int(after_reentry.get("director_count", 0)) == 1
		and bool(game.get("_piloting"))
		and game.active_ship == route_ship
		and int((after_reentry.get("snapshot", {}) as Dictionary).get("next_checkpoint_index", -1)) == 1,
		"Main re-entry reuses one director and does not replay or duplicate route state"
	)
	_check(
		bool(hud_after_reentry.get("visible", false))
		and int(hud_after_reentry.get("generation", -1)) == generation
		and "CHECKPOINT 2 / 5" in str(hud_after_reentry.get("text", "")),
		"the HUD re-synchronises the preserved objective after Main re-entry"
	)
	_check(
		game.get_combat_authority() == combat_before,
		"activity re-entry does not replace or duplicate the existing combat authority"
	)

	var completion_witness := {"count": 0}
	director.activity_completed.connect(
		func(activity_id: StringName, event_generation: int) -> void:
			if activity_id == ROUTE.activity_id and event_generation == generation:
				completion_witness["count"] = int(completion_witness["count"]) + 1
	)
	for index in range(1, ROUTE.get_checkpoint_count()):
		route_ship.global_position = ROUTE.get_checkpoint_position(index)
		await physics_frame
		await physics_frame
		var step := game.get_active_activity_snapshot()
		_check(
			int(step.get("next_checkpoint_index", -1)) == index + 1,
			"physical checkpoint %d advances the ordered production sampler" % (index + 1)
		)
	var completed := game.get_active_activity_snapshot()
	_check(
		int(completed.get("state", -1)) == CheckpointRouteActivity.State.COMPLETED
		and int(completed.get("next_checkpoint_index", -1)) == ROUTE.get_checkpoint_count(),
		"the same physical ship completes the ordered route at the Cinder Reach anchor"
	)
	_check(
		int(completion_witness["count"]) == 1
		and "ROUTE COMPLETE" in str(hud.get_activity_objective_report().get("text", "")),
		"completion is emitted once and the HUD presents the terminal result"
	)
	route_ship.global_position = ROUTE.get_checkpoint_position(ROUTE.get_checkpoint_count() - 1)
	await physics_frame
	await physics_frame
	_check(
		int(completion_witness["count"]) == 1,
		"remaining inside the final volume cannot complete the route twice"
	)


func _test_fail_reset_and_generation_recovery(
	game: GameFlow,
	director: ActivityDirector,
	hud: GameHUD
	) -> void:
	var completed_generation := int(game.get_active_activity_snapshot().get("generation", -1))
	_check(game.reset_active_activity(), "the production integration explicitly resets a completed route")
	var reset := game.get_active_activity_snapshot()
	var reset_generation := int(reset.get("generation", -1))
	_check(
		int(reset.get("state", -1)) == CheckpointRouteActivity.State.IDLE
		and reset_generation == completed_generation + 1
		and not bool(hud.get_activity_objective_report().get("visible", true)),
		"reset clears progress, advances generation, and removes the terminal HUD line"
	)
	var restarted := game.request_activity_start(ROUTE.activity_id)
	var active_generation := int(restarted.get("generation", -1))
	_check(
		bool(restarted.get("accepted", false))
		and active_generation == reset_generation + 1,
		"the same normal flight can start a fresh route after reset"
	)
	_check(
		game.fail_active_activity(&"pilot_abort")
		and int(game.get_active_activity_snapshot().get("state", -1)) == CheckpointRouteActivity.State.FAILED,
		"the production integration exposes a finite failure transition for the current sortie"
	)
	var failed_hud := hud.get_activity_objective_report()
	_check(
		int(failed_hud.get("state", -1)) == CheckpointRouteActivity.State.FAILED
		and "FAILED — PILOT ABORT" in str(failed_hud.get("text", "")),
		"the HUD presents the failure reason without granting or implying a reward"
	)
	var stale := director.submit_position(
		ROUTE.activity_id,
		ROUTE.get_checkpoint_position(0),
		completed_generation
	)
	_check(
		not bool(stale.get("accepted", true))
		and stale.get("reason", &"") == &"stale_generation",
		"a delayed pre-reset position cannot mutate the replacement route generation"
	)
	_check(
		game.reset_active_activity()
		and int(game.get_active_activity_snapshot().get("state", -1)) == CheckpointRouteActivity.State.IDLE,
		"a failed route resets cleanly for the next physical sortie"
	)


func _clean_up(game: GameFlow) -> void:
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
	print("CINDER_ACTIVITY_INTEGRATION_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_ACTIVITY_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("CINDER_ACTIVITY_INTEGRATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
