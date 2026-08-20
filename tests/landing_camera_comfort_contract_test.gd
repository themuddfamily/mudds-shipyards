extends SceneTree

const ContractScript := preload("res://scripts/control/landing_camera_comfort_contract.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract = ContractScript.new()
	var profile := contract.default_profile()
	var audit := contract.audit()
	_check(
		contract.validate_profile(profile).accepted
			and audit.valid
			and audit.policy_version == &"landing_camera_comfort_contract_v1",
		"current camera and landing defaults satisfy the detached comfort schema"
	)
	_check(
		profile.camera_fov == 72.0
			and profile.maximum_chase_camera_rotation_lag_degrees == 8.0
			and profile.landing_capture_maximum_speed == 32.0
			and profile.landing_completion_speed == 1.5,
		"the contract freezes the authored chase and broad-assist values"
	)
	var trial := _trial(false)
	var pending := contract.evaluate_trial(profile, trial)
	_check(
		not pending.accepted and pending.reason == &"human_review_required",
		"deterministic metrics remain pending until a player records review"
	)
	trial.human_reviewed = true
	var accepted := contract.evaluate_trial(profile, trial)
	_check(
		accepted.accepted and accepted.reason == &"trial_accepted",
		"reviewed camera/landing metrics inside the envelope are accepted"
	)
	var lagging := _trial(true)
	lagging.camera_lag_peak_degrees = 8.01
	var lag_report := contract.evaluate_trial(profile, lagging)
	_check(
		not lag_report.accepted
			and (lag_report.errors as PackedStringArray).has(&"camera_lag_exceeds_profile"),
		"camera lag beyond the authored comfort ceiling returns structured red"
	)
	var mismatch := _trial(true)
	mismatch.report_matches_hud = false
	_check(
		contract.evaluate_trial(profile, mismatch).reason == &"landing_report_hud_mismatch",
		"a landing report that disagrees with the HUD cannot pass the human gate"
	)
	var invalid := profile.duplicate(true)
	invalid.maximum_chase_camera_distance = invalid.minimum_chase_camera_distance
	_check(
		contract.validate_profile(invalid).reason == &"invalid_profile",
		"an inverted chase-distance range fails closed"
	)
	_check(
		(audit.authority as Dictionary).landing == false
			and (audit.authority as Dictionary).camera == false
			and audit.human_gate == &"explicit_player_review_required",
		"audit records zero runtime authority and the explicit human boundary"
	)
	_finish()


func _trial(human_reviewed: bool) -> Dictionary:
	return {
		&"sample_rate_hz": 60,
		&"camera_lag_peak_degrees": 8.0,
		&"camera_bank_peak_degrees": 4.5,
		&"camera_distance_error_meters": 0.25,
		&"camera_comfort_score": 4.0,
		&"landing_capture_attempts": 3,
		&"landing_capture_successes": 3,
		&"landing_maximum_speed_meters_per_second": 31.0,
		&"landing_maximum_angle_degrees": 74.0,
		&"landing_braking_overshoot_meters": 0.25,
		&"landing_clarity_score": 4.0,
		&"report_matches_hud": true,
		&"human_reviewed": human_reviewed,
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("LANDING_CAMERA_COMFORT_CONTRACT_TEST_PASS: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	push_error(
		"LANDING_CAMERA_COMFORT_CONTRACT_TEST_FAIL: %d/%d failed"
		% [_failures.size(), _assertions]
	)
	quit(1)
