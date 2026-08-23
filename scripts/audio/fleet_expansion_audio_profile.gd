class_name FleetExpansionAudioProfile
extends RefCounted

## Bounded preparation recipes for the existing ShipAudioRig mix contract.
## These values select presentation only; the rig remains the playback owner.

const PROFILE_IDS: Array[StringName] = [
	&"bulwark_heavy_gunship",
	&"cargo_craft",
	&"bomber",
	&"lightweight_interceptor",
]
const PROFILES := {
	&"bulwark_heavy_gunship": {
		"role": &"heavy_gunship", "engine_pitch_scale": 0.72,
		"idle_volume_db": -11.0, "load_volume_db": -6.5, "boost_volume_db": -3.5,
		"load_throttle_range": Vector2(0.04, 0.72), "boost_throttle_range": Vector2(0.18, 1.0),
		"reduced_dynamic_range_gain_db": -3.0,
	},
	&"cargo_craft": {
		"role": &"cargo", "engine_pitch_scale": 0.78,
		"idle_volume_db": -12.0, "load_volume_db": -7.5, "boost_volume_db": -4.5,
		"load_throttle_range": Vector2(0.03, 0.68), "boost_throttle_range": Vector2(0.22, 1.0),
		"reduced_dynamic_range_gain_db": -3.0,
	},
	&"bomber": {
		"role": &"bomber", "engine_pitch_scale": 0.88,
		"idle_volume_db": -13.0, "load_volume_db": -8.0, "boost_volume_db": -5.0,
		"load_throttle_range": Vector2(0.025, 0.76), "boost_throttle_range": Vector2(0.16, 1.0),
		"reduced_dynamic_range_gain_db": -3.5,
	},
	&"lightweight_interceptor": {
		"role": &"lightweight_interceptor", "engine_pitch_scale": 1.24,
		"idle_volume_db": -17.0, "load_volume_db": -12.0, "boost_volume_db": -8.0,
		"load_throttle_range": Vector2(0.02, 0.62), "boost_throttle_range": Vector2(0.10, 1.0),
		"reduced_dynamic_range_gain_db": -2.5,
	},
}


static func get_profile(profile_id: StringName) -> Dictionary:
	return (PROFILES.get(profile_id, {}) as Dictionary).duplicate(true)


static func get_profile_ids() -> Array[StringName]:
	return PROFILE_IDS.duplicate()


static func audit() -> Dictionary:
	var errors := PackedStringArray()
	var roles := {}
	for profile_id: StringName in PROFILE_IDS:
		var profile := get_profile(profile_id)
		if profile.is_empty():
			errors.append("missing profile %s" % profile_id)
			continue
		var role := StringName(profile.get("role", &""))
		if role.is_empty() or roles.has(role):
			errors.append("profile roles must be unique")
		roles[role] = true
		var pitch := float(profile.get("engine_pitch_scale", -1.0))
		if not is_finite(pitch) or pitch < 0.5 or pitch > 1.5:
			errors.append("engine pitch is outside ShipAudioRig bounds")
		for gain_key: StringName in [&"idle_volume_db", &"load_volume_db", &"boost_volume_db"]:
			var gain := float(profile.get(gain_key, INF))
			if not is_finite(gain) or gain < -24.0 or gain > 0.0:
				errors.append("%s gain is outside bounded mix range" % gain_key)
		if float(profile.load_volume_db) < float(profile.idle_volume_db) \
				or float(profile.boost_volume_db) < float(profile.load_volume_db):
			errors.append("engine gains must rise idle to load to boost")
		for range_key: StringName in [&"load_throttle_range", &"boost_throttle_range"]:
			var throttle_range := profile.get(range_key, Vector2(-1.0, -1.0)) as Vector2
			if throttle_range.x < 0.0 or throttle_range.x > throttle_range.y or throttle_range.y > 1.0:
				errors.append("%s is outside throttle bounds" % range_key)
		var reduced_gain := float(profile.get("reduced_dynamic_range_gain_db", INF))
		if not is_finite(reduced_gain) or reduced_gain > 0.0 or reduced_gain < -12.0:
			errors.append("reduced-range gain is outside bounded attenuation")
	return {"valid": errors.is_empty(), "errors": errors, "profile_count": PROFILE_IDS.size()}.duplicate(true)
