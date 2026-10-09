extends Node

## Opt-in release probe. It drives only the Main supplied by Boot, using the
## same accepted escort setup as the production regression. This fixture does
## not qualify normal controls, pilot-seat/world restoration or native GPU work.
const SLOT: StringName = &"cinder_convoy_session"

var stage := ""
var _assertions := 0
var _failures := PackedStringArray()
var _started := false


func on_startup_completed(main: Node) -> void:
	if _started or not main is GameFlow or get_parent().call("get_main") != main:
		_fail("the probe accepts Boot's loaded production Main exactly once")
		return
	_started = true
	_begin.call_deferred(main)


func _begin(game: GameFlow) -> void:
	# Boot finishes its signal handoff and loading-screen dismissal first.
	await get_tree().process_frame
	await run_with_main(game, "startup_completed")


func _fail(description: String) -> void:
	push_error("FAIL: " + description)
	print("IN_WORLD_RECOVERY_FAILED")
	get_tree().quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _stored_session_state(store: UserDataStore) -> Dictionary:
	return (store.get_snapshot()[String(SLOT)].activities[0].progress.convoy_session_state as Dictionary).duplicate(true)


static func _canonical(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state)) as Dictionary


func _convoy_receipts(game: GameFlow) -> int:
	var authority := game.get_activity_reward_report().get("authority", {}) as Dictionary
	var record := authority.get("record", {}) as Dictionary
	return int((record.get("reward_counts", {}) as Dictionary).get("return_convoy_credit_to_shipyard", 0))


func run_with_main(game: GameFlow, entry: String) -> void:
	var store := game.get("_runtime_settings_user_data_store") as UserDataStore
	if store == null or game.get_tree() != get_tree():
		_fail("the supplied production Main owns its existing store and scene tree")
		return
	var main_id := game.get_instance_id()
	game.set_physics_process(false)
	if stage == "arm":
		game.call("_on_settings_save_requested")
		var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
		var craft := await prepare_convoy(game, 1)
		var first_start := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		var first_arrival := await finish_convoy(game, craft)
		var reset := game.reset_active_activity()
		craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
		var next_start := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		for _tick in 4:
			craft.global_position = (game.cinder_convoy_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
			game.call("_physics_process", 0.25)
		var saved := game.save_cinder_convoy_session()
		var boundary := _stored_session_state(store)
		_check(bool(selected.accepted) and bool(first_start.accepted) and first_arrival and reset
			and bool(next_start.accepted) and bool(saved.accepted) and _convoy_receipts(game) == 1
			and game.get_active_activity_snapshot().state_id == &"active"
			and float(boundary.host_state.movement_distance) > 0.0
			and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
			and _canonical(game.cinder_convoy_threat.capture_persistence_state()) == boundary.threat_state,
			"the actual second in-world convoy and first paid receipt reach their durable boundary")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var ready := {"boundary": boundary, "receipts": _convoy_receipts(game),
			"runtime_observation": _interruption_runtime_observation(game),
			"entry": entry, "loaded_main_instance_id": main_id}
		# No orderly exit or further gameplay/save mutation before the harness kill.
		get_tree().paused = true
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify(ready))
		return
	var boundary := _stored_session_state(store)
	var observations := _interruption_runtime_observation(game)
	var recovery := game.get_recovery_available_snapshot()
	var record := game.get_session_recovery_diagnostic_snapshot()
	var crash_events := 0
	for event: Dictionary in record.get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	_check(bool(game.get_cinder_convoy_session_persistence_report().restore_status.get("accepted", false))
		and game.get_active_activity_snapshot().state_id == &"active"
		and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
		and _canonical(game.cinder_convoy_threat.capture_persistence_state()) == boundary.threat_state
		and not recovery.is_empty() and recovery.get("state") == "running" and crash_events == 1,
		"a fresh OS process adopts the exact durable convoy and records its genuine interrupted session once")
	var before_receipts := _convoy_receipts(game)
	var craft_index := -1
	var ships := game.get_flyable_ships()
	for index in ships.size():
		if ships[index].get_ship_id() == StringName(boundary.escort_ship_id):
			craft_index = index
	_check(craft_index >= 0, "the durable escort identity resolves to its actual shipped craft")
	var arrived := false
	if craft_index >= 0 and _failures.is_empty():
		var craft := await prepare_convoy(game, craft_index)
		arrived = await finish_convoy(game, craft)
	game.call("_retry_owed_game_flow_activity_rewards")
	game.call("_retry_owed_game_flow_activity_rewards")
	_check(arrived and _convoy_receipts(game) == before_receipts + 1
		and game.get_active_activity_snapshot().state_id == &"completed"
		and bool(store.get_snapshot()[String(SLOT)].activities[0].reward_granted),
		"physical continuation after OS interruption pays the distinct convoy once despite repeated retry")
	var closed := game.mark_orderly_shutdown()
	_check(bool(closed.get("accepted", false)), "the recovered process closes both existing recovery marker owners")
	var outcome := {"boundary": boundary, "receipts_before": before_receipts,
		"receipts_after": _convoy_receipts(game), "crash_events": crash_events,
		"runtime_observation": observations, "assertions": _assertions,
		"entry": entry, "loaded_main_instance_id": main_id}
	_check(is_instance_valid(game) and game.get_instance_id() == main_id
		and game.get_tree() == get_tree(), "continuation retains the supplied Main and its authority")
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify(outcome))
		get_tree().quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)


func _interruption_runtime_observation(game: GameFlow) -> Dictionary:
	return {"phase": int(game.phase), "piloting": bool(game.get("_piloting")),
		"craft_id": String(game.active_ship.get_ship_id()), "craft_piloted": game.active_ship.is_piloted(),
		"player_seated": bool(game.player.call("is_seated")),
		"craft_position": [game.active_ship.global_position.x, game.active_ship.global_position.y, game.active_ship.global_position.z]}


static func prepare_convoy(game: GameFlow, craft_index: int) -> HeroShip:
	var craft := game.get_flyable_ships()[craft_index] as HeroShip
	craft.set_piloted(true)
	game.active_ship = craft
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
	game.call("_physics_process", 0.1)
	for _frame in 20:
		if is_instance_valid(game.cinder_streaming_bootstrap.get_loaded_instance()):
			break
		await game.get_tree().physics_frame
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	return craft


static func finish_convoy(game: GameFlow, craft: HeroShip) -> bool:
	var host := game.cinder_convoy_host
	for _tick in 14:
		craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		game.call("_physics_process", 0.25)
		await game.get_tree().physics_frame
	var attacker := game.cinder_convoy_threat.get_attacker()
	if not is_instance_valid(attacker):
		return false
	craft.global_position = attacker.global_position + Vector3(0.0, 0.0, 12.0)
	await game.get_tree().physics_frame
	var intercepted := game.get_combat_authority().submit_hitscan(craft, GameFlow.RANGE_WEAPON_ID,
		craft.global_position, attacker.global_position - craft.global_position)
	var budget := 60
	while budget > 0 and host.get_snapshot().activity.state_id == &"active":
		craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		game.call("_physics_process", 0.25)
		budget -= 1
	return bool(intercepted.get("destroyed", false)) and budget > 0 and host.get_snapshot().activity.state_id == &"completed"

