class_name PlanetaryEntryHeatPresentation
extends Node

## Passive adapter from one validated PlanetaryAtmosphereProfile to one
## caller-owned entry-heat ShaderMaterial.
##
## Callers supply finite altitude/speed observations. This component freezes a
## detached atmosphere contract and owns exactly one normalized shader uniform.
## It never infers motion, damage, airflow direction, time, quality, or a ship.

signal presentation_committed(reason: StringName, snapshot: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"planetary-entry-heat-presentation"
const EQUATION_VERSION: StringName = &"entry_heat_material_intensity_v1"
const OWNED_SHADER_PARAMETER: StringName = &"entry_effect_intensity_unitless"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const REQUIRED_SHADER_PARAMETER_TYPE := TYPE_FLOAT
const AUTHORITY := {
	"renderer": true,
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
}
const ADJACENT_AUTHORITY := {
	"material_ownership": false,
	"shader_ownership": false,
	"target_geometry_ownership": false,
	"ship_visibility": false,
	"ship_attachment": false,
	"movement": false,
	"airflow_direction": false,
	"physics_drag": false,
	"damage": false,
	"gameplay_heat": false,
	"weather": false,
	"clock": false,
	"visual_quality": false,
	"particles": false,
	"lights": false,
	"audio": false,
	"streaming": false,
	"save": false,
	"network": false,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}

var _configured := false
var _profile_id: StringName = &""
var _source_profile_schema_version := 0
var _profile_snapshot: Dictionary = {}
var _sampler: PlanetaryAtmosphereSampler
var _material_ref: WeakRef
var _shader_ref: WeakRef
var _material_instance_id := 0
var _shader_instance_id := 0
var _shader_code_snapshot := ""
var _baseline_intensity := 0.0
var _current_intensity := 0.0
var _last_observation: Dictionary = {}
var _generation := 0
var _revision := 0
var _presented_observation_count := 0
var _reset_count := 0
var _mutation_active := false
var _signal_dispatch_active := false
var _lifecycle_apply_active := false
var _last_lifecycle_result: Dictionary = {}


func _enter_tree() -> void:
	if _configured:
		_lifecycle_apply_active = true
		_last_lifecycle_result = _apply_intensity(_current_intensity)
		_lifecycle_apply_active = false


func _exit_tree() -> void:
	if _configured:
		_lifecycle_apply_active = true
		_last_lifecycle_result = _apply_intensity(_baseline_intensity)
		_lifecycle_apply_active = false


## Configures once against an exclusive caller-owned spatial ShaderMaterial.
## The source profile is never mutated or retained. The material/shader are kept
## only by weak identity; later presentation calls mutate the one owned uniform.
func configure(
		profile: PlanetaryAtmosphereProfile,
		material: ShaderMaterial
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if _configured:
		return _result(false, &"already_configured")
	if profile == null:
		return _result(false, &"missing_profile")
	if material == null or not is_instance_valid(material):
		return _result(false, &"missing_material")
	var profile_audit := profile.get_audit_report()
	if not profile.is_definition_valid() \
			or not bool(profile_audit.get("valid", false)):
		return _result(false, &"invalid_profile", {
			"profile_errors": (
				profile_audit.get("errors", PackedStringArray()) \
					as PackedStringArray
			).duplicate(),
		})
	var target_result := _validate_unconfigured_target(material)
	if not bool(target_result.get("accepted", false)):
		return _result(
			false, StringName(target_result.get("reason", &"invalid_target"))
		)
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	var sampler := PlanetaryAtmosphereSampler.new()
	var sampler_result := sampler.configure(profile)
	if not bool(sampler_result.get("accepted", false)) \
			or not bool(sampler.audit().get("valid", false)):
		return _result(false, &"sampler_configuration_failed")
	var baseline: Variant = material.get_shader_parameter(
		OWNED_SHADER_PARAMETER
	)
	if not _is_unit_number(baseline) or float(baseline) != 0.0:
		return _result(false, &"baseline_must_be_zero")
	var shader := material.shader

	_mutation_active = true
	_profile_id = StringName(profile_audit.get("profile_id", &""))
	_source_profile_schema_version = int(profile_audit.get("schema_version", 0))
	_profile_snapshot = profile_audit.duplicate(true)
	_sampler = sampler
	_material_ref = weakref(material)
	_shader_ref = weakref(shader)
	_material_instance_id = material.get_instance_id()
	_shader_instance_id = shader.get_instance_id()
	_shader_code_snapshot = shader.code
	_baseline_intensity = 0.0
	_current_intensity = 0.0
	_generation += 1
	_configured = true
	_last_lifecycle_result = {
		"accepted": true,
		"reason": &"configured_in_current_tree_state",
	}.duplicate(true)
	_mutation_active = false
	_commit(&"configured")
	return _result(true, &"configured")


## Maps one caller-owned altitude/speed observation through the frozen
## atmosphere sampler. No delta, clock, vector, or ship state is inferred.
func present_observation(
		altitude_m: Variant,
		speed_mps: Variant,
		expected_generation: Variant
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if not _is_exact_generation(expected_generation) \
			or int(expected_generation) != _generation:
		return _result(false, &"stale_generation")
	# This public adapter has no owner-gated caller. A detached or queued sample
	# must not become retained intent that appears only after a later re-entry.
	if is_queued_for_deletion() or not is_inside_tree():
		return _result(false, &"presentation_detached")
	if not _is_finite_number(altitude_m):
		return _result(false, &"invalid_altitude")
	if not _is_finite_number(speed_mps):
		return _result(false, &"invalid_speed")
	var altitude := float(altitude_m)
	var speed := float(speed_mps)
	var geometry := _profile_snapshot.get("geometry", {}) as Dictionary
	var planet_radius := float(geometry.get("planet_radius_m", NAN))
	if altitude < -planet_radius \
			or altitude > PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M:
		return _result(false, &"invalid_altitude")
	if speed < 0.0 or speed > PlanetaryAtmosphereProfile.MAX_ENTRY_SPEED_MPS:
		return _result(false, &"invalid_speed")
	if _resolve_shader() == null:
		return _result(false, &"renderer_target_unavailable")

	_mutation_active = true
	var sample := _sampler.sample(altitude, 0.0, speed, 0.0, 0.0)
	if not bool(sample.get("accepted", false)):
		_mutation_active = false
		return _result(
			false, StringName(sample.get("reason", &"sample_rejected"))
		)
	var observation := _build_observation(sample)
	if not _observation_contract_is_valid(observation):
		_mutation_active = false
		return _result(false, &"sampler_contract_mismatch")
	var candidate := float(observation.entry_effect_intensity_unitless)
	var identical := observation == _last_observation \
		and candidate == _current_intensity
	if identical and _target_matches_expected():
		_mutation_active = false
		return _result(true, &"unchanged", {
			"observation": _last_observation.duplicate(true),
		})
	var value_to_apply := candidate if is_inside_tree() else _baseline_intensity
	var apply_result := _apply_intensity(value_to_apply)
	if not bool(apply_result.get("accepted", false)):
		_mutation_active = false
		return _result(
			false,
			StringName(apply_result.get("reason", &"material_apply_failed"))
		)
	_last_observation = observation.duplicate(true)
	_current_intensity = candidate
	_presented_observation_count += 1
	_mutation_active = false
	var reason: StringName = (
		&"material_reapplied" if identical else &"observation_presented"
	)
	_commit(reason)
	return _result(true, reason, {
		"observation": _last_observation.duplicate(true),
	})


func reset_for_reuse(expected_generation: Variant) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if not _is_exact_generation(expected_generation) \
			or int(expected_generation) != _generation:
		return _result(false, &"stale_generation")
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	if _resolve_shader() == null:
		return _result(false, &"renderer_target_unavailable")
	_mutation_active = true
	var apply_result := _apply_intensity(_baseline_intensity)
	if not bool(apply_result.get("accepted", false)):
		_mutation_active = false
		return _result(
			false,
			StringName(apply_result.get("reason", &"material_apply_failed"))
		)
	_generation += 1
	_current_intensity = _baseline_intensity
	_last_observation.clear()
	_reset_count += 1
	_mutation_active = false
	_commit(&"reset")
	return _result(true, &"reset")


func get_generation() -> int:
	return _generation


func get_profile_snapshot() -> Dictionary:
	return _profile_snapshot.duplicate(true)


func get_renderer_snapshot() -> Dictionary:
	var material := _resolve_material()
	var shader := _resolve_shader()
	var actual: Variant = null
	if material != null and shader != null:
		actual = material.get_shader_parameter(OWNED_SHADER_PARAMETER)
	var expected := _current_intensity if is_inside_tree() else _baseline_intensity
	return {
		"target_available": material != null and shader != null,
		"material_instance_id": _material_instance_id,
		"shader_instance_id": _shader_instance_id,
		"owned_parameters": [String(OWNED_SHADER_PARAMETER)],
		"baseline": {OWNED_SHADER_PARAMETER: _baseline_intensity},
		"expected": {OWNED_SHADER_PARAMETER: expected},
		"actual": {OWNED_SHADER_PARAMETER: actual},
		"current_values_applied": is_inside_tree() \
			and actual == _current_intensity,
		"baseline_applied_while_detached": not is_inside_tree() \
			and actual == _baseline_intensity,
	}.duplicate(true)


func get_state_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"equation_version": EQUATION_VERSION,
		"configured": _configured,
		"profile_id": _profile_id,
		"source_profile_schema_version": _source_profile_schema_version,
		"generation": _generation,
		"revision": _revision,
		"inside_tree": is_inside_tree(),
		"has_presented_observation": not _last_observation.is_empty(),
		"last_observation": _last_observation.duplicate(true),
		"profile": _profile_snapshot.duplicate(true),
		"renderer": get_renderer_snapshot(),
		"presented_observation_count": _presented_observation_count,
		"reset_count": _reset_count,
		"last_lifecycle_result": _last_lifecycle_result.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("presentation_not_configured")
	else:
		if _profile_id.is_empty() \
				or _source_profile_schema_version \
				!= PlanetaryAtmosphereProfile.SCHEMA_VERSION:
			errors.append("profile_identity_drift")
		if _profile_snapshot.get("profile_id", &"") != _profile_id \
				or not bool(_profile_snapshot.get("valid", false)):
			errors.append("profile_snapshot_drift")
		if _sampler == null or not bool(_sampler.audit().get("valid", false)) \
				or _sampler.get_snapshot().get("profile_id", &"") != _profile_id:
			errors.append("sampler_contract_drift")
		if _resolve_material() == null:
			errors.append("material_identity_drift")
		elif _resolve_shader_identity() == null:
			errors.append("shader_identity_drift")
		elif not _configured_shader_contract_is_valid(
			_resolve_shader_identity()
		):
			errors.append("shader_schema_drift")
		elif not _target_matches_expected():
			errors.append("owned_material_state_drift")
		if _generation <= 0 or _generation > MAX_SAFE_GENERATION:
			errors.append("generation_out_of_bounds")
		if _revision <= 0:
			errors.append("revision_out_of_bounds")
		if not _last_observation.is_empty() \
				and not _observation_contract_is_valid(_last_observation):
			errors.append("observation_contract_drift")
		if not _evidence_contract_is_valid(EVIDENCE):
			errors.append("evidence_contract_drift")
	if get_child_count() != 0:
		errors.append("passive_adapter_gained_child_nodes")
	if is_processing() or is_physics_processing() \
			or has_method("_process") or has_method("_physics_process"):
		errors.append("passive_adapter_gained_process_authority")
	errors.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"state": get_state_snapshot(),
		"required_shader_parameter_types": {
			OWNED_SHADER_PARAMETER: REQUIRED_SHADER_PARAMETER_TYPE,
		}.duplicate(true),
		"owned_shader_parameters": [String(OWNED_SHADER_PARAMETER)],
		"boundaries": {
			"at_or_above_atmosphere_top": &"exact_zero_vacuum",
			"entry_altitude": &"zero_at_start_full_at_or_below_full",
			"entry_speed": &"zero_at_minimum_full_at_or_above_full",
			"mapping": &"sampler_entry_effect_intensity_exact",
			"baseline": &"exact_zero",
			"quality": &"same_target_and_mapping_high_low",
		},
		"capabilities": {
			"entry_intensity_material_adapter_implemented": true,
			"dedicated_overlay_target_compatible": true,
			"atmosphere_sampler_mapping_implemented": true,
			"transactional_material_apply": true,
			"consolidated_resource_changed_notification": true,
			"tree_exit_restores_baseline": true,
			"tree_reentry_reapplies_current_generation": true,
			"physical_heating_simulation": false,
			"directional_bow_shock": false,
			"production_ship_integration": false,
			"quality_selection": false,
		},
		"performance": {
			"runtime_child_node_count": get_child_count(),
			"owned_renderer_node_count": 0,
			"owned_material_resource_count": 0,
			"owned_shader_resource_count": 0,
			"renderer_resource_allocations_after_configuration": 0,
			"process_loop_count": 0,
		},
		"evidence": EVIDENCE.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _build_observation(sample: Dictionary) -> Dictionary:
	var inputs := sample.get("inputs", {}) as Dictionary
	return {
		"accepted": true,
		"reason": &"observed",
		"profile_id": _profile_id,
		"equation_version": EQUATION_VERSION,
		"inputs": {
			"altitude_m": float(inputs.get("altitude_m", NAN)),
			"speed_mps": float(inputs.get("speed_mps", NAN)),
		},
		"entry_effect_intensity_unitless": float(
			sample.get("entry_effect_intensity", NAN)
		),
		"vacuum": bool(sample.get("vacuum", false)),
		"sample": sample.duplicate(true),
	}.duplicate(true)


func _observation_contract_is_valid(observation: Dictionary) -> bool:
	if observation.size() != 8 \
			or observation.get("accepted") != true \
			or observation.get("reason") != &"observed" \
			or observation.get("profile_id", &"") != _profile_id \
			or observation.get("equation_version", &"") != EQUATION_VERSION \
			or not observation.get("inputs") is Dictionary \
			or not observation.get("sample") is Dictionary \
			or not observation.get("vacuum") is bool \
			or not _is_unit_number(
				observation.get("entry_effect_intensity_unitless")
			):
		return false
	var inputs := observation.get("inputs", {}) as Dictionary
	var sample := observation.get("sample", {}) as Dictionary
	if inputs.size() != 2 \
			or not _is_finite_number(inputs.get("altitude_m")) \
			or not _is_finite_number(inputs.get("speed_mps")):
		return false
	return bool(sample.get("accepted", false)) \
		and sample.get("profile_id", &"") == _profile_id \
		and sample.get("equation_version", &"") \
		== PlanetaryAtmosphereSampler.EQUATION_VERSION \
		and sample.get("vacuum") == observation.get("vacuum") \
		and sample.get("entry_effect_intensity") \
		== observation.get("entry_effect_intensity_unitless")


func _validate_unconfigured_target(material: ShaderMaterial) -> Dictionary:
	if material.shader == null or not is_instance_valid(material.shader):
		return {"accepted": false, "reason": &"missing_shader"}
	if material.shader.get_mode() != Shader.MODE_SPATIAL:
		return {"accepted": false, "reason": &"shader_not_spatial"}
	if not _shader_uniform_contract_is_valid(material.shader):
		return {
			"accepted": false,
			"reason": &"shader_uniform_contract_mismatch",
		}
	if not material.resource_local_to_scene:
		return {
			"accepted": false,
			"reason": &"material_not_exclusive",
		}
	return {"accepted": true, "reason": &"valid_target"}


func _shader_uniform_contract_is_valid(shader: Shader) -> bool:
	var found := 0
	for entry: Dictionary in shader.get_shader_uniform_list():
		if StringName(entry.get("name", "")) == OWNED_SHADER_PARAMETER:
			found += 1
			if int(entry.get("type", TYPE_NIL)) != REQUIRED_SHADER_PARAMETER_TYPE:
				return false
	return found == 1


func _resolve_material() -> ShaderMaterial:
	if _material_ref == null:
		return null
	var candidate: Variant = _material_ref.get_ref()
	if candidate == null or not is_instance_valid(candidate) \
			or not candidate is ShaderMaterial:
		return null
	var material := candidate as ShaderMaterial
	if material.get_instance_id() != _material_instance_id \
			or not material.resource_local_to_scene:
		return null
	return material


func _resolve_shader_identity() -> Shader:
	var material := _resolve_material()
	if material == null or _shader_ref == null:
		return null
	var candidate: Variant = _shader_ref.get_ref()
	if candidate == null or not is_instance_valid(candidate) \
			or not candidate is Shader:
		return null
	var shader := candidate as Shader
	if shader.get_instance_id() != _shader_instance_id \
			or material.shader != shader:
		return null
	return shader


func _resolve_shader() -> Shader:
	var shader := _resolve_shader_identity()
	if not _configured_shader_contract_is_valid(shader):
		return null
	return shader


func _configured_shader_contract_is_valid(shader: Shader) -> bool:
	return shader != null and is_instance_valid(shader) \
		and shader.get_mode() == Shader.MODE_SPATIAL \
		and shader.code == _shader_code_snapshot \
		and _shader_uniform_contract_is_valid(shader)


func _read_intensity(material: ShaderMaterial) -> Variant:
	return material.get_shader_parameter(OWNED_SHADER_PARAMETER)


func _apply_intensity(value: float) -> Dictionary:
	var material := _resolve_material()
	var shader := _resolve_shader()
	if material == null or shader == null:
		return {"accepted": false, "reason": &"renderer_target_unavailable"}
	if not _is_unit_number(value):
		return {"accepted": false, "reason": &"material_mapping_out_of_bounds"}
	var previous: Variant = _read_intensity(material)
	if not _is_unit_number(previous):
		return {"accepted": false, "reason": &"renderer_state_invalid"}
	var wrote_parameter: bool = previous != value
	if wrote_parameter:
		material.set_shader_parameter(OWNED_SHADER_PARAMETER, value)
	if wrote_parameter and is_instance_valid(material) \
			and _resolve_material() == material \
			and _resolve_shader_identity() == shader \
			and _configured_shader_contract_is_valid(shader):
		material.emit_changed()
	if _resolve_material() != material \
			or _resolve_shader_identity() != shader:
		_restore_cached_intensity(material, shader, previous)
		return {
			"accepted": false,
			"reason": &"target_chain_changed_during_apply",
		}
	if not _configured_shader_contract_is_valid(shader):
		_restore_cached_intensity(material, shader, previous)
		return {
			"accepted": false,
			"reason": &"shader_schema_changed_during_apply",
		}
	if _read_intensity(material) != value:
		_restore_cached_intensity(material, shader, previous)
		if _read_intensity(material) != previous:
			return {"accepted": false, "reason": &"rollback_failed"}
		return {
			"accepted": false,
			"reason": &"renderer_state_changed_during_apply",
		}
	return {
		"accepted": true,
		"reason": &"material_value_applied" if wrote_parameter else &"unchanged",
	}


func _restore_cached_intensity(
		material: ShaderMaterial,
		shader: Shader,
		value: Variant
	) -> void:
	if material == null or not is_instance_valid(material) \
			or shader == null or not is_instance_valid(shader) \
			or material.shader != shader \
			or not _configured_shader_contract_is_valid(shader) \
			or not _is_unit_number(value):
		return
	material.set_shader_parameter(OWNED_SHADER_PARAMETER, float(value))


func _target_matches_expected() -> bool:
	var material := _resolve_material()
	if material == null or _resolve_shader() == null:
		return false
	var expected := _current_intensity if is_inside_tree() else _baseline_intensity
	return _read_intensity(material) == expected


func _evidence_contract_is_valid(candidate: Dictionary) -> bool:
	return candidate.size() == 4 \
		and candidate.get("content_class") == &"NEW" \
		and candidate.get("status") == &"modern_interpretation" \
		and candidate.get("source_bounded") is bool \
		and candidate.get("source_bounded") == false \
		and candidate.get("confidence") == &"none"


func _is_reentrant() -> bool:
	return _mutation_active or _signal_dispatch_active or _lifecycle_apply_active


func _commit(reason: StringName) -> void:
	_revision += 1
	var snapshot := get_state_snapshot()
	_signal_dispatch_active = true
	presentation_committed.emit(reason, snapshot.duplicate(true))
	_signal_dispatch_active = false


func _result(
		accepted: bool,
		reason: StringName,
		details: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"revision": _revision,
	}
	for key: Variant in details:
		result[key] = details[key]
	return result.duplicate(true)


static func _is_exact_generation(value: Variant) -> bool:
	return value is int and int(value) >= 0 \
		and int(value) <= MAX_SAFE_GENERATION


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_unit_number(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) >= 0.0 \
		and float(value) <= 1.0
