class_name PlanetaryLandingApproachPresentation
extends Node3D

## Presentation-only landing approach marker. Caller-owned authored anchor and
## solar/weather inputs drive one exclusive emissive target; no landing,
## navigation, support, movement, or clock authority is owned here.

const MARKER_SIZE := Vector3(2.0, 0.25, 2.0)

static var _shared_marker_mesh: BoxMesh

var _configured := false
var _landing_id: StringName = &""
var _anchor := Vector3.ZERO
var _profile: StringName = &"high"
var _marker: MeshInstance3D
var _material: StandardMaterial3D
var _last_recipe: Dictionary = {}

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_marker = MeshInstance3D.new()
	_marker.name = "OwnedLandingApproachMarker"
	_marker.mesh = _get_shared_marker_mesh()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled = true
	_marker.material_override = _material
	add_child(_marker)


static func _get_shared_marker_mesh() -> BoxMesh:
	if _shared_marker_mesh == null:
		_shared_marker_mesh = BoxMesh.new()
		_shared_marker_mesh.size = MARKER_SIZE
		_shared_marker_mesh.resource_local_to_scene = false
	return _shared_marker_mesh

func configure(landing_id: StringName, anchor: Vector3) -> Dictionary:
	if _configured or landing_id.is_empty() or not anchor.is_finite():
		return {"accepted": false, "reason": &"invalid_landing_marker_configuration"}
	_landing_id = landing_id
	_anchor = anchor
	position = anchor
	_configured = true
	return {"accepted": true, "reason": &"configured"}

func apply_presentation_recipe(solar: Variant, weather: Variant) -> Dictionary:
	if not _configured or _material == null or not solar is Dictionary or not weather is Dictionary:
		return {"accepted": false, "reason": &"invalid_landing_marker_recipe"}
	var elevation: Variant = (solar as Dictionary).get("sun_elevation_sine", NAN)
	var shelter: Variant = (weather as Dictionary).get("shelter_scalar", 0.0)
	if not (elevation is float or elevation is int) or not (shelter is float or shelter is int):
		return {"accepted": false, "reason": &"invalid_landing_marker_recipe"}
	var night := clampf(-float(elevation), 0.0, 1.0)
	var intensity := clampf(0.3 + night * 0.8 + clampf(float(shelter), 0.0, 1.0) * 0.1, 0.15, 1.1)
	if _profile == &"low":
		intensity = minf(intensity, 0.4)
	_material.emission = Color(1.0, 0.5, 0.12, 1.0)
	_material.emission_energy_multiplier = intensity
	_marker.visible = intensity > 0.01
	_last_recipe = {"solar": (solar as Dictionary).duplicate(true), "weather": (weather as Dictionary).duplicate(true), "intensity_unitless": intensity}.duplicate(true)
	return {"accepted": true, "reason": &"landing_marker_recipe_applied", "intensity_unitless": intensity}

func apply_graphics_profile(profile: StringName) -> Dictionary:
	if profile not in [&"low", &"medium", &"high"]:
		return {"accepted": false, "reason": &"invalid_graphics_profile"}
	_profile = profile
	if not _last_recipe.is_empty():
		apply_presentation_recipe(_last_recipe.solar, _last_recipe.weather)
	return {"accepted": true, "reason": &"graphics_profile_applied"}

func detach() -> Dictionary:
	if _marker == null:
		return {"accepted": false, "reason": &"landing_marker_unavailable"}
	_marker.visible = false
	return {"accepted": true, "reason": &"landing_marker_detached"}

func reenter() -> Dictionary:
	if _last_recipe.is_empty():
		return {"accepted": false, "reason": &"landing_marker_reentry_unavailable"}
	return apply_presentation_recipe(_last_recipe.solar, _last_recipe.weather)

func get_snapshot() -> Dictionary:
	return {"configured": _configured, "landing_id": _landing_id, "anchor_body_local_m": _anchor, "visible": _marker.visible if _marker != null else false, "recipe": _last_recipe.duplicate(true), "graphics_profile": _profile, "authority": {"landing": false, "navigation": false, "movement": false, "clock": false}}.duplicate(true)
