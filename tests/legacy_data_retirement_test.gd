extends SceneTree

const Store := preload("res://scripts/persistence/user_data_store.gd")
const Retirement := preload("res://scripts/persistence/legacy_data_retirement.gd")

const STORE_PATH := "memory://legacy-store.json"
const LEGACY_PATH := "memory://legacy.cfg"

var _assertions := 0
var _failures := PackedStringArray()


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var fail_legacy_rename := false

	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path): return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()} if bytes.size() > maximum_bytes else {"error": OK, "bytes": bytes}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if fail_legacy_rename and from_path == LEGACY_PATH: return ERR_CANT_CREATE
		if not files.has(from_path) or files.has(to_path): return ERR_CANT_CREATE
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := FakeFilesystem.new()
	filesystem.files[LEGACY_PATH] = "legacy-settings".to_utf8_buffer()
	var store := Store.new(STORE_PATH, filesystem) as UserDataStore
	store.load()
	var migration := Retirement.new(LEGACY_PATH, store, filesystem)
	var payload := {"runtime_settings": {"schema_version": 1, "values": {"graphics_profile": "high"}}}
	var migrated := migration.migrate(payload, 0, "legacy-migrate-1")
	_check(bool(migrated.accepted) and migrated.reason == &"migrated", "validated payload publishes before legacy retirement")
	_check(not filesystem.files.has(LEGACY_PATH) and filesystem.files.has(LEGACY_PATH + ".retired.bak"), "legacy bytes move to one bounded backup marker")

	var retry_fs := FakeFilesystem.new()
	retry_fs.files[LEGACY_PATH] = "retry-legacy".to_utf8_buffer()
	var retry_store := Store.new(STORE_PATH, retry_fs) as UserDataStore
	retry_store.load()
	var retry := Retirement.new(LEGACY_PATH, retry_store, retry_fs)
	retry_fs.fail_legacy_rename = true
	var failed := retry.migrate({"save": {"progress": 4}}, 0, "legacy-migrate-2")
	_check(not bool(failed.accepted) and failed.reason == &"legacy_retirement_failed" and retry_fs.files.has(LEGACY_PATH), "retirement failure preserves original bytes")
	retry_fs.fail_legacy_rename = false
	var retried := retry.migrate({"save": {"progress": 4}}, retry_store.get_generation(), "legacy-migrate-retry")
	_check(bool(retried.accepted) and retried.already_published and not retry_fs.files.has(LEGACY_PATH), "retry retires already-published migration without duplicate commit")

	var newer_fs := FakeFilesystem.new()
	newer_fs.files[LEGACY_PATH] = "newer".to_utf8_buffer()
	var newer_store := Store.new(STORE_PATH, newer_fs) as UserDataStore
	newer_store.load()
	var newer := {"schema_version": Store.SCHEMA_VERSION + 1}
	newer_fs.files[STORE_PATH] = JSON.stringify(newer).to_utf8_buffer()
	var blocked_store := Store.new(STORE_PATH, newer_fs) as UserDataStore
	var blocked_load := blocked_store.load()
	var blocked := Retirement.new(LEGACY_PATH, blocked_store, newer_fs).migrate({"safe": true}, 0, "legacy-newer")
	_check(not bool(blocked_load.accepted) and blocked_load.reason == &"newer_schema" and not bool(blocked.accepted) and blocked.reason == &"store_not_loaded", "newer store schema fails migration closed without retiring legacy bytes")

	var composed_fs := FakeFilesystem.new()
	composed_fs.files[LEGACY_PATH] = "composed-legacy".to_utf8_buffer()
	var composed_store := Store.new(STORE_PATH, composed_fs) as UserDataStore
	composed_store.load()
	composed_fs.fail_legacy_rename = true
	var composed := composed_store.migrate_legacy(LEGACY_PATH, {"save": {"progress": 9}}, "legacy-composed-1")
	_check(not bool(composed.accepted) and composed.reason == &"legacy_retirement_failed" and composed_fs.files.has(LEGACY_PATH), "store migration path preserves legacy bytes on retirement failure")
	composed_fs.fail_legacy_rename = false
	var composed_retry := composed_store.migrate_legacy(LEGACY_PATH, {"save": {"progress": 9}}, "legacy-composed-retry")
	_check(bool(composed_retry.accepted) and composed_retry.already_published and not composed_fs.files.has(LEGACY_PATH), "store migration path retries retirement without duplicate publish")
	_finish()


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("LEGACY_DATA_RETIREMENT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		printerr("LEGACY_DATA_RETIREMENT_TEST_FAILED: ", _failures.size(), "/", _assertions)
		quit(1)
