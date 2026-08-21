extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/aft_junction_stack.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. A frame count, never a wall-clock grace: the door advances in
## `_physics_process`, and only a frame budget measures the same amount of panel
## motion on a loaded box as on an idle one.
const FRAME_BUDGET_GRACE := 30

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "AftJunctionStackTestRoot"
	root.add_child(_test_root)

	var module := MODULE_SCENE.instantiate() as AftJunctionStack
	_check(module != null, "aft junction scene instantiates as AftJunctionStack")
	if module == null:
		_finish()
		return
	module.position = Vector3(23.0, 1.5, -31.0)
	module.rotation_degrees.y = 27.0
	_test_root.add_child(module)
	_test_synchronous_parent_validation(module)
	await process_frame
	await physics_frame
	await physics_frame

	_test_identity_evidence_and_audit(module)
	_test_route_and_space_contract(module)
	await _test_collision_backed_surfaces(module)
	await _test_stair_circulation(module)
	await _test_operations_door_and_room(module)
	_test_operations_contents(module)
	_test_pod_corner_collar_visual_resource_sharing(module)
	_test_vip_facade_column_trim_batch(module)
	_test_spine_clamp_visual_resource_sharing(module)
	_test_roof_vent_collar_visual_resource_sharing(module)
	_test_rack_cable_tray_clamp_visual_resource_sharing(module)
	_test_console_shock_collar_visual_resource_sharing(module)
	_test_pedestal_bearing_visual_resource_sharing(module)
	_test_conduit_collar_visual_resource_sharing(module)
	_test_interface_collar_profile(module)
	_test_vip_landmark(module)
	await _test_negative_space(module)
	_test_collision_matrix(module)
	await _test_module_enabled_currentness(module)
	await _test_cleanup(module)
	_finish()


## No frame has elapsed when this runs. ShipyardWorld consumes the same public
## contracts from its parent `_ready`, so this witness must be green on the exact
## stack where `add_child()` completes the Aft module's ready cascade.
func _test_synchronous_parent_validation(module: AftJunctionStack) -> void:
	var resource_audit := module.get_pod_corner_collar_visual_allocation_audit()
	var module_contract := StationModuleContract.new().validate_contract(module)
	var operations_panel := module.get_node_or_null(
		^"OperationsEntrance/SlidingPanel/PanelMesh"
	) as MeshInstance3D
	var vip_panel := module.get_node_or_null(
		^"VIPAccess/SlidingPanel/PanelMesh"
	) as MeshInstance3D
	var operations_material := (
		operations_panel.material_override as StandardMaterial3D
		if operations_panel != null else null
	)
	var vip_material := (
		vip_panel.material_override as StandardMaterial3D
		if vip_panel != null else null
	)
	_check(
		bool(resource_audit.valid)
		and int(resource_audit.current.material_resource_allocations) == 30
		and (resource_audit.errors as PackedStringArray).is_empty(),
		"Aft resource census is immediately green at 30 materials before any deferred frame"
	)
	_check(
		operations_material != null
		and vip_material != null
		and operations_material != vip_material
		and operations_material.uv1_world_triplanar
		and vip_material.uv1_world_triplanar,
		"both host-coloured StationDoor leaves synchronously own their panel-surface bindings"
	)
	_check(
		bool(module_contract.valid)
		and (module_contract.errors as PackedStringArray).is_empty()
		and module.get_validation_errors().is_empty(),
		"the complete public Aft contract is valid on the synchronous parent-validation stack"
	)


func _test_identity_evidence_and_audit(module: AftJunctionStack) -> void:
	_check(module.get_module_id() == &"aft-junction-stack", "module exposes a stable kebab-case identity")
	_check(bool(module.get_meta("station_module", false)), "root metadata identifies a station module")
	_check(str(module.get_meta("evidence_status", "")) == "modern_interpretation", "root metadata rejects an authenticated-geometry claim")
	_check(bool(module.get_meta("source_bounded", false)), "root metadata marks the interpretation as source-bounded")
	_check(module.is_in_group("station_modules"), "module participates in station-module discovery")

	var evidence := module.get_evidence_metadata()
	_check(int(evidence.schema_version) == AftJunctionStack.SCHEMA_VERSION, "evidence report has a stable schema")
	_check(str(evidence.evidence_status) == "modern_interpretation", "evidence API labels exact layout as modern interpretation")
	_check((evidence.references as PackedStringArray).size() >= 4, "evidence API exposes source/timestamp references")
	_check(
		"VIP" in str(evidence.content_note) and "no authenticated interior" in str(evidence.content_note) \
			and "confidence none" in str(evidence.content_note),
		"evidence note limits the VIP claim to a landmark and grades what stands behind it"
	)
	var returned_references := evidence.references as PackedStringArray
	returned_references.append("mutation")
	_check(not (module.get_evidence_metadata().references as PackedStringArray).has("mutation"), "evidence arrays are detached from module state")

	var audit := module.get_audit_report()
	_check(bool(audit.valid), "fully constructed junction passes its public audit")
	_check((audit.errors as PackedStringArray).is_empty(), "valid audit reports no hidden structural errors")
	_check(int(audit.chair_count) == 4 and int(audit.console_bay_count) == 3, "audit exposes required operations furniture counts")
	_check(float(audit.open_to_space_ratio) >= 0.5, "audit proves a majority-open walkable-area estimate")
	(audit.operations_room as Dictionary)["half_extents"] = Vector3.ZERO
	_check((module.get_audit_report().operations_room as Dictionary).half_extents != Vector3.ZERO, "audit dictionaries are detached from module state")


func _test_route_and_space_contract(module: AftJunctionStack) -> void:
	var expected_routes := PackedStringArray([
		"approach",
		"lower-junction",
		"stair-base",
		"stair-top",
		"operations-room",
		"upper-floor",
		"vip-landmark",
	])
	for route_id in expected_routes:
		_check(module.has_route_marker(StringName(route_id)), "route marker is exposed: %s" % route_id)
		_check(module.get_route_marker(StringName(route_id)) != null, "route marker resolves to a physical Marker3D: %s" % route_id)
	_check(module.get_route_ids().size() == expected_routes.size(), "route registry has no implicit or missing route entries")
	_check(module.get_route_marker(&"missing-route") == null, "unknown route marker has no fallback")

	var floor_elevations := module.get_floor_elevations()
	_check(floor_elevations.size() == 2, "module declares exactly two principal floor elevations")
	_check(is_equal_approx(floor_elevations[0], 0.0), "lower floor uses the integration-anchor elevation")
	_check(is_equal_approx(floor_elevations[1], 4.2), "upper floor exposes a distinct 4.2 metre elevation")
	_check(floor_elevations[1] - floor_elevations[0] > 3.5, "two levels are spatially meaningful rather than decorative offsets")

	var footprint := module.get_integration_footprint()
	var footprint_min: Vector3 = footprint.local_min
	var footprint_max: Vector3 = footprint.local_max
	_check(footprint_min.x < -10.0 and footprint_max.x > 11.0, "integration footprint exposes the asymmetric east-west envelope")
	_check(footprint_min.z < -2.0 and footprint_max.z >= 21.0, "integration footprint includes approach and aft facade")
	_check((footprint.local_size as Vector3).is_finite(), "integration footprint size is finite")
	_check(module.get_module_anchor().global_transform.is_equal_approx(module.global_transform), "module anchor is the exact root connection transform")


func _test_collision_backed_surfaces(module: AftJunctionStack) -> void:
	var lower_hit := await _ray_down(module, Vector3(0, 2.0, 7.2), Vector3(0, -1.0, 7.2))
	_check(not lower_hit.is_empty(), "lower open junction floor is backed by real physics")
	if not lower_hit.is_empty():
		var lower_local := module.to_local(lower_hit.position)
		_check(is_equal_approx(lower_local.y, 0.0), "lower collision surface matches its declared elevation")

	var room_hit := await _ray_down(module, Vector3(5.6, 2.0, 10.7), Vector3(5.6, -1.0, 10.7))
	_check(not room_hit.is_empty(), "operations-room floor is backed by real physics")
	if not room_hit.is_empty():
		_check(absf(module.to_local(room_hit.position).y) < 0.02, "operations floor joins the lower circulation without a hidden step")

	var upper_hit := await _ray_down(module, Vector3(-5.2, 6.0, 16.2), Vector3(-5.2, 3.0, 16.2))
	_check(not upper_hit.is_empty(), "upper open floor is backed by real physics")
	if not upper_hit.is_empty():
		_check(absf(module.to_local(upper_hit.position).y - 4.2) < 0.02, "upper collision surface matches its declared elevation")


func _test_stair_circulation(module: AftJunctionStack) -> void:
	var profile := module.get_stair_profile()
	_check(int(profile.step_count) == 15, "stair exposes fifteen readable treads")
	_check(float(profile.riser_height) <= 0.31, "stair riser interval remains avatar-friendly")
	_check(float(profile.tread_run) >= 0.69, "stair tread run is generous enough for circulation")
	_check(float(profile.clear_width) >= 2.8, "stair preserves a broad player-clear route")
	_check(float(profile.minimum_head_clearance) >= 2.6, "stair publishes more than player-height head clearance")
	_check(str(profile.collision_solution) == "continuous_ramp_beneath_visible_treads", "stair explicitly exposes its snag-resistant physical solution")

	var samples := module.get_stair_surface_samples()
	_check(samples.size() == int(profile.step_count), "stair provides one physical test sample per visible tread")
	var every_step_supported := true
	var every_step_clear := true
	for sample in samples:
		var support_hit := await _ray_local(module, sample + Vector3.UP * 0.55, sample - Vector3.UP * 0.5)
		if support_hit.is_empty():
			every_step_supported = false
		var clearance_hit := await _ray_local(
			module,
			sample + Vector3.UP * 0.24,
			sample + Vector3.UP * float(profile.minimum_head_clearance)
		)
		if not clearance_hit.is_empty():
			every_step_clear = false
	_check(every_step_supported, "every visible stair interval has continuous collision support")
	_check(every_step_clear, "stair centreline preserves the published head clearance at every interval")
	_check(absf(samples[0].y - 0.11) < 0.02, "stair begins at the lower floor without a high first step")
	_check(absf(samples[samples.size() - 1].y - 4.31) < 0.02, "stair terminates flush with the upper landing surface")


func _test_operations_door_and_room(module: AftJunctionStack) -> void:
	var door := module.get_operations_entrance()
	_check(door != null, "cyan operations entrance is exposed as StationDoor")
	if door == null:
		return
	_check(door.can_interact(), "operations entrance begins operable")
	_check("OPERATIONS ACCESS" in door.get_interaction_prompt(), "operations door publishes a diegetic access prompt")
	_check(str(door.get_meta("evidence_status")) == "modern_interpretation", "operations door preserves its own evidence metadata")
	_check(door.is_portal_blocked(), "closed operations entrance is physically blocked")
	var closed_hit := await _ray_through_door(door)
	_check(not closed_hit.is_empty(), "closed operations portal blocks a real physics ray")
	if not closed_hit.is_empty():
		_check(closed_hit.collider == door.get_node("PortalBlocker"), "dedicated StationDoor portal collider owns the closed obstruction")

	_check(door.interact(module), "operations entrance accepts direct component interaction")
	_check(door.get_state() == StationDoor.DoorState.OPENING, "operations entrance uses StationDoor's deterministic opening state")
	var opening_hit := await _ray_through_door(door)
	_check(not opening_hit.is_empty(), "portal remains physically blocked during opening")
	var entrance_opened := await _wait_for_door_state(door, StationDoor.DoorState.OPEN, 1.5)
	_check(entrance_opened, "operations entrance completes its motion inside its physics-frame budget")
	_check(door.is_open(), "operations entrance reaches fully open")
	_check(not door.is_portal_blocked(), "fully open operations entrance clears its blocker")
	var open_hit := await _ray_through_door(door)
	_check(open_hit.is_empty(), "fully open entrance exposes an unobstructed room threshold")

	var room_anchor := module.get_operations_room_marker()
	_check(room_anchor != null and module.contains_operations_room(room_anchor.global_position), "operations anchor lies inside the occupancy volume")
	_check(module.contains_operations_room(module.to_global(Vector3(1.0, 1.0, 10.0))), "entry-side aisle is inside the operations occupancy volume")
	_check(not module.contains_operations_room(module.to_global(Vector3(-2.0, 1.0, 13.2))), "open junction does not masquerade as room occupancy")
	_check(not module.contains_operations_room(module.to_global(Vector3(5.6, 6.0, 13.2))), "space above the operations roof is outside room occupancy")

	var room_volume := module.get_operations_room_volume()
	_check((room_volume.half_extents as Vector3).x >= 5.0, "room volume exposes its broad interior width")
	_check((room_volume.world_transform as Transform3D).origin.is_equal_approx(module.to_global(room_volume.local_center)), "room volume composes through the module transform")


func _test_operations_contents(module: AftJunctionStack) -> void:
	_check(module.get_chair_count() == 4, "operations room contains four physical chairs")
	_check(module.get_console_bay_count() == 3, "operations room contains three physical console bays")
	var chairs := module.find_children("OperationsChair*", "Node3D", true, false)
	var consoles := module.find_children("ConsoleBay*", "Node3D", true, false)
	_check(chairs.size() == 4, "four independently addressable chair roots exist in the scene tree")
	_check(consoles.size() == 3, "three independently addressable console roots exist in the scene tree")
	var furniture_tagged := true
	for chair in chairs:
		furniture_tagged = furniture_tagged and bool(chair.get_meta("station_chair", false))
	for console in consoles:
		furniture_tagged = furniture_tagged and bool(console.get_meta("station_console_bay", false))
	_check(furniture_tagged, "operations furniture exposes stable semantic metadata")
	var service_wall := module.get_service_wall()
	_check(service_wall != null and bool(service_wall.get_meta("station_service_wall", false)), "service wall is present and semantically tagged")


func _test_pod_corner_collar_visual_resource_sharing(
		module: AftJunctionStack
	) -> void:
	var report := module.get_pod_corner_collar_visual_allocation_audit()
	print(
		"AFT_POD_CORNER_COLLAR_VISUALS: "
		+ "nodes %d->%d submissions %d->%d mesh_resources %d->%d copies %d->%d" % [
			int(report.legacy.renderer_nodes),
			int(report.current.renderer_nodes),
			int(report.legacy.surface_submissions),
			int(report.current.surface_submissions),
			int(report.legacy.mesh_resource_allocations),
			int(report.current.mesh_resource_allocations),
			int(report.legacy.drawn_copies),
			int(report.current.drawn_copies),
		]
	)
	_check(
		bool(report.valid)
		and StringName(report.selected_family) == &"pod_corner_collars"
		and report.legacy == {
			"descendant_nodes": 1162,
			"renderer_nodes": 852,
			"drawn_copies": 852,
			"surface_submissions": 852,
			"mesh_resource_allocations": 318,
			"material_resource_allocations": 30,
			"family_visual_nodes": 4,
			"family_visible_copies": 4,
			"family_surface_submissions": 4,
			"family_mesh_resource_allocations": 4,
		}
		and report.current == {
			"descendant_nodes": 1159,
			"renderer_nodes": 849,
			"drawn_copies": 852,
			"surface_submissions": 849,
			"mesh_resource_allocations": 294,
			"material_resource_allocations": 30,
			"family_visual_nodes": 4,
			"family_visible_copies": 4,
			"family_surface_submissions": 4,
			"family_mesh_resource_allocations": 1,
		},
		"pod, spine, roof-vent, rack, console, chair-bearing and conduit sharing plus the VIP trim batch freeze 1159 descendants, 849 renderers/submissions, 852 copies, and 294 mesh allocations"
	)
	_check(
		report.reductions == {
			"descendant_nodes": 3,
			"renderer_nodes": 3,
			"drawn_copies": 0,
			"surface_submissions": 3,
			"mesh_resource_allocations": 23,
			"material_resource_allocations": 0,
		}
		and not bool(report.batched)
		and not bool(report.frame_time_claimed)
		and not bool(report.gpu_draw_call_claimed)
		and not bool(report.vram_claimed)
		and not bool(report.whole_scene_budget_claimed)
		and not bool(report.pixel_equivalence_claimed),
		"selected pod-family evidence remains immutable sharing, with no timing, GPU, VRAM, whole-scene or pixel claim"
	)

	var collars: Array[MeshInstance3D] = []
	for raw_node in module.find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(
			AftJunctionStack.POD_CORNER_COLLAR_FAMILY_META, &""
		)) == AftJunctionStack.POD_CORNER_COLLAR_FAMILY_ID:
			collars.append(instance)
	var exact_family := collars.size() == AftJunctionStack.POD_CORNER_COLLAR_COPY_COUNT
	var shared_mesh: TorusMesh = collars[0].mesh as TorusMesh if not collars.is_empty() else null
	for index in collars.size():
		var collar := collars[index]
		exact_family = (
			exact_family
			and collar.mesh == shared_mesh
			and collar.position.is_equal_approx(
				AftJunctionStack.POD_CORNER_COLLAR_POSITIONS[index]
				as Vector3
			)
			and collar.rotation_degrees.is_equal_approx(Vector3(90.0, 0.0, 0.0))
			and collar.scale == Vector3.ONE
			and collar.visible
			and collar.layers == 1
			and collar.cast_shadow \
				== GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and collar.get_child_count() == 0
			and collar.get_script() == null
			and StringName(collar.get_meta(TorusGeometryBudget.PROFILE_META, &"")) \
				!= TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR
		)
	_check(
		exact_family
		and shared_mesh != null
		and is_equal_approx(
			shared_mesh.inner_radius,
			AftJunctionStack.POD_CORNER_COLLAR_INNER_RADIUS
		)
		and is_equal_approx(
			shared_mesh.outer_radius,
			AftJunctionStack.POD_CORNER_COLLAR_OUTER_RADIUS
		)
		and shared_mesh.rings == AftJunctionStack.POD_CORNER_COLLAR_RINGS
		and shared_mesh.ring_segments \
			== AftJunctionStack.POD_CORNER_COLLAR_RING_SEGMENTS
		and shared_mesh.get_surface_count() == 1,
		"four childless named pod collars preserve transforms, material/render policy and exact torus recipe through one mesh identity"
	)
	_check(
		module.get_node_or_null(
			^"Structure/OperationsRoom/PodCornerCollar"
		) == collars[0]
		and module.get_operations_entrance() != null
		and module.get_vip_access() != null
		and module.get_service_wall() != null,
		"resource sharing retains the existing collar path and door, VIP and service-wall semantic paths"
	)

	(report.current as Dictionary)["mesh_resource_allocations"] = -1
	(report.behavior_rows as Array).clear()
	var detached := module.get_pod_corner_collar_visual_allocation_audit()
	_check(
		int(detached.current.mesh_resource_allocations) == 294
		and (detached.behavior_rows as Array).size() == 4,
		"component-local allocation and transform evidence is deeply detached"
	)

	# The door test immediately before this one intentionally leaves the reusable
	# StationDoor open. Recovery must restore that exact live validator state,
	# rather than pretending an unrelated subsystem is still at startup.
	var baseline_errors := module.get_validation_errors()
	var original_outer_radius := shared_mesh.outer_radius
	shared_mesh.outer_radius += 0.01
	var recipe_red := module.get_pod_corner_collar_visual_allocation_audit()
	var recipe_reached_all_copies := true
	for collar in collars:
		recipe_reached_all_copies = (
			recipe_reached_all_copies
			and is_equal_approx(
				(collar.mesh as TorusMesh).outer_radius,
				original_outer_radius + 0.01
			)
		)
	_check(
		not bool(recipe_red.valid)
		and (recipe_red.errors as PackedStringArray).has(
			"pod_corner_collar_mesh_recipe_drift"
		)
		and recipe_reached_all_copies
		and module.get_validation_errors().has(
			"shared pod-corner collar visual allocation contract drifted"
		),
		"RED recipe mutation reaches all four shared copies and turns the module audit red"
	)
	shared_mesh.outer_radius = original_outer_radius

	var original_second_mesh := collars[1].mesh
	collars[1].mesh = shared_mesh.duplicate() as Mesh
	var identity_red := module.get_pod_corner_collar_visual_allocation_audit()
	_check(
		not bool(identity_red.valid)
		and (identity_red.errors as PackedStringArray).has(
			"pod_corner_collar_mesh_identity_not_shared"
		)
		and int(identity_red.current.mesh_resource_allocations) == 295
		and int(identity_red.current.family_mesh_resource_allocations) == 2,
		"RED identity mutation rejects an exact-looking private collar mesh allocation"
	)
	collars[1].mesh = original_second_mesh
	_check(
		bool(module.get_pod_corner_collar_visual_allocation_audit().valid)
		and module.get_validation_errors() == baseline_errors,
		"restoring the shared pod-corner recipe and identity returns the exact pre-mutation module validator state"
	)


func _test_spine_clamp_visual_resource_sharing(module: AftJunctionStack) -> void:
	var report := module.get_spine_clamp_visual_allocation_audit()
	_check(
		bool(report.valid)
		and report.legacy == {
			"visual_nodes": 5,
			"drawn_copies": 5,
			"surface_submissions": 5,
			"mesh_resource_allocations": 5,
			"material_resource_allocations": 1,
		}
		and report.current == {
			"visual_nodes": 5,
			"drawn_copies": 5,
			"surface_submissions": 5,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
		}
		and report.reductions == {
			"visual_nodes": 0,
			"drawn_copies": 0,
			"surface_submissions": 0,
			"mesh_resource_allocations": 4,
			"material_resource_allocations": 0,
		}
		and not bool(report.batched)
		and not bool(report.renderer_values_changed)
		and not bool(report.normalised)
		and report.authored_tessellation == Vector2i(48, 16)
		and report.live_tessellation == Vector2i(48, 16)
		and int(report.collision_authority_count) == 0
		and int(report.semantic_authority_count) == 0,
		"five SpineClamp renderers preserve nodes, copies and submissions while immutable mesh allocations fall 5 -> 1"
	)

	var paths := report.node_paths as PackedStringArray
	var clamps: Array[MeshInstance3D] = []
	for raw_node in module.find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(
			AftJunctionStack.INTERFACE_COLLAR_KIND_META, &""
		)) == &"SpineClamp":
			clamps.append(instance)
	var shared_mesh := clamps[0].mesh as TorusMesh if not clamps.is_empty() else null
	var exact_family := clamps.size() == 5 and paths.size() == 5
	for index in clamps.size():
		var clamp := clamps[index]
		exact_family = (
			exact_family
			and clamp.mesh == shared_mesh
			and clamp.position.is_equal_approx(
				AftJunctionStack.SPINE_CLAMP_POSITIONS[index] as Vector3
			)
			and clamp.rotation_degrees.is_equal_approx(Vector3(90.0, 0.0, 0.0))
			and clamp.scale == Vector3.ONE
			and clamp.visible
			and clamp.layers == 1
			and clamp.cast_shadow \
				== GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and clamp.material_overlay == null
			and is_zero_approx(clamp.transparency)
			and clamp.get_child_count() == 0
			and clamp.get_script() == null
		)
	_check(
		exact_family
		and paths[0] \
			== "Structure/OperationsRoom/VisualPressureEnvelope/SpineClamp"
		and String(clamps[1].name).begins_with("@MeshInstance3D@")
		and String(clamps[4].name).begins_with("@MeshInstance3D@")
		and shared_mesh != null
		and is_equal_approx(shared_mesh.inner_radius, 0.16)
		and is_equal_approx(shared_mesh.outer_radius, 0.225)
		and shared_mesh.rings == 48
		and shared_mesh.ring_segments == 16
		and shared_mesh.get_surface_count() == 1,
		"the stable first/generated node paths, exact transforms, copper renderer state and authored 48x16 torus recipe remain intact"
	)

	(report.current as Dictionary)["mesh_resource_allocations"] = -1
	paths[0] = "mutated"
	(report.authored_transforms as Array).clear()
	var detached := module.get_spine_clamp_visual_allocation_audit()
	_check(
		int(detached.current.mesh_resource_allocations) == 1
		and (detached.node_paths as PackedStringArray)[0] \
			== "Structure/OperationsRoom/VisualPressureEnvelope/SpineClamp"
		and (detached.authored_transforms as Array).size() == 5,
		"SpineClamp allocation, path and transform evidence is deeply detached"
	)

	var baseline_errors := module.get_validation_errors()
	var original_second_mesh := clamps[1].mesh
	clamps[1].mesh = shared_mesh.duplicate() as Mesh
	var identity_red := module.get_spine_clamp_visual_allocation_audit()
	_check(
		not bool(identity_red.valid)
		and (identity_red.errors as PackedStringArray).has(
			"spine_clamp_mesh_identity_not_shared"
		)
		and int(identity_red.current.mesh_resource_allocations) == 2,
		"RED identity mutation rejects a private exact-looking SpineClamp mesh"
	)
	clamps[1].mesh = original_second_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings += 1
	var recipe_red := module.get_spine_clamp_visual_allocation_audit()
	_check(
		not bool(recipe_red.valid)
		and (recipe_red.errors as PackedStringArray).has(
			"spine_clamp_torus_recipe_drift"
		),
		"RED recipe mutation rejects arbitrary SpineClamp tessellation"
	)
	shared_mesh.rings = original_rings

	shared_mesh.set_meta(TorusGeometryBudget.AUTHORED_META, Vector2i(47, 15))
	var budget_red := module.get_spine_clamp_visual_allocation_audit()
	_check(
		not bool(budget_red.valid)
		and (budget_red.errors as PackedStringArray).has(
			"spine_clamp_budget_metadata_drift"
		),
		"RED authored-budget metadata mutation rejects a false SpineClamp recipe"
	)
	shared_mesh.remove_meta(TorusGeometryBudget.AUTHORED_META)

	var original_material := clamps[2].material_override
	clamps[2].material_override = null
	var material_red := module.get_spine_clamp_visual_allocation_audit()
	_check(
		not bool(material_red.valid)
		and (material_red.errors as PackedStringArray).has(
			"spine_clamp_material_identity_drift"
		),
		"RED material mutation rejects loss of the shared copper binding"
	)
	clamps[2].material_override = original_material

	var original_layers := clamps[3].layers
	clamps[3].layers = 2
	var renderer_red := module.get_spine_clamp_visual_allocation_audit()
	_check(
		not bool(renderer_red.valid)
		and (renderer_red.errors as PackedStringArray).has(
			"spine_clamp_renderer_state_drift"
		),
		"RED renderer mutation rejects a SpineClamp layer drift"
	)
	clamps[3].layers = original_layers

	clamps[4].set_meta("forbidden_evidence_authority", true)
	var authority_red := module.get_spine_clamp_visual_allocation_audit()
	_check(
		not bool(authority_red.valid)
		and (authority_red.errors as PackedStringArray).has(
			"spine_clamp_gained_authority_or_lifecycle"
		)
		and int(authority_red.semantic_authority_count) == 1,
		"RED metadata mutation rejects evidence authority on a visual-only SpineClamp"
	)
	clamps[4].remove_meta("forbidden_evidence_authority")
	_check(
		bool(module.get_spine_clamp_visual_allocation_audit().valid)
		and module.get_validation_errors() == baseline_errors,
		"restoring SpineClamp identity, recipe, budget metadata, material, renderer and authority returns the exact validator state"
	)


func _test_roof_vent_collar_visual_resource_sharing(module: AftJunctionStack) -> void:
	var report := module.get_roof_vent_collar_visual_allocation_audit()
	_check(
		bool(report.valid)
		and report.legacy == {"visual_nodes": 2, "drawn_copies": 2, "surface_submissions": 2, "mesh_resource_allocations": 2, "material_resource_allocations": 1}
		and report.current == {"visual_nodes": 2, "drawn_copies": 2, "surface_submissions": 2, "mesh_resource_allocations": 1, "material_resource_allocations": 1}
		and report.reductions == {"visual_nodes": 0, "drawn_copies": 0, "surface_submissions": 0, "mesh_resource_allocations": 1, "material_resource_allocations": 0}
		and not bool(report.batched) and not bool(report.renderer_values_changed),
		"two roof-vent collars retain nodes, submissions and renderer values while immutable TorusMesh allocations fall 2 -> 1"
	)
	var collars: Array[MeshInstance3D] = []
	for path_value in report.node_paths as PackedStringArray:
		var collar := module.get_node_or_null(NodePath(path_value)) as MeshInstance3D
		if collar != null:
			collars.append(collar)
	var shared_mesh := collars[0].mesh as TorusMesh if collars.size() == 2 else null
	_check(
		collars.size() == 2 and shared_mesh != null
		and collars[0].mesh == shared_mesh and collars[1].mesh == shared_mesh
		and collars[0].position.is_equal_approx(AftJunctionStack.ROOF_VENT_COLLAR_POSITIONS[0])
		and collars[1].position.is_equal_approx(AftJunctionStack.ROOF_VENT_COLLAR_POSITIONS[1])
		and is_equal_approx(shared_mesh.inner_radius, AftJunctionStack.ROOF_VENT_COLLAR_INNER_RADIUS)
		and is_equal_approx(shared_mesh.outer_radius, AftJunctionStack.ROOF_VENT_COLLAR_OUTER_RADIUS)
		and shared_mesh.rings == AftJunctionStack.ROOF_VENT_COLLAR_RINGS
		and shared_mesh.ring_segments == AftJunctionStack.ROOF_VENT_COLLAR_RING_SEGMENTS
		and shared_mesh.get_surface_count() == 1 and shared_mesh.material == null,
		"roof-vent collar paths, transforms, mid-grey overrides and exact torus recipe remain intact"
	)
	if collars.size() == 2:
		var original_mesh := collars[1].mesh
		collars[1].mesh = shared_mesh.duplicate() as TorusMesh
		var red := module.get_roof_vent_collar_visual_allocation_audit()
		_check(
			not bool(red.valid) and (red.errors as PackedStringArray).has("roof_vent_collar_mesh_identity_not_shared")
			and int((red.current as Dictionary).mesh_resource_allocations) == 2,
			"RED: a private exact-looking roof-vent collar mesh fails the sharing audit"
		)
		collars[1].mesh = original_mesh
		_check(bool(module.get_roof_vent_collar_visual_allocation_audit().valid), "restoring the roof-vent shared mesh returns its audit green")


func _test_rack_cable_tray_clamp_visual_resource_sharing(
		module: AftJunctionStack
	) -> void:
	var report := module.get_rack_cable_tray_clamp_visual_allocation_audit()
	_check(
		bool(report.valid)
		and report.legacy == {
			"visual_nodes": 4,
			"drawn_copies": 4,
			"surface_submissions": 4,
			"mesh_resource_allocations": 4,
			"material_resource_allocations": 1,
		}
		and report.current == {
			"visual_nodes": 4,
			"drawn_copies": 4,
			"surface_submissions": 4,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
		}
		and report.reductions == {
			"visual_nodes": 0,
			"drawn_copies": 0,
			"surface_submissions": 0,
			"mesh_resource_allocations": 3,
			"material_resource_allocations": 0,
		}
		and not bool(report.batched)
		and not bool(report.renderer_values_changed)
		and not bool(report.normalised)
		and report.authored_tessellation == Vector2i(48, 16)
		and report.live_tessellation == Vector2i(48, 16)
		and int(report.collision_authority_count) == 0
		and int(report.semantic_authority_count) == 0,
		"four RackCableTrayClamp renderers preserve nodes, copies and submissions while immutable mesh allocations fall 4 -> 1"
	)

	var paths := report.node_paths as PackedStringArray
	var clamps: Array[MeshInstance3D] = []
	for raw_node in module.find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(
			AftJunctionStack.INTERFACE_COLLAR_KIND_META, &""
		)) == &"RackCableTrayClamp":
			clamps.append(instance)
	var shared_mesh := clamps[0].mesh as TorusMesh if not clamps.is_empty() else null
	var exact_family := clamps.size() == 4 and paths.size() == 4
	for index in clamps.size():
		var clamp := clamps[index]
		exact_family = (
			exact_family
			and clamp.mesh == shared_mesh
			and clamp.position.is_equal_approx(
				AftJunctionStack.RACK_CABLE_TRAY_CLAMP_POSITIONS[index] as Vector3
			)
			and clamp.rotation_degrees.is_equal_approx(Vector3(0.0, 0.0, 90.0))
			and clamp.scale == Vector3.ONE
			and clamp.visible
			and clamp.layers == 1
			and clamp.cast_shadow \
				== GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and clamp.material_overlay == null
			and is_zero_approx(clamp.transparency)
			and clamp.get_child_count() == 0
			and clamp.get_script() == null
		)
	_check(
		exact_family
		and paths[0] == (
			"Structure/OperationsRoom/OperationsContent/WatchRackBank/"
			+ "RackCableTrayClamp"
		)
		and String(clamps[1].name).begins_with("@MeshInstance3D@")
		and String(clamps[3].name).begins_with("@MeshInstance3D@")
		and shared_mesh != null
		and is_equal_approx(shared_mesh.inner_radius, 0.09)
		and is_equal_approx(shared_mesh.outer_radius, 0.135)
		and shared_mesh.rings == 48
		and shared_mesh.ring_segments == 16
		and shared_mesh.get_surface_count() == 1,
		"the stable first/generated rack-clamp paths, exact transforms, brass renderer state and authored 48x16 recipe remain intact"
	)

	(report.current as Dictionary)["mesh_resource_allocations"] = -1
	paths[0] = "mutated"
	(report.authored_transforms as Array).clear()
	var detached := module.get_rack_cable_tray_clamp_visual_allocation_audit()
	_check(
		int(detached.current.mesh_resource_allocations) == 1
		and (detached.node_paths as PackedStringArray)[0] == (
			"Structure/OperationsRoom/OperationsContent/WatchRackBank/"
			+ "RackCableTrayClamp"
		)
		and (detached.authored_transforms as Array).size() == 4,
		"rack-clamp allocation, path and transform evidence is deeply detached"
	)

	var baseline_errors := module.get_validation_errors()
	var original_second_mesh := clamps[1].mesh
	clamps[1].mesh = shared_mesh.duplicate() as Mesh
	var identity_red := module.get_rack_cable_tray_clamp_visual_allocation_audit()
	_check(
		not bool(identity_red.valid)
		and (identity_red.errors as PackedStringArray).has(
			"rack_cable_tray_clamp_mesh_identity_not_shared"
		)
		and int(identity_red.current.mesh_resource_allocations) == 2,
		"RED identity mutation rejects a private exact-looking rack-clamp mesh"
	)
	clamps[1].mesh = original_second_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings += 1
	var recipe_red := module.get_rack_cable_tray_clamp_visual_allocation_audit()
	_check(
		not bool(recipe_red.valid)
		and (recipe_red.errors as PackedStringArray).has(
			"rack_cable_tray_clamp_torus_recipe_drift"
		),
		"RED recipe mutation rejects arbitrary rack-clamp tessellation"
	)
	shared_mesh.rings = original_rings

	shared_mesh.set_meta(TorusGeometryBudget.AUTHORED_META, Vector2i(47, 15))
	var budget_red := module.get_rack_cable_tray_clamp_visual_allocation_audit()
	_check(
		not bool(budget_red.valid)
		and (budget_red.errors as PackedStringArray).has(
			"rack_cable_tray_clamp_budget_metadata_drift"
		),
		"RED authored-budget metadata mutation rejects a false rack-clamp recipe"
	)
	shared_mesh.remove_meta(TorusGeometryBudget.AUTHORED_META)

	var original_material := clamps[2].material_override
	clamps[2].material_override = null
	var material_red := module.get_rack_cable_tray_clamp_visual_allocation_audit()
	_check(
		not bool(material_red.valid)
		and (material_red.errors as PackedStringArray).has(
			"rack_cable_tray_clamp_material_identity_drift"
		),
		"RED material mutation rejects loss of the shared brass binding"
	)
	clamps[2].material_override = original_material

	var original_layers := clamps[3].layers
	clamps[3].layers = 2
	var renderer_red := module.get_rack_cable_tray_clamp_visual_allocation_audit()
	_check(
		not bool(renderer_red.valid)
		and (renderer_red.errors as PackedStringArray).has(
			"rack_cable_tray_clamp_renderer_state_drift"
		),
		"RED renderer mutation rejects a rack-clamp layer drift"
	)
	clamps[3].layers = original_layers

	clamps[0].set_meta("forbidden_evidence_authority", true)
	var authority_red := module.get_rack_cable_tray_clamp_visual_allocation_audit()
	_check(
		not bool(authority_red.valid)
		and (authority_red.errors as PackedStringArray).has(
			"rack_cable_tray_clamp_gained_authority_or_lifecycle"
		)
		and int(authority_red.semantic_authority_count) == 1,
		"RED metadata mutation rejects evidence authority on a visual-only rack clamp"
	)
	clamps[0].remove_meta("forbidden_evidence_authority")
	_check(
		bool(module.get_rack_cable_tray_clamp_visual_allocation_audit().valid)
		and module.get_validation_errors() == baseline_errors,
		"restoring rack-clamp identity, recipe, budget metadata, material, renderer and authority returns the exact validator state"
	)


func _test_console_shock_collar_visual_resource_sharing(
		module: AftJunctionStack
	) -> void:
	var report := module.get_console_shock_collar_visual_allocation_audit()
	_check(
		bool(report.valid)
		and report.legacy == {
			"visual_nodes": 6,
			"drawn_copies": 6,
			"surface_submissions": 6,
			"mesh_resource_allocations": 6,
			"material_resource_allocations": 1,
		}
		and report.current == {
			"visual_nodes": 6,
			"drawn_copies": 6,
			"surface_submissions": 6,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
		}
		and report.reductions == {
			"visual_nodes": 0,
			"drawn_copies": 0,
			"surface_submissions": 0,
			"mesh_resource_allocations": 5,
			"material_resource_allocations": 0,
		}
		and not bool(report.batched)
		and not bool(report.renderer_values_changed)
		and not bool(report.normalised)
		and report.authored_tessellation == Vector2i(48, 16)
		and report.live_tessellation == Vector2i(48, 16)
		and bool(report.material_identity_preserved)
		and int(report.collision_authority_count) == 0
		and int(report.semantic_authority_count) == 0,
		"six ConsoleShockCollar renderers preserve nodes, copies and submissions while immutable mesh allocations fall 6 -> 1"
	)

	var paths := report.node_paths as PackedStringArray
	var transforms := report.authored_transforms as Array
	var collars: Array[MeshInstance3D] = []
	for raw_node in module.find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(
			AftJunctionStack.INTERFACE_COLLAR_KIND_META, &""
		)) == &"ConsoleShockCollar":
			collars.append(instance)
	var shared_mesh := collars[0].mesh as TorusMesh if not collars.is_empty() else null
	var shared_material := (
		collars[0].material_override if not collars.is_empty() else null
	)
	var exact_family := (
		collars.size() == AftJunctionStack.CONSOLE_SHOCK_COLLAR_COPY_COUNT
		and paths.size() == AftJunctionStack.CONSOLE_SHOCK_COLLAR_COPY_COUNT
		and transforms.size() == AftJunctionStack.CONSOLE_SHOCK_COLLAR_COPY_COUNT
	)
	for index in collars.size():
		var collar := collars[index]
		var bay_path := "Structure/OperationsRoom/ConsoleBay%02d" % (
			int(index / 2) + 1
		)
		exact_family = (
			exact_family
			and collar.mesh == shared_mesh
			and collar.material_override == shared_material
			and shared_material != null
			and collar.position.is_equal_approx(
				AftJunctionStack.CONSOLE_SHOCK_COLLAR_LOCAL_POSITIONS[index]
					as Vector3
			)
			and collar.rotation_degrees.is_equal_approx(Vector3(90.0, 0.0, 0.0))
			and collar.scale == Vector3.ONE
			and (transforms[index] as Transform3D).is_equal_approx(collar.transform)
			and collar.visible
			and collar.layers == 1
			and collar.cast_shadow \
				== GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and collar.material_overlay == null
			and is_zero_approx(collar.transparency)
			and collar.get_child_count() == 0
			and collar.get_script() == null
			and String(module.get_path_to(collar.get_parent())) == bay_path
			and (
				String(paths[index]) == bay_path + "/ConsoleShockCollar"
				if index % 2 == 0
				else String(collar.name).begins_with("@MeshInstance3D@")
			)
		)
	_check(
		exact_family
		and shared_mesh != null
		and shared_mesh.resource_name == "AftConsoleShockCollarMesh"
		and not shared_mesh.resource_local_to_scene
		and shared_mesh.material == null
		and is_equal_approx(shared_mesh.inner_radius, 0.09)
		and is_equal_approx(shared_mesh.outer_radius, 0.13)
		and shared_mesh.rings == 48
		and shared_mesh.ring_segments == 16
		and shared_mesh.get_surface_count() == 1,
		"the exact three-bay node/path/transform roster, rubber material, renderer state and authored 48x16 recipe remain intact"
	)

	(report.current as Dictionary)["mesh_resource_allocations"] = -1
	paths[0] = "mutated"
	transforms.clear()
	var detached := module.get_console_shock_collar_visual_allocation_audit()
	_check(
		int(detached.current.mesh_resource_allocations) == 1
		and (detached.node_paths as PackedStringArray)[0] \
			== "Structure/OperationsRoom/ConsoleBay01/ConsoleShockCollar"
		and (detached.authored_transforms as Array).size() == 6,
		"console-shock-collar allocation, path and transform evidence is deeply detached"
	)

	var baseline_errors := module.get_validation_errors()
	var original_second_mesh := collars[1].mesh
	collars[1].mesh = shared_mesh.duplicate() as Mesh
	var identity_red := module.get_console_shock_collar_visual_allocation_audit()
	_check(
		not bool(identity_red.valid)
		and (identity_red.errors as PackedStringArray).has(
			"console_shock_collar_mesh_identity_not_shared"
		)
		and int(identity_red.current.mesh_resource_allocations) == 2,
		"RED identity mutation rejects a private exact-looking console-shock-collar mesh"
	)
	collars[1].mesh = original_second_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings += 1
	var recipe_red := module.get_console_shock_collar_visual_allocation_audit()
	_check(
		not bool(recipe_red.valid)
		and (recipe_red.errors as PackedStringArray).has(
			"console_shock_collar_torus_recipe_drift"
		),
		"RED recipe mutation rejects arbitrary console-shock-collar tessellation"
	)
	shared_mesh.rings = original_rings

	shared_mesh.set_meta(TorusGeometryBudget.AUTHORED_META, Vector2i(47, 15))
	var budget_red := module.get_console_shock_collar_visual_allocation_audit()
	_check(
		not bool(budget_red.valid)
		and (budget_red.errors as PackedStringArray).has(
			"console_shock_collar_budget_metadata_drift"
		),
		"RED authored-budget metadata mutation rejects a false console-shock-collar recipe"
	)
	shared_mesh.remove_meta(TorusGeometryBudget.AUTHORED_META)

	var original_material := collars[2].material_override
	collars[2].material_override = null
	var material_red := module.get_console_shock_collar_visual_allocation_audit()
	_check(
		not bool(material_red.valid)
		and (material_red.errors as PackedStringArray).has(
			"console_shock_collar_material_identity_drift"
		),
		"RED material mutation rejects loss of the shared rubber binding"
	)
	collars[2].material_override = original_material

	var original_layers := collars[3].layers
	collars[3].layers = 2
	var renderer_red := module.get_console_shock_collar_visual_allocation_audit()
	_check(
		not bool(renderer_red.valid)
		and (renderer_red.errors as PackedStringArray).has(
			"console_shock_collar_renderer_state_drift"
		),
		"RED renderer mutation rejects a console-shock-collar layer drift"
	)
	collars[3].layers = original_layers

	collars[4].set_meta("forbidden_evidence_authority", true)
	var authority_red := module.get_console_shock_collar_visual_allocation_audit()
	_check(
		not bool(authority_red.valid)
		and (authority_red.errors as PackedStringArray).has(
			"console_shock_collar_gained_authority_or_lifecycle"
		)
		and int(authority_red.semantic_authority_count) == 1,
		"RED metadata mutation rejects authority on a visual-only console shock collar"
	)
	collars[4].remove_meta("forbidden_evidence_authority")
	_check(
		bool(module.get_console_shock_collar_visual_allocation_audit().valid)
		and module.get_validation_errors() == baseline_errors,
		"restoring console collar identity, recipe, budget, material, renderer and authority returns the exact validator state"
	)


func _test_pedestal_bearing_visual_resource_sharing(
		module: AftJunctionStack
	) -> void:
	var report := module.get_pedestal_bearing_visual_allocation_audit()
	_check(
		bool(report.valid)
		and report.legacy == {
			"visual_nodes": 4,
			"drawn_copies": 4,
			"surface_submissions": 4,
			"mesh_resource_allocations": 4,
			"material_resource_allocations": 1,
		}
		and report.current == {
			"visual_nodes": 4,
			"drawn_copies": 4,
			"surface_submissions": 4,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
		}
		and report.reductions == {
			"visual_nodes": 0,
			"drawn_copies": 0,
			"surface_submissions": 0,
			"mesh_resource_allocations": 3,
			"material_resource_allocations": 0,
		}
		and not bool(report.batched)
		and not bool(report.renderer_values_changed)
		and not bool(report.normalised)
		and report.authored_tessellation == Vector2i(48, 16)
		and report.live_tessellation == Vector2i(48, 16)
		and bool(report.material_identity_preserved)
		and int(report.collision_authority_count) == 0
		and int(report.semantic_authority_count) == 0
		and int(report.pedestal_collision_body_count) == 4
		and int(report.pedestal_collision_shape_count) == 4,
		"four PedestalBearing renderers preserve nodes, copies and submissions while mesh allocations fall 4 -> 1 beside four separate collidable pedestals"
	)

	var paths := report.node_paths as PackedStringArray
	var transforms := report.authored_transforms as Array
	var bearings: Array[MeshInstance3D] = []
	for raw_node in module.find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(
			AftJunctionStack.INTERFACE_COLLAR_KIND_META, &""
		)) == &"PedestalBearing":
			bearings.append(instance)
	var shared_mesh := bearings[0].mesh as TorusMesh if not bearings.is_empty() else null
	var shared_material := (
		bearings[0].material_override if not bearings.is_empty() else null
	)
	var exact_family := (
		bearings.size() == AftJunctionStack.PEDESTAL_BEARING_COPY_COUNT
		and paths.size() == AftJunctionStack.PEDESTAL_BEARING_COPY_COUNT
		and transforms.size() == AftJunctionStack.PEDESTAL_BEARING_COPY_COUNT
	)
	for index in bearings.size():
		var bearing := bearings[index]
		var chair_path := "Structure/OperationsRoom/OperationsChair%02d" % (
			index + 1
		)
		var chair := module.get_node_or_null(NodePath(chair_path)) as Node3D
		var pedestal := (
			chair.get_node_or_null(^"Pedestal") as StaticBody3D
			if chair != null else null
		)
		var shapes := (
			pedestal.find_children("*", "CollisionShape3D", true, false)
			if pedestal != null else []
		)
		var collision := shapes[0] as CollisionShape3D if shapes.size() == 1 else null
		var cylinder := (
			collision.shape as CylinderShape3D if collision != null else null
		)
		exact_family = (
			exact_family
			and bearing.mesh == shared_mesh
			and bearing.material_override == shared_material
			and shared_material != null
			and bearing.position.is_equal_approx(
				AftJunctionStack.PEDESTAL_BEARING_LOCAL_POSITION
			)
			and bearing.rotation_degrees.is_equal_approx(Vector3.ZERO)
			and bearing.scale == Vector3.ONE
			and (transforms[index] as Transform3D).is_equal_approx(bearing.transform)
			and bearing.visible
			and bearing.layers == 1
			and bearing.cast_shadow \
				== GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and bearing.material_overlay == null
			and is_zero_approx(bearing.transparency)
			and bearing.get_child_count() == 0
			and bearing.get_script() == null
			and String(paths[index]) == chair_path + "/PedestalBearing"
			and bearing.get_parent() == chair
			and chair != null
			and bool(chair.get_meta("station_chair", false))
			and int(chair.get_meta("chair_index", -1)) == index
			and pedestal != null
			and pedestal != bearing
			and pedestal.get_parent() == chair
			and pedestal.collision_layer == WORLD_LAYER
			and pedestal.collision_mask == 0
			and collision != null
			and not collision.disabled
			and cylinder != null
			and is_equal_approx(cylinder.radius, 0.18)
			and is_equal_approx(cylinder.height, 0.76)
		)
	_check(
		exact_family
		and shared_mesh != null
		and shared_mesh.resource_name == "AftPedestalBearingMesh"
		and not shared_mesh.resource_local_to_scene
		and shared_mesh.material == null
		and is_equal_approx(shared_mesh.inner_radius, 0.18)
		and is_equal_approx(shared_mesh.outer_radius, 0.25)
		and shared_mesh.rings == 48
		and shared_mesh.ring_segments == 16
		and shared_mesh.get_surface_count() == 1,
		"the exact four-chair paths/transforms, copper renderer state, authored recipe and independent pedestal collision remain intact"
	)

	(report.current as Dictionary)["mesh_resource_allocations"] = -1
	paths[0] = "mutated"
	transforms.clear()
	var detached := module.get_pedestal_bearing_visual_allocation_audit()
	_check(
		int(detached.current.mesh_resource_allocations) == 1
		and (detached.node_paths as PackedStringArray)[0] \
			== "Structure/OperationsRoom/OperationsChair01/PedestalBearing"
		and (detached.authored_transforms as Array).size() == 4,
		"pedestal-bearing allocation, path and transform evidence is deeply detached"
	)

	var baseline_errors := module.get_validation_errors()
	var original_second_mesh := bearings[1].mesh
	bearings[1].mesh = shared_mesh.duplicate() as Mesh
	var identity_red := module.get_pedestal_bearing_visual_allocation_audit()
	_check(
		not bool(identity_red.valid)
		and (identity_red.errors as PackedStringArray).has(
			"pedestal_bearing_mesh_identity_not_shared"
		)
		and int(identity_red.current.mesh_resource_allocations) == 2
		and module.get_validation_errors().has(
			"shared chair-pedestal-bearing visual allocation contract drifted"
		),
		"RED identity/private-duplicate mutation rejects a private exact-looking PedestalBearing mesh"
	)
	bearings[1].mesh = original_second_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings += 1
	var recipe_red := module.get_pedestal_bearing_visual_allocation_audit()
	_check(
		not bool(recipe_red.valid)
		and (recipe_red.errors as PackedStringArray).has(
			"pedestal_bearing_torus_recipe_drift"
		),
		"RED recipe mutation rejects arbitrary PedestalBearing tessellation"
	)
	shared_mesh.rings = original_rings

	shared_mesh.set_meta(TorusGeometryBudget.AUTHORED_META, Vector2i(47, 15))
	var budget_red := module.get_pedestal_bearing_visual_allocation_audit()
	_check(
		not bool(budget_red.valid)
		and (budget_red.errors as PackedStringArray).has(
			"pedestal_bearing_budget_metadata_drift"
		),
		"RED budget mutation rejects false PedestalBearing authorship metadata"
	)
	shared_mesh.remove_meta(TorusGeometryBudget.AUTHORED_META)

	var original_material := bearings[2].material_override
	bearings[2].material_override = null
	var material_red := module.get_pedestal_bearing_visual_allocation_audit()
	_check(
		not bool(material_red.valid)
		and (material_red.errors as PackedStringArray).has(
			"pedestal_bearing_material_identity_drift"
		),
		"RED material mutation rejects loss of the shared copper binding"
	)
	bearings[2].material_override = original_material

	var original_layers := bearings[3].layers
	bearings[3].layers = 2
	var renderer_red := module.get_pedestal_bearing_visual_allocation_audit()
	_check(
		not bool(renderer_red.valid)
		and (renderer_red.errors as PackedStringArray).has(
			"pedestal_bearing_renderer_state_drift"
		),
		"RED layer mutation rejects PedestalBearing renderer-state drift"
	)
	bearings[3].layers = original_layers

	bearings[0].set_meta("forbidden_evidence_authority", true)
	var authority_red := module.get_pedestal_bearing_visual_allocation_audit()
	_check(
		not bool(authority_red.valid)
		and (authority_red.errors as PackedStringArray).has(
			"pedestal_bearing_gained_authority_or_lifecycle"
		)
		and int(authority_red.semantic_authority_count) == 1,
		"RED authority mutation rejects semantics on a visual-only PedestalBearing"
	)
	bearings[0].remove_meta("forbidden_evidence_authority")
	_check(
		bool(module.get_pedestal_bearing_visual_allocation_audit().valid)
		and module.get_validation_errors() == baseline_errors,
		"restoring bearing identity, recipe, budget, material, layer and authority returns the exact validator state"
	)


func _test_conduit_collar_visual_resource_sharing(
		module: AftJunctionStack
	) -> void:
	var report := module.get_conduit_collar_visual_allocation_audit()
	_check(
		bool(report.valid)
		and report.legacy == {
			"visual_nodes": 3,
			"drawn_copies": 3,
			"surface_submissions": 3,
			"mesh_resource_allocations": 3,
			"material_resource_allocations": 1,
		}
		and report.current == {
			"visual_nodes": 3,
			"drawn_copies": 3,
			"surface_submissions": 3,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
		}
		and report.reductions == {
			"visual_nodes": 0,
			"drawn_copies": 0,
			"surface_submissions": 0,
			"mesh_resource_allocations": 2,
			"material_resource_allocations": 0,
		}
		and not bool(report.batched)
		and not bool(report.renderer_values_changed)
		and not bool(report.normalised)
		and report.authored_tessellation == Vector2i(48, 16)
		and report.live_tessellation == Vector2i(48, 16)
		and bool(report.material_identity_preserved)
		and int(report.collision_authority_count) == 0
		and int(report.semantic_authority_count) == 0,
		"three ConduitCollar renderers preserve nodes, copies, submissions and zero authority while mesh allocations fall 3 -> 1"
	)

	var paths := report.node_paths as PackedStringArray
	var transforms := report.authored_transforms as Array
	var collars: Array[MeshInstance3D] = []
	for raw_node in module.find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(
			AftJunctionStack.INTERFACE_COLLAR_KIND_META, &""
		)) == &"ConduitCollar":
			collars.append(instance)
	var shared_mesh := collars[0].mesh as TorusMesh if not collars.is_empty() else null
	var shared_material := (
		collars[0].material_override if not collars.is_empty() else null
	)
	var service_wall := module.get_node_or_null(
		^"Structure/OperationsRoom/ServiceWall"
	) as Node3D
	var exact_family := (
		collars.size() == AftJunctionStack.CONDUIT_COLLAR_COPY_COUNT
		and paths.size() == AftJunctionStack.CONDUIT_COLLAR_COPY_COUNT
		and transforms.size() == AftJunctionStack.CONDUIT_COLLAR_COPY_COUNT
	)
	for index in collars.size():
		var collar := collars[index]
		var metadata_keys := collar.get_meta_list()
		exact_family = (
			exact_family
			and collar.mesh == shared_mesh
			and collar.material_override == shared_material
			and shared_material != null
			and collar.position.is_equal_approx(
				AftJunctionStack.CONDUIT_COLLAR_POSITIONS[index] as Vector3
			)
			and collar.rotation_degrees.is_equal_approx(Vector3(90.0, 0.0, 0.0))
			and collar.scale == Vector3.ONE
			and (transforms[index] as Transform3D).is_equal_approx(collar.transform)
			and collar.visible
			and collar.layers == 1
			and collar.cast_shadow \
				== GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and collar.material_overlay == null
			and is_zero_approx(collar.transparency)
			and collar.get_child_count() == 0
			and collar.get_script() == null
			and collar.get_groups().is_empty()
			and metadata_keys.size() == 2
			and metadata_keys.has(TorusGeometryBudget.PROFILE_META)
			and metadata_keys.has(AftJunctionStack.INTERFACE_COLLAR_KIND_META)
			and StringName(collar.get_meta(
				TorusGeometryBudget.PROFILE_META, &""
			)) == TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR
			and StringName(collar.get_meta(
				AftJunctionStack.INTERFACE_COLLAR_KIND_META, &""
			)) == &"ConduitCollar"
			and collar.get_parent() == service_wall
			and (
				String(paths[index]) \
					== "Structure/OperationsRoom/ServiceWall/ConduitCollar"
				if index == 0
				else String(collar.name).begins_with("@MeshInstance3D@")
			)
		)
	_check(
		exact_family
		and service_wall != null
		and bool(service_wall.get_meta("station_service_wall", false))
		and shared_mesh != null
		and shared_mesh.resource_name == "AftConduitCollarMesh"
		and not shared_mesh.resource_local_to_scene
		and shared_mesh.material == null
		and is_equal_approx(shared_mesh.inner_radius, 0.1)
		and is_equal_approx(shared_mesh.outer_radius, 0.16)
		and shared_mesh.rings == 48
		and shared_mesh.ring_segments == 16
		and shared_mesh.get_surface_count() == 1,
		"the exact service-wall path/transform roster, brass renderer state and authored 48x16 recipe remain intact"
	)

	(report.current as Dictionary)["mesh_resource_allocations"] = -1
	paths[0] = "mutated"
	transforms.clear()
	var detached := module.get_conduit_collar_visual_allocation_audit()
	_check(
		int(detached.current.mesh_resource_allocations) == 1
		and (detached.node_paths as PackedStringArray)[0] \
			== "Structure/OperationsRoom/ServiceWall/ConduitCollar"
		and (detached.authored_transforms as Array).size() == 3,
		"conduit-collar allocation, path and transform evidence is deeply detached"
	)

	var baseline_errors := module.get_validation_errors()
	var original_second_mesh := collars[1].mesh
	collars[1].mesh = shared_mesh.duplicate() as Mesh
	var identity_red := module.get_conduit_collar_visual_allocation_audit()
	_check(
		not bool(identity_red.valid)
		and (identity_red.errors as PackedStringArray).has(
			"conduit_collar_mesh_identity_not_shared"
		)
		and int(identity_red.current.mesh_resource_allocations) == 2
		and module.get_validation_errors().has(
			"shared service-wall-conduit-collar visual allocation contract drifted"
		),
		"RED private-duplicate mutation rejects an exact-looking ConduitCollar mesh"
	)
	collars[1].mesh = original_second_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings += 1
	var recipe_red := module.get_conduit_collar_visual_allocation_audit()
	_check(
		not bool(recipe_red.valid)
		and (recipe_red.errors as PackedStringArray).has(
			"conduit_collar_torus_recipe_drift"
		),
		"RED recipe mutation rejects arbitrary ConduitCollar tessellation"
	)
	shared_mesh.rings = original_rings

	shared_mesh.set_meta(TorusGeometryBudget.AUTHORED_META, Vector2i(47, 15))
	var budget_red := module.get_conduit_collar_visual_allocation_audit()
	_check(
		not bool(budget_red.valid)
		and (budget_red.errors as PackedStringArray).has(
			"conduit_collar_budget_metadata_drift"
		),
		"RED budget mutation rejects false ConduitCollar authorship metadata"
	)
	shared_mesh.remove_meta(TorusGeometryBudget.AUTHORED_META)

	var original_material := collars[2].material_override
	collars[2].material_override = null
	var material_red := module.get_conduit_collar_visual_allocation_audit()
	_check(
		not bool(material_red.valid)
		and (material_red.errors as PackedStringArray).has(
			"conduit_collar_material_identity_drift"
		),
		"RED material mutation rejects loss of the shared brass binding"
	)
	collars[2].material_override = original_material

	var original_layers := collars[0].layers
	collars[0].layers = 2
	var renderer_red := module.get_conduit_collar_visual_allocation_audit()
	_check(
		not bool(renderer_red.valid)
		and (renderer_red.errors as PackedStringArray).has(
			"conduit_collar_renderer_state_drift"
		),
		"RED layer mutation rejects ConduitCollar renderer-state drift"
	)
	collars[0].layers = original_layers

	collars[1].set_meta("forbidden_evidence_authority", true)
	var authority_red := module.get_conduit_collar_visual_allocation_audit()
	_check(
		not bool(authority_red.valid)
		and (authority_red.errors as PackedStringArray).has(
			"conduit_collar_gained_authority_or_lifecycle"
		)
		and int(authority_red.semantic_authority_count) == 1,
		"RED authority mutation rejects semantics on a visual-only ConduitCollar"
	)
	collars[1].remove_meta("forbidden_evidence_authority")
	_check(
		bool(module.get_conduit_collar_visual_allocation_audit().valid)
		and module.get_validation_errors() == baseline_errors,
		"restoring conduit identity, recipe, budget, material, layer and authority returns the exact validator state"
	)


func _test_vip_facade_column_trim_batch(module: AftJunctionStack) -> void:
	var report := module.get_vip_facade_column_trim_batch_audit()
	if not bool(report.valid):
		print("AFT_VIP_FACADE_COLUMN_TRIM_ERRORS: ", report.errors)
	print(
		"AFT_VIP_FACADE_COLUMN_TRIM_BATCH: "
		+ "nodes %d->%d submissions %d->%d mesh_resources %d->%d copies %d->%d" % [
			int(report.legacy.renderer_nodes),
			int(report.current.renderer_nodes),
			int(report.legacy.surface_submissions),
			int(report.current.surface_submissions),
			int(report.legacy.mesh_resource_allocations),
			int(report.current.mesh_resource_allocations),
			int(report.legacy.drawn_copies),
			int(report.current.drawn_copies),
		]
	)
	_check(
		bool(report.valid)
		and report.legacy == {
			"renderer_nodes": 4,
			"mesh_instance_nodes": 4,
			"multimesh_instance_nodes": 0,
			"drawn_copies": 4,
			"surface_submissions": 4,
			"mesh_resource_allocations": 4,
		}
		and report.current == {
			"renderer_nodes": 1,
			"mesh_instance_nodes": 0,
			"multimesh_instance_nodes": 1,
			"drawn_copies": 4,
			"surface_submissions": 1,
			"mesh_resource_allocations": 1,
		}
		and report.reductions == {
			"renderer_nodes": 3,
			"surface_submissions": 3,
			"mesh_resource_allocations": 3,
			"drawn_copies": 0,
		},
		"VIP facade foot/crown trim freezes exact 4->1 nodes, submissions and mesh allocations while retaining four copies"
	)
	var batch := module.get_node_or_null(
		^"Structure/VIPLandmark/VIPFacadeColumnTrimBatch"
	) as MultiMeshInstance3D
	var expected_transforms: Array[Transform3D] = []
	for transform_value in AftJunctionStack.VIP_FACADE_COLUMN_TRIM_TRANSFORMS:
		expected_transforms.append(transform_value as Transform3D)
	var metadata_transforms := (
		batch.get_meta("authored_instance_transforms", []) as Array
		if batch != null else []
	)
	var transforms_exact := metadata_transforms.size() == expected_transforms.size()
	for index in mini(metadata_transforms.size(), expected_transforms.size()):
		transforms_exact = (
			transforms_exact
			and metadata_transforms[index] is Transform3D
			and (metadata_transforms[index] as Transform3D).is_equal_approx(
				expected_transforms[index]
			)
		)
	var mesh := (
		batch.multimesh.mesh as TorusMesh
		if batch != null and batch.multimesh != null else null
	)
	_check(
		batch != null
		and batch.multimesh != null
		and mesh != null
		and transforms_exact
		and batch.multimesh.instance_count == 4
		and batch.multimesh.visible_instance_count == 4
		and int(report.renderer_buffer_float_count) == 48
		and batch.multimesh.buffer == (report.renderer_buffer as PackedFloat32Array)
		and batch.multimesh.custom_aabb.is_equal_approx(report.culling_bounds as AABB)
		and is_equal_approx(
			mesh.inner_radius, AftJunctionStack.VIP_FACADE_COLUMN_TRIM_INNER_RADIUS
		)
		and is_equal_approx(
			mesh.outer_radius, AftJunctionStack.VIP_FACADE_COLUMN_TRIM_OUTER_RADIUS
		)
		and mesh.rings == AftJunctionStack.VIP_FACADE_COLUMN_TRIM_BUDGETED_RINGS
		and mesh.ring_segments \
			== AftJunctionStack.VIP_FACADE_COLUMN_TRIM_BUDGETED_RING_SEGMENTS
		and mesh.get_surface_count() == 1
		and mesh.get_meta(TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO) \
			== Vector2i(
				AftJunctionStack.VIP_FACADE_COLUMN_TRIM_RINGS,
				AftJunctionStack.VIP_FACADE_COLUMN_TRIM_RING_SEGMENTS
			)
		and report.authored_tessellation == Vector2i(48, 16)
		and report.live_tessellation == Vector2i(32, 14),
		"batch retains exact transform/buffer/culling evidence and the prior live 32x14 recipe with 48x16 authored metadata"
	)
	var vip := module.get_node_or_null(^"Structure/VIPLandmark")
	var authority := module.get_authority_contract()
	var collision := module.get_collision_contract()
	_check(
		batch != null
		and batch.get_child_count() == 0
		and batch.get_script() == null
		and batch.get_groups().is_empty()
		and batch.get_meta_list().size() == 2
		and bool(batch.get_meta("visual_detail_only", false))
		and not bool(report.collision_authority_added)
		and not bool(report.interaction_authority_added)
		and not bool(report.evidence_authority_added)
		and not bool(report.lifecycle_authority_added)
		and int(authority.lease_authority_count) == 0
		and int(authority.spawn_authority_count) == 0
		and str(authority.network_authority_role) == "none"
		and int(collision.body_count) == 103
		and int(collision.shape_count) == 109
		and module.get_operations_entrance() != null
		and module.get_vip_access() != null
		and vip != null
		and vip.find_children(
			"VIPFacadeColumnFoot", "MeshInstance3D", false, false
		).is_empty()
		and vip.find_children(
			"VIPFacadeColumnCrown", "MeshInstance3D", false, false
		).is_empty(),
		"batch adds zero collision, interaction, evidence or lifecycle authority and preserves both doors plus 103 bodies and 109 shapes"
	)

	(report.current as Dictionary)["renderer_nodes"] = -1
	(report.authored_transforms as Array).clear()
	(report.renderer_buffer as PackedFloat32Array)[0] = -999.0
	var detached := module.get_vip_facade_column_trim_batch_audit()
	_check(
		int(detached.current.renderer_nodes) == 1
		and (detached.authored_transforms as Array).size() == 4
		and (detached.renderer_buffer as PackedFloat32Array)[0] != -999.0,
		"VIP facade batch allocation, transform and raw-buffer evidence is deeply detached"
	)

	var baseline_errors := module.get_validation_errors()
	var original_buffer := batch.multimesh.buffer.duplicate()
	var corrupted_buffer := original_buffer.duplicate()
	corrupted_buffer[3] += 0.1
	batch.multimesh.buffer = corrupted_buffer
	_check(
		not bool(module.get_vip_facade_column_trim_batch_audit().valid)
		and (module.get_vip_facade_column_trim_batch_audit().errors as PackedStringArray).has(
			"vip_facade_column_trim_renderer_buffer_drift"
		),
		"RED renderer-buffer mutation rejects a shifted VIP trim copy"
	)
	batch.multimesh.buffer = original_buffer
	var original_bounds := batch.multimesh.custom_aabb
	batch.multimesh.custom_aabb = original_bounds.grow(0.1)
	_check(
		not bool(module.get_vip_facade_column_trim_batch_audit().valid)
		and (module.get_vip_facade_column_trim_batch_audit().errors as PackedStringArray).has(
			"vip_facade_column_trim_culling_bounds_drift"
		),
		"RED culling mutation rejects a non-authored VIP trim AABB"
	)
	batch.multimesh.custom_aabb = original_bounds
	var original_rings := mesh.rings
	mesh.rings -= 1
	_check(
		not bool(module.get_vip_facade_column_trim_batch_audit().valid)
		and (module.get_vip_facade_column_trim_batch_audit().errors as PackedStringArray).has(
			"vip_facade_column_trim_mesh_recipe_drift"
		),
		"RED recipe mutation rejects a lower-detail VIP trim torus"
	)
	mesh.rings = original_rings
	var original_authored_tessellation: Vector2i = mesh.get_meta(
		TorusGeometryBudget.AUTHORED_META
	)
	mesh.set_meta(TorusGeometryBudget.AUTHORED_META, Vector2i(47, 16))
	_check(
		not bool(module.get_vip_facade_column_trim_batch_audit().valid)
		and (module.get_vip_facade_column_trim_batch_audit().errors as PackedStringArray).has(
			"vip_facade_column_trim_budget_metadata_drift"
		),
		"RED budget-metadata mutation rejects a VIP trim mesh detached from its authored 48x16 recipe"
	)
	mesh.set_meta(
		TorusGeometryBudget.AUTHORED_META, original_authored_tessellation
	)
	var original_material := batch.material_override
	batch.material_override = null
	_check(
		not bool(module.get_vip_facade_column_trim_batch_audit().valid)
		and (module.get_vip_facade_column_trim_batch_audit().errors as PackedStringArray).has(
			"vip_facade_column_trim_render_state_drift"
		),
		"RED material mutation rejects facade trim renderer-state drift"
	)
	batch.material_override = original_material
	batch.set_meta("forbidden_evidence_authority", true)
	_check(
		not bool(module.get_vip_facade_column_trim_batch_audit().valid)
		and (module.get_vip_facade_column_trim_batch_audit().errors as PackedStringArray).has(
			"vip_facade_column_trim_gained_semantic_authority"
		),
		"RED metadata mutation rejects semantic authority on the visual-only batch"
	)
	batch.remove_meta("forbidden_evidence_authority")
	batch.multimesh.visible_instance_count = 3
	_check(
		not bool(module.get_vip_facade_column_trim_batch_audit().valid)
		and (module.get_vip_facade_column_trim_batch_audit().errors as PackedStringArray).has(
			"vip_facade_column_trim_visible_copy_roster_drift"
		),
		"RED visible-count mutation rejects a missing facade trim copy"
	)
	batch.multimesh.visible_instance_count = 4
	_check(
		bool(module.get_vip_facade_column_trim_batch_audit().valid)
		and module.get_validation_errors() == baseline_errors,
		"restoring buffer, bounds, recipe, material, authority and copies returns the exact pre-mutation validator state"
	)


func _test_interface_collar_profile(module: AftJunctionStack) -> void:
	var expected_counts := {
		&"ConsoleShockCollar": 6,
		&"SpineClamp": 5,
		&"ExteriorPipeClamp": 4,
		&"RackCableTrayClamp": 4,
		&"PedestalBearing": 4,
		&"ConduitCollar": 3,
	}
	var observed_counts: Dictionary = {}
	var mesh_ids: Dictionary = {}
	var snapshots: Array[Dictionary] = []
	for candidate in module.find_children("*", "MeshInstance3D", true, false):
		var instance := candidate as MeshInstance3D
		if StringName(instance.get_meta(TorusGeometryBudget.PROFILE_META, &"")) \
				!= TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR:
			continue
		var mesh := instance.mesh as TorusMesh
		var kind := StringName(instance.get_meta(AftJunctionStack.INTERFACE_COLLAR_KIND_META, &""))
		observed_counts[kind] = int(observed_counts.get(kind, 0)) + 1
		if mesh == null:
			continue
		mesh_ids[mesh.get_instance_id()] = true
		snapshots.append({
			"instance": instance,
			"transform": instance.transform,
			"material": instance.material_override,
			"inner_radius": mesh.inner_radius,
			"outer_radius": mesh.outer_radius,
			"aabb": mesh.get_aabb(),
		})

	_check(observed_counts == expected_counts, "Aft profile selects only the exact 26 interface-collar roster")
	_check(mesh_ids.size() == 9, "26 profiled collars retain 9 TorusMesh resources after exact spine, rack, console, chair-bearing and conduit sharing")
	# The operations test deliberately leaves the door open. Production performs
	# the geometry pass at startup with this portal closed, so restore that real
	# lifecycle state before asserting the complete module contract below.
	var operations_door := module.get_operations_entrance()
	var original_motion_duration := operations_door.motion_duration
	operations_door.motion_duration = 0.0
	_check(
		operations_door.interact(module),
		"normalization witness restores the production closed-door lifecycle"
	)
	operations_door.motion_duration = original_motion_duration
	var report := TorusGeometryBudget.normalise_tree(module)
	var exact_geometry := snapshots.size() == 26
	for snapshot in snapshots:
		var instance := snapshot["instance"] as MeshInstance3D
		var mesh := instance.mesh as TorusMesh
		var before_transform: Transform3D = snapshot["transform"]
		var before_material: Material = snapshot["material"]
		var before_aabb: AABB = snapshot["aabb"]
		exact_geometry = exact_geometry \
			and instance.transform.is_equal_approx(before_transform) \
			and instance.material_override == before_material \
			and instance.get_child_count() == 0 \
			and is_equal_approx(mesh.inner_radius, float(snapshot["inner_radius"])) \
			and is_equal_approx(mesh.outer_radius, float(snapshot["outer_radius"])) \
			and mesh.get_aabb().is_equal_approx(before_aabb) \
			and mesh.rings == TorusGeometryBudget.MIN_RINGS \
			and mesh.ring_segments == TorusGeometryBudget.AFT_INTERFACE_COLLAR_RING_SEGMENTS \
			and mesh.get_surface_count() == 1
	_check(
		exact_geometry,
		"profile preserves every collar transform, radius, bound, material, child roster, and surface"
	)
	var profile_report := (report.get("profiles", {}) as Dictionary).get(
		TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR, {}
	) as Dictionary
	_check(
		int(profile_report.get("resources", 0)) == 9
		and int(profile_report.get("instances", 0)) == 26
		and int(profile_report.get("surfaces", 0)) == 26,
		"profile report freezes 9 resources, 26 visible instances, and 26 surfaces"
	)
	_check(
		int(profile_report.get("triangles_baseline", 0)) == 19968
		and int(profile_report.get("triangles_after", 0)) == 13312,
		"Aft interface family freezes at 19968 -> 13312 triangles"
	)

	var pod_report := module.get_pod_corner_collar_visual_allocation_audit()
	var pod_recipe := pod_report.get("mesh_recipe", {}) as Dictionary
	var spine_report := module.get_spine_clamp_visual_allocation_audit()
	var rack_clamp_report := module.get_rack_cable_tray_clamp_visual_allocation_audit()
	var console_collar_report := module.get_console_shock_collar_visual_allocation_audit()
	var pedestal_bearing_report := module.get_pedestal_bearing_visual_allocation_audit()
	var conduit_collar_report := module.get_conduit_collar_visual_allocation_audit()
	var roof_vent_collar_report := module.get_roof_vent_collar_visual_allocation_audit()
	_check(
		bool(pod_report.valid)
		and bool(spine_report.valid)
		and bool(spine_report.normalised)
		and spine_report.authored_tessellation == Vector2i(48, 16)
		and spine_report.live_tessellation == Vector2i(32, 8)
		and bool(rack_clamp_report.valid)
		and bool(rack_clamp_report.normalised)
		and rack_clamp_report.authored_tessellation == Vector2i(48, 16)
		and rack_clamp_report.live_tessellation == Vector2i(32, 8)
		and bool(console_collar_report.valid)
		and bool(console_collar_report.normalised)
		and console_collar_report.authored_tessellation == Vector2i(48, 16)
		and console_collar_report.live_tessellation == Vector2i(32, 8)
		and bool(pedestal_bearing_report.valid)
		and bool(pedestal_bearing_report.normalised)
		and pedestal_bearing_report.authored_tessellation == Vector2i(48, 16)
		and pedestal_bearing_report.live_tessellation == Vector2i(32, 8)
		and bool(conduit_collar_report.valid)
		and bool(conduit_collar_report.normalised)
		and conduit_collar_report.authored_tessellation == Vector2i(48, 16)
		and conduit_collar_report.live_tessellation == Vector2i(32, 8)
		and bool(roof_vent_collar_report.valid)
		and bool(roof_vent_collar_report.normalised)
		and bool(roof_vent_collar_report.metadata_exact)
		and roof_vent_collar_report.authored_tessellation == Vector2i(48, 16)
		and roof_vent_collar_report.live_tessellation == Vector2i(40, 16)
		and bool(pod_recipe.get("normalised", false))
		and int(pod_recipe.get("authored_rings", 0)) \
			== AftJunctionStack.POD_CORNER_COLLAR_RINGS
		and int(pod_recipe.get("authored_ring_segments", 0)) \
			== AftJunctionStack.POD_CORNER_COLLAR_RING_SEGMENTS
		and int(pod_recipe.get("rings", 0)) \
			== AftJunctionStack.POD_CORNER_COLLAR_BUDGETED_RINGS
		and int(pod_recipe.get("ring_segments", 0)) \
			== AftJunctionStack.POD_CORNER_COLLAR_BUDGETED_RING_SEGMENTS
		and module.get_validation_errors().is_empty(),
		"production torus normalization retains exact 48x16 authorship metadata and keeps pod collars at 34x14 plus all five shared profiled families at 32x8"
	)

	var pod_mesh := (
		module.get_node(^"Structure/OperationsRoom/PodCornerCollar") as MeshInstance3D
	).mesh as TorusMesh
	var original_budgeted_rings := pod_mesh.rings
	pod_mesh.rings += 1
	var arbitrary_recipe := module.get_pod_corner_collar_visual_allocation_audit()
	_check(
		not bool(arbitrary_recipe.valid)
		and (arbitrary_recipe.errors as PackedStringArray).has(
			"pod_corner_collar_mesh_recipe_drift"
		),
		"RED metadata-backed arbitrary pod-collar tessellation remains rejected"
	)
	pod_mesh.rings = original_budgeted_rings

	var original_index := module.get_index()
	_test_root.remove_child(module)
	_test_root.add_child(module)
	_test_root.move_child(module, mini(original_index, _test_root.get_child_count() - 1))
	var reentry_report := module.get_pod_corner_collar_visual_allocation_audit()
	var reentry_spine_report := module.get_spine_clamp_visual_allocation_audit()
	var reentry_rack_clamp_report := module.get_rack_cable_tray_clamp_visual_allocation_audit()
	var reentry_console_collar_report := module.get_console_shock_collar_visual_allocation_audit()
	var reentry_pedestal_bearing_report := module.get_pedestal_bearing_visual_allocation_audit()
	var reentry_conduit_collar_report := module.get_conduit_collar_visual_allocation_audit()
	_check(
		bool(reentry_report.valid)
		and bool(reentry_spine_report.valid)
		and bool(reentry_rack_clamp_report.valid)
		and bool(reentry_console_collar_report.valid)
		and bool(reentry_pedestal_bearing_report.valid)
		and bool(reentry_conduit_collar_report.valid)
		and bool((reentry_report.mesh_recipe as Dictionary).normalised)
		and bool(reentry_spine_report.normalised)
		and bool(reentry_rack_clamp_report.normalised)
		and bool(reentry_console_collar_report.normalised)
		and bool(reentry_pedestal_bearing_report.normalised)
		and bool(reentry_conduit_collar_report.normalised)
		and module.get_validation_errors().is_empty(),
		"Aft re-entry preserves the exact normalized shared resource and immediately restores a green contract"
	)


func _test_vip_landmark(module: AftJunctionStack) -> void:
	var vip := module.get_vip_access()
	_check(vip != null, "VIP landmark exposes a StationDoor component")
	if vip == null:
		return
	# Reversed with the interior. This block used to require the landmark to stay
	# shut, which was right while nothing stood behind it. `VipReceptionSuite` now
	# does, so the assertions move to what actually protects the evidence
	# boundary: the door opens, and both the door and the module keep saying in
	# their own metadata that what it opens onto is invented.
	_check(not vip.locked and not vip.deferred_access, "VIP landmark opens onto its built interpretation interior")
	_check(vip.can_interact(module), "the opened VIP landmark is a real interactable door")
	var prompt := vip.get_interaction_prompt()
	_check("VIP RECEPTION" in prompt, "VIP prompt names the reception the door now leads to")
	_check("DEFERRED" not in prompt, "an opened landmark no longer advertises deferred content")
	_check(str(vip.get_meta("access_label")) == "VIP RECEPTION", "VIP component metadata exposes its stable label")
	_check(not bool(vip.get_meta("deferred_access")), "VIP component metadata records that the landmark is no longer deferred")
	_check(
		"invented modern design" in str(vip.get_meta("content_note")) \
			and "confidence none" in str(vip.get_meta("content_note")),
		"VIP component carries the evidence boundary for the room behind it"
	)
	_check(module.get_vip_access_marker().global_position.distance_to(vip.global_position + Vector3.UP * 0.15) < 1.3, "VIP route marker terminates at the landmark")

	var panel := vip.get_node_or_null("SlidingPanel/PanelMesh") as MeshInstance3D
	var panel_material := panel.material_override as StandardMaterial3D if panel != null else null
	_check(panel_material != null and panel_material.albedo_color.r > panel_material.albedo_color.g * 1.7, "VIP panel is visibly red rather than reusing cyan access styling")


func _test_negative_space(module: AftJunctionStack) -> void:
	var west_void := await _ray_local(module, Vector3(-9.0, 8.0, 6.0), Vector3(-9.0, -4.0, 6.0))
	var east_void := await _ray_local(module, Vector3(8.5, 8.0, 5.8), Vector3(8.5, -4.0, 5.8))
	_check(west_void.is_empty(), "west footprint sample remains true station negative space")
	_check(east_void.is_empty(), "east footprint sample remains true station negative space")

	var lower_sky := await _ray_local(module, Vector3(0, 0.3, 7.2), Vector3(0, 12.0, 7.2))
	var upper_sky := await _ray_local(module, Vector3(-7.8, 4.5, 16.0), Vector3(-7.8, 13.0, 16.0))
	_check(lower_sky.is_empty(), "lower junction remains uncovered and open to space")
	_check(upper_sky.is_empty(), "upper overlook remains uncovered and open to space")

	var room_roof := await _ray_local(module, Vector3(5.6, 1.0, 13.2), Vector3(5.6, 8.0, 13.2))
	_check(not room_roof.is_empty(), "compact operations insertion has a physical roof distinct from open decks")
	_check(module.get_open_to_space_ratio() > 0.67, "declared walkable-area estimate keeps more than two thirds open to space")


func _test_collision_matrix(module: AftJunctionStack) -> void:
	var bodies := module.find_children("*", "StaticBody3D", true, false)
	_check(bodies.size() >= 30, "module contains substantial collision-backed architecture and furniture")
	var every_body_canonical := true
	var every_body_shaped := true
	for candidate in bodies:
		var body := candidate as StaticBody3D
		var layer_is_valid := body.collision_layer == WORLD_LAYER
		if body.name == "PortalBlocker":
			# The reusable StationDoor deliberately clears only its portal blocker's
			# layer while fully open; all other static structure stays on World.
			layer_is_valid = body.collision_layer == WORLD_LAYER or body.collision_layer == 0
		every_body_canonical = every_body_canonical and layer_is_valid and body.collision_mask == 0
		var shapes := body.find_children("*", "CollisionShape3D", true, false)
		if shapes.is_empty():
			every_body_shaped = false
	_check(every_body_canonical, "every static collider follows the canonical World layer/mask contract")
	_check(every_body_shaped, "every static body owns at least one real collision shape")


func _test_module_enabled_currentness(module: AftJunctionStack) -> void:
	var original_index := module.get_index()
	_test_root.remove_child(module)
	_check(not module.is_inside_tree(), "a detached Aft module is no longer a live lifecycle target")
	var detached_before := _module_lifecycle_mutation_snapshot(module)
	module.set_module_enabled(false)
	_check(
		module.is_module_enabled()
		and _module_lifecycle_mutation_snapshot(module) == detached_before,
		"a detached Aft module rejects disable without retaining collision, visibility, or processing drift"
	)
	_test_root.add_child(module)
	_test_root.move_child(module, mini(original_index, _test_root.get_child_count() - 1))
	await process_frame
	var reentry_before := _module_lifecycle_mutation_snapshot(module)
	module.set_module_enabled(false)
	var disabled := module.get_lifecycle_contract()
	_check(
		not module.is_module_enabled()
		and bool(disabled.visible_matches_enabled)
		and bool(disabled.collision_matches_enabled)
		and bool(disabled.process_matches_lifecycle),
		"a reattached Aft module accepts a fresh disable and withdraws collision plus processing"
	)
	module.set_module_enabled(true)
	_check(
		module.is_module_enabled()
		and _module_lifecycle_mutation_snapshot(module) == reentry_before,
		"a fresh reentry restore returns the exact enabled lifecycle contract"
	)

	module.queue_free()
	_check(
		module.is_inside_tree() and module.is_queued_for_deletion(),
		"a queued Aft module remains in-tree during its deletion window"
	)
	var queued_before := _module_lifecycle_mutation_snapshot(module)
	module.set_module_enabled(false)
	_check(
		module.is_module_enabled()
		and _module_lifecycle_mutation_snapshot(module) == queued_before,
		"a queued Aft module rejects lifecycle mutation without retained drift"
	)


func _module_lifecycle_mutation_snapshot(module: AftJunctionStack) -> Dictionary:
	var static_bodies: Array[Dictionary] = []
	for candidate in module.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		static_bodies.append({
			"instance_id": body.get_instance_id(),
			"collision_layer": body.collision_layer,
			"visible": body.visible,
		})
	return {
		"enabled": module.is_module_enabled(),
		"visible": module.visible,
		"processing": module.is_processing(),
		"physics_processing": module.is_physics_processing(),
		"static_bodies": static_bodies,
	}.duplicate(true)


func _test_cleanup(module: AftJunctionStack) -> void:
	var module_reference: WeakRef = weakref(module)
	var operations_reference: WeakRef = weakref(module.get_operations_entrance())
	var vip_reference: WeakRef = weakref(module.get_vip_access())
	module.queue_free()
	module = null
	await process_frame
	await physics_frame
	await process_frame
	_check(module_reference.get_ref() == null, "module root cleans up without a retained instance")
	_check(operations_reference.get_ref() == null and vip_reference.get_ref() == null, "both StationDoor children clean up with the module")
	_test_root.queue_free()
	await process_frame


func _ray_down(module: AftJunctionStack, local_from: Vector3, local_to: Vector3) -> Dictionary:
	return await _ray_local(module, local_from, local_to)


func _ray_local(module: AftJunctionStack, local_from: Vector3, local_to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(module.to_global(local_from), module.to_global(local_to), WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_ray(query)


func _ray_through_door(door: StationDoor) -> Dictionary:
	await physics_frame
	var from := door.to_global(Vector3(0, 1.7, -1.7))
	var to := door.to_global(Vector3(0, 1.7, 1.7))
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return door.get_world_3d().direct_space_state.intersect_ray(query)


## Physics frames a nominal duration of simulated time is worth at the project's
## configured tick rate, plus a fixed frame grace.
func _frame_budget(seconds: float) -> int:
	var required := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + FRAME_BUDGET_GRACE


## Waits for a door to reach `expected_state` on the physics clock, which is the
## clock `StationDoor` actually advances its panel on.
##
## The budget deliberately counts physics steps rather than wall-clock seconds. A
## `Time.get_ticks_msec()` deadline measures the monotonic clock, and under load
## Godot drops physics steps rather than letting the simulation spiral, so the
## wall clock reaches the deadline while the panel has been stepped only part of
## the way. The wait then returned silently and the caller asserted on a door
## caught mid-travel — a false failure, not a defect. Counting frames gives the
## door the same amount of simulation however busy the box is, and still fails a
## genuinely stuck door because the budget remains finite.
##
## Returns whether the state was actually reached so callers can assert on it
## rather than assume it.
func _wait_for_door_state(door: StationDoor, expected_state: int, travel_seconds: float) -> bool:
	var frame_budget := _frame_budget(travel_seconds)
	var frames := 0
	while is_instance_valid(door) and door.get_state() != expected_state:
		if frames >= frame_budget:
			break
		await physics_frame
		frames += 1
	await process_frame
	return is_instance_valid(door) and door.get_state() == expected_state


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("AFT_JUNCTION_STACK_TEST_OK")
		quit(0)
	else:
		print("AFT_JUNCTION_STACK_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
