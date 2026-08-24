class_name RangeTargetComponentFeedbackBinding
extends RefCounted

## Presentation-only consumer for accepted reusable range-target receipts.
## The target adapter retains damage/destruction authority; this binding only
## fences and translates already-committed receipts into audio/caption semantics.

signal semantic_feedback_cue_emitted(
	cue_id: StringName, intensity: float, voice_admitted: bool
)
signal semantic_cue_emitted(
	source_id: StringName,
	cue_id: StringName,
	intensity: float,
	world_position: Vector3
)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_SEQUENCE := 9_007_199_254_740_991
const COMPONENT_CUES := {
	&"frame": &"range_target_frame_component_impact",
	&"core": &"range_target_core_component_impact",
}
const GENERIC_COMPONENT_CUE: StringName = &"range_target_component_impact"
const RECEIPT_CUES := {
	&"destroyed": &"range_target_destroyed",
	&"regenerated": &"range_target_regenerated",
}
const PRIORITIES := {
	&"range_target_component_impact": 58,
	&"range_target_frame_component_impact": 72,
	&"range_target_core_component_impact": 82,
	&"range_target_regenerated": 90,
	&"range_target_destroyed": 100,
}
const PREBUILT_VOICE_IDS := [
	&"range_target_component_voice",
	&"range_target_lifecycle_voice",
]

var _target: Node
var _attached := false
var _generation := 0
var _last_sequence := -1
var _slots: Array[Dictionary] = []
var _emitted_count := 0


func attach(target: Node, generation: int) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if target == null or not is_instance_valid(target) or generation <= 0:
		return _result(false, &"invalid_target")
	_target = target
	_attached = true
	_generation = generation
	_last_sequence = -1
	_slots.clear()
	return _result(true, &"attached")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_target = null
	_attached = false
	_generation += 1
	_last_sequence = -1
	_slots.clear()
	return _result(true, &"detached")


func reset_for_reuse(previous_generation: int, generation: int) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if previous_generation != _generation or generation != _generation + 1:
		return _result(false, &"stale_generation")
	_generation = generation
	_last_sequence = -1
	_slots.clear()
	return _result(true, &"reset")


func present_component_receipt(
	component_id: StringName,
	generation: int,
	sequence: int,
	intensity: float
) -> Dictionary:
	return _present_receipt(
		COMPONENT_CUES.get(component_id, GENERIC_COMPONENT_CUE),
		generation,
		sequence,
		intensity,
		component_id
	)


func present_lifecycle_receipt(
	receipt_id: StringName,
	generation: int,
	sequence: int,
	intensity: float = 1.0
) -> Dictionary:
	if not RECEIPT_CUES.has(receipt_id):
		return _result(false, &"unknown_lifecycle_receipt")
	return _present_receipt(
		RECEIPT_CUES[receipt_id], generation, sequence, intensity, receipt_id
	)


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_sequence": _last_sequence,
		"emitted_cue_count": _emitted_count,
		"active_cue_slots": _slots.duplicate(true),
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"prebuilt_voice_ids": PREBUILT_VOICE_IDS.duplicate(),
		"authority": {
			"damage": false,
			"destruction": false,
			"mission": false,
			"reward": false,
			"regeneration": false,
			"audio_cues": true,
		},
	}.duplicate(true)


func _present_receipt(
	cue_id: StringName,
	generation: int,
	sequence: int,
	intensity: float,
	receipt_subject: StringName
) -> Dictionary:
	if not _attached or not is_instance_valid(_target):
		return _result(false, &"not_attached")
	if generation != _generation:
		return _result(false, &"stale_generation")
	if sequence < 0 or sequence > MAX_SAFE_SEQUENCE:
		return _result(false, &"invalid_sequence")
	if sequence <= _last_sequence:
		return _result(false, &"duplicate_or_stale_sequence")
	if not is_finite(intensity):
		return _result(false, &"invalid_intensity")
	_last_sequence = sequence
	var safe_intensity := clampf(intensity, 0.0, 1.0)
	var voice_admitted := _admit(cue_id)
	_emitted_count += 1
	semantic_feedback_cue_emitted.emit(cue_id, safe_intensity, voice_admitted)
	# Captions remain readable when audible voices are saturated.
	semantic_cue_emitted.emit(
		_source_id(), cue_id, safe_intensity, _world_position()
	)
	var result := _result(
		true,
		&"cue_presented" if voice_admitted else &"semantic_cue_presented"
	)
	result["cue_id"] = cue_id
	result["receipt_subject"] = receipt_subject
	result["sequence"] = sequence
	result["voice_admitted"] = voice_admitted
	return result.duplicate(true)


func _admit(cue_id: StringName) -> bool:
	var priority := int(PRIORITIES.get(cue_id, 0))
	if _slots.size() < MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.append({"cue_id": cue_id, "priority": priority})
		return true
	var lowest := 0
	for index in range(1, _slots.size()):
		if int(_slots[index].priority) < int(_slots[lowest].priority):
			lowest = index
	if priority < int(_slots[lowest].priority):
		return false
	_slots[lowest] = {"cue_id": cue_id, "priority": priority}
	return true


func _source_id() -> StringName:
	if is_instance_valid(_target):
		var raw_id: Variant = _target.get_meta("target_id", &"")
		if raw_id is StringName and raw_id != &"":
			return raw_id as StringName
		if raw_id is String and not str(raw_id).is_empty():
			return StringName(raw_id as String)
	return &"range_target"


func _world_position() -> Vector3:
	if _target is Node3D:
		return _target.global_position if _target.is_inside_tree() else _target.position
	return Vector3.ZERO


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
	}.duplicate(true)
