class_name ShipBerthAudioBinding
extends RefCounted

## Presentation-only consumer for ShipBerthFeedback state transitions.
## Reservation, landing, movement, and occupancy authority remain upstream.

signal semantic_berth_cue_emitted(cue_id: StringName, berth_id: StringName, intensity: float)
signal semantic_cue_emitted(source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const CUE_OPEN_VECTOR: StringName = &"berth_open_vector"
const CUE_CAPTURE_SECURED: StringName = &"berth_capture_secured"
const CUE_RELEASE: StringName = &"berth_release"
const CUE_PRIORITIES := {
	CUE_OPEN_VECTOR: 30,
	CUE_CAPTURE_SECURED: 90,
	CUE_RELEASE: 70,
}
# These are stable authored voice identities. The binding never allocates or
# loads a player on the transition path; the production audio owner resolves
# these IDs to its prebuilt voice/resources.
const PREBUILT_VOICE_IDS := [&"berth_vector_voice", &"berth_secure_voice"]

var _feedback: Node
var _attached := false
var _generation := 0
var _last_state: StringName = &""
var _berth_id: StringName = &""
var _slots: Array[Dictionary] = []
var _seen_transitions: Dictionary = {}
var _emitted_count := 0

func attach(feedback: Node) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if feedback == null or not is_instance_valid(feedback) \
			or not feedback.has_signal(&"state_changed") \
			or not feedback.has_method(&"get_feedback_state") \
			or not feedback.has_method(&"get_state_snapshot"):
		return _result(false, &"invalid_feedback")
	_feedback = feedback
	_attached = true
	_last_state = StringName(feedback.call(&"get_feedback_state"))
	var snapshot := feedback.call(&"get_state_snapshot") as Dictionary
	_berth_id = StringName(snapshot.get("berth_id", &""))
	_slots.clear()
	_seen_transitions.clear()
	var callback := Callable(self, "_on_feedback_state_changed")
	if not feedback.is_connected(&"state_changed", callback):
		feedback.connect(&"state_changed", callback)
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if is_instance_valid(_feedback):
		var callback := Callable(self, "_on_feedback_state_changed")
		if _feedback.is_connected(&"state_changed", callback):
			_feedback.disconnect(&"state_changed", callback)
	_feedback = null
	_attached = false
	_last_state = &""
	_berth_id = &""
	_slots.clear()
	_seen_transitions.clear()
	_generation += 1
	return _result(true, &"detached")

func present_state(state: StringName) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if state not in [&"released", &"approach", &"occupied"]:
		return _result(false, &"invalid_state")
	if state == _last_state:
		return _result(false, &"duplicate_state")
	var key := "%d:%s" % [_generation, String(state)]
	if _seen_transitions.has(key):
		return _result(false, &"duplicate_transition")
	_seen_transitions[key] = true
	var cue_id: StringName = _cue_for_transition(_last_state, state)
	_last_state = state
	if cue_id.is_empty():
		return _result(true, &"state_recorded")
	if not _admit(cue_id):
		return _result(false, &"voice_budget_rejected")
	_emitted_count += 1
	semantic_berth_cue_emitted.emit(cue_id, _berth_id, 1.0)
	semantic_cue_emitted.emit(&"station_berth", cue_id, 1.0, _world_position())
	return _result(true, &"cue_presented")

func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"berth_id": _berth_id,
		"last_state": _last_state,
		"emitted_cue_count": _emitted_count,
		"active_cue_slots": _slots.duplicate(true),
		"prebuilt_voice_ids": PREBUILT_VOICE_IDS.duplicate(),
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"lease": false, "landing": false, "movement": false, "audio_cues": true},
	}.duplicate(true)

func _on_feedback_state_changed(state: StringName) -> void:
	present_state(state)

func _cue_for_transition(previous: StringName, next: StringName) -> StringName:
	if next == &"approach" and previous == &"released":
		return CUE_OPEN_VECTOR
	if next == &"occupied" and previous == &"approach":
		return CUE_CAPTURE_SECURED
	if next == &"released" and previous in [&"approach", &"occupied"]:
		return CUE_RELEASE
	return &""

func _admit(cue_id: StringName) -> bool:
	var priority := int(CUE_PRIORITIES.get(cue_id, 0))
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

func _world_position() -> Vector3:
	return _feedback.global_position if _feedback is Node3D else Vector3.ZERO

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
