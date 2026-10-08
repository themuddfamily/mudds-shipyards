extends SceneTree

## A route completion whose reward receipt cannot be saved (the store rejects the
## write) stays owed. The next activity reset, start or shipyard landing retries
## it, and the adapter/authority generation fence pays it exactly once.

const MAIN_SCENE := preload("res://scenes/main.tscn")
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
	game.call("_on_patrol_completed", {"generation": 3})
	game.call("_on_cinder_convoy_safely_arrived", {"activity": {"generation": 2}})
	_check(
		_receipts(game) == 0
			and not bool(game.get_activity_reward_report().get("last_result", {}).get("accepted", true)),
		"race, patrol and convoy completions are rejected while the store cannot write"
	)
	game.reset_active_activity()
	_check(_receipts(game) == 0 and game.get_active_activity_snapshot().get("state_id") == &"completed", "a retry while the store still fails pays nothing and preserves the completed owner")

	filesystem.reject_writes = false
	game.reset_active_activity()
	var counts := _reward_counts(game)
	_check(
		_receipts(game) == 3
			and int(counts.get("return_race_record_to_shipyard", 0)) == 1
			and int(counts.get("return_patrol_log_to_shipyard", 0)) == 1
			and int(counts.get("return_convoy_credit_to_shipyard", 0)) == 1,
		"the next activity reset pays each owed reward once after the store recovers (%s)" % counts
	)
	game.reset_active_activity()
	game.call("_on_patrol_completed", {"generation": 3})
	_check(_receipts(game) == 3, "later retries and a replayed completion never pay twice")

	game.queue_free()
	await process_frame
	await process_frame
	await _test_completed_race_reward_crash()
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
	# Bounded reward-handoff boundary: this valid unrelated request is not a
	# claimed physical patrol journey. Its actual receipt replaces last_receipt.
	second.call("_on_patrol_completed", {"generation": 7})
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


func _make_disk_game(store: UserDataStore) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(store)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	return game


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
