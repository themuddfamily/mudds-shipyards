extends SceneTree

const Profile := preload("res://scripts/audio/fleet_expansion_audio_profile.gd")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var audit := Profile.audit()
	_check(bool(audit.valid), "fleet expansion audio profiles pass bounded audit")
	_check(Profile.get_profile_ids().size() == 4, "four expansion roles are represented")
	var roles := {}
	for profile_id: StringName in Profile.get_profile_ids():
		var profile := Profile.get_profile(profile_id)
		roles[profile.role] = true
		_check(float(profile.engine_pitch_scale) > 0.0 and float(profile.engine_pitch_scale) <= 1.5, "%s pitch is bounded" % profile_id)
		_check(float(profile.idle_volume_db) <= float(profile.load_volume_db) and float(profile.load_volume_db) <= float(profile.boost_volume_db), "%s gains rise by load" % profile_id)
		_check((profile.load_throttle_range as Vector2).x >= 0.0 and (profile.boost_throttle_range as Vector2).y <= 1.0, "%s throttle ranges are bounded" % profile_id)
		_check(float(profile.reduced_dynamic_range_gain_db) <= 0.0, "%s reduced-range mix is attenuation-only" % profile_id)
	_check(roles.size() == 4, "profile roles remain explicitly differentiated")
	for failure in _failures:
		push_error(failure)
	print("fleet_expansion_audio_profile_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
