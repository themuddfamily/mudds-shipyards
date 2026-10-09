extends SceneTree

## Production checkpoint/reward transactions on real disk, with independent
## fresh Main owners. Approach samples are positioned; this is not a flight journey.
const Main := preload("res://scenes/main.tscn")
const Scan := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")

class FaultFilesystem extends UserDataFilesystem:
	var reject_rewards := true
	var reject_all := false
	var freeze_on_reward := false
	var refused_reward := false
	var fail_published_reward_sync := false
	var _reward_just_published := false

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if reject_all:
			return ERR_UNAVAILABLE
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if reject_rewards and document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-"):
			refused_reward = true
			if freeze_on_reward:
				reject_all = true
			return ERR_UNAVAILABLE
		return super.write_bytes_and_flush(path, bytes)

	func remove_path(path: String) -> Error:
		return ERR_UNAVAILABLE if reject_all else super.remove_path(path)

	func rename_path(from_path: String, to_path: String) -> Error:
		if reject_all:
			return ERR_UNAVAILABLE
		var reward := false
		if from_path.ends_with(".tmp"):
			var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(from_path))
			reward = document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-")
		var result := super.rename_path(from_path, to_path)
		if result == OK and reward:
			_reward_just_published = true
		return result

	func sync_directory(path: String) -> Error:
		if _reward_just_published and fail_published_reward_sync:
			fail_published_reward_sync = false
			_reward_just_published = false
			return ERR_UNAVAILABLE
		return super.sync_directory(path)

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _progress_recovery()
	await _legacy_discovery_compatibility()
	var path := "user://scan_durable_%d.json" % Time.get_ticks_usec()
	var first_fs := FaultFilesystem.new()
	first_fs.freeze_on_reward = true
	var first := await _game(path, first_fs)
	await _board(first)
	var binding := await _binding(first)
	first.call("_on_settings_save_requested")
	var settings_before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload.runtime_settings
	await _complete(first, binding)
	var completed := binding.get_activity_snapshot(&"structure_scan")
	var generation := int(completed.generation)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var terminal: Dictionary = document.payload.get("cinder_structure_scan_session", {})
	_check(first_fs.refused_reward and completed.state_id == &"complete" and _receipts(first) == 0,
		"the actual production timed scan completes while the real reward write is rejected")
	_check(not terminal.is_empty() and CinderAbandonedStructureScanActivity.validate_persistence_record(terminal).accepted
		and terminal.activities[0].reward_requested and not terminal.activities[0].reward_granted,
		"the successful checkpoint leaves a valid unpaid terminal on real disk before reward publication")
	await _dispose(first)
	var second_fs := FaultFilesystem.new()
	var second := await _game(path, second_fs)
	var second_binding := await _binding(second)
	var restored := second_binding.get_activity_snapshot(&"structure_scan")
	_check(restored.state_id == &"complete" and int(restored.generation) == generation
		and restored.elapsed_seconds == Scan.SCAN_SECONDS and restored.reward_pending and _receipts(second) == 0,
		"fresh Main restores the exact genuine unpaid completion and visible pending handoff")
	_button(second, 3).emit_signal("pressed")
	if _button(second, 3).text == "CONFIRM RESET":
		_button(second, 3).emit_signal("pressed")
	_button(second, 2).emit_signal("pressed")
	_check(second_binding.get_activity_snapshot(&"structure_scan").state_id == &"complete"
		and second_fs.refused_reward and _receipts(second) == 0,
		"ordinary Reset cannot erase recovered debt and Start retries it while storage refuses")
	second_fs.reject_rewards = false
	_button(second, 2).emit_signal("pressed")
	var paid := second_binding.get_activity_snapshot(&"structure_scan")
	_check(paid.reward_requested and paid.reward_committed and not paid.reward_pending and _receipts(second) == 1,
		"ordinary Start commits one receipt and the terminal payment acknowledgement atomically")
	await _dispose(second)
	var third := await _game(path, UserDataFilesystem.new())
	var third_binding := await _binding(third)
	var paid_restore := third_binding.get_activity_snapshot(&"structure_scan")
	_check(paid_restore.reward_requested and paid_restore.reward_committed and paid_restore.discovery_persisted and _receipts(third) == 1,
		"another fresh Main restores paid completion with legacy discovery presentation and without a second entitlement")
	var duplicate := third_binding.request_structure_scan_reward()
	_check(not duplicate.accepted and _receipts(third) == 1, "the recovered paid scan terminal never pays twice")
	_check(JSON.parse_string(FileAccess.get_file_as_string(path)).payload.runtime_settings == settings_before,
		"scan recovery, checkpoints and first payment preserve the actual earlier disk settings namespace")
	_button(third, 3).emit_signal("pressed")
	_check(third_binding.get_activity_snapshot(&"structure_scan").state_id == &"reset" and _receipts(third) == 1,
		"ordinary paid Reset persists its genuine reset boundary before Main exits")
	await _dispose(third)
	var fourth := await _game(path, UserDataFilesystem.new())
	var fourth_binding := await _binding(fourth)
	var reset_restore := fourth_binding.get_activity_snapshot(&"structure_scan")
	_check(reset_restore.state_id == &"reset" and int(reset_restore.generation) == generation
		and reset_restore.elapsed_seconds == 0.0 and not reset_restore.reward_requested and _receipts(fourth) == 1,
		"fresh Main restores the exact paid-reset generation without inheriting an owed terminal")
	# Boot's existing safe-start owner can legitimately persist its recommended
	# graphics after repeated unclean lifetimes. Scan transactions must preserve
	# the actual namespace handed to them after that existing owner has run.
	var settings_next_baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload.runtime_settings
	var cold_changes: Dictionary = {}
	for key in settings_before.values:
		if settings_before.values[key] != settings_next_baseline.values[key]:
			cold_changes[key] = {"before": settings_before.values[key], "after": settings_next_baseline.values[key]}
	print("SCAN_COLD_START_SETTINGS_CHANGE: ", JSON.stringify(cold_changes))
	await _board(fourth)
	await _complete(fourth, fourth_binding)
	var next_paid := fourth_binding.get_activity_snapshot(&"structure_scan")
	_check(next_paid.state_id == &"complete" and int(next_paid.generation) == generation + 1
		and next_paid.reward_committed and _receipts(fourth) == 2,
		"ordinary Start after fresh reset completes and pays the distinct next generation once")
	var stale: Dictionary = fourth.call("_commit_game_flow_activity_reward", {
		"activity_id": Scan.ACTIVITY_ID, "activity_generation": generation,
		"reward_id": Scan.REWARD_ID, "reward_authority": false, "granted": false,
	})
	_check(not stale.accepted and stale.reason == &"reward_generation_mismatch" and _receipts(fourth) == 2,
		"the existing reward owner rejects the earlier completion against the next saved generation")
	var fourth_store: UserDataStore = fourth.get("_runtime_settings_user_data_store")
	_check(fourth_store.get_snapshot().runtime_settings == settings_next_baseline
		and JSON.parse_string(FileAccess.get_file_as_string(path)).payload.runtime_settings == settings_next_baseline,
		"scan checkpoints and receipts preserve the actual pretransaction disk settings namespace")
	await _dispose(fourth)
	var fifth := await _game(path, UserDataFilesystem.new())
	var fifth_binding := await _binding(fifth)
	var next_restore := fifth_binding.get_activity_snapshot(&"structure_scan")
	var next_duplicate := fifth_binding.request_structure_scan_reward()
	_check(next_restore.state_id == &"complete" and int(next_restore.generation) == generation + 1
		and next_restore.reward_committed and not next_duplicate.accepted and _receipts(fifth) == 2,
		"another fresh Main restores the next paid generation and refuses its duplicate handoff")
	await _dispose(fifth)
	await _published_payment_retry()
	await _all_writes_failed()
	await _unsupported_record(path)
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("GAME_FLOW_SCAN_DURABLE_RECOVERY_TEST_OK: %d assertions" % _checks)
	quit(0 if _failures.is_empty() else 1)

func _progress_recovery() -> void:
	var path := "user://scan_progress_%d.json" % Time.get_ticks_usec()
	var first := await _game(path, UserDataFilesystem.new())
	await _board(first)
	var binding := await _binding(first)
	first.active_ship.global_position = first.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	_button(first, 2).emit_signal("pressed")
	first.call("_advance_cinder_structure_scan", 1.5, first.call("_capture_cinder_actor_sample"))
	var progress := binding.get_activity_snapshot(&"structure_scan")
	_check(progress.state_id == &"active" and is_equal_approx(progress.elapsed_seconds, 1.5), "ordinary HUD Start and actual production sample accrue genuine scan progress")
	await _dispose(first)
	var fresh := await _game(path, UserDataFilesystem.new())
	var fresh_binding := await _binding(fresh)
	var restored := fresh_binding.get_activity_snapshot(&"structure_scan")
	_check(restored.state_id == &"active" and restored.generation == progress.generation and is_equal_approx(restored.elapsed_seconds, 1.5), "fresh Main restores the exact saved scan generation and accrued time")
	var foreign := await _game(path, UserDataFilesystem.new())
	var foreign_binding := await _binding(foreign)
	await _board(foreign)
	foreign.active_ship.global_position = foreign.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	foreign.call("_advance_cinder_structure_scan", Scan.SCAN_SECONDS-1.5, foreign.call("_capture_cinder_actor_sample"))
	var old_save: Dictionary = fresh.call("_save_cinder_scan_session", fresh_binding)
	_check(not old_save.accepted and _receipts(foreign) == 1, "an earlier Main cannot overwrite the later owner's paid completion with its saved active progress")
	await _dispose(foreign)
	await _dispose(fresh)


func _legacy_discovery_compatibility() -> void:
	var path := "user://scan_legacy_discovery_%d.json" % Time.get_ticks_usec()
	var paid := await _game(path, UserDataFilesystem.new())
	await _board(paid)
	var paid_binding := await _binding(paid)
	await _complete(paid, paid_binding)
	_check(_receipts(paid) == 1 and paid_binding.get_activity_snapshot(&"structure_scan").discovery_persisted,
		"existing production discovery and shared reward owners publish a genuine paid scan")
	await _dispose(paid)
	# A historical save predates the new progress namespace. Preserve the real
	# discovery/ledger produced above and omit only that newer namespace.
	var store := UserDataStore.new(path)
	store.load()
	var payload := store.get_snapshot()
	payload.erase("cinder_structure_scan_session")
	_check(store.commit(payload, store.get_generation(), "unit-legacy-scan-save-layout").accepted,
		"the real legacy-format disk fixture retains its discovery and paid ledger")
	var legacy := await _game(path, UserDataFilesystem.new())
	var binding := await _binding(legacy)
	var presentation := binding.get_activity_snapshot(&"structure_scan")
	var authority_state: Dictionary = binding.capture_structure_scan_session().activities[0]
	_check(presentation.discovery_persisted and presentation.state_id == &"complete"
		and authority_state.state == Scan.State.IDLE and authority_state.generation == 0
		and _receipts(legacy) == 1,
		"legacy paid discovery restores presentation while scan authority stays idle without owed entitlement")
	await _board(legacy)
	await _complete(legacy, binding)
	_check(_receipts(legacy) == 2 and binding.get_activity_snapshot(&"structure_scan").reward_committed,
		"ordinary Start completes a genuine new scan from a legacy save and pays that distinct run once")
	await _dispose(legacy)


func _published_payment_retry() -> void:
	var path := "user://scan_published_payment_%d.json" % Time.get_ticks_usec()
	var fault := FaultFilesystem.new()
	fault.reject_rewards = false
	fault.fail_published_reward_sync = true
	var game := await _game(path, fault)
	await _board(game)
	var binding := await _binding(game)
	await _complete(game, binding)
	var live := binding.get_activity_snapshot(&"structure_scan")
	var published: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload
	var failed: Dictionary = game.get_activity_reward_report().last_cinder_structure_scan_result
	_check(not live.reward_requested and published.cinder_structure_scan_session.activities[0].reward_granted
		and int(published.game_flow_reward_store.total_receipts) == 1
		and failed.authority_result.store_result.reason == "published_directory_sync_failed"
		and failed.authority_result.store_result.published,
		"a real postpublication sync failure leaves a paid disk receipt while the live owner reports refusal")
	_button(game, 2).emit_signal("pressed")
	var reconciled := binding.get_activity_snapshot(&"structure_scan")
	var store: UserDataStore = game.get("_runtime_settings_user_data_store")
	_check(reconciled.reward_requested and reconciled.reward_committed and _receipts(game) == 1
		and store.get_snapshot().cinder_structure_scan_session.activities[0].reward_granted,
		"ordinary Start reconciles the exact published payment without downgrading its acknowledgement or paying twice")
	_button(game, 3).emit_signal("pressed")
	game.active_ship.global_position = game.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	_button(game, 2).emit_signal("pressed")
	_check(binding.get_activity_snapshot(&"structure_scan").generation == int(live.generation) + 1 and _receipts(game) == 1,
		"the reconciled payment permits an ordinary new generation with one durable receipt")
	await _dispose(game)
	var fresh := await _game(path, UserDataFilesystem.new())
	await _binding(fresh)
	_check(_receipts(fresh) == 1, "fresh Main after the sync failure still loads exactly one material-sample payment")
	await _dispose(fresh)

func _all_writes_failed() -> void:
	var path := "user://scan_unsaved_%d.json" % Time.get_ticks_usec()
	var fault := FaultFilesystem.new()
	var first := await _game(path, fault)
	await _board(first)
	var binding := await _binding(first)
	fault.reject_all = true
	await _complete(first, binding)
	_check(binding.get_activity_snapshot(&"structure_scan").state_id == &"complete" and _receipts(first) == 0,
		"when every write fails the live owner retains completion but grants no reward")
	await _dispose(first)
	var fresh := await _game(path, UserDataFilesystem.new())
	var fresh_binding := await _binding(fresh)
	_check(fresh_binding.get_activity_snapshot(&"structure_scan").state_id == &"idle" and _receipts(fresh) == 0,
		"without a valid durable terminal fresh Main safely offers a new scan and no entitlement")
	await _dispose(fresh)

func _unsupported_record(path: String) -> void:
	var store := UserDataStore.new(path)
	store.load()
	var payload := store.get_snapshot()
	payload.cinder_structure_scan_session.schema_version = 2
	store.commit(payload, store.get_generation(), "unit-unsupported-scan-record")
	var unsupported := JSON.parse_string(JSON.stringify(payload.cinder_structure_scan_session)) as Dictionary
	var fresh := await _game(path, UserDataFilesystem.new())
	await _binding(fresh)
	_button(fresh, 2).emit_signal("pressed")
	_button(fresh, 3).emit_signal("pressed")
	_check(fresh.get("_runtime_settings_user_data_store").get_snapshot().cinder_structure_scan_session == unsupported,
		"unsupported saved scan data remains unchanged through ordinary Start and Reset")
	_check(fresh.call("_get_nearby_activity_binding").get_activity_snapshot(&"structure_scan").generation == 0
		and _receipts(fresh) == 2, "unsupported state creates neither a recovered generation nor reward entitlement")
	await _dispose(fresh)

func _game(path: String, filesystem: UserDataFilesystem) -> GameFlow:
	var game := Main.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(UserDataStore.new(path, filesystem), path + ".legacy.cfg")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	return game

func _board(game: GameFlow) -> void:
	game.set_physics_process(true)
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.start_shift()
	var craft := game.get_guided_ship()
	game.player.global_position = craft.get_boarding_position()
	game.call("_board_ship", craft)
	for _tick in 300:
		if craft.is_piloted() and game.player.is_seated_at(craft.get_pilot_seat_anchor()):
			break
		await physics_frame
	_check(craft.is_piloted() and game.player.is_seated_at(craft.get_pilot_seat_anchor()), "actual production boarding supplies the scan fixture's pilot owner")
	game.set_physics_process(false)

func _binding(game: GameFlow) -> NearbySectorActivityBinding:
	game.cinder_streaming_bootstrap.update_position(CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR)
	var binding: NearbySectorActivityBinding
	for _frame in 180:
		binding = game.call("_get_nearby_activity_binding") as NearbySectorActivityBinding
		if is_instance_valid(binding):
			break
		await process_frame
	_check(is_instance_valid(binding), "the real Cinder streaming owner supplies the scan binding")
	game.call("_sync_activity_hud")
	return binding

func _complete(game: GameFlow, binding: NearbySectorActivityBinding) -> void:
	var craft := game.active_ship
	craft.global_position = game.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	_button(game, 2).emit_signal("pressed")
	_check(binding.get_activity_snapshot(&"structure_scan").state_id == &"active", "ordinary HUD Start admits the actual authored scan approach")
	for _tick in int(Scan.SCAN_SECONDS * 60):
		game.call("_advance_cinder_structure_scan", 1.0 / 60.0, game.call("_capture_cinder_actor_sample"))
	_check(binding.get_activity_snapshot(&"structure_scan").elapsed_seconds == Scan.SCAN_SECONDS,
		"ordinary 1/60 scan samples normalize the genuine completed timer to its durable terminal")

func _button(game: GameFlow, index: int) -> Button:
	for row in (game.hud.get("_nearby_activity_rows") as VBoxContainer).get_children():
		if "cinder_derelict_structure_scan" in str(row.name):
			return row.get_child(index) as Button
	return null

func _dispose(game: GameFlow) -> void:
	game.queue_free()
	await process_frame
	await process_frame

func _receipts(game: GameFlow) -> int:
	return int(game.get_activity_reward_report().authority.record.total_receipts)

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("PASS: ", message)
	else:
		_failures.append("FAIL: " + message)
