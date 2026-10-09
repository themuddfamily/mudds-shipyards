extends SceneTree

## Unclean shutdown -> resume offer. A running marker left by a session that
## never reached mark_clean_shutdown makes the next start a recovery; the
## startup card then offers "Resume Last Save" (naming the save, including a
## fallback to a rotated copy) or "Start Fresh", each emitting its own intent.

const Coordinator := preload("res://scripts/diagnostics/crash_recovery_coordinator.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const InterruptionProbe := preload("res://scripts/diagnostics/in_world_interruption_probe.gd")

const STORE_PATH := "memory://resume_offer.json"

var _assertions := 0
var _failures := PackedStringArray()
var _requests: Array[StringName] = []


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var reject_writes := false
	var reject_rewards := false
	var write_attempts := 0

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		write_attempts += 1
		if reject_writes:
			return ERR_CANT_CREATE
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if reject_rewards and document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-"):
			return ERR_CANT_CREATE
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if "--solo-crew-only" in OS.get_cmdline_user_args():
		await _test_real_solo_crew_recovery()
		_finish()
		return
	var recovery_snapshot := _test_unclean_shutdown_is_detected_and_clean_quit_is_not()
	_test_save_summary_names_the_resumed_save()
	await _test_startup_card_offers_resume_or_start_fresh(recovery_snapshot)
	await _test_cold_solo_safe_recovery()
	await _test_cold_cabin_and_rest_recovery()
	await _test_cold_cabin_and_rest_recovery("BulwarkHeavyGunship", ["cabin"])
	await _test_real_file_landed_rest_recovery()
	await _test_real_solo_crew_recovery()
	_finish()


func _test_unclean_shutdown_is_detected_and_clean_quit_is_not() -> Dictionary:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem) as UserDataStore
	store.load()
	var first = Coordinator.new(store)
	first.restore()
	_check(first.begin_session(1, "resume-start-1").reason == &"started", "the first session writes its running marker at start")
	# The process dies here: no mark_clean_shutdown.
	var crashed_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	crashed_store.load()
	var second = Coordinator.new(crashed_store)
	second.restore()
	var interrupted: Dictionary = second.get_snapshot()
	var recovered: Dictionary = second.begin_session(2, "resume-start-2")
	_check(
		bool(recovered.accepted) and recovered.reason == &"recovered_previous_session" and bool(recovered.recovered),
		"the next start detects the unclean shutdown from the left-over marker"
	)
	_check(
		bool(second.mark_clean_shutdown(2, 10, 0.5, "resume-clean-2").accepted),
		"a clean quit clears the marker"
	)
	var clean_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	clean_store.load()
	var third = Coordinator.new(clean_store)
	third.restore()
	_check(third.begin_session(3, "resume-start-3").reason == &"started", "after a clean quit the next start is not treated as a crash")
	return interrupted


func _test_save_summary_names_the_resumed_save() -> void:
	var flow = GameFlowScript.new()
	flow.set("_runtime_settings_load_status", {
		"accepted": true, "reason": &"loaded", "store_reason": &"ok", "generation": 12,
		"store_status": {"reason": &"ok", "generation": 12},
	})
	_check(str(flow.get_session_recovery_save_summary()).contains("last good save (save 12)"), "a normal load names the save Resume continues from")
	flow.set("_runtime_settings_load_status", {
		"accepted": true, "reason": &"loaded", "store_reason": &"primary_invalid_backup_loaded", "generation": 11,
		"store_status": {"reason": &"primary_invalid_backup_loaded", "generation": 11},
	})
	_check(str(flow.get_session_recovery_save_summary()).contains("previous good save (save 11)"), "a damaged save names the backup Resume will use")
	flow.set("_runtime_settings_load_status", {
		"accepted": true, "reason": &"loaded", "store_reason": &"primary_invalid_backup_loaded", "generation": 9,
		"store_status": {
			"reason": &"primary_invalid_backup_loaded", "generation": 9,
			"fallback": &"rotated_history", "history_index": 2,
		},
	})
	_check(str(flow.get_session_recovery_save_summary()).contains("rotated copy 2"), "a damaged save and backup name the rotated copy Resume will use")
	flow.free()


func _test_startup_card_offers_resume_or_start_fresh(interrupted: Dictionary) -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.session_recovery_continue_requested.connect(func(_t: int, _g: int) -> void: _requests.append(&"resume"))
	hud.session_recovery_discard_requested.connect(func(_t: int, _g: int) -> void: _requests.append(&"start_fresh"))
	hud.set_session_recovery_save_summary("Resume continues from your last good save (save 12).")
	var recovery := {
		"schema_version": 1,
		"state": "running",
		"session_id": maxi(1, int(interrupted.get("session_id", 1))),
		"startup_generation": maxi(1, int(interrupted.get("startup_generation", 1))),
		"unclean_start_count": 1,
		"last_physics_tick": 0,
		"last_elapsed_physics_seconds": 0.0,
	}
	var recommendation := {
		"available": true,
		"requires_caller_choice": true,
		"severity": &"review_prior_session",
		"choices": [&"normal_start", &"safe_graphics_windowed", &"discard"],
		"safe_start_patch": {},
		"applies_settings": false,
		"persists_settings": false,
	}
	var presented := hud.present_session_recovery_notice(recovery, recommendation)
	_check(bool(presented.accepted), "the interrupted-session card is presented")
	var detail := hud.get("_recovery_prompt_detail") as Label
	var actions := hud.get("_recovery_prompt_actions") as HBoxContainer
	_check(detail.text.contains("last good save (save 12)"), "the card names the save that Resume keeps")
	var resume := actions.get_child(1) as Button
	var fresh := actions.get_child(2) as Button
	_check(resume.text == "Resume Last Save" and fresh.text == "Start Fresh", "the card offers Resume Last Save and Start Fresh")
	fresh.pressed.emit()
	_check(_requests.size() == 1 and _requests[0] == &"start_fresh", "Start Fresh emits its own intent and latches the choice")
	resume.pressed.emit()
	_check(_requests.size() == 1, "a second choice after the latch is ignored")
	hud.queue_free()
	await process_frame


func _make_game(filesystem: FakeFilesystem) -> GameFlow:
	return await _make_game_with_store(Store.new(STORE_PATH, filesystem) as UserDataStore)


func _make_game_with_store(store: UserDataStore) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game.configure_runtime_settings_persistence(store), "Main uses the existing isolated shared store")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.disembarking_motion_time = 0.02
	game.set_physics_process(false)
	return game


func _wait_for_seat(game: GameFlow, craft: HeroShip) -> bool:
	for _frame in 120:
		if game.phase == GameFlow.Phase.START_ENGINES:
			return game.player.is_seated_at(craft.get_pilot_seat_anchor()) and craft.is_piloted()
		await physics_frame
	return false


func _retire_game(game: GameFlow) -> void:
	game.queue_free()
	for _frame in 3:
		await process_frame


func _canonical(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _test_cold_solo_safe_recovery() -> void:
	var filesystem := FakeFilesystem.new()
	var original := await _make_game(filesystem)
	var craft := original.get_flyable_ships()[1] as HeroShip
	original.start_shift()
	original.call("_on_settings_save_requested")
	var store := original.get("_runtime_settings_user_data_store") as UserDataStore
	var original_files := filesystem.files.duplicate(true)
	var original_generation := store.get_generation()
	filesystem.reject_writes = true
	original.call("_board_ship", craft)
	_check(await _wait_for_seat(original, craft), "the original solo craft has a real settled Player seat")
	_check(filesystem.files == original_files and store.get_generation() == original_generation and craft.is_piloted() and original.player.is_seated_at(craft.get_pilot_seat_anchor()), "a rejected context save preserves disk generation and the real live seat owners")
	var attempted_writes := filesystem.write_attempts
	for _tick in 20:
		original.call("_advance_session_diagnostics_physics", 0.01)
	_check(filesystem.write_attempts == attempted_writes, "rejected writes do not retry at every physics tick")
	filesystem.reject_writes = false
	original.call("_advance_session_diagnostics_physics", GameFlowScript.SESSION_DIAGNOSTICS_RETRY_DELAY_SECONDS)
	var context: Dictionary = store.get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT]
	_check(context.mode == "pilot" and context.craft_id == String(craft.get_ship_id()), "settled boarding durably saves only the registered craft and safe pilot mode")
	# Existing escort fixture supplies a mission boundary, not the recovery seat.
	_check(bool(original.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT).accepted), "a convoy can own the interrupted saved activity")
	await InterruptionProbe.prepare_convoy(original, 1)
	_check(bool(original.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID).accepted), "the interrupted convoy starts through its existing director")
	_check(bool(original.save_cinder_convoy_session().accepted), "the existing activity persists independently of safe-return context")
	var activity_boundary: Variant = _canonical(store.get_snapshot()["cinder_convoy_session"])
	var reward_boundary: Variant = _canonical(original.get_activity_reward_report().get("authority", {}).get("record", {}))
	await _retire_game(original)
	var cold := await _make_game(filesystem)
	var recovered_craft := cold.get_flyable_ships()[1] as HeroShip
	var cold_store := cold.get("_runtime_settings_user_data_store") as UserDataStore
	var pending := cold.get_recovery_available_snapshot()
	_check(not pending.is_empty() and not cold.player.is_seated(), "fresh Main offers recovery without replaying old seat identities")
	_check(cold.get_session_recovery_save_summary().contains(recovered_craft.get_display_name()) and cold.get_session_recovery_save_summary().contains("previous flight position is not restored"), "Resume discloses named home-berth safe recovery before acceptance")
	var rejected: Dictionary = cold.call("_handle_hud_session_recovery_choice", &"normal_start", int(pending.session_id), int(pending.startup_generation) + 1)
	_check(not bool(rejected.accepted) and not bool(cold.get("_solo_safe_recovery_pending")) and not cold.player.is_seated(), "a stale Resume fence cannot stage or acquire a seat")
	var accepted: Dictionary = cold.call("_handle_hud_session_recovery_choice", &"normal_start", int(pending.session_id), int(pending.startup_generation))
	_check(bool(accepted.accepted) and not cold.player.is_seated(), "accepted Resume stages safe recovery until the player begins the shift")
	cold.start_shift()
	_check(await _wait_for_seat(cold, recovered_craft), "cold Resume reacquires the real saved craft seat through ordinary boarding")
	var area := recovered_craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var berth := cold.world.get_berth_node(recovered_craft.get_home_berth_id()) as ShipBerth
	_check(area.get_reservation_token() == cold.player and berth.get_occupant() == recovered_craft and berth.get_reservation_owner() == recovered_craft, "recovery uses a fresh exclusive Player reservation and the existing occupied home berth")
	_check(_canonical(cold_store.get_snapshot()["cinder_convoy_session"]) == activity_boundary and cold.get_active_activity_snapshot().state_id == &"active", "safe boarding preserves the exact saved active convoy boundary")
	_check(_canonical(cold.get_activity_reward_report().get("authority", {}).get("record", {})) == reward_boundary, "safe recovery neither grants nor resets reward authority")
	var retained_player := cold.player
	var retained_anchor := recovered_craft.get_pilot_seat_anchor()
	root.remove_child(cold)
	await process_frame
	root.add_child(cold)
	for _frame in 3:
		await process_frame
	cold.set_physics_process(false)
	_check(cold.player == retained_player and cold.player.is_seated_at(retained_anchor) and area.get_reservation_token() == retained_player and recovered_craft.is_piloted(), "retained Main reentry keeps its same Player seat and reservation identities")
	Input.action_press(&"move_forward")
	await physics_frame
	await physics_frame
	Input.action_release(&"move_forward")
	_check(str(recovered_craft.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE" and recovered_craft.get_last_ship_command().throttle > 0.0, "the recovered real pilot can submit an ordinary flight control")
	filesystem.reject_rewards = true
	await InterruptionProbe.prepare_convoy(cold, 1)
	_check(await InterruptionProbe.finish_convoy(cold, recovered_craft), "the actual recovered convoy reaches its terminal owner with a rejected reward write")
	var owed: Dictionary = cold_store.get_snapshot()["cinder_convoy_session"].activities[0]
	_check(owed.reward_requested and not owed.reward_granted, "the terminal convoy retains genuine owed payment")
	activity_boundary = _canonical(cold_store.get_snapshot()["cinder_convoy_session"])
	await _retire_game(cold)
	var terminal := await _make_game(filesystem)
	var terminal_craft := terminal.get_flyable_ships()[1] as HeroShip
	var terminal_recovery := terminal.get_recovery_available_snapshot()
	terminal.call("_handle_hud_session_recovery_choice", &"normal_start", int(terminal_recovery.session_id), int(terminal_recovery.startup_generation))
	terminal.start_shift()
	_check(await _wait_for_seat(terminal, terminal_craft), "cold safe recovery also boards the real pilot with terminal payment owed")
	var terminal_store := terminal.get("_runtime_settings_user_data_store") as UserDataStore
	_check(terminal.get_active_activity_snapshot().state_id == &"completed" and _canonical(terminal_store.get_snapshot()["cinder_convoy_session"]) == activity_boundary, "safe recovery never resets the unpaid terminal owner or acknowledgement fields")
	filesystem.reject_rewards = false
	terminal.call("_retry_owed_game_flow_activity_rewards")
	var paid_record: Variant = _canonical(terminal.get_activity_reward_report().get("authority", {}).get("record", {}))
	terminal.call("_retry_owed_game_flow_activity_rewards")
	_check(bool(terminal_store.get_snapshot()["cinder_convoy_session"].activities[0].reward_granted) and _canonical(terminal.get_activity_reward_report().get("authority", {}).get("record", {})) == paid_record, "ordinary owed retry acknowledges payment once after safe recovery")
	activity_boundary = _canonical(terminal_store.get_snapshot()["cinder_convoy_session"])
	terminal.call("_disembark_ship_to_exterior", terminal_craft)
	for _frame in 120:
		if not bool(terminal.get("_transition_busy")) and not terminal.player.is_seated():
			break
		await physics_frame
	for _frame in 12:
		await physics_frame
	terminal.call("_capture_solo_safe_recovery_context")
	_check(terminal.player.is_on_floor() and terminal_store.get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT].mode == "on_foot", "real disembark saves settled supported on-foot mode")
	await _retire_game(terminal)
	var on_foot := await _make_game(filesystem)
	var foot_recovery := on_foot.get_recovery_available_snapshot()
	_check(on_foot.get_session_recovery_save_summary().contains("on foot beside"), "the on-foot offer discloses the saved craft's supported home-berth location")
	on_foot.call("_handle_hud_session_recovery_choice", &"normal_start", int(foot_recovery.session_id), int(foot_recovery.startup_generation))
	on_foot.start_shift()
	for _frame in 12:
		await physics_frame
	on_foot.call("_capture_solo_safe_recovery_context")
	var foot_context: Dictionary = (on_foot.get("_runtime_settings_user_data_store") as UserDataStore).get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT]
	_check(not on_foot.player.is_seated() and on_foot.player.is_on_floor() and on_foot.player.is_control_enabled() and foot_context.craft_id == context.craft_id, "cold on-foot recovery is supported and preserves the last craft preference rather than replacing it with Torrent")
	await _retire_game(on_foot)
	# Corrupt or transient context cannot move or seat the fresh Player; the
	# independent mission slot must still remain intact.
	var cases := [
		{"context": {"mode": "unavailable"}, "guard": ""},
		{"context": {"location": "mudds_home_berth", "mode": "pilot", "craft_id": "unknown_craft", "berth_id": "central"}, "guard": ""},
		{"context": context, "guard": "planetary"},
		{"context": context, "guard": "network"},
	]
	for test_case: Dictionary in cases:
		var edit_store := Store.new(STORE_PATH, filesystem) as UserDataStore
		edit_store.load()
		var payload := edit_store.get_snapshot()
		payload[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT] = test_case.context
		_check(bool(edit_store.commit(payload, edit_store.get_generation(), "invalid-safe-context-%d" % (edit_store.get_generation() + 1)).accepted), "the corrupt-context fixture retains the existing document envelope")
		var fallback := await _make_game(filesystem)
		if test_case.guard == "planetary":
			# Guard fixture represents the existing journey's surface ownership;
			# it does not grant a visit or qualify a planet transition.
			fallback.get("_planetary_journey").set("_ember_surface_journey_active", true)
		elif test_case.guard == "network":
			_check(bool(fallback.host_network_session(28479).get("accepted", false)), "the network fallback fixture establishes a real production host session")
		var fallback_recovery := fallback.get_recovery_available_snapshot()
		fallback.call("_handle_hud_session_recovery_choice", &"normal_start", int(fallback_recovery.session_id), int(fallback_recovery.startup_generation))
		fallback.start_shift()
		for _frame in 12:
			await physics_frame
		_check(not fallback.player.is_seated() and fallback.player.is_control_enabled() and fallback.player.is_on_floor(), "invalid, transient, planetary or network context falls back to a supported controllable station Player")
		_check(_canonical((fallback.get("_runtime_settings_user_data_store") as UserDataStore).get_snapshot()["cinder_convoy_session"]) == activity_boundary, "fallback preserves the independent activity and its debt fields")
		if test_case.guard == "planetary":
			fallback.get("_planetary_journey").set("_ember_surface_journey_active", false)
		await _retire_game(fallback)


func _settle_frames(count: int = 12) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _test_cold_cabin_and_rest_recovery(craft_name: String = "HalyardCrewTransport", modes: Array = ["cabin", "rest", "crew"]) -> void:
	var filesystem := FakeFilesystem.new()
	filesystem.reject_rewards = true
	var original := await _make_game(filesystem)
	var craft := original.get_node(craft_name) as HeroShip
	original.start_shift()
	original.call("_board_ship", craft)
	_check(await _wait_for_seat(original, craft), "cabin interruption begins with an ordinary settled saved-craft pilot")
	_check(bool(original.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT).accepted), "the cabin fixture selects the existing convoy owner")
	await InterruptionProbe.prepare_convoy(original, original.get_flyable_ships().find(craft))
	_check(bool(original.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID).accepted), "the cabin fixture starts its actual convoy")
	_check(await InterruptionProbe.finish_convoy(original, craft), "the cabin fixture reaches a real terminal convoy with reward write rejected")
	var store := original.get("_runtime_settings_user_data_store") as UserDataStore
	var activity_boundary: Variant = _canonical(store.get_snapshot()["cinder_convoy_session"])
	var reward_boundary: Variant = _canonical(original.get_activity_reward_report().get("authority", {}).get("record", {}))
	_check(store.get_snapshot()["cinder_convoy_session"].activities[0].reward_requested and not store.get_snapshot()["cinder_convoy_session"].activities[0].reward_granted, "the interrupted cabin carries real owed payment")
	Input.action_press(&"hover")
	Input.action_press(&"move_forward")
	await _settle_frames(6)
	Input.action_release(&"move_forward")
	Input.action_release(&"hover")
	await _settle_frames(int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 3)
	_check(not bool(craft.get_telemetry().get("landed", true)) and craft.global_position.distance_to(original.world.get_berth_transform(craft.get_home_berth_id()).origin) > 100.0, "the interrupted craft really is airborne and away from its home berth")
	original.call("_leave_seat_into_cabin")
	await _settle_frames()
	_check(original.player.is_on_floor() and original.get_in_flight_cabin_status().carried and not craft.is_piloted(), "production seat exit creates a real supported cabin passenger")
	if craft is HalyardCrewTransport:
		var airborne_bunk := craft.get_node("WalkableInterior/AftSystemsBay/PortSleepingBerth/ShipBunkInteraction") as ShipBunk
		original.player.teleport_to(airborne_bunk.get_exit_transform())
		await _settle_frames()
		original.call("_sit_in_station_seat", airborne_bunk)
		await _settle_frames()
		original.call("_capture_solo_safe_recovery_context")
		_check(original.player.is_sleeping() and airborne_bunk.is_reserved_for(original.player) and not bool(craft.get_telemetry().get("landed", true)) and store.get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT].get("mode") == "rest", "a real airborne ShipBunk captures rest through its live owner without flight coordinates")
		original.call("_on_interact_requested")
		await _settle_frames()
		_check(not original.player.is_sleeping() and original.player.is_control_enabled() and original.player.is_on_floor() and airborne_bunk.is_available() and original.get_in_flight_cabin_status().carried, "ordinary wake returns the airborne sleeper to the supported controllable cabin")
	for mode in modes:
		if mode == "rest":
			var bunk := craft.get_node("WalkableInterior/AftSystemsBay/PortSleepingBerth/ShipBunkInteraction") as ShipBunk
			original.player.teleport_to(bunk.get_exit_transform())
			await _settle_frames()
			original.call("_sit_in_station_seat", bunk)
			await _settle_frames()
			_check(original.player.is_sleeping() and original.player.is_seated_at(bunk.get_seat_anchor()) and bunk.is_reserved_for(original.player) and not craft.is_piloted(), "real reserved ShipBunk rest never grants pilot authority")
		if mode == "crew":
			var crew_seat := craft.find_child("SoloPassengerSeatInteraction", true, false) as ShipCrewSeat
			original.player.teleport_to(crew_seat.get_entry_transform())
			await _settle_frames()
			await _press_crew_interaction()
			_check(original.player.is_seated_at(crew_seat.get_seat_anchor()) and not craft.is_piloted(), "owed terminal activity admits the actual passenger through ordinary E without a helm claim")
		original.call("_capture_solo_safe_recovery_context")
		var context: Dictionary = store.get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT]
		_check(context.get("mode") == mode and context.get("craft_id") == String(craft.get_ship_id()) and context.size() == 4, "settled %s durably saves only safe mode and saved craft/home berth" % mode)
		var old_player_id := original.player.get_instance_id()
		var old_craft_id := craft.get_instance_id()
		await _retire_game(original)
		var cold := await _make_game(filesystem)
		craft = cold.get_node(craft_name) as HeroShip
		store = cold.get("_runtime_settings_user_data_store") as UserDataStore
		var pending := cold.get_recovery_available_snapshot()
		var summary := cold.get_session_recovery_save_summary()
		_check(summary.contains(craft.get_display_name()) and summary.contains("awake") and summary.contains("home berth") and summary.contains("pilot seat"), "the %s offer names an awake home-cabin recovery without pilot control" % mode)
		var rejected: Dictionary = cold.call("_handle_hud_session_recovery_choice", &"normal_start", int(pending.session_id), int(pending.startup_generation) + 1)
		_check(not rejected.accepted and not bool(cold.get("_solo_safe_recovery_pending")) and not cold.player.is_cabin_containment_active(), "stale %s Resume cannot stage cabin ownership" % mode)
		var accepted: Dictionary = cold.call("_handle_hud_session_recovery_choice", &"normal_start", int(pending.session_id), int(pending.startup_generation))
		_check(accepted.accepted and not cold.player.is_cabin_containment_active(), "accepted %s Resume waits for BEGIN SHIFT" % mode)
		cold.start_shift()
		await _settle_frames()
		var frame := craft.call("get_moving_interior_component") as MovingInteriorFrame
		var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
		var berth := cold.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
		_check(cold.phase == GameFlow.Phase.IN_FLIGHT_CABIN and cold.active_ship == craft and not craft.is_piloted() and not cold.player.is_seated() and not cold.player.is_sleeping() and cold.player.is_control_enabled() and cold.player.is_on_floor(), "cold %s Resume wakes a supported controllable saved-craft passenger" % mode)
		_check(frame.is_occupant_registered(cold.player) and cold.player.is_cabin_containment_active() and area.get_reservation_token() == cold.player and berth.get_occupant() == craft and berth.get_reservation_owner() == craft and cold.player.get_instance_id() != old_player_id and craft.get_instance_id() != old_craft_id, "cold %s recovery acquires fresh exclusive cabin/hatch owners and exact home berth" % mode)
		_check(_canonical(store.get_snapshot()["cinder_convoy_session"]) == activity_boundary and _canonical(cold.get_activity_reward_report().get("authority", {}).get("record", {})) == reward_boundary, "cold %s recovery preserves terminal activity and unpaid reward exactly" % mode)
		var start := cold.player.global_position
		var walk_action := &"move_forward" if craft is BulwarkHeavyGunship else &"move_back"
		Input.action_press(walk_action)
		await _settle_frames(20)
		Input.action_release(walk_action)
		await _settle_frames()
		_check(cold.player.global_position.distance_to(start) > 0.1 and cold.player.is_on_floor() and not craft.is_piloted(), "the recovered %s passenger can walk the actual cabin floor without piloting" % mode)
		var retained_player := cold.player
		root.remove_child(cold)
		await process_frame
		root.add_child(cold)
		await _settle_frames()
		cold.set_physics_process(false)
		_check(cold.player == retained_player and frame.is_occupant_registered(retained_player) and not area.is_reserved() and not craft.is_piloted(), "retained %s Main keeps its same cabin Player and existing detached-hatch release policy" % mode)
		original = cold
	# Ordinary retaking of the physical seat remains the explicit pilot grant.
	original.player.teleport_to(craft.get_cabin_stand_transform())
	await _settle_frames()
	Input.action_press(&"move_forward")
	await _settle_frames(24)
	Input.action_release(&"move_forward")
	await _settle_frames()
	await _press_crew_interaction()
	_check(await _wait_for_seat(original, craft) and not original.player.is_cabin_containment_active() and not (craft.call("get_moving_interior_component") as MovingInteriorFrame).is_occupant_registered(original.player), "ordinary cabin interaction retakes pilot control and releases passenger containment")
	original.call("_try_exit_ship")
	await _settle_frames(120)
	_check(original.phase == GameFlow.Phase.APPROACH_SHIP and original.player.is_on_floor() and original.player.is_control_enabled() and not original.player.is_seated() and not craft.is_piloted(), "the recovered passenger can leave through the ordinary landed pilot exit onto the shipyard deck")
	_check(_canonical(store.get_snapshot()["cinder_convoy_session"]) == activity_boundary, "ordinary recovered cabin retake and deck exit preserve the exact unpaid terminal boundary")
	filesystem.reject_rewards = false
	original.call("_retry_owed_game_flow_activity_rewards")
	var paid: Variant = _canonical(original.get_activity_reward_report().get("authority", {}).get("record", {}))
	original.call("_retry_owed_game_flow_activity_rewards")
	_check(bool(store.get_snapshot()["cinder_convoy_session"].activities[0].reward_granted) and _canonical(original.get_activity_reward_report().get("authority", {}).get("record", {})) == paid, "the recovered cabin's actual owed reward still saves exactly once after ordinary exit")
	await _retire_game(original)


## The write-fault cases above use a shared fake disk. This path uses the actual
## production filesystem and reloads a private user-data file into a fresh Main.
func _test_real_file_landed_rest_recovery() -> void:
	var path := "user://solo-cabin-recovery-%d.json" % OS.get_process_id()
	var store := Store.new(path) as UserDataStore
	var game := await _make_game_with_store(store)
	var craft := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var bunk := craft.get_node("WalkableInterior/AftSystemsBay/PortSleepingBerth/ShipBunkInteraction") as ShipBunk
	game.start_shift()
	game.player.teleport_to(bunk.get_exit_transform())
	await _settle_frames()
	game.call("_capture_solo_safe_recovery_context")
	_check(store.get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT].get("mode") == "cabin" and store.get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT].get("craft_id") == String(craft.get_ship_id()), "landed frame-owned cabin walk saves the actual Halyard rather than Main's default Torrent")
	game.call("_sit_in_station_seat", bunk)
	await _settle_frames()
	game.call("_capture_solo_safe_recovery_context")
	_check(game.player.is_sleeping() and game.active_ship != craft and store.get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT].get("mode") == "rest" and store.get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT].get("craft_id") == String(craft.get_ship_id()) and FileAccess.file_exists(path), "landed reserved ShipBunk persists its own craft to a real private user file")
	await _retire_game(game)
	var cold := await _make_game_with_store(Store.new(path) as UserDataStore)
	var cold_craft := cold.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var pending := cold.get_recovery_available_snapshot()
	_test_cabin_owner_refusals(cold, cold_craft)
	_check(not pending.is_empty() and cold.get_session_recovery_save_summary().contains(cold_craft.get_display_name()), "fresh Main reloads the actual file and offers its saved bunk craft")
	cold.call("_handle_hud_session_recovery_choice", &"normal_start", int(pending.session_id), int(pending.startup_generation))
	cold.start_shift()
	await _settle_frames()
	_check(cold.active_ship == cold_craft and cold.player.is_on_floor() and cold.player.is_control_enabled() and not cold.player.is_sleeping() and not cold_craft.is_piloted() and cold_craft.get_moving_interior_component().is_occupant_registered(cold.player), "real-file cold Resume wakes onto a usable supported saved-craft cabin")
	await _retire_game(cold)
	for suffix in ["", ".bak", ".tmp", ".bak.1", ".bak.2", ".bak.3"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _test_cabin_owner_refusals(game: GameFlow, craft: HeroShip) -> void:
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var other := Node.new()
	game.add_child(other)
	var pose := game.player.global_transform
	var context: Dictionary = game.get("_solo_safe_recovery_context").duplicate(true)
	_check(area.try_reserve(other), "the occupied-cabin fixture owns a real competing hatch reservation")
	game.set("_solo_safe_recovery_pending", true)
	game.call("_apply_solo_safe_recovery")
	_check(game.player.global_transform.is_equal_approx(pose) and game.active_ship != craft and not game.player.is_cabin_containment_active() and area.get_reservation_token() == other, "cabin recovery refuses a reserved hatch without moving the Player or stealing its owner")
	area.release_reservation(other)
	other.queue_free()
	# Withdraw the actual authored body shapes. A supported report alone must
	# never substitute for real floor support at the standing route.
	var body_layers: Dictionary = {}
	body_layers[craft] = craft.collision_layer
	craft.collision_layer = 0
	for body in craft.find_children("*", "PhysicsBody3D", true, false):
		body_layers[body] = body.collision_layer
		body.collision_layer = 0
	game.set("_solo_safe_recovery_pending", true)
	game.call("_apply_solo_safe_recovery")
	_check(game.player.global_transform.is_equal_approx(pose) and game.active_ship != craft and not game.player.is_cabin_containment_active() and not area.is_reserved(), "cabin recovery refuses an unsupported standing route without an orphan hatch claim")
	for body: PhysicsBody3D in body_layers:
		body.collision_layer = int(body_layers[body])
	_check(game.get("_solo_safe_recovery_context") == context, "both refusals preserve the durable cabin preference for the next explicit Resume")


func _press_crew_interaction() -> void:
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	await _settle_frames()


func _test_real_solo_crew_recovery() -> void:
	var path := "user://solo-crew-recovery-%d.json" % OS.get_process_id()
	var store := Store.new(path) as UserDataStore
	var game := await _make_game_with_store(store)
	var craft := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var seat := craft.find_child("SoloPassengerSeatInteraction", true, false) as Area3D
	_check(seat != null, "Main authors a reachable Halyard passenger interaction at the existing crew_port_00 chair")
	if seat == null:
		await _retire_game(game)
		return
	game.start_shift()
	game.set_physics_process(true)
	var entry: Transform3D = seat.call("get_entry_transform")
	game.player.teleport_to(entry)
	await _settle_frames()
	_check(game.station_interaction_candidate == seat and (game.hud.get("_interaction_label") as Label).text.contains("PASSENGER"), "ordinary facing and overlap discover the physical passenger chair and its visible prompt")
	var contract := (seat as ShipCrewSeat).get_role_contract()
	_check(contract.get("seat") == craft.get_loadmaster_station_anchor() and contract.get("frame") == craft.get_moving_interior_component() and contract.get("vessel_id") == craft.get_ship_id() and contract.get("seat_id") == &"crew_port_00" and contract.get("role") == &"passenger" and contract.get("entry_transform") == entry and contract.get("exit_transform") == entry, "ordinary Halyard chair publishes its original live craft, role, frame and entry/exit poses")
	var anchor := craft.get_loadmaster_station_anchor()
	var anchor_parent := anchor.get_parent()
	anchor.reparent(game, true)
	_check((seat as ShipCrewSeat).get_role_contract().is_empty() and not game.player.is_seated() and craft.get_crew_role_authority() == null, "chair discovery refuses an anchor that left its craft hierarchy before granting any crew claim")
	anchor.reparent(anchor_parent, true)
	await _settle_frames()
	var foreign := CrewSeatRoleAuthority.new(1)
	foreign.register_halyard_roster()
	foreign.claim(1, 2, &"other_passenger", &"crew_port_00", &"passenger", 1)
	craft.attach_crew_role_authority(foreign)
	var foreign_snapshot: Variant = _canonical(foreign.get_snapshot())
	await _press_crew_interaction()
	_check(not game.player.is_seated() and craft.get_crew_role_authority() == foreign and _canonical(foreign.get_snapshot()) == foreign_snapshot and game.player.is_on_floor(), "ordinary E refuses a competing foreign passenger roster without changing its exact claims")
	foreign.release(1, 2, &"other_passenger", &"crew_port_00", 2)
	craft.detach_crew_role_authority(foreign)
	var other_frame_root := Node3D.new()
	game.add_child(other_frame_root)
	var other_frame := MovingInteriorFrame.new()
	other_frame.auto_register_from_volume = false
	other_frame.require_inside_bounds_on_register = false
	other_frame_root.add_child(other_frame)
	craft.get_moving_interior_component().unregister_occupant(game.player)
	var other_registered := other_frame.register_occupant(game.player)
	await _press_crew_interaction()
	_check(bool(other_registered.get("registered", false)) and other_frame.is_occupant_registered(game.player) and craft.get_crew_role_authority() == null and not game.player.is_seated(), "ordinary chair admission refuses an independently registered Player without stealing its frame or creating a local claim")
	other_frame.unregister_occupant(game.player)
	other_frame_root.queue_free()
	await _settle_frames()
	game.boarding_motion_time = 0.3
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	game.call("_capture_solo_safe_recovery_context")
	_check(bool(game.get("_transition_busy")) and store.get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT].get("mode") == "unavailable", "live passenger acquisition records unavailable until the actual Player reaches its assigned chair")
	await _settle_frames(40)
	game.boarding_motion_time = 0.02
	var authority := craft.get_crew_role_authority()
	var status: Dictionary = game.call("get_solo_crew_seat_status")
	_check(game.player.is_seated_at(craft.get_loadmaster_station_anchor()) and game.player.is_station_seated() and not game.player.is_sleeping() and not craft.is_piloted() and status.get("seated", false) and authority != null, "real E sits the actual Player at the authored passenger anchor without helm or sleep authority")
	if authority == null:
		await _retire_game(game)
		return
	var assignment: Dictionary = status.assignment
	_check(assignment.get("role") == &"passenger" and assignment.get("seat_id") == &"crew_port_00" and craft.get_moving_interior_component().is_occupant_registered(game.player), "the sole existing role ledger and moving frame own the admitted Player passenger")
	var released := authority.release(1, 1, &"solo_halyard_passenger", &"crew_port_00", 100, int(assignment.seat_generation))
	var unauthorized := craft.release_crew_role_occupant(2, 1, &"solo_halyard_passenger", &"crew_port_00", game.player, 101, int(assignment.seat_generation))
	_check(bool(released.get("accepted", false)) and not bool(unauthorized.get("accepted", false)) and game.player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META), "withdrawn local assignment still fences physical cleanup to the exact authority peer")
	game.call("_update_station_seat_flow")
	await _settle_frames()
	_check(not game.player.is_seated() and not game.player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META) and game.player.is_on_floor() and game.get_in_flight_cabin_status().carried and craft.get_crew_role_authority() == null, "withdrawn local passenger ledger clears its exact tag and preserves newly restored walking cabin occupancy")
	await _press_crew_interaction()
	authority = craft.get_crew_role_authority()
	_check(game.player.is_seated_at(craft.get_loadmaster_station_anchor()), "ordinary E admits the same physical passenger after exact stale-claim cleanup")
	var advanced := authority.submit_intent(1, 1, &"solo_halyard_passenger", CrewSeatRoleAuthority.ACTION_PASSENGER_PING, {"channel": &"cabin", "marker_id": &"solo_cleanup_ping"}, 100)
	_check(bool(advanced.get("accepted", false)), "the existing passenger owner admits a real command beyond Main's local interaction cursor")
	await _press_crew_interaction()
	_check(not game.player.is_seated() and game.player.is_on_floor() and game.player.is_control_enabled() and authority.get_snapshot().assignments.is_empty() and not game.player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META) and game.get_in_flight_cabin_status().carried, "ordinary E stand releases the exact passenger claim and restores supported walking cabin ownership")
	await _press_crew_interaction()
	_check(game.player.is_seated_at(craft.get_loadmaster_station_anchor()), "the same ordinary passenger interaction remains reusable after standing")
	var hosted := game.host_network_session(28619)
	await _settle_frames()
	_check(bool(hosted.get("accepted", false)) and authority.get_snapshot().assignments.is_empty() and not game.player.is_seated() and not game.player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META) and game.player.is_control_enabled() and game.player.is_on_floor(), "successful production host handback releases the local passenger before network composition owns the session")
	await _press_crew_interaction()
	_check(not game.player.is_seated_at(craft.get_loadmaster_station_anchor()) and not game.player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META) and craft.get_crew_role_authority() == null and (game.get_solo_crew_seat_status().get("assignment", {}) as Dictionary).is_empty(), "live network E cannot acquire a solo passenger claim or physical crew tag")
	# The network chair filter deliberately lets this press reach the legal
	# empty cockpit. Prove and finish that actual pilot handoff before teardown.
	_check(await _wait_for_seat(game, craft) and craft.is_piloted() and game.player.is_seated_at(craft.get_pilot_seat_anchor()), "network E beside the unavailable solo chair uses only the authorized pilot seat")
	await _press_crew_interaction()
	await _settle_frames(120)
	_check(not game.player.is_seated() and game.player.is_control_enabled() and game.player.is_on_floor() and not craft.is_piloted() and not bool(game.get("_transition_busy")), "ordinary E fully leaves the host pilot seat onto supported controllable deck")
	game.shutdown_network_session(&"crew_test")
	await _retire_game(game)
	# Subsequent solo persistence is an independent Main session, using the
	# same authored chair setup as the initial ordinary passenger fixture.
	game = await _make_game_with_store(store)
	craft = game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	seat = craft.find_child("SoloPassengerSeatInteraction", true, false) as Area3D
	game.start_shift()
	game.set_physics_process(true)
	game.player.teleport_to(seat.call("get_entry_transform"))
	await _settle_frames()
	await _press_crew_interaction()
	_check(game.player.is_seated_at(craft.get_loadmaster_station_anchor()), "ordinary solo input can admit a passenger after network shutdown")
	game.call("_capture_solo_safe_recovery_context")
	var context: Dictionary = store.get_snapshot()[GameFlowScript.SOLO_SAFE_RECOVERY_SLOT]
	_check(context.get("mode") == "crew" and context.get("craft_id") == String(craft.get_ship_id()) and context.size() == 4 and FileAccess.file_exists(path), "a settled real passenger persists only safe crew mode and its registered craft/home berth to an actual file")
	var retained_player := game.player
	root.remove_child(game)
	root.add_child(game)
	await _settle_frames()
	game.set_physics_process(true)
	_check(game.player == retained_player and not game.player.is_seated() and game.player.is_control_enabled() and game.player.is_on_floor() and not game.player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META), "retained Main releases passenger ownership and keeps the same supported usable Player")
	await _press_crew_interaction()
	_check(game.player.is_seated_at(craft.get_loadmaster_station_anchor()), "retained Main can admit the same Player again through ordinary input")
	game.call("_capture_solo_safe_recovery_context")
	await _retire_game(game)
	var cold := await _make_game_with_store(Store.new(path) as UserDataStore)
	craft = cold.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var pending := cold.get_recovery_available_snapshot()
	_check(not pending.is_empty() and cold.get_session_recovery_save_summary().contains("crew") and cold.get_session_recovery_save_summary().contains(craft.get_display_name()), "fresh Main names the saved craft and an awake recovery without replaying the crew claim")
	var stale: Dictionary = cold.call("_handle_hud_session_recovery_choice", &"normal_start", int(pending.session_id), int(pending.startup_generation) + 1)
	_check(not stale.accepted and not bool(cold.get("_solo_safe_recovery_pending")), "a stale crew Resume cannot stage any seat or cabin owner")
	cold.call("_handle_hud_session_recovery_choice", &"normal_start", int(pending.session_id), int(pending.startup_generation))
	cold.start_shift()
	cold.set_physics_process(true)
	await _settle_frames()
	_check(cold.active_ship == craft and cold.player.is_control_enabled() and cold.player.is_on_floor() and not cold.player.is_seated() and not craft.is_piloted() and craft.get_crew_role_authority() == null and cold.get_in_flight_cabin_status().carried and (craft.get_node("ShipBoardingArea") as ShipBoardingArea).get_reservation_token() == cold.player, "explicit crew Resume reacquires a fresh supported awake cabin and hatch without restoring old passenger or pilot claims")
	var walk_origin := cold.player.global_position
	Input.action_press(&"move_forward")
	await _settle_frames(24)
	Input.action_release(&"move_forward")
	await _settle_frames()
	_check(cold.player.global_position.distance_to(walk_origin) > 0.1 and cold.player.is_on_floor(), "crew Resume allows ordinary walking away from the passenger chair toward the helm")
	# The real input proof keeps the authored pilot motion: an artificial 20ms
	# seat handoff can complete while the original E is still being sampled.
	cold.boarding_motion_time = 1.1
	await _press_crew_interaction()
	_check(await _wait_for_seat(cold, craft) and bool(craft.get_telemetry().get("landed", false)), "ordinary recovered cabin interaction retakes the actual helm")
	cold.call("_try_exit_ship")
	await _settle_frames(120)
	_check(cold.phase == GameFlow.Phase.APPROACH_SHIP and not cold.player.is_cabin_containment_active() and not cold.player.is_seated() and cold.player.is_on_floor() and cold.player.is_control_enabled() and not craft.is_piloted(), "ordinary landed exit returns the crew-resumed Player to the supported deck")
	cold.player.teleport_to((craft.find_child("SoloPassengerSeatInteraction", true, false) as ShipCrewSeat).get_entry_transform())
	await _settle_frames()
	await _press_crew_interaction()
	var passenger_settled := false
	for _tick in 120:
		if cold.player.is_seated_at(craft.get_loadmaster_station_anchor()) \
				and bool((cold.call("get_solo_crew_seat_status") as Dictionary).get("seated", false)) \
				and not bool(cold.get("_transition_busy")):
			passenger_settled = true
			break
		await physics_frame
	var destroyed_authority := craft.get_crew_role_authority()
	_check(passenger_settled and destroyed_authority != null, "the live recovered craft accepts the real passenger before hull-loss cleanup")
	if passenger_settled and destroyed_authority != null:
		craft.apply_damage(craft.maximum_hull + 1.0, craft.global_position, Vector3.UP)
		await _settle_frames(120)
		_check(not cold.player.is_seated() and cold.player.is_control_enabled() and cold.player.is_on_floor() and not cold.player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META) and destroyed_authority.get_snapshot().assignments.is_empty(), "actual hull loss releases the exact passenger ledger and restores a supported usable station Player")
	await _retire_game(cold)
	for suffix in ["", ".bak", ".tmp", ".bak.1", ".bak.2", ".bak.3"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("SESSION_RECOVERY_RESUME_OFFER_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("SESSION_RECOVERY_RESUME_OFFER_TEST_FAILED: %d/%d assertions failed" % [_failures.size(), _assertions])
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
