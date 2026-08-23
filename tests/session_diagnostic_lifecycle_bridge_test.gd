extends SceneTree

const Bridge := preload("res://scripts/diagnostics/session_diagnostic_lifecycle_bridge.gd")
const Coordinator := preload("res://scripts/diagnostics/crash_recovery_coordinator.gd")
const Record := preload("res://scripts/diagnostics/session_diagnostic_record.gd")
const Sink := preload("res://scripts/diagnostics/session_diagnostic_file_sink.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")

const PATH := "memory://diagnostic-bridge.json"
var _assertions := 0
var _failures := PackedStringArray()


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var fail_write := false

	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path): return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()} if bytes.size() > maximum_bytes else {"error": OK, "bytes": bytes}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if fail_write: return ERR_FILE_CANT_WRITE
		files[path] = bytes.duplicate()
		return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path) or files.has(to_path): return ERR_CANT_CREATE
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(PATH, filesystem) as UserDataStore
	store.load()
	var first_coordinator := Coordinator.new(store)
	first_coordinator.restore()
	var first_bridge := Bridge.new(first_coordinator, Record.new(), Sink.new("memory://diag", filesystem))
	_check(bool(first_bridge.begin_session(10, "begin-10", 0, 0.0).accepted), "first startup begins through the bridge")
	_check(bool(first_bridge.mark_stable(4, 0.1, "stable-10").accepted), "caller marks the first startup stable")
	var second_store := Store.new(PATH, filesystem) as UserDataStore
	second_store.load()
	var second_coordinator := Coordinator.new(second_store)
	second_coordinator.restore()
	var sink_filesystem := FakeFilesystem.new()
	var sink := Sink.new("memory://diag", sink_filesystem)
	sink_filesystem.fail_write = true
	var record := Record.new() as SessionDiagnosticRecord
	var bridge := Bridge.new(second_coordinator, record, sink)
	var recovered := bridge.begin_session(11, "begin-11", 1, 0.02)
	_check(bool(recovered.accepted) and recovered.reason == &"recovered_flush_pending" and bool(recovered.recovery_flush_pending), "unfinished startup is surfaced while failed diagnostic flush remains pending")
	_check(record.get_snapshot().events.size() == 1, "recovery event is recorded exactly once before sink retry")
	sink_filesystem.fail_write = false
	var flushed := bridge.flush_recovery_event(2, 0.03)
	_check(bool(flushed.accepted) and flushed.reason == &"recovery_flushed" and not bool(flushed.recovery_flush_pending), "next-start recovery event flushes through the existing sink")
	var stable := bridge.mark_stable(2, 0.03, "stable-11")
	_check(bool(stable.accepted) and stable.reason == &"stable", "bridge marks stable after the recovery flush")
	_check(bool(bridge.mark_stable(2, 0.03, "ignored").accepted), "stable transition is idempotent")
	var closed := bridge.mark_orderly_shutdown(3, 0.04, "clean-11")
	_check(bool(closed.accepted) and closed.reason == &"orderly_shutdown" and bridge.get_snapshot().state == Bridge.STATE_CLEAN, "explicit orderly shutdown closes the bridge")
	_check(sink_filesystem.files.has("memory://diag/crash-log.json"), "diagnostic sink retains the privacy-safe recovery snapshot")
	_finish()


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("SESSION_DIAGNOSTIC_LIFECYCLE_BRIDGE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		printerr("SESSION_DIAGNOSTIC_LIFECYCLE_BRIDGE_TEST_FAILED: ", _failures.size(), "/", _assertions)
		quit(1)
