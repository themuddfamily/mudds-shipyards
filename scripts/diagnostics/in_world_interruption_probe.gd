extends Node

## Opt-in release probe. It drives only the Main supplied by Boot, using the
## same accepted escort setup as the production regression. The arm leg first
## acquires a real Player seat; cold Resume must reacquire it at the disclosed
## safe home berth before the escort motion fixture runs. This does not qualify
## human flight acceptance, original flight-pose restoration or native GPU work.
const SLOT: StringName = &"cinder_convoy_session"

var stage := ""
var recovery_context := "pilot"
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
		var craft := (game.get_flyable_ships()[1] if recovery_context == "pilot" else game.get_node("HalyardCrewTransport")) as HeroShip
		if recovery_context == "pilot":
			game.canopy_motion_time = 0.01
			game.boarding_motion_time = 0.02
		game.start_shift()
		game.call("_board_ship", craft)
		_check(await _wait_for_real_pilot(game, craft, 300 if recovery_context != "pilot" else 120), "the arm leg settles a real Player pilot before any escort fixture setup")
		var saved_context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		_check(saved_context.get("mode") == "pilot" and saved_context.get("craft_id") == String(craft.get_ship_id()), "the actual settled solo pilot context is durable before the OS interruption")
		var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
		await _position_escort_fixture(game, craft)
		var first_start := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		var first_arrival := await finish_convoy(game, craft)
		var reset := game.reset_active_activity()
		craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
		var next_start := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		for _tick in 4:
			craft.global_position = (game.cinder_convoy_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
			game.call("_physics_process", 0.25)
		if recovery_context != "pilot":
			await _settle_airborne_context(game, craft)
		var saved := game.save_cinder_convoy_session()
		var boundary := _stored_session_state(store)
		_check(bool(selected.accepted) and bool(first_start.accepted) and first_arrival and reset
			and bool(next_start.accepted) and bool(saved.accepted) and _convoy_receipts(game) == 1
			and game.get_active_activity_snapshot().state_id == (&"active" if recovery_context == "pilot" else &"failed")
			and float(boundary.host_state.movement_distance) > 0.0
			and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
			and _canonical(game.cinder_convoy_threat.capture_persistence_state()) == boundary.threat_state,
			"the actual second in-world convoy and first paid receipt reach their durable boundary")
		saved_context = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		_check(saved_context.get("mode") == recovery_context and saved_context.get("craft_id") == String(craft.get_ship_id()),
			"the actual settled selected recovery context and craft are durable before kill")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var ready := {"boundary": boundary, "receipts": _convoy_receipts(game),
			"runtime_observation": _interruption_runtime_observation(game),
			"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
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
		and game.get_active_activity_snapshot().state_id == (&"active" if recovery_context == "pilot" else &"failed")
		and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
		and _restored_threat_boundary_matches(game, boundary)
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
	var safe_recovery_observation := {}
	if craft_index >= 0 and _failures.is_empty():
		var craft := ships[craft_index] as HeroShip
		var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start", int(recovery.session_id), int(recovery.startup_generation))
		if recovery_context == "pilot":
			game.canopy_motion_time = 0.01
			game.boarding_motion_time = 0.02
		game.start_shift()
		var settled := await _wait_for_real_pilot(game, craft) if recovery_context == "pilot" else await _wait_for_awake_cabin(game, craft)
		if recovery_context != "pilot":
			_check(craft.get_ship_id() == GameFlow.HALYARD_SHIP_ID and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1,
				"cold cabin recovery resolves the registered Halyard at its exact safe home berth")
		if recovery_context == "crew":
			var crew_status: Dictionary = game.call("get_solo_crew_seat_status")
			_check(settled and not bool(crew_status.seated) and (crew_status.assignment as Dictionary).is_empty()
				and (craft as HalyardCrewTransport).get_crew_role_authority() == null
				and not game.player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META),
				"cold crew Resume acquires awake cabin ownership without replaying the old passenger ledger or occupant tag")
		safe_recovery_observation = _interruption_runtime_observation(game)
		var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
		var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
		_check(bool(resumed.get("accepted", false)) and settled
			and area.get_reservation_token() == game.player and berth.get_occupant() == craft
			and berth.get_reservation_owner() == craft
			and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
			and _restored_threat_boundary_matches(game, boundary),
			"ordinary cold Resume reacquires the selected real safe home context and preserves the exact convoy before fixture positioning")
		if recovery_context != "pilot":
			var start := game.player.global_position
			Input.action_press(&"move_forward")
			await _settle_frames(24)
			Input.action_release(&"move_forward")
			await _settle_frames()
			_check(game.player.global_position.distance_to(start) > 0.1 and game.player.is_on_floor()
				and not craft.is_piloted() and game.player.is_control_enabled(),
				"the cold awake cabin passenger walks the actual floor before any convoy fixture")
			_check(game.get_active_activity_snapshot().state_id == &"failed"
				and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
				and _restored_threat_boundary_matches(game, boundary)
				and _convoy_receipts(game) == before_receipts,
				"awake cabin movement preserves the exact failed second convoy and first receipt")
			await _press_real_interaction()
			_check(await _wait_for_real_pilot(game, craft, 300) and not game.player.is_cabin_containment_active()
				and not craft.get_moving_interior_component().is_occupant_registered(game.player),
				"ordinary cabin interaction retakes a real pilot seat and releases passenger owners")
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release(&"move_forward")
		_check(str(craft.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE"
			and craft.get_last_ship_command().throttle > 0.0,
			"the cold recovered real pilot accepts an ordinary flight control")
		if _failures.is_empty():
			await _position_escort_fixture(game, craft)
			if recovery_context != "pilot":
				_check(game.get_active_activity_snapshot().state_id == &"idle"
					and _convoy_receipts(game) == before_receipts,
					"ordinary retaking of the pilot resets the failed convoy through its existing owner without credit")
				var next := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
				_check(bool(next.accepted), "existing owners accept a distinct new convoy after the production retake reset")
			if _failures.is_empty():
				arrived = await finish_convoy(game, craft)
	game.call("_retry_owed_game_flow_activity_rewards")
	game.call("_retry_owed_game_flow_activity_rewards")
	_check(arrived and _convoy_receipts(game) == before_receipts + 1
		and game.get_active_activity_snapshot().state_id == &"completed"
		and bool(store.get_snapshot()[String(SLOT)].activities[0].reward_granted),
		"escort fixture continuation after real safe recovery pays the distinct convoy once despite repeated retry")
	var closed := game.mark_orderly_shutdown()
	_check(bool(closed.get("accepted", false)), "the recovered process closes both existing recovery marker owners")
	var outcome := {"boundary": boundary, "receipts_before": before_receipts,
		"receipts_after": _convoy_receipts(game), "crash_events": crash_events,
		"runtime_observation": observations, "assertions": _assertions,
		"safe_recovery_observation": safe_recovery_observation,
		"continuation_method": "real_safe_home_berth_boarding_then_escort_motion_fixture" if recovery_context == "pilot" else "real_awake_home_cabin_walk_then_pilot_retake_new_convoy_escort_motion_fixture",
		"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
	_check(is_instance_valid(game) and game.get_instance_id() == main_id
		and game.get_tree() == get_tree(), "continuation retains the supplied Main and its authority")
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify(outcome))
		get_tree().quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)


func _restored_threat_boundary_matches(game: GameFlow, boundary: Dictionary) -> bool:
	if recovery_context == "pilot":
		return _canonical(game.cinder_convoy_threat.capture_persistence_state()) == boundary.threat_state
	# A failed terminal convoy has no running threat to arm. Main retains its
	# saved threat boundary for the terminal owner rather than reviving combat.
	var store := game.get("_runtime_settings_user_data_store") as UserDataStore
	return _stored_session_state(store) == boundary \
		and _canonical(game.get("_cinder_convoy_restored_threat_state") as Dictionary) == boundary.threat_state


func _settle_frames(count: int = 12) -> void:
	for _frame in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _settle_airborne_context(game: GameFlow, craft: HeroShip) -> void:
	# Real flight input and the craft's idle owner establish an airborne hull;
	# the production seat exit, not this probe, fails the active second convoy.
	Input.action_press(&"hover")
	Input.action_press(&"move_forward")
	await _settle_frames(6)
	Input.action_release(&"move_forward")
	Input.action_release(&"hover")
	await _settle_frames(int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 3)
	_check(not bool(craft.get_telemetry().get("landed", true))
		and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) > 100.0,
		"the selected context begins aboard a real airborne hull away from home")
	game.call("_leave_seat_into_cabin")
	for _frame in 120:
		if not bool(game.get("_transition_busy")) and game.player.is_on_floor():
			break
		await _settle_frames(1)
	await _settle_frames()
	_check(game.player.is_on_floor() and bool(game.get_in_flight_cabin_status().carried)
		and not craft.is_piloted() and game.get_active_activity_snapshot().state_id == &"failed",
		"production seat exit creates a supported cabin passenger and fails the second convoy")
	if recovery_context == "rest":
		var bunk := craft.get_node("WalkableInterior/AftSystemsBay/PortSleepingBerth/ShipBunkInteraction") as ShipBunk
		game.player.teleport_to(bunk.get_exit_transform())
		await _settle_frames()
		game.call("_sit_in_station_seat", bunk)
		for _frame in 120:
			if not bool(game.get("_transition_busy")):
				break
			await _settle_frames(1)
		await _settle_frames()
		_check(game.player.is_sleeping() and game.player.is_seated_at(bunk.get_seat_anchor())
			and bunk.is_reserved_for(game.player) and not craft.is_piloted(),
			"actual airborne ShipBunk rest owns the sleeper without pilot authority")
	if recovery_context == "crew":
		await _settle_real_crew_seat(game, craft as HalyardCrewTransport)
	game.call("_capture_solo_safe_recovery_context")


func _press_real_interaction() -> void:
	# Let the real Player sample E once while the authored motion is still
	# active. A shortened boarding can finish before the same edge is cleared.
	Input.action_press(&"interact")
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release(&"interact")
	await _settle_frames()


func _settle_real_crew_seat(game: GameFlow, craft: HalyardCrewTransport) -> void:
	var seat := craft.find_child("SoloPassengerSeatInteraction", true, false) as ShipCrewSeat
	_check(seat != null and seat.get_seat_anchor() == craft.get_loadmaster_station_anchor()
		and craft.get_crew_role_authority() == null,
		"the existing authored crew_port_00 chair has no injected passenger ledger before interaction")
	if seat == null:
		return
	game.player.teleport_to(seat.get_entry_transform())
	await _settle_frames()
	_check(game.station_interaction_candidate == seat and game.player.is_on_floor()
		and (game.hud.get("_interaction_label") as Label).text.contains("PASSENGER"),
		"ordinary overlap and facing discover the real passenger chair and visible E prompt")
	await _press_real_interaction()
	for _frame in 120:
		if not bool(game.get("_transition_busy")):
			break
		await _settle_frames(1)
	var status: Dictionary = game.call("get_solo_crew_seat_status")
	var assignment := status.assignment as Dictionary
	_check(bool(status.seated) and status.ship == craft
		and assignment.get("role") == &"passenger" and assignment.get("seat_id") == &"crew_port_00"
		and int(assignment.get("seat_generation", 0)) > 0
		and game.player.is_station_seated() and game.player.is_seated_at(seat.get_seat_anchor())
		and game.player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META)
		and craft.get_moving_interior_component().is_occupant_registered(game.player)
		and game.player.is_cabin_containment_active() and not craft.is_piloted()
		and not game.player.is_sleeping() and game.player.is_control_enabled(),
		"ordinary E settles the real passenger in the existing ledger, moving frame and authored chair without helm or sleep authority")


func _wait_for_awake_cabin(game: GameFlow, craft: HeroShip) -> bool:
	await _settle_frames()
	return game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and game.active_ship == craft \
		and not bool(game.get("_piloting")) and not craft.is_piloted() \
		and not game.player.is_seated() and not game.player.is_sleeping() \
		and game.player.is_control_enabled() and game.player.is_on_floor() \
		and game.player.is_cabin_containment_active() \
		and craft.get_moving_interior_component().is_occupant_registered(game.player)


func _interruption_runtime_observation(game: GameFlow) -> Dictionary:
	return {"phase": int(game.phase), "piloting": bool(game.get("_piloting")),
		"craft_id": String(game.active_ship.get_ship_id()), "craft_piloted": game.active_ship.is_piloted(),
		"player_seated": bool(game.player.call("is_seated")),
		"player_sleeping": game.player.is_sleeping(), "player_on_floor": game.player.is_on_floor(),
		"player_control_enabled": game.player.is_control_enabled(),
		"cabin_containment": game.player.is_cabin_containment_active(),
		"player_instance_id": game.player.get_instance_id(), "craft_instance_id": game.active_ship.get_instance_id(),
		"craft_position": [game.active_ship.global_position.x, game.active_ship.global_position.y, game.active_ship.global_position.z]}


func _wait_for_real_pilot(game: GameFlow, craft: HeroShip, frame_budget: int = 120) -> bool:
	for _frame in frame_budget:
		if game.phase == GameFlow.Phase.START_ENGINES:
			return game.player.is_seated_at(craft.get_pilot_seat_anchor()) and craft.is_piloted()
		await get_tree().physics_frame
	return false


static func prepare_convoy(game: GameFlow, craft_index: int) -> HeroShip:
	var craft := game.get_flyable_ships()[craft_index] as HeroShip
	craft.set_piloted(true)
	game.active_ship = craft
	game.set("_piloting", true)
	await _position_escort_fixture(game, craft)
	return craft


## Scenario positioning shared with old regression consumers. It does not
## acquire a seat, and the Boot probe measures real recovery before this call.
static func _position_escort_fixture(game: GameFlow, craft: HeroShip) -> void:
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
	game.call("_physics_process", 0.1)
	for _frame in 20:
		if is_instance_valid(game.cinder_streaming_bootstrap.get_loaded_instance()):
			break
		await game.get_tree().physics_frame
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER


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

