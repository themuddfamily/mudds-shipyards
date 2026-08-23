class_name StationDefenseAudioBinding
extends RefCounted

## Presentation-only bridge for detached station-defense snapshots. It emits
## typed activity cues; wave, asset, combat, and reward authority stay upstream.

signal semantic_activity_cue_emitted(cue_id: StringName, activity_id: StringName, intensity: float)
signal semantic_cue_emitted(source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3)

const MAX_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const CONTENT_COMPONENT_ID: StringName = &"shipyard_perimeter_defense_content"
const PINCER_WAVE_ID: StringName = &"dockside_relief"
const PINCER_CLOSE_HOSTILE_ID: StringName = &"perimeter_raider_beta"
const PINCER_OUTER_HOSTILE_ID: StringName = &"perimeter_raider_gamma"
const BREAKER_FEINT_TACTIC_ID: StringName = &"core_breaker_outer_feint"
const BREAKER_STATES: Array[StringName] = [
	&"idle", &"standby", &"inbound", &"active", &"transitioned", &"interrupted",
	&"completed", &"failed", &"aborted", &"timed_out",
]
const CUE_PRIORITIES := {
	&"station_defense_wave_started": 20,
	&"station_defense_breaker_inbound": 55,
	&"station_defense_breaker_active": 70,
	&"station_defense_breaker_interrupted": 65,
	&"station_defense_pincer_inbound": 55,
	&"station_defense_crossfire_active": 75,
	&"station_defense_pincer_wing_broken": 65,
	&"station_defense_pincer_cleared": 45,
	&"station_defense_asset_danger": 50,
	&"station_defense_asset_critical": 80,
	&"station_defense_asset_destroyed": 100,
	&"station_defense_asset_recovered": 70,
	&"station_defense_asset_safe": 20,
	&"station_defense_completed": 100,
	&"station_defense_aborted": 90,
}

var _host: Node
var _snapshot_source: Node
var _attached := false
var _generation := 0
var _last_state: StringName = &"idle"
var _last_wave_index := -1
var _last_asset_damage: Dictionary = {}
var _last_snapshot: Dictionary = {}
var _emitted_cue_count := 0
var _last_cue_id: StringName = &""
var _audio_director: Node
var _reduced_dynamic_range := false
var _tactic_generation_by_activity: Dictionary = {}
var _tactic_state_by_activity: Dictionary = {}
var _seen_tactic_cues_by_activity: Dictionary = {}

func register_audio_director(audio_director: Node) -> Dictionary:
	if audio_director == null or not is_instance_valid(audio_director) or not audio_director.has_method(&"_on_semantic_cue"):
		return _result(false, &"invalid_audio_director")
	_audio_director = audio_director
	return _result(true, &"audio_director_registered")

func unregister_audio_director() -> Dictionary:
	_audio_director = null
	return _result(true, &"audio_director_unregistered")


func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	return _result(true, &"mix_updated")


func attach(host: Node) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if host == null or not is_instance_valid(host) or not host.has_signal(&"snapshot_changed"):
		return _result(false, &"invalid_host")
	var snapshot_source := _resolve_snapshot_source(host)
	if snapshot_source == null:
		return _result(false, &"invalid_snapshot_source")
	_host = host
	_snapshot_source = snapshot_source
	var callback := Callable(self, "_on_host_snapshot")
	if not snapshot_source.is_connected(&"snapshot_changed", callback):
		snapshot_source.connect(&"snapshot_changed", callback)
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
	if is_instance_valid(_snapshot_source):
		var callback := Callable(self, "_on_host_snapshot")
		if _snapshot_source.is_connected(&"snapshot_changed", callback):
			_snapshot_source.disconnect(&"snapshot_changed", callback)
	_attached = false
	_host = null
	_snapshot_source = null
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
		"reduced_dynamic_range": _reduced_dynamic_range,
		"tactic_generation_fences": _tactic_generation_by_activity.duplicate(true),
		"authority": {"activity": false, "protected_assets": false, "combat": false, "audio_cues": true},
	}.duplicate(true)


func _on_host_snapshot(snapshot: Dictionary) -> void:
	present_snapshot(snapshot)


func _resolve_snapshot_source(host: Node) -> Node:
	var parent := host.get_parent()
	if (
		parent != null
		and parent.has_signal(&"snapshot_changed")
		and parent.has_method(&"get_snapshot")
	):
		var parent_snapshot: Variant = parent.call(&"get_snapshot")
		if (
			parent_snapshot is Dictionary
			and StringName((parent_snapshot as Dictionary).get("component_id", &""))
			== CONTENT_COMPONENT_ID
		):
			return parent
	return host


func _decode_snapshot(snapshot: Dictionary) -> Dictionary:
	var activity: Variant = snapshot.get("activity", null)
	if not activity is Dictionary:
		var host_snapshot: Variant = snapshot.get("host", {})
		if host_snapshot is Dictionary:
			activity = (host_snapshot as Dictionary).get("activity", null)
	if not activity is Dictionary:
		activity = snapshot
	if not activity is Dictionary:
		return _result(false, &"invalid_activity_snapshot")
	var state: Variant = activity.get("state_id", &"")
	var activity_id: Variant = activity.get("activity_id", &"")
	var wave_index: Variant = activity.get("current_wave_index", 0)
	var wave_active: Variant = activity.get("wave_active", false)
	var generation: Variant = activity.get("generation", -1)
	var wave_id: Variant = activity.get("wave_id", &"")
	var active_hostile_handles: Variant = activity.get("active_hostile_handles", [])
	var assets: Variant = activity.get("protected_assets", [])
	if state not in [&"idle", &"active", &"completed", &"failed", &"aborted", &"timed_out"] \
			or not activity_id is StringName or (activity_id as StringName).is_empty() \
			or not wave_index is int or int(wave_index) < 0 \
			or not wave_active is bool or not assets is Array \
			or not generation is int or int(generation) < 0 \
			or int(generation) > MAX_SAFE_GENERATION \
			or not wave_id is StringName or not active_hostile_handles is Array:
		return _result(false, &"invalid_activity_snapshot")
	var breaker := _decode_breaker_state(snapshot, activity as Dictionary, int(generation))
	if not bool(breaker.get("accepted", false)):
		return _result(false, StringName(breaker.get("reason", &"invalid_breaker_snapshot")))
	return {
		"accepted": true,
		"state": state,
		"activity_id": activity_id,
		"generation": int(generation),
		"wave_index": int(wave_index),
		"wave_id": wave_id,
		"wave_active": bool(wave_active),
		"active_hostile_handles": active_hostile_handles,
		"assets": assets,
		"breaker_authoritative": bool(breaker.get("available", false)),
		"breaker_state": StringName(breaker.get("state_id", &"unavailable")),
	}.duplicate(true)


func _decode_breaker_state(
	snapshot: Dictionary,
	activity: Dictionary,
	activity_generation: int
	) -> Dictionary:
	var state: Variant = &"unavailable"
	var tactic_generation := activity_generation
	var breaker: Variant = snapshot.get("breaker_feint", null)
	if breaker is Dictionary and not (breaker as Dictionary).is_empty():
		if StringName((breaker as Dictionary).get("tactic_id", &"")) != BREAKER_FEINT_TACTIC_ID:
			return {"accepted": false, "reason": &"invalid_breaker_snapshot"}
		state = (breaker as Dictionary).get("state_id", &"")
		var generation_variant: Variant = (breaker as Dictionary).get("generation", -1)
		if (
			not generation_variant is int
			or int(generation_variant) < 0
			or int(generation_variant) > MAX_SAFE_GENERATION
		):
			return {"accepted": false, "reason": &"invalid_breaker_snapshot"}
		tactic_generation = int(generation_variant)
	elif StringName(activity.get("opening_tactic_id", &"")) == BREAKER_FEINT_TACTIC_ID:
		state = activity.get("opening_tactic_state_id", &"")
	elif StringName(snapshot.get("component_id", &"")) == CONTENT_COMPONENT_ID:
		return {"accepted": false, "reason": &"missing_breaker_snapshot"}
	else:
		return {"accepted": true, "available": false, "state_id": &"unavailable"}
	if not state is StringName or StringName(state) not in BREAKER_STATES:
		return {"accepted": false, "reason": &"invalid_breaker_snapshot"}
	if StringName(state) not in [&"idle", &"standby"] and tactic_generation != activity_generation:
		return {"accepted": false, "reason": &"stale_breaker_snapshot"}
	return {"accepted": true, "available": true, "state_id": StringName(state)}


func _emit_transitions(decoded: Dictionary) -> void:
	var activity_id: StringName = decoded.activity_id
	var state: StringName = decoded.state
	var wave_index := int(decoded.wave_index)
	if state == &"active" and bool(decoded.wave_active) \
			and (wave_index != _last_wave_index or _last_state != &"active"):
		_emit_cue(&"station_defense_wave_started", activity_id, 1.0)
	_emit_tactic_transition(decoded)
	for asset_variant in decoded.assets as Array:
		if not asset_variant is Dictionary:
			continue
		var asset := asset_variant as Dictionary
		var handle := asset.get("handle", {}) as Dictionary
		var key := str(handle.get("asset_id", &""))
		var damage_count := int(asset.get("damage_event_count", 0))
		var destroyed := bool(asset.get("destroyed", false))
		var prior := int(_last_asset_damage.get(key, 0))
		if destroyed and (prior < 3):
			if prior < 2:
				_emit_cue(&"station_defense_asset_critical", activity_id, 1.0)
			_emit_cue(&"station_defense_asset_destroyed", activity_id, 1.0)
		elif damage_count > 0 and prior == 0:
			_emit_cue(&"station_defense_asset_danger", activity_id, 0.5)
		elif damage_count == 0 and prior > 0 and not destroyed:
			_emit_cue(&"station_defense_asset_recovered", activity_id, 0.75)
		elif damage_count == 0 and not _last_asset_damage.has(key):
			_emit_cue(&"station_defense_asset_safe", activity_id, 0.25)
		_last_asset_damage[key] = 3 if destroyed else damage_count
	if state == &"completed" and _last_state != &"completed":
		_emit_cue(&"station_defense_completed", activity_id, 1.0)
	elif state in [&"failed", &"aborted", &"timed_out"] and _last_state not in [&"failed", &"aborted", &"timed_out"]:
		_emit_cue(&"station_defense_aborted", activity_id, 1.0)
	_last_state = state
	_last_wave_index = wave_index


func _emit_tactic_transition(decoded: Dictionary) -> void:
	var activity_id: StringName = decoded.activity_id
	var activity_key := str(activity_id)
	var generation := int(decoded.generation)
	var fenced_generation := int(_tactic_generation_by_activity.get(activity_key, -1))
	if generation < fenced_generation:
		return
	if generation > fenced_generation:
		_tactic_generation_by_activity[activity_key] = generation
		_tactic_state_by_activity[activity_key] = &"idle"
		_seen_tactic_cues_by_activity[activity_key] = {}

	var prior_state: StringName = _tactic_state_by_activity.get(activity_key, &"idle")
	var tactic_state := _decode_tactic_state(decoded, prior_state)
	var cue_id: StringName = &""
	var intensity := 0.0
	match tactic_state:
		&"breaker_inbound":
			cue_id = &"station_defense_breaker_inbound"
			intensity = 0.7
		&"breaker_active":
			cue_id = &"station_defense_breaker_active"
			intensity = 0.9
		&"breaker_interrupted":
			cue_id = &"station_defense_breaker_interrupted"
			intensity = 0.85
		&"inbound":
			cue_id = &"station_defense_pincer_inbound"
			intensity = 0.7
		&"active":
			cue_id = &"station_defense_crossfire_active"
			intensity = 1.0
		&"broken":
			cue_id = &"station_defense_pincer_wing_broken"
			intensity = 0.85
		&"cleared":
			if prior_state in [
				&"breaker_inbound", &"breaker_active", &"breaker_interrupted",
				&"inbound", &"active", &"broken",
			]:
				cue_id = &"station_defense_pincer_cleared"
				intensity = 0.65

	var seen := _seen_tactic_cues_by_activity.get(activity_key, {}) as Dictionary
	if not cue_id.is_empty() and not seen.has(cue_id):
		seen[cue_id] = true
		_seen_tactic_cues_by_activity[activity_key] = seen
		_emit_cue(cue_id, activity_id, intensity)
	_tactic_state_by_activity[activity_key] = tactic_state


func _decode_tactic_state(decoded: Dictionary, prior_state: StringName) -> StringName:
	var state: StringName = decoded.state
	var wave_id: StringName = decoded.wave_id
	if state == &"active" and wave_id == PINCER_WAVE_ID:
		if bool(decoded.breaker_authoritative):
			match StringName(decoded.breaker_state):
				&"inbound":
					return &"breaker_inbound"
				&"active":
					return &"breaker_active"
				&"interrupted":
					return &"breaker_interrupted"
				&"transitioned":
					return _decode_live_pincer_state(decoded)
				&"completed", &"failed", &"aborted", &"timed_out":
					return &"cleared"
				_:
					return &"idle"
		if not bool(decoded.wave_active):
			return &"inbound"
		return _decode_live_pincer_state(decoded)
	if prior_state in [
		&"breaker_inbound", &"breaker_active", &"breaker_interrupted",
		&"inbound", &"active", &"broken",
	]:
		return &"cleared"
	return &"idle"


func _decode_live_pincer_state(decoded: Dictionary) -> StringName:
	var active_ids: Array[StringName] = []
	for handle_variant in decoded.active_hostile_handles as Array:
		if handle_variant is Dictionary:
			active_ids.append(StringName((handle_variant as Dictionary).get("hostile_id", &"")))
	var close_active := PINCER_CLOSE_HOSTILE_ID in active_ids
	var outer_active := PINCER_OUTER_HOSTILE_ID in active_ids
	if close_active and outer_active:
		return &"active"
	if close_active or outer_active:
		return &"broken"
	return &"cleared"


func _emit_cue(cue_id: StringName, activity_id: StringName, intensity: float) -> void:
	var adjusted_intensity := clampf(
		intensity * (0.75 if _reduced_dynamic_range else 1.0),
		0.0,
		1.0
	)
	_emitted_cue_count += 1
	_last_cue_id = cue_id
	semantic_activity_cue_emitted.emit(cue_id, activity_id, adjusted_intensity)
	semantic_cue_emitted.emit(&"station_defense", cue_id, adjusted_intensity, Vector3.ZERO)
	if _audio_director != null and is_instance_valid(_audio_director):
		_audio_director.call(
			&"_on_semantic_cue",
			&"station_defense",
			cue_id,
			adjusted_intensity,
			Vector3.ZERO
		)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
