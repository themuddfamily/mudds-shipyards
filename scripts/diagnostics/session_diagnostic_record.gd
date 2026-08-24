class_name SessionDiagnosticRecord
extends RefCounted

## Privacy-safe, bounded session/crash evidence owned by no gameplay system.
##
## The caller owns session identity, physics timing, commit identity, and the
## injected UserDataStore lifecycle. This service only validates, retains, and
## serializes observations. It never reads a wall clock or filesystem path.

const Event := preload("res://scripts/diagnostics/session_diagnostic_event.gd")

const SCHEMA_VERSION := 1
const MAX_EVENTS := 64
const MAX_INPUT_FIELDS := 12
const MAX_FIELD_NAME_BYTES := 64
const MAX_SESSION_ID := 9_007_199_254_740_991
const MAX_PHYSICS_TICK := 9_007_199_254_740_991
const MAX_SESSION_PHYSICS_SECONDS := 2_592_000.0
const MAX_FIELD_INTEGER := 9_007_199_254_740_991
const MAX_COUNT := 1_000_000
const MAX_ERROR_CODE := 2_147_483_647
const MAX_INPUT_DEVICE_CODE := 65_535
const MAX_PEER_COUNT := 4_096
const MAX_FRAME_DELTA_SECONDS := 60.0
const MAX_SPEED_METRES_PER_SECOND := 1_000_000.0
const PAYLOAD_NAMESPACE := "session_diagnostics"

## Production lifecycle observations use existing event and field vocabulary so
## wiring the ring does not create a second schema. The caller still owns the
## session identity and monotonic physics sample supplied to each observation.
enum LifecycleObservation {
	STARTUP_COMPLETED = 1,
	MODE_HANDOFF = 2,
	CLEAN_SHUTDOWN = 3,
}

enum RuntimeMode {
	STATION = 1,
	FLIGHT = 2,
	SURFACE = 3,
}

const _CODE_NAMES := [
	"session_started",
	"session_reentered",
	"session_ended",
	"physics_stall",
	"crash_detected",
	"recovery_started",
	"recovery_completed",
	"persistence_failure",
	"control_source_changed",
]
const _SEVERITY_NAMES := ["info", "warning", "error"]
const _SAFE_FIELDS := [
	"attempt_count",
	"damage_ratio",
	"duration_physics_seconds",
	"entity_count",
	"error_code",
	"frame_delta_seconds",
	"input_device_code",
	"peer_count",
	"recovered",
	"speed_metres_per_second",
]
const _INTEGER_FIELDS := [
	"attempt_count",
	"entity_count",
	"error_code",
	"input_device_code",
	"peer_count",
]
const _FLOAT_FIELDS := [
	"damage_ratio",
	"duration_physics_seconds",
	"frame_delta_seconds",
	"speed_metres_per_second",
]
const _BOOLEAN_FIELDS := ["recovered"]
const _SECRET_MARKERS := [
	"api_key",
	"authorization",
	"cookie",
	"credential",
	"password",
	"private_key",
	"secret",
	"token",
]
const _PRIVATE_TEXT_MARKERS := [
	"address",
	"directory",
	"email",
	"file",
	"folder",
	"label",
	"message",
	"name",
	"path",
	"text",
	"user",
]
const _SNAPSHOT_KEYS := [
	"schema_version",
	"capacity",
	"next_sequence",
	"dropped_event_count",
	"events",
]
const _EVENT_KEYS := [
	"sequence",
	"session_id",
	"event_code",
	"severity",
	"physics_tick",
	"session_elapsed_physics_seconds",
	"fields",
	"redacted_field_count",
]

var _store: UserDataStore
var _events: Array[Dictionary] = []
var _next_sequence := 1
var _dropped_event_count := 0
var _attached := false
var _attached_session_id := 0


func _init(store: UserDataStore = null) -> void:
	_store = store


## Marks an observer as attached to a caller-owned session. It does not begin,
## resume, advance, or otherwise authorize that session.
func attach_session(session_id: int) -> Dictionary:
	if not _valid_session_id(session_id):
		return _lifecycle_result(false, &"invalid_session_id")
	if _attached:
		if _attached_session_id == session_id:
			return _lifecycle_result(true, &"already_attached")
		return _lifecycle_result(false, &"different_session_attached")
	_attached = true
	_attached_session_id = session_id
	return _lifecycle_result(true, &"attached")


func detach_session(session_id: int) -> Dictionary:
	if not _attached:
		return _lifecycle_result(false, &"not_attached")
	if session_id != _attached_session_id:
		return _lifecycle_result(false, &"wrong_session")
	_attached = false
	_attached_session_id = 0
	return _lifecycle_result(true, &"detached")


func record(event: SessionDiagnosticEvent) -> Dictionary:
	if not _attached:
		return _record_result(false, &"not_attached")
	var sanitized := _sanitize_event(event)
	if not bool(sanitized.accepted):
		return _record_result(false, sanitized.reason)
	if int((sanitized.event as Dictionary).session_id) != _attached_session_id:
		return _record_result(false, &"wrong_session")
	# `next_sequence` is serialized too, so reserve the final JSON-safe integer
	# instead of accepting an event that would make the following snapshot invalid.
	if _next_sequence >= MAX_FIELD_INTEGER:
		return _record_result(false, &"sequence_exhausted")
	var stored := sanitized.event as Dictionary
	stored["sequence"] = _next_sequence
	stored = _canonical_event(stored)
	if _events.size() == MAX_EVENTS:
		_events.pop_front()
		_dropped_event_count += 1
	_events.append(stored)
	_next_sequence += 1
	return _record_result(
		true,
		&"recorded",
		int(stored.sequence),
		int(stored.redacted_field_count)
	)


## Converts the production owner's fixed lifecycle enum into the ring's
## existing typed events. No caller text or filesystem/process data is accepted.
func record_lifecycle_observation(
	observation: LifecycleObservation,
	session_id: int,
	physics_tick: int,
	elapsed_physics_seconds: float,
	runtime_mode: RuntimeMode = RuntimeMode.STATION
	) -> Dictionary:
	var event_code := Event.Code.CONTROL_SOURCE_CHANGED
	var fields := {}
	match observation:
		LifecycleObservation.STARTUP_COMPLETED:
			event_code = Event.Code.SESSION_STARTED
			fields = {"recovered": false}
		LifecycleObservation.MODE_HANDOFF:
			if runtime_mode not in [
				RuntimeMode.STATION, RuntimeMode.FLIGHT, RuntimeMode.SURFACE,
			]:
				return _record_result(false, &"invalid_runtime_mode")
			fields = {"input_device_code": runtime_mode}
		LifecycleObservation.CLEAN_SHUTDOWN:
			event_code = Event.Code.SESSION_ENDED
			fields = {"duration_physics_seconds": elapsed_physics_seconds}
		_:
			return _record_result(false, &"invalid_lifecycle_observation")
	return record(Event.new(
		event_code,
		Event.Severity.INFO,
		session_id,
		physics_tick,
		elapsed_physics_seconds,
		fields,
	))


## Detached, JSON-safe durable state. Observer attachment is intentionally not
## serialized, so a restored recorder cannot implicitly resume a session.
func get_snapshot() -> Dictionary:
	var detached_events: Array[Dictionary] = []
	for event in _events:
		detached_events.append(event.duplicate(true))
	return {
		"schema_version": SCHEMA_VERSION,
		"capacity": MAX_EVENTS,
		"next_sequence": _next_sequence,
		"dropped_event_count": _dropped_event_count,
		"events": detached_events,
	}


func serialize_snapshot() -> String:
	return JSON.stringify(get_snapshot())


## Reads only this service's namespace from an already-loaded injected store.
## Invalid or absent data never replaces live recorder state.
func restore_from_store() -> Dictionary:
	if _store == null:
		return {"accepted": false, "reason": &"no_store"}
	if _attached:
		return {"accepted": false, "reason": &"service_attached"}
	var payload := _store.get_snapshot()
	if not payload.has(PAYLOAD_NAMESPACE):
		return {"accepted": false, "reason": &"no_record"}
	var validated := _validate_snapshot(payload.get(PAYLOAD_NAMESPACE))
	if not bool(validated.accepted):
		return _record_rejection(validated)
	var snapshot := validated.snapshot as Dictionary
	_events.clear()
	for event in snapshot.events as Array:
		_events.append((event as Dictionary).duplicate(true))
	_next_sequence = int(snapshot.next_sequence)
	_dropped_event_count = int(snapshot.dropped_event_count)
	return {"accepted": true, "reason": &"restored", "snapshot": get_snapshot()}


## Merges this one namespace into the injected store's current payload. The
## caller must load the store and supply the cross-system commit identity. A
## malformed or newer existing diagnostics namespace is preserved for explicit
## recovery/migration instead of being replaced by ordinary persistence.
func persist(commit_id: String) -> Dictionary:
	if _store == null:
		return {"accepted": false, "reason": &"no_store"}
	if not _valid_commit_token(commit_id):
		return {"accepted": false, "reason": &"invalid_commit_id"}
	var payload := _store.get_snapshot()
	if payload.has(PAYLOAD_NAMESPACE):
		var existing := _validate_snapshot(payload.get(PAYLOAD_NAMESPACE))
		if not bool(existing.accepted):
			var rejected := _record_rejection(existing)
			rejected["generation"] = _store.get_generation()
			return rejected
	payload[PAYLOAD_NAMESPACE] = get_snapshot()
	var committed := _store.commit(payload, _store.get_generation(), commit_id)
	# Do not proxy the store's payload/commit metadata back through this service;
	# those adjacent namespaces and identities remain the caller's concern.
	var result := {
		"accepted": bool(committed.accepted),
		"reason": StringName(committed.reason),
		"generation": int(committed.generation),
	}
	if committed.has("rollback_restored"):
		result["rollback_restored"] = bool(committed.rollback_restored)
		result["rollback_error"] = int(committed.rollback_error)
	return result


func audit() -> Dictionary:
	return {
		"valid": _validate_snapshot(get_snapshot()).accepted,
		"limits": {
			"maximum_events": MAX_EVENTS,
			"maximum_input_fields": MAX_INPUT_FIELDS,
			"maximum_session_physics_seconds": MAX_SESSION_PHYSICS_SECONDS,
		},
		"observer_state": {
			"attached": _attached,
			"attached_session_id": _attached_session_id,
		},
		"authority": {
			"wall_clock": false,
			"physics_time": false,
			"session_lifecycle": false,
			"gameplay": false,
			"settings": false,
			"save_game": false,
			"crash_recovery": false,
			"filesystem_path": false,
			"commit_identity": false,
		},
		"privacy": {
			"arbitrary_field_names": false,
			"string_values": false,
			"paths": false,
			"user_text": false,
			"secret_values_retained": false,
		},
		"snapshot": get_snapshot(),
	}


func _sanitize_event(event: SessionDiagnosticEvent) -> Dictionary:
	if event == null:
		return {"accepted": false, "reason": &"invalid_event"}
	if event.code < 0 or event.code >= _CODE_NAMES.size():
		return {"accepted": false, "reason": &"invalid_event"}
	if event.severity < 0 or event.severity >= _SEVERITY_NAMES.size():
		return {"accepted": false, "reason": &"invalid_event"}
	if not _valid_session_id(event.session_id):
		return {"accepted": false, "reason": &"invalid_event"}
	if event.physics_tick < 0 or event.physics_tick > MAX_PHYSICS_TICK:
		return {"accepted": false, "reason": &"invalid_event"}
	if not _valid_elapsed(event.session_elapsed_physics_seconds):
		return {"accepted": false, "reason": &"invalid_event"}
	if event.fields.size() > MAX_INPUT_FIELDS:
		return {"accepted": false, "reason": &"invalid_event"}

	var safe_fields := {}
	var redacted := 0
	for key_variant in event.fields:
		if typeof(key_variant) != TYPE_STRING and typeof(key_variant) != TYPE_STRING_NAME:
			return {"accepted": false, "reason": &"invalid_event"}
		var key := str(key_variant)
		if key.is_empty() or key.to_utf8_buffer().size() > MAX_FIELD_NAME_BYTES:
			return {"accepted": false, "reason": &"invalid_event"}
		var lowered := key.to_lower()
		if _contains_marker(lowered, _PRIVATE_TEXT_MARKERS):
			return {"accepted": false, "reason": &"private_text_or_path"}
		if _contains_marker(lowered, _SECRET_MARKERS):
			redacted += 1
			continue
		if not _SAFE_FIELDS.has(key):
			return {"accepted": false, "reason": &"unknown_field"}
		var value: Variant = event.fields[key_variant]
		if not _valid_field_value(key, value, false):
			return {"accepted": false, "reason": &"invalid_field_value"}
		safe_fields[key] = value

	return {
		"accepted": true,
		"reason": &"ok",
		"event": {
			"sequence": 0,
			"session_id": event.session_id,
			"event_code": _CODE_NAMES[event.code],
			"severity": _SEVERITY_NAMES[event.severity],
			"physics_tick": event.physics_tick,
			"session_elapsed_physics_seconds": event.session_elapsed_physics_seconds,
			"fields": _canonical_fields(safe_fields),
			"redacted_field_count": redacted,
		},
	}


func _validate_snapshot(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _invalid_snapshot()
	var snapshot := candidate as Dictionary
	var raw_schema: Variant = snapshot.get("schema_version")
	if not _exact_integer(raw_schema):
		return _invalid_snapshot()
	var schema := int(raw_schema)
	if schema > SCHEMA_VERSION:
		return _invalid_snapshot(&"newer_schema")
	if schema != SCHEMA_VERSION:
		return _invalid_snapshot(&"unsupported_schema")
	if not _has_exact_keys(snapshot, _SNAPSHOT_KEYS):
		return _invalid_snapshot()
	if not _exact_integer(snapshot.capacity) or int(snapshot.capacity) != MAX_EVENTS:
		return _invalid_snapshot()
	if not _exact_integer(snapshot.next_sequence) \
		or int(snapshot.next_sequence) < 1 \
		or int(snapshot.next_sequence) > MAX_FIELD_INTEGER:
		return _invalid_snapshot()
	if not _exact_integer(snapshot.dropped_event_count) \
		or int(snapshot.dropped_event_count) < 0 \
		or int(snapshot.dropped_event_count) > MAX_FIELD_INTEGER:
		return _invalid_snapshot()
	if not snapshot.events is Array or (snapshot.events as Array).size() > MAX_EVENTS:
		return _invalid_snapshot()
	if int(snapshot.dropped_event_count) > 0 and (snapshot.events as Array).size() != MAX_EVENTS:
		return _invalid_snapshot()

	var canonical_events: Array[Dictionary] = []
	var previous_sequence := 0
	for event_variant in snapshot.events as Array:
		var validated_event := _validate_stored_event(event_variant, previous_sequence, int(snapshot.next_sequence))
		if not bool(validated_event.accepted):
			return _invalid_snapshot()
		var event := validated_event.event as Dictionary
		previous_sequence = int(event.sequence)
		canonical_events.append(event)
	if int(snapshot.next_sequence) - 1 - int(snapshot.dropped_event_count) != canonical_events.size():
		return _invalid_snapshot()
	if not canonical_events.is_empty() \
		and int(canonical_events[0].sequence) != int(snapshot.dropped_event_count) + 1:
		return _invalid_snapshot()
	if not canonical_events.is_empty() \
		and int(canonical_events[-1].sequence) + 1 != int(snapshot.next_sequence):
		return _invalid_snapshot()
	return {
		"accepted": true,
		"snapshot": {
			"schema_version": SCHEMA_VERSION,
			"capacity": MAX_EVENTS,
			"next_sequence": int(snapshot.next_sequence),
			"dropped_event_count": int(snapshot.dropped_event_count),
			"events": canonical_events,
		},
	}


static func _invalid_snapshot(reason: StringName = &"invalid_snapshot") -> Dictionary:
	return {"accepted": false, "reason": reason}


static func _record_rejection(validation: Dictionary) -> Dictionary:
	var record_reason := StringName(validation.get("reason", &"invalid_snapshot"))
	return {
		"accepted": false,
		"reason": &"record_schema_newer" if record_reason == &"newer_schema" else &"invalid_record",
		"record_reason": record_reason,
	}


func _validate_stored_event(candidate: Variant, previous_sequence: int, next_sequence: int) -> Dictionary:
	if not candidate is Dictionary:
		return {"accepted": false}
	var event := candidate as Dictionary
	if not _has_exact_keys(event, _EVENT_KEYS):
		return {"accepted": false}
	if not _exact_integer(event.sequence) \
		or int(event.sequence) <= previous_sequence \
		or int(event.sequence) >= next_sequence:
		return {"accepted": false}
	if not _exact_integer(event.session_id) or not _valid_session_id(int(event.session_id)):
		return {"accepted": false}
	if not event.event_code is String or not _CODE_NAMES.has(event.event_code):
		return {"accepted": false}
	if not event.severity is String or not _SEVERITY_NAMES.has(event.severity):
		return {"accepted": false}
	if not _exact_integer(event.physics_tick) \
		or int(event.physics_tick) < 0 \
		or int(event.physics_tick) > MAX_PHYSICS_TICK:
		return {"accepted": false}
	if not event.session_elapsed_physics_seconds is float \
		and not event.session_elapsed_physics_seconds is int:
		return {"accepted": false}
	if not _valid_elapsed(float(event.session_elapsed_physics_seconds)):
		return {"accepted": false}
	if not event.fields is Dictionary or (event.fields as Dictionary).size() > MAX_INPUT_FIELDS:
		return {"accepted": false}
	var fields := event.fields as Dictionary
	for key_variant in fields:
		if not key_variant is String or not _SAFE_FIELDS.has(key_variant):
			return {"accepted": false}
		if not _valid_field_value(str(key_variant), fields[key_variant], true):
			return {"accepted": false}
	if not _exact_integer(event.redacted_field_count) \
		or int(event.redacted_field_count) < 0 \
		or int(event.redacted_field_count) > MAX_INPUT_FIELDS:
		return {"accepted": false}
	if fields.size() + int(event.redacted_field_count) > MAX_INPUT_FIELDS:
		return {"accepted": false}
	return {"accepted": true, "event": _canonical_event(event)}


func _canonical_event(event: Dictionary) -> Dictionary:
	return {
		"sequence": int(event.sequence),
		"session_id": int(event.session_id),
		"event_code": str(event.event_code),
		"severity": str(event.severity),
		"physics_tick": int(event.physics_tick),
		"session_elapsed_physics_seconds": float(event.session_elapsed_physics_seconds),
		"fields": _canonical_fields(event.fields as Dictionary),
		"redacted_field_count": int(event.redacted_field_count),
	}


func _canonical_fields(fields: Dictionary) -> Dictionary:
	var result := {}
	var keys := fields.keys()
	keys.sort()
	for key in keys:
		var key_string := str(key)
		if _INTEGER_FIELDS.has(key_string):
			result[key_string] = int(fields[key])
		elif _FLOAT_FIELDS.has(key_string):
			result[key_string] = float(fields[key])
		elif _BOOLEAN_FIELDS.has(key_string):
			result[key_string] = bool(fields[key])
	return result


func _record_result(
	accepted: bool,
	reason: StringName,
	sequence: int = 0,
	redacted_field_count: int = 0
	) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"sequence": sequence,
		"redacted_field_count": redacted_field_count,
		"retained_event_count": _events.size(),
		"dropped_event_count": _dropped_event_count,
	}


func _lifecycle_result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"attached": _attached,
		"attached_session_id": _attached_session_id,
	}


static func _valid_session_id(session_id: int) -> bool:
	return session_id > 0 and session_id <= MAX_SESSION_ID


static func _valid_elapsed(value: float) -> bool:
	return not is_nan(value) and not is_inf(value) \
		and value >= 0.0 and value <= MAX_SESSION_PHYSICS_SECONDS


static func _valid_field_value(key: String, value: Variant, from_json_wire: bool) -> bool:
	if _BOOLEAN_FIELDS.has(key):
		return value is bool
	if _INTEGER_FIELDS.has(key):
		if from_json_wire:
			if not _exact_integer(value):
				return false
		elif not value is int:
			return false
		var integer := int(value)
		match key:
			"attempt_count", "entity_count":
				return integer >= 0 and integer <= MAX_COUNT
			"error_code":
				return integer >= -MAX_ERROR_CODE - 1 and integer <= MAX_ERROR_CODE
			"input_device_code":
				return integer >= 0 and integer <= MAX_INPUT_DEVICE_CODE
			"peer_count":
				return integer >= 0 and integer <= MAX_PEER_COUNT
		return false
	if _FLOAT_FIELDS.has(key):
		if not value is int and not value is float:
			return false
		var number := float(value)
		if is_nan(number) or is_inf(number):
			return false
		match key:
			"damage_ratio":
				return number >= 0.0 and number <= 1.0
			"duration_physics_seconds":
				return number >= 0.0 and number <= MAX_SESSION_PHYSICS_SECONDS
			"frame_delta_seconds":
				return number >= 0.0 and number <= MAX_FRAME_DELTA_SECONDS
			"speed_metres_per_second":
				return number >= 0.0 and number <= MAX_SPEED_METRES_PER_SECOND
		return false
	return false


static func _contains_marker(value: String, markers: Array) -> bool:
	for marker in markers:
		if value.contains(str(marker)):
			return true
	return false


static func _has_exact_keys(dictionary: Dictionary, expected: Array) -> bool:
	if dictionary.size() != expected.size():
		return false
	for key in expected:
		if not dictionary.has(key):
			return false
	for key in dictionary:
		if not key is String or not expected.has(key):
			return false
	return true


static func _exact_integer(value: Variant) -> bool:
	if value is int:
		return int(value) >= -MAX_FIELD_INTEGER and int(value) <= MAX_FIELD_INTEGER
	if not value is float:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) \
		and number == floor(number) and absf(number) <= MAX_FIELD_INTEGER


static func _valid_commit_token(commit_id: String) -> bool:
	if commit_id.length() < 1 or commit_id.length() > 64:
		return false
	for character in commit_id:
		var code := character.unicode_at(0)
		var allowed := (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or character in ["-", "_", ".", ":"]
		if not allowed:
			return false
	return true
