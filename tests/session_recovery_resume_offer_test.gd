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
	var recovery_snapshot := _test_unclean_shutdown_is_detected_and_clean_quit_is_not()
	_test_save_summary_names_the_resumed_save()
	await _test_startup_card_offers_resume_or_start_fresh(recovery_snapshot)
	await _test_cold_solo_safe_recovery()
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
	var store := Store.new(STORE_PATH, filesystem) as UserDataStore
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
