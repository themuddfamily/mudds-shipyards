class_name SessionDiagnosticLifecycleBridge
extends RefCounted

## Caller-driven lifecycle composition for privacy-safe session diagnostics.
## It owns no process hooks, clock, GameFlow, or gameplay state: callers provide
## session identity, progress, and commit IDs at each explicit boundary.

const Coordinator := preload("res://scripts/diagnostics/crash_recovery_coordinator.gd")
const Record := preload("res://scripts/diagnostics/session_diagnostic_record.gd")
const SessionDiagnosticEvent := preload("res://scripts/diagnostics/session_diagnostic_event.gd")

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
var _network_generation := 0
var _recovery_available_snapshot: Dictionary = {}
var _recovery_choice_generation := -1


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
	var prior := _coordinator.get_snapshot()
	var prior_was_unclean := StringName(prior.get("state", &"")) == &"running"
	var begun := _coordinator.begin_session(session_id, commit_id)
	if not bool(begun.accepted):
		return _status(false, &"begin_failed", {"coordinator_status": begun})
	_session_id = session_id
	_state = STATE_STARTING
	var attached := _record.attach_session(session_id)
	if not bool(attached.accepted) and attached.reason != &"already_attached":
		return _status(false, &"diagnostic_attach_failed", {"record_status": attached})
	if bool(begun.get("recovered", false)):
		if prior_was_unclean:
			_recovery_available_snapshot = prior.duplicate(true)
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


func get_recovery_available_snapshot() -> Dictionary:
	return _recovery_available_snapshot.duplicate(true)


## Explicit caller acknowledgement retires only the detached recovery receipt.
func acknowledge_recovery() -> Dictionary:
	if _recovery_available_snapshot.is_empty():
		return _status(false, &"no_recovery_available")
	_recovery_available_snapshot.clear()
	return _status(true, &"recovery_acknowledged")


## Explicit discard has the same narrow authority as acknowledgement: it clears
## only the in-memory receipt, never the marker, save store, or diagnostics log.
func discard_recovery() -> Dictionary:
	if _recovery_available_snapshot.is_empty():
		return _status(false, &"no_recovery_available")
	_recovery_available_snapshot.clear()
	return _status(true, &"recovery_discarded")


## Returns caller-choice startup guidance only; it never applies a settings
## patch or changes the marker. The optional policy patch is already validated
## by SafeStartRecoveryPolicy and remains inert until an owner chooses it.
func get_recovery_recommendation(safe_start_patch: Dictionary = {}) -> Dictionary:
	if _recovery_available_snapshot.is_empty():
		return {"available": false, "requires_caller_choice": false}
	var failures := int(_recovery_available_snapshot.get("unclean_start_count", 0))
	var severity: StringName = &"safe_graphics_recommended" if failures >= 3 else &"review_prior_session"
	return {
		"available": true,
		"requires_caller_choice": true,
		"severity": severity,
		"choices": [&"normal_start", &"safe_graphics_windowed", &"discard"],
		"safe_start_patch": safe_start_patch.duplicate(true),
		"applies_settings": false,
		"persists_settings": false,
	}.duplicate(true)


## Executes exactly one caller-authorized choice. Safe graphics application is
## delegated to SafeStartRecoveryPolicy's production owner; normal/discard do
## not touch settings. A failed safe choice leaves the receipt available.
func choose_recovery(choice: StringName, safe_graphics_apply: Callable = Callable()) -> Dictionary:
	if _recovery_available_snapshot.is_empty():
		return _status(false, &"no_recovery_available")
	var generation := int(_recovery_available_snapshot.get("startup_generation", 0))
	if generation <= 0 or _recovery_choice_generation == generation:
		return _status(false, &"recovery_choice_replayed")
	match choice:
		&"normal_start":
			_recovery_choice_generation = generation
			return acknowledge_recovery()
		&"discard":
			_recovery_choice_generation = generation
			return discard_recovery()
		&"safe_graphics_windowed":
			if not safe_graphics_apply.is_valid():
				return _status(false, &"safe_graphics_unavailable")
			var applied := safe_graphics_apply.call(generation) as Dictionary
			if not bool(applied.get("accepted", false)):
				return applied
			_recovery_choice_generation = generation
			return acknowledge_recovery()
		_:
			return _status(false, &"invalid_recovery_choice")


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
		"recovery_available": not _recovery_available_snapshot.is_empty(),
		"recovery_snapshot": _recovery_available_snapshot.duplicate(true),
		"last_status": _last_status.duplicate(true),
		"coordinator": _coordinator.get_snapshot() if _coordinator != null else {},
		"record": _record.get_snapshot() if _record != null else {},
	}.duplicate(true)


## Records a privacy-safe network observation supplied by the network adapter.
## Only bounded numeric fields enter SessionDiagnosticRecord; addresses, tokens,
## packet payloads, and transport authority never cross this seam.
func record_network_observation(
		session_id: int,
		physics_tick: int,
		elapsed_physics_seconds: float,
		generation: int,
		reason_code: int,
		quality: Dictionary
) -> Dictionary:
	if _state not in [STATE_STARTING, STATE_STABLE]:
		return _status(false, &"session_not_open")
	if generation <= 0 or (_network_generation > 0 and generation < _network_generation):
		return _status(false, &"stale_network_generation")
	_network_generation = generation
	var event := SessionDiagnosticEvent.new(
		SessionDiagnosticEvent.Code.SESSION_ENDED,
		SessionDiagnosticEvent.Severity.INFO,
		session_id,
		physics_tick,
		elapsed_physics_seconds,
		{
			"error_code": maxi(0, reason_code),
			"attempt_count": maxi(0, generation),
			"entity_count": clampi(int(quality.get("accepted_count", 0)), 0, 1000000),
			"peer_count": clampi(int(quality.get("released_count", 0)), 0, 4096),
			"recovered": int(quality.get("pending_depth", 0)) == 0,
		}
	)
	var recorded := _record.record(event)
	_last_status = _status(bool(recorded.accepted), &"network_recorded" if bool(recorded.accepted) else &"network_record_failed", {
		"record_status": recorded,
		"generation": generation,
	})
	return _last_status.duplicate(true)


## Records a bounded GameFlow lifecycle transition. Numeric codes are caller
## owned enums; no names, paths, coordinates, or free text cross the boundary.
func record_lifecycle_transition(
		transition_code: int,
		entity_code: int = 0,
		active: bool = true
		) -> Dictionary:
	if _state not in [STATE_STARTING, STATE_STABLE]:
		return _status(false, &"session_not_open")
	if transition_code < 1 or transition_code > 32:
		return _status(false, &"invalid_transition_code")
	if entity_code < 0 or entity_code > 1000000:
		return _status(false, &"invalid_entity_code")
	var event := SessionDiagnosticEvent.new(
		SessionDiagnosticEvent.Code.CONTROL_SOURCE_CHANGED,
		SessionDiagnosticEvent.Severity.INFO,
		_session_id,
		0,
		0.0,
		{
			"input_device_code": transition_code,
			"entity_count": entity_code,
			"recovered": active,
		}
	)
	var recorded := _record.record(event)
	_last_status = _status(
		bool(recorded.accepted),
		&"lifecycle_recorded" if bool(recorded.accepted) else &"lifecycle_record_failed",
		{"record_status": recorded}
	)
	return _last_status.duplicate(true)


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
