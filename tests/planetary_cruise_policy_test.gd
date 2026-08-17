extends SceneTree

const PolicyScript := preload("res://scripts/world/planetary_cruise_policy.gd")
const EXPECTED_ASSERTIONS := 24
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tuned_reference_leg_and_purity()
	_test_participation_and_speed_hints()
	_test_safety_gates_and_braking_envelope()
	_test_schema_bounds_and_determinism()
	_test_detachment_and_authority()
	_finish()


func _test_tuned_reference_leg_and_purity() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var audit := policy.audit()
	_check(
		policy is RefCounted
			and not (policy as Object).is_class("Node")
			and bool(audit.valid)
			and audit.policy_version == &"planetary_cruise_policy_v1",
		"the policy is a valid pure RefCounted contract"
	)
	_check(
		is_equal_approx(
			float(audit.ember_reference.distance_meters), 8_000_000.0
		)
			and float(audit.ember_reference.estimated_minutes) > 7.0
			and float(audit.ember_reference.estimated_minutes) < 8.0
			and is_equal_approx(
				float(audit.tuning.target_cruise_speed_meters_per_second),
				20_000.0
			),
		"the frozen default estimates the exact eight-megameter leg in minutes"
	)
	_check(
		audit.purity == {
			"caller_driven": true,
			"physics_delta_input": false,
			"clock_input": false,
			"retains_observations": false,
			"performs_obstacle_query": false,
			"moves_actor": false,
		},
		"audit freezes caller-driven evaluation with no hidden clock or query"
	)


func _test_participation_and_speed_hints() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var accelerating := policy.evaluate(_observation())
	_check(
		bool(accelerating.accepted)
			and accelerating.reason == &"cruise_participation_desired"
			and bool(accelerating.desired_cruise_participation)
			and accelerating.state == &"accelerate"
			and accelerating.desired_speed_meters_per_second == 20_000.0
			and accelerating.acceleration_hint_meters_per_second_squared == 500.0
			and not bool(accelerating.braking_requested),
		"a clear aligned piloted long leg requests bounded acceleration to cruise"
	)
	var cruising_input := _observation()
	cruising_input.closing_speed_meters_per_second = 20_000.0
	cruising_input.currently_participating = true
	var cruising := policy.evaluate(cruising_input)
	_check(
		cruising.state == &"cruise"
			and cruising.acceleration_hint_meters_per_second_squared == 0.0
			and not bool(cruising.braking_requested),
		"target closing speed produces a neutral cruise hint"
	)
	var overspeed_input := cruising_input.duplicate(true)
	overspeed_input.closing_speed_meters_per_second = 21_000.0
	var overspeed := policy.evaluate(overspeed_input)
	_check(
		overspeed.state == &"brake_to_cruise_speed"
			and bool(overspeed.desired_cruise_participation)
			and bool(overspeed.braking_requested)
			and overspeed.acceleration_hint_meters_per_second_squared == -750.0
			and overspeed.braking_acceleration_hint_meters_per_second_squared
				== 750.0,
		"overspeed retains participation but returns an explicit braking hint"
	)
	var receding_input := _observation()
	receding_input.closing_speed_meters_per_second = -100.0
	var receding := policy.evaluate(receding_input)
	_check(
		bool(receding.desired_cruise_participation)
			and receding.state == &"accelerate"
			and receding.current_braking_envelope_meters == 25_000.0,
		"a bounded receding sample may accelerate and never invents negative stopping distance"
	)


func _test_safety_gates_and_braking_envelope() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var at_target := _observation()
	at_target.closing_speed_meters_per_second = 20_000.0
	at_target.currently_participating = true
	var target_result := policy.evaluate(at_target)
	_check(
		is_equal_approx(
			float(target_result.current_braking_envelope_meters),
			331_666.6666666667
		)
			and float(target_result.required_verified_clearance_meters)
				== float(target_result.current_braking_envelope_meters),
		"braking envelope includes v-squared stopping, response travel, and fixed margin"
	)
	var engage := policy.evaluate(_observation())
	_check(
		is_equal_approx(
			float(engage.minimum_engage_distance_meters),
			731_666.6666666667
		)
			and engage.required_verified_clearance_meters
				== engage.minimum_engage_distance_meters
			and engage.required_destination_distance_meters
				== engage.minimum_engage_distance_meters,
		"fresh engagement requires room to accelerate to target and brake safely"
	)
	var too_near_to_engage := _observation()
	too_near_to_engage.distance_to_destination_meters = float(
		engage.minimum_engage_distance_meters
	)
	var engage_boundary := policy.evaluate(too_near_to_engage)
	too_near_to_engage.distance_to_destination_meters += 0.001
	_check(
		engage_boundary.reason == &"destination_braking_envelope"
			and not bool(engage_boundary.braking_requested)
			and bool(
				policy.evaluate(too_near_to_engage).desired_cruise_participation
			),
		"fresh engagement uses its inclusive distance without braking a stopped craft"
	)
	var gate_cases := [
		["destroyed", true, &"destroyed", false],
		["piloted", false, &"not_piloted", false],
		["landing_active", true, &"landing_active", false],
		["combat_active", true, &"combat_active", false],
		["clearance_verified", false, &"clearance_unverified", true],
		["obstacle_detected", true, &"obstacle_detected", true],
	]
	var gates_hold := true
	for gate_case in gate_cases:
		var sample := _observation()
		sample.closing_speed_meters_per_second = 1_000.0
		sample[gate_case[0]] = gate_case[1]
		var result := policy.evaluate(sample)
		gates_hold = gates_hold \
			and bool(result.accepted) \
			and result.reason == gate_case[2] \
			and not bool(result.desired_cruise_participation) \
			and bool(result.braking_requested) == gate_case[3]
	_check(
		gates_hold,
		"destroyed, piloting, landing, combat, clearance, and obstacle gates have deterministic priority"
	)
	var all_blocked := _observation()
	all_blocked.closing_speed_meters_per_second = 1_000.0
	all_blocked.destroyed = true
	all_blocked.piloted = false
	all_blocked.landing_active = true
	all_blocked.combat_active = true
	all_blocked.clearance_verified = false
	all_blocked.obstacle_detected = true
	var priority_result := policy.evaluate(all_blocked)
	_check(
		priority_result.reason == &"destroyed"
			and not bool(priority_result.braking_requested),
		"simultaneous blockers resolve to the frozen destroyed-first precedence"
	)
	var misaligned := _observation()
	misaligned.alignment_dot = 0.994
	var retained := misaligned.duplicate(true)
	retained.currently_participating = true
	var below_retain := retained.duplicate(true)
	below_retain.alignment_dot = 0.979
	_check(
		policy.evaluate(misaligned).reason == &"alignment_below_threshold"
			and bool(policy.evaluate(retained).desired_cruise_participation)
			and policy.evaluate(below_retain).reason
				== &"alignment_below_threshold",
		"exact engage and lower retain alignment thresholds provide deterministic hysteresis"
	)
	var insufficient := _observation()
	insufficient.closing_speed_meters_per_second = 1_000.0
	insufficient.verified_clearance_meters = float(
		engage.required_verified_clearance_meters
	) - 0.001
	var blocked := policy.evaluate(insufficient)
	_check(
		blocked.reason == &"insufficient_verified_clearance"
			and bool(blocked.braking_requested),
		"one millimetre-scale boundary witness below required clearance fails closed"
	)
	var near_destination := at_target.duplicate(true)
	near_destination.distance_to_destination_meters = float(
		target_result.current_braking_envelope_meters
	)
	var at_envelope := policy.evaluate(near_destination)
	near_destination.distance_to_destination_meters += 0.001
	_check(
		at_envelope.reason == &"destination_braking_envelope"
			and bool(at_envelope.braking_requested)
			and bool(policy.evaluate(near_destination).desired_cruise_participation),
		"the inclusive destination braking boundary disengages while just above remains eligible"
	)


func _test_schema_bounds_and_determinism() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var missing := _observation()
	missing.erase("combat_active")
	var extra := _observation()
	extra["delta"] = 1.0 / 60.0
	_check(
		policy.evaluate(missing).reason == &"observation_schema_mismatch"
			and policy.evaluate(extra).reason == &"observation_schema_mismatch"
			and not bool(policy.evaluate(extra).desired_cruise_participation),
		"missing fields and a forbidden physics delta are structured red"
	)
	var wrong_type := _observation()
	wrong_type.distance_to_destination_meters = 8_000_000
	var wrong_bool := _observation()
	wrong_bool.piloted = 1
	_check(
		policy.evaluate(wrong_type).reason
			== &"distance_to_destination_meters_not_float"
			and policy.evaluate(wrong_bool).reason == &"piloted_not_bool",
		"physical scalars and gates use an exact primitive schema"
	)
	var nonfinite := _observation()
	nonfinite.alignment_dot = NAN
	var too_fast := _observation()
	too_fast.closing_speed_meters_per_second = 100_000.001
	var bad_alignment := _observation()
	bad_alignment.alignment_dot = 1.001
	var bad_clearance := _observation()
	bad_clearance.verified_clearance_meters = -0.001
	_check(
		policy.evaluate(nonfinite).reason == &"alignment_dot_nonfinite"
			and policy.evaluate(too_fast).reason == &"closing_speed_out_of_bounds"
			and policy.evaluate(bad_alignment).reason == &"alignment_out_of_bounds"
			and policy.evaluate(bad_clearance).reason == &"clearance_out_of_bounds",
		"nonfinite and out-of-range observations reject without unsafe hints"
	)
	var baseline := policy.evaluate(_observation())
	var deterministic := true
	for _rate_hz in [30, 60, 120]:
		deterministic = deterministic \
			and policy.evaluate(_observation()) == baseline
	_check(
		deterministic,
		"evaluation is byte-for-byte deterministic at nominal caller physics rates because it accepts no delta"
	)
	var exact_maximum := _observation()
	exact_maximum.distance_to_destination_meters = 1_000_000_000.0
	exact_maximum.closing_speed_meters_per_second = 100_000.0
	exact_maximum.verified_clearance_meters = 1_000_000_000.0
	var above_distance := exact_maximum.duplicate(true)
	above_distance.distance_to_destination_meters += 0.001
	_check(
		bool(policy.evaluate(exact_maximum).accepted)
			and policy.evaluate(above_distance).reason
				== &"distance_to_destination_out_of_bounds",
		"exact finite maxima are inclusive and the first value above rejects"
	)


func _test_detachment_and_authority() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var input := _observation()
	var result := policy.evaluate(input)
	input.distance_to_destination_meters = 0.0
	(result.observation as Dictionary).distance_to_destination_meters = 1.0
	var fresh := policy.evaluate(_observation())
	_check(
		fresh.observation.distance_to_destination_meters == 8_000_000.0
			and bool(fresh.desired_cruise_participation),
		"input and returned nested dictionaries are detached from later evaluations"
	)
	var audit := policy.audit()
	(audit.tuning as Dictionary).target_cruise_speed_meters_per_second = 1.0
	(audit.authority as Dictionary).physics = true
	var fresh_audit := policy.audit()
	_check(
		fresh_audit.tuning.target_cruise_speed_meters_per_second == 20_000.0
			and not bool(fresh_audit.authority.physics),
		"caller mutation cannot retune policy or forge authority evidence"
	)
	var authority := fresh_audit.authority as Dictionary
	var exact_zero := authority.size() == COMMON_AUTHORITY_KEYS.size()
	for key in COMMON_AUTHORITY_KEYS:
		exact_zero = exact_zero and authority.has(key) \
			and authority[key] is bool and not bool(authority[key])
	_check(
		exact_zero,
		"audit publishes the exact common twelve-key zero-authority roster"
	)
	_check(
		fresh_audit.adjacent_authority == {
			"ship_control": false,
			"throttle_input": false,
			"node_movement": false,
			"collision_query": false,
			"clearance_proof": false,
			"landing_decision": false,
			"combat_decision": false,
			"streaming_decision": false,
			"reward": false,
		},
		"policy explicitly owns no ship, collision, landing, combat, streaming, or reward decision"
	)


func _observation() -> Dictionary:
	return {
		"distance_to_destination_meters": 8_000_000.0,
		"closing_speed_meters_per_second": 0.0,
		"alignment_dot": 1.0,
		"verified_clearance_meters": 8_000_000.0,
		"clearance_verified": true,
		"obstacle_detected": false,
		"currently_participating": false,
		"piloted": true,
		"destroyed": false,
		"landing_active": false,
		"combat_active": false,
	}


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion count mismatch: expected %d, got %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("PLANETARY_CRUISE_POLICY_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	push_error(
		"PLANETARY_CRUISE_POLICY_TEST_FAILED (%d failures / %d assertions)"
		% [_failures.size(), _assertions]
	)
	for failure in _failures:
		push_error("  - %s" % failure)
	quit(1)
