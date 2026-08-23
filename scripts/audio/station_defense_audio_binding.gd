class_name StationDefenseAudioBinding
extends RefCounted

## Presentation-only bridge for detached station-defense snapshots. It emits
## typed activity cues; wave, asset, combat, and reward authority stay upstream.

signal semantic_activity_cue_emitted(cue_id: StringName, activity_id: StringName, intensity: float)
signal semantic_cue_emitted(source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3)

const MAX_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const CUE_PRIORITIES := {
	&"station_defense_wave_started": 20,
	&"station_defense_asset_danger": 50,
	&"station_defense_asset_critical": 80,
	&"station_defense_completed": 100,
	&"station_defense_aborted": 90,
}

var _host: Node
var _attached := false
var _generation := 0
var _last_state: StringName = &"idle"
var _last_wave_index := -1
var _last_asset_damage: Dictionary = {}
var _last_snapshot: Dictionary = {}
var _emitted_cue_count := 0
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


func attach(host: Node) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if host == null or not is_instance_valid(host) or not host.has_signal(&"snapshot_changed"):
		return _result(false, &"invalid_host")
	_host = host
	var callback := Callable(self, "_on_host_snapshot")
	if not host.is_connected(&"snapshot_changed", callback):
		host.connect(&"snapshot_changed", callback)
	_attached = true
	_last_state = &"idle"
	_last_wave_index = -1
	_last_asset_damage.clear()
	_last_snapshot.clear()
	return _result(true, &"attached")


func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var decoded := _decode_snapshot(snapshot)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_snapshot")))
	_emit_transitions(decoded)
	_last_snapshot = snapshot.duplicate(true)
	return _result(true, &"snapshot_presented")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if is_instance_valid(_host):
		var callback := Callable(self, "_on_host_snapshot")
		if _host.is_connected(&"snapshot_changed", callback):
			_host.disconnect(&"snapshot_changed", callback)
	_attached = false
	_host = null
	_last_state = &"idle"
	_last_wave_index = -1
	_last_asset_damage.clear()
	_last_snapshot.clear()
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	_generation += 1
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_snapshot": _last_snapshot.duplicate(true),
		"emitted_cue_count": _emitted_cue_count,
		"last_cue_id": _last_cue_id,
		"maximum_simultaneous_voices": MAX_SIMULTANEOUS_VOICES,
		"authority": {"activity": false, "protected_assets": false, "combat": false, "audio_cues": true},
	}.duplicate(true)


func _on_host_snapshot(snapshot: Dictionary) -> void:
	present_snapshot(snapshot)


func _decode_snapshot(snapshot: Dictionary) -> Dictionary:
	var activity: Variant = snapshot.get("activity", snapshot)
	if not activity is Dictionary:
		return _result(false, &"invalid_activity_snapshot")
	var state: Variant = activity.get("state_id", &"")
	var activity_id: Variant = activity.get("activity_id", &"")
	var wave_index: Variant = activity.get("current_wave_index", 0)
	var wave_active: Variant = activity.get("wave_active", false)
	var assets: Variant = activity.get("protected_assets", [])
	if state not in [&"idle", &"active", &"completed", &"failed", &"aborted", &"timed_out"] \
			or not activity_id is StringName or (activity_id as StringName).is_empty() \
			or not wave_index is int or int(wave_index) < 0 \
			or not wave_active is bool or not assets is Array:
		return _result(false, &"invalid_activity_snapshot")
	return {"accepted": true, "state": state, "activity_id": activity_id, "wave_index": int(wave_index), "wave_active": bool(wave_active), "assets": assets}.duplicate(true)


func _emit_transitions(decoded: Dictionary) -> void:
	var activity_id: StringName = decoded.activity_id
	var state: StringName = decoded.state
	var wave_index := int(decoded.wave_index)
	if state == &"active" and bool(decoded.wave_active) \
			and (wave_index != _last_wave_index or _last_state != &"active"):
		_emit_cue(&"station_defense_wave_started", activity_id, 1.0)
	for asset_variant in decoded.assets as Array:
		if not asset_variant is Dictionary:
			continue
		var asset := asset_variant as Dictionary
		var handle := asset.get("handle", {}) as Dictionary
		var key := str(handle.get("asset_id", &""))
		var damage_count := int(asset.get("damage_event_count", 0))
		var destroyed := bool(asset.get("destroyed", false))
		var prior := int(_last_asset_damage.get(key, 0))
		if destroyed and (prior < 2):
			_emit_cue(&"station_defense_asset_critical", activity_id, 1.0)
		elif damage_count > 0 and prior == 0:
			_emit_cue(&"station_defense_asset_danger", activity_id, 0.5)
		_last_asset_damage[key] = 2 if destroyed else damage_count
	if state == &"completed" and _last_state != &"completed":
		_emit_cue(&"station_defense_completed", activity_id, 1.0)
	elif state in [&"failed", &"aborted", &"timed_out"] and _last_state not in [&"failed", &"aborted", &"timed_out"]:
		_emit_cue(&"station_defense_aborted", activity_id, 1.0)
	_last_state = state
	_last_wave_index = wave_index


func _emit_cue(cue_id: StringName, activity_id: StringName, intensity: float) -> void:
	_emitted_cue_count += 1
	_last_cue_id = cue_id
	semantic_activity_cue_emitted.emit(cue_id, activity_id, clampf(intensity, 0.0, 1.0))
	semantic_cue_emitted.emit(&"station_defense", cue_id, clampf(intensity, 0.0, 1.0), Vector3.ZERO)
	if _audio_director != null and is_instance_valid(_audio_director):
		_audio_director.call(&"_on_semantic_cue", &"station_defense", cue_id, clampf(intensity, 0.0, 1.0), Vector3.ZERO)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
