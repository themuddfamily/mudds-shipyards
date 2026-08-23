extends SceneTree

const Event := preload("res://scripts/diagnostics/session_diagnostic_event.gd")
const Record := preload("res://scripts/diagnostics/session_diagnostic_record.gd")
const Sink := preload("res://scripts/diagnostics/session_diagnostic_file_sink.gd")

var _failures := PackedStringArray()
var _assertions := 0


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var fail_write := false

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
		if fail_write:
			return ERR_FILE_CANT_WRITE
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path) or files.has(to_path):
			return ERR_CANT_CREATE
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := FakeFilesystem.new()
	var sink := Sink.new("memory://diagnostics", filesystem)
	var record := Record.new()
	record.attach_session(7)
	record.record(Event.new(Event.Code.CRASH_DETECTED, Event.Severity.ERROR, 7, 1, 0.1, {"recovered": true}))
	var snapshot := record.get_snapshot()
	var first := sink.append_snapshot(snapshot)
	_check(bool(first.accepted) and first.reason == &"written" and int(first.retained_snapshot_count) == 1, "redacted diagnostic snapshot publishes to the fixed local sink")
	_check(filesystem.files.has("memory://diagnostics/crash-log.json") and not filesystem.files.has("memory://diagnostics/crash-log.json.tmp"), "atomic publication leaves no temporary sibling")
	var second := sink.append_snapshot(snapshot)
	_check(bool(second.accepted) and filesystem.files.has("memory://diagnostics/crash-log.previous.json"), "publication rotates exactly one bounded previous generation")
	for index in 8:
		var appended := sink.append_snapshot(snapshot)
		_check(bool(appended.accepted), "bounded sink accepts redacted snapshot %d" % index)
	_check(int(sink._read_log().snapshots.size()) == Sink.MAX_RETAINED_SNAPSHOTS, "retained diagnostic snapshots are capped")
	var secret := snapshot.duplicate(true)
	(secret.events[0] as Dictionary).fields["token"] = 1
	var rejected := sink.append_snapshot(secret)
	_check(not bool(rejected.accepted) and rejected.reason == &"snapshot_rejected", "secret-bearing snapshot is rejected before any file mutation")
	var bytes_before := (filesystem.files["memory://diagnostics/crash-log.json"] as PackedByteArray).duplicate()
	filesystem.fail_write = true
	var failed := sink.append_snapshot(snapshot)
	_check(not bool(failed.accepted) and filesystem.files["memory://diagnostics/crash-log.json"] == bytes_before, "stage failure preserves the prior published log")
	var unsafe := Sink.new("/tmp/free-path", filesystem)
	_check(unsafe.get_log_path().is_empty() and not bool(unsafe.append_snapshot(snapshot).accepted), "free filesystem paths are rejected")
	var malformed_fs := FakeFilesystem.new()
	var malformed_sink := Sink.new("memory://malformed", malformed_fs)
	malformed_fs.files["memory://malformed/crash-log.json"] = "{broken".to_utf8_buffer()
	var blocked := malformed_sink.append_snapshot(snapshot)
	_check(not bool(blocked.accepted) and blocked.reason == &"log_invalid", "malformed prior logs block implicit append")
	var repaired := malformed_sink.recover_prior_log()
	_check(bool(repaired.accepted) and repaired.reason == &"malformed_log_quarantined" and malformed_fs.files.has("memory://malformed/crash-log.json.rejected"), "explicit recovery quarantines malformed log bytes")
	_check(bool(malformed_sink.append_snapshot(snapshot).accepted), "append resumes after explicit malformed-log recovery")
	var fallback_fs := FakeFilesystem.new()
	var fallback_sink := Sink.new("memory://fallback", fallback_fs)
	fallback_fs.files["memory://fallback/crash-log.json"] = "oversize-or-corrupt".to_utf8_buffer()
	fallback_fs.files["memory://fallback/crash-log.previous.json"] = JSON.stringify([snapshot]).to_utf8_buffer()
	var fallback := fallback_sink.append_snapshot(snapshot)
	_check(
		bool(fallback.accepted)
		and fallback_fs.files.has("memory://fallback/crash-log.json")
		and fallback_fs.files.has("memory://fallback/crash-log.previous.json"),
		"malformed current log falls back to the valid previous generation without unbounded restoration"
	)
	_finish()


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("SESSION_DIAGNOSTIC_FILE_SINK_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		printerr("SESSION_DIAGNOSTIC_FILE_SINK_TEST_FAILED: ", _failures.size(), "/", _assertions)
		quit(1)
