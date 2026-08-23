class_name CinderCargoTerminalAudioBinding
extends RefCounted

## Presentation-only consumer for detached cargo-terminal state. Terminal,
## inventory, interaction, and reward authority remain caller-owned.

signal semantic_terminal_cue_emitted(cue_id: StringName, terminal_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const STATES := [&"unavailable", &"ready", &"carrying", &"at_terminal", &"committed", &"stale_rejected", &"reset"]
const CUES := {
	&"unavailable": &"cargo_terminal_berth_required", &"ready": &"cargo_terminal_ready",
	&"carrying": &"cargo_terminal_carrying", &"at_terminal": &"cargo_terminal_submit_ready",
	&"committed": &"cargo_terminal_committed", &"stale_rejected": &"cargo_terminal_rejected",
	&"reset": &"cargo_terminal_reset",
}

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
	_last_states.clear(); _seen.clear(); _slots.clear()
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false; _generation += 1
	_last_states.clear(); _seen.clear(); _slots.clear()
	return _result(true, &"detached")

func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var terminal_id := StringName(snapshot.get("terminal_id", &""))
	var state := StringName(snapshot.get("state_id", &""))
	var generation := int(snapshot.get("terminal_generation", -1))
	if terminal_id.is_empty() or state not in STATES or generation < 0:
		return _result(false, &"invalid_snapshot")
	var previous := StringName(_last_states.get(terminal_id, &""))
	if state == previous:
		return _result(true, &"duplicate_state")
	var cue: StringName = CUES[state]
	var key := "%s:%d:%s" % [terminal_id, generation, state]
	if not _seen.has(key):
		_seen[key] = true
		if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
			_slots.pop_front()
		_slots.append(cue)
		_emitted_count += 1
		semantic_terminal_cue_emitted.emit(cue, terminal_id, 1.0)
	_last_states[terminal_id] = state
	return _result(true, &"snapshot_presented")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "last_states": _last_states.duplicate(true), "emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES, "authority": {"terminal": false, "inventory": false, "interaction": false, "reward": false, "audio_cues": true}}.duplicate(true)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
