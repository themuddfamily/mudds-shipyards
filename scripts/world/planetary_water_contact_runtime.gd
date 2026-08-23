class_name PlanetaryWaterContactRuntime
extends RefCounted

## Caller-evidence water contact runtime over one authored water contract.
## It emits bounded buoyancy/drag/recovery requests and owns no physics,
## actor, health, movement, or water simulation state.

const ContractScript := preload("res://scripts/world/planetary_water_surface_material_contract.gd")
const MAX_DEPTH_M := 100.0
const MAX_SPEED_MPS := 1_000.0
const MAX_DELTA_SECONDS := 10.0
const CONTACT_REACH_M := 20.0

enum State { IDLE, CONTACT, DETACHED }

var _contract: PlanetaryWaterSurfaceMaterialContract
var _water_body_id: StringName = &""
var _recovery_id: StringName = &""
var _state := State.IDLE
var _attachment_generation := 0


func configure(contract: PlanetaryWaterSurfaceMaterialContract) -> Dictionary:
	if _contract != null:
		return _result(false, &"already_configured")
	if contract == null or not contract.is_definition_valid():
		return _result(false, &"invalid_water_contract")
	_contract = contract
	var snapshot := contract.get_snapshot()
	_water_body_id = StringName(snapshot.water.body_id)
	var hazards := snapshot.get("shoreline_hazards", []) as Array
	if not hazards.is_empty():
		_recovery_id = StringName((hazards[0] as Dictionary).get("recovery_id", &""))
	return _result(true, &"configured")


func enter_water(
		position: Variant, attachment_generation: Variant
	) -> Dictionary:
	if _contract == null:
		return _result(false, &"not_configured")
	if _state != State.IDLE:
		return _result(false, &"water_contact_not_available")
	if not _finite_vector(position) or not _valid_generation(attachment_generation):
		return _result(false, &"invalid_contact_evidence")
	_attachment_generation = int(attachment_generation)
	_state = State.CONTACT
	return _result(true, &"water_contact_entered")


func sample_contact(
		depth_m: Variant,
		velocity_mps: Variant,
		delta_seconds: Variant,
		expected_attachment_generation: Variant
	) -> Dictionary:
	if _state != State.CONTACT:
		return _result(false, &"water_contact_inactive")
	if int(expected_attachment_generation) != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	if not _finite_range(depth_m, 0.0, MAX_DEPTH_M) \
			or not _finite_vector(velocity_mps) \
			or (velocity_mps as Vector3).length() > MAX_SPEED_MPS \
			or not _finite_range(delta_seconds, 0.0, MAX_DELTA_SECONDS):
		return _result(false, &"invalid_contact_sample")
	var depth := float(depth_m)
	var velocity := velocity_mps as Vector3
	var submerged := clampf(depth / CONTACT_REACH_M, 0.0, 1.0)
	var drag := clampf(velocity.length() / MAX_SPEED_MPS + submerged * 0.5, 0.0, 1.0)
	return _result(true, &"water_contact_sampled", {
		"water_body_id": _water_body_id,
		"buoyancy_request": {"unitless": submerged, "physics_mutation": false},
		"drag_request": {"unitless": drag, "physics_mutation": false},
		"recovery_request": {
			"requested": depth >= CONTACT_REACH_M,
			"recovery_id": _recovery_id,
			"movement_mutation": false,
		},
	})


func exit_water(expected_attachment_generation: Variant) -> Dictionary:
	if _state != State.CONTACT:
		return _result(false, &"water_contact_inactive")
	if int(expected_attachment_generation) != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	_state = State.IDLE
	return _result(true, &"water_contact_exited")


func detach() -> Dictionary:
	if _state != State.CONTACT:
		return _result(false, &"water_contact_inactive")
	_state = State.DETACHED
	return _result(true, &"water_contact_detached")


func reenter(new_attachment_generation: Variant) -> Dictionary:
	if _state != State.DETACHED or not _valid_generation(new_attachment_generation):
		return _result(false, &"water_reentry_unavailable")
	if int(new_attachment_generation) <= _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	_attachment_generation = int(new_attachment_generation)
	_state = State.CONTACT
	return _result(true, &"water_contact_reentered")


func get_snapshot() -> Dictionary:
	return {
		"state": [&"idle", &"contact", &"detached"][_state],
		"water_body_id": _water_body_id,
		"attachment_generation": _attachment_generation,
		"recovery_id": _recovery_id,
		"authority": {"physics": false, "movement": false, "health": false, "water_simulation": false},
	}.duplicate(true)


func _valid_generation(value: Variant) -> bool:
	return value is int and int(value) > 0


func _finite_range(value: Variant, minimum: float, maximum: float) -> bool:
	if value is not float and value is not int:
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum


func _finite_vector(value: Variant) -> bool:
	return value is Vector3 and (value as Vector3).is_finite()


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := extra.duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	result["runtime"] = get_snapshot()
	return result.duplicate(true)
