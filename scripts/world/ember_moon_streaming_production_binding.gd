class_name EmberMoonStreamingProductionBinding
extends Node

## Production caller-physics adapter for [EmberMoonStreamingBootstrap].
##
## GameFlow supplies its one detached ship-or-player position sample. This
## component encodes that local position into the bootstrap's exact absolute
## orbital frame and asks the bootstrap to evaluate its existing streaming
## contract. It deliberately cannot request, commit, or apply an origin rebase.

const SCHEMA_VERSION := 1
const EXPECTED_INITIAL_FRAME_GENERATION := 1
const DEFAULT_BOOTSTRAP_PATH := NodePath("../EmberMoonStreamingBootstrap")
const VALID_ACTOR_KINDS := [&"player", &"ship"]
const SAMPLE_KEYS := [
	"actor_instance_id",
	"actor_kind",
	"available",
	"position",
]
const UNAVAILABLE_SAMPLE_KEYS := ["available", "reason"]

@export var bootstrap_path: NodePath = DEFAULT_BOOTSTRAP_PATH

var _bootstrap: EmberMoonStreamingBootstrap
var _coordinate_frame: PlanetaryCoordinateFrame
var _activated := false
var _configuration_error: StringName = &""
var _bound_frame_generation := 0
var _bootstrap_instance_id := 0
var _frame_instance_id := 0
var _tick_active := false
var _physics_tick_count := 0
var _accepted_sample_count := 0
var _rejected_sample_count := 0
var _invalid_delta_count := 0
var _reentrant_rejection_count := 0
var _generation_drift_rejection_count := 0
var _last_actor_kind: StringName = &""
var _last_actor_instance_id := 0
var _last_world_streaming_position := Vector3.ZERO
var _last_absolute_coordinate: Dictionary = {}
var _last_streaming_result: Dictionary = {}
var _last_tick_result: Dictionary = {}


func _enter_tree() -> void:
	set_process(false)
	set_physics_process(false)


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	call_deferred(&"_activate_scene_binding")


func _exit_tree() -> void:
	# The exact bootstrap/frame identities remain descendants of the same Main.
	# A whole-Main detach pauses caller ticks but is not a new streaming lifetime.
	set_process(false)
	set_physics_process(false)


## Consumes one already-captured production sample. No engine callback in this
## component can create a competing observation cadence.
func physics_tick_from_caller_sample(delta: float, sample: Variant) -> Dictionary:
	if not _activated or not is_inside_tree() or is_queued_for_deletion():
		return _result(false, &"binding_unavailable")
	if _tick_active:
		_reentrant_rejection_count += 1
		return _result(false, &"reentrant_call")
	if not is_finite(delta) or delta < 0.0:
		_invalid_delta_count += 1
		return _result(false, &"invalid_delta")
	var identity_error := _validate_bound_identity()
	if not identity_error.is_empty():
		_generation_drift_rejection_count += 1
		return _result(false, identity_error)
	var sample_validation := _validate_available_sample(sample)
	if not bool(sample_validation.get("accepted", false)):
		_rejected_sample_count += 1
		_invalidate_actor_preview()
		_last_tick_result = sample_validation.duplicate(true)
		return _last_tick_result.duplicate(true)

	_tick_active = true
	var sample_dictionary := sample as Dictionary
	var position := sample_dictionary.get("position", Vector3.INF) as Vector3
	var absolute_result := _coordinate_frame.world_streaming_to_orbital_position(
		position, _bound_frame_generation
	)
	if not bool(absolute_result.get("accepted", false)):
		_rejected_sample_count += 1
		_invalidate_actor_preview()
		_last_tick_result = _result(
			false,
			absolute_result.get("reason", &"absolute_coordinate_rejected") as StringName,
		)
		_tick_active = false
		return _last_tick_result.duplicate(true)

	var absolute_coordinate := (
		absolute_result.get("coordinate", {}) as Dictionary
	).duplicate(true)
	var streaming_result := _bootstrap.update_absolute_focus(
		absolute_coordinate, _bound_frame_generation
	)
	_physics_tick_count += 1
	_accepted_sample_count += 1
	_last_actor_kind = sample_dictionary.get("actor_kind", &"") as StringName
	_last_actor_instance_id = int(sample_dictionary.get("actor_instance_id", 0))
	_last_world_streaming_position = position
	_last_absolute_coordinate = absolute_coordinate.duplicate(true)
	_last_streaming_result = streaming_result.duplicate(true)
	_last_tick_result = _result(
		bool(streaming_result.get("accepted", false)),
		streaming_result.get("reason", &"streaming_update_rejected") as StringName,
		{
			"coordinate_frame_generation": _bound_frame_generation,
			"absolute_coordinate": absolute_coordinate.duplicate(true),
			"streaming": streaming_result.duplicate(true),
		},
	)
	_tick_active = false
	return _last_tick_result.duplicate(true)


## Read-only origin-shift seam for a future common-world origin owner. It
## derives the exact request inputs from the last committed actor observation,
## but does not create pending frame state or translate any node.
func preview_origin_rebase(expected_frame_generation: int) -> Dictionary:
	if _tick_active:
		_reentrant_rejection_count += 1
		return _result(false, &"reentrant_call")
	if not _activated or not is_inside_tree() or is_queued_for_deletion():
		return _result(false, &"binding_unavailable")
	var identity_error := _validate_bound_identity()
	if not identity_error.is_empty():
		return _result(false, identity_error)
	if expected_frame_generation != _bound_frame_generation:
		return _result(false, &"stale_coordinate_frame_generation")
	if _last_absolute_coordinate.is_empty():
		return _result(false, &"actor_not_observed")
	var evaluation := _coordinate_frame.evaluate_origin_shift(
		_last_world_streaming_position, expected_frame_generation
	)
	if not bool(evaluation.get("accepted", false)):
		return _result(
			false,
			evaluation.get("reason", &"origin_shift_evaluation_rejected") as StringName,
		)
	return _result(true, &"origin_rebase_preview", {
		"coordinate_frame_generation": _bound_frame_generation,
		"actor_instance_id": _last_actor_instance_id,
		"actor_kind": _last_actor_kind,
		"absolute_coordinate": _last_absolute_coordinate.duplicate(true),
		"focus_world_streaming_position": _last_world_streaming_position,
		"world_translation_delta": -_last_world_streaming_position,
		"distance_from_origin_meters": evaluation.get(
			"distance_from_origin_meters", INF
		),
		"threshold_meters": evaluation.get("threshold_meters", INF),
		"rebase_required": bool(evaluation.get("rebase_required", false)),
		"binding_can_request_rebase": false,
		"binding_can_apply_translation": false,
		"binding_can_commit_rebase": false,
		"required_application_owner": &"common_world_origin_owner",
	})


func get_snapshot() -> Dictionary:
	var frame_snapshot := (
		_coordinate_frame.get_snapshot()
		if _coordinate_frame != null
		else {}
	)
	var bootstrap_snapshot := (
		_bootstrap.get_snapshot()
		if is_instance_valid(_bootstrap)
		else {}
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"activated": _activated,
		"configuration_error": _configuration_error,
		"inside_tree": is_inside_tree(),
		"automatic_process": is_processing(),
		"automatic_physics_process": is_physics_processing(),
		"bootstrap_instance_id": _bootstrap_instance_id,
		"coordinate_frame_instance_id": _frame_instance_id,
		"bound_coordinate_frame_generation": _bound_frame_generation,
		"current_coordinate_frame_generation": int(frame_snapshot.get("generation", 0)),
		"physics_tick_count": _physics_tick_count,
		"accepted_sample_count": _accepted_sample_count,
		"rejected_sample_count": _rejected_sample_count,
		"invalid_delta_count": _invalid_delta_count,
		"reentrant_rejection_count": _reentrant_rejection_count,
		"generation_drift_rejection_count": _generation_drift_rejection_count,
		"last_actor_kind": _last_actor_kind,
		"last_actor_instance_id": _last_actor_instance_id,
		"last_world_streaming_position": _last_world_streaming_position,
		"last_absolute_coordinate": _last_absolute_coordinate.duplicate(true),
		"last_streaming_result": _last_streaming_result.duplicate(true),
		"last_tick_result": _last_tick_result.duplicate(true),
		"coordinate_frame": frame_snapshot,
		"bootstrap": bootstrap_snapshot,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var host := get_parent()
	var binding_count := 0
	var bootstrap_count := 0
	if host != null:
		for candidate in host.find_children("*", "", true, false):
			if candidate is EmberMoonStreamingProductionBinding:
				binding_count += 1
			elif candidate is EmberMoonStreamingBootstrap:
				bootstrap_count += 1
	if not _activated:
		errors.append("production Ember binding is not activated: %s" % _configuration_error)
	var identity_error := _validate_bound_identity()
	if not identity_error.is_empty():
		errors.append("bound Ember identity is invalid: %s" % identity_error)
	if binding_count != 1 or bootstrap_count != 1:
		errors.append("Main must contain exactly one Ember binding and bootstrap")
	if is_processing() or is_physics_processing():
		errors.append("binding must not own an engine process callback")
	if _accepted_sample_count != _physics_tick_count:
		errors.append("accepted caller samples and physics ticks diverged")
	var authority := {
		"activity": false,
		"cargo": false,
		"cinder_streaming": false,
		"combat": false,
		"gameplay": false,
		"landing": false,
		"movement": false,
		"network": false,
		"origin_rebase_application": false,
		"origin_rebase_commit": false,
		"origin_rebase_request": false,
		"reward": false,
		"save": false,
		"ship": false,
		"streaming_generation": false,
	}
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"binding_count": binding_count,
		"bootstrap_count": bootstrap_count,
		"observation_authority": &"one_detached_actor_sample_from_game_flow_physics",
		"owned_capabilities": {
			"absolute_coordinate_encoding": true,
			"origin_rebase_preview": true,
			"streaming_update_cadence": true,
		},
		"absolute_coordinate_policy": &"current_frame_generation_exact_conversion",
		"origin_rebase_policy": &"detached_preview_only_future_common_world_owner",
		"can_make_ember_resident": false,
		"requires_external_common_world_origin_owner": true,
		"adjacent_authority": authority,
	}.duplicate(true)


func _activate_scene_binding() -> void:
	if _activated or not is_inside_tree():
		return
	_bootstrap = get_node_or_null(bootstrap_path) as EmberMoonStreamingBootstrap
	if not is_instance_valid(_bootstrap) or _bootstrap.get_parent() != get_parent():
		_configuration_error = &"missing_ember_streaming_bootstrap"
		return
	if not bool(_bootstrap.audit().get("valid", false)):
		_configuration_error = &"invalid_ember_streaming_bootstrap"
		return
	_coordinate_frame = _bootstrap.get_coordinate_frame_for_session()
	if _coordinate_frame == null:
		_configuration_error = &"missing_coordinate_frame"
		return
	var generation := _coordinate_frame.get_generation()
	if generation != EXPECTED_INITIAL_FRAME_GENERATION:
		_configuration_error = &"unexpected_initial_coordinate_frame_generation"
		return
	var frame_snapshot := _coordinate_frame.get_snapshot()
	if not (frame_snapshot.get("pending_rebase", {}) as Dictionary).is_empty():
		_configuration_error = &"coordinate_frame_rebase_pending"
		return
	_bootstrap_instance_id = _bootstrap.get_instance_id()
	_frame_instance_id = _coordinate_frame.get_instance_id()
	_bound_frame_generation = generation
	_activated = true
	_configuration_error = &""


func _validate_bound_identity() -> StringName:
	if is_queued_for_deletion():
		return &"binding_queued_for_deletion"
	var host := get_parent()
	if host == null or host.is_queued_for_deletion():
		return &"host_identity_drift"
	if not is_instance_valid(_bootstrap) \
			or _bootstrap.is_queued_for_deletion() \
			or not _bootstrap.is_inside_tree() \
			or _bootstrap.get_instance_id() != _bootstrap_instance_id \
			or _bootstrap.get_parent() != host:
		return &"bootstrap_identity_drift"
	if _coordinate_frame == null \
			or _coordinate_frame.get_instance_id() != _frame_instance_id \
			or _bootstrap.get_coordinate_frame_for_session() != _coordinate_frame:
		return &"coordinate_frame_identity_drift"
	if _coordinate_frame.get_generation() != _bound_frame_generation:
		return &"coordinate_frame_generation_drift"
	var frame_snapshot := _coordinate_frame.get_snapshot()
	if not (frame_snapshot.get("pending_rebase", {}) as Dictionary).is_empty():
		return &"coordinate_frame_rebase_pending"
	if not bool(_bootstrap.audit().get("valid", false)):
		return &"bootstrap_audit_invalid"
	return &""


func _validate_available_sample(sample: Variant) -> Dictionary:
	if not sample is Dictionary:
		return _result(false, &"invalid_actor_sample")
	var value := sample as Dictionary
	var keys := value.keys()
	keys.sort()
	var unavailable_keys := UNAVAILABLE_SAMPLE_KEYS.duplicate()
	unavailable_keys.sort()
	if keys == unavailable_keys:
		if value.get("available") is not bool \
				or bool(value.get("available", true)) \
				or value.get("reason") is not StringName \
				or (value.get("reason", &"") as StringName).is_empty():
			return _result(false, &"invalid_actor_sample")
		return _result(false, &"actor_unavailable", {
			"actor_reason": value.get("reason", &"") as StringName,
		})
	var expected_keys := SAMPLE_KEYS.duplicate()
	expected_keys.sort()
	if keys != expected_keys:
		return _result(false, &"actor_sample_schema_mismatch")
	if value.get("available") is not bool or not bool(value.get("available", false)):
		return _result(false, &"actor_unavailable")
	if value.get("position") is not Vector3 \
			or not (value.get("position") as Vector3).is_finite():
		return _result(false, &"invalid_actor_position")
	if value.get("actor_kind") is not StringName \
			or not VALID_ACTOR_KINDS.has(value.get("actor_kind") as StringName):
		return _result(false, &"invalid_actor_kind")
	if value.get("actor_instance_id") is not int \
			or int(value.get("actor_instance_id", 0)) <= 0:
		return _result(false, &"invalid_actor_instance_id")
	return _result(true, &"actor_sample_valid")


func _invalidate_actor_preview() -> void:
	_last_actor_kind = &""
	_last_actor_instance_id = 0
	_last_world_streaming_position = Vector3.ZERO
	_last_absolute_coordinate.clear()


func _result(
	accepted: bool,
	reason: StringName,
	extra: Dictionary = {},
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
