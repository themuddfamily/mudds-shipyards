extends SceneTree

## A route completion whose reward receipt cannot be saved (the store rejects the
## write) stays owed. The next activity reset, start or shipyard landing retries
## it, and the adapter/authority generation fence pays it exactly once.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Beacon := preload("res://scripts/world/cinder_beacon_traversal_activity.gd")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "memory://owed-activity-reward-settings.json"

var _assertions := 0
var _failures: Array[String] = []


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var reject_writes := false

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
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if reject_writes:
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
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


## Reject a real reward write, then freeze once the terminal race is published.
## Its record is produced and saved by the live route, never authored here.
class InterruptedRewardFilesystem extends UserDataFilesystem:
	var stopped := false
	var interrupt_rewards := true
	var reward_rejected := false
	var terminal_staged := false
	var stage_reward_before_refusal := false

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if stopped:
			return ERR_UNAVAILABLE
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if interrupt_rewards and document is Dictionary and str(
			(document.get("commit", {}) as Dictionary).get("id", "")
		).begins_with("game-flow-reward-"):
			if stage_reward_before_refusal:
				var staged := super.write_bytes_and_flush(path, bytes)
				if staged != OK:
					return staged
			reward_rejected = true
			stopped = terminal_staged
			return ERR_UNAVAILABLE
		if document is Dictionary and path.ends_with(".tmp"):
			var slot: Dictionary = (document.get("payload", {}) as Dictionary).get("cinder_timed_race_session", {})
			if slot.get("activities") is Array and not slot.activities.is_empty():
				terminal_staged = int((slot.activities[0] as Dictionary).get("state", -1)) == TimedCheckpointRace.State.COMPLETED
		return super.write_bytes_and_flush(path, bytes)

	func remove_path(path: String) -> Error:
		return ERR_UNAVAILABLE if stopped else super.remove_path(path)

	func rename_path(from_path: String, to_path: String) -> Error:
		if stopped:
			return ERR_UNAVAILABLE
		var result := super.rename_path(from_path, to_path)
		if result == OK and from_path.ends_with(".tmp") and terminal_staged and reward_rejected and interrupt_rewards:
			stopped = true
		return result


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem) as UserDataStore
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(
		store, "memory://owed-activity-reward-legacy.cfg"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		bool(game.get_activity_reward_report().get("configured", false))
			and _receipts(game) == 0,
		"production Main configures its reward authority over the isolated store"
	)

	game.set_physics_process(false)
	var craft := game.get_flyable_ships()[1] as HeroShip
	game.active_ship = craft
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.request_activity_start(ROUTE.activity_id)
	game.call("_physics_process", 2.0)
	game.call("_physics_process", 1.0)
	for checkpoint in ROUTE.get_checkpoint_count():
		filesystem.reject_writes = checkpoint == ROUTE.get_checkpoint_count() - 1
		craft.global_position = ROUTE.get_checkpoint_position(checkpoint)
		game.call("_physics_process", 0.0)
	_check(game.get_active_activity_snapshot().get("state_id") == &"completed" and _receipts(game) == 0,
		"a live race terminal-save failure grants no receipt before its durable handoff exists")
	_complete_unrelated_convoy(game, true)
	_check(
		_receipts(game) == 0
			and not bool(game.get_activity_reward_report().get("last_result", {}).get("accepted", true)),
		"real race and durable convoy reward handoffs remain unpaid while reward writes fail"
	)
	game.reset_active_activity()
	_check(_receipts(game) == 0 and game.get_active_activity_snapshot().get("state_id") == &"completed", "a retry while the store still fails pays nothing and preserves the completed owner")

	filesystem.reject_writes = false
	game.reset_active_activity()
	var counts := _reward_counts(game)
	_check(
		_receipts(game) == 2
			and int(counts.get("return_race_record_to_shipyard", 0)) == 1
			and int(counts.get("return_convoy_credit_to_shipyard", 0)) == 1,
		"the next activity reset pays each owed reward once after the store recovers (%s)" % counts
	)
	game.reset_active_activity()
	_check(_receipts(game) == 2, "later retries and a replayed completion never pay twice")

	game.queue_free()
	await process_frame
	await process_frame
	await _test_completed_race_reward_crash()
	await _test_beacon_reset_preserves_owed_reward()
	_finish()


func _test_completed_race_reward_crash() -> void:
	var path := "user://race_reward_interruption_%d.json" % Time.get_ticks_usec()
	var filesystem := InterruptedRewardFilesystem.new()
	var store := Store.new(path, filesystem) as UserDataStore
	var first := await _make_disk_game(store)
	first.set_physics_process(false)
	first.call("_on_settings_save_requested")
	var craft := first.get_flyable_ships()[1] as HeroShip
	first.active_ship = craft
	first.set("_piloting", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	var started := first.request_activity_start(ROUTE.activity_id)
	first.call("_physics_process", 2.0)
	first.call("_physics_process", 1.0)
	for checkpoint in ROUTE.get_checkpoint_count():
		craft.global_position = ROUTE.get_checkpoint_position(checkpoint)
		first.call("_physics_process", 0.0)
	_check(bool(started.accepted) and filesystem.stopped
		and first.get_active_activity_snapshot().get("state_id") == &"completed"
		and _receipts(first) == 0,
		"a live race retains its terminal result when reward publication fails (stopped=%s, rejected=%s, receipts=%d)" % [filesystem.stopped, filesystem.reward_rejected, _receipts(first)])
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(int(((saved.payload.cinder_timed_race_session as Dictionary).activities[0] as Dictionary).state)
		== TimedCheckpointRace.State.COMPLETED,
		"the interrupted profile contains the production terminal race on real disk")
	# The original filesystem remains frozen through teardown; no clean-exit or
	# detached scene write may repair the interrupted profile.
	first.queue_free()
	await process_frame
	await process_frame
	var retry_filesystem := InterruptedRewardFilesystem.new()
	var second_store := Store.new(path, retry_filesystem) as UserDataStore
	var second := await _make_disk_game(second_store)
	_check(second.get_active_activity_snapshot().get("state_id") == &"completed"
		and _receipts(second) == 0 and retry_filesystem.reward_rejected,
		"fresh Main retries the saved unpaid race while reward writes still fail (state=%s receipts=%d rejected=%s reason=%s)" % [second.get_active_activity_snapshot().get("state_id"), _receipts(second), retry_filesystem.reward_rejected, second.get_activity_reward_report().get("last_result", {}).get("reason")])
	_check(not second.reset_active_activity() and second.get_active_activity_snapshot().get("state_id") == &"completed",
		"an unpaid terminal race cannot be reset over its pending recovery record")
	retry_filesystem.interrupt_rewards = false
	retry_filesystem.stopped = false
	second.call("_retry_owed_game_flow_activity_rewards")
	var acknowledgement := (second_store.get_snapshot().cinder_timed_race_session.activities[0] as Dictionary)
	_check(_receipts(second) == 1 and acknowledgement.reward_requested and acknowledgement.reward_granted,
		"the existing owed retry publishes receipt and terminal acknowledgement together")
	second.save_cinder_race_session()
	_check(bool((second_store.get_snapshot().cinder_timed_race_session.activities[0] as Dictionary).reward_granted),
		"ordinary terminal saves preserve the paid acknowledgement")
	# An independent live convoy model produces the unrelated completion. This
	# exercises the reward handoff boundary, not a physical convoy journey.
	_complete_unrelated_convoy(second)
	_check(_receipts(second) == 2,
		"an unrelated valid reward handoff becomes the latest durable receipt")
	second.queue_free()
	await process_frame
	await process_frame
	var staged_filesystem := InterruptedRewardFilesystem.new()
	staged_filesystem.interrupt_rewards = false
	var third := await _make_disk_game(Store.new(path, staged_filesystem))
	third.call("_on_cinder_session_completed", third.get_active_activity_snapshot())
	_check(_receipts(third) == 2 and int(_reward_counts(third).get("return_race_record_to_shipyard", 0)) == 1,
		"fresh Main and a repeated completion never repay the race after another receipt becomes latest")
	third.set_physics_process(false)
	var third_craft := third.get_flyable_ships()[1] as HeroShip
	third.active_ship = third_craft
	third.set("_piloting", true)
	third.phase = GameFlow.Phase.FREE_FLIGHT
	var previous_generation := int(third.get_active_activity_snapshot().get("activity_generation", 0))
	_check(third.reset_active_activity(), "a paid race resets through its existing owner")
	var third_store := third.get("_runtime_settings_user_data_store") as UserDataStore
	var fresh_marker := (third_store.get_snapshot().cinder_timed_race_session.activities[0] as Dictionary)
	_check(not fresh_marker.reward_requested and not fresh_marker.reward_granted,
		"the next valid race generation inherits no terminal reward acknowledgement")
	staged_filesystem.stage_reward_before_refusal = true
	third.request_activity_start(ROUTE.activity_id)
	third.call("_physics_process", 2.0)
	third.call("_physics_process", 1.0)
	for checkpoint in ROUTE.get_checkpoint_count():
		staged_filesystem.interrupt_rewards = checkpoint == ROUTE.get_checkpoint_count() - 1
		third_craft.global_position = ROUTE.get_checkpoint_position(checkpoint)
		third.call("_physics_process", 0.0)
	_check(_receipts(third) == 2 and FileAccess.file_exists(path + ".tmp"),
		"interrupted receipt publication leaves its real staged receipt and acknowledgement together")
	staged_filesystem.interrupt_rewards = false
	staged_filesystem.stopped = false
	third.call("_on_settings_save_requested")
	third.call("_retry_owed_game_flow_activity_rewards")
	var stale := third.call("_commit_game_flow_activity_reward", {
		"activity_id": ROUTE.activity_id, "activity_generation": previous_generation,
		"reward_id": &"return_race_record_to_shipyard", "reward_authority": false, "granted": false,
	}) as Dictionary
	_check(_receipts(third) == 3 and int(_reward_counts(third).get("return_race_record_to_shipyard", 0)) == 2
		and not bool(stale.accepted) and stale.reason == &"reward_generation_mismatch",
		"a fresh live race pays once and rejects the old completion generation")
	_check(third.reset_active_activity(),
		"rolling forward a staged paid receipt resolves the existing owed retry and permits reset")
	third.queue_free()
	await process_frame
	await process_frame


func _test_beacon_reset_preserves_owed_reward() -> void:
	var path := "user://beacon_owed_reward_%d.json" % Time.get_ticks_usec()
	var filesystem := InterruptedRewardFilesystem.new()
	var game := await _make_disk_game(Store.new(path, filesystem))
	game.start_shift()
	var craft := game.get_guided_ship()
	game.player.global_position = craft.get_boarding_position()
	game.call("_board_ship", craft)
	for _tick in 300:
		if game.player.is_seated_at(craft.get_pilot_seat_anchor()) and craft.is_piloted():
			break
		await physics_frame
	_check(game.player.is_seated_at(craft.get_pilot_seat_anchor()) and craft.is_piloted(),
		"beacon reward fixture boards the real production pilot owner")
	game.set_physics_process(false)
	var binding := await _load_beacon_binding(game)
	if not is_instance_valid(binding):
		game.queue_free()
		await process_frame
		return
	craft.global_position = game.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_beacon_button(game, 2).emit_signal("pressed")
	var started := binding.get_activity_snapshot(&"beacon_traversal")
	_check(started.state_id == &"active", "ordinary HUD Start begins the authored beacon route")
	for point in Beacon.BEACONS:
		craft.global_position = game.call("_cinder_authored_frame_to_world", point)
		game.call("_advance_cinder_beacon_traversal", 0.0, game.call("_capture_cinder_actor_sample"))
	var completed := binding.get_activity_snapshot(&"beacon_traversal")
	var generation := int(completed.get("generation", 0))
	_check(completed.state_id == &"complete" and not completed.reward_requested
		and filesystem.reward_rejected and _receipts(game) == 0,
		"ordered production ship samples complete the route but a real reward write fails")
	_check(bool(completed.get("reward_pending", false))
		and (_beacon_button(game, 2).get_parent().get_child(0) as Label).text.contains("REWARD PENDING"),
		"the rejected beacon reward stays visibly pending in its retained HUD row")
	_beacon_button(game, 3).emit_signal("pressed")
	# An unpaid completion may request the normal reset confirmation first.
	if _beacon_button(game, 3).text == "CONFIRM RESET":
		_beacon_button(game, 3).emit_signal("pressed")
	var after_reset := binding.get_activity_snapshot(&"beacon_traversal")
	_check(after_reset.state_id == &"complete" and int(after_reset.generation) == generation
		and int(after_reset.next_beacon_index) == Beacon.BEACONS.size() and _receipts(game) == 0,
		"ordinary HUD Reset cannot discard the unpaid completion or ordered progress")
	var direct_start := binding.start_beacon_traversal(Beacon.BEACONS[0])
	_check(not bool(direct_start.accepted)
		and int(binding.get_activity_snapshot(&"beacon_traversal").generation) == generation,
		"the existing binding owner also refuses a new run over its unpaid completion")
	if after_reset.state_id != &"complete":
		game.queue_free()
		await process_frame
		await process_frame
		return
	_beacon_button(game, 2).emit_signal("pressed")
	_check(binding.get_activity_snapshot(&"beacon_traversal").state_id == &"complete"
		and _receipts(game) == 0,
		"Start retries the same legitimate reward while storage still refuses it")
	filesystem.interrupt_rewards = false
	_beacon_button(game, 2).emit_signal("pressed")
	var paid := binding.get_activity_snapshot(&"beacon_traversal")
	_check(paid.reward_requested and paid.reward_committed and not paid.reward_pending
		and int(paid.generation) == generation and _receipts(game) == 1
		and int(_reward_counts(game).get(String(Beacon.REWARD_ID), 0)) == 1,
		"restored storage lets Start pay the same beacon completion exactly once")
	binding.request_beacon_traversal_reward()
	_check(_receipts(game) == 1, "repeated reward requests never repay the completed beacon route")
	_beacon_button(game, 3).emit_signal("pressed")
	craft.global_position = game.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
	_beacon_button(game, 2).emit_signal("pressed")
	var next_run := binding.get_activity_snapshot(&"beacon_traversal")
	var stale := binding.request_beacon_traversal_reward()
	_check(next_run.state_id == &"active" and int(next_run.generation) == generation + 1
		and not bool(stale.accepted)
		and binding.get_activity_snapshot(&"beacon_traversal").next_beacon_index == 0
		and _receipts(game) == 1,
		"paid Reset permits a new generation and the old terminal retry cannot alter it")
	game.queue_free()
	await process_frame
	await process_frame
	var fresh := await _make_disk_game(Store.new(path, UserDataFilesystem.new()))
	fresh.set_physics_process(false)
	var fresh_binding := await _load_beacon_binding(fresh)
	_check(_receipts(fresh) == 1
		and int(_reward_counts(fresh).get(String(Beacon.REWARD_ID), 0)) == 1,
		"fresh Main loads the one paid navigation-data receipt from real disk")
	if is_instance_valid(fresh_binding):
		fresh.active_ship.global_position = fresh.call("_cinder_authored_frame_to_world", Beacon.BEACONS[0])
		_beacon_button(fresh, 2).emit_signal("pressed")
		_check(fresh_binding.get_activity_snapshot(&"beacon_traversal").state_id == &"active"
			and _receipts(fresh) == 1,
			"fresh Main can start a new beacon run without losing its paid progress")
	fresh.queue_free()
	await process_frame
	await process_frame


func _load_beacon_binding(game: GameFlow) -> NearbySectorActivityBinding:
	game.cinder_streaming_bootstrap.update_position(CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR)
	var binding: NearbySectorActivityBinding
	for _frame in 180:
		binding = game.call("_get_nearby_activity_binding") as NearbySectorActivityBinding
		if is_instance_valid(binding):
			break
		await process_frame
	_check(is_instance_valid(binding), "production streaming loads the real Cinder beacon owner")
	game.call("_sync_activity_hud")
	return binding


func _beacon_button(game: GameFlow, index: int) -> Button:
	var rows := game.hud.get("_nearby_activity_rows") as VBoxContainer
	for row in rows.get_children():
		if "cinder_debris_beacon_traversal" in str(row.name):
			return row.get_child(index) as Button
	return null


func _make_disk_game(store: UserDataStore) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(store)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	return game


func _complete_unrelated_convoy(game: GameFlow, reject_reward: bool = false) -> void:
	# Bounded typed-host/codec handoff, not a streamed combat journey. The actual
	# movement owner publishes its terminal before the ordinary reward callback.
	var store := game.get("_runtime_settings_user_data_store") as UserDataStore
	var persistence := CinderConvoySessionPersistence.new()
	persistence.configure(store, &"cinder_convoy_session")
	var convoy := CinderConvoyEscortHost.new()
	root.add_child(convoy)
	var filesystem := store.get("_filesystem") as UserDataFilesystem
	if reject_reward:
		filesystem.set("reject_writes", false)
	convoy.convoy_safely_arrived.connect(func(snapshot: Dictionary) -> void:
		var saved := persistence.save(convoy, &"torrent", "unit-live-convoy-terminal")
		_check(bool(saved.get("accepted", false)), "the genuine convoy terminal is durable before its reward handoff")
		if reject_reward:
			filesystem.set("reject_writes", true)
		game.call("_on_cinder_convoy_safely_arrived", snapshot)
	)
	convoy.start(convoy.get_generation())
	var budget := 60
	while budget > 0 and convoy.get_snapshot().activity.state_id == &"active":
		convoy.advance_physics(0.25, convoy.get_snapshot().entity_position as Vector3, convoy.get_generation())
		if convoy.get_snapshot().activity.state_id == &"active":
			persistence.save(convoy, &"torrent", "unit-live-convoy-progress-%d" % budget)
		budget -= 1
	_check(budget > 0 and convoy.get_snapshot().activity.state_id == &"completed",
		"the unrelated receipt comes from an exact completed convoy host and codec")
	if not reject_reward:
		var retired := persistence.retire(convoy, "unit-convoy-explicit-retirement")
		_check(bool(retired.get("accepted", false)), "the paid model fixture explicitly retires its convoy slot")
	convoy.free()


func _record(game: GameFlow) -> Dictionary:
	return (game.get_activity_reward_report().get("authority", {}) as Dictionary).get(
		"record", {}
	) as Dictionary


func _receipts(game: GameFlow) -> int:
	return int(_record(game).get("total_receipts", -1))


func _reward_counts(game: GameFlow) -> Dictionary:
	return _record(game).get("reward_counts", {}) as Dictionary


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_FLOW_OWED_ACTIVITY_REWARD_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("GAME_FLOW_OWED_ACTIVITY_REWARD_TEST_FAILED: ", "; ".join(_failures))
	quit(1)
