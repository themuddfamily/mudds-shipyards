class_name PlanetaryAtmospherePresentation
extends Node

## Generation-safe passive renderer adapter for a validated atmosphere profile.
##
## A composition owner supplies one Environment. This adapter freezes its four
## owned fog properties, samples a detached copy of a validated profile through
## PlanetaryAtmosphereSampler, and changes presentation only when the caller
## submits an observation. It owns no clock, process loop, Environment resource,
## WorldEnvironment node, sky shader, cloud geometry, or gameplay decision.

signal presentation_committed(reason: StringName, snapshot: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"planetary-atmosphere-presentation"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MIN_FOG_PATH_M := 0.1
const MIN_TRANSMITTANCE := 0.0000000000000000000000000001
const MAX_FOG_LIGHT_ENERGY := 64.0
const OWNED_RENDERER_PROPERTIES := [
	"fog_density",
	"fog_light_color",
	"fog_light_energy",
	"fog_sky_affect",
]
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
	"ship_movement": false,
	"player_movement": false,
	"landing": false,
	"navigation": false,
	"camera": false,
	"weather_selection": false,
	"cloud_advection": false,
	"entry_gameplay": false,
	"damage": false,
	"reward": false,
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
var _environment_ref: WeakRef
var _environment_instance_id := 0
var _baseline_renderer_values: Dictionary = {}
var _current_renderer_values: Dictionary = {}
var _last_sample: Dictionary = {}
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
		_apply_renderer_values(_current_renderer_values)
		_lifecycle_apply_active = false


func _exit_tree() -> void:
	if _configured:
		_lifecycle_apply_active = true
		_apply_renderer_values(_baseline_renderer_values)
		_lifecycle_apply_active = false


## Configures this component once. The source Resource is read and released;
## only detached values and a sampler containing its own detached values remain.
func configure(
		profile: PlanetaryAtmosphereProfile,
		environment: Environment
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if _configured:
		return _result(false, &"already_configured")
	if profile == null:
		return _result(false, &"missing_profile")
	if environment == null or not is_instance_valid(environment):
		return _result(false, &"missing_environment")
	var profile_audit := profile.get_audit_report()
	if not profile.is_definition_valid() \
			or not bool(profile_audit.get("valid", false)):
		return _result(false, &"invalid_profile", {
			"profile_errors": (
				profile_audit.get("errors", PackedStringArray()) as PackedStringArray
			).duplicate(),
		})
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	var sampler := PlanetaryAtmosphereSampler.new()
	var sampler_result := sampler.configure(profile)
	if not bool(sampler_result.get("accepted", false)) \
			or not bool(sampler.audit().get("valid", false)):
		return _result(false, &"sampler_configuration_failed")
	var baseline := _read_renderer_values(environment)
	if not _renderer_values_are_bounded(baseline):
		return _result(false, &"invalid_renderer_baseline")

	_mutation_active = true
	_profile_id = StringName(profile_audit.get("profile_id", &""))
	_source_profile_schema_version = int(profile_audit.get("schema_version", 0))
	_profile_snapshot = profile_audit.duplicate(true)
	_sampler = sampler
	_environment_ref = weakref(environment)
	_environment_instance_id = environment.get_instance_id()
	_baseline_renderer_values = baseline.duplicate(true)
	_current_renderer_values = _baseline_renderer_values.duplicate(true)
	_generation += 1
	_configured = true
	_mutation_active = false
	_commit(&"configured")
	return _result(true, &"configured")


## Samples and presents one caller observation. There is no implicit time,
## smoothing or interpolation; identical observations are signal-free.
func present_observation(
		altitude_m: float,
		path_distance_m: float,
		speed_mps: float,
		weather_scalar: float,
		cloud_scalar: float,
		expected_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	# This public adapter has no owner-gated caller. Detached or terminal samples
	# must not become retained renderer intent that applies on a later re-entry.
	if is_queued_for_deletion() or not is_inside_tree():
		return _result(false, &"presentation_detached")
	var environment := _resolve_environment()
	if environment == null:
		return _result(false, &"environment_unavailable")

	_mutation_active = true
	var sample := _sampler.sample(
		altitude_m,
		path_distance_m,
		speed_mps,
		weather_scalar,
		cloud_scalar
	)
	if not bool(sample.get("accepted", false)):
		_mutation_active = false
		return _result(false, StringName(sample.get("reason", &"sample_rejected")))
	if not _sample_identity_is_valid(sample):
		_mutation_active = false
		return _result(false, &"sampler_contract_mismatch")
	var renderer_values := _renderer_values_for_sample(sample)
	if not _renderer_values_are_bounded(renderer_values):
		_mutation_active = false
		return _result(false, &"renderer_mapping_out_of_bounds")
	var identical_sample := sample == _last_sample \
		and renderer_values == _current_renderer_values
	var target_matches := _target_matches_expected(environment)
	if identical_sample and target_matches:
		_mutation_active = false
		return _result(true, &"unchanged")

	var values_to_apply := (
		renderer_values if is_inside_tree() else _baseline_renderer_values
	)
	var apply_result := _apply_renderer_values(values_to_apply)
	if not bool(apply_result.get("accepted", false)):
		_mutation_active = false
		return _result(
			false,
			StringName(apply_result.get("reason", &"renderer_apply_failed"))
		)
	_last_sample = sample.duplicate(true)
	_current_renderer_values = renderer_values.duplicate(true)
	_presented_observation_count += 1
	_mutation_active = false
	var reason: StringName = (
		&"renderer_reapplied" if identical_sample else &"observation_presented"
	)
	_commit(reason)
	return _result(true, reason, {"sample": _last_sample.duplicate(true)})


## Tombstones stale callers, clears the sample, and restores the captured
## renderer baseline without replacing the profile, sampler or target identity.
func reset_for_reuse(expected_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	if _resolve_environment() == null:
		return _result(false, &"environment_unavailable")
	_mutation_active = true
	var apply_result := _apply_renderer_values(_baseline_renderer_values)
	if not bool(apply_result.get("accepted", false)):
		_mutation_active = false
		return _result(
			false,
			StringName(apply_result.get("reason", &"renderer_apply_failed"))
		)
	_generation += 1
	_last_sample.clear()
	_current_renderer_values = _baseline_renderer_values.duplicate(true)
	_reset_count += 1
	_mutation_active = false
	_commit(&"reset")
	return _result(true, &"reset")


func get_generation() -> int:
	return _generation


func get_profile_snapshot() -> Dictionary:
	return _profile_snapshot.duplicate(true)


func get_renderer_snapshot() -> Dictionary:
	var environment := _resolve_environment()
	return {
		"environment_available": environment != null,
		"environment_instance_id": _environment_instance_id,
		"owned_properties": OWNED_RENDERER_PROPERTIES.duplicate(),
		"baseline": _baseline_renderer_values.duplicate(true),
		"expected": _current_renderer_values.duplicate(true),
		"actual": (
			_read_renderer_values(environment) if environment != null else {}
		),
		"current_values_applied": (
			is_inside_tree() and environment != null
			and _renderer_values_match(
				_read_renderer_values(environment), _current_renderer_values
			)
		),
		"baseline_applied_while_detached": (
			not is_inside_tree() and environment != null
			and _renderer_values_match(
				_read_renderer_values(environment), _baseline_renderer_values
			)
		),
	}.duplicate(true)


func get_state_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"configured": _configured,
		"profile_id": _profile_id,
		"source_profile_schema_version": _source_profile_schema_version,
		"equation_version": PlanetaryAtmosphereSampler.EQUATION_VERSION,
		"generation": _generation,
		"revision": _revision,
		"inside_tree": is_inside_tree(),
		"has_presented_sample": not _last_sample.is_empty(),
		"last_sample": _last_sample.duplicate(true),
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
	var environment := _resolve_environment()
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
				or (_sampler.get_snapshot().get("profile_id", &"") != _profile_id):
			errors.append("sampler_contract_drift")
		if environment == null:
			errors.append("environment_unavailable")
		elif environment.get_instance_id() != _environment_instance_id:
			errors.append("environment_identity_drift")
		elif not _target_matches_expected(environment):
			errors.append("owned_renderer_state_drift")
		if _generation <= 0 or _generation > MAX_SAFE_GENERATION:
			errors.append("generation_out_of_bounds")
		if _revision <= 0:
			errors.append("revision_out_of_bounds")
		if not _last_sample.is_empty() \
				and not _sample_identity_is_valid(_last_sample):
			errors.append("sample_contract_drift")
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
		"owned_renderer_properties": OWNED_RENDERER_PROPERTIES.duplicate(),
		"renderer_mapping": {
			"fog_density": &"negative_log_opacity_over_caller_path",
			"fog_light_color": &"normalized_frozen_rayleigh_plus_mie",
			"fog_light_energy": &"density_ratio_linear_0_35_to_1_0",
			"fog_sky_affect": &"half_sample_fog_factor",
			"exact_vacuum_density": 0.0,
			"minimum_density_path_m": MIN_FOG_PATH_M,
		},
		"boundaries": (
			_sampler.audit().get("boundary_policy", {}).duplicate(true)
			if _sampler != null else {}
		),
		"capabilities": {
			"fog_renderer_implemented": true,
			"transactional_renderer_apply": true,
			"consolidated_resource_changed_notification": true,
			"sky_renderer_implemented": false,
			"cloud_renderer_implemented": false,
			"entry_renderer_implemented": false,
			"wind_renderer_implemented": false,
			"shell_renderer_implemented": false,
			"caller_driven_observations_only": true,
			"tree_exit_restores_baseline": true,
			"tree_reentry_reapplies_current_generation": true,
		},
		"performance": {
			"runtime_child_node_count": get_child_count(),
			"owned_environment_resource_count": 0,
			"owned_sky_resource_count": 0,
			"renderer_resource_allocations_after_configuration": 0,
			"process_loop_count": 0,
		},
		"evidence": EVIDENCE.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _renderer_values_for_sample(sample: Dictionary) -> Dictionary:
	var fog_factor := float(sample.get("fog_factor", 0.0))
	var path_distance := float(
		(sample.get("inputs", {}) as Dictionary).get("path_distance_m", 0.0)
	)
	var vacuum := bool(sample.get("vacuum", true))
	var fog_density := 0.0
	if not vacuum and fog_factor > 0.0:
		fog_density = clampf(
			-log(maxf(1.0 - fog_factor, MIN_TRANSMITTANCE))
			/ maxf(path_distance, MIN_FOG_PATH_M),
			0.0,
			1.0
		)
	return {
		"fog_density": _renderer_real(fog_density),
		"fog_light_color": _frozen_scattering_color(),
		"fog_light_energy": _renderer_real(clampf(
			0.35 + float(sample.get("density_ratio", 0.0)) * 0.65,
			0.0,
			1.0
		)),
		"fog_sky_affect": _renderer_real(clampf(
			fog_factor * 0.5, 0.0, 1.0
		)),
	}.duplicate(true)


func _frozen_scattering_color() -> Color:
	var optics := _profile_snapshot.get("optics", {}) as Dictionary
	var rayleigh := optics.get(
		"rayleigh_scattering_per_m", Color(0.0, 0.0, 0.0, 1.0)
	) as Color
	var mie := optics.get(
		"mie_scattering_per_m", Color(0.0, 0.0, 0.0, 1.0)
	) as Color
	var combined := Vector3(
		rayleigh.r + mie.r,
		rayleigh.g + mie.g,
		rayleigh.b + mie.b
	)
	var strongest := maxf(combined.x, maxf(combined.y, combined.z))
	if strongest <= 0.0:
		return Color(0.5, 0.5, 0.5, 1.0)
	var normalized := combined / strongest
	return Color(
		clampf(0.18 + normalized.x * 0.62, 0.0, 1.0),
		clampf(0.18 + normalized.y * 0.62, 0.0, 1.0),
		clampf(0.18 + normalized.z * 0.62, 0.0, 1.0),
		1.0
	)


func _sample_identity_is_valid(sample: Dictionary) -> bool:
	return bool(sample.get("accepted", false)) \
		and sample.get("reason", &"") == &"sampled" \
		and bool(sample.get("configured", false)) \
		and int(sample.get("sample_schema_version", 0)) \
		== PlanetaryAtmosphereSampler.SCHEMA_VERSION \
		and sample.get("profile_id", &"") == _profile_id \
		and sample.get("equation_version", &"") \
		== PlanetaryAtmosphereSampler.EQUATION_VERSION \
		and _is_unit_float(sample.get("density_ratio")) \
		and _is_unit_float(sample.get("fog_factor")) \
		and _is_unit_float(sample.get("cloud_layer_factor")) \
		and _is_unit_float(sample.get("entry_effect_intensity")) \
		and sample.get("wind_velocity_mps") is Vector3 \
		and (sample.get("wind_velocity_mps") as Vector3).is_finite() \
		and sample.get("inputs") is Dictionary


func _target_matches_expected(environment: Environment) -> bool:
	var expected := (
		_current_renderer_values if is_inside_tree()
		else _baseline_renderer_values
	)
	return _renderer_values_match(_read_renderer_values(environment), expected)


func _renderer_values_match(actual: Dictionary, expected: Dictionary) -> bool:
	return _renderer_values_are_bounded(actual) \
		and _renderer_values_are_bounded(expected) \
		and actual == expected


func _resolve_environment() -> Environment:
	if _environment_ref == null:
		return null
	var candidate: Variant = _environment_ref.get_ref()
	if candidate == null or not is_instance_valid(candidate) \
			or not candidate is Environment:
		return null
	var environment := candidate as Environment
	if environment.get_instance_id() != _environment_instance_id:
		return null
	return environment


func _read_renderer_values(environment: Environment) -> Dictionary:
	return {
		"fog_density": environment.fog_density,
		"fog_light_color": environment.fog_light_color,
		"fog_light_energy": environment.fog_light_energy,
		"fog_sky_affect": environment.fog_sky_affect,
	}.duplicate(true)


func _apply_renderer_values(values: Dictionary) -> Dictionary:
	var environment := _resolve_environment()
	if environment == null:
		return {"accepted": false, "reason": &"renderer_target_unavailable"}
	if not _renderer_values_are_bounded(values):
		return {"accepted": false, "reason": &"renderer_mapping_out_of_bounds"}
	var previous := _read_renderer_values(environment)
	var wrote_property := false
	var fog_density := float(values.get("fog_density", 0.0))
	var fog_light_color := values.get("fog_light_color", Color.BLACK) as Color
	var fog_light_energy := float(values.get("fog_light_energy", 0.0))
	var fog_sky_affect := float(values.get("fog_sky_affect", 0.0))
	if environment.fog_density != fog_density:
		environment.fog_density = fog_density
		wrote_property = true
		if _resolve_environment() != environment:
			if is_instance_valid(environment):
				_restore_cached_environment(environment, previous)
			return {
				"accepted": false,
				"reason": &"target_changed_during_apply",
			}
	if environment.fog_light_color != fog_light_color:
		environment.fog_light_color = fog_light_color
		wrote_property = true
		if _resolve_environment() != environment:
			if is_instance_valid(environment):
				_restore_cached_environment(environment, previous)
			return {
				"accepted": false,
				"reason": &"target_changed_during_apply",
			}
	if environment.fog_light_energy != fog_light_energy:
		environment.fog_light_energy = fog_light_energy
		wrote_property = true
		if _resolve_environment() != environment:
			if is_instance_valid(environment):
				_restore_cached_environment(environment, previous)
			return {
				"accepted": false,
				"reason": &"target_changed_during_apply",
			}
	if environment.fog_sky_affect != fog_sky_affect:
		environment.fog_sky_affect = fog_sky_affect
		wrote_property = true
		if _resolve_environment() != environment:
			if is_instance_valid(environment):
				_restore_cached_environment(environment, previous)
			return {
				"accepted": false,
				"reason": &"target_changed_during_apply",
			}
	# Property setters may emit their own notifications. This explicit event is
	# the one consolidated callback spanning the complete four-property attempt.
	if wrote_property and is_instance_valid(environment):
		environment.emit_changed()
	if _resolve_environment() != environment:
		if is_instance_valid(environment):
			_restore_cached_environment(environment, previous)
		return {
			"accepted": false,
			"reason": &"target_changed_during_apply",
		}
	if _read_renderer_values(environment) != values:
		if not _restore_cached_environment(environment, previous):
			return {"accepted": false, "reason": &"rollback_failed"}
		return {
			"accepted": false,
			"reason": &"renderer_state_changed_during_apply",
		}
	return {
		"accepted": true,
		"reason": &"renderer_values_applied" if wrote_property else &"unchanged",
	}


func _restore_cached_environment(
		environment: Environment,
		values: Dictionary
	) -> bool:
	if environment == null or not is_instance_valid(environment) \
			or not _renderer_values_are_bounded(values):
		return false
	environment.fog_density = float(values.get("fog_density", 0.0))
	environment.fog_light_color = values.get("fog_light_color", Color.BLACK) as Color
	environment.fog_light_energy = float(values.get("fog_light_energy", 0.0))
	environment.fog_sky_affect = float(values.get("fog_sky_affect", 0.0))
	if not is_instance_valid(environment):
		return false
	return _read_renderer_values(environment) == values


func _renderer_values_are_bounded(values: Dictionary) -> bool:
	if values.size() != OWNED_RENDERER_PROPERTIES.size() \
			or values.get("fog_density") is not float \
			or values.get("fog_light_color") is not Color \
			or values.get("fog_light_energy") is not float \
			or values.get("fog_sky_affect") is not float:
		return false
	var color := values.get("fog_light_color") as Color
	return _is_finite_range(values.get("fog_density"), 0.0, 1.0) \
		and _color_is_bounded(color) \
		and _is_finite_range(
			values.get("fog_light_energy"), 0.0, MAX_FOG_LIGHT_ENERGY
		) \
		and _is_finite_range(values.get("fog_sky_affect"), 0.0, 1.0)


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


static func _is_unit_float(value: Variant) -> bool:
	return value is float and is_finite(float(value)) \
		and float(value) >= 0.0 and float(value) <= 1.0


static func _is_finite_range(
		value: Variant,
		minimum: float,
		maximum: float
	) -> bool:
	return value is float and is_finite(float(value)) \
		and float(value) >= minimum and float(value) <= maximum


static func _renderer_real(value: Variant) -> float:
	# Vector components use the renderer build's real_t representation. Freeze
	# the candidate in that representation before exact Environment readback.
	return Vector2(float(value), 0.0).x


static func _color_is_bounded(value: Color) -> bool:
	return is_finite(value.r) and is_finite(value.g) \
		and is_finite(value.b) and is_finite(value.a) \
		and value.r >= 0.0 and value.r <= 1.0 \
		and value.g >= 0.0 and value.g <= 1.0 \
		and value.b >= 0.0 and value.b <= 1.0 \
		and value.a >= 0.0 and value.a <= 1.0
