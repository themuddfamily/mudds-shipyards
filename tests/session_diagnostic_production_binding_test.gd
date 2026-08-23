extends SceneTree

const Store := preload("res://scripts/persistence/user_data_store.gd")
const Record := preload("res://scripts/diagnostics/session_diagnostic_record.gd")
const Event := preload("res://scripts/diagnostics/session_diagnostic_event.gd")
const Binding := preload("res://scripts/diagnostics/session_diagnostic_production_binding.gd")

var _assertions := 0
var _failures: Array[String] = []
var _generation := 0
class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var fail_writes := false
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, _max: int) -> Dictionary:
		if not files.has(path): return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": (files[path] as PackedByteArray).duplicate()}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if fail_writes: return ERR_FILE_CANT_WRITE
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path) or files.has(to_path): return ERR_FILE_CANT_WRITE
		files[to_path] = (files[from_path] as PackedByteArray).duplicate(); files.erase(from_path); return OK

func _initialize() -> void:
	_run()

func _run() -> void:
	var fs := FakeFilesystem.new()
	var store := Store.new("memory://diagnostic-binding.json", fs)
	var loaded := store.load()
	_check(bool(loaded.accepted), "injected store loads before diagnostic binding")
	_generation = store.get_generation()
	var record := Record.new(store)
	var binding := Binding.new()
	_check(bool(binding.configure(record, 42, _generation, Callable(self, &"_read_generation")).accepted), "binding accepts caller session and generation seam")
	_check(bool(binding.attach().accepted), "binding attaches one diagnostic session")
	var event := Event.new(Event.Code.SESSION_STARTED, Event.Severity.INFO, 42, 1, 0.25, {"entity_count": 2})
	_check(bool(binding.record_event(event).accepted), "binding records only the matching privacy-safe event")
	_check(bool(binding.persist("diagnostic-binding-0001").accepted), "binding persists through the injected record/store seam")
	_generation = store.get_generation()
	_check(bool(binding.detach().accepted), "binding detaches without clearing retained diagnostics")
	_check(not bool(binding.record_event(event).accepted), "detached binding rejects event replay")
	_check(bool(binding.attach().accepted), "binding re-enters the same session")
	_generation = store.get_generation() + 1
	_check(not bool(binding.persist("diagnostic-binding-stale").accepted) and binding.get_report().last_status.reason == &"stale_store_generation", "stale generation fails closed before commit")
	_generation = store.get_generation()
	fs.fail_writes = true
	_check(not bool(binding.persist("diagnostic-binding-0002").accepted), "commit failure remains caller-visible and retryable")
	_check(binding.get_snapshot().events.size() == 1, "commit failure leaves the detached diagnostic snapshot available")
	_finish()

func _read_generation() -> int:
	return _generation

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition: print("PASS: ", message)
	else: _failures.append(message); push_error("FAIL: " + message)

func _finish() -> void:
	if _failures.is_empty(): print("SESSION_DIAGNOSTIC_PRODUCTION_BINDING_TEST_OK: %d assertions" % _assertions)
	else: push_error("SESSION_DIAGNOSTIC_PRODUCTION_BINDING_TEST_FAILED: " + "; ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
