class_name NearbySectorActivityAudioBinding
extends Node

## Audio-owned presentation adapter for detached Nearby Sector activity state.
## It observes snapshots only; activity, checkpoint, and reward authority remain
## with the caller. No per-activity gameplay knowledge is required here.

signal semantic_activity_cue_emitted(cue_id: StringName, activity_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const PROGRESS_THRESHOLDS := [0.25, 0.5, 0.75]
const ACTIVITY_STATES := [&"idle", &"selected", &"countdown", &"active", &"complete", &"reset"]
const BEACON_TRANSITION_CUES := [
	&"beacon_gate_acquired", &"beacon_route_interrupted", &"beacon_route_recovered",
	&"beacon_final_gate", &"beacon_route_completed",
]
const CONVOY_TRANSITION_CUES := [
	&"convoy_escort_secure", &"convoy_escort_separation_warning",
	&"convoy_escort_separation_critical", &"convoy_escort_recovered",
	&"convoy_escort_formation_secured", &"convoy_escort_lost",
]
const MINING_TRANSITION_CUES := [
	&"cinder_mining_extraction_started", &"cinder_mining_yield_checkpoint",
	&"cinder_mining_extraction_interrupted", &"cinder_mining_capacity_ready",
	&"cinder_mining_extraction_completed",
]
const SCAN_TRANSITION_CUES := [
	&"cinder_scan_started", &"cinder_scan_progress_checkpoint",
	&"cinder_scan_interrupted", &"cinder_scan_completed",
]
const RACE_TRANSITION_CUES := [
	&"cinder_race_countdown_started", &"cinder_race_gate_acquired",
	&"cinder_race_missed_gate", &"cinder_race_completed",
]
const CUE_PRIORITIES := {
	&"activity_progress": 10,
	&"activity_checkpoint": 20,
	&"activity_complete": 80,
	&"activity_reset": 85,
	&"activity_reward_pending": 90,
	&"cargo_deadline_warning": 60,
	&"cargo_deadline_critical": 95,
	&"cargo_deadline_recovered": 70,
	&"cargo_delivery_completed": 90,
	&"beacon_gate_acquired": 40,
	&"beacon_route_interrupted": 95,
	&"beacon_route_recovered": 70,
	&"beacon_final_gate": 90,
	&"beacon_route_completed": 100,
	&"convoy_escort_secure": 40,
	&"convoy_escort_separation_warning": 70,
	&"convoy_escort_separation_critical": 95,
	&"convoy_escort_recovered": 75,
	&"convoy_escort_formation_secured": 90,
	&"convoy_escort_lost": 100,
	&"cinder_mining_extraction_started": 50,
	&"cinder_mining_yield_checkpoint": 40,
	&"cinder_mining_extraction_interrupted": 90,
	&"cinder_mining_capacity_ready": 85,
	&"cinder_mining_extraction_completed": 95,
	&"cinder_scan_started": 50,
	&"cinder_scan_progress_checkpoint": 40,
	&"cinder_scan_interrupted": 90,
	&"cinder_scan_completed": 95,
	&"cinder_race_countdown_started": 55,
	&"cinder_race_gate_acquired": 45,
	&"cinder_race_missed_gate": 90,
	&"cinder_race_completed": 95,
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
	var activity_kind := StringName(decoded.activity_kind)
	var source_time := float(decoded.source_time_seconds)
	var previous := _activity_ledger.get(activity_id, {}) as Dictionary
	var previous_generation := int(previous.get("generation", -1))
	if source_generation < previous_generation:
		return _result(false, &"stale_activity_generation")
	var mining_reset_rewind := activity_kind == &"mining" and state == &"reset" \
		and is_zero_approx(source_time)
	if source_generation == previous_generation \
			and source_time < float(previous.get("source_time_seconds", 0.0)) \
			and not mining_reset_rewind:
		return _result(false, &"stale_activity_time")
	if activity_kind == &"beacon" and source_generation == previous_generation \
			and int(decoded.next_beacon_index) < int(previous.get("next_beacon_index", 0)):
		return _result(false, &"stale_beacon_checkpoint")
	if activity_kind == &"mining" and source_generation == previous_generation \
			and state != &"reset" \
			and _mining_progress(decoded) < float(previous.get("mining_progress", 0.0)):
		return _result(false, &"stale_mining_yield")
	var is_structure_scan := activity_kind == &"salvage" \
			and activity_id == &"cinder_derelict_structure_scan"
	if is_structure_scan and source_generation == previous_generation \
			and state != &"reset" \
			and progress < float(previous.get("scan_progress", 0.0)):
		return _result(false, &"stale_scan_progress")
	var is_cinder_race := activity_kind == &"race" \
			and activity_id == &"cinder_reach_checkpoint_route"
	if is_cinder_race and source_generation == previous_generation \
			and state != &"reset" \
			and progress < float(previous.get("race_progress", 0.0)):
		return _result(false, &"stale_race_gate")
	var generation_changed := source_generation > previous_generation
	var prior_generation_urgency := StringName(previous.get("urgency", &"normal"))
	if generation_changed:
		previous = {}
	var previous_state := StringName(previous.get("state", &"idle"))
	var previous_checkpoint := StringName(previous.get("checkpoint_id", &""))
	var previous_progress := float(previous.get("progress", 0.0))
	var previous_reward_pending := bool(previous.get("reward_pending", false))
	var previous_reset_serial := int(previous.get("reset_serial", 0))
	var thresholds := previous.get("progress_thresholds", {}) as Dictionary
	var urgency := _cargo_urgency(decoded) if activity_kind == &"cargo" else &"normal"
	var previous_urgency := StringName(previous.get("urgency", &"normal"))
	var previous_beacon_index := int(previous.get("next_beacon_index", 0))
	var previous_beacon_reason := StringName(previous.get("beacon_interruption_reason", &""))
	var previous_convoy_threat := StringName(previous.get("convoy_threat", &"none"))
	var previous_mining_checkpoint := int(previous.get("mining_yield_checkpoint", 0))
	var previous_scan_checkpoint := int(previous.get("scan_progress_checkpoint", 0))
	var previous_race_missed := bool(previous.get("race_missed_gate", false))
	if generation_changed and urgency == &"normal":
		previous_urgency = prior_generation_urgency
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
	if activity_kind == &"cargo":
		if urgency == &"warning" and previous_urgency not in [&"warning", &"critical"]:
			_emit_cue(&"cargo_deadline_warning", activity_id, 0.8)
		elif urgency == &"critical" and previous_urgency != &"critical":
			_emit_cue(&"cargo_deadline_critical", activity_id, 1.0)
		elif urgency == &"normal" and previous_urgency in [&"warning", &"critical"]:
			_emit_cue(&"cargo_deadline_recovered", activity_id, 0.75)
	elif activity_kind == &"beacon":
		_retire_beacon_transition_slots(activity_id)
		var beacon_index := int(decoded.next_beacon_index)
		var beacon_count := int(decoded.beacon_count)
		var beacon_reason := StringName(decoded.beacon_interruption_reason)
		if beacon_index > previous_beacon_index and beacon_index < beacon_count:
			_emit_cue(&"beacon_gate_acquired", activity_id, 0.8)
		if not beacon_reason.is_empty() and previous_beacon_reason.is_empty():
			_emit_cue(&"beacon_route_interrupted", activity_id, 1.0)
		elif beacon_reason.is_empty() and not previous_beacon_reason.is_empty():
			_emit_cue(&"beacon_route_recovered", activity_id, 0.7)
		if beacon_index == beacon_count and previous_beacon_index < beacon_count:
			_emit_cue(&"beacon_final_gate", activity_id, 1.0)
	elif activity_kind == &"convoy":
		_retire_activity_transition_slots(activity_id, CONVOY_TRANSITION_CUES)
		var convoy_threat := _convoy_threat(decoded)
		if convoy_threat == &"stable" and previous_convoy_threat == &"none":
			_emit_cue(&"convoy_escort_secure", activity_id, 0.65)
		elif convoy_threat == &"stable" \
				and previous_convoy_threat in [&"warning", &"critical"]:
			_emit_cue(&"convoy_escort_recovered", activity_id, 0.8)
		elif convoy_threat == &"warning" and previous_convoy_threat != &"warning":
			_emit_cue(&"convoy_escort_separation_warning", activity_id, 0.8)
		elif convoy_threat == &"critical" and previous_convoy_threat != &"critical":
			_emit_cue(&"convoy_escort_separation_critical", activity_id, 1.0)
	elif activity_kind == &"mining":
		_retire_activity_transition_slots(activity_id, MINING_TRANSITION_CUES)
		var mining_checkpoint := _mining_yield_checkpoint(decoded)
		if state == &"active" and previous_state != &"active":
			_emit_cue(&"cinder_mining_extraction_started", activity_id, 0.8)
		if state == &"active" and mining_checkpoint > previous_mining_checkpoint:
			_emit_cue(
				&"cinder_mining_yield_checkpoint", activity_id,
				[0.0, 0.4, 0.65, 1.0][mining_checkpoint]
			)
		if state == &"reset" and previous_state != &"reset":
			_emit_cue(&"cinder_mining_extraction_interrupted", activity_id, 1.0)
	elif is_structure_scan:
		_retire_activity_transition_slots(activity_id, SCAN_TRANSITION_CUES)
		var scan_checkpoint := _progress_checkpoint(progress)
		if state == &"active" and previous_state != &"active":
			_emit_cue(&"cinder_scan_started", activity_id, 0.8)
		if state == &"active" and scan_checkpoint > previous_scan_checkpoint:
			_emit_cue(
				&"cinder_scan_progress_checkpoint", activity_id,
				[0.0, 0.4, 0.65, 1.0][scan_checkpoint]
			)
		if state == &"reset" and previous_state != &"reset":
			_emit_cue(&"cinder_scan_interrupted", activity_id, 1.0)
	elif is_cinder_race:
		_retire_activity_transition_slots(activity_id, RACE_TRANSITION_CUES)
		var race_missed := checkpoint_id == &"race_missed_gate"
		var race_failed := checkpoint_id == &"race_failed"
		if state == &"countdown" and previous_state != &"countdown":
			_emit_cue(&"cinder_race_countdown_started", activity_id, 0.8)
		if race_missed and not previous_race_missed:
			_emit_cue(&"cinder_race_missed_gate", activity_id, 1.0)
		if state in [&"active", &"complete"] and not race_missed and not race_failed \
				and progress > previous_progress:
			_emit_cue(
				&"cinder_race_gate_acquired", activity_id,
				clampf(0.45 + 0.55 * progress, 0.0, 1.0)
			)
	if state == &"complete" and previous_state != &"complete":
		if is_cinder_race:
			if checkpoint_id != &"race_failed":
				_emit_cue(&"cinder_race_completed", activity_id, 1.0)
		elif is_structure_scan:
			_emit_cue(&"cinder_scan_completed", activity_id, 1.0)
		elif activity_kind == &"mining":
			_emit_cue(&"cinder_mining_capacity_ready", activity_id, 1.0)
			_emit_cue(&"cinder_mining_extraction_completed", activity_id, 1.0)
		elif activity_kind == &"convoy":
			if StringName(decoded.convoy_outcome) == &"arrived":
				_emit_cue(&"convoy_escort_formation_secured", activity_id, 1.0)
			elif StringName(decoded.convoy_outcome) == &"failed":
				_emit_cue(&"convoy_escort_lost", activity_id, 1.0)
		elif activity_kind == &"beacon":
			_emit_cue(&"beacon_route_completed", activity_id, 1.0)
		elif activity_kind != &"cargo":
			_emit_cue(&"activity_complete", activity_id, 1.0)
		elif StringName(decoded.cargo_outcome) == &"delivered":
			_emit_cue(&"cargo_delivery_completed", activity_id, 1.0)
	if reward_pending and not previous_reward_pending:
		_emit_cue(&"activity_reward_pending", activity_id, 1.0)
	if state == &"reset" and previous_state != &"reset" \
			or reset_serial > previous_reset_serial:
		_emit_cue(&"activity_reset", activity_id, 1.0)
	_activity_ledger[activity_id] = {
		"generation": source_generation,
		"activity_kind": activity_kind,
		"source_time_seconds": source_time,
		"urgency": urgency,
		"next_beacon_index": int(decoded.get("next_beacon_index", 0)),
		"beacon_interruption_reason": StringName(decoded.get("beacon_interruption_reason", &"")),
		"convoy_threat": _convoy_threat(decoded) if activity_kind == &"convoy" else &"none",
		"mining_progress": _mining_progress(decoded) if activity_kind == &"mining" else 0.0,
		"mining_yield_checkpoint": (
			_mining_yield_checkpoint(decoded) if activity_kind == &"mining" else 0
		),
		"scan_progress": progress if is_structure_scan else 0.0,
		"scan_progress_checkpoint": _progress_checkpoint(progress) if is_structure_scan else 0,
		"race_progress": progress if is_cinder_race else 0.0,
		"race_missed_gate": checkpoint_id == &"race_missed_gate" if is_cinder_race else false,
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
	var activity_kind: Variant = snapshot.get("activity_kind", &"")
	var source_time: Variant = snapshot.get("source_time_seconds", 0.0)
	if activity_id is not StringName or (activity_id as StringName).is_empty() \
			or state is not StringName or not ACTIVITY_STATES.has(state as StringName) \
			or not _finite_range(progress, 0.0, 1.0) \
			or checkpoint is not StringName or not (reset_serial is int) \
			or not (generation is int) or int(generation) < 0 \
			or int(generation) > MAX_SAFE_GENERATION \
			or not (activity_kind is StringName) \
			or not (source_time is float or source_time is int) \
			or not is_finite(float(source_time)) or float(source_time) < 0.0 \
			or int(reset_serial) < 0 or int(reset_serial) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_snapshot")
	var reward_pending: Variant = snapshot.get("reward_pending", false)
	if reward_pending is not bool:
		return _result(false, &"invalid_reward_state")
	var decoded := {
		"accepted": true,
		"activity_id": activity_id,
		"state": state,
		"progress_unitless": float(progress),
		"checkpoint_id": checkpoint,
		"reward_pending": reward_pending,
		"reset_serial": int(reset_serial),
		"generation": int(generation),
		"activity_kind": activity_kind,
		"source_time_seconds": float(source_time),
	}.duplicate(true)
	if activity_kind == &"cargo":
		var deadline: Variant = snapshot.get("deadline_seconds", null)
		var remaining: Variant = snapshot.get("deadline_remaining_seconds", null)
		var cargo_outcome: Variant = snapshot.get("cargo_outcome", &"active")
		if not (deadline is float or deadline is int) or not is_finite(float(deadline)) \
				or float(deadline) <= 0.0 \
				or not (remaining is float or remaining is int) or not is_finite(float(remaining)) \
				or float(remaining) < 0.0 or float(remaining) > float(deadline):
			return _result(false, &"invalid_cargo_deadline")
		if not cargo_outcome is StringName \
				or cargo_outcome not in [&"active", &"delivered", &"failed"]:
			return _result(false, &"invalid_cargo_outcome")
		decoded["deadline_seconds"] = float(deadline)
		decoded["deadline_remaining_seconds"] = float(remaining)
		decoded["cargo_outcome"] = cargo_outcome
	elif activity_kind == &"beacon":
		var next_index: Variant = snapshot.get("next_beacon_index", null)
		var beacon_count: Variant = snapshot.get("beacon_count", null)
		var interruption: Variant = snapshot.get("beacon_interruption_reason", &"")
		if not next_index is int or not beacon_count is int \
				or int(beacon_count) <= 0 or int(beacon_count) > 1024 \
				or int(next_index) < 0 or int(next_index) > int(beacon_count):
			return _result(false, &"invalid_beacon_cursor")
		if not interruption is StringName \
				or interruption not in [&"", &"out_of_order_beacon", &"outside_beacon"]:
			return _result(false, &"invalid_beacon_interruption")
		decoded["next_beacon_index"] = int(next_index)
		decoded["beacon_count"] = int(beacon_count)
		decoded["beacon_interruption_reason"] = interruption
	elif activity_kind == &"convoy":
		var has_sample: Variant = snapshot.get("convoy_has_sample", null)
		var escort_distance: Variant = snapshot.get("convoy_escort_distance", null)
		var proximity_radius: Variant = snapshot.get("convoy_proximity_radius", null)
		var within_proximity: Variant = snapshot.get("convoy_within_proximity", null)
		var maximum_separation: Variant = snapshot.get("convoy_maximum_separation_seconds", null)
		var separation_remaining: Variant = snapshot.get("convoy_separation_remaining_seconds", null)
		var convoy_status: Variant = snapshot.get("convoy_status", &"")
		var convoy_outcome: Variant = snapshot.get("convoy_outcome", &"")
		var terminal_reason: Variant = snapshot.get("convoy_terminal_reason", &"")
		if has_sample is not bool or within_proximity is not bool \
				or not _finite_range(escort_distance, -1.0, 1_000_000.0) \
				or not _finite_range(proximity_radius, 0.001, 1_000_000.0) \
				or not _finite_range(maximum_separation, 0.001, 86_400.0) \
				or not _finite_range(separation_remaining, 0.0, float(maximum_separation)):
			return _result(false, &"invalid_convoy_separation")
		if convoy_status is not StringName \
				or convoy_status not in [&"active", &"destroyed", &"lost"] \
				or convoy_outcome is not StringName \
				or convoy_outcome not in [&"active", &"arrived", &"failed"] \
				or terminal_reason is not StringName:
			return _result(false, &"invalid_convoy_status")
		decoded["convoy_has_sample"] = has_sample
		decoded["convoy_escort_distance"] = float(escort_distance)
		decoded["convoy_proximity_radius"] = float(proximity_radius)
		decoded["convoy_within_proximity"] = within_proximity
		decoded["convoy_maximum_separation_seconds"] = float(maximum_separation)
		decoded["convoy_separation_remaining_seconds"] = float(separation_remaining)
		decoded["convoy_status"] = convoy_status
		decoded["convoy_outcome"] = convoy_outcome
		decoded["convoy_terminal_reason"] = terminal_reason
	elif activity_kind == &"mining":
		var elapsed: Variant = snapshot.get("mining_elapsed_seconds", null)
		var duration: Variant = snapshot.get("mining_extraction_seconds", null)
		if not _finite_range(duration, 0.001, 86_400.0) \
				or not _finite_range(elapsed, 0.0, float(duration)):
			return _result(false, &"invalid_mining_extraction")
		if (state == &"complete" and not is_equal_approx(float(elapsed), float(duration))) \
				or (state == &"reset" and not is_zero_approx(float(elapsed))) \
				or (reward_pending and state != &"complete"):
			return _result(false, &"invalid_mining_state")
		decoded["mining_elapsed_seconds"] = float(elapsed)
		decoded["mining_extraction_seconds"] = float(duration)
	return decoded


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


func _retire_beacon_transition_slots(activity_id: StringName) -> void:
	_retire_activity_transition_slots(activity_id, BEACON_TRANSITION_CUES)


func _retire_activity_transition_slots(activity_id: StringName, cue_ids: Array) -> void:
	for index in range(_active_cue_slots.size() - 1, -1, -1):
		var slot := _active_cue_slots[index] as Dictionary
		if StringName(slot.get("activity_id", &"")) == activity_id \
				and StringName(slot.get("cue_id", &"")) in cue_ids:
			_active_cue_slots.remove_at(index)


func _convoy_threat(decoded: Dictionary) -> StringName:
	if StringName(decoded.get("state", &"")) != &"active" \
			or not bool(decoded.get("convoy_has_sample", false)):
		return &"none"
	if bool(decoded.get("convoy_within_proximity", false)):
		return &"stable"
	var maximum := float(decoded.get("convoy_maximum_separation_seconds", 1.0))
	var remaining := float(decoded.get("convoy_separation_remaining_seconds", maximum))
	return &"critical" if remaining / maximum <= 0.25 else &"warning"


func _mining_progress(decoded: Dictionary) -> float:
	var duration := float(decoded.get("mining_extraction_seconds", 1.0))
	return clampf(float(decoded.get("mining_elapsed_seconds", 0.0)) / duration, 0.0, 1.0)


func _mining_yield_checkpoint(decoded: Dictionary) -> int:
	return _progress_checkpoint(_mining_progress(decoded))


func _progress_checkpoint(progress: float) -> int:
	if progress >= 0.75:
		return 3
	if progress >= 0.5:
		return 2
	return 1 if progress >= 0.25 else 0


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


func _cargo_urgency(decoded: Dictionary) -> StringName:
	if StringName(decoded.get("state", &"")) == &"complete":
		return &"terminal"
	var deadline := float(decoded.get("deadline_seconds", 1.0))
	var remaining := float(decoded.get("deadline_remaining_seconds", deadline))
	var ratio := remaining / deadline
	if ratio <= 0.1:
		return &"critical"
	if ratio <= 0.25:
		return &"warning"
	return &"normal"


func _finite_range(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
			and float(value) >= minimum and float(value) <= maximum


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}.duplicate(true)
