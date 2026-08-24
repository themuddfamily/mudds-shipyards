class_name CinderTimedRaceSession
extends RefCounted

## Production-neutral adapter joining the existing ActivityDirector checkpoint
## route to TimedCheckpointRace. The director remains the only position/radius
## authority and the race remains the only clock/lap/result authority.

const ROUTE: ActivityDefinition = preload(
	"res://assets/activities/cinder_reach_checkpoint_route.tres"
)

signal session_started(snapshot: Dictionary)
signal session_active(snapshot: Dictionary)
signal checkpoint_advanced(snapshot: Dictionary)
signal lap_advanced(snapshot: Dictionary, lap_time_seconds: float)
signal penalty_changed(snapshot: Dictionary)
signal session_completed(snapshot: Dictionary)
signal session_failed(snapshot: Dictionary)
signal session_reset(snapshot: Dictionary)
signal presentation_changed(snapshot: Dictionary)

var _director: ActivityDirector
var _race: TimedCheckpointRace
var _session_generation := 0
var _activity_generation := 0
var _race_generation := 0
var _attached := false
var _mutation_active := false
var _signal_dispatch_active := false
var _session_started_once := false
var _closed := false
var _pending_activity_completion := false
var _pending_race_completion := false
var _pending_race_failure: StringName = &""
var _authority_desynchronized := false
var _presentation_reason: StringName = &""


func _init(
	laps: int = 1,
	countdown_seconds: float = 3.0,
	timeout_seconds: float = 120.0
) -> void:
	_race = TimedCheckpointRace.new(ROUTE, laps, countdown_seconds, timeout_seconds)
	_race.race_started.connect(_on_race_started)
	_race.checkpoint_reached.connect(_on_race_checkpoint_reached)
	_race.lap_completed.connect(_on_race_lap_completed)
	_race.penalty_applied.connect(_on_race_penalty_applied)
	_race.completed.connect(_on_race_completed)
	_race.failed.connect(_on_race_failed)


func attach(director: ActivityDirector, expected_session_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_session_generation != _session_generation:
		return _finish(false, &"stale_generation")
	if _closed:
		return _finish(false, &"closed")
	if _attached:
		return _finish(false, &"already_attached")
	if not _director_owns_shared_route(director):
		return _finish(false, &"route_not_registered")
	if _session_started_once and not _director_state_matches(director):
		return _finish(false, &"director_state_mismatch")
	_director = director
	_connect_director()
	_attached = true
	var result := _finish(true, &"attached")
	_emit_presentation_changed()
	return result


func detach(expected_session_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_session_generation != _session_generation:
		return _finish(false, &"stale_generation")
	if not _attached:
		return _finish(false, &"not_attached")
	_disconnect_director()
	_attached = false
	var result := _finish(true, &"detached")
	_emit_presentation_changed()
	return result


func start(expected_session_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_session_generation != _session_generation:
		return _finish(false, &"stale_generation")
	if not _attached:
		return _finish(false, &"not_attached")
	if not _race.is_configuration_valid():
		return _finish(false, &"invalid_race_configuration")
	if _is_running():
		return _finish(false, &"already_running")
	var activity_start := _director.start_activity(ROUTE.activity_id)
	if not bool(activity_start.get("accepted", false)):
		return _finish(false, &"activity_cannot_start")
	_activity_generation = int(activity_start.get("generation", 0))
	var race_start := _race.start(_race.get_generation())
	if not bool(race_start.get("accepted", false)):
		_director.fail_activity(
			ROUTE.activity_id, &"race_start_coupling_failed", _activity_generation
		)
		return _finish(false, &"race_cannot_start")
	_race_generation = int(race_start.get("generation", 0))
	_session_generation += 1
	_session_started_once = true
	_pending_activity_completion = false
	_pending_race_completion = false
	_pending_race_failure = &""
	_authority_desynchronized = false
	_presentation_reason = &""
	var result := _finish(true, &"started")
	_emit_snapshot_signal(session_started)
	_emit_presentation_changed()
	return result


func advance_physics(delta: float, expected_session_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(expected_session_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	var race_result := _race.advance_physics(delta, _race_generation)
	if not bool(race_result.get("accepted", false)):
		return _finish(false, StringName(race_result.get("reason", &"race_rejected")))
	if _race.get_state() == TimedCheckpointRace.State.FAILED:
		if not _director.fail_activity(
			ROUTE.activity_id, _pending_race_failure, _activity_generation
		):
			return _finish(false, &"authority_desynchronized")
	var result := _finish(true, StringName(race_result.get("reason", &"advanced")))
	_emit_presentation_changed()
	return result


func submit_position(position: Vector3, expected_session_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(expected_session_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if _race.get_state() == TimedCheckpointRace.State.COUNTDOWN:
		# The route remains armed with the director during the countdown, but it
		# must not consume an early gate overlap. Return the live countdown state
		# so callers can keep the player on the start signal and retry unchanged.
		return _finish(false, &"countdown_in_progress")
	if _race.get_state() != TimedCheckpointRace.State.ACTIVE:
		return _finish(false, &"race_not_active")
	var activity_result := _director.submit_position(
		ROUTE.activity_id, position, _activity_generation
	)
	if _authority_desynchronized:
		_terminalize_authority_desynchronization()
		return _finish(false, &"authority_desynchronized")
	if not bool(activity_result.get("accepted", false)):
		_presentation_reason = StringName(
			activity_result.get("reason", &"activity_rejected")
		)
		return _finish(
			false,
			_presentation_reason
		)
	_presentation_reason = &""
	if _pending_activity_completion and not _pending_race_completion:
		if not _start_next_activity_lap():
			return _finish(false, &"authority_desynchronized")
	elif _pending_activity_completion and _pending_race_completion:
		_pending_activity_completion = false
		_pending_race_completion = false
		_emit_snapshot_signal(session_completed)
	var result := _finish(true, &"checkpoint_reached")
	_emit_presentation_changed()
	return result


func apply_penalty(
	seconds: float,
	reason: StringName,
	expected_session_generation: int
) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(expected_session_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	var race_result := _race.apply_penalty(seconds, reason, _race_generation)
	if not bool(race_result.get("accepted", false)):
		return _finish(false, StringName(race_result.get("reason", &"race_rejected")))
	if _race.get_state() == TimedCheckpointRace.State.FAILED:
		if not _director.fail_activity(
			ROUTE.activity_id, _pending_race_failure, _activity_generation
		):
			return _finish(false, &"authority_desynchronized")
	var result := _finish(true, &"penalty_applied")
	_emit_presentation_changed()
	return result


func fail(reason: StringName, expected_session_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(expected_session_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	var race_result := _race.fail(reason, _race_generation)
	if not bool(race_result.get("accepted", false)):
		return _finish(false, StringName(race_result.get("reason", &"race_rejected")))
	if not _director.fail_activity(
		ROUTE.activity_id,
		StringName(race_result.get("failure_reason", &"unspecified_failure")),
		_activity_generation
	):
		return _finish(false, &"authority_desynchronized")
	return _finish(true, &"failed")


func reset(expected_session_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_session_generation != _session_generation:
		return _finish(false, &"stale_generation")
	if not _attached:
		return _finish(false, &"not_attached")
	if not _session_started_once:
		return _finish(false, &"not_started")
	if not _director.reset_activity(ROUTE.activity_id, _activity_generation):
		return _finish(false, &"authority_desynchronized")
	var race_reset := _race.reset(_race_generation)
	if not bool(race_reset.get("accepted", false)):
		return _finish(false, &"authority_desynchronized")
	_activity_generation = int(
		_director.get_activity_snapshot(ROUTE.activity_id).get("generation", 0)
	)
	_race_generation = int(race_reset.get("generation", 0))
	_session_generation += 1
	_pending_activity_completion = false
	_pending_race_completion = false
	_pending_race_failure = &""
	_authority_desynchronized = false
	_presentation_reason = &""
	var result := _finish(true, &"reset")
	_emit_snapshot_signal(session_reset)
	_emit_presentation_changed()
	return result


## Permanently releases signal connections so a RefCounted session cannot keep
## either authority alive after its owner retires the session.
func close(expected_session_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_session_generation != _session_generation:
		return _finish(false, &"stale_generation")
	if _closed:
		return _finish(false, &"already_closed")
	_disconnect_director()
	_disconnect_race()
	_attached = false
	_closed = true
	return _finish(true, &"closed")


func get_session_generation() -> int:
	return _session_generation


func get_presentation_snapshot() -> Dictionary:
	var race_snapshot := _race.get_snapshot()
	var race_state := int(race_snapshot.get("state", TimedCheckpointRace.State.IDLE))
	var current_lap := int(race_snapshot.get("current_lap", 0))
	var laps := int(race_snapshot.get("lap_count", 0))
	var checkpoint_count := ROUTE.get_checkpoint_count()
	var next_checkpoint := int(race_snapshot.get("next_checkpoint_index", 0))
	var total_checkpoint_count := laps * checkpoint_count
	var completed_checkpoint_count := current_lap * checkpoint_count + next_checkpoint
	if race_state == TimedCheckpointRace.State.COMPLETED:
		completed_checkpoint_count = total_checkpoint_count
	var progress := (
		clampf(float(completed_checkpoint_count) / float(total_checkpoint_count), 0.0, 1.0)
		if total_checkpoint_count > 0 else 0.0
	)
	var semantic_checkpoint: StringName = &""
	if race_state == TimedCheckpointRace.State.FAILED:
		semantic_checkpoint = &"race_failed"
	elif _presentation_reason == &"outside_checkpoint":
		semantic_checkpoint = &"race_missed_gate"
	elif completed_checkpoint_count > 0:
		semantic_checkpoint = StringName("race_gate_%d" % completed_checkpoint_count)
	return {
		"activity_id": ROUTE.activity_id,
		"display_name": ROUTE.display_name,
		"session_generation": _session_generation,
		"activity_generation": _activity_generation,
		"race_generation": _race_generation,
		"state": race_state,
		"state_id": _state_id(race_state),
		"attached": _attached,
		"closed": _closed,
		"running": race_state in [
			TimedCheckpointRace.State.COUNTDOWN,
			TimedCheckpointRace.State.ACTIVE,
		],
		"lap_number": mini(current_lap + 1, laps) if laps > 0 else 0,
		"lap_count": laps,
		"next_checkpoint_index": next_checkpoint,
		"checkpoint_count": checkpoint_count,
		"progress_unitless": progress,
		"checkpoint_id": semantic_checkpoint,
		"reset_serial": (
			_session_generation
			if race_state == TimedCheckpointRace.State.IDLE and _session_started_once else 0
		),
		"presentation_reason": _presentation_reason,
		"reward_pending": false,
		"countdown_remaining_seconds": float(race_snapshot.get("countdown_remaining", 0.0)),
		"current_time_seconds": float(race_snapshot.get("current_time_seconds", 0.0)),
		"last_time_seconds": float(race_snapshot.get("last_time_seconds", -1.0)),
		"best_time_seconds": float(race_snapshot.get("best_time_seconds", -1.0)),
		"penalty_seconds": float(race_snapshot.get("penalty_seconds", 0.0)),
		"failure_reason": StringName(race_snapshot.get("failure_reason", &"")),
		"uses_caller_physics_delta": true,
		"owns_checkpoint_geometry": false,
		"grants_rewards": false,
		"ship_authority": false,
		"berth_authority": false,
		"combat_authority": false,
		"network_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var report := get_presentation_snapshot()
	report["valid"] = _race.is_configuration_valid() and (
		not _attached or _director_owns_shared_route(_director)
	)
	report["route_resource_path"] = ROUTE.resource_path
	report["activity_director_authority"] = true
	report["timed_race_authority"] = true
	return report


func _start_next_activity_lap() -> bool:
	var next_start := _director.start_activity(ROUTE.activity_id)
	if not bool(next_start.get("accepted", false)):
		return false
	_activity_generation = int(next_start.get("generation", 0))
	_pending_activity_completion = false
	return true


func _terminalize_authority_desynchronization() -> void:
	_pending_race_failure = &"activity_race_desynchronized"
	if _race.get_state() in [
		TimedCheckpointRace.State.COUNTDOWN,
		TimedCheckpointRace.State.ACTIVE,
	]:
		_race.fail(_pending_race_failure, _race_generation)
	var activity_snapshot := _director.get_activity_snapshot(ROUTE.activity_id)
	if (
		int(activity_snapshot.get("generation", -1)) == _activity_generation
		and int(activity_snapshot.get("state", CheckpointRouteActivity.State.IDLE))
		== CheckpointRouteActivity.State.ACTIVE
	):
		_director.fail_activity(
			ROUTE.activity_id, _pending_race_failure, _activity_generation
		)


func _on_activity_checkpoint_reached(
	activity_id: StringName,
	checkpoint_index: int,
	generation: int
) -> void:
	if not _accepts_activity_signal(activity_id, generation):
		return
	if _authority_desynchronized:
		return
	var race_result := _race.submit_checkpoint(checkpoint_index, _race_generation)
	if not bool(race_result.get("accepted", false)):
		_authority_desynchronized = true
		if not _mutation_active:
			_terminalize_authority_desynchronization()


func _on_activity_completed(activity_id: StringName, generation: int) -> void:
	if not _accepts_activity_signal(activity_id, generation):
		return
	_pending_activity_completion = true


func _on_activity_failed(
	activity_id: StringName,
	reason: StringName,
	generation: int
) -> void:
	if not _accepts_activity_signal(activity_id, generation):
		return
	if _race.get_state() != TimedCheckpointRace.State.FAILED:
		var race_failure := _race.fail(reason, _race_generation)
		if not bool(race_failure.get("accepted", false)):
			return
	if reason != _pending_race_failure:
		return
	_pending_race_failure = &""
	_emit_snapshot_signal(session_failed)
	_emit_presentation_changed()


func _on_race_started(_activity_id: StringName, generation: int) -> void:
	if not _accepts_race_signal(generation) or not _session_started_once:
		return
	_emit_snapshot_signal(session_active)
	_emit_presentation_changed()


func _on_race_checkpoint_reached(
	_activity_id: StringName,
	_checkpoint_index: int,
	_lap_number: int,
	generation: int
) -> void:
	if not _accepts_race_signal(generation):
		return
	_emit_snapshot_signal(checkpoint_advanced)


func _on_race_lap_completed(
	_activity_id: StringName,
	_lap_number: int,
	lap_time: float,
	generation: int
) -> void:
	if not _accepts_race_signal(generation):
		return
	_emit_lap_signal(lap_time)


func _on_race_penalty_applied(
	_activity_id: StringName,
	_seconds: float,
	_reason: StringName,
	_total_penalty: float,
	generation: int
) -> void:
	if not _accepts_race_signal(generation):
		return
	_emit_snapshot_signal(penalty_changed)


func _on_race_completed(
	_activity_id: StringName,
	_last_time: float,
	_best_time: float,
	generation: int
) -> void:
	if _accepts_race_signal(generation):
		_pending_race_completion = true


func _on_race_failed(
	_activity_id: StringName,
	reason: StringName,
	generation: int
) -> void:
	if _accepts_race_signal(generation):
		_pending_race_failure = reason


func _director_owns_shared_route(director: ActivityDirector) -> bool:
	return (
		is_instance_valid(director)
		and director.get_definition(ROUTE.activity_id) == ROUTE
	)


func _director_state_matches(director: ActivityDirector) -> bool:
	var activity_snapshot := director.get_activity_snapshot(ROUTE.activity_id)
	if activity_snapshot.is_empty():
		return false
	if int(activity_snapshot.get("generation", -1)) != _activity_generation:
		return false
	var race_snapshot := _race.get_snapshot()
	var race_state := int(race_snapshot.get("state", TimedCheckpointRace.State.IDLE))
	var activity_state := int(activity_snapshot.get("state", CheckpointRouteActivity.State.IDLE))
	var states_match := (
		(race_state == TimedCheckpointRace.State.IDLE and activity_state == CheckpointRouteActivity.State.IDLE)
		or (race_state in [TimedCheckpointRace.State.COUNTDOWN, TimedCheckpointRace.State.ACTIVE]
			and activity_state == CheckpointRouteActivity.State.ACTIVE)
		or (race_state == TimedCheckpointRace.State.COMPLETED
			and activity_state == CheckpointRouteActivity.State.COMPLETED)
		or (race_state == TimedCheckpointRace.State.FAILED
			and activity_state == CheckpointRouteActivity.State.FAILED)
	)
	if not states_match:
		return false
	if race_state != TimedCheckpointRace.State.ACTIVE:
		return true
	return int(activity_snapshot.get("next_checkpoint_index", -1)) == int(
		race_snapshot.get("next_checkpoint_index", -2)
	)


func _connect_director() -> void:
	if not _director.activity_checkpoint_reached.is_connected(_on_activity_checkpoint_reached):
		_director.activity_checkpoint_reached.connect(_on_activity_checkpoint_reached)
	if not _director.activity_completed.is_connected(_on_activity_completed):
		_director.activity_completed.connect(_on_activity_completed)
	if not _director.activity_failed.is_connected(_on_activity_failed):
		_director.activity_failed.connect(_on_activity_failed)


func _disconnect_director() -> void:
	if not is_instance_valid(_director):
		return
	if _director.activity_checkpoint_reached.is_connected(_on_activity_checkpoint_reached):
		_director.activity_checkpoint_reached.disconnect(_on_activity_checkpoint_reached)
	if _director.activity_completed.is_connected(_on_activity_completed):
		_director.activity_completed.disconnect(_on_activity_completed)
	if _director.activity_failed.is_connected(_on_activity_failed):
		_director.activity_failed.disconnect(_on_activity_failed)


func _disconnect_race() -> void:
	if _race.race_started.is_connected(_on_race_started):
		_race.race_started.disconnect(_on_race_started)
	if _race.checkpoint_reached.is_connected(_on_race_checkpoint_reached):
		_race.checkpoint_reached.disconnect(_on_race_checkpoint_reached)
	if _race.lap_completed.is_connected(_on_race_lap_completed):
		_race.lap_completed.disconnect(_on_race_lap_completed)
	if _race.penalty_applied.is_connected(_on_race_penalty_applied):
		_race.penalty_applied.disconnect(_on_race_penalty_applied)
	if _race.completed.is_connected(_on_race_completed):
		_race.completed.disconnect(_on_race_completed)
	if _race.failed.is_connected(_on_race_failed):
		_race.failed.disconnect(_on_race_failed)


func _accepts_activity_signal(activity_id: StringName, generation: int) -> bool:
	return (
		_attached
		and activity_id == ROUTE.activity_id
		and generation == _activity_generation
	)


func _accepts_race_signal(generation: int) -> bool:
	return generation == _race_generation


func _running_rejection(expected_session_generation: int) -> StringName:
	if expected_session_generation != _session_generation:
		return &"stale_generation"
	if _closed:
		return &"closed"
	if not _attached:
		return &"not_attached"
	if not _is_running():
		return &"not_running"
	return &""


func _is_running() -> bool:
	return _race.get_state() in [
		TimedCheckpointRace.State.COUNTDOWN,
		TimedCheckpointRace.State.ACTIVE,
	]


func _is_reentrant() -> bool:
	return _mutation_active or _signal_dispatch_active


func _finish(accepted: bool, reason: StringName) -> Dictionary:
	_mutation_active = false
	return _result(accepted, reason)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_presentation_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result


func _emit_snapshot_signal(session_signal: Signal) -> void:
	_signal_dispatch_active = true
	session_signal.emit(get_presentation_snapshot())
	_signal_dispatch_active = false


func _emit_lap_signal(lap_time: float) -> void:
	_signal_dispatch_active = true
	lap_advanced.emit(get_presentation_snapshot(), lap_time)
	_signal_dispatch_active = false


func _emit_presentation_changed() -> void:
	_signal_dispatch_active = true
	presentation_changed.emit(get_presentation_snapshot())
	_signal_dispatch_active = false


func _state_id(state: int) -> StringName:
	match state:
		TimedCheckpointRace.State.COUNTDOWN:
			return &"countdown"
		TimedCheckpointRace.State.ACTIVE:
			return &"active"
		TimedCheckpointRace.State.COMPLETED:
			return &"completed"
		TimedCheckpointRace.State.FAILED:
			return &"failed"
		_:
			return &"idle"
