class_name CinderFieldActivityAudioBinding
extends RefCounted

## Presentation-only cues for Cinder's authored extraction, scan, and beacon
## activities. The activity binding remains the sole state/reward authority.

signal semantic_activity_cue_emitted(cue_id: StringName, activity_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const ACTIVITY_IDS := [&"cinder_platform_mining_run", &"cinder_derelict_structure_scan", &"cinder_debris_beacon_traversal"]
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

var _attached := false
var _generation := 0
var _last: Dictionary = {}
var _seen: Dictionary = {}
var _slots: Array[Dictionary] = []
var _emitted_count := 0

func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_last.clear()
	_seen.clear()
	_slots.clear()
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_last.clear()
	_seen.clear()
	_slots.clear()
	return _result(true, &"detached")

func present_activity_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var activity_id := StringName(snapshot.get("activity_id", &""))
	if not ACTIVITY_IDS.has(activity_id):
		return _result(false, &"foreign_activity")
	var source_generation: Variant = snapshot.get("generation", null)
	if not source_generation is int or int(source_generation) < 0 or int(source_generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	var state := _state_name(activity_id, snapshot)
	if state == &"invalid":
		return _result(false, &"invalid_state")
	var previous := _last.get(activity_id, {}) as Dictionary
	if state == &"active" and StringName(previous.get("state", &"idle")) != &"active":
		_emit(&"cinder_activity_started", activity_id, 1.0, "%s:%d:start" % [activity_id, source_generation])
	if state == &"complete" and StringName(previous.get("state", &"")) != &"complete":
		_emit(&"cinder_activity_complete", activity_id, 1.0, "%s:%d:complete" % [activity_id, source_generation])
	if state == &"reset" and StringName(previous.get("state", &"")) != &"reset":
		_emit(&"cinder_activity_reset", activity_id, 1.0, "%s:%d:reset" % [activity_id, source_generation])
	var progress := _progress(activity_id, snapshot)
	var prior_progress := float(previous.get("progress", 0.0))
	for threshold: float in [0.5, 1.0]:
		if progress >= threshold and prior_progress < threshold:
			_emit(&"cinder_activity_progress", activity_id, threshold, "%s:%d:progress:%s" % [activity_id, source_generation, threshold])
	_last[activity_id] = {"state": state, "progress": progress, "generation": int(source_generation)}
	return _result(true, &"snapshot_presented")

func present_beacon_result(result: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var activity_id := StringName(result.get("activity_id", &"cinder_debris_beacon_traversal"))
	if activity_id != &"cinder_debris_beacon_traversal":
		return _result(false, &"foreign_activity")
	var reason := StringName(result.get("reason", &""))
	if reason != &"out_of_order_beacon":
		return _result(false, &"irrelevant_result")
	var source_generation := int(result.get("generation", -1))
	if source_generation < 0 or source_generation > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	_emit(&"cinder_beacon_wrong_order", activity_id, 1.0, "%s:%d:wrong-order" % [activity_id, source_generation])
	return _result(true, &"result_presented")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "emitted_cue_count": _emitted_count,
		"active_cue_slots": _slots.duplicate(true), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"activity": false, "reward": false, "gameplay": false, "audio_cues": true}}.duplicate(true)

func _state_name(activity_id: StringName, snapshot: Dictionary) -> StringName:
	var raw := int(snapshot.get("state", -1))
	if raw in [0, 1, 2, 3]:
		return [&"idle", &"active", &"complete", &"reset"][raw]
	return &"invalid"

func _progress(activity_id: StringName, snapshot: Dictionary) -> float:
	if activity_id == &"cinder_debris_beacon_traversal":
		return clampf(float(snapshot.get("next_beacon_index", 0)) / maxf(float(snapshot.get("beacon_count", 1)), 1.0), 0.0, 1.0)
	var elapsed_key := "scan_seconds" if activity_id == &"cinder_derelict_structure_scan" else "extraction_seconds"
	return clampf(float(snapshot.get("elapsed_seconds", 0.0)) / maxf(float(snapshot.get(elapsed_key, 1.0)), 1.0), 0.0, 1.0)

func _emit(cue_id: StringName, activity_id: StringName, intensity: float, key: String) -> void:
	if _seen.has(key): return
	_seen[key] = true
	if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.pop_front()
		_slots.append({"cue_id": cue_id, "activity_id": activity_id})
	else:
		_slots.append({"cue_id": cue_id, "activity_id": activity_id})
	_emitted_count += 1
	semantic_activity_cue_emitted.emit(cue_id, activity_id, clampf(intensity, 0.0, 1.0))

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
