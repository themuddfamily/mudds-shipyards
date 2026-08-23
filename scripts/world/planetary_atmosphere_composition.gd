class_name PlanetaryAtmosphereComposition
extends Node3D

## Explicit standalone owner that installs one configured rig Environment into
## its sibling WorldEnvironment. It owns no clock, camera, streaming, gameplay,
## or production-world binding.

const COMPONENT_ID: StringName = &"planetary-atmosphere-composition"
const SCENE_PATH := "res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn"

@export var world_definition: PlanetaryWorldDefinition
@export var atmosphere_profile: PlanetaryAtmosphereProfile
@export var terrain_profile: PlanetaryTerrainProfile

var _configured := false
var _generation := 0
var _baseline_environment: Environment
var _baseline_sun_energy := 1.0
var _baseline_sun_color := Color.WHITE
var _baseline_ambient_energy := 1.0
var _baseline_cloud_transparency := 0.0
var _baseline_fog_enabled := false
var _baseline_fog_density := 0.0
var _baseline_fog_sky_affect := 0.0
var _baseline_background_energy := 1.0
var _last_recipe: Dictionary = {}
var _cloud_shadow_projection: MeshInstance3D


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	var target := get_world_environment()
	_baseline_environment = target.environment if target != null else null
	var rig := get_atmosphere_rig()
	if rig != null:
		var sun := rig.get_sun_light()
		var cloud := rig.get_cloud_shell()
		if sun != null:
			_baseline_sun_energy = sun.light_energy
			_baseline_sun_color = sun.light_color
		if target != null and target.environment != null:
			_baseline_ambient_energy = target.environment.ambient_light_energy
			_baseline_fog_enabled = target.environment.fog_enabled
			_baseline_fog_density = target.environment.fog_density
			_baseline_fog_sky_affect = target.environment.fog_sky_affect
			_baseline_background_energy = target.environment.background_energy_multiplier
		if cloud != null:
			_baseline_cloud_transparency = cloud.transparency
	_cloud_shadow_projection = MeshInstance3D.new()
	_cloud_shadow_projection.name = "OwnedCloudShadowProjection"
	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(64.0, 64.0)
	_cloud_shadow_projection.mesh = shadow_mesh
	_cloud_shadow_projection.rotation_degrees.x = -90.0
	var shadow_material := ShaderMaterial.new()
	var shadow_shader := Shader.new()
	shadow_shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, blend_mix; uniform float shadow_opacity; uniform vec3 wind_offset; void fragment(){ ALBEDO = vec3(0.015, 0.02, 0.025); ALPHA = shadow_opacity; }"
	shadow_material.shader = shadow_shader
	_cloud_shadow_projection.material_override = shadow_material
	_cloud_shadow_projection.visible = false
	add_child(_cloud_shadow_projection)


func _exit_tree() -> void:
	if _configured:
		var target := get_world_environment()
		if target != null:
			target.environment = _baseline_environment
		var rig := get_atmosphere_rig()
		if rig != null:
			var sun := rig.get_sun_light()
			var cloud := rig.get_cloud_shell()
			if sun != null:
				sun.light_energy = _baseline_sun_energy
				sun.light_color = _baseline_sun_color
			if target != null and target.environment != null:
				target.environment.ambient_light_energy = _baseline_ambient_energy
				target.environment.fog_enabled = _baseline_fog_enabled
				target.environment.fog_density = _baseline_fog_density
				target.environment.fog_sky_affect = _baseline_fog_sky_affect
				target.environment.background_energy_multiplier = _baseline_background_energy
			if cloud != null:
				cloud.transparency = _baseline_cloud_transparency
		if _cloud_shadow_projection != null:
			_cloud_shadow_projection.visible = false


func _enter_tree() -> void:
	if _configured:
		var target := get_world_environment()
		var rig := get_atmosphere_rig()
		if target != null and rig != null:
			target.environment = rig.get_scene_environment()
		if not _last_recipe.is_empty():
			apply_retained_presentation_recipe(
				_last_recipe.solar, _last_recipe.weather
			)


func configure() -> Dictionary:
	if _configured:
		return {"accepted": false, "reason": &"already_configured"}
	var target := get_world_environment()
	var rig := get_atmosphere_rig()
	if target == null or rig == null:
		return {"accepted": false, "reason": &"authored_scene_contract_invalid"}
	if world_definition == null or atmosphere_profile == null or terrain_profile == null:
		return {"accepted": false, "reason": &"missing_composition_resource"}
	var result := rig.configure(world_definition, atmosphere_profile, terrain_profile)
	if not bool(result.get("accepted", false)):
		return result.duplicate(true)
	_baseline_environment = target.environment
	target.environment = rig.get_scene_environment()
	_configured = true
	_generation = rig.get_generation()
	return {"accepted": true, "reason": &"configured", "generation": _generation}.duplicate(true)


func present_observation(observation: Dictionary, expected_generation: int) -> Dictionary:
	if not _configured:
		return {"accepted": false, "reason": &"not_configured"}
	if is_queued_for_deletion() or not is_inside_tree():
		return {"accepted": false, "reason": &"composition_detached"}
	return get_atmosphere_rig().present_observation(observation, expected_generation)


func apply_retained_presentation_recipe(
		solar_snapshot: Variant, weather_snapshot: Variant
	) -> Dictionary:
	if not _configured or not is_inside_tree():
		return {"accepted": false, "reason": &"composition_detached"}
	var rig := get_atmosphere_rig()
	if rig == null:
		return {"accepted": false, "reason": &"rig_unavailable"}
	var solar := rig.get_sky_presentation().present_solar_phase_snapshot(solar_snapshot)
	if not bool(solar.get("accepted", false)):
		return solar
	var weather := rig.get_sky_presentation().present_weather_exposure_snapshot(weather_snapshot)
	if not bool(weather.get("accepted", false)):
		return weather
	var sun := rig.get_sun_light()
	var cloud := rig.get_cloud_shell()
	var target := get_world_environment()
	if sun == null or cloud == null or target == null or target.environment == null:
		return {"accepted": false, "reason": &"presentation_target_unavailable"}
	sun.light_energy = clampf(float(solar.get("sun_energy_unitless", 0.0)) * 1.2 + 0.1, 0.1, 1.3)
	sun.light_color = solar.get("sun_color", _baseline_sun_color) as Color
	target.environment.ambient_light_energy = clampf(float(solar.get("sky_exposure_unitless", 0.16)), 0.16, 1.0)
	var altitude_m := float(weather_snapshot.get("altitude_m", 0.0)) if weather_snapshot is Dictionary else 0.0
	var aerial := clampf(altitude_m / 20000.0, 0.0, 1.0) if is_finite(altitude_m) else 0.0
	target.environment.fog_enabled = _baseline_fog_enabled or aerial < 0.95
	target.environment.fog_density = clampf(_baseline_fog_density * (1.0 - aerial * 0.85), 0.0, 0.2)
	target.environment.fog_sky_affect = clampf(_baseline_fog_sky_affect * (1.0 - aerial) + aerial * 0.15, 0.0, 1.0)
	target.environment.background_energy_multiplier = clampf(
		_baseline_background_energy * (0.8 + aerial * 0.2), 0.0, 2.0
	)
	cloud.transparency = clampf(1.0 - float(weather.get("cloud_opacity_unitless", 0.0)), 0.0, 1.0)
	var shadow_material := _cloud_shadow_projection.material_override as ShaderMaterial
	if shadow_material != null:
		var shadow_opacity := clampf(float(weather.get("cloud_opacity_unitless", 0.0)) * 0.35, 0.0, 0.35)
		shadow_material.set_shader_parameter("shadow_opacity", shadow_opacity)
		shadow_material.set_shader_parameter("wind_offset", weather.get("wind_velocity_mps", Vector3.ZERO))
		_cloud_shadow_projection.visible = shadow_opacity > 0.01
	var retained_weather := (weather_snapshot as Dictionary).duplicate(true)
	retained_weather["altitude_m"] = altitude_m
	_last_recipe = {
		"solar": (solar_snapshot as Dictionary).duplicate(true),
		"weather": retained_weather,
		"aerial_factor_unitless": aerial,
	}.duplicate(true)
	return {"accepted": true, "reason": &"presentation_recipe_applied", "solar": solar, "weather": weather, "aerial_factor_unitless": aerial}.duplicate(true)


func get_presentation_snapshot() -> Dictionary:
	var rig := get_atmosphere_rig()
	var target := get_world_environment()
	var sun := rig.get_sun_light() if rig != null else null
	var cloud := rig.get_cloud_shell() if rig != null else null
	var shadow := get_node_or_null(^"OwnedCloudShadowProjection") as MeshInstance3D
	return {
		"configured": _configured,
		"sun_energy": sun.light_energy if sun != null else 0.0,
		"sun_color": sun.light_color if sun != null else Color.BLACK,
		"ambient_energy": target.environment.ambient_light_energy if target != null and target.environment != null else 0.0,
		"cloud_transparency": cloud.transparency if cloud != null else 1.0,
		"cloud_shadow_visible": shadow.visible if shadow != null else false,
		"fog_enabled": target.environment.fog_enabled if target != null and target.environment != null else false,
		"fog_density": target.environment.fog_density if target != null and target.environment != null else 0.0,
		"fog_sky_affect": target.environment.fog_sky_affect if target != null and target.environment != null else 0.0,
		"background_energy_multiplier": target.environment.background_energy_multiplier if target != null and target.environment != null else 0.0,
		"recipe": _last_recipe.duplicate(true),
	}.duplicate(true)


func get_world_environment() -> WorldEnvironment:
	return get_node_or_null("WorldEnvironment") as WorldEnvironment


func get_atmosphere_rig() -> PlanetaryAtmosphereWorldRig:
	return get_node_or_null("PlanetaryAtmosphereWorldRig") as PlanetaryAtmosphereWorldRig


func audit() -> Dictionary:
	var target := get_world_environment()
	var rig := get_atmosphere_rig()
	var errors := PackedStringArray()
	if scene_file_path != SCENE_PATH or target == null or rig == null:
		errors.append("authored_scene_contract_invalid")
	if is_processing() or is_physics_processing():
		errors.append("process_authority_added")
	if _configured and (
		target == null
		or rig == null
		or target.environment != (
			rig.get_scene_environment() if is_inside_tree() else _baseline_environment
		)
		or _generation != rig.get_generation()
	):
		errors.append("installed_environment_drift")
	return {
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"configured": _configured,
		"generation": _generation,
		"authority": {
			"renderer": true, "gameplay": false, "streaming": false,
			"save": false, "network": false, "physics": false,
			"world_generation": false, "terrain_generation": false,
			"collision_generation": false, "origin_shift": false,
			"weather_clock": false, "audio": false,
		},
	}.duplicate(true)
