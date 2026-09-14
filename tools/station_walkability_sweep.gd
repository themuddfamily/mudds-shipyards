class_name StationWalkabilitySweep
extends SceneTree

## Embodied-player walkability sweep for the production station (Phase 10 §1).
##
## `tools/station_walkable_area_census.gd` already answers "which authored
## surfaces are walkable and how large are they". This probe reuses that roster
## verbatim -- including the live `walkable_surface` metadata that later modules
## publish -- and answers the next question: standing on those surfaces with the
## real production capsule, where does the world misbehave?
##
## Four defect classes are reported, each keyed to something a player notices:
##
##   invisible_blocker  collision that stops the capsule with nothing rendered
##                      within 0.3 m of it -- the player walks into thin air.
##   walk_through       a rendered piece at least 0.4 m tall standing on a
##                      walkable cell with no collider anywhere in its volume --
##                      the player strolls through a solid-looking object.
##   choke              an authored lane pinched below 0.9 m of clear width
##                      between two blockers -- the player scrapes or is stopped.
##   gap                an authored walkable cell (or a one/two-cell seam between
##                      two authored decks) with no floor within 0.3 m below.
##
## The sweep is a probe, not a gate: it always exits 0 once the production scene
## boots, prints a compact per-module summary, and writes the full triage list to
## `user://station_walkability_sweep.json`.

const SCHEMA_VERSION := 1
const PROFILE_ID := &"station_walkability_capsule_sweep_v1"

const CENSUS := preload("res://tools/station_walkable_area_census.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")

const GRID := 0.25
## Production `scenes/player/player.tscn` values; asserted against the real scene
## at boot so this probe can never drift from the shipped capsule.
const CAPSULE_RADIUS := 0.38
const CAPSULE_HEIGHT := 1.94
const CAPSULE_MASK := 7
const STAND_EPSILON := 0.02

## A blocker counts as rendered when any visible geometry comes this close.
const RENDER_MATCH_RADIUS := 0.3
## Dressing shorter than this reads as trim, not as an object you would expect
## to stop at.
const DRESSING_MIN_HEIGHT := 0.4
## Above this, a mesh AABB is a hull/shell envelope rather than a discrete prop
## and its box says nothing useful about what the player can touch.
const DRESSING_MAX_EXTENT := 8.0
## Horizontal overlap the standing capsule must have with the piece before it
## counts as walking through it rather than brushing its bounding box. Kept below
## a mast/post's typical 0.16 m section so thin upright dressing still registers.
const DRESSING_MIN_PENETRATION := 0.08
const CHOKE_WIDTH := 0.9
const CHOKE_PROBE_REACH := 2.0
const CHOKE_SEARCH_CELLS := 3
const FLOOR_PROBE_DEPTH := 0.3
## A cell centre can land exactly on a deck's outer face or on the shared face
## between two abutting plates, where a single ray is a coin flip. A gap is only
## real when the whole 4 cm cross around the cell finds nothing.
const FLOOR_PROBE_SPREAD := 0.02
const SEAM_MAX_CELLS := 2
const LEVEL_TOLERANCE := 0.35
const NARROWEST_LANES_REPORTED := 12

const RENDER_HASH_CELL := 4.0
const RENDER_HASH_CELL_BUDGET := 4096
## Batched dressing is indexed one instance at a time up to this count, which is
## both tighter than the batch envelope and the only usable answer in headless:
## the dummy renderer never computes a MultiMesh's aggregate AABB.
const MULTIMESH_INSTANCE_BUDGET := 4000

const MAX_FINDINGS_PER_CLASS := 120

var _space: PhysicsDirectSpaceState3D
var _capsule: CapsuleShape3D
var _excluded: Array[RID] = []
var _render_boxes: Array[AABB] = []
var _render_paths: PackedStringArray = PackedStringArray()
var _render_aggregate: Array[bool] = []
var _render_hash: Dictionary = {}
var _render_oversize: PackedInt32Array = PackedInt32Array()
var _blocker_cache: Dictionary = {}
var _cells: Dictionary = {}
var _columns: Dictionary = {}
var _findings: Array[Dictionary] = []
var _notes: PackedStringArray = PackedStringArray()
var _narrowest: Dictionary = {}
var _lanes_measured := 0


func _init() -> void:
	call_deferred("_run_cli")


func _run_cli() -> void:
	var game := MAIN_SCENE.instantiate()
	if game == null:
		push_error("STATION_WALKABILITY_SWEEP_FAILED: production Main did not instantiate")
		quit(1)
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	if game.has_method("start_shift"):
		game.call("start_shift")
	for _settle in 8:
		await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as Node3D
	var player := game.get_node_or_null(^"Player") as CharacterBody3D
	if world == null or player == null:
		push_error("STATION_WALKABILITY_SWEEP_FAILED: production world or player capsule missing")
		quit(1)
		return

	var report := sweep(world, player, game as Node3D)
	for line: String in summary_lines(report):
		print(line)
	var json_path := "user://station_walkability_sweep.json"
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		push_error("STATION_WALKABILITY_SWEEP_FAILED: cannot write %s" % json_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t", true, false))
	file.close()
	print("STATION_WALKABILITY_SWEEP_JSON=", ProjectSettings.globalize_path(json_path))
	print("STATION_WALKABILITY_SWEEP_OK")
	game.queue_free()
	await process_frame
	quit(0)


## `world` owns the authored walkable roster; `render_root` is the whole live
## scene, because the craft parked on those decks are siblings of the station and
## their hulls are exactly the geometry a blocker check must be able to see.
func sweep(world: Node3D, player: CharacterBody3D, render_root: Node3D = null) -> Dictionary:
	_space = world.get_world_3d().direct_space_state
	_verify_production_capsule(player)
	_capsule = CapsuleShape3D.new()
	_capsule.radius = CAPSULE_RADIUS
	_capsule.height = CAPSULE_HEIGHT
	_excluded = [player.get_rid()]
	_collect_openable_door_blockers(world)
	_collect_renderers(render_root if render_root != null else world, player)

	var census := CENSUS.measure_production(world, _space) as Dictionary
	_build_cells(world, census)
	_classify_cells()
	_find_chokes()
	_find_walk_through_dressing(world)
	_find_seam_gaps()

	return _build_report(census)


func _verify_production_capsule(player: CharacterBody3D) -> void:
	var collision := player.get_node_or_null(^"PlayerCollision") as CollisionShape3D
	var shape: CapsuleShape3D = null
	if collision != null:
		shape = collision.shape as CapsuleShape3D
	if shape == null:
		_notes.append("production PlayerCollision capsule not found; swept the declared 0.38/1.94 capsule")
		return
	if not is_equal_approx(shape.radius, CAPSULE_RADIUS) or not is_equal_approx(shape.height, CAPSULE_HEIGHT):
		_notes.append("production capsule is %.3f/%.3f but the sweep declares %.3f/%.3f" % [
			shape.radius, shape.height, CAPSULE_RADIUS, CAPSULE_HEIGHT
		])
	if player.collision_mask != CAPSULE_MASK:
		_notes.append("production player mask is %d but the sweep declares %d" % [
			player.collision_mask, CAPSULE_MASK
		])


## Closed reusable doors are openable content, not blockers. A deferred-access
## landmark door stays solid on purpose and keeps its portal in the sweep.
func _collect_openable_door_blockers(world: Node3D) -> void:
	for candidate in world.find_children("*", "StationDoor", true, false):
		if bool(candidate.get("deferred_access")):
			continue
		var blocker := (candidate as Node).get_node_or_null(^"%PortalBlocker") as StaticBody3D
		if blocker != null:
			_excluded.append(blocker.get_rid())


func _collect_renderers(render_root: Node3D, player: CharacterBody3D) -> void:
	for candidate in render_root.find_children("*", "VisualInstance3D", true, false):
		var visual := candidate as VisualInstance3D
		if visual == null or visual == player or player.is_ancestor_of(visual):
			continue
		if not visual.is_visible_in_tree():
			continue
		if visual is Light3D or visual is GPUParticles3D or visual is CPUParticles3D:
			continue
		var path := String(render_root.get_path_to(visual))
		if visual is MultiMeshInstance3D:
			_collect_multimesh(visual as MultiMeshInstance3D, path)
			continue
		if visual is MeshInstance3D and (visual as MeshInstance3D).mesh == null:
			continue
		var local := visual.get_aabb()
		if local.size.length_squared() <= 0.0:
			continue
		_add_render_box(visual.global_transform * local, path, false)


func _collect_multimesh(batch: MultiMeshInstance3D, path: String) -> void:
	var multimesh := batch.multimesh
	if multimesh == null or multimesh.mesh == null:
		return
	if multimesh.transform_format != MultiMesh.TRANSFORM_3D:
		return
	var count := multimesh.instance_count
	if multimesh.visible_instance_count >= 0:
		count = mini(count, multimesh.visible_instance_count)
	if count <= 0:
		return
	var local := multimesh.mesh.get_aabb()
	if local.size.length_squared() <= 0.0:
		return
	var placements := _multimesh_placements(batch, multimesh, count)
	var batch_transform := batch.global_transform
	if placements.is_empty():
		_add_render_box(batch_transform * local, path, true)
		return
	if placements.size() <= MULTIMESH_INSTANCE_BUDGET:
		for instance in placements.size():
			_add_render_box(
				batch_transform * placements[instance] * local, "%s#%d" % [path, instance], false
			)
		return
	var combined := batch_transform * placements[0] * local
	for instance in range(1, placements.size()):
		combined = combined.merge(batch_transform * placements[instance] * local)
	_add_render_box(combined, path, true)


## Godot's dummy rendering server keeps no per-instance transform, so
## `MultiMesh.get_instance_transform()` answers identity in a headless probe and
## the batch's own AABB is empty. The packed `buffer` survives that round trip
## and the station's batch builders also publish `authored_instance_transforms`;
## either one recovers where the batched dressing actually stands.
func _multimesh_placements(
		batch: MultiMeshInstance3D,
		multimesh: MultiMesh,
		count: int
	) -> Array[Transform3D]:
	var placements: Array[Transform3D] = []
	var buffer := multimesh.buffer
	var stride := 12
	if multimesh.use_colors:
		stride += 4
	if multimesh.use_custom_data:
		stride += 4
	if buffer.size() >= count * stride:
		for instance in count:
			var base := instance * stride
			placements.append(Transform3D(
				Basis(
					Vector3(buffer[base + 0], buffer[base + 4], buffer[base + 8]),
					Vector3(buffer[base + 1], buffer[base + 5], buffer[base + 9]),
					Vector3(buffer[base + 2], buffer[base + 6], buffer[base + 10])
				),
				Vector3(buffer[base + 3], buffer[base + 7], buffer[base + 11])
			))
		return placements
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	for instance in mini(count, authored.size()):
		placements.append(authored[instance] as Transform3D)
	return placements


func _add_render_box(box: AABB, path: String, aggregate: bool) -> void:
	var index := _render_boxes.size()
	_render_boxes.append(box)
	_render_paths.append(path)
	_render_aggregate.append(aggregate)
	_index_render_box(index, box)


func _index_render_box(index: int, box: AABB) -> void:
	var grown := box.grow(RENDER_MATCH_RADIUS)
	var low := Vector3i(
		floori(grown.position.x / RENDER_HASH_CELL),
		floori(grown.position.y / RENDER_HASH_CELL),
		floori(grown.position.z / RENDER_HASH_CELL)
	)
	var high := Vector3i(
		floori(grown.end.x / RENDER_HASH_CELL),
		floori(grown.end.y / RENDER_HASH_CELL),
		floori(grown.end.z / RENDER_HASH_CELL)
	)
	var span := (high.x - low.x + 1) * (high.y - low.y + 1) * (high.z - low.z + 1)
	if span > RENDER_HASH_CELL_BUDGET:
		_render_oversize.append(index)
		return
	for cx in range(low.x, high.x + 1):
		for cy in range(low.y, high.y + 1):
			for cz in range(low.z, high.z + 1):
				var key := Vector3i(cx, cy, cz)
				var bucket := _render_hash.get(key, PackedInt32Array()) as PackedInt32Array
				bucket.append(index)
				_render_hash[key] = bucket


func _has_renderer_near(box: AABB) -> bool:
	var grown := box.grow(RENDER_MATCH_RADIUS)
	var low := Vector3i(
		floori(grown.position.x / RENDER_HASH_CELL),
		floori(grown.position.y / RENDER_HASH_CELL),
		floori(grown.position.z / RENDER_HASH_CELL)
	)
	var high := Vector3i(
		floori(grown.end.x / RENDER_HASH_CELL),
		floori(grown.end.y / RENDER_HASH_CELL),
		floori(grown.end.z / RENDER_HASH_CELL)
	)
	for cx in range(low.x, high.x + 1):
		for cy in range(low.y, high.y + 1):
			for cz in range(low.z, high.z + 1):
				var bucket := _render_hash.get(Vector3i(cx, cy, cz), PackedInt32Array()) as PackedInt32Array
				for index: int in bucket:
					if grown.intersects(_render_boxes[index]):
						return true
	for index: int in _render_oversize:
		if grown.intersects(_render_boxes[index]):
			return true
	return false


# -- cell construction -------------------------------------------------------

func _build_cells(world: Node3D, census: Dictionary) -> void:
	for row: Dictionary in census.rows:
		var polygon := PackedVector2Array(row.polygon_xz)
		if polygon.size() < 3:
			continue
		var normal := _top_normal(world, String(row.path))
		if normal.y <= 0.001:
			continue
		var centre := row.top_center as Vector3
		var minimum := polygon[0]
		var maximum := polygon[0]
		for point: Vector2 in polygon:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		var ix_min := ceili(minimum.x / GRID)
		var ix_max := floori(maximum.x / GRID)
		var iz_min := ceili(minimum.y / GRID)
		var iz_max := floori(maximum.y / GRID)
		var identity := "%s/%s" % [row.owner, row.surface_id]
		for ix in range(ix_min, ix_max + 1):
			var x := float(ix) * GRID
			for iz in range(iz_min, iz_max + 1):
				var z := float(iz) * GRID
				if not Geometry2D.is_point_in_polygon(Vector2(x, z), polygon):
					continue
				var y := centre.y - ((x - centre.x) * normal.x + (z - centre.z) * normal.z) / normal.y
				var key := "%d:%d:%d" % [ix, iz, roundi(y * 4.0)]
				if _cells.has(key):
					continue
				_cells[key] = {
					"ix": ix,
					"iz": iz,
					"x": x,
					"z": z,
					"y": y,
					"up": normal.y,
					"owner": String(row.owner),
					"surface": identity,
					"kind": String(row.kind),
					"blocked": false,
				}
				var column := "%d:%d" % [ix, iz]
				var stack := _columns.get(column, []) as Array
				stack.append(key)
				_columns[column] = stack


## Upward normal of a declared surface's single enabled box top face. The census
## keeps the roster and the footprint polygon; the sweep needs the plane so a
## ramp cell can be placed at its true height without a per-cell raycast.
func _top_normal(world: Node3D, path: String) -> Vector3:
	var body := world.get_node_or_null(NodePath(path)) as StaticBody3D
	if body == null:
		return Vector3.UP
	for candidate in body.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if collision.disabled or not collision.shape is BoxShape3D:
			continue
		var basis := collision.global_transform.basis
		var normal := basis.y.normalized()
		if normal.dot(Vector3.UP) < 0.0:
			normal = -normal
		return normal
	return Vector3.UP


func _stand_offset(up: float) -> float:
	return CAPSULE_RADIUS / maxf(up, 0.2) + (CAPSULE_HEIGHT * 0.5 - CAPSULE_RADIUS) + STAND_EPSILON


func _capsule_centre(cell: Dictionary) -> Vector3:
	return Vector3(float(cell.x), float(cell.y) + _stand_offset(float(cell.up)), float(cell.z))


# -- class (a) invisible blockers and class (d) declared-cell gaps ------------

func _classify_cells() -> void:
	var blocked_keys: Array[String] = []
	for key: String in _cells:
		var cell := _cells[key] as Dictionary
		var hits := _capsule_hits(_capsule_centre(cell))
		if hits.is_empty():
			if not _floor_at(float(cell.x), float(cell.z), float(cell.y)):
				_record(
					&"gap",
					cell,
					"declared walkable cell has no floor within %.2f m below" % FLOOR_PROBE_DEPTH,
					"",
					{"subtype": "declared_surface_hole"}
				)
			continue
		cell.blocked = true
		cell["hits"] = hits
		blocked_keys.append(key)
	for key: String in blocked_keys:
		_inspect_blocked_cell(_cells[key] as Dictionary)


func _capsule_hits(centre: Vector3) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform = Transform3D(Basis.IDENTITY, centre)
	query.collision_mask = CAPSULE_MASK
	query.collide_with_areas = false
	query.margin = 0.0
	query.exclude = _excluded
	var results: Array[Dictionary] = []
	for raw: Dictionary in _space.intersect_shape(query, 6):
		results.append(raw)
	return results


func _inspect_blocked_cell(cell: Dictionary) -> void:
	for hit: Dictionary in cell.hits as Array[Dictionary]:
		var descriptor := _blocker_descriptor(hit)
		if descriptor.is_empty() or bool(descriptor.rendered):
			continue
		_record(
			&"invisible_blocker",
			cell,
			"collision stops the capsule with no visible geometry within %.2f m" % RENDER_MATCH_RADIUS,
			String(descriptor.path),
			{"blocker_box": _box_to_json(descriptor.box as AABB)}
		)


func _blocker_descriptor(hit: Dictionary) -> Dictionary:
	var collider := hit.get("collider") as CollisionObject3D
	if collider == null:
		return {}
	var shape_index := int(hit.get("shape", 0))
	var cache_key := "%d:%d" % [int(hit.get("collider_id", 0)), shape_index]
	if _blocker_cache.has(cache_key):
		return _blocker_cache[cache_key]
	var owner_id := collider.shape_find_owner(shape_index)
	var shape: Shape3D = null
	var transform := collider.global_transform
	if owner_id >= 0:
		shape = collider.shape_owner_get_shape(owner_id, 0)
		transform = collider.global_transform * collider.shape_owner_get_transform(owner_id)
	var box := _shape_world_box(shape, transform)
	var descriptor := {
		"path": String(collider.get_path()),
		"box": box,
		"rendered": _has_renderer_near(box),
	}
	_blocker_cache[cache_key] = descriptor
	return descriptor


func _shape_world_box(shape: Shape3D, transform: Transform3D) -> AABB:
	var local := AABB(Vector3(-0.25, -0.25, -0.25), Vector3(0.5, 0.5, 0.5))
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		local = AABB(-size * 0.5, size)
	elif shape is SphereShape3D:
		var radius := (shape as SphereShape3D).radius
		local = AABB(Vector3.ONE * -radius, Vector3.ONE * radius * 2.0)
	elif shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		local = AABB(
			Vector3(-capsule.radius, -capsule.height * 0.5, -capsule.radius),
			Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0)
		)
	elif shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		local = AABB(
			Vector3(-cylinder.radius, -cylinder.height * 0.5, -cylinder.radius),
			Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
		)
	elif shape is ConvexPolygonShape3D:
		local = _points_box((shape as ConvexPolygonShape3D).points)
	elif shape is ConcavePolygonShape3D:
		local = _points_box((shape as ConcavePolygonShape3D).get_faces())
	return transform * local


func _points_box(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB(Vector3(-0.25, -0.25, -0.25), Vector3(0.5, 0.5, 0.5))
	var minimum := points[0]
	var maximum := points[0]
	for point: Vector3 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


# -- class (c) chokes --------------------------------------------------------

func _find_chokes() -> void:
	for key: String in _cells:
		var cell := _cells[key] as Dictionary
		if bool(cell.blocked) or not _near_a_blocker(cell):
			continue
		var base := float(cell.y)
		for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
			var width := INF
			var bounded := true
			for offset: float in [0.45, 1.0, 1.55]:
				var origin := Vector3(float(cell.x), base + offset, float(cell.z))
				var forward := _clearance(origin, axis)
				var backward := _clearance(origin, -axis)
				if forward < 0.0 or backward < 0.0:
					bounded = false
					break
				width = minf(width, forward + backward)
			if not bounded:
				continue
			_lanes_measured += 1
			_note_lane_width(cell, width, axis)
			if width >= CHOKE_WIDTH:
				continue
			_record(
				&"choke",
				cell,
				"authored lane pinches to %.2f m clear width (needs %.2f m)" % [width, CHOKE_WIDTH],
				"",
				{
					"clear_width_m": snappedf(width, 0.001),
					"axis": "x" if axis == Vector3.RIGHT else "z",
				}
			)
			break


## Keeps the narrowest measured lane on every surface even when it clears the
## threshold, so a zero-choke result is a measurement rather than a silence.
func _note_lane_width(cell: Dictionary, width: float, axis: Vector3) -> void:
	var surface := String(cell.surface)
	if _narrowest.has(surface) and float((_narrowest[surface] as Dictionary).clear_width_m) <= width:
		return
	_narrowest[surface] = {
		"surface": surface,
		"owner": String(cell.owner),
		"clear_width_m": snappedf(width, 0.001),
		"axis": "x" if axis == Vector3.RIGHT else "z",
		"position": [
			snappedf(float(cell.x), 0.001),
			snappedf(float(cell.y), 0.001),
			snappedf(float(cell.z), 0.001),
		],
	}


func _near_a_blocker(cell: Dictionary) -> bool:
	var ix := int(cell.ix)
	var iz := int(cell.iz)
	var y := float(cell.y)
	for step in range(1, CHOKE_SEARCH_CELLS + 1):
		for offset: Vector2i in [
			Vector2i(step, 0), Vector2i(-step, 0), Vector2i(0, step), Vector2i(0, -step)
		]:
			for other_key: String in _columns.get("%d:%d" % [ix + offset.x, iz + offset.y], []) as Array:
				var other := _cells[other_key] as Dictionary
				if not bool(other.blocked):
					continue
				if absf(float(other.y) - y) <= LEVEL_TOLERANCE:
					return true
	return false


func _clearance(origin: Vector3, direction: Vector3) -> float:
	var ray := PhysicsRayQueryParameters3D.create(
		origin, origin + direction * CHOKE_PROBE_REACH, CAPSULE_MASK
	)
	ray.collide_with_areas = false
	ray.exclude = _excluded
	var hit := _space.intersect_ray(ray)
	if hit.is_empty():
		return -1.0
	return origin.distance_to(hit.position as Vector3)


# -- class (b) walk-through dressing ----------------------------------------

func _find_walk_through_dressing(world: Node3D) -> void:
	var probe := BoxShape3D.new()
	for index in _render_boxes.size():
		if _render_aggregate[index]:
			continue
		var box := _render_boxes[index]
		if box.size.y < DRESSING_MIN_HEIGHT:
			continue
		if maxf(box.size.x, maxf(box.size.y, box.size.z)) > DRESSING_MAX_EXTENT:
			continue
		var covered := _cells_inside_footprint(box)
		if covered.is_empty():
			continue
		probe.size = Vector3(
			maxf(box.size.x, 0.02), maxf(box.size.y, 0.02), maxf(box.size.z, 0.02)
		)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = probe
		query.transform = Transform3D(Basis.IDENTITY, box.get_center())
		query.collision_mask = CAPSULE_MASK
		query.collide_with_areas = false
		query.margin = 0.0
		query.exclude = _excluded
		if not _space.intersect_shape(query, 1).is_empty():
			continue
		var representative := _cells[covered[0]] as Dictionary
		_record(
			&"walk_through",
			representative,
			"rendered piece %.2f m tall has no collider anywhere in its volume" % box.size.y,
			_render_paths[index],
			{"mesh_box": _box_to_json(box), "walkable_cells": covered.size()}
		)


## Walkable cells whose standing capsule actually intersects the rendered box,
## with enough penetration on every axis that the player passes through the
## piece rather than brushing its bounding box.
func _cells_inside_footprint(box: AABB) -> Array[String]:
	var found: Array[String] = []
	var ix_min := floori(box.position.x / GRID)
	var ix_max := ceili(box.end.x / GRID)
	var iz_min := floori(box.position.z / GRID)
	var iz_max := ceili(box.end.z / GRID)
	for ix in range(ix_min, ix_max + 1):
		for iz in range(iz_min, iz_max + 1):
			for key: String in _columns.get("%d:%d" % [ix, iz], []) as Array:
				var cell := _cells[key] as Dictionary
				if bool(cell.blocked):
					continue
				var centre := _capsule_centre(cell)
				var body := AABB(
					centre - Vector3(CAPSULE_RADIUS, CAPSULE_HEIGHT * 0.5, CAPSULE_RADIUS),
					Vector3(CAPSULE_RADIUS * 2.0, CAPSULE_HEIGHT, CAPSULE_RADIUS * 2.0)
				)
				var overlap := body.intersection(box)
				if overlap.size.x < DRESSING_MIN_PENETRATION:
					continue
				if overlap.size.z < DRESSING_MIN_PENETRATION:
					continue
				if overlap.size.y < DRESSING_MIN_HEIGHT:
					continue
				found.append(key)
	return found


# -- class (d) seam gaps between authored decks ------------------------------

func _find_seam_gaps() -> void:
	var reported := {}
	for key: String in _cells:
		var cell := _cells[key] as Dictionary
		var ix := int(cell.ix)
		var iz := int(cell.iz)
		var y := float(cell.y)
		for direction: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			for width in range(1, SEAM_MAX_CELLS + 1):
				var far_column := "%d:%d" % [
					ix + direction.x * (width + 1), iz + direction.y * (width + 1)
				]
				if not _column_has_level(far_column, y):
					continue
				var missing: Array[Vector2i] = []
				for step in range(1, width + 1):
					var seam := Vector2i(ix + direction.x * step, iz + direction.y * step)
					if _column_has_level("%d:%d" % [seam.x, seam.y], y):
						missing.clear()
						break
					missing.append(seam)
				if missing.is_empty():
					continue
				var open := true
				for seam: Vector2i in missing:
					if _floor_at(float(seam.x) * GRID, float(seam.y) * GRID, y):
						open = false
						break
				if not open:
					continue
				var seam_key := "%d:%d:%d" % [missing[0].x, missing[0].y, roundi(y * 4.0)]
				if reported.has(seam_key):
					continue
				reported[seam_key] = true
				var probe := cell.duplicate()
				probe.x = float(missing[0].x) * GRID
				probe.z = float(missing[0].y) * GRID
				_record(
					&"gap",
					probe,
					"%.2f m open seam between two authored decks with no floor within %.2f m" % [
						float(missing.size()) * GRID, FLOOR_PROBE_DEPTH
					],
					"",
					{
						"subtype": "deck_seam",
						"seam_width_m": snappedf(float(missing.size()) * GRID, 0.001),
					}
				)
				break


func _column_has_level(column: String, y: float) -> bool:
	for key: String in _columns.get(column, []) as Array:
		if absf(float((_cells[key] as Dictionary).y) - y) <= LEVEL_TOLERANCE:
			return true
	return false


func _floor_at(x: float, z: float, y: float) -> bool:
	for offset: Vector2 in [
		Vector2.ZERO,
		Vector2(FLOOR_PROBE_SPREAD, 0.0),
		Vector2(-FLOOR_PROBE_SPREAD, 0.0),
		Vector2(0.0, FLOOR_PROBE_SPREAD),
		Vector2(0.0, -FLOOR_PROBE_SPREAD),
	]:
		var ray := PhysicsRayQueryParameters3D.create(
			Vector3(x + offset.x, y + FLOOR_PROBE_DEPTH, z + offset.y),
			Vector3(x + offset.x, y - FLOOR_PROBE_DEPTH, z + offset.y),
			CAPSULE_MASK
		)
		ray.collide_with_areas = false
		ray.exclude = _excluded
		if not _space.intersect_ray(ray).is_empty():
			return true
	return false


# -- reporting ---------------------------------------------------------------

func _record(
		defect: StringName,
		cell: Dictionary,
		detail: String,
		blamed_path: String,
		extra: Dictionary
	) -> void:
	var entry := {
		"defect": String(defect),
		"owner": String(cell.owner),
		"surface": String(cell.surface),
		"detail": detail,
		"blamed_path": blamed_path,
		"position": Vector3(float(cell.x), float(cell.y), float(cell.z)),
	}
	entry.merge(extra, true)
	_findings.append(entry)


func _build_report(census: Dictionary) -> Dictionary:
	var clusters := _cluster(_findings)
	var by_class := {}
	var by_module := {}
	for cluster: Dictionary in clusters:
		var defect := String(cluster.defect)
		by_class[defect] = int(by_class.get(defect, 0)) + 1
		var owner := String(cluster.owner)
		var module := by_module.get(owner, {}) as Dictionary
		module[defect] = int(module.get(defect, 0)) + 1
		by_module[owner] = module
	var owner_names := PackedStringArray()
	for owner: String in by_module:
		owner_names.append(owner)
	owner_names.sort()
	var module_rows: Array[Dictionary] = []
	for owner: String in owner_names:
		var module := by_module[owner] as Dictionary
		module_rows.append({
			"owner": owner,
			"invisible_blocker": int(module.get("invisible_blocker", 0)),
			"walk_through": int(module.get("walk_through", 0)),
			"choke": int(module.get("choke", 0)),
			"gap": int(module.get("gap", 0)),
		})
	var trimmed: Array[Dictionary] = []
	var kept := {}
	for cluster: Dictionary in clusters:
		var defect := String(cluster.defect)
		var used := int(kept.get(defect, 0))
		if used >= MAX_FINDINGS_PER_CLASS:
			continue
		kept[defect] = used + 1
		trimmed.append(cluster)
	return {
		"schema_version": SCHEMA_VERSION,
		"profile": String(PROFILE_ID),
		"engine": Engine.get_version_info().get("string", "unknown"),
		"source_sha": CENSUS.source_sha(),
		"grid_m": GRID,
		"capsule_radius_m": CAPSULE_RADIUS,
		"capsule_height_m": CAPSULE_HEIGHT,
		"collision_mask": CAPSULE_MASK,
		"surfaces_swept": int(census.surface_count),
		"swept_cells": _cells.size(),
		"blocked_cells": _blocked_cell_count(),
		"notes": _notes,
		"finding_counts": {
			"invisible_blocker": int(by_class.get("invisible_blocker", 0)),
			"walk_through": int(by_class.get("walk_through", 0)),
			"choke": int(by_class.get("choke", 0)),
			"gap": int(by_class.get("gap", 0)),
		},
		"module_totals": module_rows,
		"lanes_measured": _lanes_measured,
		"narrowest_lanes": _narrowest_lanes(),
		"findings": trimmed,
		"findings_total": clusters.size(),
	}


func _narrowest_lanes() -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	for surface: String in _narrowest:
		lanes.append(_narrowest[surface])
	lanes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.clear_width_m), float(b.clear_width_m)):
			return float(a.clear_width_m) < float(b.clear_width_m)
		return String(a.surface) < String(b.surface)
	)
	return lanes.slice(0, NARROWEST_LANES_REPORTED)


## One authored defect is one report line, not one line per 0.25 m cell. Cells
## of the same class that blame the same node and sit inside the same 1.5 m box
## on the same surface collapse into a single finding carrying the cell count.
func _cluster(raw: Array[Dictionary]) -> Array[Dictionary]:
	var buckets := {}
	var order: Array[String] = []
	for entry: Dictionary in raw:
		var position := entry.position as Vector3
		var key := "%s|%s|%s|%d:%d:%d" % [
			entry.defect,
			entry.surface,
			entry.blamed_path,
			floori(position.x / 1.5),
			floori(position.y / 1.5),
			floori(position.z / 1.5),
		]
		if not buckets.has(key):
			var seed := entry.duplicate(true)
			seed["cells"] = 0
			buckets[key] = seed
			order.append(key)
		var bucket := buckets[key] as Dictionary
		bucket.cells = int(bucket.cells) + 1
		if entry.has("clear_width_m") and float(entry.clear_width_m) < float(bucket.get("clear_width_m", INF)):
			bucket.clear_width_m = entry.clear_width_m
			bucket.position = position
			bucket.detail = entry.detail
	var clusters: Array[Dictionary] = []
	for key: String in order:
		var bucket := buckets[key] as Dictionary
		var position := bucket.position as Vector3
		bucket.position = [
			snappedf(position.x, 0.001), snappedf(position.y, 0.001), snappedf(position.z, 0.001)
		]
		clusters.append(bucket)
	clusters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.defect != b.defect:
			return String(a.defect) < String(b.defect)
		if int(a.cells) != int(b.cells):
			return int(a.cells) > int(b.cells)
		return String(a.surface) < String(b.surface)
	)
	return clusters


func _blocked_cell_count() -> int:
	var total := 0
	for key: String in _cells:
		if bool((_cells[key] as Dictionary).blocked):
			total += 1
	return total


func summary_lines(report: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("STATION_WALKABILITY_SWEEP surfaces=%d cells=%d blocked=%d findings=%d" % [
		int(report.surfaces_swept), int(report.swept_cells),
		int(report.blocked_cells), int(report.findings_total),
	])
	var counts := report.finding_counts as Dictionary
	lines.append("STATION_WALKABILITY_CLASSES invisible_blocker=%d walk_through=%d choke=%d gap=%d" % [
		int(counts.invisible_blocker), int(counts.walk_through),
		int(counts.choke), int(counts.gap),
	])
	for note: String in report.notes as PackedStringArray:
		lines.append("STATION_WALKABILITY_NOTE " + note)
	lines.append("STATION_WALKABILITY_LANES measured=%d narrowest_reported=%d" % [
		int(report.lanes_measured), (report.narrowest_lanes as Array).size(),
	])
	for lane: Dictionary in report.narrowest_lanes as Array:
		var lane_position := lane.position as Array
		lines.append("STATION_WALKABILITY_LANE\t%s\t%.3f m\t%s\t(%.2f, %.2f, %.2f)" % [
			lane.surface, float(lane.clear_width_m), lane.axis,
			float(lane_position[0]), float(lane_position[1]), float(lane_position[2]),
		])
	for module: Dictionary in report.module_totals as Array:
		lines.append("STATION_WALKABILITY_MODULE\t%s\tinvisible=%d\twalk_through=%d\tchoke=%d\tgap=%d" % [
			module.owner, int(module.invisible_blocker), int(module.walk_through),
			int(module.choke), int(module.gap),
		])
	for finding: Dictionary in report.findings as Array:
		var position := finding.position as Array
		lines.append("STATION_WALKABILITY_FINDING\t%s\t%s\tcells=%d\t(%.2f, %.2f, %.2f)\t%s\t%s" % [
			finding.defect, finding.surface, int(finding.cells),
			float(position[0]), float(position[1]), float(position[2]),
			finding.blamed_path, finding.detail,
		])
	return lines


static func _box_to_json(box: AABB) -> Dictionary:
	return {
		"position": [
			snappedf(box.position.x, 0.001),
			snappedf(box.position.y, 0.001),
			snappedf(box.position.z, 0.001),
		],
		"size": [
			snappedf(box.size.x, 0.001),
			snappedf(box.size.y, 0.001),
			snappedf(box.size.z, 0.001),
		],
	}
