class_name SettlementInteractionAudioBinding
extends RefCounted

## Presentation-only consumer for exact settlement interaction receipts.
## Interaction, door, activity, and objective authority remain upstream.

signal semantic_settlement_cue_emitted(cue_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const EVENT_CUES := {&"success": &"settlement_interaction_success", &"denied": &"settlement_interaction_denied", &"reset": &"settlement_interaction_reset"}
const KIND_LABELS := {&"door": &"door", &"terminal": &"terminal", &"airlock": &"airlock"}
const PRIORITY := {&"settlement_interaction_success": 60, &"settlement_interaction_denied": 80, &"settlement_interaction_reset": 30}

var _attached := false
var _generation := 0
var _last_source_generation := -1
var _seen: Dictionary = {}
var _slots: Array[Dictionary] = []
var _reduced_dynamic_range := false
var _perspective: StringName = &"exterior"
var _emitted_count := 0

func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_seen.clear()
	_slots.clear()
	_last_source_generation = -1
	return _result(true, &"attached")

func set_perspective(perspective: StringName) -> Dictionary:
	if perspective not in [&"cockpit", &"exterior"]:
		return _result(false, &"invalid_perspective")
	_perspective = perspective
	return _result(true, &"perspective_updated")

func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	return _result(true, &"mix_updated")

func present_receipt(receipt: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var runtime := receipt.get("runtime", {}) as Dictionary
	var generation: Variant = receipt.get("generation", runtime.get("attachment_generation", -1))
	var event_id: Variant = receipt.get("event_id", &"")
	var kind: Variant = receipt.get("interaction_kind", &"")
	var accepted: Variant = receipt.get("accepted", false)
	var interaction_id: Variant = receipt.get("interaction_id", &"")
	if not generation is int or int(generation) < 0 or int(generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	if not event_id is StringName or not EVENT_CUES.has(event_id as StringName) or kind not in KIND_LABELS or accepted is not bool:
		return _result(false, &"invalid_interaction_receipt")
	if not interaction_id is StringName or (interaction_id as StringName).is_empty():
		return _result(false, &"invalid_interaction_id")
	if int(generation) < _last_source_generation:
		return _result(false, &"stale_generation")
	var key := "%d:%s:%s" % [int(generation), String(interaction_id), String(event_id)]
	if _seen.has(key):
		return _result(false, &"duplicate_receipt")
	_seen[key] = true
	_last_source_generation = int(generation)
	var cue_id: StringName = EVENT_CUES[event_id]
	if not _admit(cue_id):
		return _result(false, &"voice_budget_rejected")
	var intensity := 0.65 if event_id == &"denied" else 1.0
	if _perspective == &"cockpit": intensity *= 0.7
	if _reduced_dynamic_range: intensity *= 0.75
	_emitted_count += 1
	semantic_settlement_cue_emitted.emit(StringName("settlement_%s_%s" % [String(kind), String(cue_id)]), clampf(intensity, 0.0, 1.0))
	return _result(true, &"cue_presented")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_seen.clear()
	_slots.clear()
	_last_source_generation = -1
	_generation += 1
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "last_source_generation": _last_source_generation, "emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(true), "perspective": _perspective, "reduced_dynamic_range": _reduced_dynamic_range, "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES, "authority": {"interaction": false, "doors": false, "activity": false, "objective": false, "audio": true}}.duplicate(true)

func _admit(cue_id: StringName) -> bool:
	var priority := int(PRIORITY.get(cue_id, 0))
	if _slots.size() < MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.append({"cue_id": cue_id, "priority": priority})
		return true
	var lowest := 0
	for index in range(1, _slots.size()):
		if int(_slots[index].priority) < int(_slots[lowest].priority): lowest = index
	_slots[lowest] = {"cue_id": cue_id, "priority": priority}
	return true

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
