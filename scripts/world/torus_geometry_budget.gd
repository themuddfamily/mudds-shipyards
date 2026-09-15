class_name TorusGeometryBudget
extends RefCounted

## Single owner of how much geometry a `TorusMesh` in this project is allowed to
## cost, scaled to the ring's world-space size rather than applied as one number.
##
## The whole-scene census found 129 `TorusMesh` instances costing 213,664
## triangles — 15.2% of the entire scene at 1,656 triangles each, the worst
## value-per-triangle in the project. The cause is that five module builders and
## four ship builders each authored a fixed tessellation (`rings` 40-64,
## `ring_segments` 12-18) and applied it to every ring they made, from a
## 148-metre moonlet ring down to a 10-centimetre pipe collar.
##
## A single global replacement is the wrong fix, and this class exists because of
## that. A half-metre mast collar and a five-metre Cinder Reach beacon signal
## ring are both `TorusMesh`; the collar can drop hard and the signal ring cannot,
## because the player reads the signal ring *as a circle* and a visibly polygonal
## circle is one of the loudest "cheap game" tells there is. So the budget solves
## for tessellation from the ring's own measured world-space radii.
##
## Everything here is modern interpretation: presentation-budget numbers chosen
## by measurement and by looking at renders in this project, not recovered values.
##
## ## The rule
##
## A circle of radius `R` drawn with `N` segments deviates from the true circle
## by a sagitta of `R * (1 - cos(PI / N))`. That is the entire visual defect, and
## it is the only thing this budget targets. Two independent circles live in a
## torus and they are solved separately:
##
## - `rings` tessellates the **major sweep** — the big circle the ring traces.
##   Its faceting is what makes a ring "look polygonal".
## - `ring_segments` tessellates the **tube cross-section**. Its faceting shows up
##   as flats along the tube's silhouette and as banding in its specular.
##
## Each is given an error allowance and solved for the smallest segment count
## that stays inside it. The allowances differ because the two features are seen
## from different distances:
##
## - **Major sweep.** To see a ring of radius `R` as a ring at all, the whole
##   circle has to fit the frame, which puts the camera at least `R / tan(fov/2)`
##   away — about `1.5 R` at this project's 70 degree field of view. That is
##   geometry, not an assumption about where the level puts the player, so the
##   allowance is `TOLERANCE * max(NEAR_EYE, FRAME_RATIO * R)`.
## - **Tube cross-section.** The tube is a *local* feature: a player can walk up
##   to one small arc of a nine-metre landing pad ring and stand beside it. There
##   is no geometric floor on that distance, so the tube is always budgeted at
##   `NEAR_EYE` — the closest a camera realistically gets to a solid surface.
##
## One extra constraint applies to the major sweep. On a *thin* ring the sweep's
## faceting is judged against the tube's own thickness rather than against the
## ring's radius: a 2-centimetre-thick band that wobbles by a centimetre reads as
## a ring of straight rods no matter how large the ring is. So the major
## allowance is additionally capped at a fraction of the tube radius.
##
## Finally, the budget **never increases** authored tessellation. Where the rule
## asks for more than a builder authored, the authored value stands. This class
## is a ceiling, not a target, and it cannot make the scene more expensive.

## Angular size, in radians, of the largest geometric error this budget will
## accept at the assumed viewing distance.
##
## This is the one number that decides how smooth a large ring stays, so it is
## calibrated against something already rendered and already accepted rather than
## picked as a round figure. `nearby_sector_cluster.gd` builds the biggest
## circles in the game — the 148 m moonlet rings and the Cinder Reach beacon
## signal and trim rings — at `rings = 40`, and those read as circles in the
## shipped scene. 0.0021 rad is the tolerance at which this budget's own answer
## for a large ring comes out at exactly 40.
##
## That calibration is deliberate and it is what makes this pass safe. Because 40
## is both the answer for a large ring and the value the large rings were already
## authored at, every one of them comes out unchanged to the segment: the beacon
## signal and trim rings, the moonlet rings, the crater rims, the drum collars.
## Nothing authored at 40 moves at all.
##
## Rings authored at 48 and 64 do come down to 40 — including ones a player does
## read as circles, such as the 9 m landing pad rings and the berth rings. Those
## are the reductions that had to be *looked at* rather than reasoned about, and
## they were: at both walk-up and whole-ring framing they are indistinguishable
## from the authored version at 1:1. 40 is not a number this class invented; it is
## the number the project's own large circles already use.
##
## For scale: at the reference framing this project captures at — 1920x1080 with
## the 70 degree field of view the game cameras use — one vertical pixel is
## `deg_to_rad(70) / 1080 = 0.001131` rad, so this is a shade under two pixels of
## silhouette error at the distance the ring is assumed to be seen from.
const TOLERANCE_RADIANS := 0.0021

## Closest distance in metres a camera is taken to a solid surface in this game.
##
## The on-foot camera sits inside a character body that collides with the world,
## and the flight cameras are outside the hull they follow. 0.6 m is the
## walk-up case with margin; nothing in the station lets a player press their eye
## against a pipe collar.
const NEAR_EYE_METRES := 0.6

## Multiple of a ring's radius at which the whole ring first fits the frame.
##
## At a 70 degree vertical field of view a circle of radius `R` fits when the
## camera is `R / tan(35 deg) = 1.43 R` away. 1.5 is that with a little margin.
## This is what makes the budget scale with apparent size instead of with world
## size: a large ring is necessarily seen from further away, so it is allowed a
## proportionally larger sagitta, while a small collar is not.
const FRAME_RATIO := 1.5

## Cap on the major sweep's sagitta as a fraction of the tube radius.
##
## Protects thin rings. The Arrow's fuselage panel bands are 1.35 m across with a
## 2 cm tube; without this cap the distance rule alone would let them wobble by
## more than a fifth of their own thickness, which reads as a polygon of straight
## rods rather than as a band. 0.20 keeps the wobble to a fifth of the tube
## radius, a tenth of its visible width.
const SILHOUETTE_TUBE_FRACTION := 0.20

## Floors, and the most important numbers in this file.
##
## These are **not** arithmetic. The distance rule above, left to itself, took the
## smallest rings in the scene — the 10 cm exterior pipe clamps on the operations
## room, at 0.6 m — down to `18 x 9`, a saving of 79%. Rendered and looked at,
## `18 x 9` is a visibly polygonal ring: straight runs and hard corners around the
## top and lower-left of the silhouette. So the rule was wrong, and the floor is
## what corrects it.
##
## The correction came from a sweep, not from re-deriving the maths. That clamp
## was built into the live world at `48x16`, `32x12`, `24x12`, `20x10` and `18x9`
## and photographed at walk-up range by `tests/capture_torus_smoothness.gd`, then
## magnified 3x on the silhouette:
##
## - `48x16` (authored) — a smooth ellipse.
## - `32x12` — also smooth. No straight run anywhere on the silhouette.
## - `24x12` — a faint flattening appears at the top of the ring.
## - `20x10` — clear angular corners top and lower-left.
## - `18x9`  — plainly a polygon.
##
## `32 x 12` is therefore the floor: the coarsest tessellation that was *looked at*
## and found clean on the worst case in the game. Roughly 11,000 triangles are
## left on the table by not going to `24 x 12`, and that is the right trade —
## a faceted circle is one of the loudest "cheap game" tells there is, and this
## project's whole direction is away from that.
##
## The lesson the numbers missed: a silhouette *polygon* is detectable well below
## the point where its deviation from a circle is two pixels, because the eye
## reads straightness and corners rather than absolute error. An angular error
## budget alone will always over-reduce small close objects.
const MIN_RINGS := 32
const MIN_RING_SEGMENTS := 12

## ## The declared-view rule (ninth trim)
##
## The floors above were photographed at `NEAR_EYE_METRES`, and the tube rule
## always budgets at that range, because a torus *can* be anywhere. Most of the
## station's collars cannot: a pipe collar on a 3.6 m service run, a roof-vent
## collar on a 5.3 m roof, a lashing ring recessed into the deck plate under a
## standing eye. Every one of those still carried the 0.6 m answer, and the
## whole-scene census found 174,000 triangles of `TorusMesh` at 905 each — the
## cheapest headroom left against the 1,800,000 ceiling.
##
## A builder may therefore *declare* the nearest distance a camera can be taken
## to a ring — the same declaration `StationSurfaceKit.radial_segments_for` and
## the module rib builders already make for round stock — and the plan is then
## solved at that distance:
##
## - The sagitta rule is unchanged: `TOLERANCE_RADIANS` at the declared
##   distance, still capped at a fraction of the tube for the major sweep.
## - The floor scales with the declaration. A polygon is read by its *angular*
##   edge length, not its metric error, so the photographed 32x12 at 0.6 m is
##   carried to a further distance as `32 * 0.6 / d` and `12 * 0.6 / d`: the
##   same angular sampling the walk-up floor was judged clean at. Below
##   `FAR_MIN_RINGS` x `FAR_MIN_RING_SEGMENTS` nothing goes, whatever the
##   distance: a 12-gon is the coarsest circle this project will draw, and eight
##   is the cardinal-aligned tube section the bounded profiles below already use.
## - Declared answers are rounded up to a multiple of `RADIAL_ALIGNMENT` so a
##   vertex lands on every cardinal direction of both circles: the ring's x/z
##   footprint and the tube's thickness stay exactly the authored extrema, which
##   is what lets every family's AABB contract hold to the millimetre.
##
## Undeclared rings — anything a builder has not measured — keep the walk-up
## rule bit for bit. A declaration never raises tessellation and never lowers
## the floor a walk-up ring is held to; it only says how far away the ring is.
const FAR_MIN_RINGS := 12
const FAR_MIN_RING_SEGMENTS := 8
const RADIAL_ALIGNMENT := 4

## Declared nearest-view distances, keyed by `TorusMesh` instance id.
##
## A registry rather than metadata, deliberately: the module audits freeze the
## exact metadata list on their collar meshes and renderer nodes (one key, the
## authored tessellation, after the sweep; none before it), and a builder must
## be able to declare a distance without moving any of those contracts. The
## sweep consults it; `apply` consults it when not given a distance directly.
static var _declared_nearest_view: Dictionary = {}

## Smallest saving worth perturbing a builder's authored geometry for.
##
## The rule sometimes lands one or two segments below what a builder chose — the
## Jovian outer dock ring comes out at 47 against an authored 48, worth 24
## triangles. Re-tessellating for that is churn: it moves every vertex on the
## ring, changes its inscribed radius, and buys nothing. Below a tenth, the
## authored value stands.
const MINIMUM_SAVING_FRACTION := 0.10

## Optional per-instance profile selected by builders for a bounded visual-only
## family. Profiles are never inferred from names or paths: a builder must opt a
## ring in explicitly, keeping the global rendered floor authoritative for every
## unmarked torus.
const PROFILE_META := "torus_geometry_budget_profile"
const PROFILE_OCCLUDED_CHAIR_BEARING: StringName = &"occluded_chair_bearing"
const PROFILE_AFT_INTERFACE_COLLAR: StringName = &"aft_interface_collar"
const PROFILE_FREIGHT_RECESSED_LASHING_RING: StringName = &"freight_recessed_lashing_ring"

## The eight observation-common chair bearings sit inside the pedestal/seat
## overlap. Their 32-edge major silhouette remains at the globally reviewed
## floor; only the occluded tube cross-section drops from 13 segments to 8.
## Eight is aligned to the cardinal axes, so outer radius and visible thickness
## retain exact extrema. This family was approved from its same-camera Forward+
## comparison, not generalized to exposed collars.
const OCCLUDED_CHAIR_BEARING_RING_SEGMENTS := 8

## Twenty-six visual-only Aft Junction collars wrap an existing solid support or
## service run: chair pedestals, console shocks, roof/service pipes, cable tray
## and cabinet conduits. They share the generic budget's 32x12 result. Keeping
## all 32 major rings and using the same cardinal-aligned eight-edge tube section
## preserves their outer extrema while removing an invisible roundness premium
## from these inset interfaces. Freestanding and large rings never opt in.
const AFT_INTERFACE_COLLAR_RING_SEGMENTS := 8

## Eight visual-only Jovian Freight Berth lashing rings are partly inset into
## their graphite deck plates. Their circular sweep remains at the globally
## reviewed 32-ring floor. Only the four-centimetre tube cross-section drops
## from twelve to eight cardinal-aligned segments, which preserves the exact
## inner/outer extrema and AABB. The builder tags this exact family explicitly;
## no name or path inference opts a torus into the exception.
const FREIGHT_RECESSED_LASHING_RING_SEGMENTS := 8


## Smallest segment count whose sagitta on a circle of `radius` stays within
## `allowed_error`, both in metres.
##
## Inverts `radius * (1 - cos(PI / segments)) <= allowed_error`. A degenerate or
## unbounded input returns the floor rather than something enormous.
static func segments_for(radius: float, allowed_error: float, minimum: int) -> int:
	if radius <= 0.0 or allowed_error <= 0.0:
		return minimum
	var cosine := 1.0 - allowed_error / radius
	if cosine <= -1.0:
		# The allowance is larger than the whole circle; the floor governs.
		return minimum
	var half_angle := acos(clampf(cosine, -1.0, 1.0))
	if half_angle <= 0.0:
		return minimum
	return maxi(minimum, int(ceil(PI / half_angle)))


## Declares the nearest distance a camera can be taken to any instance of
## `mesh`, in metres, for the sweep and `apply` to solve at. Never raises the
## tessellation; a declaration under walk-up range is the walk-up rule.
static func declare_nearest_view(mesh: TorusMesh, nearest_view_metres: float) -> TorusMesh:
	if mesh == null:
		return mesh
	# A shared resource is budgeted at the closest of its uses: a second
	# declaration can only bring the distance in, never push it out.
	var key := mesh.get_instance_id()
	var declared := _sanitised_view(nearest_view_metres)
	if _declared_nearest_view.has(key):
		declared = minf(declared, float(_declared_nearest_view[key]))
	_declared_nearest_view[key] = declared
	return mesh


## The distance declared for `mesh`, or walk-up range when nothing was declared.
static func nearest_view_for(mesh: TorusMesh) -> float:
	if mesh == null:
		return NEAR_EYE_METRES
	return float(_declared_nearest_view.get(mesh.get_instance_id(), NEAR_EYE_METRES))


static func _sanitised_view(nearest_view_metres: float) -> float:
	if not is_finite(nearest_view_metres):
		return NEAR_EYE_METRES
	return maxf(NEAR_EYE_METRES, nearest_view_metres)


## Rounds a declared count up to the next multiple of `RADIAL_ALIGNMENT`.
static func aligned(segments: int) -> int:
	return int(ceil(float(maxi(segments, RADIAL_ALIGNMENT)) / float(RADIAL_ALIGNMENT))) * RADIAL_ALIGNMENT


## Major-sweep floor at a declared distance: the photographed 32 carried out to
## `nearest_view_metres` at the same angular edge, never under `FAR_MIN_RINGS`.
static func floor_rings_for(nearest_view_metres: float) -> int:
	var declared := _sanitised_view(nearest_view_metres)
	if declared <= NEAR_EYE_METRES:
		return MIN_RINGS
	return maxi(FAR_MIN_RINGS, aligned(int(ceil(float(MIN_RINGS) * NEAR_EYE_METRES / declared))))


## Tube-section floor at a declared distance, likewise from the photographed 12.
static func floor_ring_segments_for(nearest_view_metres: float) -> int:
	var declared := _sanitised_view(nearest_view_metres)
	if declared <= NEAR_EYE_METRES:
		return MIN_RING_SEGMENTS
	return maxi(
		FAR_MIN_RING_SEGMENTS,
		aligned(int(ceil(float(MIN_RING_SEGMENTS) * NEAR_EYE_METRES / declared)))
	)


## Tessellation this budget would choose for a torus of the given world-space
## radii, ignoring whatever was authored.
##
## `outer_radius` and `inner_radius` are the `TorusMesh` properties already
## multiplied by the instance's world scale, so this works on the size a player
## actually sees rather than on the size the builder typed. `nearest_view_metres`
## is the builder's declared closest approach; at or under `NEAR_EYE_METRES` this
## is exactly the walk-up rule the floors were photographed for.
##
## Returns `{"rings": int, "ring_segments": int}`.
static func plan(
		outer_radius: float,
		inner_radius: float,
		nearest_view_metres: float = NEAR_EYE_METRES
	) -> Dictionary:
	var major_radius := (outer_radius + inner_radius) * 0.5
	var tube_radius := (outer_radius - inner_radius) * 0.5
	var declared := _sanitised_view(nearest_view_metres)
	# Major sweep: seen from at least far enough that the ring fits the frame,
	# and never nearer than the builder declared.
	var major_distance := maxf(declared, FRAME_RATIO * major_radius)
	var major_allowance := TOLERANCE_RADIANS * major_distance
	if tube_radius > 0.0:
		# ...but never allowed to wobble by much of the tube's own thickness.
		major_allowance = minf(major_allowance, SILHOUETTE_TUBE_FRACTION * tube_radius)
	# Tube cross-section: a local feature, budgeted at the declared range.
	var tube_allowance := TOLERANCE_RADIANS * declared
	if declared <= NEAR_EYE_METRES:
		return {
			"rings": segments_for(major_radius, major_allowance, MIN_RINGS),
			"ring_segments": segments_for(tube_radius, tube_allowance, MIN_RING_SEGMENTS),
		}
	return {
		"rings": aligned(segments_for(major_radius, major_allowance, floor_rings_for(declared))),
		"ring_segments": aligned(segments_for(
			tube_radius, tube_allowance, floor_ring_segments_for(declared)
		)),
	}


## Metadata key under which a mesh's pre-budget tessellation is kept.
##
## This exists so a before/after render can be taken from **one** build of the
## world rather than from two builds of two code states. "Does the saving show?"
## is the only question that decides whether a reduction is allowed, and it is
## much easier to answer honestly when both pictures come out of the same scene,
## the same lighting and the same camera. `tests/capture_torus_smoothness.gd`
## uses this; nothing at runtime reads it.
const AUTHORED_META := "torus_budget_authored_tessellation"


## Applies the budget to one `TorusMesh` in place at a given world scale.
##
## Never increases either count: where the rule asks for more than the builder
## authored, the authored value stands. Returns the mesh so callers can chain.
## `nearest_view_metres` is the builder's declared closest approach; left
## negative, a distance declared through `declare_nearest_view` is used, and
## an undeclared mesh is budgeted at walk-up range.
static func apply(mesh: TorusMesh, world_scale := 1.0, nearest_view_metres := -1.0) -> TorusMesh:
	return apply_profile(mesh, world_scale, &"", nearest_view_metres)


## Applies the general plan, with one deliberately narrow presentation profile
## selected explicitly by the builder.
## The profile changes no radius or transform and may never raise tessellation.
static func apply_profile(
		mesh: TorusMesh,
		world_scale: float,
		profile: StringName,
		nearest_view_metres := -1.0
	) -> TorusMesh:
	if mesh == null:
		return mesh
	if not mesh.has_meta(AUTHORED_META):
		mesh.set_meta(AUTHORED_META, Vector2i(mesh.rings, mesh.ring_segments))
	var scale_factor := maxf(world_scale, 0.0001)
	# An explicit distance is a declaration: it is recorded so the sweep, the
	# census and the budget suite all read the same nearest view for this mesh.
	if nearest_view_metres > NEAR_EYE_METRES:
		declare_nearest_view(mesh, nearest_view_metres)
	var declared := nearest_view_for(mesh) if nearest_view_metres < 0.0 \
		else minf(_sanitised_view(nearest_view_metres), nearest_view_for(mesh))
	var chosen := plan(
		mesh.outer_radius * scale_factor, mesh.inner_radius * scale_factor, declared
	)
	var rings := mini(mesh.rings, int(chosen["rings"]))
	var segments := mini(mesh.ring_segments, int(chosen["ring_segments"]))
	if profile == PROFILE_OCCLUDED_CHAIR_BEARING:
		segments = mini(segments, OCCLUDED_CHAIR_BEARING_RING_SEGMENTS)
	elif profile == PROFILE_AFT_INTERFACE_COLLAR:
		segments = mini(segments, AFT_INTERFACE_COLLAR_RING_SEGMENTS)
	elif profile == PROFILE_FREIGHT_RECESSED_LASHING_RING:
		segments = mini(segments, FREIGHT_RECESSED_LASHING_RING_SEGMENTS)
	var before := mesh.rings * mesh.ring_segments
	if before - rings * segments < int(ceil(MINIMUM_SAVING_FRACTION * float(before))):
		return mesh
	mesh.rings = rings
	mesh.ring_segments = segments
	return mesh


## Puts every budgeted `TorusMesh` under `node` back to the tessellation its
## builder authored. Used only by the smoothness capture harness.
static func restore_authored(node: Node) -> int:
	var restored := 0
	var instance := node as MeshInstance3D
	if instance != null:
		var mesh := instance.mesh as TorusMesh
		if mesh != null and mesh.has_meta(AUTHORED_META):
			var authored: Vector2i = mesh.get_meta(AUTHORED_META)
			mesh.rings = authored.x
			mesh.ring_segments = authored.y
			restored += 1
	for child in node.get_children():
		restored += restore_authored(child)
	return restored


## Applies the budget to every `TorusMesh` under `node`, including itself.
##
## This exists so the budget has one owner rather than one copy per module that
## happens to build a ring. Nine builders across the station modules and the ship
## visuals author tori, two of which this pass is not allowed to edit; sweeping
## the built tree reaches all of them without touching any of their call sites.
##
## World scale is read from each instance's global transform, so this must run
## once the tree is inside the scene and the modules have finished building. A
## mesh shared by several instances is budgeted at the largest scale it appears
## at, so sharing can never make a ring coarser than its biggest use allows.
##
## Returns `{"tori": int, "triangles_before": int, "triangles_after": int}` so a
## caller can log or assert on the saving rather than trust it.
static func normalise_tree(node: Node) -> Dictionary:
	var found: Dictionary = {}
	_collect(node, found)
	var report := {
		"tori": 0,
		"triangles_before": 0,
		"triangles_baseline": 0,
		"triangles_after": 0,
		"profiles": {},
	}
	for key in found:
		var entry: Dictionary = found[key]
		var mesh: TorusMesh = entry["mesh"]
		var instances := int(entry["instances"])
		var profile := StringName(entry["profile"])
		var before := triangles_of(mesh) * instances
		var baseline_mesh := mesh.duplicate() as TorusMesh
		if mesh.has_meta(AUTHORED_META):
			var authored: Vector2i = mesh.get_meta(AUTHORED_META)
			baseline_mesh.rings = authored.x
			baseline_mesh.ring_segments = authored.y
		# The baseline column is the walk-up rule regardless of any declaration,
		# so a report always shows what the declared distance bought.
		apply(baseline_mesh, float(entry["scale"]), NEAR_EYE_METRES)
		var baseline := triangles_of(baseline_mesh) * instances
		report["tori"] = int(report["tori"]) + instances
		report["triangles_before"] = int(report["triangles_before"]) + before
		report["triangles_baseline"] = int(report["triangles_baseline"]) + baseline
		apply_profile(mesh, float(entry["scale"]), profile)
		var after := triangles_of(mesh) * instances
		report["triangles_after"] = int(report["triangles_after"]) + after
		if not profile.is_empty():
			var profiles := report["profiles"] as Dictionary
			if not profiles.has(profile):
				profiles[profile] = {
					"resources": 0,
					"instances": 0,
					"surfaces": 0,
					"triangles_before": 0,
					"triangles_baseline": 0,
					"triangles_after": 0,
				}
			var profile_report := profiles[profile] as Dictionary
			profile_report["resources"] = int(profile_report["resources"]) + 1
			profile_report["instances"] = int(profile_report["instances"]) + instances
			profile_report["surfaces"] = int(profile_report["surfaces"]) + int(entry["surfaces"])
			profile_report["triangles_before"] = int(profile_report["triangles_before"]) + before
			profile_report["triangles_baseline"] = int(profile_report["triangles_baseline"]) + baseline
			profile_report["triangles_after"] = int(profile_report["triangles_after"]) + after
	return report


static func _collect(node: Node, found: Dictionary) -> void:
	var instance := node as MeshInstance3D
	if instance != null:
		var mesh := instance.mesh as TorusMesh
		if mesh != null:
			var basis := instance.global_transform.basis
			var world_scale := maxf(maxf(basis.x.length(), basis.y.length()), basis.z.length())
			var key := mesh.get_instance_id()
			if found.has(key):
				var entry: Dictionary = found[key]
				entry["instances"] = int(entry["instances"]) + 1
				entry["surfaces"] = int(entry["surfaces"]) + mesh.get_surface_count()
				entry["scale"] = maxf(float(entry["scale"]), world_scale)
				if StringName(entry["profile"]) != StringName(instance.get_meta(PROFILE_META, &"")):
					entry["profile"] = &""
			else:
				found[key] = {
					"mesh": mesh,
					"scale": world_scale,
					"instances": 1,
					"surfaces": mesh.get_surface_count(),
					"profile": StringName(instance.get_meta(PROFILE_META, &"")),
				}
	for child in node.get_children():
		_collect(child, found)


## Triangle count of a `TorusMesh`.
##
## `Mesh` has no triangle accessor. `TorusMesh` is a closed grid of
## `rings * ring_segments` quads, so this is exact and, unlike reading the
## surface arrays back, does not force the mesh to regenerate.
static func triangles_of(mesh: TorusMesh) -> int:
	if mesh == null:
		return 0
	return mesh.rings * mesh.ring_segments * 2
