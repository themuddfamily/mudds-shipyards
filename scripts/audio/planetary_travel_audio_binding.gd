class_name PlanetaryTravelAudioBinding
extends RefCounted

## Presentation-only consumer for detached PlanetaryTravelSession snapshots.
## Travel, landing, and return authority remain with the session owner.

signal semantic_travel_cue_emitted(cue_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const CUE_BY_STATE := {
	&"orbit_approach": &"planetary_orbit_approach",
	&"atmospheric_entry": &"planetary_atmospheric_entry",
	&"landed": &"planetary_landed",
	&"takeoff": &"planetary_takeoff",
	&"ascent": &"planetary_ascent",
	&"orbit_return": &"planetary_orbit_return",
	&"completed": &"planetary_returned_to_station",
}
const CUE_PRIORITIES := {
	&"planetary_orbit_approach": 30,
	&"planetary_atmospheric_entry": 40,
	&"planetary_landed": 70,
	&"planetary_takeoff": 50,
	&"planetary_ascent": 50,
	&"planetary_orbit_return": 60,
	&"planetary_returned_to_station": 100,
}

var _session: Object
var _attached := false
var _generation := 0
var _last_session_generation := -1
var _last_state_id: StringName = &""
var _active_slots: Array[Dictionary] = []
var _emitted_cue_count := 0
var _preempted_cue_count := 0
var _last_cue_id: StringName = &""
var _reduced_dynamic_range := false

func attach(session: Object = null) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if session != null:
		if not is_instance_valid(session) or not session.has_signal(&"presentation_changed") \
				or not session.has_method(&"get_presentation_snapshot"):
			return _result(false, &"invalid_travel_session")
		_session = session
		var callback := Callable(self, "_on_session_snapshot")
		if not session.is_connected(&"presentation_changed", callback):
			session.connect(&"presentation_changed", callback)
	_attached = true
	_last_session_generation = -1
	_last_state_id = &""
	_active_slots.clear()
	if _session != null:
		present_snapshot(_session.call(&"get_presentation_snapshot"))
	return _result(true, &"attached")

func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	return _result(true, &"mix_updated")

func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var generation: Variant = snapshot.get("generation", -1)
	var state_id: Variant = snapshot.get("state_id", &"")
	if not generation is int or int(generation) < 0 or int(generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	if not state_id is StringName or (state_id as StringName).is_empty():
		return _result(false, &"invalid_state")
	if int(generation) < _last_session_generation:
		return _result(false, &"stale_generation")
	if int(generation) == _last_session_generation and state_id == _last_state_id:
		return _result(false, &"duplicate_state")
	_last_session_generation = int(generation)
	if CUE_BY_STATE.has(state_id as StringName):
		var cue_id: StringName = CUE_BY_STATE[state_id]
		if not _admit(cue_id):
			return _result(false, &"voice_budget_rejected")
		var intensity := 0.75 if _reduced_dynamic_range else 1.0
		_emitted_cue_count += 1
		_last_cue_id = cue_id
		semantic_travel_cue_emitted.emit(cue_id, intensity)
	_last_state_id = state_id
	return _result(true, &"snapshot_presented")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if _session != null and is_instance_valid(_session):
		var callback := Callable(self, "_on_session_snapshot")
		if _session.is_connected(&"presentation_changed", callback):
			_session.disconnect(&"presentation_changed", callback)
	_session = null
	_attached = false
	_active_slots.clear()
	_last_state_id = &""
	_last_session_generation = -1
	_generation += 1
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "last_session_generation": _last_session_generation, "last_state_id": _last_state_id, "last_cue_id": _last_cue_id, "emitted_cue_count": _emitted_cue_count, "preempted_cue_count": _preempted_cue_count, "active_cue_slots": _active_slots.duplicate(true), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES, "reduced_dynamic_range": _reduced_dynamic_range, "authority": {"travel": false, "landing": false, "movement": false, "audio_cues": true}}.duplicate(true)

func _on_session_snapshot(snapshot: Dictionary) -> void:
	present_snapshot(snapshot)

func _admit(cue_id: StringName) -> bool:
	var priority := int(CUE_PRIORITIES.get(cue_id, 0))
	if _active_slots.size() < MAXIMUM_SIMULTANEOUS_VOICES:
		_active_slots.append({"cue_id": cue_id, "priority": priority})
		return true
	var lowest := 0
	for index in range(1, _active_slots.size()):
		if int(_active_slots[index].priority) < int(_active_slots[lowest].priority):
			lowest = index
	if priority < int(_active_slots[lowest].priority):
		return false
	_active_slots[lowest] = {"cue_id": cue_id, "priority": priority}
	_preempted_cue_count += 1
	return true

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
