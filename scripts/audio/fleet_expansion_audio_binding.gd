class_name FleetExpansionAudioBinding
extends RefCounted

## Audio-owned application seam for immutable fleet recipes. The caller supplies
## identity and the existing rig; this binding never owns flight or engine state.

const Profile := preload("res://scripts/audio/fleet_expansion_audio_profile.gd")
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
	_apply_plan()
	return _result(true, &"bound")


func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	if not _attached:
		return _result(false, &"not_bound")
	_reduced_dynamic_range = enabled
	_apply_plan()
	return _result(true, &"mix_updated")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_bound")
	_attached = false
	_generation += 1
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
		"authority": {"flight": false, "engine_state": false, "audio_playback": false},
	}.duplicate(true)


func _apply_plan() -> void:
	var profile := Profile.get_profile(_profile_id)
	var attenuation := float(profile.get("reduced_dynamic_range_gain_db", 0.0)) if _reduced_dynamic_range else 0.0
	_applied_plan = {
		"engine_pitch_scale": float(profile.get("engine_pitch_scale", 1.0)),
		"idle_volume_db": float(profile.get("idle_volume_db", -15.0)) + attenuation,
		"load_volume_db": float(profile.get("load_volume_db", -10.5)) + attenuation,
		"boost_volume_db": float(profile.get("boost_volume_db", -7.0)) + attenuation,
		"load_throttle_range": profile.get("load_throttle_range", Vector2.ZERO),
		"boost_throttle_range": profile.get("boost_throttle_range", Vector2.ZERO),
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
