class_name CinderLongRangeBomber
extends HeroShip

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

var _bomber_boarding_marker: Marker3D
var _payload_hardpoints: Array[Marker3D] = []
var _bomber_built := false


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _ready() -> void:
	ship_id = COMPONENT_ID
	display_name = DISPLAY_NAME
	role_name = "Long-range bomber"
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	super._ready()
	if not _bomber_built:
		_bomber_built = rebuild_variant_presentation(_build_bomber_variant)


func _build_bomber_variant(_controller: HeroShip) -> bool:
	var visual := get_variant_visual_root()
	if visual == null:
		return false
	visual.name = "CinderBomberVisual"
	visual.set_meta(&"geometry_status", EVIDENCE_STATUS)
	visual.set_meta(&"historically_supported", false)
	_build_hull(visual)
	_build_cockpit_and_boarding(visual)
	_build_payload_hardpoints(visual)
	return true


func get_display_name() -> String:
	return DISPLAY_NAME


func get_cockpit_seat_anchor() -> Marker3D:
	return get_pilot_seat_anchor() as Marker3D


func get_boarding_marker() -> Marker3D:
	return _bomber_boarding_marker


func get_payload_hardpoints() -> Array[Marker3D]:
	return _payload_hardpoints.duplicate()


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not _bomber_built:
		errors.append("bomber has not built its authored component tree")
	if not is_instance_valid(get_pilot_seat_anchor()) or not is_instance_valid(_bomber_boarding_marker):
		errors.append("cockpit and boarding anchors are required")
	if _payload_hardpoints.size() != PAYLOAD_HARDPOINT_COUNT:
		errors.append("four caller-owned payload hardpoints are required")
	if not bool(get_landing_collision_report().get("valid", false)):
		errors.append("bomber requires HeroShip root collision")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"payload_hardpoint_count": _payload_hardpoints.size(),
		"hero_ship_derived": true,
		"flight_authority": true,
		"landing_authority": true,
		"damage_authority": true,
		"reuse_authority": true,
		"combat_authority": false,
		"ordnance_authority": false,
		"berth_authority": false,
		"game_flow_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _build_collision() -> void:
	_add_box_collision_shape("BomberHullCollision", Vector3(0.0, 0.0, 0.0), HULL_SIZE)


func _build_hull(visual: Node3D) -> void:
	var hull := MeshInstance3D.new()
	hull.name = "LongRangeHull"
	var mesh := BoxMesh.new()
	mesh.size = HULL_SIZE
	hull.mesh = mesh
	hull.material_override = _material(HULL_COLOR, 0.78, 0.4)
	visual.add_child(hull)
	var ordnance := MeshInstance3D.new()
	ordnance.name = "OrdnanceSpine"
	var ordnance_mesh := BoxMesh.new()
	ordnance_mesh.size = Vector3(2.2, 1.25, 8.4)
	ordnance.mesh = ordnance_mesh
	ordnance.position = Vector3(0.0, -0.15, 1.5)
	ordnance.material_override = _material(ORDNANCE_COLOR, 0.52, 0.4)
	visual.add_child(ordnance)
	var sensor := MeshInstance3D.new()
	sensor.name = "LongRangeSensor"
	var sensor_mesh := SphereMesh.new()
	sensor_mesh.radius = 0.62
	sensor_mesh.height = 1.24
	sensor.mesh = sensor_mesh
	sensor.position = Vector3(0.0, 1.6, -5.2)
	sensor.material_override = _material(SENSOR_COLOR, 0.35, 0.4, SENSOR_COLOR, 1.8)
	visual.add_child(sensor)


func _build_cockpit_and_boarding(visual: Node3D) -> void:
	_bomber_boarding_marker = Marker3D.new()
	_bomber_boarding_marker.name = "BoardingMarker"
	_bomber_boarding_marker.position = Vector3(-3.8, -1.0, -0.5)
	_bomber_boarding_marker.set_meta(&"boarding_side", &"port")
	visual.add_child(_bomber_boarding_marker)


func _build_payload_hardpoints(visual: Node3D) -> void:
	for index in PAYLOAD_HARDPOINT_COUNT:
		var hardpoint := Marker3D.new()
		hardpoint.name = "PayloadHardpoint%02d" % (index + 1)
		hardpoint.position = Vector3(-1.55 if index % 2 == 0 else 1.55, -1.0, -2.4 + float(index / 2) * 4.8)
		hardpoint.set_meta(&"payload_slot_index", index)
		hardpoint.set_meta(&"ordnance_owner", COMPONENT_ID)
		visual.add_child(hardpoint)
		_payload_hardpoints.append(hardpoint)
