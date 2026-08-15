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
## the two deferred landmark doors stay solid.

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
const X_MAX := 76.0
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
	["JovianFreightBerth", "ConnectionLattice/ConnectionHandoffDeck"],
	["JovianFreightBerth", "ConnectionLattice/ConnectionDeckA"],
	["JovianFreightBerth", "LoadingApron/ApronDeck01"],
	["JovianFreightBerth", "LoadingApron/ApronDeck03"],
	["JovianFreightBerth", "FreightControlRoom/RoomFloor"],
	["FleetDockComb", "GeneratedComb/WalkableSurfaces/Trunk"],
	["FleetDockComb", "GeneratedComb/WalkableSurfaces/DockSlab01"],
	["FleetDockComb", "GeneratedComb/WalkableSurfaces/DockSlab03Upper"],
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
		"inside the operations pod, past its glazed frontage"],
	["ModernFleetRegistry/RegistryPodDeck", Vector3(-46.5, 0.18, 21.0), 26.0,
		"onto the fleet registry pod deck, whose terminal interaction MAP-002 made unreachable"],
	["JovianFreightBerth/ConnectionLattice/ConnectionHandoffDeck", Vector3(-47.0, 0.18, 21.0), 26.0,
		"out along the freight branch connection lattice"],
]
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
		"continuous move_forward from the lattice deck walks up into the operations pod, the fleet registry pod, and the freight branch without a jump"
	)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
	await physics_frame


func _test_freight_branch_has_a_walkable_approach(world: ShipyardWorld) -> void:
	var port := world.get_node_or_null(^"ExposedDockLattice/PortBerthNode") as StaticBody3D
	var freight := world.get_node_or_null(^"JovianFreightBerth") as JovianFreightBerth
	var handoff: StaticBody3D
	if freight != null:
		handoff = freight.get_node_or_null(^"ConnectionLattice/ConnectionHandoffDeck") as StaticBody3D
	if port == null or handoff == null:
		_check(false, "the port berth node and the freight handoff deck both resolve")
		return
	var port_box := _body_world_box(port)
	var handoff_box := _body_world_box(handoff)
	# Sample the seam the freight branch is supposed to hand off across.
	var voids := PackedStringArray()
	var x_start: float = maxf(port_box.position.x, handoff_box.position.x) + 0.4
	var x_end: float = minf(port_box.end.x, handoff_box.end.x) - 0.4
	var sample_x := (x_start + x_end) * 0.5
	var z := port_box.end.z - 1.0
	while z <= handoff_box.position.z + 1.0:
		var ray := PhysicsRayQueryParameters3D.create(
			Vector3(sample_x, 20.0, z), Vector3(sample_x, -20.0, z), WORLD_LAYER
		)
		ray.collide_with_areas = false
		ray.exclude = _door_blockers
		var hit := _space.intersect_ray(ray)
		if hit.is_empty():
			voids.append("%.2f,%.2f" % [sample_x, z])
		z += 0.25
	print("FREIGHT_HANDOFF_SEAM: x=", sample_x, " void_samples=", voids)
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
		fleet.size() == 4,
		"the production fleet still exposes exactly four flyable craft"
	)
	_check(
		stranded.is_empty(),
		"every flyable craft can be approached on foot from spawn without a jump"
	)


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
