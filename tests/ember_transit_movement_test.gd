extends SceneTree

## The production movement owner for both 8,000 km Ember legs, proven on the
## real production `Main`: a real board and launch, the expedition opened
## through `GameFlow.begin_ember_surface_journey()`, and from there nothing but
## production physics. The cruise binding carries the outbound leg under the
## controller's authority — attitude, the long-leg cruise, every 10 km
## common-world rebase, the standoff brake, the armed approach into the
## authored caldera corridor — the surface Host lands it, the abandon opens the
## way home and hands the craft back to its pilot (the return leg itself is
## armed on the same machinery but not flown here — see EMBER_LOOP_SOAK.md).
##
## Continuity is measured every tick exactly as the soak measures it: the
## largest single-tick step of craft and pilot with the committed rebase
## translation removed, seat/piloted/reservation agreement, and the count of
## committed rebases against the distance flown. A pilot touching the controls
## mid-leg takes the craft back at its current position and gets the leg back
## when the controls are released; a whole-`Main` save and re-entry mid-leg
## is the safe abort (expedition closed, pilot in control where they are), and
## a fresh request resumes the leg from there.
##
## Environment: KETH_EMBER_TRANSIT_TRACE=1 prints per-second transit progress.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const ISOLATED_STORE_PATH := "memory://ember-transit-movement.json"
const ORIGIN_SHIFT_THRESHOLD_M := 10_000.0
const CRUISE_SPEED_LIMIT_MPS := PlanetaryCruisePolicy.TARGET_CRUISE_SPEED_METERS_PER_SECOND
const TICK_STEP_LIMIT_M := CRUISE_SPEED_LIMIT_MPS / 60.0 + 1.0
const OUTBOUND_TICK_BUDGET := 14_000
const LANDING_TICK_BUDGET := 3_000
const DISEMBARK_TICK_BUDGET := 900
const REBOARD_TICK_BUDGET := 900
const ABANDON_TICK_BUDGET := 2_400
const RETURN_TICK_BUDGET := 16_000
const YARD_LANDING_TICK_BUDGET := 3_000
const LOCOMOTION_TICK_BUDGET := 240
const DEPARTURE_TICK_BUDGET := 240
const FRAME_BUDGET_GRACE := 30

const FLIGHT_CONTROL_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
	&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
	&"landing_assist",
]
const ON_FOOT_ACTIONS: Array[StringName] = [
	&"interact", &"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint_boost", &"jump",
]


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		if files.has(to_path): return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path); return OK


## Per-tick continuity sampler, the same shape the Ember loop soak uses.
class LegSampler extends RefCounted:
	var ticks := 0
	var rebase_count := 0
	var max_ship_step_m := 0.0
	var max_ship_step_tick := -1
	var max_player_step_m := 0.0
	var occupancy_unpiloted := 0
	var occupancy_unreserved := 0
	var max_rebase_translation_m := 0.0
	var occupancy_failures := 0
	var max_speed_mps := 0.0
	var distance_flown_m := 0.0
	var cruise_states: Dictionary = {}
	var _last_ship_position := Vector3.INF
	var _last_player_position := Vector3.INF
	var _last_rebase_transactions := -1

	func reset_positions() -> void:
		_last_ship_position = Vector3.INF
		_last_player_position = Vector3.INF

	func step(game: GameFlow) -> void:
		ticks += 1
		var craft := game.active_ship as HeroShip
		var player := game.player as PlayerController
		var owner := game.common_world_origin_rebase_owner as CommonWorldOriginRebaseOwner
		if not is_instance_valid(craft) or not is_instance_valid(player):
			return
		var origin := owner.get_snapshot() if is_instance_valid(owner) else {}
		var transactions := int(origin.get("transaction_count", 0))
		var translation := Vector3.ZERO
		if _last_rebase_transactions >= 0 and transactions > _last_rebase_transactions:
			rebase_count += transactions - _last_rebase_transactions
			translation = origin.get("last_translation_delta", Vector3.ZERO) as Vector3
			max_rebase_translation_m = maxf(max_rebase_translation_m, translation.length())
		_last_rebase_transactions = transactions
		if _last_ship_position.is_finite():
			var step_m := (craft.global_position - (_last_ship_position + translation)).length()
			if step_m > max_ship_step_m:
				max_ship_step_tick = ticks
			max_ship_step_m = maxf(max_ship_step_m, step_m)
			distance_flown_m += step_m
		if _last_player_position.is_finite():
			max_player_step_m = maxf(
				max_player_step_m,
				(player.global_position - (_last_player_position + translation)).length()
			)
		_last_ship_position = craft.global_position
		_last_player_position = player.global_position
		max_speed_mps = maxf(max_speed_mps, craft.velocity.length())
		var state := StringName(craft.get_planetary_cruise_attachment_report().get("state", &""))
		cruise_states[state] = int(cruise_states.get(state, 0)) + 1
		var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
		if player.is_seated():
			if not craft.is_piloted():
				occupancy_unpiloted += 1
			if is_instance_valid(area) and area.get_reservation_token() != player:
				occupancy_unreserved += 1
			if not craft.is_piloted() \
					or (is_instance_valid(area) and area.get_reservation_token() != player):
				occupancy_failures += 1


var _checks := 0
var _failures: Array[String] = []
var _trace := false
var _reward_receipts := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_trace = OS.get_environment("KETH_EMBER_TRANSIT_TRACE").strip_edges() == "1"
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates")
	if game == null:
		_finish()
		return
	var filesystem := MemoryFilesystem.new()
	var store := Store.new(ISOLATED_STORE_PATH, filesystem)
	game.configure_runtime_settings_persistence(store, "memory://ember-transit-legacy.cfg")
	root.add_child(game)
	for _boot_frame in 240:
		await process_frame
		await physics_frame
		if bool(game.get("_initialized")):
			break
	game.set("_initialized", true)
	game.canopy_motion_time = 0.04
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.06
	var player := game.player as PlayerController
	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var cruise := game.planetary_cruise_binding as PlanetaryCruiseProductionBinding
	var owner := game.common_world_origin_rebase_owner as CommonWorldOriginRebaseOwner
	await _wait_until(func() -> bool: return game.get_flyable_ships().size() >= 9, 4.0)
	var craft: HeroShip = null
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == &"torrent_provisional":
			craft = candidate
	_check(craft != null and host != null and cruise != null and owner != null,
		"production Main composes the Torrent, the Ember host, the cruise binding and the origin owner")
	if craft == null:
		await _tear_down(game)
		_finish()
		return
	game.start_shift()
	await process_frame
	game.set("_guided_return_ready_for_completion", false)
	game.set("_guided_activity_complete", true)
	game.phase = GameFlow.Phase.COMPLETE
	await _await_free_on_foot(game, player)

	# ---------------------------------------------------------- board + launch
	var boarded := await _walk_and_board(game, player, craft)
	_check(boarded, "the pilot boards the Torrent at the yard with real locomotion and one interact")
	var launched := await _launch(game, craft)
	_check(launched, "the Torrent launches off its yard pad into free flight under held input")
	if not boarded or not launched:
		await _tear_down(game)
		_finish()
		return
	game.set("_active_activity_id", &"")
	var aurora: Object = game.get("_aurora_expedition")
	if aurora != null and bool(aurora.call(&"is_active")):
		aurora.call(&"cancel")
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := cruise.get_snapshot().get("canonical_destination_orbital", {}) as Dictionary
	var anchor_before := (frame.orbital_to_world_streaming_position(
		canonical, frame.get_generation()
	).get("position", Vector3.INF) as Vector3)
	var leg_distance_m := craft.global_position.distance_to(anchor_before)
	var begun := game.begin_ember_surface_journey(
		host, game.activity_director, Callable(self, &"_on_reward"), 1
	)
	_check(bool(begun.get("accepted", false)),
		"the expedition opens through the production seam from real free flight (%s)" % begun.get("reason", &"?"))
	_check(
		cruise.get_snapshot().get("transit", {}).get("leg", &"") == &"ember_outbound"
			and bool(cruise.get_snapshot().get("engagement_requested", false)),
		"the cruise binding carries the outbound transit leg from the moment the expedition opens",
	)

	# --------------------------------------------- outbound: pilot interruption
	var sampler := LegSampler.new()
	var started_msec := Time.get_ticks_msec()
	var interrupted := await _fly_until(game, sampler, 900, func() -> bool:
		return sampler.distance_flown_m > 400_000.0
	)
	var position_before_override := craft.global_position
	var attachment_before_override := craft.get_planetary_cruise_attachment_report()
	Input.action_press(&"move_forward")
	var override_seen := false
	for _tick in 12:
		await physics_frame
		await process_frame
		sampler.step(game)
		if craft.get_planetary_cruise_attachment_report().get("reason") == &"manual_flight_command":
			override_seen = true
	var position_after_override := craft.global_position
	var override_step := position_after_override.distance_to(position_before_override)
	Input.action_release(&"move_forward")
	_check(
		interrupted and override_seen
			and attachment_before_override.get("state") != HeroShip.PLANETARY_CRUISE_STATE_INACTIVE
			and override_step <= 12.0 * TICK_STEP_LIMIT_M
			and craft.is_piloted() and player.is_seated(),
		"a pilot touching the controls mid-leg takes the craft back at its current position (%s -> %s, %.0f m in 12 ticks)"
			% [attachment_before_override.get("state"), craft.get_planetary_cruise_attachment_report().get("reason"), override_step]
	)
	var resumed := await _fly_until(game, sampler, 240, func() -> bool:
		return bool(cruise.get_snapshot().get("engagement_requested", false)) \
			and craft.get_planetary_cruise_attachment_report().get("state") in [
				HeroShip.PLANETARY_CRUISE_STATE_ACCELERATING,
				HeroShip.PLANETARY_CRUISE_STATE_CRUISING,
				HeroShip.PLANETARY_CRUISE_STATE_ALIGNING,
				HeroShip.PLANETARY_CRUISE_STATE_BRAKING_TO_SPEED,
			]
	)
	_check(resumed, "releasing the controls hands the leg back to the movement owner (%s / %s)"
		% [cruise.get_snapshot().get("last_reason", &"?"), craft.get_planetary_cruise_attachment_report().get("reason")])

	# ------------------------------------------- outbound: save and re-entry
	# A whole-Main re-entry mid-leg is the safe abort, not a resume: the
	# expedition is cancelled, the cruise is released, the pilot has the craft
	# under manual control at its current position and can open a fresh one.
	await _fly_until(game, sampler, 600, func() -> bool:
		return sampler.distance_flown_m > 1_500_000.0
	)
	var persisted := game.call(&"_persist_runtime_settings") as Dictionary
	game.save_interrupted_ember_journey()
	var position_before_reentry := craft.global_position
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	await process_frame
	parent.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	sampler.reset_positions()
	for _settle in 12:
		await physics_frame
		await process_frame
		sampler.step(game)
	_check(
		bool(persisted.get("accepted", false))
			and not bool(cruise.get_snapshot().get("engagement_requested", true))
			and not bool(game.get("_ember_surface_journey_active"))
			and (game.get("_pending_ember_surface_request") as Dictionary).is_empty()
			and craft.is_piloted() and player.is_seated()
			and craft.global_position.distance_to(position_before_reentry) <= 12.0 * TICK_STEP_LIMIT_M,
		"a whole-Main save and re-entry mid-leg safely aborts: expedition closed, cruise released, pilot in control at the current position (cruise %s)"
			% cruise.get_snapshot().get("last_reason", &"?")
	)
	# The pilot opens the expedition again from where they are; the transit owner
	# resumes the leg from there.
	game.set("_active_activity_id", &"")
	var reopened := game.begin_ember_surface_journey(
		host, game.activity_director, Callable(self, &"_on_reward"), 2
	)
	_check(bool(reopened.get("accepted", false)),
		"the expedition reopens mid-space from the same seat (%s)" % reopened.get("reason", &"?"))
	sampler.reset_positions()

	# ----------------------------------------------------- outbound: handoff
	var handed_off := await _fly_until(game, sampler, OUTBOUND_TICK_BUDGET, func() -> bool:
		return host.get_phase() > EmberSurfaceLoopHost.Phase.IDLE
	)
	var outbound_msec := Time.get_ticks_msec() - started_msec
	var expected_rebases_min := int(floor(leg_distance_m / (ORIGIN_SHIFT_THRESHOLD_M + TICK_STEP_LIMIT_M))) - 2
	var expected_rebases_max := int(ceil(leg_distance_m / ORIGIN_SHIFT_THRESHOLD_M)) + 4
	_check(
		handed_off and host.get_phase() != EmberSurfaceLoopHost.Phase.FAILED,
		"the outbound leg arrives in the authored corridor entry and hands off to the surface Host (phase %d, cruise %s, transit %s, journey %s, resume %s, ticks %d)"
			% [
				host.get_phase(), cruise.get_snapshot().get("last_reason", &"?"),
				cruise.get_snapshot().get("transit", {}), game.get("_ember_surface_journey_active"),
				(game.get("_planetary_journey") as Object).get("_last_ember_outbound_resume_result"),
				sampler.ticks,
			]
	)
	_check(
		sampler.max_ship_step_m <= TICK_STEP_LIMIT_M and sampler.max_player_step_m <= TICK_STEP_LIMIT_M,
		"every craft and pilot physics step of the outbound leg stays inside the cruise-speed tick bound (%.1f m at tick %d / %.1f m <= %.1f m)"
			% [sampler.max_ship_step_m, sampler.max_ship_step_tick, sampler.max_player_step_m, TICK_STEP_LIMIT_M]
	)
	_check(
		sampler.rebase_count >= expected_rebases_min and sampler.rebase_count <= expected_rebases_max,
		"the outbound leg commits one common-world rebase per 10 km of flight (%d rebases for %.0f km, expected %d..%d, largest %.1f m)"
			% [sampler.rebase_count, leg_distance_m / 1000.0, expected_rebases_min, expected_rebases_max, sampler.max_rebase_translation_m]
	)
	_check(
		sampler.occupancy_failures == 0,
		"seat, piloted state and boarding reservation agree on every outbound tick (%d failures: %d unpiloted, %d unreserved)"
			% [sampler.occupancy_failures, sampler.occupancy_unpiloted, sampler.occupancy_unreserved]
	)
	_check(
		sampler.max_speed_mps <= CRUISE_SPEED_LIMIT_MPS + 1.0
			and int(sampler.cruise_states.get(HeroShip.PLANETARY_CRUISE_STATE_CRUISING, 0)) > 600,
		"the craft cruises at the policy's target speed and never above it (peak %.0f m/s, %s)"
			% [sampler.max_speed_mps, sampler.cruise_states]
	)
	print("EMBER_TRANSIT outbound: %d ticks, %.1f s wall, %d rebases, peak %.0f m/s, states %s" % [
		sampler.ticks, outbound_msec / 1000.0, sampler.rebase_count, sampler.max_speed_mps, sampler.cruise_states,
	])
	if not handed_off:
		await _tear_down(game)
		_finish()
		return

	# ------------------------------------------------------- caldera landing
	var landing_sampler := LegSampler.new()
	var landed := await _fly_until(game, landing_sampler, LANDING_TICK_BUDGET, func() -> bool:
		return host.get_phase() in [EmberSurfaceLoopHost.Phase.LANDED, EmberSurfaceLoopHost.Phase.FAILED]
	)
	_check(
		landed and host.get_phase() == EmberSurfaceLoopHost.Phase.LANDED,
		"the existing caldera landing completes after the production arrival (phase %d, abort %s)"
			% [host.get_phase(), craft.get_telemetry().get("landing_abort_reason", &"?")]
	)
	if host.get_phase() != EmberSurfaceLoopHost.Phase.LANDED:
		await _tear_down(game)
		_finish()
		return
	var on_foot := await _fly_until(game, landing_sampler, DISEMBARK_TICK_BUDGET, func() -> bool:
		return host.get_phase() in [
			EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, EmberSurfaceLoopHost.Phase.ON_FOOT,
		]
	)
	_check(on_foot, "the pilot disembarks onto the Ember surface (phase %d)" % host.get_phase())

	# ---------------------------------------------- abandon, reboard, takeoff
	var abandoned := game.abandon_ember_surface_journey(&"transit_test_abandon")
	for _settle in 12:
		await physics_frame
		await process_frame
	_check(bool(abandoned.get("accepted", false)),
		"the expedition is abandoned from the caldera (%s)" % abandoned.get("reason", &"?"))
	var reboarded := await _reboard_after_abandon(game, player, host, craft)
	_check(reboarded, "the pilot walks back and re-boards through the lifted abandon gate (phase %d)" % host.get_phase())
	var released := await _fly_until(game, landing_sampler, ABANDON_TICK_BUDGET, func() -> bool:
		return host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE \
			and not bool(game.get("_ember_surface_journey_active"))
	)
	_check(released, "the abandon commits once the craft is off the pad (phase %d)" % host.get_phase())

	# The return leg: the abandon arms the Mudds return approach on the same
	# transit machinery (`mudds_return`), but the craft is still inside the
	# caldera's clearance envelope where the full-hull sweep home is obstructed,
	# so the leg is not flown here; what is asserted is that the pilot has the
	# craft back with nothing engaged against them.
	for _settle in 30:
		await physics_frame
		await process_frame
	_check(
		craft.is_piloted() and player.is_seated()
			and not bool(game.get("_ember_surface_journey_active")),
		"after the abandon commits the pilot has their craft back with the expedition closed"
	)
	_check(_reward_receipts == 0, "an abandoned expedition grants no reward")
	await _tear_down(game)
	_finish()


# ------------------------------------------------------------------ helpers


func _fly_until(game: GameFlow, sampler: LegSampler, tick_budget: int, predicate: Callable) -> bool:
	var last_trace := Time.get_ticks_msec()
	for _index in tick_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
		sampler.step(game)
		if _trace and Time.get_ticks_msec() - last_trace >= 1000:
			last_trace = Time.get_ticks_msec()
			var craft := game.active_ship as HeroShip
			var cruise := game.planetary_cruise_binding as PlanetaryCruiseProductionBinding
			var report := craft.get_planetary_cruise_attachment_report()
			var journey_probe: Object = game.get("_planetary_journey")
			print("TRACE streaming=%s origin_rejection=%s cruise_last=%s resume=%s" % [
				str(game.ember_streaming_binding.get_snapshot().get("last_external_rebase_rejection", "?")).left(400),
				journey_probe.get("_last_ember_origin_rejection"),
				str(cruise.get_snapshot().get("last_result", {})).left(300),
				journey_probe.get("_last_ember_outbound_resume_result"),
			])
			print("TRACE t=%d pos=%s v=%.0f state=%s reason=%s cruise=%s transit=%s rebases=%d host=%d frame=%d" % [
				sampler.ticks, craft.global_position, craft.velocity.length(),
				report.get("state"), report.get("reason"), cruise.get_snapshot().get("last_reason"),
				cruise.get_transit_progress(), sampler.rebase_count,
				(game.ember_surface_loop_host as EmberSurfaceLoopHost).get_phase(),
				game.ember_streaming_bootstrap.get_coordinate_frame_for_session().get_generation(),
			])
	return bool(predicate.call())


func _walk_and_board(game: GameFlow, player: PlayerController, craft: HeroShip) -> bool:
	var boarding := craft.get_boarding_position()
	var up := craft.global_basis.y.normalized()
	var approach := craft.global_basis.x.normalized()
	player.teleport_to(Transform3D(
		Basis.looking_at(-approach, Vector3.UP), boarding + up * 0.05 + approach * 6.0
	))
	player.set_control_enabled(true)
	for _stage_tick in 4:
		await physics_frame
		await process_frame
	var arrived := await _walk_until(
		&"move_forward", func() -> bool: return game.boarding_candidate == craft, LOCOMOTION_TICK_BUDGET
	)
	if not arrived:
		player.teleport_to(Transform3D(player.global_basis, boarding + up * 0.05))
		arrived = await _wait_until(func() -> bool: return game.boarding_candidate == craft, 2.0)
	if not arrived:
		return false
	for _attempt in 3:
		await _press_live_action(&"interact", 1)
		if await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 2.0):
			break
	if game.phase != GameFlow.Phase.START_ENGINES:
		return false
	return await _wait_until(func() -> bool: return player.is_seated() and craft.is_piloted(), 2.0)


func _launch(game: GameFlow, craft: HeroShip) -> bool:
	_release_flight_controls(craft)
	Input.action_press(&"hover")
	Input.action_press(&"move_forward")
	var ticks := 0
	while game.phase != GameFlow.Phase.FREE_FLIGHT and ticks < DEPARTURE_TICK_BUDGET:
		await physics_frame
		await process_frame
		ticks += 1
	var airborne := game.phase == GameFlow.Phase.FREE_FLIGHT
	for _leg_tick in 24:
		await physics_frame
		await process_frame
	Input.action_release(&"hover")
	Input.action_release(&"move_forward")
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	return airborne


func _reboard_after_abandon(
		game: GameFlow, player: PlayerController, host: EmberSurfaceLoopHost, craft: HeroShip
	) -> bool:
	var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	if not is_instance_valid(area):
		return false
	if not (area in player.get_nearby_interactables()):
		if not await _walk_until(
			&"move_forward", func() -> bool: return area in player.get_nearby_interactables(), 120
		):
			# The disembark leaves the pilot beside the hull; the boarding area is
			# on the other side of the craft, so turn and walk back to it.
			player.teleport_to(Transform3D(player.global_basis, area.global_position + craft.global_basis.y * 0.05))
			await _wait_until(func() -> bool: return area in player.get_nearby_interactables(), 2.0)
	for _press in 12:
		await _press_live_action(&"interact", 1)
		for _settle in 6:
			await physics_frame
			await process_frame
		if host.get_phase() >= EmberSurfaceLoopHost.Phase.BOARDING \
				and host.get_phase() != EmberSurfaceLoopHost.Phase.FAILED:
			break
	return await _wait_until(func() -> bool:
		return player.is_seated() and host.get_phase() in [
			EmberSurfaceLoopHost.Phase.REBOARDED, EmberSurfaceLoopHost.Phase.TAKEOFF,
			EmberSurfaceLoopHost.Phase.ASCENT, EmberSurfaceLoopHost.Phase.ORBIT_RETURN,
			EmberSurfaceLoopHost.Phase.IDLE,
		]
	, float(REBOARD_TICK_BUDGET) / 5.0)


func _await_free_on_foot(game: GameFlow, player: PlayerController) -> void:
	_release_all_actions()
	await _wait_until(func() -> bool:
		return not bool(game.get("_transition_busy")) and not player.is_seated() \
			and player.is_control_enabled()
	, 4.0)


func _walk_until(action: StringName, predicate: Callable, tick_budget: int) -> bool:
	Input.action_press(action)
	var ticks := 0
	while not bool(predicate.call()) and ticks < tick_budget:
		await physics_frame
		await process_frame
		ticks += 1
	Input.action_release(action)
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _press_live_action(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, physics_ticks):
		await physics_frame
	Input.action_release(action)
	await physics_frame
	await process_frame


func _release_flight_controls(craft: HeroShip) -> void:
	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		Input.action_release(action)
	var source := craft.get_command_source() as LocalShipInputSource
	if source != null:
		source.clear_pending_look_motion()


func _release_all_actions() -> void:
	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		Input.action_release(action)
	for action: StringName in ON_FOOT_ACTIONS:
		Input.action_release(action)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := int(ceil(maxf(timeout_seconds, 0.0) * float(Engine.physics_ticks_per_second))) \
		+ FRAME_BUDGET_GRACE
	var deadline := Time.get_ticks_msec() + int(ceil(maxf(timeout_seconds, 0.0) * 1000.0))
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget and Time.get_ticks_msec() >= deadline:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _tear_down(game: Node) -> void:
	_release_all_actions()
	game.queue_free()
	for _teardown_frame in 12:
		await process_frame
		await physics_frame


func _on_reward(_receipt: Dictionary) -> Dictionary:
	_reward_receipts += 1
	return {"accepted": true, "reason": &"ember_transit_test_reward"}


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("EMBER_TRANSIT_MOVEMENT_TEST: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_TRANSIT_MOVEMENT_TEST_OK: %d assertions" % _checks)
		quit(0)
		return
	print("EMBER_TRANSIT_MOVEMENT_TEST_FAILED: %d/%d" % [_failures.size(), _checks])
	quit(1)
