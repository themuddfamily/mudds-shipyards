class_name FleetExpansionBerths
extends Node3D

## Original-modern station expansion: three bounded service pads for the new
## cargo hauler, bomber, and interceptor. No historical berth or ship-ownership claim.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"fleet-expansion-berths"
const EVIDENCE_STATUS: StringName = &"NEW"
const WORLD_LAYER := PhysicsLayers.WORLD
const PAD_IDS: Array[StringName] = [&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"]
const PAD_POSITIONS: Array[Vector3] = [
	Vector3(-16.4, 0.0, -8.0), Vector3(34.0, 0.0, -18.0), Vector3(0.0, 0.0, 34.0)
]
const PAD_SIZE := Vector3(28.0, 0.6, 42.0)
const APPROACH_OFFSET := Vector3(0.0, 0.0, 30.0)
const LANDING_ANCHOR_Y := 4.0
## The craft are held by their kinematic attachment contracts four metres above
## this plane; World collision never supported their hulls. The former broad
## 3,220.8 m2 pad plates therefore created player floor without serving the
## landing physics. Six honest one-metre routes now connect the live trunk/Aft
## handoff to each exact craft boarding-marker projection.
const ACCESS_DECK_THICKNESS := 0.6
const ACCESS_SURFACE_NAMES := [
	&"CargoTrunkLeg", &"CargoBoardingLeg", &"Dock05BomberBridge",
	&"BomberBerthLeg", &"BomberBoardingLeg", &"InterceptorBoardingToe",
]
const ACCESS_SURFACE_SPECS: Array[Dictionary] = [
	{"name": &"CargoTrunkLeg", "top_center": Vector3(-11.35, 0.0, 0.5), "size": Vector3(17.9, 0.6, 1.0)},
	{"name": &"CargoBoardingLeg", "top_center": Vector3(-19.8, 0.0, -3.75), "size": Vector3(1.0, 0.6, 9.5)},
	{"name": &"Dock05BomberBridge", "top_center": Vector3(13.3, 0.02, -22.8), "size": Vector3(13.4, 0.6, 1.0)},
	{"name": &"BomberBerthLeg", "top_center": Vector3(25.35, 0.0, -22.8), "size": Vector3(10.7, 0.6, 1.0)},
	{"name": &"BomberBoardingLeg", "top_center": Vector3(30.2, 0.0, -20.65), "size": Vector3(1.0, 0.6, 5.3)},
	{"name": &"InterceptorBoardingToe", "top_center": Vector3(-2.7, 0.0, 34.0), "size": Vector3(0.6, 0.6, 1.0)},
]
const ACCESS_GROSS_HORIZONTAL_M2 := 57.4
const ACCESS_UNIQUE_HORIZONTAL_M2 := 55.4
const ACCESS_SUPPORT_MESH_COUNT := 11
const MAX_STATIC_BODIES := 6
const MAX_MESH_INSTANCES := 38
const EXPECTED_STATIC_BODIES := 6
const EXPECTED_COLLISION_SHAPES := 6
const EXPECTED_MESH_INSTANCES := 21
const EXPECTED_MULTIMESH_INSTANCES := 3
const EXPECTED_RENDERER_NODES := 24
const EXPECTED_WAYFINDING_MESH_INSTANCES := 1
const EXPECTED_WAYFINDING_LABELS := 1
const EXPECTED_WAYFINDING_BOXES := 14
const EXPECTED_SERVICE_MESH_INSTANCES := 14
const EXPECTED_SERVICE_RENDERER_NODES := 11
const EXPECTED_SERVICE_MESH_RESOURCE_ALLOCATIONS := 11
const EXPECTED_COMPONENT_MESH_RESOURCE_ALLOCATIONS := 24
const EXPECTED_GUIDE_LIGHTS := 5
const EXPECTED_DESCENDANTS := 59
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
	&"dock_04_cargo": "CARGO HAULER",
	&"dock_05_bomber": "BOMBER",
	&"dock_06_interceptor": "INTERCEPTOR",
}
const PAD_MARKER_MATERIAL_KEYS := {
	&"dock_04_cargo": "cargo_marker",
	&"dock_05_bomber": "bomber_marker",
	&"dock_06_interceptor": "interceptor_marker",
}
## Reuse each pad's live availability sign as its ground-level boarding fascia.
## Positions are pad-local but resolve 35 mm proud of the approach-side vertical
## face of the named collision-backed bridge. The three different rotations face
## the real on-foot approach rather than assuming every berth shares an axis.
const PAD_BOARDING_FASCIA_SPECS := {
	&"dock_04_cargo": {
		"position": Vector3(-3.4, -0.28, -0.535),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"approach_normal": Vector3.FORWARD,
		"support": &"CargoBoardingLeg",
		"craft_role": &"cargo_hauler",
	},
	&"dock_05_bomber": {
		"position": Vector3(-3.8, -0.28, 0.035),
		"rotation_degrees": Vector3.ZERO,
		"approach_normal": Vector3.BACK,
		"support": &"BomberBoardingLeg",
		"craft_role": &"bomber",
	},
	&"dock_06_interceptor": {
		"position": Vector3(-3.035, -0.28, 0.0),
		"rotation_degrees": Vector3(0.0, -90.0, 0.0),
		"approach_normal": Vector3.LEFT,
		"support": &"InterceptorBoardingToe",
		"craft_role": &"interceptor",
	},
}
const PRESENTATION_NODE_DELTA := 0
const PRESENTATION_LIGHT_DELTA := 0
const PRESENTATION_SUBMISSION_DELTA := 0
const AFT_ROUTE_LEGEND_TEXT := "FLEET EXPANSION // BERTH ASSIGNMENTS\nSOUTH   DOCK 04  CARGO HAULER\nNORTH   DOCK 05  BOMBER\nEAST    DOCK 06  INTERCEPTOR"
const AFT_ROUTE_LEGEND_POSITION := Vector3(7.45, 2.55, -19.55)
const PANEL_SURFACE_SCALE := 0.30
const LAUNCH_RAIL_SIZE := Vector3(1.0, 1.0, 38.0)
const LAUNCH_RAIL_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(-16.0, 0.5, 5.0)),
	Transform3D(Basis.IDENTITY, Vector3(16.0, 0.5, 5.0)),
]
const CARGO_CONTAINER_SIZE := Vector3(7.0, 3.6, 7.0)
const CARGO_CONTAINER_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(18.0, 1.8, -10.0)),
	Transform3D(Basis.IDENTITY, Vector3(18.0, 1.8, 0.0)),
	Transform3D(Basis.IDENTITY, Vector3(18.0, 1.8, 10.0)),
]
const UNDERFRAME_SUPPORT_SIZE := Vector3(0.55, 2.5, 0.55)
const UNDERFRAME_SUPPORT_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(-15.0, -1.75, 0.5)),
	Transform3D(Basis.IDENTITY, Vector3(-5.0, -1.75, 0.5)),
	Transform3D(Basis.IDENTITY, Vector3(-19.8, -1.75, -6.0)),
	Transform3D(Basis.IDENTITY, Vector3(10.0, -1.75, -22.8)),
	Transform3D(Basis.IDENTITY, Vector3(24.0, -1.75, -22.8)),
	Transform3D(Basis.IDENTITY, Vector3(30.2, -1.75, -19.2)),
]

var _pads: Dictionary = {}
var _attachments: Dictionary = {}
var _service_materials: Dictionary = {}
var _built := false
var _pad_presentation_states: Dictionary = {}
var _access_surfaces: Dictionary = {}


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
	_build_access_circulation()


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
		var batches: Array[Node] = []
		var lights: Array[Node] = []
		var local_bounds := AABB()
		var first_bound := true
		var landing_clear := true
		var approach_clear := true
		if service == null:
			errors.append("service presentation missing: %s" % pad_id)
		else:
			meshes = service.find_children("*", "MeshInstance3D", true, false)
			batches = service.find_children("*", "MultiMeshInstance3D", true, false)
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
			for raw_batch in batches:
				var batch := raw_batch as MultiMeshInstance3D
				if batch.multimesh == null or batch.multimesh.mesh == null:
					errors.append("service batch missing: %s" % pad_id)
					continue
				mesh_resource_ids[batch.multimesh.mesh.get_instance_id()] = true
				# RenderingServer transform readback can be identity-only headless, so
				# retain the exact submitted parent-space roster for deterministic
				# clearance and silhouette audits.
				var authored_transforms := batch.get_meta(
					&"authored_instance_transforms", []
				) as Array
				if authored_transforms.size() != batch.multimesh.instance_count:
					errors.append("service batch transform roster drift: %s" % pad_id)
				for authored_transform in authored_transforms:
					var bounds := (
						batch.transform
						* (authored_transform as Transform3D)
						* batch.multimesh.mesh.get_aabb()
					).abs()
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
		var visible_mesh_copies := meshes.size()
		for raw_batch in batches:
			var batch := raw_batch as MultiMeshInstance3D
			if batch.multimesh != null:
				visible_mesh_copies += batch.multimesh.instance_count
		if visible_mesh_copies != int(SERVICE_MESH_COUNTS[pad_id]):
			errors.append("service mesh budget drift: %s" % pad_id)
		var expected_batches := 1 if pad_id in [&"dock_04_cargo", &"dock_06_interceptor"] else 0
		if batches.size() != expected_batches:
			errors.append("service batch roster drift: %s" % pad_id)
		elif pad_id == &"dock_04_cargo":
			var container_batch := batches[0] as MultiMeshInstance3D
			var container_mesh := container_batch.multimesh.mesh as BoxMesh \
				if container_batch.multimesh != null else null
			if container_batch.name != &"CargoContainerBatch" \
					or container_mesh == null \
					or not container_mesh.size.is_equal_approx(CARGO_CONTAINER_SIZE) \
					or container_batch.multimesh.instance_count != CARGO_CONTAINER_TRANSFORMS.size() \
					or container_batch.material_override != _service_materials["cargo_container"] \
					or container_batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
					or not bool(container_batch.get_meta(&"visual_detail_only", false)) \
					or container_batch.get_meta(&"authored_instance_transforms", []) != CARGO_CONTAINER_TRANSFORMS:
				errors.append("cargo container batch recipe drift")
		elif pad_id == &"dock_06_interceptor":
			var rail_batch := batches[0] as MultiMeshInstance3D
			var rail_mesh := rail_batch.multimesh.mesh as BoxMesh \
				if rail_batch.multimesh != null else null
			if rail_batch.name != &"LaunchRailBatch" \
					or rail_mesh == null or not rail_mesh.size.is_equal_approx(LAUNCH_RAIL_SIZE) \
					or rail_batch.multimesh.instance_count != LAUNCH_RAIL_TRANSFORMS.size() \
					or rail_batch.material_override != _service_materials["interceptor_marker"] \
					or rail_batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
					or not bool(rail_batch.get_meta(&"visual_detail_only", false)) \
					or rail_batch.get_meta(&"authored_instance_transforms", []) != LAUNCH_RAIL_TRANSFORMS:
				errors.append("launch rail batch recipe drift")
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
		var marker_key := String(PAD_MARKER_MATERIAL_KEYS[pad_id])
		var marker_material := _service_materials.get(marker_key) as StandardMaterial3D
		if not _is_station_panel_finish(
			marker_material,
			StationSurfaceKit.TRIM_CLEARCOAT,
			StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS
		):
			errors.append("service marker station material drift: %s" % pad_id)
		var expected_landing := PAD_POSITIONS[pad_index] + Vector3(0.0, LANDING_ANCHOR_Y, 0.0)
		var expected_approach := PAD_POSITIONS[pad_index] + APPROACH_OFFSET
		var contract := get_landing_contract(pad_id)
		if (contract.get("landing_anchor", Vector3.INF) as Vector3) != expected_landing \
				or (contract.get("approach_anchor", Vector3.INF) as Vector3) != expected_approach:
			errors.append("service presentation moved landing contract: %s" % pad_id)
		pad_reports[pad_id] = {
			"service_role": SERVICE_ROLES[pad_id],
			"mesh_nodes": meshes.size(),
			"multimesh_nodes": batches.size(),
			"visible_mesh_copies": visible_mesh_copies,
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
		"renderer_nodes_after": EXPECTED_SERVICE_RENDERER_NODES,
		"renderer_node_delta": EXPECTED_SERVICE_RENDERER_NODES - EXPECTED_SERVICE_MESH_INSTANCES,
		"geometry_submissions_before": EXPECTED_SERVICE_MESH_INSTANCES,
		"geometry_submissions_after": EXPECTED_SERVICE_RENDERER_NODES,
		"geometry_submission_delta": EXPECTED_SERVICE_RENDERER_NODES - EXPECTED_SERVICE_MESH_INSTANCES,
		"visible_mesh_copies": EXPECTED_SERVICE_MESH_INSTANCES,
		"mesh_resource_allocations_before": 12,
		"mesh_resource_allocations_after": mesh_resource_ids.size(),
		"mesh_resource_delta": mesh_resource_ids.size() - 12,
		"budgets": {
			"mesh_instances": EXPECTED_MESH_INSTANCES,
			"multimesh_instances": EXPECTED_MULTIMESH_INSTANCES,
			"renderer_nodes": EXPECTED_RENDERER_NODES,
			"mesh_resource_allocations": EXPECTED_COMPONENT_MESH_RESOURCE_ALLOCATIONS,
			"service_mesh_resource_allocations": EXPECTED_SERVICE_MESH_RESOURCE_ALLOCATIONS,
			"guide_lights": EXPECTED_GUIDE_LIGHTS,
			"descendants": EXPECTED_DESCENDANTS,
			"static_bodies": EXPECTED_STATIC_BODIES,
			"collision_shapes": EXPECTED_COLLISION_SHAPES,
		},
		"ship_authority": false,
		"berth_lease_authority": false,
		"interaction_authority": false,
	}.duplicate(true)


## Reports the production walking structure itself. This is intentionally a
## small topology contract: seven physical surfaces, one shared underframe, and
## no overlap with any landing or final-approach envelope.
func get_access_circulation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var projection_rects: Array[Rect2] = []
	var gross_horizontal_m2 := 0.0
	var circulation := get_node_or_null(^"AccessCirculation") as Node3D
	var underframe := circulation.get_node_or_null(^"SupportedUnderframe") as Node3D \
		if circulation != null else null
	var bodies: Array[Node] = []
	var shapes: Array[Node] = []
	var meshes: Array[Node] = []
	if circulation == null:
		errors.append("access circulation missing")
	else:
		bodies = circulation.find_children("*", "StaticBody3D", true, false)
		shapes = circulation.find_children("*", "CollisionShape3D", true, false)
		meshes = circulation.find_children("*", "MeshInstance3D", true, false)
	for surface_name in ACCESS_SURFACE_NAMES:
		var body := circulation.get_node_or_null(NodePath(String(surface_name))) as StaticBody3D \
			if circulation != null else null
		var authored := _access_surfaces.get(surface_name, {}) as Dictionary
		if body == null or authored.is_empty():
			errors.append("access surface missing: %s" % surface_name)
			continue
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		var surface := body.get_node_or_null(^"Surface") as MeshInstance3D
		var expected_transform := authored.get("transform", Transform3D.IDENTITY) as Transform3D
		var expected_size := authored.get("size", Vector3.ZERO) as Vector3
		var topology := authored.get("topology", &"box") as StringName
		if not body.transform.is_equal_approx(expected_transform):
			errors.append("access surface transform drift: %s" % surface_name)
		var collision_valid := collision != null and not collision.disabled \
			and collision.transform.is_equal_approx(Transform3D.IDENTITY)
		var render_valid := surface != null \
			and surface.transform.is_equal_approx(Transform3D.IDENTITY)
		if topology == &"tapered_prism":
			var expected_bounds := authored.get("local_bounds", AABB()) as AABB
			collision_valid = collision_valid and collision.shape is ConvexPolygonShape3D \
				and _points_aabb((collision.shape as ConvexPolygonShape3D).points).is_equal_approx(expected_bounds)
			render_valid = render_valid and surface.mesh is ArrayMesh \
				and surface.mesh.get_aabb().is_equal_approx(expected_bounds)
		elif topology == &"transition_plate":
			var expected_bounds := authored.get("local_bounds", AABB()) as AABB
			collision_valid = collision_valid and collision.shape is ConcavePolygonShape3D \
				and _flat_bounds_match(_points_aabb((collision.shape as ConcavePolygonShape3D).get_faces()), expected_bounds)
			render_valid = render_valid and surface.mesh is ArrayMesh \
				and _flat_bounds_match(surface.mesh.get_aabb(), expected_bounds)
		else:
			collision_valid = collision_valid and collision.shape is BoxShape3D \
				and (collision.shape as BoxShape3D).size.is_equal_approx(expected_size)
			render_valid = render_valid and surface.mesh is BoxMesh \
				and (surface.mesh as BoxMesh).size.is_equal_approx(expected_size)
		if not collision_valid:
			errors.append("access surface collision drift: %s" % surface_name)
		if not render_valid:
			errors.append("access surface render drift: %s" % surface_name)
		var expected_id := StringName("fleet-expansion-" + String(surface_name).to_snake_case())
		if body.collision_layer != WORLD_LAYER or body.collision_mask != 0 \
				or not bool(body.get_meta(&"walkable_surface", false)) \
				or StringName(body.get_meta(&"walkable_surface_id", &"")) != expected_id \
				or StringName(body.get_meta(&"walkable_surface_kind", &"")) != &"level" \
				or StringName(body.get_meta(&"walkable_surface_owner", &"")) != COMPONENT_ID:
			errors.append("access surface world ownership drift: %s" % surface_name)
		if collision != null and collision.shape is BoxShape3D:
			var live_size := (collision.shape as BoxShape3D).size
			gross_horizontal_m2 += live_size.x * live_size.z
			projection_rects.append(Rect2(
				Vector2(body.position.x - live_size.x * 0.5, body.position.z - live_size.z * 0.5),
				Vector2(live_size.x, live_size.z)
			))
	if bodies.size() != ACCESS_SURFACE_NAMES.size() or shapes.size() != ACCESS_SURFACE_NAMES.size():
		errors.append("access collision roster drift")
	var support_meshes: Array[Node] = []
	var support_batches: Array[Node] = []
	var support_visual_copies := 0
	if underframe == null:
		errors.append("access supported underframe missing")
	else:
		support_meshes = underframe.find_children("*", "MeshInstance3D", true, false)
		support_batches = underframe.find_children("*", "MultiMeshInstance3D", true, false)
		support_visual_copies = support_meshes.size()
		for raw_batch in support_batches:
			var batch := raw_batch as MultiMeshInstance3D
			if batch.multimesh != null:
				support_visual_copies += batch.multimesh.instance_count
		if support_visual_copies != ACCESS_SUPPORT_MESH_COUNT:
			errors.append("access support roster drift")
		if support_batches.size() != 1:
			errors.append("access support batch roster drift")
		else:
			var post_batch := support_batches[0] as MultiMeshInstance3D
			var post_mesh := post_batch.multimesh.mesh as BoxMesh \
				if post_batch.multimesh != null else null
			if post_batch.name != &"UnderframeSupportBatch" \
					or post_mesh == null or not post_mesh.size.is_equal_approx(UNDERFRAME_SUPPORT_SIZE) \
					or post_batch.multimesh.instance_count != UNDERFRAME_SUPPORT_TRANSFORMS.size() \
					or post_batch.material_override != _service_materials["access_support"] \
					or post_batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
					or not bool(post_batch.get_meta(&"visual_detail_only", false)) \
					or post_batch.get_meta(&"authored_instance_transforms", []) != UNDERFRAME_SUPPORT_TRANSFORMS:
				errors.append("access support batch recipe drift")
		if not underframe.find_children("*", "CollisionObject3D", true, false).is_empty() \
				or not underframe.find_children("*", "CollisionShape3D", true, false).is_empty():
			errors.append("access underframe gained collision")
	var unique_horizontal_m2 := _axis_aligned_rect_union_area(projection_rects)
	if not is_equal_approx(gross_horizontal_m2, ACCESS_GROSS_HORIZONTAL_M2):
		errors.append("access gross walkable area drift")
	if not is_equal_approx(unique_horizontal_m2, ACCESS_UNIQUE_HORIZONTAL_M2):
		errors.append("access unique walkable area drift")
	var envelopes_clear := true
	if circulation != null:
		for raw_body in circulation.find_children("*", "StaticBody3D", true, false):
			var route_body := raw_body as StaticBody3D
			var collision := route_body.get_node_or_null(^"Collision") as CollisionShape3D
			if collision == null or collision.disabled or collision.shape is not BoxShape3D:
				continue
			var size := (collision.shape as BoxShape3D).size
			var bounds := (collision.global_transform * AABB(-size * 0.5, size)).abs()
			for pad_index in PAD_IDS.size():
				var pad := get_node_or_null(NodePath(String(PAD_IDS[pad_index]))) as Node3D
				if pad == null:
					continue
				var landing_bounds := (pad.global_transform * LANDING_VISUAL_CLEARANCE).abs()
				var approach_bounds := (pad.global_transform * APPROACH_VISUAL_CLEARANCE).abs()
				if _aabbs_have_positive_overlap(bounds, landing_bounds) \
						or _aabbs_have_positive_overlap(bounds, approach_bounds):
					envelopes_clear = false
	if not envelopes_clear:
		errors.append("access circulation entered landing or approach clearance")
	var wayfinding := get_access_wayfinding_audit()
	if not bool(wayfinding.get("valid", false)):
		for error in (wayfinding.get("errors", PackedStringArray()) as PackedStringArray):
			errors.append("wayfinding: %s" % error)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"surface_names": ACCESS_SURFACE_NAMES.duplicate(),
		"static_bodies": bodies.size(),
		"collision_shapes": shapes.size(),
		"surface_meshes": meshes.size() - support_meshes.size() - EXPECTED_WAYFINDING_MESH_INSTANCES,
		"support_meshes": support_visual_copies,
		"support_renderer_nodes": support_meshes.size() + support_batches.size(),
		"wayfinding": wayfinding,
		"envelopes_clear": envelopes_clear,
		"gross_horizontal_m2": snappedf(gross_horizontal_m2, 0.000001),
		"unique_horizontal_m2": snappedf(unique_horizontal_m2, 0.000001),
		"shared_spine": false,
		"world_collision_backed": true,
	}.duplicate(true)


func get_access_wayfinding_audit() -> Dictionary:
	var errors := PackedStringArray()
	var circulation := get_node_or_null(^"AccessCirculation") as Node3D
	var route_mesh := circulation.get_node_or_null(^"BerthRouteEdgeTreatment") as MeshInstance3D \
		if circulation != null else null
	var legend := circulation.get_node_or_null(^"AftJunctionRouteLegend") as Label3D \
		if circulation != null else null
	var expected_grammars := {
		&"dock_04_cargo": &"square_cargo_cradle",
		&"dock_05_bomber": &"swept_bomber_chevron",
		&"dock_06_interceptor": &"straight_launch_spear",
	}
	if route_mesh == null or route_mesh.mesh is not ArrayMesh:
		errors.append("batched route edge treatment missing")
	else:
		var bounds := route_mesh.mesh.get_aabb()
		var budget_bounds := AABB(Vector3(-20.5, -0.001, -23.25), Vector3(51.5, 0.1, 58.25))
		if route_mesh.mesh.get_surface_count() != 1 \
				or route_mesh.material_override != _service_materials["access_support"] \
				or not budget_bounds.encloses(bounds):
			errors.append("route edge treatment geometry or material drift")
		if int(route_mesh.get_meta(&"batched_box_count", -1)) != EXPECTED_WAYFINDING_BOXES \
				or route_mesh.get_meta(&"route_cue_grammars", {}) != expected_grammars \
				or not bool(route_mesh.get_meta(&"manufactured_edge_treatment", false)):
			errors.append("route shape grammar drift")
	if legend == null or legend.text != AFT_ROUTE_LEGEND_TEXT \
			or not legend.position.is_equal_approx(AFT_ROUTE_LEGEND_POSITION) \
			or legend.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
		errors.append("Aft junction route legend drift")
	if circulation != null and (
		circulation.find_children("*", "MeshInstance3D", true, false).filter(
			func(node: Node) -> bool: return node.name == &"BerthRouteEdgeTreatment"
		).size() != EXPECTED_WAYFINDING_MESH_INSTANCES
		or circulation.find_children("*", "Label3D", true, false).filter(
			func(node: Node) -> bool: return node.name == &"AftJunctionRouteLegend"
		).size() != EXPECTED_WAYFINDING_LABELS
	):
		errors.append("wayfinding renderer roster drift")
	if route_mesh != null and (
		not route_mesh.find_children("*", "CollisionObject3D", true, false).is_empty()
		or not route_mesh.find_children("*", "CollisionShape3D", true, false).is_empty()
	):
		errors.append("wayfinding gained collision")
	var fascia_reports: Dictionary = {}
	for pad_id in PAD_IDS:
		var pad := get_node_or_null(NodePath(String(pad_id))) as Node3D
		var sign := pad.get_node_or_null(^"PadSign") as Label3D if pad != null else null
		var spec := PAD_BOARDING_FASCIA_SPECS[pad_id] as Dictionary
		var expected_normal := spec.get("approach_normal", Vector3.ZERO) as Vector3
		var facing_normal := sign.basis.z.normalized() if sign != null else Vector3.ZERO
		var fascia_valid := sign != null \
			and sign.position.is_equal_approx(spec.get("position", Vector3.INF) as Vector3) \
			and sign.rotation_degrees.is_equal_approx(
				spec.get("rotation_degrees", Vector3.INF) as Vector3
			) \
			and facing_normal.dot(expected_normal) > 0.999 \
			and StringName(sign.get_meta(&"pad_id", &"")) == pad_id \
			and StringName(sign.get_meta(&"craft_role", &"")) \
				== StringName(spec.get("craft_role", &"")) \
			and StringName(sign.get_meta(&"supported_by", &"")) \
				== StringName(spec.get("support", &"")) \
			and StringName(sign.get_meta(&"boarding_orientation", &"")) == &"ahead" \
			and bool(sign.get_meta(&"non_authoritative_presentation", false)) \
			and sign.font_size == 30 and is_equal_approx(sign.pixel_size, 0.007) \
			and sign.outline_size == 6 and not sign.no_depth_test \
			and sign.get_child_count() == 0 and sign.get_script() == null
		if not fascia_valid:
			errors.append("boarding fascia transform or identity drift: %s" % pad_id)
		fascia_reports[pad_id] = {
			"craft_role": spec.get("craft_role", &""),
			"support": spec.get("support", &""),
			"approach_normal": expected_normal,
			"facing_normal": facing_normal,
			"supported_clearance_m": 0.035,
			"approach_facing": facing_normal.dot(expected_normal) > 0.999,
		}.duplicate(true)
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"cue_grammars": expected_grammars,
		"manufactured_edge_treatment": route_mesh != null,
		"mesh_instances": EXPECTED_WAYFINDING_MESH_INSTANCES,
		"mesh_surfaces": route_mesh.mesh.get_surface_count() if route_mesh != null and route_mesh.mesh != null else 0,
		"labels": EXPECTED_WAYFINDING_LABELS,
		"boarding_fascias": fascia_reports,
		"boarding_fascia_labels": PAD_IDS.size(),
		"boarding_fascia_roster_delta": 0,
		"lights": 0,
		"collision_shapes": 0,
		"ship_authority": false,
		"berth_lease_authority": false,
		"interaction_authority": false,
	}.duplicate(true)


func _points_aabb(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _flat_bounds_match(actual: AABB, expected: AABB) -> bool:
	return absf(actual.position.x - expected.position.x) <= 0.0001 \
		and absf(actual.position.z - expected.position.z) <= 0.0001 \
		and absf(actual.size.x - expected.size.x) <= 0.0001 \
		and absf(actual.size.z - expected.size.z) <= 0.0001 \
		and absf(actual.position.y - expected.position.y) <= 0.0001 \
		and actual.size.y <= 0.0001


func _aabbs_have_positive_overlap(first: AABB, second: AABB) -> bool:
	return minf(first.end.x, second.end.x) - maxf(first.position.x, second.position.x) > 0.001 \
		and minf(first.end.y, second.end.y) - maxf(first.position.y, second.position.y) > 0.001 \
		and minf(first.end.z, second.end.z) - maxf(first.position.z, second.position.z) > 0.001


func _axis_aligned_rect_union_area(rects: Array[Rect2]) -> float:
	var x_values := PackedFloat32Array()
	for rect in rects:
		x_values.append(rect.position.x)
		x_values.append(rect.end.x)
	x_values.sort()
	var area := 0.0
	for x_index in range(x_values.size() - 1):
		var x_min := x_values[x_index]
		var x_max := x_values[x_index + 1]
		if x_max - x_min <= 0.000001:
			continue
		var z_intervals: Array[Vector2] = []
		for rect in rects:
			if rect.position.x < x_max - 0.000001 and rect.end.x > x_min + 0.000001:
				z_intervals.append(Vector2(rect.position.y, rect.end.y))
		z_intervals.sort_custom(func(left: Vector2, right: Vector2) -> bool: return left.x < right.x)
		var covered_z := 0.0
		var active := Vector2.ZERO
		var has_active := false
		for interval in z_intervals:
			if not has_active:
				active = interval
				has_active = true
			elif interval.x <= active.y + 0.000001:
				active.y = maxf(active.y, interval.y)
			else:
				covered_z += active.y - active.x
				active = interval
		if has_active:
			covered_z += active.y - active.x
		area += (x_max - x_min) * covered_z
	return area


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if PAD_IDS.size() != 3 or _pads.size() != 3:
		errors.append("exactly three authored expansion pads are required")
	var bodies := find_children("*", "StaticBody3D", true, false).size()
	var mesh_nodes := find_children("*", "MeshInstance3D", true, false)
	var meshes := mesh_nodes.size()
	var multimesh_nodes := find_children("*", "MultiMeshInstance3D", true, false)
	var renderer_nodes := meshes + multimesh_nodes.size()
	var mesh_resource_ids := {}
	for raw_mesh in mesh_nodes:
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			mesh_resource_ids[mesh_instance.mesh.get_instance_id()] = true
	for raw_batch in multimesh_nodes:
		var batch := raw_batch as MultiMeshInstance3D
		if batch != null and batch.multimesh != null and batch.multimesh.mesh != null:
			mesh_resource_ids[batch.multimesh.mesh.get_instance_id()] = true
	var collision_shapes := find_children("*", "CollisionShape3D", true, false).size()
	var guide_lights := find_children("*", "OmniLight3D", true, false).size()
	var descendants := find_children("*", "", true, false).size()
	if bodies > MAX_STATIC_BODIES:
		errors.append("static body budget exceeded")
	if renderer_nodes > MAX_MESH_INSTANCES:
		errors.append("mesh budget exceeded")
	if bodies != EXPECTED_STATIC_BODIES or collision_shapes != EXPECTED_COLLISION_SHAPES:
		errors.append("walkable collision roster drift")
	if meshes != EXPECTED_MESH_INSTANCES \
			or multimesh_nodes.size() != EXPECTED_MULTIMESH_INSTANCES \
			or renderer_nodes != EXPECTED_RENDERER_NODES \
			or guide_lights != EXPECTED_GUIDE_LIGHTS \
			or descendants != EXPECTED_DESCENDANTS:
		errors.append("service presentation census drift")
	if mesh_resource_ids.size() != EXPECTED_COMPONENT_MESH_RESOURCE_ALLOCATIONS:
		errors.append("whole-component mesh resource census drift")
	var service_presentation := get_service_presentation_audit()
	if not bool(service_presentation.get("valid", false)):
		for error in (service_presentation.get("errors", PackedStringArray()) as PackedStringArray):
			errors.append("service presentation: %s" % error)
	var access_circulation := get_access_circulation_audit()
	if not bool(access_circulation.get("valid", false)):
		for error in (access_circulation.get("errors", PackedStringArray()) as PackedStringArray):
			errors.append("access circulation: %s" % error)
	for pad_id in PAD_IDS:
		var contract := get_landing_contract(pad_id)
		if not bool(contract.get("accepted", false)):
			errors.append("missing landing contract: %s" % pad_id)
	for pad_id in PAD_IDS:
		var pad := get_node_or_null(NodePath(String(pad_id))) as Node3D
		if pad == null:
			errors.append("logical pad missing: %s" % pad_id)
			continue
		if pad.get_node_or_null(^"WalkablePadCollision") != null \
				or not pad.find_children("ServicePadSurface*", "MeshInstance3D", true, false).is_empty() \
				or not pad.find_children("*", "StaticBody3D", true, false).is_empty() \
				or not pad.find_children("*", "CollisionShape3D", true, false).is_empty():
			errors.append("logical pad regained broad collision or render: %s" % pad_id)
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
		"multimesh_instances": multimesh_nodes.size(),
		"renderer_nodes": renderer_nodes,
		"mesh_resource_allocations": mesh_resource_ids.size(),
		"service_mesh_resource_allocations": int(
			service_presentation.get("mesh_resource_allocations_after", -1)
		),
		"collision_shapes": collision_shapes,
		"guide_lights": guide_lights,
		"descendants": descendants,
		"service_presentation": service_presentation,
		"access_circulation": access_circulation,
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
	sign.text = "DOCK %02d  %s" % [index + 4, String(PAD_ROLE_LABELS[pad_id])]
	var fascia_spec := PAD_BOARDING_FASCIA_SPECS[pad_id] as Dictionary
	sign.position = fascia_spec.get("position", Vector3.ZERO) as Vector3
	sign.rotation_degrees = fascia_spec.get("rotation_degrees", Vector3.ZERO) as Vector3
	sign.font_size = 30
	sign.pixel_size = 0.007
	sign.outline_size = 6
	sign.modulate = Color("63dbe0")
	sign.outline_modulate = Color("071b1d")
	sign.no_depth_test = false
	sign.set_meta(&"ground_level_boarding_fascia", true)
	sign.set_meta(&"pad_id", pad_id)
	sign.set_meta(&"craft_role", fascia_spec.get("craft_role", &""))
	sign.set_meta(&"supported_by", fascia_spec.get("support", &""))
	sign.set_meta(&"boarding_orientation", &"ahead")
	sign.set_meta(&"non_authoritative_presentation", true)
	pad.add_child(sign)
	_build_service_presentation(pad, pad_id)
	_pads[pad_id] = {
		"pad_id": pad_id,
		"landing_anchor": landing.global_position,
		"approach_anchor": route.global_position,
		"position": pad_position,
		"size": PAD_SIZE,
	}
func _build_access_circulation() -> void:
	var circulation := Node3D.new()
	circulation.name = "AccessCirculation"
	circulation.set_meta(&"component_id", &"fleet-expansion-pedestrian-access")
	circulation.set_meta(&"connects_existing_module", &"fleet-dock-comb")
	add_child(circulation)

	for spec in ACCESS_SURFACE_SPECS:
		_add_access_level(
			circulation, spec.name, spec.top_center as Vector3, spec.size as Vector3
		)
	_build_access_underframe(circulation)
	_build_access_wayfinding(circulation)


## One batched, non-colliding metal inlay supplies a continuous manufactured
## edge read and three silhouette-distinct threshold glyphs. The square cargo
## cradle, bomber chevron, and interceptor spear remain legible when their
## shared station-family material is rendered without colour.
func _build_access_wayfinding(circulation: Node3D) -> void:
	var boxes := [
		{"centre": Vector3(-11.35, 0.035, 0.18), "size": Vector3(17.5, 0.07, 0.10)},
		{"centre": Vector3(-11.35, 0.035, 0.82), "size": Vector3(17.5, 0.07, 0.10)},
		{"centre": Vector3(-20.12, 0.035, -3.75), "size": Vector3(0.10, 0.07, 8.9)},
		{"centre": Vector3(-19.48, 0.035, -3.75), "size": Vector3(0.10, 0.07, 8.9)},
		{"centre": Vector3(18.65, 0.055, -23.12), "size": Vector3(23.7, 0.07, 0.10)},
		{"centre": Vector3(18.65, 0.055, -22.48), "size": Vector3(23.7, 0.07, 0.10)},
		{"centre": Vector3(29.88, 0.035, -20.65), "size": Vector3(0.10, 0.07, 4.7)},
		{"centre": Vector3(30.52, 0.035, -20.65), "size": Vector3(0.10, 0.07, 4.7)},
		# Square, chevron, and spear make the three endpoints colour-independent.
		{"centre": Vector3(-19.8, 0.035, -8.12), "size": Vector3(0.62, 0.07, 0.10)},
		{"centre": Vector3(30.0, 0.035, -18.35), "size": Vector3(0.62, 0.07, 0.10), "yaw": -PI * 0.25},
		{"centre": Vector3(30.4, 0.035, -18.35), "size": Vector3(0.62, 0.07, 0.10), "yaw": PI * 0.25},
		{"centre": Vector3(-2.7, 0.035, 34.0), "size": Vector3(0.38, 0.07, 0.10)},
		{"centre": Vector3(-2.86, 0.035, 33.86), "size": Vector3(0.30, 0.07, 0.10), "yaw": PI * 0.25},
		{"centre": Vector3(-2.86, 0.035, 34.14), "size": Vector3(0.30, 0.07, 0.10), "yaw": -PI * 0.25},
	]
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for spec in boxes:
		_append_wayfinding_box(
			builder,
			spec.get("centre", Vector3.ZERO) as Vector3,
			spec.get("size", Vector3.ZERO) as Vector3,
			float(spec.get("yaw", 0.0))
		)
	builder.generate_normals()
	var route_mesh := MeshInstance3D.new()
	route_mesh.name = "BerthRouteEdgeTreatment"
	route_mesh.mesh = builder.commit()
	route_mesh.material_override = _service_materials["access_support"]
	route_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	route_mesh.set_meta(&"presentation_only", true)
	route_mesh.set_meta(&"non_authoritative_visual", true)
	route_mesh.set_meta(&"non_walkable_reason", "thin manufactured route inlay over the six authoritative access boxes")
	route_mesh.set_meta(&"manufactured_edge_treatment", true)
	route_mesh.set_meta(&"route_cue_grammars", {
		&"dock_04_cargo": &"square_cargo_cradle",
		&"dock_05_bomber": &"swept_bomber_chevron",
		&"dock_06_interceptor": &"straight_launch_spear",
	})
	route_mesh.set_meta(&"batched_box_count", boxes.size())
	circulation.add_child(route_mesh)

	var legend := Label3D.new()
	legend.name = "AftJunctionRouteLegend"
	legend.text = AFT_ROUTE_LEGEND_TEXT
	legend.position = AFT_ROUTE_LEGEND_POSITION
	legend.font_size = 28
	legend.outline_size = 7
	legend.pixel_size = 0.009
	legend.modulate = Color("d5e5e4")
	legend.outline_modulate = Color("15252d")
	legend.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	legend.set_meta(&"presentation_only", true)
	legend.set_meta(&"viewpoint", &"aft_junction_and_on_foot_approach")
	circulation.add_child(legend)


func _append_wayfinding_box(
	builder: SurfaceTool, centre: Vector3, size: Vector3, yaw: float
	) -> void:
	var half := size * 0.5
	var basis := Basis(Vector3.UP, yaw)
	var corners := PackedVector3Array([
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, half.z), Vector3(-half.x, -half.y, half.z),
		Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z),
		Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z),
	])
	for corner_index in corners.size():
		corners[corner_index] = basis * corners[corner_index] + centre
	var indices := PackedInt32Array([
		0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
		0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5,
		2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7,
	])
	for index in indices:
		builder.add_vertex(corners[index])


func _add_access_level(
		parent: Node3D, surface_name: StringName, top_centre: Vector3, size: Vector3
	) -> void:
	var transform := Transform3D(
		Basis.IDENTITY, top_centre - Vector3.UP * size.y * 0.5
	)
	_add_access_surface(parent, surface_name, transform, size, &"level")


## The production capsule catches on a vertical face when two independently
## owned coplanar boxes merely touch. This prism has a flat walkable top but its
## underside tapers to that leading edge, so the Aft-floor handoff owns neither
## overlap nor a capsule-height wall.
func _add_tapered_access_level(
		parent: Node3D, surface_name: StringName, top_centre: Vector3, size: Vector3
	) -> void:
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	var taper_run := 0.5
	var points := PackedVector3Array([
		Vector3(-half_x, 0.0, -half_z), Vector3(half_x, 0.0, -half_z),
		Vector3(half_x, 0.0, half_z), Vector3(-half_x, 0.0, half_z),
		Vector3(-half_x + taper_run, -size.y, -half_z),
		Vector3(half_x, -size.y, -half_z),
		Vector3(half_x, -size.y, half_z),
		Vector3(-half_x + taper_run, -size.y, half_z),
	])
	var body := StaticBody3D.new()
	body.name = String(surface_name)
	body.position = top_centre
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.set_meta(&"walkable_surface", true)
	body.set_meta(&"walkable_surface_id", StringName("fleet-expansion-" + String(surface_name).to_snake_case()))
	body.set_meta(&"walkable_surface_kind", &"level")
	body.set_meta(&"walkable_surface_owner", COMPONENT_ID)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	surface.mesh = _tapered_prism_mesh(points)
	surface.material_override = _service_materials["access_deck"]
	body.add_child(surface)
	_access_surfaces[surface_name] = {
		"transform": body.transform,
		"size": size,
		"kind": &"level",
		"topology": &"tapered_prism",
		"local_bounds": AABB(Vector3(-half_x, -size.y, -half_z), size),
	}.duplicate(true)


func _add_access_transition_plate(
		parent: Node3D, surface_name: StringName, top_centre: Vector3, size: Vector2
	) -> void:
	var half_x := size.x * 0.5
	var half_z := size.y * 0.5
	var corners := PackedVector3Array([
		Vector3(-half_x, 0.0, -half_z), Vector3(half_x, 0.0, -half_z),
		Vector3(half_x, 0.0, half_z), Vector3(-half_x, 0.0, half_z),
	])
	var faces := PackedVector3Array([
		corners[0], corners[1], corners[2],
		corners[0], corners[2], corners[3],
	])
	var body := StaticBody3D.new()
	body.name = String(surface_name)
	body.position = top_centre
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.set_meta(&"walkable_surface", true)
	body.set_meta(&"walkable_surface_id", StringName("fleet-expansion-" + String(surface_name).to_snake_case()))
	body.set_meta(&"walkable_surface_kind", &"level_transition")
	body.set_meta(&"walkable_surface_owner", COMPONENT_ID)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collision.shape = shape
	body.add_child(collision)
	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in faces:
		builder.add_vertex(point)
	builder.generate_normals()
	surface.mesh = builder.commit()
	surface.material_override = _service_materials["access_deck"]
	body.add_child(surface)
	_access_surfaces[surface_name] = {
		"transform": body.transform,
		"kind": &"level_transition",
		"topology": &"transition_plate",
		"local_bounds": AABB(Vector3(-half_x, 0.0, -half_z), Vector3(size.x, 0.0, size.y)),
	}.duplicate(true)


func _tapered_prism_mesh(points: PackedVector3Array) -> ArrayMesh:
	var indices := PackedInt32Array([
		0, 3, 2, 0, 2, 1,
		4, 5, 6, 4, 6, 7,
		0, 1, 5, 0, 5, 4,
		1, 2, 6, 1, 6, 5,
		2, 3, 7, 2, 7, 6,
		3, 0, 4, 3, 4, 7,
	])
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		builder.add_vertex(points[index])
	builder.generate_normals()
	return builder.commit()


func _add_access_surface(
		parent: Node3D, surface_name: StringName, surface_transform: Transform3D,
		size: Vector3, kind: StringName
	) -> void:
	var body := StaticBody3D.new()
	body.name = String(surface_name)
	body.transform = surface_transform
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.set_meta(&"walkable_surface", true)
	body.set_meta(&"walkable_surface_id", StringName("fleet-expansion-" + String(surface_name).to_snake_case()))
	body.set_meta(&"walkable_surface_kind", kind)
	body.set_meta(&"walkable_surface_owner", COMPONENT_ID)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	var mesh := BoxMesh.new()
	mesh.size = size
	surface.mesh = mesh
	surface.material_override = _service_materials["access_deck"]
	body.add_child(surface)
	_access_surfaces[surface_name] = {
		"transform": surface_transform,
		"size": size,
		"kind": kind,
	}.duplicate(true)


func _build_access_underframe(circulation: Node3D) -> void:
	var underframe := Node3D.new()
	underframe.name = "SupportedUnderframe"
	underframe.set_meta(&"presentation_only", true)
	underframe.set_meta(&"structurally_supports", &"fleet-expansion-pedestrian-access")
	circulation.add_child(underframe)
	_visual_box(underframe, "CargoTrunkChord", Vector3(-11.35, -1.24, 0.5),
		Vector3(17.5, 1.4, 0.46), _service_materials["access_underframe"])
	_visual_box(underframe, "CargoBoardingChord", Vector3(-19.8, -1.24, -3.75),
		Vector3(0.46, 1.4, 9.1), _service_materials["access_underframe"])
	_visual_box(underframe, "BomberBerthChord", Vector3(18.65, -1.24, -22.8),
		Vector3(23.7, 1.4, 0.46), _service_materials["access_underframe"])
	_visual_box(underframe, "BomberBoardingChord", Vector3(30.2, -1.24, -20.65),
		Vector3(0.46, 1.4, 4.9), _service_materials["access_underframe"])
	_visual_box(underframe, "InterceptorToeChord", Vector3(-2.7, -1.24, 34.0),
		Vector3(0.2, 1.4, 0.6), _service_materials["access_underframe"])
	_build_underframe_support_batch(underframe)


func _build_underframe_support_batch(underframe: Node3D) -> void:
	var post_mesh := BoxMesh.new()
	post_mesh.size = UNDERFRAME_SUPPORT_SIZE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = post_mesh
	multimesh.instance_count = UNDERFRAME_SUPPORT_TRANSFORMS.size()
	multimesh.visible_instance_count = -1
	var batch := MultiMeshInstance3D.new()
	batch.name = "UnderframeSupportBatch"
	batch.multimesh = multimesh
	batch.material_override = _service_materials["access_support"]
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta(&"visual_detail_only", true)
	batch.set_meta(&"visual_batch_family_id", &"access_underframe_support_posts")
	batch.set_meta(&"authored_instance_transforms", UNDERFRAME_SUPPORT_TRANSFORMS.duplicate())
	underframe.add_child(batch)
	for index in UNDERFRAME_SUPPORT_TRANSFORMS.size():
		multimesh.set_instance_transform(index, UNDERFRAME_SUPPORT_TRANSFORMS[index])


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
			_build_cargo_container_batch(service)
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
			_build_launch_rail_batch(service)
			_visual_box(service, "LaunchFramePort", Vector3(-16.0, 5.0, -16.0), Vector3(1.5, 10.0, 1.5), _service_materials["interceptor_frame"])
			_visual_box(service, "LaunchFrameStarboard", Vector3(16.0, 5.0, -16.0), Vector3(1.5, 10.0, 1.5), _service_materials["interceptor_frame"])
			_visual_box(service, "LaunchFrameHeader", Vector3(0.0, 10.0, -16.0), Vector3(33.5, 1.0, 1.5), _service_materials["interceptor_frame"])
			_guide_light(service, "LaunchGuidePort", Vector3(-16.0, 1.2, 24.0), Color("61e4ee"))
			_guide_light(service, "LaunchGuideStarboard", Vector3(16.0, 1.2, 24.0), Color("61e4ee"))


func _build_launch_rail_batch(service: Node3D) -> void:
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = LAUNCH_RAIL_SIZE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = rail_mesh
	multimesh.instance_count = LAUNCH_RAIL_TRANSFORMS.size()
	multimesh.visible_instance_count = -1
	var batch := MultiMeshInstance3D.new()
	batch.name = "LaunchRailBatch"
	batch.multimesh = multimesh
	batch.material_override = _service_materials["interceptor_marker"]
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta(&"visual_detail_only", true)
	batch.set_meta(&"visual_batch_family_id", &"dock_06_launch_rails")
	batch.set_meta(&"authored_instance_transforms", LAUNCH_RAIL_TRANSFORMS.duplicate())
	service.add_child(batch)
	multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(-16.0, 0.5, 5.0)))
	multimesh.set_instance_transform(1, Transform3D(Basis.IDENTITY, Vector3(16.0, 0.5, 5.0)))


func _build_cargo_container_batch(service: Node3D) -> void:
	var container_mesh := BoxMesh.new()
	container_mesh.size = CARGO_CONTAINER_SIZE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = container_mesh
	multimesh.instance_count = CARGO_CONTAINER_TRANSFORMS.size()
	multimesh.visible_instance_count = -1
	var batch := MultiMeshInstance3D.new()
	batch.name = "CargoContainerBatch"
	batch.multimesh = multimesh
	batch.material_override = _service_materials["cargo_container"]
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta(&"visual_detail_only", true)
	batch.set_meta(&"visual_batch_family_id", &"dock_04_cargo_containers")
	batch.set_meta(&"authored_instance_transforms", CARGO_CONTAINER_TRANSFORMS.duplicate())
	service.add_child(batch)
	for index in CARGO_CONTAINER_TRANSFORMS.size():
		multimesh.set_instance_transform(index, CARGO_CONTAINER_TRANSFORMS[index])


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
		"pad_deck": _panel_material(
			Color("334b55"), 0.7, StationSurfaceKit.PanelFinish.WALKED_DECK
		),
		"cargo_frame": _panel_material(
			Color("8a6a36"), 0.72, StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY
		),
		"cargo_container": _panel_material(
			Color("2f5966"), 0.58, StationSurfaceKit.PanelFinish.PAINTED_METAL
		),
		"cargo_marker": _emissive_material(Color("56d8de")),
		"bomber_frame": _panel_material(
			Color("3b3034"), 0.78, StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY
		),
		"bomber_marker": _emissive_material(Color("ff8b42")),
		"interceptor_frame": _panel_material(
			Color("31515b"), 0.74, StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY
		),
		"interceptor_marker": _emissive_material(Color("61e4ee")),
		"access_deck": _panel_material(
			Color("39545d"), 0.68, StationSurfaceKit.PanelFinish.WALKED_DECK
		),
		"access_underframe": _panel_material(
			Color("263d48"), 0.78, StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY
		),
		"access_support": _panel_material(
			Color("a15f2d"), 0.62, StationSurfaceKit.PanelFinish.METAL_TRIM
		),
	}


## Apply the same registered panel maps and physical projection used by the
## station modules Dock 04/05/06 meet. Finish roles affect only surface response;
## the authored berth-role tints and non-colour wayfinding shapes remain intact.
func _panel_material(
		color: Color, metallic: float, finish: StationSurfaceKit.PanelFinish
	) -> StandardMaterial3D:
	var material := _material(color, metallic)
	StationSurfaceKit.apply_panel_triplanar(material, PANEL_SURFACE_SCALE, finish)
	return material


func _emissive_material(color: Color) -> StandardMaterial3D:
	# These cues are large pieces of manufactured rail/gantry hardware, not
	# screen-space glyphs. Retain their emissive state language while giving the
	# underlying metal the same metric grain and response as the neighbouring
	# station trim. This changes no geometry, renderer, or light roster.
	var material := _panel_material(
		color.darkened(0.25), 0.48, StationSurfaceKit.PanelFinish.METAL_TRIM
	)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	return material


func _is_station_panel_finish(
		material: StandardMaterial3D, clearcoat: float, clearcoat_roughness: float
	) -> bool:
	return material != null \
		and material.albedo_texture != null \
		and material.albedo_texture.resource_path == StationSurfaceKit.PANEL_ALBEDO_PATH \
		and material.normal_enabled \
		and material.normal_texture != null \
		and material.normal_texture.resource_path == StationSurfaceKit.PANEL_NORMAL_PATH \
		and material.roughness_texture != null \
		and material.roughness_texture.resource_path == StationSurfaceKit.PANEL_ROUGHNESS_PATH \
		and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED \
		and material.uv1_triplanar and material.uv1_world_triplanar \
		and material.uv1_scale.is_equal_approx(Vector3.ONE * PANEL_SURFACE_SCALE) \
		and material.clearcoat_enabled \
		and is_equal_approx(material.clearcoat, clearcoat) \
		and is_equal_approx(material.clearcoat_roughness, clearcoat_roughness)


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
