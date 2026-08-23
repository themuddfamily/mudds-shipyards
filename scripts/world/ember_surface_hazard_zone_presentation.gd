class_name EmberSurfaceHazardZonePresentation
extends Node3D

## Presentation-only perimeter for one authored Ember surface hazard.
## Caller observations select semantic state; this node owns no actor sampling,
## damage, movement, recovery, reward, HUD, or lifecycle authority.

var _configured := false
var _attached := false
var _hazard_id: StringName = &""
var _display_name := ""
var _anchor := Vector3.ZERO
var _radius_m := 0.0
var _state: StringName = &"clear"
var _ring: MeshInstance3D
var _beacon: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	_ring = MeshInstance3D.new()
	_ring.name = "OwnedHazardPerimeter"
	_ring.material_override = _material
	add_child(_ring)
	_beacon = MeshInstance3D.new()
	_beacon.name = "OwnedHazardBeacon"
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.18
	beacon_mesh.bottom_radius = 0.45
	beacon_mesh.height = 2.4
	_beacon.mesh = beacon_mesh
	_beacon.position = Vector3(0.0, 1.2, 0.0)
	_beacon.material_override = _material
	add_child(_beacon)
	_set_visible(false)


func configure(hazard: Variant, radius_m: float) -> Dictionary:
	if _configured or not hazard is Dictionary or not is_finite(radius_m) \
			or radius_m <= 0.0:
		return {"accepted": false, "reason": &"invalid_hazard_zone_configuration"}
	var record := hazard as Dictionary
	var hazard_id := StringName(record.get("id", &""))
	var display_name := String(record.get("display_name", ""))
	var anchor: Variant = record.get("position_body_local_m", Vector3.INF)
	if hazard_id.is_empty() or display_name.is_empty() or not anchor is Vector3 \
			or not (anchor as Vector3).is_finite():
		return {"accepted": false, "reason": &"invalid_hazard_zone_configuration"}
	_hazard_id = hazard_id
	_display_name = display_name
	_anchor = anchor as Vector3
	_radius_m = radius_m
	position = _anchor
	var perimeter := TorusMesh.new()
	perimeter.inner_radius = maxf(0.1, radius_m - 0.28)
	perimeter.outer_radius = radius_m
	_ring.mesh = perimeter
	_configured = true
	_attached = true
	_apply_state(&"clear")
	return {"accepted": true, "reason": &"hazard_zone_configured"}


func apply_status(status: Variant) -> Dictionary:
	if not _configured or not status is Dictionary:
		return {"accepted": false, "reason": &"invalid_hazard_zone_status"}
	var semantic := status as Dictionary
	if StringName(semantic.get("hazard_id", &"")) != _hazard_id:
		return {"accepted": false, "reason": &"hazard_zone_identity_mismatch"}
	var state := StringName(semantic.get("state", &""))
	if state not in [&"clear", &"warning", &"recovery_required"]:
		return {"accepted": false, "reason": &"invalid_hazard_zone_status"}
	_apply_state(state)
	return {"accepted": true, "reason": &"hazard_zone_status_applied"}


func detach() -> Dictionary:
	if not _configured or not _attached:
		return {"accepted": false, "reason": &"hazard_zone_not_attached"}
	_attached = false
	_state = &"clear"
	_set_visible(false)
	return {"accepted": true, "reason": &"hazard_zone_detached"}


func reenter() -> Dictionary:
	if not _configured or _attached:
		return {"accepted": false, "reason": &"hazard_zone_reentry_unavailable"}
	_attached = true
	_apply_state(&"clear")
	return {"accepted": true, "reason": &"hazard_zone_reentered"}


func get_snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"attached": _attached,
		"hazard_id": _hazard_id,
		"display_name": _display_name,
		"anchor_body_local_m": _anchor,
		"radius_m": _radius_m,
		"state": _state,
		"visible": _attached and _ring != null and _ring.visible,
		"authority": {
			"damage": false, "health": false, "movement": false,
			"recovery": false, "reward": false, "hud": false,
			"lifecycle": false,
		},
	}.duplicate(true)


func _apply_state(state: StringName) -> void:
	_state = state
	if _material != null:
		match state:
			&"recovery_required":
				_material.albedo_color = Color(1.0, 0.12, 0.04, 0.72)
				_material.emission = Color(1.0, 0.05, 0.01)
				_material.emission_energy_multiplier = 2.4
			&"warning":
				_material.albedo_color = Color(1.0, 0.42, 0.04, 0.58)
				_material.emission = Color(1.0, 0.24, 0.02)
				_material.emission_energy_multiplier = 1.45
			_:
				_material.albedo_color = Color(1.0, 0.62, 0.08, 0.34)
				_material.emission = Color(0.9, 0.32, 0.03)
				_material.emission_energy_multiplier = 0.65
	_set_visible(_attached)


func _set_visible(value: bool) -> void:
	if _ring != null:
		_ring.visible = value
	if _beacon != null:
		_beacon.visible = value
