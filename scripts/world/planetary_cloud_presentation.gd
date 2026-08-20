class_name PlanetaryCloudPresentation
extends Node

## Passive adapter from one validated atmosphere profile to one caller-owned
## cloud ShaderMaterial contract.
##
## The caller owns geometry, shader code, material lifetime, observation cadence,
## weather/cloud choices, and the time origin. This component freezes detached
## atmosphere values, samples them deterministically, and owns only six named
## shader parameters. It creates no renderer Resource, geometry, clock, process
## loop, weather state, physics, streaming, or gameplay decision.

signal presentation_committed(reason: StringName, snapshot: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"planetary-cloud-presentation"
const EQUATION_VERSION: StringName = &"cloud_material_parameters_v1"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MAX_CLOUD_WIND_OFFSET_M := 1_048_576.0
const OWNED_SHADER_PARAMETERS := [
	"cloud_base_radius_m",
	"cloud_top_radius_m",
	"cloud_coverage_unitless",
	"cloud_observer_layer_factor_unitless",
	"cloud_wind_velocity_mps",
	"cloud_wind_offset_m",
]
const REQUIRED_SHADER_PARAMETER_TYPES := {
	"cloud_base_radius_m": TYPE_FLOAT,
	"cloud_top_radius_m": TYPE_FLOAT,
	"cloud_coverage_unitless": TYPE_FLOAT,
	"cloud_observer_layer_factor_unitless": TYPE_FLOAT,
	"cloud_wind_velocity_mps": TYPE_VECTOR3,
	"cloud_wind_offset_m": TYPE_VECTOR3,
}
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
	"cloud_geometry": false,
	"cloud_volume": false,
	"textures": false,
	"noise": false,
	"cloud_density": false,
	"cloud_lighting": false,
	"weather_selection": false,
	"weather_clock": false,
	"time_accumulation": false,
	"time_wrapping": false,
	"wind_simulation": false,
	"camera": false,
	"visual_quality": false,
	"origin_application": false,
	"movement": false,
	"landing": false,
	"gameplay": false,
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
var _baseline_parameter_values: Dictionary = {}
var _current_parameter_values: Dictionary = {}
var _last_observation: Dictionary = {}
var _generation := 0
var _revision := 0
var _presented_observation_count := 0
var _reset_count := 0
var _mutation_active := false
var _signal_dispatch_active := false
var _lifecycle_apply_active := false


func _enter_tree() -> void:
	if _configured:
		_lifecycle_apply_active = true
		_apply_parameter_values(_current_parameter_values)
		_lifecycle_apply_active = false


func _exit_tree() -> void:
	if _configured:
		_lifecycle_apply_active = true
		_apply_parameter_values(_baseline_parameter_values)
		_lifecycle_apply_active = false


## Configures once against a caller-owned spatial ShaderMaterial. Neither target
## nor source profile is held strongly after this call.
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
	var shader := material.shader
	var baseline := _read_parameter_values(material)
	if not _parameter_values_are_bounded(baseline, profile_audit):
		return _result(false, &"invalid_material_baseline")

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
	_baseline_parameter_values = baseline.duplicate(true)
	_current_parameter_values = baseline.duplicate(true)
	_generation += 1
	_configured = true
	_mutation_active = false
	_commit(&"configured")
	return _result(true, &"configured")


## Samples one caller-selected point and derives an absolute wind offset from
## caller-owned time. This method never advances, wraps, or infers time.
func present_observation(
		altitude_m: Variant,
		caller_time_seconds: Variant,
		weather_scalar: Variant,
		cloud_scalar: Variant,
		expected_generation: Variant
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if not _is_exact_integer(expected_generation) \
			or int(expected_generation) != _generation:
		return _result(false, &"stale_generation")
	# This public adapter has no owner-gated caller. A detached or queued sample
	# must not become retained material intent that appears on a later re-entry.
	if is_queued_for_deletion() or not is_inside_tree():
		return _result(false, &"presentation_detached")
	if not _is_finite_number(altitude_m):
		return _result(false, &"invalid_altitude")
	var geometry := _profile_snapshot.get("geometry", {}) as Dictionary
	var planet_radius := float(geometry.get("planet_radius_m", NAN))
	var altitude := float(altitude_m)
	if altitude < -planet_radius \
			or altitude > PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M:
		return _result(false, &"invalid_altitude")
	if not _is_unit_number(weather_scalar):
		return _result(false, &"invalid_weather_intensity")
	if not _is_unit_number(cloud_scalar):
		return _result(false, &"invalid_cloud_coverage")
	if not _is_finite_number(caller_time_seconds) \
			or float(caller_time_seconds) < 0.0:
		return _result(false, &"invalid_caller_time")
	if _resolve_shader() == null:
		return _result(false, &"renderer_target_unavailable")

	_mutation_active = true
	var sample := _sampler.sample(
		altitude,
		0.0,
		0.0,
		float(weather_scalar),
		float(cloud_scalar)
	)
	if not bool(sample.get("accepted", false)):
		_mutation_active = false
		return _result(
			false, StringName(sample.get("reason", &"sample_rejected"))
		)
	var observation := _build_observation(
		sample, float(caller_time_seconds)
	)
	if not bool(observation.get("accepted", false)):
		_mutation_active = false
		return _result(
			false, StringName(observation.get("reason", &"observation_rejected"))
		)
	if not _observation_contract_is_valid(observation):
		_mutation_active = false
		return _result(false, &"sampler_contract_mismatch")
	var parameter_values := _parameter_values_for_observation(observation)
	if not _parameter_values_are_bounded(
		parameter_values, _profile_snapshot
	):
		_mutation_active = false
		return _result(false, &"material_mapping_out_of_bounds")
	var identical := observation == _last_observation \
		and parameter_values == _current_parameter_values
	var target_matches := _target_matches_expected()
	if identical and target_matches:
		_mutation_active = false
		return _result(true, &"unchanged", {
			"observation": _last_observation.duplicate(true),
		})

	var values_to_apply := (
		parameter_values if is_inside_tree() else _baseline_parameter_values
	)
	var apply_result := _apply_parameter_values(values_to_apply)
	if not bool(apply_result.get("accepted", false)):
		_mutation_active = false
		return _result(
			false,
			StringName(apply_result.get("reason", &"material_apply_failed"))
		)
	_last_observation = observation.duplicate(true)
	_current_parameter_values = parameter_values.duplicate(true)
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
	if not _is_exact_integer(expected_generation) \
			or int(expected_generation) != _generation:
		return _result(false, &"stale_generation")
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	if _resolve_shader() == null:
		return _result(false, &"renderer_target_unavailable")
	_mutation_active = true
	var apply_result := _apply_parameter_values(_baseline_parameter_values)
	if not bool(apply_result.get("accepted", false)):
		_mutation_active = false
		return _result(
			false,
			StringName(apply_result.get("reason", &"material_apply_failed"))
		)
	_generation += 1
	_last_observation.clear()
	_current_parameter_values = _baseline_parameter_values.duplicate(true)
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
	var actual := (
		_read_parameter_values(material)
		if material != null and shader != null else {}
	)
	return {
		"target_available": material != null and shader != null,
		"material_instance_id": _material_instance_id,
		"shader_instance_id": _shader_instance_id,
		"owned_parameters": OWNED_SHADER_PARAMETERS.duplicate(),
		"baseline": _baseline_parameter_values.duplicate(true),
		"expected": _current_parameter_values.duplicate(true),
		"actual": actual,
		"current_values_applied": (
			is_inside_tree() and not actual.is_empty()
			and actual == _current_parameter_values
		),
		"baseline_applied_while_detached": (
			not is_inside_tree() and not actual.is_empty()
			and actual == _baseline_parameter_values
		),
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
		"required_shader_parameter_types": (
			REQUIRED_SHADER_PARAMETER_TYPES.duplicate(true)
		),
		"owned_shader_parameters": OWNED_SHADER_PARAMETERS.duplicate(),
		"boundaries": {
			"cloud_layer": &"base_inclusive_top_exclusive",
			"observer_at_or_above_atmosphere_top": &"zero_observer_factor_global_layer_persists",
			"global_coverage": &"frozen_profile_coverage_times_caller_cloud_scalar",
			"global_wind": &"frozen_profile_wind_times_caller_weather_scalar",
			"weather_scalar": &"closed_unit_interval",
			"cloud_scalar": &"closed_unit_interval",
			"caller_time_seconds": &"nonnegative_finite_no_implicit_clock",
			"wind_offset": &"frozen_profile_wind_times_weather_scalar_times_caller_time",
			"maximum_wind_offset_m": MAX_CLOUD_WIND_OFFSET_M,
		},
		"capabilities": {
			"cloud_material_uniform_adapter_implemented": true,
			"visible_cloud_renderer_implemented": false,
			"production_cloud_shader_implemented": false,
			"cloud_geometry_implemented": false,
			"weather_selection_implemented": false,
			"weather_simulation_implemented": false,
			"clock_implemented": false,
			"caller_time_only": true,
			"transactional_material_apply": true,
			"consolidated_resource_changed_notification": true,
			"tree_exit_restores_baseline": true,
			"tree_reentry_reapplies_current_generation": true,
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


func _build_observation(sample: Dictionary, caller_time_seconds: float) -> Dictionary:
	var geometry := _profile_snapshot.get("geometry", {}) as Dictionary
	var weather := _profile_snapshot.get("weather", {}) as Dictionary
	var inputs := sample.get("inputs", {}) as Dictionary
	var weather_scalar := float(inputs.get("weather_scalar", NAN))
	var cloud_scalar := float(inputs.get("cloud_scalar", NAN))
	var wind_velocity := (
		(weather.get("wind_velocity_mps", Vector3.INF) as Vector3)
		* weather_scalar
	)
	var wind_offset := (
		Vector3.ZERO
		if wind_velocity == Vector3.ZERO
		else wind_velocity * caller_time_seconds
	)
	if not wind_offset.is_finite() \
			or wind_offset.length() > MAX_CLOUD_WIND_OFFSET_M:
		return {"accepted": false, "reason": &"wind_offset_out_of_bounds"}
	var altitude := float(inputs.get("altitude_m", NAN))
	var planet_radius := float(geometry.get("planet_radius_m", NAN))
	var cloud_base := float(weather.get("cloud_base_altitude_m", NAN))
	var cloud_top := float(weather.get("cloud_top_altitude_m", NAN))
	var coverage := clampf(
		float(weather.get("cloud_coverage_unitless", NAN)) * cloud_scalar,
		0.0,
		1.0
	)
	return {
		"accepted": true,
		"reason": &"observed",
		"profile_id": _profile_id,
		"equation_version": EQUATION_VERSION,
		"inputs": {
			"altitude_m": altitude,
			"weather_scalar": weather_scalar,
			"cloud_scalar": cloud_scalar,
			"caller_time_seconds": caller_time_seconds,
		},
		"cloud_base_radius_m": planet_radius + cloud_base,
		"cloud_top_radius_m": planet_radius + cloud_top,
		"cloud_coverage_unitless": float(
			coverage
		),
		"cloud_observer_layer_factor_unitless": float(
			sample.get("cloud_layer_factor", NAN)
		),
		"cloud_wind_velocity_mps": wind_velocity,
		"cloud_wind_offset_m": wind_offset,
		"sample": sample.duplicate(true),
	}.duplicate(true)


func _parameter_values_for_observation(observation: Dictionary) -> Dictionary:
	return {
		"cloud_base_radius_m": float(observation.cloud_base_radius_m),
		"cloud_top_radius_m": float(observation.cloud_top_radius_m),
		"cloud_coverage_unitless": float(
			observation.cloud_coverage_unitless
		),
		"cloud_observer_layer_factor_unitless": float(
			observation.cloud_observer_layer_factor_unitless
		),
		"cloud_wind_velocity_mps": (
			observation.cloud_wind_velocity_mps as Vector3
		),
		"cloud_wind_offset_m": observation.cloud_wind_offset_m as Vector3,
	}.duplicate(true)


func _observation_contract_is_valid(observation: Dictionary) -> bool:
	if observation.get("profile_id", &"") != _profile_id \
			or observation.get("equation_version", &"") != EQUATION_VERSION:
		return false
	if not observation.get("inputs") is Dictionary \
			or not observation.get("sample") is Dictionary:
		return false
	var inputs := observation.get("inputs", {}) as Dictionary
	var sample := observation.get("sample", {}) as Dictionary
	var wind_velocity: Variant = observation.get("cloud_wind_velocity_mps")
	var wind_offset: Variant = observation.get("cloud_wind_offset_m")
	return bool(sample.get("accepted", false)) \
		and sample.get("profile_id", &"") == _profile_id \
		and sample.get("equation_version", &"") \
		== PlanetaryAtmosphereSampler.EQUATION_VERSION \
		and _is_unit_number(observation.get("cloud_coverage_unitless")) \
		and _is_unit_number(
			observation.get("cloud_observer_layer_factor_unitless")
		) \
		and _is_finite_number(inputs.get("caller_time_seconds")) \
		and float(inputs.get("caller_time_seconds")) >= 0.0 \
		and _is_unit_number(inputs.get("weather_scalar")) \
		and _is_unit_number(inputs.get("cloud_scalar")) \
		and _is_finite_number(observation.get("cloud_base_radius_m")) \
		and _is_finite_number(observation.get("cloud_top_radius_m")) \
		and float(observation.get("cloud_base_radius_m")) \
		< float(observation.get("cloud_top_radius_m")) \
		and wind_velocity is Vector3 \
		and (wind_velocity as Vector3).is_finite() \
		and (wind_velocity as Vector3).length() \
		<= PlanetaryAtmosphereProfile.MAX_WIND_SPEED_MPS \
		and wind_offset is Vector3 and (wind_offset as Vector3).is_finite() \
		and (wind_offset as Vector3).length() \
		<= MAX_CLOUD_WIND_OFFSET_M


func _validate_unconfigured_target(material: ShaderMaterial) -> Dictionary:
	if material.shader == null or not is_instance_valid(material.shader):
		return {"accepted": false, "reason": &"missing_shader"}
	if material.shader.get_mode() != Shader.MODE_SPATIAL:
		return {"accepted": false, "reason": &"shader_not_spatial"}
	if not _shader_uniform_contract_is_valid(material.shader):
		return {"accepted": false, "reason": &"shader_uniform_contract_mismatch"}
	return {"accepted": true, "reason": &"valid_target"}


func _shader_uniform_contract_is_valid(shader: Shader) -> bool:
	var found := {}
	for entry: Dictionary in shader.get_shader_uniform_list():
		var name := String(entry.get("name", ""))
		if REQUIRED_SHADER_PARAMETER_TYPES.has(name):
			found[name] = int(entry.get("type", TYPE_NIL))
	if found.size() != REQUIRED_SHADER_PARAMETER_TYPES.size():
		return false
	for name: String in REQUIRED_SHADER_PARAMETER_TYPES:
		if int(found.get(name, TYPE_NIL)) != int(
			REQUIRED_SHADER_PARAMETER_TYPES[name]
		):
			return false
	return true


func _resolve_material() -> ShaderMaterial:
	if _material_ref == null:
		return null
	var candidate: Variant = _material_ref.get_ref()
	if candidate == null or not is_instance_valid(candidate) \
			or not candidate is ShaderMaterial:
		return null
	var material := candidate as ShaderMaterial
	if material.get_instance_id() != _material_instance_id:
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


func _read_parameter_values(material: ShaderMaterial) -> Dictionary:
	var values := {}
	for parameter_name: String in OWNED_SHADER_PARAMETERS:
		values[parameter_name] = material.get_shader_parameter(parameter_name)
	return values.duplicate(true)


func _apply_parameter_values(values: Dictionary) -> Dictionary:
	var material := _resolve_material()
	var shader := _resolve_shader()
	if material == null or shader == null:
		return {"accepted": false, "reason": &"renderer_target_unavailable"}
	if not _parameter_values_are_bounded(values, _profile_snapshot):
		return {"accepted": false, "reason": &"material_mapping_out_of_bounds"}
	var previous := _read_parameter_values(material)
	var wrote_parameter := false
	for parameter_name: String in OWNED_SHADER_PARAMETERS:
		var expected: Variant = values[parameter_name]
		if material.get_shader_parameter(parameter_name) != expected:
			material.set_shader_parameter(parameter_name, expected)
			wrote_parameter = true
			if _resolve_material() != material \
					or _resolve_shader_identity() != shader:
				break
			if not _configured_shader_contract_is_valid(shader):
				break
	if wrote_parameter and is_instance_valid(material) \
			and _resolve_material() == material \
			and _resolve_shader_identity() == shader \
			and _configured_shader_contract_is_valid(shader):
		material.emit_changed()
	if _resolve_material() != material \
			or _resolve_shader_identity() != shader:
		_restore_cached_material(material, shader, previous)
		return {
			"accepted": false,
			"reason": &"target_chain_changed_during_apply",
		}
	if not _configured_shader_contract_is_valid(shader):
		_restore_cached_material(material, shader, previous)
		return {
			"accepted": false,
			"reason": &"shader_schema_changed_during_apply",
		}
	if _read_parameter_values(material) != values:
		_restore_cached_material(material, shader, previous)
		return {
			"accepted": false,
			"reason": &"renderer_state_changed_during_apply",
		}
	return {
		"accepted": true,
		"reason": &"material_values_applied" if wrote_parameter else &"unchanged",
	}


func _restore_cached_material(
		material: ShaderMaterial,
		shader: Shader,
		values: Dictionary
	) -> void:
	if material == null or not is_instance_valid(material) \
			or shader == null or not is_instance_valid(shader) \
			or material.shader != shader \
			or not _configured_shader_contract_is_valid(shader) \
			or not _parameter_values_are_bounded(values, _profile_snapshot):
		return
	for parameter_name: String in OWNED_SHADER_PARAMETERS:
		material.set_shader_parameter(parameter_name, values[parameter_name])


func _target_matches_expected() -> bool:
	var material := _resolve_material()
	if material == null or _resolve_shader() == null:
		return false
	var expected := (
		_current_parameter_values if is_inside_tree()
		else _baseline_parameter_values
	)
	return _read_parameter_values(material) == expected


func _parameter_values_are_bounded(
		values: Dictionary,
		profile_snapshot: Dictionary
	) -> bool:
	if values.size() != OWNED_SHADER_PARAMETERS.size():
		return false
	if not _is_unit_number(values.get("cloud_coverage_unitless")) \
			or not _is_unit_number(
				values.get("cloud_observer_layer_factor_unitless")
			):
		return false
	var geometry := profile_snapshot.get("geometry", {}) as Dictionary
	var planet_radius := float(geometry.get("planet_radius_m", NAN))
	var maximum_radius := (
		planet_radius + PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M
	)
	if not _is_finite_range(
		values.get("cloud_base_radius_m"), 0.0, maximum_radius
	) or not _is_finite_range(
		values.get("cloud_top_radius_m"), 0.0, maximum_radius
	) or float(values.get("cloud_base_radius_m")) \
		>= float(values.get("cloud_top_radius_m")):
		return false
	var wind_velocity: Variant = values.get("cloud_wind_velocity_mps")
	var wind_offset: Variant = values.get("cloud_wind_offset_m")
	return wind_velocity is Vector3 \
		and (wind_velocity as Vector3).is_finite() \
		and (wind_velocity as Vector3).length() \
		<= PlanetaryAtmosphereProfile.MAX_WIND_SPEED_MPS \
		and wind_offset is Vector3 and (wind_offset as Vector3).is_finite() \
		and (wind_offset as Vector3).length() \
		<= MAX_CLOUD_WIND_OFFSET_M


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


static func _is_exact_integer(value: Variant) -> bool:
	return value is int and int(value) >= 0 and int(value) <= MAX_SAFE_GENERATION


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_unit_number(value: Variant) -> bool:
	return _is_finite_range(value, 0.0, 1.0)


static func _is_finite_range(
		value: Variant,
		minimum: float,
		maximum: float
	) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
		and float(value) >= minimum and float(value) <= maximum
