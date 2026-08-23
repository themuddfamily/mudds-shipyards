class_name FleetExpansionBerths
extends Node3D

## Original-modern station expansion: two bounded service pads for the new
## cargo hauler and bomber. No historical berth or ship-ownership claim.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"fleet-expansion-berths"
const EVIDENCE_STATUS: StringName = &"NEW"
const PAD_IDS: Array[StringName] = [&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"]
const PAD_POSITIONS: Array[Vector3] = [
	Vector3(-34.0, 0.0, -18.0), Vector3(34.0, 0.0, -18.0), Vector3(0.0, 0.0, 34.0)
]
const PAD_SIZE := Vector3(28.0, 0.6, 42.0)
const APPROACH_OFFSET := Vector3(0.0, 0.0, 30.0)
const LANDING_ANCHOR_Y := 4.0
const MAX_STATIC_BODIES := 10
const MAX_MESH_INSTANCES := 30

var _pads: Dictionary = {}
var _attachments: Dictionary = {}
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


func attach_craft(pad_id: StringName, craft: Node3D, craft_id: StringName) -> Dictionary:
	if not _pads.has(pad_id):
		return {"accepted": false, "reason": &"unknown_pad"}
	if not is_instance_valid(craft) or not craft.is_inside_tree():
		return {"accepted": false, "reason": &"craft_not_current"}
	if not _is_stable_craft_id(craft_id):
		return {"accepted": false, "reason": &"invalid_craft_id"}
	if StringName(craft.get_meta(&"evidence_status", &"")) != EVIDENCE_STATUS:
		return {"accepted": false, "reason": &"craft_evidence_not_new"}
	if _attachments.has(pad_id):
		return {"accepted": false, "reason": &"pad_occupied"}
	for attachment in _attachments.values():
		if (attachment.get("craft", WeakRef.new()) as WeakRef).get_ref() == craft:
			return {"accepted": false, "reason": &"craft_already_attached"}
	var anchor: Vector3 = _pads[pad_id].get("landing_anchor", Vector3.INF)
	craft.global_transform = Transform3D(craft.global_transform.basis, anchor)
	_attachments[pad_id] = {"craft": weakref(craft), "craft_id": craft_id, "landing_anchor": anchor}
	return {"accepted": true, "reason": &"attached", "pad_id": pad_id, "craft_id": craft_id, "landing_anchor": anchor}


func detach_craft(pad_id: StringName, craft: Node3D) -> Dictionary:
	if not _attachments.has(pad_id):
		return {"accepted": false, "reason": &"pad_empty"}
	var attachment := _attachments[pad_id] as Dictionary
	var owner: Object = (attachment.get("craft", WeakRef.new()) as WeakRef).get_ref()
	if owner != craft:
		return {"accepted": false, "reason": &"foreign_craft"}
	_attachments.erase(pad_id)
	return {"accepted": true, "reason": &"detached", "pad_id": pad_id}


func get_attachment_snapshot(pad_id: StringName) -> Dictionary:
	var attachment := _attachments.get(pad_id, {}) as Dictionary
	if attachment.is_empty():
		return {"attached": false, "pad_id": pad_id}
	return {"attached": true, "pad_id": pad_id, "craft_id": attachment.get("craft_id", &""), "landing_anchor": attachment.get("landing_anchor", Vector3.INF)}


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if PAD_IDS.size() != 3 or _pads.size() != 3:
		errors.append("exactly three authored expansion pads are required")
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
	for pad_id in _attachments:
		var attachment := _attachments[pad_id] as Dictionary
		if (attachment.get("craft", WeakRef.new()) as WeakRef).get_ref() == null:
			errors.append("attachment has lost its craft owner: %s" % pad_id)
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
	sign.text = "DOCK %02d  %s" % [index + 4, ["CARGO", "BOMBER", "INTERCEPTOR"][index]]
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


func _is_stable_craft_id(craft_id: StringName) -> bool:
	var text := str(craft_id)
	if text.is_empty() or text.length() > 64:
		return false
	for index in text.length():
		var code := text.unicode_at(index)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code in [95, 45]):
			return false
	return true
