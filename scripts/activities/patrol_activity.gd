class_name PatrolActivity
extends RefCounted

## Typed patrol authority layered over an ActivityDirector checkpoint route.
##
## The shared ActivityDefinition remains the checkpoint-volume contract and
## ActivityDirector commits the ordered checkpoint only after continuous dwell.
## This component owns dwell timing, patrol lifecycle, and detached presentation
## state; no world geometry is copied or created here.

signal patrol_started(snapshot: Dictionary)
signal checkpoint_arrived(snapshot: Dictionary, checkpoint_index: int)
signal checkpoint_dwell_completed(snapshot: Dictionary, checkpoint_index: int)
signal patrol_completed(snapshot: Dictionary)
signal patrol_failed(snapshot: Dictionary)
signal patrol_aborted(snapshot: Dictionary)
signal patrol_reset(snapshot: Dictionary)
signal presentation_changed(snapshot: Dictionary)

enum State {
	IDLE,
	ACTIVE,
	COMPLETED,
	FAILED,
	ABORTED,
}

const ANY_CHECKPOINT := -1

var definition: ActivityDefinition
var dwell_seconds: float

var _director: ActivityDirector
var _generation := 0
var _activity_generation := 0
var _state := State.IDLE
var _next_checkpoint_index := 0
var _completed_checkpoint_count := 0
var _dwell_checkpoint_index := ANY_CHECKPOINT
var _dwell_elapsed := 0.0
var _elapsed := 0.0
var _last_duration := -1.0
var _checkpoint_occupied := false
var _terminal_reason: StringName = &""
var _attached := false
var _started_once := false
var _closed := false
var _mutation_active := false
var _signal_dispatch_active := false
var _pending_submission := false
var _pending_checkpoint_event := false
var _activity_route_completed := false
var _authority_desynchronized := false
var _pending_terminal_state := State.IDLE
var _patrol_actor_ref: WeakRef
var _patrol_actor_instance_id := 0
var _patrol_actor_status_id: StringName = &"unbound"
var _patrol_actor_exit_callback := Callable()
var _patrol_actor_exit_pending := false
var _patrol_actor_loss_pending := false
var _patrol_actor_pending_reason: StringName = &""


func _init(route_definition: ActivityDefinition, configured_dwell_seconds: float = 2.0) -> void:
	definition = route_definition
	dwell_seconds = configured_dwell_seconds


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null or not definition.is_definition_valid():
		errors.append("a valid ActivityDefinition is required")
	elif definition.activity_kind != ActivityDefinition.ACTIVITY_KIND_CHECKPOINT_ROUTE:
		errors.append("definition must own a checkpoint route")
	if not is_finite(dwell_seconds) or dwell_seconds < 0.0:
		errors.append("dwell_seconds must be finite and non-negative")
	return errors


func is_configuration_valid() -> bool:
	return get_configuration_errors().is_empty()


func attach(director: ActivityDirector, expected_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_generation != _generation:
		return _finish(false, &"stale_generation")
	if _closed:
		return _finish(false, &"closed")
	if _attached:
		return _finish(false, &"already_attached")
	if not _director_owns_route(director):
		return _finish(false, &"route_not_registered")
	if _started_once and not _director_state_matches(director):
		return _finish(false, &"director_state_mismatch")
	_director = director
	_connect_director()
	_attached = true
	_validate_and_rearm_patrol_actor_on_attach()
	if _patrol_actor_loss_pending:
		var pending_reason := _patrol_actor_pending_reason
		_patrol_actor_loss_pending = false
		_patrol_actor_pending_reason = &""
		_mutation_active = false
		return fail(pending_reason, expected_generation)
	var result := _finish(true, &"attached")
	_emit_snapshot_signal(presentation_changed)
	return result


func detach(expected_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_generation != _generation:
		return _finish(false, &"stale_generation")
	if not _attached:
		return _finish(false, &"not_attached")
	_disconnect_director()
	_attached = false
	var result := _finish(true, &"detached")
	_emit_snapshot_signal(presentation_changed)
	return result


func start(expected_generation: int, patrol_actor: Variant = null) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_generation != _generation:
		return _finish(false, &"stale_generation")
	if _closed:
		return _finish(false, &"closed")
	if not _attached:
		return _finish(false, &"not_attached")
	if not is_configuration_valid():
		return _finish(false, &"invalid_configuration")
	if _state == State.ACTIVE:
		return _finish(false, &"already_running")
	if patrol_actor != null:
		var actor_rejection := _patrol_actor_rejection(patrol_actor)
		if not actor_rejection.is_empty():
			return _finish(false, actor_rejection)
	var activity_start := _director.start_activity(definition.activity_id)
	if not bool(activity_start.get("accepted", false)):
		return _finish(false, &"activity_cannot_start")
	_activity_generation = int(activity_start.get("generation", 0))
	_generation += 1
	_state = State.ACTIVE
	_next_checkpoint_index = 0
	_completed_checkpoint_count = 0
	_dwell_checkpoint_index = ANY_CHECKPOINT
	_dwell_elapsed = 0.0
	_elapsed = 0.0
	_checkpoint_occupied = false
	_terminal_reason = &""
	_started_once = true
	_pending_submission = false
	_pending_checkpoint_event = false
	_activity_route_completed = false
	_authority_desynchronized = false
	_pending_terminal_state = State.IDLE
	if patrol_actor != null:
		_track_patrol_actor(patrol_actor as Node3D, _generation)
	var result := _finish(true, &"started")
	_emit_snapshot_signal(patrol_started)
	_emit_snapshot_signal(presentation_changed)
	return result


## Begins dwell only when this position occupies the exact next volume in the
## shared definition. ActivityDirector remains unchanged until dwell completes;
## advance_physics() then submits that same ordered checkpoint for authoritative
## commit. Duplicate submissions during dwell are rejected.
func submit_position(position: Vector3, expected_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(expected_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not WorldLocationDefinition._is_finite_vector(position):
		return _finish(false, &"invalid_position")
	if not _ensure_authorities_coherent():
		return _finish_desynchronized()
	if _dwell_checkpoint_index != ANY_CHECKPOINT:
		return _finish(false, &"dwell_in_progress")
	var checkpoint_position := definition.get_checkpoint_position(_next_checkpoint_index)
	if position.distance_to(checkpoint_position) > definition.checkpoint_radius:
		return _finish(false, &"outside_checkpoint")

	_dwell_checkpoint_index = _next_checkpoint_index
	_dwell_elapsed = 0.0
	_checkpoint_occupied = true
	var arrived_index := _next_checkpoint_index
	var instant_dwell := is_zero_approx(dwell_seconds)
	_mutation_active = false
	_emit_checkpoint_signal(checkpoint_arrived, arrived_index)
	if instant_dwell:
		_mutation_active = true
		var completed_cleanly := _complete_checkpoint_dwell(position)
		_mutation_active = false
		if not completed_cleanly:
			_emit_snapshot_signal(patrol_failed)
			_emit_snapshot_signal(presentation_changed)
			return _result(false, &"authority_desynchronized")
		_emit_checkpoint_signal(checkpoint_dwell_completed, arrived_index)
		if _state == State.COMPLETED:
			_emit_snapshot_signal(patrol_completed)
	_emit_snapshot_signal(presentation_changed)
	return _result(true, &"checkpoint_arrived")


## Advances total patrol time and, while the supplied position remains inside
## the director-accepted checkpoint volume, continuous dwell time. A zero delta
## is an explicit state-preserving pause operation.
func advance_physics(
	delta: float,
	patrol_position: Vector3,
	expected_generation: int
) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(expected_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not is_finite(delta) or delta < 0.0:
		return _finish(false, &"invalid_delta")
	if not WorldLocationDefinition._is_finite_vector(patrol_position):
		return _finish(false, &"invalid_position")
	if not _ensure_authorities_coherent():
		return _finish_desynchronized()
	if is_zero_approx(delta):
		return _finish(true, &"no_delta")
	var candidate_elapsed := _elapsed + delta
	if not is_finite(candidate_elapsed):
		return _finish(false, &"time_overflow")

	_elapsed = candidate_elapsed
	var result_reason: StringName = &"advanced"
	var completed_dwell_index := ANY_CHECKPOINT
	if _dwell_checkpoint_index != ANY_CHECKPOINT:
		var dwell_position := definition.get_checkpoint_position(_dwell_checkpoint_index)
		_checkpoint_occupied = (
			patrol_position.distance_to(dwell_position) <= definition.checkpoint_radius
		)
		if not _checkpoint_occupied:
			if _dwell_elapsed > 0.0:
				_dwell_elapsed = 0.0
				result_reason = &"dwell_interrupted"
		else:
			var dwell_remaining := maxf(0.0, dwell_seconds - _dwell_elapsed)
			_dwell_elapsed += minf(delta, dwell_remaining)
			if _dwell_elapsed >= dwell_seconds or is_equal_approx(
				_dwell_elapsed, dwell_seconds
			):
				completed_dwell_index = _dwell_checkpoint_index
				if not _complete_checkpoint_dwell(patrol_position):
					var failed_result := _finish(false, &"authority_desynchronized")
					_emit_snapshot_signal(patrol_failed)
					_emit_snapshot_signal(presentation_changed)
					return failed_result
				result_reason = &"dwell_completed"

	var result := _finish(true, result_reason)
	if completed_dwell_index != ANY_CHECKPOINT:
		_emit_checkpoint_signal(checkpoint_dwell_completed, completed_dwell_index)
		if _state == State.COMPLETED:
			_emit_snapshot_signal(patrol_completed)
	_emit_snapshot_signal(presentation_changed)
	return result


## Actor-aware production seam for hosts that own the physical patrol caller.
## The first valid sample fences this run to one actor identity. Losing that
## node, replacing it mid-run, or supplying invalid transform evidence fails
## the same director-backed lifecycle instead of leaving an active patrol with
## no future position samples. Recovery remains the existing reset/start path.
func advance_actor_physics(
	delta: float,
	patrol_actor: Variant,
	sampled_position: Vector3,
	expected_generation: int
) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	var rejection := _running_rejection(expected_generation)
	if not rejection.is_empty():
		return _result(false, rejection)
	var actor_rejection := _patrol_actor_identity_rejection(patrol_actor)
	if actor_rejection.is_empty() and not WorldLocationDefinition._is_finite_vector(
		(patrol_actor as Node3D).global_position
	):
		actor_rejection = &"patrol_actor_invalid_position"
	if actor_rejection.is_empty() \
			and not WorldLocationDefinition._is_finite_vector(sampled_position):
		actor_rejection = &"patrol_actor_invalid_position"
	if not actor_rejection.is_empty():
		_patrol_actor_status_id = (
			&"lost"
			if actor_rejection == &"patrol_actor_lost"
			else &"invalid"
		)
		return fail(actor_rejection, expected_generation)
	var actor := patrol_actor as Node3D
	if _patrol_actor_instance_id == 0:
		_track_patrol_actor(actor, expected_generation)
	elif actor.get_instance_id() != _patrol_actor_instance_id:
		_patrol_actor_status_id = &"replaced"
		return fail(&"patrol_actor_replaced", expected_generation)
	elif _patrol_actor_status_id == &"detached":
		_track_patrol_actor(actor, expected_generation)

	var before := get_presentation_snapshot()
	if before.get("phase_id", &"") == &"travel":
		submit_position(sampled_position, expected_generation)
	if _state != State.ACTIVE:
		return _result(false, &"patrol_actor_advance_rejected")
	return advance_physics(delta, sampled_position, expected_generation)


func abort(reason: StringName, expected_generation: int) -> Dictionary:
	return _request_terminal(State.ABORTED, reason, expected_generation)


func fail(reason: StringName, expected_generation: int) -> Dictionary:
	return _request_terminal(State.FAILED, reason, expected_generation)


func reset(expected_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_generation != _generation:
		return _finish(false, &"stale_generation")
	if _closed:
		return _finish(false, &"closed")
	if not _attached:
		return _finish(false, &"not_attached")
	if not _started_once:
		return _finish(false, &"not_started")
	if not _director.reset_activity(definition.activity_id, _activity_generation):
		_authority_desynchronized = true
		return _finish_desynchronized()
	_activity_generation = int(
		_director.get_activity_snapshot(definition.activity_id).get("generation", 0)
	)
	_generation += 1
	_state = State.IDLE
	_next_checkpoint_index = 0
	_completed_checkpoint_count = 0
	_dwell_checkpoint_index = ANY_CHECKPOINT
	_dwell_elapsed = 0.0
	_elapsed = 0.0
	_checkpoint_occupied = false
	_terminal_reason = &""
	_pending_submission = false
	_pending_checkpoint_event = false
	_activity_route_completed = false
	_authority_desynchronized = false
	_pending_terminal_state = State.IDLE
	_release_patrol_actor()
	var result := _finish(true, &"reset")
	_emit_snapshot_signal(patrol_reset)
	_emit_snapshot_signal(presentation_changed)
	return result


## Permanently disconnects this adapter. Closing does not invent an abort or
## mutate the director; callers that need a terminal result must abort/fail first.
func close(expected_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_generation != _generation:
		return _finish(false, &"stale_generation")
	if _closed:
		return _finish(false, &"already_closed")
	_disconnect_director()
	_release_patrol_actor()
	_attached = false
	_closed = true
	var result := _finish(true, &"closed")
	_emit_snapshot_signal(presentation_changed)
	return result


func get_generation() -> int:
	return _generation


func get_state() -> int:
	return _state


func get_presentation_snapshot() -> Dictionary:
	var phase_id: StringName = &"idle"
	if _state == State.ACTIVE:
		phase_id = &"dwell" if _dwell_checkpoint_index != ANY_CHECKPOINT else &"travel"
	elif _state == State.COMPLETED:
		phase_id = &"complete"
	elif _state == State.FAILED:
		phase_id = &"failed"
	elif _state == State.ABORTED:
		phase_id = &"aborted"
	var actor_recovery_required := (
		_state == State.FAILED
		and _terminal_reason in [
			&"patrol_actor_lost",
			&"patrol_actor_invalid",
			&"patrol_actor_invalid_position",
			&"patrol_actor_replaced",
		]
	)
	var recovery_action_id: StringName = &""
	if actor_recovery_required:
		recovery_action_id = &"reset_patrol_then_restart"
	elif _patrol_actor_loss_pending:
		recovery_action_id = &"reattach_patrol_to_terminalize"
	return {
		"activity_id": definition.activity_id if definition != null else &"",
		"display_name": definition.display_name if definition != null else "",
		"activity_kind": &"patrol",
		"state": _state,
		"state_id": _state_id(_state),
		"phase_id": phase_id,
		"generation": _generation,
		"activity_generation": _activity_generation,
		"attached": _attached,
		"closed": _closed,
		"running": _state == State.ACTIVE,
		"next_checkpoint_index": _next_checkpoint_index,
		"checkpoint_count": definition.get_checkpoint_count() if definition != null else 0,
		"completed_checkpoint_count": _completed_checkpoint_count,
		"dwell_checkpoint_index": _dwell_checkpoint_index,
		"dwell_seconds": dwell_seconds,
		"dwell_elapsed_seconds": _dwell_elapsed,
		"dwell_remaining_seconds": (
			maxf(0.0, dwell_seconds - _dwell_elapsed)
			if _dwell_checkpoint_index != ANY_CHECKPOINT
			else 0.0
		),
		"checkpoint_occupied": _checkpoint_occupied,
		"current_time_seconds": _elapsed,
		"last_duration_seconds": _last_duration,
		"terminal_reason": _terminal_reason,
		"failure_reason": _terminal_reason if _state == State.FAILED else &"",
		"abort_reason": _terminal_reason if _state == State.ABORTED else &"",
		"patrol_actor_instance_id": _patrol_actor_instance_id,
		"patrol_actor_status_id": _patrol_actor_status_id,
		"patrol_actor_loss_pending": _patrol_actor_loss_pending,
		"patrol_actor_pending_reason": _patrol_actor_pending_reason,
		"actor_recovery_required": actor_recovery_required,
		"recovery_action_id": recovery_action_id,
		"uses_caller_physics_delta": true,
		"owns_checkpoint_geometry": false,
		"gameplay_authority": false,
		"grants_rewards": false,
		"ship_authority": false,
		"combat_authority": false,
		"berth_authority": false,
		"save_authority": false,
		"network_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var report := get_presentation_snapshot()
	report["valid"] = is_configuration_valid() and not _authority_desynchronized and (
		not _attached or _director_owns_route(_director)
	)
	report["errors"] = get_configuration_errors()
	report["route_resource_path"] = definition.resource_path if definition != null else ""
	report["shares_activity_director_route"] = true
	report["activity_director_checkpoint_authority"] = true
	report["patrol_dwell_authority"] = true
	return report.duplicate(true)


func _request_terminal(
	terminal_state: int,
	reason: StringName,
	expected_generation: int
) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(expected_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not _ensure_authorities_coherent():
		return _finish_desynchronized()
	_pending_terminal_state = terminal_state
	var accepted_reason := reason
	if accepted_reason.is_empty():
		accepted_reason = &"patrol_aborted" if terminal_state == State.ABORTED else &"unspecified_failure"
	if not _director.fail_activity(
		definition.activity_id,
		accepted_reason,
		_activity_generation
	):
		_pending_terminal_state = State.IDLE
		_authority_desynchronized = true
		return _finish_desynchronized()
	if _state == State.ACTIVE:
		_pending_terminal_state = State.IDLE
		_authority_desynchronized = true
		return _finish_desynchronized()
	_pending_terminal_state = State.IDLE
	_disconnect_patrol_actor_exit_signal()
	var result_reason: StringName = &"aborted" if terminal_state == State.ABORTED else &"failed"
	var result := _finish(true, result_reason)
	if terminal_state == State.ABORTED:
		_emit_snapshot_signal(patrol_aborted)
	else:
		_emit_snapshot_signal(patrol_failed)
	_emit_snapshot_signal(presentation_changed)
	return result


func _complete_checkpoint_dwell(patrol_position: Vector3) -> bool:
	var checkpoint_index := _dwell_checkpoint_index
	if checkpoint_index == ANY_CHECKPOINT or checkpoint_index != _next_checkpoint_index:
		_authority_desynchronized = true
		_terminalize_authority_desynchronization()
		return false
	_pending_submission = true
	_pending_checkpoint_event = false
	_activity_route_completed = false
	var activity_result := _director.submit_position(
		definition.activity_id,
		patrol_position,
		_activity_generation
	)
	_pending_submission = false
	if (
		_authority_desynchronized
		or not bool(activity_result.get("accepted", false))
		or not _pending_checkpoint_event
	):
		_authority_desynchronized = true
		_terminalize_authority_desynchronization()
		return false
	var candidate_next_checkpoint := _next_checkpoint_index + 1
	var completes_route := candidate_next_checkpoint == definition.get_checkpoint_count()
	if completes_route:
		if not _activity_route_completed or not _director_progress_matches_completed():
			_authority_desynchronized = true
			_terminalize_authority_desynchronization()
			return false
	elif not _director_progress_matches_active(candidate_next_checkpoint):
		_authority_desynchronized = true
		_terminalize_authority_desynchronization()
		return false
	_next_checkpoint_index += 1
	_completed_checkpoint_count += 1
	_dwell_checkpoint_index = ANY_CHECKPOINT
	_dwell_elapsed = 0.0
	_checkpoint_occupied = false
	if completes_route:
		_state = State.COMPLETED
		_last_duration = _elapsed
		_terminal_reason = &""
		_disconnect_patrol_actor_exit_signal()
		return true
	return true


func _ensure_authorities_coherent() -> bool:
	if _authority_desynchronized:
		_terminalize_authority_desynchronization()
		return false
	if not _director_state_matches(_director):
		_authority_desynchronized = true
		_terminalize_authority_desynchronization()
		return false
	return true


func _finish_desynchronized() -> Dictionary:
	_terminalize_authority_desynchronization()
	var result := _finish(false, &"authority_desynchronized")
	_emit_snapshot_signal(patrol_failed)
	_emit_snapshot_signal(presentation_changed)
	return result


func _terminalize_authority_desynchronization() -> void:
	_state = State.FAILED
	_terminal_reason = &"activity_patrol_desynchronized"
	_dwell_checkpoint_index = ANY_CHECKPOINT
	_dwell_elapsed = 0.0
	_checkpoint_occupied = false
	_pending_submission = false
	_pending_checkpoint_event = false
	_activity_route_completed = false
	_pending_terminal_state = State.IDLE
	if not is_instance_valid(_director) or definition == null:
		return
	var activity_snapshot := _director.get_activity_snapshot(definition.activity_id)
	if (
		int(activity_snapshot.get("generation", -1)) == _activity_generation
		and int(activity_snapshot.get("state", CheckpointRouteActivity.State.IDLE))
		== CheckpointRouteActivity.State.ACTIVE
	):
		_director.fail_activity(
			definition.activity_id,
			_terminal_reason,
			_activity_generation
		)


func _on_activity_checkpoint_reached(
	activity_id: StringName,
	checkpoint_index: int,
	activity_generation: int
) -> void:
	if not _accepts_activity_signal(activity_id, activity_generation):
		return
	if (
		not _pending_submission
		or _pending_checkpoint_event
		or checkpoint_index != _next_checkpoint_index
	):
		_authority_desynchronized = true
		return
	_pending_checkpoint_event = true


func _on_activity_completed(activity_id: StringName, activity_generation: int) -> void:
	if not _accepts_activity_signal(activity_id, activity_generation):
		return
	if (
		not _pending_submission
		or not _pending_checkpoint_event
		or _dwell_checkpoint_index != definition.get_checkpoint_count() - 1
	):
		_authority_desynchronized = true
		return
	_activity_route_completed = true


func _on_activity_failed(
	activity_id: StringName,
	reason: StringName,
	activity_generation: int
) -> void:
	if not _accepts_activity_signal(activity_id, activity_generation):
		return
	if _state != State.ACTIVE:
		return
	var activity_snapshot := _director.get_activity_snapshot(definition.activity_id)
	if (
		int(activity_snapshot.get("state", CheckpointRouteActivity.State.IDLE))
		!= CheckpointRouteActivity.State.FAILED
		or StringName(activity_snapshot.get("failure_reason", &"")) != reason
	):
		_authority_desynchronized = true
		return
	_state = (
		State.ABORTED
		if _pending_terminal_state == State.ABORTED
		else State.FAILED
	)
	_terminal_reason = reason if not reason.is_empty() else &"unspecified_failure"
	_dwell_checkpoint_index = ANY_CHECKPOINT
	_dwell_elapsed = 0.0
	_checkpoint_occupied = false
	_activity_route_completed = false
	_disconnect_patrol_actor_exit_signal()
	if _mutation_active:
		return
	if _state == State.ABORTED:
		_emit_snapshot_signal(patrol_aborted)
	else:
		_emit_snapshot_signal(patrol_failed)
	_emit_snapshot_signal(presentation_changed)


func _director_owns_route(director: ActivityDirector) -> bool:
	return (
		is_instance_valid(director)
		and definition != null
		and director.get_definition(definition.activity_id) == definition
	)


func _patrol_actor_rejection(patrol_actor: Variant) -> StringName:
	var identity_rejection := _patrol_actor_identity_rejection(patrol_actor)
	if not identity_rejection.is_empty():
		return identity_rejection
	var actor := patrol_actor as Node3D
	if not WorldLocationDefinition._is_finite_vector(actor.global_position):
		return &"patrol_actor_invalid_position"
	return &""


func _patrol_actor_identity_rejection(patrol_actor: Variant) -> StringName:
	if patrol_actor == null:
		return &"patrol_actor_lost"
	if not patrol_actor is Object:
		return &"patrol_actor_invalid"
	if not is_instance_valid(patrol_actor):
		return &"patrol_actor_lost"
	if not patrol_actor is Node3D:
		return &"patrol_actor_invalid"
	var actor := patrol_actor as Node3D
	if actor.is_queued_for_deletion() or not actor.is_inside_tree():
		return &"patrol_actor_lost"
	return &""


func _track_patrol_actor(actor: Node3D, expected_generation: int) -> void:
	_disconnect_patrol_actor_exit_signal(false)
	_patrol_actor_ref = weakref(actor)
	_patrol_actor_instance_id = actor.get_instance_id()
	_patrol_actor_status_id = &"tracked"
	_patrol_actor_exit_pending = false
	_patrol_actor_exit_callback = _on_patrol_actor_tree_exiting.bind(
		_patrol_actor_instance_id, expected_generation
	)
	actor.tree_exiting.connect(_patrol_actor_exit_callback, CONNECT_ONE_SHOT)


func _on_patrol_actor_tree_exiting(actor_instance_id: int, generation: int) -> void:
	if actor_instance_id != _patrol_actor_instance_id or generation != _generation:
		return
	_patrol_actor_exit_callback = Callable()
	_patrol_actor_exit_pending = true
	_patrol_actor_status_id = &"exit_pending"
	call_deferred("_resolve_patrol_actor_exit", actor_instance_id, generation)


func _resolve_patrol_actor_exit(actor_instance_id: int, generation: int) -> void:
	if (
		not _patrol_actor_exit_pending
		or actor_instance_id != _patrol_actor_instance_id
		or generation != _generation
	):
		return
	_patrol_actor_exit_pending = false
	if _state != State.ACTIVE:
		return
	var actor := _get_tracked_patrol_actor()
	if is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion():
		_track_patrol_actor(actor, generation)
		return
	if not _attached:
		if is_instance_valid(actor):
			_patrol_actor_status_id = &"detached"
		else:
			_latch_patrol_actor_loss()
		return
	_patrol_actor_ref = null
	_patrol_actor_status_id = &"lost"
	fail(&"patrol_actor_lost", generation)


func _get_tracked_patrol_actor() -> Node3D:
	return (
		_patrol_actor_ref.get_ref() as Node3D
		if _patrol_actor_ref != null
		else null
	)


func _validate_and_rearm_patrol_actor_on_attach() -> void:
	if _state != State.ACTIVE or _patrol_actor_instance_id == 0:
		return
	var actor := _get_tracked_patrol_actor()
	if (
		not is_instance_valid(actor)
		or actor.is_queued_for_deletion()
		or not actor.is_inside_tree()
	):
		_latch_patrol_actor_loss()
		return
	_track_patrol_actor(actor, _generation)


func _latch_patrol_actor_loss() -> void:
	_patrol_actor_ref = null
	_patrol_actor_exit_callback = Callable()
	_patrol_actor_exit_pending = false
	_patrol_actor_status_id = &"lost"
	_patrol_actor_loss_pending = true
	_patrol_actor_pending_reason = &"patrol_actor_lost"


func _disconnect_patrol_actor_exit_signal(clear_actor_ref: bool = true) -> void:
	var actor := _get_tracked_patrol_actor()
	if (
		is_instance_valid(actor)
		and _patrol_actor_exit_callback.is_valid()
		and actor.tree_exiting.is_connected(_patrol_actor_exit_callback)
	):
		actor.tree_exiting.disconnect(_patrol_actor_exit_callback)
	if clear_actor_ref:
		_patrol_actor_ref = null
	_patrol_actor_exit_callback = Callable()
	_patrol_actor_exit_pending = false


func _release_patrol_actor() -> void:
	_disconnect_patrol_actor_exit_signal()
	_patrol_actor_instance_id = 0
	_patrol_actor_status_id = &"unbound"
	_patrol_actor_exit_pending = false
	_patrol_actor_loss_pending = false
	_patrol_actor_pending_reason = &""


func _director_state_matches(director: ActivityDirector) -> bool:
	if not _director_owns_route(director):
		return false
	if not _started_once:
		return true
	var activity_snapshot := director.get_activity_snapshot(definition.activity_id)
	if activity_snapshot.is_empty():
		return false
	if int(activity_snapshot.get("generation", -1)) != _activity_generation:
		return false
	var activity_state := int(
		activity_snapshot.get("state", CheckpointRouteActivity.State.IDLE)
	)
	match _state:
		State.IDLE:
			return activity_state == CheckpointRouteActivity.State.IDLE
		State.ACTIVE:
			return (
				activity_state == CheckpointRouteActivity.State.ACTIVE
				and int(activity_snapshot.get("next_checkpoint_index", -1))
				== _next_checkpoint_index
			)
		State.COMPLETED:
			return activity_state == CheckpointRouteActivity.State.COMPLETED
		State.FAILED, State.ABORTED:
			return activity_state == CheckpointRouteActivity.State.FAILED
	return false


func _director_progress_matches_active(expected_next_checkpoint: int) -> bool:
	if not is_instance_valid(_director):
		return false
	var activity_snapshot := _director.get_activity_snapshot(definition.activity_id)
	return (
		int(activity_snapshot.get("generation", -1)) == _activity_generation
		and int(activity_snapshot.get("state", CheckpointRouteActivity.State.IDLE))
		== CheckpointRouteActivity.State.ACTIVE
		and int(activity_snapshot.get("next_checkpoint_index", -1))
		== expected_next_checkpoint
	)


func _director_progress_matches_completed() -> bool:
	if not is_instance_valid(_director):
		return false
	var activity_snapshot := _director.get_activity_snapshot(definition.activity_id)
	return (
		int(activity_snapshot.get("generation", -1)) == _activity_generation
		and int(activity_snapshot.get("state", CheckpointRouteActivity.State.IDLE))
		== CheckpointRouteActivity.State.COMPLETED
		and int(activity_snapshot.get("next_checkpoint_index", -1))
		== definition.get_checkpoint_count()
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


func _accepts_activity_signal(activity_id: StringName, activity_generation: int) -> bool:
	return (
		_attached
		and definition != null
		and activity_id == definition.activity_id
		and activity_generation == _activity_generation
	)


func _running_rejection(expected_generation: int) -> StringName:
	if expected_generation != _generation:
		return &"stale_generation"
	if _closed:
		return &"closed"
	if not _attached:
		return &"not_attached"
	if _state != State.ACTIVE:
		return &"not_running"
	return &""


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


func _emit_snapshot_signal(patrol_signal: Signal) -> void:
	_signal_dispatch_active = true
	patrol_signal.emit(get_presentation_snapshot())
	_signal_dispatch_active = false


func _emit_checkpoint_signal(patrol_signal: Signal, checkpoint_index: int) -> void:
	_signal_dispatch_active = true
	patrol_signal.emit(get_presentation_snapshot(), checkpoint_index)
	_signal_dispatch_active = false


func _state_id(state: int) -> StringName:
	match state:
		State.ACTIVE:
			return &"active"
		State.COMPLETED:
			return &"completed"
		State.FAILED:
			return &"failed"
		State.ABORTED:
			return &"aborted"
		_:
			return &"idle"
