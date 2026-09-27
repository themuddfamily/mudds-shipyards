class_name HeavyBreachActivityBoardAudioBinding
extends RefCounted

## Presentation-only consumer for the physical heavy-breach activity board.
## Admission, objective, combat, and reward authority remain caller-owned.
##
## The board posts two contracts. Heavy Breach and Torpedo Run each get their
## own armed and terminal cues; [constant CUE_STREAMS] names the authored board
## tone the owning board voices for each cue (cues without an entry stay
## semantic-only, so a rejected out-of-range press is not audible).

signal semantic_board_cue_emitted(cue_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const SCENARIO_HEAVY_BREACH: StringName = &"heavy_breach"
const SCENARIO_TORPEDO_RUN: StringName = &"torpedo_run"
const CUE_TORPEDO_RUN_ARMED: StringName = &"torpedo_run_board_armed"
const CUE_TORPEDO_RUN_CLEARED: StringName = &"torpedo_run_board_cleared"
const CUE_TORPEDO_RUN_FAILED: StringName = &"torpedo_run_board_failed"
const BOARD_TONE_DIRECTORY := "res://assets/audio/combat/torpedo_run/"
## cue -> [authored board tone, pitch scale]. Heavy Breach reuses the Torpedo
## Run tones a fourth lower so the two contracts are told apart by ear.
const CUE_STREAMS := {
	CUE_TORPEDO_RUN_ARMED: [BOARD_TONE_DIRECTORY + "torpedo_board_armed_v1.wav", 1.0],
	CUE_TORPEDO_RUN_CLEARED: [BOARD_TONE_DIRECTORY + "torpedo_board_cleared_v1.wav", 1.0],
	CUE_TORPEDO_RUN_FAILED: [BOARD_TONE_DIRECTORY + "torpedo_board_failed_v1.wav", 1.0],
	&"heavy_breach_board_admitted": [BOARD_TONE_DIRECTORY + "torpedo_board_armed_v1.wav", 0.75],
	&"heavy_breach_board_success": [BOARD_TONE_DIRECTORY + "torpedo_board_cleared_v1.wav", 0.75],
	&"heavy_breach_board_terminal": [BOARD_TONE_DIRECTORY + "torpedo_board_failed_v1.wav", 0.75],
}

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
	if bool(result.get("accepted", false)) and _interaction_scenario(result) == SCENARIO_TORPEDO_RUN \
			and reason in [&"sortie_armed", &"torpedo_run_started"]:
		cue = CUE_TORPEDO_RUN_ARMED
	# The board generation only advances on reset or stream-out, so the sortie
	# (or director) generation keeps the second and later arms audible.
	var sortie := int(result.get("sortie_generation", result.get("director_generation", 0)))
	_emit(cue, "%d:%d:interaction:%s" % [generation, sortie, reason])
	return _result(true, &"interaction_presented")

func present_terminal(scenario_id: StringName, outcome: StringName, generation: int) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if scenario_id not in [SCENARIO_HEAVY_BREACH, SCENARIO_TORPEDO_RUN] or generation < 1:
		return _result(false, &"foreign_terminal")
	var cue := &"heavy_breach_board_success" if outcome == &"cleared" else &"heavy_breach_board_terminal"
	if scenario_id == SCENARIO_TORPEDO_RUN:
		cue = CUE_TORPEDO_RUN_CLEARED if outcome == &"cleared" else CUE_TORPEDO_RUN_FAILED
	_emit(cue, "%d:terminal:%s" % [generation, outcome])
	return _result(true, &"terminal_presented")

func present_reward(result: Dictionary, generation: int) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if generation < 1 or not bool(result.get("accepted", false)):
		return _result(false, &"reward_not_committed")
	_emit(&"heavy_breach_board_reward_confirmed", "%d:reward" % generation)
	return _result(true, &"reward_presented")

## The authored board tone and pitch for one cue, or an empty array when the cue
## is semantic-only.
func get_cue_stream(cue_id: StringName) -> Array:
	return (CUE_STREAMS.get(cue_id, []) as Array).duplicate()


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

## A launch result names its scenario; an arm result carries the offered one
## in its board snapshot.
func _interaction_scenario(result: Dictionary) -> StringName:
	if result.has("scenario"):
		return StringName(result.get("scenario", &""))
	var snapshot: Variant = result.get("snapshot", {})
	if snapshot is Dictionary:
		return StringName((snapshot as Dictionary).get("offered_scenario", &""))
	return &""


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
