class_name BomberPayloadAudioBinding
extends Node

## Presentation-only bridge for accepted BomberPayloadAuthority release records.
## It never admits, spawns, moves, damages, or scores payloads.

signal semantic_engine_cue_emitted(cue_id: StringName, intensity: float)
signal payload_audio_cue_emitted(cue_id: StringName, payload_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const ProjectileBinding := preload("res://scripts/audio/bomber_payload_projectile_audio_binding.gd")
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const CUE_RELEASE: StringName = &"bomber_payload_release"
const CUE_ABORT: StringName = &"bomber_payload_abort"
const CUE_RESET: StringName = &"bomber_payload_reset"
const PRIORITIES := {CUE_RELEASE: 70, CUE_ABORT: 85, CUE_RESET: 20}

var _attached := false
var _generation := 0
var _last_sequence := -1
var _reduced_dynamic_range := false
var _active_cue_slots: Array[Dictionary] = []
var _last_payload_id: StringName = &""
var _last_snapshot: Dictionary = {}
var _emitted_cue_count := 0
var _preempted_cue_count := 0
var _last_preempted_cue: StringName = &""
var _projectile_binding: Node


func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_clear_state()
	_projectile_binding = ProjectileBinding.new()
	_projectile_binding.semantic_engine_cue_emitted.connect(_on_projectile_cue)
	var projectile_result: Dictionary = _projectile_binding.attach(0)
	for generation in range(expected_generation):
		if not bool(projectile_result.get("accepted", false)):
			break
		_projectile_binding.detach()
		projectile_result = _projectile_binding.attach(generation + 1)
	if not bool(projectile_result.get("accepted", false)):
		_projectile_binding.free()
		_projectile_binding = null
		_attached = false
		return _result(false, &"projectile_binding_failed")
	return _result(true, &"attached")


func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	if _reduced_dynamic_range == enabled:
		return _result(true, &"mix_unchanged")
	_reduced_dynamic_range = enabled
	if _projectile_binding != null:
		_projectile_binding.set_reduced_dynamic_range(enabled)
	return _result(true, &"mix_updated")


func present_release_record(record: Dictionary) -> Dictionary:
	return _present_record(record, CUE_RELEASE)


func present_abort_record(record: Dictionary) -> Dictionary:
	return _present_record(record, CUE_ABORT)


func present_projectile_launch(record: Dictionary) -> Dictionary:
	if _projectile_binding == null:
		return _result(false, &"not_attached")
	return _projectile_binding.present_launch_record(record)


func present_projectile_terminal(intent: Dictionary) -> Dictionary:
	if _projectile_binding == null:
		return _result(false, &"not_attached")
	return _projectile_binding.present_terminal_intent(intent)


func present_projectile_abort(record: Dictionary) -> Dictionary:
	if _projectile_binding == null:
		return _result(false, &"not_attached")
	return _projectile_binding.present_abort_record(record)


func reset_for_reuse(expected_generation: int) -> Dictionary:
	return attach(expected_generation)


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_clear_state()
	if _projectile_binding != null:
		_projectile_binding.detach()
		_projectile_binding.free()
		_projectile_binding = null
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_sequence": _last_sequence,
		"last_payload_id": _last_payload_id,
		"reduced_dynamic_range": _reduced_dynamic_range,
		"last_snapshot": _last_snapshot.duplicate(true),
		"active_cue_slots": _active_cue_slots.duplicate(true),
		"emitted_cue_count": _emitted_cue_count,
		"preempted_cue_count": _preempted_cue_count,
		"last_preempted_cue": _last_preempted_cue,
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"projectile_audio": _projectile_binding.get_snapshot() if _projectile_binding != null else {},
		"authority": {"release": false, "spawn": false, "combat": false, "audio_cues": true},
	}.duplicate(true)


func _present_record(record: Dictionary, cue_id: StringName) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var decoded := _decode_record(record)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_record")))
	var sequence := int(decoded.sequence)
	if sequence <= _last_sequence:
		return _result(false, &"duplicate_sequence" if sequence == _last_sequence else &"stale_sequence")
	_last_sequence = sequence
	_last_payload_id = decoded.payload_id
	_last_snapshot = record.duplicate(true)
	_emit_cue(cue_id, decoded.payload_id, 1.0)
	return _result(true, &"cue_presented")


func _decode_record(record: Dictionary) -> Dictionary:
	var generation: Variant = record.get("generation", -1)
	var sequence: Variant = record.get("request_sequence", record.get("sequence", -1))
	var payload_id: Variant = record.get("payload_id", &"")
	if not generation is int or int(generation) < 0 or int(generation) > MAX_SAFE_GENERATION \
			or int(generation) != _generation:
		return _result(false, &"stale_generation")
	if not sequence is int or int(sequence) < 0:
		return _result(false, &"invalid_sequence")
	if not payload_id is StringName or (payload_id as StringName).is_empty():
		return _result(false, &"invalid_payload_id")
	return {"accepted": true, "sequence": int(sequence), "payload_id": payload_id}


func _emit_cue(cue_id: StringName, payload_id: StringName, intensity: float) -> void:
	if not _admit_cue(cue_id):
		return
	var adjusted := clampf(intensity * (0.75 if _reduced_dynamic_range else 1.0), 0.0, 1.0)
	_emitted_cue_count += 1
	payload_audio_cue_emitted.emit(cue_id, payload_id, adjusted)
	semantic_engine_cue_emitted.emit(cue_id, adjusted)


func _on_projectile_cue(cue_id: StringName, intensity: float) -> void:
	semantic_engine_cue_emitted.emit(cue_id, intensity)


func _admit_cue(cue_id: StringName) -> bool:
	var priority := int(PRIORITIES.get(cue_id, 0))
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
	_last_payload_id = &""
	_last_snapshot.clear()
	_active_cue_slots.clear()
	_last_preempted_cue = &""


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
