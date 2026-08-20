class_name PlanetarySunPresentation
extends Node

## Passive, generation-safe DirectionalLight3D presentation adapter.
##
## A composition owner supplies validated world/atmosphere definitions, one
## existing light, and its exact authored baseline. This component configures a
## private PlanetarySunLightingPolicy and owns only baseline-relative
## light_color and light_energy writes. It never owns light direction, a clock,
## ephemeris, shadows, occlusion, world state, physics, or gameplay.

signal presentation_committed(reason: StringName, snapshot: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"planetary-sun-presentation"
const EQUATION_VERSION: StringName = &"baseline_relative_sun_light_v1"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MAX_AUTHORED_LIGHT_ENERGY := 64.0
const OWNED_RENDERER_PROPERTIES := ["light_color", "light_energy"]
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"directional_light_node_ownership", "directional_light_creation",
	"light_direction_or_transform", "sun_ephemeris",
	"time_or_day_night_clock", "absolute_energy_or_lux",
	"calibrated_colorimetry", "temperature", "angular_distance", "shadows",
	"occlusion_query", "terrain_horizon", "cloud_or_weather",
	"environment_or_sky", "camera", "origin_or_rebase", "physics",
	"gameplay", "streaming", "save", "network",
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
	"directional_light_node_ownership": false,
	"directional_light_creation": false,
	"light_direction_or_transform": false,
	"sun_ephemeris": false,
	"time_or_day_night_clock": false,
	"absolute_energy_or_lux": false,
	"calibrated_colorimetry": false,
	"temperature": false,
	"angular_distance": false,
	"shadows": false,
	"occlusion_query": false,
	"terrain_horizon": false,
	"cloud_or_weather": false,
	"environment_or_sky": false,
	"camera": false,
	"origin_or_rebase": false,
	"physics": false,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
}
const CAPABILITIES := {
	"baseline_relative_light_energy_implemented": true,
	"baseline_relative_light_color_hint_implemented": true,
	"transactional_renderer_apply": true,
	"caller_driven_observations_only": true,
	"tree_exit_restores_baseline": true,
	"tree_reentry_reapplies_current_generation": true,
	"target_tree_exit_restores_baseline": true,
	"target_tree_reentry_reapplies_current_generation": true,
	"direction_or_orientation_implemented": false,
	"absolute_energy_or_lux_implemented": false,
	"calibrated_colorimetry_implemented": false,
	"shadow_or_occlusion_implemented": false,
	"clock_or_ephemeris_implemented": false,
	"environment_or_sky_implemented": false,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}

var _configured := false
var _world_id: StringName = &""
var _source_world_schema_version := 0
var _source_atmosphere_schema_version := 0
var _policy: PlanetarySunLightingPolicy
var _policy_snapshot: Dictionary = {}
var _light_ref: WeakRef
var _light_instance_id := 0
var _baseline_renderer_values: Dictionary = {}
var _current_renderer_values: Dictionary = {}
var _last_evaluation: Dictionary = {}
var _generation := 0
var _revision := 0
var _presented_observation_count := 0
var _reset_count := 0
var _mutation_active := false
var _signal_dispatch_active := false
var _lifecycle_apply_active := false
var _last_lifecycle_error: StringName = &""


func _enter_tree() -> void:
	if not _configured:
		return
	_lifecycle_apply_active = true
	var light := _resolve_light()
	var values := (
		_current_renderer_values
		if light != null and light.is_inside_tree()
		else _baseline_renderer_values
	)
	_record_lifecycle_result(_apply_renderer_values(values))
	_lifecycle_apply_active = false


func _exit_tree() -> void:
	if not _configured:
		return
	_lifecycle_apply_active = true
	_record_lifecycle_result(_apply_renderer_values(_baseline_renderer_values))
	_lifecycle_apply_active = false


## Configures once from detached policy inputs and one caller-owned light.
## The explicit authored baseline must exactly match the target's current two
## owned values; configuration never silently rewrites an unexpected target.
func configure(
		world: PlanetaryWorldDefinition,
		atmosphere: PlanetaryAtmosphereProfile,
		target: Variant,
		authored_baseline_energy: Variant,
		authored_baseline_color: Variant
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if _configured:
		return _result(false, &"already_configured")
	if world == null:
		return _result(false, &"missing_world_definition")
	if target is not DirectionalLight3D:
		return _result(false, &"missing_directional_light")
	var light := target as DirectionalLight3D
	if not is_instance_valid(light) or light.is_queued_for_deletion():
		return _result(false, &"directional_light_unavailable")
	var baseline_result := _decode_authored_baseline(
		authored_baseline_energy, authored_baseline_color
	)
	if not bool(baseline_result.get("accepted", false)):
		return _result(
			false,
			StringName(baseline_result.get("reason", &"invalid_authored_baseline"))
		)
	var baseline := baseline_result.get("values", {}) as Dictionary
	if _read_renderer_values(light) != baseline:
		return _result(false, &"renderer_baseline_mismatch")
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")

	var policy := PlanetarySunLightingPolicy.new()
	var policy_result := policy.configure(world, atmosphere)
	if not bool(policy_result.get("accepted", false)):
		return _result(false, &"policy_configuration_failed", {
			"policy_reason": policy_result.get("reason", &"unknown"),
		})
	var policy_audit := policy.audit()
	var policy_snapshot := policy.get_snapshot()
	if not bool(policy_audit.get("valid", false)) \
			or policy_snapshot.get("world_id", &"") == &"":
		return _result(false, &"policy_configuration_failed", {
			"policy_reason": &"invalid_policy_audit",
		})

	_mutation_active = true
	_world_id = policy_snapshot.get("world_id", &"") as StringName
	_source_world_schema_version = int(
		policy_snapshot.get("source_world_schema_version", 0)
	)
	_source_atmosphere_schema_version = int(
		policy_snapshot.get("source_atmosphere_schema_version", 0)
	)
	_policy = policy
	_policy_snapshot = policy_snapshot.duplicate(true)
	_light_ref = weakref(light)
	_light_instance_id = light.get_instance_id()
	_baseline_renderer_values = baseline.duplicate(true)
	_current_renderer_values = baseline.duplicate(true)
	_generation += 1
	_configured = true
	_connect_target_lifecycle(light)
	_mutation_active = false
	_commit(&"configured")
	return _result(true, &"configured")


## Evaluates one exact body-local observation through the frozen private policy
## and applies only the two baseline-relative light properties.
func present_observation(
		observation: Variant,
		expected_generation: Variant
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if not _is_exact_integer(expected_generation) \
			or int(expected_generation) != _generation:
		return _result(false, &"stale_generation")
	var light := _resolve_light(true)
	if light == null:
		return _result(false, &"directional_light_unavailable")
	# This public adapter can be called without its composition owner. A detached
	# sample must not become a retained candidate that first appears on a later
	# adapter or target re-entry.
	if is_queued_for_deletion() or not is_inside_tree() \
			or light.is_queued_for_deletion() or not light.is_inside_tree():
		return _result(false, &"presentation_detached")
	if _policy == null or not bool(_policy.audit().get("valid", false)):
		return _result(false, &"policy_unavailable")

	var policy_result := _policy.evaluate(observation)
	if not bool(policy_result.get("accepted", false)):
		return _result(false, &"policy_evaluation_rejected", {
			"policy_reason": policy_result.get("reason", &"unknown"),
		})
	var evaluation := policy_result.get("evaluation", {}) as Dictionary
	if not _policy_evaluation_is_valid(evaluation):
		return _result(false, &"policy_evaluation_contract_mismatch")
	var renderer_values := _renderer_values_for_evaluation(evaluation)
	if not _renderer_values_are_bounded(renderer_values):
		return _result(false, &"renderer_mapping_out_of_bounds")
	var identical := evaluation == _last_evaluation \
		and renderer_values == _current_renderer_values
	if identical and _target_matches_expected():
		return _result(true, &"unchanged", {
			"evaluation": _last_evaluation.duplicate(true),
			"renderer_values": _current_renderer_values.duplicate(true),
		})

	_mutation_active = true
	var apply_result := _apply_renderer_values(renderer_values)
	if not bool(apply_result.get("accepted", false)):
		_mutation_active = false
		return _result(
			false,
			StringName(apply_result.get("reason", &"renderer_apply_failed"))
		)
	_last_evaluation = evaluation.duplicate(true)
	_current_renderer_values = renderer_values.duplicate(true)
	_presented_observation_count += 1
	_last_lifecycle_error = &""
	_mutation_active = false
	var reason: StringName = (
		&"renderer_reapplied" if identical else &"observation_presented"
	)
	_commit(reason)
	return _result(true, reason, {
		"evaluation": _last_evaluation.duplicate(true),
		"renderer_values": _current_renderer_values.duplicate(true),
	})


## Restores the exact authored baseline before advancing the generation.
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
	if _resolve_light() == null:
		return _result(false, &"directional_light_unavailable")
	_mutation_active = true
	var apply_result := _apply_renderer_values(_baseline_renderer_values)
	if not bool(apply_result.get("accepted", false)):
		_mutation_active = false
		return _result(
			false,
			StringName(apply_result.get("reason", &"renderer_apply_failed"))
		)
	_generation += 1
	_last_evaluation.clear()
	_current_renderer_values = _baseline_renderer_values.duplicate(true)
	_reset_count += 1
	_last_lifecycle_error = &""
	_mutation_active = false
	_commit(&"reset")
	return _result(true, &"reset")


func get_generation() -> int:
	return _generation


func get_policy_snapshot() -> Dictionary:
	return _policy_snapshot.duplicate(true)


func get_renderer_snapshot() -> Dictionary:
	var light := _resolve_light()
	var actual := _read_renderer_values(light) if light != null else {}
	var target_inside_tree := light != null and light.is_inside_tree()
	var current_should_apply := is_inside_tree() and target_inside_tree
	return {
		"target_available": light != null,
		"target_inside_tree": target_inside_tree,
		"target_instance_id": _light_instance_id,
		"owned_properties": OWNED_RENDERER_PROPERTIES.duplicate(),
		"baseline": _baseline_renderer_values.duplicate(true),
		"expected": _current_renderer_values.duplicate(true),
		"actual": actual,
		"current_values_applied": (
			current_should_apply and actual == _current_renderer_values
		),
		"baseline_applied_while_inactive": (
			not current_should_apply and light != null
			and actual == _baseline_renderer_values
		),
	}.duplicate(true)


func get_state_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"equation_version": EQUATION_VERSION,
		"configured": _configured,
		"world_id": _world_id,
		"source_world_schema_version": _source_world_schema_version,
		"source_atmosphere_schema_version": (
			_source_atmosphere_schema_version
		),
		"generation": _generation,
		"revision": _revision,
		"inside_tree": is_inside_tree(),
		"has_presented_observation": not _last_evaluation.is_empty(),
		"last_evaluation": _last_evaluation.duplicate(true),
		"policy": _policy_snapshot.duplicate(true),
		"renderer": get_renderer_snapshot(),
		"presented_observation_count": _presented_observation_count,
		"reset_count": _reset_count,
		"last_lifecycle_error": _last_lifecycle_error,
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("presentation_not_configured")
	else:
		if _world_id.is_empty() \
				or _source_world_schema_version \
				!= PlanetaryWorldDefinition.SCHEMA_VERSION:
			errors.append("policy_identity_drift")
		if _policy == null or not bool(_policy.audit().get("valid", false)) \
				or _policy.get_snapshot() != _policy_snapshot:
			errors.append("policy_contract_drift")
		if _resolve_light() == null:
			errors.append("directional_light_identity_drift")
		elif not _target_matches_expected():
			errors.append("owned_renderer_state_drift")
		if not _baseline_values_are_valid(_baseline_renderer_values):
			errors.append("renderer_baseline_drift")
		if not _renderer_values_are_bounded(_current_renderer_values):
			errors.append("renderer_candidate_drift")
		if _generation <= 0 or _generation > MAX_SAFE_GENERATION:
			errors.append("generation_out_of_bounds")
		if _revision <= 0:
			errors.append("revision_out_of_bounds")
		if not _last_evaluation.is_empty() \
				and not _policy_evaluation_is_valid(_last_evaluation):
			errors.append("evaluation_contract_drift")
		if not _last_lifecycle_error.is_empty():
			errors.append("lifecycle_apply_failed")
	if not _authority_contract_is_valid(AUTHORITY):
		errors.append("authority_contract_drift")
	if not _exact_false_contract_is_valid(
		ADJACENT_AUTHORITY, ADJACENT_AUTHORITY_KEYS
	):
		errors.append("adjacent_authority_contract_drift")
	if not _evidence_contract_is_valid(EVIDENCE):
		errors.append("evidence_contract_drift")
	if not _capability_contract_is_valid(CAPABILITIES):
		errors.append("capability_contract_drift")
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
			"energy": &"authored_baseline_times_policy_unit_factor",
			"color": &"authored_baseline_rgb_times_normalized_policy_hint",
			"alpha": &"authored_baseline_preserved",
			"night": &"zero_energy_with_baseline_color_metadata",
			"airless_or_vacuum_day": &"exact_authored_baseline",
		},
		"boundaries": {
			"authored_energy": &"finite_zero_to_named_adapter_ceiling_inclusive",
			"authored_color": &"finite_unit_channels",
			"observation": &"delegated_to_frozen_planetary_sun_lighting_policy",
			"generation": &"exact_safe_integer_current_generation",
		},
		"limitations": {
			"direction_matches_observation_verified": false,
			"absolute_energy_or_lux_produced": false,
			"calibrated_colorimetry_produced": false,
			"terrain_or_cloud_occlusion_modeled": false,
			"visual_quality_reviewed": false,
		},
		"performance": {
			"runtime_child_node_count": get_child_count(),
			"owned_directional_light_count": 0,
			"renderer_node_allocations_after_configuration": 0,
			"process_loop_count": 0,
		},
		"evidence": EVIDENCE.duplicate(true),
		"source_evidence": (
			_policy_snapshot.get("source_evidence", {}) as Dictionary
		).duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"capabilities": CAPABILITIES.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _connect_target_lifecycle(light: DirectionalLight3D) -> void:
	var exiting := Callable(self, &"_on_target_tree_exiting")
	var entered := Callable(self, &"_on_target_tree_entered")
	if not light.tree_exiting.is_connected(exiting):
		light.tree_exiting.connect(exiting)
	if not light.tree_entered.is_connected(entered):
		light.tree_entered.connect(entered)


func _on_target_tree_exiting() -> void:
	if not _configured:
		return
	_lifecycle_apply_active = true
	_record_lifecycle_result(
		_apply_renderer_values(_baseline_renderer_values, true)
	)
	_lifecycle_apply_active = false


func _on_target_tree_entered() -> void:
	if not _configured:
		return
	_lifecycle_apply_active = true
	var values := (
		_current_renderer_values if is_inside_tree()
		else _baseline_renderer_values
	)
	_record_lifecycle_result(_apply_renderer_values(values))
	_lifecycle_apply_active = false


func _record_lifecycle_result(result: Dictionary) -> void:
	_last_lifecycle_error = (
		&"" if bool(result.get("accepted", false))
		else StringName(result.get("reason", &"renderer_apply_failed"))
	)


func _decode_authored_baseline(
		energy_value: Variant,
		color_value: Variant
	) -> Dictionary:
	if not _is_finite_range(
		energy_value, 0.0, MAX_AUTHORED_LIGHT_ENERGY
	):
		return {"accepted": false, "reason": &"invalid_authored_energy"}
	if color_value is not Color or not _color_is_bounded(color_value as Color):
		return {"accepted": false, "reason": &"invalid_authored_color"}
	return {
		"accepted": true,
		"reason": &"valid_authored_baseline",
		"values": {
			"light_color": color_value as Color,
			"light_energy": _renderer_real(energy_value),
		}.duplicate(true),
	}


func _renderer_values_for_evaluation(evaluation: Dictionary) -> Dictionary:
	var hint := evaluation.get("directional_light_hint", {}) as Dictionary
	var factor := float(
		hint.get("recommended_energy_factor_unitless", 0.0)
	)
	var tint := hint.get("recommended_color", Color.WHITE) as Color
	var baseline_color := _baseline_renderer_values.get(
		"light_color", Color.WHITE
	) as Color
	return {
		"light_color": Color(
			baseline_color.r * tint.r,
			baseline_color.g * tint.g,
			baseline_color.b * tint.b,
			baseline_color.a
		),
		"light_energy": _renderer_real(float(
			_baseline_renderer_values.get("light_energy", 0.0)
		) * factor),
	}.duplicate(true)


func _policy_evaluation_is_valid(evaluation: Dictionary) -> bool:
	if not bool(evaluation.get("accepted", false)) \
			or evaluation.get("reason", &"") != &"evaluated" \
			or evaluation.get("world_id", &"") != _world_id \
			or evaluation.get("policy_version", &"") \
			!= PlanetarySunLightingPolicy.POLICY_VERSION \
			or evaluation.get("equation_version", &"") \
			!= PlanetarySunLightingPolicy.EQUATION_VERSION:
		return false
	if evaluation.get("inputs") is not Dictionary \
			or evaluation.get("geometry") is not Dictionary \
			or evaluation.get("classification") is not Dictionary \
			or evaluation.get("directional_light_hint") is not Dictionary:
		return false
	var hint := evaluation.get("directional_light_hint", {}) as Dictionary
	if hint.size() != 6 \
			or hint.get("color_space", &"") \
			!= &"linear_rgb_normalized_hint" \
			or hint.get("recommended_color") is not Color \
			or not _color_is_bounded(hint.get("recommended_color") as Color) \
			or not _is_finite_range(
				hint.get("recommended_energy_factor_unitless"), 0.0, 1.0
			) \
			or hint.get("absolute_energy_or_lux") is not bool \
			or bool(hint.get("absolute_energy_or_lux", true)):
		return false
	return hint.get("direct_transmittance_rgb") is Color \
		and _color_is_bounded(hint.get("direct_transmittance_rgb") as Color) \
		and _is_finite_range(
			hint.get("direct_transmittance_unitless"), 0.0, 1.0
		)


func _resolve_light(allow_queued: bool = false) -> DirectionalLight3D:
	if _light_ref == null:
		return null
	var candidate: Variant = _light_ref.get_ref()
	if candidate == null or not is_instance_valid(candidate) \
			or candidate is not DirectionalLight3D:
		return null
	var light := candidate as DirectionalLight3D
	if light.get_instance_id() != _light_instance_id:
		return null
	if not allow_queued and light.is_queued_for_deletion():
		return null
	return light


func _read_renderer_values(light: DirectionalLight3D) -> Dictionary:
	return {
		"light_color": light.light_color,
		"light_energy": light.light_energy,
	}.duplicate(true)


func _apply_renderer_values(
		values: Dictionary,
		allow_queued: bool = false
	) -> Dictionary:
	var light := _resolve_light(allow_queued)
	if light == null:
		return {"accepted": false, "reason": &"directional_light_unavailable"}
	if not _renderer_values_are_bounded(values):
		return {"accepted": false, "reason": &"renderer_mapping_out_of_bounds"}
	var previous := _read_renderer_values(light)
	var color := values.get("light_color", Color.WHITE) as Color
	var energy := float(values.get("light_energy", 0.0))
	if light.light_color != color:
		light.light_color = color
	if _resolve_light(allow_queued) != light:
		return _rollback_after_apply_failure(
			light, previous, &"target_changed_during_apply"
		)
	if light.light_energy != energy:
		light.light_energy = energy
	if _resolve_light(allow_queued) != light:
		return _rollback_after_apply_failure(
			light, previous, &"target_changed_during_apply"
		)
	if _read_renderer_values(light) != values:
		return _rollback_after_apply_failure(
			light, previous, &"renderer_state_changed_during_apply"
		)
	return {"accepted": true, "reason": &"renderer_values_applied"}


func _rollback_after_apply_failure(
		light: DirectionalLight3D,
		previous: Dictionary,
		reason: StringName
	) -> Dictionary:
	if not _restore_cached_light(light, previous):
		return {"accepted": false, "reason": &"rollback_failed"}
	return {"accepted": false, "reason": reason}


func _restore_cached_light(
		light: DirectionalLight3D,
		values: Dictionary
	) -> bool:
	if light == null or not is_instance_valid(light) \
			or not _baseline_values_are_valid(values):
		return false
	light.light_color = values.get("light_color", Color.WHITE) as Color
	light.light_energy = float(values.get("light_energy", 0.0))
	return is_instance_valid(light) and _read_renderer_values(light) == values


func _target_matches_expected() -> bool:
	var light := _resolve_light()
	if light == null:
		return false
	var expected := (
		_current_renderer_values
		if is_inside_tree() and light.is_inside_tree()
		else _baseline_renderer_values
	)
	return _read_renderer_values(light) == expected


func _baseline_values_are_valid(values: Dictionary) -> bool:
	if values.size() != OWNED_RENDERER_PROPERTIES.size() \
			or values.get("light_color") is not Color:
		return false
	return _color_is_bounded(values.get("light_color") as Color) \
		and _is_finite_range(
			values.get("light_energy"), 0.0, MAX_AUTHORED_LIGHT_ENERGY
		)


func _renderer_values_are_bounded(values: Dictionary) -> bool:
	if not _baseline_values_are_valid(values) \
			or not _baseline_values_are_valid(_baseline_renderer_values):
		return false
	var color := values.get("light_color") as Color
	var baseline_color := _baseline_renderer_values.get("light_color") as Color
	var energy := float(values.get("light_energy", -1.0))
	var baseline_energy := float(
		_baseline_renderer_values.get("light_energy", -1.0)
	)
	return color.r <= baseline_color.r \
		and color.g <= baseline_color.g \
		and color.b <= baseline_color.b \
		and color.a == baseline_color.a \
		and energy <= baseline_energy


func _is_reentrant() -> bool:
	return _mutation_active or _signal_dispatch_active \
		or _lifecycle_apply_active


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
	return value is int and int(value) >= 0 \
		and int(value) <= MAX_SAFE_GENERATION


static func _is_finite_range(
		value: Variant,
		minimum: float,
		maximum: float
	) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
		and float(value) >= minimum and float(value) <= maximum


static func _renderer_real(value: Variant) -> float:
	# Vector components use the renderer build's real_t representation. This
	# canonicalizes the candidate before the exact Light3D property transaction.
	return Vector2(float(value), 0.0).x


static func _color_is_bounded(value: Color) -> bool:
	return is_finite(value.r) and is_finite(value.g) \
		and is_finite(value.b) and is_finite(value.a) \
		and value.r >= 0.0 and value.r <= 1.0 \
		and value.g >= 0.0 and value.g <= 1.0 \
		and value.b >= 0.0 and value.b <= 1.0 \
		and value.a >= 0.0 and value.a <= 1.0


static func _authority_contract_is_valid(value: Dictionary) -> bool:
	if value.size() != COMMON_AUTHORITY_KEYS.size() \
			or value.get("renderer") is not bool \
			or not bool(value.get("renderer", false)):
		return false
	for key: String in COMMON_AUTHORITY_KEYS:
		if not value.has(key) or value[key] is not bool:
			return false
		if key != "renderer" and bool(value[key]):
			return false
	return true


static func _exact_false_contract_is_valid(
		value: Dictionary,
		keys: Array
	) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key) or value[key] is not bool or bool(value[key]):
			return false
	return true


static func _evidence_contract_is_valid(value: Dictionary) -> bool:
	return value.size() == 4 \
		and value.get("content_class") is StringName \
		and value.get("content_class") == &"NEW" \
		and value.get("status") is StringName \
		and value.get("status") == &"modern_interpretation" \
		and value.get("source_bounded") is bool \
		and not bool(value.get("source_bounded", true)) \
		and value.get("confidence") is StringName \
		and value.get("confidence") == &"none"


static func _capability_contract_is_valid(value: Dictionary) -> bool:
	if value.size() != CAPABILITIES.size():
		return false
	for key: Variant in CAPABILITIES:
		if not value.has(key) or value[key] is not bool \
				or value[key] != CAPABILITIES[key]:
			return false
	return true
