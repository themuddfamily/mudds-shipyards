class_name PlanetaryFinalApproachAudioBinding
extends RefCounted

## Presentation-only consumer for detached final-approach snapshots/receipts.
## Cruise, landing, movement, Host, and playback authority remain upstream.

signal semantic_cue_emitted(
		source_id: StringName,
		cue_id: StringName,
		intensity: float,
		world_position: Vector3,
	)

const SOURCE_ID: StringName = &"planetary_final_approach"
const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const STATE_CUES := {
	&"armed": &"planetary_final_approach_armed",
	&"final_approach": &"planetary_final_approach_alignment_ready",
	&"active": &"planetary_final_approach_alignment_ready",
	&"completed": &"planetary_final_approach_handoff_ready",
}
const REJECTION_REASONS := [
	&"final_approach_aborted",
	&"final_approach_target_unavailable",
	&"final_approach_generation_mismatch",
	&"final_approach_completion_invalid",
]

var _attached := false
var _generation := 0
var _last_input_generation := -1
var _last_key := ""
var _seen: Dictionary = {}
var _slots: Array[StringName] = []
var _emitted_count := 0
var _rejected_count := 0

func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_seen.clear()
	_slots.clear()
	_last_input_generation = -1
	_last_key = ""
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached:
		return _result(true, &"already_detached")
	_attached = false
	_generation += 1
	_seen.clear()
	_slots.clear()
	_last_input_generation = -1
	_last_key = ""
	return _result(true, &"detached")

func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var final_approach := snapshot.get("final_approach", snapshot) as Dictionary
	var input_generation: Variant = final_approach.get(
		"target_generation", snapshot.get("generation", -1)
	)
	if not input_generation is int or int(input_generation) < 0 \
			or int(input_generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	var state_id := StringName(final_approach.get("state_id", &""))
	if state_id.is_empty():
		return _result(false, &"invalid_state")
	if int(input_generation) < _last_input_generation:
		return _result(false, &"stale_generation")
	var reason := StringName(final_approach.get("reason", snapshot.get("reason", &"")))
	var key := "%d:state:%s:%s" % [int(input_generation), state_id, reason]
	if _seen.has(key):
		return _result(true, &"duplicate_snapshot")
	_seen[key] = true
	_last_input_generation = int(input_generation)
	_last_key = key
	if REJECTION_REASONS.has(reason) or state_id in [&"aborted", &"failed"]:
		_rejected_count += 1
		_emit(&"planetary_final_approach_rejected")
		return _result(true, &"rejection_presented")
	var cue: StringName = STATE_CUES.get(state_id, &"")
	if cue.is_empty():
		return _result(true, &"snapshot_accepted")
	_emit(cue)
	return _result(true, &"snapshot_presented")

func present_receipt(receipt: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var reason := StringName(receipt.get("reason", &""))
	var generation: Variant = receipt.get(
		"target_generation", receipt.get("generation", -1)
	)
	if not generation is int or int(generation) < 0 \
			or int(generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	if int(generation) < _last_input_generation:
		return _result(false, &"stale_generation")
	var key := "%d:receipt:%s:%d" % [int(generation), reason, int(receipt.get("caller_tick", -1))]
	if _seen.has(key):
		return _result(true, &"duplicate_receipt")
	_seen[key] = true
	_last_input_generation = int(generation)
	_last_key = key
	if reason == &"final_approach_handoff_ready":
		_emit(&"planetary_final_approach_handoff_ready")
	else:
		_rejected_count += 1
		_emit(&"planetary_final_approach_rejected")
	return _result(true, &"receipt_presented")

func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_input_generation": _last_input_generation,
		"last_key": _last_key,
		"emitted_cue_count": _emitted_count,
		"rejected_count": _rejected_count,
		"active_cue_slots": _slots.duplicate(),
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"cruise": false, "landing": false, "movement": false, "host": false, "audio_cues": true},
	}.duplicate(true)

func _emit(cue_id: StringName) -> void:
	if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.pop_front()
	_slots.append(cue_id)
	_emitted_count += 1
	semantic_cue_emitted.emit(SOURCE_ID, cue_id, 1.0, Vector3.ZERO)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
