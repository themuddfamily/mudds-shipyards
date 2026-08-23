class_name PlanetaryWaterPresentation
extends Node3D

## Live, exclusive water presentation target. It consumes authored material
## identities and caller-owned solar/weather hints without simulating contact.

const ContractScript := preload("res://scripts/world/planetary_water_surface_material_contract.gd")

var _configured := false
var _generation := 0
var _contract: PlanetaryWaterSurfaceMaterialContract
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _last_recipe: Dictionary = {}
var _graphics_profile: StringName = &"high"


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_mesh = MeshInstance3D.new()
	_mesh.name = "OwnedWaterSurface"
	var quad := QuadMesh.new()
	quad.size = Vector2(8.0, 8.0)
	_mesh.mesh = quad
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled; uniform vec4 water_color : source_color; uniform float roughness; uniform float wave_strength; uniform vec3 wind_velocity; void fragment(){ ALBEDO = water_color.rgb; ROUGHNESS = roughness; }"
	_material.shader = shader
	_mesh.material_override = _material
	add_child(_mesh)


func configure(contract: PlanetaryWaterSurfaceMaterialContract = null) -> Dictionary:
	if _configured:
		return {"accepted": false, "reason": &"already_configured"}
	_contract = contract if contract != null else ContractScript.new()
	if not _contract.is_definition_valid():
		return {"accepted": false, "reason": &"invalid_water_contract"}
	_configured = true
	_generation += 1
	return {"accepted": true, "reason": &"configured", "generation": _generation}


func apply_presentation_recipe(solar_snapshot: Variant, weather_snapshot: Variant) -> Dictionary:
	if not _configured or _material == null:
		return {"accepted": false, "reason": &"presentation_unavailable"}
	if not solar_snapshot is Dictionary or not weather_snapshot is Dictionary:
		return {"accepted": false, "reason": &"invalid_presentation_recipe"}
	var solar := solar_snapshot as Dictionary
	var weather := weather_snapshot as Dictionary
	var energy: Variant = solar.get("sun_energy_unitless", NAN)
	var exposure: Variant = weather.get("sky_exposure_unitless", 0.5)
	var wind: Variant = weather.get("wind_velocity_mps", Vector3.ZERO)
	if not (energy is float or energy is int) or not (exposure is float or exposure is int) \
			or not wind is Vector3 or not (wind as Vector3).is_finite():
		return {"accepted": false, "reason": &"invalid_presentation_recipe"}
	var daylight := clampf(float(energy), 0.0, 1.0)
	var sky := clampf(float(exposure), 0.0, 1.0)
	var wind_value := (wind as Vector3).limit_length(1000.0)
	var water_color := Color(0.04 + daylight * 0.08, 0.14 + sky * 0.16, 0.2 + sky * 0.24, 1.0)
	_material.set_shader_parameter("water_color", water_color)
	_material.set_shader_parameter("roughness", clampf(0.72 - daylight * 0.25, 0.35, 0.85))
	var wave_strength := clampf(0.05 + wind_value.length() / 1000.0 * 0.25, 0.05, 0.3)
	if _graphics_profile == &"low":
		wave_strength *= 0.35
	_material.set_shader_parameter("wave_strength", wave_strength)
	_material.set_shader_parameter("wind_velocity", wind_value)
	_last_recipe = {"solar": solar.duplicate(true), "weather": weather.duplicate(true), "water_color": water_color}.duplicate(true)
	return {"accepted": true, "reason": &"water_presentation_applied", "recipe": _last_recipe.duplicate(true)}


func apply_graphics_profile(profile: StringName) -> Dictionary:
	if profile not in [&"low", &"high"]:
		return {"accepted": false, "reason": &"invalid_graphics_profile"}
	_graphics_profile = profile
	if not _last_recipe.is_empty():
		apply_presentation_recipe(_last_recipe.solar, _last_recipe.weather)
	return {"accepted": true, "reason": &"graphics_profile_applied", "profile": _graphics_profile}


func get_snapshot() -> Dictionary:
	return {"configured": _configured, "generation": _generation, "material_id": _contract.water_surface_material_id if _contract != null else &"", "mesh_instance_id": _mesh.get_instance_id() if _mesh != null else 0, "material_instance_id": _material.get_instance_id() if _material != null else 0, "recipe": _last_recipe.duplicate(true), "graphics_profile": _graphics_profile, "authority": {"physics": false, "movement": false, "water_simulation": false, "clock": false}}.duplicate(true)
