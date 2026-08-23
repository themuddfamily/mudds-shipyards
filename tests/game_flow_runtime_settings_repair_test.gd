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
	var committed := flow.commit_runtime_settings_repair(token)
	_check(bool(committed.get("accepted", false)) and committed.get("reason") == &"repair_committed", "GameFlow commits repair through existing store transaction")
	_check(bool((store.get_snapshot().get("foreign", {}) as Dictionary).get("keep", false) == "yes"), "GameFlow repair preserves unrelated store namespaces")
	_check(not bool(flow.commit_runtime_settings_repair(token).get("accepted", false)), "GameFlow repair rejects confirmation replay")
	flow.free()
	if _failures.is_empty(): print("GAME_FLOW_RUNTIME_SETTINGS_REPAIR_TEST_OK: %d assertions" % _assertions)
	else:
		for failure in _failures: push_error(failure)
		print("GAME_FLOW_RUNTIME_SETTINGS_REPAIR_TEST_FAILED: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
