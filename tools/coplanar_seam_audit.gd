class_name CoplanarSeamAudit
extends SceneTree

## Coplanar-seam / z-fighting audit for the production scene (Phase 10 §1, §3).
##
## Z-fighting is not a property of one node, so no per-module test can find it:
## it happens when two *different* opaque renderers put solid faces on the same
## world plane within depth precision. A sign plate laid flush on a wall, a floor
## patch dropped on a deck at zero offset, a decal authored as a box, a second
## panel stacked on the first -- at gameplay distance the depth buffer cannot
## separate them and the surface flickers as the camera moves.
##
## This probe boots `scenes/main.tscn` exactly like
## `tests/geometry_census_scenario_test.gd`, walks every visible opaque
## `MeshInstance3D` and `MultiMeshInstance3D` copy (decoding `MultiMesh.buffer`
## or `authored_instance_transforms` the way `tools/station_walkability_sweep.gd`
## does, because the headless rendering server answers identity for
## `get_instance_transform()`), reduces each mesh to its dominant world-space
## planar faces, and reports every pair that is:
##
##   * parallel within `PARALLEL_TOLERANCE_DEG`,
##   * offset by no more than `OFFSET_TOLERANCE_M` along the shared normal,
##   * overlapping by at least `MIN_OVERLAP_AREA_M2` of real face polygon area.
##
## Four classes of legitimate coincidence are excluded rather than reported:
##
##   back-to-back  the two faces point into each other -- two solids in contact.
##                 Backface culling removes one of them before the depth test, so
##                 the pair cannot flicker.
##   interior      one face lies strictly inside the other renderer's closed
##                 volume (its world AABB, shrunk by `INTERIOR_MARGIN_M`, is the
##                 cheap proxy, and only for a box-like renderer that actually
##                 fills its box). Nothing inside a solid can fight on screen.
##   occluded      both faces are themselves already in back-to-back contact over
##                 the whole overlap: two props standing on one deck, each
##                 pressed flat against it. Neither is visible.
##   declared      a `coplanar_by_design` metadata key on either renderer (or an
##                 ancestor) *and* an identical material on both faces. That is
##                 one material rendering identically on a shared plane, which is
##                 a seam the author chose, not a defect.
##
## Reported normals are facing directions. Godot winds front faces clockwise, so
## the geometric cross-product normal points away from the visible side and is
## negated on the way out; the parallel and same-facing tests are unaffected
## because both faces flip together.
##
## The probe is triage, not a gate: it always exits 0 once the scene boots,
## prints a per-module summary, and writes the full list to
## `user://coplanar_seam_audit.json`.

const SCHEMA_VERSION := 1
const PROFILE_ID := &"coplanar_seam_audit_v1"
const MAIN_SCENE := preload("res://scenes/main.tscn")
const DESIGN_META := &"coplanar_by_design"

## Depth precision at gameplay distance, not mathematical coincidence: a 0.5 deg
## wedge and a 3 mm gap both still resolve to the same depth sample on a 1280x720
## compatibility-renderer frame a few metres away.
const PARALLEL_TOLERANCE_DEG := 0.5
const OFFSET_TOLERANCE_M := 0.003
## A patch smaller than a 10 cm square cannot produce a seam a player reads as
## flicker, and pruning them is what keeps this probe inside a minute.
const MIN_FACE_AREA_M2 := 0.01
const MIN_OVERLAP_AREA_M2 := 0.01
## Half a millimetre, not four: a plate laid flush *on* a wall has its back face
## exactly on that wall's boundary plane and must stay in the report, while a
## panel genuinely recessed a millimetre inside a solid is invisible and must not.
const INTERIOR_MARGIN_M := 0.0005

const GRID_CELL := 1.0
const GRID_SPAN_BUDGET := 4096
const MULTIMESH_INSTANCE_BUDGET := 2048
## Above this a face group is replaced by the convex hull of its own outline;
## the overlap it reports is then an upper bound and the finding says so.
const POLYGON_TRIANGLE_BUDGET := 64
const MAX_TRIANGLES_PER_SURFACE := 40000
const MIN_LOCAL_AREA_M2 := 1.0e-5
const MAX_FINDINGS := 2000
const EYE_HEIGHT := 1.6
const SETTLE_FRAMES := 8
const PARALLEL_COSINE := cos(deg_to_rad(PARALLEL_TOLERANCE_DEG))
## Share of a same-facing overlap that must already be in back-to-back contact
## before the pair counts as pressed against a solid rather than fighting on it.
const OCCLUSION_COVERAGE := 0.95

var _instances: Array[Dictionary] = []
var _face_normal: Array[Vector3] = []
var _face_d := PackedFloat64Array()
var _face_area := PackedFloat64Array()
var _face_tris: Array = []
var _face_aabb: Array[AABB] = []
var _face_instance := PackedInt32Array()
var _face_material := PackedInt64Array()
var _face_hulled: Array[bool] = []
var _face_double_sided: Array[bool] = []
var _face_grown: Array[AABB] = []
var _face_backed_area := PackedFloat64Array()

var _mesh_cache: Dictionary = {}
var _mesh_box_like: Dictionary = {}
var _grid: Dictionary = {}
var _oversize := PackedInt32Array()
var _oversize_set: Dictionary = {}
var _viewpoints: Array[Vector3] = []

var _findings: Array[Dictionary] = []
var _declared: Array[Dictionary] = []
var _same_facing: Array = []
var _interior_skips := 0
var _occluded_skips := 0
var _back_to_back_skips := 0
var _pairs_tested := 0
var _notes := PackedStringArray()
var _shadow_only_skips := 0
var _skipped_batches := 0
var _skipped_surfaces := 0
var _phase_ms: Dictionary = {}


func _init() -> void:
	call_deferred("_run_cli")


func _run_cli() -> void:
	var started := Time.get_ticks_msec()
	var game := MAIN_SCENE.instantiate()
	if game == null:
		push_error("COPLANAR_SEAM_AUDIT_FAILED: production Main did not instantiate")
		quit(1)
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	if game.has_method("start_shift"):
		game.call("start_shift")
	for _settle in SETTLE_FRAMES:
		await physics_frame
	await process_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as Node3D
	if world == null:
		push_error("COPLANAR_SEAM_AUDIT_FAILED: production ShipyardWorld missing")
		quit(1)
		return

	var booted := Time.get_ticks_msec()
	_collect_viewpoints(world)
	_collect_renderers(game as Node3D, game.get_node_or_null(^"Player") as Node3D)
	var walked := Time.get_ticks_msec()
	_index_faces()
	var indexed := Time.get_ticks_msec()
	_find_pairs()
	_resolve_pairs()
	_phase_ms = {
		"boot": booted - started,
		"walk": walked - booted,
		"index": indexed - walked,
		"pair": Time.get_ticks_msec() - indexed,
	}
	var report := _build_report(game as Node3D, Time.get_ticks_msec() - started)

	for line: String in summary_lines(report):
		print(line)
	var json_path := "user://coplanar_seam_audit.json"
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		push_error("COPLANAR_SEAM_AUDIT_FAILED: cannot write %s" % json_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t", true, false))
	file.close()
	print("COPLANAR_SEAM_AUDIT_JSON=", ProjectSettings.globalize_path(json_path))
	print("COPLANAR_SEAM_AUDIT_OK")
	game.queue_free()
	await process_frame
	quit(0)


# ---------------------------------------------------------------- collection


## Gameplay distance is measured from where the player can actually stand, which
## is the same authored `walkable_surface` roster the walkable-area census and
## the walkability sweep already discover.
func _collect_viewpoints(world: Node3D) -> void:
	for candidate in world.find_children("*", "PhysicsBody3D", true, false):
		var body := candidate as PhysicsBody3D
		if body == null or not bool(body.get_meta("walkable_surface", false)):
			continue
		for shape_child in body.find_children("*", "CollisionShape3D", true, false):
			var shape := shape_child as CollisionShape3D
			if shape == null or shape.disabled or shape.shape == null:
				continue
			var top := shape.global_position
			if shape.shape is BoxShape3D:
				top += shape.global_basis.y.normalized() \
					* ((shape.shape as BoxShape3D).size.y * 0.5)
			_viewpoints.append(top + Vector3.UP * EYE_HEIGHT)
	if _viewpoints.is_empty():
		_notes.append("no walkable_surface viewpoints found; distances fall back to the origin")
		_viewpoints.append(Vector3.UP * EYE_HEIGHT)


func _collect_renderers(render_root: Node3D, player: Node3D) -> void:
	for candidate in render_root.find_children("*", "VisualInstance3D", true, false):
		var visual := candidate as VisualInstance3D
		if visual == null or visual == player:
			continue
		if player != null and player.is_ancestor_of(visual):
			continue
		if not visual.is_visible_in_tree():
			continue
		if visual is Light3D or visual is GPUParticles3D or visual is CPUParticles3D:
			continue
		# `SHADOWS_ONLY` proxies -- the station's `StaticShadowBatch` envelopes --
		# never reach the colour pass, so they cannot fight anything on screen.
		if visual is GeometryInstance3D and (visual as GeometryInstance3D).cast_shadow \
				== GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			_shadow_only_skips += 1
			continue
		var path := String(render_root.get_path_to(visual))
		if visual is MultiMeshInstance3D:
			_collect_multimesh(visual as MultiMeshInstance3D, path)
		elif visual is MeshInstance3D:
			var instance := visual as MeshInstance3D
			if instance.mesh == null:
				continue
			_add_instance(
				instance, path, -1, instance.global_transform, instance.mesh,
				func(surface: int) -> Material: return instance.get_active_material(surface)
			)


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
	var placements := _multimesh_placements(batch, multimesh, count)
	if placements.is_empty():
		_skipped_batches += 1
		return
	if placements.size() > MULTIMESH_INSTANCE_BUDGET:
		_skipped_batches += 1
		_notes.append("batch over instance budget, not planed: %s (%d copies)" % [
			path, placements.size(),
		])
		return
	var mesh := multimesh.mesh
	var override := batch.material_override
	var resolve := func(surface: int) -> Material:
		if override != null:
			return override
		return mesh.surface_get_material(surface)
	var batch_transform := batch.global_transform
	for copy in placements.size():
		_add_instance(batch, path, copy, batch_transform * placements[copy], mesh, resolve)


## `MultiMesh.get_instance_transform()` answers identity headlessly. The packed
## `buffer` survives that round trip, and the station's batch builders also
## publish `authored_instance_transforms`; either recovers the real placements.
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


func _add_instance(
		node: VisualInstance3D,
		path: String,
		copy: int,
		world_transform: Transform3D,
		mesh: Mesh,
		resolve_material: Callable
	) -> void:
	var groups := _mesh_face_groups(mesh)
	if groups.is_empty():
		return
	var basis := world_transform.basis
	# Conservative upper bound on how much this placement can grow a local face
	# area, so a group can be discarded before any vertex is transformed.
	var stretch := maxf(
		basis.x.length(), maxf(basis.y.length(), basis.z.length())
	)
	var area_bound := stretch * stretch
	if area_bound <= 0.0:
		return
	var kept: Array[Dictionary] = []
	for group_variant in groups:
		var group := group_variant as Dictionary
		if float(group.area) * area_bound < MIN_FACE_AREA_M2:
			continue
		var material := resolve_material.call(int(group.surface)) as Material
		if not _is_opaque(material):
			continue
		kept.append({
			"group": group, "material": material, "double_sided": _is_double_sided(material),
		})
	if kept.is_empty():
		return

	var local_aabb := mesh.get_aabb()
	var index := _instances.size()
	_instances.append({
		"path": path,
		"copy": copy,
		"node_id": node.get_instance_id(),
		"owner": _owner_script(node),
		"module": _module_for(path),
		"declared": _design_declaration(node),
		"aabb": _transformed_aabb(world_transform, local_aabb),
		"box_like": bool(_mesh_box_like.get(mesh.get_instance_id(), false)),
		"faces": 0,
	})
	var instance_row := _instances[index]
	for entry_variant in kept:
		var entry := entry_variant as Dictionary
		var group := entry.group as Dictionary
		var tris: Array = []
		var area := 0.0
		var normal := Vector3.ZERO
		var box := AABB()
		var first := true
		for tri_variant in group.tris as Array:
			var tri := tri_variant as PackedVector3Array
			var a := world_transform * tri[0]
			var b := world_transform * tri[1]
			var c := world_transform * tri[2]
			var cross := (b - a).cross(c - a)
			var length := cross.length()
			if length <= 1.0e-12:
				continue
			area += length * 0.5
			if first:
				normal = cross / length
				box = AABB(a, Vector3.ZERO)
				first = false
			box = box.expand(a)
			box = box.expand(b)
			box = box.expand(c)
			tris.append(PackedVector3Array([a, b, c]))
		if first or area < MIN_FACE_AREA_M2:
			continue
		var material := entry.material as Material
		_face_normal.append(normal)
		_face_d.append(normal.dot((tris[0] as PackedVector3Array)[0]))
		_face_area.append(area)
		_face_tris.append(tris)
		_face_aabb.append(box)
		_face_instance.append(index)
		_face_material.append(0 if material == null else material.get_instance_id())
		_face_hulled.append(bool(group.get("hulled", false)))
		_face_double_sided.append(bool(entry.double_sided))
		instance_row.faces = int(instance_row.faces) + 1
	if int(instance_row.faces) == 0:
		_instances.resize(index)


# ------------------------------------------------------------- mesh planing


## Cached per mesh resource: the station shares its plate and panel meshes
## aggressively, so planing once per unique mesh is what makes the whole walk
## affordable.
func _mesh_face_groups(mesh: Mesh) -> Array:
	var key := mesh.get_instance_id()
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var out: Array = []
	for surface in mesh.get_surface_count():
		# `PrimitiveMesh` -- every `BoxMesh` plate, `PlaneMesh` patch and
		# `CylinderMesh` post in the station -- has no `surface_get_primitive_type`
		# and hands over its single always-triangles surface through
		# `get_mesh_arrays()` instead.
		var arrays: Array = []
		if mesh is PrimitiveMesh:
			arrays = (mesh as PrimitiveMesh).get_mesh_arrays()
		elif mesh is ArrayMesh:
			var array_mesh := mesh as ArrayMesh
			if array_mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			arrays = array_mesh.surface_get_arrays(surface)
		else:
			continue
		if arrays.is_empty() or arrays.size() <= Mesh.ARRAY_INDEX:
			continue
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if verts.is_empty():
			continue
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var indexed := indices.size() > 0
		var tri_count := (indices.size() if indexed else verts.size()) / 3
		if tri_count <= 0:
			continue
		if tri_count > MAX_TRIANGLES_PER_SURFACE:
			_skipped_surfaces += 1
			continue
		var groups := {}
		for triangle in tri_count:
			var base := triangle * 3
			var a := verts[indices[base]] if indexed else verts[base]
			var b := verts[indices[base + 1]] if indexed else verts[base + 1]
			var c := verts[indices[base + 2]] if indexed else verts[base + 2]
			var cross := (b - a).cross(c - a)
			var length := cross.length()
			if length <= 1.0e-12:
				continue
			var normal := cross / length
			var offset := normal.dot(a)
			var group_key := "%d|%d|%d|%d" % [
				roundi(normal.x * 512.0), roundi(normal.y * 512.0),
				roundi(normal.z * 512.0), roundi(offset * 4096.0),
			]
			if not groups.has(group_key):
				groups[group_key] = {
					"surface": surface, "normal": normal, "d": offset,
					"tris": [], "area": 0.0,
				}
			var group := groups[group_key] as Dictionary
			(group.tris as Array).append(PackedVector3Array([a, b, c]))
			group.area = float(group.area) + length * 0.5
		for group_key: String in groups:
			var group := groups[group_key] as Dictionary
			if float(group.area) < MIN_LOCAL_AREA_M2:
				continue
			for component_variant in _split_components(group):
				var component := component_variant as Dictionary
				if float(component.area) < MIN_LOCAL_AREA_M2:
					continue
				if (component.tris as Array).size() > POLYGON_TRIANGLE_BUDGET:
					_hull_group(component)
				out.append(component)
	_mesh_cache[key] = out
	_mesh_box_like[key] = _is_box_like(mesh, out)
	return out


## A merged batch -- one `SurfaceTool` commit holding every rail, post and plate
## in a room -- puts hundreds of unrelated little faces on one shared plane. Left
## whole they read as a single room-sized face and swamp the report. A planar
## *face* is a connected region, so each plane group is split into
## vertex-connected components before anything else looks at it.
func _split_components(group: Dictionary) -> Array:
	var tris := group.tris as Array
	var count := tris.size()
	if count <= 1:
		return [group]
	var parent := PackedInt32Array()
	parent.resize(count)
	for index in count:
		parent[index] = index
	var vertex_owner := {}
	for index in count:
		for point: Vector3 in tris[index] as PackedVector3Array:
			var key := Vector3i(
				roundi(point.x * 10000.0), roundi(point.y * 10000.0), roundi(point.z * 10000.0)
			)
			if vertex_owner.has(key):
				_union(parent, index, int(vertex_owner[key]))
			else:
				vertex_owner[key] = index
	var buckets := {}
	for index in count:
		var root := _find(parent, index)
		if not buckets.has(root):
			buckets[root] = {
				"surface": group.surface, "normal": group.normal, "d": group.d,
				"tris": [], "area": 0.0,
			}
		var component := buckets[root] as Dictionary
		var tri := tris[index] as PackedVector3Array
		(component.tris as Array).append(tri)
		component.area = float(component.area) \
			+ (tri[1] - tri[0]).cross(tri[2] - tri[0]).length() * 0.5
	var out: Array = []
	for root: int in buckets:
		out.append(buckets[root])
	return out


static func _find(parent: PackedInt32Array, index: int) -> int:
	var root := index
	while parent[root] != root:
		root = parent[root]
	var walker := index
	while parent[walker] != root:
		var next := parent[walker]
		parent[walker] = root
		walker = next
	return root


static func _union(parent: PackedInt32Array, left: int, right: int) -> void:
	var left_root := _find(parent, left)
	var right_root := _find(parent, right)
	if left_root != right_root:
		parent[right_root] = left_root


## The AABB-containment shortcut is only truthful for a renderer that actually
## fills its own box. A merged room batch's AABB is the room, so "inside the
## AABB" there would silently bury every real defect in the space. A mesh earns
## the shortcut only when its six largest faces account for most of its own
## bounding box's surface -- that is, when it is a box, plate or rounded box.
static func _is_box_like(mesh: Mesh, components: Array) -> bool:
	var box := mesh.get_aabb()
	var shell := 2.0 * (
		box.size.x * box.size.y + box.size.y * box.size.z + box.size.z * box.size.x
	)
	if shell <= 0.0:
		return false
	var areas := PackedFloat64Array()
	for component_variant in components:
		areas.append(float((component_variant as Dictionary).area))
	areas.sort()
	areas.reverse()
	var dominant := 0.0
	for index in mini(6, areas.size()):
		dominant += areas[index]
	return dominant >= shell * 0.6


## A face carrying more triangles than the budget is replaced by the convex hull
## of its own outline. Overlap computed against a hull is an upper bound, and
## every finding that used one is flagged `approximate`.
func _hull_group(group: Dictionary) -> void:
	var normal := group.normal as Vector3
	var axes := _plane_axes(normal)
	var origin := ((group.tris as Array)[0] as PackedVector3Array)[0]
	var points := PackedVector2Array()
	for tri_variant in group.tris as Array:
		for point: Vector3 in tri_variant as PackedVector3Array:
			var delta := point - origin
			points.append(Vector2(delta.dot(axes[0]), delta.dot(axes[1])))
	var hull := Geometry2D.convex_hull(points)
	if hull.size() < 3:
		return
	var tris: Array = []
	var area := 0.0
	for corner in range(1, hull.size() - 1):
		var a := origin + axes[0] * hull[0].x + axes[1] * hull[0].y
		var b := origin + axes[0] * hull[corner].x + axes[1] * hull[corner].y
		var c := origin + axes[0] * hull[corner + 1].x + axes[1] * hull[corner + 1].y
		var cross := (b - a).cross(c - a)
		if cross.length() <= 1.0e-12:
			continue
		area += cross.length() * 0.5
		tris.append(PackedVector3Array([a, b, c]))
	if tris.is_empty():
		return
	group.tris = tris
	group.area = area
	group["hulled"] = true


static func _plane_axes(normal: Vector3) -> Array[Vector3]:
	var reference := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	var u := normal.cross(reference)
	if u.length_squared() <= 1.0e-12:
		u = normal.cross(Vector3.FORWARD)
	u = u.normalized()
	var axes: Array[Vector3] = [u, normal.cross(u).normalized()]
	return axes


static func _transformed_aabb(world_transform: Transform3D, local: AABB) -> AABB:
	var box := AABB(world_transform * local.position, Vector3.ZERO)
	for corner in 8:
		box = box.expand(world_transform * local.get_endpoint(corner))
	return box


## Only opaque renderers can z-fight: a blended or depth-test-free surface never
## competes for the same depth sample.
static func _is_opaque(material: Material) -> bool:
	if material == null:
		return true
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
		if base.no_depth_test:
			return false
		if base.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
			return false
		return true
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		if shader == null:
			return false
		var code := shader.code
		for marker in [
			"blend_add", "blend_sub", "blend_mul", "blend_premul_alpha",
			"depth_draw_never", "depth_test_disabled",
		]:
			if code.contains(marker):
				return false
		return true
	return false


## A double-sided face is drawn from both sides, so an abutting back-to-back
## pair can still reach the depth test together.
static func _is_double_sided(material: Material) -> bool:
	if material == null:
		return false
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		return shader != null and shader.code.contains("cull_disabled")
	return false


# ------------------------------------------------------------- pair finding


func _index_faces() -> void:
	for index in _face_aabb.size():
		var box := _face_aabb[index].grow(OFFSET_TOLERANCE_M)
		_face_grown.append(box)
		_face_backed_area.append(0.0)
		var low := Vector3i(
			floori(box.position.x / GRID_CELL),
			floori(box.position.y / GRID_CELL),
			floori(box.position.z / GRID_CELL)
		)
		var high := Vector3i(
			floori(box.end.x / GRID_CELL),
			floori(box.end.y / GRID_CELL),
			floori(box.end.z / GRID_CELL)
		)
		var span := (high.x - low.x + 1) * (high.y - low.y + 1) * (high.z - low.z + 1)
		if span > GRID_SPAN_BUDGET or span <= 0:
			_oversize.append(index)
			_oversize_set[index] = true
			continue
		for cx in range(low.x, high.x + 1):
			for cy in range(low.y, high.y + 1):
				for cz in range(low.z, high.z + 1):
					var key := Vector3i(cx, cy, cz)
					var bucket := _grid.get(key, PackedInt32Array()) as PackedInt32Array
					bucket.append(index)
					_grid[key] = bucket


func _find_pairs() -> void:
	var count := _face_aabb.size()
	for index in count:
		if _oversize_set.has(index):
			continue
		var box := _face_grown[index]
		var low := Vector3i(
			floori(box.position.x / GRID_CELL),
			floori(box.position.y / GRID_CELL),
			floori(box.position.z / GRID_CELL)
		)
		var high := Vector3i(
			floori(box.end.x / GRID_CELL),
			floori(box.end.y / GRID_CELL),
			floori(box.end.z / GRID_CELL)
		)
		var seen := {}
		var multi_cell := low != high
		# The parallel test is inlined here rather than left to `_test_pair`: it
		# rejects the overwhelming majority of neighbours, and at this candidate
		# volume the saved call overhead is most of the probe's runtime.
		var normal := _face_normal[index]
		for cx in range(low.x, high.x + 1):
			for cy in range(low.y, high.y + 1):
				for cz in range(low.z, high.z + 1):
					for other: int in _grid.get(
						Vector3i(cx, cy, cz), PackedInt32Array()
					) as PackedInt32Array:
						if other <= index:
							continue
						if absf(normal.dot(_face_normal[other])) < PARALLEL_COSINE:
							continue
						if multi_cell:
							if seen.has(other):
								continue
							seen[other] = true
						_test_pair(index, other)
	for index: int in _oversize:
		var normal := _face_normal[index]
		for other in count:
			if other == index:
				continue
			if _oversize_set.has(other) and other < index:
				continue
			if absf(normal.dot(_face_normal[other])) < PARALLEL_COSINE:
				continue
			_test_pair(index, other)


func _test_pair(left: int, right: int) -> void:
	if _face_instance[left] == _face_instance[right]:
		return
	if int(_instances[_face_instance[left]].node_id) \
			== int(_instances[_face_instance[right]].node_id):
		return
	var alignment := _face_normal[left].dot(_face_normal[right])
	if absf(alignment) < PARALLEL_COSINE:
		return
	if not _face_grown[left].intersects(_face_aabb[right]):
		return
	var same_facing := alignment >= 0.0
	var right_offset := _face_d[right] if same_facing else -_face_d[right]
	var separation := absf(_face_d[left] - right_offset)
	if separation > OFFSET_TOLERANCE_M:
		return
	_pairs_tested += 1
	var overlap := _overlap(left, right)
	if float(overlap.area) < MIN_OVERLAP_AREA_M2:
		return
	# Back-to-back contact -- two abutting solids sharing a face, each normal
	# pointing into the other -- is the largest coincidence class in the station
	# and it cannot flicker: whichever side the camera is on, one of the two
	# faces is back-facing and culled away before the depth test. Only a
	# double-sided material makes such a pair fight. It is also the evidence that
	# the *other* face is pressed against a solid, which is what
	# `_resolve_pairs()` uses to drop the props-on-a-shared-deck family.
	if not same_facing and not (_face_double_sided[left] or _face_double_sided[right]):
		_back_to_back_skips += 1
		_face_backed_area[left] += float(overlap.area)
		_face_backed_area[right] += float(overlap.area)
		return
	_same_facing.append({
		"left": left, "right": right, "alignment": alignment,
		"separation": separation, "overlap": float(overlap.area),
		"center": overlap.center,
	})


## Second pass, once every back-to-back contact in the scene is known.
func _resolve_pairs() -> void:
	for candidate_variant in _same_facing:
		var candidate := candidate_variant as Dictionary
		_record_pair(candidate)


func _record_pair(candidate: Dictionary) -> void:
	var left := int(candidate.left)
	var right := int(candidate.right)
	var overlap := float(candidate.overlap)
	var alignment := float(candidate.alignment)
	var separation := float(candidate.separation)
	var left_instance := _instances[_face_instance[left]]
	var right_instance := _instances[_face_instance[right]]
	var buried := bool(right_instance.box_like) and _face_inside(left, right_instance.aabb)
	if not buried:
		buried = bool(left_instance.box_like) and _face_inside(right, left_instance.aabb)
	if buried:
		_interior_skips += 1
		return
	# Two props standing on one deck share a downward face on the deck's own top
	# plane. Neither is visible -- each is pressed flat against the deck that
	# backs it -- so a same-facing pair whose two faces are both already in
	# back-to-back contact over at least this much area is contact, not flicker.
	if _face_backed_area[left] >= overlap * OCCLUSION_COVERAGE \
			and _face_backed_area[right] >= overlap * OCCLUSION_COVERAGE:
		_occluded_skips += 1
		return

	var same_material := _face_material[left] == _face_material[right]
	var declaration := ""
	if str(left_instance.declared) != "":
		declaration = str(left_instance.declared)
	elif str(right_instance.declared) != "":
		declaration = str(right_instance.declared)
	var centroid := candidate.center as Vector3
	var distance := _gameplay_distance(centroid)
	var row := {
		"overlap_area_m2": snappedf(overlap, 0.0001),
		"separation_mm": snappedf(separation * 1000.0, 0.01),
		"angle_deg": snappedf(rad_to_deg(acos(clampf(absf(alignment), -1.0, 1.0))), 0.001),
		"normal": _vector_row(-_face_normal[left]),
		"overlap_center": _vector_row(centroid),
		"gameplay_distance_m": snappedf(distance, 0.01),
		"screen_score": snappedf(overlap / pow(maxf(distance, 1.0), 2.0), 0.000001),
		"same_material": same_material,
		"approximate": _face_hulled[left] or _face_hulled[right],
		"a": _renderer_row(left_instance, left),
		"b": _renderer_row(right_instance, right),
		"module": str(left_instance.module),
		"owner": str(left_instance.owner),
		"peer_owner": str(right_instance.owner),
	}
	if declaration != "" and same_material:
		row["declaration"] = declaration
		_declared.append(row)
		return
	if declaration != "":
		row["declaration_rejected"] = declaration
	_findings.append(row)


## Returns the overlap area and, with it, the world point at the middle of that
## overlap. The area alone cannot be aimed a camera at: the two faces are often
## far bigger than the patch they share, and their own centres can be metres from
## the seam.
func _overlap(left: int, right: int) -> Dictionary:
	var normal := _face_normal[left]
	var axes := _plane_axes(normal)
	var origin := ((_face_tris[left] as Array)[0] as PackedVector3Array)[0]
	var left_polygons := _project(_face_tris[left] as Array, origin, axes)
	var right_polygons := _project(_face_tris[right] as Array, origin, axes)
	var total := 0.0
	var weighted := Vector2.ZERO
	for left_polygon: PackedVector2Array in left_polygons:
		for right_polygon: PackedVector2Array in right_polygons:
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(
				left_polygon, right_polygon
			):
				var area := _polygon_area(piece)
				if area <= 0.0:
					continue
				total += area
				weighted += _polygon_centroid(piece) * area
	if total <= 0.0:
		return {"area": 0.0, "center": origin}
	var center := weighted / total
	return {
		"area": total,
		"center": origin + axes[0] * center.x + axes[1] * center.y,
	}


static func _polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in polygon:
		total += point
	return total / maxf(float(polygon.size()), 1.0)


static func _project(tris: Array, origin: Vector3, axes: Array[Vector3]) -> Array:
	var polygons: Array = []
	for tri_variant in tris:
		var polygon := PackedVector2Array()
		for point: Vector3 in tri_variant as PackedVector3Array:
			var delta := point - origin
			polygon.append(Vector2(delta.dot(axes[0]), delta.dot(axes[1])))
		polygons.append(polygon)
	return polygons


static func _polygon_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var total := 0.0
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


## Cheap "is this face buried" proxy: every vertex inside the other renderer's
## world AABB, shrunk so a face lying *on* that box's own boundary plane -- which
## is exactly the flush-plate case this probe exists to catch -- still counts as
## outside.
func _face_inside(face: int, box: AABB) -> bool:
	var shrunk := box.grow(-INTERIOR_MARGIN_M)
	if shrunk.size.x <= 0.0 or shrunk.size.y <= 0.0 or shrunk.size.z <= 0.0:
		return false
	for tri_variant in _face_tris[face] as Array:
		for point: Vector3 in tri_variant as PackedVector3Array:
			if not shrunk.has_point(point):
				return false
	return true


func _gameplay_distance(point: Vector3) -> float:
	var best := INF
	for viewpoint in _viewpoints:
		var distance := viewpoint.distance_to(point)
		if distance < best:
			best = distance
	return 0.0 if is_inf(best) else best


# --------------------------------------------------------------- reporting


func _renderer_row(instance: Dictionary, face: int) -> Dictionary:
	return {
		"path": str(instance.path),
		"copy": int(instance.copy),
		"owner": str(instance.owner),
		"face_area_m2": snappedf(_face_area[face], 0.0001),
	}


static func _vector_row(value: Vector3) -> Array:
	return [snappedf(value.x, 0.0001), snappedf(value.y, 0.0001), snappedf(value.z, 0.0001)]


## The nearest ancestor carrying a script names the file that has to be edited,
## which is the only attribution a triage list can act on.
static func _owner_script(node: Node) -> String:
	var walker: Node = node
	while walker != null:
		var script := walker.get_script() as Script
		if script != null and script.resource_path != "":
			return script.resource_path
		walker = walker.get_parent()
	return "(no script owner)"


static func _module_for(path: String) -> String:
	if path == "":
		return "(scene root)"
	var parts := path.split("/")
	if parts.size() >= 2 and parts[0] == "ShipyardWorld":
		return "%s/%s" % [parts[0], parts[1]]
	return parts[0]


static func _design_declaration(node: Node) -> String:
	var walker: Node = node
	while walker != null:
		if walker.has_meta(DESIGN_META):
			var value: Variant = walker.get_meta(DESIGN_META)
			if value is String or value is StringName:
				return str(value)
			if bool(value):
				return "declared"
			return ""
		walker = walker.get_parent()
	return ""


func _build_report(game: Node3D, elapsed_ms: int) -> Dictionary:
	_findings.sort_custom(
		func(a, b): return float(a.screen_score) > float(b.screen_score)
	)
	var by_module := {}
	for finding: Dictionary in _findings:
		var module := str(finding.module)
		var row := by_module.get(module, {"pairs": 0, "area_m2": 0.0, "owners": {}}) as Dictionary
		row.pairs = int(row.pairs) + 1
		row.area_m2 = float(row.area_m2) + float(finding.overlap_area_m2)
		(row.owners as Dictionary)[str(finding.owner)] = true
		by_module[module] = row
	var module_rows: Array[Dictionary] = []
	for module: String in by_module:
		var row := by_module[module] as Dictionary
		var owners := PackedStringArray()
		for owner: String in row.owners as Dictionary:
			owners.append(owner)
		owners.sort()
		module_rows.append({
			"module": module,
			"pairs": int(row.pairs),
			"overlap_area_m2": snappedf(float(row.area_m2), 0.0001),
			"owners": owners,
		})
	module_rows.sort_custom(func(a, b): return int(a.pairs) > int(b.pairs))
	return {
		"schema_version": SCHEMA_VERSION,
		"profile": String(PROFILE_ID),
		"scene": game.scene_file_path,
		"tolerances": {
			"parallel_deg": PARALLEL_TOLERANCE_DEG,
			"offset_m": OFFSET_TOLERANCE_M,
			"min_overlap_area_m2": MIN_OVERLAP_AREA_M2,
			"interior_margin_m": INTERIOR_MARGIN_M,
		},
		"renderer_placements": _instances.size(),
		"planar_faces": _face_aabb.size(),
		"unique_meshes_planed": _mesh_cache.size(),
		"coplanar_pairs_examined": _pairs_tested,
		"interior_pairs_excluded": _interior_skips,
		"occluded_pairs_excluded": _occluded_skips,
		"back_to_back_pairs_excluded": _back_to_back_skips,
		"declared_pairs": _declared,
		"findings": _findings.slice(0, MAX_FINDINGS),
		"finding_count": _findings.size(),
		"module_totals": module_rows,
		"viewpoints": _viewpoints.size(),
		"shadow_only_renderers_skipped": _shadow_only_skips,
		"skipped_batches": _skipped_batches,
		"skipped_surfaces": _skipped_surfaces,
		"notes": _notes,
		"elapsed_ms": elapsed_ms,
		"phase_ms": _phase_ms,
		"families": _families(),
	}


## Triage acts on families, not pairs: one authored mistake in a batch builder
## shows up once per copy, and the pair list alone buries the twenty real defects
## under two thousand repeats of six of them.
func _families() -> Array[Dictionary]:
	var rows := {}
	for finding: Dictionary in _findings:
		var left := str((finding.a as Dictionary).path)
		var right := str((finding.b as Dictionary).path)
		var key := "%s\n%s" % [left, right] if left <= right else "%s\n%s" % [right, left]
		if not rows.has(key):
			rows[key] = {
				"a": left, "b": right, "pairs": 0, "overlap_area_m2": 0.0,
				"worst_screen_score": 0.0, "min_distance_m": INF,
				"owner": str(finding.owner), "peer_owner": str(finding.peer_owner),
				"module": str(finding.module), "example_center": finding.overlap_center,
			}
		var row := rows[key] as Dictionary
		row.pairs = int(row.pairs) + 1
		row.overlap_area_m2 = float(row.overlap_area_m2) + float(finding.overlap_area_m2)
		if float(finding.screen_score) > float(row.worst_screen_score):
			row.worst_screen_score = finding.screen_score
			row.example_center = finding.overlap_center
		row.min_distance_m = minf(float(row.min_distance_m), float(finding.gameplay_distance_m))
	var out: Array[Dictionary] = []
	for key: String in rows:
		var row := rows[key] as Dictionary
		row.overlap_area_m2 = snappedf(float(row.overlap_area_m2), 0.0001)
		out.append(row)
	out.sort_custom(
		func(a, b): return float(a.worst_screen_score) > float(b.worst_screen_score)
	)
	return out


func summary_lines(report: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("COPLANAR_SEAM_AUDIT schema=%d placements=%d faces=%d meshes=%d %d ms" % [
		int(report.schema_version), int(report.renderer_placements),
		int(report.planar_faces), int(report.unique_meshes_planed), int(report.elapsed_ms),
	])
	lines.append(
		"  coplanar pairs: %d reported, %d back-to-back, %d buried, %d declared by design" % [
			int(report.finding_count), int(report.back_to_back_pairs_excluded),
			int(report.interior_pairs_excluded) + int(report.occluded_pairs_excluded),
			(report.declared_pairs as Array).size(),
		]
	)
	lines.append("%-46s %6s %12s" % ["module", "pairs", "overlap m2"])
	for module: Dictionary in report.module_totals as Array:
		lines.append("%-46s %6d %12.3f" % [
			module.module, int(module.pairs), float(module.overlap_area_m2),
		])
	lines.append("  worst families by on-screen area at gameplay distance:")
	var shown := 0
	for family: Dictionary in report.families as Array:
		if shown >= 24:
			break
		shown += 1
		lines.append("   %2d. score=%.5f x%d overlap=%.3f m2 d=%.1f m %s" % [
			shown, float(family.worst_screen_score), int(family.pairs),
			float(family.overlap_area_m2), float(family.min_distance_m),
			str(family.owner).get_file(),
		])
		lines.append("       A %s" % str(family.a))
		lines.append("       B %s  [%s]" % [str(family.b), str(family.peer_owner).get_file()])
	for note: String in report.notes as PackedStringArray:
		lines.append("  note: %s" % note)
	return lines


static func _placement_label(row: Dictionary) -> String:
	var label := str(row.path)
	if int(row.copy) >= 0:
		label += "#%d" % int(row.copy)
	return "%s (%.3f m2, %s)" % [label, float(row.face_area_m2), str(row.owner).get_file()]
