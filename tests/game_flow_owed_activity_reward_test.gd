extends SceneTree

## A route completion whose reward receipt cannot be saved (the store rejects the
## write) stays owed. The next activity reset, start or shipyard landing retries
## it, and the adapter/authority generation fence pays it exactly once.

const MAIN_SCENE := preload("res://scenes/main.tscn")
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

	filesystem.reject_writes = true
	game.call("_on_cinder_session_completed", {"activity_generation": 4})
	game.call("_on_patrol_completed", {"generation": 3})
	game.call("_on_cinder_convoy_safely_arrived", {"activity": {"generation": 2}})
	_check(
		_receipts(game) == 0
			and not bool(game.get_activity_reward_report().get("last_result", {}).get("accepted", true)),
		"race, patrol and convoy completions are rejected while the store cannot write"
	)
	game.reset_active_activity()
	_check(_receipts(game) == 0, "a retry while the store still fails pays nothing")

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
	_finish()


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
