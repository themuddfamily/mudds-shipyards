class_name StationSurfaceKit
extends RefCounted

## Shared station surface treatment: the one chamfered-box builder and the one
## registered panel-material recipe the whole station uses.
##
## Two properties separate a manufactured station part from a shaded primitive:
## a chamfer that catches a highlight along every edge, and a metric surface
## grain that stays the same physical size however the part is scaled. This kit
## owns both. It began as the treatment for components mounted onto the station
## modules — the pressure door and the structural service dressing — and the
## modules and the hub each carried a private copy of the same builder; those
## copies are now gone and everything calls in here instead. What stayed
## per-caller is the small part that was genuinely different: the bevel *rule*
## (see `proportional_bevel_for_size`) and the face UV convention (`BevelUV`).
##
## The kit is deliberately stateless. Callers own their mesh cache so the meshes
## are freed with the node that built them and never outlive the scene tree.

const PANEL_ALBEDO_PATH := "res://assets/materials/procedural-panel-triplanar-albedo-v2.png"
const PANEL_NORMAL_PATH := "res://assets/materials/procedural-panel-triplanar-normal-v2.png"
const PANEL_ROUGHNESS_PATH := "res://assets/materials/procedural-panel-triplanar-roughness-v2.png"
const PANEL_NORMAL_SCALE := 1.0
const PANEL_TRIPLANAR_SHARPNESS := 4.0

## Bevel rule.
##
## `BEVEL_PROPORTION` keeps the chamfer in scale with the part, so a 4.2 m header
## and a 0.11 m frame member are not given the same edge. `MINIMUM_BEVEL` is the
## floor the proportional-only rule was missing: at 0.22 of the shortest side a
## 0.035 m indicator strip earned a 0.008 m chamfer, which is below one pixel at
## the arm's-length range these parts are actually viewed from, so the edge stayed
## a hard 90° line. `MAXIMUM_BEVEL` stops a large slab softening into a pill.
## `BEVEL_SAFETY_LIMIT` keeps the chamfer strictly inside the part so the inset
## shell can never invert on a thin section, and it always wins over the floor.
const BEVEL_PROPORTION := 0.22
const MINIMUM_BEVEL := 0.012
const MAXIMUM_BEVEL := 0.18
const BEVEL_SAFETY_LIMIT := 0.45

## Floor of the older proportional-only rule the four station modules and the
## hub still use. It exists only to keep a sub-centimetre sliver from collapsing
## to a zero-width chamfer; it is not the perceptual floor `MINIMUM_BEVEL` is.
const MODULE_MINIMUM_BEVEL := 0.003

## Face UV convention for the chamfered box.
##
## Both conventions describe the same nine sub-quads per face and produce the
## same positions and normals; they differ only in the UV channel, and therefore
## in the tangent frame `generate_tangents()` derives from it. They are kept
## apart rather than unified because the frozen module geometry differs by that
## channel: unifying would rewrite every affected surface's tangent array for no
## visible gain while the panel family stays `uv1_world_triplanar`.
##
## `UNIT_PER_QUAD` gives every sub-quad the full 0..1 square. `FACE_GRID` tiles
## the nine sub-quads across one 0..1 face atlas, which is what a non-triplanar
## UV1 material on a hub primitive expects.
enum BevelUV {
	UNIT_PER_QUAD,
	FACE_GRID,
}


## Physical chamfer width for a box of this size, in metres.
static func bevel_for_size(size: Vector3) -> float:
	var shortest := minf(absf(size.x), minf(absf(size.y), absf(size.z)))
	if shortest <= 0.0:
		return 0.0
	var proportional := maxf(shortest * BEVEL_PROPORTION, MINIMUM_BEVEL)
	return minf(proportional, minf(MAXIMUM_BEVEL, shortest * BEVEL_SAFETY_LIMIT))


## The proportional-only chamfer rule the station modules and the hub froze
## before this kit existed: `clamp(shortest_side * 0.22, minimum, maximum)`.
##
## Each caller keeps its own `maximum_bevel` because the caps are not
## interchangeable — 0.18 m in the Aft and Habitat modules, 0.20 m in the hub,
## the Fleet Dock comb and the operations activity, 0.22 m in the Freight berth.
## They are published here so the rule itself is written once even though its
## constants stay per-module. Deliberately *not* folded into `bevel_for_size`:
## that rule's 0.012 m floor and `shortest * 0.45` safety limit would move 108 of
## the 277 live chamfered box sizes, by up to 0.04 m, including the 0.03 m route
## stripes the proportional rule exists to keep flat.
static func proportional_bevel_for_size(
		size: Vector3,
		maximum_bevel: float,
		minimum_bevel: float = MODULE_MINIMUM_BEVEL
	) -> float:
	var shortest := minf(size.x, minf(size.y, size.z))
	return clampf(shortest * BEVEL_PROPORTION, minimum_bevel, maximum_bevel)


## Caller-owned cache keyed on the exact size, so repeated members in one
## component share a single mesh without leaking across components.
static func rounded_box_mesh_cached(size: Vector3, cache: Dictionary) -> ArrayMesh:
	return rounded_box_mesh_with_bevel_cached(size, bevel_for_size(size), cache)


## As `rounded_box_mesh_cached`, for a caller that owns its own bevel rule.
static func rounded_box_mesh_with_bevel_cached(
		size: Vector3,
		bevel: float,
		cache: Dictionary,
		uv_mode: BevelUV = BevelUV.UNIT_PER_QUAD
	) -> ArrayMesh:
	var cache_key := "%0.4f:%0.4f:%0.4f" % [size.x, size.y, size.z]
	if cache.has(cache_key):
		return cache[cache_key] as ArrayMesh
	var mesh := rounded_box_mesh_with_bevel(size, bevel, uv_mode)
	cache[cache_key] = mesh
	return mesh


## A box whose twelve edges are chamfered and whose outer extents are identical
## to `BoxMesh.size`. Preserving the AABB exactly is what lets a bevel be a pure
## edge treatment: no footprint, collision shape, or published envelope moves.
static func rounded_box_mesh(size: Vector3) -> ArrayMesh:
	return rounded_box_mesh_with_bevel(size, bevel_for_size(size))


## The chamfered-box builder itself, with the chamfer width supplied rather than
## derived. Every station builder shares this body; only the bevel rule and the
## UV convention were ever genuinely different between them.
static func rounded_box_mesh_with_bevel(
		size: Vector3,
		bevel: float,
		uv_mode: BevelUV = BevelUV.UNIT_PER_QUAD
	) -> ArrayMesh:
	var half := size * 0.5
	var inner_half := Vector3(
		maxf(0.0, half.x - bevel),
		maxf(0.0, half.y - bevel),
		maxf(0.0, half.z - bevel)
	)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array[Array] = [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for face: Array in faces:
		var normal_axis: Vector3 = face[0]
		var u_axis: Vector3 = face[1]
		var v_axis: Vector3 = face[2]
		var face_center := Vector3(
			normal_axis.x * half.x,
			normal_axis.y * half.y,
			normal_axis.z * half.z
		)
		var u_extent := absf(u_axis.x) * half.x + absf(u_axis.y) * half.y + absf(u_axis.z) * half.z
		var v_extent := absf(v_axis.x) * half.x + absf(v_axis.y) * half.y + absf(v_axis.z) * half.z
		var u_inner := maxf(0.0, u_extent - bevel)
		var v_inner := maxf(0.0, v_extent - bevel)
		var u_values := PackedFloat32Array([-u_extent, -u_inner, u_inner, u_extent])
		var v_values := PackedFloat32Array([-v_extent, -v_inner, v_inner, v_extent])
		for u_index in u_values.size() - 1:
			for v_index in v_values.size() - 1:
				var points := [
					face_center + u_axis * u_values[u_index] + v_axis * v_values[v_index],
					face_center + u_axis * u_values[u_index + 1] + v_axis * v_values[v_index],
					face_center + u_axis * u_values[u_index + 1] + v_axis * v_values[v_index + 1],
					face_center + u_axis * u_values[u_index] + v_axis * v_values[v_index + 1],
				]
				var u0 := 0.0
				var u1 := 1.0
				var v0 := 0.0
				var v1 := 1.0
				if uv_mode == BevelUV.FACE_GRID:
					u0 = float(u_index) / 3.0
					u1 = float(u_index + 1) / 3.0
					v0 = float(v_index) / 3.0
					v1 = float(v_index + 1) / 3.0
				_add_rounded_vertex(tool, points[0], inner_half, bevel, Vector2(u0, v0))
				_add_rounded_vertex(tool, points[1], inner_half, bevel, Vector2(u1, v0))
				_add_rounded_vertex(tool, points[2], inner_half, bevel, Vector2(u1, v1))
				_add_rounded_vertex(tool, points[0], inner_half, bevel, Vector2(u0, v0))
				_add_rounded_vertex(tool, points[2], inner_half, bevel, Vector2(u1, v1))
				_add_rounded_vertex(tool, points[3], inner_half, bevel, Vector2(u0, v1))
	# Without this the committed surface still carries a tangent array, but every
	# tangent is the SurfaceTool default rather than the face's own U direction,
	# so a normal map is resolved in an arbitrary frame. The station panel family
	# is normal-mapped, so the frame has to be real.
	#
	# Measured caveat, carried over from the module builders this replaced, so
	# nobody re-chases it: while the panel materials stay uv1_world_triplanar,
	# Godot samples the normal map by world position and builds its own basis, so
	# this call changes no pixel today. It is what keeps the mesh correct if
	# triplanar is ever turned off (verified: with triplanar off the same tangent
	# change moves 2.3% of pixels).
	tool.generate_tangents()
	return tool.commit()


## Binds the registered station panel family: world-space triplanar albedo,
## normal and red-channel roughness at one of the frozen physical scales.
## Returns false when the registered maps are unavailable, leaving the caller's
## untextured PBR values untouched rather than binding a partial recipe.
static func apply_panel_triplanar(material: StandardMaterial3D, uv_scale: float) -> bool:
	if material == null:
		return false
	var albedo := load(PANEL_ALBEDO_PATH) as Texture2D
	var normal := load(PANEL_NORMAL_PATH) as Texture2D
	var roughness := load(PANEL_ROUGHNESS_PATH) as Texture2D
	if albedo == null or normal == null or roughness == null:
		return false
	material.albedo_texture = albedo
	material.normal_enabled = true
	material.normal_texture = normal
	material.normal_scale = PANEL_NORMAL_SCALE
	material.roughness_texture = roughness
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_triplanar_sharpness = PANEL_TRIPLANAR_SHARPNESS
	material.uv1_scale = Vector3.ONE * uv_scale
	material.texture_repeat = true
	return true


static func _add_rounded_vertex(
		tool: SurfaceTool,
		point: Vector3,
		inner_half: Vector3,
		bevel: float,
		uv: Vector2
	) -> void:
	var closest := Vector3(
		clampf(point.x, -inner_half.x, inner_half.x),
		clampf(point.y, -inner_half.y, inner_half.y),
		clampf(point.z, -inner_half.z, inner_half.z)
	)
	var offset := point - closest
	var normal := offset.normalized() if offset.length_squared() > 0.000001 else Vector3.UP
	tool.set_normal(normal)
	tool.set_uv(uv)
	tool.add_vertex(closest + normal * bevel)
