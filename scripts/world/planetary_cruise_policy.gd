class_name PlanetaryCruisePolicy
extends RefCounted

## Pure, caller-driven long-leg cruise recommendation policy.
##
## The policy evaluates one detached observation and returns desired cruise
## participation plus speed, acceleration, and braking hints. It never samples
## input, advances time, moves a node, casts for obstacles, or owns any runtime
## authority. A later ship/control owner must prove the supplied clearance and
## decide whether and how to enact an accepted hint.

const SCHEMA_VERSION := 2
const POLICY_VERSION: StringName = &"planetary_cruise_policy_v2"
const TUNING_VERSION: StringName = &"ember_eight_megameter_minutes_v1"
const ALIGNMENT_BASIS_VELOCITY: StringName = &"normalized_velocity_forward"
const ALIGNMENT_BASIS_ZERO_SPEED: StringName = &"normalized_ship_forward_zero_speed"
const CLEARANCE_SWEEP_BASIS: StringName = &"normalized_cruise_direction"

const TARGET_CRUISE_SPEED_METERS_PER_SECOND := 20_000.0
const ACCELERATION_HINT_METERS_PER_SECOND_SQUARED := 500.0
const BRAKING_HINT_METERS_PER_SECOND_SQUARED := 750.0
const BRAKE_RESPONSE_SECONDS := 2.0
const BRAKE_FIXED_MARGIN_METERS := 25_000.0
const ENGAGE_ALIGNMENT_DOT := 0.995
const RETAIN_ALIGNMENT_DOT := 0.980
const SPEED_DEADBAND_METERS_PER_SECOND := 1.0
const EMBER_REFERENCE_LEG_METERS := 8_000_000.0

const MAX_DISTANCE_METERS := 1_000_000_000.0
const MAX_ABSOLUTE_SPEED_METERS_PER_SECOND := 100_000.0
const MAX_CLEARANCE_METERS := 1_000_000_000.0
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

const _OBSERVATION_KEYS := [
	"distance_to_destination_meters",
	"ship_speed_meters_per_second",
	"closing_speed_meters_per_second",
	"alignment_basis",
	"alignment_dot",
	"coordinate_frame_generation",
	"verified_clearance_meters",
	"clearance_sweep_distance_meters",
	"clearance_proof_generation",
	"clearance_sweep_basis",
	"clearance_full_hull",
	"clearance_verified",
	"obstacle_detected",
	"currently_participating",
	"piloted",
	"destroyed",
	"landing_active",
	"combat_active",
]
const _COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]


## Evaluates exactly one observation against the caller's authoritative current
## coordinate-frame generation, without retaining either or accepting delta.
## Safety gate results are accepted policy decisions; malformed observations
## are rejected and still return a complete safe, non-participating hint set.
func evaluate(
	observation: Dictionary,
	expected_coordinate_frame_generation: int
) -> Dictionary:
	if expected_coordinate_frame_generation < 1 \
		or expected_coordinate_frame_generation > MAX_SAFE_GENERATION:
		return _safe_result(
			false,
			&"expected_coordinate_frame_generation_out_of_bounds",
			expected_coordinate_frame_generation
		)
	var validation_reason := _validate_observation(
		observation, expected_coordinate_frame_generation
	)
	if not validation_reason.is_empty():
		return _safe_result(
			false, validation_reason, expected_coordinate_frame_generation
		)

	var detached_observation := observation.duplicate(true)
	var distance := float(observation.distance_to_destination_meters)
	var ship_speed := float(observation.ship_speed_meters_per_second)
	var closing_speed := float(observation.closing_speed_meters_per_second)
	var alignment := float(observation.alignment_dot)
	var clearance := float(observation.verified_clearance_meters)
	var currently_participating := bool(observation.currently_participating)
	var current_braking_envelope := _braking_envelope_meters(
		ship_speed
	)
	var target_braking_envelope := _braking_envelope_meters(
		TARGET_CRUISE_SPEED_METERS_PER_SECOND
	)
	var acceleration_distance := (
		TARGET_CRUISE_SPEED_METERS_PER_SECOND
		* TARGET_CRUISE_SPEED_METERS_PER_SECOND
		/ (2.0 * ACCELERATION_HINT_METERS_PER_SECOND_SQUARED)
	)
	var minimum_engage_distance := target_braking_envelope \
		+ acceleration_distance
	var required_clearance := current_braking_envelope
	var required_destination_distance := current_braking_envelope
	if not currently_participating:
		required_clearance = maxf(
			required_clearance, minimum_engage_distance
		)
		required_destination_distance = maxf(
			required_destination_distance, minimum_engage_distance
		)

	var gate_reason := _safety_gate_reason(
		observation,
		distance,
		alignment,
		clearance,
		required_clearance,
		required_destination_distance
	)
	if not gate_reason.is_empty():
		var brake_requested := _should_offer_disengage_brake(
			gate_reason, ship_speed, observation
		)
		return _safe_result(
			true,
			gate_reason,
			expected_coordinate_frame_generation,
			{
				"observation": detached_observation,
				"braking_requested": brake_requested,
				"braking_acceleration_hint_meters_per_second_squared": (
					BRAKING_HINT_METERS_PER_SECOND_SQUARED
					if brake_requested else 0.0
				),
				"current_braking_envelope_meters": current_braking_envelope,
				"required_verified_clearance_meters": required_clearance,
				"required_destination_distance_meters": (
					required_destination_distance
				),
				"minimum_engage_distance_meters": minimum_engage_distance,
			}
		)

	var acceleration_hint := 0.0
	var braking_requested := false
	var state: StringName = &"cruise"
	if closing_speed < TARGET_CRUISE_SPEED_METERS_PER_SECOND \
		- SPEED_DEADBAND_METERS_PER_SECOND:
		acceleration_hint = ACCELERATION_HINT_METERS_PER_SECOND_SQUARED
		state = &"accelerate"
	elif closing_speed > TARGET_CRUISE_SPEED_METERS_PER_SECOND \
		+ SPEED_DEADBAND_METERS_PER_SECOND:
		acceleration_hint = -BRAKING_HINT_METERS_PER_SECOND_SQUARED
		braking_requested = true
		state = &"brake_to_cruise_speed"

	return _safe_result(
		true,
		&"cruise_participation_desired",
		expected_coordinate_frame_generation,
		{
			"observation": detached_observation,
			"desired_cruise_participation": true,
			"state": state,
			"desired_speed_meters_per_second": (
				TARGET_CRUISE_SPEED_METERS_PER_SECOND
			),
			"acceleration_hint_meters_per_second_squared": acceleration_hint,
			"braking_requested": braking_requested,
			"braking_acceleration_hint_meters_per_second_squared": (
				BRAKING_HINT_METERS_PER_SECOND_SQUARED
				if braking_requested else 0.0
			),
			"current_braking_envelope_meters": current_braking_envelope,
			"required_verified_clearance_meters": required_clearance,
			"required_destination_distance_meters": (
				required_destination_distance
			),
			"minimum_engage_distance_meters": minimum_engage_distance,
		}
	)


func audit() -> Dictionary:
	var errors := _contract_errors()
	return {
		"valid": errors.is_empty(),
		"errors": errors.duplicate(),
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"tuning_version": TUNING_VERSION,
		"observation_keys": _OBSERVATION_KEYS.duplicate(),
		"units": {
			"distance": &"meters",
			"speed": &"meters_per_second",
			"acceleration": &"meters_per_second_squared",
			"alignment": &"unitless_dot_product",
		},
		"geometry_contract": {
			"cruise_direction": &"caller_normalized_destination_direction",
			"moving_alignment_basis": ALIGNMENT_BASIS_VELOCITY,
			"zero_speed_alignment_basis": ALIGNMENT_BASIS_ZERO_SPEED,
			"closing_speed_equation": &"ship_speed_times_alignment_dot",
			"clearance_sweep_basis": CLEARANCE_SWEEP_BASIS,
			"clearance_shape": &"all_enabled_shapes_owned_by_ship_collision_body",
			"clearance_blockers": &"physics_bodies_in_ship_collision_mask_excluding_self",
			"clearance_distance": &"collision_free_prefix_of_sweep_meters",
			"obstacle_true": &"initial_overlap_or_first_contact_at_or_before_sweep_end",
			"obstacle_false": &"full_sweep_distance_collision_free",
			"currentness": &"observation_and_proof_equal_expected_frame_generation",
		},
		"gate_priority": [
			&"destroyed",
			&"not_piloted",
			&"landing_active",
			&"combat_active",
			&"clearance_unverified",
			&"obstacle_detected",
			&"alignment_below_threshold",
			&"insufficient_verified_clearance",
			&"destination_braking_envelope",
		],
		"tuning": _tuning_snapshot(),
		"ember_reference": {
			"distance_meters": EMBER_REFERENCE_LEG_METERS,
			"estimated_seconds": _default_leg_seconds(),
			"estimated_minutes": _default_leg_seconds() / 60.0,
		},
		"purity": {
			"caller_driven": true,
			"physics_delta_input": false,
			"clock_input": false,
			"retains_observations": false,
			"performs_obstacle_query": false,
			"moves_actor": false,
		},
		"authority": _zero_authority(),
		"adjacent_authority": {
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
	}.duplicate(true)


func get_authority_report() -> Dictionary:
	return _zero_authority()


static func _validate_observation(
	observation: Dictionary,
	expected_coordinate_frame_generation: int
) -> StringName:
	if not _has_exact_keys(observation, _OBSERVATION_KEYS):
		return &"observation_schema_mismatch"
	for key in [
		"distance_to_destination_meters",
		"ship_speed_meters_per_second",
		"closing_speed_meters_per_second",
		"alignment_dot",
		"verified_clearance_meters",
		"clearance_sweep_distance_meters",
	]:
		if not observation[key] is float:
			return StringName("%s_not_float" % key)
		if not is_finite(float(observation[key])):
			return StringName("%s_nonfinite" % key)
	for key in [
		"clearance_full_hull", "clearance_verified", "obstacle_detected",
		"currently_participating", "piloted", "destroyed", "landing_active",
		"combat_active",
	]:
		if not observation[key] is bool:
			return StringName("%s_not_bool" % key)
	var distance := float(observation.distance_to_destination_meters)
	if distance < 0.0 or distance > MAX_DISTANCE_METERS:
		return &"distance_to_destination_out_of_bounds"
	var ship_speed := float(observation.ship_speed_meters_per_second)
	if ship_speed < 0.0 or ship_speed > MAX_ABSOLUTE_SPEED_METERS_PER_SECOND:
		return &"ship_speed_out_of_bounds"
	var closing_speed := float(observation.closing_speed_meters_per_second)
	if absf(closing_speed) > MAX_ABSOLUTE_SPEED_METERS_PER_SECOND:
		return &"closing_speed_out_of_bounds"
	var alignment := float(observation.alignment_dot)
	if alignment < -1.0 or alignment > 1.0:
		return &"alignment_out_of_bounds"
	var clearance := float(observation.verified_clearance_meters)
	if clearance < 0.0 or clearance > MAX_CLEARANCE_METERS:
		return &"clearance_out_of_bounds"
	var sweep_distance := float(observation.clearance_sweep_distance_meters)
	if sweep_distance < 0.0 or sweep_distance > MAX_CLEARANCE_METERS:
		return &"clearance_sweep_distance_out_of_bounds"
	for key in ["alignment_basis", "clearance_sweep_basis"]:
		if not observation[key] is StringName:
			return StringName("%s_not_string_name" % key)
	for key in ["coordinate_frame_generation", "clearance_proof_generation"]:
		if not observation[key] is int:
			return StringName("%s_not_int" % key)
		var generation := int(observation[key])
		if generation < 1 or generation > MAX_SAFE_GENERATION:
			return StringName("%s_out_of_bounds" % key)
	if int(observation.coordinate_frame_generation) \
		!= expected_coordinate_frame_generation:
		return &"coordinate_frame_generation_mismatch"
	if ship_speed == 0.0:
		if closing_speed != 0.0:
			return &"zero_speed_closing_speed_mismatch"
		if observation.alignment_basis != ALIGNMENT_BASIS_ZERO_SPEED:
			return &"zero_speed_alignment_basis_mismatch"
	else:
		if observation.alignment_basis != ALIGNMENT_BASIS_VELOCITY:
			return &"moving_alignment_basis_mismatch"
		if closing_speed != ship_speed * alignment:
			return &"closing_speed_alignment_mismatch"
	if observation.clearance_sweep_basis != CLEARANCE_SWEEP_BASIS:
		return &"clearance_sweep_basis_mismatch"
	var clearance_verified := bool(observation.clearance_verified)
	var obstacle_detected := bool(observation.obstacle_detected)
	if clearance_verified:
		if int(observation.clearance_proof_generation) \
			!= int(observation.coordinate_frame_generation):
			return &"clearance_proof_generation_mismatch"
		if not bool(observation.clearance_full_hull):
			return &"clearance_proof_not_full_hull"
		if clearance > sweep_distance:
			return &"clearance_exceeds_sweep_distance"
		if not obstacle_detected and clearance != sweep_distance:
			return &"clear_sweep_distance_mismatch"
	else:
		if obstacle_detected:
			return &"unverified_obstacle_claim"
		if clearance != 0.0:
			return &"unverified_clearance_nonzero"
	return &""


static func _safety_gate_reason(
	observation: Dictionary,
	distance: float,
	alignment: float,
	clearance: float,
	required_clearance: float,
	required_destination_distance: float
) -> StringName:
	if bool(observation.destroyed):
		return &"destroyed"
	if not bool(observation.piloted):
		return &"not_piloted"
	if bool(observation.landing_active):
		return &"landing_active"
	if bool(observation.combat_active):
		return &"combat_active"
	if not bool(observation.clearance_verified):
		return &"clearance_unverified"
	if bool(observation.obstacle_detected):
		return &"obstacle_detected"
	var alignment_threshold := (
		RETAIN_ALIGNMENT_DOT
		if bool(observation.currently_participating)
		else ENGAGE_ALIGNMENT_DOT
	)
	if alignment < alignment_threshold:
		return &"alignment_below_threshold"
	if clearance < required_clearance:
		return &"insufficient_verified_clearance"
	if distance <= required_destination_distance:
		return &"destination_braking_envelope"
	return &""


static func _should_offer_disengage_brake(
	reason: StringName,
	ship_speed: float,
	observation: Dictionary
) -> bool:
	if ship_speed <= SPEED_DEADBAND_METERS_PER_SECOND:
		return false
	if bool(observation.destroyed) or not bool(observation.piloted):
		return false
	if bool(observation.landing_active) or bool(observation.combat_active):
		return false
	return reason in [
		&"clearance_unverified",
		&"obstacle_detected",
		&"alignment_below_threshold",
		&"insufficient_verified_clearance",
		&"destination_braking_envelope",
	]


static func _braking_envelope_meters(speed_meters_per_second: float) -> float:
	return (
		speed_meters_per_second * speed_meters_per_second
		/ (2.0 * BRAKING_HINT_METERS_PER_SECOND_SQUARED)
		+ speed_meters_per_second * BRAKE_RESPONSE_SECONDS
		+ BRAKE_FIXED_MARGIN_METERS
	)


static func _default_leg_seconds() -> float:
	var acceleration_seconds := TARGET_CRUISE_SPEED_METERS_PER_SECOND \
		/ ACCELERATION_HINT_METERS_PER_SECOND_SQUARED
	var braking_seconds := TARGET_CRUISE_SPEED_METERS_PER_SECOND \
		/ BRAKING_HINT_METERS_PER_SECOND_SQUARED
	var acceleration_distance := 0.5 \
		* ACCELERATION_HINT_METERS_PER_SECOND_SQUARED \
		* acceleration_seconds * acceleration_seconds
	var braking_distance := 0.5 \
		* BRAKING_HINT_METERS_PER_SECOND_SQUARED \
		* braking_seconds * braking_seconds
	var cruise_distance := maxf(
		EMBER_REFERENCE_LEG_METERS - acceleration_distance - braking_distance,
		0.0
	)
	return acceleration_seconds + braking_seconds \
		+ cruise_distance / TARGET_CRUISE_SPEED_METERS_PER_SECOND


static func _tuning_snapshot() -> Dictionary:
	return {
		"target_cruise_speed_meters_per_second": (
			TARGET_CRUISE_SPEED_METERS_PER_SECOND
		),
		"acceleration_hint_meters_per_second_squared": (
			ACCELERATION_HINT_METERS_PER_SECOND_SQUARED
		),
		"braking_hint_meters_per_second_squared": (
			BRAKING_HINT_METERS_PER_SECOND_SQUARED
		),
		"brake_response_seconds": BRAKE_RESPONSE_SECONDS,
		"brake_fixed_margin_meters": BRAKE_FIXED_MARGIN_METERS,
		"engage_alignment_dot": ENGAGE_ALIGNMENT_DOT,
		"retain_alignment_dot": RETAIN_ALIGNMENT_DOT,
		"speed_deadband_meters_per_second": (
			SPEED_DEADBAND_METERS_PER_SECOND
		),
	}.duplicate(true)


static func _contract_errors() -> Array[StringName]:
	var errors: Array[StringName] = []
	if TARGET_CRUISE_SPEED_METERS_PER_SECOND <= 0.0 \
		or TARGET_CRUISE_SPEED_METERS_PER_SECOND \
		> MAX_ABSOLUTE_SPEED_METERS_PER_SECOND:
		errors.append(&"invalid_target_cruise_speed")
	if ACCELERATION_HINT_METERS_PER_SECOND_SQUARED <= 0.0:
		errors.append(&"invalid_acceleration_hint")
	if BRAKING_HINT_METERS_PER_SECOND_SQUARED <= 0.0:
		errors.append(&"invalid_braking_hint")
	if BRAKE_RESPONSE_SECONDS < 0.0 or BRAKE_FIXED_MARGIN_METERS < 0.0:
		errors.append(&"invalid_braking_margin")
	if RETAIN_ALIGNMENT_DOT < -1.0 \
		or ENGAGE_ALIGNMENT_DOT > 1.0 \
		or RETAIN_ALIGNMENT_DOT >= ENGAGE_ALIGNMENT_DOT:
		errors.append(&"invalid_alignment_hysteresis")
	if not _has_exact_zero_authority(_zero_authority()):
		errors.append(&"invalid_common_authority_roster")
	if not is_finite(_default_leg_seconds()) or _default_leg_seconds() <= 0.0:
		errors.append(&"invalid_reference_leg_estimate")
	return errors


static func _safe_result(
	accepted: bool,
	reason: StringName,
	expected_coordinate_frame_generation: int,
	details: Dictionary = {}
) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"tuning_version": TUNING_VERSION,
		"expected_coordinate_frame_generation": (
			expected_coordinate_frame_generation
		),
		"desired_cruise_participation": false,
		"state": &"disengaged",
		"desired_speed_meters_per_second": 0.0,
		"acceleration_hint_meters_per_second_squared": 0.0,
		"braking_requested": false,
		"braking_acceleration_hint_meters_per_second_squared": 0.0,
		"current_braking_envelope_meters": 0.0,
		"required_verified_clearance_meters": 0.0,
		"required_destination_distance_meters": 0.0,
		"minimum_engage_distance_meters": 0.0,
	}
	result.merge(details, true)
	return result.duplicate(true)


static func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true


static func _has_exact_zero_authority(authority: Dictionary) -> bool:
	if authority.size() != _COMMON_AUTHORITY_KEYS.size():
		return false
	for key in _COMMON_AUTHORITY_KEYS:
		if not authority.has(key) or not authority[key] is bool \
			or bool(authority[key]):
			return false
	return true


static func _zero_authority() -> Dictionary:
	return {
		"renderer": false,
		"gameplay": false,
		"streaming": false,
		"save": false,
		"network": false,
		"physics": false,
		"world_generation": false,
		"terrain_generation": false,
		"collision_generation": false,
		"origin_shift": false,
		"weather_clock": false,
		"audio": false,
	}.duplicate(true)
