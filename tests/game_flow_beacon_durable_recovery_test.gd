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
	await _published_payment_retry()
	await _all_writes_failed()
	await _unsupported_record(path)
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("GAME_FLOW_BEACON_DURABLE_RECOVERY_TEST_OK: %d assertions" % _checks)
	quit(0 if _failures.is_empty() else 1)

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
