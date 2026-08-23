class_name HeavyBreachActivityBoardAudioBinding
extends RefCounted

## Presentation-only consumer for the physical heavy-breach activity board.
## Admission, objective, combat, and reward authority remain caller-owned.

signal semantic_board_cue_emitted(cue_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2

var _attached := false
var _generation := 0
var _seen: Dictionary = {}
var _slots: Array[StringName] = []
var _emitted_count := 0

func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_seen.clear()
	_slots.clear()
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_seen.clear()
	_slots.clear()
	return _result(true, &"detached")

func present_interaction(result: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var generation := int(result.get("generation", -1))
	if generation < 0:
		return _result(false, &"invalid_generation")
	var reason := StringName(result.get("reason", &""))
	var cue := &"heavy_breach_board_admitted" if bool(result.get("accepted", false)) else &"heavy_breach_board_rejected"
	_emit(cue, "%d:interaction:%s" % [generation, reason])
	return _result(true, &"interaction_presented")

func present_terminal(scenario_id: StringName, outcome: StringName, generation: int) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if scenario_id != &"heavy_breach" or generation < 1:
		return _result(false, &"foreign_terminal")
	var cue := &"heavy_breach_board_success" if outcome == &"cleared" else &"heavy_breach_board_terminal"
	_emit(cue, "%d:terminal:%s" % [generation, outcome])
	return _result(true, &"terminal_presented")

func present_reward(result: Dictionary, generation: int) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if generation < 1 or not bool(result.get("accepted", false)):
		return _result(false, &"reward_not_committed")
	_emit(&"heavy_breach_board_reward_confirmed", "%d:reward" % generation)
	return _result(true, &"reward_presented")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "emitted_cue_count": _emitted_count,
		"active_cue_slots": _slots.duplicate(), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"board_admission": false, "objective": false, "reward": false, "audio_cues": true}}.duplicate(true)

func _emit(cue_id: StringName, key: String) -> void:
	if _seen.has(key):
		return
	_seen[key] = true
	if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.pop_front()
	_slots.append(cue_id)
	_emitted_count += 1
	semantic_board_cue_emitted.emit(cue_id, 1.0)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
