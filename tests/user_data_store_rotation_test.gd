extends SceneTree

## Save rotation and corruption fallback: a truncated save plus a truncated
## backup load the newest good rotated copy instead of failing, the confirmed
## repair commit publishes from it, and rotation never grows beyond its depth.

const Store := preload("res://scripts/persistence/user_data_store.gd")

const PATH := "memory://rotation_profile.json"

var _failures := PackedStringArray()
var _assertions := 0


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var remove_failures: Dictionary = {}

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
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if int(remove_failures.get(path, 0)) > 0:
			remove_failures[path] = int(remove_failures[path]) - 1
			return ERR_CANT_CREATE
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
	call_deferred("_run")


func _run() -> void:
	_test_rotation_keeps_bounded_history()
	_test_truncated_save_and_backup_fall_back_to_rotated_copy()
	_test_failed_commit_does_not_duplicate_history()
	_test_everything_corrupt_still_fails_closed()
	_finish()


func _commit_generations(filesystem: FakeFilesystem, count: int) -> UserDataStore:
	var store := Store.new(PATH, filesystem) as UserDataStore
	store.load()
	for generation in range(1, count + 1):
		var result := store.commit({"credits": generation * 100}, generation - 1, "commit-%03d" % generation)
		_check(bool(result.accepted), "commit %d succeeds" % generation)
	return store


func _generation_of(filesystem: FakeFilesystem, path: String) -> int:
	if not filesystem.files.has(path):
		return -1
	var parsed: Variant = JSON.parse_string((filesystem.files[path] as PackedByteArray).get_string_from_utf8())
	return int((parsed as Dictionary).get("generation", -1)) if parsed is Dictionary else -1


func _test_rotation_keeps_bounded_history() -> void:
	var filesystem := FakeFilesystem.new()
	_commit_generations(filesystem, 6)
	_check(_generation_of(filesystem, PATH) == 6, "primary holds the newest generation")
	_check(_generation_of(filesystem, PATH + ".bak") == 5, ".bak holds the previous generation")
	_check(
		_generation_of(filesystem, PATH + ".bak.1") == 4
		and _generation_of(filesystem, PATH + ".bak.2") == 3
		and _generation_of(filesystem, PATH + ".bak.3") == 2,
		"three older generations rotate newest-first behind .bak"
	)
	_check(not filesystem.files.has(PATH + ".bak.4"), "rotation never exceeds HISTORY_DEPTH")
	_check(not filesystem.files.has(PATH + ".tmp"), "rotation leaves no staged temp")


func _test_truncated_save_and_backup_fall_back_to_rotated_copy() -> void:
	var filesystem := FakeFilesystem.new()
	_commit_generations(filesystem, 5)
	var primary_bytes := filesystem.files[PATH] as PackedByteArray
	filesystem.files[PATH] = primary_bytes.slice(0, primary_bytes.size() / 2)
	filesystem.files[PATH + ".bak"] = "{\"schema_version\": 1, \"gen".to_utf8_buffer()
	var store := Store.new(PATH, filesystem) as UserDataStore
	var loaded := store.load()
	_check(bool(loaded.accepted), "a truncated save and backup no longer fail the load")
	_check(loaded.reason == &"primary_invalid_backup_loaded" and loaded.source == &"backup", "the fallback reports as a backup recovery so existing repair guards apply")
	_check(loaded.get("fallback", &"") == &"rotated_history" and int(loaded.get("history_index", 0)) == 1, "the newest rotated copy is the one loaded")
	_check(int(loaded.generation) == 3 and float(store.get_snapshot().credits) == 300.0, "the loaded progress is the newest good generation")
	_check(store.get_loaded_history_index() == 1, "the store remembers which rotated copy it loaded")
	_check(filesystem.files.has(PATH + ".recovery"), "the damaged primary bytes are quarantined for support")
	var repaired := store.commit(store.get_snapshot(), 3, "repair-from-history")
	_check(bool(repaired.accepted) and int(repaired.generation) == 4, "a confirmed repair commit publishes from the rotated copy")
	var reloaded := Store.new(PATH, filesystem).load()
	_check(bool(reloaded.accepted) and reloaded.source == &"primary" and int(reloaded.generation) == 4, "the next launch loads the repaired primary normally")
	var next := Store.new(PATH, filesystem) as UserDataStore
	next.load()
	_check(bool(next.commit({"credits": 999}, 4, "after-repair").accepted), "ordinary saves resume after the repair")


func _test_failed_commit_does_not_duplicate_history() -> void:
	var filesystem := FakeFilesystem.new()
	var store := _commit_generations(filesystem, 3)
	var backup_before := (filesystem.files[PATH + ".bak"] as PackedByteArray).duplicate()
	filesystem.remove_failures[PATH + ".bak"] = 1
	var failed := store.commit({"credits": 1}, 3, "commit-004")
	_check(not bool(failed.accepted) and failed.reason == &"backup_cleanup_failed", "a backup cleanup failure still fails the commit")
	_check(filesystem.files[PATH + ".bak"] == backup_before, "a failed commit keeps .bak exactly")
	var retried := store.commit({"credits": 1}, 3, "commit-004")
	_check(bool(retried.accepted), "the retried commit succeeds")
	_check(
		_generation_of(filesystem, PATH + ".bak.1") == 2
		and _generation_of(filesystem, PATH + ".bak.2") == 1
		and not filesystem.files.has(PATH + ".bak.3"),
		"the retry does not rotate the same backup into history twice"
	)


func _test_everything_corrupt_still_fails_closed() -> void:
	var filesystem := FakeFilesystem.new()
	_commit_generations(filesystem, 5)
	for path: String in [PATH, PATH + ".bak", PATH + ".bak.1", PATH + ".bak.2", PATH + ".bak.3"]:
		filesystem.files[path] = "[truncated".to_utf8_buffer()
	var loaded := Store.new(PATH, filesystem).load()
	_check(not bool(loaded.accepted) and loaded.reason == &"no_valid_document", "with no valid copy anywhere the load still fails closed")


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("USER_DATA_STORE_ROTATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("USER_DATA_STORE_ROTATION_TEST_FAILED: %d/%d assertions failed" % [_failures.size(), _assertions])
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
