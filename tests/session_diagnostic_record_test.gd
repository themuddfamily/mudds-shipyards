extends SceneTree

const Event := preload("res://scripts/diagnostics/session_diagnostic_event.gd")
const Record := preload("res://scripts/diagnostics/session_diagnostic_record.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")

const STORE_PATH := "memory://session_diagnostics.json"

var _assertions := 0
var _failures := PackedStringArray()


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var fail_write_once := false
	var partial_write_on_failure := false

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
		if fail_write_once:
			fail_write_once = false
			if partial_write_on_failure:
				files[path] = bytes.slice(0, maxi(1, bytes.size() / 2))
			return ERR_FILE_CANT_WRITE
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
	_test_typed_event_and_detached_deterministic_snapshot()
	_test_overflow_is_a_strict_ring()
	_test_redaction_and_private_text_rejection()
	_test_malformed_and_nonfinite_input()
	_test_detach_and_reentry()
	_test_injected_persistence_and_failed_commit_preservation()
	_test_exact_authority_exclusions()
	_finish()


func _test_typed_event_and_detached_deterministic_snapshot() -> void:
	var record := Record.new() as SessionDiagnosticRecord
	_check(record.attach_session(41).accepted, "a bounded positive caller-owned session identity attaches the observer")
	var event := _event(
		Event.Code.CRASH_DETECTED,
		Event.Severity.ERROR,
		41,
		720,
		12.0,
		{
			"speed_metres_per_second": 82.5,
			"damage_ratio": 1.0,
			"recovered": false,
		}
	)
	var result := record.record(event)
	_check(
		bool(result.accepted) and result.reason == &"recorded" and int(result.sequence) == 1,
		"a typed enum event with bounded primitive fields is recorded"
	)
	event.physics_tick = 99_999
	event.fields["speed_metres_per_second"] = 0.0
	var snapshot := record.get_snapshot()
	var stored := (snapshot.events as Array)[0] as Dictionary
	_check(
		int(stored.physics_tick) == 720 and float((stored.fields as Dictionary).speed_metres_per_second) == 82.5,
		"recording copies caller primitives instead of retaining event mutation authority"
	)
	stored["physics_tick"] = -1
	(stored.fields as Dictionary)["damage_ratio"] = -1.0
	(snapshot.events as Array).append({"forged": true})
	var reread := record.get_snapshot()
	_check(
		int(reread.events[0].physics_tick) == 720
		and float(reread.events[0].fields.damage_ratio) == 1.0
		and (reread.events as Array).size() == 1,
		"nested snapshots are deeply detached from the live ring"
	)
	var first_json := record.serialize_snapshot()
	var second_json := record.serialize_snapshot()
	var parsed: Variant = JSON.parse_string(first_json)
	_check(
		first_json == second_json
		and parsed is Dictionary
		and bool(Store.validate_payload(parsed).valid),
		"serialization is byte-order deterministic and produces a JSON-safe detached payload"
	)
	_check(
		first_json.find("damage_ratio") < first_json.find("recovered")
		and first_json.find("recovered") < first_json.find("speed_metres_per_second"),
		"primitive field keys are serialized in canonical sorted order"
	)


func _test_overflow_is_a_strict_ring() -> void:
	var record := Record.new() as SessionDiagnosticRecord
	record.attach_session(7)
	for index in Record.MAX_EVENTS + 5:
		var result := record.record(_event(
			Event.Code.PHYSICS_STALL,
			Event.Severity.WARNING,
			7,
			index,
			float(index) / 60.0,
			{"frame_delta_seconds": 0.2}
		))
		_check(bool(result.accepted), "ring fixture accepts bounded event %d" % (index + 1))
	var snapshot := record.get_snapshot()
	_check(
		(snapshot.events as Array).size() == Record.MAX_EVENTS
		and int(snapshot.dropped_event_count) == 5
		and int(snapshot.next_sequence) == Record.MAX_EVENTS + 6
		and bool(record.audit().valid),
		"overflow retains exactly the fixed capacity and counts every displaced event"
	)
	_check(
		int(snapshot.events[0].sequence) == 6
		and int(snapshot.events[0].physics_tick) == 5
		and int(snapshot.events[-1].sequence) == Record.MAX_EVENTS + 5,
		"the ring discards only the oldest entries and preserves monotonic sequence identity"
	)


func _test_redaction_and_private_text_rejection() -> void:
	var record := Record.new() as SessionDiagnosticRecord
	record.attach_session(9)
	var secret_value := "Bearer-private-token-/Users/alex/save.json"
	var redacted := record.record(_event(
		Event.Code.PERSISTENCE_FAILURE,
		Event.Severity.ERROR,
		9,
		18,
		0.3,
		{
			"auth_token": secret_value,
			"password": {"nested": "also private"},
			"error_code": 17,
		}
	))
	var serialized := record.serialize_snapshot()
	_check(
		bool(redacted.accepted)
		and int(redacted.redacted_field_count) == 2
		and int(record.get_snapshot().events[0].redacted_field_count) == 2,
		"recognized secret fields are counted and removed regardless of their value type"
	)
	_check(
		not serialized.contains(secret_value)
		and not serialized.contains("auth_token")
		and not serialized.contains("password")
		and not serialized.contains("nested"),
		"neither secret keys nor secret values reach the retained or serialized record"
	)
	var before := record.get_snapshot()
	var private_inputs := [
		{"path": "/Users/alex/save.json"},
		{"user_message": "my ship broke"},
		{"error_code": "/home/alex/private"},
		{"notes": 3},
	]
	var rejected := true
	for fields in private_inputs:
		rejected = rejected and not bool(record.record(_event(
			Event.Code.PERSISTENCE_FAILURE,
			Event.Severity.ERROR,
			9,
			19,
			0.4,
			fields
		)).accepted)
	_check(rejected and record.get_snapshot() == before, "paths, user text, string values and arbitrary field names fail without mutation")


func _test_malformed_and_nonfinite_input() -> void:
	var record := Record.new() as SessionDiagnosticRecord
	record.attach_session(5)
	var invalid_code := _event(Event.Code.SESSION_STARTED, Event.Severity.INFO, 5, 0, 0.0)
	invalid_code.code = 999 as SessionDiagnosticEvent.Code
	var invalids: Array = [
		null,
		invalid_code,
		_event(Event.Code.SESSION_STARTED, Event.Severity.INFO, 0, 0, 0.0),
		_event(Event.Code.SESSION_STARTED, Event.Severity.INFO, 5, -1, 0.0),
		_event(Event.Code.SESSION_STARTED, Event.Severity.INFO, 5, 0, NAN),
		_event(Event.Code.SESSION_STARTED, Event.Severity.INFO, 5, 0, INF),
		_event(Event.Code.SESSION_STARTED, Event.Severity.INFO, 5, 0, -0.01),
		_event(Event.Code.SESSION_STARTED, Event.Severity.INFO, 5, 0, Record.MAX_SESSION_PHYSICS_SECONDS + 0.01),
		_event(Event.Code.PHYSICS_STALL, Event.Severity.WARNING, 5, 1, 0.1, {"frame_delta_seconds": NAN}),
		_event(Event.Code.PHYSICS_STALL, Event.Severity.WARNING, 5, 1, 0.1, {"entity_count": Record.MAX_FIELD_INTEGER + 1}),
		_event(Event.Code.PHYSICS_STALL, Event.Severity.WARNING, 5, 1, 0.1, {"damage_ratio": 1.01}),
		_event(Event.Code.PHYSICS_STALL, Event.Severity.WARNING, 5, 1, 0.1, {"frame_delta_seconds": -0.01}),
		_event(Event.Code.PHYSICS_STALL, Event.Severity.WARNING, 5, 1, 0.1, {"recovered": []}),
		_event(Event.Code.PHYSICS_STALL, Event.Severity.WARNING, 5, 1, 0.1, {"recovered": 1}),
		_event(Event.Code.PHYSICS_STALL, Event.Severity.WARNING, 5, 1, 0.1, {"entity_count": 1.5}),
	]
	var all_rejected := true
	for event in invalids:
		all_rejected = all_rejected and not bool(record.record(event).accepted)
	var too_many_fields := {}
	for index in Record.MAX_INPUT_FIELDS + 1:
		too_many_fields["unknown_%02d" % index] = index
	all_rejected = all_rejected and not bool(record.record(_event(
		Event.Code.PHYSICS_STALL,
		Event.Severity.WARNING,
		5,
		1,
		0.1,
		too_many_fields
	)).accepted)
	_check(all_rejected and record.get_snapshot().events.is_empty(), "malformed, out-of-range, nested and nonfinite inputs all fail closed")


func _test_detach_and_reentry() -> void:
	var record := Record.new() as SessionDiagnosticRecord
	_check(record.attach_session(101).reason == &"attached", "initial observer attachment succeeds")
	_check(record.attach_session(101).reason == &"already_attached", "same-session reentry is idempotent")
	_check(not bool(record.attach_session(102).accepted), "an attached observer rejects an unrelated session")
	record.record(_event(Event.Code.SESSION_STARTED, Event.Severity.INFO, 101, 0, 0.0))
	_check(record.detach_session(101).accepted, "matching detach succeeds")
	_check(
		not bool(record.record(_event(Event.Code.SESSION_ENDED, Event.Severity.INFO, 101, 1, 0.1)).accepted),
		"a detached observer cannot append events"
	)
	_check(record.attach_session(101).accepted, "the same service reattaches to the caller-owned session")
	var reentry := record.record(_event(Event.Code.SESSION_REENTERED, Event.Severity.INFO, 101, 2, 0.2))
	_check(
		bool(reentry.accepted)
		and int(reentry.sequence) == 2
		and (record.get_snapshot().events as Array).size() == 2,
		"detach/reentry preserves the ring and sequence without fabricating elapsed time"
	)
	_check(record.detach_session(101).accepted and record.attach_session(202).accepted, "a detached recorder may observe a later caller-selected session")
	var wrong_session := record.record(_event(Event.Code.SESSION_STARTED, Event.Severity.INFO, 101, 0, 0.0))
	_check(not bool(wrong_session.accepted) and int(record.get_snapshot().next_sequence) == 3, "session mismatch cannot mutate retained history")


func _test_injected_persistence_and_failed_commit_preservation() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	_check(bool(store.load().accepted), "fixture caller loads the injected UserDataStore")
	_check(
		bool(store.commit({"settings": {"volume": 0.5}, "save_game": {"slot": 3}}, 0, "profile-001").accepted),
		"fixture establishes adjacent caller-owned payload namespaces"
	)
	var record := Record.new(store) as SessionDiagnosticRecord
	record.attach_session(55)
	record.record(_event(
		Event.Code.CRASH_DETECTED,
		Event.Severity.ERROR,
		55,
		300,
		5.0,
		{"damage_ratio": 1.0, "error_code": 17}
	))
	var persisted := record.persist("diagnostics-002")
	var stored_payload := store.get_snapshot()
	_check(
		bool(persisted.accepted)
		and int(store.get_generation()) == 2
		and persisted.keys().size() == 3
		and not persisted.has("payload")
		and not persisted.has("commit"),
		"optional persistence delegates one commit without proxying adjacent payload or commit metadata"
	)
	_check(
		float(stored_payload.settings.volume) == 0.5
		and float(stored_payload.save_game.slot) == 3.0
		and stored_payload.has(Record.PAYLOAD_NAMESPACE),
		"persistence merges its namespace without owning or replacing settings/save data"
	)
	var restored := Record.new(store) as SessionDiagnosticRecord
	var restore_result := restored.restore_from_store()
	_check(
		bool(restore_result.accepted)
		and restored.get_snapshot() == record.get_snapshot()
		and typeof(restored.get_snapshot().events[0].fields.error_code) == TYPE_INT
		and not bool(restored.audit().observer_state.attached),
		"a new detached recorder restores typed exact history but never restores attachment authority"
	)
	restored.attach_session(55)
	var continued := restored.record(_event(Event.Code.RECOVERY_STARTED, Event.Severity.INFO, 55, 360, 6.0, {"attempt_count": 1}))
	_check(bool(continued.accepted) and int(continued.sequence) == 2, "restored reentry continues monotonic diagnostic sequence identity")

	var prior_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var prior_payload := store.get_snapshot()
	var prior_generation := store.get_generation()
	filesystem.fail_write_once = true
	filesystem.partial_write_on_failure = true
	var failed := restored.persist("diagnostics-003")
	_check(not bool(failed.accepted) and failed.reason == &"temp_write_failed", "injected store failure is surfaced without being disguised as a diagnostic success")
	_check(
		store.get_generation() == prior_generation
		and store.get_snapshot() == prior_payload
		and (filesystem.files[STORE_PATH] as PackedByteArray) == prior_bytes
		and not filesystem.files.has(STORE_PATH + ".tmp"),
		"failed diagnostic persistence preserves the complete prior store and removes partial staging"
	)
	_check(
		not bool(restored.persist("contains/a/path").accepted)
		and store.get_generation() == prior_generation,
		"commit identity remains caller-owned but path-like or free-text tokens are rejected before store access"
	)
	var malformed_payload := store.get_snapshot()
	malformed_payload[Record.PAYLOAD_NAMESPACE] = {
		"schema_version": Record.SCHEMA_VERSION,
		"capacity": Record.MAX_EVENTS,
		"next_sequence": 2,
		"dropped_event_count": 0,
		"events": [{"path": "/Users/private/crash.txt"}],
	}
	_check(
		bool(store.commit(malformed_payload, prior_generation, "malformed-003").accepted),
		"generic store fixture can hold a JSON-safe but diagnostics-invalid namespace"
	)
	var guarded := Record.new(store) as SessionDiagnosticRecord
	guarded.attach_session(88)
	guarded.record(_event(Event.Code.SESSION_STARTED, Event.Severity.INFO, 88, 0, 0.0))
	guarded.detach_session(88)
	var guarded_before := guarded.get_snapshot()
	var invalid_restore := guarded.restore_from_store()
	_check(
		not bool(invalid_restore.accepted)
		and invalid_restore.reason == &"invalid_record"
		and guarded.get_snapshot() == guarded_before,
		"malformed persisted diagnostics fail closed without replacing prior recorder state"
	)


func _test_exact_authority_exclusions() -> void:
	var record := Record.new() as SessionDiagnosticRecord
	var expected_authority := {
		"wall_clock": false,
		"physics_time": false,
		"session_lifecycle": false,
		"gameplay": false,
		"settings": false,
		"save_game": false,
		"crash_recovery": false,
		"filesystem_path": false,
		"commit_identity": false,
	}
	var audit := record.audit()
	_check(audit.authority == expected_authority, "audit freezes every adjacent authority exclusion exactly")
	_check(
		audit.privacy == {
			"arbitrary_field_names": false,
			"string_values": false,
			"paths": false,
			"user_text": false,
			"secret_values_retained": false,
		},
		"audit freezes the privacy exclusions exactly"
	)
	var source := FileAccess.get_file_as_string("res://scripts/diagnostics/session_diagnostic_record.gd")
	_check(
		not source.contains("Time.")
		and not source.contains("FileAccess.")
		and not source.contains("DirAccess."),
		"implementation has no wall-clock or direct filesystem authority"
	)
	(audit.authority as Dictionary)["gameplay"] = true
	(audit.snapshot as Dictionary)["next_sequence"] = -1
	_check(
		record.audit().authority == expected_authority
		and int(record.get_snapshot().next_sequence) == 1,
		"authority audit and nested state are detached from caller mutation"
	)


func _event(
	code: SessionDiagnosticEvent.Code,
	severity: SessionDiagnosticEvent.Severity,
	session_id: int,
	physics_tick: int,
	elapsed: float,
	fields: Dictionary = {}
	) -> SessionDiagnosticEvent:
	return Event.new(code, severity, session_id, physics_tick, elapsed, fields) as SessionDiagnosticEvent


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("SESSION_DIAGNOSTIC_RECORD_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("SESSION_DIAGNOSTIC_RECORD_TEST_FAILED: %d/%d assertions failed" % [_failures.size(), _assertions])
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
