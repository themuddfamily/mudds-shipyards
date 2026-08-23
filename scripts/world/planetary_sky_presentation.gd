class_name PlanetarySkyPresentation
extends Node

## Passive, generation-safe procedural-sky colour adapter.
##
## A composition owner supplies a validated atmosphere profile and an existing
## Environment -> Sky -> ProceduralSkyMaterial chain. The component freezes
## detached profile values and the three authored colour baselines, then changes
## only those colours when a caller submits an altitude and unit sun/view frame.
## It owns no clock, process loop, target Resource, light, camera, weather,
## cloud, movement, streaming, physics, gameplay, or persistence decision.

signal presentation_committed(reason: StringName, snapshot: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"planetary-sky-presentation"
const EQUATION_VERSION: StringName = &"procedural_sky_aerial_colour_v1"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const UNIT_VECTOR_TOLERANCE := 0.0001
const OWNED_RENDERER_PROPERTIES := [
	"sky_top_color",
	"sky_horizon_color",
	"ground_horizon_color",
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
	"environment_ownership": false,
	"world_environment_ownership": false,
	"sky_resource_ownership": false,
	"sky_material_ownership": false,
	"background_mode": false,
	"ambient_light": false,
	"reflections": false,
	"fog": false,
	"clouds": false,
	"sun_light": false,
	"camera": false,
	"weather_selection": false,
	"weather_clock": false,
	"ship_movement": false,
	"player_movement": false,
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
var _environment_ref: WeakRef
var _sky_ref: WeakRef
var _material_ref: WeakRef
var _environment_instance_id := 0
var _sky_instance_id := 0
var _material_instance_id := 0
var _baseline_renderer_values: Dictionary = {}
var _current_renderer_values: Dictionary = {}
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
		_apply_renderer_values(_current_renderer_values)
		_lifecycle_apply_active = false


func _exit_tree() -> void:
	if _configured:
		_lifecycle_apply_active = true
		_apply_renderer_values(_baseline_renderer_values)
		_lifecycle_apply_active = false


## Configures this passive component once. No target Resource is allocated,
## duplicated, retained strongly, or exposed through a report.
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
				profile_audit.get("errors", PackedStringArray()) \
					as PackedStringArray
			).duplicate(),
		})
	var target_result := _validate_unconfigured_target(environment)
	if not bool(target_result.get("accepted", false)):
		return _result(false, StringName(target_result.get("reason", &"invalid_target")))
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	var sampler := PlanetaryAtmosphereSampler.new()
	var sampler_result := sampler.configure(profile)
	if not bool(sampler_result.get("accepted", false)) \
			or not bool(sampler.audit().get("valid", false)):
		return _result(false, &"sampler_configuration_failed")
	var sky := environment.sky
	var material := sky.sky_material as ProceduralSkyMaterial
	var baseline := _read_renderer_values(material)
	if not _renderer_values_are_bounded(baseline):
		return _result(false, &"invalid_renderer_baseline")

	_mutation_active = true
	_profile_id = StringName(profile_audit.get("profile_id", &""))
	_source_profile_schema_version = int(profile_audit.get("schema_version", 0))
	_profile_snapshot = profile_audit.duplicate(true)
	_sampler = sampler
	_environment_ref = weakref(environment)
	_sky_ref = weakref(sky)
	_material_ref = weakref(material)
	_environment_instance_id = environment.get_instance_id()
	_sky_instance_id = sky.get_instance_id()
	_material_instance_id = material.get_instance_id()
	_baseline_renderer_values = baseline.duplicate(true)
	_current_renderer_values = baseline.duplicate(true)
	_generation += 1
	_configured = true
	_mutation_active = false
	_commit(&"configured")
	return _result(true, &"configured")


## Applies one caller observation. Directions are finite unit vectors in a
## shared coordinate frame: view points from observer into the viewed sky,
## surface_up points radially outward, and direction_to_sun points toward sun.
func present_observation(
		altitude_m: Variant,
		view_direction: Variant,
		surface_up_direction: Variant,
		direction_to_sun: Variant,
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
	# must not become retained renderer intent that appears on a later re-entry.
	if is_queued_for_deletion() or not is_inside_tree():
		return _result(false, &"presentation_detached")
	if not _is_finite_number(altitude_m):
		return _result(false, &"invalid_altitude")
	var altitude := float(altitude_m)
	var geometry := _profile_snapshot.get("geometry", {}) as Dictionary
	var planet_radius := float(geometry.get("planet_radius_m", NAN))
	if altitude < -planet_radius \
			or altitude > PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M:
		return _result(false, &"invalid_altitude")
	var vector_reason := _validate_direction(view_direction, &"view")
	if not vector_reason.is_empty():
		return _result(false, vector_reason)
	vector_reason = _validate_direction(surface_up_direction, &"surface_up")
	if not vector_reason.is_empty():
		return _result(false, vector_reason)
	vector_reason = _validate_direction(direction_to_sun, &"sun")
	if not vector_reason.is_empty():
		return _result(false, vector_reason)
	if _resolve_material() == null:
		return _result(false, &"renderer_target_unavailable")

	var view := (view_direction as Vector3).normalized()
	var surface_up := (surface_up_direction as Vector3).normalized()
	var sun := (direction_to_sun as Vector3).normalized()
	_mutation_active = true
	var observation := _build_observation(altitude, view, surface_up, sun)
	if not bool(observation.get("accepted", false)):
		_mutation_active = false
		return _result(
			false, StringName(observation.get("reason", &"sample_rejected"))
		)
	var renderer_values := _renderer_values_for_observation(observation)
	if not _renderer_values_are_bounded(renderer_values):
		_mutation_active = false
		return _result(false, &"renderer_mapping_out_of_bounds")
	var identical := observation == _last_observation \
		and renderer_values == _current_renderer_values
	var target_matches := _target_matches_expected()
	if identical and target_matches:
		_mutation_active = false
		return _result(true, &"unchanged", {
			"observation": _last_observation.duplicate(true),
		})

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
	_last_observation = observation.duplicate(true)
	_current_renderer_values = renderer_values.duplicate(true)
	_presented_observation_count += 1
	_mutation_active = false
	var reason: StringName = (
		&"renderer_reapplied" if identical else &"observation_presented"
	)
	_commit(reason)
	return _result(true, reason, {
		"observation": _last_observation.duplicate(true),
	})


## Advances the bounded generation, clears the last observation, and restores
## the exact authored colour baseline while retaining immutable configuration.
func reset_for_reuse(expected_generation: Variant) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if not _is_exact_integer(expected_generation) \
			or int(expected_generation) != _generation:
		return _result(false, &"stale_generation")
	# Like observations, reuse is a public renderer-intent mutation. A detached
	# or terminal adapter must not tombstone its live caller or emit a deferred
	# reset that changes what a later re-entry restores.
	if is_queued_for_deletion() or not is_inside_tree():
		return _result(false, &"presentation_detached")
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	if _resolve_material() == null:
		return _result(false, &"renderer_target_unavailable")
	_mutation_active = true
	var apply_result := _apply_renderer_values(_baseline_renderer_values)
	if not bool(apply_result.get("accepted", false)):
		_mutation_active = false
		return _result(
			false,
			StringName(apply_result.get("reason", &"renderer_apply_failed"))
		)
	_generation += 1
	_last_observation.clear()
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
	var material := _resolve_material()
	var actual := _read_renderer_values(material) if material != null else {}
	return {
		"target_available": material != null,
		"environment_instance_id": _environment_instance_id,
		"sky_instance_id": _sky_instance_id,
		"material_instance_id": _material_instance_id,
		"owned_properties": OWNED_RENDERER_PROPERTIES.duplicate(),
		"baseline": _baseline_renderer_values.duplicate(true),
		"expected": _current_renderer_values.duplicate(true),
		"actual": actual,
		"current_values_applied": (
			is_inside_tree() and material != null
			and actual == _current_renderer_values
		),
		"baseline_applied_while_detached": (
			not is_inside_tree() and material != null
			and actual == _baseline_renderer_values
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
		if _resolve_environment() == null:
			errors.append("environment_identity_drift")
		elif _resolve_sky() == null:
			errors.append("sky_identity_drift")
		elif _resolve_material() == null:
			errors.append("sky_material_identity_drift")
		elif not _target_matches_expected():
			errors.append("owned_renderer_state_drift")
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
		"owned_renderer_properties": OWNED_RENDERER_PROPERTIES.duplicate(),
		"renderer_mapping": {
			"shell_path": &"spherical_outer_shell_then_profile_visibility_cap",
			"scattering_phase": &"normalized_henyey_greenstein",
			"colour": &"baseline_times_transmittance_plus_scatter_times_one_minus_transmittance",
			"top_path": &"radial_zenith",
			"horizon_path": &"tangent_to_outer_shell",
			"exact_vacuum": &"authored_baseline",
		},
		"boundaries": {
			"altitude_below_reference": &"sampler_clamps_density_to_reference",
			"altitude_below_body_center": &"reject",
			"at_or_above_atmosphere_top": &"exact_vacuum_baseline",
			"directions": &"finite_unit_vectors_with_tolerance",
			"path_cap_m": _maximum_visibility_m(),
		},
		"capabilities": {
			"procedural_sky_color_renderer_implemented": true,
			"fog_renderer_implemented": false,
			"cloud_renderer_implemented": false,
			"sun_renderer_implemented": false,
			"shell_renderer_implemented": false,
			"ambient_reflection_policy_implemented": false,
			"caller_driven_observations_only": true,
			"transactional_renderer_apply": true,
			"consolidated_resource_changed_notification": true,
			"tree_exit_restores_baseline": true,
			"tree_reentry_reapplies_current_generation": true,
		},
		"performance": {
			"runtime_child_node_count": get_child_count(),
			"owned_environment_resource_count": 0,
			"owned_sky_resource_count": 0,
			"owned_sky_material_resource_count": 0,
			"renderer_resource_allocations_after_configuration": 0,
			"process_loop_count": 0,
		},
		"evidence": EVIDENCE.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


## Maps a retained caller-owned Ember solar phase into bounded presentation
## hints. This never advances time or writes renderer resources.
func present_solar_phase_snapshot(snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary:
		return _result(false, &"invalid_solar_phase_snapshot")
	var phase := snapshot as Dictionary
	var state := StringName(phase.get("state", &""))
	if state not in [&"daylight", &"twilight", &"night"]:
		return _result(false, &"invalid_solar_phase_state")
	var elevation: Variant = phase.get("sun_elevation_sine", NAN)
	var twilight: Variant = phase.get("twilight_factor_unitless", NAN)
	if not (elevation is float or elevation is int) or not (twilight is float or twilight is int):
		return _result(false, &"invalid_solar_phase_values")
	var day_factor := clampf(float(elevation), 0.0, 1.0)
	var twilight_factor := clampf(float(twilight), 0.0, 1.0)
	var night_factor := 1.0 if state == &"night" else clampf(1.0 - day_factor - twilight_factor, 0.0, 1.0)
	return _result(true, &"solar_phase_mapped", {
		"state": state,
		"sun_energy_unitless": day_factor,
		"sky_exposure_unitless": clampf(0.16 + day_factor * 0.84 + twilight_factor * 0.16, 0.0, 1.0),
		"night_visibility_unitless": clampf(0.35 + night_factor * 0.65, 0.0, 1.0),
		"sun_color": Color(1.0, 0.62 + day_factor * 0.38, 0.32 + day_factor * 0.68, 1.0),
	}).duplicate(true)


func _build_observation(
		altitude_m: float,
		view: Vector3,
		surface_up: Vector3,
		sun: Vector3
	) -> Dictionary:
	var geometry := _profile_snapshot.get("geometry", {}) as Dictionary
	var planet_radius := float(geometry.get("planet_radius_m", NAN))
	var atmosphere_top := float(
		geometry.get("atmosphere_top_altitude_m", NAN)
	)
	var vacuum := altitude_m >= atmosphere_top
	var zenith_path := 0.0
	var horizon_path := 0.0
	if not vacuum:
		var local_radius := planet_radius + altitude_m
		var outer_radius := planet_radius + atmosphere_top
		zenith_path = minf(
			outer_radius - local_radius, _maximum_visibility_m()
		)
		var tangent_squared := maxf(
			outer_radius * outer_radius - local_radius * local_radius, 0.0
		)
		horizon_path = minf(sqrt(tangent_squared), _maximum_visibility_m())
	var zenith_sample := _sampler.sample(
		altitude_m, zenith_path, 0.0, 1.0, 1.0
	)
	var horizon_sample := _sampler.sample(
		altitude_m, horizon_path, 0.0, 1.0, 1.0
	)
	if not bool(zenith_sample.get("accepted", false)) \
			or not bool(horizon_sample.get("accepted", false)):
		return {"accepted": false, "reason": &"sample_rejected"}
	var view_sun_alignment := clampf(view.dot(sun), -1.0, 1.0)
	var sun_elevation := clampf(surface_up.dot(sun), -1.0, 1.0)
	var mie_phase := _normalized_mie_phase(view_sun_alignment)
	var scattering_tint := _scattering_color(
		mie_phase * maxf(sun_elevation, 0.0)
	)
	return {
		"accepted": true,
		"reason": &"observed",
		"profile_id": _profile_id,
		"equation_version": EQUATION_VERSION,
		"inputs": {
			"altitude_m": altitude_m,
			"view_direction": view,
			"surface_up_direction": surface_up,
			"direction_to_sun": sun,
		},
		"vacuum": vacuum,
		"zenith_path_distance_m": zenith_path,
		"horizon_path_distance_m": horizon_path,
		"view_sun_alignment": view_sun_alignment,
		"sun_elevation": sun_elevation,
		"normalized_mie_phase": mie_phase,
		"scattering_tint": scattering_tint,
		"zenith_sample": zenith_sample.duplicate(true),
		"horizon_sample": horizon_sample.duplicate(true),
	}.duplicate(true)


func _renderer_values_for_observation(observation: Dictionary) -> Dictionary:
	if bool(observation.get("vacuum", true)):
		return _baseline_renderer_values.duplicate(true)
	var zenith_sample := observation.get("zenith_sample", {}) as Dictionary
	var horizon_sample := observation.get("horizon_sample", {}) as Dictionary
	var tint := observation.get(
		"scattering_tint", Color(0.5, 0.5, 0.5, 1.0)
	) as Color
	return {
		"sky_top_color": _atmospheric_color(
			_baseline_renderer_values.sky_top_color,
			zenith_sample.optical_transmittance_rgb,
			tint
		),
		"sky_horizon_color": _atmospheric_color(
			_baseline_renderer_values.sky_horizon_color,
			horizon_sample.optical_transmittance_rgb,
			tint
		),
		"ground_horizon_color": _atmospheric_color(
			_baseline_renderer_values.ground_horizon_color,
			horizon_sample.optical_transmittance_rgb,
			tint
		),
	}.duplicate(true)


func _atmospheric_color(
		baseline: Color,
		transmittance: Color,
		tint: Color
	) -> Color:
	return Color(
		clampf(baseline.r * transmittance.r + tint.r * (1.0 - transmittance.r), 0.0, 1.0),
		clampf(baseline.g * transmittance.g + tint.g * (1.0 - transmittance.g), 0.0, 1.0),
		clampf(baseline.b * transmittance.b + tint.b * (1.0 - transmittance.b), 0.0, 1.0),
		baseline.a
	)


func _normalized_mie_phase(view_sun_alignment: float) -> float:
	var optics := _profile_snapshot.get("optics", {}) as Dictionary
	var anisotropy := float(optics.get("mie_anisotropy_unitless", 0.0))
	var denominator := maxf(
		1.0 + anisotropy * anisotropy
		- 2.0 * anisotropy * view_sun_alignment,
		0.000000000001
	)
	var minimum_denominator := pow(1.0 - absf(anisotropy), 3.0)
	return clampf(
		minimum_denominator / pow(denominator, 1.5), 0.0, 1.0
	)


func _scattering_color(mie_weight: float) -> Color:
	var optics := _profile_snapshot.get("optics", {}) as Dictionary
	var rayleigh := optics.get(
		"rayleigh_scattering_per_m", Color(0.0, 0.0, 0.0, 1.0)
	) as Color
	var mie := optics.get(
		"mie_scattering_per_m", Color(0.0, 0.0, 0.0, 1.0)
	) as Color
	var combined := Vector3(
		rayleigh.r + mie.r * mie_weight,
		rayleigh.g + mie.g * mie_weight,
		rayleigh.b + mie.b * mie_weight
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


func _observation_contract_is_valid(observation: Dictionary) -> bool:
	if observation.get("profile_id", &"") != _profile_id \
			or observation.get("equation_version", &"") != EQUATION_VERSION:
		return false
	if not observation.get("inputs") is Dictionary \
			or not observation.get("scattering_tint") is Color:
		return false
	if not _is_finite_range(
		observation.get("zenith_path_distance_m"), 0.0, _maximum_visibility_m()
	) or not _is_finite_range(
		observation.get("horizon_path_distance_m"), 0.0, _maximum_visibility_m()
	) or not _is_finite_range(
		observation.get("normalized_mie_phase"), 0.0, 1.0
	):
		return false
	return bool(observation.get("zenith_sample", {}).get("accepted", false)) \
		and bool(observation.get("horizon_sample", {}).get("accepted", false))


func _validate_unconfigured_target(environment: Environment) -> Dictionary:
	if environment.background_mode != Environment.BG_SKY:
		return {"accepted": false, "reason": &"background_mode_not_sky"}
	if environment.sky == null or not is_instance_valid(environment.sky):
		return {"accepted": false, "reason": &"missing_sky"}
	if environment.sky.sky_material == null \
			or not is_instance_valid(environment.sky.sky_material):
		return {"accepted": false, "reason": &"missing_sky_material"}
	if not environment.sky.sky_material is ProceduralSkyMaterial:
		return {"accepted": false, "reason": &"unsupported_sky_material"}
	return {"accepted": true, "reason": &"valid_target"}


func _resolve_environment() -> Environment:
	if _environment_ref == null:
		return null
	var candidate: Variant = _environment_ref.get_ref()
	if candidate == null or not is_instance_valid(candidate) \
			or not candidate is Environment:
		return null
	var environment := candidate as Environment
	if environment.get_instance_id() != _environment_instance_id \
			or environment.background_mode != Environment.BG_SKY:
		return null
	return environment


func _resolve_sky() -> Sky:
	var environment := _resolve_environment()
	if environment == null or _sky_ref == null:
		return null
	var candidate: Variant = _sky_ref.get_ref()
	if candidate == null or not is_instance_valid(candidate) or not candidate is Sky:
		return null
	var sky := candidate as Sky
	if sky.get_instance_id() != _sky_instance_id or environment.sky != sky:
		return null
	return sky


func _resolve_material() -> ProceduralSkyMaterial:
	var sky := _resolve_sky()
	if sky == null or _material_ref == null:
		return null
	var candidate: Variant = _material_ref.get_ref()
	if candidate == null or not is_instance_valid(candidate) \
			or not candidate is ProceduralSkyMaterial:
		return null
	var material := candidate as ProceduralSkyMaterial
	if material.get_instance_id() != _material_instance_id \
			or sky.sky_material != material:
		return null
	return material


func _read_renderer_values(material: ProceduralSkyMaterial) -> Dictionary:
	return {
		"sky_top_color": material.sky_top_color,
		"sky_horizon_color": material.sky_horizon_color,
		"ground_horizon_color": material.ground_horizon_color,
	}.duplicate(true)


func _apply_renderer_values(values: Dictionary) -> Dictionary:
	var material := _resolve_material()
	if material == null:
		return {"accepted": false, "reason": &"renderer_target_unavailable"}
	if not _renderer_values_are_bounded(values):
		return {"accepted": false, "reason": &"renderer_mapping_out_of_bounds"}
	var previous := _read_renderer_values(material)
	var wrote_property := false
	var sky_top := values.get("sky_top_color", Color.BLACK) as Color
	var sky_horizon := values.get("sky_horizon_color", Color.BLACK) as Color
	var ground_horizon := values.get(
		"ground_horizon_color", Color.BLACK
	) as Color
	if material.sky_top_color != sky_top:
		material.sky_top_color = sky_top
		wrote_property = true
	if material.sky_horizon_color != sky_horizon:
		material.sky_horizon_color = sky_horizon
		wrote_property = true
	if material.ground_horizon_color != ground_horizon:
		material.ground_horizon_color = ground_horizon
		wrote_property = true
	# Standard ProceduralSkyMaterial setters do not promise one public changed
	# event spanning several fields. Dispatch one explicit consolidated event
	# while the caller/lifecycle guard is active, then verify the whole target.
	if wrote_property and is_instance_valid(material):
		material.emit_changed()
	if _resolve_material() != material:
		_restore_cached_material(material, previous)
		return {
			"accepted": false,
			"reason": &"target_chain_changed_during_apply",
		}
	if _read_renderer_values(material) != values:
		_restore_cached_material(material, previous)
		return {
			"accepted": false,
			"reason": &"renderer_state_changed_during_apply",
		}
	return {
		"accepted": true,
		"reason": &"renderer_values_applied" if wrote_property else &"unchanged",
	}


func _restore_cached_material(
		material: ProceduralSkyMaterial,
		values: Dictionary
	) -> void:
	if material == null or not is_instance_valid(material) \
			or not _renderer_values_are_bounded(values):
		return
	material.sky_top_color = values.get("sky_top_color", Color.BLACK) as Color
	material.sky_horizon_color = values.get(
		"sky_horizon_color", Color.BLACK
	) as Color
	material.ground_horizon_color = values.get(
		"ground_horizon_color", Color.BLACK
	) as Color


func _target_matches_expected() -> bool:
	var material := _resolve_material()
	if material == null:
		return false
	var expected := (
		_current_renderer_values if is_inside_tree()
		else _baseline_renderer_values
	)
	return _read_renderer_values(material) == expected


func _maximum_visibility_m() -> float:
	return float(
		(_profile_snapshot.get("optics", {}) as Dictionary).get(
			"maximum_visibility_m", 0.0
		)
	)


func _validate_direction(value: Variant, label: StringName) -> StringName:
	if not value is Vector3 or not (value as Vector3).is_finite():
		return StringName("invalid_%s_direction" % label)
	var length := (value as Vector3).length()
	if not is_finite(length) or absf(length - 1.0) > UNIT_VECTOR_TOLERANCE:
		return StringName("invalid_%s_direction" % label)
	return &""


func _renderer_values_are_bounded(values: Dictionary) -> bool:
	if values.size() != OWNED_RENDERER_PROPERTIES.size():
		return false
	for property_name: String in OWNED_RENDERER_PROPERTIES:
		if not values.get(property_name) is Color:
			return false
		var color := values.get(property_name) as Color
		if not _is_finite_range(color.r, 0.0, 1.0) \
				or not _is_finite_range(color.g, 0.0, 1.0) \
				or not _is_finite_range(color.b, 0.0, 1.0) \
				or not _is_finite_range(color.a, 0.0, 1.0):
			return false
	return true


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


static func _is_finite_range(
		value: Variant,
		minimum: float,
		maximum: float
	) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
		and float(value) >= minimum and float(value) <= maximum
