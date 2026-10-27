extends Node

## Opt-in release probe. It drives only the Main supplied by Boot, using the
## same accepted escort setup as the production regression. The arm leg first
## acquires a real Player seat; cold Resume must acquire the selected safe home
## context before the escort motion fixture runs. Exterior recovery additionally
## walks and boards through real input after an actual landing/exit commit. This does not qualify
## human flight acceptance, original flight-pose restoration or native GPU work.
const SLOT: StringName = &"cinder_convoy_session"
const ON_FOOT_CRAFT_ID: StringName = &"bulwark_heavy_gunship"
const ON_FOOT_BERTH_ID: StringName = &"bulwark_fleet_dock_berth"
const DOCKING_INITIALIZATION := "existing_convoy_motion_fixture_then_home_approach_3m_above_registered_berth_real_landing_request_two_assist_physics_ticks"
const EXIT_INITIALIZATION := "existing_convoy_motion_fixture_then_home_approach_3m_real_landing_automatic_OFFLINE_synchronous_exterior_exit"
const ON_FOOT_INITIALIZATION := "existing_convoy_motion_fixture_then_home_approach_3m_above_registered_berth_real_landing_and_exterior_exit"

var stage := ""
var recovery_context := "pilot"
var activity := "convoy"
var _assertions := 0
var _failures := PackedStringArray()
var _started := false
var _breach_payment_board: HeavyBreachActivityBoard
var _breach_payment_observer: Callable


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
	if recovery_context == "on_foot" and activity != "convoy":
		_fail("settled exterior interruption supports only the existing convoy boundary")
		return
	if recovery_context in ["exit", "exit_refused"]:
		if activity != "convoy":
			_fail("busy exterior interruption supports only the existing convoy boundary")
			return
		await _run_busy_exit(game, store, entry)
		return
	if recovery_context == "docking":
		if activity != "convoy":
			_fail("docking interruption supports only the existing convoy boundary")
			return
		await _run_docking(game, store, entry)
		return
	if recovery_context == "engineer":
		await _run_engineer(game, store, entry)
		return
	if activity == "breach":
		await _run_breach(game, store, entry)
		return
	if activity == "ember":
		await _run_ember(game, store, entry)
		return
	if activity == "ember-abandon":
		await _run_ember_abandon(game, store, entry)
		return
	if activity == "hulk":
		await _run_hulk(game, store, entry)
		return
	if activity == "scan":
		await _run_scan(game, store, entry)
		return
	if activity == "stationdefense":
		await _run_stationdefense(game, store, entry)
		return
	if activity == "mining":
		await _run_mining(game, store, entry)
		return
	if activity == "beacon":
		await _run_beacon(game, store, entry)
		return
	var main_id := game.get_instance_id()
	game.set_physics_process(false)
	if stage == "arm":
		game.call("_on_settings_save_requested")
		var craft := (game.get_node("BulwarkHeavyGunship") if recovery_context == "on_foot" else game.get_flyable_ships()[1] if recovery_context == "pilot" else game.get_node("HalyardCrewTransport")) as HeroShip
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
		if recovery_context == "on_foot":
			await _settle_exterior_context(game, craft)
		elif recovery_context != "pilot":
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
		if recovery_context == "on_foot":
			_check(_on_foot_context_matches(saved_context, craft)
				and _is_settled_exterior(game, craft),
				"the committed exterior preference has exactly four fields and actual supported claim-free owners")
			if not _failures.is_empty():
				get_tree().quit(1)
				return
		var ready := {"boundary": boundary, "receipts": _convoy_receipts(game),
			"runtime_observation": _interruption_runtime_observation(game),
			"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
		if recovery_context == "on_foot":
			ready["safe_context"] = saved_context
			ready["exterior_observation"] = _exterior_observation(game, craft)
			ready["initialization"] = ON_FOOT_INITIALIZATION
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
	var exterior_safe_context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	if craft_index >= 0 and _failures.is_empty():
		var craft := ships[craft_index] as HeroShip
		var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start", int(recovery.session_id), int(recovery.startup_generation))
		if recovery_context == "pilot":
			game.canopy_motion_time = 0.01
			game.boarding_motion_time = 0.02
		game.start_shift()
		var settled := false
		if recovery_context == "pilot":
			settled = await _wait_for_real_pilot(game, craft)
		elif recovery_context == "on_foot":
			await _settle_frames()
			settled = _is_settled_exterior(game, craft)
		else:
			settled = await _wait_for_awake_cabin(game, craft)
		if recovery_context not in ["pilot", "on_foot"]:
			_check(craft.get_ship_id() == GameFlow.HALYARD_SHIP_ID and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1,
				"cold cabin recovery resolves the registered Halyard at its exact safe home berth")
		if recovery_context == "crew":
			var crew_status: Dictionary = game.call("get_solo_crew_seat_status")
			_check(settled and not bool(crew_status.seated) and (crew_status.assignment as Dictionary).is_empty()
				and (craft as HalyardCrewTransport).get_crew_role_authority() == null
				and not game.player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META),
				"cold crew Resume acquires awake cabin ownership without replaying the old passenger ledger or occupant tag")
		safe_recovery_observation = _exterior_observation(game, craft) if recovery_context == "on_foot" else _interruption_runtime_observation(game)
		var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
		var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
		_check(bool(resumed.get("accepted", false)) and settled
			and (area.get_reservation_token() == null if recovery_context == "on_foot" else area.get_reservation_token() == game.player) and berth.get_occupant() == craft
			and berth.get_reservation_owner() == craft
			and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
			and _restored_threat_boundary_matches(game, boundary),
			"ordinary cold Resume reacquires the selected real safe home context and preserves the exact convoy before fixture positioning")
		if recovery_context == "on_foot":
			_check(_on_foot_context_matches(store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {}), craft)
				and game.active_ship != craft and game.active_ship == game.ship,
				"cold exterior Resume retains the saved Bulwark preference without changing Main's default active craft")
			var walk := await _walk_exterior_home(game, craft)
			safe_recovery_observation["walking"] = walk
			_check(bool(walk.supported) and float(walk.distance_m) > 0.1
				and _is_settled_exterior(game, craft)
				and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
				and _restored_threat_boundary_matches(game, boundary)
				and _convoy_receipts(game) == before_receipts,
				"normal on-foot input walks the actual supported home deck without taking claims or changing the convoy and receipt")
			_check(game.boarding_candidate == craft, "ordinary exterior discovery selects the saved Bulwark before Interact")
			if _failures.is_empty():
				await _press_real_interaction()
				_check(await _wait_for_real_pilot(game, craft, 300)
					and area.get_reservation_token() == game.player,
					"normal exterior Interact boards the saved Bulwark through its real seat and hatch owner")
		elif recovery_context != "pilot":
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
		if not _failures.is_empty():
			get_tree().quit(1)
			return
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
	if recovery_context == "on_foot":
		outcome["safe_context"] = exterior_safe_context
		outcome["initialization"] = ON_FOOT_INITIALIZATION
		outcome["continuation_method"] = "ordinary_cold_exterior_home_walk_and_interact_boarding_then_distinct_convoy_motion_fixture"
	_check(is_instance_valid(game) and game.get_instance_id() == main_id
		and game.get_tree() == get_tree(), "continuation retains the supplied Main and its authority")
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify(outcome))
		get_tree().quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)


## This cut uses the existing escort fixture, then the actual landing request.
## Landing deliberately fails its running convoy; Resume preserves that terminal
## until an explicit public reset starts a distinct escort. No old assist resumes.
func _docking_context_matches(context: Dictionary, craft: HeroShip) -> bool:
	return context == {"location": "mudds_home_berth", "mode": "pilot",
		"craft_id": String(ON_FOOT_CRAFT_ID), "berth_id": String(ON_FOOT_BERTH_ID)} \
		and craft.get_ship_id() == ON_FOOT_CRAFT_ID and craft.get_home_berth_id() == ON_FOOT_BERTH_ID


func _docking_observation(game: GameFlow, craft: HeroShip) -> Dictionary:
	var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var observed := _interruption_runtime_observation(game)
	observed["landing"] = craft.get_landing_contract_report()
	observed["landing_request_active"] = bool(game.get("_landing_request_active"))
	observed["active_landing_berth_id"] = String(game.get("_active_landing_berth_id"))
	observed["landed"] = bool(craft.get_telemetry().get("landed", false))
	observed["home_berth_id"] = String(berth.get_berth_id())
	observed["home_berth_instance_id"] = berth.get_instance_id()
	observed["berth_reservation_token"] = String(berth.get_reservation_token(craft))
	observed["berth_lease_current"] = berth.has_valid_lease(craft, berth.get_reservation_token(craft), craft.get_ship_id())
	observed["berth_reserved_by_craft"] = berth.get_reservation_owner() == craft
	observed["berth_occupied_by_craft"] = berth.get_occupant() == craft
	observed["berth_unoccupied"] = berth.get_occupant() == null
	observed["hatch_reserved_by_player"] = area.get_reservation_token() == game.player
	observed["player_at_pilot_seat"] = game.player.is_seated_at(craft.get_pilot_seat_anchor())
	observed["craft_at_home"] = craft.global_position.distance_to(berth.get_dock_transform().origin) < 0.1
	observed["distance_to_dock_m"] = craft.global_position.distance_to(berth.get_dock_transform().origin)
	observed["owed_rewards"] = (game.get("_owed_game_flow_activity_rewards") as Array).duplicate(true)
	return observed


func _docking_boundary_matches(game: GameFlow, store: UserDataStore, convoy: Dictionary, rewards: Dictionary) -> bool:
	var boundary := convoy.activities[0].progress.convoy_session_state as Dictionary
	return store.get_snapshot().get(String(SLOT), {}) == convoy \
		and store.get_snapshot().get("game_flow_reward_store", {}) == rewards \
		and game.get_active_activity_snapshot().state_id == &"failed" \
		and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state \
		and _restored_threat_boundary_matches(game, boundary) \
		and (game.get("_owed_game_flow_activity_rewards") as Array).is_empty()


func _run_docking(game: GameFlow, store: UserDataStore, entry: String) -> void:
	var main_id := game.get_instance_id()
	game.set_physics_process(false)
	var craft := game.get_node("BulwarkHeavyGunship") as HeroShip
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	if stage == "arm":
		game.call("_on_settings_save_requested")
		game.start_shift()
		game.call("_board_ship", craft)
		_check(await _wait_for_real_pilot(game, craft), "docking arm acquires the actual Bulwark pilot before disclosed escort placement")
		_check(_docking_context_matches(store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {}), craft),
			"docking arm saves only the actual four-field Bulwark pilot/home preference")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
		await _position_escort_fixture(game, craft)
		var first := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		var first_arrival := await finish_convoy(game, craft)
		var reset := game.reset_active_activity()
		craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
		var second := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		for _tick in 4:
			craft.global_position = (game.cinder_convoy_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
			game.call("_physics_process", 0.25)
		_check(selected.accepted and first.accepted and first_arrival and reset and second.accepted
			and _convoy_receipts(game) == 1 and game.get_active_activity_snapshot().state_id == &"active",
			"the existing escort fixture starts a moving second convoy after exactly one real paid arrival")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		# Ordinary thrust clears the hull's docked latch. Main remains stopped as
		# in the escort fixture; only the craft's actual physics advances here.
		Input.action_press(&"hover")
		Input.action_press(&"move_forward")
		await _settle_frames(6)
		Input.action_release(&"move_forward")
		Input.action_release(&"hover")
		_check(not bool(craft.get_telemetry().get("landed", true)), "ordinary thrust clears the real Bulwark docking latch")
		var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
		var old_token := berth.get_reservation_token(craft)
		craft.global_transform = berth.get_dock_transform().translated_local(Vector3(0.0, 3.0, 0.0))
		craft.velocity = Vector3.ZERO
		var signals := {"completed": 0, "aborted": 0}
		craft.landing_completed.connect(func(): signals.completed += 1)
		craft.landing_aborted.connect(func(_reason: StringName): signals.aborted += 1)
		game.call("_try_request_landing")
		var accepted := craft.get_landing_contract_report()
		var requested_token := berth.get_reservation_token(craft)
		var requested_position := craft.global_position
		_check(craft.is_landing_active() and bool(game.get("_landing_request_active"))
			and accepted.contract_accepted and accepted.reservation_token_bound
			and accepted.berth_instance_id == berth.get_instance_id()
			and accepted.berth_id == craft.get_home_berth_id()
			and not requested_token.is_empty() and requested_token != old_token
			and berth.get_reservation_owner() == craft and berth.get_occupant() == null,
			"the normal landing request acquires a new actual target berth lease and active assist")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		await _settle_frames(2)
		var observed := _docking_observation(game, craft)
		observed["completed_signals"] = signals.completed
		observed["aborted_signals"] = signals.aborted
		observed["advanced_distance_m"] = craft.global_position.distance_to(requested_position)
		observed["requested_elapsed"] = accepted.elapsed
		_check(observed.landing.active and observed.landing.elapsed > accepted.elapsed
			and observed.advanced_distance_m > 0.0 and not observed.landed
			and observed.berth_lease_current and observed.berth_reserved_by_craft and observed.berth_unoccupied
			and observed.landing.reservation_token_bound and observed.landing.berth_instance_id == berth.get_instance_id()
			and observed.landing.reserved_ship_id == craft.get_ship_id()
			and berth.get_reservation_token(craft) == requested_token
			and observed.landing_request_active and observed.active_landing_berth_id == String(berth.get_berth_id())
			and observed.hatch_reserved_by_player and observed.player_at_pilot_seat
			and signals.completed == 0 and signals.aborted == 0,
			"two actual assist physics ticks move the real hull while its exact live lease remains uncompleted and unaborted")
		game.call("_capture_solo_safe_recovery_context")
		var saved := game.save_cinder_convoy_session()
		var convoy: Dictionary = store.get_snapshot().get(String(SLOT), {})
		var boundary := _stored_session_state(store)
		var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		var rewards: Dictionary = store.get_snapshot().get("game_flow_reward_store", {})
		_check(saved.accepted and game.get_active_activity_snapshot().state_id == &"failed"
			and game.get("_convoy_terminal_reason") == &"landing_requested"
			and float(boundary.host_state.movement_distance) > 0.0
			and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
			and _canonical(game.cinder_convoy_threat.capture_persistence_state()) == boundary.threat_state
			and _docking_context_matches(context, craft) and observed.owed_rewards.is_empty()
			and _convoy_receipts(game) == 1,
			"actual accepted landing leaves the failed second convoy durable, debt-free and unpaid with only the four-field pilot preference")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		get_tree().paused = true
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify({"boundary": boundary, "convoy_record": convoy,
			"reward_store": rewards, "receipts": 1, "safe_context": context, "docking_observation": observed,
			"runtime_observation": _interruption_runtime_observation(game), "initialization": DOCKING_INITIALIZATION,
			"activity": activity, "recovery_context": recovery_context, "entry": entry,
			"loaded_main_instance_id": main_id, "approach_pose_restore": "NOT_SUPPORTED"}))
		return
	var convoy: Dictionary = store.get_snapshot().get(String(SLOT), {})
	var rewards: Dictionary = store.get_snapshot().get("game_flow_reward_store", {})
	var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	var boundary := _stored_session_state(store)
	var recovery := game.get_recovery_available_snapshot()
	var crash_events := 0
	for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	var before_receipts := _convoy_receipts(game)
	_check(game.get_cinder_convoy_session_persistence_report().restore_status.get("accepted", false)
		and _docking_boundary_matches(game, store, convoy, rewards) and _docking_context_matches(context, craft)
		and boundary.escort_ship_id == craft.get_ship_id() and before_receipts == 1
		and crash_events == 1 and not recovery.is_empty() and recovery.get("state") == "running"
		and not craft.is_landing_active() and not bool(game.get("_landing_request_active")),
		"fresh Boot preserves the actual failed convoy and retained threat/debt/reward boundary without restoring old assist authority")
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start",
		int(recovery.session_id), int(recovery.startup_generation))
	game.start_shift()
	var settled := await _wait_for_real_pilot(game, craft)
	var safe := _docking_observation(game, craft)
	_check(resumed.get("accepted", false) and settled and safe.craft_at_home
		and safe.berth_occupied_by_craft and safe.berth_reserved_by_craft and safe.berth_lease_current
		and safe.hatch_reserved_by_player and safe.player_at_pilot_seat and not safe.player_sleeping
		and not safe.cabin_containment and not safe.landing.active and not safe.landing_request_active
		and safe.active_landing_berth_id.is_empty() and _docking_boundary_matches(game, store, convoy, rewards),
		"ordinary cold Resume acquires fresh supported home pilot, seat, berth and hatch while preserving the exact failed boundary")
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	Input.action_press(&"move_forward")
	await _settle_frames(2)
	Input.action_release(&"move_forward")
	var control := {"engine_online": str(craft.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE",
		"throttle": craft.get_last_ship_command().throttle, "landing_active": craft.is_landing_active()}
	_check(control.engine_online and control.throttle > 0.0 and not control.landing_active
		and _docking_boundary_matches(game, store, convoy, rewards),
		"normal throttle works before fixture placement and preserves exact failed convoy, retained threat, debt and receipt")
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	await _position_escort_fixture(game, craft)
	var reset := game.reset_active_activity()
	_check(reset and game.get_active_activity_snapshot().state_id == &"idle" and _convoy_receipts(game) == before_receipts,
		"an explicit existing public reset retires the preserved failed convoy without paying it")
	var next := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	var continuation_generation := int(game.get_active_activity_snapshot().generation)
	_check(next.accepted and continuation_generation > int(convoy.activities[0].generation),
		"the existing owner starts a distinct convoy generation after the explicit reset")
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	var arrived := await finish_convoy(game, craft)
	game.call("_retry_owed_game_flow_activity_rewards")
	game.call("_retry_owed_game_flow_activity_rewards")
	_check(arrived and _convoy_receipts(game) == before_receipts + 1
		and game.get_active_activity_snapshot().state_id == &"completed"
		and store.get_snapshot()[String(SLOT)].activities[0].reward_granted,
		"the distinct escort fixture commits exactly one second receipt despite repeated production reward retry")
	var closed := game.mark_orderly_shutdown()
	_check(closed.get("accepted", false) and game.get_instance_id() == main_id and game.get_tree() == get_tree(),
		"the recovered Boot Main retains its owners and orderly closes both markers")
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify({"boundary": boundary, "convoy_record": convoy,
			"reward_store": rewards, "receipts_before": before_receipts, "receipts_after": _convoy_receipts(game),
			"crash_events": crash_events, "safe_context": context, "safe_recovery_observation": safe,
			"control_observation": control, "continuation_generation": continuation_generation, "runtime_observation": _interruption_runtime_observation(game),
			"initialization": DOCKING_INITIALIZATION, "approach_pose_restore": "NOT_SUPPORTED",
			"continuation_method": "ordinary_cold_home_pilot_resume_throttle_explicit_reset_then_distinct_convoy_motion_fixture",
			"assertions": _assertions, "activity": activity, "recovery_context": recovery_context,
			"entry": entry, "loaded_main_instance_id": main_id}))
		get_tree().quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)



## Observe the real exit coroutine before its first awaited canopy frame. The
## runner independently reads both durable files before authorizing this cut.
func _busy_exit_observation(game: GameFlow, craft: HeroShip) -> Dictionary:
	var observed := _docking_observation(game, craft)
	observed["transition_busy"] = bool(game.get("_transition_busy"))
	observed["disembarking"] = game.phase == GameFlow.Phase.DISEMBARKING
	observed["engine_offline"] = str(craft.get_telemetry().get("engine_state", "")).to_upper() == "OFFLINE"
	observed["retry_seconds"] = float(game.get("_solo_safe_recovery_retry_remaining_seconds"))
	observed["solo_crew_seated"] = bool(game.get_solo_crew_seat_status().get("seated", false))
	observed["solo_crew_assignment_empty"] = (game.get_solo_crew_seat_status().get("assignment", {}) as Dictionary).is_empty()
	observed["moving_interior_occupant"] = craft.get_moving_interior_component().is_occupant_registered(game.player)
	return observed


func _run_busy_exit(game: GameFlow, store: UserDataStore, entry: String) -> void:
	var main_id := game.get_instance_id()
	var craft := game.get_node("BulwarkHeavyGunship") as HeroShip
	var refused := recovery_context == "exit_refused"
	game.set_physics_process(false)
	if stage == "arm":
		game.call("_on_settings_save_requested")
		game.start_shift()
		game.call("_board_ship", craft)
		_check(await _wait_for_real_pilot(game, craft, 300), "busy exit setup acquires an actual Bulwark pilot")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
		await _position_escort_fixture(game, craft)
		var first := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		var first_arrival := await finish_convoy(game, craft)
		var reset := game.reset_active_activity()
		craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
		var second := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		for _tick in 4:
			craft.global_position = (game.cinder_convoy_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
			game.call("_physics_process", 0.25)
		_check(selected.accepted and first.accepted and first_arrival and reset and second.accepted
			and _convoy_receipts(game) == 1, "busy exit setup earns one real receipt before its distinct second convoy")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		game.set_physics_process(true)
		Input.action_press(&"hover")
		Input.action_press(&"move_forward")
		await _settle_frames(6)
		Input.action_release(&"move_forward")
		Input.action_release(&"hover")
		_check(not bool(craft.get_telemetry().get("landed", true)), "actual thrust clears the hull latch before disclosed home approach placement")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
		craft.global_transform = berth.get_dock_transform().translated_local(Vector3(0.0, 3.0, 0.0))
		craft.velocity = Vector3.ZERO
		game.call("_try_request_landing")
		for _frame in 300:
			if bool(craft.get_telemetry().get("landed", false)) and game.phase == GameFlow.Phase.SHUT_DOWN:
				break
			await _settle_frames(1)
		_check(bool(craft.get_telemetry().get("landed", false)) and game.phase == GameFlow.Phase.SHUT_DOWN,
			"real landing completes at the registered home berth")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		await _settle_frames(int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 3)
		game.set_physics_process(false)
		game.call("_capture_solo_safe_recovery_context")
		var saved := game.save_cinder_convoy_session()
		# Normal orderly shutdown saves these existing independent owners too.
		game.save_cinder_race_session()
		game.save_cinder_patrol_session()
		var before_payload := store.get_snapshot()
		var convoy: Dictionary = before_payload.get(String(SLOT), {})
		var rewards: Dictionary = before_payload.get("game_flow_reward_store", {})
		var boundary := _stored_session_state(store)
		var before_context: Dictionary = before_payload.get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		var before_observed := _busy_exit_observation(game, craft)
		_check(saved.accepted and _docking_context_matches(before_context, craft)
			and before_observed.engine_offline and before_observed.craft_at_home
			and before_observed.berth_occupied_by_craft and before_observed.berth_lease_current
			and before_observed.hatch_reserved_by_player and before_observed.player_at_pilot_seat
			and not before_observed.transition_busy and before_observed.retry_seconds == 0.0
			and _docking_boundary_matches(game, store, convoy, rewards)
			and game.get("_convoy_terminal_reason") == &"landing_requested" and _convoy_receipts(game) == 1,
			"actual occupied home and automatic OFFLINE retain the pilot preference and failed second convoy")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var path := ProjectSettings.globalize_path(str(store.get("_path")))
		var gate := path + ".exit-cut-authorized"
		var before_bytes := FileAccess.get_file_as_bytes(path)
		var before_backup := FileAccess.get_file_as_bytes(path + ".bak")
		var before_generation := store.get_generation()
		get_tree().paused = true
		print("IN_WORLD_EXIT_PREPARED: " + JSON.stringify({"generation": before_generation,
			"recovery_context": recovery_context, "initialization": EXIT_INITIALIZATION,
			"observation": before_observed, "boundary": boundary}))
		# Tree-pause keeps gameplay frozen; this timer alone can observe the
		# driver's gate inside its original arm deadline and independent abort.
		while not FileAccess.file_exists(gate):
			await get_tree().create_timer(0.01, true).timeout
		_check(DirAccess.remove_absolute(gate) == OK, "the owned cut gate is consumed before exit publication")
		if refused:
			_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "a real owned directory refuses the store transaction path")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		get_tree().paused = false
		game.call("_try_exit_ship")
		get_tree().paused = true
		var observed := _busy_exit_observation(game, craft)
		var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		var expected_payload := before_payload.duplicate(true)
		expected_payload[GameFlow.SOLO_SAFE_RECOVERY_SLOT] = before_context if refused else {"mode": "unavailable"}
		_check(observed.transition_busy and observed.disembarking and observed.player_at_pilot_seat
			and observed.hatch_reserved_by_player and observed.engine_offline and observed.landed
			and observed.berth_occupied_by_craft and observed.berth_lease_current
			and store.get_snapshot() == expected_payload
			and store.get_generation() == before_generation + (0 if refused else 1),
			"synchronous busy exterior publication changes only its contracted preference and generation")
		if refused:
			_check(context == before_context and observed.retry_seconds > 0.0
				and FileAccess.get_file_as_bytes(path) == before_bytes
				and FileAccess.get_file_as_bytes(path + ".bak") == before_backup,
				"refused actual publication preserves both exact durable files and schedules retry")
			_check(DirAccess.remove_absolute(path + ".tmp") == OK, "the owned refusal blocker is removed while the exit stays paused")
		else:
			_check(context == {"mode": "unavailable"} and FileAccess.get_file_as_bytes(path + ".bak") == before_bytes,
				"accepted unavailable publication rotates the exact prior primary to backup")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify({"boundary": boundary, "convoy_record": convoy,
			"reward_store": rewards, "receipts": 1, "safe_context": context, "exit_observation": observed,
			"runtime_observation": _interruption_runtime_observation(game), "initialization": EXIT_INITIALIZATION,
			"activity": activity, "recovery_context": recovery_context, "entry": entry,
			"loaded_main_instance_id": main_id}))
		return
	var convoy: Dictionary = store.get_snapshot().get(String(SLOT), {})
	var rewards: Dictionary = store.get_snapshot().get("game_flow_reward_store", {})
	var boundary := _stored_session_state(store)
	var cold_context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	var recovery := game.get_recovery_available_snapshot()
	var crash_events := 0
	for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	_check(_docking_boundary_matches(game, store, convoy, rewards) and crash_events == 1
		and not recovery.is_empty() and recovery.get("state") == "running"
		and (cold_context == {"mode": "unavailable"} if not refused else _docking_context_matches(cold_context, craft))
		and not bool(game.get("_transition_busy")) and not game.player.is_seated(),
		"fresh Boot retains the actual interrupted preference and exact failed convoy without old seat or transition")
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start",
		int(recovery.session_id), int(recovery.startup_generation))
	game.start_shift()
	var control := {}
	if refused:
		_check(await _wait_for_real_pilot(game, craft, 300), "refused publication cold Resume acquires its fresh actual home pilot")
	else:
		await _settle_frames()
	var safe := _busy_exit_observation(game, craft)
	_check(resumed.get("accepted", false) and not safe.transition_busy and not safe.disembarking
		and not safe.landing.active and not safe.landing_request_active and safe.active_landing_berth_id.is_empty()
		and not safe.player_sleeping and not safe.cabin_containment and not safe.solo_crew_seated
		and safe.solo_crew_assignment_empty and not safe.moving_interior_occupant,
		"cold Resume has no stale exterior transition, landing, crew or cabin claims")
	if refused:
		_check(safe.craft_at_home and safe.berth_occupied_by_craft and safe.berth_lease_current
			and safe.player_at_pilot_seat and safe.hatch_reserved_by_player and safe.craft_piloted,
			"retained preference acquires a fresh home berth, pilot seat and hatch owner")
	else:
		_check(game.active_ship == game.ship and not safe.player_seated and not safe.craft_piloted
			and safe.player_on_floor and safe.player_control_enabled and not safe.hatch_reserved_by_player
			and not bool(game.get("_piloting")), "accepted unavailable record falls back to the supported controllable station Player")
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	var start := game.player.global_position
	Input.action_press(&"move_forward")
	await _settle_frames(2 if refused else 24)
	Input.action_release(&"move_forward")
	if refused:
		control = {"engine_online": str(craft.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE",
			"throttle": craft.get_last_ship_command().throttle, "physics_ticks": 2}
		_check(control.engine_online and control.throttle > 0.0, "ordinary two-tick throttle drives the freshly recovered real pilot")
	else:
		control = {"distance_m": game.player.global_position.distance_to(start), "physics_ticks": 24,
			"supported": game.player.is_on_floor() and game.player.is_control_enabled() and not game.player.is_seated()}
		_check(control.distance_m > 0.1 and control.supported, "ordinary twenty-four-tick station walking moves on the actual floor")
		game.call("_capture_solo_safe_recovery_context")
	_check(_docking_boundary_matches(game, store, convoy, rewards) and _convoy_receipts(game) == 1,
		"ordinary recovered control preserves the exact failed second convoy, debt and first receipt")
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	var closed := game.mark_orderly_shutdown()
	_check(closed.get("accepted", false) and game.get_instance_id() == main_id,
		"the recovered Boot owner closes both existing clean markers")
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	print("IN_WORLD_RECOVERY_OK: " + JSON.stringify({"boundary": boundary, "convoy_record": convoy,
		"reward_store": rewards, "receipts_before": 1, "receipts_after": _convoy_receipts(game),
		"crash_events": crash_events, "safe_context": cold_context, "safe_recovery_observation": safe,
		"control_observation": control, "runtime_observation": _interruption_runtime_observation(game),
		"initialization": EXIT_INITIALIZATION, "continuation_method": "ordinary_cold_home_pilot_two_tick_throttle" if refused else "ordinary_cold_station_twenty_four_tick_walk",
		"activity": activity, "recovery_context": recovery_context, "entry": entry,
		"loaded_main_instance_id": main_id, "assertions": _assertions}))
	get_tree().quit(0)


## Fault only the existing reward transaction; every checkpoint and recovery
## marker still delegates to the actual store's original disk filesystem.
class ActivityRewardFault extends UserDataFilesystem:
	var filesystem: UserDataFilesystem
	var rejected := false
	var target_activity: String

	func _init(original: UserDataFilesystem, target := String(CinderBeaconTraversalActivity.ACTIVITY_ID)) -> void:
		filesystem = original
		target_activity = target

	func file_exists(path: String) -> bool:
		return filesystem.file_exists(path)

	func directory_exists(path: String) -> bool:
		return filesystem.directory_exists(path)

	func ensure_parent_directory(path: String) -> Error:
		return filesystem.ensure_parent_directory(path)

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		return filesystem.read_bytes(path, maximum_bytes)

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-"):
			var receipt: Dictionary = document.get("payload", {}).get("game_flow_reward_store", {}).get("last_receipt", {})
			if receipt.get("activity_id") == target_activity:
				rejected = true
				return ERR_UNAVAILABLE
		return filesystem.write_bytes_and_flush(path, bytes)

	func sync_file(path: String) -> Error:
		return filesystem.sync_file(path)

	func sync_directory(path: String) -> Error:
		return filesystem.sync_directory(path)

	func remove_path(path: String) -> Error:
		return filesystem.remove_path(path)

	func rename_path(from_path: String, to_path: String) -> Error:
		return filesystem.rename_path(from_path, to_path)


func _beacon_receipts(game: GameFlow) -> int:
	var record: Dictionary = game.get_activity_reward_report().authority.record
	return int(record.reward_counts.get(String(CinderBeaconTraversalActivity.REWARD_ID), 0))


## These observers retain only event values. They never print or mutate streaming.
## Either scene owner exiting also disconnects an abandoned awaiting lookup.
class StreamBindingObservation extends RefCounted:
	var events: Array[Dictionary] = []
	var _connections: Array[Dictionary] = []

	func _init(probe: Node, game: GameFlow, coordinator: WorldStreamingCoordinator) -> void:
		var recorded_events := events
		_listen(coordinator.location_load_started, func(id: StringName, generation: int):
			recorded_events.append({"event": "load_started", "location_id": id, "generation": generation}))
		_listen(coordinator.location_loaded, func(id: StringName, generation: int, node: Node3D):
			recorded_events.append({"event": "loaded", "location_id": id, "generation": generation,
				"instance_id": node.get_instance_id()}))
		_listen(coordinator.location_load_failed, func(id: StringName, generation: int, reason: StringName):
			recorded_events.append({"event": "load_failed", "location_id": id, "generation": generation, "reason": reason}))
		_listen(coordinator.location_unloaded, func(id: StringName, generation: int):
			recorded_events.append({"event": "unloaded", "location_id": id, "generation": generation}))
		_listen(probe.tree_exiting, disconnect_observers)
		_listen(game.tree_exiting, disconnect_observers)

	func _listen(observed_signal: Signal, callback: Callable) -> void:
		observed_signal.connect(callback)
		_connections.append({"signal": observed_signal, "callback": callback})

	func disconnect_observers() -> void:
		for connection in _connections:
			var observed_signal: Signal = connection.signal
			if is_instance_valid(observed_signal.get_object()) \
					and observed_signal.is_connected(connection.callback):
				observed_signal.disconnect(connection.callback)
		_connections.clear()


func _stream_binding_node_diagnostic(node: Node) -> Dictionary:
	if not is_instance_valid(node):
		return {"valid": false}
	var script := node.get_script() as Script
	return {"valid": true, "instance_id": node.get_instance_id(), "class": node.get_class(),
		"inside_tree": node.is_inside_tree(), "queued_for_deletion": node.is_queued_for_deletion(),
		"script_path": script.resource_path if script != null else "",
		"is_cinder_bootstrap": node is CinderStreamingBootstrap,
		"is_nearby_cluster": node is NearbySectorCluster,
		"is_activity_binding": node is NearbySectorActivityBinding}


func _report_stream_binding_failure(game: GameFlow, activity_label: String,
		update: Dictionary, observation: StreamBindingObservation, elapsed_ms: int) -> void:
	var world := game.world
	var host := world.get_parent() if is_instance_valid(world) else null
	var world_bootstrap := host.get_node_or_null(^"CinderStreamingBootstrap") if is_instance_valid(host) else null
	var loaded := game.cinder_streaming_bootstrap.get_loaded_instance()
	var direct_child := loaded.get_node_or_null(^"ActivityBinding") if is_instance_valid(loaded) else null
	var world_cluster := world.call("get_nearby_sector_cluster") as Node if is_instance_valid(world) else null
	var consumer_binding := game.call("_get_nearby_activity_binding") as Node
	print("IN_WORLD_STREAM_BINDING_FAILED: " + JSON.stringify({
		"activity": activity_label, "idle_polls": 180, "elapsed_ms": elapsed_ms,
		"update": update, "generation_events": observation.events,
		"main_instance_id": game.get_instance_id(), "main_physics_processing": game.is_physics_processing(),
		"bootstrap": game.cinder_streaming_bootstrap.get_snapshot(),
		"production_binding": game.cinder_streaming_binding.get_snapshot(),
		"coordinator": game.cinder_streaming_coordinator.audit(),
		"world": _stream_binding_node_diagnostic(world),
		"main_bootstrap": _stream_binding_node_diagnostic(game.cinder_streaming_bootstrap),
		"world_bootstrap": _stream_binding_node_diagnostic(world_bootstrap),
		"loaded_cluster": _stream_binding_node_diagnostic(loaded),
		"world_cluster": _stream_binding_node_diagnostic(world_cluster),
		"direct_activity_child": _stream_binding_node_diagnostic(direct_child),
		"consumer_binding": _stream_binding_node_diagnostic(consumer_binding)}))


func _load_beacon_binding(game: GameFlow, activity_label := "beacon") -> NearbySectorActivityBinding:
	var observation := StreamBindingObservation.new(self, game, game.cinder_streaming_coordinator)
	var started_ms := Time.get_ticks_msec()
	var update := game.cinder_streaming_bootstrap.update_position(CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR)
	var binding: NearbySectorActivityBinding
	for _frame in 180:
		binding = game.call("_get_nearby_activity_binding") as NearbySectorActivityBinding
		if is_instance_valid(binding):
			break
		await get_tree().process_frame
	observation.disconnect_observers()
	if not is_instance_valid(binding):
		_report_stream_binding_failure(game, activity_label, update, observation, Time.get_ticks_msec() - started_ms)
	_check(is_instance_valid(binding), "Boot Main streams the actual %s activity owner" % activity_label)
	game.call("_sync_activity_hud")
	return binding


func _beacon_start(game: GameFlow) -> void:
	for row in (game.hud.get("_nearby_activity_rows") as VBoxContainer).get_children():
		if "cinder_debris_beacon_traversal" in str(row.name):
			(row.get_child(2) as Button).emit_signal("pressed")
			return
	_check(false, "the actual nearby HUD exposes its beacon Start action")


func _run_beacon(game: GameFlow, store: UserDataStore, entry: String) -> void:
	if recovery_context != "pilot":
		_fail("beacon interruption supports the actual pilot recovery context only")
		return
	var main_id := game.get_instance_id()
	game.set_physics_process(false)
	var craft: HeroShip
	if stage == "arm":
		game.call("_on_settings_save_requested")
		craft = game.get_flyable_ships()[1] as HeroShip
		game.canopy_motion_time = 0.01
		game.boarding_motion_time = 0.02
		game.start_shift()
		game.call("_board_ship", craft)
		_check(await _wait_for_real_pilot(game, craft), "beacon arm acquires the real Player pilot before route positioning")
		var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		_check(context.get("mode") == "pilot" and context.get("craft_id") == String(craft.get_ship_id()),
			"beacon arm saves its exact real safe-home pilot context before interruption")
		var binding := await _load_beacon_binding(game)
		if not is_instance_valid(binding):
			get_tree().quit(1)
			return
		var baseline := _beacon_receipts(game)
		var fault := ActivityRewardFault.new(store.get("_filesystem") as UserDataFilesystem)
		store.set("_filesystem", fault)
		craft.global_position = game.call("_cinder_authored_frame_to_world", CinderBeaconTraversalActivity.BEACONS[0])
		_beacon_start(game)
		for point in CinderBeaconTraversalActivity.BEACONS:
			craft.global_position = game.call("_cinder_authored_frame_to_world", point)
			game.call("_advance_cinder_beacon_traversal", 0.0, game.call("_capture_cinder_actor_sample"))
		var boundary: Dictionary = store.get_snapshot().get("cinder_beacon_session", {})
		var live := binding.get_activity_snapshot(&"beacon_traversal")
		_check(CinderBeaconTraversalActivity.validate_persistence_record(boundary).accepted
			and fault.rejected and live.state_id == &"complete" and not live.reward_requested
			and live.reward_pending and _beacon_receipts(game) == baseline
			and boundary == binding.capture_beacon_traversal_session()
			and boundary.activities[0].reward_requested and not boundary.activities[0].reward_granted,
			"ordered production beacon samples leave an exact valid unpaid checkpoint after a real reward-write refusal")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var ready := {"boundary": boundary, "receipts": baseline, "activity": activity,
			"runtime_observation": _interruption_runtime_observation(game),
			"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
		get_tree().paused = true
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify(ready))
		return
	var boundary: Dictionary = store.get_snapshot().get("cinder_beacon_session", {})
	var binding := await _load_beacon_binding(game)
	if not is_instance_valid(binding) or not CinderBeaconTraversalActivity.validate_persistence_record(boundary).accepted:
		_fail("restart requires the actual valid durable beacon terminal")
		return
	var live := binding.get_activity_snapshot(&"beacon_traversal")
	var observations := _interruption_runtime_observation(game)
	var recovery := game.get_recovery_available_snapshot()
	var crash_events := 0
	for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	_check(live.state_id == &"complete" and live.reward_pending and not live.reward_requested
		and boundary == binding.capture_beacon_traversal_session() and crash_events == 1
		and not recovery.is_empty() and recovery.get("state") == "running",
		"a fresh Boot process restores only the genuine unpaid beacon checkpoint and one crash event")
	var baseline := _beacon_receipts(game)
	var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	for candidate in game.get_flyable_ships():
		if String(candidate.get_ship_id()) == context.get("craft_id"):
			craft = candidate
	if craft == null or not _failures.is_empty():
		_fail("the saved pilot context must resolve an actual shipped craft before Resume")
		return
	var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start", int(recovery.session_id), int(recovery.startup_generation))
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.start_shift()
	var settled := await _wait_for_real_pilot(game, craft)
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	_check(resumed.get("accepted", false) and settled and area.get_reservation_token() == game.player
		and berth.get_occupant() == craft and berth.get_reservation_owner() == craft
		and boundary == store.get_snapshot().cinder_beacon_session and boundary == binding.capture_beacon_traversal_session(),
		"ordinary Resume reacquires the real safe-home pilot and preserves the exact unpaid boundary before retry")
	Input.action_press(&"move_forward")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"move_forward")
	_check(str(craft.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE" and craft.get_last_ship_command().throttle > 0.0
		and boundary == store.get_snapshot().cinder_beacon_session,
		"the recovered real pilot accepts ordinary flight input without mutating unpaid beacon progress")
	var safe_observation := _interruption_runtime_observation(game)
	_beacon_start(game)
	var paid: Dictionary = store.get_snapshot().cinder_beacon_session
	_check(_beacon_receipts(game) == baseline + 1 and paid.activities[0].reward_granted
		and binding.get_activity_snapshot(&"beacon_traversal").reward_committed,
		"ordinary HUD Start publishes one beacon payment and its existing atomic acknowledgement")
	var duplicate := binding.request_beacon_traversal_reward()
	var stale: Dictionary = game.call("_commit_game_flow_activity_reward", {
		"activity_id": CinderBeaconTraversalActivity.ACTIVITY_ID,
		"activity_generation": int(boundary.activities[0].generation),
		"reward_id": CinderBeaconTraversalActivity.REWARD_ID, "reward_authority": false, "granted": false,
	})
	_check(not duplicate.accepted and not stale.accepted and _beacon_receipts(game) == baseline + 1
		and paid == store.get_snapshot().cinder_beacon_session,
		"duplicate and late terminal callbacks cannot pay again or change the saved beacon acknowledgement")
	var closed := game.mark_orderly_shutdown()
	_check(closed.get("accepted", false), "beacon restart closes both existing recovery marker owners")
	_check(is_instance_valid(game) and game.get_instance_id() == main_id and game.get_tree() == get_tree(),
		"beacon recovery retains Boot's exact supplied Main owner")
	var outcome := {"boundary": boundary, "paid_boundary": paid, "receipts_before": baseline,
		"receipts_after": _beacon_receipts(game), "crash_events": crash_events, "activity": activity,
		"runtime_observation": observations, "safe_recovery_observation": safe_observation,
		"continuation_method": "real_safe_home_pilot_resume_then_ordinary_beacon_start_retry",
		"assertions": _assertions, "entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify(outcome))
		get_tree().quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)


func _scan_receipts(game: GameFlow) -> int:
	var record: Dictionary = game.get_activity_reward_report().authority.record
	return int(record.reward_counts.get(String(CinderAbandonedStructureScanActivity.REWARD_ID), 0))


func _scan_start(game: GameFlow) -> void:
	for row in (game.hud.get("_nearby_activity_rows") as VBoxContainer).get_children():
		if row.get_meta(&"activity_id", &"") == CinderAbandonedStructureScanActivity.ACTIVITY_ID:
			var button := row.get_child(2) as Button
			_check(not button.disabled, "the actual nearby HUD exposes an enabled scan Start action")
			if not button.disabled:
				button.emit_signal("pressed")
			return
	_check(false, "the actual nearby HUD exposes its scan Start action")


func _run_scan(game: GameFlow, store: UserDataStore, entry: String) -> void:
	if recovery_context != "pilot":
		_fail("scan interruption supports the actual pilot recovery context only")
		return
	var main_id := game.get_instance_id()
	game.set_physics_process(false)
	var craft: HeroShip
	if stage == "arm":
		game.call("_on_settings_save_requested")
		_check(game.cargo_delivery_activity.start(game.cargo_delivery_activity.get_generation()).accepted
			and game.save_jovian_cargo_session().accepted, "the actual cargo owner saves unrelated cargo progress")
		craft = game.get_flyable_ships()[1] as HeroShip
		game.canopy_motion_time = 0.01
		game.boarding_motion_time = 0.02
		game.start_shift()
		game.call("_board_ship", craft)
		_check(await _wait_for_real_pilot(game, craft), "scan arm acquires the real Player pilot before approach positioning")
		var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		_check(context.get("mode") == "pilot" and context.get("craft_id") == String(craft.get_ship_id()),
			"scan arm saves its exact real safe-home pilot context before interruption")
		var binding := await _load_beacon_binding(game, "scan")
		if not is_instance_valid(binding):
			get_tree().quit(1)
			return
		var baseline := _scan_receipts(game)
		var original := store.get("_filesystem") as UserDataFilesystem
		var fault := ActivityRewardFault.new(original, String(CinderAbandonedStructureScanActivity.ACTIVITY_ID))
		store.set("_filesystem", fault)
		# Bounded position/time fixture: the actual seated craft samples the authored
		# approach; Main and the scan owner retain all progression/payment authority.
		craft.global_position = game.call("_cinder_authored_frame_to_world", CinderAbandonedStructureScanActivity.APPROACH_ANCHOR)
		_scan_start(game)
		game.call("_advance_cinder_structure_scan", 0.5, game.call("_capture_cinder_actor_sample"))
		var progress: Dictionary = store.get_snapshot().get("cinder_structure_scan_session", {})
		_check(CinderAbandonedStructureScanActivity.validate_persistence_record(progress).accepted
			and progress.activities[0].progress.elapsed_seconds == 0.5
			and progress == binding.capture_structure_scan_session(), "actual approach samples checkpoint genuine partial scan progress")
		game.call("_advance_cinder_structure_scan", CinderAbandonedStructureScanActivity.SCAN_SECONDS - 0.5, game.call("_capture_cinder_actor_sample"))
		var boundary: Dictionary = store.get_snapshot().get("cinder_structure_scan_session", {})
		var live := binding.get_activity_snapshot(&"structure_scan")
		_check(CinderAbandonedStructureScanActivity.validate_persistence_record(boundary).accepted
			and fault.rejected and live.state_id == &"complete" and not live.reward_requested
			and _scan_receipts(game) == baseline
			and boundary == binding.capture_structure_scan_session()
			and boundary.activities[0].reward_requested and not boundary.activities[0].reward_granted,
			"timed production scan samples leave an exact valid unpaid checkpoint after a real reward-write refusal")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var ready := {"boundary": boundary, "receipts": baseline, "activity": activity,
			"foreign_settings": store.get_snapshot().runtime_settings, "foreign_cargo": store.get_snapshot().jovian_cargo_session,
			"fixture_method": "real_pilot_authored_scan_approach_and_production_elapsed_samples",
			"runtime_observation": _interruption_runtime_observation(game),
			"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
		get_tree().paused = true
		store.set("_filesystem", original)
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify(ready))
		return
	var boundary: Dictionary = store.get_snapshot().get("cinder_structure_scan_session", {})
	var binding := await _load_beacon_binding(game, "scan")
	if not is_instance_valid(binding) or not CinderAbandonedStructureScanActivity.validate_persistence_record(boundary).accepted:
		_fail("restart requires the actual valid durable scan terminal")
		return
	if int(boundary.activities[0].state) != CinderAbandonedStructureScanActivity.State.COMPLETE or boundary.activities[0].reward_granted:
		_fail("restart requires a genuinely completed unpaid scan checkpoint")
		return
	var foreign_settings: Dictionary = store.get_snapshot().runtime_settings
	var foreign_cargo: Dictionary = store.get_snapshot().jovian_cargo_session
	var live := binding.get_activity_snapshot(&"structure_scan")
	var observations := _interruption_runtime_observation(game)
	var recovery := game.get_recovery_available_snapshot()
	var crash_events := 0
	for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	_check(live.state_id == &"complete" and not live.reward_requested
		and boundary == binding.capture_structure_scan_session() and crash_events == 1
		and not recovery.is_empty() and recovery.get("state") == "running",
		"a fresh Boot process restores only the genuine unpaid scan checkpoint and one crash event")
	var baseline := _scan_receipts(game)
	var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	for candidate in game.get_flyable_ships():
		if String(candidate.get_ship_id()) == context.get("craft_id"):
			craft = candidate
	if craft == null or not _failures.is_empty():
		_fail("the saved pilot context must resolve an actual shipped craft before Resume")
		return
	var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start", int(recovery.session_id), int(recovery.startup_generation))
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.start_shift()
	var settled := await _wait_for_real_pilot(game, craft)
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	_check(resumed.get("accepted", false) and settled and area.get_reservation_token() == game.player
		and berth.get_occupant() == craft and berth.get_reservation_owner() == craft
		and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1
		and boundary == store.get_snapshot().cinder_structure_scan_session and boundary == binding.capture_structure_scan_session(),
		"ordinary Resume reacquires the real safe-home pilot and preserves the exact unpaid boundary before retry")
	Input.action_press(&"move_forward")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"move_forward")
	_check(str(craft.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE" and craft.get_last_ship_command().throttle > 0.0
		and boundary == store.get_snapshot().cinder_structure_scan_session,
		"the recovered real pilot accepts ordinary flight input without mutating unpaid scan progress")
	var safe_observation := _interruption_runtime_observation(game)
	game.call("_sync_activity_hud")
	_scan_start(game)
	var paid: Dictionary = store.get_snapshot().cinder_structure_scan_session
	_check(_scan_receipts(game) == baseline + 1 and paid.activities[0].reward_granted
		and binding.get_activity_snapshot(&"structure_scan").reward_committed,
		"ordinary HUD Start publishes one scan payment and its existing atomic acknowledgement")
	var duplicate := binding.request_structure_scan_reward()
	var stale: Dictionary = game.call("_request_cinder_structure_scan_reward", binding)
	_check(not duplicate.accepted and not stale.accepted and _scan_receipts(game) == baseline + 1
		and paid == store.get_snapshot().cinder_structure_scan_session,
		"duplicate and late terminal callbacks cannot pay again or change the saved scan acknowledgement")
	_check(foreign_settings == store.get_snapshot().runtime_settings and foreign_cargo == store.get_snapshot().jovian_cargo_session,
		"scan recovery preserves actual settings and unrelated cargo progress")
	var closed := game.mark_orderly_shutdown()
	_check(closed.get("accepted", false), "scan restart closes both existing recovery marker owners")
	_check(is_instance_valid(game) and game.get_instance_id() == main_id and game.get_tree() == get_tree(),
		"scan recovery retains Boot's exact supplied Main owner")
	var outcome := {"boundary": boundary, "paid_boundary": paid, "receipts_before": baseline,
		"receipts_after": _scan_receipts(game), "crash_events": crash_events, "activity": activity,
		"runtime_observation": observations, "safe_recovery_observation": safe_observation,
		"continuation_method": "real_safe_home_pilot_resume_then_ordinary_scan_start_retry",
		"foreign_settings": foreign_settings, "foreign_cargo": foreign_cargo,
		"assertions": _assertions, "entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify(outcome))
		get_tree().quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)


func _mining_start(game: GameFlow) -> void:
	for row in (game.hud.get("_nearby_activity_rows") as VBoxContainer).get_children():
		if row.get_meta(&"activity_id", &"") == CinderMiningPlatformActivity.ACTIVITY_ID:
			var button := row.get_child(2) as Button
			_check(not button.disabled, "the actual nearby HUD exposes an enabled mining Start action")
			if not button.disabled:
				button.emit_signal("pressed")
			return
	_check(false, "the actual nearby HUD exposes its mining Start action")


## Pilot-only capability probe. The extraction owner publishes its genuine
## six-second completion before a real transaction-path directory refuses the
## ordinary HUD capacity save. No persisted activity or debt is invented here.
func _run_mining(game: GameFlow, store: UserDataStore, entry: String) -> void:
	if recovery_context != "pilot":
		_fail("mining interruption supports the actual pilot recovery context only")
		return
	var main_id := game.get_instance_id()
	game.set_physics_process(false)
	var craft: HeroShip
	var path := str(store.get("_path"))
	if stage == "arm":
		game.call("_on_settings_save_requested")
		var payload := store.get_snapshot()
		payload["mining_probe_foreign_cargo"] = {"cargo_note": "retain this unrelated cargo field"}
		_check(store.commit(payload, store.get_generation(), "mining-probe-foreign-cargo").accepted,
			"the actual profile retains an unrelated cargo fixture beside production settings")
		craft = game.get_flyable_ships()[1] as HeroShip
		game.canopy_motion_time = 0.01
		game.boarding_motion_time = 0.02
		game.start_shift()
		game.call("_board_ship", craft)
		_check(await _wait_for_real_pilot(game, craft), "mining arm acquires the real Player pilot before extraction positioning")
		var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		_check(context.get("mode") == "pilot" and context.get("craft_id") == String(craft.get_ship_id()),
			"mining arm saves its exact real safe-home pilot context before interruption")
		var binding := await _load_beacon_binding(game, "mining")
		if not is_instance_valid(binding) or not _failures.is_empty():
			get_tree().quit(1)
			return
		craft.global_position = game.call("_cinder_authored_frame_to_world", CinderMiningPlatformActivity.APPROACH_ANCHOR)
		_mining_start(game)
		var completed := binding.advance_mining_activity_from_caller_sample(
			CinderMiningPlatformActivity.EXTRACTION_SECONDS, CinderMiningPlatformActivity.APPROACH_ANCHOR)
		var boundary: Dictionary = store.get_snapshot().get("cinder_mining_capacity", {})
		_check(completed.accepted and completed.reason == &"complete" and boundary.get("schema_version") == 2
			and boundary.get("capacity", {}).is_empty() and boundary.get("session", {}).get("state") == CinderMiningPlatformActivity.State.COMPLETE
			and boundary.session.generation == 1 and boundary.session.elapsed_seconds == CinderMiningPlatformActivity.EXTRACTION_SECONDS
			and not boundary.session.reward_requested and not boundary.session.capacity_paid,
			"the real extraction owner durably publishes genuine generation-one full unpaid completion")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var before := FileAccess.get_file_as_bytes(path)
		_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "the actual store transaction path is blocked by a real directory")
		_mining_start(game)
		var live := binding.get_activity_snapshot(&"mining")
		_check(live.state_id == &"complete" and live.generation == 1 and live.reward_requested
			and live.get("persistence_retry_available", false) and not live.get("capacity_persisted", false)
			and FileAccess.get_file_as_bytes(path) == before
			and binding.get_cinder_mining_capacity_persistence_snapshot().last_result.reason == &"transaction_path_is_directory",
			"ordinary HUD Start genuinely refuses capacity publication while preserving the unpaid terminal file")
		get_tree().paused = true
		_check(DirAccess.remove_absolute(path + ".tmp") == OK and FileAccess.get_file_as_bytes(path) == before,
			"the blockage is removed with the genuine owed state paused and no orderly save")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var ready := {"boundary": boundary, "receipts": 0, "activity": activity,
			"foreign_settings": store.get_snapshot().get("runtime_settings", {}),
			"foreign_cargo": store.get_snapshot().mining_probe_foreign_cargo,
			"runtime_observation": _interruption_runtime_observation(game),
			"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify(ready))
		return
	var boundary: Dictionary = store.get_snapshot().get("cinder_mining_capacity", {})
	var foreign_settings: Dictionary = store.get_snapshot().get("runtime_settings", {})
	var foreign_cargo: Dictionary = store.get_snapshot().get("mining_probe_foreign_cargo", {})
	var binding := await _load_beacon_binding(game, "mining")
	if not is_instance_valid(binding):
		get_tree().quit(1)
		return
	var persistence := binding.get("_mining_capacity_persistence") as RefCounted
	if persistence == null or not bool((persistence.call("validate_record", boundary) as Dictionary).get("accepted", false)) \
			or boundary.get("schema_version") != 2:
		_fail("mining restart requires an existing valid durable extraction checkpoint")
		return
	if int(boundary.session.state) != CinderMiningPlatformActivity.State.COMPLETE or bool(boundary.session.capacity_paid):
		_fail("mining restart requires a genuine complete unpaid extraction")
		return
	var live := binding.get_activity_snapshot(&"mining")
	var genuine_snapshot := (binding.get("_mining_activity") as RefCounted).call("get_snapshot") as Dictionary
	var observations := _interruption_runtime_observation(game)
	var recovery := game.get_recovery_available_snapshot()
	var crash_events := 0
	for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	_check(live.state_id == &"complete" and live.generation == 1 and live.elapsed_seconds == CinderMiningPlatformActivity.EXTRACTION_SECONDS
		and live.get("persistence_retry_available", false) and not live.get("capacity_persisted", false)
		and boundary.session.state == CinderMiningPlatformActivity.State.COMPLETE and not boundary.session.capacity_paid
		and boundary.capacity.is_empty() and crash_events == 1 and not recovery.is_empty() and recovery.get("state") == "running",
		"a fresh Boot process restores the genuine unpaid mining completion and one crash event")
	var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	for candidate in game.get_flyable_ships():
		if String(candidate.get_ship_id()) == context.get("craft_id"):
			craft = candidate
	if craft == null or not _failures.is_empty():
		_fail("the saved mining pilot context must resolve an actual shipped craft before Resume")
		return
	var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start", int(recovery.session_id), int(recovery.startup_generation))
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.start_shift()
	var settled := await _wait_for_real_pilot(game, craft)
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	_check(resumed.get("accepted", false) and settled and area.get_reservation_token() == game.player
		and berth.get_occupant() == craft and berth.get_reservation_owner() == craft
		and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1
		and boundary == store.get_snapshot().cinder_mining_capacity,
		"ordinary Resume reacquires the real safe-home pilot and preserves exact unpaid mining progress")
	Input.action_press(&"move_forward")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"move_forward")
	_check(str(craft.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE" and craft.get_last_ship_command().throttle > 0.0
		and boundary == store.get_snapshot().cinder_mining_capacity,
		"the recovered real pilot accepts ordinary throttle without mutating unpaid mining progress")
	var safe_observation := _interruption_runtime_observation(game)
	game.call("_sync_activity_hud")
	var before_generation := store.get_generation()
	_mining_start(game)
	var paid: Dictionary = store.get_snapshot().cinder_mining_capacity
	var capacity_commits := store.get_generation() - before_generation
	_check(capacity_commits == 1 and paid.session.capacity_paid and paid.session.reward_requested
		and paid.session.generation == boundary.session.generation and paid.session.elapsed_seconds == boundary.session.elapsed_seconds
		and paid.capacity.reward_receipt.granted == false and paid.capacity.reward_receipt.replay_allowed == false
		and binding.get_activity_snapshot(&"mining").get("capacity_persisted", false),
		"ordinary HUD Start atomically publishes capacity and the same generation paid acknowledgement once")
	var bytes := FileAccess.get_file_as_bytes(path)
	var duplicate := binding.request_mining_reward()
	var late := binding.retry_mining_capacity_persistence()
	var stale := persistence.call("save_session", genuine_snapshot, false, {}, "mining-probe-late-unpaid") as Dictionary
	_check(not duplicate.accepted and not late.accepted and not stale.accepted
		and stale.reason == &"mining_session_stale" and paid == store.get_snapshot().cinder_mining_capacity
		and FileAccess.get_file_as_bytes(path) == bytes and store.get_generation() == before_generation + 1,
		"duplicate and genuine late unpaid callbacks are refused without another capacity commit")
	_check(not foreign_settings.is_empty() and not foreign_cargo.is_empty()
		and foreign_settings == store.get_snapshot().get("runtime_settings", {})
		and foreign_cargo == store.get_snapshot().get("mining_probe_foreign_cargo", {}),
		"mining recovery preserves production settings and unrelated cargo fields")
	var closed := game.mark_orderly_shutdown()
	_check(closed.get("accepted", false), "mining restart closes both existing recovery marker owners")
	_check(is_instance_valid(game) and game.get_instance_id() == main_id and game.get_tree() == get_tree(),
		"mining recovery retains Boot's exact supplied Main owner")
	var outcome := {"boundary": boundary, "paid_boundary": paid, "receipts_before": 0, "receipts_after": 1,
		"capacity_commits": capacity_commits, "crash_events": crash_events, "activity": activity,
		"foreign_settings": foreign_settings, "foreign_cargo": foreign_cargo,
		"runtime_observation": observations, "safe_recovery_observation": safe_observation,
		"continuation_method": "real_safe_home_pilot_resume_then_ordinary_mining_start_retry",
		"assertions": _assertions, "entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify(outcome))
		get_tree().quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)


## Heavy Breach terminal recovery only. Placement, shortened boarding and direct
## damage on the real picket are disclosed fixtures, not ordinary combat proof.
const BREACH_FIXTURE := "staged_on_foot_board_and_Arrow_entry_shortened_boarding_real_departure_then_direct_damage_on_real_charged_picket"


func _disconnect_breach_payment_observer() -> void:
	if is_instance_valid(_breach_payment_board) and _breach_payment_observer.is_valid() \
			and _breach_payment_board.interaction_resolved.is_connected(_breach_payment_observer):
		_breach_payment_board.interaction_resolved.disconnect(_breach_payment_observer)
	_breach_payment_board = null
	_breach_payment_observer = Callable()


func _exit_tree() -> void:
	_disconnect_breach_payment_observer()


## Read the primary synchronously at the board's completed physical admission.
## GameFlow can save the next sortie's tutorial after arm_sortie returns.
func _capture_breach_payment(actor: Node, result: Dictionary, expected_actor: Node,
		expected_generation: int, store: UserDataStore, capture: Dictionary) -> void:
	if not capture.is_empty() or actor != expected_actor or not bool(result.get("accepted", false)) \
			or result.get("reason") != &"sortie_armed" \
			or int(result.get("generation", -1)) != expected_generation:
		return
	capture.document_json = FileAccess.get_file_as_string(str(store.get("_path")))
	capture.commit = store.get_commit_metadata()
	capture.store_generation = store.get_generation()


func _breach_receipts(game: GameFlow) -> int:
	var record: Dictionary = game.get_activity_reward_report().authority.record
	return int(record.reward_counts.get(String(HeavyBreachActivityBoard.REWARD_ID), 0))


func _breach_wait(predicate: Callable) -> bool:
	for _frame in 240:
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
		await get_tree().process_frame
	return bool(predicate.call())


func _breach_board_fixture(game: GameFlow, board: HeavyBreachActivityBoard) -> bool:
	game.player.teleport_to(Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP),
		board.global_position + Vector3(0.0, 0.0, 2.0)))
	return await _breach_wait(func() -> bool: return game.station_interaction_candidate == board)


## Match the passing Heavy Breach production route's one-physics-tick pulse.
## This caller normalization does not establish the original failure's cause.
func _breach_press_interaction() -> void:
	Input.action_press(&"interact")
	await get_tree().physics_frame
	Input.action_release(&"interact")
	await get_tree().physics_frame
	await get_tree().process_frame


func _run_breach(game: GameFlow, store: UserDataStore, entry: String) -> void:
	if recovery_context != "pilot":
		_fail("Heavy Breach terminal interruption requires the supported pilot context")
		return
	var main_id := game.get_instance_id()
	var board := game.world.get_heavy_breach_activity_board() as HeavyBreachActivityBoard
	var director := game.get_node_or_null(^"EncounterScenarios") as EncounterScenarioDirector
	var craft := game.get_node_or_null(^"ArrowReconShip") as HeroShip
	if board == null or director == null or craft == null:
		_fail("Boot Main must own the real Heavy Breach board, director and Arrow")
		return
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.04
	game.disembarking_motion_time = 0.04
	if stage == "arm":
		game.call("_on_settings_save_requested")
		# Generation zero has no durable cargo record. The genuine synchronous
		# start/reset signals save a supported document and leave its clock idle
		# before any await or Heavy Breach admission; no transfer is manufactured.
		var cargo_started := game.cargo_delivery_activity.start(game.cargo_delivery_activity.get_generation())
		var cargo_reset := game.cargo_delivery_activity.reset(game.cargo_delivery_activity.get_generation())
		var cargo_saved := game.save_jovian_cargo_session()
		_check(cargo_started.accepted and cargo_reset.accepted and cargo_saved.accepted
			and game.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
			and store.get_snapshot().has("jovian_cargo_session"),
			"the genuine start/reset cargo owner saves actual unrelated idle activity payload beside Heavy Breach")
		game.start_shift()
		await get_tree().process_frame
		_check(await _breach_board_fixture(game, board), "the staged on-foot Player discovers the real Heavy Breach board")
		await _breach_press_interaction()
		_check(board.is_sortie_armed() and board.get_offered_scenario() == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH
			and director.get_state() == EncounterScenarioDirector.STATE_IDLE,
			"the production board arms Heavy Breach without starting combat against the avatar: %s" % JSON.stringify(board.get_snapshot()))
		game.player.teleport_to(Transform3D(Basis.IDENTITY, craft.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
		_check(await _breach_wait(func() -> bool: return game.boarding_candidate == craft),
			"the staged Arrow entry resolves through the production boarding sensor")
		await _breach_press_interaction()
		_check(await _wait_for_real_pilot(game, craft, 240), "the real Arrow seat settles before the Heavy Breach departure")
		Input.action_press(&"move_forward")
		var launched := await _breach_wait(func() -> bool:
			return game.phase == GameFlow.Phase.FREE_FLIGHT and director.is_running())
		Input.action_release(&"move_forward")
		_check(launched and director.get_active_scenario() == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH
			and int(board.get_snapshot().active_director_generation) > 0,
			"real Arrow departure launches the board-owned Heavy Breach director generation")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var original := store.get("_filesystem") as UserDataFilesystem
		var fault := ActivityRewardFault.new(original, String(HeavyBreachActivityBoard.ACTIVITY_ID))
		store.set("_filesystem", fault)
		var picket := game.get_node_or_null(^"StandoffPicket") as StandoffPicketOpponent
		_check(picket != null, "the genuine Heavy Breach encounter owns its real charged picket")
		if picket != null:
			picket.apply_damage(picket.maximum_health, picket.global_position)
		_check(await _breach_wait(func() -> bool: return director.is_concluded()),
			"the disclosed direct target-damage fixture concludes the actual director-owned encounter")
		var boundary: Dictionary = store.get_snapshot().get(HeavyBreachActivityBoard.SESSION_SLOT, {})
		_check(HeavyBreachActivityBoard.validate_session_record(boundary), "the real-file store contains the supported Heavy Breach terminal record")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var completion: Dictionary = boundary.session.completion
		var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		_check(director.get_outcome() == EncounterScenarioDirector.OUTCOME_CLEARED
			and completion.activity_id == String(HeavyBreachActivityBoard.ACTIVITY_ID)
			and completion.scenario == String(EncounterScenarioDirector.SCENARIO_HEAVY_BREACH)
			and completion.outcome == "cleared" and not completion.reward_granted
			and fault.rejected and _breach_receipts(game) == 0
			and int(board.get_reward_handoff_snapshot().pending_reward_generation) == int(completion.generation)
			and context.get("mode") == "pilot" and context.get("craft_id") == String(craft.get_ship_id()),
			"genuine Heavy Breach completion saves earned debt before only its delegated real-filesystem reward write is refused")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var ready := {"boundary": boundary, "receipts": 0, "activity": activity,
			"foreign_settings": store.get_snapshot().runtime_settings,
			"foreign_cargo": store.get_snapshot().jovian_cargo_session,
			"foreign_reward_record": game.get_activity_reward_report().authority.record,
			"runtime_observation": _interruption_runtime_observation(game), "fixture_method": BREACH_FIXTURE,
			"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
		get_tree().paused = true
		# No orderly shutdown or further save before the exact supervisor kill.
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify(ready))
		return
	var boundary: Dictionary = store.get_snapshot().get(HeavyBreachActivityBoard.SESSION_SLOT, {})
	if not HeavyBreachActivityBoard.validate_session_record(boundary) or boundary.session.completion.is_empty() \
			or boundary.session.completion.activity_id != String(HeavyBreachActivityBoard.ACTIVITY_ID) \
			or boundary.session.completion.scenario != String(EncounterScenarioDirector.SCENARIO_HEAVY_BREACH):
		_fail("Heavy Breach restart requires the actual supported earned Heavy Breach terminal, never Torpedo")
		return
	var paid_replay: bool = boundary.session.completion.reward_granted
	var baseline := _breach_receipts(game)
	var foreign_settings: Dictionary = store.get_snapshot().runtime_settings
	var foreign_cargo: Dictionary = store.get_snapshot().jovian_cargo_session
	var reward_before: Dictionary = game.get_activity_reward_report().authority.record
	var observations := _interruption_runtime_observation(game)
	var recovery := game.get_recovery_available_snapshot()
	var crash_events := 0
	for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	_check(director.get_state() == EncounterScenarioDirector.STATE_IDLE
		and int(board.get_snapshot().active_director_generation) == 0 and not board.is_sortie_armed()
		and not game.player.is_seated() and not craft.is_piloted()
		and baseline == (1 if paid_replay else 0)
		and int(board.get_reward_handoff_snapshot().pending_reward_generation) == (0 if paid_replay else int(boundary.session.completion.generation)),
		"fresh Boot restores terminal debt or paid acknowledgement without recreating old combat or pilot claims")
	var safe_observation := {}
	var payment_commit := {}
	var payment_capture := {}
	if paid_replay:
		_check(recovery.is_empty() and crash_events == 0,
			"the further cold process observes clean prior shutdown without inventing another crash")
	else:
		_check(not recovery.is_empty() and recovery.get("state") == "running" and crash_events == 1,
			"the distinct cold recovery process observes the genuine killed session once")
		if _failures.is_empty():
			var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start", int(recovery.session_id), int(recovery.startup_generation))
			game.start_shift()
			await get_tree().process_frame
			var settled := await _wait_for_real_pilot(game, craft, 240)
			var area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
			var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
			_check(resumed.get("accepted", false) and settled and area.get_reservation_token() == game.player
				and berth.get_occupant() == craft and berth.get_reservation_owner() == craft
				and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1
				and boundary == store.get_snapshot().heavy_breach_session,
				"ordinary cold Resume acquires the real safe-home Arrow pilot while keeping exact terminal debt")
			safe_observation = _interruption_runtime_observation(game)
			# Resume's engines are idle at the safe home berth; use the production
			# exit owner and wait for all real seat/transition owners to settle.
			await _settle_frames(int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 3)
			game.call("_try_exit_ship")
			_check(await _breach_wait(func() -> bool: return not game.get("_transition_busy") and not game.get("_piloting"))
				and not game.player.is_seated() and not craft.is_piloted() and game.player.is_control_enabled()
				and area.get_reservation_token() != game.player,
				"production pilot exit releases real ownership before the staged on-foot board retry")
			_check(await _breach_board_fixture(game, board), "the recovered on-foot Player discovers the physical unpaid board")
			if _failures.is_empty():
				_breach_payment_board = board
				_breach_payment_observer = _capture_breach_payment.bind(game.player, board.get_generation(), store, payment_capture)
				board.interaction_resolved.connect(_breach_payment_observer)
				await _breach_press_interaction()
				_disconnect_breach_payment_observer()
				payment_commit = payment_capture.get("commit", {})
	var paid: Dictionary = store.get_snapshot().heavy_breach_session
	var reward_after: Dictionary = game.get_activity_reward_report().authority.record
	var expected := boundary.duplicate(true)
	expected.session.completion.reward_granted = true
	_check(paid == expected and _breach_receipts(game) == 1
		and int(reward_after.total_receipts) == 1 and int(reward_after.receipt_serial) == 1
		and reward_after.last_receipt.activity_id == String(HeavyBreachActivityBoard.ACTIVITY_ID)
		and reward_after.last_receipt.reward_id == String(HeavyBreachActivityBoard.REWARD_ID)
		and reward_after.last_receipt.activity_generation == boundary.session.completion.generation
		and reward_after.last_receipt.granted and not reward_after.last_receipt.replay_allowed
		and int(board.get_reward_handoff_snapshot().pending_reward_generation) == 0,
		"the production board/reward owner saves exactly one Heavy Breach receipt and the exact terminal acknowledgement")
	if paid_replay:
		_check(reward_before == reward_after and boundary == paid,
			"the further distinct cold process retains the complete paid ledger and terminal without a second receipt")
	else:
		var payment_document: Variant = JSON.parse_string(str(payment_capture.get("document_json", "")))
		var document_is_dictionary: bool = payment_document is Dictionary
		var document: Dictionary = payment_document if document_is_dictionary else {}
		var payload_value: Variant = document.get("payload")
		var payload: Dictionary = payload_value if payload_value is Dictionary else {}
		var generation_value: Variant = document.get("generation")
		var generation_is_numeric: bool = generation_value is int or generation_value is float
		# JSON parsing represents numbers as floats; the live authority creates
		# integer receipt fields. Normalize only the expected live ledger using
		# the existing JSON canonicalizer, retaining the actual primary wire text.
		var payment_checks := {
			"document_is_dictionary": document_is_dictionary,
			"commit_matches": document_is_dictionary and document.get("commit", {}) == payment_commit,
			"generation_matches": generation_is_numeric and int(generation_value) == int(payment_capture.get("store_generation", -2)),
			"reward_commit_prefix": str(payment_commit.get("id", "")).begins_with("game-flow-reward-"),
			"terminal_matches": payload.get("heavy_breach_session", {}) == expected,
			"single_receipt_matches": payload.get("game_flow_reward_store", {}) == _canonical(reward_after),
			"foreign_settings_match": payload.get("runtime_settings", {}) == foreign_settings,
			"foreign_cargo_matches": payload.get("jovian_cargo_session", {}) == foreign_cargo,
		}
		var payment_matches := true
		for predicate: String in payment_checks:
			payment_matches = payment_matches and bool(payment_checks[predicate])
		if not payment_matches:
			var ledger_value: Variant = payload.get("game_flow_reward_store")
			var ledger: Dictionary = ledger_value if ledger_value is Dictionary else {}
			var receipt_value: Variant = ledger.get("last_receipt")
			var receipt: Dictionary = receipt_value if receipt_value is Dictionary else {}
			print("BREACH_PAYMENT_CAPTURE_MISMATCH: " + JSON.stringify({
				"predicates": payment_checks,
				"captured_commit_id": str(payment_commit.get("id", "")),
				"captured_store_generation": payment_capture.get("store_generation", -1),
				"document_generation": generation_value if generation_is_numeric else null,
				"types": {"document": typeof(payment_document), "payload": typeof(payload_value),
					"document_generation": typeof(generation_value), "ledger": typeof(ledger_value),
					"receipt": typeof(receipt_value), "persisted_total_receipts": typeof(ledger.get("total_receipts")),
					"live_total_receipts": typeof(reward_after.get("total_receipts")),
					"persisted_receipt_serial": typeof(ledger.get("receipt_serial")),
					"live_receipt_serial": typeof(reward_after.get("receipt_serial")),
					"persisted_activity_generation": typeof(receipt.get("activity_generation")),
					"live_activity_generation": typeof(reward_after.last_receipt.get("activity_generation"))}}))
		_check(payment_matches,
			"the physical board signal captures one persisted atomic reward document with the exact single receipt and terminal acknowledgement before later tutorial saves")
		if _failures.is_empty():
			var bytes := FileAccess.get_file_as_bytes(str(store.get("_path")))
			await _breach_press_interaction()
			_check(_breach_receipts(game) == 1 and store.get_snapshot().heavy_breach_session == paid
				and FileAccess.get_file_as_bytes(str(store.get("_path"))) == bytes,
				"a second real board interaction cannot repay or mutate the acknowledged Heavy Breach terminal")
	_check(foreign_settings == store.get_snapshot().runtime_settings and foreign_cargo == store.get_snapshot().jovian_cargo_session,
		"Heavy Breach payment and cold replay preserve actual unrelated settings and cargo progress")
	var closed := game.mark_orderly_shutdown()
	_check(closed.get("accepted", false) and game.get_instance_id() == main_id and game.get_tree() == get_tree(),
		"the exact Boot Main closes both existing recovery marker owners")
	var outcome := {"boundary": boundary, "paid_boundary": paid, "receipts_before": baseline,
		"receipts_after": _breach_receipts(game), "payment_commit": payment_commit,
		"payment_capture": payment_capture, "paid_replay": paid_replay,
		"reward_record": reward_after, "foreign_reward_record": reward_before,
		"foreign_settings": foreign_settings, "foreign_cargo": foreign_cargo, "crash_events": crash_events,
		"runtime_observation": observations, "safe_recovery_observation": safe_observation,
		"fixture_method": BREACH_FIXTURE,
		"continuation_method": "ordinary_cold_Resume_safe_home_Arrow_pilot_production_exit_staged_physical_board_interaction",
		"active_combat_restore": "NOT_SUPPORTED", "ordinary_combat_acceptance": "NOT_RUN",
		"activity": activity, "assertions": _assertions, "entry": entry,
		"loaded_main_instance_id": main_id, "recovery_context": recovery_context}
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify(outcome))
		get_tree().quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)


func _stationdefense_receipts(game: GameFlow) -> int:
	var record: Dictionary = game.get_activity_reward_report().authority.record
	return int(record.reward_counts.get("return_defense_report_to_shipyard", 0))


func _stationdefense_start(game: GameFlow) -> void:
	game.call("_sync_activity_hud")
	for row in (game.hud.get("_nearby_activity_rows") as VBoxContainer).get_children():
		if row.get_meta(&"activity_id", &"") == &"station_defense":
			var button := row.get_child(2) as Button
			_check(not button.disabled, "the actual defense HUD Start reaches its physical board gate")
			if not button.disabled:
				button.emit_signal("pressed")
			print("STATION_DEFENSE_PHYSICAL_REQUEST: " + JSON.stringify({"board_gate": game.world.get_station_defense_activity_board().get_interaction_snapshot(game.player, game.world.get_station_defense_content().get_generation()), "feedback": (game.hud.get("_nearby_activity_feedback") as Label).text, "heavy_breach_armed": game.call("_heavy_breach_sortie_is_armed"), "bindings": game.get_station_defense_encounter_status()}))
			return
	_check(false, "the actual nearby HUD exposes its station-defense Start action")


func _stationdefense_on_foot_fixture(game: GameFlow, board: StationDefenseActivityBoard) -> void:
	# Scenario positioning is bounded to the existing collision-backed station
	# board. It cannot acquire/release a pilot seat or bypass Main's on-foot gate.
	game.player.teleport_to(Transform3D(Basis.IDENTITY, board.global_position + Vector3(0.0, 0.0, 1.4)))
	await _settle_frames(4)
	_check(not game.get("_piloting") and not game.player.is_seated() and game.player.is_control_enabled()
		and game.player.global_position.distance_to(board.global_position) <= StationDefenseActivityBoard.INTERACTION_RADIUS,
		"the real on-foot Player reaches the physical defense board before its HUD request")


func _stationdefense_shoot(game: GameFlow, craft: HeroShip, target: RangeOpponent) -> bool:
	var authority := game.get_combat_authority()
	var weapon: StringName = game.call("_get_player_combat_weapon_id", craft)
	for _shot in 16:
		# Pacing/position fixture only: pause hostile AI movement, keep the
		# authored damageable/weapon/health and shared resolver unchanged.
		for enemy in target.get_parent().get_children():
			if enemy is RangeOpponent:
				enemy.set_physics_process(false)
		await get_tree().process_frame
		var aim := target.global_position
		craft.global_position = aim + Vector3(0.0, 0.0, 20.0)
		await get_tree().physics_frame
		var result := authority.submit_hitscan(craft, weapon, craft.global_position, (aim - craft.global_position).normalized())
		_check(result.get("accepted", false) and result.get("target_entity") == target and result.get("damaged", false),
			"the existing pilot weapon resolves real damage on the exact authored defense hostile: %s" % JSON.stringify(result))
		await get_tree().process_frame
		if result.get("destroyed", false):
			return true
		if not _failures.is_empty():
			return false
	return false


func _run_stationdefense(game: GameFlow, store: UserDataStore, entry: String) -> void:
	if recovery_context != "pilot":
		_fail("station-defense interruption supports the actual pilot recovery context only")
		return
	var main_id := game.get_instance_id()
	game.set_physics_process(false)
	game.call("_ensure_station_defense_encounter_bindings")
	var content := game.world.get_station_defense_content() as StationDefenseEncounterContent
	var board := game.world.get_station_defense_activity_board() as StationDefenseActivityBoard
	if not is_instance_valid(content) or not is_instance_valid(board):
		_fail("Boot Main must own the actual authored defense content and physical board")
		return
	var craft: HeroShip
	if stage == "arm":
		game.call("_on_settings_save_requested")
		_check(game.cargo_delivery_activity.start(game.cargo_delivery_activity.get_generation()).accepted
			and game.save_jovian_cargo_session().accepted, "the actual production cargo owner saves unrelated cargo progress")
		game.start_shift()
		await _load_beacon_binding(game, "station-defense HUD")
		await _stationdefense_on_foot_fixture(game, board)
		_stationdefense_start(game)
		_check(content.get_snapshot().host.activity.state_id == &"active", "the on-foot HUD request starts the genuine authored defense through its physical board: %s" % JSON.stringify(board.get_last_result()))
		for enemy in content.get_node(^"OpponentRoster").get_children():
			if enemy is RangeOpponent:
				enemy.set_physics_process(false)
		craft = game.get_flyable_ships()[1] as HeroShip
		game.canopy_motion_time = 0.01
		game.boarding_motion_time = 0.02
		game.player.teleport_to(craft.get_boarding_entry_transform())
		game.call("_board_ship", craft)
		_check(await _wait_for_real_pilot(game, craft), "defense arm acquires the real Player pilot before its combat fixture")
		var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		_check(context.get("mode") == "pilot" and context.get("craft_id") == String(craft.get_ship_id()),
			"the genuine settled defense pilot saves only its supported safe-home identity")
		# Earn the unrelated reward through the actual authored beacon route,
		# rather than manufacturing a detached reward request or receipt.
		craft.global_position = game.call("_cinder_authored_frame_to_world", CinderBeaconTraversalActivity.BEACONS[0])
		_beacon_start(game)
		for point in CinderBeaconTraversalActivity.BEACONS:
			craft.global_position = game.call("_cinder_authored_frame_to_world", point)
			game.call("_advance_cinder_beacon_traversal", 0.0, game.call("_capture_cinder_actor_sample"))
		_check(_beacon_receipts(game) == 1 and _stationdefense_receipts(game) == 0,
			"the actual authored beacon route earns one unrelated reward before defense completion")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var original := store.get("_filesystem") as UserDataFilesystem
		var fault := ActivityRewardFault.new(original, String(StationDefenseActivityBoard.ACTIVITY_ID))
		store.set("_filesystem", fault)
		var generation := content.get_generation()
		var roster := content.get_node(^"OpponentRoster")
		var cleared := await _stationdefense_shoot(game, craft, roster.get_node(^"PerimeterRaiderAlpha"))
		var relief := content.advance_physics(2.5, generation)
		_check(relief.accepted and content.get_snapshot().host.activity.wave_active, "the real authored relief wave deploys after its complete caller-owned delay: %s" % JSON.stringify(relief))
		await get_tree().physics_frame
		cleared = await _stationdefense_shoot(game, craft, roster.get_node(^"PerimeterRaiderBeta")) and cleared
		cleared = await _stationdefense_shoot(game, craft, roster.get_node(^"PerimeterRaiderGamma")) and cleared
		var picket := content.advance_physics(8.0, generation)
		_check(picket.accepted and content.get_snapshot().host.activity.wave_active, "the real authored picket wave deploys after its complete caller-owned delay: %s" % JSON.stringify(picket))
		await get_tree().physics_frame
		cleared = await _stationdefense_shoot(game, craft, roster.get_node(^"PerimeterHeavyPicket")) and cleared
		var live: Dictionary = content.get_snapshot().host.activity
		var boundary: Dictionary = store.get_snapshot().get("station_defense_session", {})
		var valid := StationDefenseSessionAdapter.new().restore(boundary.get("session"))
		_check(cleared and live.state_id == &"completed" and valid.get("accepted", false)
			and valid.history.state_id == &"completed" and valid.completion.generation == generation
			and valid.completion.reward_requested and not valid.completion.reward_granted
			and fault.rejected and board.get_reward_handoff_snapshot().reward_pending and _stationdefense_receipts(game) == 0,
			"real shared-resolver destruction completes every authored wave and a refused reward write leaves the exact earned durable unpaid report")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var ready := {"boundary": boundary, "receipts": 0, "activity": activity,
			"armed_elapsed_seconds": live.elapsed_seconds,
			"foreign_settings": store.get_snapshot().runtime_settings,
			"foreign_cargo": store.get_snapshot().jovian_cargo_session,
			"foreign_reward_counts": game.get_activity_reward_report().authority.record.reward_counts,
			"runtime_observation": _interruption_runtime_observation(game),
			"fixture_method": "on_foot_physical_board_then_real_pilot_weapon_resolver_hits_with_paused_hostile_AI_and_authored_wave_delays",
			"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
		get_tree().paused = true
		store.set("_filesystem", original)
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify(ready))
		return
	var boundary: Dictionary = store.get_snapshot().get("station_defense_session", {})
	var valid := StationDefenseSessionAdapter.new().restore(boundary.get("session"))
	if boundary.get("schema_version") != 1 or boundary.get("payload_kind") != "nearby_sector_activity_session" \
			or boundary.get("slot_id") != "station_defense_session" or not valid.get("accepted", false):
		_fail("defense restart requires an existing supported earned terminal report")
		return
	if valid.completion.is_empty() or valid.completion.reward_granted or valid.history.state_id != &"completed":
		_fail("defense restart requires a genuinely completed unpaid report")
		return
	var pending_snapshot := board.get_session_persistence_snapshot()
	var observations := _interruption_runtime_observation(game)
	var recovery := game.get_recovery_available_snapshot()
	var crash_events := 0
	for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	var live: Dictionary = content.get_snapshot().host.activity
	_check(live.state_id == &"idle" and content.get_snapshot().host.active_entity_count == 0 and live.elapsed_seconds == 0.0
		and board.get_reward_handoff_snapshot().reward_pending and board.get_reward_handoff_snapshot().pending_generation == valid.completion.generation
		and not game.player.is_seated() and not game.active_ship.is_piloted()
		and crash_events == 1 and not recovery.is_empty() and recovery.get("state") == "running",
		"fresh Boot restores only the exact owed report into safe idle content without old combat, elapsed timer or pilot-claim replay")
	var baseline := _stationdefense_receipts(game)
	var foreign_settings: Dictionary = store.get_snapshot().runtime_settings
	var foreign_cargo: Dictionary = store.get_snapshot().jovian_cargo_session
	var foreign_rewards: Dictionary = game.get_activity_reward_report().authority.record.reward_counts
	var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	for candidate in game.get_flyable_ships():
		if String(candidate.get_ship_id()) == context.get("craft_id"):
			craft = candidate
	if craft == null or not _failures.is_empty():
		_fail("the saved defense pilot identity must resolve its real shipped craft before Resume")
		return
	var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start", int(recovery.session_id), int(recovery.startup_generation))
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.disembarking_motion_time = 0.02
	game.start_shift()
	var settled := await _wait_for_real_pilot(game, craft)
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	_check(resumed.get("accepted", false) and settled and area.get_reservation_token() == game.player
		and berth.get_occupant() == craft and berth.get_reservation_owner() == craft
		and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1
		and boundary == store.get_snapshot().station_defense_session,
		"ordinary cold Resume reacquires the real safe-home pilot and preserves the unpaid defense report")
	Input.action_press(&"move_forward")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"move_forward")
	_check(str(craft.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE" and craft.get_last_ship_command().throttle > 0.0
		and boundary == store.get_snapshot().station_defense_session,
		"the recovered real pilot accepts ordinary throttle while the defense report stays unpaid")
	var safe_observation := _interruption_runtime_observation(game)
	await _settle_frames(int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 3)
	game.call("_try_exit_ship")
	for _frame in 180:
		if not game.get("_transition_busy") and not game.get("_piloting"):
			break
		await _settle_frames(1)
	_check(not game.get("_piloting") and not craft.is_piloted() and not game.player.is_seated()
		and game.player.is_control_enabled() and area.get_reservation_token() != game.player,
		"the ordinary idle propulsion and production pilot exit release real seat ownership before the board retry")
	await _load_beacon_binding(game, "station-defense HUD")
	await _stationdefense_on_foot_fixture(game, board)
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	_stationdefense_start(game)
	var paid: Dictionary = store.get_snapshot().station_defense_session
	var payment_commit := store.get_commit_metadata()
	_check(_stationdefense_receipts(game) == baseline + 1 and paid.session.completion.reward_granted
		and paid.session.completion.generation == valid.completion.generation
		and paid.session.history.reward_handoff_generation == valid.completion.generation
		and not board.get_reward_handoff_snapshot().reward_pending
		and str(payment_commit.id).begins_with("game-flow-reward-"),
		"the ordinary on-foot physical board HUD retry atomically publishes one reward receipt and the exact earned report acknowledgement")
	var bytes := FileAccess.get_file_as_bytes(str(store.get("_path")))
	var duplicate: Dictionary = game.call("_commit_game_flow_activity_reward", {
		"activity_id": StationDefenseActivityBoard.ACTIVITY_ID, "activity_generation": int(valid.completion.generation),
		"reward_id": &"return_defense_report_to_shipyard", "reward_authority": false, "granted": false})
	var stale := board.abort_and_reset(game.player, content.get_generation() - 1)
	var persistence := board.get("_persistence_binding") as RefCounted
	var late := persistence.call("save", pending_snapshot, store.get_generation(), "station-defense-late-unpaid") as Dictionary
	_check(not duplicate.accepted and not stale.accepted and stale.reason == &"stale_generation" and not late.accepted
		and _stationdefense_receipts(game) == baseline + 1 and paid == store.get_snapshot().station_defense_session
		and FileAccess.get_file_as_bytes(str(store.get("_path"))) == bytes,
		"duplicate reward, stale physical reset and genuine late unpaid checkpoint cannot repay or downgrade the acknowledged defense report")
	for key in foreign_rewards:
		_check(game.get_activity_reward_report().authority.record.reward_counts.get(key) == foreign_rewards[key],
			"the existing unrelated earned reward count is preserved")
	_check(foreign_settings == store.get_snapshot().runtime_settings and foreign_cargo == store.get_snapshot().jovian_cargo_session,
		"the report retry preserves actual production settings and cargo progress")
	var closed := game.mark_orderly_shutdown()
	_check(closed.get("accepted", false), "defense restart closes both existing recovery marker owners")
	_check(is_instance_valid(game) and game.get_instance_id() == main_id and game.get_tree() == get_tree(),
		"defense recovery retains Boot's exact supplied Main owner")
	var outcome := {"boundary": boundary, "paid_boundary": paid, "receipts_before": baseline,
		"receipts_after": _stationdefense_receipts(game), "payment_commit": payment_commit,
		"crash_events": crash_events, "activity": activity,
		"foreign_settings": foreign_settings, "foreign_cargo": foreign_cargo, "foreign_reward_counts": foreign_rewards,
		"runtime_observation": observations, "safe_recovery_observation": safe_observation,
		"continuation_method": "real_safe_home_pilot_resume_throttle_idle_pilot_exit_then_on_foot_physical_board_HUD_retry",
		"active_combat_restore": "NOT_SUPPORTED", "elapsed_timer_restore": "NOT_SUPPORTED",
		"assertions": _assertions, "entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
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


func _on_foot_context_matches(context: Dictionary, craft: HeroShip) -> bool:
	return context.size() == 4 and context.get("location") == "mudds_home_berth" \
		and context.get("mode") == "on_foot" and context.get("craft_id") == String(ON_FOOT_CRAFT_ID) \
		and context.get("berth_id") == String(ON_FOOT_BERTH_ID) \
		and craft.get_ship_id() == ON_FOOT_CRAFT_ID and craft.get_home_berth_id() == ON_FOOT_BERTH_ID


func _is_settled_exterior(game: GameFlow, craft: HeroShip) -> bool:
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	return game.phase in [GameFlow.Phase.APPROACH_SHIP, GameFlow.Phase.COMPLETE] \
		and not bool(game.get("_transition_busy")) and not bool(game.get("_piloting")) \
		and not craft.is_piloted() and not game.player.is_seated() and not game.player.is_sleeping() \
		and game.player.is_on_floor() and game.player.is_control_enabled() \
		and not game.player.is_cabin_containment_active() \
		and not bool(game.get_solo_crew_seat_status().get("seated", false)) \
		and (game.get_solo_crew_seat_status().get("assignment", {}) as Dictionary).is_empty() \
		and game.player.global_position.distance_to(craft.get_exit_transform().origin) < 1.5 \
		and not craft.get_moving_interior_component().is_occupant_registered(game.player) \
		and area.get_reservation_token() == null and berth.get_occupant() == craft \
		and berth.get_reservation_owner() == craft \
		and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1


func _exterior_observation(game: GameFlow, craft: HeroShip) -> Dictionary:
	var observation := _interruption_runtime_observation(game)
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	observation["preferred_craft_id"] = String(craft.get_ship_id())
	observation["preferred_berth_id"] = String(craft.get_home_berth_id())
	observation["preferred_craft_piloted"] = craft.is_piloted()
	observation["preferred_craft_at_home"] = craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1
	observation["home_berth_occupied_by_craft"] = berth.get_occupant() == craft and berth.get_reservation_owner() == craft
	observation["hatch_reserved"] = area.get_reservation_token() != null
	observation["moving_interior_occupant"] = craft.get_moving_interior_component().is_occupant_registered(game.player)
	observation["solo_crew_seated"] = bool(game.get_solo_crew_seat_status().get("seated", false))
	observation["solo_crew_assignment_empty"] = (game.get_solo_crew_seat_status().get("assignment", {}) as Dictionary).is_empty()
	observation["distance_to_authored_exit_m"] = game.player.global_position.distance_to(craft.get_exit_transform().origin)
	return observation


func _settle_exterior_context(game: GameFlow, craft: HeroShip) -> void:
	# The existing escort fixture positions flight. Disclose a final approach
	# placement; only real thrust, landing, berth lease and pilot exit may own
	# support/claims. No Player pose or saved recovery payload is injected.
	game.set_physics_process(true)
	Input.action_press(&"hover")
	Input.action_press(&"move_forward")
	await _settle_frames(6)
	Input.action_release(&"move_forward")
	Input.action_release(&"hover")
	_check(not bool(craft.get_telemetry().get("landed", true)),
		"ordinary flight demand clears the actual hull's landed state before return staging")
	craft.global_transform = game.world.get_berth_transform(craft.get_home_berth_id()).translated_local(Vector3(0.0, 3.0, 0.0))
	craft.velocity = Vector3.ZERO
	game.call("_try_request_landing")
	for _frame in 300:
		if bool(craft.get_telemetry().get("landed", false)) and game.phase == GameFlow.Phase.SHUT_DOWN:
			break
		await _settle_frames(1)
	_check(bool(craft.get_telemetry().get("landed", false)) and game.phase == GameFlow.Phase.SHUT_DOWN,
		"the normal landing owner docks the staged approach at the registered home berth")
	await _settle_frames(int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 3)
	game.call("_try_exit_ship")
	for _frame in 300:
		if not bool(game.get("_transition_busy")) and not game.player.is_seated():
			break
		await _settle_frames(1)
	await _settle_frames()
	game.call("_capture_solo_safe_recovery_context")
	_check(_is_settled_exterior(game, craft) and game.get_active_activity_snapshot().state_id == &"failed",
		"real home landing and exterior pilot exit leave a supported claim-free player and failed second convoy")
	game.set_physics_process(false)


func _walk_exterior_home(game: GameFlow, craft: HeroShip) -> Dictionary:
	var start := game.player.global_position
	# The Bulwark's authored exit is a narrow aft-port deck corner. Walk inboard
	# along ship +X using camera-relative action strengths, without moving the
	# actor or camera by fixture. Keep clear of the aft edge's real void.
	var forward: Vector3 = (-game.player.get_camera().global_basis.z).slide(Vector3.UP).normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var direction := craft.global_basis.x.normalized()
	var forward_strength := direction.dot(forward)
	var right_strength := direction.dot(right)
	Input.action_press(&"move_forward", maxf(forward_strength, 0.0))
	Input.action_press(&"move_back", maxf(-forward_strength, 0.0))
	Input.action_press(&"move_right", maxf(right_strength, 0.0))
	Input.action_press(&"move_left", maxf(-right_strength, 0.0))
	await _settle_frames(8)
	for action: StringName in [&"move_forward", &"move_back", &"move_right", &"move_left"]:
		Input.action_release(action)
	await _settle_frames(4)
	return {"distance_m": game.player.global_position.distance_to(start),
		"supported": game.player.is_on_floor(), "method": "ordinary_camera_relative_inboard_walking_input"}


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


static func finish_convoy(game: GameFlow, craft: HeroShip, report_shot: bool = false) -> bool:
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
	if report_shot:
		print("JOVIAN_ENGINEER_CONVOY_SHOT: " + JSON.stringify({"result": intercepted, "host": host.get_snapshot(),
			"threat": game.cinder_convoy_threat.get_snapshot(), "source": game.get_combat_authority().get_source_id(craft),
			"craft_position": craft.global_position, "target_position": attacker.global_position}))
	var budget := 60
	while budget > 0 and host.get_snapshot().activity.state_id == &"active":
		craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		game.call("_physics_process", 0.25)
		budget -= 1
	return bool(intercepted.get("destroyed", false)) and budget > 0 and host.get_snapshot().activity.state_id == &"completed"



func _engineer_apply_look(actor: PlayerController, target: Vector3) -> void:
	# Synthetic mouse input only, matching the existing ordinary route test.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		actor._unhandled_input(click)
	var desired := actor.global_basis.inverse() * (target - actor.get_camera().global_position).normalized()
	var current := actor.global_basis.inverse() * actor.get_interaction_direction().normalized()
	var yaw := wrapf(atan2(-desired.x, -desired.z) - atan2(-current.x, -current.z), -PI, PI)
	var pitch := asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-yaw, pitch * (1.0 if actor.invert_mouse_y else -1.0)) / actor.mouse_sensitivity
	actor._unhandled_input(motion)


func _engineer_look(actor: PlayerController, target: Vector3) -> void:
	for _tick in 4:
		_engineer_apply_look(actor, target)
		await _settle_frames(1)


func _engineer_walk(actor: PlayerController, craft: HeroShip, local_target: Vector3) -> void:
	var target := craft.to_global(local_target)
	await _engineer_look(actor, Vector3(target.x, actor.get_camera().global_position.y, target.z))
	Input.action_press(&"move_forward")
	for _tick in 160:
		var flat := craft.to_local(actor.global_position) - local_target
		flat.y = 0.0
		if flat.length() < 0.12:
			break
		target = craft.to_global(local_target)
		_engineer_apply_look(actor, Vector3(target.x, actor.get_camera().global_position.y, target.z))
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	await _settle_frames(4)


func _engineer_ramp_walk(game: GameFlow, craft: JovianLightFreighter) -> void:
	# The sole Player-position fixture is the supported exterior cargo ramp.
	# Every cabin/chair/helm handoff thereafter is ordinary walking/Interact.
	game.player.teleport_to(Transform3D(craft.global_basis.orthonormalized(),
		craft.get_interior_access_marker().global_position + craft.global_basis.y * 0.01))
	await _settle_frames(10)
	await _engineer_look(game.player, game.player.global_position - craft.global_basis.z * 20.0 + craft.global_basis.y * 1.5)
	for leg in [[&"move_right", 50], [&"move_right", 72], [&"move_left", 22], [&"move_forward", 90], [&"move_left", 24]]:
		Input.action_press(leg[0])
		for _tick in int(leg[1]):
			await get_tree().physics_frame
		Input.action_release(leg[0])
		await _settle_frames(3)
	_check(game.player.is_on_floor() and game.player.is_control_enabled(),
		"the real Player walks the exterior ramp and authored cabin floor to the engineer aisle")


func _engineer_claim(game: GameFlow, craft: JovianLightFreighter) -> bool:
	await _engineer_walk(game.player, craft, Vector3(-1.35, 0.60, -5.25))
	await _engineer_look(game.player, craft.get_engineer_seat_anchor().global_position + craft.global_basis.y * 1.2)
	print("JOVIAN_ENGINEER_INPUT_OBSERVATION: " + JSON.stringify({"display": DisplayServer.get_name(), "mouse_mode": int(Input.mouse_mode), "camera_active": game.player.get("_camera_active"), "player_local": craft.to_local(game.player.global_position), "anchor_local": craft.to_local(craft.get_engineer_seat_anchor().global_position), "candidate": str(game.station_interaction_candidate), "phase": int(game.phase), "floor": game.player.is_on_floor(), "control": game.player.is_control_enabled()}))
	await _press_real_interaction()
	for _tick in 180:
		if game.get_solo_crew_seat_status().seated and not game.get("_transition_busy"):
			break
		await _settle_frames(1)
	var status := game.get_solo_crew_seat_status()
	var assignment: Dictionary = status.assignment
	return (status.seated and game.player.is_seated_at(craft.get_engineer_seat_anchor())
		and assignment.get("role") == &"engineer" and assignment.get("seat_id") == craft.ENGINEER_SEAT_ID
		and craft.get_crew_role_authority() != null and not craft.is_piloted()
		and game.player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META))


func _engineer_stand(game: GameFlow, craft: JovianLightFreighter) -> bool:
	var owner := craft.get_crew_role_authority()
	await _press_real_interaction()
	for _tick in 180:
		if not game.get("_transition_busy") and not game.player.is_seated() and game.player.is_on_floor():
			break
		await _settle_frames(1)
	return (not game.player.is_seated() and game.player.is_on_floor() and game.player.is_control_enabled()
		and not game.player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META)
		and owner != null and owner.get_snapshot().assignments.is_empty())


func _engineer_helm(game: GameFlow, craft: JovianLightFreighter) -> bool:
	await _engineer_walk(game.player, craft, Vector3(0.0, 0.60, -5.25))
	await _engineer_walk(game.player, craft, Vector3(0.0, 0.60, -6.70))
	await _engineer_look(game.player, craft.get_pilot_seat_anchor().global_position + craft.global_basis.y * 1.2)
	await _press_real_interaction()
	return await _wait_for_real_pilot(game, craft, 300)


func _run_engineer(game: GameFlow, store: UserDataStore, entry: String) -> void:
	if activity != "convoy":
		_fail("engineer interruption supports only the existing adjacent convoy context")
		return
	var main_id := game.get_instance_id()
	var craft := game.get_node("JovianLightFreighter") as JovianLightFreighter
	var boundary: Dictionary
	var before_receipts := 0
	var context: Dictionary
	var foreign_settings: Dictionary
	var foreign_cargo: Dictionary
	var observation := _interruption_runtime_observation(game)
	if stage == "arm":
		game.call("_on_settings_save_requested")
		# Unrelated real-owner initial-manifest boundary, not a cargo journey:
		# start/save and its production persisted reset establish a genuine IDLE
		# record without transfers, completed cargo or inventory/reward injection.
		var cargo_started := game.cargo_delivery_activity.start(game.cargo_delivery_activity.get_generation())
		var cargo_saved := game.save_jovian_cargo_session()
		var cargo_reset := game.cargo_delivery_activity.reset_with_persistence(
			game.cargo_delivery_activity.get_generation(), game.save_jovian_cargo_session)
		var cargo_record: Dictionary = store.get_snapshot().get("jovian_cargo_session", {})
		_check(cargo_started.accepted and cargo_saved.accepted and cargo_reset.accepted
			and game.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
			and not cargo_record.is_empty() and int(cargo_record.activities[0].state) == CargoDeliveryActivity.State.IDLE,
			"the actual cargo start and persisted reset save the unrelated genuine IDLE initial-manifest boundary")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		game.canopy_motion_time = 0.01
		game.boarding_motion_time = 0.02
		game.disembarking_motion_time = 0.02
		game.start_shift()
		var escort := game.get_flyable_ships()[1] as HeroShip
		game.call("_board_ship", escort)
		_check(await _wait_for_real_pilot(game, escort), "the real armed Bulwark pilot owns the first adjacent convoy fixture")
		game.set_physics_process(false)
		var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
		await _position_escort_fixture(game, escort)
		var started := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		var arrived := await finish_convoy(game, escort, true)
		_check(selected.accepted and started.accepted and arrived and _convoy_receipts(game) == 1
			and game.reset_active_activity(), "the real first convoy pays once and its ordinary reset clears that completed run")
		if not _failures.is_empty():
			print("JOVIAN_ENGINEER_FIRST_CONVOY_OBSERVATION: " + JSON.stringify({"selected": selected, "started": started,
				"arrived": arrived, "receipts": _convoy_receipts(game), "host": game.cinder_convoy_host.get_snapshot(),
				"reward": game.get_activity_reward_report()}))
			get_tree().quit(1)
			return
		# Return only the scenario-positioned craft to its occupied home berth;
		# its real pilot exit owns seat, berth and awake Player cleanup.
		escort.global_transform = game.world.get_berth_transform(escort.get_home_berth_id())
		game.set_physics_process(true)
		await _settle_frames(int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 3)
		game.call("_try_exit_ship")
		for _tick in 180:
			if not game.get("_piloting") and not game.get("_transition_busy"):
				break
			await _settle_frames(1)
		_check(not game.get("_piloting") and not game.player.is_seated() and game.player.is_control_enabled(),
			"ordinary home pilot exit releases the first escort before the Jovian walking route")
		await _engineer_ramp_walk(game, craft)
		_check(await _engineer_claim(game, craft), "ordinary walk and Interact acquire the real Jovian engineer chair before flight")
		_check(await _engineer_stand(game, craft), "ordinary stand retires the exact engineer assignment on the supported cabin floor")
		_check(await _engineer_helm(game, craft), "ordinary cabin walk and Interact acquire the Jovian helm without direct assignment")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		game.set_physics_process(false)
		await _position_escort_fixture(game, craft)
		var next := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		for _tick in 4:
			craft.global_position = game.cinder_convoy_host.get_snapshot().entity_position + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
			game.call("_physics_process", 0.25)
		_check(next.accepted, "the genuine Jovian pilot starts a distinct second convoy without inventing a weapon or reward")
		# Existing nonpilot escort fixture holds Main's activity cadence between
		# these real samples and pilot leave. Craft/Player physics and ordinary
		# Input keep running; this is not uninterrupted combat restoration.
		craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		Input.action_press(&"hover")
		Input.action_press(&"move_forward")
		await _settle_frames(6)
		Input.action_release(&"move_forward")
		Input.action_release(&"hover")
		# Position-only escort fixture while the real propulsion owner becomes
		# idle. The subsequent ordinary pilot leave must own this failure;
		# an earlier natural separation terminal is a different runtime case.
		for _tick in int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 3:
			if craft.get_telemetry().engine_state == HeroShip.ENGINE_OFFLINE:
				break
			craft.global_position = game.cinder_convoy_host.get_snapshot().entity_position + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
			await _settle_frames(1)
		_check(craft.get_telemetry().engine_state == HeroShip.ENGINE_OFFLINE
			and game.get_active_activity_snapshot().state_id == &"active",
			"the positioned escort remains genuinely active until actual idle propulsion permits ordinary pilot leave")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		await _press_real_interaction()
		for _tick in 180:
			if not game.get("_transition_busy") and game.player.is_on_floor() and not craft.is_piloted():
				break
			await _settle_frames(1)
		_check(not craft.get_telemetry().landed and game.player.is_on_floor() and not craft.is_piloted()
			and game.get_active_activity_snapshot().state_id == &"failed"
			and game.cinder_convoy_host.get_snapshot().activity.terminal_reason == &"convoy_reported_lost"
			and game.get("_convoy_terminal_reason") == &"pilot_unseated",
			"ordinary airborne pilot leave returns the real Player to the cabin and fails the actual second convoy")
		game.set_physics_process(true)
		_check(await _engineer_claim(game, craft), "ordinary moving-cabin walk and Interact reacquire the exact Jovian engineer owner before interruption")
		var saved := game.save_cinder_convoy_session()
		boundary = _stored_session_state(store)
		context = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		print("JOVIAN_ENGINEER_SAVE_OBSERVATION: " + JSON.stringify({"save": saved, "context": context,
			"saved_host": boundary.host_state, "live_host": _canonical(game.cinder_convoy_host.capture_persistence_state()),
			"saved_threat": boundary.threat_state, "live_threat": _canonical(game.cinder_convoy_threat.capture_persistence_state()),
			"receipts": _convoy_receipts(game)}))
		_check(saved.accepted and context.size() == 4 and context.get("mode") == "crew"
			and context.get("craft_id") == String(craft.get_ship_id())
			and boundary.escort_ship_id == craft.get_ship_id() and _convoy_receipts(game) == 1
			and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
			and _canonical(game.cinder_convoy_threat.capture_persistence_state()) == boundary.threat_state,
			"actual engineer admission saves only the existing four-field crew preference beside the genuine failed Jovian convoy and first paid receipt")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var ready := {"boundary": boundary, "receipts": _convoy_receipts(game), "safe_context": context,
			"foreign_settings": store.get_snapshot().runtime_settings, "foreign_cargo": store.get_snapshot().jovian_cargo_session,
			"runtime_observation": _interruption_runtime_observation(game), "engineer_observation": game.get_solo_crew_seat_status(),
			"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
		get_tree().paused = true
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify(ready))
		return
	# No context or entitlement may be invented for a fresh profile/missing run.
	var payload := store.get_snapshot()
	context = payload.get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	if context.size() != 4 or context.get("mode") != "crew" or context.get("craft_id") != String(craft.get_ship_id()) \
			or not payload.has(String(SLOT)) or not game.get_cinder_convoy_session_persistence_report().restore_status.get("accepted", false):
		_fail("engineer restart requires a genuinely saved Jovian crew context and supported adjacent convoy")
		return
	boundary = _stored_session_state(store)
	before_receipts = _convoy_receipts(game)
	foreign_settings = payload.runtime_settings
	foreign_cargo = payload.jovian_cargo_session
	var recovery := game.get_recovery_available_snapshot()
	var crash_events := 0
	for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	_check(boundary.escort_ship_id == craft.get_ship_id() and game.get_active_activity_snapshot().state_id == &"failed"
		and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
		and _restored_threat_boundary_matches(game, boundary) and crash_events == 1
		and not game.player.is_seated() and not craft.is_piloted() and craft.get_crew_role_authority() == null,
		"fresh Boot adopts the exact failed Jovian convoy without replaying engineer, helm or work ownership")
	var resume := (game.hud.get("_session_recovery_action_buttons") as Dictionary).get(&"continue") as Button
	_check(resume != null and not recovery.is_empty(), "the real cold engineer recovery offers ordinary HUD Resume")
	if resume == null or not _failures.is_empty():
		get_tree().quit(1)
		return
	resume.emit_signal("pressed")
	await _settle_frames(3)
	game.start_shift()
	await _settle_frames(12)
	var awake := await _wait_for_awake_cabin(game, craft)
	var safe := _interruption_runtime_observation(game)
	_check(awake and game.active_ship == craft and not game.player.is_sleeping()
		and not game.player.is_seated() and craft.get_crew_role_authority() == null
		and not game.player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META)
		and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1
		and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state,
		"ordinary HUD Resume returns an awake supported home Jovian cabin without engineer, pilot or airborne pose replay")
	_check(await _engineer_claim(game, craft), "the recovered awake player ordinarily walks and interacts into a fresh actual engineer claim")
	craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _settle_frames(3)
	var model := craft.get_component_damage()
	var component: Dictionary = model.get_component_states()[1]
	# This real localized hull-damage owner fixture creates repair work. It does
	# not set integrity, kit inventory, claims or repair flags directly.
	craft.apply_damage(craft.maximum_hull * 0.35, craft.to_global(component.local_position))
	await _settle_frames(2)
	var selected := StringName(craft.get_engineer_gameplay_state().selection.get("component_id", &""))
	var integrity_before := model.get_component_integrity(selected)
	var kits_before := int(craft.get_engineer_repair_state().resource_units)
	Input.action_press(&"fire")
	await _settle_frames(2)
	var active := craft.get_engineer_repair_state()
	_check(active.active and int(active.resource_units) == kits_before,
		"ordinary engineer FIRE starts real timed berthed work without an early kit spend")
	Input.action_release(&"fire")
	await _settle_frames(30)
	var committed := craft.get_engineer_repair_state()
	var integrity_after := model.get_component_integrity(selected)
	_check(committed.reason == &"repair_committed" and int(committed.resource_units) == kits_before - 1
		and model.get_component_integrity(selected) > integrity_before,
		"normal berth ticks commit real component improvement and exactly one finite repair kit")
	await _settle_frames(50)
	craft.apply_damage(craft.maximum_hull * 0.35, craft.to_global(component.local_position))
	await _settle_frames(2)
	Input.action_press(&"fire")
	await _settle_frames(2)
	_check(craft.get_engineer_repair_state().active, "a subsequent ordinary FIRE starts genuine work before the stand interruption")
	Input.action_release(&"fire")
	_check(await _engineer_stand(game, craft) and not craft.get_engineer_repair_state().active
		and int(craft.get_engineer_repair_state().resource_units) == kits_before - 1,
		"ordinary midrepair stand retires the exact claim and cancels work without another kit")
	_check(_convoy_receipts(game) == before_receipts and game.get_active_activity_snapshot().state_id == &"failed"
		and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state,
		"ordinary engineer work and stand preserve the adjacent failed convoy and its prior paid receipt")
	_check(await _engineer_helm(game, craft), "ordinary cabin walking and Interact retake the real Jovian helm after engineer stand")
	craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	Input.action_press(&"move_forward")
	await _settle_frames(2)
	Input.action_release(&"move_forward")
	_check(craft.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE and craft.get_last_ship_command().throttle > 0.0,
		"the recovered Jovian helm accepts ordinary throttle without an engineer assignment")
	_check(_convoy_receipts(game) == before_receipts and foreign_settings == store.get_snapshot().runtime_settings
		and foreign_cargo == store.get_snapshot().jovian_cargo_session,
		"role recovery and real repair retain the actual settings, cargo and first convoy receipt")
	var closed := game.mark_orderly_shutdown()
	_check(closed.accepted and game.get_instance_id() == main_id, "the exact recovered Boot Main closes both existing marker owners")
	var outcome := {"boundary": boundary, "receipts_before": before_receipts, "receipts_after": _convoy_receipts(game),
		"crash_events": crash_events, "runtime_observation": observation, "safe_recovery_observation": safe,
		"safe_context": context, "foreign_settings": foreign_settings, "foreign_cargo": foreign_cargo,
		"repair_observation": {"kits_before": kits_before, "kits_after": int(committed.resource_units),
			"integrity_before": integrity_before, "integrity_after": integrity_after},
		"live_seat_work_restore": "NOT_SUPPORTED", "repair_inventory_restore": "NOT_SUPPORTED", "airborne_pose_restore": "NOT_SUPPORTED",
		"continuation_method": "real_awake_home_jovian_cabin_walk_engineer_repair_stand_then_helm_throttle",
		"assertions": _assertions, "entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify(outcome))
		get_tree().quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)


func _hulk_receipts(game: GameFlow) -> int:
	var record: Dictionary = game.get_activity_reward_report().authority.record
	return int(record.reward_counts.get(String(DerelictPowerRestorationActivity.REWARD_ID), 0))


## Real Boot/owner interruption capability: authored breaker engagement and
## caller physics ticks earn the terminal. Only reward I/O is faulted using the
## existing filesystem wrapper; route positioning does not invent entitlement.
func _run_hulk(game: GameFlow, store: UserDataStore, entry: String) -> void:
	if recovery_context != "pilot":
		_fail("hulk interruption supports the actual pilot recovery context only")
		return
	var main_id := game.get_instance_id()
	game.set_physics_process(false)
	var craft: HeroShip
	var slot := DerelictPowerRestorationActivity.PERSISTENCE_SLOT
	var path := str(store.get("_path"))
	if stage == "arm":
		game.call("_on_settings_save_requested")
		_check(game.cargo_delivery_activity.start(game.cargo_delivery_activity.get_generation()).accepted
			and game.save_jovian_cargo_session().accepted,
			"the actual cargo owner saves unrelated delivery progress and transfer receipts")
		game.start_shift()
		await _load_beacon_binding(game, "hulk")
		game.call("_sync_hulk_power_restoration_binding")
		var hulk := game.call("_get_station_hulk") as AbandonedStationHulk
		if not is_instance_valid(hulk):
			_fail("Boot streams the actual collision-backed hulk and its breaker")
			return
		# Route positioning fixture only; real on-foot ownership and the physical
		# breaker's reach/engage contract remain unchanged.
		game.player.teleport_to(Transform3D(Basis.IDENTITY, hulk.get_breaker_world_position()))
		await _settle_frames(4)
		var breaker := hulk.get_breaker()
		_check(not game.player.is_seated() and game.player.is_control_enabled()
			and game.player.get_nearby_interactables().has(breaker) and breaker.call("interact", game.player),
			"the real on-foot Player discovers and engages the authored streamed breaker")
		var original := store.get("_filesystem") as UserDataFilesystem
		var fault := ActivityRewardFault.new(original, String(DerelictPowerRestorationActivity.ACTIVITY_ID))
		store.set("_filesystem", fault)
		for _frame in 180:
			await get_tree().physics_frame
			game.call("_advance_hulk_power_restoration", 1.0 / 60.0)
		var boundary: Dictionary = store.get_snapshot().get(slot, {})
		var live := game.get_hulk_power_restoration_snapshot()
		_check(DerelictPowerRestorationActivity.validate_persistence_record(boundary).accepted
			and boundary.generation == 1 and boundary.elapsed_seconds == 3.0
			and live.state_id == &"complete" and live.reward_pending and fault.rejected and _hulk_receipts(game) == 0,
			"180 genuine owner physics ticks stage the full earned terminal before a refused real reward write")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		craft = game.get_flyable_ships()[1] as HeroShip
		game.canopy_motion_time = 0.01
		game.boarding_motion_time = 0.02
		# Return positioning alone confers no pilot authority: the same boarding
		# transition must acquire its real Player and record the settled preference.
		game.player.teleport_to(craft.get_boarding_entry_transform())
		game.call("_board_ship", craft)
		_check(await _wait_for_real_pilot(game, craft), "hulk arm acquires the actual Player pilot before interruption")
		var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		_check(context.get("mode") == "pilot" and context.get("craft_id") == String(craft.get_ship_id())
			and boundary == store.get_snapshot().get(slot, {}),
			"hulk arm durably saves its genuine safe-home pilot without changing earned completion")
		get_tree().paused = true
		store.set("_filesystem", original)
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify({"boundary": boundary, "receipts": 0,
			"activity": activity, "foreign_settings": store.get_snapshot().runtime_settings,
			"foreign_cargo": store.get_snapshot().jovian_cargo_session,
			"runtime_observation": _interruption_runtime_observation(game),
			"fixture_method": "on_foot_route_positioning_real_breaker_and_180_owner_physics_ticks_then_real_pilot_boarding",
			"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}))
		return
	var boundary: Dictionary = store.get_snapshot().get(slot, {})
	if not DerelictPowerRestorationActivity.validate_persistence_record(boundary).accepted or _hulk_receipts(game) not in [0, 1]:
		_fail("hulk restart requires a supported genuine earned terminal and at most one cell receipt")
		return
	game.call("_sync_hulk_power_restoration_binding")
	var live := game.get_hulk_power_restoration_snapshot()
	# Normal Boot may already have completed its legitimate automatic retry.
	# Observe that receipt honestly; do not suppress or undo production payment.
	var receipts_at_boot := _hulk_receipts(game)
	var payment_commit := store.get_commit_metadata() if receipts_at_boot == 1 else {}
	var recovery := game.get_recovery_available_snapshot()
	var crash_events := 0
	for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	_check(((receipts_at_boot == 0 and live.state_id == &"complete" and live.reward_pending)
		or (receipts_at_boot == 1 and live.state_id == &"claimed" and live.reward_claimed)) and not live.hulk_loaded
		and live.elapsed_seconds == 3.0 and live.generation == boundary.generation
		and crash_events == 1 and not recovery.is_empty() and recovery.get("state") == "running",
		"fresh Boot restores exact earned hulk completion or its legitimately paid ledger and one crash event without replaying the breaker timer")
	var observations := _interruption_runtime_observation(game)
	var foreign_settings: Dictionary = store.get_snapshot().runtime_settings
	var foreign_cargo: Dictionary = store.get_snapshot().get("jovian_cargo_session", {})
	var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	for candidate in game.get_flyable_ships():
		if String(candidate.get_ship_id()) == context.get("craft_id"):
			craft = candidate
	if craft == null or not _failures.is_empty():
		_fail("the saved hulk pilot identity must resolve its actual shipped craft before Resume")
		return
	var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start", int(recovery.session_id), int(recovery.startup_generation))
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.start_shift()
	var settled := await _wait_for_real_pilot(game, craft)
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	_check(resumed.get("accepted", false) and settled and area.get_reservation_token() == game.player
		and berth.get_occupant() == craft and berth.get_reservation_owner() == craft
		and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1
		and boundary == store.get_snapshot().get(slot, {}),
		"ordinary Resume reacquires the exact safe-home pilot while preserving the earned hulk terminal")
	Input.action_press(&"move_forward")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"move_forward")
	_check(str(craft.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE" and craft.get_last_ship_command().throttle > 0.0
		and _hulk_receipts(game) == receipts_at_boot and boundary == store.get_snapshot().get(slot, {}),
		"the recovered real pilot accepts ordinary throttle while preserving the exact earned terminal and current receipt count")
	var safe := _interruption_runtime_observation(game)
	var generation := store.get_generation()
	game.set_physics_process(true)
	for _frame in 120:
		if game.get_hulk_power_restoration_snapshot().reward_claimed:
			break
		await get_tree().physics_frame
	game.set_physics_process(false)
	var claimed := game.get_hulk_power_restoration_snapshot()
	if receipts_at_boot == 0:
		payment_commit = store.get_commit_metadata()
	var ledger: Dictionary = game.get_activity_reward_report().authority.record
	var receipt: Dictionary = ledger.get("last_receipt", {})
	_check(claimed.state_id == &"claimed" and claimed.reward_claimed and not claimed.reward_pending
		and _hulk_receipts(game) == 1 and ledger.get("total_receipts") == 1 and ledger.get("receipt_serial") == 1
		and receipt.get("activity_id") == String(DerelictPowerRestorationActivity.ACTIVITY_ID)
		and receipt.get("reward_id") == String(DerelictPowerRestorationActivity.REWARD_ID)
		and receipt.get("activity_generation") == boundary.generation and receipt.get("granted") == true
		and receipt.get("replay_allowed") == false and store.get_generation() == generation + (1 - receipts_at_boot)
		and str(payment_commit.id).begins_with("game-flow-reward-") and boundary == store.get_snapshot().get(slot, {}),
		"the actual production Boot or running retry owner pays exactly one cell and preserves its exact earned terminal")
	var bytes := FileAccess.get_file_as_bytes(path)
	var duplicate: Dictionary = game.call("_commit_hulk_power_reward")
	game.call("_advance_hulk_power_restoration", 1.0)
	_check(not duplicate.accepted and _hulk_receipts(game) == 1
		and FileAccess.get_file_as_bytes(path) == bytes and store.get_generation() == generation + (1 - receipts_at_boot),
		"late reward callback and production tick cannot repay the permanently claimed hulk cell")
	_check(not foreign_settings.is_empty() and not foreign_cargo.is_empty()
		and foreign_settings == store.get_snapshot().runtime_settings
		and foreign_cargo == store.get_snapshot().get("jovian_cargo_session", {}),
		"hulk recovery preserves unrelated production settings and cargo fields")
	_check(game.mark_orderly_shutdown().get("accepted", false), "hulk recovery closes both existing crash marker owners")
	_check(is_instance_valid(game) and game.get_instance_id() == main_id and game.get_tree() == get_tree(),
		"hulk recovery retains Boot's exact supplied Main owner")
	if not _failures.is_empty():
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)
		return
	print("IN_WORLD_RECOVERY_OK: " + JSON.stringify({"boundary": boundary, "paid_boundary": store.get_snapshot().get(slot, {}),
		"receipts_before": 0, "receipts_after": _hulk_receipts(game), "crash_events": crash_events, "activity": activity,
		"foreign_settings": foreign_settings, "foreign_cargo": foreign_cargo, "payment_commit": payment_commit,
		"runtime_observation": observations, "safe_recovery_observation": safe,
		"continuation_method": "production_automatic_hulk_retry_and_real_safe_home_pilot_resume",
		"receipts_at_boot": receipts_at_boot, "payment_stage": "boot" if receipts_at_boot == 1 else "running_retry",
		"assertions": _assertions, "entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context}))
	get_tree().quit(0)


## Installed active-visit acceptance. As in the existing Ember soak, only the
## orbital-anchor hold and initial corridor-entry pose are staged. This excludes
## canonical outbound travel. Cold production recovery returns to the ordinary
## yard on foot; another admitted trip resumes the saved survey, never its standing pose.
const EMBER_PROBE_PLACEMENTS := ["orbital_anchor_hold", "initial_corridor_entry"]


func _ember_surface(game: GameFlow) -> Dictionary:
	return game.ember_surface_loop_production_binding.get_planetary_surface_snapshot()


func _ember_route(game: GameFlow) -> Dictionary:
	return (_ember_surface(game).get("relay_survey", {}) as Dictionary).get("mandatory_route", {}) as Dictionary


func _ember_receipts(game: GameFlow) -> int:
	var record := game.get_activity_reward_report().get("authority", {}).get("record", {}) as Dictionary
	return int((record.get("reward_counts", {}) as Dictionary).get("ember_beacon_data", 0))


func _ember_wait_phase(game: GameFlow, phase_id: int, budget: int) -> bool:
	for _tick in budget:
		var host := game.ember_surface_loop_host
		if host.get_phase() == phase_id:
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			return false
		await get_tree().physics_frame
		await get_tree().process_frame
	return game.ember_surface_loop_host.get_phase() == phase_id


func _ember_walk_axis(game: GameFlow, axis: String, bound: float, greater: bool,
		action: StringName, budget: int) -> bool:
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance()
	if not is_instance_valid(loaded):
		return false
	var region := loaded.get_node("LandingRegion") as Node3D
	var initial := region.to_local(game.player.global_position)
	var initial_axis := initial.x if axis == "x" else initial.z
	var walk_speed: float = game.player.walk_speed
	var physics_hz := Engine.physics_ticks_per_second
	if not initial.is_finite() or not is_finite(bound) or not is_finite(walk_speed) \
			or walk_speed <= 0.0 or physics_hz <= 0 or budget <= 0:
		return false
	var distance := maxf(bound - initial_axis if greater else initial_axis - bound, 0.0)
	# This inner fixture deadline now allows ordinary travel time plus the old
	# budget / physics_hz allowance for acceleration and settling. Count actual
	# physics frames, since a physics/process observation pair can span many.
	# Route, held actions, walking speed and acceptance checks stay unchanged;
	# the runner's original 300 s stage and 1200 s overall caps still apply.
	var frame_allowance := int(ceil(distance / walk_speed * float(physics_hz))) + budget
	var started_frame := Engine.get_physics_frames()
	var reached := false
	Input.action_press(action)
	while Engine.get_physics_frames() - started_frame <= frame_allowance:
		var local := region.to_local(game.player.global_position)
		var value := local.x if axis == "x" else local.z
		if (value >= bound if greater else value <= bound):
			reached = true
			break
		if not game.player.is_control_enabled() or game.player.is_seated() 				or game.ember_surface_loop_host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			break
		if Engine.get_physics_frames() - started_frame == frame_allowance:
			break
		await get_tree().physics_frame
		await get_tree().process_frame
	Input.action_release(action)
	await _settle_frames(4)
	return reached and game.player.is_on_floor()


func _ember_visit_observation(game: GameFlow, craft: HeroShip) -> Dictionary:
	var source := craft.get_local_input_source()
	var command := craft.get_last_ship_command()
	var telemetry := craft.get_telemetry()
	return {
		"runtime": _interruption_runtime_observation(game),
		"input": {
			"focused": bool(source.get("_application_focused")),
			"paused": bool(source.get("_scene_tree_paused")),
			"enabled_owner": source.is_enabled_owner(),
			"current_command_source": craft.get_command_source() == source,
			"configuration_valid": source.is_input_configuration_valid(),
			"hover_pressed": Input.is_action_pressed(&"hover"),
			"forward_strength": Input.get_action_strength(&"move_forward"),
		},
		"last_consumed_command": command.to_dictionary() if command != null else {},
		"engine_state": telemetry.get("engine_state", &""),
		"throttle": telemetry.get("throttle", 0.0),
		"speed": telemetry.get("speed", 0.0),
	}


func _ember_visit_rejected(game: GameFlow, craft: HeroShip, checkpoint: String,
		details: Dictionary = {}) -> bool:
	var local_player_position: Variant = null
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance()
	if is_instance_valid(loaded):
		var region := loaded.get_node_or_null("LandingRegion") as Node3D
		if is_instance_valid(region):
			var local := region.to_local(game.player.global_position)
			local_player_position = [local.x, local.y, local.z]
	print("EMBER_INTERRUPTION_VISIT_REJECTED: " + JSON.stringify({
		"stage": stage, "checkpoint": checkpoint, "details": details,
		"observation": _ember_visit_observation(game, craft),
		"surface_player": {"position_region_local_m": local_player_position,
			"on_floor": game.player.is_on_floor(), "control_enabled": game.player.is_control_enabled()},
		"host_phase": game.ember_surface_loop_host.get_phase(),
		"persistence": game.get_ember_interrupted_journey_persistence_report(),
		"cruise": game.get_planetary_cruise_report(),
		"host": game.ember_surface_loop_host.get_snapshot(),
	}, "", true, true))
	return false


func _ember_staging_collision_observation(game: GameFlow, craft: HeroShip) -> Dictionary:
	var proof: Dictionary = game.planetary_cruise_binding.get_snapshot().get(
		"last_result", {}).get("evidence", {}).get("proof", {})
	var names := proof.get("shape_names", PackedStringArray()) as PackedStringArray
	var transforms := proof.get("shape_transforms", []) as Array
	var motion := (proof.get("direction_world", Vector3.ZERO) as Vector3) * float(
		proof.get("sweep_distance_meters", 0.0))
	var collisions := []
	var space := craft.get_world_3d().direct_space_state
	for child in craft.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var index := names.find(str(collision.name))
		if index < 0 or index >= transforms.size():
			continue
		# Repeat only the refused proof's physical query, without submitting a new
		# capability or touching any collision, flight or authority state.
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = transforms[index] as Transform3D
		query.collision_mask = int(proof.get("collision_mask", craft.collision_mask))
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [craft.get_rid()]
		query.margin = 0.0
		var hits := space.intersect_shape(query, 4)
		query.motion = motion
		var fractions := space.cast_motion(query)
		if hits.is_empty() and fractions.size() == 2 and float(fractions[0]) < 1.0:
			query.motion = Vector3.ZERO
			var contact_transform := query.transform
			contact_transform.origin += motion * float(fractions[1])
			query.transform = contact_transform
			hits = space.intersect_shape(query, 4)
		for hit: Dictionary in hits:
			var collider: Object = hit.get("collider")
			collisions.append({
				"shape": str(collision.name), "safe_unsafe_fractions": fractions,
				"collider_id": hit.get("collider_id", 0),
				"collider_path": str((collider as Node).get_path()) if collider is Node else "",
				"collider_class": collider.get_class() if collider != null else "",
				"collider_layer": (collider as CollisionObject3D).collision_layer if collider is CollisionObject3D else 0,
				"collider_position": (collider as Node3D).global_position if collider is Node3D else Vector3.ZERO,
			})
	var roster := []
	for candidate: HeroShip in game.get_flyable_ships():
		roster.append({"ship_id": candidate.get_ship_id(), "selected": candidate == craft,
			"position": candidate.global_position})
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	return {"coordinate_frame": frame.get_snapshot(), "roster": roster,
		"proof_ship_position": proof.get("ship_position_world", Vector3.INF),
		"proof_sequence": proof.get("proof_sequence", 0), "collisions": collisions}


func _ember_enter_on_foot(game: GameFlow, craft: HeroShip) -> bool:
	# Select before departure: ordinary FREE_FLIGHT starts the selected family,
	# while convoy activation waits for its real rendezvous instead of launch.
	var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
	if not selected.get("accepted", false):
		return _ember_visit_rejected(game, craft, "activity_selection", {"result": selected})
	# Ordinary launch controls establish FREE_FLIGHT and release the yard lease.
	Input.action_press(&"hover")
	Input.action_press(&"move_forward")
	for _tick in 240:
		await get_tree().physics_frame
		if game.phase == GameFlow.Phase.FREE_FLIGHT:
			break
	await _settle_frames(24)
	var held_launch := _ember_visit_observation(game, craft)
	Input.action_release(&"hover")
	Input.action_release(&"move_forward")
	await _settle_frames(4)
	if game.phase != GameFlow.Phase.FREE_FLIGHT:
		return _ember_visit_rejected(game, craft, "ordinary_launch", {"held_launch": held_launch})
	var admitted: Dictionary = game.call("_begin_player_ember_surface_journey", 1)
	if not admitted.get("accepted", false):
		return _ember_visit_rejected(game, craft, "ember_admission", {"result": admitted})
	var cruise := game.planetary_cruise_binding
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := cruise.get_snapshot().get("canonical_destination_orbital", {}) as Dictionary
	var activated := false
	var last_staging := {}
	for _tick in 420:
		var decoded := frame.orbital_to_world_streaming_position(canonical, frame.get_generation())
		var navigation := decoded.get("position", Vector3.INF) as Vector3
		if not navigation.is_finite():
			return _ember_visit_rejected(game, craft, "orbital_anchor_decode", {"canonical": canonical})
		craft.global_position = navigation + Vector3.BACK * 500.0
		craft.global_basis = Basis.IDENTITY
		craft.velocity = (navigation - craft.global_position).normalized() * 8.0
		last_staging = {"decoded": decoded, "placed_position": craft.global_position,
			"coordinate_frame_generation": frame.get_generation(), "tick": _tick}
		await get_tree().physics_frame
		var approach := cruise.get_snapshot().get("controller", {}).get("final_approach", {}) as Dictionary
		if StringName(approach.get("state_id", &"")) == &"final_approach":
			activated = true
			break
	if not activated:
		return _ember_visit_rejected(game, craft, "final_approach_staging", {
			"last_staging": last_staging,
			"collision_observation": _ember_staging_collision_observation(game, craft),
		})
	var host := game.ember_surface_loop_host
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance()
	if not is_instance_valid(loaded):
		return _ember_visit_rejected(game, craft, "surface_residency")
	var region := loaded.get_node("LandingRegion") as Node3D
	var corridor := host.get_snapshot().get("approach_entry", {}).get("envelope", {}).get(
		"corridor_transform_region_local_m", Transform3D.IDENTITY) as Transform3D
	craft.global_transform = region.global_transform * corridor
	craft.velocity = Vector3.ZERO
	if not await _ember_wait_phase(game, EmberSurfaceLoopHost.Phase.LANDED, 3000):
		return _ember_visit_rejected(game, craft, "landed_wait", {
			"target_phase": EmberSurfaceLoopHost.Phase.LANDED, "budget": 3000})
	var berth := game.ember_surface_berth
	_check(berth.get_occupant() == craft and not berth.get_reservation_token(craft).is_empty(),
		"the actual Ember Host lands the actual craft under its real caldera berth lease")
	if not await _ember_wait_phase(game, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, 600):
		return _ember_visit_rejected(game, craft, "surface_outbound_wait", {
			"target_phase": EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, "budget": 600})
	# The authored pad egress avoids the parked craft, then reaches staging.
	for leg: Array in [["x", -9.0, false, &"move_back", 90],
		["z", 8.0, true, &"move_right", 120], ["x", 17.5, true, &"move_forward", 150],
		["z", 0.5, false, &"move_left", 120], ["x", 41.5, true, &"move_forward", 150]]:
		if not await _ember_walk_axis(game, leg[0], leg[1], leg[2], leg[3], leg[4]):
			return _ember_visit_rejected(game, craft, "authored_egress_leg", {
				"leg": leg, "axis": leg[0], "bound": leg[1], "greater": leg[2],
				"action": leg[3], "budget": leg[4]})
	if not await _ember_wait_phase(game, EmberSurfaceLoopHost.Phase.ON_FOOT, 180):
		return _ember_visit_rejected(game, craft, "on_foot_wait", {
			"target_phase": EmberSurfaceLoopHost.Phase.ON_FOOT, "budget": 180})
	return true


func _ember_document_text(store: UserDataStore, boundary: Dictionary) -> String:
	# Transport the actual wire text: parsing and re-encoding a JSON number can
	# change its final digits even with full-precision output.
	var text := FileAccess.get_file_as_string(str(store.get("_path")))
	var document: Variant = JSON.parse_string(text)
	_check(document is Dictionary \
		and document.get("payload") is Dictionary \
		and document.get("payload", {}).get("ember_relay_survey_completion", {}) == boundary \
		and int(document.get("generation", -1)) == store.get_generation() \
		and document.get("commit", {}) == store.get_commit_metadata(),
		"the actual persisted Ember document matches the retained runtime boundary")
	return text


## Separate release scenario: cut immediately after durable explicit abandon,
## while the real on-foot Host is still waiting for the player to board. This
## qualifies neither the return home nor completed earned-debt recovery.
func _run_ember_abandon(game: GameFlow, store: UserDataStore, entry: String) -> void:
	if recovery_context != "pilot":
		_fail("Ember abandon interruption requires the existing real pilot visit")
		return
	var key := "ember_relay_survey_completion"
	var archive_key := key + "_declined"
	var main_id := game.get_instance_id()
	var craft := game.get_flyable_ships()[1] as HeroShip
	var boundary: Dictionary = store.get_snapshot().get(archive_key, {}).duplicate(true)
	var crash_events := 0
	var safe_observation := {}
	var boot_observation := {}
	var boot_persistence := game.get_ember_interrupted_journey_persistence_report()
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	if stage == "arm":
		game.call("_on_settings_save_requested")
		# Retain the existing engineer probe's real initial-manifest boundary.
		# Its ordinary persisted reset leaves cargo idle during the Ember visit.
		var cargo_started := game.cargo_delivery_activity.start(game.cargo_delivery_activity.get_generation())
		var cargo_saved := game.save_jovian_cargo_session()
		var cargo_reset := game.cargo_delivery_activity.reset_with_persistence(
			game.cargo_delivery_activity.get_generation(), game.save_jovian_cargo_session)
		_check(cargo_started.accepted and cargo_saved.accepted and cargo_reset.accepted
			and game.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
			and not store.get_snapshot().get("jovian_cargo_session", {}).is_empty(),
			"Ember abandon saves an actual unrelated idle cargo manifest before the visit")
		game.start_shift()
		game.call("_board_ship", craft)
		_check(await _wait_for_real_pilot(game, craft),
			"Ember abandon arm acquires the real yard pilot before disclosed flight placement")
	else:
		var recovery := game.get_recovery_available_snapshot()
		for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
			if event.get("event_code") == "crash_detected":
				crash_events += 1
		_check(not boundary.is_empty() and not store.get_snapshot().has(key)
			and not boundary.get("completion", {}).get("route_identity", {}).get("complete", true)
			and not boot_persistence.get("adopted", true)
			and not boot_persistence.get("restore_status", {}).get("checkpoint_resume", {}).get("accepted", false)
			and _ember_receipts(game) == 0 and crash_events == 1 and not recovery.is_empty()
			and game.ember_surface_loop_host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE,
			"a distinct Boot retains the declined incomplete receipt without adopting its location, route or reward")
		if not _failures.is_empty():
			_fail("cold Ember abandon recovery requires the actual declined boundary")
			return
		boot_observation = _interruption_runtime_observation(game)
		var stale: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start",
			int(recovery.session_id) + 1, int(recovery.startup_generation))
		_check(not stale.get("accepted", false), "Ember abandon recovery refuses a stale Resume fence")
		var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start",
			int(recovery.session_id), int(recovery.startup_generation))
		game.start_shift()
		await _settle_frames(4)
		var yard := _interruption_runtime_observation(game)
		_check(resumed.get("accepted", false) and not game.player.is_seated()
			and game.player.is_control_enabled() and not game.active_ship.is_piloted()
			and game.ember_surface_loop_host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE
			and not store.get_snapshot().has(key) and store.get_snapshot().get(archive_key, {}) == boundary
			and _ember_receipts(game) == 0,
			"fenced Resume reaches the ordinary yard on foot with no old surface visit or payment")
		game.call("_board_ship", craft)
		var settled := await _wait_for_real_pilot(game, craft)
		var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
		var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
		_check(settled and area.get_reservation_token() == game.player and berth.get_occupant() == craft
			and berth.get_reservation_owner() == craft
			and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1,
			"Ember abandon recovery boards the actual craft at its ordinary home berth")
		safe_observation = _interruption_runtime_observation(game)
		safe_observation["cold_yard_before_boarding"] = yard
	var foreign_settings: Dictionary = store.get_snapshot().get("runtime_settings", {}).duplicate(true)
	var foreign_cargo: Dictionary = store.get_snapshot().get("jovian_cargo_session", {}).duplicate(true)
	if not _failures.is_empty() or not await _ember_enter_on_foot(game, craft):
		_fail("Ember abandon requires the real cruise, landing, disembark and authored egress")
		return
	var host := game.ember_surface_loop_host
	var identities := host.get_snapshot().get("identities", {}) as Dictionary
	_check(identities.get("player_instance_id") == game.player.get_instance_id()
		and identities.get("ship_instance_id") == craft.get_instance_id()
		and game.player.is_on_floor() and not game.player.is_seated() and game.player.is_control_enabled(),
		"the new process actors own the actual admitted standing survey")
	if stage == "arm":
		_check(await _ember_walk_axis(game, "z", -44.0, false, &"move_left", 600)
			and await _ember_walk_axis(game, "x", 180.0, true, &"move_forward", 1800),
			"Ember abandon reaches the first real relay by ordinary held walking")
		var route := _ember_route(game).duplicate(true)
		var saved := game.save_interrupted_ember_journey()
		boundary = store.get_snapshot().get(key, {}).duplicate(true)
		var saved_document_json := _ember_document_text(store, boundary)
		_check(saved.get("accepted", false) and saved.get("binding_reason") == &"active_journey_saved"
			and route.get("next_checkpoint_index") == 1 and not route.get("complete", true)
			and _ember_receipts(game) == 0,
			"Ember abandon starts from a real durable incomplete first-relay save")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var saved_observation := _interruption_runtime_observation(game)
		# No await or additional commit separates the actual save and decline.
		# UserDataStore rotates that exact primary to .bak during the one CAS;
		# the driver independently reads both files at the paused boundary.
		var generation := store.get_generation()
		var abandoned := game.abandon_ember_surface_journey()
		get_tree().paused = true
		var payload := store.get_snapshot()
		_check(abandoned.get("accepted", false) and abandoned.get("reason") == &"ember_surface_abandon_pending_return"
			and host.get_abandon_snapshot().get("requested", false)
			and not payload.has(key) and payload.get(archive_key, {}) == boundary
			and store.get_generation() == generation + 1
			and _ember_receipts(game) == 0
			and payload.get("runtime_settings", {}) == foreign_settings
			and payload.get("jovian_cargo_session", {}) == foreign_cargo,
			"public explicit abandon atomically declines the exact saved receipt while awaiting real reboarding")
		var declined_document_json := _ember_abandon_document_text(store, boundary)
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify({"activity": activity,
			"entry": entry, "recovery_context": recovery_context, "loaded_main_instance_id": main_id,
			"boundary": boundary, "route": route, "receipts": 0,
			"saved_document_json": saved_document_json, "declined_document_json": declined_document_json,
			"abandon_result": abandoned, "abandon_state": host.get_abandon_snapshot(),
			"runtime_observation": saved_observation, "foreign_settings": foreign_settings, "foreign_cargo": foreign_cargo,
			"initial_flight_placements": EMBER_PROBE_PLACEMENTS, "canonical_outbound": "NOT_RUN",
			"standing_pose_restore": "NOT_SUPPORTED", "abandon_return_home": "NOT_RUN",
			"completed_earned_debt": "NOT_RUN"}, "", true, true))
		return
	var route := _ember_route(game).duplicate(true)
	var restore := game.get_ember_interrupted_journey_persistence_report()
	_check(route.get("next_checkpoint_index") == 0 and route.get("next_objective_id") == "ember_relay_tower"
		and not route.get("complete", true) and not restore.get("adopted", true)
		and not restore.get("restore_status", {}).get("checkpoint_resume", {}).get("accepted", false)
		and not store.get_snapshot().has(key) and store.get_snapshot().get(archive_key, {}) == boundary
		and _ember_receipts(game) == 0,
		"a legitimate new physical arrival starts at observation zero without old progress or automatic payment")
	_check(not foreign_settings.is_empty() and not foreign_cargo.is_empty()
		and store.get_snapshot().get("runtime_settings", {}) == foreign_settings
		and store.get_snapshot().get("jovian_cargo_session", {}) == foreign_cargo,
		"the fresh survey preserves exact unrelated settings and cargo")
	# Capture the one legitimate receipt an ordinary quit could write for THIS
	# new visit. This uses existing production contracts without saving it, and
	# no frame advances before the orderly-close/quit sequence below.
	var prospective := _ember_prospective_journey_record(game, store)
	_check(prospective.get("accepted", false),
		"the fresh visit has a valid prospective current-zero checkpoint without a persistence write")
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	var closed := game.mark_orderly_shutdown()
	_check(closed.get("accepted", false) and game.get_instance_id() == main_id,
		"the distinct recovered Main closes its existing recovery markers")
	var final_document_json := _ember_abandon_document_text(store, boundary, prospective.record)
	if not _failures.is_empty():
		get_tree().quit(1)
		return
	print("IN_WORLD_RECOVERY_OK: " + JSON.stringify({"activity": activity, "entry": entry,
		"recovery_context": recovery_context, "loaded_main_instance_id": main_id,
		"boundary": boundary, "receipts_before": 0, "receipts_after": _ember_receipts(game), "crash_events": crash_events,
		"boot_persistence": boot_persistence, "boot_observation": boot_observation,
		"safe_recovery_observation": safe_observation, "runtime_observation": _interruption_runtime_observation(game),
		"fresh_route": route, "fresh_persistence": restore, "final_document_json": final_document_json,
		"prospective_fresh_record": prospective.record, "prospective_fresh_record_valid": true,
		"foreign_settings": foreign_settings, "foreign_cargo": foreign_cargo, "assertions": _assertions,
		"initial_flight_placements": EMBER_PROBE_PLACEMENTS,
		"continuation_method": "explicit_abandon_pending_cut_then_cold_yard_and_legitimate_new_survey",
		"canonical_outbound": "NOT_RUN", "standing_pose_restore": "NOT_SUPPORTED",
		"abandon_return_home": "NOT_RUN", "completed_earned_debt": "NOT_RUN"}, "", true, true))
	get_tree().quit(0)


func _ember_prospective_journey_record(game: GameFlow, store: UserDataStore) -> Dictionary:
	var generation := store.get_generation()
	var evidence: Dictionary = game.call("_collect_ember_interrupted_journey_save_evidence")
	if not evidence.get("accepted", false):
		return evidence
	var host := evidence.get("host", {}) as Dictionary
	var route := evidence.get("route", {}) as Dictionary
	var coordinate := evidence.get("coordinate", {}) as Dictionary
	var contract := PlanetarySaveSessionContract.new(&"ember_moon", evidence.get("frame") as PlanetaryCoordinateFrame)
	var begun := contract.begin_session(StringName("ember_expedition_%010d_%010d" % [
		int(host.get("generation", 0)), int(route.get("activity_generation", 0))]),
		int(host.get("attachment_generation", 0)), int(host.get("coordinate_frame_generation", 0)))
	if not begun.get("accepted", false):
		return begun
	var checkpoint := contract.save_surface_checkpoint(int(host.get("attachment_generation", 0)),
		int(host.get("coordinate_frame_generation", 0)), int(host.get("physics_advance_count", 0)),
		coordinate.get("orbital_coordinate", {}) as Dictionary,
		coordinate.get("surface_tangent_position", Vector3.ZERO) as Vector3,
		{"activity_id": str(route.get("activity_id", "")),
			"journey_phase_id": str(host.get("phase_id", "")),
			"route_checkpoint_index": int(route.get("next_checkpoint_index", -1))})
	if not checkpoint.get("accepted", false):
		return checkpoint
	var detached := contract.detach_session(int(host.get("attachment_generation", 0)),
		int(host.get("coordinate_frame_generation", 0)))
	if not detached.get("accepted", false):
		return detached
	var captured := PlanetaryReturnPersistenceAdapter.new().capture_interrupted_journey(contract,
		{"route_identity": route, "optional_progress": evidence.get("optional_progress", {})})
	if not captured.get("accepted", false):
		return captured
	var persistence := EmberRelaySurveyPersistenceBinding.new()
	var configured := persistence.configure(store, &"ember_relay_survey_completion")
	if not configured.get("accepted", false):
		return configured
	var recovery: Dictionary = persistence.call("_wire_copy", captured)
	var record := {"schema_version": float(EmberRelaySurveyPersistenceBinding.SCHEMA_VERSION),
		"payload_kind": EmberRelaySurveyPersistenceBinding.ACTIVE_JOURNEY_PAYLOAD_KIND,
		"slot_id": "ember_relay_survey_completion", "completion": recovery,
		"receipt_sha256": persistence.call("_digest", recovery)}
	# Compare the same full-precision wire interpretation the store installs.
	record = JSON.parse_string(JSON.stringify(record, "", true, true))
	var validated := persistence.validate_interrupted_journey_record(record)
	if not validated.get("accepted", false):
		return validated
	return {"accepted": store.get_generation() == generation,
		"record": record, "reason": &"fresh_current_checkpoint_captured_without_write"}


func _ember_abandon_document_text(
		store: UserDataStore, boundary: Dictionary, expected_fresh_record: Dictionary = {}
	) -> String:
	var text := FileAccess.get_file_as_string(str(store.get("_path")))
	var document: Variant = JSON.parse_string(text)
	_check(document is Dictionary and document.get("payload") is Dictionary
		and (not document.payload.has("ember_relay_survey_completion")
			if expected_fresh_record.is_empty()
			else document.payload.get("ember_relay_survey_completion", {}) == expected_fresh_record)
		and document.payload.get("ember_relay_survey_completion_declined", {}) == boundary
		and int(document.get("generation", -1)) == store.get_generation()
		and document.get("commit", {}) == store.get_commit_metadata(),
		"the actual primary file retains the exact decline and only the expected fresh checkpoint")
	return text


func _run_ember(game: GameFlow, store: UserDataStore, entry: String) -> void:
	if recovery_context != "pilot":
		_fail("Ember interruption supports only a real pilot boarding for each production visit")
		return
	var main_id := game.get_instance_id()
	var boundary: Dictionary = store.get_snapshot().get("ember_relay_survey_completion", {})
	var boundary_document_json := ""
	var receipt_before := {"store_generation": store.get_generation(),
		"commit": store.get_commit_metadata(), "receipt": boundary.duplicate(true)}
	var before_receipts := _ember_receipts(game)
	var crash_events := 0
	var safe_observation := {}
	var craft: HeroShip
	if stage == "arm":
		game.call("_on_settings_save_requested")
		craft = game.get_flyable_ships()[1] as HeroShip
		game.canopy_motion_time = 0.01
		game.boarding_motion_time = 0.02
		game.start_shift()
		game.call("_board_ship", craft)
		_check(await _wait_for_real_pilot(game, craft), "Ember arm acquires the real yard pilot before disclosed flight placement")
	else:
		boundary_document_json = _ember_document_text(store, boundary)
		var recovery := game.get_recovery_available_snapshot()
		for event: Dictionary in game.get_session_recovery_diagnostic_snapshot().get("events", []):
			if event.get("event_code") == "crash_detected":
				crash_events += 1
		craft = game.get_flyable_ships()[1] as HeroShip
		_check(not boundary.is_empty() and boundary.get("payload_kind") == "ember_relay_survey_active_journey"
			and before_receipts == 0 and crash_events == 1 and not recovery.is_empty(),
			"a fresh Boot process observes the genuine interrupted Ember receipt without replaying activity or reward")
		if not is_instance_valid(craft) or not _failures.is_empty():
			_fail("the genuine Ember receipt must be present before ordinary cold Resume")
			return
		var stale: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start",
			int(recovery.session_id) + 1, int(recovery.startup_generation))
		_check(not stale.get("accepted", false), "ordinary Resume refuses a stale recovery fence")
		var resumed: Dictionary = game.call("_handle_hud_session_recovery_choice", &"normal_start",
			int(recovery.session_id), int(recovery.startup_generation))
		game.canopy_motion_time = 0.01
		game.boarding_motion_time = 0.02
		game.start_shift()
		await _settle_frames(4)
		_check(resumed.get("accepted", false) and not game.player.is_seated()
			and game.player.is_control_enabled() and not game.active_ship.is_piloted()
			and boundary == store.get_snapshot().get("ember_relay_survey_completion", {}),
			"fenced cold Resume returns to the ordinary yard on foot while the exact Ember checkpoint remains passive")
		var yard_observation := _interruption_runtime_observation(game)
		game.call("_board_ship", craft)
		var settled := await _wait_for_real_pilot(game, craft)
		var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
		var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
		_check(settled and area.get_reservation_token() == game.player and berth.get_occupant() == craft
			and berth.get_reservation_owner() == craft
			and craft.global_position.distance_to(game.world.get_berth_transform(craft.get_home_berth_id()).origin) < 0.1
			and boundary == store.get_snapshot().get("ember_relay_survey_completion", {}),
			"a real new boarding acquires the home pilot for the return trip without consuming the saved survey")
		safe_observation = _interruption_runtime_observation(game)
		safe_observation["cold_yard_before_boarding"] = yard_observation
	if not _failures.is_empty() or not await _ember_enter_on_foot(game, craft):
		_fail("the real Ember cruise, Host landing, disembark and authored egress must reach on-foot survey admission")
		return
	var host := game.ember_surface_loop_host
	var session := host.get_travel_session_observation_source()
	var identities := host.get_snapshot().get("identities", {}) as Dictionary
	_check(is_instance_valid(session) and identities.get("player_instance_id") == game.player.get_instance_id()
		and identities.get("ship_instance_id") == craft.get_instance_id()
		and game.player.is_on_floor() and not game.player.is_seated() and game.player.is_control_enabled(),
		"the current real Host, session and fresh process actors own the admitted standing survey")
	if stage == "arm":
		_check(await _ember_walk_axis(game, "z", -44.0, false, &"move_left", 600)
			and await _ember_walk_axis(game, "x", 180.0, true, &"move_forward", 1800),
			"ordinary held walking reaches the authored relay checkpoint on real surface support")
		var route := _ember_route(game).duplicate(true)
		var saved := game.save_interrupted_ember_journey()
		boundary = store.get_snapshot().get("ember_relay_survey_completion", {})
		boundary_document_json = _ember_document_text(store, boundary)
		_check(route.get("next_checkpoint_index") == 1 and not route.get("complete", true)
			and saved.get("accepted", false) and saved.get("binding_reason") == &"active_journey_saved"
			and before_receipts == 0 and _ember_receipts(game) == 0,
			"the genuine first relay checkpoint is durable as an incomplete unpaid active journey")
		if not _failures.is_empty():
			get_tree().quit(1)
			return
		var ready := {"boundary": boundary, "boundary_document_json": boundary_document_json,
			"route": route, "receipts": 0,
			"runtime_observation": _interruption_runtime_observation(game),
			"entry": entry, "loaded_main_instance_id": main_id, "recovery_context": recovery_context,
			"activity": activity, "initial_flight_placements": EMBER_PROBE_PLACEMENTS,
			"host_attachment_generation": host.get_attachment_generation(),
			"safe_context": store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {}),
			"canonical_outbound": "NOT_RUN", "standing_pose_restore": "NOT_SUPPORTED"}
		get_tree().paused = true
		# Match UserDataStore's full-precision wire encoding for exact checkpoint comparison.
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify(ready, "", true, true))
		return
	var saved_route: Dictionary = boundary.completion.route_identity
	var route := _ember_route(game).duplicate(true)
	var restore := game.get_ember_interrupted_journey_persistence_report()
	var resumed: bool = (restore.restore_status.get("accepted", false) and restore.restore_status.checkpoint_resume.get("accepted", false)
		and _canonical(route) == saved_route and not store.get_snapshot().has("ember_relay_survey_completion")
		and _ember_receipts(game) == before_receipts)
	if not resumed:
		print("EMBER_INTERRUPTED_SURVEY_START_REJECTED: " + JSON.stringify({
			"survey_start_result": restore.get("survey_start_result", {}), "restore": restore,
			"saved_route": saved_route, "live_route": route, "surface": _ember_surface(game),
			"receipt_before": receipt_before, "receipt_after": {"store_generation": store.get_generation(),
				"commit": store.get_commit_metadata(),
				"receipt": store.get_snapshot().get("ember_relay_survey_completion", {})},
			"receipts_before": before_receipts, "receipts_after": _ember_receipts(game),
		}, "", true, true))
	_check(resumed,
		"ordinary production survey Start adopts the original checkpoint/generation and only then retires its receipt")
	if not _failures.is_empty():
		_fail("the genuine saved route must be adopted before continuation")
		return
	# Walk from staging through the relay, then outside the hazard arc to the
	# authored return beacon. No caller position sample substitutes for movement.
	_check(await _ember_walk_axis(game, "z", -44.0, false, &"move_left", 600)
		and await _ember_walk_axis(game, "x", 180.0, true, &"move_forward", 1800)
		and await _ember_walk_axis(game, "z", -210.0, false, &"move_left", 2100)
		and await _ember_walk_axis(game, "x", 540.0, true, &"move_forward", 4200),
		"the resumed real actor walks to the authored return beacon without checkpoint placement")
	await _settle_frames(12)
	game.call("_retry_owed_game_flow_activity_rewards")
	game.call("_retry_owed_game_flow_activity_rewards")
	var paid: Dictionary = store.get_snapshot().get("ember_relay_survey_completion", {})
	_check(_ember_receipts(game) == before_receipts + 1 and paid.get("payload_kind") == "ember_relay_survey_completion"
		and paid.get("completion", {}).get("activity_generation") == saved_route.activity_generation
		and paid.get("completion", {}).get("mandatory_route", {}).get("complete", false),
		"the preserved original survey completes and commits its real beacon-data receipt once despite reward retries")
	var counts := (store.get_snapshot().get("game_flow_reward_store", {}) as Dictionary).get("reward_counts", {}) as Dictionary
	await _settle_frames(12)
	game.save_interrupted_ember_journey()
	game.save_interrupted_ember_journey()
	_check(store.get_snapshot().get("ember_relay_survey_completion", {}) == paid
		and store.get_snapshot().get("game_flow_reward_store", {}).get("reward_counts", {}) == counts,
		"late repeated journey saves and production cadence preserve the paid terminal and exact reward ledger")
	var closed := game.mark_orderly_shutdown()
	_check(closed.get("accepted", false) and game.get_instance_id() == main_id and game.get_tree() == get_tree(),
		"the recovered Boot Main retains its owners and closes both existing recovery markers")
	var paid_document_json := _ember_document_text(store, paid)
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify({"boundary": boundary, "paid_boundary": paid,
			"boundary_document_json": boundary_document_json, "paid_document_json": paid_document_json,
			"receipts_before": before_receipts, "receipts_after": _ember_receipts(game), "crash_events": crash_events,
			"safe_recovery_observation": safe_observation, "runtime_observation": _interruption_runtime_observation(game),
			"resumed_route": route, "host_attachment_generation": host.get_attachment_generation(),
			"assertions": _assertions, "entry": entry,
			"loaded_main_instance_id": main_id, "recovery_context": recovery_context, "activity": activity,
			"initial_flight_placements": EMBER_PROBE_PLACEMENTS,
			"continuation_method": "ordinary_cold_yard_then_real_boarding_disclosed_initial_flight_placements_and_original_survey_resume",
			"canonical_outbound": "NOT_RUN", "standing_pose_restore": "NOT_SUPPORTED"}, "", true, true))
		get_tree().quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		get_tree().quit(1)
