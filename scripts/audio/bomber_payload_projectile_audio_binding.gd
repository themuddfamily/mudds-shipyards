class_name BomberPayloadProjectileAudioBinding
extends Node

## Presentation-only bridge for accepted bomber projectile launch/terminal
## records. Projectile motion, collision, expiry, and abort authority stay out.

signal semantic_engine_cue_emitted(cue_id: StringName, intensity: float)
signal projectile_audio_cue_emitted(
		cue_id: StringName, payload_id: StringName, intensity: float, world_position: Vector3
)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const CUE_LAUNCH: StringName = &"bomber_payload_projectile_launch"
const CUE_IMPACT: StringName = &"bomber_payload_projectile_impact"
const CUE_EXPIRY: StringName = &"bomber_payload_projectile_expiry"
const CUE_ABORT: StringName = &"bomber_payload_projectile_abort"
const PRIORITIES := {CUE_LAUNCH: 20, CUE_EXPIRY: 40, CUE_ABORT: 80, CUE_IMPACT: 100}

var _attached := false
var _generation := 0
var _reduced_dynamic_range := false
var _seen_events: Dictionary = {}
var _active_cue_slots: Array[Dictionary] = []
var _last_payload_id: StringName = &""
var _last_snapshot: Dictionary = {}
var _emitted_cue_count := 0
var _preempted_cue_count := 0
var _last_preempted_cue: StringName = &""


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


func present_launch_record(record: Dictionary) -> Dictionary:
	var decoded := _decode_record(record)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_record")))
	return _present_event(CUE_LAUNCH, decoded, "launch")


func present_terminal_intent(intent: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var decoded := _decode_terminal(intent)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_terminal")))
	var kind: StringName = decoded.kind
	return _present_event(CUE_IMPACT if kind == &"impact" else CUE_EXPIRY, decoded, "terminal")


func present_abort_record(record: Dictionary) -> Dictionary:
	var decoded := _decode_record(record)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_record")))
	return _present_event(CUE_ABORT, decoded, "abort")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_clear_state()
	return _result(true, &"detached")


func reset_for_reuse(expected_generation: int) -> Dictionary:
	return attach(expected_generation)


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"reduced_dynamic_range": _reduced_dynamic_range,
		"seen_event_count": _seen_events.size(),
		"active_cue_slots": _active_cue_slots.duplicate(true),
		"last_payload_id": _last_payload_id,
		"last_snapshot": _last_snapshot.duplicate(true),
		"emitted_cue_count": _emitted_cue_count,
		"preempted_cue_count": _preempted_cue_count,
		"last_preempted_cue": _last_preempted_cue,
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"motion": false, "impact": false, "expiry": false, "audio_cues": true},
	}.duplicate(true)


func _present_event(cue_id: StringName, decoded: Dictionary, kind: String) -> Dictionary:
	var event_key := "%d:%d:%s" % [int(decoded.generation), int(decoded.sequence), kind]
	if _seen_events.has(event_key):
		return _result(false, &"duplicate_event")
	_seen_events[event_key] = true
	_last_payload_id = decoded.payload_id
	_last_snapshot = decoded.snapshot.duplicate(true)
	_emit_cue(cue_id, decoded.payload_id, decoded.position)
	return _result(true, &"cue_presented")


func _decode_record(record: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var generation: Variant = record.get("generation", -1)
	var sequence: Variant = record.get("request_sequence", record.get("release_sequence", -1))
	var payload_id: Variant = record.get("payload_id", &"")
	if not generation is int or int(generation) < 0 or int(generation) > MAX_SAFE_GENERATION \
			or int(generation) != _generation:
		return _result(false, &"stale_generation")
	if not sequence is int or int(sequence) < 0:
		return _result(false, &"invalid_sequence")
	if not payload_id is StringName or (payload_id as StringName).is_empty():
		return _result(false, &"invalid_payload_id")
	return {"accepted": true, "generation": int(generation), "sequence": int(sequence), "payload_id": payload_id, "position": Vector3.ZERO, "snapshot": record}


func _decode_terminal(intent: Dictionary) -> Dictionary:
	var generation: Variant = intent.get("generation", -1)
	var sequence: Variant = intent.get("terminal_sequence", -1)
	var kind: Variant = intent.get("kind", &"")
	var payload_id: Variant = intent.get("payload_id", &"")
	var position: Variant = intent.get("position", Vector3.ZERO)
	if not generation is int or int(generation) != _generation \
			or not sequence is int or int(sequence) < 0:
		return _result(false, &"stale_generation")
	if kind not in [&"impact", &"expiry"]:
		return _result(false, &"invalid_terminal_kind")
	if not payload_id is StringName or (payload_id as StringName).is_empty() \
			or not position is Vector3 or not position.is_finite():
		return _result(false, &"invalid_terminal")
	return {"accepted": true, "generation": generation, "sequence": sequence, "kind": kind, "payload_id": payload_id, "position": position, "snapshot": intent}


func _emit_cue(cue_id: StringName, payload_id: StringName, position: Vector3) -> void:
	if not _admit_cue(cue_id):
		return
	var intensity := 0.75 if _reduced_dynamic_range else 1.0
	_emitted_cue_count += 1
	projectile_audio_cue_emitted.emit(cue_id, payload_id, intensity, position)
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
	_seen_events.clear()
	_active_cue_slots.clear()
	_last_payload_id = &""
	_last_snapshot.clear()
	_last_preempted_cue = &""


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
