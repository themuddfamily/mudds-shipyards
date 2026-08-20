extends SceneTree

const ContractScript := preload("res://scripts/control/flight_feel_tuning_contract.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_default_profile_and_audit()
	_test_profile_validation_boundaries()
	_test_trial_human_gate_and_acceptance()
	_test_trial_thresholds_and_detachment()
	_finish()


func _test_default_profile_and_audit() -> void:
	var contract = ContractScript.new()
	var profile := contract.default_profile()
	var report := contract.validate_profile(profile)
	var audit := contract.audit()
	_check(
		bool(report.accepted)
			and report.reason == &"profile_valid"
			and bool(audit.valid)
			and audit.schema_version == 1
			and audit.policy_version == &"flight_feel_tuning_contract_v1",
		"current flight defaults satisfy the detached tuning schema"
	)
	_check(
		is_equal_approx(float(profile.mouse_sensitivity), 0.0022)
			and profile.maximum_mouse_turn_degrees == 18.0
			and profile.thrust_acceleration == 34.0
			and profile.brake_acceleration == 48.0
			and profile.maximum_chase_camera_rotation_lag_degrees == 8.0
			and profile.landing_completion_angle_degrees == 1.5,
		"the contract freezes the existing control, chase, and landing defaults"
	)
	_check(
		audit.human_gate == &"explicit_player_review_required"
			and audit.purity == {
				"reads_input": false,
				"reads_scene": false,
				"advances_clock": false,
				"moves_camera": false,
				"moves_ship": false,
			}
			and _all_false(audit.authority),
		"audit declares the player review boundary and zero runtime authority"
	)


func _test_profile_validation_boundaries() -> void:
	var contract = ContractScript.new()
	var missing := contract.default_profile()
	missing.erase(&"camera_fov")
	_check(
		contract.validate_profile(missing).reason == &"invalid_profile",
		"missing tuning fields fail the exact profile schema"
	)
	var extra := contract.default_profile()
	extra[&"physics_delta"] = 1.0 / 60.0
	_check(
		contract.validate_profile(extra).reason == &"invalid_profile",
		"a hidden delta or unknown tuning field cannot enter the contract"
	)
	var inverted := contract.default_profile()
	inverted.minimum_chase_camera_distance = 12.0
	inverted.maximum_chase_camera_distance = 12.0
	_check(
		(contract.validate_profile(inverted).errors as PackedStringArray).has(
			&"chase_camera_distance_order_invalid"
		),
		"the chase camera requires a positive requested-distance range"
	)
	var weak_brake := contract.default_profile()
	weak_brake.brake_acceleration = weak_brake.thrust_acceleration - 0.001
	_check(
		(contract.validate_profile(weak_brake).errors as PackedStringArray).has(
			&"braking_must_match_or_exceed_thrust"
		),
		"braking cannot be tuned below thrust without an explicit failed gate"
	)


func _test_trial_human_gate_and_acceptance() -> void:
	var contract = ContractScript.new()
	var profile := contract.default_profile()
	var trial := _trial(false)
	var automated := contract.evaluate_trial(profile, trial)
	_check(
		not bool(automated.accepted)
			and automated.reason == &"human_review_required",
		"clean automated metrics remain pending until a player records review"
	)
	trial.human_reviewed = true
	var accepted := contract.evaluate_trial(profile, trial)
	_check(
		bool(accepted.accepted)
			and accepted.reason == &"trial_accepted"
			and accepted.profile == profile
			and accepted.trial == trial,
		"a reviewed trial inside every deterministic envelope is accepted"
	)


func _test_trial_thresholds_and_detachment() -> void:
	var contract = ContractScript.new()
	var profile := contract.default_profile()
	var trial := _trial(true)
	trial.camera_lag_degrees = 8.001
	var rejected := contract.evaluate_trial(profile, trial)
	_check(
		not bool(rejected.accepted)
			and rejected.reason == &"trial_threshold_exceeded"
			and (rejected.errors as PackedStringArray).has(&"camera_lag_exceeds_profile"),
		"camera lag above the frozen profile limit returns structured red"
	)
	var clean := _trial(true)
	var first := contract.evaluate_trial(profile, clean)
	profile.camera_fov = 99.0
	clean.camera_fov = 99.0
	var second := contract.evaluate_trial(contract.default_profile(), _trial(true))
	_check(
		first == second
			and first.reason == &"trial_accepted",
		"evaluation is deterministic and returned profile/trial data is detached"
	)
	var audit := contract.audit()
	(audit.authority as Dictionary).physics = true
	_check(
		not bool(contract.audit().authority.physics),
		"caller mutation cannot forge runtime authority in a fresh audit"
	)


func _trial(human_reviewed: bool) -> Dictionary:
	return {
		&"sample_rate_hz": 60,
		&"sampling_rate_heading_error_degrees": 0.0,
		&"sampling_rate_attitude_error_degrees": 0.0,
		&"camera_nose_alignment_error_degrees": 0.0,
		&"camera_lag_degrees": 8.0,
		&"camera_bank_degrees": 4.5,
		&"mouse_full_axis_response_degrees": 18.0,
		&"hover_vertical_residual_meters_per_second": 0.0,
		&"landing_speed_meters_per_second": 0.5,
		&"landing_angle_degrees": 0.5,
		&"braking_distance_overshoot_meters": 0.0,
		&"throttle_release_settle_seconds": 0.2,
		&"human_reviewed": human_reviewed,
	}


func _all_false(value: Dictionary) -> bool:
	for key in value:
		if value[key] != false:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
	else:
		print("PASS: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("FLIGHT_FEEL_TUNING_CONTRACT_TEST_PASS: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	push_error(
		"FLIGHT_FEEL_TUNING_CONTRACT_TEST_FAIL: %d/%d failed"
		% [_failures.size(), _assertions]
	)
	quit(1)
