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

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
## Conservative physical horizon above the pure policy's 731,666.67 m default
## engagement requirement. Higher current speeds fail closed when this horizon
## cannot cover their larger braking envelope.
const CLEARANCE_PROOF_HORIZON_METERS := 750_000.0
const PlanetaryCruisePolicyType := preload(
	"res://scripts/world/planetary_cruise_policy.gd"
)

const _COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]

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
		"common_authority": _zero_authority(),
		"adjacent_capabilities": {
			"policy_evaluation": true,
			"collision_query_request": true,
			"clearance_proof_request": true,
			"intent_submission": true,
			"input_sampling": false,
			"velocity_write": false,
			"move_and_slide": false,
			"transform_write": false,
			"teleport": false,
			"landing_decision": false,
			"combat_decision": false,
		}.duplicate(true),
	}.duplicate(true)


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
