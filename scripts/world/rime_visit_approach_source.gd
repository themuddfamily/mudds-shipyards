class_name RimeVisitApproachSource
extends Node

## The final-approach source for one Rime visit.
##
## `PlanetaryCruiseProductionBinding` consumes any node publishing
## `get_final_approach_source_snapshot()`. This is Rime's: it owns readiness for
## exactly one approach against one streamed generation, and the coordinate
## frame fence it advances only after the common origin owner committed the
## exact Rime transaction. It moves no actor, streams nothing, holds no lease
## and decides no landing.

const SCHEMA_VERSION := 1

var _ready_for_approach := false
var _generation := 0
var _attachment_generation := 0
var _coordinate_frame_generation := 0
var _location_generation := 0
var _arm_count := 0
var _retire_count := 0
var _bootstrap: RimeGlacialStreamingBootstrap
var _origin_owner: CommonWorldOriginRebaseOwner
var _frame_instance_id := 0


func _enter_tree() -> void:
	set_process(false)
	set_physics_process(false)


func _ready() -> void:
	set_process(false)
	set_physics_process(false)


## Declares readiness for exactly one approach against one streamed generation.
## Arming twice is a refusal, never a silent retarget.
func arm(
		coordinate_frame_generation: int,
		location_generation: int,
		bootstrap: RimeGlacialStreamingBootstrap,
		origin_owner: CommonWorldOriginRebaseOwner,
	) -> Dictionary:
	if _ready_for_approach:
		return _result(false, &"approach_source_already_armed")
	if coordinate_frame_generation < 1 or location_generation < 1:
		return _result(false, &"approach_source_generation_invalid")
	if not is_instance_valid(bootstrap) or not is_instance_valid(origin_owner) \
			or not bootstrap.is_inside_tree() or not origin_owner.is_inside_tree() \
			or bootstrap.get_parent() != get_parent() \
			or origin_owner.get_parent() != get_parent():
		return _result(false, &"approach_source_composition_invalid")
	var frame := bootstrap.get_coordinate_frame_for_session()
	if frame == null or frame.get_generation() != coordinate_frame_generation \
			or int(bootstrap.get_snapshot().get("location_generation", 0)) != location_generation:
		return _result(false, &"approach_source_frame_invalid")
	_bootstrap = bootstrap
	_origin_owner = origin_owner
	_frame_instance_id = frame.get_instance_id()
	_coordinate_frame_generation = coordinate_frame_generation
	_location_generation = location_generation
	_attachment_generation += 1
	_arm_count += 1
	_ready_for_approach = true
	return _result(true, &"approach_source_armed", {
		"generation": _generation,
		"attachment_generation": _attachment_generation,
	})


## Advances only this readiness fence after the common owner committed the
## exact Rime transaction. Geometry belongs to the translated landing root.
func accept_committed_origin_rebase(
	receipt: Dictionary, expected_generation: int, expected_attachment_generation: int
) -> Dictionary:
	if not _ready_for_approach or not is_inside_tree() or is_queued_for_deletion() \
			or expected_generation != _generation \
			or expected_attachment_generation != _attachment_generation:
		return _result(false, &"approach_source_stale_attachment")
	if not is_instance_valid(_bootstrap) or not _bootstrap.is_inside_tree() \
			or _bootstrap.is_queued_for_deletion() \
			or not is_instance_valid(_origin_owner) or not _origin_owner.is_inside_tree() \
			or _origin_owner.is_queued_for_deletion() \
			or _bootstrap.get_parent() != get_parent() \
			or _origin_owner.get_parent() != get_parent():
		return _result(false, &"approach_source_composition_invalid")
	var frame := _bootstrap.get_coordinate_frame_for_session()
	var target_generation := int(receipt.get("target_generation", 0))
	var delta: Variant = receipt.get("world_translation_delta")
	if receipt != _origin_owner.get_snapshot().get("last_receipt", {}) \
			or receipt.get("world_id", &"") != RimeGlacialStreamingBootstrap.WORLD_ID \
			or int(receipt.get("source_generation", 0)) != _coordinate_frame_generation \
			or target_generation != _coordinate_frame_generation + 1 \
			or not delta is Vector3 or not (delta as Vector3).is_finite() \
			or frame == null or frame.get_instance_id() != _frame_instance_id \
			or frame.get_generation() != target_generation \
			or int(_bootstrap.get_snapshot().get("location_generation", 0)) != _location_generation:
		return _result(false, &"approach_source_origin_receipt_invalid")
	_coordinate_frame_generation = target_generation
	return _result(true, &"approach_source_origin_adopted")


## Withdraws readiness; a cruise still flying against this source drops the
## approach, the intended fail-closed behaviour for an ending visit.
func retire(reason: StringName = &"approach_source_retired") -> Dictionary:
	if not _ready_for_approach:
		return _result(true, &"approach_source_already_retired")
	_ready_for_approach = false
	_bootstrap = null
	_origin_owner = null
	_frame_instance_id = 0
	_generation += 1
	_coordinate_frame_generation = 0
	_location_generation = 0
	_retire_count += 1
	return _result(true, reason, {"generation": _generation})


func get_generation() -> int:
	return _generation


func get_attachment_generation() -> int:
	return _attachment_generation


func is_ready_for_approach() -> bool:
	return _ready_for_approach


## The declared capability `PlanetaryCruiseProductionBinding` consumes.
func get_final_approach_source_snapshot() -> Dictionary:
	return {
		"ready": _ready_for_approach and is_inside_tree()
			and not is_queued_for_deletion(),
		"generation": _generation,
		"attachment_generation": _attachment_generation,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"location_generation": _location_generation,
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	var record := get_final_approach_source_snapshot()
	record["schema_version"] = SCHEMA_VERSION
	record["arm_count"] = _arm_count
	record["retire_count"] = _retire_count
	record["inside_tree"] = is_inside_tree()
	return record.duplicate(true)


func _result(
		accepted: bool, reason: StringName, extra: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
