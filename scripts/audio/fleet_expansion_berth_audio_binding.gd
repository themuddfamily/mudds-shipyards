class_name FleetExpansionBerthAudioBinding
extends RefCounted

## Presentation-only berth cues for the three expanded fleet pads. Lease and
## landing authority remain with FleetExpansionBerths.

signal semantic_berth_cue_emitted(cue_id: StringName, pad_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const PAD_IDS := [&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"]

var _attached := false
var _generation := 0
var _last_states: Dictionary = {}
var _seen: Dictionary = {}
var _slots: Array[StringName] = []
var _emitted_count := 0

func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_last_states.clear()
	_seen.clear()
	_slots.clear()
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_last_states.clear()
	_seen.clear()
	_slots.clear()
	return _result(true, &"detached")

func present_pad_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var pad_id := StringName(snapshot.get("pad_id", &""))
	if not PAD_IDS.has(pad_id):
		return _result(false, &"foreign_pad")
	var state := StringName(snapshot.get("lease_state_id", &"available"))
	if state not in [&"available", &"occupied"]:
		return _result(false, &"invalid_state")
	var previous := StringName(_last_states.get(pad_id, &""))
	if previous == state:
		return _result(true, &"duplicate_state")
	var craft_id := StringName(snapshot.get("craft_id", pad_id))
	var cue := &"fleet_berth_approach" if state == &"available" else &"fleet_berth_secured"
	_emit(cue, pad_id, "%s:%s:%s" % [pad_id, craft_id, state])
	_last_states[pad_id] = state
	return _result(true, &"state_presented")

func present_release(pad_id: StringName, generation: int) -> Dictionary:
	if not _attached or not PAD_IDS.has(pad_id):
		return _result(false, &"invalid_pad")
	_emit(&"fleet_berth_released", pad_id, "%s:%d:released" % [pad_id, generation])
	_last_states[pad_id] = &"available"
	return _result(true, &"release_presented")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "last_states": _last_states.duplicate(true),
		"emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(),
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"lease": false, "landing": false, "movement": false, "audio_cues": true}}.duplicate(true)

func _emit(cue_id: StringName, pad_id: StringName, key: String) -> void:
	if _seen.has(key): return
	_seen[key] = true
	if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.pop_front()
	_slots.append(cue_id)
	_emitted_count += 1
	semantic_berth_cue_emitted.emit(cue_id, pad_id, 1.0)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
