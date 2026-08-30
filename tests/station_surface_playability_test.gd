extends SceneTree

## Production-capsule coverage for every authored station stair/ramp and the
## collision-backed floor roster used by reachable station routes. Movement
## probes use continuous real InputMap actions and never press jump.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD
const PRODUCTION_SHIP_ROOT_SHAPE_COUNTS := {
	&"ArrowReconShip": 2,
	&"BulwarkHeavyGunship": 3,
	&"cinder_cargo_hauler": 8,
	&"cinder_light_interceptor": 1,
	&"cinder_long_range_bomber": 1,
	&"HalyardCrewTransport": 21,
	&"JovianLightFreighter": 31,
	&"TorrentInterceptor": 7,
	&"ZenithInterceptor": 24,
}
const PRODUCTION_SHIP_ROOT_SHAPE_TOTAL := 98

const WORLD_SURFACE_PATHS := [
	"ExposedDockLattice/CentralJunction",
	"ExposedDockLattice/HeroBerthNode",
	"ExposedDockLattice/JunctionLink",
	"ExposedDockLattice/PortBranchArm",
	"ExposedDockLattice/PortBerthNode",
	"ExposedDockLattice/StarboardBranchArm",
	"ExposedDockLattice/StarboardBerthNode",
	"ExposedDockLattice/AftSpine",
	"ExposedDockLattice/AftModuleConnector",
	"ExposedDockLattice/FleetDockCombConnector/FleetDockCombConnectorDeck",
	"ExposedDockLattice/FabricationAnnexConnector/ConnectorDeckA",
	"ExposedDockLattice/FabricationAnnexConnector/ConnectorDeckB",
	"ExposedDockLattice/FabricationAnnexConnector/ConnectorDeckC",
	"ExposedDockLattice/ObservationLogisticsConnector/ConnectorDeck",
	"ExposedDockLattice/SalvageTerraceConnector/ConnectorDeck",
	# HALYARD-DECK-001. Fleet Dock 02's berth apron. The comb's 12 x 12 m tooth is
	# the middle of this pad, not the whole of it: the 28.35 m Halyard needs deck
	# fore and aft of it, and a player needs a loop round the craft.
	"ExposedDockLattice/HalyardBerthApron/HalyardApronNose",
	"ExposedDockLattice/HalyardBerthApron/HalyardApronTailPort",
	"ExposedDockLattice/HalyardBerthApron/HalyardApronTailStarboard",
	"OpenLaunchSpine/LaunchArmDeck",
	"UpperOperations/ObservationLanding",
	"UpperOperations/OperationsPodFloor",
	"ModernFleetRegistry/RegistryPodDeck",
]

const AFT_SURFACE_PATHS := [
	"Structure/LowerOpenDeck/ConnectionDeck",
	"Structure/LowerOpenDeck/JunctionDeck",
	"Structure/LowerOpenDeck/JunctionDeckWestApron",
	"Structure/LowerOpenDeck/StairBaseLanding",
	"Structure/Circulation/ContinuousStairRamp",
	"Structure/UpperOpenDeck/UpperFloor",
	"Structure/OperationsRoom/OperationsFloor",
]

const HABITAT_SURFACE_PATHS := [
	"Structure/PlayerClearConnector/ConnectorFloor",
	"Structure/PressurizedHabitatCorridor/EntryVestibuleFloor",
	"Structure/PressurizedHabitatCorridor/HabitatFloor",
	"Structure/ObservationCommon/CommonFloor",
	"Structure/SideBranchGarden/BranchLink/LinkFloor",
	"Structure/SideBranchGarden/GardenShell/GardenFloor",
]

const FREIGHT_SURFACE_PATHS := [
	"ConnectionLattice/ConnectionDeckA",
	"ConnectionLattice/ConnectionDeckB",
	"ConnectionLattice/ConnectionDeckC",
	"LoadingApron/ApronDeck01",
	"LoadingApron/ApronDeck02",
	"LoadingApron/ApronDeck03",
	"LoadingApron/ApronDeck04",
	"LoadingApron/CargoRackShelf",
	"LoadingApron/ServiceRoomShelf",
	"FreightControlRoom/RoomFloor",
]

const COMB_SURFACE_PATHS := [
	"GeneratedComb/WalkableSurfaces/Trunk",
	"GeneratedComb/WalkableSurfaces/Rung01",
	"GeneratedComb/WalkableSurfaces/DockSlab01",
	"GeneratedComb/WalkableSurfaces/Rung02",
	"GeneratedComb/WalkableSurfaces/DockSlab02",
	"GeneratedComb/WalkableSurfaces/Rung03Vertical",
	"GeneratedComb/WalkableSurfaces/DockSlab03Upper",
]

const FABRICATION_SURFACE_PATHS := [
	"GeneratedAnnex/ConnectorApron",
	"GeneratedAnnex/CentralThroughAisle",
	"GeneratedAnnex/PortWorkBay",
	"GeneratedAnnex/StarboardWorkBay",
	"GeneratedAnnex/PortSideBypass",
	"GeneratedAnnex/StarboardSideBypass",
	"GeneratedAnnex/RearCrossAisle",
]

const OBSERVATION_LOGISTICS_SURFACE_PATHS := [
	"Structure/Walkable/ExposedConnectorDeck",
	"Structure/Walkable/PadCrossLanding",
	"Structure/Walkable/ObservationPad",
	"Structure/Walkable/LogisticsPad",
	"Structure/Walkable/FarReturnBridge",
]

const SALVAGE_TERRACE_SURFACE_PATHS := [
	"GeneratedRoot/ConnectionApron",
	"GeneratedRoot/LowerSalvagePad",
	"GeneratedRoot/MainServiceRamp",
	"GeneratedRoot/UpperInspectionPad",
	"GeneratedRoot/InspectionRamp",
	"GeneratedRoot/TopInspectionPad",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for station surface playability")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	for _settle in 6:
		await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var player := game.get_node_or_null(^"Player") as PlayerController
	_check(world != null and player != null, "production world and player capsule are live")
	if world == null or player == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	_test_collision_backed_surface_roster(world)
	_test_fabrication_annex_siting(world)
	_test_observation_logistics_siting(world, game.get_flyable_ships())
	await _test_salvage_terrace_siting(world, game.get_flyable_ships())
	_test_shared_bevel_rules(world)
	_test_station_panel_material_bindings(world)
	await _test_discovered_walkable_surface_support(world)
	_test_fleet_expansion_surface_honesty(world)
	_test_no_station_collision_without_visible_geometry(world)
	_test_lattice_decks_do_not_share_the_authored_runway_volume(world)
	await _test_spawn_adjacent_stair(world, player)
	await _test_aft_stair_mount_and_climb(world, player)
	await _test_fleet_comb_ramp(world, player)
	if OS.get_cmdline_user_args().has("--capture-fabrication-integration"):
		await _capture_fabrication_integration_frame(game, world)
	if OS.get_cmdline_user_args().has("--capture-observation-integration"):
		await _capture_observation_integration_frame(game, world)
	if OS.get_cmdline_user_args().has("--capture-salvage-integration"):
		await _capture_salvage_integration_frame(game, world)

	_release_actions()
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	_finish()


func _test_collision_backed_surface_roster(world: ShipyardWorld) -> void:
	var aft := world.get_node_or_null(^"AftJunctionStack") as AftJunctionStack
	var habitat := world.get_node_or_null(^"HabitatSpine") as HabitatSpine
	var freight := world.get_node_or_null(^"JovianFreightBerth") as JovianFreightBerth
	var comb := world.get_node_or_null(^"FleetDockComb") as FleetDockComb
	var fabrication := world.get_node_or_null(^"FabricationAnnex") as FabricationAnnex
	var observation := world.get_node_or_null(^"ObservationLogisticsSpur") as ObservationLogisticsSpur
	var salvage := world.get_node_or_null(^"SalvageTerrace") as SalvageTerrace
	_check(aft != null and habitat != null and freight != null and comb != null and fabrication != null and observation != null and salvage != null, "all reachable station modules resolve for surface coverage")

	var every_surface_exact := _surface_roster_matches(world, WORLD_SURFACE_PATHS)
	if aft != null:
		every_surface_exact = _surface_roster_matches(aft, AFT_SURFACE_PATHS) and every_surface_exact
	if habitat != null:
		every_surface_exact = _surface_roster_matches(habitat, HABITAT_SURFACE_PATHS) and every_surface_exact
	if freight != null:
		every_surface_exact = _surface_roster_matches(freight, FREIGHT_SURFACE_PATHS) and every_surface_exact
	if comb != null:
		every_surface_exact = _surface_roster_matches(comb, COMB_SURFACE_PATHS) and every_surface_exact
	if fabrication != null:
		every_surface_exact = _surface_roster_matches(fabrication, FABRICATION_SURFACE_PATHS) and every_surface_exact
	if observation != null:
		every_surface_exact = _surface_roster_matches(observation, OBSERVATION_LOGISTICS_SURFACE_PATHS) and every_surface_exact
	if salvage != null:
		every_surface_exact = _surface_roster_matches(salvage, SALVAGE_TERRACE_SURFACE_PATHS) and every_surface_exact
	_check(every_surface_exact, "all 71 visible route floors, decks, shelves, slabs, rungs, and ramps own matching World collision")


func _surface_roster_matches(owner: Node3D, paths: Array) -> bool:
	var valid := true
	for raw_path in paths:
		var path := NodePath(raw_path)
		var body := owner.get_node_or_null(path) as StaticBody3D
		if body == null or body.collision_layer != WORLD_LAYER or body.collision_mask != 0:
			print("SURFACE_ROSTER_INVALID_BODY: ", owner.name, "/", raw_path, " -> ", body)
			valid = false
			continue
		var mesh_instance := body.get_node_or_null(^"Mesh") as MeshInstance3D
		if mesh_instance == null:
			mesh_instance = body.get_node_or_null(^"RampMesh") as MeshInstance3D
		if mesh_instance == null:
			for candidate in body.find_children("*", "MeshInstance3D", false, false):
				mesh_instance = candidate as MeshInstance3D
				break
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		if collision == null:
			collision = body.get_node_or_null(^"RampCollision") as CollisionShape3D
		if collision == null:
			for candidate in body.find_children("*", "CollisionShape3D", false, false):
				collision = candidate as CollisionShape3D
				break
		if mesh_instance == null or mesh_instance.mesh == null:
			if _has_exact_batched_surface_visual(owner, body):
				continue
			print("SURFACE_ROSTER_INVALID_CHILDREN: ", owner.name, "/", raw_path)
			valid = false
			continue
		if collision == null or collision.shape == null or collision.disabled:
			print("SURFACE_ROSTER_INVALID_CHILDREN: ", owner.name, "/", raw_path)
			valid = false
			continue
		var box := collision.shape as BoxShape3D
		var rendered_size := mesh_instance.mesh.get_aabb().size * mesh_instance.scale.abs()
		if box != null and rendered_size.distance_to(box.size) > 0.035:
			print("SURFACE_ROSTER_SIZE_DRIFT: ", owner.name, "/", raw_path, " mesh=", rendered_size, " collision=", box.size)
			valid = false
	return valid


func _has_exact_batched_surface_visual(owner: Node3D, body: StaticBody3D) -> bool:
	if owner is ObservationLogisticsSpur:
		var anchor := body.get_node_or_null(^"Mesh") as Marker3D
		var batch := owner.get_node_or_null(
			^"Structure/Walkable/WalkableDeckRenderBatch"
		) as MultiMeshInstance3D
		var collision := body.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		var transforms := batch.get_meta("authored_instance_transforms", []) as Array if batch != null else []
		var expected := Transform3D(
			Basis.from_scale(shape.size), body.position
		) if shape != null else Transform3D.IDENTITY
		return anchor != null \
			and bool(anchor.get_meta("visual_detail_only", false)) \
			and bool(anchor.get_meta("batched_visual_anchor", false)) \
			and batch != null and batch.multimesh != null \
			and transforms.has(expected)
	if owner is FabricationAnnex:
		var surface_id := StringName(body.get_meta(&"walkable_surface_id", &""))
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		if shape == null:
			return false
		var floor_batch := owner.get_node_or_null(^"GeneratedAnnex/FloorSlabRenderBatch") as MeshInstance3D
		for part_variant in floor_batch.get_meta(&"fabrication_floor_render_parts", []) as Array if floor_batch != null else []:
			var part := part_variant as Dictionary
			if StringName(part.get("id", &"")) == surface_id \
					and (part.get("size", Vector3.ZERO) as Vector3).is_equal_approx(shape.size) \
					and (part.get("transform", Transform3D.IDENTITY) as Transform3D).origin.is_equal_approx(body.position):
				return true
		for raw_batch in owner.find_children("*", "MultiMeshInstance3D", true, false):
			var batch := raw_batch as MultiMeshInstance3D
			if not batch.has_meta(&"fabrication_annex_batch_key") \
					or batch.multimesh == null or batch.multimesh.mesh == null \
					or not batch.multimesh.mesh.get_aabb().size.is_equal_approx(shape.size):
				continue
			for transform_variant in _authored_batch_transforms(batch):
				var transform := transform_variant as Transform3D
				if transform.origin.is_equal_approx(body.position) \
						and transform.basis.is_equal_approx(Basis.IDENTITY):
					return true
	return false


func _test_fabrication_annex_siting(world: ShipyardWorld) -> void:
	var annex := world.get_node_or_null(^"FabricationAnnex") as FabricationAnnex
	var connector := world.get_node_or_null(^"ExposedDockLattice/FabricationAnnexConnector") as Node3D
	_check(annex != null and connector != null, "production Fabrication Annex and its station-owned connector resolve")
	if annex == null or connector == null:
		return
	var expected_transform := Transform3D(
		Basis(Vector3.UP, PI * 0.5), Vector3(72.0, 0.38, 38.0)
	)
	_check(annex.global_transform.is_equal_approx(expected_transform), "Fabrication Annex keeps the reviewed (72, 0.38, 38), yaw +90 placement")

	var deck_specs := [
		["ConnectorDeckA", Vector3(59.5, 0.18, 28.0), Vector3(21.0, 0.4, 3.0), &"fabrication_connector_a", 63.0],
		["ConnectorDeckB", Vector3(68.5, 0.18, 34.5), Vector3(3.0, 0.4, 10.0), &"fabrication_connector_b", 30.0],
		["ConnectorDeckC", Vector3(71.0, 0.18, 38.0), Vector3(2.0, 0.4, 3.0), &"fabrication_connector_c", 6.0],
	]
	var decks_exact := true
	var connector_area := 0.0
	var connector_boxes: Array[AABB] = []
	for spec in deck_specs:
		var body := connector.get_node_or_null(NodePath(spec[0] as String)) as StaticBody3D
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D if body != null else null
		var shape := collision.shape as BoxShape3D if collision != null else null
		decks_exact = (
			decks_exact
			and body != null
			and body.position.is_equal_approx(spec[1] as Vector3)
			and shape != null
			and shape.size.is_equal_approx(spec[2] as Vector3)
			and bool(body.get_meta(&"walkable_surface", false))
			and StringName(body.get_meta(&"walkable_surface_id", &"")) == StringName(spec[3])
			and StringName(body.get_meta(&"walkable_surface_kind", &"")) == &"level"
			and StringName(body.get_meta(&"walkable_surface_owner", &"")) == &"station_hub"
			and is_equal_approx(float(body.get_meta(&"horizontal_area_m2", -1.0)), float(spec[4]))
		)
		connector_area += float(spec[4])
		if body != null:
			connector_boxes.append(_collision_body_box(body))
	_check(decks_exact and is_equal_approx(connector_area, 99.0), "connector A/B/C are the exact tagged 63 + 30 + 6 = 99.0 m2 dogleg surfaces")

	var rail_specs := [
		["ConnectorRailASouth", Vector3(59.5, 1.10, 26.5), Vector3(21.0, 1.44, 0.14)],
		["ConnectorRailANorth", Vector3(58.0, 1.10, 29.5), Vector3(18.0, 1.44, 0.14)],
		["ConnectorRailBWest", Vector3(67.0, 1.10, 34.5), Vector3(0.14, 1.44, 10.0)],
		["ConnectorRailBEast", Vector3(70.0, 1.10, 33.0), Vector3(0.14, 1.44, 7.0)],
		["ConnectorRailBNorth", Vector3(68.5, 1.10, 39.5), Vector3(3.0, 1.44, 0.14)],
		["ConnectorRailCSouth", Vector3(71.0, 1.10, 36.5), Vector3(2.0, 1.44, 0.14)],
		["ConnectorRailCNorth", Vector3(71.0, 1.10, 39.5), Vector3(2.0, 1.44, 0.14)],
	]
	var rails_exact := true
	for spec in rail_specs:
		var body := connector.get_node_or_null(NodePath(spec[0] as String)) as StaticBody3D
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D if body != null else null
		var shape := collision.shape as BoxShape3D if collision != null else null
		rails_exact = rails_exact and body != null and body.position.is_equal_approx(spec[1] as Vector3) \
			and shape != null and shape.size.is_equal_approx(spec[2] as Vector3) \
			and not bool(body.get_meta(&"walkable_surface", false))
	_check(rails_exact, "all seven reviewed connector rail runs protect the outer edges while leaving both mouths open")

	# Compare every physical Annex/connector box to every unrelated station body.
	# Boundary-touch at Operations x=49 is allowed; positive three-axis volume is not.
	var owned_bodies: Array[StaticBody3D] = []
	for candidate in connector.find_children("*", "StaticBody3D", true, false):
		owned_bodies.append(candidate as StaticBody3D)
	for candidate in annex.find_children("*", "StaticBody3D", true, false):
		owned_bodies.append(candidate as StaticBody3D)
	var intrusions := PackedStringArray()
	for raw_other in world.find_children("*", "StaticBody3D", true, false):
		var other := raw_other as StaticBody3D
		var observation_connector := world.get_node_or_null(^"ExposedDockLattice/ObservationLogisticsConnector") as Node3D
		if connector.is_ancestor_of(other) or annex.is_ancestor_of(other) \
				or (observation_connector != null and observation_connector.is_ancestor_of(other)):
			continue
		var other_box := _collision_body_box(other)
		if not other_box.has_volume():
			continue
		for owned in owned_bodies:
			var overlap := _aabb_overlap_depth(_collision_body_box(owned), other_box)
			if overlap.x > 0.002 and overlap.y > 0.002 and overlap.z > 0.002:
				intrusions.append("%s <> %s depth=%s" % [owned.get_path(), other.get_path(), overlap])
	intrusions.sort()
	print("FABRICATION_GEOMETRY_INTRUSIONS: ", intrusions)
	_check(intrusions.is_empty(), "Annex and connector collision have no positive-volume intersection with unrelated station geometry")

	var connector_a := connector.get_node(^"ConnectorDeckA") as StaticBody3D
	var nearest_habitat_gap := INF
	var nearest_habitat_path := ""
	var connector_a_box := _collision_body_box(connector_a)
	var habitat := world.get_node(^"HabitatSpine") as Node3D
	for candidate in habitat.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		var mesh_box := (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs()
		var gap := _horizontal_aabb_separation(connector_a_box, mesh_box)
		if gap < nearest_habitat_gap:
			nearest_habitat_gap = gap
			nearest_habitat_path = str(mesh_instance.get_path())
	print("FABRICATION_HABITAT_APERTURE_GAP: %.3f nearest=%s" % [nearest_habitat_gap, nearest_habitat_path])
	_check(
		is_equal_approx(nearest_habitat_gap, 3.28)
		and nearest_habitat_path.ends_with("HabitatSpine/Structure/ObservationCommon/SideWindowFrameA/Mesh"),
		"live Connector A geometry freezes the measured 3.280 m gap to Habitat SideWindowFrameA"
	)

	var local_footprint := annex.get_integration_footprint()
	var annex_bounds := (annex.global_transform * AABB(
		local_footprint.local_min as Vector3,
		(local_footprint.local_max as Vector3) - (local_footprint.local_min as Vector3)
	)).abs()
	var observation_root_standoff := 92.5 - annex_bounds.end.x
	_check(
		absf(annex_bounds.end.x - 92.2) <= 0.001
		and absf(observation_root_standoff - 0.3) <= 0.001,
		"Annex keeps its reviewed envelope and 0.3 m origin standoff at the integrated Observation seam"
	)
	var rear_gate := annex.get_rear_observation_gate_contract()
	var returned_segments := rear_gate.returned_segments as Array
	var returned_exact := bool(rear_gate.enabled) \
		and is_equal_approx(float(rear_gate.opening_width_m), 4.0) \
		and (rear_gate.opening_local_x as Vector2).is_equal_approx(Vector2(-2.0, 2.0)) \
		and is_equal_approx(float(rear_gate.rear_boundary_local_z), 20.0) \
		and returned_segments.size() == 2
	var expected_returned_segments := {
		&"north": {"local": Vector3(-8.0, 0.72, 20.0), "world": Vector3(92.0, 1.10, 46.0)},
		&"south": {"local": Vector3(8.0, 0.72, 20.0), "world": Vector3(92.0, 1.10, 30.0)},
	}
	for segment_variant in returned_segments:
		var segment := segment_variant as Dictionary
		var segment_id := StringName(segment.segment_id)
		var expected := expected_returned_segments.get(segment_id, {}) as Dictionary
		returned_exact = returned_exact \
			and not expected.is_empty() \
			and (segment.local_center as Vector3).is_equal_approx(expected.local as Vector3) \
			and (segment.world_center as Vector3).is_equal_approx(expected.world as Vector3) \
			and (segment.size as Vector3).is_equal_approx(Vector3(12.0, 1.44, 0.14))
	var full_rear_rail_survives := false
	for candidate in annex.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		var box_shape := _body_box_shape(body)
		if body.position.is_equal_approx(Vector3(0.0, 0.72, 20.0)) \
				and box_shape != null \
				and box_shape.size.is_equal_approx(Vector3(28.0, 1.44, 0.14)):
			full_rear_rail_survives = true
	print("FABRICATION_OBSERVATION_GATE: ", rear_gate)
	_check(returned_exact and not full_rear_rail_survives, "production Annex atomically replaces its full rear rail with the two exact returned 12 m segments around the 4 m Observation gate")
	var annex_audit := annex.get_audit_report()
	print("FABRICATION_INTEGRATED_PERFORMANCE: ", annex.get_performance_contract())
	_check(bool(annex_audit.valid), "Fabrication remains within its measured production budget after the atomic rear-gate split")
	var north_service := annex.get_route_marker(&"annex_port_service")
	var rear_cross := annex.get_route_marker(&"annex_rear_cross")
	_check(
		north_service != null
		and north_service.global_position.is_equal_approx(Vector3(84.0, 0.53, 52.0))
		and not north_service.has_meta(&"station_connection_slot")
		and rear_cross != null
		and rear_cross.global_position.is_equal_approx(Vector3(91.0, 0.53, 38.0))
		and not rear_cross.has_meta(&"station_connection_slot"),
		"north service gate remains the exact built Salvage handoff while rear-cross remains an internal-only Observation seam"
	)

	var smallest_berth_gap := INF
	for berth_id in world.get_berth_ids():
		var berth := world.get_berth_node(berth_id)
		var half := berth.get_landing_half_extents()
		var berth_box := (berth.get_dock_transform() * AABB(-half, half * 2.0)).abs()
		for owned in owned_bodies:
			smallest_berth_gap = minf(
				smallest_berth_gap,
				_aabb_separation(_collision_body_box(owned), berth_box)
			)
	print("FABRICATION_MINIMUM_BERTH_GAP: %.3f" % smallest_berth_gap)
	_check(smallest_berth_gap >= 0.15, "every Annex/connector collision body strictly clears every authoritative berth volume")

	var halyard := world.get_berth_node(&"halyard_fleet_dock_berth")
	var capture_half := halyard.get_assist_capture_half_extents()
	var capture_box := (halyard.get_assist_capture_transform() * AABB(-capture_half, capture_half * 2.0)).abs()
	var capture_overlap := _aabb_overlap_depth(capture_box, connector_a_box)
	_check(capture_overlap.x > 0.0 and capture_overlap.y > 0.0 and capture_overlap.z > 0.0, "audit records the bounded connector-A overlap with Halyard's nonphysical assist-capture volume")
	var hull_bounds := HalyardCrewTransport.FLIGHT_COLLISION_BOUNDS
	var staging_hull := (halyard.get_assist_staging_transform() * hull_bounds).abs()
	var docked_hull := (halyard.get_dock_transform() * hull_bounds).abs()
	var swept_hull := staging_hull.merge(docked_hull)
	var swept_clear := true
	for connector_box in connector_boxes:
		var overlap := _aabb_overlap_depth(swept_hull, connector_box)
		swept_clear = swept_clear and (overlap.x <= 0.0 or overlap.y <= 0.0 or overlap.z <= 0.0)
	_check(swept_clear, "the complete swept Halyard assist-path hull clears all three connector decks despite capture-volume overlap")

	var authority := annex.get_authority_contract()
	_check(
		int(authority.ship_berth_count) == 0
		and int(authority.landing_or_interaction_area_count) == 0
		and int(authority.activity_node_count) == 0,
		"production Annex preserves zero ship, berth, interaction, combat, and activity authority"
	)


func _test_observation_logistics_siting(world: ShipyardWorld, ships: Array[HeroShip]) -> void:
	var spur := world.get_node_or_null(^"ObservationLogisticsSpur") as ObservationLogisticsSpur
	var connector := world.get_node_or_null(^"ExposedDockLattice/ObservationLogisticsConnector") as Node3D
	var annex := world.get_node_or_null(^"FabricationAnnex") as FabricationAnnex
	_check(spur != null and connector != null and annex != null, "production Observation spur, connector, and opened Fabrication seam resolve")
	if spur == null or connector == null or annex == null:
		return
	var expected_transform := Transform3D(
		Basis(Vector3.UP, PI * 0.5), Vector3(92.5, 0.38, 38.0)
	)
	_check(spur.global_transform.is_equal_approx(expected_transform), "Observation spur keeps the reviewed (92.5, 0.38, 38), yaw +90 placement")
	var local_footprint := spur.get_integration_footprint()
	var footprint := (spur.global_transform * AABB(
		local_footprint.local_min as Vector3,
		(local_footprint.local_max as Vector3) - (local_footprint.local_min as Vector3)
	)).abs()
	_check(
		footprint.position.is_equal_approx(Vector3(92.5, 0.08, 24.6))
		and footprint.end.is_equal_approx(Vector3(132.0, 4.78, 51.4)),
		"Observation footprint is exactly x=92.5..132, y=0.08..4.78, z=24.6..51.4"
	)

	var deck := connector.get_node_or_null(^"ConnectorDeck") as StaticBody3D
	var deck_shape := _body_box_shape(deck)
	var connector_exact := deck != null \
		and deck.position.is_equal_approx(Vector3(92.25, 0.23, 38.0)) \
		and deck_shape != null \
		and deck_shape.size.is_equal_approx(Vector3(0.5, 0.3, 4.0)) \
		and bool(deck.get_meta(&"walkable_surface", false)) \
		and StringName(deck.get_meta(&"walkable_surface_id", &"")) == &"observation_logistics_connector" \
		and StringName(deck.get_meta(&"walkable_surface_kind", &"")) == &"level" \
		and StringName(deck.get_meta(&"walkable_surface_owner", &"")) == &"station_hub" \
		and is_equal_approx(float(deck.get_meta(&"horizontal_area_m2", -1.0)), 2.0)
	for rail_spec in [
		["ConnectorRailSouth", Vector3(92.25, 1.0, 35.88)],
		["ConnectorRailNorth", Vector3(92.25, 1.0, 40.12)],
	]:
		var rail := connector.get_node_or_null(NodePath(rail_spec[0] as String)) as StaticBody3D
		var rail_shape := _body_box_shape(rail)
		connector_exact = connector_exact \
			and rail != null \
			and rail.position.is_equal_approx(rail_spec[1] as Vector3) \
			and rail_shape != null \
			and rail_shape.size.is_equal_approx(Vector3(0.5, 1.24, 0.16)) \
			and not bool(rail.get_meta(&"walkable_surface", false))
	_check(connector_exact, "Observation handoff is the exact tagged 2.0 m2 deck with two exact guarded edges")
	var rail_laps_exact := true
	var rear_gate := annex.get_rear_observation_gate_contract()
	var connector_rail_by_segment := {
		&"north": connector.get_node_or_null(^"ConnectorRailNorth") as StaticBody3D,
		&"south": connector.get_node_or_null(^"ConnectorRailSouth") as StaticBody3D,
	}
	for segment_variant in rear_gate.returned_segments as Array:
		var segment := segment_variant as Dictionary
		var segment_id := StringName(segment.segment_id)
		var returned_body := annex.get_node_or_null(segment.body_path as NodePath) as StaticBody3D
		var connector_rail := connector_rail_by_segment.get(segment_id) as StaticBody3D
		if returned_body == null or connector_rail == null:
			rail_laps_exact = false
			continue
		var lap := _aabb_overlap_depth(_collision_body_box(returned_body), _collision_body_box(connector_rail))
		rail_laps_exact = rail_laps_exact and lap.distance_to(Vector3(0.07, 1.24, 0.16)) <= 0.001
	_check(rail_laps_exact, "both connector rails make the exact 0.07 x 1.24 x 0.16 m safety lap with the returned Fabrication rail tips")
	var route_anchor := connector.get_node_or_null(^"RouteAnchor") as Node3D
	var rear_cross := annex.get_node_or_null(^"GeneratedAnnex/RearCrossAisle") as StaticBody3D
	var exposed_connector := spur.get_node_or_null(^"Structure/Walkable/ExposedConnectorDeck") as StaticBody3D
	var support_boxes := [
		_collision_body_box(rear_cross),
		_collision_body_box(deck),
		_collision_body_box(exposed_connector),
	]
	var route_continuous := route_anchor != null \
		and route_anchor.global_position.is_equal_approx(Vector3(91.0, 0.53, 38.0)) \
		and connector.is_ancestor_of(route_anchor) \
		and not annex.is_ancestor_of(route_anchor) \
		and not spur.is_ancestor_of(route_anchor)
	for sample_index in 31:
		var sample_x := 91.0 + float(sample_index) * 0.05
		var supported := false
		for support_box_variant in support_boxes:
			var support_box := support_box_variant as AABB
			if sample_x >= support_box.position.x - 0.001 \
					and sample_x <= support_box.end.x + 0.001 \
					and 38.0 >= support_box.position.z - 0.001 \
					and 38.0 <= support_box.end.z + 0.001:
				supported = true
		route_continuous = route_continuous and supported
	_check(route_continuous, "world-owned route anchor to connector to Spur origin is continuously backed by real walkable collision")

	var slots := spur.get_connection_slots()
	var origin := slots.get(&"origin", {}) as Dictionary
	var route_ids := spur.get_route_ids()
	var slot_exact := slots.size() == 1 \
		and StringName(origin.get("slot_id", &"")) == &"observation-logistics-spur-origin" \
		and (origin.get("world_transform", Transform3D.IDENTITY) as Transform3D).is_equal_approx(expected_transform)
	for route_id in [&"observation-pad", &"logistics-pad"]:
		var marker := spur.get_route_marker(route_id)
		slot_exact = slot_exact \
			and marker != null \
			and bool(marker.get_meta(&"deferred_connection_route", false)) \
			and StringName(marker.get_meta(&"connection_status", &"")) == &"internal_route_only_no_geometry" \
			and not marker.has_meta(&"station_connection_slot")
	_check(
		slot_exact and route_ids.size() == 6,
		"Observation publishes one honest origin slot while both pad markers remain deferred internal routes"
	)

	# The connector/module may touch at x=92.5, and the connector's safety rails
	# intentionally lap the returned Fabrication rail tips. Neither is an unrelated
	# station intrusion, so audit all other station bodies independently.
	var owned_bodies: Array[StaticBody3D] = []
	for candidate in connector.find_children("*", "StaticBody3D", true, false):
		owned_bodies.append(candidate as StaticBody3D)
	for candidate in spur.find_children("*", "StaticBody3D", true, false):
		owned_bodies.append(candidate as StaticBody3D)
	var intrusions := PackedStringArray()
	for raw_other in world.find_children("*", "StaticBody3D", true, false):
		var other := raw_other as StaticBody3D
		if connector.is_ancestor_of(other) or spur.is_ancestor_of(other) or annex.is_ancestor_of(other):
			continue
		var other_box := _collision_body_box(other)
		if not other_box.has_volume():
			continue
		for owned in owned_bodies:
			var overlap := _aabb_overlap_depth(_collision_body_box(owned), other_box)
			if overlap.x > 0.002 and overlap.y > 0.002 and overlap.z > 0.002:
				intrusions.append("%s <> %s depth=%s" % [owned.get_path(), other.get_path(), overlap])
	intrusions.sort()
	print("OBSERVATION_GEOMETRY_INTRUSIONS: ", intrusions)
	_check(intrusions.is_empty(), "Observation collision has no positive-volume intersection with unrelated station geometry")

	var observation_boxes: Array[AABB] = []
	for body in owned_bodies:
		var body_box := _collision_body_box(body)
		if body_box.has_volume():
			observation_boxes.append(body_box)
	var halyard := world.get_berth_node(&"halyard_fleet_dock_berth")
	var halyard_ship: HalyardCrewTransport
	for ship in ships:
		if ship is HalyardCrewTransport:
			halyard_ship = ship as HalyardCrewTransport
			break
	_check(halyard != null and halyard_ship != null, "live Halyard berth and production craft resolve for capture-braking clearance")
	if halyard == null or halyard_ship == null:
		return
	var berth_half := halyard.get_landing_half_extents()
	var berth_box := (halyard.get_dock_transform() * AABB(-berth_half, berth_half * 2.0)).abs()
	var hull_bounds := HalyardCrewTransport.FLIGHT_COLLISION_BOUNDS
	var staging_hull := (halyard.get_assist_staging_transform() * hull_bounds).abs()
	var docked_hull := (halyard.get_dock_transform() * hull_bounds).abs()
	var braking_sweep := staging_hull.merge(docked_hull)
	var berth_clearance := INF
	var staging_clearance := INF
	var braking_clearance := INF
	for body_box in observation_boxes:
		berth_clearance = minf(berth_clearance, _aabb_separation(berth_box, body_box))
		staging_clearance = minf(staging_clearance, _aabb_separation(staging_hull, body_box))
		braking_clearance = minf(braking_clearance, _aabb_separation(braking_sweep, body_box))
	print(
		"OBSERVATION_HALYARD_CLEARANCE: berth=%.3f staging=%.3f braking_sweep=%.3f" % [
			berth_clearance, staging_clearance, braking_clearance,
		]
	)
	_check(
		berth_clearance > 10.0 and staging_clearance > 10.0 and braking_clearance > 10.0,
		"Observation spur and connector keep more than 10 m from Halyard berth, staging hull, and fixed staging-to-dock sweep"
	)

	# The fixed staging path above does not cover the edge of the accepted capture
	# volume. Bound that separate live risk in its worst +X direction: the capture
	# root may begin at the box's maximum X, any accepted attitude may point the
	# furthest physical collision corner toward +X, and maximum accepted velocity
	# requires v²/(2a) metres before stopping at the live ship braking rate.
	var capture_half := halyard.get_assist_capture_half_extents()
	var capture_box := (halyard.get_assist_capture_transform() * AABB(
		-capture_half, capture_half * 2.0
	)).abs()
	var shape_radius_report := _maximum_enabled_physical_shape_corner_radius(halyard_ship)
	var shape_corner_radius := float(shape_radius_report.radius)
	var capture_maximum_speed := halyard.get_assist_capture_maximum_speed()
	var configured_brake_acceleration := halyard_ship.brake_acceleration
	# The production landing-assist brake enforces this exact 48 m/s² minimum
	# (`HeroShip._update_landing_brake`), even on the Halyard's heavier 19 m/s²
	# manual-flight braking tune. This is the rate that stops an accepted capture.
	var landing_brake_acceleration := maxf(configured_brake_acceleration, 48.0)
	var stopping_distance := capture_maximum_speed * capture_maximum_speed \
		/ (2.0 * landing_brake_acceleration)
	var accepted_capture_braking_max_x := capture_box.end.x + shape_corner_radius + stopping_distance
	var connector_min_x := INF
	for candidate in connector.find_children("*", "StaticBody3D", true, false):
		connector_min_x = minf(connector_min_x, _collision_body_box(candidate as StaticBody3D).position.x)
	var spur_min_x := INF
	for candidate in spur.find_children("*", "StaticBody3D", true, false):
		spur_min_x = minf(spur_min_x, _collision_body_box(candidate as StaticBody3D).position.x)
	var capture_braking_connector_margin := connector_min_x - accepted_capture_braking_max_x
	var capture_braking_spur_margin := spur_min_x - accepted_capture_braking_max_x
	print(
		"OBSERVATION_HALYARD_CAPTURE_BRAKING_BOUND: capture_max_x=%.6f shapes=%d corner_radius=%.6f speed=%.6f configured_brake=%.6f landing_brake=%.6f stopping=%.6f bound_max_x=%.6f connector_min_x=%.6f connector_margin=%.6f spur_min_x=%.6f spur_margin=%.6f" % [
			capture_box.end.x, int(shape_radius_report.shape_count), shape_corner_radius,
			capture_maximum_speed, configured_brake_acceleration,
			landing_brake_acceleration, stopping_distance,
			accepted_capture_braking_max_x, connector_min_x,
			capture_braking_connector_margin, spur_min_x, capture_braking_spur_margin,
		]
	)
	_check(
		int(shape_radius_report.shape_count) == int(PRODUCTION_SHIP_ROOT_SHAPE_COUNTS[&"HalyardCrewTransport"]) \
		and absf(capture_box.end.x - 61.0) <= 0.00001 \
		and absf(shape_corner_radius - 15.922939) <= 0.00001 \
		and is_equal_approx(capture_maximum_speed, 22.0) \
		and is_equal_approx(configured_brake_acceleration, 19.0) \
		and is_equal_approx(landing_brake_acceleration, 48.0) \
		and absf(stopping_distance - 5.041667) <= 0.00001 \
		and absf(accepted_capture_braking_max_x - 81.964606) <= 0.00001 \
		and absf(connector_min_x - 92.0) <= 0.00001 \
		and absf(capture_braking_connector_margin - 10.035394) <= 0.00001 \
		and absf(spur_min_x - 92.5) <= 0.00001 \
		and absf(capture_braking_spur_margin - 10.535394) <= 0.00001 \
		and capture_braking_connector_margin > 10.0 \
		and capture_braking_spur_margin > 10.0,
		"worst accepted Halyard capture root, attitude, and velocity retain more than 10 m braking margin to both connector and Spur collision"
	)

	# SIT-OBS-OVERFLIGHT-001: preserve the authored +X overflight root line. Every
	# enabled physical collision shape of every production craft is sampled at
	# seven positions and three representative pitch/roll attitudes. This is an
	# intentionally conservative AABB witness per shape, never one aggregate hull.
	var overflight_boxes: Array[AABB] = observation_boxes.duplicate()
	for candidate in annex.find_children("*", "StaticBody3D", true, false):
		var annex_box := _collision_body_box(candidate as StaticBody3D)
		if annex_box.has_volume():
			overflight_boxes.append(annex_box)
	var sampled_shape_count := 0
	var sample_count := 0
	var overflight_intrusions := PackedStringArray()
	var attitude_degrees := [Vector2.ZERO, Vector2(-8.0, -5.0), Vector2(8.0, 5.0)]
	for ship in ships:
		var ship_shapes: Array[CollisionShape3D] = []
		for raw_shape in ship.find_children("*", "CollisionShape3D", true, false):
			var collision := raw_shape as CollisionShape3D
			if collision.get_parent() == ship and not collision.disabled and collision.shape != null:
				ship_shapes.append(collision)
		sampled_shape_count += ship_shapes.size()
		for x_position in [100.0, 107.0, 114.0, 121.0, 128.0, 135.0, 142.0]:
			for attitude in attitude_degrees:
				var basis := Basis(Vector3.UP, -PI * 0.5) \
					* Basis(Vector3.RIGHT, deg_to_rad((attitude as Vector2).x)) \
					* Basis(Vector3.FORWARD, deg_to_rad((attitude as Vector2).y))
				var sample_transform := Transform3D(basis, Vector3(x_position, 22.0, 38.0))
				for collision in ship_shapes:
					sample_count += 1
					var local_bounds := _shape_local_bounds(collision.shape)
					var sample_box := _transformed_aabb(sample_transform * collision.transform, local_bounds)
					for station_box in overflight_boxes:
						var overlap := _aabb_overlap_depth(sample_box, station_box)
						if overlap.x > 0.0 and overlap.y > 0.0 and overlap.z > 0.0:
							overflight_intrusions.append(
								"%s/%s x=%.1f attitude=%s depth=%s" % [
									ship.name, collision.name, x_position, attitude, overlap,
								]
							)
	var highest_structure_top := -INF
	for station_box in overflight_boxes:
		highest_structure_top = maxf(highest_structure_top, station_box.end.y)
	var root_height_clearance := 22.0 - highest_structure_top
	var camera_sphere_clearance := INF
	for ship in ships:
		camera_sphere_clearance = minf(
			camera_sphere_clearance,
			22.0 - ship.chase_camera_collision_radius - highest_structure_top
		)
	overflight_intrusions.sort()
	print(
		"OBSERVATION_OVERFLIGHT: craft=%d shapes=%d shape_samples=%d highest_structure=%.3f root_clearance=%.3f camera_sphere_clearance=%.3f intrusions=%s" % [
			ships.size(), sampled_shape_count, sample_count, highest_structure_top,
			root_height_clearance, camera_sphere_clearance, overflight_intrusions,
		]
	)
	_check(
		_production_ship_root_shape_roster_matches(ships) \
		and sampled_shape_count == PRODUCTION_SHIP_ROOT_SHAPE_TOTAL \
		and sample_count == PRODUCTION_SHIP_ROOT_SHAPE_TOTAL * 21 \
		and overflight_intrusions.is_empty(),
		"all 98 enabled physical shapes across the exact nine-ship production roster clear Spur, connector, and Fabrication along the sampled +X overflight line"
	)
	_check(
		root_height_clearance > 16.0 and camera_sphere_clearance > 15.0,
		"the 22 m overflight root retains more than 16 m root-height and 15 m live camera-sphere clearance"
	)

	var authority := spur.get_authority_contract()
	_check(
		(authority.authority_ids as PackedStringArray).is_empty() \
		and int(authority.ship_berth_count) == 0 \
		and int(authority.landing_or_interaction_area_count) == 0 \
		and int(authority.audio_node_count) == 0 \
		and int(authority.activity_node_count) == 0 \
		and int(authority.lease_authority_count) == 0 \
		and int(authority.spawn_authority_count) == 0 \
		and StringName(authority.network_authority_role) == &"none",
		"production Observation module preserves zero ship, berth, interaction, audio, activity, lease, spawn, and network authority"
	)
	var audit := spur.get_audit_report()
	print("OBSERVATION_PRODUCTION_AUDIT: ", audit)
	_check(bool(audit.valid) and is_equal_approx(float(audit.walkable_area_m2), 366.0), "production Observation audit stays valid with its compacted exact 366 m2 standalone surface union")


func _test_salvage_terrace_siting(world: ShipyardWorld, ships: Array[HeroShip]) -> void:
	var salvage := world.get_node_or_null(^"SalvageTerrace") as SalvageTerrace
	var connector := world.get_node_or_null(^"ExposedDockLattice/SalvageTerraceConnector") as Node3D
	var annex := world.get_node_or_null(^"FabricationAnnex") as FabricationAnnex
	_check(salvage != null and connector != null and annex != null, "production Salvage Terrace, connector, and Fabrication service seam resolve")
	if salvage == null or connector == null or annex == null:
		return
	var expected_transform := Transform3D(Basis.IDENTITY, Vector3(84.0, 0.38, 52.91))
	_check(salvage.global_transform.is_equal_approx(expected_transform), "Salvage Terrace keeps the reviewed identity-yaw placement at (84, 0.38, 52.91)")
	var local_footprint := salvage.get_integration_footprint()
	var footprint := (salvage.global_transform * AABB(
		local_footprint.local_min as Vector3,
		(local_footprint.local_max as Vector3) - (local_footprint.local_min as Vector3)
	)).abs()
	_check(
		footprint.position.is_equal_approx(Vector3(65.9, -1.42, 52.21))
		and footprint.end.is_equal_approx(Vector3(111.3, 7.48, 71.01)),
		"Salvage footprint is exactly x=65.9..111.3, y=-1.42..7.48, z=52.21..71.01"
	)

	var deck := connector.get_node_or_null(^"ConnectorDeck") as StaticBody3D
	var deck_shape := _body_box_shape(deck)
	var connector_exact := deck != null \
		and deck.position.is_equal_approx(Vector3(84.0, 0.18, 52.455)) \
		and deck_shape != null \
		and deck_shape.size.is_equal_approx(Vector3(4.32, 0.40, 0.91)) \
		and bool(deck.get_meta(&"walkable_surface", false)) \
		and StringName(deck.get_meta(&"walkable_surface_id", &"")) == &"salvage_terrace_connector" \
		and StringName(deck.get_meta(&"walkable_surface_kind", &"")) == &"level" \
		and StringName(deck.get_meta(&"walkable_surface_owner", &"")) == &"station_hub" \
		and is_equal_approx(float(deck.get_meta(&"horizontal_area_m2", -1.0)), 3.9312)
	for rail_spec in [
		["ConnectorRailWest", Vector3(81.92, 1.03, 52.45)],
		["ConnectorRailEast", Vector3(86.08, 1.03, 52.45)],
	]:
		var rail := connector.get_node_or_null(NodePath(rail_spec[0] as String)) as StaticBody3D
		var rail_shape := _body_box_shape(rail)
		connector_exact = connector_exact \
			and rail != null \
			and rail.position.is_equal_approx(rail_spec[1] as Vector3) \
			and rail_shape != null \
			and rail_shape.size.is_equal_approx(Vector3(0.16, 1.30, 0.76)) \
			and not bool(rail.get_meta(&"walkable_surface", false))
	_check(
		connector_exact,
		"Salvage handoff is the exact tagged 3.9312 m2 deck with two exact rails and 4.0 m clear width"
	)

	# The graph endpoint remains world-owned, while the only promoted Fabrication
	# route is its actual north service marker at the physical seam. The anchor is
	# 0.09 m inside the Fabrication deck solely to preserve the courier component's
	# honest one-metre minimum route without inventing another waypoint.
	var route_anchor := connector.get_node_or_null(^"RouteAnchor") as Node3D
	var service_marker := annex.get_route_marker(&"annex_port_service")
	var module_connector := salvage.get_route_marker(&"connector")
	var fabrication_floor := annex.get_node_or_null(^"GeneratedAnnex/PortSideBypass") as StaticBody3D
	var salvage_apron := salvage.get_node_or_null(^"GeneratedRoot/ConnectionApron") as StaticBody3D
	var support_boxes := [
		_collision_body_box(fabrication_floor),
		_collision_body_box(deck),
		_collision_body_box(salvage_apron),
	]
	var route_continuous := route_anchor != null \
		and service_marker != null \
		and module_connector != null \
		and route_anchor.global_position.is_equal_approx(Vector3(84.0, 0.53, 51.91)) \
		and service_marker.global_position.is_equal_approx(Vector3(84.0, 0.53, 52.0)) \
		and module_connector.global_position.is_equal_approx(Vector3(84.0, 0.53, 52.91)) \
		and is_equal_approx(route_anchor.global_position.distance_to(module_connector.global_position), 1.0) \
		and connector.is_ancestor_of(route_anchor) \
		and not annex.is_ancestor_of(route_anchor) \
		and not salvage.is_ancestor_of(route_anchor) \
		and not service_marker.has_meta(&"station_connection_slot")
	for sample_index in 21:
		var sample_z := 51.91 + float(sample_index) * 0.05
		var supported := false
		for support_box_variant in support_boxes:
			var support_box := support_box_variant as AABB
			if 84.0 >= support_box.position.x - 0.001 \
					and 84.0 <= support_box.end.x + 0.001 \
					and sample_z >= support_box.position.z - 0.001 \
					and sample_z <= support_box.end.z + 0.001:
				supported = true
		route_continuous = route_continuous and supported
	_check(
		route_continuous,
		"Fabrication north-service marker through the world anchor, connector, and Salvage origin is continuously collision-backed"
	)
	var connection_slots: Array = salvage.get_connection_slot_contract()
	var slot_exact := connection_slots.size() == 1 \
		and StringName((connection_slots[0] as Dictionary).get("slot_id", &"")) == &"hub-salvage-terrace" \
		and StringName((connection_slots[0] as Dictionary).get("route_id", &"")) == &"connector"
	for route_id in salvage.get_route_ids():
		var marker := salvage.get_route_marker(route_id)
		slot_exact = slot_exact and marker != null \
			and (marker.has_meta(&"station_connection_slot") == (route_id == &"connector"))
	_check(slot_exact, "Salvage publishes only its honest local-origin connector slot; all six internal routes remain non-slots")

	var owned_bodies: Array[StaticBody3D] = []
	for candidate in connector.find_children("*", "StaticBody3D", true, false):
		owned_bodies.append(candidate as StaticBody3D)
	for candidate in salvage.find_children("*", "StaticBody3D", true, false):
		owned_bodies.append(candidate as StaticBody3D)
	var intrusions := PackedStringArray()
	for raw_other in world.find_children("*", "StaticBody3D", true, false):
		var other := raw_other as StaticBody3D
		if connector.is_ancestor_of(other) or salvage.is_ancestor_of(other):
			continue
		var other_box := _collision_body_box(other)
		if not other_box.has_volume():
			continue
		for owned in owned_bodies:
			var overlap := _aabb_overlap_depth(_collision_body_box(owned), other_box)
			if overlap.x > 0.002 and overlap.y > 0.002 and overlap.z > 0.002:
				intrusions.append("%s <> %s depth=%s" % [owned.get_path(), other.get_path(), overlap])
	intrusions.sort()
	print("SALVAGE_GEOMETRY_INTRUSIONS: ", intrusions)
	_check(intrusions.is_empty(), "Salvage and connector collision have no positive-volume intersection with unrelated station geometry")
	var handoff_overlap := _aabb_overlap_depth(_collision_body_box(deck), _collision_body_box(salvage_apron))
	_check(
		handoff_overlap.x > 3.99 and handoff_overlap.y > 0.0 and absf(handoff_overlap.z) <= 0.001,
		"connector and Salvage apron share only their exact four-metre boundary plane"
	)

	var owned_boxes: Array[AABB] = []
	for body in owned_bodies:
		var box := _collision_body_box(body)
		if box.has_volume():
			owned_boxes.append(box)
	var smallest_berth_gap := INF
	for berth_id in world.get_berth_ids():
		var berth := world.get_berth_node(berth_id)
		var half := berth.get_landing_half_extents()
		var berth_box := (berth.get_dock_transform() * AABB(-half, half * 2.0)).abs()
		for owned_box in owned_boxes:
			smallest_berth_gap = minf(smallest_berth_gap, _aabb_separation(berth_box, owned_box))

	# Use every enabled physical root shape, rather than a nominal craft AABB, for
	# both the parked fleet and 21 actual Halyard assist-path attitudes.
	var craft_shape_count := 0
	var craft_intrusions := PackedStringArray()
	var smallest_craft_gap := INF
	var halyard_ship: HalyardCrewTransport
	for ship in ships:
		if ship is HalyardCrewTransport:
			halyard_ship = ship as HalyardCrewTransport
		for raw_shape in ship.find_children("*", "CollisionShape3D", true, false):
			var collision := raw_shape as CollisionShape3D
			if collision.get_parent() != ship or collision.disabled or collision.shape == null:
				continue
			craft_shape_count += 1
			var craft_box := _transformed_aabb(collision.global_transform, _shape_local_bounds(collision.shape))
			for owned_box in owned_boxes:
				var overlap := _aabb_overlap_depth(craft_box, owned_box)
				if overlap.x > 0.0 and overlap.y > 0.0 and overlap.z > 0.0:
					craft_intrusions.append("%s/%s depth=%s" % [ship.name, collision.name, overlap])
				else:
					smallest_craft_gap = minf(smallest_craft_gap, _aabb_separation(craft_box, owned_box))
	var assist_shape_count := 0
	var assist_sample_count := 0
	var assist_intrusions := PackedStringArray()
	var smallest_assist_gap := INF
	var halyard := world.get_berth_node(&"halyard_fleet_dock_berth")
	if halyard != null and halyard_ship != null:
		var staging := halyard.get_assist_staging_transform()
		var docked := halyard.get_dock_transform()
		var halyard_shapes: Array[CollisionShape3D] = []
		for raw_shape in halyard_ship.find_children("*", "CollisionShape3D", true, false):
			var collision := raw_shape as CollisionShape3D
			if collision.get_parent() == halyard_ship and not collision.disabled and collision.shape != null:
				halyard_shapes.append(collision)
		assist_shape_count = halyard_shapes.size()
		for sample_index in 21:
			var sample_root := staging.interpolate_with(docked, float(sample_index) / 20.0)
			for collision in halyard_shapes:
				assist_sample_count += 1
				var sample_box := _transformed_aabb(
					sample_root * collision.transform, _shape_local_bounds(collision.shape)
				)
				for owned_box in owned_boxes:
					var overlap := _aabb_overlap_depth(sample_box, owned_box)
					if overlap.x > 0.0 and overlap.y > 0.0 and overlap.z > 0.0:
						assist_intrusions.append("%s sample=%d depth=%s" % [collision.name, sample_index, overlap])
					else:
						smallest_assist_gap = minf(smallest_assist_gap, _aabb_separation(sample_box, owned_box))
	var capture_overlap_count := 0
	var smallest_capture_gap := INF
	if halyard != null:
		var capture_half := halyard.get_assist_capture_half_extents()
		var capture_box := (halyard.get_assist_capture_transform() * AABB(-capture_half, capture_half * 2.0)).abs()
		for owned_box in owned_boxes:
			var overlap := _aabb_overlap_depth(capture_box, owned_box)
			if overlap.x > 0.0 and overlap.y > 0.0 and overlap.z > 0.0:
				capture_overlap_count += 1
			else:
				smallest_capture_gap = minf(smallest_capture_gap, _aabb_separation(capture_box, owned_box))
	print(
		"SALVAGE_CLEARANCES: berth=%.6f craft=%.6f craft_shapes=%d assist=%.6f assist_shapes=%d assist_samples=%d capture=%.6f capture_overlaps=%d" % [
			smallest_berth_gap, smallest_craft_gap, craft_shape_count,
			smallest_assist_gap, assist_shape_count, assist_sample_count,
			smallest_capture_gap, capture_overlap_count,
		]
	)
	_check(
		_production_ship_root_shape_roster_matches(ships) \
		and craft_shape_count == PRODUCTION_SHIP_ROOT_SHAPE_TOTAL \
		and craft_intrusions.is_empty(),
		"all 98 enabled physical shapes across the exact nine-ship production roster clear Salvage and its connector"
	)
	_check(
		absf(smallest_berth_gap - 8.060792) <= 0.00001,
		"Salvage and connector keep the exact measured 8.060792 m minimum from authoritative berth volumes"
	)
	_check(
		assist_shape_count == int(PRODUCTION_SHIP_ROOT_SHAPE_COUNTS[&"HalyardCrewTransport"]) \
		and assist_sample_count == int(PRODUCTION_SHIP_ROOT_SHAPE_COUNTS[&"HalyardCrewTransport"]) * 21 \
		and assist_intrusions.is_empty() \
		and smallest_assist_gap > 10.0 \
		and absf(smallest_assist_gap - 24.622694) <= 0.00001,
		"all 21 Halyard shapes clear Salvage throughout 21 samples of the real staging-to-dock assist path by more than 10 m"
	)
	_check(
		capture_overlap_count == 0 and absf(smallest_capture_gap - 4.919998) <= 0.00001,
		"even Halyard's broad assist-capture volume retains the exact measured 4.919998 m gap to Salvage"
	)

	var audit := salvage.get_audit_report()
	var area := audit.get("walkable_area", {}) as Dictionary
	var authority := audit.get("authority", {}) as Dictionary
	var performance := audit.get("performance", {}) as Dictionary
	print("SALVAGE_PRODUCTION_AUDIT: ", audit)
	_check(
		bool(audit.valid) \
		and is_equal_approx(float(area.horizontal_walkable_area_m2), 396.0) \
		and is_equal_approx(float(area.ramp_projected_area_m2), 72.0) \
		and absf(float(area.ramp_true_area_m2) - 78.954163) <= 0.00001 \
		and bool(performance.exact_census) \
		and bool(performance.within_budget),
		"production Salvage audit preserves its compacted exact 396 m2 projected / 402.954163 m2 true standalone surface contract and budgets"
	)
	_check(
		(authority.authority_ids as PackedStringArray).is_empty() \
		and int(authority.ship_berth_count) == 0 \
		and int(authority.landing_or_interaction_area_count) == 0 \
		and int(authority.audio_node_count) == 0 \
		and int(authority.activity_node_count) == 0 \
		and int(authority.ship_authority_count) == 0 \
		and int(authority.berth_authority_count) == 0 \
		and int(authority.combat_authority_count) == 0 \
		and int(authority.interaction_authority_count) == 0 \
		and int(authority.station_activity_authority_count) == 0,
		"production Salvage module owns zero ship, berth, combat, interaction, audio, or activity authority"
	)
	var mutation := Area3D.new()
	mutation.name = "AuthorityMutationProbe"
	salvage.add_child(mutation)
	_check(
		not bool(salvage.get_audit_report().valid),
		"MUTATION: injecting an interaction-area authority into Salvage turns its production audit red"
	)
	salvage.remove_child(mutation)
	mutation.free()
	_check(bool(salvage.get_audit_report().valid), "removing the authority mutation returns the production Salvage audit to green")


func _production_ship_root_shape_roster_matches(ships: Array[HeroShip]) -> bool:
	var live_counts := {}
	for ship in ships:
		var count := 0
		for raw_shape in ship.find_children("*", "CollisionShape3D", true, false):
			var collision := raw_shape as CollisionShape3D
			if collision.get_parent() == ship and not collision.disabled and collision.shape != null:
				count += 1
		live_counts[StringName(ship.name)] = count
	return live_counts == PRODUCTION_SHIP_ROOT_SHAPE_COUNTS


func _collision_body_box(body: StaticBody3D) -> AABB:
	var result := AABB()
	var first := true
	for candidate in body.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		var shape := collision.shape as BoxShape3D
		if shape == null or collision.disabled:
			continue
		var box := (collision.global_transform * AABB(-shape.size * 0.5, shape.size)).abs()
		result = box if first else result.merge(box)
		first = false
	return result


func _body_box_shape(body: StaticBody3D) -> BoxShape3D:
	if body == null:
		return null
	for candidate in body.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if not collision.disabled and collision.shape is BoxShape3D:
			return collision.shape as BoxShape3D
	return null


func _shape_local_bounds(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return AABB(-size * 0.5, size)
	if shape is SphereShape3D:
		var radius := (shape as SphereShape3D).radius
		return AABB(Vector3.ONE * -radius, Vector3.ONE * radius * 2.0)
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return AABB(
			Vector3(-capsule.radius, -capsule.height * 0.5, -capsule.radius),
			Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0)
		)
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return AABB(
			Vector3(-cylinder.radius, -cylinder.height * 0.5, -cylinder.radius),
			Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
		)
	var points := PackedVector3Array()
	if shape is ConvexPolygonShape3D:
		points = (shape as ConvexPolygonShape3D).points
	elif shape is ConcavePolygonShape3D:
		points = (shape as ConcavePolygonShape3D).get_faces()
	if points.is_empty():
		return AABB()
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _maximum_enabled_physical_shape_corner_radius(ship: HeroShip) -> Dictionary:
	# HeroShip builds this live envelope from every enabled root collision shape.
	# Taking the furthest corner of the enclosing box is deliberately stricter
	# than taking the largest corner on any one shape: independent shape extrema
	# combine into one attitude-invariant sphere around the accepted ship root.
	var collision_report := ship.get_landing_collision_report()
	if not bool(collision_report.valid):
		return {"shape_count": 0, "radius": INF}
	var local_bounds := collision_report.local_bounds as AABB
	var maximum_radius := 0.0
	for x in [local_bounds.position.x, local_bounds.end.x]:
		for y in [local_bounds.position.y, local_bounds.end.y]:
			for z in [local_bounds.position.z, local_bounds.end.z]:
				maximum_radius = maxf(maximum_radius, Vector3(x, y, z).length())
	return {
		"shape_count": int(collision_report.shape_count),
		"radius": maximum_radius,
		"local_bounds": local_bounds,
	}


func _transformed_aabb(transform_value: Transform3D, source: AABB) -> AABB:
	var minimum := source.position
	var maximum := source.end
	var corners := PackedVector3Array([
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
	])
	var transformed := AABB(transform_value * corners[0], Vector3.ZERO)
	for corner in corners:
		transformed = transformed.expand(transform_value * corner)
	return transformed


func _aabb_overlap_depth(first: AABB, second: AABB) -> Vector3:
	return Vector3(
		minf(first.end.x, second.end.x) - maxf(first.position.x, second.position.x),
		minf(first.end.y, second.end.y) - maxf(first.position.y, second.position.y),
		minf(first.end.z, second.end.z) - maxf(first.position.z, second.position.z)
	)


func _horizontal_aabb_separation(first: AABB, second: AABB) -> float:
	var x_gap := maxf(0.0, maxf(first.position.x - second.end.x, second.position.x - first.end.x))
	var z_gap := maxf(0.0, maxf(first.position.z - second.end.z, second.position.z - first.end.z))
	return Vector2(x_gap, z_gap).length()


func _aabb_separation(first: AABB, second: AABB) -> float:
	var x_gap := maxf(0.0, maxf(first.position.x - second.end.x, second.position.x - first.end.x))
	var y_gap := maxf(0.0, maxf(first.position.y - second.end.y, second.position.y - first.end.y))
	var z_gap := maxf(0.0, maxf(first.position.z - second.end.z, second.position.z - first.end.z))
	return Vector3(x_gap, y_gap, z_gap).length()


## The station has two chamfer rules and exactly one chamfered-box builder.
##
## `StationSurfaceKit` publishes both rules. The component rule
## (`bevel_for_size`) has a 0.012 m perceptual floor and a `shortest * 0.45`
## safety limit; the module rule (`proportional_bevel_for_size`) is purely
## proportional between a 0.003 m collapse guard and a per-caller cap. They are
## not interchangeable and the difference is load-bearing: adopting the component
## rule for the modules would move 108 of the 277 live chamfered box sizes by up
## to 0.04 m, and on a 0.03 m route stripe it would take a 0.012 m chamfer off
## each side of a 0.03 m section. These anchors are exact on purpose, so a later
## "simplification" onto the single kit rule fails here instead of silently
## reshaping geometry.
func _test_shared_bevel_rules(_world: ShipyardWorld) -> void:
	var proportional_exact := (
		# Above 0.0545 m of shortest side the two rules already agree, which is why
		# they could share a builder at all.
		is_equal_approx(StationSurfaceKit.proportional_bevel_for_size(Vector3(0.18, 1.0, 1.0), 0.2), 0.0396)
		and is_equal_approx(StationSurfaceKit.bevel_for_size(Vector3(0.18, 1.0, 1.0)), 0.0396)
		# The 0.03 m comb/route stripe: proportional keeps it flat, the component
		# floor would not.
		and is_equal_approx(StationSurfaceKit.proportional_bevel_for_size(Vector3(0.03, 0.16, 0.55), 0.2), 0.0066)
		and is_equal_approx(StationSurfaceKit.bevel_for_size(Vector3(0.03, 0.16, 0.55)), 0.012)
		# The caps, which are the other reason the modules keep their own rule.
		and is_equal_approx(StationSurfaceKit.proportional_bevel_for_size(Vector3(1.2, 12.0, 17.0), 0.2), 0.2)
		and is_equal_approx(StationSurfaceKit.proportional_bevel_for_size(Vector3(1.2, 12.0, 17.0), 0.18), 0.18)
		and is_equal_approx(StationSurfaceKit.proportional_bevel_for_size(Vector3(1.2, 12.0, 17.0), 0.22, 0.008), 0.22)
		and is_equal_approx(StationSurfaceKit.bevel_for_size(Vector3(1.2, 12.0, 17.0)), 0.18)
		# The collapse guards.
		and is_equal_approx(StationSurfaceKit.proportional_bevel_for_size(Vector3(0.005, 1.0, 1.0), 0.2), 0.003)
		and is_equal_approx(StationSurfaceKit.proportional_bevel_for_size(Vector3(0.005, 1.0, 1.0), 0.22, 0.008), 0.008)
	)
	_check(proportional_exact, "both published station bevel rules hold their exact frozen values")

	# A chamfer is an edge treatment only: whatever the rule, the mesh must still
	# report the requested outer extents, or a walkable surface or published
	# envelope derived from the size would move.
	var extents_preserved := true
	for size in [Vector3(0.03, 0.16, 0.55), Vector3(1.2, 12.0, 17.0), Vector3(0.18, 1.0, 1.0)]:
		for bevel in [
			StationSurfaceKit.bevel_for_size(size as Vector3),
			StationSurfaceKit.proportional_bevel_for_size(size as Vector3, 0.2),
		]:
			for uv_mode in [StationSurfaceKit.BevelUV.UNIT_PER_QUAD, StationSurfaceKit.BevelUV.FACE_GRID]:
				var mesh := StationSurfaceKit.rounded_box_mesh_with_bevel(size as Vector3, bevel as float, uv_mode)
				extents_preserved = extents_preserved \
					and mesh != null \
					and mesh.get_aabb().size.is_equal_approx(size as Vector3)
	_check(extents_preserved, "the shared chamfered-box builder preserves the requested AABB at every rule and UV mode")


func _test_station_panel_material_bindings(world: ShipyardWorld) -> void:
	var specs := [
		# Complete per-module roster of keys bound into the station panel family.
		# `mid_grey`/`hull_dark` joined when the wall/floor mismatch was closed;
		# `brass`, `structural` and `orange` joined with the structural-and-painted
		# closing pass. Keeping this list complete is what stops a module binding a
		# key with a drifted recipe and only the aggregate count noticing.
		[world.get_node_or_null(^"AftJunctionStack"), ["off_white", "off_white_floor", "panel_light", "warm_grey", "warm_grey_floor", "mid_grey", "mid_grey_floor", "hull_dark", "hull_dark_floor", "brass"], 0.30],
		[world.get_node_or_null(^"HabitatSpine"), ["shell_light", "shell_light_floor", "shell_mid", "floor", "structural", "brass"], 0.28],
		[world.get_node_or_null(^"JovianFreightBerth"), ["ceramic", "ceramic_warm", "steel_blue", "orange"], 0.30],
		[world.get_node_or_null(^"JovianFreightBerth"), ["ceramic_floor", "deck"], 0.22],
		[world.get_node_or_null(^"FabricationAnnex"), ["deck", "structure", "machine"], 0.30],
	]
	var every_binding_exact := true
	for spec in specs:
		var owner := spec[0] as Node3D
		if owner == null:
			every_binding_exact = false
			continue
		var materials := owner.get("_materials") as Dictionary
		for key in spec[1] as Array:
			var material := materials.get(key) as StandardMaterial3D
			every_binding_exact = every_binding_exact and material != null
			if material == null:
				continue
			every_binding_exact = every_binding_exact \
				and material.albedo_texture != null \
				and material.albedo_texture.resource_path == "res://assets/materials/procedural-panel-triplanar-albedo-v2.png" \
				and material.normal_enabled \
				and material.normal_texture != null \
				and material.normal_texture.resource_path == "res://assets/materials/procedural-panel-triplanar-normal-v2.png" \
				and is_equal_approx(material.normal_scale, 1.0) \
				and material.roughness_texture != null \
				and material.roughness_texture.resource_path == "res://assets/materials/procedural-panel-triplanar-roughness-v2.png" \
				and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED \
				and material.uv1_triplanar \
				and material.uv1_world_triplanar \
				and material.texture_repeat \
				and material.uv1_scale.is_equal_approx(Vector3.ONE * float(spec[2]))
	_check(every_binding_exact, "Aft, Habitat, Freight, and Fabrication station roles use the exact neutral world-triplanar PBR recipe and frozen scales")

	var aft := world.get_node_or_null(^"AftJunctionStack") as AftJunctionStack
	var habitat := world.get_node_or_null(^"HabitatSpine") as HabitatSpine
	var freight := world.get_node_or_null(^"JovianFreightBerth") as JovianFreightBerth
	var no_arrow_station_materials := true
	var audited_station_meshes := 0
	var skipped_live_ship_meshes := 0
	var forbidden_station_paths := PackedStringArray()
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if _is_live_ship_mesh(mesh_instance, world):
			skipped_live_ship_meshes += 1
			continue
		audited_station_meshes += 1
		for surface_index in mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0:
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			for texture in [material.albedo_texture, material.normal_texture, material.roughness_texture]:
				if texture == null:
					continue
				var texture_path := (texture as Texture2D).resource_path
				if "arrow-hull-" in texture_path or "jovian-hull-" in texture_path:
					no_arrow_station_materials = false
					forbidden_station_paths.append("%s -> %s" % [mesh_instance.get_path(), texture_path])
	forbidden_station_paths.sort()
	print(
		"STATION_TEXTURE_TRAVERSAL: station_meshes=", audited_station_meshes,
		" skipped_live_ship_meshes=", skipped_live_ship_meshes,
		" forbidden=", forbidden_station_paths
	)
	_check(audited_station_meshes >= 450, "texture traversal audits the complete live ShipyardWorld station subtree")
	_check(no_arrow_station_materials, "no live station MeshInstance3D uses the directional Arrow or Jovian hull atlases")

	var treads := aft.find_children("VisibleTread*", "Marker3D", true, false) if aft != null else []
	var tread_world_phase := treads.size() == AftJunctionStack.STAIR_STEP_COUNT
	var tread_origins := {}
	var tread_batch := aft.get_node_or_null(
		^"Structure/Circulation/VisibleTreadRenderBatch"
	) as MultiMeshInstance3D if aft != null else null
	var tread_material := tread_batch.material_override as StandardMaterial3D if tread_batch != null else null
	var tread_transforms := tread_batch.get_meta("authored_instance_transforms", []) as Array if tread_batch != null else []
	for index in treads.size():
		var tread := treads[index] as Marker3D
		tread_world_phase = tread_world_phase \
			and tread.name == "VisibleTread%02d" % index \
			and index < tread_transforms.size() \
			and tread.transform.is_equal_approx(tread_transforms[index] as Transform3D)
		tread_origins[tread.global_position] = true
	tread_world_phase = tread_world_phase \
		and tread_batch != null and tread_batch.multimesh != null \
		and tread_batch.multimesh.instance_count == AftJunctionStack.STAIR_STEP_COUNT \
		and tread_transforms.size() == AftJunctionStack.STAIR_STEP_COUNT \
		and tread_material == (aft.get("_materials") as Dictionary).get("off_white_floor") \
		and tread_material != null \
		and tread_material.uv1_world_triplanar \
		and tread_material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30)
	_check(tread_world_phase and tread_origins.size() == AftJunctionStack.STAIR_STEP_COUNT, "all fifteen Aft treads sample one world-space panel field instead of cloning local-origin patches")

	# Same-role coplanar pieces must share the same resource. Combined with
	# world-space triplanar coordinates, this guarantees one metric phase at
	# seams instead of restarting the panel field at each MeshInstance origin.
	var phase_groups := [
		[aft, "off_white_floor", [
			"Structure/LowerOpenDeck/ConnectionDeck",
			"Structure/LowerOpenDeck/StairBaseLanding",
			"Structure/UpperOpenDeck/UpperFloor",
			"Structure/OperationsRoom/OperationsFloor",
		]],
		[habitat, "shell_light_floor", [
			"Structure/PlayerClearConnector/ConnectorFloor",
			"Structure/PressurizedHabitatCorridor/EntryVestibuleFloor",
			"Structure/PressurizedHabitatCorridor/HabitatFloor",
			"Structure/ObservationCommon/CommonFloor",
		]],
		[freight, "deck", [
			"ConnectionLattice/ConnectionDeckA",
			"ConnectionLattice/ConnectionDeckB",
			"ConnectionLattice/ConnectionDeckC",
			"LoadingApron/ApronDeck01",
			"LoadingApron/ApronDeck02",
			"LoadingApron/ApronDeck03",
			"LoadingApron/ApronDeck04",
		]],
		[freight, "ceramic_floor", ["FreightControlRoom/RoomFloor"]],
		[world.get_node_or_null(^"FabricationAnnex"), "deck", FABRICATION_SURFACE_PATHS],
	]
	var coplanar_phase_exact := true
	for phase_group in phase_groups:
		var owner := phase_group[0] as Node3D
		if owner == null:
			coplanar_phase_exact = false
			continue
		var reference := (owner.get("_materials") as Dictionary).get(phase_group[1]) as StandardMaterial3D
		coplanar_phase_exact = coplanar_phase_exact and reference != null and reference.uv1_world_triplanar
		for raw_path in phase_group[2] as Array:
			coplanar_phase_exact = coplanar_phase_exact and _surface_material(owner, NodePath(raw_path)) == reference
	_check(coplanar_phase_exact, "coplanar station floor segments share one material resource, scale, and world-metric triplanar phase across seams")

	# Overlay pieces the player physically walks on used to sit unmapped on top of
	# mapped floors: the Aft continuous stair ramp, the Aft operations pressure
	# plates, and the Habitat connector/corridor/common insets. They must carry the
	# same station family as the floor they interrupt.
	var walked_overlays_mapped := true
	for overlay_spec in [
		[aft, "Structure/Circulation/ContinuousStairRamp/RampMesh"],
		[habitat, "Structure/PlayerClearConnector/ConnectorInset"],
		[habitat, "Structure/PressurizedHabitatCorridor/CorridorLane"],
		[habitat, "Structure/ObservationCommon/CommonFloorInset"],
	]:
		var overlay_owner := overlay_spec[0] as Node3D
		var overlay: MeshInstance3D
		if overlay_owner != null:
			overlay = overlay_owner.get_node_or_null(NodePath(overlay_spec[1] as String)) as MeshInstance3D
		var overlay_material: StandardMaterial3D
		if overlay != null and overlay.mesh != null and overlay.mesh.get_surface_count() > 0:
			overlay_material = overlay.get_active_material(0) as StandardMaterial3D
		walked_overlays_mapped = walked_overlays_mapped \
			and overlay_material != null \
			and overlay_material.albedo_texture != null \
			and overlay_material.albedo_texture.resource_path == "res://assets/materials/procedural-panel-triplanar-albedo-v2.png" \
			and overlay_material.uv1_world_triplanar
	_check(walked_overlays_mapped, "the Aft stair ramp and the Habitat connector/corridor/common floor overlays carry the station panel family")

	var mapped_pressure_plates := 0
	if aft != null:
		var aft_materials := aft.get("_materials") as Dictionary
		var plate_materials := [aft_materials.get("hull_dark_floor"), aft_materials.get("mid_grey_floor")]
		for candidate in aft.get_node(^"Structure/OperationsRoom").find_children("*", "MeshInstance3D", true, false):
			var plate := candidate as MeshInstance3D
			if plate.mesh == null or plate.mesh.get_surface_count() == 0:
				continue
			var plate_material := plate.get_active_material(0) as StandardMaterial3D
			if plate_material == null or not plate_materials.has(plate_material):
				continue
			if plate_material.albedo_texture != null \
					and plate_material.albedo_texture.resource_path == "res://assets/materials/procedural-panel-triplanar-albedo-v2.png" \
					and plate_material.uv1_world_triplanar:
				mapped_pressure_plates += 1
	_check(mapped_pressure_plates == 9, "all nine Aft operations-room floor pressure plates read as mapped station floor, not unmapped voids")


func _surface_material(owner: Node3D, path: NodePath) -> Material:
	var body := owner.get_node_or_null(path) as StaticBody3D
	if body == null:
		return null
	if owner is FabricationAnnex:
		var surface_id := StringName(body.get_meta(&"walkable_surface_id", &""))
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		var floor_batch := owner.get_node_or_null(^"GeneratedAnnex/FloorSlabRenderBatch") as MeshInstance3D
		for part_variant in floor_batch.get_meta(&"fabrication_floor_render_parts", []) as Array if floor_batch != null else []:
			var part := part_variant as Dictionary
			if StringName(part.get("id", &"")) == surface_id \
					and shape != null \
					and (part.get("size", Vector3.ZERO) as Vector3).is_equal_approx(shape.size) \
					and (part.get("transform", Transform3D.IDENTITY) as Transform3D).origin.is_equal_approx(body.position):
				return floor_batch.material_override
		for raw_batch in owner.find_children("*", "MultiMeshInstance3D", true, false):
			var batch := raw_batch as MultiMeshInstance3D
			if not batch.has_meta(&"fabrication_annex_batch_key") \
					or batch.multimesh == null or batch.multimesh.mesh == null \
					or shape == null \
					or not batch.multimesh.mesh.get_aabb().size.is_equal_approx(shape.size):
				continue
			for transform_variant in _authored_batch_transforms(batch):
				var transform := transform_variant as Transform3D
				if transform.origin.is_equal_approx(body.position) \
						and transform.basis.is_equal_approx(Basis.IDENTITY):
					return batch.material_override
	var mesh_instance := body.get_node_or_null(^"Mesh") as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = body.get_node_or_null(^"RampMesh") as MeshInstance3D
	if mesh_instance == null:
		for candidate in body.find_children("*", "MeshInstance3D", false, false):
			mesh_instance = candidate as MeshInstance3D
			break
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return null
	return mesh_instance.get_active_material(0)


func _is_live_ship_mesh(mesh_instance: MeshInstance3D, world: ShipyardWorld) -> bool:
	var cursor := mesh_instance.get_parent()
	while cursor != null and cursor != world:
		if cursor is HeroShip:
			return true
		cursor = cursor.get_parent()
	return false


func _test_discovered_walkable_surface_support(world: ShipyardWorld) -> void:
	# This intentionally supplements the curated ownership roster. It discovers
	# every broad, thin, upward-facing mesh whose top centre lies in a reachable
	# route envelope, including visual-only tread and floor-detail overlays.
	var route_envelopes := [
		AABB(Vector3(-60.0, -0.2, -69.0), Vector3(120.0, 1.0, 129.0)),
		# Garden bay added beyond the old world-x=60 station envelope. Kept local
		# rather than widening the whole-station box into unrelated dressing.
		AABB(Vector3(61.0, -0.2, -6.1), Vector3(16.4, 1.0, 12.0)),
		AABB(Vector3(-14.0, -0.1, 4.3), Vector3(5.0, 3.7, 6.8)),
		AABB(Vector3(-8.0, -0.1, 49.0), Vector3(4.7, 4.7, 12.5)),
		AABB(Vector3(-12.0, 3.9, 60.0), Vector3(67.0, 1.2, 63.0)),
		AABB(Vector3(49.5, 4.0, 57.0), Vector3(5.0, 3.2, 13.0)),
		AABB(Vector3(48.8, -0.2, 23.6), Vector3(43.6, 1.2, 29.0)),
	]
	var candidates := 0
	var supported := 0
	var explicitly_tagged_decorations := 0
	var unsupported_paths := PackedStringArray()
	var unreasoned_visual_paths := PackedStringArray()
	var space := world.get_world_3d().direct_space_state
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		var exclusion_reason := _intentional_non_walkable_reason(mesh_instance, world)
		if not exclusion_reason.is_empty():
			explicitly_tagged_decorations += 1
			continue
		var local_aabb := mesh_instance.mesh.get_aabb()
		var local_size := local_aabb.size
		var world_up := mesh_instance.global_basis.y.normalized()
		var top_local := local_aabb.position + Vector3(local_size.x * 0.5, local_size.y, local_size.z * 0.5)
		var top_world := mesh_instance.global_transform * top_local
		var in_route_envelope := false
		for envelope: AABB in route_envelopes:
			if envelope.has_point(top_world):
				in_route_envelope = true
				break
		var broad_thin_upward := local_size.x >= 0.65 \
			and local_size.z >= 0.65 \
			and local_size.y <= 0.82 \
			and world_up.dot(Vector3.UP) >= 0.72
		if not broad_thin_upward or not in_route_envelope:
			if bool(mesh_instance.get_meta("non_authoritative_visual", false)):
				if str(mesh_instance.get_meta("non_walkable_reason", "")).is_empty():
					unreasoned_visual_paths.append(str(mesh_instance.get_path()))
				else:
					explicitly_tagged_decorations += 1
			continue

		candidates += 1
		var ray := PhysicsRayQueryParameters3D.create(
			top_world + Vector3.UP * 0.08,
			top_world + Vector3.DOWN * 0.55,
			WORLD_LAYER
		)
		ray.collide_with_areas = false
		ray.collide_with_bodies = true
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			unsupported_paths.append(str(mesh_instance.get_path()))
		else:
			supported += 1
	unsupported_paths.sort()
	unreasoned_visual_paths.sort()
	print(
		"DISCOVERED_STATION_SURFACES: candidates=", candidates,
		" supported=", supported,
		" tagged_decorations=", explicitly_tagged_decorations,
		" unsupported=", unsupported_paths
	)
	_check(candidates >= 42, "discovery independently finds at least the complete curated route-surface count")
	_check(unsupported_paths.is_empty(), "every discovered broad/thin upward route mesh has immediate World collision support below")
	_check(unreasoned_visual_paths.is_empty(), "every intentionally non-authoritative station visual carries an explicit non-walkable reason")
	_check(explicitly_tagged_decorations > 0, "discovery explicitly excludes tagged nonblocking presentation with a stable reason")


func _test_fleet_expansion_surface_honesty(world: ShipyardWorld) -> void:
	var berths := world.get_node_or_null(
		^"FleetExpansionProductionBinding/FleetExpansionBerths"
	) as Node3D
	var circulation := berths.get_node_or_null(^"AccessCirculation") as Node3D \
		if berths != null else null
	var exact := circulation != null
	var gross := 0.0
	var route_bodies := circulation.find_children("*", "StaticBody3D", true, false) \
		if circulation != null else []
	for raw_body in route_bodies:
		var body := raw_body as StaticBody3D
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		var surface := body.get_node_or_null(^"Surface") as MeshInstance3D
		var mesh := surface.mesh as BoxMesh if surface != null else null
		exact = exact and shape != null and mesh != null and not collision.disabled \
			and shape.size.is_equal_approx(mesh.size) \
			and body.collision_layer == WORLD_LAYER and body.collision_mask == 0 \
			and bool(body.get_meta(&"walkable_surface", false)) \
			and StringName(body.get_meta(&"walkable_surface_owner", &"")) == &"fleet-expansion-berths" \
			and StringName(body.get_meta(&"walkable_surface_kind", &"")) == &"level" \
			and not StringName(body.get_meta(&"walkable_surface_id", &"")).is_empty()
		if shape != null:
			gross += shape.size.x * shape.size.z
	var broad_collision := world.find_children("WalkablePadCollision", "StaticBody3D", true, false)
	var broad_render := world.find_children("ServicePadSurface*", "MeshInstance3D", true, false)
	var audit := berths.call("get_access_circulation_audit") as Dictionary if berths != null else {}
	_check(
		exact and route_bodies.size() == 6 and is_equal_approx(gross, 57.4) \
		and is_equal_approx(float(audit.get("unique_horizontal_m2", -1.0)), 55.4) \
		and broad_collision.is_empty() and broad_render.is_empty(),
		"Fleet exposes only six visible/tagged Box routes at 57.4 gross / 55.4 unique m2 and no undeclared pad top"
	)


## The inverse of `_test_discovered_walkable_surface_support`, and the case
## nothing checked: **World collision with no visible geometry**.
##
## That test proves every visible route floor has collision under it. It cannot
## see the opposite defect — a solid, standable surface the renderer never draws.
## A player walking into one is standing on nothing, or is stopped by nothing;
## the 2026-08-16 report called it "an invisible barrier ... that you can sort of
## climb on". Two were live when this check was written, both at the central
## berth and both from a generic collision box outliving the authored shell that
## replaced its render slab:
##
##   `ExposedDockLattice/HeroBerthNode` was 27.0 m wide under a 25.5 m authored
##   shell, leaving a 0.75 x 32.75 m invisible ledge down each flank.
##   `OpenLaunchSpine/CentralBerthLaunchTransitionCollision` reached z = -28.0
##   with a top plane 0.095 m proud of the launch arm, while the shell it belongs
##   to stops at z = -27.75: a 25.5 x 0.25 m invisible lip across the runway.
##
## The sweep is deliberately structural rather than a roster: it rays down over
## the reachable envelopes and asks the renderer, not a list, whether anything is
## drawn where the physics says a player may stand. Tagged safety-rail envelopes
## are barriers rather than standable route surfaces; their open-rail visuals are
## verified by the owning module suites and intentionally do not cover the
## conservative collider's complete top face. Both individual meshes and every
## visible transform in a MultiMesh contribute drawn bounds. Hull collision on the live
## craft is out of scope here — that is a published per-ship contract audited by
## `tests/torrent_collision_art_alignment_test.gd` and friends — so only the
## World layer is swept.
func _test_no_station_collision_without_visible_geometry(world: ShipyardWorld) -> void:
	var envelopes := [
		AABB(Vector3(-80.0, -3.0, -70.0), Vector3(174.0, 12.0, 156.0)),
	]
	# One 2 m XZ bucket grid over every drawn mesh, so each probe column compares
	# against a handful of candidates instead of the whole 2800-mesh world.
	var buckets := {}
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		var box := (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs()
		_bucket_drawn_aabb(buckets, box)
	for candidate in world.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := candidate as MultiMeshInstance3D
		var multi := batch.multimesh
		if multi == null or multi.mesh == null or not batch.is_visible_in_tree():
			continue
		var visible_count := multi.visible_instance_count
		if visible_count < 0:
			visible_count = multi.instance_count
		var authored_transforms := _authored_batch_transforms(batch)
		for instance_index in visible_count:
			# MultiMesh buffers read back as identity under headless. Habitat batches
			# publish the same authored transform roster used to fill that buffer; use
			# it for structural audits and the live buffer when no roster is present.
			var instance_transform := (
				authored_transforms[instance_index] as Transform3D
				if authored_transforms.size() == multi.instance_count
				else multi.get_instance_transform(instance_index)
			)
			var drawn_transform := batch.global_transform * instance_transform
			var box := (drawn_transform * multi.mesh.get_aabb()).abs()
			_bucket_drawn_aabb(buckets, box)

	var space := world.get_world_3d().direct_space_state
	var orphans := {}
	var probes := 0
	var supported := 0
	for envelope: AABB in envelopes:
		var x := envelope.position.x
		while x <= envelope.end.x:
			var z := envelope.position.z
			while z <= envelope.end.z:
				var cursor := envelope.end.y
				for _level in 5:
					var ray := PhysicsRayQueryParameters3D.create(
						Vector3(x, cursor, z), Vector3(x, envelope.position.y, z), WORLD_LAYER
					)
					ray.collide_with_areas = false
					var hit := space.intersect_ray(ray)
					if hit.is_empty():
						break
					var point := hit.position as Vector3
					if (hit.normal as Vector3).dot(Vector3.UP) >= 0.6:
						var collider := hit.collider as Node
						if collider != null and bool(collider.get_meta(&"safety_rail", false)):
							cursor = point.y - 0.05
							continue
						probes += 1
						if _column_is_drawn(buckets, x, z, point.y):
							supported += 1
						else:
							var key := str(collider.get_path()) if collider != null else "<null>"
							if not orphans.has(key):
								orphans[key] = 0
							orphans[key] = int(orphans[key]) + 1
					cursor = point.y - 0.05
					if cursor <= envelope.position.y:
						break
				z += 0.5
			x += 0.5
	var orphan_names := PackedStringArray()
	for key: String in orphans:
		orphan_names.append("%s x%d" % [key, int(orphans[key])])
	orphan_names.sort()
	print(
		"STATION_COLLISION_WITHOUT_VISIBLE_GEOMETRY: standable_probes=", probes,
		" drawn=", supported,
		" orphans=", orphan_names
	)
	_check(probes >= 20000, "the inverse sweep reaches the whole reachable station footprint")
	_check(
		orphan_names.is_empty(),
		"every standable World collision surface in the station has visible geometry drawn at it"
	)


func _authored_batch_transforms(batch: MultiMeshInstance3D) -> Array:
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	if not authored.is_empty():
		return authored
	if not batch.has_meta(&"fabrication_annex_batch_key"):
		return []
	var owner: Node = batch.get_parent()
	while owner != null and not owner is FabricationAnnex:
		owner = owner.get_parent()
	if not owner is FabricationAnnex:
		return []
	var render: Dictionary = (owner as FabricationAnnex).get_render_submission_contract()
	return (render.authored_batch_transforms as Dictionary).get(
		String(batch.get_meta(&"fabrication_annex_batch_key", "")), []
	) as Array


## RUNWAY-SEAM-001. The 2026-08-16 report: "the runway here is PERFECT but it's
## slightly overlapping the walkway ... it causes a slight texture glitch".
##
## Measured on the live scene: the authored central-berth shell — the runway —
## renders its deck panels between y = -0.005 and y = 0.095 and recesses its
## service channels down to y = -0.110, over x = -12.75 … 12.75 by
## z = -27.75 … 7.75. Three generic lattice decks had their top face on the
## y = -0.020 plane *inside* that band and inside that footprint:
## `CentralJunction` (25.0 x 2.55 m of it), `JunctionLink` (13.0 x 9.0 m, wholly
## enclosed) and the already-hidden `HeroBerthNode`. Where the shell's channels
## are recessed the grey deck stood 0.090 m proud of the channel floor and read
## through it.
##
## The fix was geometric — the walkway now stops at the shell's own edge, the
## link's render slab is hidden the way the hero berth node's already was, and
## the collision that carries the floor moved with them. Nothing about depth
## write, render priority or material was touched, so this check is written
## against geometry only: nothing the station draws may have a surface inside the
## shell's rendered band where their footprints overlap.
func _test_lattice_decks_do_not_share_the_authored_runway_volume(world: ShipyardWorld) -> void:
	var shell := world.get_node_or_null(
		^"LandingPad/CentralBerthHeroPresentation/CentralBerthHeroImport/CentralBerthHeroArt"
	) as Node3D
	if shell == null:
		_check(false, "the authored central-berth shell resolves for the runway-seam check")
		return
	var shell_meshes: Array[MeshInstance3D] = []
	var footprint := AABB()
	var first := true
	for candidate in shell.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		shell_meshes.append(mesh_instance)
		var box := (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs()
		if first:
			footprint = box
			first = false
		else:
			footprint = footprint.merge(box)
	# The shell's own walking-surface band, re-measured from the live import so a
	# re-export that moves it fails here instead of silently re-opening the seam.
	# It is exactly the deck plate and the channels recessed into it; the outer
	# edge fascia and the deep primary/secondary structure are the shell's skirt
	# and keel and belong below the walkway, not in this band.
	var band_low := INF
	var band_high := -INF
	var band_sources := 0
	for mesh_instance in shell_meshes:
		if mesh_instance.name not in ["deck_panels__DeckComposite", "service_channels__ServiceGraphite"]:
			continue
		band_sources += 1
		var box := (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs()
		band_low = minf(band_low, box.position.y)
		band_high = maxf(band_high, box.end.y)
	_check(band_sources == 2, "the authored runway shell still publishes its deck plate and recessed service channels")
	if band_sources != 2:
		return
	print("AUTHORED_RUNWAY_SHELL: footprint=", footprint, " surface_band=", band_low, " .. ", band_high)
	_check(
		is_equal_approx(band_low, -0.11) and is_equal_approx(band_high, 0.095),
		"the authored runway shell still renders its surfaces across the frozen -0.110 .. 0.095 band"
	)

	var intruders := PackedStringArray()
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		if shell.is_ancestor_of(mesh_instance):
			continue
		var box := (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs()
		var overlap_x: float = minf(box.end.x, footprint.end.x) - maxf(box.position.x, footprint.position.x)
		var overlap_z: float = minf(box.end.z, footprint.end.z) - maxf(box.position.z, footprint.position.z)
		if overlap_x <= 0.0 or overlap_z <= 0.0 or overlap_x * overlap_z < 0.25:
			continue
		# A piece resting on the shell (pad rings, chevrons, clamps, berth cue) is
		# above the band; a keel or under-brace is below it. Only a surface *inside*
		# the band shares the shell's volume.
		if box.end.y <= band_low + 0.001 or box.end.y >= band_high - 0.002:
			continue
		intruders.append("%s top=%.4f overlap=%.2f m2" % [
			str(mesh_instance.get_path()).replace("/root/Main/ShipyardWorld/", ""),
			box.end.y,
			overlap_x * overlap_z
		])
	intruders.sort()
	print("RUNWAY_SHELL_VOLUME_INTRUDERS: ", intruders)
	_check(
		intruders.is_empty(),
		"no station surface renders inside the authored runway shell's own surface band where they overlap"
	)
	_check(
		world.find_children("PadBorder", "MeshInstance3D", true, false).is_empty(),
		"the authored central-berth margins replace the legacy PadBorder overlays that penetrated them"
	)


func _column_is_drawn(buckets: Dictionary, x: float, z: float, surface_y: float) -> bool:
	var key := "%d:%d" % [int(floor(x / 2.0)), int(floor(z / 2.0))]
	if not buckets.has(key):
		return false
	for box: AABB in buckets[key] as Array:
		if x < box.position.x - 0.06 or x > box.end.x + 0.06:
			continue
		if z < box.position.z - 0.06 or z > box.end.z + 0.06:
			continue
		if surface_y < box.position.y - 0.25 or surface_y > box.end.y + 0.25:
			continue
		return true
	return false


func _bucket_drawn_aabb(buckets: Dictionary, box: AABB) -> void:
	var ix_min := int(floor((box.position.x - 0.1) / 2.0))
	var ix_max := int(floor((box.end.x + 0.1) / 2.0))
	var iz_min := int(floor((box.position.z - 0.1) / 2.0))
	var iz_max := int(floor((box.end.z + 0.1) / 2.0))
	for ix in range(ix_min, ix_max + 1):
		for iz in range(iz_min, iz_max + 1):
			var key := "%d:%d" % [ix, iz]
			if not buckets.has(key):
				buckets[key] = []
			(buckets[key] as Array).append(box)


func _intentional_non_walkable_reason(mesh_instance: MeshInstance3D, world: ShipyardWorld) -> String:
	if bool(mesh_instance.get_meta("non_authoritative_visual", false)):
		return str(mesh_instance.get_meta("non_walkable_reason", ""))
	var cursor := mesh_instance.get_parent()
	var declaring_activity: StationOperationsActivity = null
	var activity_cursor := cursor
	while activity_cursor != null and activity_cursor != world:
		if activity_cursor is StationOperationsActivity:
			declaring_activity = activity_cursor as StationOperationsActivity
			break
		activity_cursor = activity_cursor.get_parent()
	while cursor != null and cursor != world:
		if bool(cursor.get_meta("presentation_only", false)) and bool(cursor.get_meta("nonblocking_collision", false)):
			# The reusable component still owns no physics, but some exact static
			# meshes now declare sibling World collision. Do not exempt those drawn
			# surfaces merely because their presentation ancestor remains tagged.
			if declaring_activity != null \
				and _mesh_matches_declared_solid(mesh_instance, declaring_activity):
				return ""
			return "tagged presentation-only component with collision_policy=presentation_only_nonblocking"
		cursor = cursor.get_parent()
	return ""


func _mesh_matches_declared_solid(
		mesh_instance: MeshInstance3D,
		activity: StationOperationsActivity
	) -> bool:
	if mesh_instance.mesh == null:
		return false
	var activity_local := activity.global_transform.affine_inverse() * mesh_instance.global_transform
	var mesh_size := mesh_instance.mesh.get_aabb().size
	for volume in activity.get_solid_volume_contract():
		var expected := Transform3D(
			volume.get("basis", Basis.IDENTITY) as Basis,
			volume.position as Vector3
		)
		if activity_local.is_equal_approx(expected) \
			and mesh_size.is_equal_approx(volume.size as Vector3):
			return true
	return false


func _test_spawn_adjacent_stair(world: ShipyardWorld, player: PlayerController) -> void:
	var start := Vector3(-11.5, 0.18, 10.8)
	var ramp := world.get_node_or_null(^"UpperOperations/JunctionAccessRamp") as StaticBody3D
	var rendered_ramp := ramp.get_node_or_null(^"Mesh") as MeshInstance3D if ramp != null else null
	var result := await _walk_forward_until(
		player,
		Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), start),
		func() -> bool:
			return player.global_position.y >= 2.9 and player.global_position.z <= 5.3,
		180,
		false,
		func(player_position: Vector3) -> float:
			return _vertical_distance_to_rendered_ramp(ramp, rendered_ramp, player_position)
	)
	print("CENTRAL_STAIR_TRAVERSAL: ", result)
	_check(bool(result.reached), "continuous W reaches the spawn-adjacent observation landing without jumping")
	_check(float(result.maximum_y) >= 2.9, "spawn-adjacent stair raises the production capsule to the landing")
	_check(not bool(result.fell), "spawn-adjacent stair remains continuously supported")
	_check(int(result.visible_surface_samples) >= 20, "central traversal samples the rendered walking surface throughout the climb")
	_check(float(result.maximum_visible_surface_distance) <= 0.10, "production capsule feet stay within 0.10 m of the rendered central ramp plane during continuous W")

	_check(ramp != null and ramp.collision_layer == WORLD_LAYER and ramp.collision_mask == 0, "spawn-adjacent visible treads use one snag-free World collision ramp")
	if ramp != null:
		var ramp_shapes := ramp.find_children("*", "CollisionShape3D", true, false)
		_check(ramp_shapes.size() == 1, "spawn-adjacent stair owns exactly one continuous collision shape")
		var mesh_instance := ramp.get_node_or_null(^"Mesh") as MeshInstance3D
		var collision := ramp.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		_check(
			mesh_instance != null and mesh_instance.mesh != null and shape != null \
				and mesh_instance.mesh.get_aabb().size.distance_to(shape.size) <= 0.001,
			"central ramp renders the exact same bounds as its authoritative collision"
		)

	var treads := world.get_node(^"UpperOperations").find_children("JunctionAccessTread*", "MeshInstance3D", false, false)
	var exact_tread_roster := treads.size() == 7
	var maximum_tread_edge_delta := 0.0
	for tread_index in 7:
		var tread := world.get_node_or_null(NodePath("UpperOperations/JunctionAccessTread%02d" % (tread_index + 1))) as MeshInstance3D
		exact_tread_roster = exact_tread_roster and tread != null
		if tread == null or tread.mesh == null:
			continue
		var half_size := tread.mesh.get_aabb().size * 0.5
		var tread_top := tread.global_position.y + half_size.y
		for edge_z in [tread.global_position.z - half_size.z, tread.global_position.z + half_size.z]:
			var tread_edge := Vector3(tread.global_position.x, tread_top, float(edge_z))
			maximum_tread_edge_delta = maxf(
				maximum_tread_edge_delta,
				_vertical_distance_to_rendered_ramp(ramp, rendered_ramp, tread_edge)
			)
	_check(exact_tread_roster, "central stair exposes seven uniquely named tread overlays with no duplicate fallback names")
	_check(maximum_tread_edge_delta <= 0.08, "every visible tread edge stays within 0.08 m of the rendered/colliding ramp surface")

	var blocking_mast: StaticBody3D = null
	for candidate in world.get_node(^"ExposedDockLattice").find_children("DockMast*", "StaticBody3D", false, false):
		var mast := candidate as StaticBody3D
		if mast.global_position.is_equal_approx(Vector3(-11.0, 5.2, 14.0)):
			blocking_mast = mast
			break
	_check(blocking_mast == null, "the port dock mast no longer blocks the CentralJunction walkway")
	_check(
		world.get_node_or_null(^"CentralBerthServiceLine/DockMastFoot00") == null,
		"the removed walkway mast leaves no detached foot assembly"
	)


func _vertical_distance_to_rendered_ramp(
		ramp: StaticBody3D,
		rendered_ramp: MeshInstance3D,
		world_point: Vector3
	) -> float:
	if ramp == null or rendered_ramp == null or rendered_ramp.mesh == null:
		return NAN
	var half_size := rendered_ramp.mesh.get_aabb().size * 0.5
	var plane_point := ramp.global_transform * Vector3(0.0, half_size.y, 0.0)
	var plane_normal := ramp.global_basis.y.normalized()
	var vertical_denominator := plane_normal.dot(Vector3.UP)
	if absf(vertical_denominator) < 0.001:
		return NAN
	var vertical_delta := plane_normal.dot(world_point - plane_point) / vertical_denominator
	var projected_local := ramp.to_local(world_point - Vector3.UP * vertical_delta)
	if absf(projected_local.x) > half_size.x + 0.001 or absf(projected_local.z) > half_size.z + 0.001:
		return NAN
	return absf(vertical_delta)


func _test_aft_stair_mount_and_climb(world: ShipyardWorld, player: PlayerController) -> void:
	var aft := world.get_node_or_null(^"AftJunctionStack") as AftJunctionStack
	if aft == null:
		_check(false, "Aft stair module resolves for physical traversal")
		return
	# Exercise the west frontage lane that is inside the visible tread width but
	# was formerly outside the lower landing by 0.20 m at this Player root.
	var local_start := Vector3(-7.0, 0.18, 1.75)
	var world_direction := (aft.global_basis * Vector3.BACK).normalized()
	var result := await _walk_forward_until(
		player,
		Transform3D(Basis.looking_at(world_direction, Vector3.UP), aft.to_global(local_start)),
		func() -> bool:
			var local := aft.to_local(player.global_position)
			return local.y >= 3.85 and local.z >= 12.0,
		190,
		true
	)
	print("AFT_STAIR_TRAVERSAL: ", result)
	_check(bool(result.reached), "continuous W mounts the west edge of the Aft first tread and reaches the upper floor")
	_check(not bool(result.fell), "Aft west-frontage approach and ramp remain continuously supported")
	var landing := aft.get_node_or_null(^"Structure/LowerOpenDeck/StairBaseLanding") as StaticBody3D
	var landing_mesh := landing.get_node_or_null(^"Mesh") as MeshInstance3D if landing != null else null
	var landing_collision := landing.get_node_or_null(^"Collision") as CollisionShape3D if landing != null else null
	var landing_shape := landing_collision.shape as BoxShape3D if landing_collision != null else null
	var landing_size := landing_mesh.mesh.get_aabb().size if landing_mesh != null and landing_mesh.mesh != null else Vector3.ZERO
	var landing_west_edge := landing.position.x - landing_size.x * 0.5 if landing != null else INF
	var landing_east_edge := landing.position.x + landing_size.x * 0.5 if landing != null else INF
	_check(
		landing != null \
		and landing.collision_layer == WORLD_LAYER \
		and landing.collision_mask == 0 \
		and landing_shape != null \
		and landing_shape.size.is_equal_approx(landing_size) \
		and is_equal_approx(landing_west_edge, -7.16) \
		and is_equal_approx(landing_east_edge, -2.4),
		"Aft lower landing visibly and physically covers the full tread frontage while retaining its east edge"
	)


func _test_fleet_comb_ramp(world: ShipyardWorld, player: PlayerController) -> void:
	var comb := world.get_node_or_null(^"FleetDockComb") as FleetDockComb
	if comb == null:
		_check(false, "Fleet Dock Comb resolves for physical ramp traversal")
		return
	var local_start := Vector3(0.6, 0.18, 40.0)
	var world_direction := (comb.global_basis * Vector3.RIGHT).normalized()
	var result := await _walk_forward_until(
		player,
		Transform3D(Basis.looking_at(world_direction, Vector3.UP), comb.to_global(local_start)),
		func() -> bool:
			var local := comb.to_local(player.global_position)
			return local.x >= 9.1 and local.y >= 2.2,
		150,
		true
	)
	print("FLEET_COMB_RAMP_TRAVERSAL: ", result)
	_check(bool(result.reached), "continuous W climbs the Fleet Dock Comb ramp without jumping")
	_check(not bool(result.fell), "Fleet Dock Comb ramp remains continuously supported")


func _walk_forward_until(
		player: PlayerController,
		start: Transform3D,
		reached_predicate: Callable,
		maximum_frames: int,
		sprint: bool = false,
		visible_surface_distance: Callable = Callable()
	) -> Dictionary:
	_release_actions()
	player.teleport_to(start)
	for _settle in 8:
		await physics_frame
	var initial := player.global_position
	var maximum_y := initial.y
	var minimum_y := initial.y
	var grounded_frames := 0
	var reached := false
	var visible_surface_samples := 0
	var maximum_visible_surface_distance := 0.0
	var maximum_visible_surface_distance_position := Vector3.ZERO
	Input.action_press(&"move_forward")
	if sprint:
		Input.action_press(&"sprint_boost")
	for _frame in maximum_frames:
		await physics_frame
		maximum_y = maxf(maximum_y, player.global_position.y)
		minimum_y = minf(minimum_y, player.global_position.y)
		if player.is_on_floor():
			grounded_frames += 1
		if visible_surface_distance.is_valid():
			var surface_distance := float(visible_surface_distance.call(player.global_position))
			if is_finite(surface_distance):
				visible_surface_samples += 1
				if surface_distance > maximum_visible_surface_distance:
					maximum_visible_surface_distance = surface_distance
					maximum_visible_surface_distance_position = player.global_position
		if reached_predicate.call():
			reached = true
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint_boost")
	await physics_frame
	return {
		"reached": reached,
		"initial": initial,
		"final": player.global_position,
		"maximum_y": maximum_y,
		"minimum_y": minimum_y,
		"grounded_frames": grounded_frames,
		"fell": minimum_y < initial.y - 0.65,
		"visible_surface_samples": visible_surface_samples,
		"maximum_visible_surface_distance": maximum_visible_surface_distance,
		"maximum_visible_surface_distance_position": maximum_visible_surface_distance_position,
	}


func _release_actions() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)


func _capture_fabrication_integration_frame(game: GameFlow, world: ShipyardWorld) -> void:
	var annex := world.get_node_or_null(^"FabricationAnnex") as FabricationAnnex
	var connector := world.get_node_or_null(^"ExposedDockLattice/FabricationAnnexConnector") as Node3D
	_check(annex != null and connector != null, "integrated Forward+ frame resolves the live Annex and connector")
	if annex == null or connector == null:
		return
	var hud := game.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var camera := Camera3D.new()
	camera.name = "FabricationIntegrationEvidenceCamera"
	camera.position = Vector3(112.0, 34.0, 8.0)
	camera.look_at_from_position(camera.position, Vector3(70.0, 0.8, 38.0), Vector3.UP)
	camera.fov = 52.0
	camera.current = true
	game.add_child(camera)
	for _frame in 8:
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var output_path := "/tmp/fabrication-annex-integrated-forward-plus.png"
	var error := image.save_png(output_path)
	_check(
		error == OK and image.get_width() >= 1280 and image.get_height() >= 720,
		"exactly one normal-resolution integrated Forward+ frame is captured"
	)
	print("FABRICATION_INTEGRATED_FRAME: %s %s" % [output_path, image.get_size()])


func _capture_observation_integration_frame(game: GameFlow, world: ShipyardWorld) -> void:
	var spur := world.get_node_or_null(^"ObservationLogisticsSpur") as ObservationLogisticsSpur
	var connector := world.get_node_or_null(^"ExposedDockLattice/ObservationLogisticsConnector") as Node3D
	var annex := world.get_node_or_null(^"FabricationAnnex") as FabricationAnnex
	_check(spur != null and connector != null and annex != null, "integrated Forward+ frame resolves Observation, its world connector, and Fabrication gate")
	if spur == null or connector == null or annex == null:
		return
	var hud := game.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var camera := Camera3D.new()
	camera.name = "ObservationIntegrationEvidenceCamera"
	camera.position = Vector3(154.0, 38.0, 7.0)
	camera.look_at_from_position(camera.position, Vector3(111.0, 1.0, 38.0), Vector3.UP)
	camera.fov = 55.0
	camera.current = true
	game.add_child(camera)
	for _frame in 8:
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var output_path := "/tmp/observation-logistics-integrated-forward-plus.png"
	var error := image.save_png(output_path)
	_check(
		error == OK and image.get_width() >= 1280 and image.get_height() >= 720,
		"exactly one normal-resolution integrated Observation Forward+ frame is captured"
	)
	print("OBSERVATION_INTEGRATED_FRAME: %s %s" % [output_path, image.get_size()])


func _capture_salvage_integration_frame(game: GameFlow, world: ShipyardWorld) -> void:
	var salvage := world.get_node_or_null(^"SalvageTerrace") as SalvageTerrace
	var connector := world.get_node_or_null(^"ExposedDockLattice/SalvageTerraceConnector") as Node3D
	var annex := world.get_node_or_null(^"FabricationAnnex") as FabricationAnnex
	_check(salvage != null and connector != null and annex != null, "integrated Forward+ frame resolves Salvage, its world connector, and Fabrication seam")
	if salvage == null or connector == null or annex == null:
		return
	var hud := game.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var camera := Camera3D.new()
	camera.name = "SalvageIntegrationEvidenceCamera"
	camera.position = Vector3(126.0, 32.0, 94.0)
	camera.look_at_from_position(camera.position, Vector3(88.0, 2.4, 58.0), Vector3.UP)
	camera.fov = 56.0
	camera.current = true
	game.add_child(camera)
	for _frame in 8:
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var output_path := "/tmp/salvage-terrace-integrated-forward-plus.png"
	var error := image.save_png(output_path)
	_check(
		error == OK and image.get_width() >= 1280 and image.get_height() >= 720,
		"exactly one normal-resolution integrated Salvage Forward+ frame is captured"
	)
	print("SALVAGE_INTEGRATED_FRAME: %s %s" % [output_path, image.get_size()])


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	_release_actions()
	if _failures.is_empty():
		print("STATION_SURFACE_PLAYABILITY_TEST_OK")
		quit(0)
	else:
		print("STATION_SURFACE_PLAYABILITY_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
