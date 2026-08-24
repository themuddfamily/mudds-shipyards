extends SceneTree

## Traversal regression for the 2026-08-15 human playtest report:
## "there's so many places that are difficult to get to, random objects floating
## in the air and it ruins the experience."
##
## This began as a deliberately RED witness for MAP-001 … MAP-006. It now guards
## the fixed P1 traversal defects (MAP-001, MAP-002, MAP-003) and is collected by
## `tools/release/run_test_matrix.sh`. Two deliberate changes were made when the
## defects were fixed, both recorded here rather than made quietly:
##
##  1. The three P2 presentation assertions (MAP-004 mirrored legends, MAP-005
##     hovering beacons, MAP-006 orphan lens) moved verbatim into
##     `tests/station_presentation_defect_witness.gd`. They are still RED and
##     still runnable; they are reserved for a separate presentation pass and
##     must not hold the traversal gate red in the meantime.
##  2. `_test_pod_deck_lip_is_climbable` compared the raised pod decks' top
##     surface against the lattice deck's top surface and required the
##     difference to be within one no-jump step. That geometric proxy is wrong.
##     It forbids a raised pod outright — even one with a correctly authored
##     threshold — and the only ways to satisfy it were a >= 0.40 m step assist
##     (a climbing tool, not a step) or moving decks whose coordinates
##     `docs/research/STATION_TOPOLOGY.md` pins as frozen evidence. It is
##     replaced by `_test_pod_decks_can_be_walked_into`, which runs MAP-002's own
##     recorded reproduction through the production controller and requires the
##     capsule to finish standing on the raised deck. That is strictly stronger:
##     it exercises the real route rather than a proxy for it.
##
## The suite contains no production-code change and no softened threshold. It
## measures the production PlayerController's real no-jump step capability,
## rebuilds a capsule-clearance walk graph over the live production collision
## world, floods it from the production spawn marker, and then asserts the
## roadmap's playable-prototype traversal contract:
##
##   "A no-cheat traversal from spawn reaches the Central berth, Aft upper level,
##    Habitat, Freight branch, and Fleet Dock walking surfaces without falling
##    through, snagging on decorative treads, or requiring an undocumented jump."
##
## Station doors are treated as openable (their portal blockers are excluded from
## every query) so a closed reusable door is never miscounted as a defect. Only
## a deferred landmark door stays solid, and there is one of those left: the Aft
## VIP door was opened when `VipReceptionSuite` was built behind it, so its
## portal now joins the flood and the reception floor is a reachable surface.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

const GRID := 0.25
const CAPSULE_RADIUS := 0.38
const CAPSULE_HEIGHT := 1.94
const MAX_LEVELS := 6
## cos(floor_max_angle) for the production capsule (50 degrees).
const WALKABLE_DOT := 0.6427
const SLOPE_RISE_LIMIT := GRID * 1.19175
const DROP_LIMIT := 4.0

const X_MIN := -80.0
const X_MAX := 134.0
const Z_MIN := -92.0
const Z_MAX := 86.0

## Route surfaces the roadmap requires an on-foot player to reach from spawn.
const REQUIRED_ROUTE_SURFACES := [
	["", "ExposedDockLattice/CentralJunction"],
	["", "ExposedDockLattice/HeroBerthNode"],
	["", "ExposedDockLattice/PortBerthNode"],
	["", "ExposedDockLattice/StarboardBerthNode"],
	["", "ExposedDockLattice/AftModuleConnector"],
	["", "ExposedDockLattice/FleetDockCombConnector/FleetDockCombConnectorDeck"],
	["", "ExposedDockLattice/FabricationAnnexConnector/ConnectorDeckA"],
	["", "ExposedDockLattice/FabricationAnnexConnector/ConnectorDeckB"],
	["", "ExposedDockLattice/FabricationAnnexConnector/ConnectorDeckC"],
	["", "ExposedDockLattice/ObservationLogisticsConnector/ConnectorDeck"],
	["", "ExposedDockLattice/SalvageTerraceConnector/ConnectorDeck"],
	["", "OpenLaunchSpine/LaunchArmDeck"],
	["", "UpperOperations/ObservationLanding"],
	["", "UpperOperations/OperationsPodFloor"],
	["", "ModernFleetRegistry/RegistryPodDeck"],
	["AftJunctionStack", "Structure/LowerOpenDeck/StairBaseLanding"],
	["AftJunctionStack", "Structure/Circulation/ContinuousStairRamp"],
	["AftJunctionStack", "Structure/UpperOpenDeck/UpperFloor"],
	["AftJunctionStack", "Structure/OperationsRoom/OperationsFloor"],
	["HabitatSpine", "Structure/PressurizedHabitatCorridor/HabitatFloor"],
	["HabitatSpine", "Structure/ObservationCommon/CommonFloor"],
	# The side branch. Its door was locked and explicitly deferred, so there was
	# nothing to require; it opens onto a built garden bay now, and the strongest
	# statement available that the room is real is that the production flood fill
	# reaches its deck from the player spawn through every door on the way.
	["HabitatSpine", "Structure/SideBranchGarden/BranchLink/LinkFloor"],
	["HabitatSpine", "Structure/SideBranchGarden/GardenShell/GardenFloor"],
	["JovianFreightBerth", "ConnectionLattice/ConnectionDeckA"],
	["JovianFreightBerth", "LoadingApron/ApronDeck01"],
	["JovianFreightBerth", "LoadingApron/ApronDeck03"],
	["JovianFreightBerth", "FreightControlRoom/RoomFloor"],
	["FleetDockComb", "GeneratedComb/WalkableSurfaces/Trunk"],
	["FleetDockComb", "GeneratedComb/WalkableSurfaces/DockSlab01"],
	["FleetDockComb", "GeneratedComb/WalkableSurfaces/DockSlab03Upper"],
	["FabricationAnnex", "GeneratedAnnex/ConnectorApron"],
	["FabricationAnnex", "GeneratedAnnex/CentralThroughAisle"],
	["FabricationAnnex", "GeneratedAnnex/PortWorkBay"],
	["FabricationAnnex", "GeneratedAnnex/StarboardWorkBay"],
	["FabricationAnnex", "GeneratedAnnex/PortSideBypass"],
	["FabricationAnnex", "GeneratedAnnex/StarboardSideBypass"],
	["FabricationAnnex", "GeneratedAnnex/RearCrossAisle"],
	["ObservationLogisticsSpur", "Structure/Walkable/ExposedConnectorDeck"],
	["ObservationLogisticsSpur", "Structure/Walkable/PadCrossLanding"],
	["ObservationLogisticsSpur", "Structure/Walkable/ObservationPad"],
	["ObservationLogisticsSpur", "Structure/Walkable/LogisticsPad"],
	["ObservationLogisticsSpur", "Structure/Walkable/FarReturnBridge"],
	["SalvageTerrace", "GeneratedRoot/ConnectionApron"],
	["SalvageTerrace", "GeneratedRoot/LowerSalvagePad"],
	["SalvageTerrace", "GeneratedRoot/MainServiceRamp"],
	["SalvageTerrace", "GeneratedRoot/UpperInspectionPad"],
	["SalvageTerrace", "GeneratedRoot/InspectionRamp"],
	["SalvageTerrace", "GeneratedRoot/TopInspectionPad"],
	["VipReceptionSuite", "Structure/Threshold/ThresholdFloor"],
	["VipReceptionSuite", "Structure/Reception/FloorPlateFront"],
	["VipReceptionSuite", "Structure/Reception/WellPan"],
]

## MAP-002's own recorded reproductions. Each entry is a lattice-deck standing
## point in front of a raised deck, the minimum Z the capsule must reach on that
## raised deck, and why that Z is the right stopping point.
## The recorded registry-pod approach at x = -43.0 stands inside the parked
## ArrowReconShip's hull, so the capsule starts overlapping a ship rather than on
## the lattice deck. The approach is moved 3.5 m west along the same 12 m pod
## frontage; the lip being crossed is identical.
const POD_WALK_INS := [
	["UpperOperations/OperationsPodFloor", Vector3(43.0, 0.18, 21.0), 23.5,
		"inside the operations pod through its threshold-aligned central doorway"],
	["ModernFleetRegistry/RegistryPodDeck", Vector3(-46.5, 0.18, 21.0), 26.0,
		"onto the fleet registry pod deck, whose terminal interaction MAP-002 made unreachable"],
	["JovianFreightBerth/ConnectionLattice/ConnectionDeckA", Vector3(-47.0, 0.18, 21.0), 26.0,
		"out along the freight branch connection lattice"],
]
## PORT-DECK-001. The 2026-08-16 report: "the walkway to enter isn't wide enough
## to get around to the side — you can get in this one by jumping over the rails".
##
## The port berth node is 17 m deep and the parked Arrow's wing spans z = 9.95 …
## 21.05 of it, so the walkable lane beside the craft is the ~2.5 m strip at each
## end plus the aprons off its nose and tail. Reaching any of them used to mean
## crossing a 1.24 m `BranchRail`: the rails ran 5 m past the branch arm and
## across the node, and the only gap in them was underneath the wing.
##
## These four points are one standable cell on each face of the parked craft. All
## four must be in the no-jump flood from the production spawn marker.
const ARROW_BERTH_WALKAROUND_POINTS := [
	[Vector3(-47.0, -0.02, 8.5), "starboard flank, outboard of the sensor wing"],
	[Vector3(-47.0, -0.02, 20.5), "port flank, outboard of the sensor wing"],
	[Vector3(-50.5, -0.02, 15.5), "nose apron, on the 16.8 m deck the 12.2 m craft used to overhang"],
	[Vector3(-36.0, -0.02, 15.5), "tail apron, where the branch arm hands off to the node"],
]

## HALYARD-DECK-001. The 2026-08-16 report, second craft: "I wasn't able to get
## on the new ship, its way too big for its stand ... extend the walkway and then
## give it a much larger square so you can walk all the way around it".
##
## Measured before the fix: the Halyard's collision footprint is 9.6 x 28.35 m
## and Fleet Dock 02's slab was 12.0 x 12.0 m, so 7.85 m of nose and 8.50 m of
## tail stood over open space and two of four footprint corners had nothing
## beneath them. The only walkable approach was the comb's 3.6 m `Rung02`, which
## delivered a player into a dead end at each flank.
##
## These four points are one standable cell on each face of the parked craft, at
## the y = 4.2 fleet-dock elevation. All four must be in the no-jump flood from
## the production spawn marker.
const HALYARD_BERTH_WALKAROUND_POINTS := [
	[Vector3(42.0, 4.2, 53.3), "starboard flank, outboard of the cabin wall"],
	[Vector3(32.0, 4.2, 53.3), "port flank, at the foot of the airstair"],
	[Vector3(37.0, 4.2, 37.5), "nose apron, on deck that did not exist ahead of the bow collar"],
	[Vector3(33.1, 4.2, 62.6), "aft apron, in the 6.6 m gap that used to be open space"],
]
## Top of the Fleet Dock decks: the comb's trunk, rungs and slabs, and the berth
## apron the world adds around slab 02. All of them are one flush plane.
const FLEET_DOCK_DECK_TOP := 4.2

## PORT-BOARDING-001. The same report, refined: "the option to enter never
## appears when you're standing to the side of the ship". A single staged
## approach vector cannot see that — `tests/fleet_role_differentiation_test.gd`
## walks one and passes — so this samples a ring around each parked craft instead
## and requires the prompt from every standable point on it.
const BOARDING_RING_RADII := [3.0, 5.0, 7.0]
const BOARDING_RING_SAMPLES := 16

## Top of every raised pod deck the walk-ins have to finish standing on.
const POD_DECK_TOP := 0.38
## Top of the lattice berth nodes the walk-ins start from.
const LATTICE_DECK_TOP := -0.02
const POD_WALK_TOLERANCE := 0.08

var _failures: Array[String] = []
var _space: PhysicsDirectSpaceState3D
var _capsule: CapsuleShape3D
var _door_blockers: Array[RID] = []
var _clear_heights: Dictionary = {}
var _clear_normals: Dictionary = {}
var _step_limit := 0.14


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_step_limit = await _measure_no_jump_step_height()
	print("MEASURED_NO_JUMP_STEP_HEIGHT: ", _step_limit)

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the traversal defect witness")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	for _settle in 8:
		await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var player := game.get_node_or_null(^"Player") as PlayerController
	_check(world != null and player != null, "production world and player capsule are live")
	if world == null or player == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	# The player body would otherwise occlude its own reachability sweep.
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
	await physics_frame

	_space = world.get_world_3d().direct_space_state
	_capsule = CapsuleShape3D.new()
	_capsule.radius = CAPSULE_RADIUS
	_capsule.height = CAPSULE_HEIGHT
	_collect_openable_door_blockers(world)

	var spawn_marker := world.get_node_or_null(^"%PlayerSpawn") as Marker3D
	_check(spawn_marker != null, "production spawn marker resolves")
	var spawn := spawn_marker.global_position if spawn_marker != null else Vector3(-8.5, 0.18, 11.0)

	_build_walk_graph()
	var reachable := _flood_from(spawn)
	print(
		"WALK_GRAPH: nodes=", _clear_node_count(),
		" reachable_no_jump=", reachable.size(),
		" spawn=", spawn
	)

	_test_required_route_surfaces_reachable(world, reachable)
	_test_freight_branch_has_a_walkable_approach(world)
	_test_every_flyable_ship_is_boardable_on_foot(game, world, reachable)
	_test_arrow_berth_can_be_walked_around(reachable)
	_test_halyard_berth_can_be_walked_around(reachable)
	_test_parked_craft_are_fully_supported_by_their_berth_decks(game, world)
	await _test_arrow_berth_rails_no_longer_fence_the_walkway(player)
	await _test_halyard_berth_is_one_continuous_loop(player)
	await _test_fabrication_annex_round_trip(player)
	await _test_observation_logistics_round_trip(player)
	await _test_salvage_terrace_round_trip(player)
	await _test_boarding_prompt_is_offered_all_round_each_craft(game, player)
	await _test_pod_decks_can_be_walked_into(player)
	await _test_aft_stair_base_is_not_fenced_off(player)

	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	_finish()


## Drives the real PlayerController into synthetic lips to record the exact
## height it can mount with continuous forward input and no jump.
func _measure_no_jump_step_height() -> float:
	var best := 0.0
	for height in [0.05, 0.10, 0.14, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45]:
		if await _probe_step(float(height)):
			best = maxf(best, float(height))
	return best


func _probe_step(height: float) -> bool:
	var rig := Node3D.new()
	root.add_child(rig)
	rig.add_child(_slab(Vector3(8.0, 1.0, 8.0), Vector3(0.0, -0.5, 0.0)))
	rig.add_child(_slab(Vector3(8.0, 1.0 + height, 8.0), Vector3(0.0, -0.5 + height * 0.5, -8.0)))
	var player := PLAYER_SCENE.instantiate() as PlayerController
	rig.add_child(player)
	await process_frame
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 2.0)))
	for _settle in 10:
		await physics_frame
	Input.action_press(&"move_forward")
	var climbed := false
	for _frame in 150:
		await physics_frame
		if player.global_position.z < -4.5 and player.global_position.y >= height - 0.02:
			climbed = true
			break
	Input.action_release(&"move_forward")
	await physics_frame
	rig.queue_free()
	await process_frame
	return climbed


func _slab(size: Vector3, slab_position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = slab_position
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	return body


func _collect_openable_door_blockers(world: ShipyardWorld) -> void:
	for candidate in world.find_children("*", "StationDoor", true, false):
		var door := candidate as StationDoor
		if door.deferred_access:
			continue
		var blocker := door.get_node_or_null(^"%PortalBlocker") as StaticBody3D
		if blocker != null:
			_door_blockers.append(blocker.get_rid())
	print("OPENABLE_DOOR_PORTALS_EXCLUDED: ", _door_blockers.size())


func _build_walk_graph() -> void:
	var columns := _column_count()
	var rows := _row_count()
	for ix in columns:
		var x := X_MIN + float(ix) * GRID
		for iz in rows:
			var z := Z_MIN + float(iz) * GRID
			var heights := PackedFloat32Array()
			var normals := PackedFloat32Array()
			var cursor := 60.0
			for _level in MAX_LEVELS:
				var ray := PhysicsRayQueryParameters3D.create(
					Vector3(x, cursor, z), Vector3(x, -60.0, z), WORLD_LAYER
				)
				ray.collide_with_areas = false
				ray.exclude = _door_blockers
				var hit := _space.intersect_ray(ray)
				if hit.is_empty():
					break
				var point := hit.position as Vector3
				var up_dot := (hit.normal as Vector3).dot(Vector3.UP)
				if up_dot >= WALKABLE_DOT and _capsule_clear(Vector3(x, point.y + _stand_offset(up_dot), z)):
					heights.append(point.y)
					normals.append(up_dot)
				cursor = point.y - 0.05
				if cursor < -59.0:
					break
			if heights.size() > 0:
				var key := "%d:%d" % [ix, iz]
				_clear_heights[key] = heights
				_clear_normals[key] = normals


func _flood_from(spawn: Vector3) -> Dictionary:
	var visited := {}
	var start_key := _nearest_node_key(spawn)
	if start_key.is_empty():
		_check(false, "the production spawn marker stands on a capsule-clear walkable surface")
		return visited
	var columns := _column_count()
	var rows := _row_count()
	var stack: Array[String] = [start_key]
	visited[start_key] = true
	var neighbours := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
	]
	while not stack.is_empty():
		var key: String = stack.pop_back()
		var parts := key.split(":")
		var ix := int(parts[0])
		var iz := int(parts[1])
		var y := float(parts[2])
		var from_stand := y + _stand_offset(_node_normal(ix, iz, y))
		for offset: Vector2i in neighbours:
			var nx := ix + offset.x
			var nz := iz + offset.y
			if nx < 0 or nz < 0 or nx >= columns or nz >= rows:
				continue
			var cell_key := "%d:%d" % [nx, nz]
			if not _clear_heights.has(cell_key):
				continue
			var neighbour_heights := _clear_heights[cell_key] as PackedFloat32Array
			var neighbour_normals := _clear_normals[cell_key] as PackedFloat32Array
			for level in neighbour_heights.size():
				var ny := neighbour_heights[level]
				var delta := ny - y
				# A continuous ramp is climbable up to floor_max_angle; a flat lip
				# is limited to the measured no-jump step height.
				var sloped := neighbour_normals[level] < 0.999 or _node_normal(ix, iz, y) < 0.999
				var rise_limit: float = SLOPE_RISE_LIMIT if sloped else _step_limit
				if delta > rise_limit:
					continue
				if delta < -maxf(rise_limit, _step_limit) and delta < -DROP_LIMIT:
					continue
				var neighbour_key := "%d:%d:%f" % [nx, nz, ny]
				if visited.has(neighbour_key):
					continue
				var sweep_y: float = maxf(ny + _stand_offset(neighbour_normals[level]), from_stand) + 0.01
				var from_centre := Vector3(X_MIN + float(ix) * GRID, sweep_y, Z_MIN + float(iz) * GRID)
				var to_centre := Vector3(X_MIN + float(nx) * GRID, sweep_y, Z_MIN + float(nz) * GRID)
				if not _sweep_clear(from_centre, to_centre):
					continue
				visited[neighbour_key] = true
				stack.append(neighbour_key)
	return visited


func _test_required_route_surfaces_reachable(world: ShipyardWorld, reachable: Dictionary) -> void:
	var unreachable := PackedStringArray()
	for entry in REQUIRED_ROUTE_SURFACES:
		var owner := world as Node3D
		if not (entry[0] as String).is_empty():
			owner = world.get_node_or_null(NodePath(entry[0] as String)) as Node3D
		var body: StaticBody3D
		if owner != null:
			body = owner.get_node_or_null(NodePath(entry[1] as String)) as StaticBody3D
		if body == null:
			unreachable.append("%s/%s <missing>" % [entry[0], entry[1]])
			continue
		var box := _body_world_box(body)
		var stats := _surface_reach(box, reachable)
		if int(stats.reachable) == 0:
			unreachable.append("%s/%s nodes=%d top=%.3f centre=%s" % [
				entry[0], entry[1], int(stats.nodes), box.end.y, str(box.get_center())
			])
	print("UNREACHABLE_REQUIRED_ROUTE_SURFACES: ", unreachable)
	_check(
		unreachable.is_empty(),
		"every required station route surface is reachable on foot from spawn without a jump"
	)


## MAP-002's recorded reproduction, run through the production controller:
## stand on the lattice deck in front of a raised deck, face it, hold
## `move_forward`, and require the capsule to finish standing on that raised
## deck. No jump is pressed and no transform is set during the walk.
##
## This replaces the earlier deck-top-versus-deck-top proxy, which no raised pod
## could satisfy however well its threshold was authored. See the file header.
func _test_pod_decks_can_be_walked_into(player: PlayerController) -> void:
	var blocked := PackedStringArray()
	var results := PackedStringArray()
	for entry in POD_WALK_INS:
		var start := entry[1] as Vector3
		var minimum_z := float(entry[2])
		var result := await _walk_forward(player, start, Vector3.BACK, 200)
		var settled := result.initial as Vector3
		var final_position := result.final as Vector3
		results.append("%s start_y=%.3f final=%s" % [
			entry[0], settled.y, str(final_position)
		])
		# Control: the walk has to begin standing on the lattice deck, not
		# hovering above it or already inside the raised deck.
		if absf(settled.y - LATTICE_DECK_TOP) > POD_WALK_TOLERANCE:
			blocked.append("%s did not start on the lattice deck (y=%.3f)" % [entry[0], settled.y])
			continue
		if final_position.y < POD_DECK_TOP - POD_WALK_TOLERANCE:
			blocked.append("%s stopped below the raised deck (y=%.3f)" % [entry[0], final_position.y])
			continue
		if final_position.z < minimum_z:
			blocked.append("%s stopped short at z=%.3f (needed %.3f, %s)" % [
				entry[0], final_position.z, minimum_z, entry[3]
			])
	print("POD_WALK_INS: ", results)
	print("BLOCKED_POD_WALK_INS: ", blocked)
	_check(
		blocked.is_empty(),
		"continuous move_forward through the operations pod doorway, onto the fleet registry pod, and into the freight branch succeeds without a jump"
	)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
	await physics_frame


func _test_freight_branch_has_a_walkable_approach(world: ShipyardWorld) -> void:
	var port := world.get_node_or_null(^"ExposedDockLattice/PortBerthNode") as StaticBody3D
	var freight := world.get_node_or_null(^"JovianFreightBerth") as JovianFreightBerth
	var connection_deck: StaticBody3D
	if freight != null:
		connection_deck = freight.get_node_or_null(^"ConnectionLattice/ConnectionDeckA") as StaticBody3D
	if port == null or connection_deck == null:
		_check(false, "the port berth node and freight connection deck both resolve")
		return
	var port_box := _body_world_box(port)
	var connection_deck_box := _body_world_box(connection_deck)
	# Sample the seam the freight branch is supposed to hand off across.
	var voids := PackedStringArray()
	var x_start: float = maxf(port_box.position.x, connection_deck_box.position.x) + 0.4
	var x_end: float = minf(port_box.end.x, connection_deck_box.end.x) - 0.4
	var sample_x := (x_start + x_end) * 0.5
	var z := port_box.end.z - 1.0
	while z <= connection_deck_box.position.z + 1.0:
		var ray := PhysicsRayQueryParameters3D.create(
			Vector3(sample_x, 20.0, z), Vector3(sample_x, -20.0, z), WORLD_LAYER
		)
		ray.collide_with_areas = false
		ray.exclude = _door_blockers
		var hit := _space.intersect_ray(ray)
		if hit.is_empty():
			voids.append("%.2f,%.2f" % [sample_x, z])
		z += 0.25
	print("FREIGHT_CONNECTION_SEAM: x=", sample_x, " void_samples=", voids)
	_check(
		voids.is_empty(),
		"the freight branch hands off to the port berth node across continuous walkable structure, not a void"
	)


func _test_every_flyable_ship_is_boardable_on_foot(
		game: GameFlow,
		world: ShipyardWorld,
		reachable: Dictionary
	) -> void:
	var fleet: Array = game.call("get_flyable_ships")
	var stranded := PackedStringArray()
	for entry in fleet:
		var ship := entry as HeroShip
		if ship == null:
			continue
		var boarding_position := ship.call("get_boarding_position") as Vector3
		if not _has_reachable_node_near(boarding_position, 2.6, reachable):
			stranded.append("%s at %s" % [ship.name, str(boarding_position)])
	print("STRANDED_SHIPS: ", stranded)
	_check(
		fleet.size() == 5,
		"the production fleet still exposes exactly five flyable craft"
	)
	_check(
		stranded.is_empty(),
		"every flyable craft can be approached on foot from spawn without a jump"
	)


## PORT-DECK-001 reachability. Every face of the parked Arrow must be walkable to
## from the production spawn without a jump, not just the rail corridor the
## branch arm delivers you into.
func _test_arrow_berth_can_be_walked_around(reachable: Dictionary) -> void:
	var stranded := PackedStringArray()
	for entry in ARROW_BERTH_WALKAROUND_POINTS:
		if not _has_reachable_node_near(entry[0] as Vector3, 0.6, reachable):
			stranded.append("%s (%s)" % [str(entry[0]), entry[1]])
	print("UNREACHABLE_ARROW_BERTH_FACES: ", stranded)
	_check(
		stranded.is_empty(),
		"the walkway beside the parked Arrow is reachable on every face without jumping a rail"
	)


## HALYARD-DECK-001 reachability, the same shape of check as the Arrow's. Every
## face of the parked Halyard must be walkable to from the production spawn
## without a jump. Before the apron was built the nose and tail points below were
## open space and the two flank points were dead ends off a 3.6 m rung.
func _test_halyard_berth_can_be_walked_around(reachable: Dictionary) -> void:
	var stranded := PackedStringArray()
	for entry in HALYARD_BERTH_WALKAROUND_POINTS:
		if not _has_reachable_node_near(entry[0] as Vector3, 0.6, reachable):
			stranded.append("%s (%s)" % [str(entry[0]), entry[1]])
	print("UNREACHABLE_HALYARD_BERTH_FACES: ", stranded)
	_check(
		stranded.is_empty(),
		"the apron beside the parked Halyard is reachable on every face without jumping"
	)


## PORT-DECK-001 structure. The recorded defect was that the 12.2 m craft is
## parked on a 12.0 m pad, so its nose projected 0.450 m past the deck edge with
## two of four footprint corners over open space. Probe the four corners of every
## parked craft's own collision footprint and require structure under each.
func _test_parked_craft_are_fully_supported_by_their_berth_decks(
		game: GameFlow,
		world: ShipyardWorld
	) -> void:
	var unsupported := PackedStringArray()
	var report := PackedStringArray()
	for entry in game.call("get_flyable_ships"):
		var ship := entry as HeroShip
		if ship == null:
			continue
		var box := AABB()
		var first := true
		for candidate in ship.find_children("*", "CollisionShape3D", true, false):
			var shape := candidate as CollisionShape3D
			if shape.disabled or shape.shape is not BoxShape3D:
				continue
			if shape.get_parent() is Area3D:
				continue
			var half := (shape.shape as BoxShape3D).size * 0.5
			var world_box := (shape.global_transform * AABB(-half, half * 2.0)).abs()
			if first:
				box = world_box
				first = false
			else:
				box = box.merge(world_box)
		if first:
			continue
		var missing := 0
		for corner in [
			Vector3(box.position.x, 0.0, box.position.z),
			Vector3(box.end.x, 0.0, box.position.z),
			Vector3(box.position.x, 0.0, box.end.z),
			Vector3(box.end.x, 0.0, box.end.z),
		]:
			var ray := PhysicsRayQueryParameters3D.create(
				Vector3(corner.x, box.position.y, corner.z),
				Vector3(corner.x, box.position.y - 12.0, corner.z),
				WORLD_LAYER
			)
			ray.collide_with_areas = false
			ray.exclude = _door_blockers
			if _space.intersect_ray(ray).is_empty():
				missing += 1
		report.append("%s footprint=%s unsupported_corners=%d" % [ship.name, str(box.size), missing])
		if missing > 0:
			unsupported.append("%s (%d of 4 corners)" % [ship.name, missing])
	print("PARKED_CRAFT_FOOTPRINT_SUPPORT: ", report)
	_check(
		unsupported.is_empty(),
		"every parked craft's collision footprint stands wholly on the berth deck beneath it"
	)


## PORT-DECK-001, run through the production controller rather than the walk
## graph: stand where the branch arm hands off to the berth node, face the
## starboard flank, hold `move_forward`, and require the capsule to arrive there.
## Then do the same toward the port flank. No jump is pressed and no transform is
## set during either walk.
##
## Reproduces the report exactly. `BranchRail` used to span x = -42.5 … -11.5 at
## both z = 12.0 and z = 19.0, five metres past the 7 m arm it guards and straight
## across the berth node, at 1.06 … 1.24 m high. From x = -36.0 both legs below
## stopped dead against it, and the only gap in it — around x = -42.5 — is under
## the Arrow's own sensor wing, which blocks a standing capsule. The rails now end
## with their arm.
func _test_arrow_berth_rails_no_longer_fence_the_walkway(player: PlayerController) -> void:
	var start := Vector3(-36.0, 0.18, 15.5)
	# The walk is bounded at 80 physics frames on purpose. Both legs only have to
	# cross the old rail line — z = 12.0 going starboard, z = 19.0 going port — and
	# an unbounded hold would carry the capsule off the far edge of the deck and
	# into GameFlow's fall recovery, which teleports it back to spawn and would
	# make this assertion measure the respawn instead of the route.
	var legs := [
		[Vector3.FORWARD, "starboard flank", 11.5, -1.0],
		[Vector3.BACK, "port flank", 19.5, 1.0],
	]
	var fenced := PackedStringArray()
	var results := PackedStringArray()
	for leg in legs:
		var result := await _walk_forward(player, start, leg[0] as Vector3, 80)
		var final_position := result.final as Vector3
		results.append("%s final=%s travelled=%.2f stuck=%d" % [
			leg[1], str(final_position), float(result.travelled), int(result.stuck_frames)
		])
		var reached := final_position.z <= float(leg[2]) if float(leg[3]) < 0.0 else final_position.z >= float(leg[2])
		if not reached:
			fenced.append("%s stopped at z=%.3f (needed %s %.1f)" % [
				leg[1], final_position.z, "<=" if float(leg[3]) < 0.0 else ">=", float(leg[2])
			])
		if absf(final_position.y - LATTICE_DECK_TOP) > POD_WALK_TOLERANCE:
			fenced.append("%s left the berth deck (y=%.3f)" % [leg[1], final_position.y])
	print("ARROW_BERTH_FLANK_WALKS: ", results)
	_check(
		fenced.is_empty(),
		"continuous move_forward from the branch-arm handoff reaches both flanks of the Arrow without jumping a rail"
	)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
	await physics_frame


## HALYARD-DECK-001, through the production controller rather than the walk
## graph, and the direct answer to "a much larger square so you can walk all the
## way around it". Four legs, one down each side of the parked craft, each driven
## with continuous `move_forward` and nothing else. No jump is pressed and no
## transform is set inside a leg — only between them, to place the capsule at the
## next corner facing the next side.
##
## The circuit is a rectangle at x = 32.0 / 42.0 and z = 37.5 / 68.5, which is
## 0.62 m inside each deck edge at the flanks and clear of the craft everywhere:
## the cabin walls stand at x = 34.28 and 39.72, the bow collar reaches z = 39.75,
## and the tail yoke that spans the full 9.6 m beam sits at y = 6.255, which a
## 1.94 m capsule on a 4.2 m deck passes under with 0.115 m to spare. Before the
## apron existed, three of these four legs ran over open space.
##
## Each leg stops the moment it passes its target rather than running a fixed
## budget, because the far edge of this deck is a 34 m drop into GameFlow's fall
## recovery and a fixed budget that overshot would measure the respawn.
func _test_halyard_berth_is_one_continuous_loop(player: PlayerController) -> void:
	var legs := [
		["starboard flank, nose apron to the comb trunk",
			Vector3(42.0, FLEET_DOCK_DECK_TOP + 0.2, 37.5), Vector3.BACK, 2, 68.5, 1.0, 700],
		["aft crossing, under the tail yoke and out over the trunk",
			Vector3(42.0, FLEET_DOCK_DECK_TOP + 0.2, 68.5), Vector3.LEFT, 0, 32.0, -1.0, 400],
		["port flank, comb trunk back to the nose apron",
			Vector3(32.0, FLEET_DOCK_DECK_TOP + 0.2, 68.5), Vector3.FORWARD, 2, 37.5, -1.0, 700],
		["nose crossing, across the apron ahead of the bow collar",
			Vector3(32.0, FLEET_DOCK_DECK_TOP + 0.2, 37.5), Vector3.RIGHT, 0, 42.0, 1.0, 400],
	]
	var blocked := PackedStringArray()
	var results := PackedStringArray()
	for leg in legs:
		var axis := int(leg[3])
		var target := float(leg[4])
		var toward_positive := float(leg[5]) > 0.0
		var result := await _walk_until(
			player,
			leg[1] as Vector3,
			leg[2] as Vector3,
			axis,
			target,
			toward_positive,
			int(leg[6])
		)
		var final_position := result.final as Vector3
		results.append("%s final=%s travelled=%.2f frames=%d stuck=%d" % [
			leg[0], str(final_position), float(result.travelled),
			int(result.frames), int(result.stuck_frames)
		])
		if not bool(result.reached):
			blocked.append("%s stopped at %.3f (needed %s %.1f)" % [
				leg[0], final_position[axis], ">=" if toward_positive else "<=", target
			])
		if absf(final_position.y - FLEET_DOCK_DECK_TOP) > POD_WALK_TOLERANCE:
			blocked.append("%s left the berth deck (y=%.3f)" % [leg[0], final_position.y])
	print("HALYARD_BERTH_LOOP_WALKS: ", results)
	_check(
		blocked.is_empty(),
		"the production capsule walks a full circuit around the parked Halyard without jumping or leaving the deck"
	)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
	await physics_frame


## Production traversal through the exact siting-audit dogleg. The capsule
## starts inside Dock Operations, steers around the two cargo stacks, crosses
## A/B/C, visits both work bays and the rear cross aisle, and walks the same
## route back. Rotation changes at corners; position is never teleported after
## the initial staging, and jump remains released for the entire round trip.
func _test_fabrication_annex_round_trip(player: PlayerController) -> void:
	var route := PackedVector3Array([
		Vector3(43.0, 0.78, 24.8),
		Vector3(48.1, 0.78, 24.8),
		Vector3(48.1, 0.78, 29.1),
		Vector3(48.1, 0.78, 28.0),
		Vector3(68.5, 0.78, 28.0),
		Vector3(68.5, 0.78, 38.0),
		Vector3(72.0, 0.78, 38.0),
		Vector3(77.0, 0.78, 38.0),
		Vector3(83.0, 0.78, 38.0),
		Vector3(83.0, 0.78, 45.0),
		Vector3(83.0, 0.78, 38.0),
		Vector3(83.0, 0.78, 31.0),
		Vector3(83.0, 0.78, 38.0),
		Vector3(90.0, 0.78, 38.0),
		Vector3(83.0, 0.78, 38.0),
		Vector3(72.0, 0.78, 38.0),
		Vector3(68.5, 0.78, 38.0),
		Vector3(68.5, 0.78, 28.0),
		Vector3(48.1, 0.78, 28.0),
		Vector3(48.1, 0.78, 29.1),
		Vector3(48.1, 0.78, 24.8),
		Vector3(43.0, 0.78, 24.8),
	])
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)
	player.teleport_to(Transform3D(Basis.IDENTITY, route[0]))
	for _settle in 10:
		await physics_frame
	var initial := player.global_position
	var failed_legs := PackedStringArray()
	var results := PackedStringArray()
	var minimum_y := initial.y
	for route_index in range(1, route.size()):
		var target := route[route_index]
		var direction := target - player.global_position
		direction.y = 0.0
		if direction.length_squared() <= 0.0001:
			continue
		direction = direction.normalized()
		var facing := player.global_transform
		facing.basis = Basis.looking_at(direction, Vector3.UP)
		player.global_transform = facing
		var reached := false
		var stuck_frames := 0
		var previous := player.global_position
		Input.action_press(&"move_forward")
		for frame in 300:
			await physics_frame
			minimum_y = minf(minimum_y, player.global_position.y)
			var remaining := target - player.global_position
			remaining.y = 0.0
			if remaining.length() <= 0.38 or remaining.dot(direction) <= 0.0:
				reached = true
				break
			if player.global_position.distance_to(previous) < 0.005:
				stuck_frames += 1
				if stuck_frames >= 45:
					break
			else:
				stuck_frames = 0
			previous = player.global_position
		Input.action_release(&"move_forward")
		await physics_frame
		results.append("%02d final=%s target=%s reached=%s stuck=%d" % [
			route_index, player.global_position, target, reached, stuck_frames,
		])
		if not reached:
			failed_legs.append("leg %d stopped at %s before %s" % [route_index, player.global_position, target])
			break
	print("FABRICATION_ANNEX_PLAYER_ROUND_TRIP: start=%s final=%s min_y=%.3f legs=%s" % [
		initial, player.global_position, minimum_y, results,
	])
	_check(
		failed_legs.is_empty()
		and minimum_y >= 0.30
		and player.global_position.distance_to(initial) <= 0.85,
		"the real production Player walks around Dock Operations cargo, through both Annex bays and rear aisle, and back without jumping"
	)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
	await physics_frame


## Production Player traversal through the world-owned rear-aisle anchor, exact
## half-metre connector, both spatially separate pads, and the far return bridge.
## One initial staging teleport is permitted; every subsequent leg uses the real
## `move_forward` action, changes facing only at corners, and never presses jump.
func _test_observation_logistics_round_trip(player: PlayerController) -> void:
	var route := PackedVector3Array([
		Vector3(90.0, 0.78, 38.0),
		Vector3(91.0, 0.78, 38.0),
		Vector3(92.25, 0.78, 38.0),
		Vector3(93.3, 0.78, 38.0),
		Vector3(116.5, 0.78, 38.0),
		Vector3(116.5, 0.78, 46.0),
		Vector3(124.5, 0.78, 46.0),
		Vector3(129.65, 0.78, 41.55),
		Vector3(130.5, 0.78, 38.0),
		Vector3(129.65, 0.78, 34.45),
		Vector3(124.5, 0.78, 30.0),
		Vector3(116.5, 0.78, 30.0),
		Vector3(116.5, 0.78, 38.0),
		Vector3(93.3, 0.78, 38.0),
		Vector3(92.25, 0.78, 38.0),
		Vector3(91.0, 0.78, 38.0),
		Vector3(90.0, 0.78, 38.0),
	])
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)
	player.teleport_to(Transform3D(Basis.IDENTITY, route[0]))
	for _settle in 10:
		await physics_frame
	var initial := player.global_position
	var failed_legs := PackedStringArray()
	var results := PackedStringArray()
	var minimum_y := initial.y
	for route_index in range(1, route.size()):
		var target := route[route_index]
		var direction := target - player.global_position
		direction.y = 0.0
		if direction.length_squared() <= 0.0001:
			continue
		direction = direction.normalized()
		var facing := player.global_transform
		facing.basis = Basis.looking_at(direction, Vector3.UP)
		player.global_transform = facing
		var reached := false
		var stuck_frames := 0
		var previous := player.global_position
		Input.action_press(&"move_forward")
		for _frame in 480:
			await physics_frame
			minimum_y = minf(minimum_y, player.global_position.y)
			var remaining := target - player.global_position
			remaining.y = 0.0
			if remaining.length() <= 0.38 or remaining.dot(direction) <= 0.0:
				reached = true
				break
			if player.global_position.distance_to(previous) < 0.005:
				stuck_frames += 1
				if stuck_frames >= 45:
					break
			else:
				stuck_frames = 0
			previous = player.global_position
		Input.action_release(&"move_forward")
		await physics_frame
		results.append("%02d final=%s target=%s reached=%s stuck=%d" % [
			route_index, player.global_position, target, reached, stuck_frames,
		])
		if not reached:
			failed_legs.append("leg %d stopped at %s before %s" % [route_index, player.global_position, target])
			break
	print("OBSERVATION_LOGISTICS_PLAYER_ROUND_TRIP: start=%s final=%s min_y=%.3f legs=%s" % [
		initial, player.global_position, minimum_y, results,
	])
	_check(
		failed_legs.is_empty() \
		and minimum_y >= 0.30 \
		and player.global_position.distance_to(initial) <= 0.85,
		"the real production Player walks from Fabrication through both Observation pads, around the far bridge, and back without jumping"
	)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
	await physics_frame


## Production Player traversal from Fabrication's port work bay through its real
## north-service gate, the 3.9312 m2 connector, the spatially separate lower
## salvage pad, both broad ramps, and the top inspection pad, then back along the
## same physical route. There is one staging teleport and no jump input.
func _test_salvage_terrace_round_trip(player: PlayerController) -> void:
	var route := PackedVector3Array([
		Vector3(83.0, 0.78, 45.0),
		Vector3(83.0, 0.78, 50.5),
		Vector3(84.0, 0.78, 51.8),
		Vector3(84.0, 0.78, 52.455),
		Vector3(84.0, 0.78, 56.91),
		Vector3(78.3, 0.78, 59.91),
		Vector3(72.0, 0.78, 59.91),
		Vector3(78.3, 0.78, 59.91),
		Vector3(84.0, 0.78, 57.91),
		Vector3(89.6, 0.78, 57.91),
		Vector3(98.4, 4.38, 57.91),
		Vector3(102.0, 4.38, 57.91),
		Vector3(107.0, 4.38, 61.9),
		Vector3(107.0, 4.38, 63.1),
		Vector3(107.0, 6.18, 67.1),
		Vector3(107.0, 6.18, 68.91),
		Vector3(107.0, 6.18, 67.1),
		Vector3(107.0, 4.38, 63.1),
		Vector3(107.0, 4.38, 61.9),
		Vector3(102.0, 4.38, 57.91),
		Vector3(98.4, 4.38, 57.91),
		Vector3(89.6, 0.78, 57.91),
		Vector3(84.0, 0.78, 56.91),
		Vector3(84.0, 0.78, 52.455),
		Vector3(84.0, 0.78, 51.8),
		Vector3(83.0, 0.78, 50.5),
		Vector3(83.0, 0.78, 45.0),
	])
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)
	player.teleport_to(Transform3D(Basis.IDENTITY, route[0]))
	for _settle in 10:
		await physics_frame
	var initial := player.global_position
	var failed_legs := PackedStringArray()
	var results := PackedStringArray()
	var minimum_y := initial.y
	var maximum_y := initial.y
	for route_index in range(1, route.size()):
		var target := route[route_index]
		var direction := target - player.global_position
		direction.y = 0.0
		if direction.length_squared() <= 0.0001:
			continue
		direction = direction.normalized()
		var facing := player.global_transform
		facing.basis = Basis.looking_at(direction, Vector3.UP)
		player.global_transform = facing
		var reached := false
		var stuck_frames := 0
		var previous := player.global_position
		Input.action_press(&"move_forward")
		for _frame in 480:
			await physics_frame
			minimum_y = minf(minimum_y, player.global_position.y)
			maximum_y = maxf(maximum_y, player.global_position.y)
			var remaining := target - player.global_position
			remaining.y = 0.0
			if remaining.length() <= 0.38 or remaining.dot(direction) <= 0.0:
				reached = true
				break
			if player.global_position.distance_to(previous) < 0.005:
				stuck_frames += 1
				if stuck_frames >= 45:
					break
			else:
				stuck_frames = 0
			previous = player.global_position
		Input.action_release(&"move_forward")
		await physics_frame
		results.append("%02d final=%s target=%s reached=%s stuck=%d" % [
			route_index, player.global_position, target, reached, stuck_frames,
		])
		if not reached:
			failed_legs.append("leg %d stopped at %s before %s" % [route_index, player.global_position, target])
			break
	print("SALVAGE_TERRACE_PLAYER_ROUND_TRIP: start=%s final=%s min_y=%.3f max_y=%.3f legs=%s" % [
		initial, player.global_position, minimum_y, maximum_y, results,
	])
	_check(
		failed_legs.is_empty() \
		and minimum_y >= 0.30 \
		and maximum_y >= 5.75 \
		and player.global_position.distance_to(initial) <= 0.85,
		"the real production Player walks Fabrication to the lower Salvage pad, climbs both ramps to the top, and returns without jumping"
	)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
	await physics_frame


## `_walk_forward` with a stopping condition instead of a frame count: hold
## `move_forward` until `axis` passes `target`, or until `max_frames` runs out.
func _walk_until(
		player: PlayerController,
		start: Vector3,
		direction: Vector3,
		axis: int,
		target: float,
		toward_positive: bool,
		max_frames: int
	) -> Dictionary:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)
	player.teleport_to(Transform3D(Basis.looking_at(direction, Vector3.UP), start))
	for _settle in 10:
		await physics_frame
	var initial := player.global_position
	var previous := initial
	var stuck_frames := 0
	var frames := 0
	var reached := false
	Input.action_press(&"move_forward")
	for _frame in max_frames:
		await physics_frame
		frames += 1
		if player.global_position.distance_to(previous) < 0.005:
			stuck_frames += 1
		previous = player.global_position
		var value := player.global_position[axis]
		if (value >= target) if toward_positive else (value <= target):
			reached = true
			break
	Input.action_release(&"move_forward")
	await physics_frame
	return {
		"initial": initial,
		"final": player.global_position,
		"travelled": initial.distance_to(player.global_position),
		"frames": frames,
		"stuck_frames": stuck_frames,
		"reached": reached,
	}


## PORT-BOARDING-001. Ring sample, not a single staged vector.
##
## For each parked craft, walk a ring of candidate standing points around it at
## 3 / 5 / 7 m, keep the ones the production capsule can actually stand on, put
## the real player there and ask GameFlow through its own
## `_refresh_interaction_targets()` seam whether the boarding prompt is offered.
## Every standable ring point must offer it. The Arrow failed 43 of its 105
## standable ring points before this pass, including the whole starboard flank.
func _test_boarding_prompt_is_offered_all_round_each_craft(
		game: GameFlow,
		player: PlayerController
	) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	var summary := PackedStringArray()
	var silent := PackedStringArray()
	var arrow_standable := 0
	var arrow_prompted := 0
	var halyard_standable := 0
	var halyard_prompted := 0
	for entry in game.call("get_flyable_ships"):
		var ship := entry as HeroShip
		if ship == null:
			continue
		var centre := ship.global_position
		var standable := 0
		var prompted := 0
		var missed := PackedStringArray()
		for radius: float in BOARDING_RING_RADII:
			for sample in BOARDING_RING_SAMPLES:
				var angle := TAU * float(sample) / float(BOARDING_RING_SAMPLES)
				var ground_x := centre.x + cos(angle) * radius
				var ground_z := centre.z + sin(angle) * radius
				var down := PhysicsRayQueryParameters3D.create(
					Vector3(ground_x, centre.y + 8.0, ground_z),
					Vector3(ground_x, centre.y - 8.0, ground_z),
					WORLD_LAYER
				)
				down.collide_with_areas = false
				down.exclude = _door_blockers
				var ground := _space.intersect_ray(down)
				if ground.is_empty():
					continue
				var floor_y := (ground.position as Vector3).y
				var stand := Vector3(ground_x, floor_y + CAPSULE_HEIGHT * 0.5 + 0.02, ground_z)
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.transform = Transform3D(Basis.IDENTITY, stand)
				query.collision_mask = WORLD_LAYER | PhysicsLayers.SHIP
				query.collide_with_areas = false
				query.margin = 0.0
				query.exclude = _door_blockers
				if not _space.intersect_shape(query, 1).is_empty():
					continue
				standable += 1
				var facing := (centre - Vector3(ground_x, floor_y, ground_z)).slide(Vector3.UP)
				if facing.length() < 0.01:
					facing = Vector3.FORWARD
				player.teleport_to(Transform3D(
					Basis.looking_at(facing.normalized(), Vector3.UP),
					Vector3(ground_x, floor_y + 0.05, ground_z)
				))
				await physics_frame
				await physics_frame
				game.call("_refresh_interaction_targets")
				if game.boarding_candidate == ship:
					prompted += 1
				else:
					missed.append("r=%.0f a=%.0f at %s" % [radius, rad_to_deg(angle), str(Vector3(ground_x, floor_y, ground_z))])
		summary.append("%s standable=%d prompted=%d" % [ship.name, standable, prompted])
		if standable > 0 and prompted < standable:
			silent.append("%s: %d of %d standable ring points offer no prompt %s" % [
				ship.name, standable - prompted, standable, str(missed)
			])
		if ship.name == "ArrowReconShip":
			arrow_standable = standable
			arrow_prompted = prompted
		if ship.name == "HalyardCrewTransport":
			halyard_standable = standable
			halyard_prompted = prompted
		if standable > 0:
			_check(
				prompted > 0,
				"%s stays boardable from at least one standable point around it" % ship.name
			)
	print("BOARDING_PROMPT_RING: ", summary)
	print("BOARDING_PROMPT_RING_SILENT: ", silent)
	# The Arrow is asserted all-round on purpose, and it is the only craft that is.
	# Its boarding marker sits at ship-local (-2.45, -0.02, 0.15), which is
	# *underneath its own sensor wing*, so no standing capsule can ever occupy the
	# centre of its inherited 4.5 m sphere; a sided volume is unusable for this
	# craft and its berth is a 16.8 x 17.0 m walk-around deck. The Torrent and the
	# Zenith keep a port-quadrant-only reach by design — `boarding_accessibility_test`
	# asserts in as many words that the Torrent "cannot be boarded through the hull
	# from its wrong/opposite side" — so their measured coverage is printed above
	# rather than asserted, and this suite only requires that they stay boardable.
	_check(
		arrow_standable >= 16,
		"the Arrow's berth deck offers a real ring of standing points around the parked craft"
	)
	_check(
		arrow_standable > 0 and arrow_prompted == arrow_standable,
		"the Arrow offers its boarding prompt from every standable point on a ring around it"
	)
	# HALYARD-BOARDING-001. The Halyard is asserted all-round for the same reason
	# the Arrow is: its berth is a walk-around apron, not a one-sided pad, and the
	# report is that the prompt never appeared. It measured 5 of 14 standable ring
	# points before this pass — every silent one aft of the wing or on the wrong
	# flank — because a 4.5 m sphere reaches 32% of a 28.35 m hull. The Torrent and
	# the Zenith keep their deliberate port-quadrant-only reach and are still only
	# required to stay boardable.
	_check(
		halyard_standable >= 12,
		"the Halyard's berth apron offers a real ring of standing points around the parked craft"
	)
	_check(
		halyard_standable > 0 and halyard_prompted == halyard_standable,
		"the Halyard offers its boarding prompt from every standable point on a ring around it"
	)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
	await physics_frame


func _test_aft_stair_base_is_not_fenced_off(player: PlayerController) -> void:
	# Deterministic production-controller reproduction: stand on the Aft
	# connection deck level with the stair, face the stair, hold W.
	var results := []
	var reached := false
	for z_value in [50.5, 51.5, 52.0, 52.6]:
		var result := await _walk_forward(
			player,
			Vector3(0.0, 0.18, float(z_value)),
			Vector3.LEFT,
			200
		)
		results.append("z=%.1f final_x=%.3f travelled=%.3f stuck=%d" % [
			z_value, (result.final as Vector3).x, float(result.travelled), int(result.stuck_frames)
		])
		if (result.final as Vector3).x <= -4.6:
			reached = true
	print("AFT_STAIR_BASE_APPROACH: ", results)
	_check(
		reached,
		"continuous W from the Aft connection deck reaches the stair base landing instead of stopping at the approach rail"
	)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
	await physics_frame


func _walk_forward(
		player: PlayerController,
		start: Vector3,
		direction: Vector3,
		frames: int
	) -> Dictionary:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)
	player.teleport_to(Transform3D(Basis.looking_at(direction, Vector3.UP), start))
	for _settle in 10:
		await physics_frame
	var initial := player.global_position
	var previous := initial
	var stuck_frames := 0
	Input.action_press(&"move_forward")
	for _frame in frames:
		await physics_frame
		if player.global_position.distance_to(previous) < 0.005:
			stuck_frames += 1
		previous = player.global_position
	Input.action_release(&"move_forward")
	await physics_frame
	return {
		"initial": initial,
		"final": player.global_position,
		"travelled": initial.distance_to(player.global_position),
		"stuck_frames": stuck_frames,
	}


func _capsule_clear(centre: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform = Transform3D(Basis.IDENTITY, centre)
	query.collision_mask = WORLD_LAYER
	query.collide_with_areas = false
	query.margin = 0.0
	query.exclude = _door_blockers
	return _space.intersect_shape(query, 1).is_empty()


func _sweep_clear(from_centre: Vector3, to_centre: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform = Transform3D(Basis.IDENTITY, from_centre)
	query.motion = to_centre - from_centre
	query.collision_mask = WORLD_LAYER
	query.collide_with_areas = false
	query.margin = 0.0
	query.exclude = _door_blockers
	var result := _space.cast_motion(query)
	return result.size() == 2 and float(result[1]) >= 0.999


## Standing capsule centre height above its contact point. On an inclined plane
## the bottom sphere needs a larger vertical offset to stay tangent.
func _stand_offset(normal_up: float) -> float:
	return CAPSULE_RADIUS / maxf(normal_up, 0.2) + (CAPSULE_HEIGHT * 0.5 - CAPSULE_RADIUS) + 0.02


func _node_normal(ix: int, iz: int, y: float) -> float:
	var key := "%d:%d" % [ix, iz]
	if not _clear_heights.has(key):
		return 1.0
	var heights := _clear_heights[key] as PackedFloat32Array
	var normals := _clear_normals[key] as PackedFloat32Array
	for level in heights.size():
		if is_equal_approx(heights[level], y):
			return normals[level]
	return 1.0


func _nearest_node_key(point: Vector3) -> String:
	var best := ""
	var best_distance := INF
	for key: String in _clear_heights:
		var parts := key.split(":")
		var ix := int(parts[0])
		var iz := int(parts[1])
		var x := X_MIN + float(ix) * GRID
		var z := Z_MIN + float(iz) * GRID
		for y: float in _clear_heights[key] as PackedFloat32Array:
			var distance := Vector3(x, y, z).distance_to(point)
			if distance < best_distance:
				best_distance = distance
				best = "%d:%d:%f" % [ix, iz, y]
	return best


func _has_reachable_node_near(point: Vector3, radius: float, reachable: Dictionary) -> bool:
	var ix_min: int = maxi(0, int(floor((point.x - radius - X_MIN) / GRID)))
	var ix_max: int = mini(_column_count() - 1, int(ceil((point.x + radius - X_MIN) / GRID)))
	var iz_min: int = maxi(0, int(floor((point.z - radius - Z_MIN) / GRID)))
	var iz_max: int = mini(_row_count() - 1, int(ceil((point.z + radius - Z_MIN) / GRID)))
	for ix in range(ix_min, ix_max + 1):
		for iz in range(iz_min, iz_max + 1):
			var key := "%d:%d" % [ix, iz]
			if not _clear_heights.has(key):
				continue
			for y: float in _clear_heights[key] as PackedFloat32Array:
				var node_position := Vector3(X_MIN + float(ix) * GRID, y, Z_MIN + float(iz) * GRID)
				if node_position.distance_to(point) > radius:
					continue
				if reachable.has("%d:%d:%f" % [ix, iz, y]):
					return true
	return false


func _surface_reach(box: AABB, reachable: Dictionary) -> Dictionary:
	var nodes := 0
	var reached := 0
	var ix_min: int = maxi(0, int(floor((box.position.x - X_MIN) / GRID)))
	var ix_max: int = mini(_column_count() - 1, int(ceil((box.end.x - X_MIN) / GRID)))
	var iz_min: int = maxi(0, int(floor((box.position.z - Z_MIN) / GRID)))
	var iz_max: int = mini(_row_count() - 1, int(ceil((box.end.z - Z_MIN) / GRID)))
	for ix in range(ix_min, ix_max + 1):
		for iz in range(iz_min, iz_max + 1):
			var key := "%d:%d" % [ix, iz]
			if not _clear_heights.has(key):
				continue
			for y: float in _clear_heights[key] as PackedFloat32Array:
				if y < box.position.y - 0.05 or y > box.end.y + 0.30:
					continue
				nodes += 1
				if reachable.has("%d:%d:%f" % [ix, iz, y]):
					reached += 1
	return {"nodes": nodes, "reachable": reached}


func _body_world_box(body: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for candidate in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var world_box := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		if first:
			box = world_box
			first = false
		else:
			box = box.merge(world_box)
	return box


func _clear_node_count() -> int:
	var total := 0
	for key: String in _clear_heights:
		total += (_clear_heights[key] as PackedFloat32Array).size()
	return total


func _column_count() -> int:
	return int(round((X_MAX - X_MIN) / GRID)) + 1


func _row_count() -> int:
	return int(round((Z_MAX - Z_MIN) / GRID)) + 1


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)
	if _failures.is_empty():
		print("STATION_TRAVERSAL_DEFECT_WITNESS_TEST_OK")
		quit(0)
	else:
		print("STATION_TRAVERSAL_DEFECT_WITNESS_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
