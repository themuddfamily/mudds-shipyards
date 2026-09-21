class_name ShipChamferedStock
extends RefCounted

## Chamfered box stock for the fleet's fitted detail, at the edge resolution the
## part's own chamfer width can actually carry.
##
## ## What the fleet was building, and what it costs
##
## `StationSurfaceKit.rounded_box_mesh_with_bevel` (and the copy of it in
## `HeroShip._rounded_box_mesh`) subdivides every face into a three-by-three grid.
## The centre cell is the flat face; the four side cells and four corner cells are
## the edge treatment. That makes each of the twelve edges a **two-segment
## quarter-round** — face plane, a vertex at 45 degrees, face plane — and each of
## the eight corners a six-triangle spherical octant. 108 triangles per box,
## whatever the box is.
##
## It is not a wasteful recipe for a station handrail or a 4.2 m pressure header.
## It is a very expensive one for the fleet's fitted stock, which is roughly 1,300
## pieces of seam, slat, fin, liner, hinge and lockbar across the Jovian and the
## Halyard, most of them a few centimetres in their smallest dimension. Those
## pieces spend 96 of their 108 triangles on rounding an edge whose entire chamfer
## is 12 mm wide — `StationSurfaceKit.MINIMUM_BEVEL`, the floor the bevel rule
## clamps almost all of this stock to.
##
## ## The reduction
##
## The two-segment quarter-round is replaced by **one segment placed on the
## tangent**, which is the ordinary manufactured chamfer the bevel rule is named
## for. The distinction between a *tangent* (circumscribed) chamfer and the naive
## secant one is the whole reason this is a safe change, so it is worth stating
## exactly.
##
## Work in the cross-section of one edge, with the inner corner at the origin and
## the authored surface the quarter circle of radius `b`:
##
## - The **secant** chamfer — simply joining the two face-plane vertices at
##   `(b, 0)` and `(0, b)` — cuts the corner off. It passes `b * (1 - cos 45) =
##   0.293 b` *inside* the authored surface at the 45 degree point. On a 12 mm
##   chamfer that is 3.5 mm, which is 1.4 px at 1.5 m. That is a real silhouette
##   move and this builder does not do it.
## - The **tangent** chamfer is the line that touches the same circle at 45
##   degrees: `x + y = b * sqrt(2)`. It meets the two face planes at `(b, 0.4142 b)`
##   and `(0.4142 b, b)`, so it begins `CHAMFER_INSET_FRACTION * b = 0.5858 b` in
##   from each face extent. It touches the authored surface exactly at 45 degrees
##   and lies *outside* it everywhere else, by at most `0.0824 b` along that one
##   cross-section. On a 12 mm chamfer that is 0.99 mm.
##
## The corners are the same construction in three axes at once: the facet is the
## tangent plane on the authored spherical octant, and the three vertices it
## shares with the edge quads sit at `(b, 0.4142 b, 0.4142 b)` from the inner
## corner. Those eight vertices are the furthest the new surface ever stands from
## the old one: `MAX_OUTWARD_FRACTION * b = sqrt(1 + 2 * (sqrt(2) - 1)^2) - 1 =
## 0.1589 b`, which is 1.9 mm on a 12 mm chamfer — 0.75 px at 1.5 m, 0.14 px at
## 8 m.
##
## So the surface moves by at most `0.1589 * bevel`, outward, and:
##
## - **the AABB is exact.** Every face plane is untouched and each chamfer
##   endpoint lies on one, so `max` and `min` on all three axes are identical to
##   the authored mesh. Nothing that reads a published envelope, footprint or
##   collision shape can see this, and no collider reads these meshes anyway.
## - **the shading is very nearly the same field.** The authored mesh carries the
##   pure face normal on its face-plane vertices and the 45 degree bisector on its
##   middle vertex; the chamfer quad carries the same two face normals at its two
##   edges and interpolates between them across one quad, which reaches that same
##   bisector at its midpoint. The band is now flat rather than a two-facet roll,
##   so the specular gradient across it is smooth instead of kinked; it is not
##   bit-identical, and see the rendered finding below.
## - **no silhouette is cut.** The one direction the surface moves is outward.
##
## ## Where it is allowed
##
## `rolled_edge_is_resolvable` gates it on the part's own chamfer width against
## `ShipGeometryBudget.WALKING_ALLOWANCE_METRES` — 3.15 mm, the project's
## calibrated angular tolerance at the 1.5 m walking range Phase 10 item 2 names.
## A chamfer wider than 38 mm, where `0.0824 * bevel` exceeds that, keeps the
## authored two-segment roll. Both bevel rules in the fleet cap out well before
## that on ordinary fitted stock — `StationSurfaceKit`'s clamps anything under
## 55 mm in its shortest dimension to a 12 mm chamfer — so what stays rolled is
## the genuinely chunky structure, where the chamfer is a visible radius rather
## than an edge highlight.
##
## ## What the renders found, stated plainly
##
## Ten fixed gameplay viewpoints across the three craft, before and after, at
## 1280x720 through `gl_compatibility` on a D3D12 GPU. At 1:1 the pairs are
## indistinguishable on every view. Magnified 8x on the *nearest* fitted stock a
## player can stand beside — a cargo restraint corner about 40 screen pixels
## across in the Jovian's bay — the two-segment rolled edge does read as a single
## chamfer facet with two creases where it used to read as a roll. That is about
## two pixels wide, it does not show at 1:1, and it is the one honest difference
## this recipe makes. It is therefore a bounded presentation trade rather than a
## free reduction, and `rolled_edge_is_resolvable` is the single place to revert
## it (at a cost of roughly 12,400 triangles across the Jovian, the Halyard and
## the three Cinder craft) if the edge treatment is ever judged too close.
##
## Everything here is modern interpretation: presentation-budget geometry chosen
## by measuring this project, not a recovered value.

## Distance in from each face extent at which the tangent chamfer starts,
## as a fraction of the chamfer width: `2 - sqrt(2)`.
const CHAMFER_INSET_FRACTION := 0.5857864376269049

## How far the tangent chamfer stands outside the authored rolled edge along the
## continuous edge band, as a fraction of the chamfer width: the perpendicular
## departure of the tangent chord from the quarter circle at its two ends,
## `sqrt(1 + (sqrt(2) - 1)^2) - 1`. This is the feature that runs the length of
## every edge, so it is what the gate is solved against — the same choice
## `TorusGeometryBudget` makes when it budgets a ring by the sagitta of its two
## circles rather than by the worst vertex anywhere on the mesh.
const EDGE_OUTWARD_FRACTION := 0.08239220029239402

## Largest distance the new surface stands outside the authored one anywhere.
## Reached at the eight corner vertices, where all three axes contribute:
## `sqrt(1 + 2 * (sqrt(2) - 1)^2) - 1`. At the gate's limit that is 6.1 mm on
## eight isolated points of a part at least 16 cm thick — 2.4 px at 1.5 m — and
## at the 12 mm chamfer most of this stock carries it is 1.9 mm, 0.75 px.
const MAX_OUTWARD_FRACTION := 0.15894234394110385

## Face table, copied from `StationSurfaceKit` so the two builders parameterise
## the same six faces with the same in-plane axes and a UV convention that lines
## up piece for piece.
const FACES: Array[Array] = [
	[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
]

enum StockUV {
	## Every emitted polygon spans the full 0..1 square, as
	## `StationSurfaceKit.BevelUV.UNIT_PER_QUAD` gives every one of its sub-quads.
	UNIT_PER_QUAD,
	## Position-linear across the owning face, which is what the authored
	## `FACE_GRID` three-column mapping approximates to within the chamfer width.
	FACE_GRID,
}


## Smallest UV-space area a `FACE_GRID` triangle may have before it is treated
## as collapsed.
##
## The chamfer band and the corner facets are the polygons on this box that
## belong to more than one face at once, so under a per-face atlas their
## vertices carry coordinates from two or three different charts. Usually those
## charts disagree enough to leave a real triangle. They do not on stock that is
## square in two axes: both charts normalise by the same extent, every vertex of
## the seam lands on the same atlas column, the UV triangle collapses to zero
## area and `generate_tangents` hands the shader a singular tangent frame there.
## The Zenith's port instrument stanchion, 45 x 200 x 45 mm, is the first part in
## the fleet to hit it.
##
## Deliberately a hair above zero rather than a tolerance: what this guards is
## exact degeneracy from equal extents, not a gradual loss of UV area.
const DEGENERATE_FACET_UV_AREA := 0.00000001


## `HeroShip`'s frozen radial segmentation for turned stock, retained as the
## ceiling `turned_stock_mesh` reduces from.
const HERO_CYLINDER_SEGMENTS := 32


## Chamfered cylinder or frustum at the radial segmentation its own radius earns.
##
## A drop-in for what `HeroShip._cylinder` and `HeroShip._frustum` build, with
## `ShipGeometryBudget.tube_segments` choosing the count instead of the frozen 32.
## Radii, height, wall rings, caps, rim chamfer, cache and material are all
## unchanged, so the AABB is exact and the silhouette moves only by the tube
## rule's own `radius * (1 - cos(PI / N))`, which is inside this project's
## calibrated tolerance at 0.6 m by construction.
static func turned_stock_mesh(
		top_radius: float,
		bottom_radius: float,
		height: float,
		cache: Dictionary,
		cap_top: bool,
		cap_bottom: bool,
		material: Material
	) -> ArrayMesh:
	var segments := ShipGeometryBudget.tube_segments(
		maxf(absf(top_radius), absf(bottom_radius)), HERO_CYLINDER_SEGMENTS
	)
	return StationSurfaceKit.chamfered_cylinder_mesh_cached(
		top_radius, bottom_radius, height, segments, cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, cap_top, cap_bottom, material
	)


## `HeroShip._rounded_box_mesh`'s own chamfer rule, mirrored so the five craft
## that override that method can ask for the same width the base builder would
## have used. Deliberately *not* `StationSurfaceKit.bevel_for_size`: the two
## rules differ (0.24 against 0.22, a 0.16 cap against 0.18, a 0.004 floor
## against 0.012) and this one governs every box built through `_box`.
static func fleet_box_bevel(size: Vector3) -> float:
	return maxf(minf(0.16, minf(size.x, minf(size.y, size.z)) * 0.24), 0.004)


## True when the authored two-segment rolled edge must be kept: its departure
## from a single tangent chamfer would be resolvable at walking range.
static func rolled_edge_is_resolvable(bevel: float) -> bool:
	return EDGE_OUTWARD_FRACTION * bevel > ShipGeometryBudget.WALKING_ALLOWANCE_METRES


## Widest chamfer the single tangent facet carries before the authored rolled
## edge has to come back, in metres.
##
## This is `rolled_edge_is_resolvable` solved for the bevel rather than tested
## against it: the width at which `EDGE_OUTWARD_FRACTION * bevel` reaches
## `ShipGeometryBudget.WALKING_ALLOWANCE_METRES`, which is 38.2 mm. It is
## published because a *builder* asks the other direction of the same question —
## not "may I chamfer this width" but "what is the widest chamfer I can cut and
## still get the 44-triangle recipe" — and answering that by hand at each call
## site is how two builders end up with two numbers.
static func largest_resolvable_chamfer() -> float:
	return ShipGeometryBudget.WALKING_ALLOWANCE_METRES / EDGE_OUTWARD_FRACTION


## Chamfer width for authored **station structure** — deck plate, walkway,
## chord, frame, gantry, mast — cut on the cheap tangent facet.
##
## `StationSurfaceKit.bevel_for_size` answers for a *fitting*, where the chamfer
## scales with the part because the part is small and its edge is the whole
## read. It does not answer for structure, and the failure is in both
## directions at once. At 0.22 of the shortest side a 0.6 m walkway deck earns a
## 0.132 m chamfer: that is not an edge on a deck plate, it is a 13 cm nosing
## that eats a fifth of the plate's thickness and visibly changes its section.
## It is also well over `largest_resolvable_chamfer()`, so the 108-triangle
## rolled recipe comes back and the piece costs 96 extra triangles instead of 32
## — the most expensive answer for the least wanted shape.
##
## Both problems have one answer, and it is the one a fabricator would give: a
## chamfer is a **tool width**, not a proportion of the stock. A 24 m blast
## datum and a 1.2 m frame leg come off the same edge tool and carry the same
## chamfer. So structure is held at `largest_resolvable_chamfer()` — this
## project's own calibrated 38.2 mm, already the width at which one facet and a
## two-segment roll are indistinguishable at walking range — and only stock too
## thin to carry that keeps the proportional rule, which is exactly the case
## where the proportion is the physical answer again.
static func structural_chamfer_for_size(size: Vector3) -> float:
	return minf(StationSurfaceKit.bevel_for_size(size), largest_resolvable_chamfer())


## Station structural stock at the tangent chamfer: one surface, the exact
## authored AABB, 44 triangles whatever the size.
##
## Deliberately calls `chamfered_box_mesh` rather than `box_mesh`: the width has
## already been chosen *by* the gate, so re-testing it would only let a
## floating-point hair at the boundary silently return the 108-triangle form.
##
## `material` is bound to the single surface when given, so a caller replacing a
## `BoxMesh` that carried `mesh.material` keeps the same material on the same
## one surface and no material census moves.
static func structural_box_mesh(size: Vector3, material: Material = null) -> ArrayMesh:
	var mesh := chamfered_box_mesh(size, structural_chamfer_for_size(size), StockUV.FACE_GRID)
	if material != null:
		mesh.surface_set_material(0, material)
	return mesh


## Fitted visual stock, at whichever edge resolution the chamfer width earns.
## Matches `StationSurfaceKit.rounded_box_mesh_with_bevel`'s outer contract:
## same size, same chamfer width, same AABB, one surface, tangents generated.
static func box_mesh(
		size: Vector3,
		bevel: float,
		uv_mode: StockUV = StockUV.UNIT_PER_QUAD
	) -> ArrayMesh:
	if bevel <= 0.0 or rolled_edge_is_resolvable(bevel):
		return StationSurfaceKit.rounded_box_mesh_with_bevel(
			size, bevel,
			StationSurfaceKit.BevelUV.FACE_GRID if uv_mode == StockUV.FACE_GRID
				else StationSurfaceKit.BevelUV.UNIT_PER_QUAD
		)
	return chamfered_box_mesh(size, bevel, uv_mode)


## Caller-owned cache keyed on the exact size, mirroring
## `StationSurfaceKit.rounded_box_mesh_with_bevel_cached` including its key, so a
## builder that swaps one for the other keeps sharing exactly the meshes it did.
static func box_mesh_cached(
		size: Vector3,
		bevel: float,
		cache: Dictionary,
		uv_mode: StockUV = StockUV.UNIT_PER_QUAD
	) -> ArrayMesh:
	var cache_key := "%0.4f:%0.4f:%0.4f" % [size.x, size.y, size.z]
	if cache.has(cache_key):
		return cache[cache_key] as ArrayMesh
	var mesh := box_mesh(size, bevel, uv_mode)
	cache[cache_key] = mesh
	return mesh


## Drop-in for `StationSurfaceKit.rounded_box_mesh_cached`: same arguments, same
## cache key, same chamfer rule, and the same mesh back whenever the chamfer is
## wide enough to keep its authored rolled edge.
static func fleet_box_mesh_cached(size: Vector3, cache: Dictionary) -> ArrayMesh:
	return box_mesh_cached(size, StationSurfaceKit.bevel_for_size(size), cache)


## The 44-triangle tangent-chamfered box itself: six inset face rectangles,
## twelve edge quads and eight corner facets.
static func chamfered_box_mesh(
		size: Vector3,
		bevel: float,
		uv_mode: StockUV = StockUV.UNIT_PER_QUAD
	) -> ArrayMesh:
	var half := size.abs() * 0.5
	var inset := minf(
		bevel * CHAMFER_INSET_FRACTION,
		minf(half.x, minf(half.y, half.z)) * 0.999
	)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for face: Array in FACES:
		var normal_axis: Vector3 = face[0]
		var u_axis: Vector3 = face[1]
		var v_axis: Vector3 = face[2]
		var centre := normal_axis * half
		var u_reach := _extent(u_axis, half) - inset
		var v_reach := _extent(v_axis, half) - inset
		var corners: Array[Vector3] = [
			centre - u_axis * u_reach - v_axis * v_reach,
			centre + u_axis * u_reach - v_axis * v_reach,
			centre + u_axis * u_reach + v_axis * v_reach,
			centre - u_axis * u_reach + v_axis * v_reach,
		]
		var normals: Array[Vector3] = [normal_axis, normal_axis, normal_axis, normal_axis]
		_emit_quad(tool, corners, normals, half, uv_mode)

	# One quad per edge, spanning the two faces whose extents meet there.
	for first in 3:
		for second in range(first + 1, 3):
			var third := 3 - first - second
			for first_sign: float in [-1.0, 1.0]:
				for second_sign: float in [-1.0, 1.0]:
					var first_normal := _axis(first) * first_sign
					var second_normal := _axis(second) * second_sign
					var third_reach := _component(half, third) - inset
					var near := _axis(third) * -third_reach
					var far := _axis(third) * third_reach
					var on_first := (
						first_normal * _component(half, first)
						+ second_normal * (_component(half, second) - inset)
					)
					var on_second := (
						first_normal * (_component(half, first) - inset)
						+ second_normal * _component(half, second)
					)
					_emit_quad(
						tool,
						[on_first + near, on_first + far, on_second + far, on_second + near],
						[first_normal, first_normal, second_normal, second_normal],
						half, uv_mode
					)

	# One facet per corner: the tangent plane on the authored spherical octant.
	for x_sign: float in [-1.0, 1.0]:
		for y_sign: float in [-1.0, 1.0]:
			for z_sign: float in [-1.0, 1.0]:
				var signs := Vector3(x_sign, y_sign, z_sign)
				var inner := Vector3(
					signs.x * (half.x - inset),
					signs.y * (half.y - inset),
					signs.z * (half.z - inset)
				)
				var facet: Array[Vector3] = [
					Vector3(signs.x * half.x, inner.y, inner.z),
					Vector3(inner.x, signs.y * half.y, inner.z),
					Vector3(inner.x, inner.y, signs.z * half.z),
				]
				var facet_normals: Array[Vector3] = [
					Vector3(signs.x, 0.0, 0.0),
					Vector3(0.0, signs.y, 0.0),
					Vector3(0.0, 0.0, signs.z),
				]
				var facet_uvs: Array[Vector2] = [
					Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0)
				]
				if uv_mode == StockUV.FACE_GRID:
					facet_uvs = []
					for index in 3:
						facet_uvs.append(_face_uv(facet_normals[index], facet[index], half))
				_emit_triangle(tool, facet, facet_normals, facet_uvs)

	tool.generate_tangents()
	return tool.commit()


static func _axis(index: int) -> Vector3:
	if index == 0:
		return Vector3.RIGHT
	return Vector3.UP if index == 1 else Vector3.BACK


static func _component(value: Vector3, index: int) -> float:
	return value.x if index == 0 else (value.y if index == 1 else value.z)


static func _extent(axis: Vector3, half: Vector3) -> float:
	return absf(axis.x) * half.x + absf(axis.y) * half.y + absf(axis.z) * half.z


## Position-linear UV across the face the vertex's normal belongs to, using the
## same in-plane axes `FACES` gives that face.
static func _face_uv(normal: Vector3, point: Vector3, half: Vector3) -> Vector2:
	for face: Array in FACES:
		if (face[0] as Vector3).dot(normal) > 0.5:
			var u_axis: Vector3 = face[1]
			var v_axis: Vector3 = face[2]
			var u_extent := _extent(u_axis, half)
			var v_extent := _extent(v_axis, half)
			return Vector2(
				0.5 if u_extent <= 0.0 else (point.dot(u_axis) + u_extent) / (2.0 * u_extent),
				0.5 if v_extent <= 0.0 else (point.dot(v_axis) + v_extent) / (2.0 * v_extent)
			)
	return Vector2(0.5, 0.5)


static func _emit_quad(
		tool: SurfaceTool,
		points: Array[Vector3],
		normals: Array[Vector3],
		half: Vector3,
		uv_mode: StockUV
	) -> void:
	var uvs: Array[Vector2] = []
	if uv_mode == StockUV.UNIT_PER_QUAD:
		uvs = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	else:
		for index in 4:
			uvs.append(_face_uv(normals[index], points[index], half))
	_emit_triangle(
		tool, [points[0], points[1], points[2]],
		[normals[0], normals[1], normals[2]], [uvs[0], uvs[1], uvs[2]]
	)
	_emit_triangle(
		tool, [points[0], points[2], points[3]],
		[normals[0], normals[2], normals[3]], [uvs[0], uvs[2], uvs[3]]
	)


## Emission order *is* the front-face winding. Godot's front face runs clockwise
## seen from outside, so on a correct surface `(b - a) x (c - a)` points opposite
## the outward shading normal — the same convention `StationSurfaceKit` records
## and the same defect it had to fix. Rather than hand-order twenty-six polygons
## across six face frames, the geometric normal is measured against the outward
## direction here and the two trailing vertices are swapped when it disagrees.
static func _emit_triangle(
		tool: SurfaceTool,
		points: Array[Vector3],
		normals: Array[Vector3],
		uvs: Array[Vector2]
	) -> void:
	var order: Array[int] = [0, 1, 2]
	var geometric := (points[1] - points[0]).cross(points[2] - points[0])
	var outward := (normals[0] + normals[1] + normals[2]) / 3.0
	if geometric.dot(outward) > 0.0:
		order = [0, 2, 1]
	# A seam triangle whose atlas coordinates collapse (see
	# `DEGENERATE_FACET_UV_AREA`) falls back to the unit triangle, which is what
	# `UNIT_PER_QUAD` would have given it and is never degenerate. Only the
	# collapsed triangles move; every polygon whose atlas mapping is a real
	# triangle keeps exactly the coordinates it had.
	var uv_area := absf((uvs[1] - uvs[0]).cross(uvs[2] - uvs[0]))
	if uv_area <= DEGENERATE_FACET_UV_AREA:
		uvs = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0)]
	for index in order:
		tool.set_normal(normals[index])
		tool.set_uv(uvs[index])
		tool.add_vertex(points[index])
