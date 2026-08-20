class_name PlanetaryAtmosphereWorldRig
extends Node3D

## Standalone, caller-driven renderer-target composition for an atmospheric body.
##
## The authored scene owns one inactive Environment/Sky chain, one cloud shell,
## one fixed non-shadow sun and four existing passive presentation adapters. A
## caller supplies validated definitions and body-local observations. This rig
## never installs a WorldEnvironment, advances time, moves/orients anything,
## streams a world, or claims cross-adapter transactionality.

signal presentation_committed(reason: StringName, snapshot: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"planetary-atmosphere-world-rig"
const RIG_SCENE_PATH := (
	"res://scenes/world/components/planetary_atmosphere_world_rig.tscn"
)
const DOCUMENTATION_PATH := "res://docs/PLANETARY_ATMOSPHERE_WORLD_RIG.md"
const CLOUD_SHADER_PATH := (
	"res://scripts/rendering/planetary_cloud_shell.gdshader"
)
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const OBSERVATION_FRAME: StringName = &"planetary_body_local"
const AUTHORED_BODY_TO_SUN_DIRECTION := Vector3.UP
const AUTHORED_EMITTED_LIGHT_DIRECTION := Vector3.DOWN
const AUTHORED_LIGHT_TRANSFORM := Transform3D(
	Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP),
	Vector3.ZERO,
)
const AUTHORED_LIGHT_COLOR := Color(1.0, 0.94, 0.82, 1.0)
const AUTHORED_LIGHT_ENERGY := 1.2
const AUTHORED_CLOUD_MESH_RECIPE := {
	"radius": 1.0,
	"height": 2.0,
	"radial_segments": 64,
	"rings": 32,
}
const OBSERVATION_KEYS := [
	"body_local_observer_m",
	"view_direction_body_local",
	"fog_path_distance_m",
	"speed_mps",
	"weather_scalar",
	"cloud_scalar",
	"caller_time_seconds",
]
const ADAPTER_ORDER := [
	&"atmosphere",
	&"sky",
	&"cloud",
	&"sun",
]
const REQUIRED_CLOUD_UNIFORMS := {
	"cloud_base_radius_m": TYPE_FLOAT,
	"cloud_top_radius_m": TYPE_FLOAT,
	"cloud_coverage_unitless": TYPE_FLOAT,
	"cloud_observer_layer_factor_unitless": TYPE_FLOAT,
	"cloud_wind_velocity_mps": TYPE_VECTOR3,
	"cloud_wind_offset_m": TYPE_VECTOR3,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
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
	"world_environment_installation": false,
	"production_world_wiring": false,
	"concrete_world_definition": false,
	"terrain_geometry": false,
	"terrain_height_generation": false,
	"cloud_volume": false,
	"cloud_texture_or_noise_asset": false,
	"physical_multiple_scattering": false,
	"cloud_shadows": false,
	"sun_orientation": false,
	"sun_ephemeris": false,
	"time_accumulation": false,
	"weather_selection": false,
	"camera": false,
	"entry_heat": false,
	"origin_application": false,
	"movement": false,
	"collision": false,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
}
const CAPABILITIES := {
	"scene_local_environment_sky_chain": true,
	"exclusive_mutable_renderer_resources": true,
	"shared_immutable_cloud_mesh_and_shader": true,
	"single_cloud_shell_target": true,
	"fixed_non_shadow_sun_target": true,
	"four_passive_adapters_composed": true,
	"strict_body_local_observations": true,
	"translation_rebase_invariant_inputs": true,
	"typed_partial_failure_reporting": true,
	"exact_retry_repairs_partial_prefix": true,
	"cross_adapter_atomicity": false,
	"world_environment_installed": false,
	"production_world_wired": false,
	"clock_or_process_loop": false,
	"physical_multiple_scattering": false,
	"cloud_shadowing": false,
}
const _CLOUD_SHADER := preload(CLOUD_SHADER_PATH)

@export var scene_environment: Environment

var _scene_ready := false
var _configured := false
var _terminal_configuration_failure := false
var _coherent := true
var _generation := 0
var _revision := 0
var _successful_observation_count := 0
var _partial_failure_count := 0
var _mutation_active := false
var _signal_dispatch_active := false
var _world_id: StringName = &""
var _profile_id: StringName = &""
var _terrain_profile_id: StringName = &""
var _body_radius_m := 0.0
var _cloud_shell_radius_m := 1.0
var _world_snapshot: Dictionary = {}
var _profile_snapshot: Dictionary = {}
var _terrain_snapshot: Dictionary = {}
var _composition_snapshot: Dictionary = {}
var _adapter_generations: Dictionary = {}
var _last_observation: Dictionary = {}
var _pending_observation: Dictionary = {}
var _last_transaction: Dictionary = {}

var _environment_ref: WeakRef
var _sky_ref: WeakRef
var _sky_material_ref: WeakRef
var _cloud_mesh_ref: WeakRef
var _cloud_material_ref: WeakRef
var _cloud_shader_ref: WeakRef
var _environment_instance_id := 0
var _sky_instance_id := 0
var _sky_material_instance_id := 0
var _cloud_mesh_instance_id := 0
var _cloud_material_instance_id := 0
var _cloud_shader_instance_id := 0
var _cloud_shader_source := ""


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_capture_authored_scene_contract()


func configure(
		world: PlanetaryWorldDefinition,
		atmosphere: PlanetaryAtmosphereProfile,
		terrain: PlanetaryTerrainProfile
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _scene_ready:
		return _result(false, &"rig_not_ready")
	if _configured:
		return _result(false, &"already_configured")
	if _terminal_configuration_failure:
		return _result(false, &"terminal_configuration_failure")
	if world == null:
		return _result(false, &"missing_world_definition")
	if atmosphere == null:
		return _result(false, &"missing_atmosphere_profile")
	if terrain == null:
		return _result(false, &"missing_terrain_profile")
	var scene_errors := _scene_contract_errors(false)
	if not scene_errors.is_empty():
		return _result(false, &"authored_scene_contract_invalid", {
			"scene_errors": scene_errors,
		})
	var composition := PlanetaryWorldCompositionValidator.new().validate_composition(
		world, atmosphere, terrain
	)
	if not bool(composition.get("valid", false)) or not world.has_atmosphere:
		return _result(false, &"invalid_atmospheric_composition", {
			"composition": composition,
		})
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")

	_mutation_active = true
	var receipts := {}
	var configured_prefix := PackedStringArray()
	var failure_id: StringName = &""
	var failure_scene_errors := PackedStringArray()
	var failure_composition: Dictionary = {}
	var unattempted := PackedStringArray()
	var atmosphere_adapter := get_atmosphere_presentation()
	var sky_adapter := get_sky_presentation()
	var cloud_adapter := get_cloud_presentation()
	var sun_adapter := get_sun_presentation()
	var environment := get_scene_environment()
	var cloud_material := get_cloud_material()
	var light := get_sun_light()
	var configure_calls := {
		&"atmosphere": func() -> Dictionary:
			return atmosphere_adapter.configure(atmosphere, environment),
		&"sky": func() -> Dictionary:
			return sky_adapter.configure(atmosphere, environment),
		&"cloud": func() -> Dictionary:
			return cloud_adapter.configure(atmosphere, cloud_material),
		&"sun": func() -> Dictionary:
			return sun_adapter.configure(
				world,
				atmosphere,
				light,
				AUTHORED_LIGHT_ENERGY,
				AUTHORED_LIGHT_COLOR,
			),
	}
	for adapter_index: int in ADAPTER_ORDER.size():
		var adapter_id: StringName = ADAPTER_ORDER[adapter_index]
		var receipt := (configure_calls[adapter_id] as Callable).call() as Dictionary
		receipts[adapter_id] = receipt.duplicate(true)
		if not bool(receipt.get("accepted", false)):
			failure_id = adapter_id
			unattempted = _adapter_suffix(adapter_index + 1)
			break
		configured_prefix.append(adapter_id)
		var postflight := _configuration_postflight(
			world, atmosphere, terrain, false
		)
		failure_scene_errors = postflight.get("errors", PackedStringArray()) \
			as PackedStringArray
		failure_composition = postflight.get("composition", {}) as Dictionary
		if not failure_scene_errors.is_empty():
			failure_id = &"rig_postflight"
			unattempted = _adapter_suffix(adapter_index + 1)
			break
	if not failure_id.is_empty():
		_terminal_configuration_failure = true
		_coherent = false
		var failure := _configuration_failure_result(
			failure_id,
			configured_prefix,
			unattempted,
			receipts,
			failure_scene_errors,
			failure_composition,
		)
		_last_transaction = failure.duplicate(true)
		_mutation_active = false
		return failure

	_world_id = world.world_id
	_profile_id = atmosphere.profile_id
	_terrain_profile_id = terrain.profile_id
	_body_radius_m = world.get_body_radius_meters()
	var weather := atmosphere.get_weather_snapshot()
	_cloud_shell_radius_m = _body_radius_m + float(
		weather.get("cloud_top_altitude_m", 0.0)
	)
	get_cloud_shell().scale = Vector3.ONE * _cloud_shell_radius_m
	_world_snapshot = world.audit().duplicate(true)
	_profile_snapshot = atmosphere.audit().duplicate(true)
	_terrain_snapshot = terrain.audit().duplicate(true)
	_composition_snapshot = composition.duplicate(true)
	_adapter_generations = {
		"atmosphere": atmosphere_adapter.get_generation(),
		"sky": sky_adapter.get_generation(),
		"cloud": cloud_adapter.get_generation(),
		"sun": sun_adapter.get_generation(),
	}
	_generation += 1
	_revision += 1
	_configured = true
	_coherent = true
	var configured_result := _result(true, &"configured", {
		"adapter_receipts": receipts,
		"composition": _composition_snapshot,
	})
	_last_transaction = configured_result.duplicate(true)
	_mutation_active = false
	return configured_result


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
	var decoded := _decode_observation(observation)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_observation")))
	var canonical := decoded.get("observation", {}) as Dictionary
	if not _pending_observation.is_empty() and canonical != _pending_observation:
		return _result(false, &"pending_observation_mismatch", {
			"pending_observation": _pending_observation,
		})
	var scene_errors := _scene_contract_errors(true)
	if not scene_errors.is_empty():
		return _result(false, &"authored_scene_contract_invalid", {
			"scene_errors": scene_errors,
		})

	_mutation_active = true
	var altitude := float(canonical.get("altitude_m", 0.0))
	var observer := canonical.get("body_local_observer_m", Vector3.ZERO) as Vector3
	var view := canonical.get("view_direction_body_local", Vector3.FORWARD) as Vector3
	var path_distance := float(canonical.get("fog_path_distance_m", 0.0))
	var speed := float(canonical.get("speed_mps", 0.0))
	var weather_scalar := float(canonical.get("weather_scalar", 0.0))
	var cloud_scalar := float(canonical.get("cloud_scalar", 0.0))
	var caller_time := float(canonical.get("caller_time_seconds", 0.0))
	var surface_up := observer.normalized()
	var body_to_sun := _authenticated_body_to_sun_direction()
	if body_to_sun == Vector3.ZERO:
		return _result(false, &"authored_scene_contract_invalid", {
			"scene_errors": PackedStringArray(["authored_sun_contract_drift"]),
		})
	var calls := {
		&"atmosphere": func() -> Dictionary:
			return get_atmosphere_presentation().present_observation(
				altitude,
				path_distance,
				speed,
				weather_scalar,
				cloud_scalar,
				int(_adapter_generations.atmosphere),
			),
		&"sky": func() -> Dictionary:
			return get_sky_presentation().present_observation(
				altitude,
				view,
				surface_up,
				body_to_sun,
				int(_adapter_generations.sky),
			),
		&"cloud": func() -> Dictionary:
			return get_cloud_presentation().present_observation(
				altitude,
				caller_time,
				weather_scalar,
				cloud_scalar,
				int(_adapter_generations.cloud),
			),
		&"sun": func() -> Dictionary:
			return get_sun_presentation().present_observation({
				"body_local_observer_m": observer,
				"normalized_body_to_sun": body_to_sun,
			}, int(_adapter_generations.sun)),
	}
	var receipts := {}
	var accepted_prefix := PackedStringArray()
	var committed_prefix := PackedStringArray()
	var failure_id: StringName = &""
	var failure_scene_errors := PackedStringArray()
	var unattempted := PackedStringArray()
	for adapter_index: int in ADAPTER_ORDER.size():
		var adapter_id: StringName = ADAPTER_ORDER[adapter_index]
		var receipt := (calls[adapter_id] as Callable).call() as Dictionary
		receipts[adapter_id] = receipt.duplicate(true)
		if not bool(receipt.get("accepted", false)):
			failure_id = adapter_id
			unattempted = _adapter_suffix(adapter_index + 1)
			break
		accepted_prefix.append(adapter_id)
		if receipt.get("reason", &"") != &"unchanged":
			committed_prefix.append(adapter_id)
		failure_scene_errors = _scene_contract_errors(true)
		if not failure_scene_errors.is_empty():
			failure_id = &"rig_postflight"
			unattempted = _adapter_suffix(adapter_index + 1)
			break
	if not failure_id.is_empty():
		_partial_failure_count += 1
		_pending_observation = canonical.duplicate(true)
		_coherent = false
		var partial := _partial_failure_result(
			failure_id,
			accepted_prefix,
			committed_prefix,
			unattempted,
			receipts,
			canonical,
			failure_scene_errors,
		)
		_last_transaction = partial.duplicate(true)
		_mutation_active = false
		return partial

	var unchanged := canonical == _last_observation \
		and committed_prefix.is_empty() and _pending_observation.is_empty()
	_last_observation = canonical.duplicate(true)
	_pending_observation.clear()
	_coherent = true
	if not unchanged:
		_successful_observation_count += 1
		_revision += 1
	var reason: StringName = &"unchanged" if unchanged else &"observation_presented"
	var success := _result(true, reason, {
		"adapter_receipts": receipts,
		"accepted_adapter_ids": accepted_prefix,
		"committed_adapter_ids": committed_prefix,
		"observation": canonical,
	})
	_mutation_active = false
	if unchanged:
		return success
	_last_transaction = success.duplicate(true)
	_signal_dispatch_active = true
	presentation_committed.emit(reason, get_snapshot())
	_signal_dispatch_active = false
	return success


func get_generation() -> int:
	return _generation


func get_scene_environment() -> Environment:
	return scene_environment


func get_cloud_shell() -> MeshInstance3D:
	return get_node_or_null("CloudShell") as MeshInstance3D


func get_sun_light() -> DirectionalLight3D:
	return get_node_or_null("SunLight") as DirectionalLight3D


func get_atmosphere_presentation() -> PlanetaryAtmospherePresentation:
	return get_node_or_null("AtmospherePresentation") \
		as PlanetaryAtmospherePresentation


func get_sky_presentation() -> PlanetarySkyPresentation:
	return get_node_or_null("SkyPresentation") as PlanetarySkyPresentation


func get_cloud_presentation() -> PlanetaryCloudPresentation:
	return get_node_or_null("CloudPresentation") as PlanetaryCloudPresentation


func get_sun_presentation() -> PlanetarySunPresentation:
	return get_node_or_null("SunPresentation") as PlanetarySunPresentation


func get_cloud_material() -> ShaderMaterial:
	var shell := get_cloud_shell()
	return (
		shell.material_override as ShaderMaterial if shell != null else null
	)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"configured": _configured,
		"terminal_configuration_failure": _terminal_configuration_failure,
		"coherent": _coherent,
		"generation": _generation,
		"revision": _revision,
		"successful_observation_count": _successful_observation_count,
		"partial_failure_count": _partial_failure_count,
		"identity": {
			"world_id": _world_id,
			"atmosphere_profile_id": _profile_id,
			"terrain_profile_id": _terrain_profile_id,
		},
		"body_radius_m": _body_radius_m,
		"cloud_shell_radius_m": _cloud_shell_radius_m,
		"observation_frame": OBSERVATION_FRAME,
		"authored_body_to_sun_direction": AUTHORED_BODY_TO_SUN_DIRECTION,
		"adapter_generations": _adapter_generations.duplicate(true),
		"last_observation": _last_observation.duplicate(true),
		"pending_observation": _pending_observation.duplicate(true),
		"last_transaction": _last_transaction.duplicate(true),
		"world": _world_snapshot.duplicate(true),
		"atmosphere": _profile_snapshot.duplicate(true),
		"terrain": _terrain_snapshot.duplicate(true),
		"composition": _composition_snapshot.duplicate(true),
		"targets": _target_snapshot(),
		"evidence": EVIDENCE.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := _scene_contract_errors(_configured)
	if not _configured:
		errors.append(
			"terminal_configuration_failure"
			if _terminal_configuration_failure else "rig_not_configured"
		)
	else:
		if _world_id.is_empty() or _profile_id.is_empty() \
				or _terrain_profile_id.is_empty():
			errors.append("source_identity_drift")
		if not bool(_composition_snapshot.get("valid", false)):
			errors.append("composition_snapshot_invalid")
		if _generation <= 0 or _generation > MAX_SAFE_GENERATION:
			errors.append("generation_out_of_bounds")
		if _revision <= 0:
			errors.append("revision_out_of_bounds")
		if not _coherent or not _pending_observation.is_empty():
			errors.append("partial_presentation_pending")
		_validate_adapter_audit(
			errors, &"atmosphere", get_atmosphere_presentation()
		)
		_validate_adapter_audit(errors, &"sky", get_sky_presentation())
		_validate_adapter_audit(errors, &"cloud", get_cloud_presentation())
		_validate_adapter_audit(errors, &"sun", get_sun_presentation())
	errors.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"topology": {
			"total_node_count": _count_nodes(self),
			"direct_child_count": get_child_count(),
			"expected_total_node_count": 7,
			"expected_direct_child_count": 6,
			"world_environment_node_count": find_children(
				"*", "WorldEnvironment", true, false
			).size(),
			"mesh_instance_count": find_children(
				"*", "MeshInstance3D", true, false
			).size(),
			"light_count": find_children("*", "Light3D", true, false).size(),
			"collision_object_count": find_children(
				"*", "CollisionObject3D", true, false
			).size(),
		},
		"resource_policy": {
			"exclusive_mutable_resources": PackedStringArray([
				"Environment",
				"Sky",
				"ProceduralSkyMaterial",
				"CloudShaderMaterial",
			]),
			"shared_immutable_resources": PackedStringArray([
				"CloudSphereMesh",
				"PlanetaryCloudShellShader",
			]),
		},
		"adapter_order": ADAPTER_ORDER.duplicate(),
		"cross_adapter_atomicity": false,
		"partial_failure_policy": &"accepted_prefix_then_exact_retry",
		"capabilities": CAPABILITIES.duplicate(true),
		"performance": {
			"mesh_instance_count": 1,
			"mesh_surface_count": (
				get_cloud_shell().mesh.get_surface_count()
				if get_cloud_shell() != null and get_cloud_shell().mesh != null else 0
			),
			"directional_light_count": 1,
			"shadow_casting_light_count": 0,
			"collision_object_count": 0,
			"process_loop_count": 0,
		},
		"evidence": EVIDENCE.duplicate(true),
		"source_evidence": (
			_composition_snapshot.get("evidence", {}).duplicate(true)
			if _composition_snapshot.get("evidence", {}) is Dictionary else {}
		),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _capture_authored_scene_contract() -> void:
	var environment := scene_environment
	var sky := environment.sky if environment != null else null
	var sky_material := sky.sky_material if sky != null else null
	var shell := get_cloud_shell()
	var mesh := shell.mesh if shell != null else null
	var cloud_material := get_cloud_material()
	var cloud_shader := cloud_material.shader if cloud_material != null else null
	_environment_ref = weakref(environment) if environment != null else null
	_sky_ref = weakref(sky) if sky != null else null
	_sky_material_ref = weakref(sky_material) if sky_material != null else null
	_cloud_mesh_ref = weakref(mesh) if mesh != null else null
	_cloud_material_ref = weakref(cloud_material) if cloud_material != null else null
	_cloud_shader_ref = weakref(cloud_shader) if cloud_shader != null else null
	_environment_instance_id = environment.get_instance_id() if environment != null else 0
	_sky_instance_id = sky.get_instance_id() if sky != null else 0
	_sky_material_instance_id = (
		sky_material.get_instance_id() if sky_material != null else 0
	)
	_cloud_mesh_instance_id = mesh.get_instance_id() if mesh != null else 0
	_cloud_material_instance_id = (
		cloud_material.get_instance_id() if cloud_material != null else 0
	)
	_cloud_shader_instance_id = (
		cloud_shader.get_instance_id() if cloud_shader != null else 0
	)
	_cloud_shader_source = cloud_shader.code if cloud_shader is Shader else ""
	_scene_ready = true


func _scene_contract_errors(configured_scale: bool) -> PackedStringArray:
	var errors := PackedStringArray()
	if scene_file_path != RIG_SCENE_PATH:
		errors.append("rig_scene_identity_drift")
	if get_child_count() != 6 or _count_nodes(self) != 7:
		errors.append("seven_node_topology_drift")
	var shell := get_cloud_shell()
	var light := get_sun_light()
	var atmosphere_adapter := get_atmosphere_presentation()
	var sky_adapter := get_sky_presentation()
	var cloud_adapter := get_cloud_presentation()
	var sun_adapter := get_sun_presentation()
	if shell == null or light == null or atmosphere_adapter == null \
			or sky_adapter == null or cloud_adapter == null or sun_adapter == null:
		errors.append("required_direct_child_missing")
	else:
		for child: Node in [
			shell, light, atmosphere_adapter, sky_adapter, cloud_adapter, sun_adapter,
		]:
			if child.get_parent() != self:
				errors.append("required_child_reparented")
				break
	if not find_children("*", "WorldEnvironment", true, false).is_empty():
		errors.append("world_environment_node_added")
	if not find_children("*", "CollisionObject3D", true, false).is_empty():
		errors.append("collision_authority_added")
	if has_method("_process") or has_method("_physics_process") \
			or is_processing() or is_physics_processing():
		errors.append("process_authority_added")
	if not _translation_only_ancestor_frame_is_exact():
		errors.append("body_local_ancestor_basis_drift")
	if shell == null or shell.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or shell.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			or shell.position != Vector3.ZERO or shell.rotation != Vector3.ZERO:
		errors.append("cloud_shell_node_contract_drift")
	elif shell.scale != Vector3.ONE * (
		_cloud_shell_radius_m if configured_scale else 1.0
	):
		errors.append("cloud_shell_scale_drift")
	elif shell.global_transform.basis != Basis.IDENTITY.scaled(shell.scale):
		errors.append("cloud_shell_global_radius_drift")
	if light == null or light.transform != AUTHORED_LIGHT_TRANSFORM \
			or light.shadow_enabled \
			or light.global_transform.basis != AUTHORED_LIGHT_TRANSFORM.basis \
			or (-light.global_transform.basis.z).normalized() \
			!= AUTHORED_EMITTED_LIGHT_DIRECTION:
		errors.append("authored_sun_contract_drift")
	if not _resource_contract_is_valid():
		errors.append("renderer_resource_contract_drift")
	return errors


func _resource_contract_is_valid() -> bool:
	var environment := scene_environment
	if not _matches_frozen_resource(
		environment, _environment_ref, _environment_instance_id
	) or not environment.resource_local_to_scene \
			or environment.background_mode != Environment.BG_SKY \
			or not environment.fog_enabled:
		return false
	var sky := environment.sky
	if not _matches_frozen_resource(sky, _sky_ref, _sky_instance_id) \
			or not sky.resource_local_to_scene:
		return false
	var sky_material := sky.sky_material
	if sky_material is not ProceduralSkyMaterial \
			or not _matches_frozen_resource(
				sky_material, _sky_material_ref, _sky_material_instance_id
			) or not sky_material.resource_local_to_scene:
		return false
	var shell := get_cloud_shell()
	var mesh := shell.mesh if shell != null else null
	if mesh is not SphereMesh or not _matches_frozen_resource(
		mesh, _cloud_mesh_ref, _cloud_mesh_instance_id
	) or mesh.resource_local_to_scene or not _mesh_recipe_is_exact(mesh as SphereMesh):
		return false
	var material := get_cloud_material()
	if not _matches_frozen_resource(
		material, _cloud_material_ref, _cloud_material_instance_id
	) or not material.resource_local_to_scene:
		return false
	var shader := material.shader
	return shader is Shader and shader == _CLOUD_SHADER \
		and _matches_frozen_resource(
			shader, _cloud_shader_ref, _cloud_shader_instance_id
		) and not shader.resource_local_to_scene \
		and shader.get_mode() == Shader.MODE_SPATIAL \
		and shader.code == _cloud_shader_source \
		and _cloud_uniform_contract_is_exact(shader)


func _mesh_recipe_is_exact(mesh: SphereMesh) -> bool:
	return mesh.radius == float(AUTHORED_CLOUD_MESH_RECIPE.radius) \
		and mesh.height == float(AUTHORED_CLOUD_MESH_RECIPE.height) \
		and mesh.radial_segments == int(AUTHORED_CLOUD_MESH_RECIPE.radial_segments) \
		and mesh.rings == int(AUTHORED_CLOUD_MESH_RECIPE.rings) \
		and mesh.get_surface_count() == 1


func _cloud_uniform_contract_is_exact(shader: Shader) -> bool:
	var actual := {}
	for entry: Dictionary in shader.get_shader_uniform_list():
		actual[str(entry.get("name", ""))] = int(entry.get("type", TYPE_NIL))
	return actual == REQUIRED_CLOUD_UNIFORMS


func _decode_observation(candidate: Variant) -> Dictionary:
	if candidate is not Dictionary:
		return {"accepted": false, "reason": &"invalid_observation_schema"}
	var source := candidate as Dictionary
	if source.size() != OBSERVATION_KEYS.size():
		return {"accepted": false, "reason": &"invalid_observation_schema"}
	for key: String in OBSERVATION_KEYS:
		if not source.has(key):
			return {"accepted": false, "reason": &"invalid_observation_schema"}
	var observer: Variant = source.get("body_local_observer_m")
	var view: Variant = source.get("view_direction_body_local")
	if observer is not Vector3 or not (observer as Vector3).is_finite():
		return {"accepted": false, "reason": &"invalid_body_local_observer"}
	if view is not Vector3 or not _is_unit_vector(view as Vector3):
		return {"accepted": false, "reason": &"invalid_view_direction"}
	var observer_vector := observer as Vector3
	if absf(observer_vector.x) > PlanetaryCoordinateFrame.MAX_LOCAL_COMPONENT_METERS \
			or absf(observer_vector.y) > PlanetaryCoordinateFrame.MAX_LOCAL_COMPONENT_METERS \
			or absf(observer_vector.z) > PlanetaryCoordinateFrame.MAX_LOCAL_COMPONENT_METERS:
		return {"accepted": false, "reason": &"body_local_observer_out_of_bounds"}
	var radius := observer_vector.length()
	var altitude := radius - _body_radius_m
	if not is_finite(radius) or radius < _body_radius_m \
			or altitude > PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M:
		return {"accepted": false, "reason": &"body_local_observer_out_of_bounds"}
	if not _is_finite_range(
		source.get("fog_path_distance_m"), 0.0,
		PlanetaryAtmosphereProfile.MAX_VISIBILITY_M
	):
		return {"accepted": false, "reason": &"invalid_fog_path_distance"}
	if not _is_finite_range(
		source.get("speed_mps"), 0.0,
		PlanetaryAtmosphereProfile.MAX_ENTRY_SPEED_MPS
	):
		return {"accepted": false, "reason": &"invalid_speed"}
	if not _is_finite_range(source.get("weather_scalar"), 0.0, 1.0):
		return {"accepted": false, "reason": &"invalid_weather_scalar"}
	if not _is_finite_range(source.get("cloud_scalar"), 0.0, 1.0):
		return {"accepted": false, "reason": &"invalid_cloud_scalar"}
	if not _is_finite_number(source.get("caller_time_seconds")) \
			or float(source.get("caller_time_seconds")) < 0.0:
		return {"accepted": false, "reason": &"invalid_caller_time"}
	var weather := _profile_snapshot.get("weather", {}) as Dictionary
	var wind := weather.get("wind_velocity_mps", Vector3.ZERO) as Vector3
	var effective_wind := wind * float(source.get("weather_scalar"))
	var offset := (
		Vector3.ZERO if effective_wind == Vector3.ZERO
		else effective_wind * float(source.get("caller_time_seconds"))
	)
	if not offset.is_finite() \
			or offset.length() > PlanetaryCloudPresentation.MAX_CLOUD_WIND_OFFSET_M:
		return {"accepted": false, "reason": &"cloud_wind_offset_out_of_bounds"}
	return {
		"accepted": true,
		"reason": &"valid_observation",
		"observation": {
			"body_local_observer_m": observer_vector,
			"view_direction_body_local": (view as Vector3).normalized(),
			"fog_path_distance_m": float(source.get("fog_path_distance_m")),
			"speed_mps": float(source.get("speed_mps")),
			"weather_scalar": float(source.get("weather_scalar")),
			"cloud_scalar": float(source.get("cloud_scalar")),
			"caller_time_seconds": float(source.get("caller_time_seconds")),
			"altitude_m": altitude,
		}.duplicate(true),
	}


func _configuration_failure_result(
		failed_adapter_id: StringName,
		configured_prefix: PackedStringArray,
		unattempted_adapter_ids: PackedStringArray,
		receipts: Dictionary,
		scene_errors: PackedStringArray,
		composition: Dictionary
	) -> Dictionary:
	return _result(false, &"partial_configuration_failure", {
		"failed_adapter_id": failed_adapter_id,
		"configured_adapter_ids": configured_prefix,
		"unattempted_adapter_ids": unattempted_adapter_ids,
		"adapter_receipts": receipts,
		"scene_errors": scene_errors,
		"composition": composition.duplicate(true),
		"retry_allowed": false,
	})


func _partial_failure_result(
		failed_adapter_id: StringName,
		accepted_prefix: PackedStringArray,
		committed_prefix: PackedStringArray,
		unattempted_adapter_ids: PackedStringArray,
		receipts: Dictionary,
		observation: Dictionary,
		scene_errors: PackedStringArray
	) -> Dictionary:
	return _result(false, &"partial_presentation_failure", {
		"failed_adapter_id": failed_adapter_id,
		"accepted_adapter_ids": accepted_prefix,
		"committed_adapter_ids": committed_prefix,
		"unattempted_adapter_ids": unattempted_adapter_ids,
		"adapter_receipts": receipts,
		"scene_errors": scene_errors,
		"pending_observation": observation,
		"exact_retry_required": true,
	})


func _validate_adapter_audit(
		errors: PackedStringArray,
		adapter_id: StringName,
		adapter: Node
	) -> void:
	if adapter == null or not adapter.has_method(&"audit") \
			or not adapter.has_method(&"get_generation"):
		errors.append("%s_adapter_unavailable" % adapter_id)
		return
	var report := adapter.call(&"audit") as Dictionary
	if not bool(report.get("valid", false)):
		errors.append("%s_adapter_invalid" % adapter_id)
	if int(adapter.call(&"get_generation")) \
			!= int(_adapter_generations.get(adapter_id, -1)):
		errors.append("%s_adapter_generation_drift" % adapter_id)


func _target_snapshot() -> Dictionary:
	var shell := get_cloud_shell()
	var light := get_sun_light()
	var material := get_cloud_material()
	var shader := material.shader if material != null else null
	return {
		"environment_instance_id": _environment_instance_id,
		"sky_instance_id": _sky_instance_id,
		"sky_material_instance_id": _sky_material_instance_id,
		"cloud_mesh_instance_id": _cloud_mesh_instance_id,
		"cloud_material_instance_id": _cloud_material_instance_id,
		"cloud_shader_instance_id": _cloud_shader_instance_id,
		"environment_available": _resource_is_live(_environment_ref),
		"sky_available": _resource_is_live(_sky_ref),
		"sky_material_available": _resource_is_live(_sky_material_ref),
		"cloud_mesh_available": _resource_is_live(_cloud_mesh_ref),
		"cloud_material_available": _resource_is_live(_cloud_material_ref),
		"cloud_shader_available": _resource_is_live(_cloud_shader_ref),
		"cloud_mesh_recipe": AUTHORED_CLOUD_MESH_RECIPE.duplicate(true),
		"cloud_shader_source_sha256": (
			shader.code.sha256_text() if shader is Shader else ""
		),
		"cloud_shell_scale": shell.scale if shell != null else Vector3.ZERO,
		"sun_transform": light.transform if light != null else Transform3D.IDENTITY,
		"sun_shadow_enabled": light.shadow_enabled if light != null else true,
		"resource_local_to_scene": {
			"environment": (
				scene_environment.resource_local_to_scene
				if scene_environment != null else false
			),
			"sky": (
				scene_environment.sky.resource_local_to_scene
				if scene_environment != null and scene_environment.sky != null else false
			),
			"sky_material": (
				scene_environment.sky.sky_material.resource_local_to_scene
				if scene_environment != null and scene_environment.sky != null
				and scene_environment.sky.sky_material != null else false
			),
			"cloud_material": (
				material.resource_local_to_scene if material != null else false
			),
			"cloud_mesh": (
				shell.mesh.resource_local_to_scene
				if shell != null and shell.mesh != null else true
			),
			"cloud_shader": (
				shader.resource_local_to_scene if shader != null else true
			),
		},
	}.duplicate(true)


func _translation_only_ancestor_frame_is_exact() -> bool:
	var cursor: Node = self
	while cursor != null:
		if cursor is Node3D and (cursor as Node3D).transform.basis != Basis.IDENTITY:
			return false
		cursor = cursor.get_parent()
	return global_transform.basis == Basis.IDENTITY


func _configuration_postflight(
		world: PlanetaryWorldDefinition,
		atmosphere: PlanetaryAtmosphereProfile,
		terrain: PlanetaryTerrainProfile,
		configured_scale: bool
	) -> Dictionary:
	var errors := _scene_contract_errors(configured_scale)
	var composition := PlanetaryWorldCompositionValidator.new().validate_composition(
		world, atmosphere, terrain
	)
	if not bool(composition.get("valid", false)) or not world.has_atmosphere:
		errors.append("composition_input_drift")
	errors.sort()
	return {
		"errors": errors,
		"composition": composition.duplicate(true),
	}.duplicate(true)


func _authenticated_body_to_sun_direction() -> Vector3:
	var light := get_sun_light()
	if light == null or light.global_transform.basis != AUTHORED_LIGHT_TRANSFORM.basis:
		return Vector3.ZERO
	var emitted_direction := (-light.global_transform.basis.z).normalized()
	if not _is_unit_vector(emitted_direction) \
			or emitted_direction != AUTHORED_EMITTED_LIGHT_DIRECTION:
		return Vector3.ZERO
	var body_to_sun := -emitted_direction
	return body_to_sun if body_to_sun == AUTHORED_BODY_TO_SUN_DIRECTION else Vector3.ZERO


func _adapter_suffix(start_index: int) -> PackedStringArray:
	var suffix := PackedStringArray()
	for index: int in range(start_index, ADAPTER_ORDER.size()):
		suffix.append(ADAPTER_ORDER[index])
	return suffix


func _is_reentrant() -> bool:
	return _mutation_active or _signal_dispatch_active


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
		"coherent": _coherent,
	}
	for key: Variant in details:
		result[key] = details[key]
	return result.duplicate(true)


static func _matches_frozen_resource(
		resource: Resource,
		resource_ref: WeakRef,
		instance_id: int
	) -> bool:
	if resource == null or not is_instance_valid(resource) or resource_ref == null:
		return false
	var frozen := resource_ref.get_ref() as Resource
	return frozen != null and frozen == resource \
		and resource.get_instance_id() == instance_id


static func _resource_is_live(resource_ref: WeakRef) -> bool:
	return resource_ref != null and resource_ref.get_ref() != null


static func _count_nodes(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count


static func _is_exact_integer(value: Variant) -> bool:
	return value is int and int(value) >= 0 and int(value) <= MAX_SAFE_GENERATION


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_finite_range(
		value: Variant,
		minimum: float,
		maximum: float
	) -> bool:
	return _is_finite_number(value) and float(value) >= minimum \
		and float(value) <= maximum


static func _is_unit_vector(value: Vector3) -> bool:
	if not value.is_finite():
		return false
	var length := value.length()
	return is_finite(length) and absf(length - 1.0) \
		<= PlanetarySkyPresentation.UNIT_VECTOR_TOLERANCE
