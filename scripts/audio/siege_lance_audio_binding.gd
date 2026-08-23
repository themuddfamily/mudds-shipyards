class_name SiegeLanceAudioBinding
extends RefCounted

## Presentation-only consumer for exact siege-lance weapon records.
## Fire, damage, target, and resolver authority remain upstream.

signal semantic_weapon_cue_emitted(cue_id: StringName, transaction_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const WEAPON_ID: StringName = &"picket_siege_lance"
const CUE_BY_EVENT := {
	&"charge_started": &"siege_lance_charge",
	&"dispatch": &"siege_lance_dispatch",
	&"impact": &"siege_lance_impact",
	&"aborted": &"siege_lance_abort",
}
const PRIORITY := {
	&"siege_lance_charge": 20,
	&"siege_lance_dispatch": 50,
	&"siege_lance_impact": 90,
	&"siege_lance_abort": 70,
}

var _attached := false
var _generation := 0
var _seen: Dictionary = {}
var _slots: Array[Dictionary] = []
var _reduced_dynamic_range := false
var _emitted_count := 0
var _last_cue: StringName = &""
var _source: Object

func attach(source: Object = null, expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	if source != null:
		if not is_instance_valid(source) or not source.has_signal(&"siege_lance_audio_record"):
			_attached = false
			return _result(false, &"invalid_weapon_source")
		_source = source
		var callback := Callable(self, "_on_weapon_record")
		if not source.is_connected(&"siege_lance_audio_record", callback):
			source.connect(&"siege_lance_audio_record", callback)
	_seen.clear()
	_slots.clear()
	return _result(true, &"attached")

func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	return _result(true, &"mix_updated")

func present_record(record: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var generation: Variant = record.get("generation", -1)
	var sequence: Variant = record.get("sequence", -1)
	var transaction_id: Variant = record.get("transaction_id", &"")
	var event_id: Variant = record.get("event_id", &"")
	var weapon_id: Variant = record.get("weapon_id", &"")
	var accepted: Variant = record.get("accepted", false)
	if not generation is int or int(generation) != _generation:
		return _result(false, &"stale_generation")
	if not sequence is int or int(sequence) < 0:
		return _result(false, &"invalid_sequence")
	if not transaction_id is StringName or (transaction_id as StringName).is_empty():
		return _result(false, &"invalid_transaction_id")
	if not event_id is StringName or not CUE_BY_EVENT.has(event_id as StringName):
		return _result(false, &"invalid_event_id")
	if weapon_id != WEAPON_ID or accepted is not bool or not accepted:
		return _result(false, &"invalid_weapon_record")
	var key := "%d:%s:%s" % [_generation, String(transaction_id), String(event_id)]
	if _seen.has(key):
		return _result(false, &"duplicate_record")
	_seen[key] = true
	var cue_id: StringName = CUE_BY_EVENT[event_id]
	if not _admit(cue_id, transaction_id):
		return _result(false, &"voice_budget_rejected")
	var intensity := 0.75 if _reduced_dynamic_range else 1.0
	_emitted_count += 1
	_last_cue = cue_id
	semantic_weapon_cue_emitted.emit(cue_id, transaction_id, intensity)
	return _result(true, &"cue_presented")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	if _source != null and is_instance_valid(_source):
		var callback := Callable(self, "_on_weapon_record")
		if _source.is_connected(&"siege_lance_audio_record", callback):
			_source.disconnect(&"siege_lance_audio_record", callback)
	_source = null
	_seen.clear()
	_slots.clear()
	_generation += 1
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "emitted_cue_count": _emitted_count, "last_cue_id": _last_cue, "active_cue_slots": _slots.duplicate(true), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES, "reduced_dynamic_range": _reduced_dynamic_range, "authority": {"fire": false, "damage": false, "target": false, "audio_cues": true}}.duplicate(true)

func _admit(cue_id: StringName, transaction_id: StringName) -> bool:
	var priority := int(PRIORITY.get(cue_id, 0))
	if _slots.size() < MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.append({"cue_id": cue_id, "transaction_id": transaction_id, "priority": priority})
		return true
	var lowest := 0
	for index in range(1, _slots.size()):
		if int(_slots[index].priority) < int(_slots[lowest].priority):
			lowest = index
	if priority < int(_slots[lowest].priority):
		return false
	_slots[lowest] = {"cue_id": cue_id, "transaction_id": transaction_id, "priority": priority}
	return true

func _on_weapon_record(record: Dictionary) -> void:
	present_record(record)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
