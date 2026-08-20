class_name ConvoyEscortActivity
extends Node

## Generation-safe convoy escort lifecycle over an ActivityDirector definition.
##
## Ordered leg positions and arrival radius come from one detached
## [ActivityDefinition] snapshot. Entity adapters supply convoy identity,
## generation, position/status, and escort position. Only caller physics deltas
## advance timeout or continuous-separation clocks.

signal started(
	activity_id: StringName,
	activity_generation: int,
	convoy_id: StringName,
	convoy_generation: int
)
signal leg_reached(
	activity_id: StringName,
	leg_index: int,
	activity_generation: int
)
signal safely_arrived(activity_id: StringName, activity_generation: int)
signal failed(
	activity_id: StringName,
	terminal_result: int,
	reason: StringName,
	activity_generation: int
)
signal aborted(activity_id: StringName, reason: StringName, activity_generation: int)
signal escort_reset(activity_id: StringName, activity_generation: int)

enum State {
	IDLE,
	ACTIVE,
	COMPLETED,
	FAILED,
	ABORTED,
}

enum EntityStatus {
	ACTIVE,
	DESTROYED,
	LOST,
}

enum TerminalResult {
	NONE,
	SAFELY_ARRIVED,
	CONVOY_DESTROYED,
	CONVOY_LOST,
	TIMEOUT,
	ABORTED,
}

const SCHEMA_VERSION := 1

var _escort_proximity_radius: float
var _maximum_separation_seconds: float
var _timeout_seconds: float

var _definition: ActivityDefinition
var _requested_activity_id: StringName = &""
var _director_instance_id := 0
var _state := State.IDLE
var _generation := 0
var _terminal_result := TerminalResult.NONE
var _terminal_reason: StringName = &""
var _convoy_id: StringName = &""
var _convoy_generation := -1
var _next_leg_index := 0
var _elapsed_seconds := 0.0
var _separation_elapsed_seconds := 0.0
var _has_sample := false
var _convoy_position := Vector3.ZERO
var _escort_position := Vector3.ZERO
var _escort_distance := 0.0
var _last_entity_status := EntityStatus.ACTIVE
var _sample_count := 0
var _signal_dispatch_active := false


func _init(
	director: ActivityDirector,
	activity_id: StringName,
	configured_escort_proximity_radius: float = 120.0,
	configured_maximum_separation_seconds: float = 8.0,
	configured_timeout_seconds: float = 180.0
) -> void:
	set_process(false)
	set_physics_process(false)
	_requested_activity_id = activity_id
	_escort_proximity_radius = configured_escort_proximity_radius
	_maximum_separation_seconds = configured_maximum_separation_seconds
	_timeout_seconds = configured_timeout_seconds
	if is_instance_valid(director):
		_director_instance_id = director.get_instance_id()
		var registered := director.get_definition(activity_id)
		if registered != null:
			_definition = registered.duplicate(true) as ActivityDefinition


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _definition == null or not _definition.is_definition_valid():
		errors.append("a valid director-registered ActivityDefinition is required")
	else:
		if _definition.activity_id != _requested_activity_id:
			errors.append("director registration identity changed before composition")
		if _definition.activity_kind != ActivityDefinition.ACTIVITY_KIND_CHECKPOINT_ROUTE:
			errors.append("definition must provide ordered checkpoint-route legs")
		if _definition.get_checkpoint_count() < 2:
			errors.append("convoy escort requires at least two ordered legs")
		for index in range(1, _definition.get_checkpoint_count()):
			if _definition.get_checkpoint_position(index).is_equal_approx(
				_definition.get_checkpoint_position(index - 1)
			):
				errors.append("ordered convoy legs cannot duplicate consecutive positions")
				break
	if not is_finite(_escort_proximity_radius) or _escort_proximity_radius <= 0.0:
		errors.append("escort_proximity_radius must be finite and greater than zero")
	if not is_finite(_maximum_separation_seconds) or _maximum_separation_seconds <= 0.0:
		errors.append("maximum_separation_seconds must be finite and greater than zero")
	if not is_finite(_timeout_seconds) or _timeout_seconds <= 0.0:
		errors.append("timeout_seconds must be finite and greater than zero")
	return errors


func is_configuration_valid() -> bool:
	return get_configuration_errors().is_empty()


## Starts a fresh activity generation and binds the exact protected convoy.
func start(
	convoy_id: StringName,
	convoy_generation: int,
	expected_generation: int
) -> Dictionary:
	if not _is_current():
		return _result(false, &"activity_detached")
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if _state == State.ACTIVE:
		return _result(false, &"already_active")
	if not WorldLocationDefinition._is_stable_id(str(convoy_id)) or convoy_generation < 0:
		return _result(false, &"invalid_convoy_identity")
	_generation += 1
	_state = State.ACTIVE
	_terminal_result = TerminalResult.NONE
	_terminal_reason = &""
	_convoy_id = convoy_id
	_convoy_generation = convoy_generation
	_next_leg_index = 0
	_elapsed_seconds = 0.0
	_separation_elapsed_seconds = 0.0
	_has_sample = false
	_convoy_position = Vector3.ZERO
	_escort_position = Vector3.ZERO
	_escort_distance = 0.0
	_last_entity_status = EntityStatus.ACTIVE
	_sample_count = 0
	_signal_dispatch_active = true
	started.emit(_definition.activity_id, _generation, _convoy_id, _convoy_generation)
	_signal_dispatch_active = false
	return _result(true, &"started")


## Records one typed world sample. Samples do not advance either clock.
func submit_entity_sample(
	convoy_id: StringName,
	convoy_generation: int,
	convoy_position: Vector3,
	escort_position: Vector3,
	convoy_status: int,
	expected_generation: int
) -> Dictionary:
	if not _is_current():
		return _result(false, &"activity_detached")
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	if convoy_id != _convoy_id:
		return _result(false, &"wrong_convoy_identity")
	if convoy_generation != _convoy_generation:
		return _result(false, &"stale_convoy_generation")
	if not WorldLocationDefinition._is_finite_vector(convoy_position) \
		or not WorldLocationDefinition._is_finite_vector(escort_position):
		return _result(false, &"invalid_position")
	if convoy_status < EntityStatus.ACTIVE or convoy_status > EntityStatus.LOST:
		return _result(false, &"invalid_entity_status")
	var candidate_escort_distance := convoy_position.distance_to(escort_position)
	if not is_finite(candidate_escort_distance):
		return _result(false, &"distance_overflow")

	_has_sample = true
	_convoy_position = convoy_position
	_escort_position = escort_position
	_escort_distance = candidate_escort_distance
	_last_entity_status = convoy_status
	_sample_count += 1
	if _escort_distance <= _escort_proximity_radius:
		_separation_elapsed_seconds = 0.0

	if convoy_status == EntityStatus.DESTROYED:
		_commit_failure(TerminalResult.CONVOY_DESTROYED, &"convoy_destroyed")
		return _result(true, &"convoy_destroyed")
	if convoy_status == EntityStatus.LOST:
		_commit_failure(TerminalResult.CONVOY_LOST, &"convoy_reported_lost")
		return _result(true, &"convoy_lost")

	var leg_position := _definition.get_checkpoint_position(_next_leg_index)
	if convoy_position.distance_to(leg_position) > _definition.checkpoint_radius:
		return _result(true, &"sample_recorded")
	var is_final_leg := _next_leg_index == _definition.get_checkpoint_count() - 1
	if is_final_leg and _escort_distance > _escort_proximity_radius:
		return _result(true, &"final_leg_waiting_for_escort")

	var reached_index := _next_leg_index
	_next_leg_index += 1
	if is_final_leg:
		_state = State.COMPLETED
		_terminal_result = TerminalResult.SAFELY_ARRIVED
		_terminal_reason = &"safely_arrived"
	_signal_dispatch_active = true
	leg_reached.emit(_definition.activity_id, reached_index, _generation)
	_signal_dispatch_active = false
	if is_final_leg:
		_signal_dispatch_active = true
		safely_arrived.emit(_definition.activity_id, _generation)
		_signal_dispatch_active = false
		return _result(true, &"safely_arrived")
	return _result(true, &"leg_reached")


## Advances mission and continuous-separation time from the caller's physics
## clock. Samples and wall-clock/tree time never advance these values.
func advance_physics(delta: float, expected_generation: int) -> Dictionary:
	if not _is_current():
		return _result(false, &"activity_detached")
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	if not is_finite(delta) or delta < 0.0:
		return _result(false, &"invalid_delta")
	if is_zero_approx(delta):
		return _result(true, &"no_delta")
	var next_elapsed := _elapsed_seconds + delta
	var next_separation_elapsed := _separation_elapsed_seconds
	if _has_sample and _escort_distance > _escort_proximity_radius:
		next_separation_elapsed += delta
	else:
		next_separation_elapsed = 0.0
	if not is_finite(next_elapsed) or not is_finite(next_separation_elapsed):
		return _result(false, &"time_overflow")
	_elapsed_seconds = next_elapsed
	_separation_elapsed_seconds = next_separation_elapsed
	# Separation is the more specific sampled failure if both limits cross on the
	# same caller tick; this ordering is deterministic and published in audit.
	if _separation_elapsed_seconds >= _maximum_separation_seconds:
		_commit_failure(TerminalResult.CONVOY_LOST, &"escort_separation_exceeded")
		return _result(true, &"convoy_lost")
	if _elapsed_seconds >= _timeout_seconds:
		_commit_failure(TerminalResult.TIMEOUT, &"timeout")
		return _result(true, &"timeout")
	return _result(true, &"advanced")


func abort(reason: StringName, expected_generation: int) -> Dictionary:
	if not _is_current():
		return _result(false, &"activity_detached")
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	_terminal_reason = reason if not reason.is_empty() else &"operator_abort"
	_terminal_result = TerminalResult.ABORTED
	_state = State.ABORTED
	_signal_dispatch_active = true
	aborted.emit(_definition.activity_id, _terminal_reason, _generation)
	_signal_dispatch_active = false
	return _result(true, &"aborted")


func reset(expected_generation: int) -> Dictionary:
	if not _is_current():
		return _result(false, &"activity_detached")
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_generation += 1
	_state = State.IDLE
	_terminal_result = TerminalResult.NONE
	_terminal_reason = &""
	_convoy_id = &""
	_convoy_generation = -1
	_next_leg_index = 0
	_elapsed_seconds = 0.0
	_separation_elapsed_seconds = 0.0
	_has_sample = false
	_convoy_position = Vector3.ZERO
	_escort_position = Vector3.ZERO
	_escort_distance = 0.0
	_last_entity_status = EntityStatus.ACTIVE
	_sample_count = 0
	_signal_dispatch_active = true
	escort_reset.emit(_definition.activity_id if _definition != null else &"", _generation)
	_signal_dispatch_active = false
	return _result(true, &"reset")


func get_generation() -> int:
	return _generation


func get_state() -> int:
	return _state


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


## Detached, HUD-ready identifiers, progress, timing, and proximity state.
func get_snapshot() -> Dictionary:
	var leg_count := _definition.get_checkpoint_count() if _definition != null else 0
	var has_next_leg := _state == State.ACTIVE and _next_leg_index < leg_count
	var progress := float(_next_leg_index) / float(leg_count) if leg_count > 0 else 0.0
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_id": _definition.activity_id if _definition != null else &"",
		"display_name": _definition.display_name if _definition != null else "",
		"director_instance_id": _director_instance_id,
		"state": _state,
		"state_id": _state_id(_state),
		"generation": _generation,
		"terminal_result": _terminal_result,
		"terminal_result_id": _terminal_result_id(_terminal_result),
		"terminal_reason": _terminal_reason,
		"convoy_id": _convoy_id,
		"convoy_generation": _convoy_generation,
		"leg_count": leg_count,
		"completed_leg_count": _next_leg_index,
		"next_leg_index": _next_leg_index if has_next_leg else -1,
		"next_leg_number": _next_leg_index + 1 if has_next_leg else 0,
		"next_leg_position": _definition.get_checkpoint_position(_next_leg_index) \
			if has_next_leg else Vector3.ZERO,
		"leg_arrival_radius": _definition.checkpoint_radius if _definition != null else 0.0,
		"progress_fraction": progress,
		"has_entity_sample": _has_sample,
		"sample_count": _sample_count,
		"convoy_position": _convoy_position if _has_sample else Vector3.ZERO,
		"escort_position": _escort_position if _has_sample else Vector3.ZERO,
		"convoy_status": _last_entity_status,
		"convoy_status_id": _entity_status_id(_last_entity_status),
		"escort_distance": _escort_distance if _has_sample else -1.0,
		"escort_proximity_radius": _escort_proximity_radius,
		"escort_within_proximity": _has_sample and _escort_distance <= _escort_proximity_radius,
		"separation_elapsed_seconds": _separation_elapsed_seconds,
		"maximum_separation_seconds": _maximum_separation_seconds,
		"separation_remaining_seconds": maxf(
			0.0, _maximum_separation_seconds - _separation_elapsed_seconds
		),
		"elapsed_seconds": _elapsed_seconds,
		"timeout_seconds": _timeout_seconds,
		"timeout_remaining_seconds": maxf(0.0, _timeout_seconds - _elapsed_seconds),
		"uses_caller_physics_delta": true,
		"owns_ordered_leg_geometry": false,
		"entity_movement_authority": false,
		"combat_authority": false,
		"damage_authority": false,
		"gameplay_authority": false,
		"grants_rewards": false,
		"cargo_authority": false,
		"ship_authority": false,
		"berth_authority": false,
		"game_flow_authority": false,
		"hud_authority": false,
		"save_authority": false,
		"network_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := get_configuration_errors()
	if _generation < 0:
		errors.append("activity generation cannot be negative")
	var leg_count := _definition.get_checkpoint_count() if _definition != null else 0
	if _next_leg_index < 0 or _next_leg_index > leg_count:
		errors.append("ordered leg progress is outside the definition")
	if not is_finite(_elapsed_seconds) or _elapsed_seconds < 0.0:
		errors.append("elapsed physics time is invalid")
	if not is_finite(_separation_elapsed_seconds) or _separation_elapsed_seconds < 0.0:
		errors.append("separation physics time is invalid")
	if _state == State.ACTIVE:
		if not WorldLocationDefinition._is_stable_id(str(_convoy_id)) or _convoy_generation < 0:
			errors.append("active state requires one valid protected convoy identity")
		if _terminal_result != TerminalResult.NONE:
			errors.append("active state cannot have a terminal result")
	if _state == State.IDLE and _terminal_result != TerminalResult.NONE:
		errors.append("idle state cannot have a terminal result")
	if _state == State.COMPLETED \
		and (_terminal_result != TerminalResult.SAFELY_ARRIVED or _next_leg_index != leg_count):
		errors.append("completed state must mean every leg safely arrived")
	if _state == State.FAILED and _terminal_result not in [
		TerminalResult.CONVOY_DESTROYED,
		TerminalResult.CONVOY_LOST,
		TerminalResult.TIMEOUT,
	]:
		errors.append("failed state requires a convoy or timeout failure result")
	if _state == State.ABORTED and _terminal_result != TerminalResult.ABORTED:
		errors.append("aborted state requires the aborted terminal result")
	var report := get_snapshot()
	report["valid"] = errors.is_empty()
	report["errors"] = errors
	report["definition_snapshot_policy"] = &"deep_copy_from_activity_director_registration"
	report["clock_policy"] = &"caller_physics_delta_only"
	report["simultaneous_limit_policy"] = &"separation_before_timeout"
	return report.duplicate(true)


func _commit_failure(result: int, reason: StringName) -> void:
	_state = State.FAILED
	_terminal_result = result
	_terminal_reason = reason
	_signal_dispatch_active = true
	failed.emit(_definition.activity_id, result, reason, _generation)
	_signal_dispatch_active = false


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result.duplicate(true)


static func _state_id(state: int) -> StringName:
	match state:
		State.IDLE:
			return &"idle"
		State.ACTIVE:
			return &"active"
		State.COMPLETED:
			return &"completed"
		State.FAILED:
			return &"failed"
		State.ABORTED:
			return &"aborted"
	return &"invalid"


static func _entity_status_id(status: int) -> StringName:
	match status:
		EntityStatus.ACTIVE:
			return &"active"
		EntityStatus.DESTROYED:
			return &"destroyed"
		EntityStatus.LOST:
			return &"lost"
	return &"invalid"


static func _terminal_result_id(result: int) -> StringName:
	match result:
		TerminalResult.NONE:
			return &"none"
		TerminalResult.SAFELY_ARRIVED:
			return &"safely_arrived"
		TerminalResult.CONVOY_DESTROYED:
			return &"convoy_destroyed"
		TerminalResult.CONVOY_LOST:
			return &"convoy_lost"
		TerminalResult.TIMEOUT:
			return &"timeout"
		TerminalResult.ABORTED:
			return &"aborted"
	return &"invalid"
