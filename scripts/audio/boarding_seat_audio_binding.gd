class_name BoardingSeatAudioBinding
extends RefCounted

## Presentation-only consumer for accepted boarding-seat transitions.
## Seat, boarding, lease, and player-control authority remain caller-owned.

signal semantic_boarding_cue_emitted(cue_id: StringName, seat_id: StringName, intensity: float)
signal semantic_cue_emitted(source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const CUES := {
	&"reserve": &"boarding_seat_reserved",
	&"boarding_start": &"boarding_started",
	&"seated": &"boarding_seated",
	&"controls_ready": &"boarding_controls_ready",
	&"disembark": &"boarding_disembark",
	&"release": &"boarding_release",
	&"rejected": &"boarding_rejected",
}
const PRIORITIES := {
	&"boarding_seat_reserved": 45,
	&"boarding_started": 55,
	&"boarding_seated": 80,
	&"boarding_controls_ready": 85,
	&"boarding_disembark": 88,
	&"boarding_release": 60,
	&"boarding_rejected": 90,
}
const PREBUILT_VOICE_IDS := [&"boarding_transition_voice", &"boarding_confirmation_voice"]

var _area: Node
var _attached := false
var _generation := 0
var _last_sequence := -1
var _next_sequence := 0
var _seat_id: StringName = &""
var _slots: Array[Dictionary] = []
var _seen: Dictionary = {}
var _perspective: StringName = &"exterior"
var _reduced_dynamic_range := false
var _emitted_count := 0

func attach(area: Node, seat_id: StringName = &"boarding_seat") -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if area == null or not is_instance_valid(area) or not area.has_signal(&"reservation_changed"):
		return _result(false, &"invalid_boarding_area")
	_area = area
	_seat_id = seat_id
	_attached = true
	_last_sequence = -1
	_next_sequence = 0
	_slots.clear()
	_seen.clear()
	var callback := Callable(self, "_on_reservation_changed")
	if not area.is_connected(&"reservation_changed", callback):
		area.connect(&"reservation_changed", callback)
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if is_instance_valid(_area):
		var callback := Callable(self, "_on_reservation_changed")
		if _area.is_connected(&"reservation_changed", callback):
			_area.disconnect(&"reservation_changed", callback)
	_area = null
	_attached = false
	_seat_id = &""
	_last_sequence = -1
	_next_sequence = 0
	_slots.clear()
	_seen.clear()
	_generation += 1
	return _result(true, &"detached")

func set_perspective(perspective: StringName) -> Dictionary:
	if perspective not in [&"cockpit", &"exterior"]:
		return _result(false, &"invalid_perspective")
	_perspective = perspective
	return _result(true, &"perspective_updated")

func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	return _result(true, &"mix_updated")

func present_event(event: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var event_id: Variant = event.get("event_id", &"")
	var event_generation: Variant = event.get("generation", _generation)
	var sequence: Variant = event.get("sequence", -1)
	if not event_id is StringName or not CUES.has(event_id as StringName) \
			or not event_generation is int or int(event_generation) != _generation \
			or not sequence is int or int(sequence) < 0 \
			or not bool(event.get("accepted", true)):
		return _result(false, &"invalid_or_stale_event")
	if int(sequence) <= _last_sequence or _seen.has(int(sequence)):
		return _result(false, &"duplicate_event")
	_seen[int(sequence)] = true
	_last_sequence = int(sequence)
	var cue_id: StringName = CUES[event_id]
	if not _admit(cue_id):
		return _result(false, &"voice_budget_rejected")
	_emitted_count += 1
	var intensity := _intensity(float(event.get("intensity", 1.0)))
	semantic_boarding_cue_emitted.emit(cue_id, _seat_id, intensity)
	semantic_cue_emitted.emit(&"boarding", cue_id, intensity, _world_position())
	return _result(true, &"cue_presented")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "seat_id": _seat_id, "last_sequence": _last_sequence, "emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(true), "prebuilt_voice_ids": PREBUILT_VOICE_IDS.duplicate(), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES, "perspective": _perspective, "reduced_dynamic_range": _reduced_dynamic_range, "authority": {"boarding": false, "seat": false, "lease": false, "controls": false, "audio_cues": true}}.duplicate(true)

func _on_reservation_changed(reserved: bool, _token: Variant) -> void:
	if reserved:
		_present_internal(&"reserve")
		_present_internal(&"boarding_start")
	else:
		_present_internal(&"release")

func _present_internal(event_id: StringName) -> void:
	present_event({"event_id": event_id, "generation": _generation, "sequence": _next_sequence, "accepted": true})
	_next_sequence += 1

func _intensity(value: float) -> float:
	var adjusted := clampf(value, 0.0, 1.0)
	if _perspective == &"cockpit":
		adjusted *= 0.75
	if _reduced_dynamic_range:
		adjusted *= 0.75
	return clampf(adjusted, 0.0, 1.0)

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

func _world_position() -> Vector3:
	return _area.global_position if _area is Node3D else Vector3.ZERO

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
