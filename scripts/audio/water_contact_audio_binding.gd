class_name WaterContactAudioBinding
extends RefCounted

## Presentation-only consumer for exact PlanetaryWaterContactRuntime receipts.
## Physics, buoyancy, movement, and recovery remain caller-owned.

signal semantic_water_cue_emitted(cue_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const CUES := {&"enter": &"water_splash_enter", &"sample": &"water_wake_drag", &"exit": &"water_dry_exit"}
const PRIORITY := {&"water_splash_enter": 70, &"water_wake_drag": 20, &"water_dry_exit": 80}

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
	var accepted: Variant = receipt.get("accepted", false)
	if not generation is int or int(generation) < 0 or int(generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	if not event_id is StringName or not CUES.has(event_id as StringName) or accepted is not bool or not accepted:
		return _result(false, &"invalid_contact_receipt")
	if int(generation) < _last_source_generation:
		return _result(false, &"stale_generation")
	var sequence := int(receipt.get("sequence", 0))
	var key := "%d:%d:%s" % [int(generation), sequence, String(event_id)]
	if _seen.has(key):
		return _result(false, &"duplicate_receipt")
	_seen[key] = true
	_last_source_generation = int(generation)
	var cue_id: StringName = CUES[event_id]
	var intensity := _intensity_for(event_id, receipt)
	if not _admit(cue_id):
		return _result(false, &"voice_budget_rejected")
	_emitted_count += 1
	semantic_water_cue_emitted.emit(cue_id, intensity)
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
	return {"attached": _attached, "generation": _generation, "last_source_generation": _last_source_generation, "emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(true), "perspective": _perspective, "reduced_dynamic_range": _reduced_dynamic_range, "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES, "authority": {"physics": false, "buoyancy": false, "movement": false, "recovery": false, "audio": true}}.duplicate(true)

func _intensity_for(event_id: StringName, receipt: Dictionary) -> float:
	var value := 1.0
	if event_id == &"sample":
		var drag: Variant = (receipt.get("drag_request", {}) as Dictionary).get("unitless", 0.0)
		value = clampf(float(drag), 0.0, 1.0)
	if _perspective == &"cockpit":
		value *= 0.65
	if _reduced_dynamic_range:
		value *= 0.75
	return clampf(value, 0.0, 1.0)

func _admit(cue_id: StringName) -> bool:
	var priority := int(PRIORITY.get(cue_id, 0))
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

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
