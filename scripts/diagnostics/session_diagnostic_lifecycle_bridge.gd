class_name SessionDiagnosticLifecycleBridge
extends RefCounted

## Caller-driven lifecycle composition for privacy-safe session diagnostics.
## It owns no process hooks, clock, GameFlow, or gameplay state: callers provide
## session identity, progress, and commit IDs at each explicit boundary.

const Coordinator := preload("res://scripts/diagnostics/crash_recovery_coordinator.gd")
const Record := preload("res://scripts/diagnostics/session_diagnostic_record.gd")

const STATE_IDLE := "idle"
const STATE_STARTING := "starting"
const STATE_STABLE := "stable"
const STATE_CLEAN := "clean"

var _coordinator: CrashRecoveryCoordinator
var _record: SessionDiagnosticRecord
var _sink: RefCounted
var _state := STATE_IDLE
var _session_id := 0
var _recovery_flush_pending := false
var _last_status: Dictionary = {}


func _init(
		coordinator: CrashRecoveryCoordinator,
		diagnostic_record: SessionDiagnosticRecord,
		file_sink: RefCounted
		) -> void:
	_coordinator = coordinator
	_record = diagnostic_record
	_sink = file_sink


## Starts the marker-backed session and flushes a prior unfinished-session
## event when the coordinator reports recovery. Sink failure remains retryable.
func begin_session(session_id: int, commit_id: String, physics_tick: int, elapsed_physics_seconds: float) -> Dictionary:
	if _coordinator == null or _record == null or _sink == null:
		return _status(false, &"bridge_unavailable")
	var begun := _coordinator.begin_session(session_id, commit_id)
	if not bool(begun.accepted):
		return _status(false, &"begin_failed", {"coordinator_status": begun})
	_session_id = session_id
	_state = STATE_STARTING
	var attached := _record.attach_session(session_id)
	if not bool(attached.accepted) and attached.reason != &"already_attached":
		return _status(false, &"diagnostic_attach_failed", {"record_status": attached})
	if bool(begun.get("recovered", false)):
		var flushed := _coordinator.publish_recovery_event(
			_record, _sink, physics_tick, elapsed_physics_seconds
		)
		_recovery_flush_pending = not bool(flushed.accepted)
		_last_status = _status(true, &"recovered" if not _recovery_flush_pending else &"recovered_flush_pending", {
			"coordinator_status": begun,
			"flush_status": flushed,
		})
		return _last_status.duplicate(true)
	_recovery_flush_pending = false
	_last_status = _status(true, &"started", {"coordinator_status": begun})
	return _last_status.duplicate(true)


## Retries publication of the one recovery event without recording another one.
func flush_recovery_event(physics_tick: int, elapsed_physics_seconds: float) -> Dictionary:
	if not _recovery_flush_pending:
		return _status(false, &"no_recovery_flush_pending")
	var flushed := _coordinator.publish_recovery_event(
		_record, _sink, physics_tick, elapsed_physics_seconds
	)
	if bool(flushed.accepted):
		_recovery_flush_pending = false
	_last_status = _status(bool(flushed.accepted), &"recovery_flushed" if bool(flushed.accepted) else &"recovery_flush_failed", {
		"flush_status": flushed,
	})
	return _last_status.duplicate(true)


## Marks the caller-confirmed stable checkpoint. Repeating it is an idempotent
## success, while checkpoint persistence remains coordinator-owned.
func mark_stable(
		physics_tick: int,
		elapsed_physics_seconds: float,
		commit_id: String
		) -> Dictionary:
	if _state == STATE_STABLE:
		return _status(true, &"already_stable")
	if _state != STATE_STARTING:
		return _status(false, &"session_not_starting")
	var checkpoint := _coordinator.checkpoint(
		_session_id, physics_tick, elapsed_physics_seconds, commit_id
	)
	if not bool(checkpoint.accepted):
		return _status(false, &"stable_checkpoint_failed", {"coordinator_status": checkpoint})
	_state = STATE_STABLE
	_last_status = _status(true, &"stable", {"coordinator_status": checkpoint})
	return _last_status.duplicate(true)


## Records an explicit orderly shutdown. An omitted call leaves the coordinator
## running, so the next begin_session can report an unfinished session.
func mark_orderly_shutdown(
		physics_tick: int,
		elapsed_physics_seconds: float,
		commit_id: String
		) -> Dictionary:
	if _state not in [STATE_STARTING, STATE_STABLE]:
		return _status(false, &"session_not_open")
	var closed := _coordinator.mark_clean_shutdown(
		_session_id, physics_tick, elapsed_physics_seconds, commit_id
	)
	if not bool(closed.accepted):
		return _status(false, &"orderly_shutdown_failed", {"coordinator_status": closed})
	_state = STATE_CLEAN
	_last_status = _status(true, &"orderly_shutdown", {"coordinator_status": closed})
	return _last_status.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"state": _state,
		"session_id": _session_id,
		"recovery_flush_pending": _recovery_flush_pending,
		"last_status": _last_status.duplicate(true),
		"coordinator": _coordinator.get_snapshot() if _coordinator != null else {},
		"record": _record.get_snapshot() if _record != null else {},
	}.duplicate(true)


func _status(accepted: bool, reason: StringName, details: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"state": _state,
		"session_id": _session_id,
		"recovery_flush_pending": _recovery_flush_pending,
	}
	result.merge(details, true)
	return result.duplicate(true)
