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
	var deployed_generation := content.get_generation()
	var host := content.get_snapshot().host as Dictionary
	_check(activity.state_id == &"active" and deployed_generation > initial_generation
		and activity.timeout_seconds == 34.0 and activity.wave_count == 3
		and host.spawn_roster_count == 4 and host.active_entity_count == 1
		and board.get_physical_interaction_action() == &"status"
		and board.get_interaction_prompt().contains("STATION DEFENSE ACTIVE"),
		"actual Player E starts the unchanged real 34-second three-wave/four-actor encounter")
	var elapsed_before := float(activity.elapsed_seconds)
	await _press_interact()
	activity = _activity(content)
	_check(activity.state_id == &"active" and content.get_generation() == deployed_generation
		and float(activity.elapsed_seconds) >= elapsed_before
		and game.combat_authority.get_resolver().get_registered_source_count() == source_count,
		"active E is status-only: it neither aborts, resets nor restarts the encounter clock")

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
	_check(_activity(content).state_id == &"active" and content.get_generation() > reset_generation,
		"next physical Deploy remains usable after Reset and clearing the disclosed refusal fixture")
	var core_after := content.get_protected_asset().get_snapshot()
	_check(_interact_edges >= 10 and game.get_activity_reward_report().authority.record == reward_before
		and core_after.health > 0 and core_after.maximum_health == core_before.maximum_health,
		"requests came from Player input intent; real core remains live and no completion reward was fabricated")
	await _finish(game)


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
	if is_instance_valid(game):
		game.queue_free()
	for _frame in 10:
		await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_STATION_DEFENSE_INTERACTION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
	else:
		quit(1)
