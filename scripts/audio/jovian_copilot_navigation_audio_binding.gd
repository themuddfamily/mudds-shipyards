class_name JovianCopilotNavigationAudioBinding
extends RefCounted

## Audio-only consumer for caller-resolved Jovian copilot navigation receipts.
## Seat, route, and navigation authority remain with JovianLightFreighter.

signal semantic_copilot_cue_emitted(cue_id: StringName, intensity: float, perspective: StringName)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const PERSPECTIVES := [&"cockpit", &"exterior"]

var _attached := false
var _generation := 0
var _perspective: StringName = &"exterior"
var _last_receipt_key := ""
var _seen: Dictionary = {}
var _slots: Array[StringName] = []
var _emitted_count := 0

func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_last_receipt_key = ""
	_seen.clear()
	_slots.clear()
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_last_receipt_key = ""
	_seen.clear()
	_slots.clear()
	return _result(true, &"detached")

func present_perspective(perspective: StringName) -> Dictionary:
	if not _attached or not PERSPECTIVES.has(perspective):
		return _result(false, &"invalid_perspective" if _attached else &"not_attached")
	_perspective = perspective
	return _result(true, &"perspective_updated")

func present_accepted_receipt(receipt: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if StringName(receipt.get("role", &"")) != &"copilot_navigation_support":
		return _result(false, &"foreign_receipt")
	var navigation_generation := int(receipt.get("navigation_generation", -1))
	if navigation_generation < 0:
		return _result(false, &"invalid_receipt")
	var route_id := StringName(receipt.get("route_id", &""))
	var target_id := StringName(receipt.get("target_id", &""))
	if route_id.is_empty() or target_id.is_empty():
		return _result(false, &"invalid_receipt")
	var key := "%d:%d:%s:%s" % [navigation_generation, int(receipt.get("request_sequence", -1)), route_id, target_id]
	if _seen.has(key):
		return _result(true, &"duplicate_receipt")
	_seen[key] = true
	_last_receipt_key = key
	_emit(&"copilot_route_confirmed", 1.0)
	return _result(true, &"receipt_presented")

func present_rejected_result(result: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var reason := StringName(result.get("reason", &""))
	if reason not in [&"stale_sequence", &"stale_generation", &"assignment_not_found", &"foreign_vessel", &"unsupported_jovian_role_action", &"intent_effect_rejected"]:
		return _result(false, &"irrelevant_result")
	var key := "%d:rejected:%s" % [_generation, reason]
	if _seen.has(key):
		return _result(true, &"duplicate_rejection")
	_seen[key] = true
	_emit(&"copilot_navigation_rejected", 1.0)
	return _result(true, &"rejection_presented")

func present_cleared(generation: int, reason: StringName) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if generation < 0:
		return _result(false, &"invalid_generation")
	var key := "%d:clear:%s" % [generation, reason]
	if _seen.has(key):
		return _result(true, &"duplicate_clear")
	_seen[key] = true
	_last_receipt_key = ""
	_emit(&"copilot_navigation_reset", 1.0)
	return _result(true, &"clear_presented")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "perspective": _perspective,
		"last_receipt_key": _last_receipt_key, "emitted_cue_count": _emitted_count,
		"active_cue_slots": _slots.duplicate(), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"navigation": false, "seat": false, "audio_cues": true}}.duplicate(true)

func _emit(cue_id: StringName, intensity: float) -> void:
	if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.pop_front()
	_slots.append(cue_id)
	_emitted_count += 1
	semantic_copilot_cue_emitted.emit(cue_id, intensity, _perspective)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
