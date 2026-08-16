class_name WorldStreamingDistancePolicy
extends Node

## Explicit, deterministic distance policy for [WorldStreamingCoordinator].
##
## The policy owns thresholds and ordering only. It never instantiates scenes,
## invents generations, or assumes that a request succeeded: every update reads
## the coordinator's public loaded/loading IDs and records the exact public
## request outcome. There is deliberately no `_process()` or `_physics_process()`;
## callers either submit a position explicitly or pass their physics delta.

signal transition_attempted(
	location_id: StringName,
	action: StringName,
	distance: float,
	outcome: Dictionary
)

const SCHEMA_VERSION := 1
const ACTION_LOAD: StringName = &"load"
const ACTION_UNLOAD: StringName = &"unload"
const MAX_REQUEST_BUDGET := 64

var _coordinator: WorldStreamingCoordinator
var _locations: Dictionary = {}
var _last_outcomes: Dictionary = {}
var _tracked_position := Vector3.ZERO
var _has_tracking := false
var _request_budget := 1
var _update_index := 0
var _physics_elapsed_seconds := 0.0
var _attempt_count := 0
var _accepted_request_count := 0
var _rejected_request_count := 0
var _evaluation_active := false


## Binds one coordinator before registration. Reconfiguration after locations
## exist is rejected because their registrations belong to that coordinator.
func configure(coordinator: WorldStreamingCoordinator, requests_per_update: int = 1) -> bool:
	if _evaluation_active or not is_instance_valid(coordinator) or not _locations.is_empty():
		return false
	if requests_per_update < 1 or requests_per_update > MAX_REQUEST_BUDGET:
		return false
	_coordinator = coordinator
	_request_budget = requests_per_update
	return true


func set_request_budget(requests_per_update: int) -> bool:
	if _evaluation_active or requests_per_update < 1 \
		or requests_per_update > MAX_REQUEST_BUDGET:
		return false
	_request_budget = requests_per_update
	return true


## Registers one immutable distance contract and forwards the definition/scene
## through the coordinator's public API. Strictly larger unload radius provides
## the hysteresis band; equal or inverted radii are invalid.
func register_location(
	definition: WorldLocationDefinition,
	load_radius: float,
	unload_radius: float,
	scene: PackedScene = null
) -> bool:
	if _evaluation_active or not is_instance_valid(_coordinator):
		return false
	if definition == null or not definition.is_definition_valid():
		return false
	if not is_finite(load_radius) or not is_finite(unload_radius):
		return false
	if load_radius <= 0.0 or unload_radius <= load_radius:
		return false
	var location_id := definition.location_id
	if _locations.has(location_id):
		return false
	var anchor := definition.get_anchor_position()
	if not _is_finite_vector(anchor):
		return false
	if not _coordinator.register_location(definition, scene):
		return false
	_locations[location_id] = {
		"location_id": location_id,
		"anchor_position": anchor,
		"load_radius": load_radius,
		"unload_radius": unload_radius,
	}
	return true


func unregister_location(location_id: StringName) -> bool:
	if _evaluation_active or not _locations.has(location_id):
		return false
	if is_instance_valid(_coordinator):
		var removed := _coordinator.unregister_location(location_id)
		# An external coordinator unregistration may already have removed it. Only
		# retain a policy record if a live coordinator still exposes a definition.
		if not removed and _coordinator.get_definition(location_id) != null:
			return false
	_locations.erase(location_id)
	_last_outcomes.erase(location_id)
	return true


## Updates the retained tracking sample without evaluating transitions.
func set_tracked_position(position: Vector3) -> bool:
	if _evaluation_active or not _is_finite_vector(position):
		return false
	_tracked_position = position
	_has_tracking = true
	return true


## Marks tracking temporarily unavailable. Updates become no-ops and preserve
## both loaded and loading coordinator state until a new valid sample arrives.
func clear_tracked_position() -> void:
	if _evaluation_active:
		return
	_has_tracking = false


## Explicitly supplies a new tracking sample and evaluates once without
## advancing physics time.
func update_position(position: Vector3) -> Dictionary:
	if _evaluation_active:
		return _update_result(false, &"evaluation_in_progress", [], 0)
	if not set_tracked_position(position):
		return _update_result(false, &"invalid_tracked_position", [], 0)
	return _evaluate(false, 0.0)


## Evaluates the retained position using caller-owned physics time.
func physics_tick(delta: float) -> Dictionary:
	if _evaluation_active:
		return _update_result(false, &"evaluation_in_progress", [], 0)
	if not is_finite(delta) or delta < 0.0:
		return _update_result(false, &"invalid_physics_delta", [], 0)
	return _evaluate(true, delta)


## Evaluates the retained position without advancing physics time.
func update_now() -> Dictionary:
	if _evaluation_active:
		return _update_result(false, &"evaluation_in_progress", [], 0)
	return _evaluate(false, 0.0)


func has_tracked_position() -> bool:
	return _has_tracking


func get_snapshot() -> Dictionary:
	var loaded_ids := PackedStringArray()
	var loading_ids := PackedStringArray()
	if is_instance_valid(_coordinator):
		loaded_ids = _coordinator.get_loaded_ids()
		loading_ids = _coordinator.get_loading_ids()
	var location_records: Array[Dictionary] = []
	for location_id_string in _sorted_location_ids():
		var location_id := StringName(location_id_string)
		var registration := _locations[location_id] as Dictionary
		var state: StringName = &"unloaded"
		if loaded_ids.has(str(location_id)):
			state = &"loaded"
		elif loading_ids.has(str(location_id)):
			state = &"loading"
		var record := {
			"location_id": location_id,
			"anchor_position": registration.get("anchor_position", Vector3.ZERO),
			"load_radius": float(registration.get("load_radius", 0.0)),
			"unload_radius": float(registration.get("unload_radius", 0.0)),
			"state": state,
			"distance": _distance_for(registration) if _has_tracking else -1.0,
			"last_outcome": (_last_outcomes.get(location_id, {}) as Dictionary).duplicate(true),
		}
		location_records.append(record)
	return {
		"schema_version": SCHEMA_VERSION,
		"configured": is_instance_valid(_coordinator),
		"coordinator_instance_id": _coordinator.get_instance_id() \
			if is_instance_valid(_coordinator) else 0,
		"tracking_available": _has_tracking,
		"tracked_position": _tracked_position if _has_tracking else Vector3.ZERO,
		"request_budget": _request_budget,
		"update_index": _update_index,
		"physics_elapsed_seconds": _physics_elapsed_seconds,
		"registered_ids": _sorted_location_ids(),
		"locations": location_records,
		"attempt_count": _attempt_count,
		"accepted_request_count": _accepted_request_count,
		"rejected_request_count": _rejected_request_count,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not is_instance_valid(_coordinator):
		errors.append("a live WorldStreamingCoordinator is required")
	if _request_budget < 1 or _request_budget > MAX_REQUEST_BUDGET:
		errors.append("request budget is outside the supported range")
	if not is_finite(_physics_elapsed_seconds):
		errors.append("physics elapsed time is non-finite")
	if _attempt_count != _accepted_request_count + _rejected_request_count:
		errors.append("request attempt counters are inconsistent")
	for location_id: StringName in _locations:
		var record := _locations[location_id] as Dictionary
		var load_radius := float(record.get("load_radius", 0.0))
		var unload_radius := float(record.get("unload_radius", 0.0))
		var anchor := record.get("anchor_position", Vector3.INF) as Vector3
		if not _is_finite_vector(anchor) or not is_finite(load_radius) \
			or not is_finite(unload_radius) or load_radius <= 0.0 \
			or unload_radius <= load_radius:
			errors.append("location %s has an invalid frozen distance contract" % location_id)
	var report := {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"update_authority": &"explicit_only",
		"priority_policy": &"distance_ascending_then_stable_id",
		"hysteresis_policy": &"load_at_or_inside_load_unload_outside_unload",
		"missing_tracking_policy": &"preserve_coordinator_state",
		"automatic_engine_processing": false,
		"gameplay_authority": false,
		"grants_rewards": false,
		"ship_authority": false,
		"berth_authority": false,
		"save_authority": false,
		"network_authority": false,
	}
	return report.duplicate(true)


func _evaluate(advance_physics_time: bool, delta: float) -> Dictionary:
	if _evaluation_active:
		return _update_result(false, &"evaluation_in_progress", [], 0)
	if not is_instance_valid(_coordinator):
		return _update_result(false, &"missing_coordinator", [], 0)
	var next_physics_elapsed := _physics_elapsed_seconds
	if advance_physics_time:
		next_physics_elapsed += delta
		if not is_finite(next_physics_elapsed):
			return _update_result(false, &"time_overflow", [], 0)
	_evaluation_active = true
	_update_index += 1
	if advance_physics_time:
		_physics_elapsed_seconds = next_physics_elapsed
	if not _has_tracking:
		var unavailable := _update_result(false, &"tracking_unavailable", [], 0)
		_evaluation_active = false
		return unavailable

	var loaded_ids := _coordinator.get_loaded_ids()
	var loading_ids := _coordinator.get_loading_ids()
	var candidates: Array[Dictionary] = []
	for location_id: StringName in _locations:
		var registration := _locations[location_id] as Dictionary
		var distance := _distance_for(registration)
		var active := loaded_ids.has(str(location_id)) or loading_ids.has(str(location_id))
		var action: StringName = &""
		if active and distance > float(registration.get("unload_radius", 0.0)):
			action = ACTION_UNLOAD
		elif not active and distance <= float(registration.get("load_radius", 0.0)):
			action = ACTION_LOAD
		if not action.is_empty():
			candidates.append({
				"location_id": location_id,
				"action": action,
				"distance": distance,
			})
	candidates.sort_custom(_candidate_precedes)

	var transitions: Array[Dictionary] = []
	var attempt_limit := mini(_request_budget, candidates.size())
	for index in attempt_limit:
		var candidate := candidates[index] as Dictionary
		var location_id := candidate.get("location_id", &"") as StringName
		var action := candidate.get("action", &"") as StringName
		var outcome := _coordinator.request_load(location_id) \
			if action == ACTION_LOAD else _coordinator.request_unload(location_id)
		var transition := {
			"location_id": location_id,
			"action": action,
			"distance": float(candidate.get("distance", 0.0)),
			"update_index": _update_index,
			"accepted": bool(outcome.get("accepted", false)),
			"reason": outcome.get("reason", &"missing_outcome"),
			"generation": int(outcome.get("generation", -1)),
		}
		_last_outcomes[location_id] = transition.duplicate(true)
		transitions.append(transition)
		_attempt_count += 1
		if bool(transition.get("accepted", false)):
			_accepted_request_count += 1
		else:
			_rejected_request_count += 1
		transition_attempted.emit(
			location_id,
			action,
			float(transition.get("distance", 0.0)),
			transition.duplicate(true)
		)
	var result := _update_result(true, &"updated", transitions, candidates.size() - attempt_limit)
	_evaluation_active = false
	return result


func _distance_for(registration: Dictionary) -> float:
	return _tracked_position.distance_to(
		registration.get("anchor_position", Vector3.ZERO) as Vector3
	)


func _candidate_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_distance := float(left.get("distance", 0.0))
	var right_distance := float(right.get("distance", 0.0))
	if left_distance != right_distance:
		return left_distance < right_distance
	return str(left.get("location_id", &"")) < str(right.get("location_id", &""))


func _sorted_location_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for location_id: StringName in _locations:
		ids.append(str(location_id))
	ids.sort()
	return ids


func _update_result(
	accepted: bool,
	reason: StringName,
	transitions: Array,
	deferred_candidate_count: int
) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"update_index": _update_index,
		"tracking_available": _has_tracking,
		"attempted_count": transitions.size(),
		"deferred_candidate_count": deferred_candidate_count,
		"transitions": transitions.duplicate(true),
	}.duplicate(true)


static func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
