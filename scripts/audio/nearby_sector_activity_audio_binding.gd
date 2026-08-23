class_name NearbySectorActivityAudioBinding
extends Node

## Audio-owned presentation adapter for detached Nearby Sector activity state.
## It observes snapshots only; activity, checkpoint, and reward authority remain
## with the caller. No per-activity gameplay knowledge is required here.

signal semantic_activity_cue_emitted(cue_id: StringName, activity_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const PROGRESS_THRESHOLDS := [0.25, 0.5, 0.75]
const ACTIVITY_STATES := [&"idle", &"selected", &"active", &"complete", &"reset"]
const CUE_PRIORITIES := {
	&"activity_progress": 10,
	&"activity_checkpoint": 20,
	&"activity_complete": 80,
	&"activity_reset": 85,
	&"activity_reward_pending": 90,
}

var _attached := false
var _generation := 0
var _last_snapshot: Dictionary = {}
var _last_activity_id: StringName = &""
var _last_state: StringName = &"idle"
var _last_checkpoint_id: StringName = &""
var _last_progress := 0.0
var _last_reward_pending := false
var _progress_thresholds_emitted := {}
var _emitted_cue_count := 0
var _active_cue_slots: Array[Dictionary] = []
var _preempted_cue_count := 0
var _last_preempted_cue: StringName = &""
var _activity_ledger: Dictionary = {}
var _audio_director: Node
var _semantic_output_bound := false
var _reduced_dynamic_range := false
var _ever_attached := false


func _ready() -> void:
	call_deferred("_bind_authored_semantic_output")


func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	if not _ever_attached:
		_activity_ledger.clear()
		_ever_attached = true
	_last_snapshot.clear()
	_last_activity_id = &""
	_last_state = &"idle"
	_last_checkpoint_id = &""
	_last_progress = 0.0
	_last_reward_pending = false
	_progress_thresholds_emitted.clear()
	_active_cue_slots.clear()
	_last_preempted_cue = &""
	_ensure_semantic_output_bound()
	return _result(true, &"attached")


## Registers this presentation-only source with the existing AudioDirector
## semantic router. The director continues to own playback/mix and GameFlow
## continues to own captions and accessibility policy.
func bind_semantic_audio_output(audio_director: Node) -> Dictionary:
	if audio_director == null or not is_instance_valid(audio_director) \
			or not audio_director.has_method(&"bind_semantic_audio_source") \
			or not audio_director.has_method(&"unbind_semantic_audio_source"):
		return _result(false, &"audio_director_contract_missing")
	if _audio_director != audio_director:
		_unbind_semantic_output()
		_audio_director = audio_director
	return _ensure_semantic_output_bound()


func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	return _result(true, &"reduced_dynamic_range_updated")


func present_activity_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var decoded := _decode_snapshot(snapshot)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_snapshot")))
	var activity_id: StringName = decoded.activity_id
	var state: StringName = decoded.state
	var progress := float(decoded.progress_unitless)
	var checkpoint_id: StringName = decoded.checkpoint_id
	var reward_pending := bool(decoded.reward_pending)
	var reset_serial := int(decoded.reset_serial)
	var source_generation := int(decoded.generation)
	var previous := _activity_ledger.get(activity_id, {}) as Dictionary
	var previous_generation := int(previous.get("generation", -1))
	if source_generation < previous_generation:
		return _result(false, &"stale_activity_generation")
	if source_generation > previous_generation:
		previous = {}
	var previous_state := StringName(previous.get("state", &"idle"))
	var previous_checkpoint := StringName(previous.get("checkpoint_id", &""))
	var previous_progress := float(previous.get("progress", 0.0))
	var previous_reward_pending := bool(previous.get("reward_pending", false))
	var previous_reset_serial := int(previous.get("reset_serial", 0))
	var thresholds := previous.get("progress_thresholds", {}) as Dictionary
	if previous.is_empty():
		_emit_cue(&"activity_selected", activity_id, 1.0)
	if state == &"active" and previous_state != &"active":
		_emit_cue(&"activity_started", activity_id, 1.0)
	if checkpoint_id != &"" and checkpoint_id != previous_checkpoint:
		_emit_cue(&"activity_checkpoint", activity_id, 1.0)
	for threshold: float in PROGRESS_THRESHOLDS:
		if progress >= threshold and previous_progress < threshold \
				and not thresholds.has(threshold):
			thresholds[threshold] = true
			_emit_cue(&"activity_progress", activity_id, threshold)
	if state == &"complete" and previous_state != &"complete":
		_emit_cue(&"activity_complete", activity_id, 1.0)
	if reward_pending and not previous_reward_pending:
		_emit_cue(&"activity_reward_pending", activity_id, 1.0)
	if state == &"reset" and previous_state != &"reset" \
			or reset_serial > previous_reset_serial:
		_emit_cue(&"activity_reset", activity_id, 1.0)
	_activity_ledger[activity_id] = {
		"generation": source_generation,
		"state": state,
		"checkpoint_id": checkpoint_id,
		"progress": progress,
		"reward_pending": reward_pending,
		"reset_serial": reset_serial,
		"progress_thresholds": thresholds.duplicate(true),
	}.duplicate(true)
	_last_activity_id = activity_id
	_last_state = state
	_last_checkpoint_id = checkpoint_id
	_last_progress = progress
	_last_reward_pending = reward_pending
	_last_snapshot = snapshot.duplicate(true)
	return _result(true, &"snapshot_presented")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_unbind_semantic_output()
	_generation += 1
	_last_snapshot.clear()
	_last_activity_id = &""
	_last_state = &"idle"
	_last_checkpoint_id = &""
	_last_progress = 0.0
	_last_reward_pending = false
	_progress_thresholds_emitted.clear()
	_active_cue_slots.clear()
	_last_preempted_cue = &""
	return _result(true, &"detached")


func _exit_tree() -> void:
	if _attached:
		detach()
	else:
		_unbind_semantic_output()


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_snapshot": _last_snapshot.duplicate(true),
		"last_activity_id": _last_activity_id,
		"last_state": _last_state,
		"last_progress_unitless": _last_progress,
		"emitted_cue_count": _emitted_cue_count,
		"active_cue_slots": _active_cue_slots.duplicate(true),
		"preempted_cue_count": _preempted_cue_count,
		"last_preempted_cue": _last_preempted_cue,
		"semantic_output_bound": _semantic_output_bound,
		"tracked_activity_count": _activity_ledger.size(),
		"reduced_dynamic_range": _reduced_dynamic_range,
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"activity": false, "reward": false, "gameplay": false, "audio_cues": true},
	}.duplicate(true)


func _decode_snapshot(snapshot: Dictionary) -> Dictionary:
	var activity_id: Variant = snapshot.get("activity_id", &"")
	var state: Variant = snapshot.get("state", &"")
	var progress: Variant = snapshot.get("progress_unitless", 0.0)
	var checkpoint: Variant = snapshot.get("checkpoint_id", &"")
	var reset_serial: Variant = snapshot.get("reset_serial", 0)
	var generation: Variant = snapshot.get("generation", 0)
	if activity_id is not StringName or (activity_id as StringName).is_empty() \
			or state is not StringName or not ACTIVITY_STATES.has(state as StringName) \
			or not _finite_range(progress, 0.0, 1.0) \
			or checkpoint is not StringName or not (reset_serial is int) \
			or not (generation is int) or int(generation) < 0 \
			or int(generation) > MAX_SAFE_GENERATION \
			or int(reset_serial) < 0 or int(reset_serial) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_snapshot")
	var reward_pending: Variant = snapshot.get("reward_pending", false)
	if reward_pending is not bool:
		return _result(false, &"invalid_reward_state")
	return {
		"accepted": true,
		"activity_id": activity_id,
		"state": state,
		"progress_unitless": float(progress),
		"checkpoint_id": checkpoint,
		"reward_pending": reward_pending,
		"reset_serial": int(reset_serial),
		"generation": int(generation),
	}.duplicate(true)


func _emit_cue(cue_id: StringName, activity_id: StringName, intensity: float) -> void:
	if not _admit_cue(cue_id, activity_id):
		return
	_emitted_cue_count += 1
	_refresh_reduced_dynamic_range()
	var adjusted := intensity * (0.75 if _reduced_dynamic_range else 1.0)
	semantic_activity_cue_emitted.emit(cue_id, activity_id, clampf(adjusted, 0.0, 1.0))


func _admit_cue(cue_id: StringName, activity_id: StringName) -> bool:
	if not CUE_PRIORITIES.has(cue_id):
		return true
	var priority := int(CUE_PRIORITIES[cue_id])
	if _active_cue_slots.size() < MAXIMUM_SIMULTANEOUS_VOICES:
		_active_cue_slots.append({"cue_id": cue_id, "activity_id": activity_id, "priority": priority})
		return true
	var lowest_index := 0
	for index in range(1, _active_cue_slots.size()):
		if int(_active_cue_slots[index].get("priority", 0)) < int(_active_cue_slots[lowest_index].get("priority", 0)):
			lowest_index = index
	var lowest_priority := int(_active_cue_slots[lowest_index].get("priority", 0))
	if priority <= lowest_priority:
		return false
	_last_preempted_cue = StringName(_active_cue_slots[lowest_index].get("cue_id", &""))
	_preempted_cue_count += 1
	_active_cue_slots[lowest_index] = {
		"cue_id": cue_id, "activity_id": activity_id, "priority": priority,
	}
	return true


func _bind_authored_semantic_output() -> void:
	if _audio_director != null or not is_inside_tree():
		return
	var host := get_parent()
	var director := host.get_node_or_null(^"AudioDirector") if host != null else null
	if is_instance_valid(director):
		bind_semantic_audio_output(director)


func _ensure_semantic_output_bound() -> Dictionary:
	if not _attached:
		return _result(true, &"semantic_output_deferred")
	if _audio_director == null or not is_instance_valid(_audio_director):
		return _result(false, &"audio_director_unavailable")
	# The router may have cleared all registrations while Main was detached.
	# Reconcile idempotently instead of trusting a retained local flag.
	_audio_director.call(&"unbind_semantic_audio_source", self, &"activity")
	var result := _audio_director.call(
		&"bind_semantic_audio_source", self, &"activity"
	) as Dictionary
	_semantic_output_bound = bool(result.get("accepted", false))
	_refresh_reduced_dynamic_range()
	return result


func _unbind_semantic_output() -> void:
	if _audio_director != null and is_instance_valid(_audio_director):
		_audio_director.call(&"unbind_semantic_audio_source", self, &"activity")
	_semantic_output_bound = false


func _refresh_reduced_dynamic_range() -> void:
	if _audio_director == null or not is_instance_valid(_audio_director) \
			or not _audio_director.has_method(&"get_dynamic_mix_plan"):
		return
	var mix := _audio_director.call(&"get_dynamic_mix_plan") as Dictionary
	_reduced_dynamic_range = bool(mix.get("reduced_dynamic_range", false))


func _finite_range(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
			and float(value) >= minimum and float(value) <= maximum


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}.duplicate(true)
