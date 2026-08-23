class_name FleetExpansionAudioBinding
extends RefCounted

## Audio-owned application seam for immutable fleet recipes. The caller supplies
## identity and the existing rig; this binding never owns flight or engine state.

const Profile := preload("res://scripts/audio/fleet_expansion_audio_profile.gd")
const ComponentDamageBinding := preload("res://scripts/audio/component_damage_audio_binding.gd")
const BomberPayloadBinding := preload("res://scripts/audio/bomber_payload_audio_binding.gd")
const RIG_PROFILE_BY_RECIPE := {
	&"bulwark_heavy_gunship": &"heavy_quad_freighter",
	&"cargo_craft": &"heavy_quad_freighter",
	&"bomber": &"standard_fighter",
	&"lightweight_interceptor": &"efficient_twin_recon",
}

var _rig: Node
var _ship_id: StringName = &""
var _profile_id: StringName = &""
var _reduced_dynamic_range := false
var _attached := false
var _generation := 0
var _applied_plan: Dictionary = {}
var _profile_cache: Dictionary = {}
var _plan_cache: Dictionary = {}
var _plan_build_count := 0
var _plan_apply_count := 0
var _baseline_player_count := -1
var _baseline_synthesis_generation := -1
var _damage_binding: RefCounted
var _payload_binding: Node

signal semantic_engine_cue_emitted(cue_id: StringName, intensity: float)


func bind(ship_id: StringName, rig: Node) -> Dictionary:
	if _attached:
		return _result(false, &"already_bound")
	if not Profile.get_profile_ids().has(ship_id):
		return _result(false, &"unknown_ship_profile")
	if rig == null or not rig.has_method(&"get_component_id") \
			or rig.call(&"get_component_id") != &"ship-audio-rig":
		return _result(false, &"foreign_audio_rig")
	if not rig.has_method(&"get_profile_id"):
		return _result(false, &"invalid_audio_rig")
	var expected_profile: StringName = RIG_PROFILE_BY_RECIPE[ship_id]
	if rig.call(&"get_profile_id") != expected_profile:
		return _result(false, &"rig_profile_mismatch")
	_rig = rig
	_ship_id = ship_id
	_profile_id = ship_id
	_attached = true
	if not _profile_cache.has(ship_id):
		_profile_cache[ship_id] = Profile.get_profile(ship_id)
	if _baseline_player_count < 0 and rig.has_method(&"get_performance_report"):
		_baseline_player_count = int(rig.call(&"get_performance_report").get("audio_player_count", -1))
	if _baseline_synthesis_generation < 0 and rig.has_method(&"get_synthesis_report"):
		_baseline_synthesis_generation = int(rig.call(&"get_synthesis_report").get("generation_count", -1))
	_apply_plan()
	_damage_binding = ComponentDamageBinding.new()
	var damage_result: Dictionary = _damage_binding.bind(rig)
	if not bool(damage_result.get("accepted", false)):
		_damage_binding = null
		_attached = false
		_rig = null
		_ship_id = &""
		_profile_id = &""
		_applied_plan.clear()
		return _result(false, &"damage_binding_failed")
	var payload_created := _payload_binding == null
	if payload_created:
		_payload_binding = BomberPayloadBinding.new()
		_payload_binding.semantic_engine_cue_emitted.connect(_on_payload_engine_cue)
	var payload_result: Dictionary = _payload_binding.attach(0 if payload_created else _generation)
	if payload_created and bool(payload_result.get("accepted", false)):
		for expected_generation in range(_generation):
			_payload_binding.detach()
			payload_result = _payload_binding.attach(expected_generation + 1)
	if not bool(payload_result.get("accepted", false)):
		_payload_binding.queue_free()
		_payload_binding = null
		_damage_binding.detach()
		_damage_binding = null
		_attached = false
		_rig = null
		_ship_id = &""
		_profile_id = &""
		_applied_plan.clear()
		return _result(false, &"payload_binding_failed")
	return _result(true, &"bound")


func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	if not _attached:
		return _result(false, &"not_bound")
	if _reduced_dynamic_range == enabled:
		return _result(true, &"mix_unchanged")
	_reduced_dynamic_range = enabled
	_apply_plan()
	if _payload_binding != null:
		_payload_binding.set_reduced_dynamic_range(enabled)
	return _result(true, &"mix_updated")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_bound")
	_attached = false
	_generation += 1
	if _damage_binding != null:
		_damage_binding.detach()
		_damage_binding = null
	if _payload_binding != null:
		_payload_binding.detach()
		_payload_binding.free()
		_payload_binding = null
	_rig = null
	_ship_id = &""
	_profile_id = &""
	_reduced_dynamic_range = false
	_applied_plan.clear()
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"ship_id": _ship_id,
		"profile_id": _profile_id,
		"reduced_dynamic_range": _reduced_dynamic_range,
		"applied_plan": _applied_plan.duplicate(true),
		"profile_cache_entries": _profile_cache.size(),
		"plan_cache_entries": _plan_cache.size(),
		"plan_build_count": _plan_build_count,
		"plan_apply_count": _plan_apply_count,
		"component_damage": _damage_binding.get_snapshot() if _damage_binding != null else {},
		"payload_audio": _payload_binding.get_snapshot() if _payload_binding != null else {},
		"audit": get_audit(),
		"authority": {"flight": false, "engine_state": false, "audio_playback": false},
	}.duplicate(true)


func present_component_damage(snapshot: Dictionary) -> Dictionary:
	if _damage_binding == null:
		return _result(false, &"not_bound")
	return _damage_binding.present_damage_snapshot(snapshot)


func present_payload_release(record: Dictionary) -> Dictionary:
	if _ship_id != &"bomber" or _payload_binding == null:
		return _result(false, &"payload_audio_not_supported")
	return _payload_binding.present_release_record(record)


func present_payload_abort(record: Dictionary) -> Dictionary:
	if _ship_id != &"bomber" or _payload_binding == null:
		return _result(false, &"payload_audio_not_supported")
	return _payload_binding.present_abort_record(record)


func _apply_plan() -> void:
	var cache_key := "%s|%s" % [_profile_id, "reduced" if _reduced_dynamic_range else "nominal"]
	if not _plan_cache.has(cache_key):
		var profile := _profile_cache.get(_profile_id, {}) as Dictionary
		if profile.is_empty():
			profile = Profile.get_profile(_profile_id)
		var attenuation := float(profile.get("reduced_dynamic_range_gain_db", 0.0)) if _reduced_dynamic_range else 0.0
		_plan_cache[cache_key] = {
			"engine_pitch_scale": float(profile.get("engine_pitch_scale", 1.0)),
			"idle_volume_db": float(profile.get("idle_volume_db", -15.0)) + attenuation,
			"load_volume_db": float(profile.get("load_volume_db", -10.5)) + attenuation,
			"boost_volume_db": float(profile.get("boost_volume_db", -7.0)) + attenuation,
			"load_throttle_range": profile.get("load_throttle_range", Vector2.ZERO),
			"boost_throttle_range": profile.get("boost_throttle_range", Vector2.ZERO),
		}.duplicate(true)
		_plan_build_count += 1
	_applied_plan = _plan_cache[cache_key]
	_plan_apply_count += 1


func get_audit() -> Dictionary:
	var current_player_count := -1
	var current_synthesis_generation := -1
	if is_instance_valid(_rig) and _rig.has_method(&"get_performance_report"):
		current_player_count = int(_rig.call(&"get_performance_report").get("audio_player_count", -1))
	if is_instance_valid(_rig) and _rig.has_method(&"get_synthesis_report"):
		current_synthesis_generation = int(_rig.call(&"get_synthesis_report").get("generation_count", -1))
	return {
		"valid": _plan_build_count <= 2 and _plan_apply_count >= 0,
		"plan_build_count": _plan_build_count,
		"plan_apply_count": _plan_apply_count,
		"plan_cache_entries": _plan_cache.size(),
		"player_count_stable": _baseline_player_count < 0 or current_player_count == _baseline_player_count,
		"resource_generation_stable": _baseline_synthesis_generation < 0 or current_synthesis_generation == _baseline_synthesis_generation,
		"baseline_player_count": _baseline_player_count,
		"current_player_count": current_player_count,
		"baseline_synthesis_generation": _baseline_synthesis_generation,
		"current_synthesis_generation": current_synthesis_generation,
	}.duplicate(true)


func _on_payload_engine_cue(cue_id: StringName, intensity: float) -> void:
	semantic_engine_cue_emitted.emit(cue_id, intensity)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
