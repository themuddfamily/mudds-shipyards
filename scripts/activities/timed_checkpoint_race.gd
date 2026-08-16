class_name TimedCheckpointRace
extends RefCounted

## Generation-safe timing and lap authority layered over an ActivityDefinition.
##
## Checkpoint geometry remains owned by the supplied checkpoint-route definition.
## This object advances only through caller-supplied physics delta and boundary
## submissions; it owns no process callback, wall clock, reward, craft, or world
## integration authority.

signal countdown_started(activity_id: StringName, seconds: float, generation: int)
signal race_started(activity_id: StringName, generation: int)
signal checkpoint_reached(
	activity_id: StringName,
	checkpoint_index: int,
	lap_number: int,
	generation: int
)
signal lap_completed(activity_id: StringName, lap_number: int, lap_time: float, generation: int)
signal penalty_applied(
	activity_id: StringName,
	seconds: float,
	reason: StringName,
	total_penalty: float,
	generation: int
)
signal completed(activity_id: StringName, last_time: float, best_time: float, generation: int)
signal failed(activity_id: StringName, reason: StringName, generation: int)
signal race_reset(activity_id: StringName, generation: int)

enum State {
	IDLE,
	COUNTDOWN,
	ACTIVE,
	COMPLETED,
	FAILED,
}

var definition: ActivityDefinition
var lap_count: int
var countdown_seconds: float
var timeout_seconds: float

var _state := State.IDLE
var _generation := 0
var _current_lap := 0
var _next_checkpoint_index := 0
var _countdown_remaining := 0.0
var _race_elapsed := 0.0
var _lap_started_at := 0.0
var _penalty_seconds := 0.0
var _last_time := -1.0
var _best_time := -1.0
var _failure_reason: StringName = &""
var _signal_dispatch_active := false


func _init(
	activity_definition: ActivityDefinition,
	configured_laps: int = 1,
	configured_countdown_seconds: float = 3.0,
	configured_timeout_seconds: float = 120.0
) -> void:
	definition = activity_definition
	lap_count = configured_laps
	countdown_seconds = configured_countdown_seconds
	timeout_seconds = configured_timeout_seconds


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null or not definition.is_definition_valid():
		errors.append("a valid ActivityDefinition is required")
	elif definition.activity_kind != ActivityDefinition.ACTIVITY_KIND_CHECKPOINT_ROUTE:
		errors.append("definition must own a checkpoint route")
	if lap_count <= 0:
		errors.append("lap_count must be greater than zero")
	if not is_finite(countdown_seconds) or countdown_seconds < 0.0:
		errors.append("countdown_seconds must be finite and non-negative")
	if not is_finite(timeout_seconds) or timeout_seconds <= 0.0:
		errors.append("timeout_seconds must be finite and greater than zero")
	return errors


func is_configuration_valid() -> bool:
	return get_configuration_errors().is_empty()


func start(expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if _state == State.COUNTDOWN or _state == State.ACTIVE:
		return _result(false, &"already_running")
	_generation += 1
	_state = State.COUNTDOWN
	_current_lap = 0
	_next_checkpoint_index = 0
	_countdown_remaining = countdown_seconds
	_race_elapsed = 0.0
	_lap_started_at = 0.0
	_penalty_seconds = 0.0
	_failure_reason = &""
	_signal_dispatch_active = true
	countdown_started.emit(definition.activity_id, countdown_seconds, _generation)
	_signal_dispatch_active = false
	if is_zero_approx(_countdown_remaining):
		_begin_active_race()
	return _result(true, &"started")


## Advances countdown and ACTIVE timing on the caller's physics clock. A zero
## delta is an accepted no-op, making pause behavior explicit and deterministic.
func advance_physics(delta: float, expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not is_finite(delta) or delta < 0.0:
		return _result(false, &"invalid_delta")
	if _state != State.COUNTDOWN and _state != State.ACTIVE:
		return _result(false, &"not_running")
	if is_zero_approx(delta):
		return _result(true, &"no_delta")
	var countdown_delta := 0.0
	var active_delta := delta
	if _state == State.COUNTDOWN:
		countdown_delta = minf(active_delta, _countdown_remaining)
		active_delta -= countdown_delta
	if active_delta > 0.0:
		var candidate_elapsed := _race_elapsed + active_delta
		var candidate_current := candidate_elapsed + _penalty_seconds
		if not is_finite(candidate_elapsed) or not is_finite(candidate_current):
			return _result(false, &"time_overflow")
	if _state == State.COUNTDOWN:
		_countdown_remaining = maxf(0.0, _countdown_remaining - countdown_delta)
		if is_zero_approx(_countdown_remaining):
			_countdown_remaining = 0.0
			_begin_active_race()
	if _state == State.ACTIVE and active_delta > 0.0:
		_race_elapsed += active_delta
		_fail_on_timeout()
	return _result(true, &"advanced")


## Accepts an ordered boundary index supplied by a checkpoint-volume adapter.
## Re-submitting an already accepted boundary in the same lap is rejected rather
## than silently advancing another objective.
func submit_checkpoint(checkpoint_index: int, expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	return _submit_checkpoint(checkpoint_index, expected_generation)


func _submit_checkpoint(checkpoint_index: int, expected_generation: int) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	if checkpoint_index < 0 or checkpoint_index >= definition.get_checkpoint_count():
		return _result(false, &"invalid_checkpoint")
	if checkpoint_index < _next_checkpoint_index:
		return _result(false, &"duplicate_checkpoint")
	if checkpoint_index != _next_checkpoint_index:
		return _result(false, &"out_of_order")
	var lap_number := _current_lap + 1
	_next_checkpoint_index += 1
	_signal_dispatch_active = true
	checkpoint_reached.emit(
		definition.activity_id,
		checkpoint_index,
		lap_number,
		_generation
	)
	_signal_dispatch_active = false
	if _next_checkpoint_index == definition.get_checkpoint_count():
		_complete_lap()
	return _result(true, &"checkpoint_reached")


## Convenience adapter for callers that own a position rather than a boundary
## signal. Radius and positions are still read from the shared route definition.
func submit_position(position: Vector3, expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	if not WorldLocationDefinition._is_finite_vector(position):
		return _result(false, &"invalid_position")
	var expected_position := definition.get_checkpoint_position(_next_checkpoint_index)
	if position.distance_to(expected_position) > definition.checkpoint_radius:
		return _result(false, &"outside_checkpoint")
	return _submit_checkpoint(_next_checkpoint_index, expected_generation)


func apply_penalty(seconds: float, reason: StringName, expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	if not is_finite(seconds) or seconds <= 0.0:
		return _result(false, &"invalid_penalty")
	var candidate_penalty := _penalty_seconds + seconds
	var candidate_current := _race_elapsed + candidate_penalty
	if not is_finite(candidate_penalty) or not is_finite(candidate_current):
		return _result(false, &"time_overflow")
	var accepted_reason := reason if not reason.is_empty() else &"unspecified_penalty"
	_penalty_seconds = candidate_penalty
	_signal_dispatch_active = true
	penalty_applied.emit(
		definition.activity_id,
		seconds,
		accepted_reason,
		_penalty_seconds,
		_generation
	)
	_signal_dispatch_active = false
	_fail_on_timeout()
	return _result(true, &"penalty_applied")


func fail(reason: StringName, expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.COUNTDOWN and _state != State.ACTIVE:
		return _result(false, &"not_running")
	_commit_failure(reason if not reason.is_empty() else &"unspecified_failure")
	return _result(true, &"failed")


func reset(expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_generation += 1
	_state = State.IDLE
	_current_lap = 0
	_next_checkpoint_index = 0
	_countdown_remaining = 0.0
	_race_elapsed = 0.0
	_lap_started_at = 0.0
	_penalty_seconds = 0.0
	_failure_reason = &""
	if definition != null:
		_signal_dispatch_active = true
		race_reset.emit(definition.activity_id, _generation)
		_signal_dispatch_active = false
	return _result(true, &"reset")


func get_state() -> int:
	return _state


func get_generation() -> int:
	return _generation


func get_snapshot() -> Dictionary:
	return {
		"activity_id": definition.activity_id if definition != null else &"",
		"route_activity_id": definition.activity_id if definition != null else &"",
		"state": _state,
		"generation": _generation,
		"lap_count": lap_count,
		"current_lap": _current_lap,
		"next_checkpoint_index": _next_checkpoint_index,
		"checkpoint_count": definition.get_checkpoint_count() if definition != null else 0,
		"countdown_seconds": countdown_seconds,
		"countdown_remaining": _countdown_remaining,
		"timeout_seconds": timeout_seconds,
		"race_elapsed_seconds": _race_elapsed,
		"penalty_seconds": _penalty_seconds,
		"current_time_seconds": _race_elapsed + _penalty_seconds,
		"last_time_seconds": _last_time,
		"best_time_seconds": _best_time,
		"failure_reason": _failure_reason,
		"uses_caller_physics_delta": true,
		"owns_checkpoint_geometry": false,
		"gameplay_authority": false,
		"grants_rewards": false,
		"ship_authority": false,
		"combat_authority": false,
		"berth_authority": false,
		"network_authority": false,
	}


func audit() -> Dictionary:
	var errors := get_configuration_errors()
	var report := get_snapshot()
	report["valid"] = errors.is_empty()
	report["errors"] = errors
	return report


func _begin_active_race() -> void:
	_state = State.ACTIVE
	_signal_dispatch_active = true
	race_started.emit(definition.activity_id, _generation)
	_signal_dispatch_active = false


func _complete_lap() -> void:
	var lap_number := _current_lap + 1
	var current_time := _race_elapsed + _penalty_seconds
	var lap_time := current_time - _lap_started_at
	_current_lap += 1
	_next_checkpoint_index = 0
	_lap_started_at = current_time
	var race_is_complete := _current_lap == lap_count
	if race_is_complete:
		_state = State.COMPLETED
		_last_time = current_time
		if _best_time < 0.0 or _last_time < _best_time:
			_best_time = _last_time
	_signal_dispatch_active = true
	lap_completed.emit(definition.activity_id, lap_number, lap_time, _generation)
	_signal_dispatch_active = false
	if not race_is_complete:
		return
	_signal_dispatch_active = true
	completed.emit(definition.activity_id, _last_time, _best_time, _generation)
	_signal_dispatch_active = false


func _fail_on_timeout() -> void:
	if _race_elapsed + _penalty_seconds >= timeout_seconds:
		_commit_failure(&"timeout")


func _commit_failure(reason: StringName) -> void:
	_state = State.FAILED
	_failure_reason = reason
	_signal_dispatch_active = true
	failed.emit(definition.activity_id, _failure_reason, _generation)
	_signal_dispatch_active = false


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot().duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	return result
