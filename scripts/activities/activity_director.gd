class_name ActivityDirector
extends Node

## Thin runtime seam between declarative activity resources and callers that
## observe world positions. It deliberately has no dependencies on ships,
## berths, rewards, combat, or `GameFlow`.

signal activity_started(activity_id: StringName, generation: int)
signal activity_checkpoint_reached(activity_id: StringName, checkpoint_index: int, generation: int)
signal activity_completed(activity_id: StringName, generation: int)
signal activity_failed(activity_id: StringName, reason: StringName, generation: int)
signal activity_reset(activity_id: StringName, generation: int)

@export var activity_definitions: Array[ActivityDefinition] = []

var _definitions: Dictionary = {}
var _activities: Dictionary = {}


func _ready() -> void:
	for definition in activity_definitions:
		register_definition(definition)


func register_definition(definition: ActivityDefinition) -> bool:
	if definition == null or not definition.is_definition_valid() or _definitions.has(definition.activity_id):
		return false
	_definitions[definition.activity_id] = definition
	return true


func start_activity(activity_id: StringName) -> Dictionary:
	if not _can_mutate_live_activity():
		return {"accepted": false, "reason": &"director_detached"}
	var activity := _get_or_create_activity(activity_id)
	if activity == null:
		return {"accepted": false, "reason": &"unknown_activity"}
	var generation := activity.start()
	if generation < 0:
		return _with_result(activity.get_snapshot(), false, &"cannot_start")
	return _with_result(activity.get_snapshot(), true, &"started")


func submit_position(activity_id: StringName, position: Vector3, expected_generation: int) -> Dictionary:
	if not _can_mutate_live_activity():
		return {"accepted": false, "reason": &"director_detached"}
	var activity := _activities.get(activity_id) as CheckpointRouteActivity
	if activity == null:
		return {"accepted": false, "reason": &"unknown_activity"}
	return activity.submit_position(position, expected_generation)


func fail_activity(activity_id: StringName, reason: StringName, expected_generation: int) -> bool:
	if not _can_mutate_live_activity():
		return false
	var activity := _activities.get(activity_id) as CheckpointRouteActivity
	return activity != null and activity.fail(reason, expected_generation)


func reset_activity(activity_id: StringName, expected_generation: int = CheckpointRouteActivity.ANY_GENERATION) -> bool:
	if not _can_mutate_live_activity():
		return false
	var activity := _activities.get(activity_id) as CheckpointRouteActivity
	return activity != null and activity.reset(expected_generation)


func _can_mutate_live_activity() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func get_activity_snapshot(activity_id: StringName) -> Dictionary:
	var activity := _activities.get(activity_id) as CheckpointRouteActivity
	return activity.get_snapshot() if activity != null else {}


func get_definition(activity_id: StringName) -> ActivityDefinition:
	return _definitions.get(activity_id) as ActivityDefinition


## Generation-safe startup restoration stays inside the existing route
## authority. The director creates its ordinary route object and that object
## adopts validated state without replaying historical signals.
func restore_activity_persistence_state(
	activity_id: StringName,
	state: Variant
	) -> Dictionary:
	if not _can_mutate_live_activity():
		return {"accepted": false, "reason": &"director_detached"}
	var activity := _get_or_create_activity(activity_id)
	if activity == null:
		return {"accepted": false, "reason": &"unknown_activity"}
	return activity.restore_persistence_state(state)


func validate_activity_persistence_state(
	activity_id: StringName,
	state: Variant
	) -> Dictionary:
	var definition := get_definition(activity_id)
	if definition == null:
		return {"accepted": false, "reason": &"unknown_activity"}
	var validator := CheckpointRouteActivity.new(definition)
	return validator.validate_persistence_state(state)


func audit() -> Dictionary:
	var active_ids := PackedStringArray()
	for activity_id: StringName in _activities:
		var activity := _activities[activity_id] as CheckpointRouteActivity
		if activity.get_state() == CheckpointRouteActivity.State.ACTIVE:
			active_ids.append(str(activity_id))
	return {
		"registered_activity_count": _definitions.size(),
		"instantiated_activity_count": _activities.size(),
		"active_activity_ids": active_ids,
		"gameplay_authority": false,
		"grants_rewards": false,
		"ship_authority": false,
		"berth_authority": false,
	}


func _get_or_create_activity(activity_id: StringName) -> CheckpointRouteActivity:
	var existing := _activities.get(activity_id) as CheckpointRouteActivity
	if existing != null:
		return existing
	var definition := get_definition(activity_id)
	if definition == null:
		return null
	var activity := CheckpointRouteActivity.new(definition)
	activity.started.connect(func(id: StringName, generation: int) -> void: activity_started.emit(id, generation))
	activity.checkpoint_reached.connect(
		func(id: StringName, index: int, generation: int) -> void:
			activity_checkpoint_reached.emit(id, index, generation)
	)
	activity.completed.connect(func(id: StringName, generation: int) -> void: activity_completed.emit(id, generation))
	activity.failed.connect(
		func(id: StringName, reason: StringName, generation: int) -> void:
			activity_failed.emit(id, reason, generation)
	)
	activity.route_reset.connect(func(id: StringName, generation: int) -> void: activity_reset.emit(id, generation))
	_activities[activity_id] = activity
	return activity


func _with_result(snapshot: Dictionary, accepted: bool, reason: StringName) -> Dictionary:
	var result := snapshot.duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	return result
