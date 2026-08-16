extends SceneTree

## Focused integration regression for the provisional Arrow's place in the
## persistent five-craft yard. This deliberately begins before the guided
## Torrent activity so an Arrow sortie cannot accidentally consume mission
## state or replace the authored guide.

const MAIN_SCENE := preload("res://scenes/main.tscn")

## Extra simulated frames every bounded wait is granted on top of the frames its
## nominal duration implies. A frame count, never a wall-clock grace: widening a
## sleep would hide the clock divergence described on [method _wait_until], while
## a frame budget removes it.
const FRAME_BUDGET_GRACE := 30

## Nominal budget for a phase consequence that follows a condition this suite has
## already waited for. The phase itself is assigned in `_process`, so it needs
## idle frames rather than simulated seconds, and the grace supplies those.
const PHASE_SETTLE_SECONDS := 0.1

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "five-craft production scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var player := game.get_node("Player") as PlayerController
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	var arrow := game.get_node("ArrowReconShip") as ArrowReconShip
	var jovian := game.get_node("JovianLightFreighter") as JovianLightFreighter
	var zenith := game.get_node("ZenithInterceptor") as HeroShip
	var halyard := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var opponent := game.get_node("RangeOpponent") as CharacterBody3D
	var original_game_id := game.get_instance_id()
	var original_player_id := player.get_instance_id()
	var fleet := game.get_flyable_ships()
	_check(fleet.size() == 5, "main scene registers exactly five physical flyable craft")
	_check(
		fleet.has(torrent) and fleet.has(arrow) and fleet.has(jovian)
		and fleet.has(zenith) and fleet.has(halyard),
		"fleet registry contains exactly the Torrent, Arrow, Jovian, Zenith, and Halyard instances"
	)
	_check(game.get_node_or_null("ReserveInterceptor") == null, "retired duplicate handling article is absent")
	_check(game.get_guided_ship() == torrent, "Torrent remains the explicit guided-activity craft")
	_check(torrent.get_ship_id() == &"torrent_provisional", "Torrent exposes its stable production identity")
	_check(arrow.get_ship_id() == &"arrow_provisional", "Arrow exposes its distinct stable production identity")
	_check(jovian.get_ship_id() == &"jovian_provisional", "Jovian exposes its distinct stable production identity")
	_check(zenith.get_ship_id() == &"zenith_b7_observed", "Zenith exposes its B7-observed stable production identity")
	_check(halyard.get_ship_id() == &"halyard_new_design", "Halyard exposes its original-design stable production identity")
	_check(torrent.get_home_berth_id() == &"central_berth", "Torrent owns the central guided berth")
	_check(arrow.get_home_berth_id() == &"arrow_recon_berth", "Arrow owns the dedicated recon berth")
	_check(jovian.get_home_berth_id() == &"jovian_freight_berth", "Jovian owns the dedicated freight berth")
	_check(zenith.get_home_berth_id() == &"zenith_fleet_dock_berth", "Zenith owns the assigned Fleet Dock Comb berth")
	_check(halyard.get_home_berth_id() == &"halyard_fleet_dock_berth", "Halyard owns the assigned Fleet Dock 02 berth")
	_check(world.has_berth(torrent.get_home_berth_id()), "shared world registers the Torrent berth")
	_check(world.has_berth(arrow.get_home_berth_id()), "shared world registers the Arrow berth")
	_check(world.has_berth(jovian.get_home_berth_id()), "shared world registers the Jovian berth")
	_check(world.has_berth(zenith.get_home_berth_id()), "shared world registers the Zenith berth")
	_check(world.has_berth(halyard.get_home_berth_id()), "shared world registers the Halyard berth")
	var arrow_berth := world.get_berth_node(arrow.get_home_berth_id())
	_check(arrow_berth != null and arrow_berth.get_occupant() == arrow, "Arrow begins physically occupying its recon berth")
	_check(
		arrow_berth != null
		and arrow_berth.get_compatibility_tags() == PackedStringArray(["recon"]),
		"Arrow's branch-rail berth exposes the exact recon-only compatibility contract"
	)
	var torrent_berth := world.get_berth_node(torrent.get_home_berth_id())
	var jovian_berth := world.get_berth_node(jovian.get_home_berth_id())
	_check(
		jovian_berth != null
		and jovian_berth.get_reservation_owner() == jovian
		and jovian_berth.get_occupant() == jovian
		and jovian_berth.get_reserved_ship_id() == jovian.get_ship_id(),
		"Jovian begins with the authoritative occupied lease for its freight berth"
	)

	var targets := _get_live_range_targets(world)
	var target_health_before: Dictionary = {}
	for target in targets:
		target_health_before[target.get_instance_id()] = float(target.get_meta("health", -1.0))
	var target_total_before := world.get_target_count()
	var destroyed_before := world.get_destroyed_target_count()
	_check(targets.size() == target_total_before and target_total_before > 0, "guided range contacts are live before either sortie")

	game.canopy_motion_time = 0.02
	game.boarding_motion_time = 0.04
	game.disembarking_motion_time = 0.04
	game.start_shift()
	await process_frame
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "shift begins on foot with the guide still pending")

	# Walk into the Arrow's real interaction volume and board through the same E
	# action used by the player. No menu, node-name selection, or direct board call
	# participates in this handoff.
	player.teleport_to(Transform3D(Basis.IDENTITY, arrow.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	# `boarding_candidate` is recomputed in `_process`, from an interaction origin
	# the physics loop settles. Two physics frames plus one idle frame is a
	# hardcoded guess at how those two loops interleave, and the interleaving is
	# exactly what changes under load. Wait for the candidate itself.
	var arrow_selected := await _wait_until(
		func() -> bool: return game.boarding_candidate == arrow,
		PHASE_SETTLE_SECONDS
	)
	_check(arrow_selected, "Arrow boarding selection settles inside its frame budget")
	_check(game.boarding_candidate == arrow, "physical proximity selects the Arrow boarding area")
	await _press_live_action(&"interact", 1)
	# Boarding is an awaited chain of canopy motion and avatar interpolation, all
	# advanced by the engine loops; a `SceneTree` timer measures none of them.
	var arrow_boarded := await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.24)
	_check(arrow_boarded, "live Arrow boarding completes its transition inside its frame budget")
	_check(game.get_active_ship() == arrow, "live interaction makes Arrow the active craft")
	_check(player.is_seated() and arrow.is_piloted(), "the same visible player occupies Arrow's physical seat")
	_check(game.phase == GameFlow.Phase.START_ENGINES, "Arrow boarding reaches its engine-start phase")
	_check(arrow.get_camera().current and not player.get_camera().current, "boarding transfers the live camera to Arrow")
	game.set("_transition_busy", true)
	_dispatch_pilot_action(game, &"engine_start")
	await physics_frame
	_check(
		str(arrow.get_telemetry().get("engine_state", &"")) == "OFFLINE"
		and game.phase == GameFlow.Phase.START_ENGINES,
		"engine-start input is ignored during an atomic transition handoff"
	)
	game.set("_transition_busy", false)

	# Start via GameFlow's actual piloting action path. Arrow is intentionally a
	# free sortie, while the pending Torrent guide and its defender remain dormant.
	arrow.engine_start_time = 0.03
	_dispatch_pilot_action(game, &"engine_start")
	# `engine_start_time` is spent by the ship's own simulation, not by idle time.
	var arrow_engine_online := await _wait_until(
		func() -> bool: return str(arrow.get_telemetry().get("engine_state", &"")) == "ONLINE",
		0.12
	)
	_check(arrow_engine_online, "Arrow engine spin-up completes inside its frame budget")
	var arrow_free_flight := await _wait_for_phase(game, GameFlow.Phase.FREE_FLIGHT, PHASE_SETTLE_SECONDS)
	_check(arrow_free_flight, "the free-flight phase follows Arrow startup inside its frame budget")
	_check(str(arrow.get_telemetry().get("engine_state", &"")) == "ONLINE", "Arrow starts from the physical pilot seat")
	_check(game.phase == GameFlow.Phase.FREE_FLIGHT, "Arrow-first startup enters unrestricted free flight")
	_check(not game.is_guided_activity_complete(), "Arrow-first free flight does not complete the Torrent guide")
	_check(not bool(opponent.call("is_active")), "guided range defender stays dormant during the Arrow sortie")
	_check(
		arrow_berth.get_occupant() == arrow
		and arrow_berth.get_reservation_owner() == arrow,
		"engine startup alone preserves Arrow's occupied berth authority"
	)

	# Fire through the ship-owned command source. GameFlow should still produce a
	# tracer/result, but its explicit reservation status must protect every guided
	# range contact from damage or mission-counter mutation.
	arrow.weapon_cooldown = 0.02
	await _press_live_action(&"fire", 2)
	await process_frame
	var protected_result := game.get_last_player_shot_result()
	_check(protected_result.get("status") == &"guided_range_reserved", "Arrow fire is explicitly rejected from the pending guided range")
	_check(protected_result.get("source_entity") == arrow, "protected shot result retains Arrow source identity")
	_check(int(protected_result.get("source_id", 0)) == 1102, "protected Arrow shot retains its stable combat source ID")
	_check(game.destroyed_targets == 0, "Arrow fire cannot advance guided target progress")
	_check(world.get_destroyed_target_count() == destroyed_before, "Arrow fire cannot mutate world target-destruction state")
	_check(world.get_target_count() == target_total_before, "all guided range contacts remain registered")
	for target in targets:
		_check(
			not bool(target.get_meta("destroyed", false))
			and is_equal_approx(
				float(target.get_meta("health", -2.0)),
				float(target_health_before.get(target.get_instance_id(), -1.0))
			),
			"%s retains full pre-guide health after Arrow fire" % target.name
		)

	# Depart under real thrust input, proving the sandbox does not treat the
	# initially parked landed flag as an immediate completed return.
	var launch_position := arrow.global_position
	var launch_forward := -arrow.global_basis.z.normalized()
	Input.action_press(&"move_forward")
	for _step in 18:
		await physics_frame
	Input.action_release(&"move_forward")
	for _settle in 3:
		await physics_frame
	var departed_telemetry := arrow.get_telemetry()
	_check(not bool(departed_telemetry.get("landed", true)), "real forward thrust clears Arrow's landed state")
	_check(arrow.global_position.distance_to(launch_position) > 0.05, "Arrow physically departs its recon berth")
	_check(arrow.velocity.normalized().dot(launch_forward) > 0.9, "Arrow thrust travels along the craft's visible forward axis")
	_check(game.phase == GameFlow.Phase.FREE_FLIGHT, "departure remains in free flight instead of auto-shutdown")
	_check(
		arrow_berth.get_occupant() == null
		and arrow_berth.get_reservation_owner() == null,
		"authoritative landed-to-airborne departure releases Arrow's berth claim"
	)

	# ShipBerth deliberately matches any advertised tag. Prove the authored
	# recon-only contract closes the former small-craft false positive before a
	# wider Torrent can acquire landing authority near the port branch rails.
	_check(
		not arrow_berth.can_accept(torrent.get_ship_definition(), torrent),
		"clear Arrow berth rejects Torrent by exact compatibility rather than occupancy"
	)
	var torrent_cross_berth_token := arrow_berth.try_reserve(
		torrent,
		torrent.get_ship_definition()
	)
	_check(
		torrent_cross_berth_token.is_empty()
		and arrow_berth.get_reservation_owner() == null
		and arrow_berth.get_reserved_ship_id().is_empty(),
		"Torrent cannot reserve the rail-constrained Arrow berth"
	)
	_check(
		not torrent.request_berth_landing(arrow_berth)
		and not torrent.is_landing_active()
		and StringName(torrent.get_landing_contract_report().get("last_abort_reason", &"")) == &"reservation_lost",
		"Torrent cannot request Arrow landing assist without a compatible berth lease"
	)
	_check(
		torrent_berth != null
		and torrent_berth.get_occupant() == torrent
		and torrent_berth.get_reservation_owner() == torrent,
		"rejected cross-berth request preserves Torrent's central small-craft lease"
	)

	# Return over the full rotated berth transform and invoke landing through the
	# piloting L action. The common assist owns alignment, clamps, and shutdown.
	var arrow_berth_transform := world.get_berth_transform(arrow.get_home_berth_id())
	arrow.global_transform = arrow_berth_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	arrow.velocity = Vector3.ZERO
	await physics_frame
	_dispatch_pilot_action(game, &"landing_assist")
	await physics_frame
	_check(
		arrow.is_landing_active()
		and arrow_berth.get_reservation_owner() == arrow
		and arrow_berth.get_reserved_ship_id() == arrow.get_ship_id(),
		"recon Arrow acquires the real berth lease and starts strict landing assist"
	)
	# Landing assist integrates the approach in `_physics_process`. Under load the
	# engine drops physics steps, so 2.2 wall-clock seconds can contain far fewer
	# than 2.2 seconds of simulated descent and the assist is still mid-travel.
	var arrow_landed := await _wait_until(
		func() -> bool: return bool(arrow.get_telemetry().get("landed", false)),
		2.2
	)
	_check(arrow_landed, "Arrow landing assist completes inside its simulated-frame budget")
	var arrow_shut_down := await _wait_for_phase(game, GameFlow.Phase.SHUT_DOWN, PHASE_SETTLE_SECONDS)
	_check(arrow_shut_down, "safe shutdown follows the completed Arrow landing inside its frame budget")
	var landed_telemetry := arrow.get_telemetry()
	_check(bool(landed_telemetry.get("landed", false)), "Arrow completes landing assist at its own berth")
	_check(arrow.global_transform.is_equal_approx(arrow_berth_transform), "Arrow landing restores the recon berth's complete transform")
	_check(game.phase == GameFlow.Phase.SHUT_DOWN, "completed Arrow landing reaches safe shutdown")
	_check(
		arrow_berth.get_occupant() == arrow
		and arrow_berth.get_reservation_owner() == arrow
		and arrow_berth.get_reserved_ship_id() == arrow.get_ship_id(),
		"completed Arrow landing physically occupies its exact recon lease"
	)

	_dispatch_pilot_action(game, &"engine_stop")
	await physics_frame
	_check(str(arrow.get_telemetry().get("engine_state", &"")) == "OFFLINE", "Arrow shuts down before disembarking")
	_dispatch_pilot_action(game, &"engine_start")
	await physics_frame
	_check(
		str(arrow.get_telemetry().get("engine_state", &"")) == "OFFLINE"
		and game.phase == GameFlow.Phase.SHUT_DOWN,
		"engine-start input is ignored after landing reaches SHUT_DOWN"
	)
	_dispatch_pilot_action(game, &"interact")
	# Disembarking is the same awaited canopy/avatar chain as boarding.
	var arrow_exited := await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 0.24)
	_check(arrow_exited, "Arrow disembark completes its transition inside its frame budget")
	_check(not player.is_seated() and player.is_control_enabled(), "Arrow exit returns the same character to on-foot control")
	_check(not arrow.is_piloted() and arrow.is_boardable(), "Arrow remains a reusable physical craft after exit")
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "pre-guide Arrow exit returns to the pending approach phase")
	_check(not game.is_guided_activity_complete() and game.destroyed_targets == 0, "the guided activity remains completely untouched after the Arrow sortie")

	# Physically clear the just-exited Arrow's reboard suppression, then fly and
	# destroy it before guide completion. Recovery must recall this same pilot in
	# this same world and leave Torrent available for the pending activity.
	player.teleport_to(Transform3D(Basis.IDENTITY, torrent.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	for _clear_refresh in 3:
		await physics_frame
		await process_frame
	player.teleport_to(Transform3D(Basis.IDENTITY, arrow.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	var arrow_reselected := await _wait_until(
		func() -> bool: return game.boarding_candidate == arrow,
		PHASE_SETTLE_SECONDS
	)
	_check(arrow_reselected, "cleared Arrow reboard block resolves inside its frame budget")
	_check(game.boarding_candidate == arrow, "Arrow can be selected again after physically clearing its reboard block")
	await _press_live_action(&"interact", 1)
	var arrow_reboarded := await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.24)
	_check(arrow_reboarded, "the second Arrow boarding completes its transition inside its frame budget")
	arrow.engine_start_time = 0.03
	_dispatch_pilot_action(game, &"engine_start")
	var second_sortie_active := await _wait_for_phase(game, GameFlow.Phase.FREE_FLIGHT, 0.12)
	_check(second_sortie_active, "the second Arrow sortie reaches free flight inside its frame budget")
	_check(game.phase == GameFlow.Phase.FREE_FLIGHT and game.get_active_ship() == arrow, "second pre-guide Arrow sortie becomes active")
	arrow.apply_damage(arrow.maximum_hull + 1.0, arrow.global_position, Vector3.UP)
	# Destruction recovery re-poses the avatar through `force_recovery_to_on_foot`.
	# If the wait ends before that lands, the teleport to Torrent below is undone by
	# a late recall and the Torrent boarding selection fails for a reason that has
	# nothing to do with the behaviour under test. Wait for the recovery itself.
	var arrow_recovered := await _wait_until(
		func() -> bool: return (
			arrow.is_destroyed()
			and game.phase == GameFlow.Phase.APPROACH_SHIP
			and not player.is_seated()
		),
		0.30
	)
	_check(arrow_recovered, "Arrow destruction recovery completes inside its frame budget")
	_check(arrow.is_destroyed(), "lethal damage destroys the active Arrow through its common lifecycle")
	_check(game.get_instance_id() == original_game_id, "Arrow destruction recovery preserves the same world/session instance")
	_check(player.get_instance_id() == original_player_id, "Arrow destruction recovery preserves the same player instance")
	_check(not player.is_seated() and player.is_control_enabled(), "pre-guide Arrow destruction recalls the pilot to on-foot control")
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "pre-guide Arrow loss returns to the pending Torrent approach")
	_check(not game.is_guided_activity_complete() and game.get_guided_ship() == torrent, "Arrow loss cannot complete or replace the Torrent guide")
	_check(torrent.is_boardable(), "Torrent remains physically available after pre-guide Arrow destruction")
	_check(not bool(opponent.call("is_active")), "range defender remains dormant after Arrow recovery")

	# Physically cross the yard to Torrent. Its startup must still enter LAUNCH,
	# demonstrating that an earlier Arrow sortie neither substitutes for nor
	# corrupts the authored vertical-slice progression.
	player.teleport_to(Transform3D(Basis.IDENTITY, torrent.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	# This is the assertion observed failing while two matrices overlapped. The
	# candidate is recomputed in `_process` from an origin the physics loop settles,
	# and a hardcoded two-physics-plus-one-idle wait fixes neither loop's count
	# under load. Wait for the selection instead of assuming the interleaving.
	var torrent_selected := await _wait_until(
		func() -> bool: return game.boarding_candidate == torrent,
		PHASE_SETTLE_SECONDS
	)
	_check(torrent_selected, "Torrent boarding selection settles inside its frame budget")
	_check(game.boarding_candidate == torrent, "walking to the central berth selects Torrent after the Arrow sortie")
	await _press_live_action(&"interact", 1)
	var torrent_boarded := await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.24)
	_check(torrent_boarded, "Torrent boarding completes its transition inside its frame budget")
	_check(game.get_active_ship() == torrent and player.is_seated(), "physical interaction transfers the same pilot into Torrent")
	torrent.engine_start_time = 0.03
	_dispatch_pilot_action(game, &"engine_start")
	var torrent_launched := await _wait_for_phase(game, GameFlow.Phase.LAUNCH, 0.12)
	_check(torrent_launched, "Torrent startup reaches the guided launch phase inside its frame budget")
	_check(game.phase == GameFlow.Phase.LAUNCH, "Torrent startup still enters the guided launch phase")
	_check(not game.is_guided_activity_complete(), "entering Torrent launch does not prematurely complete the guide")
	_check(game.destroyed_targets == 0 and world.get_destroyed_target_count() == destroyed_before, "all reserved target progress is intact for Torrent")

	await _clean_up(game)
	_finish()


func _get_live_range_targets(world: Node) -> Array[StaticBody3D]:
	var targets: Array[StaticBody3D] = []
	for candidate in world.find_children("*", "StaticBody3D", true, false):
		if candidate.get_meta("is_shipyard_target", false):
			targets.append(candidate as StaticBody3D)
	return targets


## Physics frames a nominal duration of simulated time is worth at the project's
## configured tick rate, plus a fixed frame grace.
func _frame_budget(seconds: float) -> int:
	var required := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + FRAME_BUDGET_GRACE


## Waits for `predicate` on the simulation clock instead of the wall clock.
##
## Every condition this suite waits on — canopy motion, the boarding interpolation,
## engine spin-up, landing assist, destruction recovery — is advanced by the engine
## loops, while a `SceneTree` timer counts Godot's smoothed idle delta. The two are
## different clocks and they diverge in both directions under parallel load: the
## engine drops physics steps rather than letting the simulation spiral, and the
## smoothed delta can run ahead of the monotonic clock while catching up from a
## stall. A timer sized to "long enough on an idle box" therefore fires mid-motion
## on a busy one, which is a false failure rather than a defect.
##
## `nominal_seconds` is kept only as the duration the wait is *expected* to take
## and is converted into a budget of simulated frames, so the wait stays bounded —
## a genuinely stuck condition still fails — but a merely loaded machine is given
## the same amount of simulation as an idle one. Both loops are advanced each
## iteration because some conditions here settle in `_physics_process` (ship
## motion) and others in `_process` (`GameFlow.phase`, `boarding_candidate`).
func _wait_until(predicate: Callable, nominal_seconds: float) -> bool:
	var frame_budget := _frame_budget(nominal_seconds)
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


## Waits for `GameFlow` to reach `expected_phase`. Phase is assigned in `_process`
## after the physics-driven condition that triggers it, so it needs idle frames of
## its own; a hardcoded frame count is not a bound on that under load.
func _wait_for_phase(game: GameFlow, expected_phase: int, nominal_seconds: float) -> bool:
	return await _wait_until(
		func() -> bool: return game.phase == expected_phase,
		nominal_seconds
	)


func _press_live_action(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, physics_ticks):
		await physics_frame
	Input.action_release(action)
	await physics_frame


func _dispatch_pilot_action(game: GameFlow, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func _clean_up(game: Node) -> void:
	for action in [&"interact", &"move_forward", &"fire", &"engine_start", &"engine_stop", &"landing_assist"]:
		Input.action_release(action)
	await _release_combat_audio_before_main_teardown(game)
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _release_combat_audio_before_main_teardown(game: Node) -> void:
	var combat_audio := game.get_node_or_null("CombatAudioPresentation") as CombatAudioPresentation
	if combat_audio == null:
		return
	for candidate in combat_audio.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := candidate as AudioStreamPlayer3D
		player.stop()
		player.stream_paused = false
		player.stream = null
	# Give both the scene loop and audio backend a bounded boundary in which to
	# release the final explosion playback before the presentation bank is freed.
	await process_frame
	var mixer_release_seconds := maxf(
		0.05,
		AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	)
	await create_timer(mixer_release_seconds).timeout
	var parent := combat_audio.get_parent()
	if parent != null:
		parent.remove_child(combat_audio)
	combat_audio.free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("ARROW_SANDBOX_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("ARROW_SANDBOX_INTEGRATION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
