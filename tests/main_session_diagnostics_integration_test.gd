extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")

var _failures: Array[String] = []
var _assertions := 0


class MemoryFilesystem extends Filesystem:
	var files: Dictionary = {}

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
	var filesystem := MemoryFilesystem.new()
	var store := Store.new("memory://main-session-diagnostics.json", filesystem)
	_check(bool(store.load().get("accepted", false)), "isolated diagnostics store loads empty")
	var flow := GameFlowType.new()
	flow.set("_runtime_settings_user_data_store", store)
	flow._initialize_session_diagnostics()
	var started := flow.get_session_diagnostics_snapshot()
	_check(
		bool(started.available)
		and bool(started.bridge.get("coordinator", {}).get("active", false))
		and StringName(started.last_status.reason) == &"started",
		"Main composition publishes a running privacy-safe session marker"
	)
	var closed := flow.mark_orderly_session_shutdown()
	var finished := flow.get_session_diagnostics_snapshot()
	_check(
		bool(closed.accepted)
		and StringName(closed.reason) == &"orderly_shutdown"
		and StringName(finished.bridge.get("state", "")) == &"clean",
		"caller-confirmed Main shutdown clears the running marker without touching gameplay state"
	)
	flow.free()
	if _failures.is_empty():
		print("MAIN_SESSION_DIAGNOSTICS_INTEGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("MAIN_SESSION_DIAGNOSTICS_INTEGRATION_TEST_FAILED: ", _failures)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)
		push_error("FAIL: " + description)
