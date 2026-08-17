extends SceneTree

const PolicyScript := preload("res://scripts/world/planetary_cruise_policy.gd")
const EXPECTED_ASSERTIONS := 30
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
	_test_tuned_reference_leg_geometry_and_purity()
	_test_participation_speed_and_braking_hints()
	_test_gate_priority_and_distance_envelopes()
	_test_alignment_and_deadband_exact_boundaries()
	_test_geometry_proof_structured_red()
	_test_schema_bounds_determinism_detachment_and_authority()
	_finish()


func _test_tuned_reference_leg_geometry_and_purity() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var audit := policy.audit()
	_check(
		policy is RefCounted
			and not (policy as Object).is_class("Node")
			and bool(audit.valid)
			and audit.schema_version == 2
			and audit.policy_version == &"planetary_cruise_policy_v2",
		"the corrected policy is a valid pure schema-two RefCounted contract"
	)
	_check(
		float(audit.ember_reference.distance_meters) == 8_000_000.0
			and float(audit.ember_reference.estimated_seconds)
				== 433.3333333333333
			and float(audit.ember_reference.estimated_minutes)
				== 7.222222222222222,
		"audit freezes the exact eight-megameter 433.33-second / 7.22-minute estimate"
	)
	_check(
		audit.geometry_contract == {
			"cruise_direction": &"caller_normalized_destination_direction",
			"moving_alignment_basis": &"normalized_velocity_forward",
			"zero_speed_alignment_basis": &"normalized_ship_forward_zero_speed",
			"closing_speed_equation": &"ship_speed_times_alignment_dot",
			"clearance_sweep_basis": &"normalized_cruise_direction",
			"clearance_shape": &"all_enabled_shapes_owned_by_ship_collision_body",
			"clearance_blockers": &"physics_bodies_in_ship_collision_mask_excluding_self",
			"clearance_distance": &"collision_free_prefix_of_sweep_meters",
			"obstacle_true": &"initial_overlap_or_first_contact_at_or_before_sweep_end",
			"obstacle_false": &"full_sweep_distance_collision_free",
			"currentness": &"observation_and_proof_equal_expected_frame_generation",
		},
		"audit freezes exact alignment, zero-speed, and swept full-hull geometry semantics"
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
		"policy accepts no delta and performs no hidden query, clock, or movement"
	)


func _test_participation_speed_and_braking_hints() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var accelerating := _evaluate(policy, _observation())
	_check(
		bool(accelerating.accepted)
			and accelerating.reason == &"cruise_participation_desired"
			and bool(accelerating.desired_cruise_participation)
			and accelerating.state == &"accelerate"
			and accelerating.desired_speed_meters_per_second == 20_000.0
			and accelerating.acceleration_hint_meters_per_second_squared == 500.0
			and not bool(accelerating.braking_requested),
		"a stopped aligned craft with a full proof requests bounded acceleration"
	)
	var target := _observation()
	_set_motion(target, 20_000.0, 1.0)
	target.currently_participating = true
	var cruising := _evaluate(policy, target)
	_check(
		cruising.state == &"cruise"
			and cruising.acceleration_hint_meters_per_second_squared == 0.0
			and not bool(cruising.braking_requested),
		"target speed returns a neutral cruise hint"
	)
	var overspeed := target.duplicate(true)
	_set_motion(overspeed, 21_000.0, 1.0)
	var braking := _evaluate(policy, overspeed)
	_check(
		braking.state == &"brake_to_cruise_speed"
			and bool(braking.desired_cruise_participation)
			and bool(braking.braking_requested)
			and braking.acceleration_hint_meters_per_second_squared == -750.0
			and braking.braking_acceleration_hint_meters_per_second_squared
				== 750.0,
		"overspeed retains cruise ownership while returning an explicit braking hint"
	)
	var receding := _observation()
	_set_motion(receding, 100.0, -1.0)
	var receding_result := _evaluate(policy, receding)
	_check(
		receding_result.reason == &"alignment_below_threshold"
			and bool(receding_result.braking_requested)
			and is_equal_approx(
				float(receding_result.current_braking_envelope_meters),
				25_206.666666666668
			),
		"total ship speed drives braking even when signed closing speed is receding"
	)


func _test_gate_priority_and_distance_envelopes() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var target := _observation()
	_set_motion(target, 20_000.0, 1.0)
	target.currently_participating = true
	var target_result := _evaluate(policy, target)
	_check(
		is_equal_approx(
			float(target_result.current_braking_envelope_meters),
			331_666.6666666667
		)
			and target_result.required_verified_clearance_meters
				== target_result.current_braking_envelope_meters,
		"stopping envelope uses total speed, v-squared braking, response, and margin"
	)
	var engage := _evaluate(policy, _observation())
	_check(
		is_equal_approx(
			float(engage.minimum_engage_distance_meters),
			731_666.6666666667
		)
			and engage.required_verified_clearance_meters
				== engage.minimum_engage_distance_meters
			and engage.required_destination_distance_meters
				== engage.minimum_engage_distance_meters,
		"fresh engagement freezes its acceleration-plus-braking clearance and distance"
	)
	var at_engage_distance := _observation()
	at_engage_distance.distance_to_destination_meters = float(
		engage.minimum_engage_distance_meters
	)
	var engage_boundary := _evaluate(policy, at_engage_distance)
	at_engage_distance.distance_to_destination_meters += 0.001
	_check(
		engage_boundary.reason == &"destination_braking_envelope"
			and not bool(engage_boundary.braking_requested)
			and bool(
				_evaluate(policy, at_engage_distance).desired_cruise_participation
			),
		"fresh inclusive distance boundary disengages while the first millimetre above engages"
	)

	var priority := _unverified_observation()
	_set_motion(priority, 1_000.0, 0.970)
	priority.distance_to_destination_meters = 1_000.0
	priority.destroyed = true
	priority.piloted = false
	priority.landing_active = true
	priority.combat_active = true
	var reasons: Array[StringName] = []
	reasons.append(_evaluate(policy, priority).reason)
	priority.destroyed = false
	reasons.append(_evaluate(policy, priority).reason)
	priority.piloted = true
	reasons.append(_evaluate(policy, priority).reason)
	priority.landing_active = false
	reasons.append(_evaluate(policy, priority).reason)
	priority.combat_active = false
	reasons.append(_evaluate(policy, priority).reason)
	_set_obstacle_proof(priority, 500.0, 8_000_000.0)
	reasons.append(_evaluate(policy, priority).reason)
	_set_clear_proof(priority, 1_000.0)
	reasons.append(_evaluate(policy, priority).reason)
	_set_motion(priority, 1_000.0, 1.0)
	reasons.append(_evaluate(policy, priority).reason)
	_set_clear_proof(priority, 8_000_000.0)
	reasons.append(_evaluate(policy, priority).reason)
	_check(
		reasons == [
			&"destroyed", &"not_piloted", &"landing_active", &"combat_active",
			&"clearance_unverified", &"obstacle_detected",
			&"alignment_below_threshold", &"insufficient_verified_clearance",
			&"destination_braking_envelope",
		]
			and policy.audit().gate_priority == reasons,
		"all nine schema-valid gates execute in the documented first-wins priority"
	)


func _test_alignment_and_deadband_exact_boundaries() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var engage_below := _next_float64(0.995, -1)
	var fresh_at := _observation()
	fresh_at.alignment_dot = 0.995
	var fresh_below := fresh_at.duplicate(true)
	fresh_below.alignment_dot = engage_below
	_check(
		bool(_evaluate(policy, fresh_at).desired_cruise_participation)
			and engage_below < 0.995
			and _float64_bits(0.995) - _float64_bits(engage_below) == 1
			and _evaluate(policy, fresh_below).reason
				== &"alignment_below_threshold",
		"fresh alignment is green at exact 0.995 and red at its next representable value below"
	)
	var retain_below_value := _next_float64(0.980, -1)
	var retain_at := _observation()
	retain_at.currently_participating = true
	retain_at.alignment_dot = 0.980
	var retain_below := retain_at.duplicate(true)
	retain_below.alignment_dot = retain_below_value
	_check(
		bool(_evaluate(policy, retain_at).desired_cruise_participation)
			and retain_below_value < 0.980
			and _float64_bits(0.980) - _float64_bits(retain_below_value) == 1
			and _evaluate(policy, retain_below).reason
				== &"alignment_below_threshold",
		"retained alignment is green at exact 0.980 and red at its next value below"
	)
	var lower_outside_value := _next_float64(19_999.0, -1)
	var lower_edge := _observation()
	_set_motion(lower_edge, 19_999.0, 1.0)
	lower_edge.currently_participating = true
	var lower_outside := lower_edge.duplicate(true)
	_set_motion(lower_outside, lower_outside_value, 1.0)
	_check(
		_evaluate(policy, lower_edge).state == &"cruise"
			and _float64_bits(19_999.0) - _float64_bits(lower_outside_value)
				== 1
			and _evaluate(policy, lower_outside).state == &"accelerate",
		"minus 1 m/s is inside the deadband and the next representable value accelerates"
	)
	var upper_outside_value := _next_float64(20_001.0, 1)
	var upper_edge := _observation()
	_set_motion(upper_edge, 20_001.0, 1.0)
	upper_edge.currently_participating = true
	var upper_outside := upper_edge.duplicate(true)
	_set_motion(upper_outside, upper_outside_value, 1.0)
	_check(
		_evaluate(policy, upper_edge).state == &"cruise"
			and _float64_bits(upper_outside_value) - _float64_bits(20_001.0)
				== 1
			and _evaluate(policy, upper_outside).state == &"brake_to_cruise_speed",
		"plus 1 m/s is inside the deadband and the next representable value brakes"
	)


func _test_geometry_proof_structured_red() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var zero_closing := _observation()
	zero_closing.closing_speed_meters_per_second = 0.001
	var zero_basis := _observation()
	zero_basis.alignment_basis = &"normalized_velocity_forward"
	_check(
		_evaluate(policy, zero_closing).reason
			== &"zero_speed_closing_speed_mismatch"
			and _evaluate(policy, zero_basis).reason
				== &"zero_speed_alignment_basis_mismatch",
		"zero speed requires zero closing speed and normalized physical ship forward"
	)
	var moving_basis := _observation()
	_set_motion(moving_basis, 1_000.0, 0.995)
	moving_basis.alignment_basis = &"normalized_ship_forward_zero_speed"
	var moving_equation := _observation()
	_set_motion(moving_equation, 1_000.0, 0.995)
	moving_equation.closing_speed_meters_per_second += 0.001
	_check(
		_evaluate(policy, moving_basis).reason == &"moving_alignment_basis_mismatch"
			and _evaluate(policy, moving_equation).reason
				== &"closing_speed_alignment_mismatch",
		"moving alignment requires normalized velocity and the exact projected-speed identity"
	)
	var stale := _observation()
	stale.clearance_proof_generation = 6
	var stale_observation := _observation()
	stale_observation.coordinate_frame_generation = 6
	stale_observation.clearance_proof_generation = 6
	var partial := _observation()
	partial.clearance_full_hull = false
	var wrong_sweep_basis := _observation()
	wrong_sweep_basis.clearance_sweep_basis = &"ship_forward"
	_check(
		_evaluate(policy, stale).reason == &"clearance_proof_generation_mismatch"
			and _evaluate(policy, partial).reason == &"clearance_proof_not_full_hull"
			and _evaluate(policy, wrong_sweep_basis).reason
				== &"clearance_sweep_basis_mismatch",
		"stale, partial-hull, and wrong-basis corridor proofs are structured red"
	)
	_check(
		_evaluate(policy, stale_observation).reason
			== &"coordinate_frame_generation_mismatch",
		"the separate authoritative expected generation rejects an equal-but-stale proof pair"
	)
	var clearance_exceeds := _observation()
	clearance_exceeds.clearance_sweep_distance_meters -= 0.001
	var unverified_nonzero := _unverified_observation()
	unverified_nonzero.verified_clearance_meters = 0.001
	_check(
		_evaluate(policy, clearance_exceeds).reason
			== &"clearance_exceeds_sweep_distance"
			and _evaluate(policy, unverified_nonzero).reason
				== &"unverified_clearance_nonzero",
		"clear prefix cannot exceed its sweep and unavailable proof cannot claim distance"
	)
	var clear_length_mismatch := _observation()
	clear_length_mismatch.verified_clearance_meters -= 0.001
	var obstacle_at_end := _observation()
	obstacle_at_end.obstacle_detected = true
	var unverified_obstacle := _unverified_observation()
	unverified_obstacle.obstacle_detected = true
	_check(
		_evaluate(policy, clear_length_mismatch).reason
			== &"clear_sweep_distance_mismatch"
			and bool(_evaluate(policy, obstacle_at_end).accepted)
			and _evaluate(policy, obstacle_at_end).reason == &"obstacle_detected"
			and _evaluate(policy, unverified_obstacle).reason
				== &"unverified_obstacle_claim",
		"obstacle false/true and unavailable proof have exact non-overlapping semantics"
	)


func _test_schema_bounds_determinism_detachment_and_authority() -> void:
	var policy := PolicyScript.new() as PlanetaryCruisePolicy
	var missing := _observation()
	missing.erase("combat_active")
	var extra := _observation()
	extra["delta"] = 1.0 / 60.0
	_check(
		_evaluate(policy, missing).reason == &"observation_schema_mismatch"
			and _evaluate(policy, extra).reason == &"observation_schema_mismatch",
		"missing fields and a forbidden physics delta fail the exact schema"
	)
	var wrong_float := _observation()
	wrong_float.ship_speed_meters_per_second = 0
	var wrong_generation := _observation()
	wrong_generation.coordinate_frame_generation = 7.0
	var wrong_name := _observation()
	wrong_name.alignment_basis = "normalized_ship_forward_zero_speed"
	_check(
		_evaluate(policy, wrong_float).reason
			== &"ship_speed_meters_per_second_not_float"
			and _evaluate(policy, wrong_generation).reason
				== &"coordinate_frame_generation_not_int"
			and _evaluate(policy, wrong_name).reason == &"alignment_basis_not_string_name",
		"all geometry proof primitives retain exact float, int, and StringName types"
	)
	var nonfinite := _observation()
	nonfinite.alignment_dot = NAN
	var too_fast := _observation()
	_set_motion(too_fast, 100_000.0, 1.0)
	too_fast.ship_speed_meters_per_second = 100_000.001
	var bad_generation := _observation()
	bad_generation.coordinate_frame_generation = 0
	var bad_expected := _observation()
	_check(
		_evaluate(policy, nonfinite).reason == &"alignment_dot_nonfinite"
			and _evaluate(policy, too_fast).reason == &"ship_speed_out_of_bounds"
			and _evaluate(policy, bad_generation).reason
				== &"coordinate_frame_generation_out_of_bounds"
			and _evaluate(policy, bad_expected, 0).reason
				== &"expected_coordinate_frame_generation_out_of_bounds",
		"nonfinite, speed, and generation bounds fail safely"
	)
	var baseline := _evaluate(policy, _observation())
	var deterministic := true
	for _rate_hz in [30, 60, 120]:
		deterministic = deterministic and _evaluate(policy, _observation()) == baseline
	_check(
		deterministic,
		"30/60/120 Hz callers receive identical output because evaluation accepts no delta"
	)
	var input := _observation()
	var result := _evaluate(policy, input)
	input.coordinate_frame_generation = 99
	(result.observation as Dictionary).coordinate_frame_generation = 100
	_check(
		_evaluate(policy, _observation()).observation.coordinate_frame_generation == 7,
		"input and returned geometry proof dictionaries are deeply detached"
	)
	var audit := policy.audit()
	(audit.geometry_contract as Dictionary).clearance_shape = &"point_ray"
	(audit.authority as Dictionary).physics = true
	var fresh_audit := policy.audit()
	_check(
		fresh_audit.geometry_contract.clearance_shape
			== &"all_enabled_shapes_owned_by_ship_collision_body"
			and not bool(fresh_audit.authority.physics),
		"caller mutation cannot weaken geometry or forge query authority"
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
		"policy owns no ship, input, movement, collision, gameplay, or streaming authority"
	)


func _observation() -> Dictionary:
	return {
		"distance_to_destination_meters": 8_000_000.0,
		"ship_speed_meters_per_second": 0.0,
		"closing_speed_meters_per_second": 0.0,
		"alignment_basis": &"normalized_ship_forward_zero_speed",
		"alignment_dot": 1.0,
		"coordinate_frame_generation": 7,
		"verified_clearance_meters": 8_000_000.0,
		"clearance_sweep_distance_meters": 8_000_000.0,
		"clearance_proof_generation": 7,
		"clearance_sweep_basis": &"normalized_cruise_direction",
		"clearance_full_hull": true,
		"clearance_verified": true,
		"obstacle_detected": false,
		"currently_participating": false,
		"piloted": true,
		"destroyed": false,
		"landing_active": false,
		"combat_active": false,
	}


func _unverified_observation() -> Dictionary:
	var observation := _observation()
	observation.verified_clearance_meters = 0.0
	observation.clearance_full_hull = false
	observation.clearance_verified = false
	return observation


func _set_motion(
	observation: Dictionary,
	ship_speed_meters_per_second: float,
	alignment_dot: float
) -> void:
	observation.ship_speed_meters_per_second = ship_speed_meters_per_second
	observation.alignment_dot = alignment_dot
	observation.closing_speed_meters_per_second = (
		ship_speed_meters_per_second * alignment_dot
	)
	observation.alignment_basis = (
		&"normalized_ship_forward_zero_speed"
		if ship_speed_meters_per_second == 0.0
		else &"normalized_velocity_forward"
	)


func _set_clear_proof(observation: Dictionary, distance_meters: float) -> void:
	observation.verified_clearance_meters = distance_meters
	observation.clearance_sweep_distance_meters = distance_meters
	observation.clearance_proof_generation = observation.coordinate_frame_generation
	observation.clearance_sweep_basis = &"normalized_cruise_direction"
	observation.clearance_full_hull = true
	observation.clearance_verified = true
	observation.obstacle_detected = false


func _set_obstacle_proof(
	observation: Dictionary,
	clear_prefix_meters: float,
	sweep_distance_meters: float
) -> void:
	observation.verified_clearance_meters = clear_prefix_meters
	observation.clearance_sweep_distance_meters = sweep_distance_meters
	observation.clearance_proof_generation = observation.coordinate_frame_generation
	observation.clearance_sweep_basis = &"normalized_cruise_direction"
	observation.clearance_full_hull = true
	observation.clearance_verified = true
	observation.obstacle_detected = true


func _evaluate(
	policy: PlanetaryCruisePolicy,
	observation: Dictionary,
	expected_coordinate_frame_generation: int = 7
) -> Dictionary:
	return policy.evaluate(observation, expected_coordinate_frame_generation)


func _next_float64(value: float, bit_step: int) -> float:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	bytes.encode_s64(0, bytes.decode_s64(0) + bit_step)
	return bytes.decode_double(0)


func _float64_bits(value: float) -> int:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.decode_s64(0)


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
