class_name PlanetarySurfaceLandmarkBeaconPresentation
extends Node3D

## Presentation-only authored landmark beacon. It owns one mesh/material target
## and consumes caller-owned solar/weather values; it owns no navigation,
## activity, movement, clock, or landmark discovery authority.

const BEACON_RADIUS_M := 0.8
const BEACON_HEIGHT_M := 1.6

static var _shared_beacon_mesh: SphereMesh

var _configured := false
var _landmark_id: StringName = &""
var _anchor := Vector3.ZERO
var _profile: StringName = &"high"
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _last_recipe: Dictionary = {}

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_mesh = MeshInstance3D.new()
	_mesh.name = "OwnedLandmarkBeacon"
	_mesh.mesh = _get_shared_beacon_mesh()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled = true
	_mesh.material_override = _material
	add_child(_mesh)

static func _get_shared_beacon_mesh() -> SphereMesh:
	if _shared_beacon_mesh == null:
		_shared_beacon_mesh = SphereMesh.new()
		_shared_beacon_mesh.radius = BEACON_RADIUS_M
		_shared_beacon_mesh.height = BEACON_HEIGHT_M
	return _shared_beacon_mesh

func configure(landmark_id: StringName, anchor: Vector3) -> Dictionary:
	if _configured or landmark_id.is_empty() or not anchor.is_finite():
		return {"accepted": false, "reason": &"invalid_beacon_configuration"}
	_landmark_id = landmark_id
	_anchor = anchor
	position = anchor
	_configured = true
	return {"accepted": true, "reason": &"configured"}

func apply_presentation_recipe(solar: Variant, weather: Variant) -> Dictionary:
	if not _configured or _material == null or not solar is Dictionary or not weather is Dictionary:
		return {"accepted": false, "reason": &"invalid_beacon_recipe"}
	var elevation: Variant = (solar as Dictionary).get("sun_elevation_sine", NAN)
	var opacity: Variant = (weather as Dictionary).get("cloud_opacity_unitless", 0.0)
	if not (elevation is float or elevation is int) or not (opacity is float or opacity is int):
		return {"accepted": false, "reason": &"invalid_beacon_recipe"}
	var night := clampf(-float(elevation), 0.0, 1.0)
	var cloud := clampf(float(opacity), 0.0, 1.0)
	var intensity := clampf(0.35 + night * 0.75 - cloud * 0.15, 0.15, 1.1)
	if _profile == &"low":
		intensity = minf(intensity, 0.45)
	_material.emission = Color(0.15, 0.45, 1.0, 1.0)
	_material.emission_energy_multiplier = intensity
	_mesh.visible = intensity > 0.01
	_last_recipe = {"solar": (solar as Dictionary).duplicate(true), "weather": (weather as Dictionary).duplicate(true), "intensity_unitless": intensity}.duplicate(true)
	return {"accepted": true, "reason": &"beacon_recipe_applied", "intensity_unitless": intensity}

func apply_graphics_profile(profile: StringName) -> Dictionary:
	if profile not in [&"low", &"medium", &"high"]:
		return {"accepted": false, "reason": &"invalid_graphics_profile"}
	_profile = profile
	if not _last_recipe.is_empty():
		apply_presentation_recipe(_last_recipe.solar, _last_recipe.weather)
	return {"accepted": true, "reason": &"graphics_profile_applied"}

func detach() -> Dictionary:
	if _mesh == null:
		return {"accepted": false, "reason": &"beacon_unavailable"}
	_mesh.visible = false
	return {"accepted": true, "reason": &"beacon_detached"}

func reenter() -> Dictionary:
	if _last_recipe.is_empty():
		return {"accepted": false, "reason": &"beacon_reentry_unavailable"}
	return apply_presentation_recipe(_last_recipe.solar, _last_recipe.weather)

func get_snapshot() -> Dictionary:
	return {"configured": _configured, "landmark_id": _landmark_id, "anchor_body_local_m": _anchor, "visible": _mesh.visible if _mesh != null else false, "recipe": _last_recipe.duplicate(true), "graphics_profile": _profile, "authority": {"navigation": false, "activity": false, "movement": false, "clock": false}}.duplicate(true)
