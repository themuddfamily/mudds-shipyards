class_name FleetExpansionBerths
extends Node3D

## Original-modern station expansion: two bounded service pads for the new
## cargo hauler and bomber. No historical berth or ship-ownership claim.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"fleet-expansion-berths"
const EVIDENCE_STATUS: StringName = &"NEW"
const PAD_IDS: Array[StringName] = [&"dock_04_cargo", &"dock_05_bomber"]
const PAD_POSITIONS: Array[Vector3] = [Vector3(-34.0, 0.0, -18.0), Vector3(34.0, 0.0, -18.0)]
const PAD_SIZE := Vector3(28.0, 0.6, 42.0)
const APPROACH_OFFSET := Vector3(0.0, 0.0, 30.0)
const LANDING_ANCHOR_Y := 4.0
const MAX_STATIC_BODIES := 8
const MAX_MESH_INSTANCES := 24

var _pads: Dictionary = {}
var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	for index in PAD_IDS.size():
		_build_pad(PAD_IDS[index], PAD_POSITIONS[index], index)


func get_pad_ids() -> Array[StringName]:
	return PAD_IDS.duplicate()


func get_pad_snapshot(pad_id: StringName) -> Dictionary:
	var pad := _pads.get(pad_id, {}) as Dictionary
	return pad.duplicate(true)


func get_landing_contract(pad_id: StringName) -> Dictionary:
	var pad := _pads.get(pad_id, {}) as Dictionary
	if pad.is_empty():
		return {"accepted": false, "reason": &"unknown_pad"}
	return {
		"accepted": true,
		"pad_id": pad_id,
		"landing_anchor": pad.get("landing_anchor", Vector3.INF),
		"approach_anchor": pad.get("approach_anchor", Vector3.INF),
		"approach_radius": 12.0,
		"ship_authority": false,
		"berth_lease_authority": false,
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if PAD_IDS.size() != 2 or _pads.size() != 2:
		errors.append("exactly two authored expansion pads are required")
	var bodies := find_children("*", "StaticBody3D", true, false).size()
	var meshes := find_children("*", "MeshInstance3D", true, false).size()
	if bodies > MAX_STATIC_BODIES:
		errors.append("static body budget exceeded")
	if meshes > MAX_MESH_INSTANCES:
		errors.append("mesh budget exceeded")
	for pad_id in PAD_IDS:
		var contract := get_landing_contract(pad_id)
		if not bool(contract.get("accepted", false)):
			errors.append("missing landing contract: %s" % pad_id)
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"pad_count": _pads.size(),
		"static_bodies": bodies,
		"mesh_instances": meshes,
		"ship_authority": false,
		"berth_lease_authority": false,
		"game_flow_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _build_pad(pad_id: StringName, pad_position: Vector3, index: int) -> void:
	var pad := Node3D.new()
	pad.name = String(pad_id)
	pad.position = pad_position
	pad.set_meta(&"landing_contract_anchor", true)
	add_child(pad)
	var body := StaticBody3D.new()
	body.name = "WalkablePadCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	pad.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = PAD_SIZE
	collision.shape = shape
	collision.position.y = -0.3
	body.add_child(collision)
	var surface := MeshInstance3D.new()
	surface.name = "ServicePadSurface"
	var mesh := BoxMesh.new()
	mesh.size = PAD_SIZE
	surface.mesh = mesh
	surface.material_override = _material(Color("334b55"), 0.7)
	pad.add_child(surface)
	var route := Marker3D.new()
	route.name = "ApproachMarker"
	route.position = APPROACH_OFFSET
	route.set_meta(&"route_marker", true)
	pad.add_child(route)
	var landing := Marker3D.new()
	landing.name = "LandingContractAnchor"
	landing.position = Vector3(0.0, LANDING_ANCHOR_Y, 0.0)
	landing.set_meta(&"landing_contract", true)
	pad.add_child(landing)
	var sign := Label3D.new()
	sign.name = "PadSign"
	sign.text = "DOCK %02d  %s" % [index + 4, "CARGO" if index == 0 else "BOMBER"]
	sign.position = Vector3(0.0, 4.5, -18.0)
	sign.font_size = 32
	sign.modulate = Color("63dbe0")
	pad.add_child(sign)
	_pads[pad_id] = {
		"pad_id": pad_id,
		"landing_anchor": landing.global_position,
		"approach_anchor": route.global_position,
		"position": pad_position,
		"size": PAD_SIZE,
	}


func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.44
	return material
