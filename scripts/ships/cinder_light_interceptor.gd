class_name CinderLightInterceptor
extends HeroShip

## Original-modern lightweight interceptor. No historical craft, weapon, or
## combat claim is authenticated here.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder-light-interceptor"
const EVIDENCE_STATUS: StringName = &"NEW"
const DISPLAY_NAME := "Cinder light interceptor"
const HULL_SIZE := Vector3(4.8, 2.5, 8.8)
const HULL_COLOR := Color("e0a43d")
const CANOPY_COLOR := Color("55d5dc")
const WING_COLOR := Color("8b4a38")

var _interceptor_boarding_marker: Marker3D
var _interceptor_built := false


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _ready() -> void:
	ship_id = COMPONENT_ID
	display_name = DISPLAY_NAME
	role_name = "Light interceptor"
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	super._ready()
	if not _interceptor_built:
		_interceptor_built = rebuild_variant_presentation(_build_interceptor_variant)


func _build_interceptor_variant(_controller: HeroShip) -> bool:
	var visual := get_variant_visual_root()
	if visual == null:
		return false
	visual.name = "CinderInterceptorVisual"
	visual.set_meta(&"geometry_status", EVIDENCE_STATUS)
	visual.set_meta(&"historically_supported", false)
	_build_hull(visual)
	_build_boarding_marker(visual)
	return true


func get_display_name() -> String:
	return DISPLAY_NAME


func get_cockpit_seat_anchor() -> Marker3D:
	return get_pilot_seat_anchor() as Marker3D


func get_boarding_marker() -> Marker3D:
	return _interceptor_boarding_marker


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not _interceptor_built:
		errors.append("interceptor has not built its authored component tree")
	if not is_instance_valid(get_pilot_seat_anchor()) or not is_instance_valid(_interceptor_boarding_marker):
		errors.append("cockpit and boarding anchors are required")
	if not bool(get_landing_collision_report().get("valid", false)):
		errors.append("interceptor requires HeroShip root collision")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"hero_ship_derived": true,
		"flight_authority": true,
		"landing_authority": true,
		"damage_authority": true,
		"reuse_authority": true,
		"combat_authority": false,
		"weapon_authority": false,
		"berth_authority": false,
		"game_flow_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _build_collision() -> void:
	_add_box_collision_shape("InterceptorHullCollision", Vector3.ZERO, HULL_SIZE)


func _build_hull(visual: Node3D) -> void:
	var hull := MeshInstance3D.new()
	hull.name = "HighVisibilityHull"
	var mesh := BoxMesh.new()
	mesh.size = HULL_SIZE
	hull.mesh = mesh
	hull.material_override = _material(HULL_COLOR, 0.62, 0.36)
	visual.add_child(hull)
	var wing := MeshInstance3D.new()
	wing.name = "RapidResponseWing"
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(12.0, 0.45, 2.4)
	wing.mesh = wing_mesh
	wing.position = Vector3(0.0, -0.15, 0.8)
	wing.material_override = _material(WING_COLOR, 0.5, 0.36)
	visual.add_child(wing)
	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.25
	canopy_mesh.height = 1.5
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.0, 1.1, -2.1)
	canopy.material_override = _material(CANOPY_COLOR, 0.15, 0.36, CANOPY_COLOR, 2.0)
	visual.add_child(canopy)


func _build_boarding_marker(visual: Node3D) -> void:
	_interceptor_boarding_marker = Marker3D.new()
	_interceptor_boarding_marker.name = "BoardingMarker"
	_interceptor_boarding_marker.position = Vector3(-2.7, -0.85, 0.0)
	_interceptor_boarding_marker.set_meta(&"boarding_side", &"port")
	visual.add_child(_interceptor_boarding_marker)
