class_name LandingCameraComfortContract
extends RefCounted

## Detached acceptance contract for the player-led flight/landing comfort pass.
##
## This is an evidence boundary, not a camera, ship, berth, or input owner.
## A packaged-build run submits one profile and one trial record; deterministic
## limits catch regressions while the explicit review flag preserves the human
## tuning gate in ROADMAP item 578.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"landing_camera_comfort_contract_v1"
const TUNING_VERSION: StringName = &"packaged_flight_landing_comfort_v1"
const HUMAN_REVIEW_REQUIRED_REASON: StringName = &"human_review_required"

const _PROFILE_KEYS := [
	&"camera_fov",
	&"chase_camera_rotation_response",
	&"maximum_chase_camera_rotation_lag_degrees",
	&"maximum_chase_camera_bank_degrees",
	&"chase_camera_zoom_response",
	&"minimum_chase_camera_distance",
	&"maximum_chase_camera_distance",
	&"landing_capture_maximum_speed",
	&"landing_capture_maximum_tilt_degrees",
	&"landing_brake_acceleration",
	&"landing_completion_speed",
	&"landing_completion_angle_degrees",
	&"landing_completion_distance_meters",
]

const _TRIAL_KEYS := [
	&"sample_rate_hz",
	&"camera_lag_peak_degrees",
	&"camera_bank_peak_degrees",
	&"camera_distance_error_meters",
	&"camera_comfort_score",
	&"landing_capture_attempts",
	&"landing_capture_successes",
	&"landing_maximum_speed_meters_per_second",
	&"landing_maximum_angle_degrees",
	&"landing_braking_overshoot_meters",
	&"landing_clarity_score",
	&"report_matches_hud",
	&"human_reviewed",
]

const _PROFILE_BOUNDS := {
	&"camera_fov": [55.0, 110.0],
	&"chase_camera_rotation_response": [1.0, 30.0],
	&"maximum_chase_camera_rotation_lag_degrees": [0.0, 12.0],
	&"maximum_chase_camera_bank_degrees": [0.0, 12.0],
	&"chase_camera_zoom_response": [1.0, 30.0],
	&"minimum_chase_camera_distance": [6.0, 20.0],
	&"maximum_chase_camera_distance": [12.0, 36.0],
	&"landing_capture_maximum_speed": [1.0, 80.0],
	&"landing_capture_maximum_tilt_degrees": [1.0, 89.0],
	&"landing_brake_acceleration": [1.0, 80.0],
	&"landing_completion_speed": [0.1, 10.0],
	&"landing_completion_angle_degrees": [0.1, 5.0],
	&"landing_completion_distance_meters": [0.05, 1.0],
}

const _TRIAL_LIMITS := {
	&"camera_lag_peak_degrees": 12.0,
	&"camera_bank_peak_degrees": 12.0,
	&"camera_distance_error_meters": 2.0,
	&"landing_braking_overshoot_meters": 0.5,
}

const _DEFAULT_PROFILE := {
	&"camera_fov": 72.0,
	&"chase_camera_rotation_response": 7.0,
	&"maximum_chase_camera_rotation_lag_degrees": 8.0,
	&"maximum_chase_camera_bank_degrees": 4.583662361710865,
	&"chase_camera_zoom_response": 9.0,
	&"minimum_chase_camera_distance": 9.0,
	&"maximum_chase_camera_distance": 24.0,
	&"landing_capture_maximum_speed": 32.0,
	&"landing_capture_maximum_tilt_degrees": 75.0,
	&"landing_brake_acceleration": 48.0,
	&"landing_completion_speed": 1.5,
	&"landing_completion_angle_degrees": 1.5,
	&"landing_completion_distance_meters": 0.16,
}


func default_profile() -> Dictionary:
	return _DEFAULT_PROFILE.duplicate(true)


func validate_profile(profile: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	if not _has_exact_keys(profile, _PROFILE_KEYS):
		errors.append("profile_schema_mismatch")
	for key: StringName in _PROFILE_KEYS:
		if not profile.has(key):
			continue
		var value = profile[key]
		if not (value is float or value is int):
			errors.append("%s_not_numeric" % key)
			continue
		var numeric := float(value)
		if not is_finite(numeric):
			errors.append("%s_nonfinite" % key)
			continue
		var bounds := _PROFILE_BOUNDS[key] as Array
		if numeric < float(bounds[0]) or numeric > float(bounds[1]):
			errors.append("%s_out_of_bounds" % key)
	if errors.is_empty():
		if float(profile.maximum_chase_camera_distance) <= float(profile.minimum_chase_camera_distance):
			errors.append("chase_camera_distance_order_invalid")
		if float(profile.landing_brake_acceleration) < 1.0:
			errors.append("landing_brake_acceleration_invalid")
		if float(profile.landing_completion_speed) >= float(profile.landing_capture_maximum_speed):
			errors.append("landing_completion_speed_not_below_capture_limit")
	return {
		"accepted": errors.is_empty(),
		"reason": &"profile_valid" if errors.is_empty() else &"invalid_profile",
		"errors": errors.duplicate(),
		"profile": profile.duplicate(true),
	}.duplicate(true)


func evaluate_trial(profile: Dictionary, trial: Dictionary) -> Dictionary:
	var profile_result := validate_profile(profile)
	if not bool(profile_result.get("accepted", false)):
		return _result(false, &"invalid_profile", {
			"profile_errors": profile_result.get("errors", PackedStringArray()),
		})
	if not _has_exact_keys(trial, _TRIAL_KEYS):
		return _result(false, &"trial_schema_mismatch")
	var errors := PackedStringArray()
	for key: StringName in _TRIAL_KEYS:
		if key == &"human_reviewed" or key == &"report_matches_hud":
			if not (trial[key] is bool):
				errors.append("%s_not_bool" % key)
			continue
		var value = trial[key]
		if not (value is float or value is int):
			errors.append("%s_not_numeric" % key)
			continue
		if not is_finite(float(value)) or float(value) < 0.0:
			errors.append("%s_invalid" % key)
	if errors.is_empty():
		if float(trial.sample_rate_hz) < 30.0 or float(trial.sample_rate_hz) > 240.0:
			errors.append("sample_rate_out_of_bounds")
		for key: StringName in _TRIAL_LIMITS:
			if float(trial[key]) > float(_TRIAL_LIMITS[key]):
				errors.append("%s_exceeds_limit" % key)
		if float(trial.camera_lag_peak_degrees) > float(profile.maximum_chase_camera_rotation_lag_degrees):
			errors.append("camera_lag_exceeds_profile")
		if float(trial.camera_bank_peak_degrees) > float(profile.maximum_chase_camera_bank_degrees):
			errors.append("camera_bank_exceeds_profile")
		if float(trial.landing_maximum_speed_meters_per_second) > float(profile.landing_capture_maximum_speed):
			errors.append("landing_speed_exceeds_profile")
		if float(trial.landing_maximum_angle_degrees) > float(profile.landing_capture_maximum_tilt_degrees):
			errors.append("landing_angle_exceeds_profile")
		if int(trial.landing_capture_successes) > int(trial.landing_capture_attempts):
			errors.append("landing_successes_exceed_attempts")
		if int(trial.landing_capture_attempts) < 1:
			errors.append("landing_attempts_missing")
		if float(trial.camera_comfort_score) < 1.0 or float(trial.camera_comfort_score) > 5.0:
			errors.append("camera_comfort_score_out_of_bounds")
		if float(trial.landing_clarity_score) < 1.0 or float(trial.landing_clarity_score) > 5.0:
			errors.append("landing_clarity_score_out_of_bounds")
	if not errors.is_empty():
		return _result(false, &"trial_threshold_exceeded", {
			"errors": errors.duplicate(),
			"profile": profile.duplicate(true),
			"trial": trial.duplicate(true),
		})
	if not bool(trial.report_matches_hud):
		return _result(false, &"landing_report_hud_mismatch", {
			"profile": profile.duplicate(true),
			"trial": trial.duplicate(true),
		})
	if not bool(trial.human_reviewed):
		return _result(false, HUMAN_REVIEW_REQUIRED_REASON, {
			"profile": profile.duplicate(true),
			"trial": trial.duplicate(true),
		})
	return _result(true, &"trial_accepted", {
		"profile": profile.duplicate(true),
		"trial": trial.duplicate(true),
	})


func audit() -> Dictionary:
	return {
		"valid": true,
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"tuning_version": TUNING_VERSION,
		"profile_keys": _PROFILE_KEYS.duplicate(),
		"trial_keys": _TRIAL_KEYS.duplicate(),
		"profile_bounds": _PROFILE_BOUNDS.duplicate(true),
		"trial_limits": _TRIAL_LIMITS.duplicate(true),
		"human_gate": &"explicit_player_review_required",
		"authority": {
			"camera": false,
			"input": false,
			"ship": false,
			"landing": false,
			"berth": false,
			"game_flow": false,
		},
		"purity": {
			"reads_input": false,
			"reads_scene": false,
			"advances_clock": false,
			"moves_camera": false,
			"moves_ship": false,
		},
	}.duplicate(true)


func _result(accepted: bool, reason: StringName, data: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
	}
	for key in data:
		result[key] = data[key]
	return result.duplicate(true)


func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true
