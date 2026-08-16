extends SceneTree

## Generates route and possible-obstacle candidates for embodied tow drives.
## Its 1.7 m square, heading-free proxy is not the production 2.3 x 3.8 m
## chassis, so neither a filled cell nor a mesh sample proves vehicle behaviour.
##
## Not a test. A survey tool, run by hand, whose output is the roster the fix is
## measured against. Named held-input drives remain the acceptance authority.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const CELL := 1.0
const MAX_CELLS := 90000
const RISE := 0.9
const DROP := 2.2
const CLEARANCE_HEIGHT := 1.6
const CLEARANCE_HALF_WIDTH := 0.85
## A vehicle bonnet reaches roughly this high. Drawn geometry crossing this band
## near a route-candidate cell is worth an embodied contact drive.
const HIT_BAND_LOW := 0.30
const HIT_BAND_HIGH := 2.1

var _space: PhysicsDirectSpaceState3D
var _world_mask := 1
var _solid_mask := 1 | 4
var _exclude: Array[RID] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	await physics_frame

	var world := game.get_node("ShipyardWorld") as Node3D
	var tractor := game.get_node_or_null("ShipyardWorld/CargoAndMachinery/TowTractor") as Node3D
	if tractor == null:
		var found := world.find_children("*", "TowTractor", true, false)
		tractor = found[0] as Node3D
	_space = world.get_world_3d().direct_space_state
	_exclude = [(tractor as CollisionObject3D).get_rid()]

	var start := tractor.global_position
	print("SURVEY: tractor home %s" % start)

	var reachable := _flood(start)
	print("SURVEY: route-candidate deck cells = %d at %.2f m spacing" % [reachable.size(), CELL])
	var bounds := AABB(start, Vector3.ZERO)
	for key: Vector2i in reachable:
		bounds = bounds.expand(Vector3(float(key.x) * CELL, reachable[key], float(key.y) * CELL))
	print("SURVEY: route-candidate bounds %s size %s" % [bounds.position, bounds.size])

	# The tractor is 2.3 x 3.8 m, so it touches geometry standing well outside the
	# proxy cells. Dilate the candidate set before asking what might stand nearby.
	var contact := _dilate(reachable, 2)
	print("SURVEY: possible-contact candidate cells = %d" % contact.size())
	_report_meshes(game, contact)
	_report_named_reachability(game, reachable)
	_report_ships(game)

	game.queue_free()
	await process_frame
	quit(0)


## Flood fill over cells the deck-edge interlock would allow, with a clearance
## box so the fill cannot walk through a wall.
func _flood(start: Vector3) -> Dictionary:
	var visited: Dictionary = {}
	var start_key := Vector2i(int(round(start.x / CELL)), int(round(start.z / CELL)))
	var ground := _ground_at(Vector3(float(start_key.x) * CELL, start.y + 2.0, float(start_key.y) * CELL), 4.0, 4.0)
	if not is_finite(ground):
		print("SURVEY: no ground under the tractor home; aborting fill")
		return visited
	visited[start_key] = ground
	var queue: Array[Vector2i] = [start_key]
	while not queue.is_empty() and visited.size() < MAX_CELLS:
		var key: Vector2i = queue.pop_back()
		var here: float = visited[key]
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_key: Vector2i = key + step
			if visited.has(next_key):
				continue
			var probe := Vector3(float(next_key.x) * CELL, here, float(next_key.y) * CELL)
			var next_ground := _ground_at(probe, RISE, DROP)
			if not is_finite(next_ground):
				visited[next_key] = INF
				continue
			if not _clear_above(Vector3(probe.x, next_ground, probe.z)):
				visited[next_key] = INF
				continue
			visited[next_key] = next_ground
			queue.append(next_key)
	var result: Dictionary = {}
	for key: Vector2i in visited:
		if is_finite(visited[key]):
			result[key] = visited[key]
	return result


## Every cell within `radius` cells of a route candidate, keyed to its nearby
## ground height.
func _dilate(reachable: Dictionary, radius: int) -> Dictionary:
	var result: Dictionary = reachable.duplicate()
	for key: Vector2i in reachable:
		var ground: float = reachable[key]
		for offset_x in range(-radius, radius + 1):
			for offset_z in range(-radius, radius + 1):
				var next_key := key + Vector2i(offset_x, offset_z)
				if not result.has(next_key):
					result[next_key] = ground
	return result


func _ground_at(point: Vector3, rise: float, drop: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * rise,
		point + Vector3.DOWN * drop,
		_world_mask
	)
	query.collide_with_areas = false
	query.exclude = _exclude
	var hit := _space.intersect_ray(query)
	if hit.is_empty():
		return INF
	return (hit["position"] as Vector3).y


func _clear_above(ground_point: Vector3) -> bool:
	var box := BoxShape3D.new()
	box.size = Vector3(CLEARANCE_HALF_WIDTH * 2.0, CLEARANCE_HEIGHT, CLEARANCE_HALF_WIDTH * 2.0)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.transform = Transform3D(Basis.IDENTITY, ground_point + Vector3.UP * (CLEARANCE_HEIGHT * 0.5 + 0.12))
	params.collision_mask = _solid_mask
	params.collide_with_areas = false
	params.exclude = _exclude
	return _space.intersect_shape(params, 1).is_empty()


## Every drawn mesh standing in the reachable region, sorted into "the tractor
## stops" and "the tractor drives through".
func _report_meshes(game: Node, reachable: Dictionary) -> void:
	var solid: Dictionary = {}
	var phantom: Dictionary = {}
	for node in game.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		if _is_under_tractor(mesh_instance):
			continue
		var local := mesh_instance.get_aabb()
		var world_aabb := mesh_instance.global_transform * local
		var samples := _band_samples(world_aabb, reachable)
		if samples.is_empty():
			continue
		var name_key := _family(mesh_instance)
		var blocked := false
		for sample: Vector3 in samples:
			if _solid_at(sample):
				blocked = true
				break
		var bucket := solid if blocked else phantom
		if not bucket.has(name_key):
			bucket[name_key] = []
		(bucket[name_key] as Array).append(samples[0])

	print("\n=== POSSIBLE SOLID CONTACT (candidate samples; drive to prove) ===")
	_print_bucket(solid)
	print("\n=== POSSIBLE UNBACKED GEOMETRY (candidate samples; drive to prove) ===")
	_print_bucket(phantom)


func _print_bucket(bucket: Dictionary) -> void:
	var keys := bucket.keys()
	keys.sort()
	for key: String in keys:
		var entries := bucket[key] as Array
		print("  %-46s x%-4d e.g. %s" % [key, entries.size(), entries[0]])


func _is_under_tractor(node: Node) -> bool:
	var walk := node
	while walk != null:
		if walk.get_class() == "CharacterBody3D" and str(walk.name).contains("Tractor"):
			return true
		if str(walk.name) == "TowTractor":
			return true
		walk = walk.get_parent()
	return false


func _family(node: Node) -> String:
	var name_text := str(node.name)
	var parent := node.get_parent()
	if name_text == "Mesh" and parent != null:
		name_text = str(parent.name)
		parent = parent.get_parent()
	var digits := RegEx.new()
	digits.compile("[0-9]+$")
	name_text = digits.sub(name_text, "", true)
	var owner_text := str(parent.name) if parent != null else "?"
	return "%s/%s" % [owner_text, name_text]


## Points inside `world_aabb` that sit in the drive band above a candidate cell.
func _band_samples(world_aabb: AABB, reachable: Dictionary) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var min_key := Vector2i(int(floor(world_aabb.position.x / CELL)), int(floor(world_aabb.position.z / CELL)))
	var max_key := Vector2i(int(ceil(world_aabb.end.x / CELL)), int(ceil(world_aabb.end.z / CELL)))
	if (max_key.x - min_key.x) > 200 or (max_key.y - min_key.y) > 200:
		return result
	for cell_x in range(min_key.x, max_key.x + 1):
		for cell_z in range(min_key.y, max_key.y + 1):
			var key := Vector2i(cell_x, cell_z)
			if not reachable.has(key):
				continue
			var ground: float = reachable[key]
			var low := ground + HIT_BAND_LOW
			var high := ground + HIT_BAND_HIGH
			if world_aabb.end.y < low or world_aabb.position.y > high:
				continue
			var sample_y := clampf((world_aabb.position.y + world_aabb.end.y) * 0.5, low, high)
			var sample := Vector3(
				clampf(float(cell_x) * CELL, world_aabb.position.x, world_aabb.end.x),
				sample_y,
				clampf(float(cell_z) * CELL, world_aabb.position.z, world_aabb.end.z)
			)
			result.append(sample)
			if result.size() >= 24:
				return result
	return result


func _solid_at(point: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, point)
	params.collision_mask = _solid_mask
	params.collide_with_areas = false
	params.exclude = _exclude
	return not _space.intersect_shape(params, 1).is_empty()


## Which named surfaces overlap candidate cells, and where named dressing sits.
## This is coverage triage, not production-vehicle reachability evidence.
func _report_named_reachability(game: Node, reachable: Dictionary) -> void:
	print("\n=== NAMED SURFACE ROUTE-CANDIDATE COVERAGE ===")
	for surface_name in [
		"DockSlab01", "DockSlab02", "DockSlab03Upper", "Trunk", "Rung02",
		"HalyardApronNose", "HalyardApronTailPort", "HalyardApronTailStarboard",
		"FleetDockCombConnectorDeck", "CentralJunction",
	]:
		var found := game.find_children(surface_name, "", true, false)
		if found.is_empty():
			print("  %-30s <not found>" % surface_name)
			continue
		var body := found[0] as Node3D
		var world_aabb := _node_world_aabb(body)
		var covered := 0
		var total := 0
		var cell_x := int(floor(world_aabb.position.x / CELL))
		while cell_x <= int(ceil(world_aabb.end.x / CELL)):
			var cell_z := int(floor(world_aabb.position.z / CELL))
			while cell_z <= int(ceil(world_aabb.end.z / CELL)):
				total += 1
				if reachable.has(Vector2i(cell_x, cell_z)):
					covered += 1
				cell_z += 1
			cell_x += 1
		print("  %-30s aabb=%s candidate_cells=%d/%d" % [
			surface_name, world_aabb, covered, total
		])
	print("\n=== NAMED DRESSING POSITIONS ===")
	for dressing_name in ["DockEdgeKerb01", "DockEdgeKerb02", "DockEdgeKerb03"]:
		var found := game.find_children(dressing_name, "", true, false)
		if found.is_empty():
			print("  %-20s <not found>" % dressing_name)
			continue
		print("  %-20s aabb=%s" % [dressing_name, _node_world_aabb(found[0] as Node3D)])


func _node_world_aabb(node: Node3D) -> AABB:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		return mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
	var result := AABB()
	var first := true
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var child := candidate as MeshInstance3D
		if child.mesh == null:
			continue
		var world := child.global_transform * child.mesh.get_aabb()
		if first:
			result = world
			first = false
		else:
			result = result.merge(world)
	return result


func _report_ships(game: Node) -> void:
	print("\n=== CRAFT BODY LAYERS ===")
	for node in game.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		var name_text := str(body.name)
		if name_text.contains("Tractor") or body is Area3D:
			continue
		if body.collision_layer == 1:
			continue
		print("  %-34s layer=%d mask=%d  at %s" % [
			name_text, body.collision_layer, body.collision_mask, body.global_position
		])
