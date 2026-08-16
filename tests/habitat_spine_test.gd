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
	for rack_index in 6:
		var rack := module.get_node_or_null(
			NodePath("Structure/SideBranchGarden/GardenGrowRacks/GrowRack%02d" % (rack_index + 1))
		) as Node3D
		if rack == null:
			every_rack_faces_inward = false
			continue
		var outward := Vector3(rack.position.x - 14.4, 0.0, rack.position.z - 20.2).normalized()
		every_rack_faces_inward = every_rack_faces_inward and rack.basis.x.normalized().dot(outward) >= 0.999
	_check(every_rack_faces_inward, "all six rack label faces point inward toward the nutrient column")

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
	_check(
		module.find_children("*", "Node", true, false).size() == 1922
		and module.find_children("*", "MeshInstance3D", true, false).size() == 1275
		and module.find_children("*", "MultiMeshInstance3D", true, false).size() == 11,
		"cabinet batching re-freezes the Habitat census at 1922 nodes, 1275 meshes and 11 MultiMeshes"
	)
	var performance := module.get_performance_contract()
	_check(
		int(performance.static_bodies) == 250
		and int(performance.collision_shapes) == 263
		and bool(performance.within_budget),
		"visual-only batching preserves the exact 250-body/263-shape collision census and performance contract"
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
