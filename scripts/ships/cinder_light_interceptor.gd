class_name CinderLightInterceptor
extends Node3D

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

var _cockpit_seat: Marker3D
var _boarding_marker: Marker3D
var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	_build_hull()
	_build_cockpit()


func get_display_name() -> String:
	return DISPLAY_NAME


func get_cockpit_seat_anchor() -> Marker3D:
	return _cockpit_seat


func get_boarding_marker() -> Marker3D:
	return _boarding_marker


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not _built:
		errors.append("interceptor has not built its authored component tree")
	if not is_instance_valid(_cockpit_seat) or not is_instance_valid(_boarding_marker):
		errors.append("cockpit and boarding anchors are required")
	if find_children("*", "StaticBody3D", true, false).size() != 1:
		errors.append("interceptor requires one hull collision body")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"flight_authority": false,
		"combat_authority": false,
		"weapon_authority": false,
		"berth_authority": false,
		"game_flow_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _build_hull() -> void:
	var body := StaticBody3D.new()
	body.name = "HullCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = HULL_SIZE
	collision.shape = shape
	body.add_child(collision)
	var hull := MeshInstance3D.new()
	hull.name = "HighVisibilityHull"
	var mesh := BoxMesh.new()
	mesh.size = HULL_SIZE
	hull.mesh = mesh
	hull.material_override = _material(HULL_COLOR, 0.62)
	add_child(hull)
	var wing := MeshInstance3D.new()
	wing.name = "RapidResponseWing"
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(12.0, 0.45, 2.4)
	wing.mesh = wing_mesh
	wing.position = Vector3(0.0, -0.15, 0.8)
	wing.material_override = _material(WING_COLOR, 0.5)
	add_child(wing)
	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.25
	canopy_mesh.height = 1.5
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.0, 1.1, -2.1)
	canopy.material_override = _material(CANOPY_COLOR, 0.15, CANOPY_COLOR)
	add_child(canopy)


func _build_cockpit() -> void:
	_cockpit_seat = Marker3D.new()
	_cockpit_seat.name = "PilotCockpitSeat"
	_cockpit_seat.position = Vector3(0.0, 1.0, -2.4)
	_cockpit_seat.set_meta(&"seat_role", &"pilot")
	_cockpit_seat.set_meta(&"physical_boarding_anchor", true)
	add_child(_cockpit_seat)
	_boarding_marker = Marker3D.new()
	_boarding_marker.name = "BoardingMarker"
	_boarding_marker.position = Vector3(-2.7, -0.85, 0.0)
	_boarding_marker.set_meta(&"boarding_side", &"port")
	add_child(_boarding_marker)


func _material(color: Color, metallic: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.36
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.0
	return material
