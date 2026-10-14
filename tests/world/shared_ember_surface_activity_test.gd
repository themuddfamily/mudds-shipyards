extends SceneTree

## Focused shared surface owner test. Only the initial flight envelope is staged;
## the typed approach handoff, supported touchdown, disembarkation and survey
## observations all come from real production physics at the normal time scale.
## The default mode cancels after the first genuine checkpoint. Set
## KETH_SHARED_SURFACE_SUCCESS=1 to walk both checkpoints and return physically
## through normal canonical home cruise and ordinary pilot inputs. Outbound
## canonical travel and remote crew remain outside this single local ENet test.
const MAIN_SCENE := preload("res://scenes/main.tscn")
const SUCCESS_MODE_ENV := "KETH_SHARED_SURFACE_SUCCESS"
# Second beacon: ~396 m / 5.8 m/s, with terrain margin. Return walking: ~560 m
# plus the clear bow crossing. Ascent: normal boosted 20 km Host leg. Cruise:
# unchanged 8 Mm / 20 km/s, with acceleration, braking and typed approach.
# Home approach: the existing movement soak's 48,000 normal 60 Hz tick budget.
const SUCCESS_BEACON_SECONDS := 100.0
const SUCCESS_WALK_HOME_SECONDS := 140.0
const SUCCESS_ASCENT_SECONDS := 240.0
const SUCCESS_CRUISE_SECONDS := 720.0
const SUCCESS_HOME_FLIGHT_SECONDS := 800.0
const FLIGHT_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_forward", &"move_back", &"pitch_up", &"pitch_down",
	&"roll_left", &"roll_right", &"brake", &"landing_assist", &"interact",
]
var _success_mode := false
var _return_phases: Dictionary = {}
var _reboard_identity_observed := false
var _failures: Array[String] = []
var _game: GameFlow
const WALK_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_forward", &"move_back"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_success_mode = OS.get_environment(SUCCESS_MODE_ENV) == "1"
	print("SHARED_SURFACE_MODE: ", "success" if _success_mode else "cancellation")
	_game = MAIN_SCENE.instantiate() as GameFlow
	root.add_child(_game)
	for _index in 120:
		await process_frame
		await physics_frame
		if _game.get("_initialized"):
			break
	_game.start_shift()
	var session := _game.host_network_session(43000 + OS.get_process_id() % 10000)
	_check(bool(session.get("accepted", false)), "actual ENet host starts")
	var ship := _game.get_node("HalyardCrewTransport") as HeroShip
	_game.player.teleport_to(ship.get_boarding_entry_transform())
	_game._board_ship(ship)
	if not await _until(func(): return _game._piloting and not _game._transition_busy, 15.0):
		_check(false, "production boarding owns Halyard pilot")
		_finish()
		return
	_check(_game.player.is_seated_at(ship.get_pilot_seat_anchor()), "host physically holds actual cockpit anchor")
	_game._sortie_departed_berth = true
	_game.phase = GameFlow.Phase.FREE_FLIGHT
	var claimed := _game._claim_network_host_pilot_seat(ship)
	_check(bool(claimed.get("accepted", false)), "existing host boarding ledger confirms pilot")
	var frame := _game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var cruise := _game.planetary_cruise_binding.get_snapshot()
	var destination: Vector3 = frame.orbital_to_world_streaming_position(
		cruise.canonical_destination_orbital, frame.get_generation()).position
	ship.global_position = destination + Vector3.BACK * 500.0
	ship.global_basis = Basis.looking_at((destination - ship.global_position).normalized(), Vector3.UP)
	ship.velocity = Vector3.ZERO
	var host := _game.ember_surface_loop_host
	var production := _game.ember_surface_loop_production_binding
	var journey = _game.get("_planetary_journey")
	var premature: Dictionary = journey.admit_shared_ember_surface()
	_check(not premature.accepted and production.get_planetary_surface_snapshot().is_empty(),
		"a seated shared pilot cannot create surface work before typed physical landing")
	var admitted := _game.engage_planetary_cruise()
	_check(bool(admitted.get("accepted", false)), "ordinary shared admission retains physical arrival owner")
	if not await _until(func(): return journey.shared_ember_surface_is_current(), 120.0):
		_check(false, "real typed approach and supported Halyard landing compose shared surface")
		var binding_failure := production.get_snapshot()
		print("SHARED_SURFACE_ADMISSION_FAILED: ", _game.get_network_planetary_journey_snapshot(),
			" host=", host.get_snapshot(), " binding=", {
				"state_id": binding_failure.get("state_id"),
				"last_result": binding_failure.get("last_result"),
				"last_late_result": binding_failure.get("last_late_result"),
			}, " cadence=", journey.get("_last_ember_surface_cadence_result"))
		_finish()
		return
	_check(host._landed_public_state_is_exact(), "surface admission retains actual occupied berth, strict hull and solid support")
	_check(not production.get_planetary_surface_snapshot().is_empty(), "same production surface binding owns authored survey")
	var composed := production.get("_planetary_composition") as Node
	var context: Dictionary = (journey.get("_shared_ember_surface_context") as Dictionary).duplicate(true)
	var duplicate: Dictionary = journey.admit_shared_ember_surface()
	_check(duplicate.accepted and production.get("_planetary_composition") == composed,
		"duplicate admission retains one surface composition")
	if not await _until(func(): return host.get_phase() == EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, 20.0):
		_check(false, "real Host disembarks its pilot through normal exterior transition")
		_finish()
		return
	_check(not _game.player.is_seated() and journey.shared_ember_surface_is_current()
		and _game._network_planetary_journey.is_active(), "intentional standing host retains authenticated shared journey")
	var landing := _game.ember_streaming_bootstrap.get_loaded_instance().get_node("LandingRegion") as Node3D
	var egress: Vector3 = host.get_snapshot().surface_route.egress_anchor
	var staging: Vector3 = host.get_snapshot().surface_route.staging_anchor
	# Halyard exits to port; the authored egress is starboard. Walk outside its
	# actual landed bow before crossing, within the same total egress deadline.
	var egress_detour: Array[Vector3] = [
		ship.to_global(Vector3(-9.0, 0.0, -16.0)),
		ship.to_global(Vector3(18.0, 0.0, -16.0)),
	]
	if not await _walk_to(egress, 20.0, egress_detour) or not await _walk_to(staging, 20.0):
		_check(false, "normal walking crosses ordered egress and staging anchors")
		_finish()
		return
	_check(await _until(func(): return production.get_planetary_surface_snapshot().adapter.activity_reward.state == &"active", 4.0),
		"on-foot boundary starts the genuine host-owned relay survey")
	var before := _game._runtime_settings_user_data_store.get_generation()
	var rewards: Dictionary = production.get_snapshot().relay_reward_commit
	_check(int(rewards.authority_commit_count) == 0 and int(rewards.persistence_commit_count) == 0,
		"starting the shared survey infers neither reward nor completed save")
	_check(not journey._ember_survey_return_is_admitted(production.get_snapshot())
		and journey._consume_ember_surface_reboard_interaction() and not _game.player.is_seated(),
		"ordinary shared reboard remains refused without durable completion and current manifest")
	# Reach a genuine authored checkpoint, through Player movement. The normal
	# production late sample must advance the Director; no route receipt is supplied.
	var tower := landing.to_global(Vector3(160.0, 0.0, -30.0))
	_check(await _walk_to(tower, 50.0), "actual Player walks to authored relay tower")
	_check(await _until(func(): return int(_game.activity_director.get_activity_snapshot(&"ember_beacon_survey").get("next_checkpoint_index", 0)) == 1, 4.0),
		"authenticated host observations advance real mandatory relay progress")
	if _success_mode:
		await _run_success(ship, landing, egress, staging)
		_finish()
		return
	var retained_reward := production.get("_planetary_reward_authority") as Callable
	var retained_gate := composed.get("_lifecycle_gate") as Callable
	# Exercise the real player cancellation seam while the survey is genuinely
	# ACTIVE. Its work gate closes immediately, but cleanup must still fail the
	# same Director generation rather than leave an active route behind it.
	var survey_before := _game.activity_director.get_activity_snapshot(&"ember_beacon_survey")
	_game.hud.planetary_cruise_toggle_requested.emit(_game._last_hud_planetary_cruise_toggle_serial + 1)
	var survey_after := _game.activity_director.get_activity_snapshot(&"ember_beacon_survey")
	var cancelled_runtime: Dictionary = production.get_planetary_surface_snapshot().adapter.activity_reward
	_check(bool(journey.get("_ember_surface_abandon_pending")) and not bool(retained_gate.call())
		and int(survey_after.state) == CheckpointRouteActivity.State.FAILED
		and int(survey_after.generation) == int(survey_before.generation)
		and cancelled_runtime.state == &"failed",
		"ordinary HUD cancellation terminalizes the same genuine Director survey after revoking its work gate")
	var cancelled_start: Dictionary = composed.call("start_relay_survey")
	var cancelled_reward: Dictionary = retained_reward.call({"activity_id": &"ember_beacon_survey"})
	var cancelled_manifest := production.issue_planetary_relay_survey_return_manifest()
	_check(not cancelled_start.accepted and not cancelled_reward.accepted and not cancelled_manifest.accepted
		and (cancelled_runtime.pending_reward as Dictionary).is_empty()
		and not journey._ember_survey_return_is_admitted(production.get_snapshot())
		and _game._runtime_settings_user_data_store.get_generation() == before,
		"cancelled work cannot restart, create debt, grant/save a reward or issue a successful survey return manifest")
	_game.shutdown_network_session(&"focused_shared_surface_done")
	_check(not journey.shared_ember_surface_is_current() and not bool(retained_gate.call()),
		"actual session stop revokes the visit and retained callbacks synchronously")
	var rejected: Dictionary = retained_reward.call({"activity_id": &"ember_beacon_survey"})
	var stopped_start: Dictionary = composed.call("start_relay_survey")
	_check(not rejected.accepted and not stopped_start.accepted,
		"old session cannot restart authored work or claim a reward")
	_check(_game._runtime_settings_user_data_store.get_generation() == before,
		"incomplete shared survey and stale callbacks do not write completion or reward")
	_check(int(context.journey_epoch) > 0 and _game.player.is_control_enabled(),
		"retired surface visit leaves standing player controls usable")
	_finish()

## After the common genuine checkpoint, all movement and lifecycle changes come
## from production ownership and ordinary Input actions. No receipt is injected.
func _run_success(ship: HeroShip, landing: Node3D, egress: Vector3, staging: Vector3) -> void:
	var production := _game.ember_surface_loop_production_binding
	var host := _game.ember_surface_loop_host
	var journey = _game.get("_planetary_journey")
	var store := _game._runtime_settings_user_data_store
	var original_commands := host.get("_original_command_source") as ShipCommandSource
	var boarding := host.get("_boarding_area") as ShipBoardingArea
	var context: Dictionary = journey._ember_survey_context(production.get_snapshot()).duplicate(true)
	var beacon := landing.to_global(Vector3(540.0, 30.0, -210.0))
	var survey_generation := int(_game.activity_director.get_activity_snapshot(&"ember_beacon_survey").get("generation", -1))
	var beacon_completed := func() -> bool:
		var observed := _game.activity_director.get_activity_snapshot(&"ember_beacon_survey")
		return survey_generation > 0 and int(observed.get("generation", -1)) == survey_generation \
			and int(observed.get("state", -1)) == CheckpointRouteActivity.State.COMPLETED \
			and int(observed.get("next_checkpoint_index", -1)) == 2 \
			and journey.shared_ember_surface_is_current()
	# The Director accepts the authored three-dimensional checkpoint radius.
	# Its real completion ends this walk before an unrelated center tolerance.
	if not await _walk_to(beacon, SUCCESS_BEACON_SECONDS, [], 1.5, beacon_completed):
		_check(false, "ordinary walking reaches the second authored survey beacon")
		return
	_check(true, "ordinary walking reaches the second authored survey beacon")
	if not await _until(func(): return production.get_planetary_surface_snapshot().adapter.activity_reward.state == &"completed", 4.0):
		_check(false, "genuine final observation completes the Director and durable reward")
		print("SHARED_SURFACE_COMPLETION_FAILED: ", production.get_snapshot())
		return
	var activity := _game.activity_director.get_activity_snapshot(&"ember_beacon_survey")
	var surface := production.get_planetary_surface_snapshot()
	var runtime: Dictionary = surface.adapter.activity_reward
	var reward: Dictionary = production.get_snapshot().relay_reward_commit
	var receipt := (reward.get("commit_receipt", {}) as Dictionary).duplicate(true)
	var authority := receipt.get("authority", {}) as Dictionary
	var evidence := authority.get("evidence", {}) as Dictionary
	var exact_identity := not context.is_empty()
	for key in ["owner_generation", "host_generation", "host_attachment_generation", "actor_instance_id", "session_instance_id"]:
		exact_identity = exact_identity and receipt.get(key) == context.get(key)
	for key in context:
		exact_identity = exact_identity and evidence.get(key) == context[key]
	_check(int(activity.get("state", -1)) == CheckpointRouteActivity.State.COMPLETED
		and int(activity.get("next_checkpoint_index", -1)) == 2
		and runtime.state == &"completed" and (runtime.pending_reward as Dictionary).is_empty()
		and int(receipt.get("activity_generation", -1)) == int(activity.get("generation", -2))
		and bool(authority.get("accepted", false))
		and bool((receipt.get("persistence", {}) as Dictionary).get("accepted", false))
		and exact_identity and int(reward.authority_commit_count) == 1
		and int(reward.persistence_commit_count) == 1,
		"same authenticated Director completion owns exactly one fenced authority and persistence commit")
	if not _failures.is_empty():
		return
	var reader := UserDataStore.new(str(store.get("_path")))
	var persistence := EmberRelaySurveyPersistenceBinding.new()
	var configured := persistence.configure(reader, GameFlow.EMBER_RELAY_SURVEY_PERSISTENCE_SLOT)
	var captured := persistence.capture(surface)
	var loaded := reader.load_read_only()
	var payload := reader.get_snapshot()
	var saved := payload.get("ember_relay_survey_completion", {}) as Dictionary
	var ledger := payload.get("game_flow_reward_store", {}) as Dictionary
	var authority_result := authority.get("authority_result", {}) as Dictionary
	var ledger_receipt := ledger.get("last_receipt", {}) as Dictionary
	_check(bool(configured.get("accepted", false)) and bool(captured.get("accepted", false))
		and bool(loaded.get("accepted", false))
		and reader.get_loaded_source() == &"primary" and reader.get_generation() == store.get_generation()
		and bool(persistence.validate_record(saved).get("accepted", false))
		and saved == captured.get("record", {})
		and int(ledger.get("total_receipts", -1)) == 1
		and int((ledger.get("reward_counts", {}) as Dictionary).get("ember_beacon_data", -1)) == 1
		and ledger_receipt == JSON.parse_string(JSON.stringify(authority_result.get("receipt", {})))
		and str(ledger_receipt.get("activity_id", "")) == "ember_beacon_survey"
		and int(ledger_receipt.get("activity_generation", -1)) == int(activity.get("generation", -2)),
		"independent read-only disk load retains the exact completed survey and its single matching reward receipt")
	if not await _until(func(): return journey._ember_survey_return_is_admitted(production.get_snapshot()), 4.0):
		_check(false, "coordinator admits its own durable generation-fenced return manifest")
		return
	_check(true, "coordinator admits its own durable generation-fenced return manifest")
	var saved_generation := store.get_generation()
	# Let genuine duplicate late ticks observe the terminal route in place.
	var settle_deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < settle_deadline:
		await physics_frame
	var repeated: Dictionary = production.get_snapshot().relay_reward_commit
	_check(repeated.commit_receipt == receipt and int(repeated.authority_commit_count) == 1
		and int(repeated.persistence_commit_count) == 1 and store.get_generation() == saved_generation,
		"duplicate production ticks preserve one reward, completion and save generation")
	if not _failures.is_empty():
		return
	# Retrace the clear terrain to staging and egress, then reverse the same bow
	# crossing used outbound. A single deadline covers this entire physical leg.
	var return_waypoints: Array[Vector3] = [
		landing.to_global(Vector3(160.0, 0.0, -30.0)), staging, egress,
		ship.to_global(Vector3(18.0, 0.0, -16.0)),
		ship.to_global(Vector3(-9.0, 0.0, -16.0)),
	]
	if not await _walk_to(boarding.global_position, SUCCESS_WALK_HOME_SECONDS, return_waypoints, 1.0):
		_check(false, "ordinary return walking retraces egress and reaches actual Halyard boarding area")
		return
	_check(bool(host.get_snapshot().surface_route.return_complete)
		and boarding.get_ship() == ship and _game.player.get_nearby_interactables().has(boarding),
		"live return route and actual nearby Halyard boarding area permit ordinary interaction")
	if not _failures.is_empty():
		return
	await _press_action(&"interact")
	if not await _until(func(): return _reboard_identity_observed, 15.0):
		_check(false, "ordinary interaction restores actual pilot anchor and boarding token through REBOARDED")
		return
	_check(true, "ordinary interaction restores actual pilot anchor and boarding token through REBOARDED")
	if not await _until(func(): return production.has_delivered_completion_handback(), SUCCESS_ASCENT_SECONDS):
		_check(false, "actual Host ascent clears Ember and delivers typed ownership handback")
		print("SHARED_SURFACE_ASCENT_FAILED: ", host.get_snapshot(), " binding=", production.get_snapshot())
		return
	var handback := (journey.get("_mudds_return_handback_receipt") as Dictionary).duplicate(true)
	var station_intent := (journey.get("_mudds_station_return_intent_receipt") as Dictionary).duplicate(true)
	var handoff := production.get_snapshot()
	_check(_return_phases.has(EmberSurfaceLoopHost.Phase.ASCENT)
		and _return_phases.has(EmberSurfaceLoopHost.Phase.ORBIT_RETURN)
		and bool(handback.get("command_source_restored", false))
		and bool(handback.get("boarding_reservation_retained", false))
		and bool(handback.get("player_seated", false)) and bool(handback.get("ship_piloted", false))
		and not bool(handback.get("host_attached", true))
		and int(handback.get("generation", -1)) == int(context.host_generation)
		and int(handback.get("retired_attachment_generation", -1)) == int(context.host_attachment_generation)
		and int(handback.get("current_attachment_generation", -1)) == int(context.host_attachment_generation) + 1
		and int(handback.get("ship_instance_id", 0)) == ship.get_instance_id()
		and int(handback.get("player_instance_id", 0)) == _game.player.get_instance_id()
		and ship.get_command_source() == original_commands
		and _game.player.is_seated_at(ship.get_pilot_seat_anchor())
		and _game.ember_surface_berth.get_occupant() == null
		and StringName(host.get("_berth_token")).is_empty()
		and bool(handoff.get("station_return_handoff_delivered", false))
		and bool(journey.get("_mudds_station_return_intent_consumption_attempted"))
		and not station_intent.is_empty() and int(handoff.get("handback_count", -1)) == 1,
		"real ascent and orbit return release surface lease and restore commands with one consumed station intent")
	if not _failures.is_empty():
		return
	if not await _until(func(): return StringName((journey.get("_last_mudds_return_approach_result") as Dictionary).get("reason", &"")) == &"return_approach_handed_to_station_lifecycle", SUCCESS_CRUISE_SECONDS):
		_check(false, "unchanged canonical Mudds cruise completes its real typed approach")
		print("SHARED_SURFACE_CRUISE_FAILED: ", journey.get("_last_mudds_return_approach_result"),
			" cruise=", _game.planetary_cruise_binding.get_snapshot())
		return
	_check(_game.phase == GameFlow.Phase.RETURN_TO_YARD
		and not is_instance_valid(_game.ember_streaming_bootstrap.get_loaded_instance())
		and not bool(journey.get("_planetary_return_receipt_consumed"))
		and not _game._return_registered,
		"canonical cruise unloads Ember and hands back flight while physical home arrival remains unearned")
	_check(await _fly_home_berth(ship), "ordinary pilot steering and admitted landing assist occupy the actual home berth")
	if not _failures.is_empty():
		return
	var berth := _game.world.get_berth_node(ship.get_home_berth_id()) as ShipBerth
	var token := berth.get_reservation_token(ship)
	var landing_report := ship.get_landing_contract_report()
	var network_landing := _game.get("_last_network_landing_handoff_result") as Dictionary
	var arrived := journey.get("_last_planetary_return_physical_arrival_result") as Dictionary
	_check(bool(landing_report.get("strict_dock_acceptance", false))
		and bool(landing_report.get("reservation_token_bound", false))
		and berth.get_occupant() == ship and not token.is_empty()
		and token == StringName(_game._berth_tokens.get(ship.get_instance_id(), &""))
		and berth.has_valid_lease(ship, token, ship.get_ship_id()) and _home_ship_supported(ship, berth)
		and bool(network_landing.get("accepted", false))
		and bool(network_landing.get("mutation_committed", false))
		and network_landing.get("status") == &"network_landing_committed"
		and bool(arrived.get("accepted", false)) and arrived.get("reason") == &"planetary_return_consumed"
		and bool(journey.get("_planetary_return_receipt_consumed"))
		and _game._return_registered and _game.phase == GameFlow.Phase.SHUT_DOWN,
		"strict supported home dock commits network landing and consumes genuine planetary arrival once into SHUT_DOWN")
	# Successful arrival retires the live surface binding and clears its receipts.
	# The disk record and coordinator's frozen ownership receipts survive that cleanup.
	var final_reward: Dictionary = production.get_snapshot().relay_reward_commit
	var final_loaded := reader.load_read_only()
	var final_payload := reader.get_snapshot()
	_check(int(final_reward.authority_commit_count) == 1 and int(final_reward.persistence_commit_count) == 1
		and bool(final_loaded.get("accepted", false))
		and final_payload.get("ember_relay_survey_completion", {}) == saved
		and final_payload.get("game_flow_reward_store", {}) == ledger
		and journey.get("_mudds_return_handback_receipt") == handback
		and journey.get("_mudds_station_return_intent_receipt") == station_intent,
		"the full physical return preserves the single durable reward and frozen one-shot ownership receipts")
	if not _failures.is_empty():
		return
	_check(await _exit_and_walk_home(ship, berth, token),
		"ordinary Interact releases the returned pilot and permits supported home apron walking while preserving the exact dock lease")

## Match the movement soak's usable home exit: wait for real propulsion shutdown,
## request exterior disembark through Interact, then walk along Halyard's apron.
func _exit_and_walk_home(ship: HeroShip, berth: ShipBerth, token: StringName) -> bool:
	var player := _game.player
	var boarding := ship.get_node("ShipBoardingArea") as ShipBoardingArea
	var ship_parent := ship.get_parent()
	var berth_parent := berth.get_parent()
	var exited := false
	for tick in 900:
		if not player.is_seated() and player.is_control_enabled() \
				and not _game._transition_busy and player.is_on_floor() \
				and _game.get_network_host_boarding_seat().is_empty():
			exited = true
			break
		if tick % 30 == 0:
			await _press_action(&"interact")
		await physics_frame
		await process_frame
	if not exited or _game._piloting or ship.is_piloted() or boarding.is_reserved() \
			or boarding.get_reservation_token() != null \
			or player.global_position.distance_to(ship.get_boarding_position()) >= 20.0 \
			or player.get_floor_normal().dot(player.up_direction) <= 0.9:
		return false
	for occupancy: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if occupancy.get("ship_id") == ship.get_ship_id() \
				and occupancy.get("seat_id") == StringName("%s_pilot" % String(ship.get_ship_id())):
			return false
	var walk_start := player.global_position
	# Halyard faces inboard at its apron edge. Backing away crosses the authored
	# open outboard gap; the production movement soak uses this supported route.
	var walk_action: StringName = &"move_right" if ship.get_ship_id() == &"halyard_new_design" else &"move_back"
	Input.action_press(walk_action)
	for _tick in 20:
		await physics_frame
	Input.action_release(walk_action)
	await physics_frame
	await process_frame
	var walk_distance := (player.global_position - walk_start).slide(player.up_direction).length()
	return walk_distance > 0.25 and walk_distance < 5.0 \
		and player.is_on_floor() and player.get_floor_normal().dot(player.up_direction) > 0.9 \
		and player.is_control_enabled() and not player.is_seated() \
		and not _game._piloting and not ship.is_piloted() and not _game._transition_busy \
		and not boarding.is_reserved() and boarding.get_reservation_token() == null \
		and _game.get_network_host_boarding_seat().is_empty() \
		and _game.active_ship == ship and ship.get_parent() == ship_parent \
		and _game.world.get_berth_node(ship.get_home_berth_id()) == berth \
		and berth.get_parent() == berth_parent and berth.get_occupant() == ship \
		and berth.get_reservation_token(ship) == token \
		and StringName(_game._berth_tokens.get(ship.get_instance_id(), &"")) == token \
		and berth.has_valid_lease(ship, token, ship.get_ship_id()) \
		and _home_ship_supported(ship, berth) and _game._return_registered

func _observe_return() -> void:
	if not _success_mode or not is_instance_valid(_game):
		return
	var host := _game.ember_surface_loop_host
	var phase := host.get_phase()
	_return_phases[phase] = true
	if phase == EmberSurfaceLoopHost.Phase.REBOARDED:
		var ship := _game.active_ship
		var boarding := host.get("_boarding_area") as ShipBoardingArea
		_reboard_identity_observed = _game.player.is_seated_at(ship.get_pilot_seat_anchor()) \
			and boarding.get_reservation_token() == _game.player and ship.is_piloted()

func _press_action(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await process_frame
	_observe_return()
	Input.action_release(action)

## This is the existing ordinary flight pattern from ember_transit_movement_soak:
## fly above yard walls, enter the open approach side, then request assist only
## when the actual home berth accepts the actual craft's capture observation.
func _fly_home_berth(ship: HeroShip) -> bool:
	var berth := _game.world.get_berth_node(ship.get_home_berth_id()) as ShipBerth
	var landing_requested := false
	var approach_leg := 0
	var deadline := Time.get_ticks_msec() + int(SUCCESS_HOME_FLIGHT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_release_flight()
		var report := _game.call(&"_get_active_landing_assist_report") as Dictionary
		if not landing_requested and report.get("selected_berth_id") == ship.get_home_berth_id() \
				and bool(report.get("assist_capture_accepted", false)):
			Input.action_press(&"landing_assist")
			landing_requested = true
		elif not landing_requested:
			var waypoint := berth.get_dock_transform() * Vector3(0.0, 120.0, -200.0) \
				if approach_leg == 0 else berth.get_assist_capture_transform().origin
			var offset := waypoint - ship.global_position
			if approach_leg == 0 and offset.length() < 12.0 and ship.velocity.length() < 10.0:
				approach_leg = 1
			var local := ship.global_basis.inverse() * offset.normalized()
			var yaw := atan2(local.x, -local.z)
			var pitch := atan2(local.y, Vector2(local.x, local.z).length())
			_set_signed_action(&"move_right", &"move_left", yaw * 3.0)
			_set_signed_action(&"pitch_up", &"pitch_down", pitch * 3.0)
			var up := berth.global_basis.y.normalized()
			var roll := atan2(up.dot(ship.global_basis.x), up.dot(ship.global_basis.y))
			_set_signed_action(&"roll_right", &"roll_left", roll * 3.0)
			var desired_speed := minf(ship.maximum_speed * 0.9,
				sqrt(maxf(0.0, offset.length() - 5.0) * ship.brake_acceleration) * 0.6)
			Input.action_press(&"move_forward" if absf(yaw) < 0.08 and absf(pitch) < 0.08 \
				and ship.velocity.length() < desired_speed else &"brake")
		await physics_frame
		await process_frame
		if _game.phase == GameFlow.Phase.SHUT_DOWN and _game._return_registered:
			_release_flight()
			return true
		if ship.is_destroyed() or not _game.player.is_seated_at(ship.get_pilot_seat_anchor()):
			break
		if landing_requested and not ship.is_landing_active() and not bool(ship.get_telemetry().get("landed", false)):
			landing_requested = false
	_release_flight()
	print("SHARED_SURFACE_HOME_FLIGHT_FAILED: ", {"phase": _game.phase, "position": ship.global_position,
		"speed": ship.velocity.length(), "landing": ship.get_landing_contract_report(),
		"arrival": _game.get("_planetary_journey").get("_last_planetary_return_physical_arrival_result")})
	return false

func _home_ship_supported(ship: HeroShip, berth: ShipBerth) -> bool:
	var bounds: AABB = ship.get_landing_collision_report().local_bounds
	var up := berth.global_basis.y.normalized()
	var lowest := INF
	var corners: Array[Vector3] = []
	for x: float in [bounds.position.x, bounds.end.x]:
		for y: float in [bounds.position.y, bounds.end.y]:
			for z: float in [bounds.position.z, bounds.end.z]:
				var corner := ship.global_transform * Vector3(x, y, z)
				var projection := corner.dot(up)
				if projection < lowest - 0.001:
					lowest = projection
					corners.assign([corner])
				elif absf(projection - lowest) <= 0.001:
					corners.append(corner)
	if corners.is_empty():
		return false
	var center := Vector3.ZERO
	for corner in corners:
		center += corner
	center /= float(corners.size())
	var query := PhysicsRayQueryParameters3D.create(center + up * 0.08,
		center - up * 0.18, PhysicsLayers.WORLD_BODY_LAYER)
	query.exclude = [ship.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := ship.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") is StaticBody3D \
		and (hit.get("normal", Vector3.ZERO) as Vector3).dot(up) > 0.9 \
		and absf(((hit.get("position", Vector3.INF) as Vector3) - center).dot(up)) <= 0.12

func _set_signed_action(positive: StringName, negative: StringName, strength: float) -> void:
	Input.action_release(positive)
	Input.action_release(negative)
	if absf(strength) > 0.005:
		Input.action_press(positive if strength > 0.0 else negative, minf(1.0, absf(strength)))

func _release_flight() -> void:
	for action in FLIGHT_ACTIONS:
		Input.action_release(action)

func _until(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		_observe_return()
		if bool(predicate.call()):
			return true
	return false

func _walk_to(target: Vector3, seconds: float, via: Array[Vector3] = [], arrival_radius: float = 1.5, completion: Callable = Callable()) -> bool:
	var waypoints: Array[Vector3] = via.duplicate()
	waypoints.append(target)
	var waypoint_index := 0
	var started_msec := Time.get_ticks_msec()
	var started_physics_frame := int(Engine.get_physics_frames())
	var waypoint_started_msec := started_msec
	var waypoint_started_physics_frame := started_physics_frame
	var planned_path_m := 0.0
	var previous := _game.player.global_position
	for waypoint in waypoints:
		planned_path_m += (waypoint - previous).slide(_game.player.up_direction).length()
		previous = waypoint
	var deadline := started_msec + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if completion.is_valid() and bool(completion.call()):
			_release_walk()
			return true
		var offset := (waypoints[waypoint_index] - _game.player.global_position).slide(_game.player.up_direction)
		if offset.length() <= arrival_radius:
			if waypoint_index == waypoints.size() - 1:
				_release_walk()
				if not completion.is_valid():
					return true
				await physics_frame
				continue
			waypoint_index += 1
			waypoint_started_msec = Time.get_ticks_msec()
			waypoint_started_physics_frame = int(Engine.get_physics_frames())
			continue
		var camera := _game.player.get_node("%CameraYaw") as Node3D
		var forward := -camera.global_basis.z.slide(_game.player.up_direction).normalized()
		var right := camera.global_basis.x.slide(_game.player.up_direction).normalized()
		var direction := offset.normalized()
		var axes := Vector2(direction.dot(right), -direction.dot(forward))
		_release_walk()
		Input.action_press(&"move_right" if axes.x > 0.0 else &"move_left", absf(axes.x))
		Input.action_press(&"move_back" if axes.y > 0.0 else &"move_forward", absf(axes.y))
		await physics_frame
	_release_walk()
	var collision := _game.player.get_last_slide_collision()
	var collider: Object = collision.get_collider() if collision != null else null
	var host := _game.ember_surface_loop_host
	var boarding := host.get("_boarding_area") as ShipBoardingArea
	var ended_msec := Time.get_ticks_msec()
	var ended_physics_frame := int(Engine.get_physics_frames())
	print("SHARED_SURFACE_WALK_FAILED: ", {
		"elapsed_wall_seconds": float(ended_msec - started_msec) / 1000.0,
		"elapsed_physics_frames": ended_physics_frame - started_physics_frame,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"engine_time_scale": Engine.time_scale,
		"planned_path_m": planned_path_m,
		"nominal_walk_speed_mps": _game.player.walk_speed,
		"waypoint_elapsed_wall_seconds": float(ended_msec - waypoint_started_msec) / 1000.0,
		"waypoint_elapsed_physics_frames": ended_physics_frame - waypoint_started_physics_frame,
		"velocity_world_mps": _game.player.velocity,
		"is_on_floor": _game.player.is_on_floor(),
		"floor_normal": _game.player.get_floor_normal(),
		"nearby_actual_boarding_area": boarding != null and _game.player.get_nearby_interactables().has(boarding),
		"surface_route_outbound_complete": bool(host.get("_surface_route_outbound_complete")),
		"surface_route_return_complete": bool(host.get("_surface_route_return_complete")),
		"return_departed_staging": bool(host.get("_return_departed_staging")),
		"position": _game.player.global_position, "waypoint_index": waypoint_index,
		"waypoint": waypoints[waypoint_index],
		"remaining_m": (waypoints[waypoint_index] - _game.player.global_position).slide(_game.player.up_direction).length(),
		"collider": (collider as Node).name if collider is Node else &"",
		"control_enabled": _game.player.is_control_enabled(), "seated": _game.player.is_seated(),
		"host_phase": _game.ember_surface_loop_host.get_phase(),
		"owner_current": _game.get("_planetary_journey").shared_ember_surface_is_current(),
	})
	return false

func _release_walk() -> void:
	for action in WALK_ACTIONS:
		Input.action_release(action)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error(description)

func _finish() -> void:
	_release_walk()
	_release_flight()
	if is_instance_valid(_game):
		_game.free()
	if _failures.is_empty():
		print("SHARED_EMBER_SURFACE_ACTIVITY_TEST_OK")
		if _success_mode:
			print("SHARED_EMBER_SURFACE_ROUNDTRIP_TEST_OK")
	await process_frame
	quit(0 if _failures.is_empty() else 1)
