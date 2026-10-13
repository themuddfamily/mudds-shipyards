extends SceneTree

## Production outbound flight from a real yard launch, with no flight staging.
## KETH_EMBER_PHYSICAL_RETURN=1 adds the long ABANDON round trip and ordinary
## pilot-input berth landing. KETH_RETURN_ARRIVAL_DIAGNOSTIC=1 runs only a real
## yard launch and input-driven return to the same berth (no flight staging).
## --ember-completed-return launches the Arrow as an ordinary free sortie,
## walks the actual relay survey, commits its reward,
## reboards and physically returns home. It uses the existing initial on-foot
## yard placement and fresh disk-backed user:// store, with no surface/flight placement.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const ISOLATED_STORE_PATH := "memory://ember-transit-movement.json"
const COMPLETED_STORE_PATH := "user://ember-canonical-completed-journey.json"
const CRUISE_SPEED_LIMIT_MPS := PlanetaryCruisePolicy.TARGET_CRUISE_SPEED_METERS_PER_SECOND
const TICK_STEP_LIMIT_M := CRUISE_SPEED_LIMIT_MPS / 60.0 + 1.0
const OUTBOUND_TICK_BUDGET := 36_000
const LANDING_TICK_BUDGET := 3_000
const LOCOMOTION_TICK_BUDGET := 240
const DEPARTURE_TICK_BUDGET := 240
const FRAME_BUDGET_GRACE := 30
const COMPLETED_ASCENT_SECONDS := 240.0
const COMPLETED_RETURN_TICK_BUDGET := 42_000
const SURFACE_OUTBOUND_LEGS: Array = [
	["x", -9.0, false, &"move_back", 90],
	["z", 8.0, true, &"move_right", 120],
	["x", 17.5, true, &"move_forward", 150],
	["z", 0.5, false, &"move_left", 120],
	["x", 41.5, true, &"move_forward", 150],
]
const SURVEY_LEGS: Array = [
	["z", -44.0, false, &"move_left", 600],
	["x", 180.0, true, &"move_forward", 1800],
	["z", -210.0, false, &"move_left", 2100],
	["x", 540.0, true, &"move_forward", 4200],
]
const SURFACE_RETURN_LEGS: Array = [
	["x", 180.0, false, &"move_back", 4200],
	["z", -44.0, true, &"move_right", 2100],
	["x", 41.5, false, &"move_back", 1800],
	["z", 0.5, true, &"move_right", 600],
	["x", 18.5, false, &"move_back", 150],
	["z", 8.0, true, &"move_right", 120],
	["x", -9.0, false, &"move_back", 150],
	["z", 0.5, false, &"move_left", 120],
]

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

	var physics_sampling := false
	var physics_phase: StringName = &""
	var physics_samples := 0
	var max_physics_frame_gap := 0
	var max_landing_step_m := 0.0
	var _physics_tree: SceneTree
	var _physics_game: WeakRef
	var _last_physics_frame := -1
	var _waiting_for_seat := false

	func start_physics_sampling(tree: SceneTree, game: GameFlow, phase: StringName, wait_for_seat: bool = false) -> void:
		_physics_tree = tree
		_physics_game = weakref(game)
		physics_phase = phase
		physics_sampling = true
		_waiting_for_seat = wait_for_seat
		if not wait_for_seat:
			_baseline_physics_positions(game)
		tree.physics_frame.connect(_sample_previous_physics_step)

	func _baseline_physics_positions(game: GameFlow) -> void:
		# A read-only baseline; measured deltas come only from physics callbacks.
		_last_ship_position = game.active_ship.global_position
		_last_player_position = game.player.global_position
		_last_rebase_transactions = int(game.common_world_origin_rebase_owner.get_snapshot().get("transaction_count", 0))

	func stop_physics_sampling() -> void:
		if not physics_sampling:
			return
		# The connected callback runs first and captures the final completed
		# tick before this waiter disconnects. No post-process sample is added.
		await _physics_tree.physics_frame
		_physics_tree.physics_frame.disconnect(_sample_previous_physics_step)
		physics_sampling = false
		_physics_game = null

	func _sample_previous_physics_step() -> void:
		var game := _physics_game.get_ref() as GameFlow
		if not is_instance_valid(game) or game.is_queued_for_deletion():
			return
		if _waiting_for_seat:
			var craft := game.active_ship as HeroShip
			var player := game.player as PlayerController
			var area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
			if not craft.is_piloted() or not player.is_seated_at(craft.get_pilot_seat_anchor()) \
					or area.get_reservation_token() != player \
					or game.ember_surface_loop_host.get_phase() < EmberSurfaceLoopHost.Phase.REBOARDED:
				return
			# Observe the genuine seat boundary before the first ascent step;
			# the ordinary boarding pose change is outside flight continuity.
			_baseline_physics_positions(game)
			_waiting_for_seat = false
		var frame := Engine.get_physics_frames()
		if _last_physics_frame >= 0:
			max_physics_frame_gap = maxi(max_physics_frame_gap, frame - _last_physics_frame)
		_last_physics_frame = frame
		physics_samples += 1
		# physics_frame precedes EVERY node physics step, so these reads observe
		# the previous completed step even during several catch-up ticks.
		_sample(game)
		if physics_phase == &"outbound" and game.ember_surface_loop_host.get_phase() > EmberSurfaceLoopHost.Phase.IDLE:
			physics_phase = &"landing"
		if physics_phase == &"landing":
			max_landing_step_m = maxf(max_landing_step_m, maxf(last_ship_step_m, last_player_step_m))

	func step(game: GameFlow) -> void:
		# Existing process-loop calls remain the legacy sampler; completed mode
		# is measured exclusively by the physics callback, with no double steps.
		if not physics_sampling:
			_sample(game)

	func _sample(game: GameFlow) -> void:
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
var _first_outbound_blocker: Dictionary = {}
var _physics_samplers: Array[LegSampler] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var completed_mode := "--ember-completed-return" in OS.get_cmdline_user_args()
	if completed_mode and (OS.get_environment("KETH_EMBER_PHYSICAL_RETURN") == "1" \
			or OS.get_environment("KETH_RETURN_ARRIVAL_DIAGNOSTIC") == "1"):
		_check(false, "completed mode must run separately from ABANDON and local arrival modes")
		_finish()
		return
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates")
	if game == null:
		_finish()
		return
	var filesystem: UserDataFilesystem = UserDataFilesystem.new() if completed_mode else MemoryFilesystem.new()
	var store_path := COMPLETED_STORE_PATH if completed_mode else ISOLATED_STORE_PATH
	if completed_mode:
		# Run in a fresh private profile; never erase or replace a previous journey.
		var fresh := true
		for suffix in ["", ".tmp", ".bak", ".bak.1", ".bak.2", ".bak.3"]:
			fresh = fresh and not filesystem.file_exists(store_path + suffix)
		_check(fresh, "completed journey requires an empty isolated disk-backed store")
		if not fresh:
			game.free()
			_finish()
			return
	var store := Store.new(store_path, filesystem)
	game.configure_runtime_settings_persistence(store,
		"user://ember-canonical-completed-legacy.cfg" if completed_mode else "memory://ember-transit-legacy.cfg")
	root.add_child(game)
	for _boot_frame in 240:
		await process_frame
		await physics_frame
		if bool(game.get("_initialized")):
			break
	if completed_mode:
		_check(bool(game.get("_initialized")), "completed journey waits for genuine production initialization")
		if not bool(game.get("_initialized")):
			await _tear_down(game)
			_finish()
			return
	else:
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
	# Fresh Torrent remains the guided combat slice. The Arrow naturally boards
	# as a free sortie without manufacturing tutorial completion or sandbox flags.
	var craft_id: StringName = &"arrow_provisional" if completed_mode else &"torrent_provisional"
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == craft_id:
			craft = candidate
	_check(craft != null and host != null and cruise != null and owner != null,
		"production Main composes the selected craft, the Ember host, the cruise binding and the origin owner")
	if craft == null or (completed_mode and (host == null or cruise == null or owner == null)):
		await _tear_down(game)
		_finish()
		return
	game.start_shift()
	await process_frame
	if completed_mode:
		# Select before ordinary launch can start and lock the default timed race.
		var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
		_check(bool(selected.get("accepted", false)), "completed journey selects the idle activity through production")
		if not bool(selected.get("accepted", false)):
			await _tear_down(game)
			_finish()
			return
	else:
		game.set("_guided_return_ready_for_completion", false)
		game.set("_guided_activity_complete", true)
		game.phase = GameFlow.Phase.COMPLETE
	await _await_free_on_foot(game, player)

	# ---------------------------------------------------------- board + launch
	var boarded := await _walk_and_board(game, player, craft, completed_mode)
	_check(boarded, "the pilot boards the selected craft at the yard with real locomotion and interact")
	var launched: bool
	if completed_mode:
		launched = await _launch_completed(game, craft)
	else:
		launched = await _launch(game, craft)
	_check(launched, "the selected craft launches off its yard pad into free flight under held input")
	if not boarded or not launched:
		await _tear_down(game)
		_finish()
		return
	if OS.get_environment("KETH_RETURN_ARRIVAL_DIAGNOSTIC") == "1":
		Input.action_press(&"hover")
		Input.action_press(&"move_forward")
		for tick in 180:
			await physics_frame
			await process_frame
		_release_all_actions()
		var arrived := await _fly_home_berth(game, LegSampler.new())
		_check(arrived, "ordinary flight inputs return the launch to its home berth and disembark")
		await _tear_down(game)
		_finish()
		return
	if not completed_mode:
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
	if completed_mode:
		var climbed := await _clear_completed_departure_hulk(game, craft)
		var aligned: bool = false
		if climbed:
			aligned = await _align_completed_outbound(game, craft)
		_check(climbed and aligned, "ordinary outward climb clears the station hulk before yaw, pitch and braking align the departed craft for cruise")
		if not aligned:
			await _tear_down(game)
			_finish()
			return
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := cruise.get_snapshot().get("canonical_destination_orbital", {}) as Dictionary
	if completed_mode:
		# Retirement emits this snapshot synchronously with the refused proof still
		# present; a later ordinary tick replaces it with not_engaged.
		cruise.engagement_changed.connect(func(snapshot: Dictionary) -> void:
			_capture_first_outbound_blocker(game, craft, snapshot)
		)
	var ordinary_engagement := game.engage_planetary_cruise()
	_check(bool(ordinary_engagement.get("accepted", false)), "ordinary cruise can precede expedition admission")
	var attachment_before_admission := craft.get_planetary_cruise_attachment_report()
	var begun: Dictionary
	if completed_mode:
		begun = game.call(&"_begin_player_ember_surface_journey", 1)
	else:
		begun = game.begin_ember_surface_journey(
			host, game.activity_director, Callable(self, &"_on_reward"), 1
		)
	_check(bool(begun.get("accepted", false)),
		"the expedition opens through the production seam from real free flight (%s)" % begun.get("reason", &"?"))
	_check(bool(cruise.get_snapshot().get("carry_transit", false))
		and craft.get_planetary_cruise_attachment_report().get("ship_attachment_generation")
			== attachment_before_admission.get("ship_attachment_generation"),
		"expedition promotes ordinary cruise without retiring its live attachment")
	if completed_mode and not bool(begun.get("accepted", false)):
		await _tear_down(game)
		_finish()
		return
	if not completed_mode:
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
	if completed_mode:
		sampler.start_physics_sampling(self, game, &"outbound")
		_physics_samplers.append(sampler)
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
		if not completed_mode and sampler.rebase_count > 0 and not _replayed_rebase_checked:
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
	if not completed_mode:
		_check(_forged_rebase_checks == 3 and _forged_rebases_rejected,
			"wrong world, request and translation receipts leave live transit unchanged")
	if completed_mode and not handed_off:
		await sampler.stop_physics_sampling()
	_check(handed_off, "physical outbound reaches the authored entry and starts surface handoff")
	_check(sampler.distance_flown_m > 7_800_000.0, "outbound craft physically covers over 7,800 km")
	_check(sampler.rebase_count > 700, "outbound crosses hundreds of committed origin rebases")
	_check(sampler.max_ship_step_m <= TICK_STEP_LIMIT_M and sampler.max_player_step_m <= TICK_STEP_LIMIT_M
		and (not completed_mode or sampler.max_physics_frame_gap <= 1),
		"craft and seated pilot remain continuous through rebases")
	_check(sampler.occupancy_failures == 0, "pilot retains seat reservation and piloted state")
	print("OUTBOUND_RESULT ticks=%d distance=%.1f rebases=%d peak=%.1f max_steps=%.3f/%.3f" % [
		sampler.ticks, sampler.distance_flown_m, sampler.rebase_count, sampler.max_speed_mps,
		sampler.max_ship_step_m, sampler.max_player_step_m],
		" physics_phase=%s physics_samples=%d max_frame_gap=%d" % [sampler.physics_phase,
			sampler.physics_samples, sampler.max_physics_frame_gap] if completed_mode else "")
	if handed_off:
		var landed := false
		var landing_max_step := 0.0
		# Host SURFACE_APPROACH uses ordinary flight before landing assist.
		var landing_step_limit := craft.maximum_speed / float(Engine.physics_ticks_per_second) + 0.01
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
		if completed_mode:
			await sampler.stop_physics_sampling()
			landing_max_step = sampler.max_landing_step_m
		_check(landed and bool(craft.get_telemetry().get("landed", false))
			and game.ember_surface_berth.get_occupant() == craft,
			"surface Host physically lands the arriving craft")
		_check(sampler.max_ship_step_m <= TICK_STEP_LIMIT_M
			and sampler.max_player_step_m <= TICK_STEP_LIMIT_M
			and sampler.occupancy_failures == 0 and landing_max_step <= landing_step_limit
			and (not completed_mode or sampler.max_physics_frame_gap <= 1),
			"physical handoff and landing preserve craft, pilot and seat continuity")
		print("OUTBOUND_LANDING phase=", host.get_phase(), " max_step=", landing_max_step, " telemetry=", craft.get_telemetry(),
			" physics_phase=%s physics_samples=%d max_frame_gap=%d" % [sampler.physics_phase,
				sampler.physics_samples, sampler.max_physics_frame_gap] if completed_mode else "")
		if landed and completed_mode:
			await _physical_completed_return(game, store, filesystem)
		elif landed and OS.get_environment("KETH_EMBER_PHYSICAL_RETURN") == "1":
			await _physical_abandon_return(game)

	await _tear_down(game)
	_finish()


func _capture_first_outbound_blocker(game: GameFlow, craft: HeroShip, snapshot: Dictionary) -> void:
	if not _first_outbound_blocker.is_empty() or snapshot.get("last_reason") != &"obstacle_detected":
		return
	# Keep the delivered snapshot, not a later read of the binding's last result.
	_first_outbound_blocker = snapshot.duplicate(true)
	var result := _first_outbound_blocker.get("last_result", {}) as Dictionary
	var proof := (result.get("evidence", {}) as Dictionary).get("proof", {}) as Dictionary
	var exclusions := _read_only_cruise_self_exclusions(craft)
	var names := proof.get("shape_names", PackedStringArray()) as PackedStringArray
	var transforms := proof.get("shape_transforms", []) as Array
	var motion := (proof.get("direction_world", Vector3.ZERO) as Vector3) \
		* float(proof.get("sweep_distance_meters", 0.0))
	var space := craft.get_world_3d().direct_space_state
	var queries: Array[Dictionary] = []
	for child in craft.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var index := names.find(str(collision.name))
		if index < 0 or index >= transforms.size():
			continue
		# Replay only the refused proof's transform, mask, zero margin, exact live
		# production self-exclusions and motion. No new proof is built/submitted.
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = transforms[index] as Transform3D
		query.collision_mask = int(proof.get("collision_mask", craft.collision_mask))
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = exclusions
		query.margin = 0.0
		var start_hits := space.intersect_shape(query, 4)
		var fractions := PackedFloat32Array()
		if start_hits.is_empty():
			query.motion = motion
			fractions = space.cast_motion(query)
		var contact_hits: Array[Dictionary] = []
		var endpoint_hits: Array[Dictionary] = []
		if start_hits.is_empty() and fractions.size() == 2:
			query.motion = Vector3.ZERO
			var contact_transform := query.transform
			if float(fractions[0]) < 1.0:
				contact_transform.origin += motion * float(fractions[1])
				query.transform = contact_transform
				contact_hits = space.intersect_shape(query, 4)
			else:
				contact_transform.origin += motion
				query.transform = contact_transform
				endpoint_hits = space.intersect_shape(query, 4)
		var refinement: Dictionary = {}
		if start_hits.is_empty() and contact_hits.is_empty() and fractions.size() == 2 \
				and float(fractions[0]) < 1.0:
			refinement = _refine_blocker_contact(space, query, transforms[index] as Transform3D, motion, fractions, craft)
		# Include every root shape, including full casts that replay clear. The
		# aggregate zero prefix can originate in an unsupported shape or a leaf.
		queries.append({"shape": str(collision.name), "shape_class": collision.shape.get_class(),
			"safe_unsafe_fractions": fractions,
			"start_overlaps": _blocker_hit_details(craft, start_hits),
			"sweep_contacts": _blocker_hit_details(craft, contact_hits),
			"closed_endpoint_contacts": _blocker_hit_details(craft, endpoint_hits), "refinement": refinement,
			"first_forced_leaf": _capture_first_forced_leaf(space, query,
				transforms[index] as Transform3D, motion, craft)})
	var exclusion_ids: Array[int] = []
	for excluded: RID in exclusions:
		exclusion_ids.append(excluded.get_id())
	print("OUTBOUND_STALLED first_blocker=", JSON.stringify({
		"snapshot": _first_outbound_blocker, "proof": proof,
		"physics_frame": Engine.get_physics_frames(), "craft_position": craft.global_position,
		"craft_velocity": craft.velocity, "telemetry": craft.get_telemetry(),
		"coordinate_frame": game.ember_streaming_bootstrap.get_coordinate_frame_for_session().get_snapshot(),
		"self_exclusion_rids": exclusion_ids, "queries": queries,
	}, "", true, true))


## Synchronous read-only replay of the first depth-eight leaf. No proof request,
## submission, movement or actor authority is created. The separate convex query
## covers the complete translated Box, with the exact production query filters.
func _capture_first_forced_leaf(
		space: PhysicsDirectSpaceState3D, original: PhysicsShapeQueryParameters3D,
		start: Transform3D, full_motion: Vector3, craft: HeroShip
	) -> Dictionary:
	var leaf_motion := full_motion / float(1 << HeroShip.PLANETARY_CRUISE_CLEARANCE_SPLIT_MAX_DEPTH)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = original.shape
	query.transform = start
	query.collision_mask = original.collision_mask
	query.collide_with_bodies = original.collide_with_bodies
	query.collide_with_areas = original.collide_with_areas
	query.exclude = original.exclude
	query.margin = original.margin
	query.motion = Vector3.ZERO
	var start_hits := space.intersect_shape(query, 4)
	query.motion = leaf_motion
	var fractions := space.cast_motion(query)
	var native_valid: bool = fractions.size() == 2 and is_finite(float(fractions[0])) \
		and is_finite(float(fractions[1])) and float(fractions[0]) >= 0.0 \
		and float(fractions[1]) <= 1.0 and float(fractions[0]) <= float(fractions[1])
	var end := start
	end.origin += leaf_motion
	query.transform = end
	query.motion = Vector3.ZERO
	var end_hits := space.intersect_shape(query, 4)
	var result := {"motion_world": leaf_motion, "length_m": leaf_motion.length(),
		"start_transform": start, "end_transform": end,
		"native_cast_valid": native_valid, "safe_unsafe_fractions": fractions,
		"start_overlaps": _blocker_hit_details(craft, start_hits),
		"closed_endpoint_contacts": _blocker_hit_details(craft, end_hits),
		"swept_volume_status": &"not_box", "swept_volume_contacts": []}
	var box := original.shape as BoxShape3D
	if box == null:
		return result
	result["swept_volume_status"] = &"invalid_transform"
	if not start.is_finite() or not leaf_motion.is_finite() or is_zero_approx(start.basis.determinant()):
		return result
	result["swept_volume_status"] = &"invalid_box_size"
	if not box.size.is_finite() or box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		return result
	var local_motion := start.basis.inverse() * leaf_motion
	result["swept_volume_status"] = &"invalid_local_motion"
	if not local_motion.is_finite():
		return result
	var half_size := box.size * 0.5
	var points := PackedVector3Array()
	result["swept_volume_status"] = &"invalid_corners"
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var corner := half_size * Vector3(x, y, z)
				var end_corner := corner + local_motion
				if not corner.is_finite() or not end_corner.is_finite():
					return result
				points.append(corner)
				points.append(end_corner)
	var volume := ConvexPolygonShape3D.new()
	volume.points = points
	result["swept_volume_status"] = &"invalid_volume"
	if volume.points.size() != 16 or not volume.get_rid().is_valid():
		return result
	var swept_query := PhysicsShapeQueryParameters3D.new()
	swept_query.shape = volume
	swept_query.transform = start
	swept_query.motion = Vector3.ZERO
	swept_query.collision_mask = original.collision_mask
	swept_query.collide_with_bodies = original.collide_with_bodies
	swept_query.collide_with_areas = original.collide_with_areas
	swept_query.exclude = original.exclude
	swept_query.margin = original.margin
	result["swept_volume_status"] = &"queried"
	result["swept_volume_contacts"] = _blocker_hit_details(craft, space.intersect_shape(swept_query, 4))
	return result


## A 750 km cast can bracket a thin object by kilometres. Narrow that SAME
## captured interval with at most four local casts; never change the proof or
## infer a collider from a fraction alone. intersect_shape samples each explicit
## pose with zero motion (that API ignores the motion property).
func _refine_blocker_contact(
		space: PhysicsDirectSpaceState3D, original_query: PhysicsShapeQueryParameters3D,
		original_transform: Transform3D, motion: Vector3, fractions: PackedFloat32Array,
		craft: HeroShip
	) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = original_query.shape
	query.collision_mask = original_query.collision_mask
	query.collide_with_bodies = original_query.collide_with_bodies
	query.collide_with_areas = original_query.collide_with_areas
	query.exclude = original_query.exclude
	query.margin = original_query.margin
	var lower := float(fractions[0])
	var upper := float(fractions[1])
	var observations: Array[Dictionary] = []
	var reason := &"four_refinements_without_intersection"
	for _iteration in 4:
		var start_pose := original_transform
		start_pose.origin += motion * lower
		var end_pose := original_transform
		end_pose.origin += motion * upper
		query.motion = Vector3.ZERO
		query.transform = start_pose
		var start_hits := space.intersect_shape(query, 4)
		query.transform = end_pose
		var end_hits := space.intersect_shape(query, 4)
		var observation := {"interval_fractions": [lower, upper],
			"interval_length_m": motion.length() * (upper - lower),
			"start_overlaps": _blocker_hit_details(craft, start_hits),
			"unsafe_contacts": _blocker_hit_details(craft, end_hits)}
		observations.append(observation)
		if not start_hits.is_empty() or not end_hits.is_empty():
			reason = &"actual_refined_intersection"
			break
		if upper <= lower:
			reason = &"no_remaining_interval_without_intersection"
			break
		query.transform = start_pose
		query.motion = motion * (upper - lower)
		var local_fractions := space.cast_motion(query)
		observation["local_safe_unsafe_fractions"] = local_fractions
		if local_fractions.size() != 2 or not is_finite(float(local_fractions[0])) \
				or not is_finite(float(local_fractions[1])):
			reason = &"refined_cast_invalid"
			break
		if float(local_fractions[0]) == 1.0 and float(local_fractions[1]) == 1.0:
			reason = &"captured_interval_recasts_clear_with_clear_endpoints"
			break
		var next_lower := lower + (upper - lower) * float(local_fractions[0])
		var next_upper := lower + (upper - lower) * float(local_fractions[1])
		if next_lower < lower or next_upper > upper or next_upper < next_lower:
			reason = &"refined_cast_interval_invalid"
			break
		var contact_pose := original_transform
		contact_pose.origin += motion * next_upper
		query.motion = Vector3.ZERO
		query.transform = contact_pose
		var contacts := space.intersect_shape(query, 4)
		observation["refined_interval_fractions"] = [next_lower, next_upper]
		observation["refined_interval_length_m"] = motion.length() * (next_upper - next_lower)
		observation["refined_contact_pose"] = contact_pose
		observation["refined_contacts"] = _blocker_hit_details(craft, contacts)
		lower = next_lower
		upper = next_upper
		if not contacts.is_empty():
			reason = &"actual_refined_intersection"
			break
	return {"reason": reason, "interval_fractions": [lower, upper],
		"interval_length_m": motion.length() * (upper - lower), "observations": observations}


## Same membership as HeroShip._planetary_cruise_self_collision_exclusions.
## Read declarations only: the preceding production proof already maintained its
## live exception watchers. Do not call the owner helper's cleanup/connect paths.
func _read_only_cruise_self_exclusions(craft: HeroShip) -> Array[RID]:
	var exclusions: Array[RID] = [craft.get_rid()]
	var declared: Array[RID] = []
	for body: PhysicsBody3D in craft.get_collision_exceptions():
		if is_instance_valid(body):
			declared.append(body.get_rid())
	if declared.is_empty():
		return exclusions
	var pending: Array[Node] = []
	pending.assign(craft.get_children())
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion() \
				or node is CharacterBody3D or node is RigidBody3D:
			continue
		if node is CollisionObject3D:
			var body_rid := (node as CollisionObject3D).get_rid()
			if declared.has(body_rid):
				exclusions.append(body_rid)
		pending.append_array(node.get_children())
	exclusions.sort_custom(func(left: RID, right: RID) -> bool: return left.get_id() < right.get_id())
	return exclusions


func _blocker_hit_details(craft: HeroShip, hits: Array[Dictionary]) -> Array[Dictionary]:
	var details: Array[Dictionary] = []
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		var node := collider as Node
		var collision_object := collider as CollisionObject3D
		var hit_rid: RID = hit.get("rid", RID())
		details.append({"collider_id": hit.get("collider_id", 0), "rid": hit_rid.get_id(),
			"path": str(node.get_path()) if is_instance_valid(node) else "",
			"class": collider.get_class() if is_instance_valid(collider) else "",
			"layer": collision_object.collision_layer if is_instance_valid(collision_object) else 0,
			"selected_craft_descendant": is_instance_valid(node) and craft.is_ancestor_of(node),
			"position": (node as Node3D).global_position if node is Node3D else Vector3.ZERO})
	return details


## Same physical outbound and home pilot as ABANDON, but the real survey owns
## completion and reward. Walking deadlines add distance / ordinary walk speed
## to the existing per-leg settling allowance and count actual physics frames.
func _physical_completed_return(
		game: GameFlow, store: UserDataStore, filesystem: UserDataFilesystem
	) -> void:
	var craft := game.active_ship as HeroShip
	var player := game.player as PlayerController
	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var on_foot := await _wait_until(func() -> bool:
		return host.get_phase() == EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND \
			and not player.is_seated() and player.is_control_enabled(), 30.0)
	_check(on_foot, "completed arrival genuinely disembarks its pilot")
	if not on_foot:
		return
	if not await _walk_surface_legs(game, SURFACE_OUTBOUND_LEGS):
		return
	var survey_started := await _wait_until(func() -> bool:
		return host.get_phase() == EmberSurfaceLoopHost.Phase.ON_FOOT, 3.0)
	var identities := host.get_snapshot().get("identities", {}) as Dictionary
	_check(survey_started and host.is_attached()
		and identities.get("player_instance_id") == player.get_instance_id()
		and identities.get("ship_instance_id") == craft.get_instance_id()
		and _beacon_receipts(store) == 0,
		"current real Host actors start the unpaid surface survey after authored egress")
	if not survey_started:
		return
	var generation := int(_survey_route(game).get("activity_generation", -1))
	_check(generation > 0, "the real survey owns a positive activity generation")
	for index in SURVEY_LEGS.size():
		if not await _walk_surface_legs(game, [SURVEY_LEGS[index]]):
			return
		if index == 1:
			var route := _survey_route(game)
			var saved := game.save_interrupted_ember_journey()
			var reloaded := Store.new(COMPLETED_STORE_PATH, filesystem)
			var loaded := reloaded.load_read_only()
			_check(route.get("next_checkpoint_index") == 1 and not route.get("complete", true)
				and bool(saved.get("accepted", false))
				and saved.get("binding_reason") == &"active_journey_saved"
				and _beacon_receipts(store) == 0 and bool(loaded.get("accepted", false))
				and reloaded.get_snapshot() == store.get_snapshot()
				and reloaded.get_generation() == store.get_generation(),
				"the genuinely walked first relay saves an incomplete unpaid checkpoint that reloads through the actual serializer")
			if not _failures.is_empty():
				return
	for _settle in 12:
		await physics_frame
		await process_frame
	game.call(&"_retry_owed_game_flow_activity_rewards")
	game.call(&"_retry_owed_game_flow_activity_rewards")
	var paid := store.get_snapshot().get("ember_relay_survey_completion", {}) as Dictionary
	var completion := paid.get("completion", {}) as Dictionary
	var rewards := store.get_snapshot().get("game_flow_reward_store", {}) as Dictionary
	_check(_survey_route(game).get("complete", false) and _beacon_receipts(store) == 1
		and int(rewards.get("total_receipts", 0)) == 1
		and paid.get("payload_kind") == "ember_relay_survey_completion"
		and int(completion.get("activity_generation", -1)) == generation
		and completion.get("mandatory_route", {}).get("complete", false),
		"held walking earns and saves the original survey's one genuine beacon-data reward")
	game.save_interrupted_ember_journey()
	game.save_interrupted_ember_journey()
	game.call(&"_retry_owed_game_flow_activity_rewards")
	var reloaded := Store.new(COMPLETED_STORE_PATH, filesystem)
	var loaded := reloaded.load_read_only()
	_check(store.get_snapshot().get("ember_relay_survey_completion", {}) == paid
		and store.get_snapshot().get("game_flow_reward_store", {}) == rewards
		and bool(loaded.get("accepted", false))
		and reloaded.get_snapshot() == store.get_snapshot()
		and reloaded.get_generation() == store.get_generation(),
		"repeated production saves and reward retries preserve the paid terminal and serialized ledger")
	if not _failures.is_empty() or not await _walk_surface_legs(game, SURFACE_RETURN_LEGS):
		return
	_check(host.get_snapshot().get("surface_route", {}).get("return_complete", false),
		"the real reverse walk completes the Host's authored return route")
	var area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
	var nearby := await _walk_until(&"move_forward", func() -> bool:
		return area in player.get_nearby_interactables(), 120)
	_check(nearby and player.is_on_floor() and player.is_control_enabled(),
		"the returning surface pilot walks into the actual boarding interaction")
	if not nearby or not _failures.is_empty():
		return
	var sampler := LegSampler.new()
	sampler.start_physics_sampling(self, game, &"return", true)
	_physics_samplers.append(sampler)
	for _attempt in 12:
		await _press_live_action(&"interact", 1)
		for _settle in 6:
			await physics_frame
			await process_frame
		if host.get_phase() >= EmberSurfaceLoopHost.Phase.BOARDING:
			break
	var reboarded := await _wait_until(func() -> bool:
		return player.is_seated_at(craft.get_pilot_seat_anchor()) and craft.is_piloted() \
			and area.get_reservation_token() == player \
			and host.get_phase() >= EmberSurfaceLoopHost.Phase.REBOARDED \
			and host.get_phase() != EmberSurfaceLoopHost.Phase.FAILED, 10.0)
	_check(reboarded, "ordinary E reboards the completed survey pilot with a current real seat reservation")
	if not reboarded:
		return
	var started_frame := Engine.get_physics_frames()
	var ascent_frames := int(ceil(COMPLETED_ASCENT_SECONDS * float(Engine.physics_ticks_per_second)))
	var returning := false
	while Engine.get_physics_frames() - started_frame < ascent_frames:
		await physics_frame
		await process_frame
		sampler.step(game)
		var attachment := craft.get_planetary_cruise_attachment_report()
		returning = bool(game.get("_mudds_return_approach_active")) \
			and bool(game.planetary_cruise_binding.get_snapshot().get("engagement_requested", false)) \
			and StringName(attachment.get("state", &"inactive")) in [
				HeroShip.PLANETARY_CRUISE_STATE_ACCELERATING,
				HeroShip.PLANETARY_CRUISE_STATE_CRUISING]
		if returning or host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED \
				or craft.is_destroyed() or sampler.occupancy_failures > 0:
			break
	_check(returning, "Host physically takes off and completes its normal ascent into the genuine return cruise")
	if not returning:
		await sampler.stop_physics_sampling()
		return
	var completed := false
	var left_ember := false
	for tick in COMPLETED_RETURN_TICK_BUDGET:
		await physics_frame
		await process_frame
		sampler.step(game)
		left_ember = left_ember or not is_instance_valid(game.ember_streaming_bootstrap.get_loaded_instance())
		var result := game.get("_last_mudds_return_approach_result") as Dictionary
		if tick % 1200 == 0:
			print("RETURN tick=", tick, " home_distance=", craft.global_position.distance_to(game.world.get_ship_spawn().origin),
				" speed=", craft.velocity.length(), " rebases=", sampler.rebase_count,
				" cruise=", game.planetary_cruise_binding.get_snapshot().get("last_reason"), " result=", result.get("reason"))
		if result.get("reason") == &"return_approach_handed_to_station_lifecycle":
			completed = true
			break
		if craft.is_destroyed() or sampler.occupancy_failures > 0:
			break
	if not completed:
		await sampler.stop_physics_sampling()
	_check(completed and left_ember and sampler.rebase_count > 700
		and sampler.distance_flown_m > 7_800_000.0,
		"the paid expedition physically returns over 7,800 km, unloads Ember and enters the real home corridor")
	_check(sampler.max_ship_step_m <= TICK_STEP_LIMIT_M and sampler.max_player_step_m <= TICK_STEP_LIMIT_M
		and sampler.occupancy_failures == 0 and sampler.max_physics_frame_gap <= 1,
		"completed return preserves craft and seated pilot continuity without recovery placement")
	if completed:
		_check(await _fly_home_berth(game, sampler),
			"ordinary pilot controls physically dock at the home lease and leave a supported walking exit")
		var arrival := game.get("_last_planetary_return_physical_arrival_result") as Dictionary
		_check(bool(arrival.get("accepted", false)) and bool(game.get("_planetary_return_receipt_consumed")),
			"the actual home berth landing consumes the current production planetary return receipt")
	await sampler.stop_physics_sampling()
	var final_store := Store.new(COMPLETED_STORE_PATH, filesystem)
	var final_load := final_store.load_read_only()
	_check(_beacon_receipts(store) == 1
		and store.get_snapshot().get("ember_relay_survey_completion", {}) == paid
		and bool(final_load.get("accepted", false))
		and final_store.get_snapshot() == store.get_snapshot()
		and final_store.get_generation() == store.get_generation(),
		"the usable home exit retains exactly one earned reward and its paid terminal on disk")
	print("PHYSICAL_RETURN_RESULT completed=", completed, " ticks=", sampler.ticks,
		" rebases=", sampler.rebase_count, " distance=", sampler.distance_flown_m,
		" max_steps=", sampler.max_ship_step_m, "/", sampler.max_player_step_m,
		" physics_phase=", sampler.physics_phase, " physics_samples=", sampler.physics_samples,
		" max_frame_gap=", sampler.max_physics_frame_gap)


func _survey_route(game: GameFlow) -> Dictionary:
	var surface := game.ember_surface_loop_production_binding.get_planetary_surface_snapshot()
	return (surface.get("relay_survey", {}) as Dictionary).get("mandatory_route", {}) as Dictionary


func _beacon_receipts(store: UserDataStore) -> int:
	var rewards := store.get_snapshot().get("game_flow_reward_store", {}) as Dictionary
	return int((rewards.get("reward_counts", {}) as Dictionary).get("ember_beacon_data", 0))


func _walk_surface_legs(game: GameFlow, legs: Array) -> bool:
	var player := game.player as PlayerController
	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance() as Node3D
	if not is_instance_valid(loaded):
		_check(false, "the physical surface remains loaded while walking its route")
		return false
	var region := loaded.get_node(^"LandingRegion") as Node3D
	for leg: Array in legs:
		var axis := str(leg[0])
		var bound := float(leg[1])
		var greater := bool(leg[2])
		var initial := region.to_local(player.global_position)
		var initial_axis := initial.x if axis == "x" else initial.z
		var speed: float = player.walk_speed
		var hz := Engine.physics_ticks_per_second
		if not initial.is_finite() or not is_finite(bound) or not is_finite(speed) \
				or speed <= 0.0 or hz <= 0 or int(leg[4]) <= 0:
			_check(false, "surface walking requires a finite route and positive production speed and deadline")
			return false
		var distance := maxf(bound - initial_axis if greater else initial_axis - bound, 0.0)
		var allowance := int(ceil(distance / speed * float(hz))) + int(leg[4])
		var started := Engine.get_physics_frames()
		var reached := false
		Input.action_press(StringName(leg[3]))
		while Engine.get_physics_frames() - started <= allowance:
			var local := region.to_local(player.global_position)
			var value := local.x if axis == "x" else local.z
			if (value >= bound if greater else value <= bound):
				reached = true
				break
			if not player.is_control_enabled() or player.is_seated() or not host.is_attached() \
					or host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED \
					or Engine.get_physics_frames() - started == allowance:
				break
			await physics_frame
			await process_frame
		Input.action_release(StringName(leg[3]))
		for _settle in 4:
			await physics_frame
			await process_frame
		var supported := player.is_on_floor() and player.is_control_enabled() and not player.is_seated()
		_check(reached and supported and host.is_attached() and host.get_phase() != EmberSurfaceLoopHost.Phase.FAILED,
			"surface held action %s reaches %s=%s on supported ground (%s)" % [leg[3], axis, bound, region.to_local(player.global_position)])
		if not reached or not supported or not _failures.is_empty():
			return false
	return true


func _physical_abandon_return(game: GameFlow) -> void:
	var craft := game.active_ship as HeroShip
	var player := game.player as PlayerController
	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var on_foot := await _wait_until(func() -> bool:
		return host.get_phase() == EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND \
			and not player.is_seated() and player.is_control_enabled(), 30.0)
	_check(on_foot, "physical arrival disembarks the pilot before ABANDON")
	if not on_foot:
		return
	var abandon := game.abandon_ember_surface_journey(&"player_abandoned")
	_check(bool(abandon.get("accepted", false)), "the player ABANDON request remains pending for real reboarding and takeoff")
	var boarding := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	for tick in 900:
		if player.is_seated() and craft.is_piloted():
			break
		_release_all_actions()
		if player.is_seated():
			await physics_frame
			await process_frame
			continue
		if boarding in player.get_nearby_interactables():
			if tick % 12 == 0:
				await _press_live_action(&"interact", 2)
		else:
			var offset := craft.get_boarding_position() - player.global_position
			var right: Vector3 = player.call(&"_camera_relative_direction", Vector2.RIGHT)
			var forward: Vector3 = player.call(&"_camera_relative_direction", Vector2.UP)
			_set_signed_action(&"move_right", &"move_left", offset.normalized().dot(right))
			_set_signed_action(&"move_forward", &"move_back", offset.normalized().dot(forward))
		await physics_frame
		await process_frame
	_release_all_actions()
	_check(player.is_seated() and craft.is_piloted(), "the abandoned pilot reboards through the live boarding interaction")
	if not player.is_seated() or not craft.is_piloted():
		return
	var sampler := LegSampler.new()
	# Host owns takeoff through its surface-clear commit. The authored departure
	# then hands the pilot local flight; use ordinary thrust to clear the caldera
	# before releasing controls to the queued return. No placement occurs here.
	var departure_ready := false
	for _tick in 1800:
		await physics_frame
		await process_frame
		sampler.step(game)
		if int(host.get_abandon_snapshot().get("commit_count", 0)) > 0:
			departure_ready = true
			break
	_check(departure_ready, "Host physically clears the surface before handing off manual departure")
	if not departure_ready:
		return
	var surface_berth := game.ember_surface_berth as EmberSurfaceBerth
	var cleared_surface := false
	Input.action_press(&"move_forward")
	for _tick in 2400:
		await physics_frame
		await process_frame
		sampler.step(game)
		var altitude := (craft.global_position - surface_berth.global_position).dot(surface_berth.global_basis.y)
		if altitude >= 1200.0:
			cleared_surface = true
			break
		if craft.is_destroyed() or not craft.is_piloted():
			break
	Input.action_release(&"move_forward")
	_check(cleared_surface, "ordinary pilot thrust clears the local terrain before queued return cruise")
	if not cleared_surface:
		return
	var completed := false
	var left_ember := false
	for tick in 42_000:
		await physics_frame
		await process_frame
		sampler.step(game)
		left_ember = left_ember or not is_instance_valid(game.ember_streaming_bootstrap.get_loaded_instance())
		var result := game.get("_last_mudds_return_approach_result") as Dictionary
		if tick % 1200 == 0:
			print("RETURN tick=", tick, " home_distance=", craft.global_position.distance_to(game.world.get_ship_spawn().origin),
				" speed=", craft.velocity.length(), " rebases=", sampler.rebase_count,
				" cruise=", game.planetary_cruise_binding.get_snapshot().get("last_reason"), " result=", result.get("reason"))
		if result.get("reason") == &"abandoned_return_handed_to_station_lifecycle":
			completed = true
			break
		if craft.is_destroyed() or sampler.occupancy_failures > 0:
			break
	_check(completed and left_ember and sampler.rebase_count > 700,
		"ABANDON physically returns through origin rebases, unloads Ember and enters the typed home corridor")
	_check(sampler.max_ship_step_m <= TICK_STEP_LIMIT_M and sampler.max_player_step_m <= TICK_STEP_LIMIT_M
		and sampler.occupancy_failures == 0, "the return preserves ship and seated pilot continuity without recovery placement")
	if completed:
		_check(await _fly_home_berth(game, sampler),
			"ordinary pilot inputs finish the return at the actual home lease and leave a controllable disembarked pilot")
	print("PHYSICAL_RETURN_RESULT completed=", completed, " ticks=", sampler.ticks,
		" rebases=", sampler.rebase_count, " distance=", sampler.distance_flown_m,
		" max_steps=", sampler.max_ship_step_m, "/", sampler.max_player_step_m)


## A test pilot issues only the same held actions as a player. Cruise has already
## handed back authority; no transform, velocity, lease or completion is written.
func _fly_home_berth(game: GameFlow, sampler: LegSampler) -> bool:
	if sampler.physics_sampling:
		sampler.physics_phase = &"home"
	var craft := game.active_ship as HeroShip
	var player := game.player as PlayerController
	var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	var landing_requested := false
	var approach_leg := 0
	var docked := false
	var tick_budget := 3000 if OS.get_environment("KETH_RETURN_ARRIVAL_DIAGNOSTIC") == "1" else 48_000
	for tick in tick_budget:
		_release_flight_controls(craft)
		var report := game.call(&"_get_active_landing_assist_report") as Dictionary
		if not landing_requested and report.get("selected_berth_id") == craft.get_home_berth_id() \
				and bool(report.get("assist_capture_accepted", false)):
			Input.action_press(&"landing_assist")
			landing_requested = true
		elif not landing_requested:
			# Cross the yard above its walls, then descend from the open approach side.
			var waypoint := berth.get_dock_transform() * Vector3(0.0, 120.0, -200.0) \
				if approach_leg == 0 else berth.get_assist_capture_transform().origin
			var offset := waypoint - craft.global_position
			if approach_leg == 0 and offset.length() < 12.0 and craft.velocity.length() < 10.0:
				approach_leg = 1
			var local := craft.global_basis.inverse() * offset.normalized()
			var yaw := atan2(local.x, -local.z)
			var pitch := atan2(local.y, Vector2(local.x, local.z).length())
			_set_signed_action(&"move_right", &"move_left", yaw * 3.0)
			_set_signed_action(&"pitch_up", &"pitch_down", pitch * 3.0)
			var desired_up := berth.global_basis.y.normalized()
			var roll := atan2(desired_up.dot(craft.global_basis.x), desired_up.dot(craft.global_basis.y))
			_set_signed_action(&"roll_right", &"roll_left", roll * 3.0)
			var desired_speed := minf(craft.maximum_speed * 0.9,
				sqrt(maxf(0.0, offset.length() - 5.0) * craft.brake_acceleration) * 0.6)
			if absf(yaw) < 0.08 and absf(pitch) < 0.08 and craft.velocity.length() < desired_speed:
				Input.action_press(&"move_forward")
			else:
				Input.action_press(&"brake")
		await physics_frame
		await process_frame
		sampler.step(game)
		if tick % (120 if OS.get_environment("KETH_RETURN_ARRIVAL_DIAGNOSTIC") == "1" else 1200) == 0:
			print("BERTH_RETURN tick=", tick, " distance=", craft.global_position.distance_to(berth.get_dock_transform().origin),
				" speed=", craft.velocity.length(), " requested=", landing_requested, " phase=", game.phase,
				" local_target=", craft.global_basis.inverse() * (berth.get_assist_capture_transform().origin - craft.global_position),
				" report=", report.get("errors", []))
		if craft.is_destroyed():
			break
		if bool(craft.get_telemetry().get("landing_dock_accepted", false)) \
				and not craft.is_landing_active() and berth.get_occupant() == craft:
			docked = true
			break
		if landing_requested and not craft.is_landing_active() and not bool(craft.get_telemetry().get("landed", false)):
			landing_requested = false
	_release_all_actions()
	if sampler.physics_sampling:
		await sampler.stop_physics_sampling()
	var token := berth.get_reservation_token(craft)
	if not docked or token.is_empty() \
			or token != StringName((game.get("_berth_tokens") as Dictionary).get(craft.get_instance_id(), &"")):
		return false
	_check(sampler.max_ship_step_m <= TICK_STEP_LIMIT_M and sampler.max_player_step_m <= TICK_STEP_LIMIT_M
		and sampler.occupancy_failures == 0 and sampler.max_physics_frame_gap <= 1,
		"ordinary flight and physical berth landing preserve craft/pilot continuity and occupied seat until disembark")
	for tick in 900:
		if not player.is_seated() and player.is_control_enabled() and not bool(game.get("_transition_busy")):
			if craft.is_piloted() or player.global_position.distance_to(craft.get_boarding_position()) >= 20.0:
				return false
			var walk_start := player.global_position
			# Halyard exits facing inboard at the apron edge; walk along the apron,
			# since backing away crosses its deliberately open outboard gap.
			var walk_action: StringName = &"move_right" if craft.get_ship_id() == &"halyard_new_design" else &"move_back"
			await _press_live_action(walk_action, 20)
			var walk_distance := (player.global_position - walk_start).slide(player.up_direction).length()
			var supported_walk := walk_distance > 0.25 and walk_distance < 5.0 \
				and player.is_on_floor() and player.is_control_enabled()
			_check(supported_walk,
				"the disembarked pilot physically walks along supported home berth ground under held movement input")
			return supported_walk
		if tick % 30 == 0:
			await _press_live_action(&"interact", 2)
		await physics_frame
		await process_frame
	print("BERTH_EXIT_STALLED phase=", game.phase, " piloting=", game.get("_piloting"), " transition=", game.get("_transition_busy"), " seated=", player.is_seated(), " enabled=", player.is_control_enabled(), " telemetry=", craft.get_telemetry())
	return false


func _set_signed_action(positive: StringName, negative: StringName, strength: float) -> void:
	Input.action_release(positive)
	Input.action_release(negative)
	if absf(strength) > 0.005:
		Input.action_press(positive if strength > 0.0 else negative, minf(1.0, absf(strength)))


func _walk_and_board(
		game: GameFlow, player: PlayerController, craft: HeroShip, require_live_control: bool = false
	) -> bool:
	if require_live_control and (not player.is_control_enabled() or player.is_seated()
			or bool(game.get("_transition_busy"))):
		return false
	var boarding := craft.get_boarding_position()
	var up := craft.global_basis.y.normalized()
	var approach := craft.global_basis.x.normalized()
	# Initial on-foot placement only; failed locomotion never teleports into admission.
	player.teleport_to(Transform3D(
		Basis.looking_at(-approach, Vector3.UP), boarding + up * 0.05 + approach * 6.0
	))
	if not require_live_control:
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


## Sandbox boarding already sets FREE_FLIGHT; that phase cannot prove takeoff.
## Keep the original 240-observation departure cap. Arrow has an open port pad
## (9 m landing half-depth); 20 m horizontal travel plus 5 m altitude clears it.
## Only ordinary held inputs produce that departure and its real lease release.
func _launch_completed(game: GameFlow, craft: HeroShip) -> bool:
	var player := game.player as PlayerController
	var area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
	var berth := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	var dock := berth.get_dock_transform()
	var up := dock.basis.y.normalized()
	var start := craft.global_position
	var departed := false
	_release_flight_controls(craft)
	Input.action_press(&"hover")
	Input.action_press(&"move_forward")
	for _tick in DEPARTURE_TICK_BUDGET:
		await physics_frame
		await process_frame
		var telemetry := craft.get_telemetry()
		var offset := craft.global_position - dock.origin
		var pilot_current: bool = craft.is_piloted() and player.is_seated_at(craft.get_pilot_seat_anchor()) \
			and area.get_reservation_token() == player
		if craft.is_destroyed() or not pilot_current:
			break
		if not bool(telemetry.get("landed", true)):
			# After physical pad departure, climb through the real pitch control.
			# Hover would otherwise keep the original horizontal launch attitude.
			Input.action_release(&"hover")
			var climb_pitch := asin(clampf((-craft.global_basis.z.normalized()).dot(up), -1.0, 1.0))
			_set_signed_action(&"pitch_up", &"pitch_down", (deg_to_rad(25.0) - climb_pitch) * 3.0)
		departed = game.phase == GameFlow.Phase.FREE_FLIGHT \
			and str(telemetry.get("engine_state", "OFFLINE")).to_upper() == "ONLINE" \
			and not bool(telemetry.get("landed", true)) \
			and offset.dot(up) >= 5.0 and offset.slide(up).length() >= 20.0 \
			and craft.global_position.distance_to(start) >= 20.0 \
			and craft.velocity.length() > HeroShip.DEPARTURE_SPEED_THRESHOLD \
			and bool(game.get("_sortie_departed_berth")) and berth.get_occupant() != craft
		if departed:
			break
	_release_all_actions()
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	var final_offset := craft.global_position - dock.origin
	departed = departed and not craft.is_destroyed() and craft.is_piloted() \
		and player.is_seated_at(craft.get_pilot_seat_anchor()) and area.get_reservation_token() == player \
		and not bool(craft.get_telemetry().get("landed", true)) \
		and final_offset.dot(up) >= 5.0 and final_offset.slide(up).length() >= 20.0
	if not departed:
		print("OUTBOUND_STALLED launch=", {"position": craft.global_position,
			"offset_from_home_dock": craft.global_position - dock.origin,
			"motion_from_launch_start": craft.global_position.distance_to(start),
			"velocity": craft.velocity, "telemetry": craft.get_telemetry(),
			"yard_departure_recorded": game.get("_sortie_departed_berth"),
			"home_berth_still_occupied": berth.get_occupant() == craft})
	return departed


## The real Cinder hulk blocks a direct low-altitude turn toward Ember:
## anchor Y=26 plus its full authored radius of 54 m puts all hull/mast stock
## below Y=80. Keep the ordinary outward launch heading while pitching 60 degrees
## and thrusting above that sphere plus the actual full-hull radius and 5 metres.
## This distinct climb has 240 observations; launch and alignment retain 240 each.
func _clear_completed_departure_hulk(game: GameFlow, craft: HeroShip) -> bool:
	var player := game.player as PlayerController
	var area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
	var report := craft.get_landing_collision_report()
	var bounds := report.get("local_bounds", AABB()) as AABB
	if not bool(report.get("valid", false)) or not bounds.has_volume() \
			or not bounds.position.is_finite() or not bounds.size.is_finite():
		return false
	# The componentwise farthest corner encloses every enabled root hull shape
	# at ANY attitude, including the four cylinders on Arrow's turned tail.
	var farthest_corner := Vector3(maxf(absf(bounds.position.x), absf(bounds.end.x)),
		maxf(absf(bounds.position.y), absf(bounds.end.y)),
		maxf(absf(bounds.position.z), absf(bounds.end.z)))
	var hull_radius := farthest_corner.length()
	var clearance_y := AbandonedStationHulk.HULK_ANCHOR.y \
		+ AbandonedStationHulk.HULL_BOUNDING_RADIUS + hull_radius + 5.0
	var outward := (-craft.global_basis.z.normalized()).slide(Vector3.UP)
	if not outward.is_finite() or outward.length_squared() <= 0.0 \
			or not is_finite(clearance_y) or hull_radius <= 0.0:
		return false
	outward = outward.normalized()
	var direction := outward * cos(deg_to_rad(60.0)) + Vector3.UP * sin(deg_to_rad(60.0))
	var cleared := false
	for _tick in DEPARTURE_TICK_BUDGET:
		_release_flight_controls(craft)
		var pilot_current: bool = craft.is_piloted() and player.is_seated_at(craft.get_pilot_seat_anchor()) \
			and area.get_reservation_token() == player
		var telemetry := craft.get_telemetry()
		if not pilot_current or craft.is_destroyed() or game.phase != GameFlow.Phase.FREE_FLIGHT \
				or bool(telemetry.get("landed", true)) or not craft.global_position.is_finite() \
				or str(telemetry.get("engine_state", "OFFLINE")).to_upper() != "ONLINE":
			break
		var local := craft.global_basis.inverse() * direction
		var yaw := atan2(local.x, -local.z)
		var pitch := atan2(local.y, Vector2(local.x, local.z).length())
		_set_signed_action(&"move_right", &"move_left", yaw * 3.0)
		_set_signed_action(&"pitch_up", &"pitch_down", pitch * 3.0)
		Input.action_press(&"move_forward")
		await physics_frame
		await process_frame
		if craft.global_position.y >= clearance_y:
			cleared = true
			break
	_release_all_actions()
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	cleared = cleared and craft.global_position.y >= clearance_y and not craft.is_destroyed() \
		and game.phase == GameFlow.Phase.FREE_FLIGHT and craft.is_piloted() and player.is_seated_at(craft.get_pilot_seat_anchor()) \
		and area.get_reservation_token() == player and not bool(craft.get_telemetry().get("landed", true))
	if not cleared:
		print("OUTBOUND_STALLED departure_climb=", {"position": craft.global_position,
			"velocity": craft.velocity, "required_center_y": clearance_y, "hull_radius": hull_radius,
			"outward_direction": outward, "telemetry": craft.get_telemetry()})
	return cleared


## A separate bounded steering phase uses the existing 240-tick allowance.
## The actual policy chooses velocity at ANY nonzero speed, so brake naturally
## to zero while yawing/pitching; never replace momentum or attitude directly.
func _align_completed_outbound(game: GameFlow, craft: HeroShip) -> bool:
	var player := game.player as PlayerController
	var area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := game.planetary_cruise_binding.get_snapshot().get("canonical_destination_orbital", {}) as Dictionary
	var aligned := false
	var nose_alignment := -1.0
	var motion_alignment := -1.0
	for _tick in DEPARTURE_TICK_BUDGET:
		_release_flight_controls(craft)
		var decoded := frame.orbital_to_world_streaming_position(canonical, frame.get_generation())
		var target := decoded.get("position", Vector3.INF) as Vector3
		var offset := target - craft.global_position
		if not target.is_finite() or not offset.is_finite() or offset.length_squared() <= 0.0 \
				or craft.is_destroyed() or not craft.is_piloted() \
				or not player.is_seated_at(craft.get_pilot_seat_anchor()) \
				or area.get_reservation_token() != player or bool(craft.get_telemetry().get("landed", true)):
			break
		var direction := offset.normalized()
		var local := craft.global_basis.inverse() * direction
		var yaw := atan2(local.x, -local.z)
		var pitch := atan2(local.y, Vector2(local.x, local.z).length())
		_set_signed_action(&"move_right", &"move_left", yaw * 3.0)
		_set_signed_action(&"pitch_up", &"pitch_down", pitch * 3.0)
		Input.action_press(&"brake")
		await physics_frame
		await process_frame
		nose_alignment = (-craft.global_basis.z.normalized()).dot(direction)
		motion_alignment = craft.velocity.normalized().dot(direction) if craft.velocity.length() > 0.0 else nose_alignment
		aligned = nose_alignment >= PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT \
			and motion_alignment >= PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT
		if aligned:
			break
	_release_all_actions()
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	# Recheck after releasing the actual commands, before asking for admission.
	var decoded := frame.orbital_to_world_streaming_position(canonical, frame.get_generation())
	var target := decoded.get("position", Vector3.INF) as Vector3
	if target.is_finite() and (target - craft.global_position).length_squared() > 0.0:
		var direction := (target - craft.global_position).normalized()
		nose_alignment = (-craft.global_basis.z.normalized()).dot(direction)
		motion_alignment = craft.velocity.normalized().dot(direction) if craft.velocity.length() > 0.0 else nose_alignment
		aligned = aligned and nose_alignment >= PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT \
			and motion_alignment >= PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT
	else:
		aligned = false
	aligned = aligned and not craft.is_destroyed() and craft.is_piloted() \
		and player.is_seated_at(craft.get_pilot_seat_anchor()) and area.get_reservation_token() == player \
		and not bool(craft.get_telemetry().get("landed", true))
	if not aligned:
		print("OUTBOUND_STALLED alignment=", {"position": craft.global_position,
			"velocity": craft.velocity, "nose_alignment": nose_alignment,
			"motion_alignment": motion_alignment, "required_alignment": PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT})
	return aligned


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
	for sampler: LegSampler in _physics_samplers:
		await sampler.stop_physics_sampling()
	_physics_samplers.clear()
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
