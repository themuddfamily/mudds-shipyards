extends SceneTree

## Failing witnesses for the 2026-08-15 human playtest report:
## "there's so many places that are difficult to get to, random objects floating
## in the air and it ruins the experience."
##
## Every assertion here is expected to be RED until the corresponding defect is
## fixed. The suite deliberately contains no production-code change and no
## softened threshold. It measures the production PlayerController's real no-jump
## step capability, rebuilds a capsule-clearance walk graph over the live
## production collision world, floods it from the production spawn marker, and
## then asserts the roadmap's playable-prototype traversal contract:
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

## Facade and terminal legends whose readable face must point at the deck the
## player actually approaches them from. TextMesh renders its readable face
## toward local +Z, so `expected_facing` is the direction a reader stands in.
const APPROACH_FACING_SIGNS := [
	["UpperOperations/Sign_DOCK_OPERATIONS", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_FLEET_REGISTRY__--__MODERN_INTERFACE", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_SAY_SHIP_NAME", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_TORRENT__JOVIAN__TITAN__VORTEX", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_KATANA__PARADOX__PREDATOR__DYNAMIC", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_UTOPIA__ARROW", Vector3(0.0, 0.0, -1.0)],
]

## Decorative pieces that must rest on the surface they are placed against.
const SEATED_DECORATION_PATHS := [
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon01/Base",
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon02/Base",
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon03/Base",
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon04/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon01/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon02/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon03/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon04/Base",
]
const SEATED_DECORATION_TOLERANCE := 0.03

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
	_test_pod_deck_lip_is_climbable(world)
	_test_freight_branch_has_a_walkable_approach(world)
	_test_every_flyable_ship_is_boardable_on_foot(game, world, reachable)
	await _test_aft_stair_base_is_not_fenced_off(player)
	_test_approach_facing_signs(world)
	_test_seated_decorations_rest_on_their_surface(world)
	_test_orphan_dock_guide_lens(world)

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


func _test_pod_deck_lip_is_climbable(world: ShipyardWorld) -> void:
	var lips := [
		["UpperOperations/OperationsPodFloor", "ExposedDockLattice/StarboardBerthNode"],
		["ModernFleetRegistry/RegistryPodDeck", "ExposedDockLattice/PortBerthNode"],
		["JovianFreightBerth/ConnectionLattice/ConnectionHandoffDeck", "ExposedDockLattice/PortBerthNode"],
	]
	var offenders := PackedStringArray()
	for lip in lips:
		var raised := world.get_node_or_null(NodePath(lip[0] as String)) as StaticBody3D
		var approach := world.get_node_or_null(NodePath(lip[1] as String)) as StaticBody3D
		if raised == null or approach == null:
			offenders.append("%s <missing>" % lip[0])
			continue
		var rise := _body_world_box(raised).end.y - _body_world_box(approach).end.y
		if rise > _step_limit:
			offenders.append("%s rise=%.3f > step=%.3f" % [lip[0], rise, _step_limit])
	print("POD_DECK_LIPS: ", offenders)
	_check(
		offenders.is_empty(),
		"the operations pod, registry pod, and freight handoff decks sit within one no-jump step of the lattice deck they open onto"
	)


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


func _test_approach_facing_signs(world: ShipyardWorld) -> void:
	var reversed_signs := PackedStringArray()
	for entry in APPROACH_FACING_SIGNS:
		var sign_mesh := world.get_node_or_null(NodePath(entry[0] as String)) as MeshInstance3D
		if sign_mesh == null or sign_mesh.mesh is not TextMesh:
			reversed_signs.append("%s <missing>" % entry[0])
			continue
		# TextMesh renders its readable face toward local +Z.
		var readable_from := sign_mesh.global_basis.z.normalized()
		if readable_from.dot(entry[1] as Vector3) <= 0.5:
			reversed_signs.append("%s readable_from=%s expected=%s" % [
				entry[0], str(readable_from), str(entry[1])
			])
	print("REVERSED_APPROACH_SIGNS: ", reversed_signs)
	_check(
		reversed_signs.is_empty(),
		"pod facade and registry terminal legends read forwards from the deck they are approached from"
	)


func _test_seated_decorations_rest_on_their_surface(world: ShipyardWorld) -> void:
	var floating := PackedStringArray()
	for path in SEATED_DECORATION_PATHS:
		var mesh_instance := world.get_node_or_null(NodePath(path)) as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			floating.append("%s <missing>" % path)
			continue
		var drop := _drop_below(mesh_instance)
		if drop > SEATED_DECORATION_TOLERANCE:
			floating.append("%s drop=%.3f" % [path, drop])
	print("FLOATING_SEATED_DECORATIONS: ", floating)
	_check(
		floating.is_empty(),
		"every roof-mounted safety beacon rests on the surface it is placed against"
	)


func _test_orphan_dock_guide_lens(world: ShipyardWorld) -> void:
	var lens := world.get_node_or_null(
		^"JovianFreightBerth/FreightPresentation/DockGuideLens18"
	) as MeshInstance3D
	if lens == null or lens.mesh == null:
		_check(false, "the freight dock guide lens roster resolves")
		return
	var apron := world.get_node_or_null(
		^"JovianFreightBerth/LoadingApron/ApronDeck04"
	) as StaticBody3D
	var apron_box := _body_world_box(apron) if apron != null else AABB()
	var lens_box := lens.global_transform * lens.mesh.get_aabb()
	var drop := _drop_below(lens)
	print(
		"DOCK_GUIDE_LENS_18: centre=", lens_box.get_center(),
		" drop=", drop,
		" apron_max_z=", apron_box.end.z
	)
	_check(
		drop <= 0.35,
		"the freight dock guide lens sits on the apron it marks instead of hanging in open space"
	)


func _drop_below(mesh_instance: MeshInstance3D) -> float:
	var box := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
	var origin := Vector3(box.get_center().x, box.position.y + 0.01, box.get_center().z)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 400.0, WORLD_LAYER)
	ray.collide_with_areas = false
	var body := _owning_body(mesh_instance)
	if body != null:
		ray.exclude = [body.get_rid()]
	var hit := _space.intersect_ray(ray)
	if hit.is_empty():
		return 400.0
	return origin.y - float((hit.position as Vector3).y)


func _owning_body(node: Node) -> PhysicsBody3D:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor is PhysicsBody3D:
			return cursor as PhysicsBody3D
		cursor = cursor.get_parent()
	return null


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
