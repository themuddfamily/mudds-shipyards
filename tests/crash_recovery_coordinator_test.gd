extends SceneTree

const Coordinator := preload("res://scripts/diagnostics/crash_recovery_coordinator.gd")
const Event := preload("res://scripts/diagnostics/session_diagnostic_event.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")

const STORE_PATH := "memory://crash_recovery_coordinator.json"

var _assertions := 0
var _failures := PackedStringArray()


class FakeFilesystem extends UserDataFilesystem:
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
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem) as UserDataStore
	_check(bool(store.load().accepted), "fresh store loads before crash-marker restore")
	var coordinator = Coordinator.new(store)
	_check(coordinator.restore().reason == &"empty", "missing marker is a valid empty recovery state")
	var started := coordinator.begin_session(41, "crash-start-1")
	_check(
		bool(started.accepted)
		and started.reason == &"started"
		and not bool(started.recovered)
		and not bool(started.safe_mode_recommended),
		"first session writes a running marker without a false crash diagnosis"
	)
	_check(
		coordinator.checkpoint(41, 3, 0.05, "crash-checkpoint-1").accepted,
		"caller-owned physics progress checkpoints through the marker authority"
	)
	var before_regression := coordinator.get_snapshot()
	var regression := coordinator.checkpoint(41, 2, 0.04, "crash-checkpoint-regression")
	_check(
		not bool(regression.accepted)
		and regression.reason == &"progress_regressed"
		and coordinator.get_snapshot() == before_regression,
		"tick and elapsed regressions fail without mutating recovery state"
	)

	# A fresh process sees the running marker and turns it into one typed,
	# caller-recordable diagnostic event.
	var restarted_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	_check(bool(restarted_store.load().accepted), "restarted process loads the prior marker")
	var restarted = Coordinator.new(restarted_store)
	_check(bool(restarted.restore().accepted), "restarted coordinator restores marker state")
	var recovered := restarted.begin_session(42, "crash-start-2")
	_check(
		bool(recovered.accepted)
		and recovered.reason == &"recovered_previous_session"
		and bool(recovered.recovered)
		and int(recovered.get("safe_mode_recommended", -1)) == 0,
		"an unfinished prior session is detected exactly once and remains advisory"
	)
	var recovery_event := restarted.get_recovery_event(1, 0.01)
	var event := recovery_event.get("event") as SessionDiagnosticEvent
	_check(
		bool(recovery_event.accepted)
		and event != null
		and event.code == Event.Code.CRASH_DETECTED
		and event.severity == Event.Severity.ERROR
		and event.fields == {"attempt_count": 1, "recovered": true},
		"recovery exposes a privacy-bounded typed event for SessionDiagnosticRecord"
	)
	_check(
		restarted.mark_clean_shutdown(42, 4, 0.1, "crash-clean-2").accepted,
		"clean shutdown closes the marker through the same generation-safe seam"
	)
	var clean_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	clean_store.load()
	var clean_restart = Coordinator.new(clean_store)
	clean_restart.restore()
	var clean_begin := clean_restart.begin_session(43, "crash-start-3")
	_check(
		bool(clean_begin.accepted) and not bool(clean_begin.recovered),
		"a cleanly closed session is not misclassified on the next startup"
	)

	# Three consecutive unfinished starts produce safe-mode advice but never
	# apply settings; each iteration represents a new process after a crash.
	var consecutive: Variant = clean_restart
	for index in 3:
		var process_store := Store.new(STORE_PATH, filesystem) as UserDataStore
		process_store.load()
		consecutive = Coordinator.new(process_store)
		consecutive.restore()
		var result: Dictionary = consecutive.begin_session(50 + index, "crash-repeat-%d" % index)
		_check(bool(result.accepted), "repeated unfinished start %d remains recoverable" % (index + 1))
		if index == 2:
			_check(
				bool(result.get("safe_mode_recommended", false))
				and int(consecutive.get_snapshot().unclean_start_count) == 3,
				"the third consecutive unfinished start raises bounded safe-mode advice"
			)

	# A concurrent writer must not be overwritten by a stale checkpoint.
	var race_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	race_store.load()
	var race = Coordinator.new(race_store)
	race.restore()
	_check(
		bool(race.begin_session(60, "race-begin").accepted),
		"race fixture establishes a live session before the competing writer"
	)
	var race_before := race.get_snapshot()
	var competing := Store.new(STORE_PATH, filesystem) as UserDataStore
	competing.load()
	var competing_payload := competing.get_snapshot()
	competing_payload["unrelated_namespace"] = {"preserved": true}
	_check(
		bool(competing.commit(competing_payload, competing.get_generation(), "competing-writer").accepted),
		"the fixture advances store authority through an independent writer"
	)
	var stale := race.checkpoint(60, 8, 0.2, "stale-checkpoint")
	_check(
		not bool(stale.accepted)
		and stale.reason in [&"authority_changed", &"authority_changed_during_staging"]
		and race.get_snapshot() == race_before,
		"a stale checkpoint fails closed without overwriting a concurrent writer"
	)

	# Newer/malformed marker data is never silently repaired.
	var malformed_payload := competing.get_snapshot()
	malformed_payload[Coordinator.PAYLOAD_NAMESPACE] = {"schema_version": 999}
	competing.commit(malformed_payload, competing.get_generation(), "malformed-marker")
	var malformed_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	malformed_store.load()
	var malformed = Coordinator.new(malformed_store)
	var malformed_result := malformed.restore()
	_check(
		not bool(malformed_result.accepted)
		and malformed_result.reason == &"invalid_marker",
		"malformed or newer marker authority is rejected rather than overwritten"
	)
	_check(
		bool(race.audit().authority.os_crash_capture) == false
		and bool(race.audit().authority.settings_application) == false
		and bool(race.audit().authority.gameplay_recovery) == false,
		"the coordinator audit keeps OS capture, settings and gameplay outside its authority"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
	else:
		print("PASS: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("OK: crash_recovery_coordinator_test assertions=%d" % _assertions)
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	printerr("FAIL: crash_recovery_coordinator_test assertions=%d failures=%d" % [_assertions, _failures.size()])
	quit(1)
