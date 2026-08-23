class_name EmberAirlessEnvironmentPresentation
extends RefCounted

## Passive adapter for the one authored Environment already installed by Main.
## It consumes an accepted Ember sun evaluation and scales only captured
## ambient baselines. Sky/background identity and sun geometry remain external.

const COMPONENT_ID: StringName = &"ember-airless-environment-presentation"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const TERMINATOR_CLEARANCE_DEGREES := 5.0
const DAY_AMBIENT_MULTIPLIER := 0.32
const DAY_SKY_MULTIPLIER := 0.42
const TERMINATOR_AMBIENT_MULTIPLIER := 0.12
const TERMINATOR_SKY_MULTIPLIER := 0.18
const NIGHT_AMBIENT_MULTIPLIER := 0.025
const NIGHT_SKY_MULTIPLIER := 0.04

var _target_ref: WeakRef
var _environment_ref: WeakRef
var _sun_ref: WeakRef
var _target_instance_id := 0
var _environment_instance_id := 0
var _sky_instance_id := 0
var _sky_material_instance_id := 0
var _sun_instance_id := 0
var _location_generation := 0
var _coordinate_frame_generation := 0
var _generation := 0
var _baseline: Dictionary = {}
var _current: Dictionary = {}
var _last_result: Dictionary = {}
var _present_count := 0
var _restore_count := 0


func configure(
		target: WorldEnvironment, sun: EmberAirlessSunBinding,
		coordinate_frame_generation: int, location_generation: int
	) -> Dictionary:
	if _generation != 0:
		return _result(false, &"already_configured")
	if target == null or not is_instance_valid(target) \
			or not target.is_inside_tree() or target.environment == null:
		return _result(false, &"authored_environment_unavailable")
	if sun == null or not is_instance_valid(sun) or not sun.is_inside_tree():
		return _result(false, &"sun_binding_unavailable")
	if not _valid_generation(coordinate_frame_generation) \
			or not _valid_generation(location_generation):
		return _result(false, &"invalid_streaming_generation")
	var environment := target.environment
	if environment.background_mode != Environment.BG_SKY \
			or environment.sky == null or environment.sky.sky_material == null:
		return _result(false, &"authored_black_sky_chain_unavailable")
	var sun_snapshot := sun.get_snapshot()
	if not bool(sun_snapshot.get("configured", false)) \
			or int(sun_snapshot.get("coordinate_frame_generation", 0)) \
			!= coordinate_frame_generation \
			or int(sun_snapshot.get("location_generation", 0)) \
			!= location_generation:
		return _result(false, &"sun_generation_mismatch")
	_target_ref = weakref(target)
	_environment_ref = weakref(environment)
	_sun_ref = weakref(sun)
	_target_instance_id = target.get_instance_id()
	_environment_instance_id = environment.get_instance_id()
	_sky_instance_id = environment.sky.get_instance_id()
	_sky_material_instance_id = environment.sky.sky_material.get_instance_id()
	_sun_instance_id = sun.get_instance_id()
	_location_generation = location_generation
	_coordinate_frame_generation = coordinate_frame_generation
	_baseline = _read_owned_values(environment)
	_current = _baseline.duplicate(true)
	_generation = 1
	return _result(true, &"configured")


func present_accepted_sun(
		sun_result: Dictionary, coordinate_frame_generation: int,
		location_generation: int, expected_generation: int
	) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	var identity_reason := _identity_reason(
		coordinate_frame_generation, location_generation
	)
	if not identity_reason.is_empty():
		return _result(false, identity_reason)
	if not bool(sun_result.get("accepted", false)):
		return _result(false, &"sun_sample_not_accepted")
	var evaluation := sun_result.get("evaluation", {}) as Dictionary
	var geometry := evaluation.get("geometry", {}) as Dictionary
	var atmosphere := evaluation.get("atmosphere", {}) as Dictionary
	if evaluation.get("world_id", &"") != &"ember_moon" \
			or bool(atmosphere.get("world_has_atmosphere", true)) \
			or geometry.get("sun_horizon_clearance_degrees") is not float:
		return _result(false, &"invalid_airless_sun_evaluation")
	var clearance := float(geometry.sun_horizon_clearance_degrees)
	if not is_finite(clearance):
		return _result(false, &"invalid_sun_clearance")
	var visual_state := _visual_state(clearance)
	var multipliers := _multipliers(visual_state)
	var environment := _environment()
	var requested := {
		"ambient_light_energy": float(_baseline.ambient_light_energy) \
			* float(multipliers.ambient),
		"ambient_light_sky_contribution": clampf(
			float(_baseline.ambient_light_sky_contribution) \
				* float(multipliers.sky), 0.0, 1.0
		),
		"fog_enabled": false,
	}.duplicate(true)
	_apply_owned_values(environment, requested)
	# Retain the actual property representation so the audit compares like for
	# like even if a renderer-backed property narrows the assigned float.
	_current = _read_owned_values(environment)
	_coordinate_frame_generation = coordinate_frame_generation
	_present_count += 1
	_last_result = _result(true, &"airless_environment_presented", {
		"visual_state": visual_state,
		"sun_horizon_clearance_degrees": clearance,
		"relative_multipliers": multipliers.duplicate(true),
	})
	return _last_result.duplicate(true)


func detach(reason: StringName, expected_generation: int) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	var environment := _environment()
	if environment != null:
		_apply_owned_values(environment, _baseline)
	_current = _baseline.duplicate(true)
	_restore_count += 1
	_generation += 1
	var result := _result(true, reason)
	_target_ref = null
	_environment_ref = null
	_sun_ref = null
	return result


func get_generation() -> int:
	return _generation


func get_snapshot() -> Dictionary:
	var environment := _environment()
	return {
		"component_id": COMPONENT_ID,
		"configured": _generation > 0 and environment != null,
		"generation": _generation,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"location_generation": _location_generation,
		"target_instance_id": _target_instance_id,
		"environment_instance_id": _environment_instance_id,
		"sky_instance_id": _sky_instance_id,
		"sky_material_instance_id": _sky_material_instance_id,
		"sun_instance_id": _sun_instance_id,
		"baseline": _baseline.duplicate(true),
		"current": _current.duplicate(true),
		"actual": _read_owned_values(environment) if environment != null else {},
		"present_count": _present_count,
		"restore_count": _restore_count,
		"last_result": _last_result.duplicate(true),
		"black_star_field_preserved": _black_sky_identity_is_current(environment),
		"node_budget": 0,
		"resource_budget": 0,
		"presentation_only": true,
		"sun_direction_authority": false,
		"clock_authority": false,
		"ephemeris_authority": false,
		"camera_authority": false,
		"gameplay_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var snapshot := get_snapshot()
	var errors := PackedStringArray()
	if _generation < 1:
		errors.append("presentation_not_configured")
	var identity_reason := _identity_reason(
		_coordinate_frame_generation, _location_generation
	)
	if not identity_reason.is_empty():
		errors.append(String(identity_reason))
	if snapshot.actual != snapshot.current:
		errors.append("owned_environment_values_drift")
	if not bool(snapshot.black_star_field_preserved):
		errors.append("black_star_field_identity_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": snapshot,
		"owned_properties": PackedStringArray([
			"Environment.ambient_light_energy",
			"Environment.ambient_light_sky_contribution",
			"Environment.fog_enabled",
		]),
		"runtime_world_environment_creation": false,
		"runtime_environment_resource_creation": false,
	}.duplicate(true)


func _identity_reason(
		coordinate_frame_generation: int, location_generation: int
	) -> StringName:
	var target := _target()
	var environment := _environment()
	var sun := _sun()
	if target == null or environment == null:
		return &"authored_environment_unavailable"
	if target.environment != environment \
			or target.get_instance_id() != _target_instance_id \
			or environment.get_instance_id() != _environment_instance_id:
		return &"authored_environment_identity_drift"
	if sun == null or sun.get_instance_id() != _sun_instance_id:
		return &"sun_binding_identity_drift"
	var sun_snapshot := sun.get_snapshot()
	if int(sun_snapshot.get("coordinate_frame_generation", 0)) \
			!= coordinate_frame_generation:
		return &"stale_coordinate_frame_generation"
	if location_generation != _location_generation \
			or int(sun_snapshot.get("location_generation", 0)) \
			!= location_generation:
		return &"stale_location_generation"
	if not _black_sky_identity_is_current(environment):
		return &"black_star_field_identity_drift"
	return &""


func _visual_state(clearance_degrees: float) -> StringName:
	if clearance_degrees > TERMINATOR_CLEARANCE_DEGREES:
		return &"surface_day"
	if clearance_degrees >= -TERMINATOR_CLEARANCE_DEGREES:
		return &"airless_terminator"
	return &"surface_night"


func _multipliers(state: StringName) -> Dictionary:
	match state:
		&"surface_day":
			return {"ambient": DAY_AMBIENT_MULTIPLIER, "sky": DAY_SKY_MULTIPLIER}
		&"airless_terminator":
			return {
				"ambient": TERMINATOR_AMBIENT_MULTIPLIER,
				"sky": TERMINATOR_SKY_MULTIPLIER,
			}
		_:
			return {"ambient": NIGHT_AMBIENT_MULTIPLIER, "sky": NIGHT_SKY_MULTIPLIER}


func _target() -> WorldEnvironment:
	if _target_ref == null:
		return null
	var candidate: Variant = _target_ref.get_ref()
	return candidate as WorldEnvironment \
		if is_instance_valid(candidate) and candidate is WorldEnvironment else null


func _environment() -> Environment:
	if _environment_ref == null:
		return null
	var candidate: Variant = _environment_ref.get_ref()
	return candidate as Environment \
		if is_instance_valid(candidate) and candidate is Environment else null


func _sun() -> EmberAirlessSunBinding:
	if _sun_ref == null:
		return null
	var candidate: Variant = _sun_ref.get_ref()
	return candidate as EmberAirlessSunBinding \
		if is_instance_valid(candidate) and candidate is EmberAirlessSunBinding else null


func _read_owned_values(environment: Environment) -> Dictionary:
	if environment == null:
		return {}
	return {
		"ambient_light_energy": environment.ambient_light_energy,
		"ambient_light_sky_contribution": (
			environment.ambient_light_sky_contribution
		),
		"fog_enabled": environment.fog_enabled,
	}.duplicate(true)


func _apply_owned_values(environment: Environment, values: Dictionary) -> void:
	environment.ambient_light_energy = float(values.ambient_light_energy)
	environment.ambient_light_sky_contribution = float(
		values.ambient_light_sky_contribution
	)
	environment.fog_enabled = bool(values.fog_enabled)


func _black_sky_identity_is_current(environment: Environment) -> bool:
	return environment != null \
		and environment.background_mode == Environment.BG_SKY \
		and environment.sky != null \
		and environment.sky.get_instance_id() == _sky_instance_id \
		and environment.sky.sky_material != null \
		and environment.sky.sky_material.get_instance_id() \
			== _sky_material_instance_id


func _valid_generation(value: int) -> bool:
	return value >= 1 and value <= MAX_SAFE_GENERATION


func _result(
		accepted: bool, reason: StringName, extra: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"presentation_only": true,
		"gameplay_authority": false,
	}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
