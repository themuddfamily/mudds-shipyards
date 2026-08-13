extends SceneTree

## Adversarial production-scene regression for the guided Torrent lifecycle.
## Defender victory owns only the return authorization; the guide is complete
## only after landing, shutdown, and the generation-guarded physical exit.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_preflight_exit_cannot_complete_the_guide()
	await _test_victory_is_not_completion_and_return_loss_retries()
	await _test_landing_abort_releases_return_reservation()
	await _test_return_exit_destruction_invalidates_completion()
	await _test_completion_occurs_once_after_physical_disembark()
	await _test_free_sorties_cannot_claim_guided_return()
	_finish()


func _test_preflight_exit_cannot_complete_the_guide() -> void:
	var game := await _new_game()
	var player := game.get_node("Player") as PlayerController
	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	var hud := game.get_node("HUD") as GameHUD
	game.call("_board_ship", torrent)
	_check(
		await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.8),
		"preflight fixture reaches the landed, offline Torrent seat"
	)
	game.call("_begin_return_to_yard")
	_check(
		game.phase == GameFlow.Phase.START_ENGINES
		and not bool(game.get("_guided_return_ready_for_completion")),
		"a non-combat return request cannot authorize guided completion"
	)
	_dispatch_pilot_action(game, &"interact")
	_check(
		await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 1.0),
		"preflight physical exit returns to the pending guide"
	)
	_check(
		not game.is_guided_activity_complete()
		and not bool(game.get("_guided_return_ready_for_completion"))
		and player.is_control_enabled()
		and not player.is_seated()
		and not torrent.is_piloted(),
		"ordinary Torrent disembarkation cannot substitute for the guided sortie"
	)
	_check(
		_label_text(hud.get("_objective_kicker")) == "GUIDED TEST PENDING"
		and _label_text(hud.get("_toast_title")) == "SAFE EXIT COMPLETE",
		"preflight exit retains the pending objective and safe-exit feedback"
	)
	await _free_fixture(game)


func _test_victory_is_not_completion_and_return_loss_retries() -> void:
	var fixture := await _new_guided_combat_fixture()
	var game := fixture.game as GameFlow
	var player := fixture.player as PlayerController
	var torrent := fixture.torrent as HeroShip
	var opponent := fixture.opponent as RangeOpponent
	var hud := fixture.hud as GameHUD
	if game == null or torrent == null or opponent == null:
		await _free_fixture(game)
		return

	var victory_toast_serial_before := int(hud.get("_toast_serial"))
	opponent.apply_damage(opponent.maximum_health + 1.0, opponent.global_position)
	await process_frame
	_check(game.phase == GameFlow.Phase.RETURN_TO_YARD, "defender victory begins the guided return leg")
	_check(not game.is_guided_activity_complete(), "defender victory does not complete the guided sortie")
	_check(
		bool(game.get("_guided_return_ready_for_completion")),
		"defender victory records one pending return authorization"
	)
	_check(
		int(hud.get("_toast_serial")) == victory_toast_serial_before + 1,
		"the first victory publishes exactly one return toast"
	)

	# Duplicate destruction delivery and a duplicate coordinator callback must be
	# idempotent. Neither may regress the phase nor replace the live return toast.
	var victory_toast_serial := int(hud.get("_toast_serial"))
	var victory_toast_title := _label_text(hud.get("_toast_title"))
	opponent.destroyed.emit(opponent.global_position)
	game.call("_begin_return_to_yard")
	await process_frame
	_check(
		game.phase == GameFlow.Phase.RETURN_TO_YARD
		and not game.is_guided_activity_complete()
		and bool(game.get("_guided_return_ready_for_completion")),
		"duplicate victory delivery preserves the single pending return state"
	)
	_check(
		int(hud.get("_toast_serial")) == victory_toast_serial
		and _label_text(hud.get("_toast_title")) == victory_toast_title,
		"duplicate victory delivery cannot race or replace the return toast"
	)

	var transition_generation_before_loss := int(game.get("_transition_generation"))
	torrent.apply_damage(torrent.maximum_hull + 1.0, torrent.global_position, Vector3.UP)
	await process_frame
	await physics_frame
	_check(torrent.is_destroyed(), "lethal return-leg damage destroys the active Torrent")
	_check(
		game.phase == GameFlow.Phase.APPROACH_SHIP
		and not game.is_guided_activity_complete(),
		"return-leg destruction recalls the pilot to a pending guide, never COMPLETE"
	)
	_check(
		not bool(game.get("_guided_return_ready_for_completion"))
		and not bool(game.get("_opponent_spawned"))
		and not opponent.is_active(),
		"return recovery clears stale victory and defender latches for a coherent retry"
	)
	_check(
		int(game.get("_transition_generation")) > transition_generation_before_loss
		and not bool(game.get("_transition_busy"))
		and not bool(game.get("_recovering")),
		"return recovery invalidates stale transitions and releases the atomic guard"
	)
	_check(
		player.is_control_enabled() and not player.is_seated() and not torrent.is_piloted(),
		"return recovery restores exactly one on-foot pilot authority"
	)
	var recovery_toast_serial := int(hud.get("_toast_serial"))
	_check(
		_label_text(hud.get("_toast_title")) == "HULL INTEGRITY LOST",
		"return destruction publishes recovery feedback rather than a completion toast"
	)
	opponent.destroyed.emit(opponent.global_position)
	await process_frame
	_check(
		game.phase == GameFlow.Phase.APPROACH_SHIP
		and int(hud.get("_toast_serial")) == recovery_toast_serial,
		"a late defender signal cannot race the pending recovery phase or toast"
	)

	_check(
		await _wait_until(func() -> bool: return not torrent.is_destroyed(), 5.4),
		"the destroyed guided craft regenerates within the production retry bound"
	)
	game.call("_board_ship", torrent)
	_check(
		await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.8),
		"the regenerated Torrent can be physically boarded for the retry"
	)
	torrent.engine_start_time = 0.01
	_dispatch_pilot_action(game, &"engine_start")
	_check(
		await _wait_for_engine_state(torrent, "ONLINE", 0.35)
		and await _wait_for_phase(game, GameFlow.Phase.LAUNCH, 0.35),
		"the retry restores the guided launch path rather than sandbox completion"
	)
	await _depart_active_ship(game, torrent, "the guided retry physically releases its regenerated berth")
	game.call("_begin_interceptor_engagement")
	await process_frame
	_check(
		game.phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
		and opponent.is_active()
		and bool(game.get("_opponent_spawned"))
		and not bool(game.get("_guided_return_ready_for_completion"))
		and not game.is_guided_activity_complete(),
		"the retry can launch one fresh defender while the guide remains incomplete"
	)

	await _free_fixture(game)


func _test_landing_abort_releases_return_reservation() -> void:
	var fixture := await _new_guided_combat_fixture()
	var game := fixture.game as GameFlow
	var torrent := fixture.torrent as HeroShip
	var opponent := fixture.opponent as RangeOpponent
	var world := fixture.world as ShipyardWorld
	var hud := fixture.hud as GameHUD
	opponent.apply_damage(opponent.maximum_health + 1.0, opponent.global_position)
	await process_frame
	var berth := world.get_berth_node(torrent.get_home_berth_id()) as ShipBerth
	var berth_transform := world.get_berth_transform(torrent.get_home_berth_id())
	torrent.global_transform = berth_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	torrent.velocity = Vector3.ZERO
	await physics_frame
	_dispatch_pilot_action(game, &"landing_assist")
	_check(
		bool(game.get("_landing_request_active"))
		and game.get("_active_landing_berth_id") == torrent.get_home_berth_id()
		and torrent.is_landing_active(),
		"accepted guided landing records one strict active-berth contract"
	)
	game.call("_update_pilot_flow")
	_check(
		_label_text(hud.get("_interaction_label")) == "LANDING ASSIST  //  FINAL APPROACH"
		and not _label_text(hud.get("_interaction_label")).contains("ENGAGE"),
		"active landing replaces the engage prompt with its live assist phase"
	)
	_check(
		game.call("_landing_assist_phase_status", &"brake") == "LANDING ASSIST  //  BRAKING"
		and game.call("_landing_assist_phase_status", &"move_to_staging") == "LANDING ASSIST  //  STAGING"
		and game.call("_landing_assist_phase_status", &"align") == "LANDING ASSIST  //  ALIGNING"
		and game.call("_landing_assist_phase_status", &"final_approach") == "LANDING ASSIST  //  FINAL APPROACH",
		"landing HUD maps every staged assist phase to explicit progress copy"
	)
	_check(
		berth.get_reservation_owner() == torrent and berth.get_occupant() == null,
		"active landing owns a reservation without prematurely occupying the berth"
	)
	var assist_timeout := float(
		torrent.get_landing_contract_report().get("timeout_seconds", 24.0)
	)
	torrent.call("_update_landing", assist_timeout + 0.1)
	await process_frame
	_check(
		game.phase == GameFlow.Phase.RETURN_TO_YARD
		and not game.is_guided_activity_complete()
		and bool(game.get("_guided_return_ready_for_completion")),
		"landing abort preserves the authorized but incomplete return phase"
	)
	_check(
		not bool(game.get("_landing_request_active"))
		and (game.get("_active_landing_berth_id") as StringName).is_empty()
		and not torrent.is_landing_active(),
		"landing abort clears both ship and coordinator assist authority"
	)
	_check(
		berth.get_reservation_owner() == null and berth.get_occupant() == null,
		"landing abort releases the pending physical berth reservation"
	)
	_check(
		_label_text(hud.get("_toast_title")) == "LANDING ASSIST ABORTED"
		and _label_text(hud.get("_objective_label")).contains("retry"),
		"landing abort presents a coherent guided retry instead of completion"
	)
	var abort_toast_serial := int(hud.get("_toast_serial"))
	torrent.landing_aborted.emit(&"assist_timeout")
	await process_frame
	_check(
		game.phase == GameFlow.Phase.RETURN_TO_YARD
		and int(hud.get("_toast_serial")) == abort_toast_serial,
		"duplicate landing-abort delivery cannot race the phase or retry toast"
	)
	torrent.global_basis = (
		berth_transform.basis * Basis(Vector3.RIGHT, deg_to_rad(80.0))
	).orthonormalized()
	torrent.velocity = Vector3.ZERO
	game.call("_update_pilot_flow")
	_check(
		_label_text(hud.get("_interaction_label"))
		== "LEVEL / ROLL TO WITHIN 75° FOR LANDING ASSIST",
		"attitude-rejected capture shows the exact level/roll recovery cue"
	)
	await _free_fixture(game)


func _test_return_exit_destruction_invalidates_completion() -> void:
	var fixture := await _new_guided_combat_fixture()
	var game := fixture.game as GameFlow
	var player := fixture.player as PlayerController
	var torrent := fixture.torrent as HeroShip
	var opponent := fixture.opponent as RangeOpponent
	var world := fixture.world as ShipyardWorld
	var hud := fixture.hud as GameHUD
	opponent.apply_damage(opponent.maximum_health + 1.0, opponent.global_position)
	await process_frame
	var berth_transform := world.get_berth_transform(torrent.get_home_berth_id())
	torrent.global_transform = berth_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	torrent.velocity = Vector3.ZERO
	await physics_frame
	_dispatch_pilot_action(game, &"landing_assist")
	_check(
		await _wait_for_phase(game, GameFlow.Phase.SHUT_DOWN, 5.0),
		"exit-destruction fixture completes the authorized return landing"
	)
	_dispatch_pilot_action(game, &"engine_stop")
	_check(await _wait_for_engine_state(torrent, "OFFLINE", 0.35), "exit-destruction fixture shuts down safely")
	_dispatch_pilot_action(game, &"interact")
	_check(
		await _wait_until(func() -> bool:
			return game.phase == GameFlow.Phase.DISEMBARKING and not player.is_seated(),
			0.5
		),
		"exit-destruction fixture reaches the live player-motion handoff"
	)
	var doomed_generation := int(game.get("_transition_generation"))
	torrent.apply_damage(torrent.maximum_hull + 1.0, torrent.global_position, Vector3.UP)
	await process_frame
	_check(
		game.phase == GameFlow.Phase.APPROACH_SHIP
		and not game.is_guided_activity_complete()
		and not bool(game.get("_guided_return_ready_for_completion")),
		"destruction during final exit cancels completion and restores the pending guide"
	)
	_check(
		int(game.get("_transition_generation")) > doomed_generation
		and not bool(game.get("_transition_busy"))
		and player.is_control_enabled()
		and not player.is_seated(),
		"exit destruction invalidates the transition generation and restores on-foot authority"
	)
	var recovery_toast_serial := int(hud.get("_toast_serial"))
	await create_timer(0.55).timeout
	await process_frame
	_check(
		game.phase == GameFlow.Phase.APPROACH_SHIP
		and not game.is_guided_activity_complete()
		and int(hud.get("_toast_serial")) == recovery_toast_serial,
		"stale canopy/disembark continuations cannot complete the guide or replace recovery feedback"
	)
	await _free_fixture(game)


func _test_completion_occurs_once_after_physical_disembark() -> void:
	var fixture := await _new_guided_combat_fixture()
	var game := fixture.game as GameFlow
	var player := fixture.player as PlayerController
	var torrent := fixture.torrent as HeroShip
	var opponent := fixture.opponent as RangeOpponent
	var world := fixture.world as ShipyardWorld
	var hud := fixture.hud as GameHUD
	if game == null or torrent == null or opponent == null or world == null:
		await _free_fixture(game)
		return

	var disembark_signal_state := {"count": 0, "complete": false}
	player.disembarking_completed.connect(func() -> void:
		disembark_signal_state.count = int(disembark_signal_state.count) + 1
		disembark_signal_state.complete = game.is_guided_activity_complete()
	)
	opponent.apply_damage(opponent.maximum_health + 1.0, opponent.global_position)
	await process_frame
	_check(
		game.phase == GameFlow.Phase.RETURN_TO_YARD
		and bool(game.get("_guided_return_ready_for_completion"))
		and not game.is_guided_activity_complete(),
		"completion fixture enters an incomplete authorized return"
	)

	# Stage only the approach position; landing itself, berth occupation, phase
	# handoff, engine stop, and physical exit all use the production paths.
	var berth_transform := world.get_berth_transform(torrent.get_home_berth_id())
	torrent.global_transform = berth_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	torrent.velocity = Vector3.ZERO
	await physics_frame
	_dispatch_pilot_action(game, &"landing_assist")
	_check(
		await _wait_for_phase(game, GameFlow.Phase.SHUT_DOWN, 5.0),
		"authorized return completes a production landing into SHUT_DOWN"
	)
	_check(
		bool(torrent.get_telemetry().get("landed", false))
		and bool(game.get("_return_registered"))
		and not game.is_guided_activity_complete(),
		"successful landing alone leaves the guide incomplete"
	)

	_dispatch_pilot_action(game, &"engine_stop")
	_check(await _wait_for_engine_state(torrent, "OFFLINE", 0.35), "the landed Torrent completes engine shutdown")
	_check(
		game.phase == GameFlow.Phase.SHUT_DOWN
		and bool(game.get("_guided_return_ready_for_completion"))
		and not game.is_guided_activity_complete(),
		"landing plus engine shutdown remains incomplete before physical exit"
	)

	var toast_serial_before_exit := int(hud.get("_toast_serial"))
	var transition_generation_before_exit := int(game.get("_transition_generation"))
	_dispatch_pilot_action(game, &"interact")
	_check(
		game.phase == GameFlow.Phase.DISEMBARKING
		and bool(game.get("_transition_busy"))
		and not game.is_guided_activity_complete(),
		"starting the physical exit still does not complete the guide"
	)
	var disembark_generation := int(game.get("_transition_generation"))
	_check(
		disembark_generation == transition_generation_before_exit + 1,
		"physical exit owns exactly one new transition generation"
	)

	# Repeated E/private exit calls and a late duplicate defender signal arrive
	# while the canopy/player coroutine is live. All must be inert.
	_dispatch_pilot_action(game, &"interact")
	game.call("_try_exit_ship")
	opponent.destroyed.emit(opponent.global_position)
	await process_frame
	_check(
		game.phase == GameFlow.Phase.DISEMBARKING
		and int(game.get("_transition_generation")) == disembark_generation
		and not game.is_guided_activity_complete(),
		"duplicate exit and victory events cannot race the live disembark transition"
	)
	_check(
		int(hud.get("_toast_serial")) == toast_serial_before_exit,
		"duplicate events publish no toast before physical disembark completes"
	)

	_check(
		await _wait_for_phase(game, GameFlow.Phase.COMPLETE, 1.2),
		"final canopy and player transition reaches COMPLETE"
	)
	_check(
		int(disembark_signal_state.count) == 1
		and not bool(disembark_signal_state.complete)
		and game.is_guided_activity_complete(),
		"the physical disembark signal occurs once before the completion latch is committed"
	)
	_check(
		not bool(game.get("_guided_return_ready_for_completion"))
		and not bool(game.get("_transition_busy"))
		and int(game.get("_transition_generation")) == disembark_generation,
		"final completion consumes the return authorization without spawning a second transition"
	)
	_check(
		player.is_control_enabled()
		and not player.is_seated()
		and not torrent.is_piloted()
		and int(hud.get("_toast_serial")) == toast_serial_before_exit + 1
		and _label_text(hud.get("_toast_title")) == "WELCOME BACK TO MUDDS SHIPYARDS",
		"exact completion restores on-foot authority and publishes one completion toast"
	)
	_check(
		_label_text(hud.get("_objective_kicker")) == "FLIGHT TEST COMPLETE",
		"the final objective, not combat victory, identifies the completed flight test"
	)

	var final_toast_serial := int(hud.get("_toast_serial"))
	game.call("_begin_return_to_yard")
	game.call("_try_exit_ship")
	player.disembarking_completed.emit()
	opponent.destroyed.emit(opponent.global_position)
	await process_frame
	_check(
		game.phase == GameFlow.Phase.COMPLETE
		and game.is_guided_activity_complete()
		and int(game.get("_transition_generation")) == disembark_generation,
		"late duplicate lifecycle signals cannot regress or restart completed state"
	)
	_check(
		int(hud.get("_toast_serial")) == final_toast_serial,
		"late duplicate lifecycle signals cannot duplicate the completion toast"
	)

	await _free_fixture(game)


func _test_free_sorties_cannot_claim_guided_return() -> void:
	for craft_name in [&"ArrowReconShip", &"JovianLightFreighter"]:
		var game := await _new_game()
		var candidate := game.get_node(NodePath(str(craft_name))) as HeroShip
		var hud := game.get_node("HUD") as GameHUD
		game.call("_board_ship", candidate)
		_check(
			await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.8),
			"%s reaches its production free-sortie pilot seat" % candidate.get_display_name()
		)
		var phase_before := game.phase
		var toast_serial_before := int(hud.get("_toast_serial"))
		game.call("_begin_return_to_yard")
		await process_frame
		_check(
			game.phase == phase_before
			and not game.is_guided_activity_complete()
			and not bool(game.get("_guided_return_ready_for_completion")),
			"%s cannot consume or authorize the pending Torrent guide" % candidate.get_display_name()
		)
		_check(
			bool(game.get("_sandbox_sortie"))
			and int(hud.get("_toast_serial")) == toast_serial_before,
			"%s retains free-sortie semantics without a false return toast" % candidate.get_display_name()
		)
		await _free_fixture(game)


func _new_guided_combat_fixture() -> Dictionary:
	var game := await _new_game()
	var player := game.get_node("Player") as PlayerController
	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	var opponent := game.get_node("RangeOpponent") as RangeOpponent
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var hud := game.get_node("HUD") as GameHUD
	game.call("_board_ship", torrent)
	_check(
		await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.8),
		"guided fixture completes production boarding and seating"
	)
	torrent.engine_start_time = 0.01
	_dispatch_pilot_action(game, &"engine_start")
	_check(
		await _wait_for_engine_state(torrent, "ONLINE", 0.35)
		and await _wait_for_phase(game, GameFlow.Phase.LAUNCH, 0.35),
		"guided fixture reaches the production launch phase"
	)
	await _depart_active_ship(game, torrent, "guided fixture physically clears the occupied berth")
	game.destroyed_targets = game.total_targets
	game.call("_begin_interceptor_engagement")
	await process_frame
	_check(
		game.phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
		and opponent.is_active()
		and not game.is_guided_activity_complete(),
		"guided fixture launches one live production defender before completion"
	)
	return {
		"game": game,
		"player": player,
		"torrent": torrent,
		"opponent": opponent,
		"world": world,
		"hud": hud,
	}


func _depart_active_ship(game: GameFlow, candidate: HeroShip, description: String) -> bool:
	Input.action_press(&"move_forward")
	var departed := await _wait_until(func() -> bool:
		return (
			not bool(candidate.get_telemetry().get("landed", true))
			and bool(game.get("_sortie_departed_berth"))
		),
		0.9
	)
	Input.action_release(&"move_forward")
	await physics_frame
	_check(departed, description)
	return departed


func _new_game() -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production main scene instantiates")
	if game == null:
		return null
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.02
	game.boarding_motion_time = 0.025
	game.disembarking_motion_time = 0.16
	game.start_shift()
	await process_frame
	return game


func _dispatch_pilot_action(game: GameFlow, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func _wait_for_phase(game: GameFlow, expected: GameFlow.Phase, timeout: float) -> bool:
	return await _wait_until(func() -> bool: return game.phase == expected, timeout)


func _wait_for_engine_state(ship: HeroShip, expected: String, timeout: float) -> bool:
	return await _wait_until(func() -> bool:
		return str(ship.get_telemetry().get("engine_state", "")).to_upper() == expected,
		timeout
	)


func _wait_until(predicate: Callable, timeout: float) -> bool:
	var deadline_msec := Time.get_ticks_msec() + int(ceil(timeout * 1000.0))
	while Time.get_ticks_msec() < deadline_msec:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _label_text(value: Variant) -> String:
	var label := value as Label
	return label.text if label != null else ""


func _free_fixture(game: GameFlow) -> void:
	for action in [&"interact", &"move_forward", &"engine_start", &"engine_stop", &"landing_assist"]:
		Input.action_release(action)
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TORRENT_SORTIE_COMPLETION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("TORRENT_SORTIE_COMPLETION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
