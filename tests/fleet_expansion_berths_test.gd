extends SceneTree

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")
const CargoHauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const StationSurfaceKit := preload("res://scripts/world/station_surface_kit.gd")
const EXPECTED_PAD_IDS: Array[StringName] = [
	&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"
]
## Dock 04 moved 3.0 m outboard (pad-local z -8.0 -> -5.0) once the long-session
## soak proved its published approach lane ran 1.55 m through `VipReceptionSuite`.
const EXPECTED_PAD_POSITIONS: Array[Vector3] = [
	Vector3(-16.4, 0.0, -5.0), Vector3(34.0, 0.0, -18.0), Vector3(0.0, 0.0, 34.0)
]
const EXPECTED_SERVICE_MESHES := [3, 3, 3]
const EXPECTED_SERVICE_BATCHES := [3, 0, 3]
const EXPECTED_SERVICE_COPIES := [38, 3, 44]
const EXPECTED_SERVICE_LIGHTS := [2, 1, 2]
const EXPECTED_SERVICE_MESH_RESOURCE_ALLOCATIONS := 12
const EXPECTED_COMPONENT_MESH_RESOURCE_ALLOCATIONS := 25
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
	_test_service_structure_collision(berths, audit)
	_test_apron_and_lane_kits(berths)
	_test_underframe_support_batch(berths, audit)
	_test_access_circulation(berths, audit)
	_test_panel_finish_roles(berths)
	for pad_id in berths.get_pad_ids():
		var contract := berths.get_landing_contract(pad_id)
		_check(bool(contract.get("accepted", false)) and (contract.get("landing_anchor", Vector3.INF) as Vector3).is_finite(), "landing contract is finite for %s" % pad_id)
		_check(not bool(contract.get("ship_authority", true)) and not bool(contract.get("berth_lease_authority", true)), "contract remains caller-owned for %s" % pad_id)
	var unknown := berths.get_landing_contract(&"dock_99")
	_check(not bool(unknown.get("accepted", true)), "unknown pad IDs fail closed")
	var craft := CargoHauler.new() as HeroShip
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
		and int(audit.get("static_bodies", -1)) == 8
		and int(audit.get("collision_shapes", -1)) == 42
		and int(audit.get("mesh_instances", -1)) == 21
		and int(audit.get("multimesh_instances", -1)) == 7
		and int(audit.get("renderer_nodes", -1)) == 28
		and int(audit.get("mesh_resource_allocations", -1)) == EXPECTED_COMPONENT_MESH_RESOURCE_ALLOCATIONS
		and int(audit.get("service_mesh_resource_allocations", -1)) == EXPECTED_SERVICE_MESH_RESOURCE_ALLOCATIONS
		and int(audit.get("guide_lights", -1)) == 5
		and int(audit.get("descendants", -1)) == 104
		and int(budgets.get("static_bodies", -1)) == 8
		and int(budgets.get("collision_shapes", -1)) == 42
		and int(budgets.get("mesh_instances", -1)) == 21
		and int(budgets.get("multimesh_instances", -1)) == 7
		and int(budgets.get("renderer_nodes", -1)) == 28
		and int(budgets.get("mesh_resource_allocations", -1)) == EXPECTED_COMPONENT_MESH_RESOURCE_ALLOCATIONS
		and int(budgets.get("service_mesh_resource_allocations", -1)) == EXPECTED_SERVICE_MESH_RESOURCE_ALLOCATIONS
		and int(budgets.get("guide_lights", -1)) == 5
		and int(budgets.get("descendants", -1)) == 104,
		"three logical pads and six honest routes freeze at 28 renderers, 25 resources, 104 descendants, six exact walkable boxes and 36 service-structure colliders"
	)
	var expected_bounds: Array[AABB] = [
		AABB(Vector3(-18.75, 0.0, -15.2), Vector3(32.65, 12.0, 35.830929)),
		AABB(Vector3(-19.5, 0.0, -19.0), Vector3(31.5, 11.0, 17.0)),
		AABB(Vector3(-13.9, 0.0, -20.3), Vector3(27.8, 10.8, 40.95)),
	]
	var required_nodes := [
		[
			"CargoCraneMast", "CargoCraneJib", "CargoContainerBatch",
			"CargoApronKitBatch", "CargoApronMarkingBatch", "CargoManifestBoard",
		],
		["OrdnanceGantryPort", "OrdnanceMarkerPort", "BlastSafetyDatum"],
		[
			"LaunchRailBatch", "LaunchFramePort", "LaunchFrameHeader",
			"LaunchApronKitBatch", "LaunchLaneMarkingBatch", "LaunchReadinessBoard",
		],
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
	# The container is no longer a box. `FreightContainerKit.shell_mesh` draws it as
	# four surfaces — painted body, cast frame, door leaves, stencil plate — and
	# the assertion that matters is that its AABB is still exactly the 3 x 3.6 x 4
	# the seven colliders, the clearance sweeps and the authored pad bounds are all
	# built from, so the finish moved nothing.
	var container_mesh := batch.multimesh.mesh as ArrayMesh \
		if batch != null and batch.multimesh != null else null
	var expected_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(12.4, 1.8, -4.0)),
		Transform3D(Basis.IDENTITY, Vector3(12.4, 1.8, 0.3)),
		Transform3D(Basis.IDENTITY, Vector3(12.4, 5.4, -1.85)),
		Transform3D(Basis.IDENTITY, Vector3(12.4, 1.8, 8.6)),
		Transform3D(Basis.IDENTITY, Vector3(12.4, 1.8, 12.9)),
		Transform3D(Basis.IDENTITY, Vector3(12.4, 5.4, 10.75)),
		Transform3D(Basis.IDENTITY, Vector3(-12.0, 3.1, -7.0)),
	]
	var authored_transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
		if batch != null else []
	var transforms_exact := authored_transforms.size() == expected_transforms.size()
	if transforms_exact:
		for index in expected_transforms.size():
			transforms_exact = transforms_exact and (
				authored_transforms[index] as Transform3D
			).is_equal_approx(expected_transforms[index])
	var presentation := audit.get("service_presentation", {}) as Dictionary
	_check(
		batch != null and container_mesh != null
		and container_mesh.get_aabb().is_equal_approx(
			AABB(Vector3(-1.5, -1.8, -2.0), Vector3(3.0, 3.6, 4.0))
		)
		and container_mesh.get_surface_count() == FreightContainerKit.SURFACE_COUNT
		and batch.multimesh.instance_count == 7 and transforms_exact
		and batch.material_override == null
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and batch.get_child_count() == 0
		and bool(batch.get_meta(&"visual_detail_only", false))
		and StringName(batch.get_meta(&"visual_batch_family_id", &"")) \
			== &"dock_04_cargo_containers",
		"Dock 04 stows all seven exact cargo-container copies and transforms in one childless visual batch"
	)
	# The freight finish, checked where a player would read it: three liveries
	# across the seven units, cast steel shared by all of them, and a stencil plate
	# that is neither tinted by the livery nor part of the panel family.
	var body_surface := container_mesh.surface_get_material(
		FreightContainerKit.SURFACE_BODY
	) as StandardMaterial3D if container_mesh != null else null
	var casting_surface := container_mesh.surface_get_material(
		FreightContainerKit.SURFACE_CASTING
	) as StandardMaterial3D if container_mesh != null else null
	var stencil_surface := container_mesh.surface_get_material(
		FreightContainerKit.SURFACE_STENCIL
	) as StandardMaterial3D if container_mesh != null else null
	var operators := batch.get_meta(&"freight_operator_indices", []) as Array \
		if batch != null else []
	var livery_spread := {}
	for entry in operators:
		livery_spread[int(entry)] = true
	_check(
		body_surface != null and body_surface.vertex_color_use_as_albedo
		and body_surface.albedo_color.is_equal_approx(Color.WHITE)
		and casting_surface != null
		and casting_surface.albedo_color.is_equal_approx(FreightContainerKit.CASTING_COLOR)
		and not casting_surface.vertex_color_use_as_albedo
		and stencil_surface != null and not stencil_surface.vertex_color_use_as_albedo
		and not stencil_surface.uv1_triplanar
		and stencil_surface.albedo_texture != null
		and stencil_surface.albedo_texture.resource_path \
			== "res://assets/ships/markings/freight-yard.svg"
		and batch.multimesh.use_colors
		and operators.size() == 7 and livery_spread.size() == 3,
		"the seven containers wear all three freight liveries over shared cast steel and the yard's stencilled plate"
	)
	_check(
		int(presentation.get("renderer_nodes_before", -1)) == 85
		and int(presentation.get("renderer_nodes_after", -1)) == 15
		and int(presentation.get("renderer_node_delta", 0)) == -70
		and int(presentation.get("geometry_submissions_before", -1)) == 85
		# 15 renderer nodes, 18 submissions: the container shell is the one mesh in
		# the roster that carries more than one surface, because its four finishes
		# cannot share one. Measured off the live meshes rather than asserted from
		# the node count.
		and int(presentation.get("geometry_submissions_after", -1)) == 18
		and int(presentation.get("measured_geometry_submissions", -1)) == 18
		and int(presentation.get("geometry_submission_delta", 0)) == -67
		and int(presentation.get("visible_mesh_copies", -1)) == 85,
		"batching draws all 85 service copies from 15 renderers and 18 submissions"
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
	# Chamfered stock, whose AABB is the authored size exactly; the drawn
	# envelope is what the collider pairing and the lane clearance read.
	var rail_mesh := batch.multimesh.mesh \
		if batch != null and batch.multimesh != null else null
	var expected_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(-11.0, 0.5, 9.5)),
		Transform3D(Basis.IDENTITY, Vector3(11.0, 0.5, 9.5)),
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
		and rail_mesh.get_aabb().size.is_equal_approx(Vector3(1.0, 1.0, 22.0))
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
		int(presentation.get("renderer_nodes_before", -1)) == 85
		and int(presentation.get("renderer_nodes_after", -1)) == 15
		and int(presentation.get("renderer_node_delta", 0)) == -70
		and int(presentation.get("geometry_submissions_before", -1)) == 85
		and int(presentation.get("geometry_submissions_after", -1)) == 18
		and int(presentation.get("geometry_submission_delta", 0)) == -67
		and int(presentation.get("mesh_resource_allocations_before", -1)) == 12
		and int(presentation.get("mesh_resource_allocations_after", -1)) == 12
		and int(presentation.get("mesh_resource_delta", 0)) == 0
		and int(presentation.get("visible_mesh_copies", -1)) == 85,
		"the rail, container, apron and lane families draw 85 service copies from 15 renderers, 18 submissions and 12 mesh resources"
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


## Phase 10 §3 art direction. Dock 04 and Dock 06 were shape-correct and
## unreadable: three loose crates buried behind the VIP suite, and two launch
## rails hanging in open space. The apron/launch kits below rebuild both
## identities from the same box primitive and the same per-pad materials, with
## every structural piece carrying the collider it visually implies and every
## emissive cue riding on a piece of that structure.
func _test_apron_and_lane_kits(berths: Node3D) -> void:
	for spec in [
		[
			^"dock_04_cargo/ServicePresentation",
			"CargoApronKitBatch", Berths.CARGO_APRON_KIT, Color("8a6a36"), false,
			"CargoApronMarkingBatch", Berths.CARGO_APRON_MARKINGS, Color("56d8de"),
			"CargoManifestBoard", "FREIGHT APRON",
		],
		[
			^"dock_06_interceptor/ServicePresentation",
			"LaunchApronKitBatch", Berths.LAUNCH_APRON_KIT, Color("31515b"), false,
			"LaunchLaneMarkingBatch", Berths.LAUNCH_LANE_MARKINGS, Color("61e4ee"),
			"LaunchReadinessBoard", "LAUNCH LANE",
		],
	]:
		var service := berths.get_node_or_null(spec[0] as NodePath) as Node3D
		var kit := service.get_node_or_null(NodePath(spec[1] as String)) as MultiMeshInstance3D \
			if service != null else null
		var marking := service.get_node_or_null(NodePath(spec[5] as String)) as MultiMeshInstance3D \
			if service != null else null
		var board := service.get_node_or_null(NodePath(spec[8] as String)) as Label3D \
			if service != null else null
		var kit_pieces := spec[2] as Array[Dictionary]
		var marking_pieces := spec[6] as Array[Dictionary]
		_check(
			kit != null and marking != null
			and kit.multimesh != null and marking.multimesh != null
			and (kit.multimesh.mesh as BoxMesh) != null
			and (kit.multimesh.mesh as BoxMesh).size.is_equal_approx(Vector3.ONE)
			and kit.multimesh.mesh == marking.multimesh.mesh
			and kit.multimesh.instance_count == kit_pieces.size()
			and marking.multimesh.instance_count == marking_pieces.size()
			and kit.get_child_count() == 0 and marking.get_child_count() == 0
			and kit.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and marking.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"%s draws its apron kit and its lane cues from one shared unit box" % spec[0]
		)
		var kit_material := kit.material_override as StandardMaterial3D if kit != null else null
		var marking_material := marking.material_override as StandardMaterial3D \
			if marking != null else null
		_check(
			kit_material != null and not kit_material.emission_enabled
			and kit_material.albedo_color.is_equal_approx(spec[3] as Color)
			and marking_material != null and marking_material.emission_enabled
			and marking_material.emission.is_equal_approx(spec[7] as Color),
			"%s reuses its own structural and marker materials and adds none" % spec[0]
		)
		var transforms_exact := kit != null and marking != null
		for pair in [[kit, kit_pieces], [marking, marking_pieces]]:
			var batch := pair[0] as MultiMeshInstance3D
			var pieces := pair[1] as Array[Dictionary]
			var authored := batch.get_meta(&"authored_instance_transforms", []) as Array \
				if batch != null else []
			transforms_exact = transforms_exact and authored.size() == pieces.size()
			if authored.size() != pieces.size():
				continue
			for index in pieces.size():
				var expected := Berths.scaled_box_transform(pieces[index])
				transforms_exact = transforms_exact \
					and (authored[index] as Transform3D).is_equal_approx(expected)
		_check(transforms_exact, "%s publishes its exact authored apron roster" % spec[0])
		_check(
			board != null and board.text.contains(spec[9] as String)
			and board.get_child_count() == 0 and board.get_script() == null
			and bool(board.get_meta(&"non_authoritative_presentation", false)),
			"%s carries a non-authoritative pad board" % spec[0]
		)


func _test_underframe_support_batch(berths: Node3D, audit: Dictionary) -> void:
	var underframe := berths.get_node_or_null(
		^"AccessCirculation/SupportedUnderframe"
	) as Node3D
	var batch := underframe.get_node_or_null(^"UnderframeSupportBatch") as MultiMeshInstance3D \
		if underframe != null else null
	var post_mesh := batch.multimesh.mesh \
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
		and post_mesh.get_aabb().size.is_equal_approx(Vector3(0.55, 2.5, 0.55))
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
		and int(audit.get("renderer_nodes", -1)) == 28
		and int(audit.get("mesh_resource_allocations", -1)) == 25,
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
	var expected_dock05_alignment := [
		{"centre": Vector3(30.2, 0.035, -20.4), "size": Vector3(0.72, 0.07, 0.10)},
		{"centre": Vector3(30.2, 0.035, -19.65), "size": Vector3(0.72, 0.07, 0.10)},
		{"centre": Vector3(30.2, 0.035, -18.9), "size": Vector3(0.72, 0.07, 0.10)},
	]
	var route_mesh := berths.get_node_or_null(
		^"AccessCirculation/BerthRouteEdgeTreatment"
	) as MeshInstance3D
	var route_legend := berths.get_node_or_null(
		^"AccessCirculation/AftJunctionRouteLegend"
	) as Label3D
	_check(
		route_mesh != null and route_mesh.mesh is ArrayMesh
		and route_mesh.mesh.get_surface_count() == 1
		and int(route_mesh.get_meta(&"batched_box_count", -1)) == 17
		and route_mesh.get_meta(&"route_cue_grammars", {}) == expected_grammars
		and bool(route_mesh.get_meta(&"manufactured_edge_treatment", false))
		and route_legend != null
		and route_legend.text.contains("DOCK 04  CARGO")
		and route_legend.text.contains("DOCK 05  BOMBER")
		and route_legend.text.contains("DOCK 06  INTERCEPTOR")
		and route_mesh.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"one batched station-family edge treatment pairs explicit Aft-junction text with square, chevron, and spear berth identities without colour or collision"
	)
	_check(
		route_mesh != null
		and int(route_mesh.get_meta(&"batched_box_count", -1)) == 17
		and route_mesh.get_meta(&"dock05_boarding_alignment_boxes", [])
			== expected_dock05_alignment,
		"the same route batch includes three exact Dock 05 boarding-alignment rungs"
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


## CAMERA-LANE. Focused regression for the Phase 10 §1 camera-lane fix.
##
## Four pieces of this module's service dressing were drawn as heavy steel and
## heavy freight while carrying no collision at all, so the chase rig's
## `SpringArm3D` sweep — which queries `CAMERA_OBSTRUCTION_QUERY_MASK` — had
## nothing to retract against and the player's camera clipped straight through
## them on four different craft's assist and launch lanes, up to 0.737 m deep.
## Two of them were worse than that: `LaunchFramePort` and `LaunchFrameHeader`
## stood inside Dock 04's *own published approach lane*, and the container row
## stood inside the VIP reception suite, the Aft Junction Stack's operations
## room and on the fleet-dock comb's trunk walking plate.
##
## What this asserts is the shape of the fix, not just its presence: every
## declared structural collider pairs with a piece that is actually drawn, at the
## same transform and the same size, and every service piece stays inside the
## 28 x 42 m pad it belongs to so it cannot reach into a neighbour's lane again.
func _test_service_structure_collision(berths: Node3D, audit: Dictionary) -> void:
	var structure: Dictionary = berths.call("get_service_structure_audit")
	_check(
		bool(structure.get("valid", false))
		and (structure.get("errors", PackedStringArray()) as PackedStringArray).is_empty()
		and int(structure.get("structural_bodies", -1)) == Berths.SERVICE_STRUCTURE_BODIES
		and int(structure.get("structural_shapes", -1)) == Berths.SERVICE_STRUCTURE_SHAPES
		and (audit.get("service_structure", {}) as Dictionary) == structure,
		"every drawn service structure piece has a matching World-layer collider and the module publishes the pairing"
	)

	var root_node := berths.get_node_or_null(^"ServiceStructure") as Node3D
	var layers_exact := root_node != null
	var colliders_inside_pad := root_node != null
	var half := Vector3(
		Berths.PAD_SIZE.x * 0.5, INF, Berths.PAD_SIZE.z * 0.5
	)
	var worst_overhang := -INF
	for pad_id: StringName in berths.get_pad_ids():
		var body := root_node.get_node_or_null(NodePath(String(pad_id))) as StaticBody3D \
			if root_node != null else null
		if body == null:
			continue
		layers_exact = layers_exact \
			and body.collision_layer == PhysicsLayers.WORLD \
			and body.collision_mask == 0
		for child in body.get_children():
			var shape_node := child as CollisionShape3D
			if shape_node == null or shape_node.shape is not BoxShape3D:
				continue
			var extent := (shape_node.shape as BoxShape3D).size * 0.5
			for axis in [0, 2]:
				var reach := absf(shape_node.position[axis]) + extent[axis]
				worst_overhang = maxf(worst_overhang, reach - half[axis])
				colliders_inside_pad = colliders_inside_pad and reach <= half[axis]
	_check(
		layers_exact and colliders_inside_pad,
		"every service-structure collider stays inside its own %.0f x %.0f m pad (worst reach %.2f m past the edge)"
			% [Berths.PAD_SIZE.x, Berths.PAD_SIZE.z, worst_overhang]
	)
