extends SceneTree

## Focused embodied route for the already-composed Heavy Breach content:
## physical on-foot board admission -> real Arrow boarding -> real berth
## departure -> existing director-owned encounter in FREE_FLIGHT.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const FRAME_BUDGET := 240

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var player := game.player as PlayerController
	var hud := game.hud as GameHUD
	var world := game.world as ShipyardWorld
	var arrow := game.get_node_or_null(^"ArrowReconShip") as HeroShip
	var director := game.get_node_or_null(^"EncounterScenarios") as EncounterScenarioDirector
	var board := world.get_heavy_breach_activity_board() as Area3D
	var defense_board := world.get_station_defense_activity_board() as Area3D
	_check(
		player != null and hud != null and arrow != null and director != null
		and board != null and defense_board != null,
		"production activity boards, player, Arrow, director, and HUD resolve"
	)
	if player == null or arrow == null or director == null \
			or board == null or defense_board == null:
		await _finish(game)
		return
	var board_body := board.get_node_or_null(^"CollisionBackedConsole") as CollisionObject3D
	var board_exclusions: Array[RID] = []
	if board_body != null:
		board_exclusions.append(board_body.get_rid())
	var board_position := board.global_position
	var supported_points := [
		board_position + Vector3(-0.75, 0.0, -1.15),
		board_position + Vector3(0.75, 0.0, -1.15),
		board_position + Vector3(-0.75, 0.0, 1.15),
		board_position + Vector3(0.75, 0.0, 1.15),
		board_position + Vector3(0.0, 0.0, 2.0),
	]
	var board_is_supported := true
	for point: Vector3 in supported_points:
		board_is_supported = board_is_supported and _has_world_floor_below(
			world, point, board_exclusions
		)
	_check(
		board_is_supported,
		"the board footprint and its interaction face are supported by the live station deck"
	)

	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.04
	game.start_shift()
	await process_frame

	# Stand on the readable/front side of the real board and face its centre.
	var player_position := board_position + Vector3(0.0, 0.0, 2.0)
	var board_direction := (board_position - player_position).normalized()
	player.teleport_to(Transform3D(
		Basis.looking_at(board_direction, Vector3.UP),
		player_position,
	))
	var board_selected := await _wait_until(func() -> bool:
		return game.station_interaction_candidate == board
	)
	_check(
		board_selected
		and "ARM HEAVY BREACH SORTIE" in str(board.call(&"get_interaction_prompt")),
		"the embodied interaction sensor selects the physical board and prompt"
	)
	await _press_action(&"interact", 1)
	var armed_snapshot := board.call(&"get_snapshot") as Dictionary
	var armed_hud := hud.get_activity_objective_report()
	_check(
		bool(armed_snapshot.get("sortie_armed", false))
		and int(armed_snapshot.get("armed_actor_instance_id", 0))
			== player.get_instance_id()
		and director.get_state() == EncounterScenarioDirector.STATE_IDLE
		and game.phase == GameFlow.Phase.APPROACH_SHIP,
		"live E arms one board generation without starting combat against the avatar"
	)
	_check(
		armed_hud.get("activity_id") == &"shipyard_heavy_breach"
		and StringName((armed_hud.get("heavy_breach", {}) as Dictionary).get(
			"state_id", &""
		)) == &"armed"
		and "SORTIE ARMED" in str(armed_hud.get("text", "")),
		"the retained activity HUD tells the player to launch a craft"
	)
	await _press_action(&"interact", 1)
	_check(
		not bool((board.call(&"get_snapshot") as Dictionary).get("sortie_armed", true))
		and director.get_state() == EncounterScenarioDirector.STATE_IDLE,
		"a second physical board interaction cancels the armed sortie cleanly"
	)
	await _press_action(&"interact", 1)
	armed_snapshot = board.call(&"get_snapshot") as Dictionary
	_check(
		bool(armed_snapshot.get("sortie_armed", false))
		and "CANCEL HEAVY BREACH SORTIE" in str(board.call(&"get_interaction_prompt")),
		"the same live board can immediately arm a fresh fenced sortie"
	)
	var stale_launch := board.call(
		&"launch_armed_sortie",
		arrow,
		int(armed_snapshot.get("sortie_generation", 0)) - 1,
	) as Dictionary
	_check(
		not bool(stale_launch.get("accepted", false))
		and stale_launch.get("reason") == &"stale_sortie_generation"
		and bool((board.call(&"get_snapshot") as Dictionary).get(
			"sortie_armed", false
		))
		and director.get_state() == EncounterScenarioDirector.STATE_IDLE,
		"a stale departure callback cannot consume the retained board admission"
	)
	player.teleport_to(Transform3D(
		Basis.IDENTITY,
		defense_board.global_position + Vector3(0.0, 0.0, 1.5),
	))
	await physics_frame
	var defense_start := game.call(&"_start_physical_station_defense_board") as Dictionary
	var defense_activity := (
		world.get_station_defense_content().get_snapshot().host.activity as Dictionary
	)
	_check(
		not bool(defense_start.get("accepted", false))
		and defense_start.get("reason") == &"heavy_breach_sortie_armed"
		and StringName(defense_activity.get("state_id", &"")) == &"idle"
		and bool((board.call(&"get_snapshot") as Dictionary).get("sortie_armed", false)),
		"the in-range defense-directory route cannot start a concurrent encounter while the sortie is armed"
	)

	# Board the real Arrow through the same proximity + E route used in play.
	player.teleport_to(Transform3D(
		Basis.IDENTITY,
		arrow.get_boarding_position() + Vector3(0.0, 0.05, 0.0),
	))
	var arrow_selected := await _wait_until(func() -> bool:
		return game.boarding_candidate == arrow
	)
	_check(arrow_selected, "the production Arrow boarding area becomes the live candidate")
	await _press_action(&"interact", 1)
	var arrow_boarded := await _wait_until(func() -> bool:
		return game.phase == GameFlow.Phase.START_ENGINES
	)
	_check(
		arrow_boarded and game.get_active_ship() == arrow
		and player.is_seated() and arrow.is_piloted(),
		"the armed contract still requires the complete physical Arrow seat handoff"
	)
	_check(
		bool((board.call(&"get_snapshot") as Dictionary).get("sortie_armed", false))
		and director.get_state() == EncounterScenarioDirector.STATE_IDLE,
		"boarding and engine-ready state alone do not launch the encounter"
	)

	# Real thrust clears the landed latch. GameFlow releases the berth, enters
	# FREE_FLIGHT, and only then supplies Arrow as the director target.
	Input.action_press(&"move_forward")
	var launched := await _wait_until(func() -> bool:
		return (
			game.phase == GameFlow.Phase.FREE_FLIGHT
			and director.get_state() == EncounterScenarioDirector.STATE_RUNNING
			and director.get_active_scenario()
				== EncounterScenarioDirector.SCENARIO_HEAVY_BREACH
		)
	)
	Input.action_release(&"move_forward")
	await physics_frame
	_check(launched, "physical departure launches Heavy Breach in real free flight")
	var running_snapshot := board.call(&"get_snapshot") as Dictionary
	var running_director := running_snapshot.get("director", {}) as Dictionary
	_check(
		not bool(running_snapshot.get("sortie_armed", true))
		and int(running_snapshot.get("active_director_generation", 0)) > 0
		and bool(running_director.get("launched", false))
		and int(running_director.get("active_roster", 0)) == 2,
		"the admitted generation becomes one picket-plus-screen encounter roster"
	)
	for _frame in 5:
		await physics_frame
		await process_frame
	_check(
		game.phase == GameFlow.Phase.FREE_FLIGHT
		and director.get_state() == EncounterScenarioDirector.STATE_RUNNING,
		"the explicit Heavy Breach phase gate remains live instead of withdrawing next tick"
	)
	var running_hud := hud.get_activity_objective_report()
	_check(
		running_hud.get("activity_id") == &"shipyard_heavy_breach"
		and "LAUNCHED" in str(running_hud.get("text", ""))
		and "PICKET" in str(running_hud.get("text", "")),
		"the live HUD exposes the launched objective and charged picket"
	)
	_check(
		not bool(game.get_active_activity_snapshot().get("running", false)),
		"Heavy Breach departure does not also start the default Cinder activity"
	)

	await _finish(game)


func _wait_until(predicate: Callable) -> bool:
	for _frame in FRAME_BUDGET:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _press_action(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(physics_ticks, 1):
		await physics_frame
	Input.action_release(action)
	await physics_frame
	await process_frame


func _has_world_floor_below(
	world: Node3D, point: Vector3, exclusions: Array[RID]
	) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3(0.0, 2.0, 0.0),
		point + Vector3(0.0, -3.0, 0.0),
		PhysicsLayers.WORLD,
	)
	query.exclude = exclusions
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.get("position", Vector3.ZERO) as Vector3).y > -0.25


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish(game: GameFlow) -> void:
	Input.action_release(&"interact")
	Input.action_release(&"move_forward")
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.set_paused(false)
	if is_instance_valid(game):
		game.queue_free()
	for _frame in 3:
		await process_frame
	if _failures.is_empty():
		print("HEAVY_BREACH_GAME_FLOW_PRODUCTION_ROUTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
	else:
		quit(1)
