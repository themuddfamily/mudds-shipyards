class_name FlightFeelTuningContract
extends RefCounted

## Detached contract for the player-led flight-feel pass.
##
## This freezes the bounded control/camera/landing envelope and evaluates one
## caller-supplied trial record. It never samples Input, reads a ship, advances
## a clock, moves a camera, or claims that a headless run is human evidence.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"flight_feel_tuning_contract_v1"
const TUNING_VERSION: StringName = &"vertical_slice_flight_feel_v1"
const HUMAN_REVIEW_REQUIRED_REASON: StringName = &"human_review_required"

const _PROFILE_KEYS := [
	&"mouse_sensitivity",
	&"maximum_mouse_turn_degrees",
	&"yaw_speed_degrees",
	&"pitch_speed_degrees",
	&"roll_speed_degrees",
	&"throttle_response",
	&"thrust_acceleration",
	&"brake_acceleration",
	&"passive_drag",
	&"flight_assist_strength",
	&"visual_bank_degrees",
	&"chase_camera_rotation_response",
	&"maximum_chase_camera_rotation_lag_degrees",
	&"maximum_chase_camera_bank_degrees",
	&"chase_camera_zoom_response",
	&"minimum_chase_camera_distance",
	&"maximum_chase_camera_distance",
	&"chase_camera_zoom_step",
	&"camera_fov",
	&"hover_upright_response",
	&"landing_maximum_speed",
	&"landing_completion_angle_degrees",
	&"landing_completion_distance",
	&"landing_brake_complete_speed",
]

const _TRIAL_KEYS := [
	&"sample_rate_hz",
	&"sampling_rate_heading_error_degrees",
	&"sampling_rate_attitude_error_degrees",
	&"camera_nose_alignment_error_degrees",
	&"camera_lag_degrees",
	&"camera_bank_degrees",
	&"mouse_full_axis_response_degrees",
	&"hover_vertical_residual_meters_per_second",
	&"landing_speed_meters_per_second",
	&"landing_angle_degrees",
	&"braking_distance_overshoot_meters",
	&"throttle_release_settle_seconds",
	&"human_reviewed",
]

const _COMMON_AUTHORITY_KEYS := [
	&"renderer", &"gameplay", &"streaming", &"save", &"network", &"physics",
	&"world_generation", &"terrain_generation", &"collision_generation",
	&"origin_shift", &"weather_clock", &"audio",
]

const _PROFILE_BOUNDS := {
	&"mouse_sensitivity": [0.0002, 0.02],
	&"maximum_mouse_turn_degrees": [1.0, 45.0],
	&"yaw_speed_degrees": [10.0, 180.0],
	&"pitch_speed_degrees": [10.0, 180.0],
	&"roll_speed_degrees": [10.0, 240.0],
	&"throttle_response": [1.0, 30.0],
	&"thrust_acceleration": [1.0, 80.0],
	&"brake_acceleration": [1.0, 80.0],
	&"passive_drag": [0.1, 20.0],
	&"flight_assist_strength": [0.1, 12.0],
	&"visual_bank_degrees": [0.0, 30.0],
	&"chase_camera_rotation_response": [1.0, 30.0],
	&"maximum_chase_camera_rotation_lag_degrees": [0.0, 12.0],
	&"maximum_chase_camera_bank_degrees": [0.0, 12.0],
	&"chase_camera_zoom_response": [1.0, 30.0],
	&"minimum_chase_camera_distance": [6.0, 20.0],
	&"maximum_chase_camera_distance": [12.0, 36.0],
	&"chase_camera_zoom_step": [0.25, 4.0],
	&"camera_fov": [55.0, 110.0],
	&"hover_upright_response": [0.1, 12.0],
	&"landing_maximum_speed": [1.0, 40.0],
	&"landing_completion_angle_degrees": [0.1, 5.0],
	&"landing_completion_distance": [0.05, 1.0],
	&"landing_brake_complete_speed": [0.1, 10.0],
}

const _TRIAL_LIMITS := {
	&"sampling_rate_heading_error_degrees": 0.12,
	&"sampling_rate_attitude_error_degrees": 0.12,
	&"camera_nose_alignment_error_degrees": 0.5,
	&"hover_vertical_residual_meters_per_second": 0.25,
	&"braking_distance_overshoot_meters": 0.5,
	&"throttle_release_settle_seconds": 0.5,
}

const _DEFAULT_PROFILE := {
	&"mouse_sensitivity": 0.0022,
	&"maximum_mouse_turn_degrees": 18.0,
	&"yaw_speed_degrees": 72.0,
	&"pitch_speed_degrees": 72.0,
	&"roll_speed_degrees": 108.0,
	&"throttle_response": 10.0,
	&"thrust_acceleration": 34.0,
	&"brake_acceleration": 48.0,
	&"passive_drag": 2.8,
	&"flight_assist_strength": 5.8,
	&"visual_bank_degrees": 13.0,
	&"chase_camera_rotation_response": 7.0,
	&"maximum_chase_camera_rotation_lag_degrees": 8.0,
	&"maximum_chase_camera_bank_degrees": 4.583662361710865,
	&"chase_camera_zoom_response": 9.0,
	&"minimum_chase_camera_distance": 9.0,
	&"maximum_chase_camera_distance": 24.0,
	&"chase_camera_zoom_step": 1.5,
	&"camera_fov": 72.0,
	&"hover_upright_response": 2.0,
	&"landing_maximum_speed": 20.0,
	&"landing_completion_angle_degrees": 1.5,
	&"landing_completion_distance": 0.16,
	&"landing_brake_complete_speed": 1.5,
}


## Returns the current HeroShip defaults as a detached profile. The values are
## copied here so the player-led review can be recorded independently of a live
## scene and compared against later tuning without mutating the ship.
func default_profile() -> Dictionary:
	return _DEFAULT_PROFILE.duplicate(true)


## Validates one exact profile and returns a detached normalized report.
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
		var minimum_distance := float(profile.minimum_chase_camera_distance)
		var maximum_distance := float(profile.maximum_chase_camera_distance)
		if maximum_distance <= minimum_distance:
			errors.append("chase_camera_distance_order_invalid")
		if float(profile.brake_acceleration) < float(profile.thrust_acceleration):
			errors.append("braking_must_match_or_exceed_thrust")
		if float(profile.landing_brake_complete_speed) \
				>= float(profile.landing_maximum_speed):
			errors.append("landing_brake_speed_not_below_limit")
	return {
		"accepted": errors.is_empty(),
		"reason": &"profile_valid" if errors.is_empty() else &"invalid_profile",
		"errors": errors.duplicate(),
		"profile": profile.duplicate(true),
	}.duplicate(true)


## Evaluates one player-led trial. Automated tolerances are deterministic, but
## acceptance still requires the caller to explicitly record human review.
func evaluate_trial(profile: Dictionary, trial: Dictionary) -> Dictionary:
	var profile_result := validate_profile(profile)
	if not bool(profile_result.get("accepted", false)):
		return _trial_result(false, &"invalid_profile", {
			"profile_errors": profile_result.get("errors", PackedStringArray()),
		})
	if not _has_exact_keys(trial, _TRIAL_KEYS):
		return _trial_result(false, &"trial_schema_mismatch")
	var errors := PackedStringArray()
	for key: StringName in _TRIAL_KEYS:
		if key == &"human_reviewed":
			if not (trial[key] is bool):
				errors.append("human_reviewed_not_bool")
			continue
		var value = trial[key]
		if not (value is float or value is int):
			errors.append("%s_not_numeric" % key)
			continue
		if not is_finite(float(value)) or float(value) < 0.0:
			errors.append("%s_invalid" % key)
	if errors.is_empty():
		var sample_rate := float(trial.sample_rate_hz)
		if sample_rate < 30.0 or sample_rate > 240.0:
			errors.append("sample_rate_out_of_bounds")
		for key: StringName in _TRIAL_LIMITS:
			if float(trial[key]) > float(_TRIAL_LIMITS[key]):
				errors.append("%s_exceeds_limit" % key)
		if float(trial.camera_lag_degrees) \
				> float(profile.maximum_chase_camera_rotation_lag_degrees):
			errors.append("camera_lag_exceeds_profile")
		if float(trial.camera_bank_degrees) \
				> float(profile.maximum_chase_camera_bank_degrees):
			errors.append("camera_bank_exceeds_profile")
		if float(trial.mouse_full_axis_response_degrees) \
				> float(profile.maximum_mouse_turn_degrees):
			errors.append("mouse_response_exceeds_profile")
		if float(trial.landing_speed_meters_per_second) \
				> float(profile.landing_maximum_speed):
			errors.append("landing_speed_exceeds_profile")
		if float(trial.landing_angle_degrees) \
				> float(profile.landing_completion_angle_degrees):
			errors.append("landing_angle_exceeds_profile")
	if not errors.is_empty():
		return _trial_result(false, &"trial_threshold_exceeded", {
			"errors": errors.duplicate(),
			"profile": profile.duplicate(true),
			"trial": trial.duplicate(true),
		})
	if not bool(trial.human_reviewed):
		return _trial_result(false, HUMAN_REVIEW_REQUIRED_REASON, {
			"profile": profile.duplicate(true),
			"trial": trial.duplicate(true),
		})
	return _trial_result(true, &"trial_accepted", {
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
		"purity": {
			"reads_input": false,
			"reads_scene": false,
			"advances_clock": false,
			"moves_camera": false,
			"moves_ship": false,
		},
		"authority": _zero_authority(),
	}.duplicate(true)


func _trial_result(accepted: bool, reason: StringName, data: Dictionary = {}) -> Dictionary:
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


func _zero_authority() -> Dictionary:
	var authority := {}
	for key: StringName in _COMMON_AUTHORITY_KEYS:
		authority[key] = false
	return authority
