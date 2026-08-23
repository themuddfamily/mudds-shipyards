class_name CinderFieldActivityAudioBinding
extends RefCounted

## Presentation-only cues for Cinder's authored extraction, scan, and beacon
## activities. The activity binding remains the sole state/reward authority.

signal semantic_activity_cue_emitted(cue_id: StringName, activity_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const ACTIVITY_IDS := [
	&"cinder_platform_mining_run", &"cinder_derelict_structure_scan", &"cinder_debris_beacon_traversal",
	&"cinder_reach_checkpoint_route", &"cinder_relay_patrol",
]
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
	var source_generation: Variant = _snapshot_generation(snapshot)
	if not source_generation is int or int(source_generation) < 0 or int(source_generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	var state := _state_name(activity_id, snapshot)
	if state == &"invalid":
		return _result(false, &"invalid_state")
	var previous := _last.get(activity_id, {}) as Dictionary
	var prefix := _cue_prefix(activity_id)
	var previous_state := StringName(previous.get("state", &"idle"))
	if state in [&"countdown", &"active", &"travel", &"dwell"] and previous_state not in [&"countdown", &"active", &"travel", &"dwell"]:
		_emit(prefix + &"_started", activity_id, 1.0, "%s:%d:start" % [activity_id, source_generation])
	if state in [&"complete", &"completed"] and previous_state not in [&"complete", &"completed"]:
		_emit(prefix + &"_complete", activity_id, 1.0, "%s:%d:complete" % [activity_id, source_generation])
	if state in [&"reset", &"idle"] and previous_state not in [&"", &"idle"]:
		_emit(prefix + &"_reset", activity_id, 1.0, "%s:%d:reset" % [activity_id, source_generation])
	if state in [&"failed", &"aborted"] and previous_state not in [&"failed", &"aborted"]:
		_emit(prefix + &"_failed", activity_id, 1.0, "%s:%d:failed" % [activity_id, source_generation])
	var progress := _progress(activity_id, snapshot)
	var prior_progress := float(previous.get("progress", 0.0))
	for threshold: float in [0.5, 1.0]:
		if progress >= threshold and prior_progress < threshold:
			_emit(prefix + &"_progress", activity_id, threshold, "%s:%d:progress:%s" % [activity_id, source_generation, threshold])
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

func present_reward_result(result: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var activity_id := StringName(result.get("activity_id", &""))
	if activity_id not in [&"cinder_derelict_structure_scan", &"cinder_debris_beacon_traversal"]:
		return _result(false, &"foreign_activity")
	if not bool(result.get("accepted", false)) or StringName(result.get("reason", &"")) != &"reward_request_ready":
		return _result(false, &"reward_not_ready")
	var reward_request := result.get("reward_request", {}) as Dictionary
	var generation := int(reward_request.get("generation", result.get("generation", -1)))
	if generation < 0 or generation > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	_emit(&"cinder_activity_reward_pending", activity_id, 1.0, "%s:%d:reward" % [activity_id, generation])
	return _result(true, &"reward_presented")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "emitted_cue_count": _emitted_count,
		"active_cue_slots": _slots.duplicate(true), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"activity": false, "reward": false, "gameplay": false, "audio_cues": true}}.duplicate(true)

func _state_name(activity_id: StringName, snapshot: Dictionary) -> StringName:
	if activity_id in [&"cinder_reach_checkpoint_route", &"cinder_relay_patrol"]:
		var state_id := StringName(snapshot.get("state_id", &""))
		if activity_id == &"cinder_relay_patrol":
			state_id = StringName(snapshot.get("phase_id", state_id)) if state_id == &"active" else state_id
		return state_id if state_id in [&"idle", &"countdown", &"active", &"travel", &"dwell", &"completed", &"failed", &"aborted"] else &"invalid"
	var raw := int(snapshot.get("state", -1))
	if raw in [0, 1, 2, 3]:
		return [&"idle", &"active", &"complete", &"reset"][raw]
	return &"invalid"

func _progress(activity_id: StringName, snapshot: Dictionary) -> float:
	if activity_id in [&"cinder_reach_checkpoint_route", &"cinder_relay_patrol"]:
		return clampf(float(snapshot.get("next_checkpoint_index", snapshot.get("completed_checkpoint_count", 0))) / maxf(float(snapshot.get("checkpoint_count", 1)), 1.0), 0.0, 1.0)
	if activity_id == &"cinder_debris_beacon_traversal":
		return clampf(float(snapshot.get("next_beacon_index", 0)) / maxf(float(snapshot.get("beacon_count", 1)), 1.0), 0.0, 1.0)
	var elapsed_key := "scan_seconds" if activity_id == &"cinder_derelict_structure_scan" else "extraction_seconds"
	return clampf(float(snapshot.get("elapsed_seconds", 0.0)) / maxf(float(snapshot.get(elapsed_key, 1.0)), 1.0), 0.0, 1.0)

func _snapshot_generation(snapshot: Dictionary) -> Variant:
	if snapshot.has("generation"):
		return snapshot.get("generation")
	if snapshot.has("activity_generation"):
		return snapshot.get("activity_generation")
	return snapshot.get("session_generation", null)

func _cue_prefix(activity_id: StringName) -> StringName:
	if activity_id == &"cinder_reach_checkpoint_route":
		return &"cinder_race"
	if activity_id == &"cinder_relay_patrol":
		return &"cinder_patrol"
	return &"cinder_activity"

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
