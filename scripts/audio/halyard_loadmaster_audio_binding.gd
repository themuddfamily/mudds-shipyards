class_name HalyardLoadmasterAudioBinding
extends RefCounted

## Audio-only consumer for caller-resolved Halyard loadmaster receipts.
## Seat, manifest, cargo, and readiness authority remain with Halyard.

signal semantic_loadmaster_cue_emitted(cue_id: StringName, intensity: float, perspective: StringName)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const PERSPECTIVES := [&"cockpit", &"cabin"]

var _attached := false
var _generation := 0
var _perspective: StringName = &"cabin"
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

func present_perspective(perspective: StringName) -> Dictionary:
	if not _attached or not PERSPECTIVES.has(perspective):
		return _result(false, &"invalid_perspective" if _attached else &"not_attached")
	_perspective = perspective
	return _result(true, &"perspective_updated")

func present_accepted_receipt(receipt: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if StringName(receipt.get("seat_id", &"")) != &"crew_port_00":
		return _result(false, &"foreign_receipt")
	var generation := int(receipt.get("manifest_generation", -1))
	var manifest_id := StringName(receipt.get("manifest_id", &""))
	var route_id := StringName(receipt.get("route_id", &""))
	if generation < 0 or manifest_id.is_empty() or route_id.is_empty():
		return _result(false, &"invalid_receipt")
	var key := "%d:%d:%s:%s" % [generation, int(receipt.get("request_sequence", -1)), manifest_id, route_id]
	if _seen.has(key):
		return _result(true, &"duplicate_receipt")
	_seen[key] = true
	_emit(&"loadmaster_route_confirmed", "%s:route" % key)
	_emit(&"loadmaster_manifest_ready" if bool(receipt.get("ready", false)) else &"loadmaster_manifest_blocked", "%s:readiness" % key)
	return _result(true, &"receipt_presented")

func present_rejected_result(result: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var reason := StringName(result.get("reason", &""))
	if reason not in [&"stale_sequence", &"stale_generation", &"assignment_not_found", &"unsupported_halyard_role_action", &"loadmaster_station_required", &"loadmaster_station_unavailable", &"ship_destroyed"]:
		return _result(false, &"irrelevant_result")
	var key := "%d:rejected:%s" % [_generation, reason]
	if _seen.has(key):
		return _result(true, &"duplicate_rejection")
	_emit(&"loadmaster_navigation_rejected", key)
	return _result(true, &"rejection_presented")

func present_cleared(generation: int, reason: StringName) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var key := "%d:clear:%s" % [generation, reason]
	if _seen.has(key):
		return _result(true, &"duplicate_clear")
	_emit(&"loadmaster_manifest_reset", key)
	return _result(true, &"clear_presented")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "perspective": _perspective,
		"emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(),
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"seat": false, "cargo": false, "manifest": false, "audio_cues": true}}.duplicate(true)

func _emit(cue_id: StringName, key: String) -> void:
	if _seen.has(key): return
	_seen[key] = true
	if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.pop_front()
	_slots.append(cue_id)
	_emitted_count += 1
	semantic_loadmaster_cue_emitted.emit(cue_id, 1.0, _perspective)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
