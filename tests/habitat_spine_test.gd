extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/habitat_spine.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. A frame count, never a wall-clock grace: the door advances in
## `_physics_process`, and only a frame budget measures the same amount of panel
## motion on a loaded box as on an idle one.
const FRAME_BUDGET_GRACE := 30

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	if OS.get_cmdline_user_args().has("--capture-service"):
		call_deferred("_capture_forward_plus", true)
	elif OS.get_cmdline_user_args().has("--capture"):
		call_deferred("_capture_forward_plus", false)
	else:
		call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "HabitatSpineTestRoot"
	root.add_child(_test_root)

	var module := MODULE_SCENE.instantiate() as HabitatSpine
	_check(module != null, "habitat scene instantiates as HabitatSpine")
	if module == null:
		_finish()
		return
	module.position = Vector3(-17.0, 2.25, 31.0)
	module.rotation_degrees.y = -34.0
	_test_root.add_child(module)
	var synchronous_audit := module.get_audit_report()
	var synchronous_render := module.get_render_allocation_report()
	_check(
		bool(synchronous_audit.get("valid", false))
		and bool(synchronous_render.get("exact_counts", false))
		and int(synchronous_render.get("unique_material_resources", -1)) == 32,
		"Habitat is allocation-green synchronously before its ShipyardWorld parent can validate it"
	)
	await process_frame
	await physics_frame
	await physics_frame

	_test_identity_evidence_and_audit(module)
	_test_route_room_and_footprint_contract(module)
	await _test_physical_support_and_clearance(module)
	await _test_main_station_door(module)
	await _test_bunk_alcoves(module)
	await _test_common_room_glazing_and_furniture(module)
	await _test_garden_pressure_shell(module)
	_test_service_and_visual_detail(module)
	await _test_garden_branch(module)
	await _test_negative_space(module)
	_test_collision_contract(module)
	await _test_lifecycle(module)
	await _test_cleanup(module)
	_finish()


func _test_identity_evidence_and_audit(module: HabitatSpine) -> void:
	_check(module.get_module_id() == &"habitat-spine", "module exposes a stable identity")
	_check(bool(module.get_meta("station_module", false)), "root metadata identifies a station module")
	_check(module.is_in_group("station_modules"), "module participates in station-module discovery")
	_check(str(module.get_meta("evidence_status", "")) == "fixed_era_inspired_modern_interpretation", "root identifies a fixed-era-inspired modern interpretation")
	_check(not bool(module.get_meta("authenticated_original_geometry", true)), "root rejects an authenticated-original-geometry claim")
	_check(not bool(module.get_meta("fixed_era_provenance_verified", true)), "root preserves uncertainty about exact fixed-build provenance")

	var evidence := module.get_evidence_metadata()
	_check(int(evidence.schema_version) == HabitatSpine.SCHEMA_VERSION, "evidence report has a stable schema")
	_check(str(evidence.evidence_status) == "fixed_era_inspired_modern_interpretation", "evidence API uses the bounded status")
	_check(bool(evidence.source_bounded), "evidence API identifies source-bounded design")
	_check(not bool(evidence.authenticated_original_geometry), "evidence API never presents recovered original geometry")
	_check(not bool(evidence.fixed_era_provenance_verified), "evidence API does not authenticate the later recording's exact build")
	_check((evidence.references as PackedStringArray).size() >= 5, "evidence API exposes timestamped and documentary references")
	_check("later secondary" in str(evidence.content_note) and "No part" in str(evidence.content_note), "content note states both source tier and non-reconstruction boundary")
	_check("wholly modern" in str(evidence.content_note) and "no source describes" in str(evidence.content_note).to_lower(), "content note records the branch room as invented rather than reconstructed")
	var interpretations := evidence.modern_interpretations as PackedStringArray
	_check(interpretations.has("six-alcove arrangement and observation/common room function"), "exact room function and arrangement are disclosed as modern interpretation")
	var returned_references := evidence.references as PackedStringArray
	returned_references.append("mutation")
	_check(not (module.get_evidence_metadata().references as PackedStringArray).has("mutation"), "evidence arrays are detached from module state")

	var audit := module.get_audit_report()
	_check(bool(audit.valid), "fully constructed habitat passes its public audit")
	_check((audit.errors as PackedStringArray).is_empty(), "valid audit reports no hidden structural errors")
	_check(int(audit.bunk_count) == 6 and int(audit.chair_count) == 8, "audit exposes habitat furniture counts")
	_check(int(audit.window_pane_count) >= 9 and int(audit.service_detail_count) >= 8, "audit exposes glazing and service-detail density")
	_check(bool(audit.side_branch_open), "audit proves the side branch door is open onto its built room")
	(audit.evidence as Dictionary)["content_note"] = "mutation"
	_check(str(module.get_audit_report().evidence.content_note) != "mutation", "audit dictionaries are detached from module state")


func _test_route_room_and_footprint_contract(module: HabitatSpine) -> void:
	var expected_routes := PackedStringArray([
		"approach",
		"threshold",
		"habitat-corridor",
		"common-entry",
		"observation",
		"deferred-branch",
	])
	for route_name in expected_routes:
		var route_id := StringName(route_name)
		_check(module.has_route_marker(route_id), "route registry exposes %s" % route_name)
		_check(module.get_route_marker(route_id) != null, "route resolves to a physical Marker3D: %s" % route_name)
	_check(module.get_route_ids().size() == expected_routes.size(), "route registry has no implicit or missing entries")
	# Re-frozen local (6.1, 0.15, 20.0) -> (10.6, 0.15, 20.0), which maps
	# world (69.0, 0.15, 9.4) -> (69.0, 0.15, 4.9) in production. The old marker
	# was 4.25 m outside the garden volume while claiming that room ID.
	_check(
		module.get_route_marker(&"deferred-branch").position.is_equal_approx(Vector3(10.6, 0.15, 20.0)),
		"garden route marker holds its measured room-interior local transform"
	)
	_check(module.get_route_marker(&"unsupported-room") == null, "unknown route has no invented fallback")
	_check(module.get_route_transform(&"observation").origin.is_equal_approx(module.get_route_marker(&"observation").global_position), "route transform composes through arbitrary module transform")

	var clearance := module.get_clearance_profile()
	_check(float(clearance.connector_clear_width) >= 4.4, "connector publishes a generous player-clear width")
	_check(float(clearance.door_clear_width) >= 3.0, "doorway publishes substantially more than avatar diameter")
	_check(float(clearance.corridor_clear_width) >= 4.5, "central pressurized corridor publishes two-way clearance")
	_check(float(clearance.minimum_head_clearance) >= 4.0, "corridor head clearance exceeds avatar height by a large margin")
	_check(float(clearance.player_capsule_reference_diameter) == 0.76, "clearance contract is tied to the real player capsule diameter")

	var room_ids := module.get_room_ids()
	# 9 -> 10: the side branch garden bay is a real room now and is registered as
	# `garden-cupola`, so the registry publishes connector, corridor, common,
	# garden and six alcoves.
	_check(room_ids.size() == 10, "room registry exposes connector, corridor, common, garden, and six alcoves only")
	_check(module.get_bunk_room_ids().size() == 6, "six bunk room IDs are independently addressable")
	_check(not module.has_room(&"deferred-branch"), "route-marker ID is not misrepresented as a separate built room")
	_check(module.get_room_volume(&"unsupported-room").is_empty(), "unknown room volume has no fallback")
	for room_id in room_ids:
		var volume := module.get_room_volume(room_id)
		_check(not volume.is_empty(), "registered room has a typed occupancy volume: %s" % room_id)
		_check((volume.half_extents as Vector3).is_finite(), "room volume is finite: %s" % room_id)
		_check((volume.world_transform as Transform3D).origin.is_equal_approx(module.to_global(volume.local_center)), "room volume transforms correctly: %s" % room_id)
		_check(module.contains_room(room_id, module.to_global(volume.local_center)), "room contains its own centre: %s" % room_id)
	_check(not module.contains_room(&"habitat-corridor", module.to_global(Vector3(5.0, 1.0, 10.0))), "bunk side zone does not masquerade as central corridor occupancy")
	_check(not module.contains_room(&"observation-common", module.to_global(Vector3(0, 1.0, 10.0))), "corridor does not masquerade as common-room occupancy")

	var footprint := module.get_integration_footprint()
	_check((footprint.local_min as Vector3).x <= -9.0 and (footprint.local_max as Vector3).x >= 9.0, "footprint publishes complete observation-room width")
	_check((footprint.local_min as Vector3).z <= -4.2 and (footprint.local_max as Vector3).z >= 29.2, "footprint includes connector and rear pressure shell")
	_check((footprint.local_size as Vector3).is_equal_approx((footprint.local_max as Vector3) - (footprint.local_min as Vector3)), "footprint size is internally coherent")
	_check(module.get_module_anchor().global_transform.is_equal_approx(module.global_transform), "module anchor is the exact root connection transform")


func _test_physical_support_and_clearance(module: HabitatSpine) -> void:
	var route_samples := PackedVector3Array([
		Vector3(0, 1.08, -3.2),
		Vector3(0, 1.08, -0.75),
		Vector3(0, 1.08, 1.55),
		Vector3(0, 1.08, 5.0),
		Vector3(0, 1.08, 10.0),
		Vector3(0, 1.08, 16.5),
		Vector3(0, 1.08, 19.0),
		Vector3(-2.0, 1.08, 21.3),
		Vector3(-2.0, 1.08, 23.2),
		Vector3(0, 1.08, 24.2),
	])
	var every_sample_supported := true
	for sample in route_samples:
		var support := await _ray_local(module, sample + Vector3.UP * 0.75, Vector3(sample.x, -0.75, sample.z))
		if support.is_empty():
			every_sample_supported = false
		elif absf(module.to_local(support.position).y) > 0.03:
			every_sample_supported = false
	_check(every_sample_supported, "connector-to-common route has continuous collision support at floor elevation")

	# Open the only supported path before testing a real player-size collision
	# envelope through its threshold.
	var main_access := module.get_main_access()
	_check(main_access.interact(module), "main habitat access accepts interaction before clearance test")
	var clearance_access_opened := await _wait_for_door_state(main_access, StationDoor.DoorState.OPEN, 1.5)
	_check(clearance_access_opened, "main access opens fully inside its physics-frame budget before the clearance sweep")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.94
	var every_sample_clear := true
	for sample in route_samples:
		var hits := await _intersect_shape_local(module, capsule, Transform3D(Basis.IDENTITY, sample), 24)
		if not hits.is_empty():
			every_sample_clear = false
	_check(every_sample_clear, "real player capsule clears the supported connector, corridor, table detour, and common route")

	var connector_crossing := await _ray_local(module, Vector3(-2.2, 1.15, -1.4), Vector3(2.2, 1.15, -1.4))
	_check(connector_crossing.is_empty(), "published connector width is free of hidden collision")
	var corridor_crossing := await _ray_local(module, Vector3(-2.2, 1.15, 10.0), Vector3(2.2, 1.15, 10.0))
	_check(corridor_crossing.is_empty(), "published central corridor width is free of hidden collision")
	var head_clearance := await _ray_local(module, Vector3(0, 0.2, 10.0), Vector3(0, 4.0, 10.0))
	_check(head_clearance.is_empty(), "central corridor preserves its published four-metre head clearance")


func _test_main_station_door(module: HabitatSpine) -> void:
	var door := module.get_main_access()
	_check(door != null, "main access is exposed as reusable StationDoor")
	if door == null:
		return
	_check(door.collision_layer == PhysicsLayers.INTERACTABLE and door.collision_mask == 0, "main access follows canonical interaction collision contract")
	_check(not door.locked and not door.deferred_access, "supported habitat route is usable rather than decorative")
	_check(str(door.get_meta("evidence_status")) == "fixed_era_inspired_modern_interpretation", "door preserves habitat evidence status")
	_check("HABITAT ACCESS" in door.get_interaction_prompt(), "door prompt identifies habitat access")
	_check(door.is_open() and not door.is_portal_blocked(), "clearance setup left the main access fully open")
	var open_hit := await _ray_through_door(door)
	_check(open_hit.is_empty(), "open StationDoor exposes an unobstructed physical threshold")
	_check(door.interact(module), "main StationDoor accepts a close interaction")
	var main_access_closed := await _wait_for_door_state(door, StationDoor.DoorState.CLOSED, 1.5)
	_check(main_access_closed, "main StationDoor completes its closing motion inside its physics-frame budget")
	_check(door.is_portal_blocked(), "closed main access restores its physical pressure barrier")
	var closed_hit := await _ray_through_door(door)
	_check(not closed_hit.is_empty(), "closed StationDoor blocks a real physics ray")
	_check(door.interact(module), "main StationDoor reopens repeatably")
	var main_access_reopened := await _wait_for_door_state(door, StationDoor.DoorState.OPEN, 1.5)
	_check(main_access_reopened, "the second opening completes inside its physics-frame budget")
	_check(door.is_open(), "main StationDoor completes a second opening lifecycle")


func _test_bunk_alcoves(module: HabitatSpine) -> void:
	_check(module.get_bunk_count() == 6, "module constructs six physical bunk alcoves")
	_check(module.get_bunk_markers().size() == 6, "module exposes one marker per bunk alcove")
	var bunks: Array[Node3D] = []
	for index in 6:
		var bunk := module.get_node_or_null("Structure/PressurizedHabitatCorridor/BunkAlcove%02d" % (index + 1)) as Node3D
		if bunk != null:
			bunks.append(bunk)
	_check(bunks.size() == 6, "six independently addressable bunk roots exist in the scene tree")
	for index in 6:
		var bunk := bunks[index] as Node3D
		var room_id := StringName("bunk-alcove-%02d" % (index + 1))
		_check(bool(bunk.get_meta("station_bunk_alcove", false)), "bunk root is semantically tagged: %s" % room_id)
		_check(str(bunk.get_meta("evidence_status")) == "fixed_era_inspired_modern_interpretation", "bunk keeps bounded evidence status: %s" % room_id)
		var volume := module.get_room_volume(room_id)
		var center := volume.local_center as Vector3
		var floor_hit := await _ray_local(module, center + Vector3.UP * 0.6, Vector3(center.x, -0.7, center.z))
		_check(not floor_hit.is_empty(), "bunk alcove has collision-backed floor: %s" % room_id)
		if not floor_hit.is_empty():
			_check(absf(module.to_local(floor_hit.position).y) < 0.03, "bunk floor joins corridor elevation: %s" % room_id)
		_check(module.contains_room(room_id, module.to_global(center)), "bunk centre lies in published occupancy volume: %s" % room_id)
		_check(not module.contains_room(room_id, module.to_global(Vector3(0, 1.0, center.z))), "central corridor is outside bunk occupancy: %s" % room_id)
		_check(bunk.get_node_or_null("BunkPlinth") is StaticBody3D and bunk.get_node_or_null("Mattress") is StaticBody3D, "bunk sleeping surface is physically backed: %s" % room_id)


func _test_common_room_glazing_and_furniture(module: HabitatSpine) -> void:
	_check(module.get_chair_count() == 8, "observation/common area contains eight physical chairs")
	var chairs := module.find_children("CommonChair*", "Node3D", true, false)
	_check(chairs.size() == 8, "eight independently addressable common-chair roots exist")
	var all_chairs_tagged := true
	for chair in chairs:
		all_chairs_tagged = all_chairs_tagged and bool(chair.get_meta("station_chair", false))
		all_chairs_tagged = all_chairs_tagged and chair.get_node_or_null("Seat") is StaticBody3D
	_check(all_chairs_tagged, "every common chair is tagged and collision-backed")
	var material_audit := module.get_observation_chair_material_audit()
	var render_before_material_probe := module.get_render_allocation_report()
	_check(
		bool(material_audit.valid)
		and StringName(material_audit.evidence_status) == &"modern_interpretation"
		and int(material_audit.backrest_count) == 8
		and int(material_audit.collision_count) == 8
		and (material_audit.albedo as Color).is_equal_approx(
			HabitatSpine.OBSERVATION_BACKREST_COLOR
		)
		and is_equal_approx(
			float(material_audit.roughness),
			HabitatSpine.OBSERVATION_BACKREST_ROUGHNESS
		)
		and int(material_audit.node_delta) == 0
		and int(material_audit.light_delta) == 0
		and int(material_audit.geometry_submission_delta) == 0
		and int(material_audit.material_resource_delta) == 1
		and int(render_before_material_probe.unique_material_resources) == 32
		and bool(render_before_material_probe.exact_counts),
		"eight chair-only modern backrests lift albedo/response with no geometry, collision, light, or submission growth"
	)
	var bearing_material: Material = null
	var bearings_exact := true
	var bearing_triangles_before := 0
	var bearing_triangles_after := 0
	for chair in chairs:
		var bearing := chair.get_node_or_null("Bearing") as MeshInstance3D
		var mesh := bearing.mesh as TorusMesh if bearing != null else null
		if bearing == null or mesh == null:
			bearings_exact = false
			continue
		var before_aabb := mesh.get_aabb()
		bearing_triangles_before += 32 * 13 * 2
		TorusGeometryBudget.apply_profile(
			mesh,
			1.0,
			StringName(bearing.get_meta(TorusGeometryBudget.PROFILE_META, &""))
		)
		bearing_triangles_after += TorusGeometryBudget.triangles_of(mesh)
		if bearing_material == null:
			bearing_material = bearing.material_override
		bearings_exact = bearings_exact \
			and bearing.position.is_equal_approx(Vector3(0.0, 0.72, 0.0)) \
			and bearing.rotation.is_zero_approx() \
			and bearing.material_override == bearing_material \
			and bearing.get_child_count() == 0 \
			and StringName(bearing.get_meta(TorusGeometryBudget.PROFILE_META, &"")) \
			== TorusGeometryBudget.PROFILE_OCCLUDED_CHAIR_BEARING \
			and is_equal_approx(mesh.inner_radius, 0.16) \
			and is_equal_approx(mesh.outer_radius, 0.24) \
			and mesh.rings == 32 \
			and mesh.ring_segments == 8 \
			and mesh.get_surface_count() == 1 \
			and mesh.get_aabb().is_equal_approx(before_aabb)
	_check(
		bearings_exact,
		"all eight visual-only bearings retain transforms, copper material, radii, bounds, and one surface"
	)
	_check(
		bearing_triangles_before == 6656 and bearing_triangles_after == 4096,
		"chair-bearing family freezes at 6656 -> 4096 triangles across eight unchanged instances"
	)

	_check(module.get_window_pane_count() >= 9, "common area exposes broad multi-pane glazing")
	var glazing := module.find_children("*", "StaticBody3D", true, false).filter(
		func(candidate: Node) -> bool: return bool(candidate.get_meta("station_glazing", false))
	)
	_check(glazing.size() >= 9, "broad glazing uses independent StaticBody pressure barriers")
	var all_glazing_tagged := true
	for pane in glazing:
		all_glazing_tagged = all_glazing_tagged \
			and bool(pane.get_meta("station_glazing", false)) \
			and bool(pane.get_meta("physical_pressure_barrier", false))
	_check(all_glazing_tagged, "every pane advertises physical pressure-barrier semantics")
	var rear_glass_hit := await _ray_local(module, Vector3(1.85, 2.5, 26.8), Vector3(1.85, 2.5, 30.0))
	_check(not rear_glass_hit.is_empty(), "rear observation glazing physically contains the room")
	if not rear_glass_hit.is_empty():
		_check(bool((rear_glass_hit.collider as Node).get_meta("station_glazing", false)), "rear sightline terminates on glazing rather than invisible wall")
	var outside_point := module.to_global(Vector3(0, 1.0, 30.0))
	_check(not module.contains_room(&"observation-common", outside_point), "space beyond broad window is outside common-room volume")


## The cupola is drawn partly from a MultiMesh, but it is still pressure-shell
## structure. Its one sibling body must remain an exact physical copy of all eight
## cap instances, and the registered glass oculus must itself be a real barrier.
func _test_garden_pressure_shell(module: HabitatSpine) -> void:
	var garden_volume := module.get_room_volume(&"garden-cupola")
	_check(
		(garden_volume.half_extents as Vector3).is_equal_approx(Vector3(5.265, 2.5, 7.41)),
		"garden room occupancy is 30 percent wider and longer without gaining height"
	)
	var garden_floor := module.get_node_or_null(
		^"Structure/SideBranchGarden/GardenShell/GardenFloor"
	) as StaticBody3D
	var floor_collision := garden_floor.get_node_or_null(^"Collision") as CollisionShape3D if garden_floor != null else null
	var floor_shape := floor_collision.shape as BoxShape3D if floor_collision != null else null
	_check(
		floor_shape != null and floor_shape.size.is_equal_approx(Vector3(11.18, 0.5, 15.60)),
		"garden floor dimensions are exactly 130 percent of the original shell"
	)
	var caps := module.get_node_or_null(
		^"Structure/SideBranchGarden/GardenShell/CupolaCaps"
	) as MultiMeshInstance3D
	var cap_collision := module.get_node_or_null(
		^"Structure/SideBranchGarden/GardenShell/CupolaCapCollision"
	) as StaticBody3D
	_check(caps != null and caps.multimesh != null, "cupola cap visual batch resolves")
	_check(cap_collision != null, "cupola caps own one sibling collision body")
	if caps == null or caps.multimesh == null or cap_collision == null:
		return
	var visual_path := cap_collision.get_meta("multimesh_visual_path", NodePath()) as NodePath
	_check(cap_collision.get_node_or_null(visual_path) == caps, "cap collision metadata resolves the live MultiMesh authority")
	_check(cap_collision.collision_layer == WORLD_LAYER and cap_collision.collision_mask == 0, "cap collision uses the canonical World layer/mask")
	var multi := caps.multimesh
	var authored_transforms := caps.get_meta("authored_instance_transforms", []) as Array
	var shapes := cap_collision.find_children("Collision*", "CollisionShape3D", false, false)
	_check(multi.instance_count == 8 and authored_transforms.size() == 8 and shapes.size() == 8, "eight drawn cupola caps have eight authored transforms and physical shapes")
	var every_cap_exact := shapes.size() == authored_transforms.size()
	var every_cap_tangent := true
	var visual_extent := multi.mesh.get_aabb().size
	for instance_index in mini(shapes.size(), authored_transforms.size()):
		var visual_transform := authored_transforms[instance_index] as Transform3D
		var collision := cap_collision.get_node_or_null(
			NodePath("Collision%02d" % instance_index)
		) as CollisionShape3D
		var box := collision.shape as BoxShape3D if collision != null else null
		every_cap_exact = every_cap_exact \
			and collision != null \
			and not collision.disabled \
			and collision.transform.is_equal_approx(visual_transform) \
			and box != null \
			and box.size.is_equal_approx(visual_extent)
		var radial := Vector3(
			visual_transform.origin.x - 14.4, 0.0, visual_transform.origin.z - 20.2
		).normalized()
		every_cap_tangent = every_cap_tangent and absf(visual_transform.basis.x.normalized().dot(radial)) <= 0.001
	_check(every_cap_exact, "every cap shape exactly matches its authored batch transform and live mesh extent")
	_check(every_cap_tangent, "all eight long-axis cupola caps are tangent rather than radial spokes")
	if not RenderingServer.get_video_adapter_name().is_empty():
		var live_buffer_exact := true
		for instance_index in multi.instance_count:
			live_buffer_exact = live_buffer_exact and multi.get_instance_transform(instance_index).is_equal_approx(
				authored_transforms[instance_index] as Transform3D
			)
		_check(live_buffer_exact, "rendering device holds the same eight cap transforms as the authored roster")

	var cap_hit := await _ray_local(module, Vector3(14.4, 6.4, 22.62), Vector3(14.4, 7.6, 22.62))
	_check(not cap_hit.is_empty() and cap_hit.collider == cap_collision, "a ray through a drawn cap meets its matching pressure-shell collision")
	var oculus := module.get_node_or_null(
		^"Structure/SideBranchGarden/GardenShell/CupolaOculus"
	) as StaticBody3D
	_check(oculus != null and bool(oculus.get_meta("physical_pressure_barrier", false)), "registered cupola oculus is a physical glazing body")
	var oculus_hit := await _ray_local(module, Vector3(14.4, 6.4, 20.2), Vector3(14.4, 7.6, 20.2))
	_check(not oculus_hit.is_empty() and oculus_hit.collider == oculus, "a ray through the oculus meets the registered glass barrier")

	var every_pane_tangent := true
	var every_kerb_tangent := true
	for facet_index in 8:
		var pane := module.get_node_or_null(
			NodePath("Structure/SideBranchGarden/GardenShell/CupolaPane%02d" % (facet_index + 1))
		) as StaticBody3D
		var kerb := module.get_node_or_null(
			NodePath("Structure/SideBranchGarden/GardenColumn/BedKerb%02d" % (facet_index + 1))
		) as StaticBody3D
		if pane == null:
			every_pane_tangent = false
		else:
			var pane_radial := Vector3(pane.position.x - 14.4, 0.0, pane.position.z - 20.2).normalized()
			every_pane_tangent = every_pane_tangent and absf(pane.basis.x.normalized().dot(pane_radial)) <= 0.001
		if kerb == null:
			every_kerb_tangent = false
		else:
			var kerb_radial := Vector3(kerb.position.x - 14.4, 0.0, kerb.position.z - 20.2).normalized()
			every_kerb_tangent = every_kerb_tangent and absf(kerb.basis.x.normalized().dot(kerb_radial)) <= 0.001
	_check(every_pane_tangent, "all eight long-axis cupola panes close a tangent octagonal pressure wall")
	_check(every_kerb_tangent, "all eight planting-bed kerbs form a tangent ring without diagonal gaps")

	var every_rack_faces_inward := true
	for rack_number in [1, 2, 3, 4, 6]:
		var rack := module.get_node_or_null(
			NodePath("Structure/SideBranchGarden/GardenGrowRacks/GrowRack%02d" % rack_number)
		) as Node3D
		if rack == null:
			every_rack_faces_inward = false
			continue
		var outward := Vector3(rack.position.x - 14.4, 0.0, rack.position.z - 20.2).normalized()
		every_rack_faces_inward = every_rack_faces_inward and rack.basis.x.normalized().dot(outward) >= 0.999
	_check(module.get_node_or_null(^"Structure/SideBranchGarden/GardenGrowRacks/GrowRack05") == null, "entry-side grow rack is absent so it cannot obstruct the garden threshold")
	_check(every_rack_faces_inward, "all five remaining rack label faces point inward toward the nutrient column")

	var soil := module.get_node_or_null(
		^"Structure/SideBranchGarden/GardenColumn/BedSoil"
	) as StaticBody3D
	_check(soil != null, "the raised visible soil bed is collision-backed")
	var soil_hit := await _ray_local(module, Vector3(15.4, 1.4, 20.2), Vector3(15.4, -0.2, 20.2))
	_check(not soil_hit.is_empty() and soil_hit.collider == soil, "a descending player-space ray lands on the visible soil surface")

	var garden_marker := module.get_route_marker(&"deferred-branch")
	_check(
		garden_marker != null and module.contains_room(&"garden-cupola", garden_marker.global_position),
		"garden route marker sits inside the room it publishes"
	)


func _test_service_and_visual_detail(module: HabitatSpine) -> void:
	_check(module.get_service_detail_count() >= 20, "habitat contains a layered maintenance/service system")
	var service_nodes := module.find_children("*", "Node3D", true, false).filter(
		func(candidate: Node) -> bool: return bool(candidate.get_meta("station_service_detail", false))
	)
	_check(service_nodes.size() == module.get_service_detail_count(), "every public service detail is discoverable through semantic metadata")
	var service_classes := {}
	for candidate in service_nodes:
		service_classes[candidate.get_meta("service_class")] = true
	_check(service_classes.has(&"environmental-main") and service_classes.has(&"isolation-valve"), "service layer includes environmental mains and isolation valves")
	_check(service_classes.has(&"service-cabinet") and service_classes.has(&"service-hatch"), "service layer includes cabinets and floor access hatches")
	_test_cabinet_louvre_batch(module)
	_test_hatch_fastener_batch(module)
	_test_nutrient_tank_band_batch(module)
	_test_nutrient_valve_batch(module)
	_test_garden_bench_leg_batching(module)
	_test_garden_column_collar_mesh_sharing(module)
	_test_pipe_collar_mesh_sharing(module)
	_test_cupola_downlight_batch(module)
	_test_corridor_deck_seam_batch(module)
	_test_common_ceiling_light_body_batch(module)
	var render := module.get_render_allocation_report()
	_check(
		int(render.descendant_nodes) == 1878
		and module.find_children("*", "MeshInstance3D", true, false).size() == 1227
		and module.find_children("*", "MultiMeshInstance3D", true, false).size() == 20,
		"visual batching stays frozen at 1878 render nodes, 1227 meshes and 20 MultiMeshes"
	)
	var performance := module.get_performance_contract()
	_check(
		int(performance.static_bodies) == 245
		and int(performance.collision_shapes) == 266
		and bool(performance.within_budget),
		"23 fixed seats add only the expected eight Habitat interaction shapes beside 245 solid bodies"
	)

	var pressure_ribs := module.find_children("*", "Node3D", true, false).filter(
		func(candidate: Node) -> bool: return "PressureRib" in candidate.name
	)
	_check(pressure_ribs.size() >= 12, "curved pressure-rib rhythm softens the habitat shell")
	var rounded_surfaces := module.find_children("*", "MeshInstance3D", true, false).filter(
		func(candidate: Node) -> bool: return (candidate as MeshInstance3D).mesh is ArrayMesh
	)
	_check(rounded_surfaces.size() >= 30, "custom bevelled surfaces replace raw block primitives throughout occupied spaces")
	# `CylinderMesh` used to be a sufficient test for "this is a turned round
	# form". It no longer is: this module's cylinders are now chamfered-rim
	# `ArrayMesh` builds from `StationSurfaceKit`, which is what gives the rail
	# ends and column caps a highlight instead of a zero-width 90° edge. The kit
	# publishes `is_cylindrical_mesh` so the check keeps asking the same question.
	# Threshold unchanged at >= 50; the live count went 475 -> 475 across the swap
	# (454 chamfered cylinders + 21 tori), so this is a spelling change, not a
	# loosened bound.
	var tubular_surfaces := module.find_children("*", "MeshInstance3D", true, false).filter(
		func(candidate: Node) -> bool:
			var mesh := (candidate as MeshInstance3D).mesh
			return StationSurfaceKit.is_cylindrical_mesh(mesh) or mesh is TorusMesh
	)
	_check(tubular_surfaces.size() >= 50, "tubular rails, ribs, utilities, furniture, and fittings provide modern silhouette detail")
	var material_sample := (module.find_child("ConnectorFloor", true, false) as StaticBody3D).get_node("Mesh") as MeshInstance3D
	var pbr := material_sample.material_override as StandardMaterial3D
	_check(pbr != null and pbr.clearcoat_enabled and pbr.roughness > 0.0 and pbr.metallic > 0.0, "primary shell uses layered PBR response rather than flat unlit colour")


func _test_corridor_deck_seam_batch(module: HabitatSpine) -> void:
	var corridor := module.get_node_or_null(
		^"Structure/PressurizedHabitatCorridor"
	) as Node3D
	var batch := corridor.get_node_or_null(^"DeckSeams") as MultiMeshInstance3D if corridor != null else null
	_check(
		corridor != null and batch != null and batch.multimesh != null,
		"nine corridor deck seams resolve through one visual-only MultiMesh"
	)
	if corridor == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = []
	for seam_z in [3.15, 5.1, 7.1, 8.15, 10.1, 12.1, 13.15, 15.1, 17.1]:
		expected.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.055, float(seam_z))))
	var anchors: Array[MeshInstance3D] = []
	for raw_node in corridor.get_children():
		var candidate := raw_node as MeshInstance3D
		if (
			candidate != null
			and candidate.mesh != null
			and candidate.mesh.get_aabb().size.is_equal_approx(Vector3(4.2, 0.02, 0.045))
			and not candidate.visible
		):
			anchors.append(candidate)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = (
			anchors_exact
			and anchors[index].transform.is_equal_approx(expected[index])
			and anchors[index].get_child_count() == 0
			and anchors[index].get_script() == null
			and anchors[index].material_override == anchors[0].material_override
		)
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (authored[index] as Transform3D).is_equal_approx(expected[index])
	_check(
		anchors_exact
		and authored_exact
		and batch.multimesh.instance_count == HabitatSpine.CORRIDOR_DECK_SEAM_COPY_COUNT
		and batch.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(4.2, 0.02, 0.045))
		and batch.material_override == anchors[0].material_override,
		"batch preserves nine exact transforms, graphite material, mesh extent and stable legacy anchors"
	)
	_check(
		batch.get_child_count() == 0
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
		and batch.find_children("*", "Area3D", true, false).is_empty()
		and bool(batch.get_meta("visual_detail_only", false)),
		"deck-seam batch remains childless, collision-free and presentation-only"
	)
	var report := module.get_render_allocation_report()
	_check(
		int(report.corridor_deck_seam_legacy_submissions) == 9
		and int(report.corridor_deck_seam_submissions) == 1
		and int(report.geometry_submissions_before_deck_seam_batch) == 1251
		and int(report.geometry_submissions) == 1238
		and int(report.geometry_submissions_removed_by_deck_seam_batch) == 8
		and int(report.drawn_copies) == 1377
		and bool(report.corridor_deck_seam_authored),
		"corridor seams measure 9 -> 1 submissions while all nine visible copies remain"
	)
	var detached := report.authored_corridor_deck_seam_transforms as Array
	detached[0] = Transform3D.IDENTITY
	_check(
		not ((module.get_render_allocation_report().authored_corridor_deck_seam_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"deck-seam allocation report returns a detached authored-transform roster"
	)


func _test_common_ceiling_light_body_batch(module: HabitatSpine) -> void:
	var common := module.get_node_or_null(^"Structure/ObservationCommon") as Node3D
	var batch := common.get_node_or_null(^"CeilingLightBodies") as MultiMeshInstance3D if common != null else null
	_check(
		common != null and batch != null and batch.multimesh != null,
		"six common-room ceiling-light housings resolve through one visual-only MultiMesh"
	)
	if common == null or batch == null or batch.multimesh == null:
		return
	var expected: Array[Transform3D] = []
	for light_z in [20.5, 24.3]:
		for light_x in [-4.7, 0.0, 4.7]:
			expected.append(Transform3D(
				Basis.IDENTITY,
				Vector3(float(light_x), 4.58, float(light_z) - 0.2)
			))
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var geometry_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		geometry_exact = geometry_exact and (authored[index] as Transform3D).is_equal_approx(expected[index])
	_check(
		geometry_exact
		and batch.multimesh.instance_count == HabitatSpine.COMMON_CEILING_LIGHT_BODY_COPY_COUNT
		and batch.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(1.95, 0.12, 0.46))
		and batch.multimesh.custom_aabb.is_equal_approx(AABB(
			Vector3(-5.675, 4.52, 20.07), Vector3(11.35, 0.12, 4.26)
		))
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1,
		"ceiling-light batch preserves all six transforms, exact housing extent, culling union, shadows and render layer"
	)
	_check(
		common.find_children("CeilingLightBody", "MeshInstance3D", false, false).is_empty()
		and batch.get_child_count() == 0
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
		and batch.find_children("*", "Area3D", true, false).is_empty()
		and bool(batch.get_meta("visual_detail_only", false))
		and StringName(batch.get_meta("authored_source_name", &"")) == &"CeilingLightBody",
		"only authority-free housing visuals are batched while lenses and practical lights remain ordinary nodes"
	)
	var retained_lenses := 0
	var retained_pool_lights := 0
	for child in common.get_children():
		var mesh_instance := child as MeshInstance3D
		if (
			mesh_instance != null
			and mesh_instance.mesh != null
			and mesh_instance.mesh.get_aabb().size.is_equal_approx(Vector3(1.55, 0.035, 0.2))
		):
			retained_lenses += 1
		var omni := child as OmniLight3D
		if (
			omni != null
			and omni.light_color.is_equal_approx(Color("ffe0b4"))
			and is_equal_approx(omni.light_energy, 0.66)
			and is_equal_approx(omni.omni_range, 9.0)
		):
			retained_pool_lights += 1
	_check(
		retained_lenses == 6 and retained_pool_lights == 6,
		"all six authored lenses and six actual common-room lights remain intact"
	)
	var report := module.get_render_allocation_report()
	_check(
		int(report.common_ceiling_light_body_legacy_renderer_nodes) == 6
		and int(report.common_ceiling_light_body_renderer_nodes) == 1
		and int(report.common_ceiling_light_body_legacy_submissions) == 6
		and int(report.common_ceiling_light_body_submissions) == 1
		and int(report.common_ceiling_light_body_copies) == 6
		and int(report.geometry_submissions_before_common_ceiling_light_body_batch) == 1243
		and int(report.geometry_submissions) == 1238
		and int(report.geometry_submissions_removed_by_common_ceiling_light_body_batch) == 5
		and int(report.drawn_copies) == 1377
		and bool(report.common_ceiling_light_body_authored),
		"common ceiling housings measure renderer nodes/submissions 6 -> 1 while all six visible copies remain"
	)


func _test_cupola_downlight_batch(module: HabitatSpine) -> void:
	var shell := module.get_node_or_null(^"Structure/SideBranchGarden/GardenShell") as Node3D
	var bodies := shell.get_node_or_null(^"CupolaDownlightBodies") as MultiMeshInstance3D if shell != null else null
	var lenses := shell.get_node_or_null(^"CupolaDownlightLenses") as MultiMeshInstance3D if shell != null else null
	var anchors_intact := shell != null
	if shell != null:
		for index in HabitatSpine.CUPOLA_DOWNLIGHT_COPY_COUNT:
			anchors_intact = anchors_intact and shell.get_node_or_null(NodePath("CupolaDownlightBody%02d" % (index + 1))) is Marker3D
			anchors_intact = anchors_intact and shell.get_node_or_null(NodePath("CupolaDownlightLens%02d" % (index + 1))) is Marker3D
	_check(
		anchors_intact
		and bodies != null and lenses != null
		and bodies.multimesh != null and lenses.multimesh != null
		and bodies.multimesh.instance_count == HabitatSpine.CUPOLA_DOWNLIGHT_COPY_COUNT
		and lenses.multimesh.instance_count == HabitatSpine.CUPOLA_DOWNLIGHT_COPY_COUNT
		and bodies.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and lenses.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"three cupola downlight body/lens paths retain stable anchors under two inert visual batches"
	)


func _test_cabinet_louvre_batch(module: HabitatSpine) -> void:
	var louvres := module.get_node_or_null(
		^"Structure/MaintenanceServiceLayer/CabinetLouvres"
	) as MultiMeshInstance3D
	_check(louvres != null and louvres.multimesh != null, "nine cabinet louvres resolve through one visual-only MultiMesh")
	if louvres == null or louvres.multimesh == null:
		return
	var multi := louvres.multimesh
	var authored := louvres.get_meta("authored_instance_transforms", []) as Array
	var expected: Array[Transform3D] = []
	for cabinet_index in 3:
		var cabinet_z := 4.35 + float(cabinet_index) * 5.05
		for louvre_index in 3:
			expected.append(
				Transform3D(
					Basis.IDENTITY,
					Vector3(-5.5, 1.42 + float(louvre_index) * 0.16, cabinet_z)
				)
			)
	_check(
		multi.instance_count == 9 and authored.size() == 9 and expected.size() == 9,
		"cabinet batch preserves the exact nine-piece visible roster"
	)
	var authored_exact := authored.size() == expected.size()
	for instance_index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (authored[instance_index] as Transform3D).is_equal_approx(
			expected[instance_index]
		)
	_check(authored_exact, "cabinet batch preserves every authored louvre transform and ordering")
	var door_seam := module.find_child("CabinetDoorSeam", true, false) as MeshInstance3D
	_check(
		multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.03, 0.05, 0.62))
		and door_seam != null
		and louvres.material_override == door_seam.material_override,
		"cabinet batch preserves the louvre box extent and graphite material identity"
	)
	_check(
		module.find_children("CabinetLouvre", "MeshInstance3D", true, false).is_empty(),
		"cabinet louvres leave no duplicate individual renderer nodes"
	)
	if not RenderingServer.get_video_adapter_name().is_empty():
		var renderer_exact := true
		for instance_index in multi.instance_count:
			renderer_exact = renderer_exact and multi.get_instance_transform(instance_index).is_equal_approx(
				authored[instance_index] as Transform3D
			)
		_check(renderer_exact, "Forward+ renderer buffer exactly matches the nine authored louvre transforms")


func _test_hatch_fastener_batch(module: HabitatSpine) -> void:
	var service := module.get_node_or_null(
		^"Structure/MaintenanceServiceLayer"
	) as Node3D
	var batch := module.get_node_or_null(
		^"Structure/MaintenanceServiceLayer/HatchFasteners"
	) as MultiMeshInstance3D
	_check(
		service != null and batch != null and batch.multimesh != null,
		"twelve floor-hatch fasteners resolve through one visual-only MultiMesh"
	)
	if service == null or batch == null or batch.multimesh == null:
		return
	var multi := batch.multimesh
	var expected: Array[Transform3D] = []
	for hatch_z in [5.1, 10.15, 15.2]:
		for fastener_x in [-0.52, 0.52]:
			for fastener_z in [-0.31, 0.31]:
				expected.append(
					Transform3D(
						Basis.IDENTITY,
						Vector3(
							float(fastener_x),
							0.08,
							float(hatch_z) + float(fastener_z)
						)
					)
				)
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (authored[index] as Transform3D).is_equal_approx(
			expected[index]
		)
	_check(
		multi.instance_count == HabitatSpine.HATCH_FASTENER_COPY_COUNT
		and multi.visible_instance_count == -1
		and authored_exact
		and StringName(batch.get_meta("authored_source_name", &"")) == &"HatchFastener",
		"batch preserves all twelve authored fastener transforms, ordering and source identity"
	)
	var brass_reference := module.find_child("CabinetHandle", true, false) as MeshInstance3D
	_check(
		multi.mesh != null
		and multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.06, 0.025, 0.06))
		and multi.mesh.get_surface_count() == 1
		and brass_reference != null
		and batch.material_override == brass_reference.material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1,
		"batch preserves fastener extent, surface, brass material identity, shadows and render layer"
	)
	var old_fastener_nodes := 0
	for raw_node in service.get_children():
		var instance := raw_node as MeshInstance3D
		if (
			instance != null
			and instance.mesh == multi.mesh
			and instance.material_override == batch.material_override
			and is_equal_approx(instance.position.y, 0.08)
		):
			old_fastener_nodes += 1
	var registered_hatches := module.find_children("*", "Node3D", true, false).filter(
		func(candidate: Node) -> bool:
			return candidate.get_meta("service_class", &"") == &"service-hatch"
	)
	_check(
		old_fastener_nodes == 0
		and batch.get_child_count() == 0
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
		and batch.find_children("*", "Area3D", true, false).is_empty()
		and bool(batch.get_meta("visual_detail_only", false))
		and registered_hatches.size() == 3,
		"only childless visual bolt stock is batched while all three registered service hatches remain"
	)

	var report := module.get_render_allocation_report()
	_check(
		int(report.descendant_nodes) == 1878
		and int(report.mesh_instances) == 1227
		and int(report.multimesh_batches) == 20,
		"renderer census includes the exact corridor and common-room batches"
	)
	_check(
		int(report.drawn_copies) == 1377
		and int(report.geometry_submissions) == 1238
		and int(report.hatch_fastener_copies) == 12,
		"drawn copies freeze at 1377 while surface submissions fall 1243 -> 1238"
	)
	_check(
		int(report.unique_mesh_resources) == 349
		and int(report.unique_material_resources) == 32
		and int(report.multimesh_resources) == 20
		and int(report.renderer_buffer_floats) == 144,
		"mesh/material allocations freeze at 349/32 while the hatch batch retains its 144-float renderer buffer"
	)
	_check(
		bool(report.renderer_buffer_matches_authored)
		and bool(report.bounds_match_authored)
		and bool(report.mesh_resource_matches_authored)
		and bool(report.material_resource_matches_authored)
		and bool(report.exact_counts),
		"renderer payload, explicit culling union and shared resource identities match the authored roster"
	)

	var detached := report.authored_hatch_fastener_transforms as Array
	detached[0] = Transform3D.IDENTITY
	_check(
		not ((module.get_render_allocation_report().authored_hatch_fastener_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"render report returns a detached hatch-fastener transform roster"
	)
	# Earlier lifecycle exercises intentionally leave a StationDoor in a live
	# test state. Mutation restoration must return the audit to that exact state,
	# not assume the wider suite has left every unrelated subsystem pristine.
	var baseline_errors := module.get_validation_errors()
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has(
			"Habitat hatch-fastener renderer buffer drifted from its authored transforms"
		),
		"RED: mutating one live fastener transform is rejected by the Habitat audit"
	)
	multi.buffer = original_buffer
	var original_bounds := multi.custom_aabb
	multi.custom_aabb = original_bounds.grow(0.25)
	_check(
		module.get_validation_errors().has(
			"Habitat hatch-fastener culling bounds drifted from its authored copies"
		),
		"RED: mutating the explicit fastener culling union is rejected by the Habitat audit"
	)
	multi.custom_aabb = original_bounds
	_check(
		module.get_validation_errors() == baseline_errors,
		"restoring the exact fastener payload restores the pre-mutation Habitat audit"
	)


func _test_nutrient_tank_band_batch(module: HabitatSpine) -> void:
	var service := module.find_child("GardenService", true, false) as Node3D
	var batch := module.find_child("NutrientTankBands", true, false) as MultiMeshInstance3D
	_check(
		service != null and batch != null and batch.multimesh != null,
		"three garden nutrient-tank bands resolve through one visual-only MultiMesh"
	)
	if service == null or batch == null or batch.multimesh == null:
		return
	var multi := batch.multimesh
	var torus := multi.mesh as TorusMesh
	var expected: Array[Transform3D] = []
	for tank_index in 3:
		expected.append(
			Transform3D(
				Basis.IDENTITY,
				Vector3(12.30 + float(tank_index), 1.16, 25.34)
			)
		)
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (authored[index] as Transform3D).is_equal_approx(
			expected[index]
		)
	_check(
		multi.instance_count == HabitatSpine.NUTRIENT_TANK_BAND_COPY_COUNT
		and multi.visible_instance_count == -1
		and authored_exact
		and StringName(batch.get_meta("authored_source_name", &"")) == &"NutrientTankBand",
		"batch preserves all three authored band transforms, ordering and source identity"
	)
	var copper_reference := module.find_child("CupolaCapRing", true, false) as MeshInstance3D
	_check(
		torus != null
		and is_equal_approx(torus.inner_radius, HabitatSpine.NUTRIENT_TANK_BAND_INNER_RADIUS)
		and is_equal_approx(torus.outer_radius, HabitatSpine.NUTRIENT_TANK_BAND_OUTER_RADIUS)
		and torus.rings == HabitatSpine.NUTRIENT_TANK_BAND_BUDGETED_RINGS
		and torus.ring_segments \
			== HabitatSpine.NUTRIENT_TANK_BAND_BUDGETED_RING_SEGMENTS
		and torus.get_surface_count() == 1
		and torus.get_meta(TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO) \
			== Vector2i(
				HabitatSpine.NUTRIENT_TANK_BAND_RINGS,
				HabitatSpine.NUTRIENT_TANK_BAND_RING_SEGMENTS
			)
		and copper_reference != null
		and batch.material_override == copper_reference.material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1,
		"batch preserves the prior live 40x12 recipe, 48x16 authored metadata, copper identity, shadows and render layer"
	)
	var tanks := service.get_children().filter(
		func(candidate: Node) -> bool:
			return (
				candidate is StaticBody3D
				and is_equal_approx((candidate as Node3D).position.y, 0.82)
				and is_equal_approx((candidate as Node3D).position.z, 25.34)
			)
	)
	var caps := service.get_children().filter(
		func(candidate: Node) -> bool:
			return (
				candidate is MeshInstance3D
				and is_equal_approx((candidate as Node3D).position.y, 1.70)
				and is_equal_approx((candidate as Node3D).position.z, 25.34)
			)
	)
	var old_bands := service.get_children().filter(
		func(candidate: Node) -> bool:
			if not candidate is MeshInstance3D:
				return false
			var old_torus := (candidate as MeshInstance3D).mesh as TorusMesh
			return (
				old_torus != null
				and is_equal_approx(old_torus.inner_radius, 0.40)
				and is_equal_approx(old_torus.outer_radius, 0.47)
				and is_equal_approx((candidate as Node3D).position.y, 1.16)
				and is_equal_approx((candidate as Node3D).position.z, 25.34)
			)
	)
	_check(
		old_bands.is_empty()
		and tanks.size() == 3
		and caps.size() == 3
		and batch.get_child_count() == 0
		and batch.get_script() == null
		and batch.get_groups().is_empty()
		and bool(batch.get_meta("visual_detail_only", false)),
		"only childless visual band stock is batched while all tank collision and cap copies remain"
	)

	var report := module.get_render_allocation_report()
	_check(
		int(report.nutrient_tank_band_legacy_mesh_instances) == 3
		and int(report.nutrient_tank_band_mesh_instances) == 0
		and int(report.nutrient_tank_band_legacy_multimesh_batches) == 0
		and int(report.nutrient_tank_band_multimesh_batches) == 1,
		"nutrient bands freeze renderer nodes at 3 -> 0 MeshInstances and 0 -> 1 MultiMesh batch"
	)
	_check(
		int(report.nutrient_tank_band_legacy_drawn_copies) == 3
		and int(report.nutrient_tank_band_drawn_copies) == 3
		and int(report.nutrient_tank_band_legacy_submissions) == 3
		and int(report.nutrient_tank_band_submissions) == 1,
		"nutrient bands preserve three drawn copies while submissions fall 3 -> 1"
	)
	_check(
		int(report.nutrient_tank_band_legacy_mesh_resources) == 3
		and int(report.nutrient_tank_band_mesh_resources) == 1
		and int(report.nutrient_tank_band_renderer_buffer_floats) == 36,
		"nutrient bands replace three private mesh resources with one exact 36-float renderer payload"
	)
	_check(
		bool(report.nutrient_tank_band_renderer_buffer_matches_authored)
		and bool(report.nutrient_tank_band_bounds_match_authored)
		and bool(report.nutrient_tank_band_recipe_matches_authored)
		and bool(report.nutrient_tank_band_budget_metadata_matches_authored)
		and report.nutrient_tank_band_authored_tessellation == Vector2i(48, 16)
		and report.nutrient_tank_band_live_tessellation == Vector2i(40, 12)
		and bool(report.nutrient_tank_band_material_matches_authored)
		and bool(report.nutrient_tank_band_renderer_state_matches_authored)
		and bool(report.nutrient_tank_band_authority_clean)
		and bool(report.exact_counts),
		"band buffer, culling union, visual recipe and zero-authority boundary match the authored roster"
	)
	var detached := report.authored_nutrient_tank_band_transforms as Array
	detached[0] = Transform3D.IDENTITY
	_check(
		not ((module.get_render_allocation_report().authored_nutrient_tank_band_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"render report returns a detached nutrient-tank-band transform roster"
	)

	var baseline_errors := module.get_validation_errors()
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has(
			"Habitat nutrient-tank-band renderer buffer drifted from its authored transforms"
		),
		"RED: mutating one live band transform is rejected by the Habitat audit"
	)
	multi.buffer = original_buffer
	var original_bounds := multi.custom_aabb
	multi.custom_aabb = original_bounds.grow(0.25)
	_check(
		module.get_validation_errors().has(
			"Habitat nutrient-tank-band culling bounds drifted from its authored copies"
		),
		"RED: mutating the explicit band culling union is rejected by the Habitat audit"
	)
	multi.custom_aabb = original_bounds
	var original_rings := torus.rings
	torus.rings = original_rings + 1
	_check(
		module.get_validation_errors().has(
			"Habitat nutrient-tank-band TorusMesh recipe drifted"
		),
		"RED: mutating the live TorusMesh recipe is rejected by the Habitat audit"
	)
	torus.rings = original_rings
	var original_authored_tessellation: Vector2i = torus.get_meta(
		TorusGeometryBudget.AUTHORED_META
	)
	torus.set_meta(TorusGeometryBudget.AUTHORED_META, Vector2i(47, 16))
	_check(
		module.get_validation_errors().has(
			"Habitat nutrient-tank-band torus-budget metadata drifted"
		),
		"RED: mutating band authored-budget metadata is rejected"
	)
	torus.set_meta(
		TorusGeometryBudget.AUTHORED_META, original_authored_tessellation
	)
	batch.set_meta("evidence_status", &"source_supported")
	_check(
		module.get_validation_errors().has(
			"Habitat nutrient-tank-band batch acquired semantic authority"
		),
		"RED: attaching evidence authority to visual-only band stock is rejected"
	)
	batch.remove_meta("evidence_status")
	_check(
		module.get_validation_errors() == baseline_errors,
		"restoring band payload, recipe and metadata restores the pre-mutation Habitat audit"
	)


func _test_nutrient_valve_batch(module: HabitatSpine) -> void:
	var service := module.find_child("GardenService", true, false) as Node3D
	var batch := module.find_child("NutrientValves", true, false) as MultiMeshInstance3D
	_check(
		service != null and batch != null and batch.multimesh != null,
		"three garden nutrient-valve wheels resolve through one visual-only MultiMesh"
	)
	if service == null or batch == null or batch.multimesh == null:
		return
	var multi := batch.multimesh
	var torus := multi.mesh as TorusMesh
	var expected: Array[Transform3D] = []
	var valve_basis := Basis.from_euler(Vector3(0.0, deg_to_rad(90.0), 0.0))
	for valve_x in [12.30, 13.30, 14.30]:
		expected.append(
			Transform3D(valve_basis, Vector3(float(valve_x), 2.30, 25.34))
		)
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (authored[index] as Transform3D).is_equal_approx(
			expected[index]
		)
	_check(
		multi.instance_count == HabitatSpine.NUTRIENT_VALVE_COPY_COUNT
		and multi.visible_instance_count == -1
		and authored_exact
		and StringName(batch.get_meta("authored_source_name", &"")) == &"NutrientValve",
		"batch preserves all three valve transforms, yaw, ordering and source identity"
	)
	var red_reference := module.find_child("IsolationValve", true, false) as MeshInstance3D
	_check(
		torus != null
		and is_equal_approx(torus.inner_radius, HabitatSpine.NUTRIENT_VALVE_INNER_RADIUS)
		and is_equal_approx(torus.outer_radius, HabitatSpine.NUTRIENT_VALVE_OUTER_RADIUS)
		and torus.rings == HabitatSpine.NUTRIENT_VALVE_BUDGETED_RINGS
		and torus.ring_segments \
			== HabitatSpine.NUTRIENT_VALVE_BUDGETED_RING_SEGMENTS
		and torus.get_surface_count() == 1
		and torus.get_meta(TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO) \
			== Vector2i(
				HabitatSpine.NUTRIENT_VALVE_RINGS,
				HabitatSpine.NUTRIENT_VALVE_RING_SEGMENTS
			)
		and red_reference != null
		and batch.material_override == red_reference.material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1,
		"batch preserves the prior live 32x12 recipe, 48x16 authored metadata, red identity, shadows and render layer"
	)
	var old_valves := service.get_children().filter(
		func(candidate: Node) -> bool:
			if not candidate is MeshInstance3D:
				return false
			var old_torus := (candidate as MeshInstance3D).mesh as TorusMesh
			return (
				old_torus != null
				and is_equal_approx(old_torus.inner_radius, 0.13)
				and is_equal_approx(old_torus.outer_radius, 0.20)
				and is_equal_approx((candidate as Node3D).position.y, 2.30)
				and is_equal_approx((candidate as Node3D).position.z, 25.34)
			)
	)
	var manifold := service.find_child("NutrientManifold", false, false) as Node3D
	var main_pipe := service.find_child("NutrientMain", false, false) as Node3D
	var registered_isolation_valves := module.find_children("*", "Node3D", true, false).filter(
		func(candidate: Node) -> bool:
			return candidate.get_meta("service_class", &"") == &"isolation-valve"
	)
	_check(
		old_valves.is_empty()
		and manifold != null
		and main_pipe != null
		and registered_isolation_valves.size() == 6
		and batch.get_child_count() == 0
		and batch.get_script() == null
		and batch.get_groups().is_empty()
		and bool(batch.get_meta("visual_detail_only", false)),
		"only childless visual valve trim is batched while pipework and registered service valves remain"
	)

	var report := module.get_render_allocation_report()
	_check(
		int(report.nutrient_valve_legacy_mesh_instances) == 3
		and int(report.nutrient_valve_mesh_instances) == 0
		and int(report.nutrient_valve_legacy_multimesh_batches) == 0
		and int(report.nutrient_valve_multimesh_batches) == 1,
		"nutrient valves freeze renderer nodes at 3 -> 0 MeshInstances and 0 -> 1 MultiMesh batch"
	)
	_check(
		int(report.nutrient_valve_legacy_drawn_copies) == 3
		and int(report.nutrient_valve_drawn_copies) == 3
		and int(report.nutrient_valve_legacy_submissions) == 3
		and int(report.nutrient_valve_submissions) == 1,
		"nutrient valves preserve three drawn copies while submissions fall 3 -> 1"
	)
	_check(
		int(report.nutrient_valve_legacy_mesh_resources) == 3
		and int(report.nutrient_valve_mesh_resources) == 1
		and int(report.nutrient_valve_renderer_buffer_floats) == 36,
		"nutrient valves replace three private mesh resources with one exact 36-float renderer payload"
	)
	_check(
		bool(report.nutrient_valve_renderer_buffer_matches_authored)
		and bool(report.nutrient_valve_bounds_match_authored)
		and bool(report.nutrient_valve_recipe_matches_authored)
		and bool(report.nutrient_valve_budget_metadata_matches_authored)
		and report.nutrient_valve_authored_tessellation == Vector2i(48, 16)
		and report.nutrient_valve_live_tessellation == Vector2i(32, 12)
		and bool(report.nutrient_valve_material_matches_authored)
		and bool(report.nutrient_valve_renderer_state_matches_authored)
		and bool(report.nutrient_valve_authority_clean)
		and bool(report.exact_counts),
		"valve buffer, culling union, visual recipe and zero-authority boundary match the authored roster"
	)
	var detached := report.authored_nutrient_valve_transforms as Array
	detached[0] = Transform3D.IDENTITY
	_check(
		not ((module.get_render_allocation_report().authored_nutrient_valve_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"render report returns a detached nutrient-valve transform roster"
	)

	var baseline_errors := module.get_validation_errors()
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		module.get_validation_errors().has(
			"Habitat nutrient-valve renderer buffer drifted from its authored transforms"
		),
		"RED: mutating one live valve transform is rejected by the Habitat audit"
	)
	multi.buffer = original_buffer
	var original_bounds := multi.custom_aabb
	multi.custom_aabb = original_bounds.grow(0.25)
	_check(
		module.get_validation_errors().has(
			"Habitat nutrient-valve culling bounds drifted from its authored copies"
		),
		"RED: mutating the explicit valve culling union is rejected by the Habitat audit"
	)
	multi.custom_aabb = original_bounds
	var original_segments := torus.ring_segments
	torus.ring_segments = original_segments + 1
	_check(
		module.get_validation_errors().has(
			"Habitat nutrient-valve TorusMesh recipe drifted"
		),
		"RED: mutating the live valve TorusMesh recipe is rejected by the Habitat audit"
	)
	torus.ring_segments = original_segments
	var original_authored_tessellation: Vector2i = torus.get_meta(
		TorusGeometryBudget.AUTHORED_META
	)
	torus.set_meta(TorusGeometryBudget.AUTHORED_META, Vector2i(48, 15))
	_check(
		module.get_validation_errors().has(
			"Habitat nutrient-valve torus-budget metadata drifted"
		),
		"RED: mutating valve authored-budget metadata is rejected"
	)
	torus.set_meta(
		TorusGeometryBudget.AUTHORED_META, original_authored_tessellation
	)
	batch.set_meta("station_service_detail", true)
	_check(
		module.get_validation_errors().has(
			"Habitat nutrient-valve batch acquired semantic authority"
		),
		"RED: attaching service authority to visual-only valve trim is rejected"
	)
	batch.remove_meta("station_service_detail")
	_check(
		module.get_validation_errors() == baseline_errors,
		"restoring valve payload, recipe and metadata restores the pre-mutation Habitat audit"
	)


func _test_pipe_collar_mesh_sharing(module: HabitatSpine) -> void:
	var report := module.get_render_allocation_report()
	var sharing := report.pipe_collar_mesh_sharing as Dictionary
	_check(
		bool(sharing.valid)
			and sharing.legacy == {
				"geometry_nodes": 6,
				"geometry_submissions": 6,
				"visible_geometry_copies": 6,
				"primitive_mesh_allocations": 6,
			}
			and int(sharing.geometry_nodes) == 6
			and int(sharing.geometry_submissions) == 6
			and int(sharing.visible_geometry_copies) == 6
			and int(sharing.primitive_mesh_allocations) == 1
			and int(sharing.resource_allocation_reduction) == 5,
		"six service pipe collars retain their renderer copies while one exact TorusMesh replaces six private allocations"
	)
	var service := module.get_node(^"Structure/MaintenanceServiceLayer") as Node3D
	var collars: Array[MeshInstance3D] = []
	for child in service.get_children():
		var collar := child as MeshInstance3D
		if collar != null and StringName(collar.get_meta("service_class", &"")) == &"pipe-collar":
			collars.append(collar)
	if collars.size() != 6:
		return
	var shared_mesh := collars[0].mesh as TorusMesh
	var exact := shared_mesh != null
	for collar in collars:
		exact = exact \
			and collar.mesh == shared_mesh \
			and collar.material_override != null \
			and collar.rotation_degrees == Vector3(90, 0, 0) \
			and bool(collar.get_meta("station_service_detail", false)) \
			and StringName(collar.get_meta("service_class", &"")) == &"pipe-collar" \
			and collar.get_child_count() == 0
	_check(
		exact
			and is_equal_approx(shared_mesh.inner_radius, HabitatSpine.PIPE_COLLAR_INNER_RADIUS)
			and is_equal_approx(shared_mesh.outer_radius, HabitatSpine.PIPE_COLLAR_OUTER_RADIUS)
			and shared_mesh.rings == HabitatSpine.PIPE_COLLAR_BUDGETED_RINGS
			and shared_mesh.ring_segments == HabitatSpine.PIPE_COLLAR_BUDGETED_RING_SEGMENTS
			and shared_mesh.get_meta(
				TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
			) == Vector2i(
				HabitatSpine.PIPE_COLLAR_RINGS,
				HabitatSpine.PIPE_COLLAR_RING_SEGMENTS
			)
			and shared_mesh.get_meta_list().size() == 1
			and shared_mesh.get_meta_list().has(TorusGeometryBudget.AUTHORED_META)
			and shared_mesh.get_surface_count() == 1
			and shared_mesh.material == null
			and not shared_mesh.resource_local_to_scene
			and sharing.authored_tessellation == Vector2i(
				HabitatSpine.PIPE_COLLAR_RINGS,
				HabitatSpine.PIPE_COLLAR_RING_SEGMENTS
			)
			and sharing.live_tessellation == Vector2i(
				HabitatSpine.PIPE_COLLAR_BUDGETED_RINGS,
				HabitatSpine.PIPE_COLLAR_BUDGETED_RING_SEGMENTS
			),
		"shared collar resource preserves its authored 48x16 provenance and normalized 32x12 renderer recipe"
	)
	var final_collar := collars[-1]
	final_collar.mesh = shared_mesh.duplicate() as TorusMesh
	_check(
		not bool((module.get_render_allocation_report().pipe_collar_mesh_sharing as Dictionary).valid),
		"RED: a private service pipe-collar mesh fails the local allocation audit"
	)
	final_collar.mesh = shared_mesh
	_check(
		bool((module.get_render_allocation_report().pipe_collar_mesh_sharing as Dictionary).valid),
		"restoring the shared service pipe-collar mesh returns the allocation audit green"
	)
	var original_rings := shared_mesh.rings
	shared_mesh.rings = original_rings + 1
	_check(
		(module.get_render_allocation_report().pipe_collar_mesh_sharing as Dictionary).errors.has(
			"pipe collar primitive recipe drift"
		),
		"RED: mutating the normalized pipe-collar tessellation is rejected"
	)
	shared_mesh.rings = original_rings
	_check(
		bool((module.get_render_allocation_report().pipe_collar_mesh_sharing as Dictionary).valid),
		"restoring the normalized pipe-collar tessellation returns the allocation audit green"
	)
	var original_authored_tessellation: Vector2i = shared_mesh.get_meta(
		TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
	)
	shared_mesh.set_meta(
		TorusGeometryBudget.AUTHORED_META,
		original_authored_tessellation + Vector2i(1, 0)
	)
	_check(
		(module.get_render_allocation_report().pipe_collar_mesh_sharing as Dictionary).errors.has(
			"pipe collar torus-budget metadata drift"
		),
		"RED: mutating pipe-collar authored-budget metadata is rejected"
	)
	shared_mesh.set_meta(
		TorusGeometryBudget.AUTHORED_META, original_authored_tessellation
	)
	_check(
		bool((module.get_render_allocation_report().pipe_collar_mesh_sharing as Dictionary).valid),
		"restoring pipe-collar provenance metadata returns the allocation audit green"
	)


func _test_garden_bench_leg_batching(module: HabitatSpine) -> void:
	var report := module.get_render_allocation_report()
	var batching := report.garden_bench_leg_batching as Dictionary
	_check(
		bool(batching.valid)
		and batching.before == {
			"family_nodes": 6,
			"renderer_nodes": 6,
			"geometry_submissions": 6,
			"mesh_resources": 2,
			"material_resources": 1,
			"drawn_copies": 6,
		}
		and batching.current == {
			"family_nodes": 2,
			"renderer_nodes": 2,
			"geometry_submissions": 2,
			"mesh_resources": 2,
			"material_resources": 1,
			"drawn_copies": 6,
		},
		"garden bench legs freeze nodes/renderers/submissions 6->2, resources 2->2 and copies 6->6"
	)
	var shell := module.get_node_or_null(
		^"Structure/SideBranchGarden/GardenShell"
	) as Node3D
	var longitudinal := shell.get_node_or_null(
		^"GardenBenchLegsLongitudinal"
	) as MultiMeshInstance3D if shell != null else null
	var transverse := shell.get_node_or_null(
		^"GardenBenchLegsTransverse"
	) as MultiMeshInstance3D if shell != null else null
	var benches_exact := shell != null
	for bench_index in 3:
		benches_exact = benches_exact and shell.get_node_or_null(NodePath(
			"GardenBench%02d" % (bench_index + 1)
		)) is StaticBody3D
	_check(
		benches_exact
		and longitudinal != null and longitudinal.multimesh.instance_count == 4
		and transverse != null and transverse.multimesh.instance_count == 2
		and (batching.authored_transforms as Array).size() == 6
		and int(batching.collision_nodes) == 0
		and int(batching.interaction_nodes) == 0,
		"all three physical named benches remain while six exact leg poses move into authority-free batches"
	)
	if longitudinal != null:
		var transforms := longitudinal.get_meta("authored_instance_transforms", []) as Array
		var drifted := transforms.duplicate()
		drifted[0] = (drifted[0] as Transform3D).translated_local(Vector3(0.05, 0, 0))
		longitudinal.set_meta("authored_instance_transforms", drifted)
		var red := module.get_render_allocation_report()
		longitudinal.set_meta("authored_instance_transforms", transforms)
		_check(
			not bool((red.garden_bench_leg_batching as Dictionary).valid)
			and not bool(red.exact_counts)
			and bool(module.get_render_allocation_report().exact_counts),
			"moving one authored leg transform turns the allocation census red and restores cleanly"
		)


func _test_garden_column_collar_mesh_sharing(module: HabitatSpine) -> void:
	var report := module.get_render_allocation_report()
	var sharing := report.garden_column_collar_mesh_sharing as Dictionary
	_check(
		bool(sharing.valid)
		and (sharing.errors as PackedStringArray).is_empty()
		and sharing.legacy == {
			"geometry_nodes": 3,
			"geometry_submissions": 3,
			"visible_geometry_copies": 3,
			"primitive_mesh_allocations": 3,
		}
		and int(sharing.geometry_nodes) == 3
		and int(sharing.geometry_submissions) == 3
		and int(sharing.visible_geometry_copies) == 3
		and int(sharing.primitive_mesh_allocations) == 1
		and int(sharing.resource_allocation_reduction) == 2,
		"garden-column collars retain 3 nodes/submissions/copies while immutable TorusMesh allocations fall 3 -> 1"
	)
	var paths := sharing.node_paths as PackedStringArray
	_check(
		paths.size() == 3
		and paths[0] == "ColumnCollar"
		and paths[1].begins_with("@MeshInstance3D@")
		and paths[2].begins_with("@MeshInstance3D@")
		and module.has_node(
			^"Structure/SideBranchGarden/GardenColumn/ColumnCollar"
		),
		"the stable presentation path and both ordinary generated collar siblings remain present"
	)
	if paths.size() != 3:
		return
	var column := module.get_node(
		^"Structure/SideBranchGarden/GardenColumn"
	) as Node3D
	var collars: Array[MeshInstance3D] = []
	for path in paths:
		collars.append(column.get_node(NodePath(path)) as MeshInstance3D)
	var expected_transforms := [
		Transform3D(Basis.IDENTITY, Vector3(14.4, 1.20, 20.2)),
		Transform3D(Basis.IDENTITY, Vector3(14.4, 2.90, 20.2)),
		Transform3D(Basis.IDENTITY, Vector3(14.4, 4.50, 20.2)),
	]
	var shared_mesh := collars[0].mesh as TorusMesh
	var copies_exact := shared_mesh != null
	for index in collars.size():
		var collar := collars[index]
		copies_exact = copies_exact \
			and collar != null \
			and collar.mesh == shared_mesh \
			and collar.transform.is_equal_approx(expected_transforms[index]) \
			and collar.material_override == collars[0].material_override \
			and collar.material_overlay == null \
			and collar.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			and collar.layers == 1 \
			and collar.visible \
			and collar.get_child_count() == 0 \
			and collar.get_script() == null \
			and collar.get_groups().is_empty() \
			and collar.get_meta_list().is_empty()
	_check(
		copies_exact,
		"all three ordinary collars retain exact transforms, copper identity, renderer state and zero authority"
	)
	_check(
		shared_mesh != null
		and is_equal_approx(
			shared_mesh.inner_radius,
			HabitatSpine.GARDEN_COLUMN_COLLAR_INNER_RADIUS
		)
		and is_equal_approx(
			shared_mesh.outer_radius,
			HabitatSpine.GARDEN_COLUMN_COLLAR_OUTER_RADIUS
		)
		and shared_mesh.rings == HabitatSpine.GARDEN_COLUMN_COLLAR_BUDGETED_RINGS
		and shared_mesh.ring_segments \
			== HabitatSpine.GARDEN_COLUMN_COLLAR_BUDGETED_RING_SEGMENTS
		and shared_mesh.get_meta(
			TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
		) == Vector2i(48, 16)
		and shared_mesh.get_meta_list().size() == 1
		and shared_mesh.get_meta_list().has(TorusGeometryBudget.AUTHORED_META)
		and shared_mesh.get_surface_count() == 1
		and shared_mesh.material == null
		and not shared_mesh.resource_local_to_scene
		and sharing.authored_tessellation == Vector2i(48, 16)
		and sharing.live_tessellation == Vector2i(40, 16),
		"shared collar resource retains the exact live 40x16 recipe and authored 48x16 budget metadata"
	)

	var detached_report := report.duplicate(true)
	(detached_report.garden_column_collar_mesh_sharing as Dictionary)[
		"primitive_mesh_allocations"
	] = -1
	var detached_transforms := (
		(detached_report.garden_column_collar_mesh_sharing as Dictionary)
			.authored_transforms as Array
	)
	detached_transforms[0] = Transform3D.IDENTITY
	var fresh_sharing := (
		module.get_render_allocation_report().garden_column_collar_mesh_sharing as Dictionary
	)
	_check(
		int(fresh_sharing.primitive_mesh_allocations) == 1
		and not ((fresh_sharing.authored_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"caller mutation cannot alter detached collar allocation or transform evidence"
	)

	var baseline_errors := module.get_validation_errors()
	var last_collar := collars[-1]
	last_collar.mesh = shared_mesh.duplicate() as TorusMesh
	_check(
		module.get_validation_errors().has(
			"garden-column collar shared-mesh identity drift"
		),
		"RED: one private collar mesh fails immutable shared-resource identity"
	)
	last_collar.mesh = shared_mesh
	var original_rings := shared_mesh.rings
	shared_mesh.rings = original_rings + 1
	_check(
		module.get_validation_errors().has(
			"garden-column collar TorusMesh recipe drift"
		),
		"RED: shared collar recipe mutation fails the live tessellation gate"
	)
	shared_mesh.rings = original_rings
	var authored_tessellation: Vector2i = shared_mesh.get_meta(
		TorusGeometryBudget.AUTHORED_META
	)
	shared_mesh.set_meta(
		TorusGeometryBudget.AUTHORED_META, Vector2i(47, 16)
	)
	_check(
		module.get_validation_errors().has(
			"garden-column collar torus-budget metadata drift"
		),
		"RED: shared collar authored-budget mutation fails its 48x16 metadata gate"
	)
	shared_mesh.set_meta(TorusGeometryBudget.AUTHORED_META, authored_tessellation)
	var copper_material := last_collar.material_override
	last_collar.material_override = null
	_check(
		module.get_validation_errors().has(
			"garden-column collar render-state drift: %s" % paths[-1]
		),
		"RED: collar material-identity mutation fails the renderer-state gate"
	)
	last_collar.material_override = copper_material
	last_collar.layers = 2
	_check(
		module.get_validation_errors().has(
			"garden-column collar render-state drift: %s" % paths[-1]
		),
		"RED: collar renderer-layer mutation fails the renderer-state gate"
	)
	last_collar.layers = 1
	last_collar.set_meta("station_service_detail", true)
	_check(
		module.get_validation_errors().has(
			"garden-column collar gained semantic authority: %s" % paths[-1]
		),
		"RED: service metadata on visual collar stock fails the zero-authority gate"
	)
	last_collar.remove_meta("station_service_detail")
	_check(
		module.get_validation_errors() == baseline_errors,
		"restoring collar identity, recipe, budget, renderer and authority state restores the Habitat audit"
	)


func _test_garden_branch(module: HabitatSpine) -> void:
	var door := module.get_deferred_branch_access()
	_check(door != null, "garden branch exposes a reusable StationDoor")
	if door == null:
		return
	# Every assertion here used to require the opposite, and the reason it was
	# right then is the reason it is right now: the door's state has to agree with
	# what is behind it. It was locked and explicitly deferred while nothing was
	# there; there is a garden bay there now, so a locked door would be a published
	# route the player cannot walk. The evidence caveat did not weaken — it moved
	# from "no source proves an adjacent room, so none exists" to "no source
	# describes anything here, and what is here is invented and labelled as such",
	# which is the same claim about the sources and a different claim about the
	# content.
	_check(not door.locked and not door.deferred_access, "the opened branch is neither locked nor deferred")
	_check(door.can_interact(module), "the opened branch is a usable route rather than a landmark")
	_check("GARDEN BAY ACCESS" in door.get_interaction_prompt(), "branch prompt names the room it opens onto")
	_check("No source describes" in str(door.get_meta("content_note")), "door metadata records the room behind it as invented")
	_check(module.has_room(&"garden-cupola"), "the opened branch publishes a real registered room")
	var branch_ray := await _ray_through_door(door)
	_check(not branch_ray.is_empty(), "initially closed garden door blocks a real physics ray")
	_check(not module.has_room(&"habitat-side-branch"), "obsolete side-branch placeholder never appears in room registry")
	_check(
		module.contains_room(&"garden-cupola", module.get_route_marker(&"deferred-branch").global_position),
		"garden marker sits beyond the pressure door inside its published room"
	)
	_check(door.interact(module), "garden StationDoor accepts an open interaction")
	var garden_access_opened := await _wait_for_door_state(door, StationDoor.DoorState.OPEN, 1.5)
	_check(garden_access_opened and not door.is_portal_blocked(), "garden StationDoor reaches a fully clear open state")
	var open_branch_ray := await _ray_through_door(door)
	_check(open_branch_ray.is_empty(), "open garden StationDoor exposes a clear physical threshold")


func _test_negative_space(module: HabitatSpine) -> void:
	var samples := module.get_negative_space_samples()
	_check(samples.size() == 4, "module publishes integration-critical negative-space samples")
	var every_sample_empty := true
	for sample in samples:
		var hit := await _ray_local(module, sample + Vector3.UP * 7.0, sample - Vector3.UP * 4.0)
		if not hit.is_empty():
			every_sample_empty = false
	_check(every_sample_empty, "connector shoulders and corridor-side footprint remain genuine station void")
	var corridor_roof := await _ray_local(module, Vector3(0, 1.0, 10.0), Vector3(0, 8.0, 10.0))
	_check(not corridor_roof.is_empty(), "pressurized corridor has a physical ceiling distinct from exterior void")
	var common_roof := await _ray_local(module, Vector3(0, 1.0, 24.0), Vector3(0, 8.0, 24.0))
	_check(not common_roof.is_empty(), "observation/common area has a physical pressure ceiling")


func _test_collision_contract(module: HabitatSpine) -> void:
	var bodies := module.find_children("*", "StaticBody3D", true, false)
	_check(bodies.size() >= 70, "module contains substantial collision-backed architecture, glazing, and furniture")
	var every_body_canonical := true
	var every_body_shaped := true
	for candidate in bodies:
		var body := candidate as StaticBody3D
		var layer_is_valid := body.collision_layer == WORLD_LAYER
		if body.name == "PortalBlocker":
			layer_is_valid = body.collision_layer == WORLD_LAYER or body.collision_layer == 0
		every_body_canonical = every_body_canonical and layer_is_valid and body.collision_mask == 0
		if body.find_children("*", "CollisionShape3D", true, false).is_empty():
			every_body_shaped = false
	_check(every_body_canonical, "every static collider follows canonical World layer/mask contract")
	_check(every_body_shaped, "every StaticBody owns at least one real collision shape")
	_check(module.get_main_access().collision_layer == PhysicsLayers.INTERACTABLE, "main StationDoor remains discoverable on Interactable layer")
	_check(module.get_deferred_branch_access().collision_layer == PhysicsLayers.INTERACTABLE, "garden StationDoor remains discoverable on Interactable layer")


func _test_lifecycle(module: HabitatSpine) -> void:
	var live_snapshot := _lifecycle_snapshot(module)
	var floor := module.get_node_or_null(
		^"Structure/PressurizedHabitatCorridor/HabitatFloor"
	) as StaticBody3D
	_test_root.remove_child(module)
	module.set_module_enabled(false)
	_check(
		_lifecycle_snapshot(module) == live_snapshot,
		"detached direct disable leaves retained enabled, visibility, and collision state unchanged"
	)
	_test_root.add_child(module)
	await process_frame
	module.set_module_enabled(false)
	_check(
		not module.is_module_enabled()
		and not module.visible
		and floor != null and floor.collision_layer == 0,
		"re-added Habitat accepts a fresh live disable of its root and representative floor"
	)
	module.set_module_enabled(true)
	_check(
		module.is_module_enabled()
		and module.visible
		and floor != null and floor.collision_layer == WORLD_LAYER,
		"fresh live re-enable restores the root and representative floor"
	)
	var reentered_snapshot := _lifecycle_snapshot(module)
	module.queue_free()
	module.set_module_enabled(false)
	_check(
		_lifecycle_snapshot(module) == reentered_snapshot,
		"queued direct disable leaves retained enabled, visibility, and collision state unchanged"
	)


func _lifecycle_snapshot(module: HabitatSpine) -> Dictionary:
	var body_states: Array[Dictionary] = []
	for raw_body in StationModuleContract.collect_static_bodies(module):
		var body := raw_body as StaticBody3D
		body_states.append({
			"path": module.get_path_to(body),
			"visible": body.visible,
			"collision_layer": body.collision_layer,
			"collision_mask": body.collision_mask,
		})
	body_states.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first.path) < str(second.path)
	)
	return {
		"enabled": module.is_module_enabled(),
		"visible": module.visible,
		"body_states": body_states,
	}.duplicate(true)


func _test_cleanup(module: HabitatSpine) -> void:
	var module_reference: WeakRef = weakref(module)
	var main_access_reference: WeakRef = weakref(module.get_main_access())
	var deferred_reference: WeakRef = weakref(module.get_deferred_branch_access())
	var bunk_reference: WeakRef = weakref(module.find_child("BunkAlcove01", true, false))
	module.queue_free()
	module = null
	await process_frame
	await physics_frame
	await process_frame
	_check(module_reference.get_ref() == null, "module root cleans up without a retained instance")
	_check(main_access_reference.get_ref() == null and deferred_reference.get_ref() == null, "both StationDoor children clean up with module")
	_check(bunk_reference.get_ref() == null, "procedural room contents clean up with module")
	_test_root.queue_free()
	await process_frame


func _ray_local(module: HabitatSpine, local_from: Vector3, local_to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(module.to_global(local_from), module.to_global(local_to), WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_ray(query)


func _ray_through_door(door: StationDoor) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(
		door.to_global(Vector3(0, 1.7, -1.65)),
		door.to_global(Vector3(0, 1.7, 1.65)),
		WORLD_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return door.get_world_3d().direct_space_state.intersect_ray(query)


func _intersect_shape_local(module: HabitatSpine, shape: Shape3D, local_transform: Transform3D, max_results: int) -> Array[Dictionary]:
	await physics_frame
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = module.global_transform * local_transform
	query.collision_mask = WORLD_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_shape(query, max_results)


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


func _capture_forward_plus(service_only: bool) -> void:
	root.size = Vector2i(1400, 900)
	var capture_root := Node3D.new()
	capture_root.name = "HabitatSpineForwardPlusCapture"
	root.add_child(capture_root)
	var module := MODULE_SCENE.instantiate() as HabitatSpine
	capture_root.add_child(module)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071016")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8da6aa")
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	capture_root.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52, -32, 0)
	key_light.light_color = Color("dbe9e7")
	key_light.light_energy = 1.15
	key_light.shadow_enabled = true
	capture_root.add_child(key_light)
	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(-18, 146, 0)
	rim_light.light_color = Color("5799ad")
	rim_light.light_energy = 0.6
	capture_root.add_child(rim_light)

	var camera := Camera3D.new()
	camera.fov = 54.0
	camera.near = 0.08
	camera.current = true
	camera.position = Vector3(22.0, 14.5, -20.0)
	capture_root.add_child(camera)
	if service_only:
		_test_cabinet_louvre_batch(module)
		camera.position = Vector3(1.9, 1.68, 16.6)
		camera.look_at(Vector3(-4.6, 1.5, 6.4), Vector3.UP)
		for _frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var service_image := root.get_texture().get_image()
		var service_error := service_image.save_png("/tmp/habitat-spine-cabinet-louvres.png")
		if service_error != OK:
			push_error("Failed to save habitat cabinet-louvre capture: %s" % service_error)
		print("HABITAT_SPINE_SERVICE_CAPTURE_OK")
		capture_root.queue_free()
		await process_frame
		quit(0 if service_error == OK and _failures.is_empty() else 1)
		return
	camera.look_at(Vector3(0, 2.1, 13.0), Vector3.UP)
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var overview := root.get_texture().get_image()
	var overview_error := overview.save_png("/tmp/habitat-spine-overview.png")
	if overview_error != OK:
		push_error("Failed to save habitat overview capture: %s" % overview_error)

	camera.position = Vector3(0, 2.5, 18.7)
	camera.look_at(Vector3(0, 1.65, 27.5), Vector3.UP)
	for _frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var interior := root.get_texture().get_image()
	var interior_error := interior.save_png("/tmp/habitat-spine-common.png")
	if interior_error != OK:
		push_error("Failed to save habitat common capture: %s" % interior_error)
	print("HABITAT_SPINE_CAPTURE_OK")
	capture_root.queue_free()
	await process_frame
	quit(0 if overview_error == OK and interior_error == OK else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("HABITAT_SPINE_TEST_OK")
		quit(0)
	else:
		print("HABITAT_SPINE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
