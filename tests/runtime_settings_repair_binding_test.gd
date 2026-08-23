extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Binding := preload("res://scripts/persistence/runtime_settings_repair_binding.gd")

const PATH := "memory://repair-settings.json"
var _assertions := 0
var _failures: PackedStringArray = []


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var fail_writes := false
	var sync_directory_calls := 0
	var fail_sync_directory_on_call := -1

	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func sync_file(_path: String) -> Error: return OK
	func sync_directory(_path: String) -> Error:
		sync_directory_calls += 1
		if sync_directory_calls == fail_sync_directory_on_call: return ERR_FILE_CANT_WRITE
		return OK
	func read_bytes(path: String, maximum: int) -> Dictionary:
		if not files.has(path): return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum: return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if fail_writes: return ERR_FILE_CANT_WRITE
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		if files.has(to_path): return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path); return OK


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fs := FakeFilesystem.new()
	var seed_settings := Settings.new("memory://repair-legacy.cfg")
	var seed_store := Store.new(PATH, fs)
	seed_store.load()
	var seed_payload := {Adapter.SETTINGS_PAYLOAD_KEY: seed_settings.to_user_data_payload(), "foreign": {"keep": true}}
	seed_store.commit(seed_payload, 0, "repair-seed-001")
	seed_settings.camera_fov = 84.0
	seed_payload[Adapter.SETTINGS_PAYLOAD_KEY] = seed_settings.to_user_data_payload()
	seed_store.commit(seed_payload, 1, "repair-seed-002")
	var corrupt_primary := (fs.files[PATH] as PackedByteArray).duplicate()
	fs.files[PATH] = "{corrupt".to_utf8_buffer()
	var settings := Settings.new("memory://repair-legacy.cfg")
	var store := Store.new(PATH, fs)
	var adapter := Adapter.new(settings, store, "memory://repair-legacy.cfg")
	var loaded := adapter.load()
	_check(bool(loaded.accepted) and loaded.store_reason == &"primary_invalid_backup_loaded", "adapter exposes verified backup recovery without applying unrelated authority")
	var binding := Binding.new()
	_check(bool(binding.configure(adapter, store).accepted), "repair binding configures with existing adapter/store authorities")
	var inspected := binding.inspect(loaded)
	_check(bool(inspected.accepted) and inspected.kind == &"promote_verified_backup", "inspect offers only explicit verified-backup promotion")
	var token := str(inspected.confirmation)
	_check(bool(binding.prepare(token, "repair-commit-001").accepted), "exact confirmation prepares a frozen repair plan")
	var committed := binding.commit(token)
	_check(bool(committed.accepted) and committed.reason == &"repair_committed", "caller commit promotes through atomic store transaction")
	_check(fs.files[PATH] != corrupt_primary and store.get_snapshot().foreign.keep, "repair preserves unrelated payload and replaces corrupt primary")
	_check(not bool(binding.commit(token).accepted) and binding.get_report().last_status.reason == &"replay_rejected", "confirmation cannot be replayed")
	var newer_fs := FakeFilesystem.new()
	var newer_store := Store.new("memory://newer.json", newer_fs)
	newer_store.load()
	newer_store.commit({Adapter.SETTINGS_PAYLOAD_KEY: {"schema_version": Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION + 1, "values": {}}}, 0, "future-001")
	var newer_adapter := Adapter.new(Settings.new("memory://newer.cfg"), Store.new("memory://newer.json", newer_fs), "memory://newer.cfg")
	var newer_load := newer_adapter.load()
	var newer_binding := Binding.new()
	newer_binding.configure(newer_adapter, newer_store)
	_check(not bool(newer_binding.inspect(newer_load).accepted) and newer_binding.get_report().last_status.reason == &"unsupported_newer_schema", "unsupported newer schema remains fail-closed")
	var retry_fs := FakeFilesystem.new()
	var retry_seed := Store.new("memory://retry.json", retry_fs)
	retry_seed.load(); retry_seed.commit(seed_payload, 0, "retry-001"); retry_seed.commit(seed_payload, 1, "retry-002")
	retry_fs.files["memory://retry.json"] = "{corrupt".to_utf8_buffer()
	var retry_store := Store.new("memory://retry.json", retry_fs)
	var retry_adapter := Adapter.new(Settings.new("memory://retry.cfg"), retry_store, "memory://retry.cfg")
	var retry_load := retry_adapter.load()
	var retry_binding := Binding.new(); retry_binding.configure(retry_adapter, retry_store)
	var retry_token := str(retry_binding.inspect(retry_load).confirmation)
	retry_binding.prepare(retry_token, "retry-commit-001")
	retry_fs.fail_writes = true
	var failed := retry_binding.commit(retry_token)
	_check(not bool(failed.accepted) and bool(failed.repair_retryable), "atomic write failure remains caller-visible and retryable")
	retry_fs.fail_writes = false
	retry_fs.fail_sync_directory_on_call = retry_fs.sync_directory_calls + 2
	var ambiguous := retry_binding.commit(retry_token)
	var ambiguous_report := retry_binding.get_report()
	_check(
		not bool(ambiguous.accepted)
		and ambiguous.reason == &"published_directory_sync_failed"
		and not bool(ambiguous.repair_retryable)
		and bool(ambiguous.repair_authority_cleared)
		and bool((ambiguous.repair_reconciliation as Dictionary).accepted)
		and int(retry_store.get_generation()) == 2
		and not bool(ambiguous_report.prepared),
		"published directory-sync ambiguity reloads visible authority and clears retry permission"
	)
	retry_binding.set_attached(false)
	_check(not bool(retry_binding.commit(retry_token).accepted), "detached binding rejects pending repair")
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty(): print("RUNTIME_SETTINGS_REPAIR_BINDING_TEST_OK: %d assertions" % _assertions)
	else:
		for failure in _failures: push_error(failure)
		print("RUNTIME_SETTINGS_REPAIR_BINDING_TEST_FAILED: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
