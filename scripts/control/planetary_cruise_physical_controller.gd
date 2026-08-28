class_name PlanetaryCruisePhysicalController
extends Node

## Caller-driven bridge from PlanetaryCruisePolicy to one real HeroShip.
##
## This component derives a current full-hull sweep proof, evaluates the pure
## policy, and submits one detached envelope. It never writes ship velocity,
## transforms, or calls a movement method; HeroShip remains the sole physical
## integration authority.

signal binding_changed(snapshot: Dictionary)
signal evaluation_committed(snapshot: Dictionary)
signal final_approach_changed(snapshot: Dictionary)
signal final_approach_completed(receipt: Dictionary)
signal return_approach_changed(snapshot: Dictionary)
signal return_approach_completed(receipt: Dictionary)

enum FinalApproachState { NONE, ARMED, ACTIVE, COMPLETED, ABORTED }

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
## Conservative physical horizon above the pure policy's 731,666.67 m default
## engagement requirement. Higher current speeds fail closed when this horizon
## cannot cover their larger braking envelope.
const CLEARANCE_PROOF_HORIZON_METERS := 750_000.0
const FINAL_APPROACH_TARGET_ID: StringName = &"FINAL_APPROACH"
const RETURN_APPROACH_TARGET_ID: StringName = &"SHIPYARD_RETURN_APPROACH"
const RETURN_APPROACH_KIND: StringName = &"shipyard_return"
const FINAL_APPROACH_KIND: StringName = &"ember_final"
const RETURN_APPROACH_FLEET_IDS := [
	&"torrent_provisional",
	&"arrow_provisional",
	&"jovian_provisional",
	&"zenith_b7_observed",
	&"halyard_new_design",
	&"bulwark_heavy_gunship",
	&"cinder_cargo_hauler",
	&"cinder_long_range_bomber",
	&"cinder_light_interceptor",
]
const FINAL_APPROACH_ACCELERATION_MPS2 := 500.0
const FINAL_APPROACH_BRAKING_MPS2 := 750.0
const FINAL_APPROACH_TRANSIT_SPEED_MPS := 5_000.0
const FINAL_APPROACH_TERMINAL_DISTANCE_M := 500.0
const FINAL_APPROACH_TERMINAL_SPEED_MPS := 10.0
const PlanetaryCruisePolicyType := preload(
	"res://scripts/world/planetary_cruise_policy.gd"
)

const _COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]


class FinalApproachTarget:
	extends RefCounted

	var target_id: StringName = FINAL_APPROACH_TARGET_ID
	var target_generation := 0
	var coordinate_frame_generation := 0
	var location_generation := 0
	var landing_root_instance_id := 0
	var corridor_id: StringName = &""
	var target_pad_id: StringName = &""
	var target_world_transform := Transform3D.IDENTITY
	var corridor_half_extents_m := Vector3.ZERO
	var entry_position_half_extents_m := Vector3.ZERO
	var maximum_speed_mps := 0.0
	var maximum_attitude_degrees := 0.0
	var hull_margin_m := 0.0
	var collision_bounds := AABB()

	func validation_reason() -> StringName:
		if target_id != FINAL_APPROACH_TARGET_ID or target_generation < 1:
			return &"final_approach_target_identity_invalid"
		if coordinate_frame_generation < 1 or location_generation < 1 \
				or landing_root_instance_id < 1:
			return &"final_approach_target_generation_invalid"
		if corridor_id.is_empty() or target_pad_id.is_empty():
			return &"final_approach_corridor_identity_invalid"
		if not _transform_is_finite(target_world_transform) \
				or not corridor_half_extents_m.is_finite() \
				or not entry_position_half_extents_m.is_finite() \
				or not collision_bounds.position.is_finite() \
				or not collision_bounds.size.is_finite():
			return &"final_approach_target_nonfinite"
		if corridor_half_extents_m.x <= 0.0 \
				or corridor_half_extents_m.y <= 0.0 \
				or corridor_half_extents_m.z <= 0.0 \
				or entry_position_half_extents_m.x <= 0.0 \
				or entry_position_half_extents_m.y <= 0.0 \
				or entry_position_half_extents_m.z <= 0.0 \
				or entry_position_half_extents_m.x > corridor_half_extents_m.x \
				or entry_position_half_extents_m.y > corridor_half_extents_m.y \
				or entry_position_half_extents_m.z > corridor_half_extents_m.z \
				or collision_bounds.size.x <= 0.0 \
				or collision_bounds.size.y <= 0.0 \
				or collision_bounds.size.z <= 0.0:
			return &"final_approach_target_extents_invalid"
		if not is_finite(maximum_speed_mps) or maximum_speed_mps <= 0.0 \
				or maximum_speed_mps > 12.0 \
				or not is_finite(maximum_attitude_degrees) \
				or maximum_attitude_degrees <= 0.0 \
				or maximum_attitude_degrees > 12.0 \
				or not is_finite(hull_margin_m) or hull_margin_m < 0.0:
			return &"final_approach_target_limits_invalid"
		return &""

	func get_snapshot() -> Dictionary:
		return {
			"target_id": target_id,
			"target_generation": target_generation,
			"coordinate_frame_generation": coordinate_frame_generation,
			"location_generation": location_generation,
			"landing_root_instance_id": landing_root_instance_id,
			"corridor_id": corridor_id,
			"target_pad_id": target_pad_id,
			"target_world_transform": target_world_transform,
			"corridor_half_extents_m": corridor_half_extents_m,
			"entry_position_half_extents_m": entry_position_half_extents_m,
			"maximum_speed_mps": maximum_speed_mps,
			"maximum_attitude_degrees": maximum_attitude_degrees,
			"hull_margin_m": hull_margin_m,
			"collision_bounds": collision_bounds,
		}.duplicate(true)

	static func _transform_is_finite(value: Transform3D) -> bool:
		return value.origin.is_finite() and value.basis.x.is_finite() \
			and value.basis.y.is_finite() and value.basis.z.is_finite() \
			and not is_zero_approx(value.basis.determinant())


class ReturnApproachTarget:
	extends RefCounted

	var target_id: StringName = RETURN_APPROACH_TARGET_ID
	var target_generation := 0
	var coordinate_frame_generation := 0
	var home_target_id: StringName = &""
	var home_target_world_transform := Transform3D.IDENTITY
	var corridor_half_extents_m := Vector3.ZERO
	var brake_shell_min_distance_m := 0.0
	var brake_shell_max_distance_m := 0.0
	var maximum_speed_mps := 0.0
	var maximum_attitude_degrees := 0.0
	var hull_margin_m := 0.0
	var active_ship_id: StringName = &""
	var collision_bounds := AABB()
	var fleet_collision_bounds: Dictionary = {}

	func validation_reason() -> StringName:
		if target_id != RETURN_APPROACH_TARGET_ID or target_generation < 1:
			return &"return_approach_target_identity_invalid"
		if coordinate_frame_generation < 1 or home_target_id.is_empty():
			return &"return_approach_target_generation_invalid"
		if not FinalApproachTarget._transform_is_finite(home_target_world_transform) \
				or not corridor_half_extents_m.is_finite() \
				or not collision_bounds.position.is_finite() \
				or not collision_bounds.size.is_finite():
			return &"return_approach_target_nonfinite"
		if corridor_half_extents_m.x <= 0.0 \
				or corridor_half_extents_m.y <= 0.0 \
				or corridor_half_extents_m.z < CLEARANCE_PROOF_HORIZON_METERS \
				or corridor_half_extents_m.z > CLEARANCE_PROOF_HORIZON_METERS \
				or collision_bounds.size.x <= 0.0 \
				or collision_bounds.size.y <= 0.0 \
				or collision_bounds.size.z <= 0.0:
			return &"return_approach_target_extents_invalid"
		if not is_finite(brake_shell_min_distance_m) \
				or not is_finite(brake_shell_max_distance_m) \
				or brake_shell_min_distance_m <= 0.0 \
				or brake_shell_max_distance_m <= brake_shell_min_distance_m \
				or brake_shell_max_distance_m > CLEARANCE_PROOF_HORIZON_METERS:
			return &"return_approach_brake_shell_invalid"
		if not is_finite(maximum_speed_mps) or maximum_speed_mps <= 0.0 \
				or maximum_speed_mps > 12.0 \
				or not is_finite(maximum_attitude_degrees) \
				or maximum_attitude_degrees <= 0.0 \
				or maximum_attitude_degrees > 12.0 \
				or not is_finite(hull_margin_m) or hull_margin_m < 0.0:
			return &"return_approach_target_limits_invalid"
		if not RETURN_APPROACH_FLEET_IDS.has(active_ship_id) \
				or fleet_collision_bounds.size() != RETURN_APPROACH_FLEET_IDS.size():
			return &"return_approach_fleet_identity_invalid"
		for ship_id: StringName in RETURN_APPROACH_FLEET_IDS:
			if not fleet_collision_bounds.has(ship_id) \
					or not fleet_collision_bounds[ship_id] is AABB:
				return &"return_approach_fleet_identity_invalid"
			var bounds := fleet_collision_bounds[ship_id] as AABB
			if not _bounds_fit_corridor(bounds):
				return &"return_approach_fleet_hull_outside_corridor"
		if collision_bounds != (fleet_collision_bounds[active_ship_id] as AABB):
			return &"return_approach_active_hull_mismatch"
		return &""

	func get_snapshot() -> Dictionary:
		return {
			"target_id": target_id,
			"target_generation": target_generation,
			"coordinate_frame_generation": coordinate_frame_generation,
			"home_target_id": home_target_id,
			"home_target_world_transform": home_target_world_transform,
			"corridor_half_extents_m": corridor_half_extents_m,
			"brake_shell_min_distance_m": brake_shell_min_distance_m,
			"brake_shell_max_distance_m": brake_shell_max_distance_m,
			"maximum_speed_mps": maximum_speed_mps,
			"maximum_attitude_degrees": maximum_attitude_degrees,
			"hull_margin_m": hull_margin_m,
			"active_ship_id": active_ship_id,
			"collision_bounds": collision_bounds,
			"fleet_collision_bounds": fleet_collision_bounds.duplicate(true),
			"fleet_corridor_proof": _fleet_corridor_proof(),
		}.duplicate(true)

	func _bounds_fit_corridor(bounds: AABB) -> bool:
		if not bounds.position.is_finite() or not bounds.size.is_finite() \
				or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 \
				or bounds.size.z <= 0.0:
			return false
		var maximum_x := maxf(absf(bounds.position.x), absf(bounds.end.x))
		var maximum_y := maxf(absf(bounds.position.y), absf(bounds.end.y))
		var maximum_z := maxf(absf(bounds.position.z), absf(bounds.end.z))
		return maximum_x + hull_margin_m <= corridor_half_extents_m.x \
			and maximum_y + hull_margin_m <= corridor_half_extents_m.y \
			and maximum_z + hull_margin_m <= corridor_half_extents_m.z

	func _fleet_corridor_proof() -> Dictionary:
		var hulls: Dictionary = {}
		var all_fit := true
		for ship_id: StringName in RETURN_APPROACH_FLEET_IDS:
			var bounds := fleet_collision_bounds.get(ship_id, AABB()) as AABB
			var fits := _bounds_fit_corridor(bounds)
			hulls[ship_id] = {
				"collision_bounds": bounds,
				"fits_cross_section": fits,
			}.duplicate(true)
			all_fit = all_fit and fits
		return {
			"accepted": all_fit and hulls.size() == RETURN_APPROACH_FLEET_IDS.size(),
			"reason": &"full_flyable_fleet_inside_corridor" if all_fit \
				else &"fleet_hull_outside_corridor",
			"route_clearance_m": CLEARANCE_PROOF_HORIZON_METERS,
			"fleet_ids": RETURN_APPROACH_FLEET_IDS.duplicate(),
			"hulls": hulls.duplicate(true),
		}.duplicate(true)

var _policy := PlanetaryCruisePolicyType.new()
var _ship_ref: WeakRef
var _ship_instance_id := 0
var _ship_attachment_generation := 0
var _coordinate_frame_generation := 0
var _generation := 1
var _sequence := 0
var _attached := false
var _mutation_active := false
var _signal_dispatch_active := false
var _last_result: Dictionary = {}
var _last_envelope: Dictionary = {}
var _final_approach_target: Variant
var _approach_kind: StringName = &""
var _final_approach_state := FinalApproachState.NONE
var _final_approach_generation := 0
var _last_final_approach_reason: StringName = &"not_requested"
var _last_final_approach_receipt: Dictionary = {}


func _exit_tree() -> void:
	var ship := _resolve_ship()
	if ship != null and _attached:
		ship.disengage_planetary_cruise(
			get_instance_id(),
			_ship_attachment_generation,
			true
		)
	_clear_binding(&"controller_detached", true)


func bind_ship(
	ship: HeroShip,
	coordinate_frame_generation: int,
	expected_generation: int
) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _receipt(false, &"reentrant_call")
	if expected_generation != _generation:
		return _receipt(false, &"generation_mismatch")
	if not _controller_is_live():
		return _receipt(false, &"controller_unavailable")
	if ship == null \
		or not is_instance_valid(ship) \
		or ship.is_queued_for_deletion() \
		or not ship.is_inside_tree():
		return _receipt(false, &"ship_unavailable")
	if coordinate_frame_generation < 1 \
		or coordinate_frame_generation > MAX_SAFE_INTEGER:
		return _receipt(false, &"coordinate_frame_generation_out_of_bounds")
	if _attached:
		return _receipt(false, &"already_attached")
	var ship_report := ship.get_planetary_cruise_attachment_report()
	if int(ship_report.get("ship_instance_id", 0)) != ship.get_instance_id():
		return _receipt(false, &"ship_report_identity_mismatch")
	var attachment_generation := int(
		ship_report.get("ship_attachment_generation", 0)
	)
	_mutation_active = true
	var attach_receipt := ship.attach_planetary_cruise_controller(
		get_instance_id(),
		attachment_generation
	)
	if not bool(attach_receipt.get("accepted", false)):
		_mutation_active = false
		return _receipt(
			false,
			StringName(attach_receipt.get("reason", &"ship_attach_rejected"))
		)
	_ship_ref = weakref(ship)
	_ship_instance_id = ship.get_instance_id()
	_ship_attachment_generation = attachment_generation
	_coordinate_frame_generation = coordinate_frame_generation
	_attached = true
	_last_result = {}
	_last_envelope = {}
	_mutation_active = false
	_emit_binding_changed()
	return _receipt(true, &"attached")


func arm_final_approach(
		target: FinalApproachTarget,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
	) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _receipt(false, &"reentrant_call")
	var binding_reason := _validate_binding(
		expected_coordinate_frame_generation, expected_generation
	)
	if not binding_reason.is_empty():
		return _receipt(false, binding_reason)
	if target == null:
		return _receipt(false, &"final_approach_target_unavailable")
	var target_reason := target.validation_reason()
	if not target_reason.is_empty():
		return _receipt(false, target_reason)
	if target.coordinate_frame_generation != _coordinate_frame_generation:
		return _receipt(false, &"final_approach_frame_generation_mismatch")
	if _final_approach_state in [
		FinalApproachState.ARMED, FinalApproachState.ACTIVE,
		FinalApproachState.COMPLETED,
	]:
		return _receipt(false, &"final_approach_already_requested")
	_mutation_active = true
	_final_approach_target = target
	_approach_kind = FINAL_APPROACH_KIND
	_final_approach_generation = target.target_generation
	_final_approach_state = FinalApproachState.ARMED
	_last_final_approach_reason = &"final_approach_armed"
	_last_final_approach_receipt.clear()
	_mutation_active = false
	_emit_final_approach_changed()
	return _final_approach_result(true, _last_final_approach_reason)


func arm_return_approach(
		target: ReturnApproachTarget,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
	) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _receipt(false, &"reentrant_call")
	var binding_reason := _validate_binding(
		expected_coordinate_frame_generation, expected_generation
	)
	if not binding_reason.is_empty():
		return _receipt(false, binding_reason)
	if target == null:
		return _receipt(false, &"return_approach_target_unavailable")
	var target_reason := target.validation_reason()
	if not target_reason.is_empty():
		return _receipt(false, target_reason)
	if target.coordinate_frame_generation != _coordinate_frame_generation:
		return _receipt(false, &"return_approach_frame_generation_mismatch")
	if _final_approach_state in [
		FinalApproachState.ARMED, FinalApproachState.ACTIVE,
		FinalApproachState.COMPLETED,
	]:
		return _receipt(false, &"approach_already_requested")
	_mutation_active = true
	_final_approach_target = target
	_approach_kind = RETURN_APPROACH_KIND
	_final_approach_generation = target.target_generation
	_final_approach_state = FinalApproachState.ARMED
	_last_final_approach_reason = &"return_approach_armed"
	_last_final_approach_receipt.clear()
	_mutation_active = false
	_emit_final_approach_changed()
	return _final_approach_result(true, _last_final_approach_reason)


func abort_final_approach(
		reason: StringName,
		expected_target_generation: int,
		expected_generation: int,
	) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _final_approach_result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _final_approach_result(false, &"generation_mismatch")
	if _approach_kind != FINAL_APPROACH_KIND:
		return _final_approach_result(false, &"final_approach_not_active")
	if expected_target_generation != _final_approach_generation:
		return _final_approach_result(false, &"final_approach_generation_mismatch")
	if _final_approach_state not in [
		FinalApproachState.ARMED, FinalApproachState.ACTIVE,
	]:
		return _final_approach_result(false, &"final_approach_not_active")
	_mutation_active = true
	_final_approach_state = FinalApproachState.ABORTED
	_last_final_approach_reason = reason
	_mutation_active = false
	_emit_final_approach_changed()
	return _final_approach_result(true, reason)


func abort_return_approach(
		reason: StringName,
		expected_target_generation: int,
		expected_generation: int,
	) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _final_approach_result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _final_approach_result(false, &"generation_mismatch")
	if _approach_kind != RETURN_APPROACH_KIND:
		return _final_approach_result(false, &"return_approach_not_active")
	if expected_target_generation != _final_approach_generation:
		return _final_approach_result(false, &"return_approach_generation_mismatch")
	if _final_approach_state not in [
		FinalApproachState.ARMED, FinalApproachState.ACTIVE,
	]:
		return _final_approach_result(false, &"return_approach_not_active")
	_mutation_active = true
	_final_approach_state = FinalApproachState.ABORTED
	_last_final_approach_reason = reason
	_mutation_active = false
	_emit_final_approach_changed()
	return _final_approach_result(true, reason)


## Produces and submits exactly one proof-bearing envelope for the next ship
## physics tick. Callers must invoke this once per physics tick while cruise is
## desired; missing cadence makes HeroShip brake on its next tick.
func evaluate_and_submit(
	destination_world: Vector3,
	combat_active: bool,
	expected_coordinate_frame_generation: int,
	expected_generation: int
) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _receipt(false, &"reentrant_call")
	var binding_reason := _validate_binding(
		expected_coordinate_frame_generation,
		expected_generation
	)
	if not binding_reason.is_empty():
		return _receipt(false, binding_reason)
	if not destination_world.is_finite():
		return _receipt(false, &"destination_nonfinite")
	var ship := _resolve_ship()
	if ship == null:
		_clear_binding(&"ship_unavailable", true)
		return _receipt(false, &"ship_unavailable")
	var final_approach_measurement: Dictionary = {}
	if _approach_kind == RETURN_APPROACH_KIND \
			and _final_approach_state in [
				FinalApproachState.ARMED, FinalApproachState.ACTIVE,
			] \
			and destination_world != (
				(_final_approach_target as ReturnApproachTarget)
					.home_target_world_transform.origin
			):
		return _receipt(false, &"return_approach_home_target_mismatch")
	if _final_approach_state == FinalApproachState.ACTIVE:
		if _approach_kind == RETURN_APPROACH_KIND:
			var return_completion := _measure_return_approach(ship)
			if bool(return_completion.get("accepted", false)):
				return _commit_return_approach_completion(return_completion)
		else:
			var completion := _measure_final_approach(ship)
			if bool(completion.get("accepted", false)):
				return _commit_final_approach_completion(completion)
			final_approach_measurement = completion.duplicate(true)
			var retarget := _final_approach_policy_destination(ship)
			if not retarget.is_finite():
				return _commit_evaluation_rejection(
					&"final_approach_retarget_nonfinite", completion
				)
			destination_world = retarget
	var offset := destination_world - ship.global_position
	var distance := offset.length()
	if not is_finite(distance) \
		or distance <= 0.0 \
		or distance > PlanetaryCruisePolicyType.MAX_DISTANCE_METERS:
		return _receipt(false, &"destination_distance_out_of_bounds")
	var direction := offset / distance
	var clearance_sweep_distance := minf(
		distance,
		CLEARANCE_PROOF_HORIZON_METERS
	)
	var proof := ship.build_planetary_cruise_clearance_proof(
		direction,
		clearance_sweep_distance,
		expected_coordinate_frame_generation,
		_ship_attachment_generation,
		get_instance_id()
	)
	if not bool(proof.get("accepted", false)):
		return _commit_evaluation_rejection(
			StringName(proof.get("reason", &"clearance_proof_rejected")),
			proof
		)
	var observation := {
		"distance_to_destination_meters": float(distance),
		"ship_speed_meters_per_second": float(
			proof.get("ship_speed_meters_per_second", 0.0)
		),
		"closing_speed_meters_per_second": float(
			proof.get("closing_speed_meters_per_second", 0.0)
		),
		"alignment_basis": StringName(proof.get("alignment_basis", &"")),
		"alignment_dot": float(proof.get("alignment_dot", 0.0)),
		"coordinate_frame_generation": expected_coordinate_frame_generation,
		"verified_clearance_meters": float(
			proof.get("verified_clearance_meters", 0.0)
		),
		"clearance_sweep_distance_meters": float(
			proof.get("sweep_distance_meters", 0.0)
		),
		"clearance_proof_generation": int(
			proof.get("coordinate_frame_generation", 0)
		),
		"clearance_sweep_basis": PlanetaryCruisePolicyType.CLEARANCE_SWEEP_BASIS,
		"clearance_full_hull": bool(proof.get("clearance_full_hull", false)),
		"clearance_verified": bool(proof.get("clearance_verified", false)),
		"obstacle_detected": bool(proof.get("obstacle_detected", false)),
		"currently_participating": bool(
			proof.get("currently_participating", false)
		),
		"piloted": ship.is_piloted(),
		"destroyed": ship.is_destroyed(),
		"landing_active": ship.is_landing_active(),
		"combat_active": combat_active,
	}.duplicate(true)
	var policy_result := _policy.evaluate(
		observation,
		expected_coordinate_frame_generation
	)
	if not bool(policy_result.get("accepted", false)):
		return _commit_evaluation_rejection(
			StringName(policy_result.get("reason", &"policy_rejected")),
			{
				"proof": proof.duplicate(true),
				"observation": observation.duplicate(true),
				"policy": policy_result.duplicate(true),
			}
		)
	if _final_approach_state == FinalApproachState.ARMED \
			and not bool(policy_result.get("desired_cruise_participation", false)):
		var policy_reason := StringName(
			policy_result.get("reason", &"policy_disengaged")
		)
		if policy_reason in [
			&"destination_braking_envelope", &"insufficient_verified_clearance",
		]:
			_mutation_active = true
			_final_approach_state = FinalApproachState.ACTIVE
			_last_final_approach_reason = &"return_approach_activated" \
				if _approach_kind == RETURN_APPROACH_KIND \
				else &"final_approach_activated"
			_mutation_active = false
			_emit_final_approach_changed()
			return evaluate_and_submit(
				destination_world, combat_active,
				expected_coordinate_frame_generation, expected_generation
			)
		_mutation_active = true
		_final_approach_state = FinalApproachState.ABORTED
		_last_final_approach_reason = policy_reason
		_mutation_active = false
		_emit_final_approach_changed()
	if _sequence >= MAX_SAFE_INTEGER:
		return _commit_evaluation_rejection(&"sequence_exhausted", {})
	var candidate_sequence := _sequence + 1
	var envelope := {
		"schema_version": HeroShip.PLANETARY_CRUISE_ENVELOPE_SCHEMA_VERSION,
		"ship_instance_id": _ship_instance_id,
		"ship_attachment_generation": _ship_attachment_generation,
		"controller_instance_id": get_instance_id(),
		"controller_generation": _generation,
		"sequence": candidate_sequence,
		"coordinate_frame_generation": expected_coordinate_frame_generation,
		"destination_direction_world": direction,
		"desired_participation": bool(
			policy_result.get("desired_cruise_participation", false)
		),
		"desired_speed_meters_per_second": float(
			policy_result.get("desired_speed_meters_per_second", 0.0)
		),
		"acceleration_hint_meters_per_second_squared": float(
			policy_result.get(
				"acceleration_hint_meters_per_second_squared",
				0.0
			)
		),
		"braking_requested": bool(
			policy_result.get("braking_requested", false)
		),
		"braking_acceleration_hint_meters_per_second_squared": float(
			policy_result.get(
				"braking_acceleration_hint_meters_per_second_squared",
				0.0
			)
		),
		"policy_reason": StringName(policy_result.get("reason", &"policy_result")),
		"observation": observation.duplicate(true),
		"clearance_proof_sequence": int(proof.get("proof_sequence", 0)),
		"clearance_proof_generation": int(
			proof.get("coordinate_frame_generation", 0)
		),
		"clearance_full_hull": bool(proof.get("clearance_full_hull", false)),
		"clearance_verified": bool(proof.get("clearance_verified", false)),
		"obstacle_detected": bool(proof.get("obstacle_detected", false)),
	}.duplicate(true)
	var submit_receipt := ship.submit_planetary_cruise_envelope(envelope)
	if not bool(submit_receipt.get("accepted", false)):
		return _commit_evaluation_rejection(
			StringName(submit_receipt.get("reason", &"ship_submission_rejected")),
			{
				"proof": proof.duplicate(true),
				"observation": observation.duplicate(true),
				"policy": policy_result.duplicate(true),
				"envelope": envelope.duplicate(true),
				"ship_receipt": submit_receipt.duplicate(true),
			}
		)
	_mutation_active = true
	_sequence = candidate_sequence
	_last_envelope = envelope.duplicate(true)
	_last_result = {
		"accepted": true,
		"reason": &"envelope_submitted",
		"schema_version": SCHEMA_VERSION,
		"controller_generation": _generation,
		"sequence": _sequence,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"proof": proof.duplicate(true),
		"observation": observation.duplicate(true),
		"policy": policy_result.duplicate(true),
		"envelope": envelope.duplicate(true),
		"ship_receipt": submit_receipt.duplicate(true),
	}.duplicate(true)
	if not final_approach_measurement.is_empty():
		_last_result["final_approach_measurement"] = (
			final_approach_measurement.duplicate(true)
		)
		_last_result = _last_result.duplicate(true)
	_mutation_active = false
	_emit_evaluation_committed()
	return _last_result.duplicate(true)


func disengage(expected_generation: int, brake_to_stop: bool = true) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _receipt(false, &"reentrant_call")
	if expected_generation != _generation:
		return _receipt(false, &"generation_mismatch")
	if not _attached:
		return _receipt(false, &"not_attached")
	var ship := _resolve_ship()
	if ship == null:
		_clear_binding(&"ship_unavailable", true)
		return _receipt(false, &"ship_unavailable")
	_mutation_active = true
	var ship_receipt := ship.disengage_planetary_cruise(
		get_instance_id(),
		_ship_attachment_generation,
		brake_to_stop
	)
	if not bool(ship_receipt.get("accepted", false)):
		_mutation_active = false
		return _receipt(
			false,
			StringName(ship_receipt.get("reason", &"ship_disengage_rejected"))
		)
	_clear_binding(&"explicit_disengage", true)
	_mutation_active = false
	return _receipt(true, StringName(ship_receipt.get("reason", &"disengaged")))


## Reconciles a HeroShip-owned lifecycle retirement without replacing this
## controller. HeroShip may advance its attachment generation independently on
## unpilot, landing, destruction, collision, reset, detach, or missed cadence.
## In that case an ordinary disengage is intentionally stale; this method only
## clears the controller's local binding after proving that the exact prior
## attachment is no longer current. It never asks the ship to move or brake.
func reconcile_retired_ship_binding(expected_generation: int) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _receipt(false, &"reentrant_call")
	if expected_generation != _generation:
		return _receipt(false, &"generation_mismatch")
	if not _attached:
		return _receipt(true, &"already_detached")
	if not _controller_is_live():
		return _receipt(false, &"controller_unavailable")
	var ship := _resolve_ship()
	if ship != null:
		var report := ship.get_planetary_cruise_attachment_report()
		if (
			int(report.get("ship_instance_id", 0)) == _ship_instance_id
			and int(report.get("ship_attachment_generation", 0))
				== _ship_attachment_generation
			and int(report.get("controller_instance_id", 0)) == get_instance_id()
		):
			return _receipt(false, &"ship_binding_still_current")
	_mutation_active = true
	_clear_binding(&"ship_binding_retired", true)
	_mutation_active = false
	return _receipt(true, &"ship_binding_reconciled")


func get_generation() -> int:
	return _generation


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"generation": _generation,
		"attached": _attached,
		"ship_instance_id": _ship_instance_id,
		"ship_attachment_generation": _ship_attachment_generation,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"sequence": _sequence,
		"last_result": _last_result.duplicate(true),
		"last_envelope": _last_envelope.duplicate(true),
		"final_approach": _final_approach_snapshot(),
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"valid": _policy.audit().get("valid", false),
		"schema_version": SCHEMA_VERSION,
		"caller_driven": true,
		"has_process_loop": false,
		"full_hull_query_owner": &"hero_ship",
		"movement_owner": &"hero_ship",
		"command_delivery": &"one_detached_envelope_per_physics_tick",
		"fixed_orientation": true,
		"final_approach_policy": &"existing_cruise_policy_dynamic_brake_retarget",
		"return_approach_policy": &"existing_cruise_policy_brake_complete_shell",
		"common_authority": _zero_authority(),
		"adjacent_capabilities": {
			"policy_evaluation": true,
			"collision_query_request": true,
			"clearance_proof_request": true,
			"intent_submission": true,
			"typed_final_approach_target": true,
			"final_approach_completion_measurement": true,
			"typed_return_approach_target": true,
			"full_flyable_fleet_return_corridor_proof": true,
			"return_brake_complete_shell_measurement": true,
			"input_sampling": false,
			"velocity_write": false,
			"move_and_slide": false,
			"transform_write": false,
			"teleport": false,
			"landing_decision": false,
			"combat_decision": false,
		}.duplicate(true),
	}.duplicate(true)


func _measure_final_approach(ship: HeroShip) -> Dictionary:
	if not _final_approach_target is FinalApproachTarget:
		return {"accepted": false, "reason": &"final_approach_target_unavailable"}
	var target := _final_approach_target as FinalApproachTarget
	var ship_transform := ship.global_transform
	if not ship_transform.origin.is_finite() \
			or not ship_transform.basis.x.is_finite() \
			or not ship.velocity.is_finite():
		return {"accepted": false, "reason": &"final_approach_actor_nonfinite"}
	var entry_local := target.target_world_transform.affine_inverse() \
		* ship_transform.origin
	var speed := ship.velocity.length()
	var attitude := rad_to_deg(
		Quaternion(target.target_world_transform.basis.orthonormalized()).angle_to(
			Quaternion(ship_transform.basis.orthonormalized())
		)
	)
	var root_inside := _point_inside(
		entry_local, target.entry_position_half_extents_m, 0.0
	)
	var hull_inside := _oriented_bounds_inside(
		target.target_world_transform, target.corridor_half_extents_m,
		ship_transform, target.collision_bounds, target.hull_margin_m
	)
	var accepted := root_inside and hull_inside \
		and speed <= target.maximum_speed_mps \
		and attitude <= target.maximum_attitude_degrees
	return {
		"accepted": accepted,
		"reason": &"final_approach_envelope_accepted" if accepted \
			else &"final_approach_converging",
		"target_generation": _final_approach_generation,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"ship_instance_id": _ship_instance_id,
		"ship_attachment_generation": _ship_attachment_generation,
		"position_offset_entry_local_m": entry_local,
		"speed_mps": speed,
		"attitude_degrees": attitude,
		"root_inside_entry_volume": root_inside,
		"full_hull_inside_authored_corridor": hull_inside,
	}.duplicate(true)


func _measure_return_approach(ship: HeroShip) -> Dictionary:
	if not _final_approach_target is ReturnApproachTarget:
		return {"accepted": false, "reason": &"return_approach_target_unavailable"}
	var target := _final_approach_target as ReturnApproachTarget
	var ship_transform := ship.global_transform
	if not ship_transform.origin.is_finite() \
			or not ship_transform.basis.x.is_finite() \
			or not ship.velocity.is_finite():
		return {"accepted": false, "reason": &"return_approach_actor_nonfinite"}
	var home_local := target.home_target_world_transform.affine_inverse() \
		* ship_transform.origin
	var distance := home_local.length()
	var speed := ship.velocity.length()
	var attitude := rad_to_deg(
		Quaternion(target.home_target_world_transform.basis.orthonormalized()).angle_to(
			Quaternion(ship_transform.basis.orthonormalized())
		)
	)
	var shell_inside := distance >= target.brake_shell_min_distance_m \
		and distance <= target.brake_shell_max_distance_m
	var root_inside := _point_inside(
		home_local, target.corridor_half_extents_m, 0.0
	)
	var hull_inside := _oriented_bounds_inside(
		target.home_target_world_transform, target.corridor_half_extents_m,
		ship_transform, target.collision_bounds, target.hull_margin_m
	)
	var fleet_proof := target.get_snapshot().get(
		"fleet_corridor_proof", {}
	) as Dictionary
	var accepted := shell_inside and root_inside and hull_inside \
		and bool(fleet_proof.get("accepted", false)) \
		and speed <= target.maximum_speed_mps \
		and attitude <= target.maximum_attitude_degrees
	return {
		"accepted": accepted,
		"reason": &"return_approach_brake_shell_accepted" if accepted \
			else &"return_approach_braking",
		"target_generation": _final_approach_generation,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"ship_instance_id": _ship_instance_id,
		"ship_attachment_generation": _ship_attachment_generation,
		"home_offset_local_m": home_local,
		"distance_to_home_m": distance,
		"speed_mps": speed,
		"attitude_degrees": attitude,
		"inside_brake_complete_shell": shell_inside,
		"root_inside_return_corridor": root_inside,
		"full_hull_inside_return_corridor": hull_inside,
		"full_flyable_fleet_corridor_proven": bool(
			fleet_proof.get("accepted", false)
		),
		"fleet_corridor_proof": fleet_proof.duplicate(true),
	}.duplicate(true)


func _final_approach_policy_destination(ship: HeroShip) -> Vector3:
	if not _final_approach_target is FinalApproachTarget:
		return Vector3.INF
	var target := _final_approach_target as FinalApproachTarget
	var approach_direction := (
		-target.target_world_transform.basis.z
	).normalized()
	if not approach_direction.is_finite() or approach_direction.is_zero_approx():
		return Vector3.INF
	# The existing policy adds response distance and a fixed braking margin to
	# its physical stopping distance. Placing its ephemeral destination exactly
	# that far beyond the accepted entry centre makes its unchanged brake-shell
	# predicate reduce to `distance_to_entry <= physical_stopping_distance`.
	# The Hero remains the only body that integrates the resulting envelope.
	var policy_lead := ship.velocity.length() \
		* PlanetaryCruisePolicyType.BRAKE_RESPONSE_SECONDS \
		+ PlanetaryCruisePolicyType.BRAKE_FIXED_MARGIN_METERS
	return target.target_world_transform.origin \
		+ approach_direction * policy_lead


func _commit_final_approach_completion(measurement: Dictionary) -> Dictionary:
	_mutation_active = true
	_final_approach_state = FinalApproachState.COMPLETED
	_last_final_approach_reason = &"final_approach_completed"
	_last_final_approach_receipt = {
		"accepted": true,
		"reason": &"final_approach_completed",
		"schema_version": SCHEMA_VERSION,
		"target_id": FINAL_APPROACH_TARGET_ID,
		"target_generation": _final_approach_generation,
		"controller_generation": _generation,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"ship_instance_id": _ship_instance_id,
		"ship_attachment_generation": _ship_attachment_generation,
		"target": _final_approach_target.get_snapshot(),
		"measurement": measurement.duplicate(true),
	}.duplicate(true)
	_last_result = {
		"accepted": true,
		"reason": &"final_approach_completed",
		"schema_version": SCHEMA_VERSION,
		"controller_generation": _generation,
		"sequence": _sequence,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"completion_receipt": _last_final_approach_receipt.duplicate(true),
	}.duplicate(true)
	_mutation_active = false
	_emit_final_approach_changed()
	_emit_final_approach_completed()
	_emit_evaluation_committed()
	return _last_result.duplicate(true)


func _commit_return_approach_completion(measurement: Dictionary) -> Dictionary:
	_mutation_active = true
	_final_approach_state = FinalApproachState.COMPLETED
	_last_final_approach_reason = &"return_approach_completed"
	_last_final_approach_receipt = {
		"accepted": true,
		"reason": &"return_approach_completed",
		"schema_version": SCHEMA_VERSION,
		"target_id": RETURN_APPROACH_TARGET_ID,
		"target_generation": _final_approach_generation,
		"controller_generation": _generation,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"ship_instance_id": _ship_instance_id,
		"ship_attachment_generation": _ship_attachment_generation,
		"target": _final_approach_target.get_snapshot(),
		"measurement": measurement.duplicate(true),
	}.duplicate(true)
	_last_result = {
		"accepted": true,
		"reason": &"return_approach_completed",
		"schema_version": SCHEMA_VERSION,
		"controller_generation": _generation,
		"sequence": _sequence,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"completion_receipt": _last_final_approach_receipt.duplicate(true),
	}.duplicate(true)
	_mutation_active = false
	_emit_final_approach_changed()
	_emit_return_approach_completed()
	_emit_evaluation_committed()
	return _last_result.duplicate(true)


func _final_approach_snapshot() -> Dictionary:
	return {
		"approach_kind": _approach_kind,
		"state": _final_approach_state,
		"state_id": _final_approach_state_id(_final_approach_state),
		"target_generation": _final_approach_generation,
		"reason": _last_final_approach_reason,
		"target": _final_approach_target.get_snapshot() \
			if _final_approach_target != null else {},
		"last_completion_receipt": _last_final_approach_receipt.duplicate(true),
	}.duplicate(true)


func _final_approach_state_id(state: int) -> StringName:
	match state:
		FinalApproachState.ARMED: return &"armed"
		FinalApproachState.ACTIVE:
			return &"return_approach" \
				if _approach_kind == RETURN_APPROACH_KIND \
				else &"final_approach"
		FinalApproachState.COMPLETED: return &"completed"
		FinalApproachState.ABORTED: return &"aborted"
		_: return &"none"


static func _point_inside(
		point: Vector3, half_extents: Vector3, margin: float
	) -> bool:
	return absf(point.x) <= half_extents.x - margin \
		and absf(point.y) <= half_extents.y - margin \
		and absf(point.z) <= half_extents.z - margin


static func _oriented_bounds_inside(
		volume_transform: Transform3D,
		half_extents: Vector3,
		body_transform: Transform3D,
		bounds: AABB,
		margin: float,
	) -> bool:
	var inverse := volume_transform.affine_inverse()
	for x: float in [bounds.position.x, bounds.end.x]:
		for y: float in [bounds.position.y, bounds.end.y]:
			for z: float in [bounds.position.z, bounds.end.z]:
				var corner := inverse * (body_transform * Vector3(x, y, z))
				if not _point_inside(corner, half_extents, margin):
					return false
	return true


func _validate_binding(
	expected_coordinate_frame_generation: int,
	expected_generation: int
) -> StringName:
	if not _controller_is_live():
		return &"controller_unavailable"
	if expected_generation != _generation:
		return &"generation_mismatch"
	if not _attached:
		return &"not_attached"
	if expected_coordinate_frame_generation != _coordinate_frame_generation:
		return &"coordinate_frame_generation_mismatch"
	var ship := _resolve_ship()
	if ship == null:
		return &"ship_unavailable"
	var report := ship.get_planetary_cruise_attachment_report()
	if int(report.get("ship_instance_id", 0)) != _ship_instance_id:
		return &"ship_instance_mismatch"
	if int(report.get("ship_attachment_generation", 0)) \
		!= _ship_attachment_generation:
		return &"ship_attachment_generation_mismatch"
	if int(report.get("controller_instance_id", 0)) != get_instance_id():
		return &"ship_controller_identity_mismatch"
	return &""


func _resolve_ship() -> HeroShip:
	if _ship_ref == null:
		return null
	var candidate: Variant = _ship_ref.get_ref()
	if not candidate is HeroShip \
		or not is_instance_valid(candidate) \
		or (candidate as HeroShip).is_queued_for_deletion() \
		or not (candidate as HeroShip).is_inside_tree() \
		or (candidate as HeroShip).get_instance_id() != _ship_instance_id:
		return null
	return candidate as HeroShip


func _controller_is_live() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _commit_evaluation_rejection(reason: StringName, evidence: Dictionary) -> Dictionary:
	_mutation_active = true
	_last_result = {
		"accepted": false,
		"reason": reason,
		"schema_version": SCHEMA_VERSION,
		"controller_generation": _generation,
		"sequence": _sequence,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"evidence": evidence.duplicate(true),
	}.duplicate(true)
	_mutation_active = false
	_emit_evaluation_committed()
	return _last_result.duplicate(true)


func _clear_binding(reason: StringName, advance_generation: bool) -> void:
	var changed := _attached or _ship_instance_id != 0
	_ship_ref = null
	_ship_instance_id = 0
	_ship_attachment_generation = 0
	_coordinate_frame_generation = 0
	_sequence = 0
	_attached = false
	_last_envelope = {}
	_final_approach_state = FinalApproachState.NONE
	_approach_kind = &""
	_final_approach_generation = 0
	_last_final_approach_reason = reason
	_last_final_approach_receipt.clear()
	_final_approach_target = null
	_last_result = {
		"accepted": true,
		"reason": reason,
		"schema_version": SCHEMA_VERSION,
	}.duplicate(true)
	if advance_generation:
		_generation = 1 if _generation >= MAX_SAFE_INTEGER else _generation + 1
	if changed:
		_emit_binding_changed()


func _emit_binding_changed() -> void:
	if _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	binding_changed.emit(get_snapshot().duplicate(true))
	_signal_dispatch_active = false


func _emit_evaluation_committed() -> void:
	if _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	evaluation_committed.emit(_last_result.duplicate(true))
	_signal_dispatch_active = false


func _emit_final_approach_changed() -> void:
	if _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	final_approach_changed.emit(_final_approach_snapshot())
	if _approach_kind == RETURN_APPROACH_KIND:
		return_approach_changed.emit(_final_approach_snapshot())
	_signal_dispatch_active = false


func _emit_final_approach_completed() -> void:
	if _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	final_approach_completed.emit(_last_final_approach_receipt.duplicate(true))
	_signal_dispatch_active = false


func _emit_return_approach_completed() -> void:
	if _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	return_approach_completed.emit(_last_final_approach_receipt.duplicate(true))
	_signal_dispatch_active = false


func _final_approach_result(
		accepted: bool, reason: StringName
	) -> Dictionary:
	var result := _receipt(accepted, reason)
	result["final_approach"] = _final_approach_snapshot()
	return result.duplicate(true)


func _receipt(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"schema_version": SCHEMA_VERSION,
		"generation": _generation,
		"attached": _attached,
		"ship_instance_id": _ship_instance_id,
		"ship_attachment_generation": _ship_attachment_generation,
		"coordinate_frame_generation": _coordinate_frame_generation,
	}.duplicate(true)


static func _zero_authority() -> Dictionary:
	var result := {}
	for key in _COMMON_AUTHORITY_KEYS:
		result[key] = false
	return result.duplicate(true)
