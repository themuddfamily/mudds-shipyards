extends Node

## Opt-in release probe. It drives only the Main supplied by Boot, using the
## same accepted escort setup as the production regression. The arm leg first
## acquires a real Player seat; cold Resume must reacquire it at the disclosed
## safe home berth before the escort motion fixture runs. This does not qualify
## human flight acceptance, original flight-pose restoration or native GPU work.
const SLOT: StringName = &"cinder_convoy_session"

var stage := ""
var recovery_context := "pilot"
var activity := "convoy"
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
	if recovery_context == "engineer":
		await _run_engineer(game, store, entry)
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


func _load_beacon_binding(game: GameFlow, activity_label := "beacon") -> NearbySectorActivityBinding:
	game.cinder_streaming_bootstrap.update_position(CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR)
	var binding: NearbySectorActivityBinding
	for _frame in 180:
		binding = game.call("_get_nearby_activity_binding") as NearbySectorActivityBinding
		if is_instance_valid(binding):
			break
		await get_tree().process_frame
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
