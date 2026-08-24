class_name CrewEngineerAudioBinding
extends Node

## Audio-only presentation bridge for caller-accepted engineer repair events.
## Repair authority, component state, and progress ownership remain external.

signal semantic_engine_cue_emitted(cue_id: StringName, intensity: float)
signal semantic_crew_cue_emitted(cue_id: StringName, role: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const STATES := [&"started", &"progress", &"interrupted", &"completed"]
const CUE_BY_STATE := {
	&"started": &"crew_engineer_repair_started",
	&"progress": &"crew_engineer_repair_progress",
	&"interrupted": &"crew_engineer_repair_interrupted",
	&"completed": &"crew_engineer_repair_completed",
}
const PRIORITY_BY_CUE := {
	&"crew_engineer_repair_started": 60,
	&"crew_engineer_repair_progress": 20,
	&"crew_engineer_repair_interrupted": 80,
	&"crew_engineer_repair_completed": 100,
}

var _attached := false
var _generation := 0
var _last_sequence := -1
var _last_state: StringName = &""
var _reduced_dynamic_range := false
var _active_cue_slots: Array[Dictionary] = []
var _last_snapshot: Dictionary = {}
var _emitted_cue_count := 0
var _preempted_cue_count := 0
var _last_preempted_cue: StringName = &""
var _last_retire_reason: StringName = &""


func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_clear_state()
	return _result(true, &"attached")


func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	if _reduced_dynamic_range == enabled:
		return _result(true, &"mix_unchanged")
	_reduced_dynamic_range = enabled
	return _result(true, &"mix_updated")


func present_repair_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var decoded := _decode_snapshot(snapshot)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_snapshot")))
	var sequence := int(decoded.sequence)
	if sequence <= _last_sequence:
		return _result(false, &"duplicate_sequence" if sequence == _last_sequence else &"stale_sequence")
	_last_sequence = sequence
	var state: StringName = decoded.state
	var cue_id: StringName = CUE_BY_STATE[state]
	var intensity := float(decoded.progress) if state == &"progress" else 1.0
	_emit_cue(cue_id, intensity)
	_last_state = state
	_last_snapshot = snapshot.duplicate(true)
	return _result(true, &"snapshot_presented")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_clear_state()
	_last_retire_reason = &"detached"
	return _result(true, &"detached")


## Retires bounded presentation voices without erasing the accepted sequence.
## The caller remains responsible for deciding that a terminal/clear lifecycle
## event occurred; this binding owns no repair state or playback bank.
func retire_active_cues(expected_generation: int, reason: StringName) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if reason.is_empty():
		return _result(false, &"invalid_retire_reason")
	_active_cue_slots.clear()
	_last_retire_reason = reason
	return _result(true, &"cues_retired")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_sequence": _last_sequence,
		"last_state": _last_state,
		"reduced_dynamic_range": _reduced_dynamic_range,
		"last_snapshot": _last_snapshot.duplicate(true),
		"active_cue_slots": _active_cue_slots.duplicate(true),
		"emitted_cue_count": _emitted_cue_count,
		"preempted_cue_count": _preempted_cue_count,
		"last_preempted_cue": _last_preempted_cue,
		"last_retire_reason": _last_retire_reason,
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"repair": false, "components": false, "audio_cues": true},
	}.duplicate(true)


func _decode_snapshot(snapshot: Dictionary) -> Dictionary:
	var generation: Variant = snapshot.get("generation", -1)
	var sequence: Variant = snapshot.get("sequence", -1)
	var state: Variant = snapshot.get("repair_state", &"")
	var progress: Variant = snapshot.get("progress", 1.0)
	if not generation is int or int(generation) < 0 or int(generation) > MAX_SAFE_GENERATION \
			or int(generation) != _generation:
		return _result(false, &"stale_generation")
	if not sequence is int or int(sequence) < 0:
		return _result(false, &"invalid_sequence")
	if not state is StringName or not STATES.has(state as StringName):
		return _result(false, &"invalid_repair_state")
	if not (progress is float or progress is int) or not is_finite(float(progress)) \
			or float(progress) < 0.0 or float(progress) > 1.0:
		return _result(false, &"invalid_progress")
	return {"accepted": true, "sequence": int(sequence), "state": state, "progress": float(progress)}


func _emit_cue(cue_id: StringName, intensity: float) -> void:
	if not _admit_cue(cue_id):
		return
	_last_retire_reason = &""
	var adjusted := clampf(intensity * (0.75 if _reduced_dynamic_range else 1.0), 0.0, 1.0)
	_emitted_cue_count += 1
	semantic_engine_cue_emitted.emit(cue_id, adjusted)
	semantic_crew_cue_emitted.emit(cue_id, &"engineer", adjusted)


func _admit_cue(cue_id: StringName) -> bool:
	var priority := int(PRIORITY_BY_CUE.get(cue_id, 0))
	if _active_cue_slots.size() < MAXIMUM_SIMULTANEOUS_VOICES:
		_active_cue_slots.append({"cue_id": cue_id, "priority": priority})
		return true
	var lowest_index := 0
	for index in range(1, _active_cue_slots.size()):
		if int(_active_cue_slots[index].priority) < int(_active_cue_slots[lowest_index].priority):
			lowest_index = index
	if priority <= int(_active_cue_slots[lowest_index].priority):
		return false
	_last_preempted_cue = StringName(_active_cue_slots[lowest_index].cue_id)
	_preempted_cue_count += 1
	_active_cue_slots[lowest_index] = {"cue_id": cue_id, "priority": priority}
	return true


func _clear_state() -> void:
	_last_sequence = -1
	_last_state = &""
	_active_cue_slots.clear()
	_last_snapshot.clear()
	_last_preempted_cue = &""
	_last_retire_reason = &""


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
