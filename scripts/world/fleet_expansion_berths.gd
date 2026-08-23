class_name FleetExpansionBerths
extends Node3D

## Original-modern station expansion: three bounded service pads for the new
## cargo hauler, bomber, and interceptor. No historical berth or ship-ownership claim.

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
const EXPECTED_STATIC_BODIES := 3
const EXPECTED_COLLISION_SHAPES := 3
const EXPECTED_MESH_INSTANCES := 17
const EXPECTED_SERVICE_MESH_INSTANCES := 14
const EXPECTED_MESH_RESOURCE_ALLOCATIONS := 12
const EXPECTED_GUIDE_LIGHTS := 5
const EXPECTED_DESCENDANTS := 43
const SERVICE_MESH_COUNTS := {
	&"dock_04_cargo": 6,
	&"dock_05_bomber": 3,
	&"dock_06_interceptor": 5,
}
const SERVICE_LIGHT_COUNTS := {
	&"dock_04_cargo": 2,
	&"dock_05_bomber": 1,
	&"dock_06_interceptor": 2,
}
const SERVICE_ROLES := {
	&"dock_04_cargo": &"cargo_crane_and_container_apron",
	&"dock_05_bomber": &"ordnance_safe_gantry_markers",
	&"dock_06_interceptor": &"rapid_launch_guide_frame",
}
const SERVICE_LOCAL_BOUNDS := {
	&"dock_04_cargo": AABB(Vector3(-20.0, -0.1, -15.0), Vector3(43.0, 13.0, 30.0)),
	&"dock_05_bomber": AABB(Vector3(-21.0, -0.1, -21.0), Vector3(42.0, 12.0, 25.0)),
	&"dock_06_interceptor": AABB(Vector3(-18.0, -0.1, -18.0), Vector3(36.0, 12.0, 44.0)),
}
const LANDING_VISUAL_CLEARANCE := AABB(Vector3(-10.0, 0.0, -14.0), Vector3(20.0, 8.0, 28.0))
const APPROACH_VISUAL_CLEARANCE := AABB(Vector3(-10.0, 0.0, 21.0), Vector3(20.0, 8.0, 15.0))
const PAD_ROLE_LABELS := {
	&"dock_04_cargo": "CARGO",
	&"dock_05_bomber": "BOMBER",
	&"dock_06_interceptor": "INTERCEPTOR",
}
const PAD_MARKER_MATERIAL_KEYS := {
	&"dock_04_cargo": "cargo_marker",
	&"dock_05_bomber": "bomber_marker",
	&"dock_06_interceptor": "interceptor_marker",
}
const PRESENTATION_NODE_DELTA := 0
const PRESENTATION_LIGHT_DELTA := 0
const PRESENTATION_SUBMISSION_DELTA := 0

var _pads: Dictionary = {}
var _attachments: Dictionary = {}
var _service_materials: Dictionary = {}
var _cargo_container_mesh: BoxMesh
var _built := false
var _pad_presentation_states: Dictionary = {}


func _enter_tree() -> void:
	if _built:
		call_deferred("_restore_pad_presentations_after_reentry")


func _ready() -> void:
	if _built:
		return
	_built = true
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	_build_service_materials()
	for index in PAD_IDS.size():
		_build_pad(PAD_IDS[index], PAD_POSITIONS[index], index)
		_publish_pad_presentation(PAD_IDS[index])


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
	_publish_pad_presentation(pad_id)
	return {"accepted": true, "reason": &"attached", "pad_id": pad_id, "craft_id": craft_id, "landing_anchor": anchor}


func detach_craft(pad_id: StringName, craft: Node3D) -> Dictionary:
	if not _attachments.has(pad_id):
		return {"accepted": false, "reason": &"pad_empty"}
	var attachment := _attachments[pad_id] as Dictionary
	var owner: Object = (attachment.get("craft", WeakRef.new()) as WeakRef).get_ref()
	if owner != craft:
		return {"accepted": false, "reason": &"foreign_craft"}
	_attachments.erase(pad_id)
	_publish_pad_presentation(pad_id)
	return {"accepted": true, "reason": &"detached", "pad_id": pad_id}


func get_attachment_snapshot(pad_id: StringName) -> Dictionary:
	var attachment := _attachments.get(pad_id, {}) as Dictionary
	if attachment.is_empty():
		return {
			"attached": false,
			"pad_id": pad_id,
			"lease_state_id": &"available",
			"approach_anchor": (_pads.get(pad_id, {}) as Dictionary).get(
				"approach_anchor", Vector3.INF
			),
		}.duplicate(true)
	return {
		"attached": true,
		"pad_id": pad_id,
		"lease_state_id": &"occupied",
		"craft_id": attachment.get("craft_id", &""),
		"landing_anchor": attachment.get("landing_anchor", Vector3.INF),
		"approach_anchor": (_pads.get(pad_id, {}) as Dictionary).get(
			"approach_anchor", Vector3.INF
		),
	}.duplicate(true)


## Presentation consumes the attachment owner's detached lease snapshot only.
## It reuses the authored guide-light roster, role marker material, and pad sign.
func _apply_detached_berth_snapshot(snapshot: Dictionary) -> Dictionary:
	var pad_id := StringName(snapshot.get("pad_id", &""))
	if pad_id not in PAD_IDS or not _pads.has(pad_id):
		return {"accepted": false, "reason": &"unknown_pad"}
	var attached := bool(snapshot.get("attached", false))
	var lease_state_id := StringName(snapshot.get("lease_state_id", &""))
	if lease_state_id != (&"occupied" if attached else &"available"):
		return {"accepted": false, "reason": &"invalid_lease_snapshot"}
	if not (snapshot.get("approach_anchor", Vector3.INF) as Vector3).is_equal_approx(
		(_pads[pad_id] as Dictionary).get("approach_anchor", Vector3.INF)
	):
		return {"accepted": false, "reason": &"approach_anchor_drift"}
	if attached and (
		not _is_stable_craft_id(StringName(snapshot.get("craft_id", &"")))
		or not (snapshot.get("landing_anchor", Vector3.INF) as Vector3).is_equal_approx(
			(_pads[pad_id] as Dictionary).get("landing_anchor", Vector3.INF)
		)
	):
		return {"accepted": false, "reason": &"occupied_lease_snapshot_invalid"}
	var pad := get_node(NodePath(String(pad_id))) as Node3D
	var service := pad.get_node(^"ServicePresentation") as Node3D
	var sign := pad.get_node(^"PadSign") as Label3D
	var lights := service.find_children("*", "OmniLight3D", true, false)
	if lights.size() != int(SERVICE_LIGHT_COUNTS[pad_id]):
		return {"accepted": false, "reason": &"guide_light_roster_drift"}
	var role_color: Color = (lights[0] as OmniLight3D).get_meta(
		&"authored_role_color", (lights[0] as OmniLight3D).light_color
	)
	var light_energy := 2.3 if not attached else 0.38
	var marker_energy := 2.0 if not attached else 0.24
	var cue_color := role_color if not attached else Color("f6a13b")
	for raw_light in lights:
		var light := raw_light as OmniLight3D
		light.light_color = cue_color
		light.light_energy = light_energy
	var marker_material := _service_materials[PAD_MARKER_MATERIAL_KEYS[pad_id]] \
		as StandardMaterial3D
	marker_material.emission_energy_multiplier = marker_energy
	var dock_number := PAD_IDS.find(pad_id) + 4
	sign.text = "DOCK %02d  %s  //  %s" % [
		dock_number,
		String(PAD_ROLE_LABELS[pad_id]),
		"OCCUPIED" if attached else "APPROACH CLEAR",
	]
	sign.modulate = cue_color
	_pad_presentation_states[pad_id] = {
		"pad_id": pad_id,
		"state_id": &"occupied" if attached else &"approach_available",
		"lease_snapshot": snapshot.duplicate(true),
		"guide_energy": light_energy,
		"marker_energy": marker_energy,
		"sign_text": sign.text,
		"node_delta": PRESENTATION_NODE_DELTA,
		"light_delta": PRESENTATION_LIGHT_DELTA,
		"submission_delta": PRESENTATION_SUBMISSION_DELTA,
		"ship_authority": false,
		"berth_lease_authority": false,
		"interaction_authority": false,
	}.duplicate(true)
	return {"accepted": true, "reason": &"berth_presentation_applied"}


func get_pad_presentation_state(pad_id: StringName) -> Dictionary:
	return (_pad_presentation_states.get(pad_id, {}) as Dictionary).duplicate(true)


func _publish_pad_presentation(pad_id: StringName) -> void:
	_apply_detached_berth_snapshot(get_attachment_snapshot(pad_id))


func _restore_pad_presentations_after_reentry() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	for pad_id in PAD_IDS:
		_publish_pad_presentation(pad_id)


func get_service_presentation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var pad_reports: Dictionary = {}
	var mesh_resource_ids: Dictionary = {}
	for pad_index in PAD_IDS.size():
		var pad_id := PAD_IDS[pad_index]
		var pad := get_node_or_null(NodePath(String(pad_id))) as Node3D
		var service := pad.get_node_or_null(^"ServicePresentation") as Node3D \
			if pad != null else null
		var meshes: Array[Node] = []
		var lights: Array[Node] = []
		var local_bounds := AABB()
		var first_bound := true
		var landing_clear := true
		var approach_clear := true
		if service == null:
			errors.append("service presentation missing: %s" % pad_id)
		else:
			meshes = service.find_children("*", "MeshInstance3D", true, false)
			lights = service.find_children("*", "Light3D", true, false)
			for raw_mesh in meshes:
				var instance := raw_mesh as MeshInstance3D
				if instance.mesh == null:
					errors.append("service mesh missing: %s" % pad_id)
					continue
				mesh_resource_ids[instance.mesh.get_instance_id()] = true
				var bounds := (instance.transform * instance.mesh.get_aabb()).abs()
				local_bounds = bounds if first_bound else local_bounds.merge(bounds)
				first_bound = false
				landing_clear = landing_clear and not bounds.intersects(LANDING_VISUAL_CLEARANCE)
				approach_clear = approach_clear and not bounds.intersects(APPROACH_VISUAL_CLEARANCE)
			for raw_light in lights:
				if (raw_light as Light3D).shadow_enabled:
					errors.append("shadow light added: %s" % pad_id)
			if not bool(service.get_meta(&"presentation_only", false)) \
					or StringName(service.get_meta(&"service_role", &"")) != SERVICE_ROLES[pad_id] \
					or bool(service.get_meta(&"ship_authority", true)) \
					or bool(service.get_meta(&"berth_lease_authority", true)):
				errors.append("service presentation authority drift: %s" % pad_id)
			if not service.find_children("*", "CollisionObject3D", true, false).is_empty() \
					or not service.find_children("*", "CollisionShape3D", true, false).is_empty() \
					or not service.find_children("*", "Area3D", true, false).is_empty():
				errors.append("service presentation gained collision or interaction: %s" % pad_id)
		if meshes.size() != int(SERVICE_MESH_COUNTS[pad_id]):
			errors.append("service mesh budget drift: %s" % pad_id)
		if lights.size() != int(SERVICE_LIGHT_COUNTS[pad_id]):
			errors.append("service light budget drift: %s" % pad_id)
		if not (SERVICE_LOCAL_BOUNDS[pad_id] as AABB).encloses(local_bounds):
			errors.append("service silhouette left local bounds: %s" % pad_id)
		if not landing_clear or not approach_clear:
			errors.append("service silhouette entered landing or approach clearance: %s" % pad_id)
		var minimum_readable_width := 31.0 if pad_id == &"dock_05_bomber" else 33.0
		var readable := not first_bound and local_bounds.size.x >= minimum_readable_width \
			and local_bounds.size.y >= 10.0
		if pad_id == &"dock_06_interceptor":
			readable = readable and local_bounds.size.z >= 40.0
		if not readable:
			errors.append("service silhouette readability drift: %s" % pad_id)
		var expected_landing := PAD_POSITIONS[pad_index] + Vector3(0.0, LANDING_ANCHOR_Y, 0.0)
		var expected_approach := PAD_POSITIONS[pad_index] + APPROACH_OFFSET
		var contract := get_landing_contract(pad_id)
		if (contract.get("landing_anchor", Vector3.INF) as Vector3) != expected_landing \
				or (contract.get("approach_anchor", Vector3.INF) as Vector3) != expected_approach:
			errors.append("service presentation moved landing contract: %s" % pad_id)
		pad_reports[pad_id] = {
			"service_role": SERVICE_ROLES[pad_id],
			"mesh_nodes": meshes.size(),
			"light_nodes": lights.size(),
			"local_bounds": local_bounds,
			"maximum_local_bounds": SERVICE_LOCAL_BOUNDS[pad_id],
			"landing_clear": landing_clear,
			"approach_clear": approach_clear,
			"readable": readable,
			"state_feedback": get_pad_presentation_state(pad_id),
		}.duplicate(true)
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"pads": pad_reports,
		"renderer_nodes_before": EXPECTED_SERVICE_MESH_INSTANCES,
		"renderer_nodes_after": EXPECTED_SERVICE_MESH_INSTANCES,
		"mesh_resource_allocations_before": EXPECTED_SERVICE_MESH_INSTANCES,
		"mesh_resource_allocations_after": mesh_resource_ids.size(),
		"mesh_resource_delta": mesh_resource_ids.size() - EXPECTED_SERVICE_MESH_INSTANCES,
		"budgets": {
			"mesh_instances": EXPECTED_MESH_INSTANCES,
			"mesh_resource_allocations": EXPECTED_MESH_RESOURCE_ALLOCATIONS,
			"guide_lights": EXPECTED_GUIDE_LIGHTS,
			"descendants": EXPECTED_DESCENDANTS,
			"static_bodies": EXPECTED_STATIC_BODIES,
			"collision_shapes": EXPECTED_COLLISION_SHAPES,
		},
		"ship_authority": false,
		"berth_lease_authority": false,
		"interaction_authority": false,
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if PAD_IDS.size() != 3 or _pads.size() != 3:
		errors.append("exactly three authored expansion pads are required")
	var bodies := find_children("*", "StaticBody3D", true, false).size()
	var meshes := find_children("*", "MeshInstance3D", true, false).size()
	var collision_shapes := find_children("*", "CollisionShape3D", true, false).size()
	var guide_lights := find_children("*", "OmniLight3D", true, false).size()
	var descendants := find_children("*", "", true, false).size()
	if bodies > MAX_STATIC_BODIES:
		errors.append("static body budget exceeded")
	if meshes > MAX_MESH_INSTANCES:
		errors.append("mesh budget exceeded")
	if bodies != EXPECTED_STATIC_BODIES or collision_shapes != EXPECTED_COLLISION_SHAPES:
		errors.append("walkable collision roster drift")
	if meshes != EXPECTED_MESH_INSTANCES or guide_lights != EXPECTED_GUIDE_LIGHTS \
			or descendants != EXPECTED_DESCENDANTS:
		errors.append("service presentation census drift")
	var service_presentation := get_service_presentation_audit()
	if not bool(service_presentation.get("valid", false)):
		for error in (service_presentation.get("errors", PackedStringArray()) as PackedStringArray):
			errors.append("service presentation: %s" % error)
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
		"mesh_resource_allocations": int(service_presentation.get("mesh_resource_allocations_after", -1)),
		"collision_shapes": collision_shapes,
		"guide_lights": guide_lights,
		"descendants": descendants,
		"service_presentation": service_presentation,
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
	_build_service_presentation(pad, pad_id)
	_pads[pad_id] = {
		"pad_id": pad_id,
		"landing_anchor": landing.global_position,
		"approach_anchor": route.global_position,
		"position": pad_position,
		"size": PAD_SIZE,
	}


func _build_service_presentation(pad: Node3D, pad_id: StringName) -> void:
	var service := Node3D.new()
	service.name = "ServicePresentation"
	service.set_meta(&"presentation_only", true)
	service.set_meta(&"service_role", SERVICE_ROLES[pad_id])
	service.set_meta(&"ship_authority", false)
	service.set_meta(&"berth_lease_authority", false)
	pad.add_child(service)
	match pad_id:
		&"dock_04_cargo":
			_visual_box(service, "CargoCraneMast", Vector3(-18.0, 6.0, -7.0), Vector3(1.5, 12.0, 1.5), _service_materials["cargo_frame"])
			_visual_box(service, "CargoCraneJib", Vector3(-12.0, 11.5, -7.0), Vector3(13.5, 1.0, 1.0), _service_materials["cargo_frame"])
			_visual_box(service, "CargoCraneHoist", Vector3(-7.0, 10.0, -7.0), Vector3(1.0, 3.0, 1.0), _service_materials["cargo_marker"])
			_cargo_container_mesh = BoxMesh.new()
			_cargo_container_mesh.size = Vector3(7.0, 3.6, 7.0)
			for container_index in 3:
				_visual_box(
					service, "CargoContainer%02d" % (container_index + 1),
					Vector3(18.0, 1.8, -10.0 + float(container_index) * 10.0),
					Vector3(7.0, 3.6, 7.0),
					_service_materials["cargo_container"], _cargo_container_mesh
				)
			_guide_light(service, "CargoApronGuidePort", Vector3(-18.0, 1.2, 12.0), Color("56d8de"))
			_guide_light(service, "CargoApronGuideStarboard", Vector3(18.0, 1.2, 14.0), Color("56d8de"))
		&"dock_05_bomber":
			# The former starboard copy sat beyond the elevated pad edge after the
			# production transform, hanging over the lower Central walkway. Keep the
			# supported port marker and the flush blast datum as the bay's clear cue.
			_visual_box(service, "OrdnanceGantryPort", Vector3(-18.0, 5.0, -5.0), Vector3(2.0, 10.0, 2.0), _service_materials["bomber_frame"])
			_visual_box(service, "OrdnanceMarkerPort", Vector3(-18.0, 10.5, -5.0), Vector3(3.0, 1.0, 6.0), _service_materials["bomber_marker"])
			_visual_box(service, "BlastSafetyDatum", Vector3(0.0, 0.4, -18.0), Vector3(24.0, 0.5, 2.0), _service_materials["bomber_marker"])
			_guide_light(service, "OrdnanceGuidePort", Vector3(-18.0, 10.5, -1.5), Color("ff9b4a"))
		&"dock_06_interceptor":
			_visual_box(service, "LaunchRailPort", Vector3(-16.0, 0.5, 5.0), Vector3(1.0, 1.0, 38.0), _service_materials["interceptor_marker"])
			_visual_box(service, "LaunchRailStarboard", Vector3(16.0, 0.5, 5.0), Vector3(1.0, 1.0, 38.0), _service_materials["interceptor_marker"])
			_visual_box(service, "LaunchFramePort", Vector3(-16.0, 5.0, -16.0), Vector3(1.5, 10.0, 1.5), _service_materials["interceptor_frame"])
			_visual_box(service, "LaunchFrameStarboard", Vector3(16.0, 5.0, -16.0), Vector3(1.5, 10.0, 1.5), _service_materials["interceptor_frame"])
			_visual_box(service, "LaunchFrameHeader", Vector3(0.0, 10.0, -16.0), Vector3(33.5, 1.0, 1.5), _service_materials["interceptor_frame"])
			_guide_light(service, "LaunchGuidePort", Vector3(-16.0, 1.2, 24.0), Color("61e4ee"))
			_guide_light(service, "LaunchGuideStarboard", Vector3(16.0, 1.2, 24.0), Color("61e4ee"))


func _visual_box(
		parent: Node3D, node_name: String, position_value: Vector3,
		size: Vector3, material: Material, shared_mesh: Mesh = null
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	var mesh := shared_mesh
	if mesh == null:
		var box := BoxMesh.new()
		box.size = size
		mesh = box
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _guide_light(
		parent: Node3D, node_name: String, position_value: Vector3, color: Color
	) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = color
	light.set_meta(&"authored_role_color", color)
	light.light_energy = 1.15
	light.omni_range = 12.0
	light.shadow_enabled = false
	parent.add_child(light)
	return light


func _build_service_materials() -> void:
	_service_materials = {
		"cargo_frame": _material(Color("8a6a36"), 0.72),
		"cargo_container": _material(Color("2f5966"), 0.58),
		"cargo_marker": _emissive_material(Color("56d8de")),
		"bomber_frame": _material(Color("3b3034"), 0.78),
		"bomber_marker": _emissive_material(Color("ff8b42")),
		"interceptor_frame": _material(Color("31515b"), 0.74),
		"interceptor_marker": _emissive_material(Color("61e4ee")),
	}


func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := _material(color.darkened(0.25), 0.48)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	return material


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
