class_name CinderLongRangeBomber
extends Node3D

## Original-modern long-range bomber component. No historical craft, weapon,
## payload, or mission claim is authenticated here.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder-long-range-bomber"
const EVIDENCE_STATUS: StringName = &"NEW"
const DISPLAY_NAME := "Cinder long-range bomber"
const PAYLOAD_HARDPOINT_COUNT := 4
const HULL_SIZE := Vector3(7.0, 3.0, 15.5)
const HULL_COLOR := Color("3e4d57")
const ORDNANCE_COLOR := Color("b85a3c")
const SENSOR_COLOR := Color("d6b45d")

var _cockpit_seat: Marker3D
var _boarding_marker: Marker3D
var _payload_hardpoints: Array[Marker3D] = []
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
	_build_payload_hardpoints()


func get_display_name() -> String:
	return DISPLAY_NAME


func get_cockpit_seat_anchor() -> Marker3D:
	return _cockpit_seat


func get_boarding_marker() -> Marker3D:
	return _boarding_marker


func get_payload_hardpoints() -> Array[Marker3D]:
	return _payload_hardpoints.duplicate()


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not _built:
		errors.append("bomber has not built its authored component tree")
	if not is_instance_valid(_cockpit_seat) or not is_instance_valid(_boarding_marker):
		errors.append("cockpit and boarding anchors are required")
	if _payload_hardpoints.size() != PAYLOAD_HARDPOINT_COUNT:
		errors.append("four caller-owned payload hardpoints are required")
	if find_children("*", "StaticBody3D", true, false).size() != 1:
		errors.append("bomber requires one hull collision body")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"payload_hardpoint_count": _payload_hardpoints.size(),
		"flight_authority": false,
		"combat_authority": false,
		"ordnance_authority": false,
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
	hull.name = "LongRangeHull"
	var mesh := BoxMesh.new()
	mesh.size = HULL_SIZE
	hull.mesh = mesh
	hull.material_override = _material(HULL_COLOR, 0.78)
	add_child(hull)
	var ordnance := MeshInstance3D.new()
	ordnance.name = "OrdnanceSpine"
	var ordnance_mesh := BoxMesh.new()
	ordnance_mesh.size = Vector3(2.2, 1.25, 8.4)
	ordnance.mesh = ordnance_mesh
	ordnance.position = Vector3(0.0, -0.15, 1.5)
	ordnance.material_override = _material(ORDNANCE_COLOR, 0.52)
	add_child(ordnance)
	var sensor := MeshInstance3D.new()
	sensor.name = "LongRangeSensor"
	var sensor_mesh := SphereMesh.new()
	sensor_mesh.radius = 0.62
	sensor_mesh.height = 1.24
	sensor.mesh = sensor_mesh
	sensor.position = Vector3(0.0, 1.6, -5.2)
	sensor.material_override = _material(SENSOR_COLOR, 0.35, SENSOR_COLOR)
	add_child(sensor)


func _build_cockpit() -> void:
	_cockpit_seat = Marker3D.new()
	_cockpit_seat.name = "PilotCockpitSeat"
	_cockpit_seat.position = Vector3(0.0, 1.15, -5.0)
	_cockpit_seat.set_meta(&"seat_role", &"pilot")
	_cockpit_seat.set_meta(&"physical_boarding_anchor", true)
	add_child(_cockpit_seat)
	_boarding_marker = Marker3D.new()
	_boarding_marker.name = "BoardingMarker"
	_boarding_marker.position = Vector3(-3.8, -1.0, -0.5)
	_boarding_marker.set_meta(&"boarding_side", &"port")
	add_child(_boarding_marker)


func _build_payload_hardpoints() -> void:
	for index in PAYLOAD_HARDPOINT_COUNT:
		var hardpoint := Marker3D.new()
		hardpoint.name = "PayloadHardpoint%02d" % (index + 1)
		hardpoint.position = Vector3(-1.55 if index % 2 == 0 else 1.55, -1.0, -2.4 + float(index / 2) * 4.8)
		hardpoint.set_meta(&"payload_slot_index", index)
		hardpoint.set_meta(&"ordnance_owner", COMPONENT_ID)
		add_child(hardpoint)
		_payload_hardpoints.append(hardpoint)


func _material(color: Color, metallic: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.4
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.8
	return material
