class_name CinderCargoTransferAudioBinding
extends RefCounted

## Presentation-only consumer for exact cargo-transfer receipts. Cargo,
## objective, reward, and inventory authority remain with the caller.

signal semantic_activity_cue_emitted(cue_id: StringName, transaction_id: StringName, intensity: float)
signal semantic_cue_emitted(source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const EVENT_TO_CUE := {
	&"pickup_accepted": &"cargo_transfer_pickup_accepted",
	&"destination_delivered": &"cargo_transfer_destination_delivered",
	&"transfer_rejected": &"cargo_transfer_rejected",
	&"activity_completed": &"cargo_transfer_activity_completed",
	&"activity_aborted": &"cargo_transfer_aborted",
}
const CUE_PRIORITIES := {
	&"cargo_transfer_pickup_accepted": 30,
	&"cargo_transfer_destination_delivered": 70,
	&"cargo_transfer_rejected": 80,
	&"cargo_transfer_activity_completed": 100,
	&"cargo_transfer_aborted": 90,
}

var _attached := false
var _generation := 0
var _seen_receipts: Dictionary = {}
var _active_cue_slots: Array[Dictionary] = []
var _emitted_cue_count := 0
var _preempted_cue_count := 0
var _last_cue_id: StringName = &""
var _audio_director: Node

func register_audio_director(audio_director: Node) -> Dictionary:
	if audio_director == null or not is_instance_valid(audio_director) or not audio_director.has_method(&"_on_semantic_cue"):
		return _result(false, &"invalid_audio_director")
	_audio_director = audio_director
	return _result(true, &"audio_director_registered")

func unregister_audio_director() -> Dictionary:
	_audio_director = null
	return _result(true, &"audio_director_unregistered")

func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_seen_receipts.clear()
	_active_cue_slots.clear()
	return _result(true, &"attached")

func present_transfer_receipt(receipt: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var decoded := _decode_receipt(receipt)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_receipt")))
	var event_id: StringName = decoded.event_id
	var transaction_id: StringName = decoded.transaction_id
	var key := "%d:%s:%s" % [_generation, String(transaction_id), String(event_id)]
	if _seen_receipts.has(key):
		return _result(false, &"duplicate_receipt")
	_seen_receipts[key] = true
	var cue_id: StringName = EVENT_TO_CUE[event_id]
	if not _admit_cue(cue_id, transaction_id):
		return _result(false, &"voice_budget_rejected")
	_emitted_cue_count += 1
	_last_cue_id = cue_id
	semantic_activity_cue_emitted.emit(cue_id, transaction_id, float(decoded.intensity))
	semantic_cue_emitted.emit(&"cinder_cargo", cue_id, float(decoded.intensity), Vector3.ZERO)
	if _audio_director != null and is_instance_valid(_audio_director):
		_audio_director.call(&"_on_semantic_cue", &"cinder_cargo", cue_id, float(decoded.intensity), Vector3.ZERO)
	return _result(true, &"cue_presented")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_seen_receipts.clear()
	_active_cue_slots.clear()
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	_generation += 1
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"emitted_cue_count": _emitted_cue_count,
		"last_cue_id": _last_cue_id,
		"active_cue_slots": _active_cue_slots.duplicate(true),
		"preempted_cue_count": _preempted_cue_count,
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"cargo": false, "reward": false, "objective": false, "audio_cues": true},
	}.duplicate(true)

func _decode_receipt(receipt: Dictionary) -> Dictionary:
	var generation: Variant = receipt.get("generation", -1)
	var transaction_id: Variant = receipt.get("transaction_id", &"")
	var event_id: Variant = receipt.get("event_id", &"")
	var accepted: Variant = receipt.get("accepted", false)
	var intensity: Variant = receipt.get("intensity", 1.0)
	if not generation is int or int(generation) != _generation:
		return _result(false, &"stale_generation")
	if not transaction_id is StringName or (transaction_id as StringName).is_empty():
		return _result(false, &"invalid_transaction_id")
	if not event_id is StringName or not EVENT_TO_CUE.has(event_id as StringName):
		return _result(false, &"invalid_event_id")
	if not accepted is bool:
		return _result(false, &"invalid_acceptance")
	if not accepted:
		return _result(false, &"rejected_receipt")
	if not intensity is float and not intensity is int:
		return _result(false, &"invalid_intensity")
	if not is_finite(float(intensity)) or float(intensity) < 0.0 or float(intensity) > 1.0:
		return _result(false, &"invalid_intensity")
	return {"accepted": true, "event_id": event_id, "transaction_id": transaction_id, "intensity": float(intensity)}

func _admit_cue(cue_id: StringName, transaction_id: StringName) -> bool:
	var priority := int(CUE_PRIORITIES.get(cue_id, 0))
	if _active_cue_slots.size() < MAXIMUM_SIMULTANEOUS_VOICES:
		_active_cue_slots.append({"cue_id": cue_id, "transaction_id": transaction_id, "priority": priority})
		return true
	var lowest_index := 0
	for index in range(1, _active_cue_slots.size()):
		if int(_active_cue_slots[index].priority) < int(_active_cue_slots[lowest_index].priority):
			lowest_index = index
	if priority <= int(_active_cue_slots[lowest_index].priority):
		return false
	_preempted_cue_count += 1
	_active_cue_slots[lowest_index] = {"cue_id": cue_id, "transaction_id": transaction_id, "priority": priority}
	return true

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
