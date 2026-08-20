class_name CrashRecoveryCoordinator
extends RefCounted

## Bounded crash-marker authority for the caller's session lifecycle.
##
## This adapter is deliberately narrower than SafeStartProductionRecovery: it
## does not choose settings, install OS crash hooks, inspect a clock, or infer
## gameplay state. The owner supplies session identity, physics progress, and
## commit identity. A `running` marker is written before the owner enters its
## loop; a later owner can therefore distinguish an unfinished prior process
## from a cleanly closed one. The marker is one UserDataStore namespace and is
## safe to compose with the existing session diagnostic record.

const Event := preload("res://scripts/diagnostics/session_diagnostic_event.gd")

const SCHEMA_VERSION := 1
const PAYLOAD_NAMESPACE := "crash_recovery"
const MAX_SESSION_ID := 9_007_199_254_740_991
const MAX_STARTUP_GENERATION := 9_007_199_254_740_991
const MAX_PHYSICS_TICK := 9_007_199_254_740_991
const MAX_ELAPSED_PHYSICS_SECONDS := 2_592_000.0
const MAX_CONSECUTIVE_UNCLEAN_STARTS := 3
const _STATE_CLEAN := "clean"
const _STATE_RUNNING := "running"
const _SNAPSHOT_KEYS := [
	"schema_version",
	"state",
	"session_id",
	"startup_generation",
	"unclean_start_count",
	"last_physics_tick",
	"last_elapsed_physics_seconds",
]

var _store: UserDataStore
var _restored := false
var _active := false
var _session_id := 0
var _startup_generation := 0
var _unclean_start_count := 0
var _last_physics_tick := 0
var _last_elapsed_physics_seconds := 0.0
var _state := _STATE_CLEAN
var _last_begin_recovered := false
var _last_status: Dictionary = {}


func _init(store: UserDataStore = null) -> void:
	_store = store


## Restores only the already-loaded injected store. A missing namespace is a
## valid first-run state; malformed/newer authority is rejected in place.
func restore() -> Dictionary:
	if _store == null:
		return _status(false, &"no_store")
	if _active:
		return _status(false, &"active_session")
	if _store.get_loaded_source() == &"none":
		return _status(false, &"store_not_loaded")
	var payload := _store.get_snapshot()
	if not payload.has(PAYLOAD_NAMESPACE):
		_reset_clean()
		_restored = true
		return _status(true, &"empty")
	var validated := _validate_snapshot(payload.get(PAYLOAD_NAMESPACE))
	if not bool(validated.accepted):
		return _status(false, StringName(validated.reason))
	_install_snapshot(validated.snapshot as Dictionary)
	_restored = true
	return _status(true, &"restored")


## Writes the running marker before the caller starts its session. If the
## previous marker was running, this begin is a recovery observation, not an
## assertion that an OS crash was captured.
func begin_session(session_id: int, commit_id: String) -> Dictionary:
	if not _restored:
		return _status(false, &"not_restored")
	if _active:
		return _status(false, &"active_session")
	if not _valid_session_id(session_id):
		return _status(false, &"invalid_session_id")
	if _state == _STATE_RUNNING and _session_id > 0:
		_unclean_start_count = mini(
			_unclean_start_count + 1,
			MAX_CONSECUTIVE_UNCLEAN_STARTS
		)
	else:
		_unclean_start_count = 0
	if _startup_generation >= MAX_STARTUP_GENERATION:
		return _status(false, &"startup_generation_exhausted")
	var candidate := {
		"schema_version": SCHEMA_VERSION,
		"state": _STATE_RUNNING,
		"session_id": session_id,
		"startup_generation": _startup_generation + 1,
		"unclean_start_count": _unclean_start_count,
		"last_physics_tick": 0,
		"last_elapsed_physics_seconds": 0.0,
	}
	var committed := _commit(candidate, commit_id)
	if not bool(committed.accepted):
		return committed
	_install_snapshot(candidate)
	_active = true
	_last_begin_recovered = _unclean_start_count > 0
	return _status(
		true,
		&"recovered_previous_session" if _last_begin_recovered else &"started",
		{
			"recovered": _last_begin_recovered,
			"safe_mode_recommended": (
				_unclean_start_count >= MAX_CONSECUTIVE_UNCLEAN_STARTS
			),
		}
	)


## Persists caller-owned progress without allowing time or tick regressions.
## Checkpoint cadence is intentionally owned by the production caller.
func checkpoint(
		session_id: int,
		physics_tick: int,
		elapsed_physics_seconds: float,
		commit_id: String
		) -> Dictionary:
	if not _active:
		return _status(false, &"no_active_session")
	if session_id != _session_id:
		return _status(false, &"wrong_session")
	if not _valid_progress(physics_tick, elapsed_physics_seconds):
		return _status(false, &"invalid_progress")
	if physics_tick < _last_physics_tick \
		or elapsed_physics_seconds < _last_elapsed_physics_seconds:
		return _status(false, &"progress_regressed")
	var candidate := _snapshot()
	candidate["last_physics_tick"] = physics_tick
	candidate["last_elapsed_physics_seconds"] = elapsed_physics_seconds
	var committed := _commit(candidate, commit_id)
	if not bool(committed.accepted):
		return committed
	_install_snapshot(candidate)
	_active = true
	return _status(true, &"checkpointed")


## Marks the current session clean exactly once. A clean close resets the
## consecutive-unfinished counter, so safe-mode advice reflects consecutive
## failures rather than lifetime history.
func mark_clean_shutdown(
		session_id: int,
		physics_tick: int,
		elapsed_physics_seconds: float,
		commit_id: String
		) -> Dictionary:
	if not _active:
		return _status(false, &"no_active_session")
	if session_id != _session_id:
		return _status(false, &"wrong_session")
	if not _valid_progress(physics_tick, elapsed_physics_seconds):
		return _status(false, &"invalid_progress")
	if physics_tick < _last_physics_tick \
		or elapsed_physics_seconds < _last_elapsed_physics_seconds:
		return _status(false, &"progress_regressed")
	var candidate := _snapshot()
	candidate["state"] = _STATE_CLEAN
	candidate["unclean_start_count"] = 0
	candidate["last_physics_tick"] = physics_tick
	candidate["last_elapsed_physics_seconds"] = elapsed_physics_seconds
	var committed := _commit(candidate, commit_id)
	if not bool(committed.accepted):
		return committed
	_install_snapshot(candidate)
	_active = false
	_last_begin_recovered = false
	return _status(true, &"clean_shutdown")


## Typed event input for SessionDiagnosticRecord. The record remains the
## diagnostic store and decides whether/how to retain the event.
func get_recovery_event(
		physics_tick: int,
		elapsed_physics_seconds: float
		) -> Dictionary:
	if not _active or not _last_begin_recovered:
		return {"accepted": false, "reason": &"no_recovery_event"}
	if not _valid_progress(physics_tick, elapsed_physics_seconds):
		return {"accepted": false, "reason": &"invalid_progress"}
	return {
		"accepted": true,
		"event": Event.new(
			Event.Code.CRASH_DETECTED,
			Event.Severity.ERROR,
			_session_id,
			physics_tick,
			elapsed_physics_seconds,
			{
				"attempt_count": _unclean_start_count,
				"recovered": true,
			}
		),
	}


func get_snapshot() -> Dictionary:
	var snapshot := _snapshot()
	snapshot["restored"] = _restored
	snapshot["active"] = _active
	snapshot["last_begin_recovered"] = _last_begin_recovered
	return snapshot.duplicate(true)


func audit() -> Dictionary:
	return {
		"valid": _validate_snapshot(_snapshot()).accepted,
		"limits": {
			"maximum_consecutive_unclean_starts": MAX_CONSECUTIVE_UNCLEAN_STARTS,
			"maximum_elapsed_physics_seconds": MAX_ELAPSED_PHYSICS_SECONDS,
		},
		"authority": {
			"wall_clock": false,
			"os_crash_capture": false,
			"filesystem": false,
			"settings_application": false,
			"gameplay_recovery": false,
			"diagnostic_storage": false,
			"commit_identity": false,
		},
		"snapshot": get_snapshot(),
	}


func _commit(candidate: Dictionary, commit_id: String) -> Dictionary:
	if _store == null:
		return _status(false, &"no_store")
	var payload := _store.get_snapshot()
	var existing: Variant = payload.get(PAYLOAD_NAMESPACE, null)
	if existing != null and not bool(_validate_snapshot(existing).accepted):
		return _status(false, &"existing_marker_invalid")
	payload[PAYLOAD_NAMESPACE] = candidate.duplicate(true)
	var committed := _store.commit(payload, _store.get_generation(), commit_id)
	return {
		"accepted": bool(committed.accepted),
		"reason": StringName(committed.reason),
		"generation": int(committed.generation),
		"rollback_restored": bool(committed.get("rollback_restored", false)),
	}


func _snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"state": _state,
		"session_id": _session_id,
		"startup_generation": _startup_generation,
		"unclean_start_count": _unclean_start_count,
		"last_physics_tick": _last_physics_tick,
		"last_elapsed_physics_seconds": _last_elapsed_physics_seconds,
	}


func _install_snapshot(snapshot: Dictionary) -> void:
	_state = str(snapshot.state)
	_session_id = int(snapshot.session_id)
	_startup_generation = int(snapshot.startup_generation)
	_unclean_start_count = int(snapshot.unclean_start_count)
	_last_physics_tick = int(snapshot.last_physics_tick)
	_last_elapsed_physics_seconds = float(snapshot.last_elapsed_physics_seconds)


func _reset_clean() -> void:
	_state = _STATE_CLEAN
	_session_id = 0
	_startup_generation = 0
	_unclean_start_count = 0
	_last_physics_tick = 0
	_last_elapsed_physics_seconds = 0.0
	_last_begin_recovered = false


func _status(accepted: bool, reason: StringName, details: Dictionary = {}) -> Dictionary:
	_last_status = {
		"accepted": accepted,
		"reason": reason,
		"generation": _store.get_generation() if _store != null else 0,
	}
	_last_status.merge(details, true)
	return _last_status.duplicate(true)


static func _validate_snapshot(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return {"accepted": false, "reason": &"invalid_marker"}
	var snapshot := candidate as Dictionary
	if snapshot.size() != _SNAPSHOT_KEYS.size():
		return {"accepted": false, "reason": &"invalid_marker"}
	for key in snapshot:
		if not key is String or not _SNAPSHOT_KEYS.has(key):
			return {"accepted": false, "reason": &"invalid_marker"}
	if not _exact_integer(snapshot.get("schema_version")) \
		or int(snapshot.get("schema_version")) != SCHEMA_VERSION:
		return {"accepted": false, "reason": &"invalid_marker"}
	if not snapshot.state is String \
		or not ["clean", "running"].has(snapshot.state):
		return {"accepted": false, "reason": &"invalid_marker"}
	for key in [
		"session_id", "startup_generation", "unclean_start_count",
		"last_physics_tick",
	]:
		if not _exact_integer(snapshot.get(key)):
			return {"accepted": false, "reason": &"invalid_marker"}
	if not snapshot.last_elapsed_physics_seconds is float \
		and not snapshot.last_elapsed_physics_seconds is int:
		return {"accepted": false, "reason": &"invalid_marker"}
	if int(snapshot.session_id) < 0 or int(snapshot.session_id) > MAX_SESSION_ID:
		return {"accepted": false, "reason": &"invalid_marker"}
	if int(snapshot.startup_generation) < 0 \
		or int(snapshot.startup_generation) > MAX_STARTUP_GENERATION:
		return {"accepted": false, "reason": &"invalid_marker"}
	if int(snapshot.unclean_start_count) < 0 \
		or int(snapshot.unclean_start_count) > MAX_CONSECUTIVE_UNCLEAN_STARTS:
		return {"accepted": false, "reason": &"invalid_marker"}
	if int(snapshot.last_physics_tick) < 0 \
		or int(snapshot.last_physics_tick) > MAX_PHYSICS_TICK:
		return {"accepted": false, "reason": &"invalid_marker"}
	var elapsed := float(snapshot.last_elapsed_physics_seconds)
	if is_nan(elapsed) or is_inf(elapsed) \
		or elapsed < 0.0 or elapsed > MAX_ELAPSED_PHYSICS_SECONDS:
		return {"accepted": false, "reason": &"invalid_marker"}
	if snapshot.state == _STATE_CLEAN and int(snapshot.unclean_start_count) != 0:
		return {"accepted": false, "reason": &"invalid_marker"}
	if snapshot.state == _STATE_RUNNING and int(snapshot.session_id) <= 0:
		return {"accepted": false, "reason": &"invalid_marker"}
	return {
		"accepted": true,
		"snapshot": {
			"schema_version": SCHEMA_VERSION,
			"state": str(snapshot.state),
			"session_id": int(snapshot.session_id),
			"startup_generation": int(snapshot.startup_generation),
			"unclean_start_count": int(snapshot.unclean_start_count),
			"last_physics_tick": int(snapshot.last_physics_tick),
			"last_elapsed_physics_seconds": elapsed,
		},
	}


static func _valid_session_id(session_id: int) -> bool:
	return session_id > 0 and session_id <= MAX_SESSION_ID


static func _valid_progress(physics_tick: int, elapsed: float) -> bool:
	return physics_tick >= 0 and physics_tick <= MAX_PHYSICS_TICK \
		and not is_nan(elapsed) and not is_inf(elapsed) \
		and elapsed >= 0.0 and elapsed <= MAX_ELAPSED_PHYSICS_SECONDS


static func _exact_integer(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) \
		and number == floor(number) and absf(number) <= MAX_SESSION_ID
