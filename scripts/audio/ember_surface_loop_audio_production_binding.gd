class_name EmberSurfaceLoopAudioProductionBinding
extends Node

## Presentation-only consumer for detached Ember surface-loop snapshots.
## Host, travel session, movement, landing, reward, and playback authority stay
## with the injected owner.

signal semantic_surface_cue_emitted(cue_id: StringName, intensity: float)

const PHASE_CUES := {
	&"descent": &"ember_surface_descent",
	&"landed": &"ember_surface_landed",
	&"on_foot": &"ember_surface_on_foot",
	&"reboarded": &"ember_surface_reboard",
	&"takeoff": &"ember_surface_takeoff",
	&"ascent": &"ember_surface_ascent",
	&"orbit_return": &"ember_surface_orbit_return",
	&"failed": &"ember_surface_abort",
}
const PRODUCTION_STATE_ALIASES := {
	&"start_pending": &"descent",
	&"running": &"descent",
	&"handoff_pending": &"orbit_return",
}
const PERSPECTIVES := [&"interior", &"exterior"]
const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

var _owner: Node
var _attached := false
var _generation := 0
var _last_owner_generation := -1
var _last_key := ""
var _perspective: StringName = &"exterior"
var _seen: Dictionary = {}
var _slots: Array[StringName] = []
var _emitted_count := 0

func attach(owner: Node, perspective: StringName = &"exterior") -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if owner == null or not is_instance_valid(owner) or not owner.has_method(&"get_snapshot"):
		return _result(false, &"owner_contract_missing")
	if perspective not in PERSPECTIVES:
		return _result(false, &"invalid_perspective")
	_owner = owner
	_perspective = perspective
	if owner.has_signal(&"state_changed"):
		owner.connect(&"state_changed", _on_owner_snapshot)
	_attached = true
	_seen.clear()
	_slots.clear()
	_last_owner_generation = -1
	_last_key = ""
	present_snapshot(owner.get_snapshot())
	return _result(true, &"attached")

func set_perspective(perspective: StringName) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if perspective not in PERSPECTIVES:
		return _result(false, &"invalid_perspective")
	_perspective = perspective
	return _result(true, &"perspective_updated")

func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var owner_generation: Variant = snapshot.get("generation", -1)
	if not owner_generation is int or int(owner_generation) < 0 \
			or int(owner_generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	if int(owner_generation) < _last_owner_generation:
		return _result(false, &"stale_generation")
	var phase_id := StringName(snapshot.get("phase_id", snapshot.get("state_id", &"")))
	if _owner != null and _owner.has_method(&"get_host_phase"):
		var host_phase := int(_owner.get_host_phase())
		phase_id = _host_phase_id(host_phase) if host_phase >= 0 else phase_id
	phase_id = StringName(PRODUCTION_STATE_ALIASES.get(phase_id, phase_id))
	if phase_id.is_empty():
		return _result(false, &"invalid_phase")
	var terminal_reason := StringName(snapshot.get("terminal_reason", &""))
	if not terminal_reason.is_empty() and phase_id not in PHASE_CUES:
		phase_id = &"failed"
	var cue: StringName = PHASE_CUES.get(phase_id, &"")
	if cue.is_empty():
		_last_owner_generation = int(owner_generation)
		return _result(true, &"snapshot_accepted")
	var key := "%d:%s:%s" % [int(owner_generation), phase_id, _perspective]
	if _seen.has(key):
		return _result(true, &"duplicate_snapshot")
	_seen[key] = true
	_last_owner_generation = int(owner_generation)
	_last_key = key
	var perspective_cue := StringName("%s_%s" % [String(cue), String(_perspective)])
	_emit(perspective_cue)
	return _result(true, &"snapshot_presented")

func detach() -> Dictionary:
	if not _attached:
		return _result(true, &"already_detached")
	if is_instance_valid(_owner) and _owner.is_connected(&"state_changed", _on_owner_snapshot):
		_owner.disconnect(&"state_changed", _on_owner_snapshot)
	_owner = null
	_attached = false
	_generation += 1
	_last_owner_generation = -1
	_last_key = ""
	_seen.clear()
	_slots.clear()
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "perspective": _perspective,
		"last_owner_generation": _last_owner_generation, "last_key": _last_key,
		"emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(),
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"host": false, "travel": false, "movement": false, "landing": false, "audio_cues": true}}.duplicate(true)

func _on_owner_snapshot(snapshot: Dictionary) -> void:
	present_snapshot(snapshot)

func _host_phase_id(host_phase: int) -> StringName:
	match host_phase:
		2: return &"descent"
		5: return &"landed"
		8: return &"on_foot"
		10: return &"reboarded"
		11: return &"takeoff"
		12: return &"ascent"
		13: return &"orbit_return"
		15: return &"failed"
		_: return &""

func _emit(cue_id: StringName) -> void:
	if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.pop_front()
	_slots.append(cue_id)
	_emitted_count += 1
	semantic_surface_cue_emitted.emit(cue_id, 1.0)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)

func _exit_tree() -> void:
	detach()
