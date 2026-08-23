class_name CinderCargoHauler
extends Node3D

## Original-modern industrial cargo craft component. No historical class,
## silhouette, cargo contract, or ownership claim is authenticated here.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder-cargo-hauler"
const EVIDENCE_STATUS: StringName = &"NEW"
const DISPLAY_NAME := "Cinder cargo hauler"
const CARGO_CAPACITY := 8
const HULL_SIZE := Vector3(6.4, 3.2, 12.0)

const HULL_COLOR := Color("536b73")
const CARGO_COLOR := Color("b2773d")
const ACCENT_COLOR := Color("42c9cf")

var _cockpit_seat: Marker3D
var _boarding_marker: Marker3D
var _cargo_hold: Node3D
var _cargo_anchors: Array[Marker3D] = []
var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	set_meta(&"content_class", EVIDENCE_STATUS)
	_build_hull()
	_build_cockpit_and_boarding()
	_build_cargo_hold()


func get_display_name() -> String:
	return DISPLAY_NAME


func get_cockpit_seat_anchor() -> Marker3D:
	return _cockpit_seat


func get_boarding_marker() -> Marker3D:
	return _boarding_marker


func get_cargo_hold_root() -> Node3D:
	return _cargo_hold


func get_cargo_transfer_anchors() -> Array[Marker3D]:
	return _cargo_anchors.duplicate()


func get_cargo_capacity() -> int:
	return CARGO_CAPACITY


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not _built:
		errors.append("craft has not built its authored component tree")
	if not is_instance_valid(_cockpit_seat) or not is_instance_valid(_boarding_marker):
		errors.append("cockpit and boarding anchors are required")
	if not is_instance_valid(_cargo_hold) or _cargo_anchors.size() != CARGO_CAPACITY:
		errors.append("cargo hold requires eight stable transfer anchors")
	var bodies := find_children("*", "StaticBody3D", true, false)
	if bodies.size() != 1:
		errors.append("craft requires one hull collision body")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"content_class": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"cargo_capacity": CARGO_CAPACITY,
		"cargo_transfer_authority": false,
		"flight_authority": false,
		"berth_authority": false,
		"combat_authority": false,
		"game_flow_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _build_hull() -> void:
	var body := StaticBody3D.new()
	body.name = "HullCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = HULL_SIZE
	shape.shape = box
	body.add_child(shape)
	var hull := MeshInstance3D.new()
	hull.name = "IndustrialHull"
	var mesh := BoxMesh.new()
	mesh.size = HULL_SIZE
	hull.mesh = mesh
	hull.material_override = _material(HULL_COLOR, 0.72)
	add_child(hull)
	var cargo_pod := MeshInstance3D.new()
	cargo_pod.name = "CargoPod"
	var pod_mesh := BoxMesh.new()
	pod_mesh.size = Vector3(5.2, 2.2, 7.2)
	cargo_pod.mesh = pod_mesh
	cargo_pod.position = Vector3(0.0, 0.15, 1.0)
	cargo_pod.material_override = _material(CARGO_COLOR, 0.45)
	add_child(cargo_pod)


func _build_cockpit_and_boarding() -> void:
	_cockpit_seat = Marker3D.new()
	_cockpit_seat.name = "PilotCockpitSeat"
	_cockpit_seat.position = Vector3(0.0, 1.35, -4.1)
	_cockpit_seat.set_meta(&"seat_role", &"pilot")
	_cockpit_seat.set_meta(&"physical_boarding_anchor", true)
	add_child(_cockpit_seat)
	_boarding_marker = Marker3D.new()
	_boarding_marker.name = "BoardingMarker"
	_boarding_marker.position = Vector3(-3.4, -1.1, 0.0)
	_boarding_marker.set_meta(&"boarding_side", &"port")
	add_child(_boarding_marker)
	var lamp := MeshInstance3D.new()
	lamp.name = "BoardingLamp"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, 0.8)
	lamp.mesh = mesh
	lamp.position = _boarding_marker.position + Vector3(0.2, 0.5, 0.0)
	lamp.material_override = _material(ACCENT_COLOR, 0.2, ACCENT_COLOR)
	add_child(lamp)


func _build_cargo_hold() -> void:
	_cargo_hold = Node3D.new()
	_cargo_hold.name = "CargoHold"
	_cargo_hold.set_meta(&"transfer_anchor_contract", true)
	add_child(_cargo_hold)
	for index in CARGO_CAPACITY:
		var anchor := Marker3D.new()
		anchor.name = "CargoTransferAnchor%02d" % (index + 1)
		anchor.position = Vector3(-2.0 if index % 2 == 0 else 2.0, 0.95, -2.4 + float(index / 2) * 1.6)
		anchor.set_meta(&"cargo_slot_index", index)
		anchor.set_meta(&"transfer_owner", COMPONENT_ID)
		_cargo_hold.add_child(anchor)
		_cargo_anchors.append(anchor)


func _material(color: Color, metallic: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.42
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.8
	return material
