class_name CheckpointRouteActivity
extends RefCounted

## Finite, side-effect-free route progression for a checkpoint activity.
##
## The caller supplies positions and an expected generation. A later start or
## reset advances that generation, so a delayed callback from an earlier run
## cannot complete, fail, or otherwise mutate the newly started route.

signal started(activity_id: StringName, generation: int)
signal checkpoint_reached(activity_id: StringName, checkpoint_index: int, generation: int)
signal completed(activity_id: StringName, generation: int)
signal failed(activity_id: StringName, reason: StringName, generation: int)
signal route_reset(activity_id: StringName, generation: int)

enum State {
	IDLE,
	ACTIVE,
	COMPLETED,
	FAILED,
}

const ANY_GENERATION := -1

var definition: ActivityDefinition
var _state := State.IDLE
var _generation := 0
var _next_checkpoint_index := 0
var _failure_reason: StringName = &""


func _init(activity_definition: ActivityDefinition) -> void:
	definition = activity_definition


func start() -> int:
	if definition == null or not definition.is_definition_valid() or _state == State.ACTIVE:
		return -1
	_generation += 1
	_state = State.ACTIVE
	_next_checkpoint_index = 0
	_failure_reason = &""
	started.emit(definition.activity_id, _generation)
	return _generation


func submit_position(position: Vector3, expected_generation: int) -> Dictionary:
	if not _matches_generation(expected_generation):
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	var checkpoint := definition.get_checkpoint_position(_next_checkpoint_index)
	if position.distance_to(checkpoint) > definition.checkpoint_radius:
		return _result(false, &"outside_checkpoint")
	var reached_index := _next_checkpoint_index
	_next_checkpoint_index += 1
	checkpoint_reached.emit(definition.activity_id, reached_index, _generation)
	if _next_checkpoint_index == definition.get_checkpoint_count():
		_state = State.COMPLETED
		completed.emit(definition.activity_id, _generation)
	return _result(true, &"checkpoint_reached")


func fail(reason: StringName, expected_generation: int) -> bool:
	if not _matches_generation(expected_generation) or _state != State.ACTIVE:
		return false
	_failure_reason = reason if not reason.is_empty() else &"unspecified_failure"
	_state = State.FAILED
	failed.emit(definition.activity_id, _failure_reason, _generation)
	return true


func reset(expected_generation: int = ANY_GENERATION) -> bool:
	if expected_generation != ANY_GENERATION and not _matches_generation(expected_generation):
		return false
	_generation += 1
	_state = State.IDLE
	_next_checkpoint_index = 0
	_failure_reason = &""
	if definition != null:
		route_reset.emit(definition.activity_id, _generation)
	return true


func get_state() -> int:
	return _state


func get_generation() -> int:
	return _generation


func get_snapshot() -> Dictionary:
	return {
		"activity_id": definition.activity_id if definition != null else &"",
		"state": _state,
		"generation": _generation,
		"next_checkpoint_index": _next_checkpoint_index,
		"checkpoint_count": definition.get_checkpoint_count() if definition != null else 0,
		"failure_reason": _failure_reason,
		"gameplay_authority": false,
		"grants_rewards": false,
		"ship_authority": false,
		"berth_authority": false,
	}


func _matches_generation(expected_generation: int) -> bool:
	return expected_generation == _generation


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result
