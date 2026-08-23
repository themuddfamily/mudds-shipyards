class_name HalyardCrewSemanticAudioBinding
extends Node

const EngineerBindingScript := preload("res://scripts/audio/crew_engineer_audio_binding.gd")

## Audio-only presentation bridge for detached Halyard crew snapshots. Crew role,
## handoff, routing, and departure authority remain with the caller.

signal semantic_crew_cue_emitted(cue_id: StringName, role: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const CUE_PRIORITIES := {
	&"crew_role_joined": 30,
	&"crew_role_left": 30,
	&"crew_engineer_route_changed": 55,
	&"crew_departure_ready": 70,
	&"crew_emergency_pilot_handoff": 90,
	&"crew_engineer_repair_started": 60,
	&"crew_engineer_repair_progress": 20,
	&"crew_engineer_repair_interrupted": 80,
	&"crew_engineer_repair_completed": 100,
}
const CREW_ROLES := [&"pilot", &"gunner", &"engineer", &"passenger"]

var _attached := false
var _generation := 0
var _last_snapshot: Dictionary = {}
var _last_occupants: Dictionary = {}
var _last_route_fingerprint := ""
var _last_handoff_fingerprint := ""
var _last_departure_ready := false
var _active_cue_slots: Array[Dictionary] = []
var _emitted_cue_count := 0
var _preempted_cue_count := 0
var _last_preempted_cue: StringName = &""
var _engineer_binding: Node


func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_clear_state()
	if _engineer_binding == null:
		_engineer_binding = EngineerBindingScript.new()
		add_child(_engineer_binding)
		_engineer_binding.semantic_crew_cue_emitted.connect(_on_engineer_cue)
	var engineer_result: Dictionary = _engineer_binding.attach(expected_generation)
	if not bool(engineer_result.get("accepted", false)):
		return _result(false, &"engineer_binding_attach_failed")
	return _result(true, &"attached")


func present_crew_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var decoded := _decode_snapshot(snapshot)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_snapshot")))
	var engineer_snapshot: Variant = snapshot.get("engineer_repair", {})
	if not engineer_snapshot is Dictionary:
		return _result(false, &"invalid_engineer_repair")
	if not (engineer_snapshot as Dictionary).is_empty():
		var repair := (engineer_snapshot as Dictionary).duplicate(true)
		if not repair.has("generation"):
			repair["generation"] = _generation
		var engineer_result: Dictionary = _engineer_binding.present_repair_snapshot(repair)
		var engineer_reason: StringName = engineer_result.get("reason", &"")
		if not bool(engineer_result.get("accepted", false)) \
				and engineer_reason not in [&"duplicate_sequence", &"stale_sequence"]:
			return _result(false, &"invalid_engineer_repair")
	var occupants := decoded.occupants as Dictionary
	for actor_key: String in _last_occupants:
		if not occupants.has(actor_key):
			_emit_cue(&"crew_role_left", StringName(_last_occupants[actor_key]), 1.0)
	for actor_key: String in occupants:
		var role := StringName(occupants[actor_key])
		if not _last_occupants.has(actor_key):
			_emit_cue(&"crew_role_joined", role, 1.0)
	var route_fingerprint: String = decoded.route_fingerprint
	if route_fingerprint != _last_route_fingerprint and not route_fingerprint.is_empty():
		_emit_cue(&"crew_engineer_route_changed", &"engineer", 1.0)
	var departure_ready := bool(decoded.departure_ready)
	if departure_ready and not _last_departure_ready:
		_emit_cue(&"crew_departure_ready", &"pilot", 1.0)
	var handoff_fingerprint: String = decoded.handoff_fingerprint
	if not handoff_fingerprint.is_empty() and handoff_fingerprint != _last_handoff_fingerprint:
		_emit_cue(&"crew_emergency_pilot_handoff", &"pilot", 1.0)
	_last_occupants = occupants.duplicate(true)
	_last_route_fingerprint = route_fingerprint
	_last_handoff_fingerprint = handoff_fingerprint
	_last_departure_ready = departure_ready
	_last_snapshot = snapshot.duplicate(true)
	return _result(true, &"snapshot_presented")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	if _engineer_binding != null:
		_engineer_binding.detach()
	_clear_state()
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_snapshot": _last_snapshot.duplicate(true),
		"last_occupants": _last_occupants.duplicate(true),
		"last_route_fingerprint": _last_route_fingerprint,
		"last_handoff_fingerprint": _last_handoff_fingerprint,
		"last_departure_ready": _last_departure_ready,
		"active_cue_slots": _active_cue_slots.duplicate(true),
		"emitted_cue_count": _emitted_cue_count,
		"preempted_cue_count": _preempted_cue_count,
		"last_preempted_cue": _last_preempted_cue,
		"engineer_binding": _engineer_binding.get_snapshot() if _engineer_binding != null else {},
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"crew_roles": false, "handoff": false, "departure": false, "audio_cues": true},
	}.duplicate(true)


func _decode_snapshot(snapshot: Dictionary) -> Dictionary:
	var raw_occupants: Variant = snapshot.get("occupants", [])
	var readiness: Variant = snapshot.get("departure_readiness", {})
	var routing: Variant = snapshot.get("power_routing", {})
	var handoff: Variant = snapshot.get("emergency_pilot_handoff", {})
	if not raw_occupants is Array or not readiness is Dictionary \
			or not routing is Dictionary or not handoff is Dictionary:
		return _result(false, &"invalid_snapshot")
	var occupants := {}
	for occupant_variant in raw_occupants:
		if not occupant_variant is Dictionary:
			return _result(false, &"invalid_occupant")
		var occupant := occupant_variant as Dictionary
		var role: Variant = occupant.get("role", &"")
		var peer_id: Variant = occupant.get("occupant_peer_id", 0)
		var avatar_id: Variant = occupant.get("avatar_id", &"")
		if role is not StringName or not CREW_ROLES.has(role as StringName) \
				or not peer_id is int or int(peer_id) < 0 \
				or not avatar_id is StringName or (avatar_id as StringName).is_empty():
			return _result(false, &"invalid_occupant")
		occupants["%d:%s" % [int(peer_id), String(avatar_id)]] = role
	var engineer := routing.get("engineer", {}) as Dictionary
	var route_fingerprint := ""
	if not engineer.is_empty():
		route_fingerprint = "%s:%d" % [
		String(engineer.get("channel", &"none")),
		int(engineer.get("component_generation", 0)),
	]
	var handoff_fingerprint := ""
	if not handoff.is_empty():
		handoff_fingerprint = "%d:%d" % [
		int(handoff.get("authority_event_sequence", -1)),
		int(handoff.get("new_seat_generation", 0)),
	]
	return {
		"accepted": true,
		"occupants": occupants,
		"route_fingerprint": route_fingerprint,
		"handoff_fingerprint": handoff_fingerprint,
		"departure_ready": bool(readiness.get("ready", false)),
	}.duplicate(true)


func _emit_cue(cue_id: StringName, role: StringName, intensity: float) -> void:
	if not _admit_cue(cue_id, role):
		return
	_emitted_cue_count += 1
	semantic_crew_cue_emitted.emit(cue_id, role, clampf(intensity, 0.0, 1.0))


func _on_engineer_cue(cue_id: StringName, role: StringName, intensity: float) -> void:
	_emit_cue(cue_id, role, intensity)


func _admit_cue(cue_id: StringName, role: StringName) -> bool:
	if not CUE_PRIORITIES.has(cue_id):
		return true
	var priority := int(CUE_PRIORITIES[cue_id])
	if _active_cue_slots.size() < MAXIMUM_SIMULTANEOUS_VOICES:
		_active_cue_slots.append({"cue_id": cue_id, "role": role, "priority": priority})
		return true
	var lowest_index := 0
	for index in range(1, _active_cue_slots.size()):
		if int(_active_cue_slots[index].priority) < int(_active_cue_slots[lowest_index].priority):
			lowest_index = index
	if priority <= int(_active_cue_slots[lowest_index].priority):
		return false
	_last_preempted_cue = StringName(_active_cue_slots[lowest_index].cue_id)
	_preempted_cue_count += 1
	_active_cue_slots[lowest_index] = {"cue_id": cue_id, "role": role, "priority": priority}
	return true


func _clear_state() -> void:
	_last_snapshot.clear()
	_last_occupants.clear()
	_last_route_fingerprint = ""
	_last_handoff_fingerprint = ""
	_last_departure_ready = false
	_active_cue_slots.clear()
	_last_preempted_cue = &""


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}.duplicate(true)
