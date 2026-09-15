class_name StationSurfaceKit
extends RefCounted

## Shared station surface treatment: chamfered geometry and a quiet, metric
## manufactured finish. Panel boundaries come from construction geometry rather
## than the same embossed tile stamped onto rails, columns and every deck.
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
## `chamfered_cylinder_mesh` closes the same gap on round stock. Boxes have been
## chamfered here for a while; cylinders and frustums were still raw
## `CylinderMesh`, so 1,237 live parts — engine cans, mast caps, conduit ends,
## column feet, chair pedestals, gantry legs — carried a zero-width 90° edge with
## no pixels to hold a highlight. (Tori were never in scope: a torus is smooth
## everywhere and has no rim. Nor was the Arrow's engine housing, which is a
## `_loft_hull` closing on a centre point, not a capped cylinder.)
## The rim rule is its own (`RIM_CHAMFER_PROPORTION`) because a cylinder chamfer
## consumes cap radius rather than a whole section, and the box rule's minimum
## bevel would eat the thin stock.
##
## The kit is deliberately stateless. Callers own their mesh cache so the meshes
## are freed with the node that built them and never outlive the scene tree.

const PANEL_ALBEDO_PATH := "res://assets/materials/manufactured-paint-albedo.png"
const PANEL_NORMAL_PATH := "res://assets/materials/manufactured-paint-normal.png"
const PANEL_ROUGHNESS_PATH := "res://assets/materials/manufactured-paint-roughness.png"
const PANEL_NORMAL_SCALE := 0.32
const PANEL_TRIPLANAR_SHARPNESS := 4.0

## Finish response layered over a neutral microfinish. Roughness and clearcoat
## keep broad surfaces, walked decks and close metal trim distinct; the maps
## supply fine surface variation without inventing large bolts or panel seams.
## Callers still own the albedo/metalness values; this only owns the clearcoat
## hierarchy and therefore cannot rewrite a caller's colour or scalar PBR read.
## Painted metal keeps the tighter clear layer already authored for exterior
## safety furniture while sharing the same metric surface grain underneath.
enum PanelFinish {
	STRUCTURAL_ALLOY,
	WALKED_DECK,
	METAL_TRIM,
	PAINTED_METAL,
}

const STRUCTURAL_CLEARCOAT := 0.18
const STRUCTURAL_CLEARCOAT_ROUGHNESS := 0.38
const WALKED_CLEARCOAT := 0.06
const WALKED_CLEARCOAT_ROUGHNESS := 0.72
const TRIM_CLEARCOAT := 0.30
const TRIM_CLEARCOAT_ROUGHNESS := 0.24
const PAINTED_CLEARCOAT := 0.45
const PAINTED_CLEARCOAT_ROUGHNESS := 0.12

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

## Rim chamfer rule for cylinders and frustums.
##
## A cylinder's cap rim is the same zero-width 90° edge the box bevel exists to
## remove, and it has the same consequence: no pixels, so no specular line, so
## the part reads as a shaded primitive rather than a turned one. The rule here
## is deliberately *not* `bevel_for_size`, for a measured reason. That rule's
## 0.012 m floor is safe on a box because a box's shortest side is the whole
## section; on a cylinder the chamfer eats the **cap radius**, and the live
## population contains 0.025 m conduits and 0.030 m rails. A 0.012 m floor takes
## 48% of a 0.025 m cap and turns a pipe end into a cone. So there is no floor at
## all: the chamfer is purely proportional downward, which lets it vanish
## gracefully on stock too thin to carry it.
##
## `governing` is the smaller of the *narrow* rim radius and the half-height —
## the two dimensions a rim chamfer actually consumes. Because
## `RIM_CHAMFER_PROPORTION` is well under 1.0, taking 0.22 of that minimum is
## itself the clamp against both: the cap can never lose more than 22% of its
## radius and the lateral wall can never lose more than 22% of its half-height.
## No separate safety constant is needed and none is published, because an
## unused clamp is a claim nobody can check.
##
## `RIM_MAXIMUM_CHAMFER` is the only absolute term. Without it a 1.1 m beacon
## mast earns a 0.242 m chamfer and a 0.84 m engine can earns 0.185 m, which
## stops being an edge treatment and starts being a taper — the silhouette read
## changes, which is exactly what this pass must not do. 0.045 m is the largest
## width that stays under 5% of the largest live radius (1.42 m), and it is still
## far above the resolution floor: face-on in a 2560-wide 62° frame it spans
## about 47 px at 2 m and 16 px at 6 m, and it only has to survive the grazing
## angles a rim is actually seen at.
##
## Where each term binds, over the live population: the proportion governs the
## thin stock (0.025 m conduit -> 0.0028 m, 0.03 m rail -> 0.0066 m), the
## half-height term governs discs (1.42 m x 0.16 m table top -> 0.0176 m), and
## the maximum governs everything large (0.46 m lattice column, 0.62 m signal
## mast, 0.84 m engine can and 1.1 m beacon mast all land on 0.045 m).
const RIM_CHAMFER_PROPORTION := 0.22
const RIM_MAXIMUM_CHAMFER := 0.045

## `CylinderMesh.rings` default, mirrored so the chamfer's own triangle delta
## stays attributable when it is measured against the primitive this builder
## replaces. It is no longer what the builder *uses* — see `CYLINDER_WALL_RINGS`
## — and is retained as the dense reference tessellation that
## `tests/fleet_surface_detail_test.gd` and
## `tests/station_structural_bevel_contract_test.gd` compare the flattened wall
## against.
const CYLINDER_DEFAULT_RINGS := 4

## Lateral wall subdivision this builder uses when a caller does not ask for
## more. Zero, and that is an edge-free reduction rather than a quality trade.
##
## The fleet reached this first: `ShipSurfaceDetail.CYLINDER_WALL_RINGS` has been
## 0 since the ship pass, with 42 fixed 2560x1440 renders behind it. The station
## modules kept Godot's `rings = 4` because the note that used to live on
## `CYLINDER_DEFAULT_RINGS` said the station half was "a separate change owing
## its own rendered evidence". This is that change, and the evidence is in
## `docs/PERFORMANCE_BUDGET_SCENE_GEOMETRY.md`.
##
## Why it is free, stated as the property it rests on: a capped cylinder's wall
## quad between two adjacent radial angles is *planar*. On a straight cylinder
## both side edges are vertical; on a frustum both are generators meeting at the
## cone apex. Splitting that planar quad horizontally puts the new vertices
## exactly on the same plane at exactly the linear parameter the interpolator
## would have produced anyway:
##
## - position — `_add_cylinder_band` places ring `k` at `lerp(bottom_y, top_y,
##   k/n)` and `_radius_at` is linear in y, so every intermediate ring sits on
##   the generator line. No silhouette moves and no AABB changes.
## - normal — a band's normal is the perpendicular of its profile *tangent*, and
##   a wall's profile is one straight segment, so every sub-band is handed the
##   identical normal. There is no curvature along the wall to resolve.
## - UV — the axial coordinate is `(y + half_height) / height`, linear in y, so a
##   subdivided quad reproduces the linear function it interpolates from.
##
## So only something sampling per *vertex* could see the difference. Nothing in
## the station modules does: every station material is `SHADING_MODE_PER_PIXEL`,
## the panel finish is world-triplanar (sampled by world position, not by an
## interpolated vertex channel), and no module binds a vertex-displacement
## shader to a cylinder.
##
## The chamfer bands and the caps are untouched: those are where the rim
## highlight lives, and they are not planar continuations of the wall.
const CYLINDER_WALL_RINGS := 0

## Stamped on every mesh this builder returns. `CylinderMesh` was itself the
## marker that a surface is a turned round form — two suites read it that way,
## including the Torrent spec's required "paired round forms" check — and
## replacing the primitive with an `ArrayMesh` would silently erase that signal.
## The name restores it without adding a metadata pass to ten call sites.
const CHAMFERED_CYLINDER_RESOURCE_NAME := "chamfered_cylinder"

## Radial subdivision rule.
##
## `CYLINDER_WALL_RINGS` removed the *lateral* subdivision, which was provably
## free because a wall band is planar. The radial count is not free in the same
## way — it is the silhouette — so it is answered by measurement rather than by
## the flat 32 the interior modules were frozen at.
##
## **This does not invent a new tolerance. It reuses the one this project already
## rendered, looked at and accepted**, in `TorusGeometryBudget`. A cylinder's
## radial count tessellates exactly the same feature that class calls the *tube
## cross-section*: one circle, seen locally, whose faceting shows as flats along
## a silhouette. That budget solves it as
##
##     sagitta = radius * (1 - cos(PI / segments)) <= TOLERANCE_RADIANS * distance
##
## floored at `MIN_RING_SEGMENTS`, and both numbers carry rendered evidence:
## `TOLERANCE_RADIANS` is calibrated so the biggest circles in the shipped game
## come out at the 40 they were authored at, and the floor is the coarsest
## tessellation that survived a magnified walk-up photo sweep of the worst case in
## the game (a 10 cm collar at 0.6 m; `24x12` already showed a flattening, `18x9`
## was plainly a polygon). Using the same tolerance and the same floor here means
## the station's round stock is held to one standard instead of two, and that
## standard is the one with pictures behind it.
##
## The only thing this rule adds is the *distance*. `TorusGeometryBudget` budgets
## every tube cross-section at walk-up range because a torus can be anywhere; a
## station module knows where it bolted each part. So a caller may declare the
## closest a player's camera can actually get to a family — an overhead pressure
## rib is metres up and cannot be approached — and anything that does not declare
## one is budgeted at the same `NEAR_EYE_METRES` walk-up distance the torus rule
## uses. The rule is a ceiling, never a target: callers pass their authored count
## as `authored_segments` and the rule can only lower it.

## Reference display and field of view, published so the rule's cost in pixels
## can be read rather than recomputed. At 1920x1080 and the game's default 72°
## vertical FOV (`RuntimeSettings.DEFAULT_CAMERA_FOV`; Godot's `Camera3D.fov` is
## vertical under the default `KEEP_HEIGHT`) one vertical pixel subtends
## `deg_to_rad(72) / 1080` = 0.0011636 rad, so the shared tolerance of 0.0021 rad
## is about 1.8 px of silhouette error at the declared viewing distance.
const RADIAL_REFERENCE_VERTICAL_PIXELS := 1080.0
const RADIAL_REFERENCE_VERTICAL_FOV_DEGREES := 72.0

## Ceiling on the answer: the count the interior modules were previously frozen
## at, so a caller that authored 32 can only ever lose segments to this rule.
const MAXIMUM_RADIAL_SEGMENTS := 32


## Radians one vertical pixel subtends on the reference display.
static func radians_per_reference_pixel() -> float:
	return deg_to_rad(RADIAL_REFERENCE_VERTICAL_FOV_DEGREES) / RADIAL_REFERENCE_VERTICAL_PIXELS


## Screen-space sagitta, in reference pixels, of a `segments`-gon standing in for
## a circle of `radius` seen from `distance_metres`.
static func silhouette_error_pixels(radius: float, segments: int, distance_metres: float) -> float:
	if distance_metres <= 0.0 or segments < 3:
		return INF
	var sagitta := absf(radius) * (1.0 - cos(PI / float(segments)))
	return (sagitta / distance_metres) / radians_per_reference_pixel()


## Radial count for round stock of `radius` whose closest walkable approach is
## `nearest_view_metres`, never above `authored_segments`.
static func radial_segments_for(
		radius: float,
		nearest_view_metres: float = TorusGeometryBudget.NEAR_EYE_METRES,
		authored_segments: int = MAXIMUM_RADIAL_SEGMENTS
	) -> int:
	if not is_finite(radius) or not is_finite(nearest_view_metres) \
			or radius <= 0.0 or nearest_view_metres <= 0.0:
		return authored_segments
	var distance := maxf(TorusGeometryBudget.NEAR_EYE_METRES, nearest_view_metres)
	var solved := TorusGeometryBudget.segments_for(
		absf(radius),
		TorusGeometryBudget.TOLERANCE_RADIANS * distance,
		TorusGeometryBudget.MIN_RING_SEGMENTS
	)
	return mini(authored_segments, quantized_radial_segments(solved))


## Rounds a solved radial count up to the next multiple of four.
##
## This is not a rounding convenience, it is what keeps the AABB exact. A
## cylinder's four lateral extrema sit at 0°, 90°, 180° and 270°, and a vertex
## only lands on all four when the count is a multiple of four; at 26 segments
## the nearest vertex to 90° is 3.1° short and the mesh's stored bounds lose
## 0.7% on that axis. Every station contract that asserts a part's bounds — the
## VIP downlight housings, the batch custom AABBs, the shadow-proxy containment
## gate — reads that number, and "a bevel may alter highlights, never a station
## footprint" is the rule the whole kit is built on. Multiples of four preserve
## it exactly, and the floor and ceiling (12 and 32) are already multiples of
## four, so the answer is always one of 12, 16, 20, 24, 28, 32.
static func quantized_radial_segments(segments: int) -> int:
	return int(ceil(float(maxi(4, segments)) / 4.0)) * 4


## ## Declared-view tessellation for torus and sphere stock (ninth trim)
##
## The two primitives the census found cheapest to trim — 192 `TorusMesh` at
## 905 triangles and 226 `SphereMesh` at 474 — were budgeted at walk-up range
## whatever their placement. These two entry points are the one place a station
## module or a craft declares how close a camera actually gets to a collar or a
## lens, and receive back the coarsest tessellation the shared sagitta rule and
## the distance-scaled floors allow, never above what the builder authored.
##
## The torus rule lives in `TorusGeometryBudget` (it owns the ring floors and the
## sweep); the sphere rule is `ShipGeometryBudget.sphere_plan` carried out to a
## declared distance in the same way: its 16x8 walk-up floor scales with the
## declaration down to `SPHERE_FAR_MIN_RADIAL_SEGMENTS` x `SPHERE_FAR_MIN_RINGS`,
## the recipe the freight berth's own guide lenses already ship at.

## Eye height of a standing player, the figure every "seen from the deck"
## declaration in the modules subtracts from a fitting's height.
const STANDING_EYE_HEIGHT_METRES := 1.75

## A ring recessed into, or lying flush on, the deck a player stands on: tie-down
## sockets, umbilical deck connectors, lashing rings. From a 1.75 m eye the
## fitting is at least 1.6 m away — straight down is the closest case and the
## body's own capsule keeps it under the eye rather than at it.
const DECK_FLUSH_NEAREST_VIEW_METRES := 1.6

## Coarsest sphere this project will draw at any declared distance: twelve
## meridians and six rings, the recipe the Jovian freight berth's eighteen guide
## lenses have shipped at.
const SPHERE_FAR_MIN_RADIAL_SEGMENTS := 12
const SPHERE_FAR_MIN_RINGS := 6


## Sphere radial floor at a declared distance: the walk-up 16 carried out at the
## same angular edge, never under `SPHERE_FAR_MIN_RADIAL_SEGMENTS`.
static func sphere_radial_floor_for(nearest_view_metres: float) -> int:
	var declared := _declared_view(nearest_view_metres)
	if declared <= TorusGeometryBudget.NEAR_EYE_METRES:
		return ShipGeometryBudget.MIN_SPHERE_RADIAL_SEGMENTS
	return maxi(SPHERE_FAR_MIN_RADIAL_SEGMENTS, quantized_radial_segments(int(ceil(
		float(ShipGeometryBudget.MIN_SPHERE_RADIAL_SEGMENTS)
		* TorusGeometryBudget.NEAR_EYE_METRES / declared
	))))


## Sphere ring floor at a declared distance, likewise from the walk-up 8.
static func sphere_rings_floor_for(nearest_view_metres: float) -> int:
	var declared := _declared_view(nearest_view_metres)
	if declared <= TorusGeometryBudget.NEAR_EYE_METRES:
		return ShipGeometryBudget.MIN_SPHERE_RINGS
	return maxi(SPHERE_FAR_MIN_RINGS, int(ceil(
		float(ShipGeometryBudget.MIN_SPHERE_RINGS)
		* TorusGeometryBudget.NEAR_EYE_METRES / declared
	)))


## `(radial_segments, rings)` for a `SphereMesh` of world-space `radius` whose
## closest camera approach is `nearest_view_metres`, never above the authored
## pair. `rings` stays at half the radial count so the meridian and equator
## samplings of the silhouette remain balanced, as `sphere_plan` keeps them.
static func sphere_tessellation_for(
		radius: float,
		nearest_view_metres: float,
		authored_radial_segments: int,
		authored_rings: int
	) -> Vector2i:
	if not is_finite(radius) or radius <= 0.0:
		return Vector2i(authored_radial_segments, authored_rings)
	var declared := _declared_view(nearest_view_metres)
	var distance := maxf(declared, TorusGeometryBudget.FRAME_RATIO * radius)
	var allowance := TorusGeometryBudget.TOLERANCE_RADIANS * distance
	var radial := quantized_radial_segments(TorusGeometryBudget.segments_for(
		radius, allowance, sphere_radial_floor_for(declared)
	))
	var rings := maxi(sphere_rings_floor_for(declared), int(ceil(float(radial) * 0.5)))
	# Godot's `SphereMesh` cuts the meridian into `rings + 1` bands, so only an
	# odd ring count puts a vertex ring on the equator — the widest circle of the
	# silhouette and the one every dimension contract measures. A declared
	# answer is therefore made odd: 12x7 rather than 12x6 costs 24 triangles a
	# sphere and keeps the authored radius exact on all three axes, where the
	# even authored 24x12 already sat 0.7% inside it.
	if declared > TorusGeometryBudget.NEAR_EYE_METRES and rings % 2 == 0:
		rings += 1
	return Vector2i(mini(authored_radial_segments, radial), mini(authored_rings, rings))


## `(rings, ring_segments)` for a `TorusMesh` of the given world-space radii whose
## closest camera approach is `nearest_view_metres`, never above the authored
## pair. This is `TorusGeometryBudget.plan` for builders that tessellate a shared
## resource themselves (MultiMesh stock and craft built after the startup sweep).
static func torus_tessellation_for(
		inner_radius: float,
		outer_radius: float,
		nearest_view_metres: float,
		authored_rings: int,
		authored_ring_segments: int
	) -> Vector2i:
	var chosen := TorusGeometryBudget.plan(outer_radius, inner_radius, nearest_view_metres)
	return Vector2i(
		mini(authored_rings, int(chosen["rings"])),
		mini(authored_ring_segments, int(chosen["ring_segments"]))
	)


static func _declared_view(nearest_view_metres: float) -> float:
	if not is_finite(nearest_view_metres):
		return TorusGeometryBudget.NEAR_EYE_METRES
	return maxf(TorusGeometryBudget.NEAR_EYE_METRES, nearest_view_metres)


## Shadow-only geometry is not held to the screen rule, because a shadow's edge
## is not resolved in screen pixels: it is resolved in shadow-map texels and then
## filtered. `ShipyardWorld` runs the station key light at Godot's default
## 4096 directional atlas in `SHADOW_PARALLEL_4_SPLITS`, so each cascade owns a
## 2048 quadrant; over the 130 m `directional_shadow_max_distance` with splits at
## 0.06/0.16/0.42 the nearest cascade resolves roughly 6 mm per texel and the next
## roughly 15 mm, before Godot's filtering and the 2-texel normal bias widen the
## edge further. A caster silhouette held under one nearest-cascade texel
## therefore cannot move the rendered shadow edge by a resolvable amount.
const SHADOW_MAP_TEXEL_METRES := 0.006
const MINIMUM_SHADOW_RADIAL_SEGMENTS := 8
const MAXIMUM_SHADOW_RADIAL_SEGMENTS := 16

## Stamped on the shadow-only proxies so a proxy can never be mistaken for the
## colour mesh it stands in for, and so `is_cylindrical_mesh` — which exists to
## tell the ship and station suites that a surface is turned round stock — does
## not answer for geometry that is never shaded.
const SHADOW_PROXY_CYLINDER_RESOURCE_NAME := "chamfered_cylinder_shadow_proxy"


## Smallest even radial count whose silhouette stays inside one nearest-cascade
## shadow-map texel. Used only for geometry that is never shaded.
static func shadow_radial_segments_for(radius: float) -> int:
	if not is_finite(radius) or radius <= 0.0:
		return MAXIMUM_SHADOW_RADIAL_SEGMENTS
	var segments := MINIMUM_SHADOW_RADIAL_SEGMENTS
	while segments < MAXIMUM_SHADOW_RADIAL_SEGMENTS:
		if absf(radius) * (1.0 - cos(PI / float(segments))) <= SHADOW_MAP_TEXEL_METRES:
			break
		segments += 4
	return mini(
		MAXIMUM_SHADOW_RADIAL_SEGMENTS, quantized_radial_segments(segments)
	)


## Shadow-only stand-in for one length of round stock.
##
## Two reductions, both of which a shadow cannot carry. The radial count drops to
## `shadow_radial_segments_for`, and the rim chamfer is dropped entirely: a
## chamfer is a specular device — it exists to give a zero-width 90° edge enough
## pixels to hold a highlight — and a shadow pass has no highlight. Dropping it
## removes the two chamfer bands, taking the part from `8n` triangles to `4n`,
## and it cannot shrink the silhouette because a chamfer only ever removes
## material from the rim corner. The AABB is unchanged either way: radial extent
## is carried by the wall vertices, which stay on the circle, and axial extent by
## the caps, which stay on the end planes.
static func shadow_proxy_cylinder_mesh_cached(
		radius: float,
		height: float,
		cache: Dictionary
	) -> ArrayMesh:
	var segments := shadow_radial_segments_for(radius)
	var cache_key := "shadowcyl:%0.4f:%0.4f:%d" % [radius, height, segments]
	if cache.has(cache_key):
		return cache[cache_key] as ArrayMesh
	var mesh := chamfered_cylinder_mesh(
		radius, radius, height, segments, 0, true, true, 0.0
	)
	mesh.resource_name = SHADOW_PROXY_CYLINDER_RESOURCE_NAME
	cache[cache_key] = mesh
	return mesh


## True when this mesh is a turned round form: Godot's own cylinder primitive, or
## one of this kit's chamfered replacements for it.
static func is_cylindrical_mesh(mesh: Mesh) -> bool:
	if mesh is CylinderMesh:
		return true
	return mesh is ArrayMesh and mesh.resource_name == CHAMFERED_CYLINDER_RESOURCE_NAME

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


## Audit the immutable geometry recipe used by structural station pieces.
##
## A bevel is only useful if it survives into the submitted mesh: a caller can
## accidentally retain a `BoxMesh` while publishing a bevel width in metadata,
## which makes the art-direction contract green while the edge is still a hard
## 90-degree line.  The builder emits one surface and nine quads per face (324
## vertices); checking that topology plus the exact AABB makes the contract both
## headless-safe and independent of a renderer or captured frame.  The AABB
## equality is intentional: a bevel may alter highlights, never a station
## footprint, collision envelope, or authored broad shape.
static func structural_bevel_contract(
		mesh: Mesh,
		size: Vector3,
		expected_bevel: float
	) -> Dictionary:
	var errors := PackedStringArray()
	if mesh == null:
		errors.append("mesh_missing")
		return {"valid": false, "errors": errors, "recipe": &"station_chamfered_box_v1"}
	if expected_bevel <= 0.0:
		errors.append("bevel_width_must_be_positive")
	if not mesh is ArrayMesh:
		errors.append("mesh_must_be_array_mesh")
	if mesh.get_surface_count() != 1:
		errors.append("mesh_surface_count_drift")
	var expected_aabb := AABB(-size * 0.5, size)
	if not mesh.get_aabb().is_equal_approx(expected_aabb):
		errors.append("mesh_aabb_drift")
	var vertex_count := 0
	if mesh.get_surface_count() == 1:
		var arrays := mesh.surface_get_arrays(0)
		if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			vertex_count = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if vertex_count != 324:
		errors.append("chamfered_box_topology_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"recipe": &"station_chamfered_box_v1",
		"bevel_width": expected_bevel,
		"aabb": mesh.get_aabb(),
		"vertex_count": vertex_count,
		"surface_count": mesh.get_surface_count(),
	}


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
				# Emission order *is* the front-face winding, and it has to agree
				# with the outward normal every vertex already carries. Godot's
				# front face is the one whose vertices run clockwise seen from
				# outside, so on a correct surface `(b - a) x (c - a)` points
				# opposite the shading normal — every engine primitive measures
				# that way (BoxMesh, CylinderMesh and SphereMesh all score 0%
				# agreement). Emitting 0-1-2 / 0-2-3 here produced the reverse on
				# all six faces, so every box this kit built had its outward faces
				# culled and showed the unlit inside of its own back faces.
				# Rendered in isolation beside `BoxMesh` under a single key light,
				# the kit box was a black shell where the engine box was a normally
				# shaded cube. Vertices, normals, UVs and tangents are untouched;
				# only the order they are emitted in is reversed.
				_add_rounded_vertex(tool, points[0], inner_half, bevel, Vector2(u0, v0))
				_add_rounded_vertex(tool, points[2], inner_half, bevel, Vector2(u1, v1))
				_add_rounded_vertex(tool, points[1], inner_half, bevel, Vector2(u1, v0))
				_add_rounded_vertex(tool, points[0], inner_half, bevel, Vector2(u0, v0))
				_add_rounded_vertex(tool, points[3], inner_half, bevel, Vector2(u0, v1))
				_add_rounded_vertex(tool, points[2], inner_half, bevel, Vector2(u1, v1))
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


## Physical rim chamfer for a cylinder or frustum of these dimensions, in metres.
## See `RIM_CHAMFER_PROPORTION` for why this rule has no minimum floor.
static func rim_chamfer_for_cylinder(
		top_radius: float,
		bottom_radius: float,
		height: float
	) -> float:
	var narrow := minf(absf(top_radius), absf(bottom_radius))
	var half_height := absf(height) * 0.5
	if narrow <= 0.0 or half_height <= 0.0:
		return 0.0
	var governing := minf(narrow, half_height)
	return minf(governing * RIM_CHAMFER_PROPORTION, RIM_MAXIMUM_CHAMFER)


## Caller-owned cache keyed on the exact dimensions, matching
## `rounded_box_mesh_cached`. Repeated identical stock — and this project builds
## a great deal of it, 454 cylinders in the Habitat module alone — pays for the
## extra rings once.
##
## `material` is part of the key rather than something the caller applies
## afterwards, because a cached mesh is shared by reference: a caller that binds
## per-surface materials (the ships do, and their tests read
## `mesh.surface_get_material(0)`) would otherwise have the last material win on
## every earlier instance. Callers that use `material_override` pass null and
## share one mesh across every colour.
static func chamfered_cylinder_mesh_cached(
		top_radius: float,
		bottom_radius: float,
		height: float,
		radial_segments: int,
		cache: Dictionary,
		rings: int = CYLINDER_WALL_RINGS,
		cap_top: bool = true,
		cap_bottom: bool = true,
		material: Material = null
	) -> ArrayMesh:
	var chamfer := rim_chamfer_for_cylinder(top_radius, bottom_radius, height)
	var cache_key := "cyl:%0.4f:%0.4f:%0.4f:%d:%d:%d:%d:%0.4f:%d" % [
		top_radius, bottom_radius, height, radial_segments, rings,
		1 if cap_top else 0, 1 if cap_bottom else 0, chamfer,
		0 if material == null else material.get_instance_id(),
	]
	if cache.has(cache_key):
		return cache[cache_key] as ArrayMesh
	var mesh := chamfered_cylinder_mesh(
		top_radius, bottom_radius, height, radial_segments, rings, cap_top, cap_bottom, chamfer
	)
	if material != null and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, material)
	cache[cache_key] = mesh
	return mesh


## A cylinder or frustum whose capped rims are chamfered, standing in for
## `CylinderMesh` with the same `top_radius` / `bottom_radius` / `height` /
## `radial_segments` / `rings` / `cap_top` / `cap_bottom`.
##
## **AABB is preserved exactly, and that is what decides which rims move.** The
## radial extent of the whole mesh is `max(top_radius, bottom_radius)`. On a
## straight cylinder that radius is carried by the entire lateral wall, so both
## rims can be chamfered and the bounding box is untouched. On a *tapered*
## section the widest radius exists only on the wide rim's own circle: chamfering
## that rim would pull the silhouette in, so this builder leaves the wide rim
## sharp and treats only the narrow one. The station's tapered stock — the
## operations activity's 0.88 taper, the Freight berth's 0.94 — stands on its
## wide end against a deck where the rim is buried anyway, and it is the top rim
## that is at eye height. Nothing here moves a footprint, a published envelope,
## or a collision shape; collision shapes are built by the callers from the same
## `radius` / `height` arguments and never see this mesh.
static func chamfered_cylinder_mesh(
		top_radius: float,
		bottom_radius: float,
		height: float,
		radial_segments: int,
		rings: int = CYLINDER_WALL_RINGS,
		cap_top: bool = true,
		cap_bottom: bool = true,
		chamfer: float = -1.0
	) -> ArrayMesh:
	var segments := maxi(3, radial_segments)
	var half_height := height * 0.5
	var width := chamfer
	if width < 0.0:
		width = rim_chamfer_for_cylinder(top_radius, bottom_radius, height)
	var widest := maxf(top_radius, bottom_radius)
	# The AABB rule above, stated as code: a rim is only chamfered when it is
	# capped, when the chamfer is real, and when it is not the sole carrier of
	# the mesh's radial extent.
	var chamfer_top := cap_top and width > 0.0 and (top_radius < widest or is_equal_approx(top_radius, bottom_radius))
	var chamfer_bottom := cap_bottom and width > 0.0 and (bottom_radius < widest or is_equal_approx(top_radius, bottom_radius))
	var top_y := half_height - (width if chamfer_top else 0.0)
	var bottom_y := -half_height + (width if chamfer_bottom else 0.0)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_count := maxi(0, rings) + 1
	# Lateral wall, smooth around the ring exactly as CylinderMesh shades it.
	for step in ring_count:
		var y0 := lerpf(bottom_y, top_y, float(step) / float(ring_count))
		var y1 := lerpf(bottom_y, top_y, float(step + 1) / float(ring_count))
		var v0 := (y0 + half_height) / maxf(height, 0.0000001)
		var v1 := (y1 + half_height) / maxf(height, 0.0000001)
		_add_cylinder_band(
			tool, segments, _radius_at(top_radius, bottom_radius, half_height, y0),
			y0, _radius_at(top_radius, bottom_radius, half_height, y1), y1, v0, v1
		)
	# The chamfer bands take their own slice of the same 0..1 axial UV range as the
	# wall. Giving them a degenerate v span would leave `generate_tangents()` with
	# no UV derivative to work from on exactly the triangles this pass exists for.
	var safe_height := maxf(absf(height), 0.0000001)
	if chamfer_top:
		_add_cylinder_band(
			tool, segments, _radius_at(top_radius, bottom_radius, half_height, top_y), top_y,
			maxf(0.0, top_radius - width), half_height,
			(top_y + half_height) / safe_height, 1.0
		)
	if chamfer_bottom:
		_add_cylinder_band(
			tool, segments, maxf(0.0, bottom_radius - width), -half_height,
			_radius_at(top_radius, bottom_radius, half_height, bottom_y), bottom_y,
			0.0, (bottom_y + half_height) / safe_height
		)
	if cap_top:
		_add_cylinder_cap(tool, segments, maxf(0.0, top_radius - (width if chamfer_top else 0.0)), half_height, true)
	if cap_bottom:
		_add_cylinder_cap(tool, segments, maxf(0.0, bottom_radius - (width if chamfer_bottom else 0.0)), -half_height, false)
	tool.generate_tangents()
	var mesh := tool.commit()
	mesh.resource_name = CHAMFERED_CYLINDER_RESOURCE_NAME
	return mesh


## Lateral radius of the untapered profile at height `y`.
static func _radius_at(top_radius: float, bottom_radius: float, half_height: float, y: float) -> float:
	if half_height <= 0.0:
		return top_radius
	return lerpf(bottom_radius, top_radius, clampf((y + half_height) / (half_height * 2.0), 0.0, 1.0))


## One quad band between two coaxial circles.
##
## Every band carries its own flat-in-profile normal, so consecutive bands do not
## share a normal at the ring they meet on. That is deliberate: the crease at
## each end of the chamfer is what makes the highlight a line instead of a
## smeared gradient, and it is also how `CylinderMesh` separates its cap from its
## wall.
static func _add_cylinder_band(
		tool: SurfaceTool,
		segments: int,
		lower_radius: float,
		lower_y: float,
		upper_radius: float,
		upper_y: float,
		lower_v: float,
		upper_v: float
	) -> void:
	if is_equal_approx(lower_radius, upper_radius) and is_equal_approx(lower_y, upper_y):
		return
	# Profile tangent in (radius, y); its perpendicular pointing outward is the
	# band's normal, so a 45° chamfer gets a 45° normal and a wall gets a radial
	# one. This is the whole mechanism: without this band there is no direction
	# between "wall" and "cap" for a highlight to sit on.
	var run := upper_radius - lower_radius
	var rise := upper_y - lower_y
	var normal_radial := rise
	var normal_y := -run
	var normal_length := sqrt(normal_radial * normal_radial + normal_y * normal_y)
	if normal_length <= 0.0000001:
		return
	normal_radial /= normal_length
	normal_y /= normal_length
	for step in segments:
		var a := TAU * float(step) / float(segments)
		var b := TAU * float(step + 1) / float(segments)
		var ua := float(step) / float(segments)
		var ub := float(step + 1) / float(segments)
		var directions := [Vector2(cos(a), sin(a)), Vector2(cos(b), sin(b))]
		var normals: Array[Vector3] = []
		for direction: Vector2 in directions:
			normals.append(Vector3(direction.x * normal_radial, normal_y, direction.y * normal_radial).normalized())
		var lower_a := Vector3(directions[0].x * lower_radius, lower_y, directions[0].y * lower_radius)
		var lower_b := Vector3(directions[1].x * lower_radius, lower_y, directions[1].y * lower_radius)
		var upper_a := Vector3(directions[0].x * upper_radius, upper_y, directions[0].y * upper_radius)
		var upper_b := Vector3(directions[1].x * upper_radius, upper_y, directions[1].y * upper_radius)
		_emit_cylinder_vertex(tool, normals[0], Vector2(ua, lower_v), lower_a)
		_emit_cylinder_vertex(tool, normals[1], Vector2(ub, lower_v), lower_b)
		_emit_cylinder_vertex(tool, normals[1], Vector2(ub, upper_v), upper_b)
		_emit_cylinder_vertex(tool, normals[0], Vector2(ua, lower_v), lower_a)
		_emit_cylinder_vertex(tool, normals[1], Vector2(ub, upper_v), upper_b)
		_emit_cylinder_vertex(tool, normals[0], Vector2(ua, upper_v), upper_a)


## Flat end disc, wound so its face points away from the body.
static func _add_cylinder_cap(
		tool: SurfaceTool,
		segments: int,
		radius: float,
		y: float,
		upward: bool
	) -> void:
	if radius <= 0.0:
		return
	var normal := Vector3.UP if upward else Vector3.DOWN
	for step in segments:
		var a := TAU * float(step) / float(segments)
		var b := TAU * float(step + 1) / float(segments)
		var edge_a := Vector3(cos(a) * radius, y, sin(a) * radius)
		var edge_b := Vector3(cos(b) * radius, y, sin(b) * radius)
		var uv_a := Vector2(cos(a) * 0.5 + 0.5, sin(a) * 0.5 + 0.5)
		var uv_b := Vector2(cos(b) * 0.5 + 0.5, sin(b) * 0.5 + 0.5)
		if upward:
			_emit_cylinder_vertex(tool, normal, Vector2(0.5, 0.5), Vector3(0.0, y, 0.0))
			_emit_cylinder_vertex(tool, normal, uv_a, edge_a)
			_emit_cylinder_vertex(tool, normal, uv_b, edge_b)
		else:
			_emit_cylinder_vertex(tool, normal, Vector2(0.5, 0.5), Vector3(0.0, y, 0.0))
			_emit_cylinder_vertex(tool, normal, uv_b, edge_b)
			_emit_cylinder_vertex(tool, normal, uv_a, edge_a)


static func _emit_cylinder_vertex(tool: SurfaceTool, normal: Vector3, uv: Vector2, point: Vector3) -> void:
	tool.set_normal(normal)
	tool.set_uv(uv)
	tool.add_vertex(point)


## Binds the station microfinish: world-space triplanar albedo, normal and
## red-channel roughness. Existing world scales preserve grain continuity across
## module joins, while authored seams and part boundaries carry construction.
## Returns false when the registered maps are unavailable, leaving the caller's
## untextured PBR values untouched rather than binding a partial recipe.
static func apply_panel_triplanar(
		material: StandardMaterial3D,
		uv_scale: float,
		finish: PanelFinish = PanelFinish.STRUCTURAL_ALLOY
	) -> bool:
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
	_apply_panel_finish(material, finish)
	return true


static func _apply_panel_finish(material: StandardMaterial3D, finish: PanelFinish) -> void:
	var clearcoat := STRUCTURAL_CLEARCOAT
	var clearcoat_roughness := STRUCTURAL_CLEARCOAT_ROUGHNESS
	match finish:
		PanelFinish.WALKED_DECK:
			clearcoat = WALKED_CLEARCOAT
			clearcoat_roughness = WALKED_CLEARCOAT_ROUGHNESS
		PanelFinish.METAL_TRIM:
			clearcoat = TRIM_CLEARCOAT
			clearcoat_roughness = TRIM_CLEARCOAT_ROUGHNESS
		PanelFinish.PAINTED_METAL:
			clearcoat = PAINTED_CLEARCOAT
			clearcoat_roughness = PAINTED_CLEARCOAT_ROUGHNESS
		PanelFinish.STRUCTURAL_ALLOY:
			pass
	material.clearcoat_enabled = true
	material.clearcoat = clearcoat
	material.clearcoat_roughness = clearcoat_roughness


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
