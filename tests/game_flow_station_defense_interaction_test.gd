extends SceneTree

## Production entry/reset regression, not an ordinary walk/combat sortie. Avatar
## poses are staged; the real Area3D overlap, facing selection, Player input edge
## and GameFlow E handler must then perform each request. The terminal fixture
## calls the existing content abort owner; it never fabricates a victory/reward.
const MAIN_SCENE := preload("res://scenes/main.tscn")
var _failures := PackedStringArray()
var _assertions := 0
var _interact_edges := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	await process_frame
	var player := game.player as PlayerController
	var board := game.world.get_station_defense_activity_board() as StationDefenseActivityBoard
	var content := game.world.get_station_defense_content() as StationDefenseEncounterContent
	var heavy := game.world.get_heavy_breach_activity_board() as Area3D
	_check(player != null and board != null and content != null and heavy != null,
		"actual Main exposes the production player, both physical boards and encounter")
	if player == null or board == null or content == null or heavy == null:
		await _finish(game)
		return
	player.interact_requested.connect(func() -> void: _interact_edges += 1)
	var initial_generation := content.get_generation()
	var source_count := game.combat_authority.get_resolver().get_registered_source_count()
	var core_before := content.get_protected_asset().get_snapshot()
	var reward_before := game.get_activity_reward_report().authority.record as Dictionary

	await _stage(player, board.global_position + Vector3(0, 0, 2), board.global_position)
	_check(player.get_nearby_interactables().has(board) and game.station_interaction_candidate == board
		and player.global_position.distance_to(board.global_position) <= 2.6
		and board.get_physical_interaction_action() == &"deploy"
		and board.get_interaction_prompt().contains("DEPLOY STATION DEFENSE"),
		"real nearby Area3D and embodied facing advertise E Deploy within the physical radius")

	# Turn away while still inside the real overlap; no cached candidate may act.
	await _stage(player, player.global_position, player.global_position + Vector3.BACK * 5)
	await _press_interact()
	_check(game.station_interaction_candidate != board and content.get_generation() == initial_generation
		and _activity(content).state_id == &"idle",
		"looking away refuses defense despite proximity and an ordinary Player E edge")
	# Horizontal 2.5 m is inside the radius, but the avatar/board height offset
	# puts the actual 3D distance outside 2.6 m while the area still overlaps.
	await _stage(player, board.global_position + Vector3(0, 0, 2.5), board.global_position)
	await _press_interact()
	_check(game.station_interaction_candidate == board
		and player.global_position.distance_to(board.global_position) > 2.6
		and content.get_generation() == initial_generation and _activity(content).state_id == &"idle",
		"actual 3D range gate refuses ordinary E even with horizontal proximity and the selected board")

	# The neighboring existing Heavy Breach board wins its own real candidate.
	await _stage(player, heavy.global_position + Vector3(0, 0, 2), heavy.global_position)
	_check(game.station_interaction_candidate == heavy, "competing physical board is selected by actual overlap and facing")
	await _press_interact()
	_check(bool((heavy.call(&"get_snapshot") as Dictionary).get("sortie_armed", false))
		and content.get_generation() == initial_generation and _activity(content).state_id == &"idle",
		"neighboring E arms its own sortie without deploying defense")
	await _stage(player, board.global_position + Vector3(0, 0, 2), board.global_position)
	await _press_interact()
	_check(game.station_interaction_candidate == board and content.get_generation() == initial_generation
		and _activity(content).state_id == &"idle"
		and game.combat_authority.get_resolver().get_registered_source_count() == source_count,
		"existing armed-sortie gate refuses defense without acquiring combat sources")
	await _stage(player, heavy.global_position + Vector3(0, 0, 2), heavy.global_position)
	await _press_interact()
	_check(not bool((heavy.call(&"get_snapshot") as Dictionary).get("sortie_armed", true)),
		"ordinary neighboring E cancels its own armed sortie")

	await _stage(player, board.global_position + Vector3(0, 0, 2), board.global_position)
	await _press_interact()
	var activity := _activity(content)
	var armed_generation := content.get_generation()
	var arm := board.get_launch_arm_snapshot()
	var host := content.get_snapshot().host as Dictionary
	_check(activity.state_id == &"idle" and armed_generation == initial_generation
		and bool(arm.armed) and arm.actor_instance_id == player.get_instance_id()
		and activity.timeout_seconds == 34.0 and activity.wave_count == 3
		and host.spawn_roster_count == 4 and host.active_entity_count == 0
		and board.get_physical_interaction_action() == &"cancel"
		and "ARMED" in board.get_interaction_prompt(),
		"actual Player E arms the unchanged real encounter without starting enemies or its 34-second timer")
	_check(not bool(game.call(&"_arm_heavy_breach_sortie", heavy))
		and bool(board.get_launch_arm_snapshot().armed),
		"armed defense retains the existing competing combat-sortie admission fence")
	game.call(&"_advance_station_defense_encounter", 40.0)
	_check(_activity(content).state_id == &"idle" and float(_activity(content).elapsed_seconds) == 0.0
		and content.get_generation() == armed_generation and bool(board.get_launch_arm_snapshot().armed),
		"armed station dwell beyond the timeout never advances the inactive encounter")
	var foreign := Node3D.new()
	game.add_child(foreign)
	var rejected_actor := board.launch_armed(foreign, content, int(arm.arm_id))
	var foreign_content := StationDefenseEncounterContent.new()
	var rejected_content := board.launch_armed(player, foreign_content, int(arm.arm_id))
	foreign_content.free()
	foreign.queue_free()
	_check(not rejected_actor.accepted and not rejected_content.accepted
		and bool(board.get_launch_arm_snapshot().armed) and _activity(content).state_id == &"idle",
		"foreign actor and replaced content cannot consume the current physical launch arm")
	await _press_interact()
	_check(not bool(board.get_launch_arm_snapshot().armed) and _activity(content).state_id == &"idle"
		and content.get_generation() == armed_generation,
		"separate physical E cancels an armed defense without starting the clock")
	await _press_interact()
	var cancelled := board.abort_and_reset(player, armed_generation)
	_check(cancelled.accepted and not bool(board.get_launch_arm_snapshot().armed)
		and _activity(content).state_id == &"idle", "physical Reset also retires an unlaunched arm")
	await _press_interact()
	# Existing-owner start is a disclosed fixture for stale-generation retirement
	# and the terminal Reset UI. Ordinary launch is exercised below through thrust.
	var direct_start := content.start(armed_generation)
	var deployed_generation := content.get_generation()
	_check(direct_start.accepted and not bool(board.get_launch_arm_snapshot().armed)
		and deployed_generation > armed_generation,
		"a content generation change retires the earlier arm instead of rebinding it")

	var aborted := content.abort(deployed_generation)
	_check(bool(aborted.get("accepted", false)) and _activity(content).state_id == &"aborted"
		and board.get_physical_interaction_action() == &"reset"
		and board.get_interaction_prompt().contains("RESET STATION DEFENSE"),
		"disclosed existing-owner terminal fixture advertises the physical Reset action")
	await _press_interact()
	_check(_activity(content).state_id == &"idle" and content.get_generation() > deployed_generation
		and board.get_physical_interaction_action() == &"deploy"
		and board.get_interaction_prompt().contains("DEPLOY STATION DEFENSE"),
		"separate ordinary E resets through the existing owner and exposes the next Deploy")
	var reset_generation := content.get_generation()
	# A staged refusal flag tests the dispatch fence; genuine store/debt recovery
	# is covered by station_defense_production_placement_test, not fabricated here.
	board.set("_session_refused", true)
	await _press_interact()
	_check(board.get_physical_interaction_action() == &"save_recovery"
		and board.get_interaction_prompt() == "SAVE RECOVERY REQUIRED"
		and content.get_generation() == reset_generation and _activity(content).state_id == &"idle",
		"refused session remains protected from ordinary E")
	board.set("_session_refused", false)
	await _press_interact()
	_check(_activity(content).state_id == &"idle" and content.get_generation() == reset_generation
		and bool(board.get_launch_arm_snapshot().armed),
		"next physical Deploy arms after Reset and clearing the disclosed refusal fixture")
	var next_arm := board.get_launch_arm_snapshot()
	_check(not board.launch_armed(player, content, int(arm.arm_id)).accepted
		and bool(board.get_launch_arm_snapshot().armed), "a cancelled arm nonce cannot consume a later arm")
	await _board_and_depart(game, board, content, int(next_arm.arm_id))
	var core_after := content.get_protected_asset().get_snapshot()
	_check(_interact_edges >= 10 and game.get_activity_reward_report().authority.record == reward_before
		and core_after.health > 0 and core_after.maximum_health == core_before.maximum_health,
		"requests came from Player input intent; real core remains live and no completion reward was fabricated")
	await _finish(game)


func _board_and_depart(game: GameFlow, board: StationDefenseActivityBoard, content: StationDefenseEncounterContent, arm_id: int) -> void:
	var craft: HeroShip = null
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == &"arrow_provisional":
			craft = candidate
	_check(craft != null, "the launch regression uses the production Arrow")
	if craft == null:
		return
	game.player.teleport_to(Transform3D(Basis.IDENTITY, craft.get_boarding_position() + Vector3.UP * 0.05))
	for _frame in 4:
		await physics_frame
	game.call(&"_board_ship", craft)
	for _frame in 600:
		if game.phase == GameFlow.Phase.START_ENGINES and not bool(game.get(&"_transition_busy")):
			break
		await physics_frame
	_check(game.phase == GameFlow.Phase.START_ENGINES and craft.is_piloted()
		and game.player.is_seated_at(craft.get_pilot_seat_anchor())
		and bool(board.get_launch_arm_snapshot().armed) and _activity(content).state_id == &"idle",
		"real boarding and START_ENGINES retain the inactive current launch arm")
	# Deliberate engine-only wake retains the physical dock latch.
	craft.call(&"_wake_engine_for_automatic_demand", false)
	for _frame in 4:
		await physics_frame
	_check(bool(craft.get_telemetry().landed) and _activity(content).state_id == &"idle"
		and float(_activity(content).elapsed_seconds) == 0.0 and bool(board.get_launch_arm_snapshot().armed),
		"engine wake alone starts neither enemies nor encounter time")
	game.set_physics_process(false)
	craft.set_physics_process(false)
	# A disclosed not-landed fixture isolates the failed authoritative release.
	craft.set(&"_landed", false)
	var guarded: Dictionary = game.get(&"_regeneration_lease_guarded_instance_ids")
	guarded[craft.get_instance_id()] = true
	game.call(&"_mark_sortie_departed")
	_check(_activity(content).state_id == &"idle" and bool(board.get_launch_arm_snapshot().armed)
		and game.world.get_berth_node(craft.get_home_berth_id()).get_occupant() == craft,
		"a refused physical release cannot consume the arm even if the historical departure flag changes")
	guarded.erase(craft.get_instance_id())
	craft.set(&"_landed", true)
	# A stale coordinator/anchor combination without a piloted craft is rejected.
	craft.set_piloted(false)
	craft.set(&"_landed", false)
	_check(not bool(game.call(&"_station_defense_departure_pilot_is_current", craft, game.player)),
		"a stale coordinator pilot flag cannot replace the craft's live piloted witness")
	craft.set(&"_landed", true)
	craft.set_piloted(true)
	craft.set_physics_process(true)
	game.set_physics_process(true)
	Input.action_press(&"move_forward")
	for _frame in 180:
		await physics_frame
		if _activity(content).state_id == &"active":
			break
	Input.action_release(&"move_forward")
	var launched_generation := content.get_generation()
	var activity := _activity(content)
	_check(not bool(craft.get_telemetry().landed) and activity.state_id == &"active"
		and activity.timeout_seconds == 34.0 and activity.wave_count == 3
		and content.get_snapshot().host.active_entity_count == 1
		and game.world.get_berth_node(craft.get_home_berth_id()).get_occupant() == null
		and not bool(board.get_launch_arm_snapshot().armed),
		"real Arrow thrust and exact occupied-berth release launch the first authored wave once")
	game.call(&"_mark_sortie_departed")
	_check(content.get_generation() == launched_generation
		and not board.launch_armed(game.player, content, arm_id).accepted
		and board.get_physical_interaction_action() == &"status",
		"repeated departure and a consumed arm cannot restart the active encounter")


func _activity(content: StationDefenseEncounterContent) -> Dictionary:
	var snapshot := content.get_snapshot()
	return (snapshot.host as Dictionary).activity as Dictionary


func _stage(player: PlayerController, position: Vector3, facing: Vector3) -> void:
	position.y = 0.18
	var direction := facing - position
	direction.y = 0.0
	player.teleport_to(Transform3D(Basis.looking_at(direction, Vector3.UP), position))
	for _frame in 4:
		await physics_frame
		await process_frame


func _press_interact() -> void:
	Input.action_press(&"interact")
	for _frame in 2:
		await physics_frame
	Input.action_release(&"interact")
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish(game: GameFlow) -> void:
	Input.action_release(&"interact")
	Input.action_release(&"move_forward")
	if is_instance_valid(game):
		game.queue_free()
	for _frame in 10:
		await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_STATION_DEFENSE_INTERACTION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
	else:
		quit(1)
