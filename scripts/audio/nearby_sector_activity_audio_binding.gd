class_name NearbySectorActivityAudioBinding
extends Node

## Audio-owned presentation adapter for detached Nearby Sector activity state.
## It observes snapshots only; activity, checkpoint, and reward authority remain
## with the caller. No per-activity gameplay knowledge is required here.

signal semantic_activity_cue_emitted(cue_id: StringName, activity_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const PROGRESS_THRESHOLDS := [0.25, 0.5, 0.75]
const ACTIVITY_STATES := [&"idle", &"selected", &"active", &"complete", &"reset"]

var _attached := false
var _generation := 0
var _last_snapshot: Dictionary = {}
var _last_activity_id: StringName = &""
var _last_state: StringName = &"idle"
var _last_checkpoint_id: StringName = &""
var _last_progress := 0.0
var _last_reward_pending := false
var _progress_thresholds_emitted := {}
var _emitted_cue_count := 0


func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_last_snapshot.clear()
	_last_activity_id = &""
	_last_state = &"idle"
	_last_checkpoint_id = &""
	_last_progress = 0.0
	_last_reward_pending = false
	_progress_thresholds_emitted.clear()
	return _result(true, &"attached")


func present_activity_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var decoded := _decode_snapshot(snapshot)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_snapshot")))
	var activity_id: StringName = decoded.activity_id
	var state: StringName = decoded.state
	var progress := float(decoded.progress_unitless)
	var checkpoint_id: StringName = decoded.checkpoint_id
	var reward_pending := bool(decoded.reward_pending)
	var reset_serial := int(decoded.reset_serial)
	if activity_id != _last_activity_id:
		_emit_cue(&"activity_selected", activity_id, 1.0)
		_progress_thresholds_emitted.clear()
	if state == &"active" and _last_state != &"active":
		_emit_cue(&"activity_started", activity_id, 1.0)
	if checkpoint_id != &"" and checkpoint_id != _last_checkpoint_id:
		_emit_cue(&"activity_checkpoint", activity_id, 1.0)
	for threshold: float in PROGRESS_THRESHOLDS:
		if progress >= threshold and not _progress_thresholds_emitted.has(threshold):
			_progress_thresholds_emitted[threshold] = true
			_emit_cue(&"activity_progress", activity_id, threshold)
	if state == &"complete" and _last_state != &"complete":
		_emit_cue(&"activity_complete", activity_id, 1.0)
	if reward_pending and not _last_reward_pending:
		_emit_cue(&"activity_reward_pending", activity_id, 1.0)
	if state == &"reset" or reset_serial > int(_last_snapshot.get("reset_serial", 0)):
		_emit_cue(&"activity_reset", activity_id, 1.0)
	_last_activity_id = activity_id
	_last_state = state
	_last_checkpoint_id = checkpoint_id
	_last_progress = progress
	_last_reward_pending = reward_pending
	_last_snapshot = snapshot.duplicate(true)
	return _result(true, &"snapshot_presented")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_last_snapshot.clear()
	_last_activity_id = &""
	_last_state = &"idle"
	_last_checkpoint_id = &""
	_last_progress = 0.0
	_last_reward_pending = false
	_progress_thresholds_emitted.clear()
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_snapshot": _last_snapshot.duplicate(true),
		"last_activity_id": _last_activity_id,
		"last_state": _last_state,
		"last_progress_unitless": _last_progress,
		"emitted_cue_count": _emitted_cue_count,
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"authority": {"activity": false, "reward": false, "gameplay": false, "audio_cues": true},
	}.duplicate(true)


func _decode_snapshot(snapshot: Dictionary) -> Dictionary:
	var activity_id: Variant = snapshot.get("activity_id", &"")
	var state: Variant = snapshot.get("state", &"")
	var progress: Variant = snapshot.get("progress_unitless", 0.0)
	var checkpoint: Variant = snapshot.get("checkpoint_id", &"")
	var reset_serial: Variant = snapshot.get("reset_serial", 0)
	if activity_id is not StringName or (activity_id as StringName).is_empty() \
			or state is not StringName or not ACTIVITY_STATES.has(state as StringName) \
			or not _finite_range(progress, 0.0, 1.0) \
			or checkpoint is not StringName or not (reset_serial is int) \
			or int(reset_serial) < 0 or int(reset_serial) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_snapshot")
	var reward_pending: Variant = snapshot.get("reward_pending", false)
	if reward_pending is not bool:
		return _result(false, &"invalid_reward_state")
	return {
		"accepted": true,
		"activity_id": activity_id,
		"state": state,
		"progress_unitless": float(progress),
		"checkpoint_id": checkpoint,
		"reward_pending": reward_pending,
		"reset_serial": int(reset_serial),
	}.duplicate(true)


func _emit_cue(cue_id: StringName, activity_id: StringName, intensity: float) -> void:
	_emitted_cue_count += 1
	semantic_activity_cue_emitted.emit(cue_id, activity_id, clampf(intensity, 0.0, 1.0))


func _finite_range(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
			and float(value) >= minimum and float(value) <= maximum


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}.duplicate(true)
