extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")

const PATH := "memory://game-flow-repair.json"
var _assertions := 0
var _failures: PackedStringArray = []


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func sync_file(_path: String) -> Error: return OK
	func sync_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum: int) -> Dictionary:
		if not files.has(path): return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum: return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
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
	var filesystem := FakeFilesystem.new()
	var seed := Settings.new("memory://game-flow-repair.cfg")
	var seed_store := Store.new(PATH, filesystem)
	seed_store.load()
	var payload := {Adapter.SETTINGS_PAYLOAD_KEY: seed.to_user_data_payload(), "foreign": {"keep": "yes"}}
	seed_store.commit(payload, 0, "flow-seed-001")
	seed.camera_fov = 83.0
	payload[Adapter.SETTINGS_PAYLOAD_KEY] = seed.to_user_data_payload()
	seed_store.commit(payload, 1, "flow-seed-002")
	filesystem.files[PATH] = "{corrupt".to_utf8_buffer()
	var flow := GameFlowType.new()
	var store := Store.new(PATH, filesystem)
	_check(flow.configure_runtime_settings_persistence(store, "memory://game-flow-repair.cfg"), "GameFlow accepts isolated repair store before startup")
	flow._initialize_runtime_settings()
	var inspected := flow.inspect_runtime_settings_repair()
	_check(bool(inspected.get("accepted", false)) and inspected.get("kind") == &"promote_verified_backup", "GameFlow exposes explicit verified-backup inspection")
	var token := str(inspected.get("confirmation", ""))
	_check(bool(flow.prepare_runtime_settings_repair(token, "flow-repair-001").get("accepted", false)), "GameFlow prepares only with exact confirmation token")
	flow._exit_tree()
	_check(not bool(flow.inspect_runtime_settings_repair(_forged_backup_status(store.get_generation())).get("accepted", false)), "GameFlow rejects repair inspection while its persistence binding is detached")
	_check(not bool(flow.commit_runtime_settings_repair(token).get("accepted", false)), "GameFlow clears a prepared repair when its owning lifecycle detaches")
	# Mirrors the single binding operation performed by
	# _restore_runtime_bindings_after_reentry without starting the full Main scene.
	flow._runtime_settings_repair_binding.set_attached(true)
	_check(not bool(flow.prepare_runtime_settings_repair(token, "flow-repair-stale").get("accepted", false)), "GameFlow re-entry requires a fresh inspection before prepare")
	var reentered := flow.inspect_runtime_settings_repair({
		"accepted": true,
		"reason": &"loaded",
		"store_reason": &"primary_loaded",
		"generation": store.get_generation(),
	})
	_check(bool(reentered.get("accepted", false)) and reentered.get("kind") == &"promote_verified_backup", "GameFlow re-entry reuses only its retained verified-backup startup receipt")
	token = str(reentered.get("confirmation", ""))
	_check(bool(flow.prepare_runtime_settings_repair(token, "flow-repair-001").get("accepted", false)), "GameFlow re-entry prepares from the fresh retained-receipt inspection")
	var committed := flow.commit_runtime_settings_repair(token)
	_check(bool(committed.get("accepted", false)) and committed.get("reason") == &"repair_committed", "GameFlow commits repair through existing store transaction")
	_check(bool((store.get_snapshot().get("foreign", {}) as Dictionary).get("keep", false) == "yes"), "GameFlow repair preserves unrelated store namespaces")
	_check(not bool(flow.commit_runtime_settings_repair(token).get("accepted", false)), "GameFlow repair rejects confirmation replay")
	var stale_generation := flow.inspect_runtime_settings_repair(
		_forged_backup_status(store.get_generation())
	)
	_check(not bool(stale_generation.get("accepted", false)) and stale_generation.get("reason") == &"stale_load_generation", "GameFlow cannot reuse a retained startup receipt after the store generation advances")
	flow.free()

	var valid_filesystem := FakeFilesystem.new()
	var valid_seed := Store.new("memory://game-flow-valid.json", valid_filesystem)
	valid_seed.load()
	valid_seed.commit(payload, 0, "valid-primary-001")
	var valid_flow := GameFlowType.new()
	var valid_store := Store.new("memory://game-flow-valid.json", valid_filesystem)
	_check(valid_flow.configure_runtime_settings_persistence(valid_store, "memory://game-flow-valid.cfg"), "valid-primary fixture installs isolated persistence")
	valid_flow._initialize_runtime_settings()
	var forged_valid_primary := valid_flow.inspect_runtime_settings_repair(
		_forged_backup_status(valid_store.get_generation())
	)
	_check(not bool(forged_valid_primary.get("accepted", false)) and forged_valid_primary.get("reason") == &"no_repair_available", "forged backup evidence cannot make a valid primary repairable")
	valid_flow.free()

	var newer_filesystem := FakeFilesystem.new()
	var newer_seed := Store.new("memory://game-flow-newer.json", newer_filesystem)
	newer_seed.load()
	newer_seed.commit({
		Adapter.SETTINGS_PAYLOAD_KEY: {
			"schema_version": Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION + 1,
			"values": {},
		},
	}, 0, "typed-newer-001")
	var newer_flow := GameFlowType.new()
	var newer_store := Store.new("memory://game-flow-newer.json", newer_filesystem)
	_check(newer_flow.configure_runtime_settings_persistence(newer_store, "memory://game-flow-newer.cfg"), "typed-newer fixture installs isolated persistence")
	newer_flow._initialize_runtime_settings()
	var forged_newer := newer_flow.inspect_runtime_settings_repair(
		_forged_backup_status(newer_store.get_generation())
	)
	_check(not bool(forged_newer.get("accepted", false)) and forged_newer.get("reason") == &"unsupported_newer_schema", "forged backup evidence cannot override a retained typed-newer startup receipt")
	newer_flow.free()

	var corrupt_filesystem := FakeFilesystem.new()
	var corrupt_seed := Store.new("memory://game-flow-corrupt.json", corrupt_filesystem)
	corrupt_seed.load()
	corrupt_seed.commit({
		Adapter.SETTINGS_PAYLOAD_KEY: {
			"schema_version": Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION,
			"values": {},
		},
	}, 0, "typed-corrupt-001")
	var corrupt_flow := GameFlowType.new()
	var corrupt_store := Store.new("memory://game-flow-corrupt.json", corrupt_filesystem)
	_check(corrupt_flow.configure_runtime_settings_persistence(corrupt_store, "memory://game-flow-corrupt.cfg"), "typed-corrupt fixture installs isolated persistence")
	corrupt_flow._initialize_runtime_settings()
	var forged_corrupt := corrupt_flow.inspect_runtime_settings_repair(
		_forged_backup_status(corrupt_store.get_generation())
	)
	_check(not bool(forged_corrupt.get("accepted", false)) and forged_corrupt.get("reason") == &"load_not_repairable", "forged backup evidence cannot override a retained corrupt typed-settings receipt")
	corrupt_flow.free()
	if _failures.is_empty(): print("GAME_FLOW_RUNTIME_SETTINGS_REPAIR_TEST_OK: %d assertions" % _assertions)
	else:
		for failure in _failures: push_error(failure)
		print("GAME_FLOW_RUNTIME_SETTINGS_REPAIR_TEST_FAILED: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)


func _forged_backup_status(generation: int) -> Dictionary:
	return {
		"accepted": true,
		"reason": &"loaded",
		"store_reason": &"primary_invalid_backup_loaded",
		"generation": generation,
	}
