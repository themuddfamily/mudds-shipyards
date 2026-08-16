class_name StationSurfaceKit
extends RefCounted

## Shared station surface treatment for components that are not station modules.
##
## Two properties separate a manufactured station part from a shaded primitive:
## a chamfer that catches a highlight along every edge, and a metric surface
## grain that stays the same physical size however the part is scaled. The four
## station modules already carry both; this kit publishes the same rule and the
## same registered material family so components mounted onto those modules —
## the pressure door and the structural service dressing — converge on the one
## look instead of growing a parallel one.
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


## Physical chamfer width for a box of this size, in metres.
static func bevel_for_size(size: Vector3) -> float:
	var shortest := minf(absf(size.x), minf(absf(size.y), absf(size.z)))
	if shortest <= 0.0:
		return 0.0
	var proportional := maxf(shortest * BEVEL_PROPORTION, MINIMUM_BEVEL)
	return minf(proportional, minf(MAXIMUM_BEVEL, shortest * BEVEL_SAFETY_LIMIT))


## Caller-owned cache keyed on the exact size, so repeated members in one
## component share a single mesh without leaking across components.
static func rounded_box_mesh_cached(size: Vector3, cache: Dictionary) -> ArrayMesh:
	var cache_key := "%0.4f:%0.4f:%0.4f" % [size.x, size.y, size.z]
	if cache.has(cache_key):
		return cache[cache_key] as ArrayMesh
	var mesh := rounded_box_mesh(size)
	cache[cache_key] = mesh
	return mesh


## A box whose twelve edges are chamfered and whose outer extents are identical
## to `BoxMesh.size`. Preserving the AABB exactly is what lets a bevel be a pure
## edge treatment: no footprint, collision shape, or published envelope moves.
static func rounded_box_mesh(size: Vector3) -> ArrayMesh:
	var half := size * 0.5
	var bevel := bevel_for_size(size)
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
				_add_rounded_vertex(tool, points[0], inner_half, bevel, Vector2(0, 0))
				_add_rounded_vertex(tool, points[1], inner_half, bevel, Vector2(1, 0))
				_add_rounded_vertex(tool, points[2], inner_half, bevel, Vector2(1, 1))
				_add_rounded_vertex(tool, points[0], inner_half, bevel, Vector2(0, 0))
				_add_rounded_vertex(tool, points[2], inner_half, bevel, Vector2(1, 1))
				_add_rounded_vertex(tool, points[3], inner_half, bevel, Vector2(0, 1))
	# Without this the committed surface still carries a tangent array, but every
	# tangent is the SurfaceTool default rather than the face's own U direction,
	# so a normal map is resolved in an arbitrary frame. The station panel family
	# is normal-mapped, so the frame has to be real.
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
