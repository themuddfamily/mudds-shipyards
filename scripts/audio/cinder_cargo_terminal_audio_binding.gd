class_name CinderCargoTerminalAudioBinding
extends RefCounted

## Presentation-only consumer for detached cargo-terminal state. Terminal,
## inventory, interaction, and reward authority remain caller-owned.

signal semantic_terminal_cue_emitted(cue_id: StringName, terminal_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
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
var _latest_activity_generations: Dictionary = {}
var _slots: Array[StringName] = []
var _emitted_count := 0

func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_last_states.clear(); _clear_active_cues()
	return _result(true, &"attached")

func detach() -> Dictionary:
	# Always silence terminal presentation first. A failed or exhausted detach
	# must not leave an audible slot alive for a later physical re-entry.
	_clear_active_cues()
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_last_states.clear()
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	_generation += 1
	return _result(true, &"detached")

func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var decoded := _decode_snapshot(snapshot)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_snapshot")))
	var terminal_id: StringName = decoded.terminal_id
	var state: StringName = decoded.state
	var terminal_generation: int = decoded.terminal_generation
	var activity_generation: int = decoded.activity_generation
	var latest_key := "%s:%d" % [terminal_id, terminal_generation]
	var latest_activity_generation := int(_latest_activity_generations.get(latest_key, -1))
	if activity_generation < latest_activity_generation:
		return _result(false, &"stale_activity_generation")
	if activity_generation > latest_activity_generation:
		_prune_prior_activity_cues(terminal_id, terminal_generation)
		_latest_activity_generations[latest_key] = activity_generation
	var key := "%s:%d:%d:%s" % [terminal_id, terminal_generation, activity_generation, state]
	if StringName(_last_states.get(terminal_id, &"")) == StringName(key):
		return _result(true, &"duplicate_state")
	var cue: StringName = CUES[state]
	if not _seen.has(key):
		_seen[key] = true
		if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
			_slots.pop_front()
		_slots.append(cue)
		_emitted_count += 1
		semantic_terminal_cue_emitted.emit(cue, terminal_id, 1.0)
	# Keep exact terminal/source-generation cues across detach. A retained
	# completed receipt then remains silent after re-entry, while the next cargo
	# activity generation receives its normal reset or ready restart cue.
	_last_states[terminal_id] = StringName(key)
	return _result(true, &"snapshot_presented")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "last_states": _last_states.duplicate(true), "latest_activity_generations": _latest_activity_generations.duplicate(true), "retained_cue_history_size": _seen.size(), "emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES, "authority": {"terminal": false, "inventory": false, "interaction": false, "reward": false, "audio_cues": true}}.duplicate(true)

func _decode_snapshot(snapshot: Dictionary) -> Dictionary:
	var terminal_id: Variant = snapshot.get("terminal_id", &"")
	var state: Variant = snapshot.get("state_id", &"")
	var terminal_generation: Variant = snapshot.get("terminal_generation", -1)
	var activity := snapshot.get("activity", {}) as Dictionary
	var activity_generation: Variant = activity.get("generation", 0)
	if not terminal_id is StringName or (terminal_id as StringName).is_empty():
		return _result(false, &"invalid_snapshot")
	if not state is StringName or state not in STATES:
		return _result(false, &"invalid_snapshot")
	if not terminal_generation is int or int(terminal_generation) < 0:
		return _result(false, &"invalid_snapshot")
	if not activity_generation is int or int(activity_generation) < 0:
		return _result(false, &"invalid_snapshot")
	return {"accepted": true, "terminal_id": terminal_id, "state": state, "terminal_generation": int(terminal_generation), "activity_generation": int(activity_generation)}

func _clear_active_cues() -> void:
	_slots.clear()

func _prune_prior_activity_cues(terminal_id: StringName, terminal_generation: int) -> void:
	var prefix := "%s:%d:" % [terminal_id, terminal_generation]
	for seen_key in _seen.keys():
		if String(seen_key).begins_with(prefix):
			_seen.erase(seen_key)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
