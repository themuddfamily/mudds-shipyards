class_name SignGeometryBudget
extends RefCounted

## Single owner of how much geometry the station's lettering is allowed to cost.
##
## Every legible sign in the game is a `TextMesh`, and a `TextMesh` is far more
## expensive than it looks. It triangulates each glyph contour at a resolution
## driven by `font_size`, then — if `depth` is non-zero — emits that whole
## triangulation a second time for the back face and a wall of quads around
## every contour segment for the sides. Measured on the production scene at the
## settings this project had been authoring signs with (`font_size = 64`,
## `pixel_size = 0.012`, `depth = 0.020`-`0.030`), 31 signs cost 315,360
## triangles: 18.9% of the entire scene, at an average of 10,172 triangles per
## sign, roughly forty times the average cost of a real authored art mesh.
##
## Two facts make that cost avoidable without touching legibility:
##
## 1. **The extrusion is invisible.** Sign depth in this project runs 0.020 to
##    0.030 m before node scale, and node scale on the station signs is 0.14 to
##    0.68 — so the actual extrusion is three to twenty *millimetres* of lettering
##    that is read from metres away, edge-on to nobody. It costs 75% of the
##    triangles.
## 2. **`font_size` is a tessellation setting, not a size setting.** World size
##    is `font_size * pixel_size * node scale`. Halving `font_size` while
##    doubling `pixel_size` produces a glyph block of *identical* world
##    dimensions, tessellated with fewer segments per curve.
##
## This class applies both, and only both. It does not change text, colour,
## alignment, position, rotation, material or node scale, so it cannot change
## what a sign says, where it is, which way it faces, or which colour cue it
## carries. The MAP-004 facing work and the colourblind-safe cue palette are
## untouched by construction.
##
## Everything here is modern interpretation: these are presentation-budget
## numbers chosen by measurement in this project, not recovered values.

## Curve tessellation resolution for station lettering.
##
## Re-frozen in the open. Old: 64, the Godot `TextMesh` default, used by every
## sign builder in the project. New: 48.
##
## Reason, from rendered evidence rather than assumption. 64, 48 and 32 were each
## built into the live world and photographed at reading distance and at distance
## by `tests/capture_sign_legibility.gd`, then cropped and magnified 2-3x on the
## bowls of `S`, `C`, `D`, `O` and `G`. At 1080p all three are legible and 48 is
## indistinguishable from 64; 32 is *also* legible, with only a hint of extra
## flattening on the `S` terminals under magnification.
##
## 48 is chosen anyway. Going from 48 to 32 saves a further 23,000 triangles,
## which is 1.4% of the scene — and it spends the entire remaining quality margin
## on the one class of object in the game whose whole job is to be read. Glyph
## tessellation is fixed geometry, so the margin that looks generous at 1080p is
## the margin that gets consumed at 1440p and 4K, which is where a mid-range
## Windows PC increasingly is. 48 keeps 80% of the available saving and keeps the
## margin. If lettering ever needs to be cheaper than this, the next move is LOD
## or baked quads, not a coarser curve.
const FONT_SIZE := 48

## Em-height in world metres before node scale: `font_size * pixel_size`.
##
## The project's authored value was `64 * 0.012 = 0.768`. This constant preserves
## it exactly, so `pixel_size` is derived rather than authored and no sign
## changes size. A sign authored at some other product keeps its own product;
## see `apply`.
const REFERENCE_EM_METRES := 0.768

## Glyph extrusion depth in world metres before node scale.
##
## Re-frozen in the open. Old: 0.020 (habitat spine, aft junction stack), 0.025
## (shipyard world), 0.030 (Cinder Reach cluster). New: 0.0. Reason: the back
## face and the contour side walls together are three quarters of a `TextMesh`,
## and at these depths and scales they render as at most a two-centimetre lip
## that no camera in the game is ever positioned to see. Flat lettering also
## removes the mirrored back face that MAP-004 was raised about: a sign seen from
## behind now shows nothing instead of showing reversed text.
##
## The extrusion is symmetric about local z = 0 either way, so this leaves every
## recorded proud-of-panel clearance in `shipyard_world.gd` exactly where it was.
const DEPTH := 0.0


## Builds a budgeted, centred `TextMesh` for a station sign.
##
## Sign builders call this instead of configuring a `TextMesh` themselves, so
## the tessellation and extrusion settings have exactly one author. Node scale,
## position, rotation and material stay with the caller: this owns cost, not
## placement.
static func build(text: String, em_metres := REFERENCE_EM_METRES) -> TextMesh:
	var mesh := TextMesh.new()
	mesh.text = text
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return apply(mesh, em_metres)


## Applies the budget to one `TextMesh` in place at a given em-height.
##
## `pixel_size` is derived so `font_size * pixel_size` stays at `em_metres`,
## which is what actually determines the glyph block's world size.
static func apply(mesh: TextMesh, em_metres := REFERENCE_EM_METRES) -> TextMesh:
	if mesh == null:
		return mesh
	var em := em_metres
	if em <= 0.0:
		em = REFERENCE_EM_METRES
	mesh.font_size = FONT_SIZE
	mesh.pixel_size = em / float(FONT_SIZE)
	mesh.depth = DEPTH
	return mesh


## Applies the budget to every `TextMesh` under `node`, including itself.
##
## This exists so the budget has one owner rather than one copy per module that
## happens to build a sign. Modules that construct their own lettering call
## `apply` directly; anything that does not is caught here, once, after the tree
## is built.
##
## Returns `{"signs": int, "triangles_before": int, "triangles_after": int}` so a
## caller can log or assert on the saving rather than trust it.
static func normalise_tree(node: Node) -> Dictionary:
	var report := {"signs": 0, "triangles_before": 0, "triangles_after": 0}
	_normalise_into(node, report)
	return report


static func _normalise_into(node: Node, report: Dictionary) -> void:
	var instance := node as MeshInstance3D
	if instance != null:
		var mesh := instance.mesh as TextMesh
		if mesh != null:
			var before := triangles_of(mesh)
			var already_budgeted := mesh.font_size == FONT_SIZE and is_equal_approx(mesh.depth, DEPTH)
			if not already_budgeted:
				# Preserve whatever em-height this sign was authored at, so a
				# module that deliberately letters larger or smaller keeps its
				# world size to the millimetre.
				apply(mesh, float(mesh.font_size) * mesh.pixel_size)
			report["signs"] = int(report["signs"]) + 1
			report["triangles_before"] = int(report["triangles_before"]) + before
			report["triangles_after"] = int(report["triangles_after"]) + triangles_of(mesh)
	for child in node.get_children():
		_normalise_into(child, report)


## Triangle count of a mesh, read from its surface arrays.
##
## `Mesh` has no triangle accessor, and `TextMesh` regenerates lazily, so this
## is the only honest way to get the number. It is exposed because the tests and
## the census both need exactly this and should not each reimplement it.
static func triangles_of(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices != null and indices.size() > 0:
			total += indices.size() / 3
			continue
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		if vertices != null:
			total += vertices.size() / 3
	return total
