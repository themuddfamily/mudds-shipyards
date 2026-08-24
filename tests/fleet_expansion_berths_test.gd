extends SceneTree

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")
const StationSurfaceKit := preload("res://scripts/world/station_surface_kit.gd")
const EXPECTED_PAD_IDS: Array[StringName] = [
	&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"
]
const EXPECTED_PAD_POSITIONS: Array[Vector3] = [
	Vector3(-16.4, 0.0, -8.0), Vector3(34.0, 0.0, -18.0), Vector3(0.0, 0.0, 34.0)
]
const EXPECTED_SERVICE_MESHES := [3, 3, 3]
const EXPECTED_SERVICE_BATCHES := [1, 0, 1]
const EXPECTED_SERVICE_COPIES := [6, 3, 5]
const EXPECTED_SERVICE_LIGHTS := [2, 1, 2]
const EXPECTED_SERVICE_MESH_RESOURCE_ALLOCATIONS := 11
const EXPECTED_COMPONENT_MESH_RESOURCE_ALLOCATIONS := 24
const EXPECTED_SERVICE_ROLES: Array[StringName] = [
	&"cargo_crane_and_container_apron",
	&"ordnance_safe_gantry_markers",
	&"rapid_launch_guide_frame",
]

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var berths := Berths.new()
	root.add_child(berths)
	await process_frame
	var audit := berths.get_audit_report()
	_check(bool(audit.get("valid", false)), "three expansion pads build within their geometry budget")
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the expansion makes no historical berth claim")
	_check(berths.get_pad_ids() == EXPECTED_PAD_IDS, "Dock 04 cargo, Dock 05 bomber, and Dock 06 interceptor are stable authored IDs")
	_test_service_presentations(berths, audit)
	_test_cargo_container_batch(berths, audit)
	_test_launch_rail_batch(berths, audit)
	_test_underframe_support_batch(berths, audit)
	_test_access_circulation(berths, audit)
	_test_panel_finish_roles(berths)
	for pad_id in berths.get_pad_ids():
		var contract := berths.get_landing_contract(pad_id)
		_check(bool(contract.get("accepted", false)) and (contract.get("landing_anchor", Vector3.INF) as Vector3).is_finite(), "landing contract is finite for %s" % pad_id)
		_check(not bool(contract.get("ship_authority", true)) and not bool(contract.get("berth_lease_authority", true)), "contract remains caller-owned for %s" % pad_id)
	var unknown := berths.get_landing_contract(&"dock_99")
	_check(not bool(unknown.get("accepted", true)), "unknown pad IDs fail closed")
	var craft := Node3D.new()
	craft.set_meta(&"evidence_status", &"NEW")
	root.add_child(craft)
	await process_frame
	var attached := berths.attach_craft(&"dock_04_cargo", craft, &"cinder_cargo_hauler")
	var occupied_state := berths.get_pad_presentation_state(&"dock_04_cargo")
	var access_spine := berths.get_node_or_null(^"AccessCirculation/CargoTrunkLeg") as StaticBody3D
	var access_spine_id := access_spine.get_instance_id() if access_spine != null else 0
	_check(
		bool(attached.get("accepted", false))
		and craft.global_position == attached.get("landing_anchor", Vector3.INF)
		and occupied_state.state_id == &"occupied"
		and float(occupied_state.guide_energy) < 0.4
		and "OCCUPIED" in String(occupied_state.sign_text),
		"Dock 04 accepts a NEW craft and its detached lease snapshot resolves the fixed roster to occupied"
	)
	root.remove_child(berths)
	await process_frame
	root.add_child(berths)
	await process_frame
	await process_frame
	_check(
		berths.get_pad_presentation_state(&"dock_04_cargo") == occupied_state,
		"detach/re-entry restores Dock 04 from the same detached occupied lease snapshot"
	)
	_check(
		access_spine_id != 0
		and berths.get_node_or_null(^"AccessCirculation/CargoTrunkLeg") == access_spine
		and bool((berths.call("get_access_circulation_audit") as Dictionary).get("valid", false)),
		"detach/re-entry retains the identity-stable compact circulation without rebuilding it"
	)
	var duplicate := berths.attach_craft(&"dock_05_bomber", craft, &"cinder_cargo_hauler")
	_check(not bool(duplicate.get("accepted", true)) and duplicate.get("reason", &"") == &"craft_already_attached", "one craft cannot occupy multiple expansion pads")
	var foreign := Node3D.new()
	foreign.set_meta(&"evidence_status", &"NEW")
	root.add_child(foreign)
	await process_frame
	var foreign_detach := berths.detach_craft(&"dock_04_cargo", foreign)
	_check(not bool(foreign_detach.get("accepted", true)) and foreign_detach.get("reason", &"") == &"foreign_craft", "foreign detach requests fail closed")
	var detached := berths.detach_craft(&"dock_04_cargo", craft)
	var available_again := berths.get_pad_presentation_state(&"dock_04_cargo")
	_check(
		bool(detached.get("accepted", false))
		and not bool(berths.get_attachment_snapshot(&"dock_04_cargo").get("attached", true))
		and available_again.state_id == &"approach_available"
		and float(available_again.guide_energy) > 2.2
		and "APPROACH CLEAR" in String(available_again.sign_text)
		and int(available_again.node_delta) == 0
		and int(available_again.light_delta) == 0
		and int(available_again.submission_delta) == 0,
		"the owner detaches and restores the bright approach-clear cue with zero roster growth"
	)
	craft.queue_free()
	foreign.queue_free()
	berths.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_berths_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_service_presentations(berths: Node3D, audit: Dictionary) -> void:
	var presentation: Dictionary = berths.call("get_service_presentation_audit")
	var budgets := presentation.get("budgets", {}) as Dictionary
	_check(
		bool(presentation.get("valid", false))
		and (presentation.get("errors", PackedStringArray()) as PackedStringArray).is_empty()
		and int(audit.get("static_bodies", -1)) == 6
		and int(audit.get("collision_shapes", -1)) == 6
		and int(audit.get("mesh_instances", -1)) == 21
		and int(audit.get("multimesh_instances", -1)) == 3
		and int(audit.get("renderer_nodes", -1)) == 24
		and int(audit.get("mesh_resource_allocations", -1)) == EXPECTED_COMPONENT_MESH_RESOURCE_ALLOCATIONS
		and int(audit.get("service_mesh_resource_allocations", -1)) == EXPECTED_SERVICE_MESH_RESOURCE_ALLOCATIONS
		and int(audit.get("guide_lights", -1)) == 5
		and int(audit.get("descendants", -1)) == 59
		and int(budgets.get("static_bodies", -1)) == 6
		and int(budgets.get("collision_shapes", -1)) == 6
		and int(budgets.get("mesh_instances", -1)) == 21
		and int(budgets.get("multimesh_instances", -1)) == 3
		and int(budgets.get("renderer_nodes", -1)) == 24
		and int(budgets.get("mesh_resource_allocations", -1)) == EXPECTED_COMPONENT_MESH_RESOURCE_ALLOCATIONS
		and int(budgets.get("service_mesh_resource_allocations", -1)) == EXPECTED_SERVICE_MESH_RESOURCE_ALLOCATIONS
		and int(budgets.get("guide_lights", -1)) == 5
		and int(budgets.get("descendants", -1)) == 59,
		"three logical pads and six honest routes freeze at 24 renderers, 24 resources, 59 descendants, and six exact walkable boxes"
	)
	var expected_bounds: Array[AABB] = [
		AABB(Vector3(-18.75, 0.0, -13.5), Vector3(40.25, 12.0, 27.0)),
		AABB(Vector3(-19.5, 0.0, -19.0), Vector3(31.5, 11.0, 17.0)),
		AABB(Vector3(-16.75, 0.0, -16.75), Vector3(33.5, 10.5, 40.75)),
	]
	var required_nodes := [
		["CargoCraneMast", "CargoCraneJib", "CargoContainerBatch"],
		["OrdnanceGantryPort", "OrdnanceMarkerPort", "BlastSafetyDatum"],
		["LaunchRailBatch", "LaunchFramePort", "LaunchFrameHeader"],
	]
	var material_signatures := PackedStringArray()
	for pad_index in EXPECTED_PAD_IDS.size():
		var pad_id := EXPECTED_PAD_IDS[pad_index]
		var pad := berths.get_node_or_null(NodePath(String(pad_id))) as Node3D
		var service := pad.get_node_or_null(^"ServicePresentation") as Node3D \
			if pad != null else null
		var pad_report := (presentation.get("pads", {}) as Dictionary).get(pad_id, {}) as Dictionary
		var contract: Dictionary = berths.call("get_landing_contract", pad_id)
		var expected_landing := EXPECTED_PAD_POSITIONS[pad_index] + Vector3(0.0, 4.0, 0.0)
		var expected_approach := EXPECTED_PAD_POSITIONS[pad_index] + Vector3(0.0, 0.0, 30.0)
		var sign := pad.get_node_or_null(^"PadSign") as Label3D if pad != null else null
		var expected_sign := "DOCK %02d  %s  //  APPROACH CLEAR" % [
			pad_index + 4, ["CARGO HAULER", "BOMBER", "INTERCEPTOR"][pad_index]
		]
		var state: Dictionary = berths.call("get_pad_presentation_state", pad_id)
		_check(
			pad != null and service != null
			and pad.position.is_equal_approx(EXPECTED_PAD_POSITIONS[pad_index])
			and (contract.get("landing_anchor", Vector3.INF) as Vector3).is_equal_approx(expected_landing)
			and (contract.get("approach_anchor", Vector3.INF) as Vector3).is_equal_approx(expected_approach)
			and sign != null and sign.text == expected_sign
			and StringName(service.get_meta(&"service_role", &"")) == EXPECTED_SERVICE_ROLES[pad_index]
			and state.state_id == &"approach_available"
			and StringName((state.lease_snapshot as Dictionary).lease_state_id) == &"available",
			"%s retains its frozen pad, landing, approach, sign, and distinct service-role identity" % pad_id
		)
		var meshes := service.find_children("*", "MeshInstance3D", true, false)
		var batches := service.find_children("*", "MultiMeshInstance3D", true, false)
		var lights := service.find_children("*", "OmniLight3D", true, false)
		var roster_complete := true
		for node_name in required_nodes[pad_index]:
			roster_complete = roster_complete and service.get_node_or_null(NodePath(node_name)) != null
		_check(
			meshes.size() == EXPECTED_SERVICE_MESHES[pad_index]
			and batches.size() == EXPECTED_SERVICE_BATCHES[pad_index]
			and int(pad_report.get("visible_mesh_copies", -1)) == EXPECTED_SERVICE_COPIES[pad_index]
			and lights.size() == EXPECTED_SERVICE_LIGHTS[pad_index] and roster_complete
			and (pad_report.get("local_bounds", AABB()) as AABB).is_equal_approx(expected_bounds[pad_index])
			and bool(pad_report.get("landing_clear", false))
			and bool(pad_report.get("approach_clear", false))
			and bool(pad_report.get("readable", false)),
			"%s has its exact bounded readable service roster outside the landing and approach clearances" % pad_id
		)
		var lights_safe := true
		for raw_light in lights:
			var light := raw_light as OmniLight3D
			lights_safe = lights_safe and not light.shadow_enabled \
				and is_equal_approx(light.light_energy, 2.3) \
				and is_equal_approx(light.omni_range, 12.0)
		_check(lights_safe, "%s uses its exact bounded shadowless service-guide roster" % pad_id)
		var first_material := (meshes[0] as MeshInstance3D).material_override as StandardMaterial3D
		material_signatures.append(first_material.albedo_color.to_html(false))
		_check(
			pad.get_node_or_null(^"WalkablePadCollision") == null
			and pad.find_children("ServicePadSurface*", "MeshInstance3D", true, false).is_empty()
			and pad.find_children("*", "StaticBody3D", true, false).is_empty()
			and pad.find_children("*", "CollisionShape3D", true, false).is_empty()
			and service.find_children("*", "CollisionObject3D", true, false).is_empty()
			and service.find_children("*", "CollisionShape3D", true, false).is_empty()
			and service.find_children("*", "Area3D", true, false).is_empty(),
			"%s remains a logical landing owner without an undeclared broad floor" % pad_id
		)
	_check(
		material_signatures[0] != material_signatures[1]
		and material_signatures[1] != material_signatures[2]
		and material_signatures[0] != material_signatures[2],
		"cargo ochre, bomber charcoal, and interceptor teal remain visually distinct material families"
	)
	var bomber_service := berths.get_node_or_null(
		^"dock_05_bomber/ServicePresentation"
	) as Node3D
	_check(
		bomber_service != null
		and bomber_service.get_node_or_null(^"OrdnanceGantryStarboard") == null
		and bomber_service.get_node_or_null(^"OrdnanceMarkerStarboard") == null
		and bomber_service.get_node_or_null(^"OrdnanceGuideStarboard") == null,
		"Dock 05 omits the outer starboard ordnance assembly over the central walkway"
	)
	_check(
		not bool(presentation.get("ship_authority", true))
		and not bool(presentation.get("berth_lease_authority", true))
		and not bool(presentation.get("interaction_authority", true)),
		"the three service silhouettes own no ship, lease, or interaction authority"
	)
	var detached: Dictionary = berths.call("get_service_presentation_audit")
	detached["ship_authority"] = true
	(detached["errors"] as PackedStringArray).append("injected")
	_check(bool(berths.get_service_presentation_audit().valid), "the service presentation audit is detached from caller mutation")
	var cargo_container_batch := berths.get_node_or_null(
		^"dock_04_cargo/ServicePresentation/CargoContainerBatch"
	) as MultiMeshInstance3D
	if cargo_container_batch == null:
		return
	cargo_container_batch.position = Vector3(-18.0, 0.0, 0.0)
	var clearance_drift: Dictionary = berths.call("get_service_presentation_audit")
	_check(
		not bool(clearance_drift.valid)
		and (clearance_drift.errors as PackedStringArray).has(
			"service silhouette entered landing or approach clearance: dock_04_cargo"
		),
		"moving cargo stock into the landing volume is structured clearance red"
	)
	cargo_container_batch.position = Vector3.ZERO
	_check(bool(berths.get_service_presentation_audit().valid), "restoring the cargo apron returns all three service presentations green")
	print(
		"FLEET_EXPANSION_SERVICE_BUDGET: world_renderers=%d total_resources=%d service_resources=%d (baseline=%d delta=%d) submissions=%d->%d lights=%d descendants=%d bodies=%d shapes=%d" % [
			int(audit.get("renderer_nodes", -1)), int(audit.get("mesh_resource_allocations", -1)),
			int(audit.get("service_mesh_resource_allocations", -1)),
			int(presentation.get("mesh_resource_allocations_before", -1)), int(presentation.get("mesh_resource_delta", -1)),
			int(presentation.get("geometry_submissions_before", -1)), int(presentation.get("geometry_submissions_after", -1)),
			int(audit.get("guide_lights", -1)),
			int(audit.get("descendants", -1)), int(audit.get("static_bodies", -1)),
			int(audit.get("collision_shapes", -1)),
		]
	)


func _test_cargo_container_batch(berths: Node3D, audit: Dictionary) -> void:
	var service := berths.get_node_or_null(
		^"dock_04_cargo/ServicePresentation"
	) as Node3D
	var batch := service.get_node_or_null(^"CargoContainerBatch") as MultiMeshInstance3D \
		if service != null else null
	var container_mesh := batch.multimesh.mesh as BoxMesh \
		if batch != null and batch.multimesh != null else null
	var expected_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(18.0, 1.8, -10.0)),
		Transform3D(Basis.IDENTITY, Vector3(18.0, 1.8, 0.0)),
		Transform3D(Basis.IDENTITY, Vector3(18.0, 1.8, 10.0)),
	]
	var authored_transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
		if batch != null else []
	var material := batch.material_override as StandardMaterial3D if batch != null else null
	var transforms_exact := authored_transforms.size() == expected_transforms.size()
	if transforms_exact:
		for index in expected_transforms.size():
			transforms_exact = transforms_exact and (
				authored_transforms[index] as Transform3D
			).is_equal_approx(expected_transforms[index])
	var presentation := audit.get("service_presentation", {}) as Dictionary
	_check(
		batch != null and container_mesh != null
		and container_mesh.size.is_equal_approx(Vector3(7.0, 3.6, 7.0))
		and batch.multimesh.instance_count == 3 and transforms_exact
		and material != null and material.albedo_color.is_equal_approx(Color("2f5966"))
		and is_equal_approx(material.metallic, 0.58) and not material.emission_enabled
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and batch.get_child_count() == 0
		and bool(batch.get_meta(&"visual_detail_only", false))
		and StringName(batch.get_meta(&"visual_batch_family_id", &"")) \
			== &"dock_04_cargo_containers",
		"Dock 04 retains all three exact cargo-container copies and transforms in one childless visual batch"
	)
	_check(
		int(presentation.get("renderer_nodes_before", -1)) == 14
		and int(presentation.get("renderer_nodes_after", -1)) == 11
		and int(presentation.get("renderer_node_delta", 0)) == -3
		and int(presentation.get("geometry_submissions_before", -1)) == 14
		and int(presentation.get("geometry_submissions_after", -1)) == 11
		and int(presentation.get("geometry_submission_delta", 0)) == -3
		and int(presentation.get("visible_mesh_copies", -1)) == 14,
		"cargo batching contributes two fewer renderers and submissions while all 14 service copies remain visible"
	)
	_check(
		service != null
		and service.find_children("CargoContainer*", "MeshInstance3D", true, false).is_empty()
		and service.find_children("*", "CollisionObject3D", true, false).is_empty()
		and service.find_children("*", "CollisionShape3D", true, false).is_empty()
		and service.find_children("*", "Area3D", true, false).is_empty(),
		"the cargo-container batch remains visual-only and owns no route, collision, boarding, or interaction behavior"
	)


func _test_launch_rail_batch(berths: Node3D, audit: Dictionary) -> void:
	var service := berths.get_node_or_null(
		^"dock_06_interceptor/ServicePresentation"
	) as Node3D
	var batch := service.get_node_or_null(^"LaunchRailBatch") as MultiMeshInstance3D \
		if service != null else null
	var presentation := audit.get("service_presentation", {}) as Dictionary
	var rail_mesh := batch.multimesh.mesh as BoxMesh \
		if batch != null and batch.multimesh != null else null
	var expected_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(-16.0, 0.5, 5.0)),
		Transform3D(Basis.IDENTITY, Vector3(16.0, 0.5, 5.0)),
	]
	# RenderingServer readback may expose identity transforms headless; the
	# submitted parent-space roster is retained alongside the GPU buffer.
	var authored_transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
		if batch != null else []
	var transforms_exact := authored_transforms.size() == expected_transforms.size()
	if transforms_exact:
		for index in expected_transforms.size():
			transforms_exact = transforms_exact and (authored_transforms[index] as Transform3D).is_equal_approx(
				expected_transforms[index]
			)
	var material := batch.material_override as StandardMaterial3D if batch != null else null
	_check(
		batch != null and rail_mesh != null
		and rail_mesh.size.is_equal_approx(Vector3(1.0, 1.0, 38.0))
		and transforms_exact
		and material != null and material.emission_enabled
		and material.emission.is_equal_approx(Color("61e4ee"))
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and batch.layers == 1 and not batch.ignore_occlusion_culling
		and is_zero_approx(batch.extra_cull_margin)
		and batch.get_child_count() == 0
		and bool(batch.get_meta(&"visual_detail_only", false))
		and StringName(batch.get_meta(&"visual_batch_family_id", &"")) == &"dock_06_launch_rails",
		"Dock 06 retains both exact rail copies, transforms, emissive material, and render state in one childless visual batch"
	)
	_check(
		int(presentation.get("renderer_nodes_before", -1)) == 14
		and int(presentation.get("renderer_nodes_after", -1)) == 11
		and int(presentation.get("renderer_node_delta", 0)) == -3
		and int(presentation.get("geometry_submissions_before", -1)) == 14
		and int(presentation.get("geometry_submissions_after", -1)) == 11
		and int(presentation.get("geometry_submission_delta", 0)) == -3
		and int(presentation.get("mesh_resource_allocations_before", -1)) == 12
		and int(presentation.get("mesh_resource_allocations_after", -1)) == 11
		and int(presentation.get("mesh_resource_delta", 0)) == -1
		and int(presentation.get("visible_mesh_copies", -1)) == 14,
		"the rail and cargo families reduce renderer nodes and submissions by three and mesh allocations by one while retaining all 14 service copies"
	)
	_check(
		service != null
		and not bool(service.get_meta(&"ship_authority", true))
		and not bool(service.get_meta(&"berth_lease_authority", true))
		and service.find_children("*", "CollisionObject3D", true, false).is_empty()
		and service.find_children("*", "CollisionShape3D", true, false).is_empty()
		and service.find_children("*", "Area3D", true, false).is_empty(),
		"the launch-rail batch remains presentation-only with no collision, landing, lease, or interaction authority"
	)


func _test_underframe_support_batch(berths: Node3D, audit: Dictionary) -> void:
	var underframe := berths.get_node_or_null(
		^"AccessCirculation/SupportedUnderframe"
	) as Node3D
	var batch := underframe.get_node_or_null(^"UnderframeSupportBatch") as MultiMeshInstance3D \
		if underframe != null else null
	var post_mesh := batch.multimesh.mesh as BoxMesh \
		if batch != null and batch.multimesh != null else null
	var expected_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(-15.0, -1.75, 0.5)),
		Transform3D(Basis.IDENTITY, Vector3(-5.0, -1.75, 0.5)),
		Transform3D(Basis.IDENTITY, Vector3(-19.8, -1.75, -6.0)),
		Transform3D(Basis.IDENTITY, Vector3(10.0, -1.75, -22.8)),
		Transform3D(Basis.IDENTITY, Vector3(24.0, -1.75, -22.8)),
		Transform3D(Basis.IDENTITY, Vector3(30.2, -1.75, -19.2)),
	]
	var authored_transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
		if batch != null else []
	var transforms_exact := authored_transforms.size() == expected_transforms.size()
	if transforms_exact:
		for index in expected_transforms.size():
			transforms_exact = transforms_exact and (
				authored_transforms[index] as Transform3D
			).is_equal_approx(expected_transforms[index])
	_check(
		batch != null and post_mesh != null
		and post_mesh.size.is_equal_approx(Vector3(0.55, 2.5, 0.55))
		and batch.multimesh.instance_count == 6
		and transforms_exact
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and batch.get_child_count() == 0
		and bool(batch.get_meta(&"visual_detail_only", false))
		and StringName(batch.get_meta(&"visual_batch_family_id", &"")) \
			== &"access_underframe_support_posts",
		"the access underframe retains all six exact support-post copies and transforms in one childless visual batch"
	)
	var access := audit.get("access_circulation", {}) as Dictionary
	_check(
		int(access.get("support_meshes", -1)) == 11
		and int(access.get("support_renderer_nodes", -1)) == 6
		and int(audit.get("renderer_nodes", -1)) == 24
		and int(audit.get("mesh_resource_allocations", -1)) == 24,
		"the support-post family removes five renderer submissions and mesh allocations while retaining all 11 underframe copies"
	)
	_check(
		underframe != null
		and underframe.find_children("*", "CollisionObject3D", true, false).is_empty()
		and underframe.find_children("*", "CollisionShape3D", true, false).is_empty()
		and underframe.find_children("*", "Area3D", true, false).is_empty(),
		"the support-post batch remains presentation-only and adds no route, collision, navigation, or interaction authority"
	)


func _test_panel_finish_roles(berths: Node3D) -> void:
	var access := berths.get_node_or_null(
		^"AccessCirculation/CargoTrunkLeg/Surface"
	) as MeshInstance3D
	var frame := berths.get_node_or_null(
		^"dock_04_cargo/ServicePresentation/CargoCraneMast"
	) as MeshInstance3D
	var underframe := berths.get_node_or_null(
		^"AccessCirculation/SupportedUnderframe/CargoTrunkChord"
	) as MeshInstance3D
	var wayfinding := berths.get_node_or_null(
		^"AccessCirculation/BerthRouteEdgeTreatment"
	) as MeshInstance3D
	var access_material := access.material_override as StandardMaterial3D if access != null else null
	var frame_material := frame.material_override as StandardMaterial3D if frame != null else null
	var underframe_material := underframe.material_override as StandardMaterial3D \
		if underframe != null else null
	var wayfinding_material := wayfinding.material_override as StandardMaterial3D \
		if wayfinding != null else null
	_check(
		_is_panel_finish(access_material, StationSurfaceKit.WALKED_CLEARCOAT,
			StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS),
		"all compact access surfaces use the walked-deck panel finish"
	)
	_check(
		_is_panel_finish(frame_material, StationSurfaceKit.STRUCTURAL_CLEARCOAT,
			StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS)
		and _is_panel_finish(underframe_material, StationSurfaceKit.STRUCTURAL_CLEARCOAT,
			StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS),
		"berth service frames and access underframes use the structural-alloy panel finish"
	)
	_check(
		_is_panel_finish(wayfinding_material, StationSurfaceKit.TRIM_CLEARCOAT,
			StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS)
		and wayfinding_material.albedo_color.is_equal_approx(Color("a15f2d")),
		"route grip uses the metal-trim panel finish while retaining its authored identity tint"
	)


func _is_panel_finish(
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
		and material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30) \
		and material.clearcoat_enabled \
		and is_equal_approx(material.clearcoat, clearcoat) \
		and is_equal_approx(material.clearcoat_roughness, clearcoat_roughness)


func _test_access_circulation(berths: Node3D, audit: Dictionary) -> void:
	var access := berths.call("get_access_circulation_audit") as Dictionary
	print("FLEET_COMPACT_ACCESS_AUDIT: ", access)
	var wayfinding := access.get("wayfinding", {}) as Dictionary
	var expected_names := [
		&"CargoTrunkLeg", &"CargoBoardingLeg", &"Dock05BomberBridge",
		&"BomberBerthLeg", &"BomberBoardingLeg", &"InterceptorBoardingToe",
	]
	_check(
		bool(access.get("valid", false))
		and (access.get("surface_names", []) as Array) == expected_names
		and int(access.get("static_bodies", -1)) == 6
		and int(access.get("collision_shapes", -1)) == 6
		and int(access.get("surface_meshes", -1)) == 6
		and int(access.get("support_meshes", -1)) == 11
		and int(access.get("support_renderer_nodes", -1)) == 6
		and bool(wayfinding.get("valid", false))
		and int(wayfinding.get("mesh_instances", -1)) == 1
		and int(wayfinding.get("mesh_surfaces", -1)) == 1
		and int(wayfinding.get("labels", -1)) == 1
		and int(wayfinding.get("lights", -1)) == 0
		and int(wayfinding.get("collision_shapes", -1)) == 0
		and bool(access.get("envelopes_clear", false))
		and is_equal_approx(float(access.get("gross_horizontal_m2", -1.0)), 57.4)
		and is_equal_approx(float(access.get("unique_horizontal_m2", -1.0)), 55.4)
		and not bool(access.get("shared_spine", true))
		and bool(access.get("world_collision_backed", false))
		and (audit.get("access_circulation", {}) as Dictionary) == access,
		"six declared route boxes own exactly 57.4 gross / 55.4 unique m2 with dynamic clearances"
	)
	var expected_grammars := {
		&"dock_04_cargo": &"square_cargo_cradle",
		&"dock_05_bomber": &"swept_bomber_chevron",
		&"dock_06_interceptor": &"straight_launch_spear",
	}
	var route_mesh := berths.get_node_or_null(
		^"AccessCirculation/BerthRouteEdgeTreatment"
	) as MeshInstance3D
	var route_legend := berths.get_node_or_null(
		^"AccessCirculation/AftJunctionRouteLegend"
	) as Label3D
	_check(
		route_mesh != null and route_mesh.mesh is ArrayMesh
		and route_mesh.mesh.get_surface_count() == 1
		and int(route_mesh.get_meta(&"batched_box_count", -1)) == 14
		and route_mesh.get_meta(&"route_cue_grammars", {}) == expected_grammars
		and bool(route_mesh.get_meta(&"manufactured_edge_treatment", false))
		and route_legend != null
		and route_legend.text.contains("DOCK 04  CARGO")
		and route_legend.text.contains("DOCK 05  BOMBER")
		and route_legend.text.contains("DOCK 06  INTERCEPTOR")
		and route_mesh.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"one batched station-family edge treatment pairs explicit Aft-junction text with square, chevron, and spear berth identities without colour or collision"
	)
	var circulation := berths.get_node_or_null(^"AccessCirculation") as Node3D
	var spine := circulation.get_node_or_null(^"CargoTrunkLeg") as StaticBody3D \
		if circulation != null else null
	var dock04 := circulation.get_node_or_null(^"CargoBoardingLeg") as StaticBody3D \
		if circulation != null else null
	var dock05 := circulation.get_node_or_null(^"Dock05BomberBridge") as StaticBody3D \
		if circulation != null else null
	var branch := circulation.get_node_or_null(^"BomberBoardingLeg") as StaticBody3D \
		if circulation != null else null
	var dock06 := circulation.get_node_or_null(^"InterceptorBoardingToe") as StaticBody3D \
		if circulation != null else null
	_check(
		spine != null and dock04 != null and dock05 != null and branch != null and dock06 != null
		and spine.position.is_equal_approx(Vector3(-11.35, -0.3, 0.5))
		and dock04.position.is_equal_approx(Vector3(-19.8, -0.3, -3.75))
		and dock05.position.is_equal_approx(Vector3(13.3, -0.28, -22.8))
		and branch.position.is_equal_approx(Vector3(30.2, -0.3, -20.65))
		and dock06.position.is_equal_approx(Vector3(-2.7, -0.3, 34.0)),
		"the compact routes meet both station seams and all three boarding projections"
	)
	var collision := dock04.get_node_or_null(^"Collision") as CollisionShape3D \
		if dock04 != null else null
	_check(collision != null, "Dock 04 boarding leg owns its production World collision")
	if collision != null:
		collision.disabled = true
		var disabled := berths.call("get_access_circulation_audit") as Dictionary
		_check(
			not bool(disabled.get("valid", true))
			and (disabled.get("errors", PackedStringArray()) as PackedStringArray).has(
				"access surface collision drift: CargoBoardingLeg"
			),
			"disabling a required boarding leg is structured red"
		)
		collision.disabled = false
		_check(bool((berths.call("get_access_circulation_audit") as Dictionary).get("valid", false)), "restoring Dock 04 access returns the production topology green")
	if collision != null and collision.shape is BoxShape3D:
		var original_size := (collision.shape as BoxShape3D).size
		(collision.shape as BoxShape3D).size.x = 2.0
		var old_offset := berths.call("get_audit_report") as Dictionary
		_check(
			not bool(old_offset.get("valid", true))
			and (old_offset.get("errors", PackedStringArray()) as PackedStringArray).has(
				"access circulation: access surface collision drift: CargoBoardingLeg"
			),
			"widening a route without its render is structured red"
		)
		(collision.shape as BoxShape3D).size = original_size
		_check(bool((berths.call("get_audit_report") as Dictionary).get("valid", false)), "restoring the exact route box returns the berth audit green")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
