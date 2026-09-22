extends SceneTree

## Production outbound flight from a real yard launch, with no flight staging.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const ISOLATED_STORE_PATH := "memory://ember-transit-movement.json"
const CRUISE_SPEED_LIMIT_MPS := PlanetaryCruisePolicy.TARGET_CRUISE_SPEED_METERS_PER_SECOND
const TICK_STEP_LIMIT_M := CRUISE_SPEED_LIMIT_MPS / 60.0 + 1.0
const OUTBOUND_TICK_BUDGET := 36_000
const LANDING_TICK_BUDGET := 3_000
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
	var last_ship_step_m := 0.0
	var last_player_step_m := 0.0
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
			occupancy_failures += 1
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
			last_ship_step_m = step_m
			if step_m > max_ship_step_m:
				max_ship_step_tick = ticks
			max_ship_step_m = maxf(max_ship_step_m, step_m)
			distance_flown_m += step_m
		if _last_player_position.is_finite():
			last_player_step_m = (player.global_position - (_last_player_position + translation)).length()
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
		var unseated := not player.is_seated()
		var unpiloted := not craft.is_piloted()
		var unreserved: bool = not is_instance_valid(area) or area.get_reservation_token() != player
		occupancy_unpiloted += int(unpiloted)
		occupancy_unreserved += int(unreserved)
		occupancy_failures += int(unseated or unpiloted or unreserved)



var _checks := 0
var _failures: Array[String] = []
var _reward_receipts := 0
var _forged_rebase_checks := 0
var _forged_rebases_rejected := true
var _replayed_rebase_checked := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
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
	_check(boarded, "the pilot boards the Torrent at the yard with real locomotion and interact")
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
	owner.rebase_committed.connect(func(receipt: Dictionary) -> void:
		if _forged_rebase_checks > 0 or not bool(cruise.get_snapshot().get("engagement_requested", false)):
			return
		var before := cruise.get_controller().get_snapshot()
		for field in ["world_id", "request_id", "world_translation_delta"]:
			var forged := receipt.duplicate(true)
			match field:
				"world_id": forged[field] = &"another_world"
				"request_id": forged[field] = int(forged[field]) + 1
				"world_translation_delta": forged[field] = (forged[field] as Vector3) + Vector3.ONE
			var rejected := cruise.accept_committed_origin_rebase(forged, cruise.get_generation())
			_forged_rebases_rejected = _forged_rebases_rejected \
				and not bool(rejected.get("accepted", true)) \
				and cruise.get_controller().get_snapshot() == before
			_forged_rebase_checks += 1
	)
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := cruise.get_snapshot().get("canonical_destination_orbital", {}) as Dictionary
	var ordinary_engagement := game.engage_planetary_cruise()
	_check(bool(ordinary_engagement.get("accepted", false)), "ordinary cruise can precede expedition admission")
	var attachment_before_admission := craft.get_planetary_cruise_attachment_report()
	var begun := game.begin_ember_surface_journey(
		host, game.activity_director, Callable(self, &"_on_reward"), 1
	)
	_check(bool(begun.get("accepted", false)),
		"the expedition opens through the production seam from real free flight (%s)" % begun.get("reason", &"?"))
	_check(bool(cruise.get_snapshot().get("carry_transit", false))
		and craft.get_planetary_cruise_attachment_report().get("ship_attachment_generation")
			== attachment_before_admission.get("ship_attachment_generation"),
		"expedition promotes ordinary cruise without retiring its live attachment")
	# Early in the same physical leg, exercise manual override, explicit cancel,
	# then a whole-Main re-entry. A fresh player request resumes from that place.
	for tick in 120:
		await physics_frame
		await process_frame
	Input.action_press(&"move_forward")
	for tick in 6:
		await physics_frame
		await process_frame
	_check(not bool(cruise.get_snapshot().get("engagement_requested", true))
		and craft.has_manual_flight_intent(), "held input takes and retains direct pilot control")
	var cancelled := game.cancel_ember_surface_journey()
	Input.action_release(&"move_forward")
	for tick in 30:
		await physics_frame
		await process_frame
	_check(bool(cancelled.get("accepted", false))
		and not bool(cruise.get_snapshot().get("engagement_requested", true))
		and (game.get("_pending_ember_surface_request") as Dictionary).is_empty(),
		"explicit cancellation after manual override does not silently resume")
	var restarted := game.begin_ember_surface_journey(host, game.activity_director, Callable(self, &"_on_reward"), 2)
	_check(bool(restarted.get("accepted", false)), "fresh player request restarts after cancellation")
	for tick in 30:
		await physics_frame
		await process_frame
	game.save_interrupted_ember_journey()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	await process_frame
	parent.add_child(game)
	for tick in 12:
		await physics_frame
		await process_frame
	var reentry_occupancy_current: bool = craft.is_piloted() \
		and player.is_seated_at(craft.get_pilot_seat_anchor()) \
		and craft.get_node("ShipBoardingArea").get_reservation_token() == player
	_check(not bool(cruise.get_snapshot().get("engagement_requested", true))
		and (game.get("_pending_ember_surface_request") as Dictionary).is_empty()
		and reentry_occupancy_current, "whole-Main re-entry aborts pending transit with pilot reservation retained")
	if not reentry_occupancy_current:
		await _tear_down(game)
		_finish()
		return
	var reopened := game.begin_ember_surface_journey(host, game.activity_director, Callable(self, &"_on_reward"), 3)
	_check(bool(reopened.get("accepted", false)), "fresh request after re-entry resumes from current craft position")
	var sampler := LegSampler.new()
	var last_reason: StringName = &""
	var ticks_without_motion := 0
	var handed_off := false
	for tick in OUTBOUND_TICK_BUDGET:
		await physics_frame
		await process_frame
		sampler.step(game)
		if sampler.occupancy_failures > 0:
			print("OUTBOUND_OCCUPANCY_LOST tick=", tick, " unpiloted=", sampler.occupancy_unpiloted, " unreserved=", sampler.occupancy_unreserved)
			break
		if sampler.rebase_count > 0 and not _replayed_rebase_checked:
			var receipt := owner.get_snapshot().get("last_receipt", {}) as Dictionary
			var before_replay := cruise.get_controller().get_snapshot()
			var replay := cruise.accept_committed_origin_rebase(receipt, cruise.get_generation())
			_check(not bool(replay.get("accepted", true))
				and cruise.get_controller().get_snapshot() == before_replay,
				"committed rebase replay cannot translate or retarget twice")
			_replayed_rebase_checked = true
		var snapshot := cruise.get_snapshot()
		var reason := StringName(snapshot.get("last_reason", &""))
		if tick % 600 == 0 or reason != last_reason:
			var anchor := frame.orbital_to_world_streaming_position(canonical, frame.get_generation())
			print("OUTBOUND tick=%d distance=%.1f speed=%.1f rebases=%d cruise=%s host_attached=%s host_phase=%d host_frame=%d loaded=%s approach=%s" % [
				tick, craft.global_position.distance_to(anchor.get("position", Vector3.INF)),
				craft.velocity.length(), sampler.rebase_count, reason, host.is_attached(), host.get_phase(),
				host.get_coordinate_frame_generation(), is_instance_valid(game.ember_streaming_bootstrap.get_loaded_instance()),
				(snapshot.get("controller", {}) as Dictionary).get("final_approach", {})])
		last_reason = reason
		if host.get_phase() > EmberSurfaceLoopHost.Phase.IDLE:
			handed_off = host.get_phase() != EmberSurfaceLoopHost.Phase.FAILED
			break
		ticks_without_motion = ticks_without_motion + 1 if craft.velocity.length() < 0.01 else 0
		if ticks_without_motion > 180:
			print("OUTBOUND_STALLED host=", host.get_snapshot().get("last_result"),
				" forwarding=", game.get("_planetary_journey").get("_last_ember_surface_forward_result"),
				" rearm=", game.get("_planetary_journey").get("_last_ember_final_approach_rearm_result"),
				" origin=", game.get("_planetary_journey").get("_last_ember_origin_announcement"),
				" cruise=", snapshot.get("last_result"))
			break
	_check(_forged_rebase_checks == 3 and _forged_rebases_rejected,
		"wrong world, request and translation receipts leave live transit unchanged")
	_check(handed_off, "physical outbound reaches the authored entry and starts surface handoff")
	_check(sampler.distance_flown_m > 7_800_000.0, "outbound craft physically covers over 7,800 km")
	_check(sampler.rebase_count > 700, "outbound crosses hundreds of committed origin rebases")
	_check(sampler.max_ship_step_m <= TICK_STEP_LIMIT_M and sampler.max_player_step_m <= TICK_STEP_LIMIT_M,
		"craft and seated pilot remain continuous through rebases")
	_check(sampler.occupancy_failures == 0, "pilot retains seat reservation and piloted state")
	print("OUTBOUND_RESULT ticks=%d distance=%.1f rebases=%d peak=%.1f max_steps=%.3f/%.3f" % [
		sampler.ticks, sampler.distance_flown_m, sampler.rebase_count, sampler.max_speed_mps,
		sampler.max_ship_step_m, sampler.max_player_step_m])
	if handed_off:
		var landed := false
		var landing_max_step := 0.0
		for tick in LANDING_TICK_BUDGET:
			await physics_frame
			await process_frame
			sampler.step(game)
			if sampler.occupancy_failures > 0:
				print("LANDING_OCCUPANCY_LOST tick=", tick)
				break
			landing_max_step = maxf(landing_max_step, maxf(sampler.last_ship_step_m, sampler.last_player_step_m))
			if host.get_phase() in [EmberSurfaceLoopHost.Phase.LANDED, EmberSurfaceLoopHost.Phase.FAILED]:
				landed = host.get_phase() == EmberSurfaceLoopHost.Phase.LANDED
				break
		_check(landed and bool(craft.get_telemetry().get("landed", false))
			and game.ember_surface_berth.get_occupant() == craft,
			"surface Host physically lands the arriving craft")
		_check(sampler.max_ship_step_m <= TICK_STEP_LIMIT_M
			and sampler.max_player_step_m <= TICK_STEP_LIMIT_M
			and sampler.occupancy_failures == 0 and landing_max_step <= 1.0,
			"physical handoff and landing preserve craft, pilot and seat continuity")
		print("OUTBOUND_LANDING phase=", host.get_phase(), " max_step=", landing_max_step, " telemetry=", craft.get_telemetry())
	await _tear_down(game)
	_finish()


func _walk_and_board(game: GameFlow, player: PlayerController, craft: HeroShip) -> bool:
	var boarding := craft.get_boarding_position()
	var up := craft.global_basis.y.normalized()
	var approach := craft.global_basis.x.normalized()
	# Initial on-foot placement only; failed locomotion never teleports into admission.
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
