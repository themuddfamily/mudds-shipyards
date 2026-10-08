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
var _activity_handoff_active := false


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


## A family handoff retires only the exact inactive route instance observed by
## its caller. Saved family generations can coincide, so generation alone is
## insufficient to authorize retirement after another family was adopted.
func retire_inactive_activity(
	activity_id: StringName, expected_generation: int, expected_instance_id: int
	) -> Dictionary:
	if not _can_mutate_live_activity():
		return {"accepted": false, "reason": &"director_detached"}
	if _activity_handoff_active:
		return {"accepted": false, "reason": &"activity_handoff_in_progress"}
	if get_definition(activity_id) == null:
		return {"accepted": false, "reason": &"unknown_activity"}
	var activity := _activities.get(activity_id) as CheckpointRouteActivity
	if activity == null:
		return {"accepted": expected_instance_id == 0 and expected_generation == 0,
			"reason": &"route_not_instantiated"}
	if activity.get_instance_id() != expected_instance_id \
			or int(activity.get_snapshot().generation) != expected_generation:
		return {"accepted": false, "reason": &"stale_route_instance"}
	if activity.get_state() == CheckpointRouteActivity.State.ACTIVE:
		return {"accepted": false, "reason": &"route_still_active"}
	_activities.erase(activity_id)
	return {"accepted": true, "reason": &"inactive_route_retired"}


## Keep the prior ordinary route until its replacement typed owner has restored
## and attached. Rejection reinstates the exact prior instance, including when
## the candidate adopted ACTIVE saved state. No lifecycle event escapes staging.
func adopt_inactive_activity_owner(
	activity_id: StringName, expected_generation: int, expected_instance_id: int,
	adoption: Callable
	) -> Dictionary:
	if _activity_handoff_active or not adoption.is_valid():
		return {"accepted": false, "reason": &"activity_adoption_unavailable"}
	var previous := _activities.get(activity_id) as CheckpointRouteActivity
	var retired := retire_inactive_activity(activity_id, expected_generation, expected_instance_id)
	if not bool(retired.get("accepted", false)):
		return retired
	_activity_handoff_active = true
	var result: Variant = adoption.call()
	var accepted: bool = result is Dictionary and bool(result.get("accepted", false))
	if not accepted:
		if previous != null:
			_activities[activity_id] = previous
		else:
			_activities.erase(activity_id)
	_activity_handoff_active = false
	return result if result is Dictionary else {"accepted": false, "reason": &"activity_adoption_rejected"}


func get_activity_instance_id(activity_id: StringName) -> int:
	var activity := _activities.get(activity_id) as CheckpointRouteActivity
	return activity.get_instance_id() if activity != null else 0


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
	var source_instance_id := activity.get_instance_id()
	activity.started.connect(_on_route_started.bind(source_instance_id))
	activity.checkpoint_reached.connect(_on_route_checkpoint_reached.bind(source_instance_id))
	activity.completed.connect(_on_route_completed.bind(source_instance_id))
	activity.failed.connect(_on_route_failed.bind(source_instance_id))
	activity.route_reset.connect(_on_route_reset.bind(source_instance_id))
	_activities[activity_id] = activity
	return activity


func _route_source_is_current(activity_id: StringName, source_instance_id: int) -> bool:
	return not _activity_handoff_active and get_activity_instance_id(activity_id) == source_instance_id


func _on_route_started(id: StringName, generation: int, source_instance_id: int) -> void:
	if _route_source_is_current(id, source_instance_id):
		activity_started.emit(id, generation)


func _on_route_checkpoint_reached(
	id: StringName, index: int, generation: int, source_instance_id: int
	) -> void:
	if _route_source_is_current(id, source_instance_id):
		activity_checkpoint_reached.emit(id, index, generation)


func _on_route_completed(id: StringName, generation: int, source_instance_id: int) -> void:
	if _route_source_is_current(id, source_instance_id):
		activity_completed.emit(id, generation)


func _on_route_failed(
	id: StringName, reason: StringName, generation: int, source_instance_id: int
	) -> void:
	if _route_source_is_current(id, source_instance_id):
		activity_failed.emit(id, reason, generation)


func _on_route_reset(id: StringName, generation: int, source_instance_id: int) -> void:
	if _route_source_is_current(id, source_instance_id):
		activity_reset.emit(id, generation)



func _with_result(snapshot: Dictionary, accepted: bool, reason: StringName) -> Dictionary:
	var result := snapshot.duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	return result
