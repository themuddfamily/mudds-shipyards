class_name SaveReentryLifecycle
extends RefCounted

## Generation-safe save/checkpoint lifecycle for a caller-owned session.
##
## This is intentionally a persistence contract, not a save-game authority. It
## validates and atomically stores one opaque JSON-safe payload, while the
## caller remains responsible for constructing gameplay state and restoring it
## into the production scene. Detach/re-entry changes only the attachment
## generation; it never replays a checkpoint or silently creates a new session.

const Store := preload("res://scripts/persistence/user_data_store.gd")

const SCHEMA_VERSION := 1
const PAYLOAD_NAMESPACE := "save_reentry"
const MAX_IDENTIFIER_BYTES := 128
const MAX_SESSION_ID := 9_007_199_254_740_991
const MAX_ATTACHMENT_GENERATION := 9_007_199_254_740_991
const MAX_CHECKPOINT_GENERATION := 9_007_199_254_740_991
const MAX_PHYSICS_TICK := 9_007_199_254_740_991

const STATE_IDLE := "idle"
const STATE_ACTIVE := "active"
const STATE_DETACHED := "detached"
const STATE_CLOSED := "closed"

const _SNAPSHOT_KEYS := [
	"schema_version",
	"state",
	"slot_id",
	"session_id",
	"attachment_generation",
	"checkpoint_generation",
	"physics_tick",
	"payload",
]
const _STATES := [STATE_IDLE, STATE_ACTIVE, STATE_DETACHED, STATE_CLOSED]

var _store: UserDataStore
var _restored := false
var _operation_active := false
var _state := STATE_IDLE
var _slot_id := ""
var _session_id := 0
var _attachment_generation := 0
var _checkpoint_generation := 0
var _physics_tick := 0
var _payload: Dictionary = {}


func _init(store: UserDataStore = null) -> void:
	_store = store


## Restores only the already-loaded store. Missing save state is a valid first
## run; malformed/newer state is rejected without changing this lifecycle.
func restore() -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call")
	_operation_active = true
	var result := _restore()
	_operation_active = false
	return result


## Starts a fresh logical session. A detached session must use reenter_session;
## accepting open_session there would make a stale scene look current.
func open_session(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		commit_id: String
		) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call")
	_operation_active = true
	var result := _open_session(slot_id, session_id, attachment_generation, commit_id)
	_operation_active = false
	return result


## Saves an opaque caller-owned checkpoint. Physics ticks and checkpoint
## generations are monotonic, and all validation happens before any store write.
func save_checkpoint(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		physics_tick: int,
		payload: Dictionary,
		commit_id: String
		) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call")
	_operation_active = true
	var result := _save_checkpoint(
		slot_id, session_id, attachment_generation, physics_tick, payload, commit_id
	)
	_operation_active = false
	return result


## Marks a live session detached. The last accepted payload remains untouched;
## a detached scene is never implicitly saved or advanced.
func detach_session(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		commit_id: String
		) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call")
	_operation_active = true
	var result := _detach_session(slot_id, session_id, attachment_generation, commit_id)
	_operation_active = false
	return result


## Reattaches the exact detached logical session at exactly the next
## attachment generation. It restores the retained snapshot but does not
## synthesize a checkpoint or advance physics progress.
func reenter_session(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		commit_id: String
		) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call")
	_operation_active = true
	var result := _reenter_session(slot_id, session_id, attachment_generation, commit_id)
	_operation_active = false
	return result


## Retries recovery of the last safe checkpoint after an interrupted detach or
## re-entry handoff. A detached session advances exactly once; an already
## active session is an idempotent success so a lost response cannot strand it.
func recover_last_safe_checkpoint(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		commit_id: String
		) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call")
	_operation_active = true
	var result := _recover_last_safe_checkpoint(
		slot_id, session_id, attachment_generation, commit_id
	)
	_operation_active = false
	return result


## Closes the logical session without discarding its last checkpoint. A later
## process can inspect the closed payload and explicitly open a new session.
func close_session(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		commit_id: String
		) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call")
	_operation_active = true
	var result := _close_session(slot_id, session_id, attachment_generation, commit_id)
	_operation_active = false
	return result


func get_snapshot() -> Dictionary:
	return _snapshot().duplicate(true)


func audit() -> Dictionary:
	var decoded := decode_snapshot(_snapshot())
	return {
		"valid": bool(decoded.accepted),
		"reason": decoded.reason,
		"snapshot": get_snapshot(),
		"limits": {
			"maximum_identifier_bytes": MAX_IDENTIFIER_BYTES,
			"maximum_session_id": MAX_SESSION_ID,
			"maximum_attachment_generation": MAX_ATTACHMENT_GENERATION,
			"maximum_checkpoint_generation": MAX_CHECKPOINT_GENERATION,
			"maximum_physics_tick": MAX_PHYSICS_TICK,
		},
		"authority": {
			"gameplay": false,
			"scene_restore": false,
			"clock": false,
			"filesystem": false,
			"commit_identity": false,
		},
	}.duplicate(true)


static func decode_snapshot(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _rejection(&"snapshot_not_dictionary")
	var raw := candidate as Dictionary
	if not _has_exact_keys(raw, _SNAPSHOT_KEYS):
		return _rejection(&"snapshot_fields_invalid")
	if not _is_integer(raw.get("schema_version")):
		return _rejection(&"schema_invalid")
	var schema := int(raw.schema_version)
	if schema > SCHEMA_VERSION:
		return _rejection(&"newer_schema")
	if schema != SCHEMA_VERSION:
		return _rejection(&"unsupported_schema")
	if not raw.state is String or not _STATES.has(raw.state):
		return _rejection(&"state_invalid")
	var state := str(raw.state)
	if not _valid_identifier(raw.slot_id, false):
		return _rejection(&"slot_id_invalid")
	if not _valid_bounded_integer(raw.session_id, 0, MAX_SESSION_ID):
		return _rejection(&"session_id_invalid")
	if not _valid_bounded_integer(raw.attachment_generation, 0, MAX_ATTACHMENT_GENERATION):
		return _rejection(&"attachment_generation_invalid")
	if not _valid_bounded_integer(raw.checkpoint_generation, 0, MAX_CHECKPOINT_GENERATION):
		return _rejection(&"checkpoint_generation_invalid")
	if not _valid_bounded_integer(raw.physics_tick, 0, MAX_PHYSICS_TICK):
		return _rejection(&"physics_tick_invalid")
	var payload_validation := Store.validate_payload(raw.payload)
	if not bool(payload_validation.valid):
		return _rejection(&"payload_invalid")
	if state == STATE_IDLE:
		if raw.slot_id != "" or int(raw.session_id) != 0 \
			or int(raw.attachment_generation) != 0 \
			or int(raw.checkpoint_generation) != 0 or int(raw.physics_tick) != 0 \
			or not (raw.payload as Dictionary).is_empty():
			return _rejection(&"idle_state_invalid")
	if state in [STATE_ACTIVE, STATE_DETACHED, STATE_CLOSED]:
		if not _valid_identifier(raw.slot_id, true) or int(raw.session_id) <= 0 \
			or int(raw.attachment_generation) <= 0:
			return _rejection(&"active_identity_invalid")
	if state == STATE_ACTIVE and int(raw.checkpoint_generation) == 0 \
		and int(raw.physics_tick) != 0:
		return _rejection(&"initial_progress_invalid")
	return {
		"accepted": true,
		"reason": &"valid",
		"snapshot": raw.duplicate(true),
	}


func _restore() -> Dictionary:
	if _store == null:
		return _result(false, &"no_store")
	if _store.get_loaded_source() == &"none":
		return _result(false, &"store_not_loaded")
	var stored := _store.get_snapshot()
	if not stored.has(PAYLOAD_NAMESPACE):
		_reset()
		_restored = true
		return _result(true, &"empty")
	var decoded := decode_snapshot(stored.get(PAYLOAD_NAMESPACE))
	if not bool(decoded.accepted):
		return _result(false, StringName(decoded.reason))
	_install(decoded.snapshot as Dictionary)
	_restored = true
	return _result(true, &"restored")


func _open_session(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		commit_id: String
		) -> Dictionary:
	if not _restored:
		return _result(false, &"not_restored")
	if _state in [STATE_ACTIVE, STATE_DETACHED]:
		return _result(false, &"session_already_open")
	if not _valid_identifier(slot_id, true):
		return _result(false, &"slot_id_invalid")
	if not _valid_bounded_integer(session_id, 1, MAX_SESSION_ID):
		return _result(false, &"session_id_invalid")
	if not _valid_bounded_integer(attachment_generation, 1, MAX_ATTACHMENT_GENERATION):
		return _result(false, &"attachment_generation_invalid")
	var candidate := _snapshot()
	candidate["state"] = STATE_ACTIVE
	candidate["slot_id"] = slot_id
	candidate["session_id"] = session_id
	candidate["attachment_generation"] = attachment_generation
	candidate["checkpoint_generation"] = 0
	candidate["physics_tick"] = 0
	candidate["payload"] = {}
	return _commit_candidate(candidate, commit_id, &"opened")


func _save_checkpoint(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		physics_tick: int,
		payload: Dictionary,
		commit_id: String
		) -> Dictionary:
	var identity := _check_identity(slot_id, session_id, attachment_generation, true)
	if not bool(identity.accepted):
		return identity
	if _state != STATE_ACTIVE:
		return _result(false, &"session_not_active")
	if not _valid_bounded_integer(physics_tick, _physics_tick, MAX_PHYSICS_TICK):
		return _result(false, &"physics_tick_regressed")
	if not bool(Store.validate_payload(payload).valid):
		return _result(false, &"payload_invalid")
	if _checkpoint_generation >= MAX_CHECKPOINT_GENERATION:
		return _result(false, &"checkpoint_generation_exhausted")
	var candidate := _snapshot()
	candidate["checkpoint_generation"] = _checkpoint_generation + 1
	candidate["physics_tick"] = physics_tick
	candidate["payload"] = payload.duplicate(true)
	return _commit_candidate(candidate, commit_id, &"checkpointed")


func _detach_session(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		commit_id: String
		) -> Dictionary:
	var identity := _check_identity(slot_id, session_id, attachment_generation, true)
	if not bool(identity.accepted):
		return identity
	if _state != STATE_ACTIVE:
		return _result(false, &"session_not_active")
	var candidate := _snapshot()
	candidate["state"] = STATE_DETACHED
	return _commit_candidate(candidate, commit_id, &"detached")


func _reenter_session(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		commit_id: String
		) -> Dictionary:
	var identity := _check_identity(slot_id, session_id, attachment_generation - 1, false)
	if not bool(identity.accepted):
		return identity
	if _state != STATE_DETACHED:
		return _result(false, &"session_not_detached")
	if attachment_generation != _attachment_generation + 1:
		return _result(false, &"stale_attachment_generation")
	if attachment_generation > MAX_ATTACHMENT_GENERATION:
		return _result(false, &"attachment_generation_exhausted")
	var candidate := _snapshot()
	candidate["state"] = STATE_ACTIVE
	candidate["attachment_generation"] = attachment_generation
	return _commit_candidate(candidate, commit_id, &"reentered")


func _recover_last_safe_checkpoint(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		commit_id: String
		) -> Dictionary:
	if _state == STATE_ACTIVE:
		var active_identity := _check_identity(slot_id, session_id, attachment_generation, true)
		if not bool(active_identity.accepted):
			return active_identity
		return _result(true, &"already_active")
	if _state == STATE_DETACHED:
		return _reenter_session(slot_id, session_id, attachment_generation, commit_id)
	return _result(false, &"session_not_recoverable")


func _close_session(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		commit_id: String
		) -> Dictionary:
	var identity := _check_identity(slot_id, session_id, attachment_generation, true)
	if not bool(identity.accepted):
		return identity
	if _state not in [STATE_ACTIVE, STATE_DETACHED]:
		return _result(false, &"session_not_open")
	var candidate := _snapshot()
	candidate["state"] = STATE_CLOSED
	return _commit_candidate(candidate, commit_id, &"closed")


func _check_identity(
		slot_id: String,
		session_id: int,
		attachment_generation: int,
		require_attachment: bool
		) -> Dictionary:
	if not _restored:
		return _result(false, &"not_restored")
	if slot_id != _slot_id or session_id != _session_id:
		return _result(false, &"wrong_session")
	if require_attachment and attachment_generation != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	return {"accepted": true}


func _commit_candidate(candidate: Dictionary, commit_id: String, reason: StringName) -> Dictionary:
	if _store == null:
		return _result(false, &"no_store")
	var decoded := decode_snapshot(candidate)
	if not bool(decoded.accepted):
		return _result(false, StringName(decoded.reason))
	var payload := _store.get_snapshot()
	payload[PAYLOAD_NAMESPACE] = candidate.duplicate(true)
	var committed := _store.commit(payload, _store.get_generation(), commit_id)
	if not bool(committed.accepted):
		return _result(false, &"store_commit_failed", {"store_status": committed})
	_install(candidate)
	return _result(true, reason, {"generation": int(committed.generation)})


func _snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"state": _state,
		"slot_id": _slot_id,
		"session_id": _session_id,
		"attachment_generation": _attachment_generation,
		"checkpoint_generation": _checkpoint_generation,
		"physics_tick": _physics_tick,
		"payload": _payload.duplicate(true),
	}


func _install(snapshot: Dictionary) -> void:
	_state = str(snapshot.state)
	_slot_id = str(snapshot.slot_id)
	_session_id = int(snapshot.session_id)
	_attachment_generation = int(snapshot.attachment_generation)
	_checkpoint_generation = int(snapshot.checkpoint_generation)
	_physics_tick = int(snapshot.physics_tick)
	_payload = (snapshot.payload as Dictionary).duplicate(true)


func _reset() -> void:
	_install({
		"state": STATE_IDLE,
		"slot_id": "",
		"session_id": 0,
		"attachment_generation": 0,
		"checkpoint_generation": 0,
		"physics_tick": 0,
		"payload": {},
	})


func _result(accepted: bool, reason: StringName, details: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"state": _state,
		"slot_id": _slot_id,
		"session_id": _session_id,
		"attachment_generation": _attachment_generation,
		"checkpoint_generation": _checkpoint_generation,
		"physics_tick": _physics_tick,
	}
	result.merge(details, true)
	return result


static func _rejection(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason}


static func _has_exact_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key: Variant in candidate:
		if not key is String or not expected.has(key):
			return false
	for key: String in expected:
		if not candidate.has(key):
			return false
	return true


static func _valid_identifier(value: Variant, required: bool) -> bool:
	if not value is String:
		return false
	var text := value as String
	if text.is_empty():
		return not required
	var bytes := text.to_utf8_buffer()
	if bytes.size() > MAX_IDENTIFIER_BYTES:
		return false
	for byte: int in bytes:
		if byte < 0x21 or byte > 0x7e:
			return false
	return true


static func _valid_bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not _is_integer(value):
		return false
	var number := int(value)
	return number >= minimum and number <= maximum


static func _is_integer(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and number == floor(number) \
		and absf(number) <= 9_007_199_254_740_991.0
