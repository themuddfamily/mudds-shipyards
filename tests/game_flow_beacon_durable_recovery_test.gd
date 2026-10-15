extends SceneTree

## Production checkpoint/reward transactions on real disk, with independent
## fresh Main owners. Route samples are positioned; this is not a flight journey.
const Main := preload("res://scenes/main.tscn")
const Beacon := preload("res://scripts/world/cinder_beacon_traversal_activity.gd")

class FaultFilesystem extends UserDataFilesystem:
	var reject_rewards := true
	var reject_all := false
	var freeze_on_reward := false
	var refused_reward := false
	var fail_published_reward_sync := false
	var _reward_just_published := false
	var fail_published_reset_sync := false
	var _reset_just_published := false
	var on_reset_write := Callable()

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if reject_all:
			return ERR_UNAVAILABLE
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if document is Dictionary and on_reset_write.is_valid():
			var session: Dictionary = document.get("payload", {}).get("cinder_beacon_session", {})
			if not session.is_empty() and int(session.activities[0].state) == Beacon.State.RESET:
				var callback := on_reset_write
				on_reset_write = Callable()
				callback.call()
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
		var reset := false
		if from_path.ends_with(".tmp"):
			var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(from_path))
			reward = document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-")
			if document is Dictionary:
				var session: Dictionary = document.get("payload", {}).get("cinder_beacon_session", {})
				reset = not session.is_empty() and int(session.activities[0].state) == Beacon.State.RESET
		var result := super.rename_path(from_path, to_path)
		if result == OK and reward:
			_reward_just_published = true
		if result == OK and reset:
			_reset_just_published = true
		return result

	func sync_directory(path: String) -> Error:
		if _reset_just_published and fail_published_reset_sync:
			fail_published_reset_sync = false
			_reset_just_published = false
			return ERR_UNAVAILABLE
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
	if OS.get_cmdline_user_args().has("--start-fresh-recovery"):
		await _start_fresh_recovery()
		_finish()
		return
	# Optional bounded diagnosis leaves every default recovery route unchanged.
	if OS.get_cmdline_user_args().has("--beacon-backup-trust-only"):
		await _backup_trust_reproduction()
		_finish()
		return
	var path := "user://beacon_durable_%d.json" % Time.get_ticks_usec()
	var first_fs := FaultFilesystem.new()
	first_fs.freeze_on_reward = true
	var first := await _game(path, first_fs)
	await _board(first)
	var binding := await _binding(first)
	first.call("_on_settings_save_requested")
	var settings_before: Dictionary = first.get("_runtime_settings_user_data_store").get_snapshot().runtime_settings
	await _complete(first, binding)
	var completed := binding.get_activity_snapshot(&"beacon_traversal")
	var generation := int(completed.generation)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var terminal: Dictionary = document.payload.get("cinder_beacon_session", {})
	_check(first_fs.refused_reward and completed.state_id == &"complete" and _receipts(first) == 0,
		"the actual ordered traversal completes while the real reward write is rejected")
	_check(not terminal.is_empty() and CinderBeaconTraversalActivity.validate_persistence_record(terminal).accepted
		and terminal.activities[0].reward_requested and not terminal.activities[0].reward_granted,
		"the successful checkpoint leaves a valid unpaid terminal on real disk before reward publication")
	await _dispose(first)
	var second_fs := FaultFilesystem.new()
	var second := await _game(path, second_fs)
	var second_binding := await _binding(second)
	var restored := second_binding.get_activity_snapshot(&"beacon_traversal")
	_check(restored.state_id == &"complete" and int(restored.generation) == generation
		and restored.next_beacon_index == Beacon.BEACONS.size() and restored.reward_pending and _receipts(second) == 0,
		"fresh Main restores the exact genuine unpaid completion and visible pending handoff")
	_button(second, 3).emit_signal("pressed")
	if _button(second, 3).text == "CONFIRM RESET":
		_button(second, 3).emit_signal("pressed")
	_button(second, 2).emit_signal("pressed")
	_check(second_binding.get_activity_snapshot(&"beacon_traversal").state_id == &"complete"
		and second_fs.refused_reward and _receipts(second) == 0,
		"ordinary Reset cannot erase recovered debt and Start retries it while storage refuses")
	second_fs.reject_rewards = false
	_button(second, 2).emit_signal("pressed")
	var paid := second_binding.get_activity_snapshot(&"beacon_traversal")
	_check(paid.reward_requested and paid.reward_committed and not paid.reward_pending and _receipts(second) == 1,
		"ordinary Start commits one receipt and the terminal payment acknowledgement atomically")
	await _dispose(second)
	var third := await _game(path, UserDataFilesystem.new())
	var third_binding := await _binding(third)
	var paid_restore := third_binding.get_activity_snapshot(&"beacon_traversal")
	_check(paid_restore.reward_requested and paid_restore.reward_committed and _receipts(third) == 1,
		"another fresh Main restores paid completion without inferring a second entitlement")
	var duplicate := third_binding.request_beacon_traversal_reward()
	_check(not duplicate.accepted and _receipts(third) == 1, "the recovered paid terminal never pays twice")
	_button(third, 3).emit_signal("pressed")
	third.active_ship.global_position = third.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_button(third, 2).emit_signal("pressed")
	var started := third_binding.get_activity_snapshot(&"beacon_traversal")
	_check(started.state_id == &"active" and int(started.generation) == generation + 1,
		"paid Reset and ordinary Start produce the next real beacon generation")
	var stale: Dictionary = third.call("_commit_game_flow_activity_reward", {
		"activity_id": Beacon.ACTIVITY_ID, "activity_generation": generation,
		"reward_id": Beacon.REWARD_ID, "reward_authority": false, "granted": false,
	})
	_check(not stale.accepted and stale.reason == &"reward_generation_mismatch" and _receipts(third) == 1,
		"the existing reward owner rejects the earlier completion against the next saved generation")
	var third_store: UserDataStore = third.get("_runtime_settings_user_data_store")
	_check(third_store.get_snapshot().runtime_settings == settings_before,
		"beacon checkpoints and receipts preserve the existing settings namespace")
	await _dispose(third)
	var fourth := await _game(path, UserDataFilesystem.new())
	var fourth_binding := await _binding(fourth)
	var next_restored := fourth_binding.get_activity_snapshot(&"beacon_traversal")
	_check(next_restored.state_id == &"active" and int(next_restored.generation) == generation + 1
		and next_restored.next_beacon_index == 0 and not next_restored.reward_requested and _receipts(fourth) == 1,
		"fresh Main recovers the next run without inheriting the previous paid reward")
	await _dispose(fourth)
	await _reset_write_failure(false)
	await _reset_write_failure(true)
	await _reset_owner_changed()
	await _published_payment_retry()
	await _all_writes_failed()
	await _unsupported_record(path)
	_finish()

func _start_fresh_recovery() -> void:
	var path := "user://beacon_start_fresh_%d.json" % Time.get_ticks_usec()
	var source := await _game(path, UserDataFilesystem.new())
	await _board(source)
	var binding := await _binding(source)
	source.call("_on_settings_save_requested")
	var store: UserDataStore = source.get("_runtime_settings_user_data_store")
	var seeded := store.get_snapshot()
	seeded["beacon_fresh_unrelated"] = {"stock": 7, "note": "retain caller data"}
	_check(store.commit(seeded, store.get_generation(), "unit-beacon-fresh-unrelated").accepted,
		"Start Fresh fixture seeds independent data beside actual settings")
	source.active_ship.global_position = source.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_button(source, 2).pressed.emit()
	for index in 2:
		source.active_ship.global_position = source.call("_cinder_authored_frame_to_world", Beacon.BEACONS[index])
		source.call("_advance_cinder_beacon_traversal", 0.0, source.call("_capture_cinder_actor_sample"))
	var active := binding.capture_beacon_traversal_session()
	_check(int(active.activities[0].state) == Beacon.State.ACTIVE
		and int(active.activities[0].progress.next_beacon_index) == 2,
		"the real ordered beacon owner saves two observations before interruption")
	var published_reset: Dictionary = source.call("_decline_interrupted_planetary_visits")
	var source_reset := binding.capture_beacon_traversal_session()
	_check(published_reset.accepted and int(source_reset.activities[0].state) == Beacon.State.RESET
		and int(source_reset.activities[0].generation) == int(active.activities[0].generation)
		and store.get_snapshot().cinder_beacon_session == source_reset,
		"successful decline publication resets only its exact live owner after committing the intended primary")
	source.active_ship.global_position = source.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_button(source, 2).pressed.emit()
	for index in 2:
		source.active_ship.global_position = source.call("_cinder_authored_frame_to_world", Beacon.BEACONS[index])
		source.call("_advance_cinder_beacon_traversal", 0.0, source.call("_capture_cinder_actor_sample"))
	active = binding.capture_beacon_traversal_session()
	_check(int(active.activities[0].state) == Beacon.State.ACTIVE
		and int(active.activities[0].generation) == int(source_reset.activities[0].generation) + 1
		and int(active.activities[0].progress.next_beacon_index) == 2,
		"successful publication releases the owner for the next real ordered traversal")
	await _dispose(source)
	var fault := FaultFilesystem.new()
	var game := await _game(path, fault)
	binding = await _binding(game)
	store = game.get("_runtime_settings_user_data_store")
	var recovery := game.get_recovery_available_snapshot()
	var fresh := _fresh_button(game)
	_check(not recovery.is_empty() and is_instance_valid(fresh) and fresh.is_visible_in_tree() and not fresh.disabled
		and binding.capture_beacon_traversal_session() == active,
		"cold Main offers actual title Start Fresh with the restored active beacon owner")
	if recovery.is_empty() or not is_instance_valid(fresh) or not fresh.is_visible_in_tree() or fresh.disabled:
		await _dispose(game)
		return
	var before := store.get_snapshot()
	var bytes := FileAccess.get_file_as_bytes(path)
	var stale: Dictionary = game.call("_handle_hud_session_recovery_choice", &"discard",
		int(recovery.session_id), int(recovery.startup_generation) + 1)
	_check(not stale.accepted and store.get_snapshot() == before and binding.capture_beacon_traversal_session() == active,
		"a stale recovery fence cannot retire beacon observations")
	fault.reject_all = true
	fresh.pressed.emit()
	var refused := game.get("_session_recovery_hud_status") as Dictionary
	_check(await _fresh_retry_ready(game, fresh, recovery)
		and not bool(refused.get("accepted", false)) and store.get_snapshot() == before
		and FileAccess.get_file_as_bytes(path) == bytes and binding.capture_beacon_traversal_session() == active,
		"a rejected actual Start Fresh write retains its same usable fence, live cursor and primary document")
	var released := binding.start_beacon_traversal(Beacon.BEACONS[0])
	_check(not released.accepted and released.reason == &"already_active"
		and binding.capture_beacon_traversal_session() == active,
		"a refused decline releases publication protection without resetting or stranding its actual owner")
	if not is_instance_valid(fresh) or fresh.disabled:
		fault.reject_all = false
		await _dispose(game)
		return
	fault.reject_all = false
	var live_at_publication := {}
	var publication_results: Array[Dictionary] = []
	fault.on_reset_write = func() -> void:
		live_at_publication["record"] = binding.capture_beacon_traversal_session()
		# These are the actual remaining ordered observations, valid for the
		# retained ACTIVE owner; the publication window must reject them.
		for index in range(2, Beacon.BEACONS.size()):
			publication_results.append(binding.submit_beacon_traversal(index, Beacon.BEACONS[index]))
		publication_results.append(binding.advance_beacon_traversal_from_caller_sample(Beacon.BEACONS[2]))
		publication_results.append(binding.start_beacon_traversal(Beacon.BEACONS[0]))
		publication_results.append(binding.request_beacon_traversal_reward())
		publication_results.append(binding.reset_beacon_traversal())
	fault.fail_published_reset_sync = true
	fresh.pressed.emit()
	refused = game.get("_session_recovery_hud_status") as Dictionary
	var callback_refused := publication_results.size() == 6
	for result in publication_results:
		callback_refused = callback_refused and not bool(result.get("accepted", false)) \
			and result.get("reason") == &"beacon_reset_publication_in_progress"
	var published: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload.cinder_beacon_session
	_check(await _fresh_retry_ready(game, fresh, recovery)
		and not bool(refused.get("accepted", false)) and callback_refused
		and live_at_publication.get("record") == active and binding.capture_beacon_traversal_session() == published
		and int(published.activities[0].state) == Beacon.State.RESET,
		"real publication callbacks cannot earn or pay during RESET, and refused sync reconciles exact primary RESET while retaining the notice")
	var old_run_inactive := true
	for index in range(2, Beacon.BEACONS.size()):
		released = binding.submit_beacon_traversal(index, Beacon.BEACONS[index])
		old_run_inactive = old_run_inactive and not released.accepted and released.reason == &"not_active"
	_check(old_run_inactive and binding.capture_beacon_traversal_session() == published,
		"publication protection releases with a coherent RESET, so ordinary remaining observations cannot earn an unpayable old completion")
	if not is_instance_valid(fresh) or fresh.disabled:
		await _dispose(game)
		return
	_check(store.load().accepted and store.get_loaded_source() == &"primary",
		"retry observes the genuinely published primary RESET after the sync refusal")
	fresh.pressed.emit()
	var accepted := game.get("_session_recovery_hud_status") as Dictionary
	var reset := binding.capture_beacon_traversal_session()
	var payload := store.get_snapshot()
	_check(bool(accepted.get("accepted", false)) and game.get_recovery_available_snapshot().is_empty()
		and live_at_publication.get("record") == active and payload.cinder_beacon_session == reset
		and int(reset.activities[0].state) == Beacon.State.RESET
		and int(reset.activities[0].generation) == int(active.activities[0].generation)
		and int(reset.activities[0].progress.next_beacon_index) == 0
		and not reset.activities[0].reward_requested and not reset.activities[0].reward_granted,
		"same-fence retry saves same-generation RESET before publishing the live reset")
	_check(payload.runtime_settings == before.runtime_settings and payload.beacon_fresh_unrelated == before.beacon_fresh_unrelated
		and payload.get("game_flow_reward_store") == before.get("game_flow_reward_store"),
		"beacon Start Fresh preserves settings, caller inventory and the exact reward ledger")
	bytes = FileAccess.get_file_as_bytes(path)
	var old_writer: Dictionary = game.call("_save_cinder_beacon_session", binding, active)
	_check(not old_writer.accepted and old_writer.reason == &"beacon_session_stale_or_unpaid"
		and store.get_snapshot() == payload and FileAccess.get_file_as_bytes(path) == bytes,
		"the abandoned same-generation ACTIVE writer cannot overwrite the durable RESET")
	await _dispose(game)
	fault = FaultFilesystem.new()
	game = await _game(path, fault)
	await _board(game)
	binding = await _binding(game)
	store = game.get("_runtime_settings_user_data_store")
	_check(binding.capture_beacon_traversal_session() == reset and _receipts(game) == 0,
		"later cold Main restores RESET without resurrecting old beacon progress or reward")
	game.active_ship.global_position = game.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_button(game, 2).pressed.emit()
	game.call("_advance_cinder_beacon_traversal", 0.0, game.call("_capture_cinder_actor_sample"))
	var next := binding.capture_beacon_traversal_session()
	_check(int(next.activities[0].state) == Beacon.State.ACTIVE
		and int(next.activities[0].generation) == int(active.activities[0].generation) + 1
		and int(next.activities[0].progress.next_beacon_index) == 1,
		"ordinary beacon Start after recovery admits only the next genuine generation")
	fault.reject_all = true
	for index in range(1, Beacon.BEACONS.size()):
		game.active_ship.global_position = game.call("_cinder_authored_frame_to_world", Beacon.BEACONS[index])
		game.call("_advance_cinder_beacon_traversal", 0.0, game.call("_capture_cinder_actor_sample"))
	var earned := binding.capture_beacon_traversal_session()
	before = store.get_snapshot()
	_check(int(earned.activities[0].state) == Beacon.State.COMPLETE
		and int(before.cinder_beacon_session.activities[0].state) == Beacon.State.ACTIVE,
		"the next real traversal earns completion while its terminal save is refused")
	# Normal boarding acknowledged this Main's title choice. Exercise the same
	# transaction planner against its real live completion without inventing a
	# replacement recovery notice or bypassing the pilot sample authority.
	refused = game.call("_decline_interrupted_planetary_visits") as Dictionary
	_check(not bool(refused.get("accepted", false)) and refused.reason == &"beacon_terminal_save_pending"
		and store.get_snapshot() == before and binding.capture_beacon_traversal_session() == earned,
		"Start Fresh refuses to erase a live earned completion over the older saved ACTIVE record")
	fault.reject_all = false
	var saved: Dictionary = game.call("_save_cinder_beacon_session", binding)
	_check(saved.accepted, "the ordinary beacon save publishes the earned terminal when storage recovers")
	await _dispose(game)
	fault = FaultFilesystem.new()
	game = await _game(path, fault)
	binding = await _binding(game)
	store = game.get("_runtime_settings_user_data_store")
	fresh = _fresh_button(game)
	if game.get_recovery_available_snapshot().is_empty() or not is_instance_valid(fresh) \
			or not fresh.is_visible_in_tree() or fresh.disabled:
		_check(false, "the unpaid cold Main exposes the actual title Start Fresh choice")
		await _dispose(game)
		return
	before = store.get_snapshot()
	fresh.pressed.emit()
	accepted = game.get("_session_recovery_hud_status") as Dictionary
	_check(bool(accepted.get("accepted", false)) and game.get_recovery_available_snapshot().is_empty()
		and store.get_snapshot() == before and binding.capture_beacon_traversal_session() == earned and _receipts(game) == 0,
		"actual Start Fresh keeps completed unpaid beacon debt inert without paying or resetting it")
	fault.reject_rewards = false
	_button(game, 2).pressed.emit()
	_check(_receipts(game) == 1 and binding.get_activity_snapshot(&"beacon_traversal").reward_committed,
		"ordinary reward retry pays the preserved completion once after Start Fresh")
	await _dispose(game)
	game = await _game(path, UserDataFilesystem.new())
	binding = await _binding(game)
	store = game.get("_runtime_settings_user_data_store")
	before = store.get_snapshot()
	earned = binding.capture_beacon_traversal_session()
	fresh = _fresh_button(game)
	if game.get_recovery_available_snapshot().is_empty() or not is_instance_valid(fresh) \
			or not fresh.is_visible_in_tree() or fresh.disabled:
		_check(false, "the paid cold Main exposes the actual Start Fresh choice")
		await _dispose(game)
		return
	fresh.pressed.emit()
	accepted = game.get("_session_recovery_hud_status") as Dictionary
	_check(bool(accepted.get("accepted", false)) and game.get_recovery_available_snapshot().is_empty()
		and store.get_snapshot() == before and binding.capture_beacon_traversal_session() == earned
		and earned.activities[0].reward_granted and _receipts(game) == 1,
		"paid cold completion and its ledger remain exact through actual Start Fresh")
	await _dispose(game)


func _fresh_button(game: GameFlow) -> Button:
	var actions := game.hud.get("_recovery_prompt_actions") as HBoxContainer
	return actions.get_child(2) as Button if actions != null and actions.get_child_count() > 2 else null


func _fresh_retry_ready(game: GameFlow, button: Button, recovery: Dictionary) -> bool:
	var deadline := Time.get_ticks_msec() + 2_000
	while is_instance_valid(button) and button.disabled and Time.get_ticks_msec() < deadline:
		await process_frame
		await physics_frame
	var notice: Dictionary = game.hud.get_session_recovery_notice_snapshot()
	return is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled \
		and bool(notice.get("active", false)) and not bool(notice.get("choice_latched", true)) \
		and int(notice.get("recovery_token", 0)) == int(recovery.session_id) \
		and int(notice.get("recovery_generation", 0)) == int(recovery.startup_generation) \
		and game.get_recovery_available_snapshot() == recovery


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("GAME_FLOW_BEACON_DURABLE_RECOVERY_TEST_OK: %d assertions" % _checks)
	quit(0 if _failures.is_empty() else 1)

## The actual ordered route pays once and rotates its genuine earned-unpaid
## predecessor into backup. Each probe retains those exact independent bytes.
func _backup_trust_reproduction() -> void:
	var path := "user://beacon_backup_trust_%d.json" % Time.get_ticks_usec()
	var fault := FaultFilesystem.new()
	fault.reject_rewards = false
	var retained := await _game(path, fault)
	await _board(retained)
	var binding := await _binding(retained)
	retained.call("_on_settings_save_requested")
	var shared: UserDataStore = retained.get("_runtime_settings_user_data_store")
	var seeded := shared.get_snapshot()
	seeded["beacon_trust_unrelated"] = {"inventory": {"units": 4, "components": ["caller-owned sample"]}, "note": "independent caller data"}
	_check(seeded.has("runtime_settings") and shared.commit(seeded, shared.get_generation(), "unit-beacon-trust-unrelated").accepted,
		"the existing store seeds caller inventory data beside actual saved runtime settings")
	await _complete(retained, binding)
	var paid_bytes := FileAccess.get_file_as_bytes(path)
	var unpaid_bytes := FileAccess.get_file_as_bytes(path + ".bak")
	var paid_document: Variant = JSON.parse_string(paid_bytes.get_string_from_utf8())
	var unpaid_document: Variant = JSON.parse_string(unpaid_bytes.get_string_from_utf8())
	print("BEACON_BACKUP_FIXTURE_COMPLETION: ", retained.get_activity_reward_report())
	var documents_valid := paid_document is Dictionary and unpaid_document is Dictionary
	_check(documents_valid, "actual ordered traversal and payment publish readable primary and predecessor documents")
	if not documents_valid:
		await _dispose(retained)
		return
	var paid_record: Dictionary = paid_document.payload.get("cinder_beacon_session", {})
	var unpaid_record: Dictionary = unpaid_document.payload.get("cinder_beacon_session", {})
	print("BEACON_BACKUP_GENUINE_FIXTURE: ", {"paid_record": paid_record,
		"unpaid_record": unpaid_record, "live": binding.get_activity_snapshot(&"beacon_traversal")})
	var valid: bool = Beacon.validate_persistence_record(paid_record).accepted and Beacon.validate_persistence_record(unpaid_record).accepted
	_check(valid, "backup trust fixture contains actual valid paid and earned-unpaid ordered-route documents")
	if not valid:
		await _dispose(retained)
		return
	var paid_entry: Dictionary = paid_record.activities[0]
	var unpaid_entry: Dictionary = unpaid_record.activities[0]
	var generation := int(paid_entry.generation)
	var genuine: bool = (
		paid_entry.reward_granted and unpaid_entry.reward_requested and not unpaid_entry.reward_granted
		and int(unpaid_entry.generation) == generation and int(unpaid_entry.progress.next_beacon_index) == Beacon.BEACONS.size()
		and int((paid_document.payload.get("game_flow_reward_store", {}) as Dictionary).get("total_receipts", 0)) == 1
		and int((unpaid_document.payload.get("game_flow_reward_store", {}) as Dictionary).get("total_receipts", 0)) == 0
		and paid_document.payload.has("runtime_settings") and paid_document.payload.has("beacon_trust_unrelated")
		and paid_document.payload.runtime_settings == unpaid_document.payload.runtime_settings
		and paid_document.payload.beacon_trust_unrelated == unpaid_document.payload.beacon_trust_unrelated
	)
	_check(genuine,
		"real one-time payment leaves its earned-unpaid predecessor while preserving complete settings and caller inventory data")
	if not genuine:
		await _dispose(retained)
		return
	var corrupt := "corrupt newer paid Beacon primary".to_utf8_buffer()
	var staged := _write_beacon_fixture(path + ".paid-witness", paid_bytes) and _write_beacon_fixture(path, corrupt)
	_check(staged, "retained Beacon probe preserves its real paid witness and corrupts only the newer primary")
	if not staged:
		await _dispose(retained)
		return
	var preflight := UserDataStore.new(path)
	var selected := preflight.load()
	print("BEACON_BACKUP_PREFLIGHT: ", selected)
	_check(selected.accepted and preflight.get_loaded_source() == &"backup",
		"the existing store selects the genuine unpaid fallback and quarantines the corrupt newer paid primary")
	var artifacts := _beacon_recovery_artifacts(path)
	_check(artifacts.get(path + ".recovery") == corrupt, "Beacon diagnosis retains the exact corrupt-primary recovery witness")
	var before := binding.capture_beacon_traversal_session()
	var retained_receipts := _receipts(retained)
	retained.active_ship.global_position = retained.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_button(retained, 2).emit_signal("pressed")
	_button(retained, 2).emit_signal("pressed")
	print("BEACON_BACKUP_RETAINED_START: ", {"feedback": (retained.hud.get("_nearby_activity_feedback") as Label).text,
		"live": binding.capture_beacon_traversal_session(), "reward": retained.get_activity_reward_report().last_cinder_beacon_traversal_result,
		"source": shared.get_loaded_source(), "payload": shared.get_snapshot()})
	_check(binding.capture_beacon_traversal_session() == before and _receipts(retained) == retained_receipts
		and shared.get_loaded_source() == &"backup" and shared.get_snapshot() == selected.payload and _beacon_recovery_artifacts(path) == artifacts,
		"ordinary retained Start cannot begin a new Beacon generation against untrusted fallback authority")
	_button(retained, 3).emit_signal("pressed")
	if _button(retained, 3).text == "CONFIRM RESET":
		_button(retained, 3).emit_signal("pressed")
	print("BEACON_BACKUP_RETAINED_RESET: ", {"feedback": (retained.hud.get("_nearby_activity_feedback") as Label).text,
		"live": binding.capture_beacon_traversal_session(), "source": shared.get_loaded_source()})
	_check(binding.capture_beacon_traversal_session() == before and _receipts(retained) == retained_receipts
		and shared.get_snapshot() == selected.payload and _beacon_recovery_artifacts(path) == artifacts,
		"ordinary retained Reset preserves the exact paid live route, inventory, settings and recovery artifacts")
	await _dispose(retained)
	_check(_beacon_recovery_artifacts(path) == artifacts, "retained Beacon teardown leaves paid evidence and unpaid fallback for explicit repair")

	# Independent path prevents pre-fix retained controls contaminating the
	# fresh-owner/direct-authority probe of the same genuine documents.
	path += "_fresh"
	staged = _write_beacon_fixture(path + ".paid-witness", paid_bytes) \
		and _write_beacon_fixture(path, corrupt) and _write_beacon_fixture(path + ".bak", unpaid_bytes)
	_check(staged, "fresh Beacon probe stages the exact same genuine paid and earned-unpaid documents")
	if not staged:
		return
	preflight = UserDataStore.new(path)
	selected = preflight.load()
	_check(selected.accepted and preflight.get_loaded_source() == &"backup", "fresh Beacon probe selects the genuine earned-unpaid backup")
	artifacts = _beacon_recovery_artifacts(path)
	var fresh := await _game(path, UserDataFilesystem.new())
	var fresh_binding := await _binding(fresh)
	var captured := fresh_binding.capture_beacon_traversal_session()
	var ready: Dictionary = fresh.call("_ensure_cinder_beacon_session", fresh_binding)
	print("BEACON_BACKUP_FRESH_BIND: ", {"ready": ready, "captured": captured,
		"presentation": fresh_binding.get_activity_snapshot(&"beacon_traversal")})
	var fresh_entry: Dictionary = captured.activities[0]
	_check(not ready.get("accepted", false) and ready.get("reason") == &"beacon_session_store_recovery_required"
		and int(fresh_entry.generation) == 0 and int(fresh_entry.state) == Beacon.State.IDLE,
		"fresh Main cannot adopt backup-derived Beacon cursor, generation or unpaid entitlement")
	var receipts := _receipts(fresh)
	_button(fresh, 2).emit_signal("pressed")
	_button(fresh, 2).emit_signal("pressed")
	_button(fresh, 3).emit_signal("pressed")
	if _button(fresh, 3).text == "CONFIRM RESET":
		_button(fresh, 3).emit_signal("pressed")
	shared = fresh.get("_runtime_settings_user_data_store")
	print("BEACON_BACKUP_FRESH_CONTROLS: ", {"feedback": (fresh.hud.get("_nearby_activity_feedback") as Label).text,
		"captured": fresh_binding.capture_beacon_traversal_session(), "reward": fresh.get_activity_reward_report().last_cinder_beacon_traversal_result,
		"source": shared.get_loaded_source(), "payload": shared.get_snapshot()})
	_check(fresh_binding.capture_beacon_traversal_session() == captured and _receipts(fresh) == receipts
		and shared.get_snapshot() == selected.payload and _beacon_recovery_artifacts(path) == artifacts,
		"ordinary fresh Start, repeated retry and Reset leave untrusted progress, inventory, settings and receipts unchanged")
	var authority: GameFlowRewardAuthority = fresh.get("_game_flow_reward_authority")
	var request := {"activity_id": Beacon.ACTIVITY_ID, "activity_generation": generation,
		"reward_id": Beacon.REWARD_ID, "reward_authority": false, "granted": false}
	var payment := authority.commit(request)
	var payment_retry := authority.commit(request)
	print("BEACON_BACKUP_DIRECT_PAYMENT: ", {"payment": payment, "retry": payment_retry,
		"source": shared.get_loaded_source(), "payload": shared.get_snapshot(), "captured": fresh_binding.capture_beacon_traversal_session()})
	_check(not payment.accepted and payment.reason == &"reward_store_recovery_required"
		and not payment_retry.accepted and payment_retry.reason == &"reward_store_recovery_required"
		and _receipts(fresh) == receipts and shared.get_loaded_source() == &"backup" and shared.get_snapshot() == selected.payload
		and fresh_binding.capture_beacon_traversal_session() == captured and _beacon_recovery_artifacts(path) == artifacts,
		"actual Beacon authority refuses repeated payment from the genuine unpaid backup without republishing its envelope")
	await _dispose(fresh)
	_check(_beacon_recovery_artifacts(path) == artifacts, "fresh Beacon teardown preserves paid evidence, unpaid fallback and quarantine for explicit repair")

func _write_beacon_fixture(path: String, bytes: PackedByteArray) -> bool:
	var writer := FileAccess.open(path, FileAccess.WRITE)
	if writer == null:
		return false
	writer.store_buffer(bytes)
	writer.close()
	return true

func _beacon_recovery_artifacts(path: String) -> Dictionary:
	var result := {}
	for suffix: String in ["", ".bak", ".bak.1", ".bak.2", ".bak.3", ".recovery", ".tmp", ".paid-witness"]:
		if FileAccess.file_exists(path + suffix):
			result[path + suffix] = FileAccess.get_file_as_bytes(path + suffix)
	return result

## A refused reset must never publish a live reset against an older disk route.
func _reset_write_failure(paid: bool) -> void:
	var path := "user://beacon_reset_%s_%d.json" % [str(paid), Time.get_ticks_usec()]
	var fault := FaultFilesystem.new()
	fault.reject_rewards = false
	var first := await _game(path, fault)
	await _board(first)
	var binding := await _binding(first)
	first.call("_on_settings_save_requested")
	var store: UserDataStore = first.get("_runtime_settings_user_data_store")
	var seeded := store.get_snapshot()
	seeded["beacon_reset_unrelated"] = {"keep": "independent data", "value": 29}
	_check(store.commit(seeded, store.get_generation(), "unit-beacon-reset-unrelated").accepted,
		"the reset fixture persists unrelated data through the production store")
	if paid:
		await _complete(first, binding)
	else:
		first.active_ship.global_position = first.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
		_button(first, 2).emit_signal("pressed")
		first.call("_advance_cinder_beacon_traversal", 0.0, first.call("_capture_cinder_actor_sample"))
	var before := binding.capture_beacon_traversal_session()
	var visible := binding.get_activity_snapshot(&"beacon_traversal")
	var payload := store.get_snapshot()
	var bytes := FileAccess.get_file_as_bytes(path)
	var receipts := _receipts(first)
	_check(int(before.activities[0].progress.next_beacon_index) == (4 if paid else 1)
		and before.activities[0].reward_granted == paid and receipts == (1 if paid else 0),
		"the reset starts from a genuinely saved active cursor or paid completion")
	fault.reject_all = true
	_button(first, 3).emit_signal("pressed")
	if _button(first, 3).text == "CONFIRM RESET":
		_button(first, 3).emit_signal("pressed")
	_check(binding.capture_beacon_traversal_session() == before
		and binding.get_activity_snapshot(&"beacon_traversal") == visible,
		"refused Reset preserves the exact live cursor, paid acknowledgement and presentation")
	_check(FileAccess.get_file_as_bytes(path) == bytes and store.get_snapshot() == payload
		and _receipts(first) == receipts,
		"refused Reset preserves durable bytes, receipts, settings and unrelated data")
	await _dispose(first)
	var retry_fault := FaultFilesystem.new()
	retry_fault.reject_rewards = false
	var second := await _game(path, retry_fault)
	var second_binding := await _binding(second)
	_check(second_binding.capture_beacon_traversal_session() == before and _receipts(second) == receipts,
		"fresh Main restores the unchanged active or paid route after refused Reset")
	# Exercise publication with failed directory sync for the paid variant.
	retry_fault.fail_published_reset_sync = paid
	_button(second, 3).emit_signal("pressed")
	if _button(second, 3).text == "CONFIRM RESET":
		_button(second, 3).emit_signal("pressed")
	var reset := second_binding.capture_beacon_traversal_session()
	_check(int(reset.activities[0].state) == Beacon.State.RESET
		and int(reset.activities[0].generation) == int(before.activities[0].generation)
		and not reset.activities[0].reward_requested and _receipts(second) == receipts,
		"ordinary writable retry publishes RESET at the same generation, including a real postpublication sync refusal")
	var second_payload: Dictionary = second.get("_runtime_settings_user_data_store").get_snapshot()
	_check(second_payload.runtime_settings == payload.runtime_settings
		and second_payload.beacon_reset_unrelated == payload.beacon_reset_unrelated
		and second_payload.get("game_flow_reward_store") == payload.get("game_flow_reward_store"),
		"committed Reset preserves settings, unrelated data and the exact reward ledger")
	await _dispose(second)
	var third := await _game(path, UserDataFilesystem.new())
	var third_binding := await _binding(third)
	_check(third_binding.capture_beacon_traversal_session() == reset and _receipts(third) == receipts,
		"another fresh Main restores the committed same-generation RESET without new entitlement")
	third.active_ship.global_position = third.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_button(third, 2).emit_signal("pressed")
	var started := third_binding.get_activity_snapshot(&"beacon_traversal")
	_check(started.state_id == &"active" and int(started.generation) == int(before.activities[0].generation) + 1
		and _receipts(third) == receipts, "the next genuine Start advances generation exactly once after reset recovery")
	await _dispose(third)

func _reset_owner_changed() -> void:
	var path := "user://beacon_reset_reentrant_%d.json" % Time.get_ticks_usec()
	var fault := FaultFilesystem.new()
	fault.reject_rewards = false
	var game := await _game(path, fault)
	await _board(game)
	var binding := await _binding(game)
	game.active_ship.global_position = game.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_button(game, 2).emit_signal("pressed")
	game.call("_advance_cinder_beacon_traversal", 0.0, game.call("_capture_cinder_actor_sample"))
	fault.on_reset_write = func() -> void:
		binding.submit_beacon_traversal(1, Beacon.BEACONS[1])
	var result: Dictionary = game.call("_reset_nearby_activity", binding, Beacon.ACTIVITY_ID)
	var live := binding.capture_beacon_traversal_session()
	_check(not result.accepted and result.reason == &"beacon_reset_owner_changed"
		and result.persistence_result.accepted and int(live.activities[0].state) == Beacon.State.ACTIVE
		and int(live.activities[0].progress.next_beacon_index) == 2,
		"a real reset-write callback changing the live route cannot publish a stale live reset")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload.cinder_beacon_session
	_check(int(disk.activities[0].state) == Beacon.State.RESET and _receipts(game) == 0,
		"the changed-owner refusal preserves the actual published outcome without rollback or entitlement")
	var bytes := FileAccess.get_file_as_bytes(path)
	var stale_active: Dictionary = game.call("_save_cinder_beacon_session", binding, live)
	var forged := live.duplicate(true)
	var forged_entry := forged.activities[0] as Dictionary
	forged_entry.state = Beacon.State.COMPLETE
	forged_entry.reward_requested = true
	forged_entry.reward_granted = false
	forged_entry.progress.state = Beacon.State.COMPLETE
	forged_entry.progress.next_beacon_index = Beacon.BEACONS.size()
	forged_entry.progress.reward_requested = false
	var forged_terminal: Dictionary = game.call("_save_cinder_beacon_session", binding, forged)
	_check(Beacon.validate_persistence_record(forged).accepted
		and not stale_active.accepted and not forged_terminal.accepted
		and FileAccess.get_file_as_bytes(path) == bytes,
		"ordinary changed-owner recovery still rejects old ACTIVE and prospective counterfeit completion over RESET")
	var parent := binding.get_parent()
	parent.remove_child(binding)
	var retired: Dictionary = game.call("_save_cinder_beacon_session", binding)
	_check(not retired.accepted and retired.reason == &"beacon_session_owner_unavailable"
		and FileAccess.get_file_as_bytes(path) == bytes,
		"a retired streamed binding cannot restore progress over its published RESET")
	parent.add_child(binding)
	await process_frame
	game.call("_sync_activity_hud")
	fault.reject_rewards = true
	for index in range(2, Beacon.BEACONS.size()):
		game.active_ship.global_position = game.call("_cinder_authored_frame_to_world", Beacon.BEACONS[index])
		game.call("_advance_cinder_beacon_traversal", 0.0, game.call("_capture_cinder_actor_sample"))
	var earned := binding.capture_beacon_traversal_session()
	var saved: Dictionary = game.call("_save_cinder_beacon_session", binding)
	var store: UserDataStore = game.get("_runtime_settings_user_data_store")
	_check(saved.accepted and int(earned.activities[0].state) == Beacon.State.COMPLETE
		and int(earned.activities[0].generation) == int(disk.activities[0].generation)
		and store.get_snapshot().cinder_beacon_session == earned
		and fault.refused_reward and _receipts(game) == 0,
		"the exact current owner can save its genuinely completed remaining observations and retain refused payment")
	fault.reject_rewards = false
	_button(game, 2).pressed.emit()
	var paid := binding.capture_beacon_traversal_session()
	var duplicate: Dictionary = game.call("_request_cinder_beacon_traversal_reward", binding)
	_check(paid.activities[0].reward_granted and _receipts(game) == 1 and not duplicate.accepted,
		"ordinary reward retry pays this changed-owner completion once and rejects repeated payment")
	await _dispose(game)
	var cold := await _game(path, UserDataFilesystem.new())
	var cold_binding := await _binding(cold)
	_check(cold_binding.capture_beacon_traversal_session() == paid and _receipts(cold) == 1,
		"cold Main retains the actual paid changed-owner completion without replay or stranded debt")
	await _dispose(cold)

func _published_payment_retry() -> void:
	var path := "user://beacon_published_payment_%d.json" % Time.get_ticks_usec()
	var fault := FaultFilesystem.new()
	fault.reject_rewards = false
	fault.fail_published_reward_sync = true
	var game := await _game(path, fault)
	await _board(game)
	var binding := await _binding(game)
	await _complete(game, binding)
	var live := binding.get_activity_snapshot(&"beacon_traversal")
	var published: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload
	var failed: Dictionary = game.get_activity_reward_report().last_cinder_beacon_traversal_result
	_check(not live.reward_requested and published.cinder_beacon_session.activities[0].reward_granted
		and int(published.game_flow_reward_store.total_receipts) == 1
		and failed.authority_result.store_result.reason == "published_directory_sync_failed"
		and failed.authority_result.store_result.published,
		"a real postpublication sync failure leaves a paid disk receipt while the live owner reports refusal")
	_button(game, 2).emit_signal("pressed")
	var reconciled := binding.get_activity_snapshot(&"beacon_traversal")
	var store: UserDataStore = game.get("_runtime_settings_user_data_store")
	_check(reconciled.reward_requested and reconciled.reward_committed and _receipts(game) == 1
		and store.get_snapshot().cinder_beacon_session.activities[0].reward_granted,
		"ordinary Start reconciles the exact published payment without downgrading its acknowledgement or paying twice")
	_button(game, 3).emit_signal("pressed")
	game.active_ship.global_position = game.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_button(game, 2).emit_signal("pressed")
	_check(binding.get_activity_snapshot(&"beacon_traversal").generation == int(live.generation) + 1 and _receipts(game) == 1,
		"the reconciled payment permits an ordinary new generation with one durable receipt")
	await _dispose(game)
	var fresh := await _game(path, UserDataFilesystem.new())
	await _binding(fresh)
	_check(_receipts(fresh) == 1, "fresh Main after the sync failure still loads exactly one navigation-data payment")
	await _dispose(fresh)

func _all_writes_failed() -> void:
	var path := "user://beacon_unsaved_%d.json" % Time.get_ticks_usec()
	var fault := FaultFilesystem.new()
	var first := await _game(path, fault)
	await _board(first)
	var binding := await _binding(first)
	fault.reject_all = true
	await _complete(first, binding)
	_check(binding.get_activity_snapshot(&"beacon_traversal").state_id == &"complete" and _receipts(first) == 0,
		"when every write fails the live owner retains completion but grants no reward")
	await _dispose(first)
	var fresh := await _game(path, UserDataFilesystem.new())
	var fresh_binding := await _binding(fresh)
	_check(fresh_binding.get_activity_snapshot(&"beacon_traversal").state_id == &"idle" and _receipts(fresh) == 0,
		"without a valid durable terminal fresh Main safely offers a new route and no entitlement")
	await _dispose(fresh)

func _unsupported_record(path: String) -> void:
	var store := UserDataStore.new(path)
	store.load()
	var payload := store.get_snapshot()
	payload.cinder_beacon_session.schema_version = 2
	store.commit(payload, store.get_generation(), "unit-unsupported-beacon-record")
	var unsupported := JSON.parse_string(JSON.stringify(payload.cinder_beacon_session)) as Dictionary
	var fresh := await _game(path, UserDataFilesystem.new())
	await _binding(fresh)
	_button(fresh, 2).emit_signal("pressed")
	_button(fresh, 3).emit_signal("pressed")
	_check(fresh.get("_runtime_settings_user_data_store").get_snapshot().cinder_beacon_session == unsupported,
		"unsupported saved beacon data remains unchanged through ordinary Start and Reset")
	_check(fresh.call("_get_nearby_activity_binding").get_activity_snapshot(&"beacon_traversal").generation == 0
		and _receipts(fresh) == 1, "unsupported state creates neither a recovered generation nor reward entitlement")
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
	game.start_shift()
	var craft := game.get_guided_ship()
	game.player.global_position = craft.get_boarding_position()
	game.call("_board_ship", craft)
	for _tick in 300:
		if craft.is_piloted() and game.player.is_seated_at(craft.get_pilot_seat_anchor()):
			break
		await physics_frame
	_check(craft.is_piloted() and game.player.is_seated_at(craft.get_pilot_seat_anchor()), "actual production boarding supplies the beacon fixture's pilot owner")
	game.set_physics_process(false)

func _binding(game: GameFlow) -> NearbySectorActivityBinding:
	game.cinder_streaming_bootstrap.update_position(CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR)
	var binding: NearbySectorActivityBinding
	for _frame in 180:
		binding = game.call("_get_nearby_activity_binding") as NearbySectorActivityBinding
		if is_instance_valid(binding):
			break
		await process_frame
	_check(is_instance_valid(binding), "the real Cinder streaming owner supplies the beacon binding")
	game.call("_sync_activity_hud")
	return binding

func _complete(game: GameFlow, binding: NearbySectorActivityBinding) -> void:
	var craft := game.active_ship
	craft.global_position = game.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_button(game, 2).emit_signal("pressed")
	_check(binding.get_activity_snapshot(&"beacon_traversal").state_id == &"active", "ordinary HUD Start admits the actual authored beacon route")
	for point in Beacon.BEACONS:
		craft.global_position = game.call("_cinder_authored_frame_to_world", point)
		game.call("_advance_cinder_beacon_traversal", 0.0, game.call("_capture_cinder_actor_sample"))

func _button(game: GameFlow, index: int) -> Button:
	for row in (game.hud.get("_nearby_activity_rows") as VBoxContainer).get_children():
		if "cinder_debris_beacon_traversal" in str(row.name):
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
