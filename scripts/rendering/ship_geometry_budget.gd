class_name ShipGeometryBudget
extends RefCounted

## Single owner of how finely the fleet's *detail* stock is tessellated, scaled
## to the part's own world-space size instead of applied as one authored number.
##
## This is the ship-side sibling of `TorusGeometryBudget`, and it exists for the
## same reason that class does. Nine builders across the five craft in scope each
## picked a fixed subdivision and used it everywhere: `_turned` revolves every
## Cinder nozzle part at 96 radial segments whether the part is a two-metre bell
## mouth or a twenty-centimetre thrust plug; the Jovian's rib, rail and frame
## joints are all 24x12 spheres from 9 cm to 16 cm across; its roof service
## patches are always 12 steps wide whether the patch spans 3.5 m or 12 cm; its
## flight-deck transition rolls a quarter-ellipse at 32 segments, which is 128
## segments around a full section.
##
## Everything in this file is modern interpretation: presentation-budget numbers
## chosen by measurement and by looking at renders, not recovered values.
##
## ## The rule, and why it is the same rule
##
## A circle of radius `R` drawn with `N` segments misses the true circle by a
## sagitta of `R * (1 - cos(PI / N))`. That is the whole visual defect on a
## revolved form, on a sphere's silhouette and on a rolled fillet alike, so the
## arithmetic is shared with `TorusGeometryBudget` rather than re-derived here:
## `TOLERANCE_RADIANS`, `NEAR_EYE_METRES` and `FRAME_RATIO` are imported from it,
## and `segments_for` is called on it directly. Keeping one set of constants is
## the point — a second, slightly different tolerance in a second file is how a
## project ends up with two answers for the same 80 cm collar.
##
## For scale, in the frames this pass captured at: 1280x720 with the 70 degree
## field of view the game cameras use, one vertical pixel is
## `deg_to_rad(70) / 720 = 0.0016977` rad, so a metre of world at 1.5 m (walking
## distance) is 589 px and at 8 m (chase distance) is 110 px. The two distances
## the roadmap item names are therefore worth 2.55 mm and 13.6 mm per pixel.
##
## ## What this budget will not do
##
## It never increases an authored count — every entry point takes the authored
## value and returns `min(authored, budgeted)`. It cannot make a mesh finer, and
## on any part already coarser than the rule it is a no-op.
##
## It also stops at the rendered floors below rather than at the arithmetic.
## `TorusGeometryBudget` learned that the hard way: its distance rule alone took
## the station's 10 cm pipe clamps to `18x9`, which was rendered and found
## plainly polygonal, because the eye reads *straightness and corners* long
## before the deviation from a circle reaches two pixels. The floors here are
## that lesson carried across, not a fresh derivation.


## Smallest number of radial segments any revolved ship form may be reduced to.
##
## Matched deliberately to `TorusGeometryBudget.MIN_RINGS`. That value is the
## coarsest tessellation the project has actually rendered a round silhouette at
## and accepted — the sweep in that file's header photographed a collar at
## 48/32/24/20/18 segments at walk-up range and found 32 clean and 24 already
## flattening at the top of the ring. A Cinder nozzle bell is the same kind of
## object as that collar: a circle the player reads *as a circle*, from outside,
## at ranges from a walk-up in the expansion berth to a chase camera. So it gets
## the same floor, and the budget's own answer for a bell-sized radius (40) sits
## above it anyway.
const MIN_REVOLVED_SEGMENTS := 32

## Floor for a sphere used as a joint, rivet or lens bead.
##
## A sphere is not a ring, and the ring floor is the wrong number for it in both
## directions. Its silhouette is one great circle, so `radial_segments` and
## `2 * rings` each sample that same circle and the coarser of the two governs;
## but unlike a ring it is a solid blob a few centimetres across whose outline is
## read as "round thing", not as "circle". The fleet's joints run 9-16 cm across
## and are seen from 1.5 m at the closest (the Jovian cargo-bay frames) — a 17 cm
## joint is 100 px at that range, and 16 segments put its worst silhouette error
## at `85 * (1 - cos(PI / 16)) = 1.63` px of a 100 px blob.
##
## 16x8 is also what the fleet's own coarsest existing joint already uses (the
## Jovian's 0.18 m boarding-rail bead), so this floor is a value the project
## ships and has looked at rather than one this file invented.
##
## Why this is *not* the blanket sphere reduction `ShipSurfaceDetail` rejected:
## that measurement dropped **every** sphere in the fleet to 16x8, including the
## Zenith's engine spheres, and the coherent 967 px clusters it found were on
## those large exposed spheres. This budget is radius-scaled, so a large sphere
## keeps its authored count and only centimetre-scale beads come down.
const MIN_SPHERE_RADIAL_SEGMENTS := 16
const MIN_SPHERE_RINGS := 8

## Floor for a rolled fillet or shallow pressed span: three segments across the
## curve. Two would make a fold rather than a roll at any size.
const MIN_CURVE_STEPS := 3

## Floor for a *tube* cross-section — the radial segmentation of a cylinder,
## frustum or rod, as opposed to a circle the player reads as a circle.
##
## Deliberately `TorusGeometryBudget.MIN_RING_SEGMENTS`, not `MIN_RINGS`, and the
## distinction is the one that file already draws. Its major sweep is a closed
## circle standing in the view plane, and a polygonal circle is the loudest
## "cheap game" tell there is, so it gets the 32 that was rendered and judged. Its
## tube cross-section is a local feature seen edge-on: the silhouette a tube
## presents is two straight generators, and coarsening it moves the apparent
## width by `radius * (1 - cos(PI / N))` rather than turning an outline into a
## polygon. That is budgeted at walk-up range against a floor of 12.
##
## A ship's rod, strut, conduit and rail stock is the tube case. Its caps are the
## circle case, but they are the small end of a rod rather than a standalone
## ring, and the kit already puts a chamfered rim on them.
const MIN_TUBE_SEGMENTS := 12

## The two gameplay ranges Phase 10 item 2 names, and the geometric error each
## one allows at this project's calibrated angular tolerance.
##
## `WALKING_DISTANCE_METRES` is the range a player on foot reads an interior
## fitting or a hull fitting from while standing beside it; `CHASE_DISTANCE_METRES`
## is the exterior chase camera's standoff. At 1280x720 and the 70 degree vertical
## field of view the game cameras use, one pixel is 2.55 mm of world at the first
## and 13.6 mm at the second.
##
## `TorusGeometryBudget.NEAR_EYE_METRES` (0.6 m) stays the strictest of the three
## and is what the revolved/sphere rules above use, because a camera really can
## be pressed that close to a collar. The walking allowance is published here for
## the *surface* rules, where the feature being judged is a chamfer band that a
## player has to be standing in front of to see at all.
const WALKING_DISTANCE_METRES := 1.5
const CHASE_DISTANCE_METRES := 8.0
const NEAR_EYE_ALLOWANCE_METRES := TorusGeometryBudget.TOLERANCE_RADIANS * TorusGeometryBudget.NEAR_EYE_METRES
const WALKING_ALLOWANCE_METRES := TorusGeometryBudget.TOLERANCE_RADIANS * WALKING_DISTANCE_METRES
const CHASE_ALLOWANCE_METRES := TorusGeometryBudget.TOLERANCE_RADIANS * CHASE_DISTANCE_METRES


## Radial segments for a form revolved about an axis, whose largest world-space
## radius is `radius` metres.
##
## The whole section is a circle the player can see end-on, so it is budgeted
## exactly as `TorusGeometryBudget` budgets a ring's major sweep: seen from at
## least far enough away that the circle fits the frame, floored at the walk-up
## distance for a small one.
static func revolved_segments(radius: float, authored: int) -> int:
	if radius <= 0.0:
		return authored
	var distance := maxf(
		TorusGeometryBudget.NEAR_EYE_METRES, TorusGeometryBudget.FRAME_RATIO * radius
	)
	var allowance := TorusGeometryBudget.TOLERANCE_RADIANS * distance
	return mini(
		authored,
		TorusGeometryBudget.segments_for(radius, allowance, MIN_REVOLVED_SEGMENTS)
	)


## Radial segments for a tube of world-space `radius` — a cylinder, frustum, rod
## or rail wall. Always budgeted at walk-up range, as `TorusGeometryBudget` does
## for a torus tube, against `MIN_TUBE_SEGMENTS`.
static func tube_segments(radius: float, authored: int) -> int:
	if radius <= 0.0:
		return authored
	var allowance := TorusGeometryBudget.TOLERANCE_RADIANS * TorusGeometryBudget.NEAR_EYE_METRES
	return mini(authored, TorusGeometryBudget.segments_for(radius, allowance, MIN_TUBE_SEGMENTS))


## Tessellation for a joint/bead `SphereMesh` of world-space `radius`.
##
## Returns `{"radial_segments": int, "rings": int}`, never above the authored
## pair. `rings` is held at half `radial_segments` so the quad aspect the
## authored spheres have (24x12) is preserved and the two silhouette samplings
## stay balanced.
static func sphere_plan(radius: float, authored_radial: int, authored_rings: int) -> Dictionary:
	if radius <= 0.0:
		return {"radial_segments": authored_radial, "rings": authored_rings}
	var distance := maxf(
		TorusGeometryBudget.NEAR_EYE_METRES, TorusGeometryBudget.FRAME_RATIO * radius
	)
	var allowance := TorusGeometryBudget.TOLERANCE_RADIANS * distance
	var radial := TorusGeometryBudget.segments_for(
		radius, allowance, MIN_SPHERE_RADIAL_SEGMENTS
	)
	# Keep the authored 2:1 radial/ring aspect; round up so the vertical
	# sampling is never the coarser of the two.
	var rings := maxi(MIN_SPHERE_RINGS, int(ceil(float(radial) * 0.5)))
	return {
		"radial_segments": mini(authored_radial, radial),
		"rings": mini(authored_rings, rings),
	}


## Segments across a circular arc of world radius `radius` sweeping `sweep`
## radians — a rolled shoulder, a quarter-elliptical fillet, a bend radius.
##
## The floor scales with the sweep: a quarter turn gets a quarter of the full
## circle's floor, because a 90 degree corner drawn with 32 segments is eight
## times smoother than the closed circles `MIN_REVOLVED_SEGMENTS` was rendered
## for, and nothing about a partial arc makes it need more per radian.
static func arc_segments(radius: float, sweep: float, authored: int) -> int:
	if radius <= 0.0 or sweep <= 0.0:
		return authored
	var distance := maxf(
		TorusGeometryBudget.NEAR_EYE_METRES, TorusGeometryBudget.FRAME_RATIO * radius
	)
	var allowance := TorusGeometryBudget.TOLERANCE_RADIANS * distance
	var full_circle := TorusGeometryBudget.segments_for(
		radius, allowance, MIN_REVOLVED_SEGMENTS
	)
	var scaled := int(ceil(float(full_circle) * sweep / TAU))
	return mini(authored, maxi(MIN_CURVE_STEPS, scaled))


## Steps across a shallow span of `chord` metres whose surface departs from the
## straight chord by at most `sagitta` metres.
##
## Used for pressed panels that follow a broad hull crown: the panel is a strip
## of a very large cylinder, so the same sagitta rule applies with the *panel's*
## own chord rather than the crown's radius. `sagitta` is the actual measured
## deflection of the surface across the span, which the caller can evaluate from
## its own height function, so nothing is assumed about the crown's shape.
##
## A span with no measurable deflection is a flat plate and needs one step.
static func span_steps(chord: float, sagitta: float, authored: int) -> int:
	if chord <= 0.0 or authored <= 1:
		return maxi(1, authored)
	if sagitta <= 0.0:
		return 1
	# A parabolic strip subdivided into `n` equal steps leaves a residual
	# sagitta of `total_sagitta / n^2`. Solve for the smallest `n` whose residual
	# is under the angular allowance at walk-up range.
	var allowance := TorusGeometryBudget.TOLERANCE_RADIANS * TorusGeometryBudget.NEAR_EYE_METRES
	if sagitta <= allowance:
		return 1
	return mini(authored, maxi(1, int(ceil(sqrt(sagitta / allowance)))))


## Grid resolution for a soft-goods surface (bunk fabric, upholstery) whose
## shape is a sum of sine terms.
##
## Fabric is not a circle and the sagitta rule does not describe it. What does is
## the sampling theorem: a surface carrying `periods` full sine periods across a
## span needs enough samples per period to reconstruct the wave, and below about
## six samples per period a fold stops being a fold and starts being a zigzag.
## `SAMPLES_PER_PERIOD` is that number, taken from the authored meshes: the
## Halyard's curtain carries five fold periods across 32 columns, which is 6.4
## samples per period, and it is the finest-featured piece of cloth on the ship.
## So the rule reproduces the authored resolution exactly where the authored
## resolution was needed, and only cuts where the surface carries fewer periods.
const SAMPLES_PER_PERIOD := 6.4

static func wave_samples(periods: float, authored: int) -> int:
	if periods <= 0.0:
		return mini(authored, 4)
	return mini(authored, maxi(4, int(ceil(periods * SAMPLES_PER_PERIOD))))
