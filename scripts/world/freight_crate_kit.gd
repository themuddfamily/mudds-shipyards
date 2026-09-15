class_name FreightCrateKit
extends RefCounted

## One shipping-crate / tote finish for the station's small freight (Phase 10 §3).
##
## ## What this replaces
##
## FREIGHT-FINISH-001 gave the station one container finish and recorded the
## residual it left behind: the Jovian freight berth's small pallet and rack
## crates — `StagedCrateLower/Upper` on the two painted staging bays and the six
## `RackStoredCrate*` units on the rack decking, 0.6–2.2 m — were still plain
## chamfered slabs in the berth's own `ceramic`, `ceramic_warm` and `orange`, and
## one of them fills the foreground of the rack-line review view. A slab painted
## the colour of the room it stands in is furniture, not freight.
##
## ## A different object class
##
## These are not small containers and must not read as one. A container is a
## steel frame with corrugated sheet hung on it; a crate at this scale is a
## **moulded tote** — one stiff shell with the ribs formed into it — and the
## recipe is built around the three things that say *tote* at gameplay distance:
##
## * **corner battens** — four full-height posts, the only parts flush with the
##   published envelope on every axis. They take the stacking load, they are what
##   the crate stands on, and they are what makes the panels between them read as
##   recessed mouldings rather than as paint.
## * **recessed panels between edge battens** — the shell core sits `panel_for`
##   behind the envelope on all four sides, split by a **mid rail** and closed at
##   the bottom by a **skirt rail** lifted `foot_lift_for` off the ground, so the
##   crate visibly stands on its four batten feet with a shadow line under the
##   skirt instead of sitting flat like a slab.
## * **a lid** — one slab dropped `LID_DROP` below the batten tops with its sides
##   set `FRAME_INSET` in from the envelope, so its underside edge is a lip and a
##   seam line runs right round the crate just below the top.
## * **a strap pair** — optional (`strapped`): two bands over the lid and down the
##   two long sides. The staged lower crate keeps the pair of separate strap
##   nodes it already had and takes the unstrapped variant; the rack crates and
##   the upper staged crate are strapped by the kit.
## * **a small stencilled marking** — the `freight-tote` stores plate from
##   `tools/generate_ship_markings.py`, in the upper panel of both long sides,
##   so the crate reads the same from the lane and from the apron and one mesh
##   serves every placement. Shared by every finish, because a returnable tote
##   carries the yard's stores mark rather than an operator's livery.
## * **three finishes** — `FINISHES`: olive, plum and stone. All three are
##   distinct hue families from the container operators' oxide red, navy and sand
##   (`FreightContainerKit.OPERATORS`), from the station's structural teal, and
##   from the five craft body tones and five accents frozen in
##   `tests/fleet_role_differentiation_test.gd`; every one is a duller, darker
##   moulded-polymer colour than any painted craft surface.
##
## ## What it costs
##
## One `ArrayMesh` with three surfaces per crate — `SURFACE_SHELL` (core, lid),
## `SURFACE_TRIM` (battens, rails, straps) and `SURFACE_STENCIL` (two quads,
## four triangles). Every part is `ShipChamferedStock.box_mesh` through
## `FreightContainerKit.commit_boxes`, so this is the same stock and the same
## emitter as the containers: no new mesh family, no new shader, no new texture
## beyond the one generated plate. A caller keeps one mesh per size and applies
## the finish as per-instance surface overrides, so the unique-mesh census does
## not move.
##
## ## The envelope is exact
##
## `shell_mesh` publishes an AABB of exactly `AABB(-size * 0.5, size)`: the four
## battens reach all six extremes and nothing else does. Every `BoxShape3D`,
## clearance sweep, bearing check and handling-fixture marker sized from `size`
## is therefore unchanged by the finish.
##
## ## Coplanar safety
##
## Everything here is one mesh in one renderer, so `tools/coplanar_seam_audit.gd`
## does not compare these faces against each other — but the eye does, and two
## faces on one plane inside one mesh flicker exactly as badly. Every part
## therefore sits on its own plane, separated by more than
## `CoplanarSeamAudit.OFFSET_TOLERANCE_M` (3 mm):
##
## * battens: flush (0).
## * straps and the stencil plate: `STRAP_STANDOFF` / `STENCIL_STANDOFF` (6 mm)
##   inside the envelope, so a strap crossing a batten top or a batten face is
##   never on its plane, and the top strap stands 6 mm proud of the lid.
## * rails and the lid: `FRAME_INSET` (12 mm) — the same plane, but the mid rail,
##   the skirt rail and the lid never overlap in height, so no pair shares area.
## * the shell core: at least `PANEL_MINIMUM` (25 mm), behind everything.
## * parts that meet are butted end-into-face or buried, never laid face-on-face.

const SURFACE_SHELL := 0
const SURFACE_TRIM := 1
const SURFACE_STENCIL := 2
const SURFACE_COUNT := 3

const MARKING := "freight-tote"

## The three tote finishes. Moulded polymer, so low metallic and a rougher
## response than the containers' painted steel; separated from one another as
## three hue families (a yellow-green, a red-violet and a neutral) rather than
## three values of one.
const FINISHES: Array[Dictionary] = [
	{"id": &"stores_olive", "shell_color": Color("5c6b3f")},
	{"id": &"stores_plum", "shell_color": Color("6b3b56")},
	{"id": &"stores_stone", "shell_color": Color("7f8478")},
]

## Battens, rails and straps: one dark polymer trim shared by every finish, at
## every site. It is the part of the recipe that makes the totes one family.
const TRIM_COLOR := Color("2c3133")
const TRIM_METALLIC := 0.22
const TRIM_ROUGHNESS := 0.58
const SHELL_METALLIC := 0.08
const SHELL_ROUGHNESS := 0.52

## Proportions, all against the crate's shortest side so a 0.6 m rack tote and a
## 2.2 m staged crate are one object at two sizes.
const BATTEN_PROPORTION := 0.09
const BATTEN_MINIMUM := 0.04
const BATTEN_MAXIMUM := 0.12
const PANEL_PROPORTION := 0.05
const PANEL_MINIMUM := 0.025
const PANEL_MAXIMUM := 0.06
const RAIL_HEIGHT_FRACTION := 0.75
const RAIL_DEPTH_FRACTION := 0.7
const LID_PROPORTION := 0.07
const LID_MINIMUM := 0.03
const LID_MAXIMUM := 0.09
const FOOT_LIFT_PROPORTION := 0.03
const FOOT_LIFT_MINIMUM := 0.015
const FOOT_LIFT_MAXIMUM := 0.03
## The mid rail sits a little below half height so the upper panel — the one
## that carries the plate and the one a standing player sees most of — is the
## larger of the two.
const MID_RAIL_HEIGHT_FRACTION := -0.08
const FRAME_INSET := 0.012
const LID_DROP := 0.012
const STRAP_STANDOFF := 0.006
const STRAP_THICKNESS := 0.016
const STRAP_OFFSET_FRACTION := 0.24
const STRAP_WIDTH_PROPORTION := 0.06
const STRAP_WIDTH_MINIMUM := 0.05
const STRAP_WIDTH_MAXIMUM := 0.11
const STENCIL_STANDOFF := 0.006
const STENCIL_ASPECT := 0.5
const STENCIL_PANEL_FRACTION := 0.6
const STENCIL_MAXIMUM_LENGTH := 0.6
const STENCIL_MINIMUM_LENGTH := 0.16

const SIGNS: Array[float] = [-1.0, 1.0]


static func finish_for_index(index: int) -> Dictionary:
	return FINISHES[posmod(index, FINISHES.size())]


static func finish_color(index: int) -> Color:
	return finish_for_index(index)["shell_color"] as Color


static func shell_material(color: Color, panel_scale: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = SHELL_METALLIC
	material.roughness = SHELL_ROUGHNESS
	StationSurfaceKit.apply_panel_triplanar(
		material, panel_scale, StationSurfaceKit.PanelFinish.PAINTED_METAL
	)
	return material


static func trim_material(panel_scale: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = TRIM_COLOR
	material.metallic = TRIM_METALLIC
	material.roughness = TRIM_ROUGHNESS
	StationSurfaceKit.apply_panel_triplanar(
		material, panel_scale, StationSurfaceKit.PanelFinish.METAL_TRIM
	)
	return material


## The stores plate: UV1, not triplanar, not tinted — the same reasoning as the
## container data plate, and the same generated 512 × 256 asset family.
static func stencil_material() -> StandardMaterial3D:
	return FreightContainerKit.stencil_material(MARKING)


static func shortest_side(size: Vector3) -> float:
	return minf(size.x, minf(size.y, size.z))


static func batten_for(size: Vector3) -> float:
	return clampf(shortest_side(size) * BATTEN_PROPORTION, BATTEN_MINIMUM, BATTEN_MAXIMUM)


static func panel_for(size: Vector3) -> float:
	return clampf(shortest_side(size) * PANEL_PROPORTION, PANEL_MINIMUM, PANEL_MAXIMUM)


static func lid_for(size: Vector3) -> float:
	return clampf(shortest_side(size) * LID_PROPORTION, LID_MINIMUM, LID_MAXIMUM)


static func foot_lift_for(size: Vector3) -> float:
	return clampf(
		shortest_side(size) * FOOT_LIFT_PROPORTION, FOOT_LIFT_MINIMUM, FOOT_LIFT_MAXIMUM
	)


static func strap_width_for(size: Vector3) -> float:
	return clampf(size.z * STRAP_WIDTH_PROPORTION, STRAP_WIDTH_MINIMUM, STRAP_WIDTH_MAXIMUM)


## The plate's drawn size for a crate of this size: `STENCIL_PANEL_FRACTION` of
## the upper panel's clear height, 2:1, and never wider than the flat panel
## between the two straps.
static func stencil_size(size: Vector3, strapped: bool) -> Vector2:
	var layout := _layout(size)
	var height := float(layout["upper_panel_height"]) * STENCIL_PANEL_FRACTION
	var length := clampf(height / STENCIL_ASPECT, STENCIL_MINIMUM_LENGTH, STENCIL_MAXIMUM_LENGTH)
	var clear := size.z - batten_for(size) * 2.0
	if strapped:
		clear = (size.z * STRAP_OFFSET_FRACTION - strap_width_for(size) * 0.5) * 2.0
	length = minf(length, maxf(clear * 0.86, STENCIL_MINIMUM_LENGTH * 0.5))
	return Vector2(length, length * STENCIL_ASPECT)


## The finish itself. One `ArrayMesh`, three surfaces, exact `size` AABB.
##
## `strapped` adds the strap pair. The plate is on both X faces, so the mesh
## does not depend on which side a player reads the crate from and the caller
## never rotates a crate for its plate.
static func shell_mesh(size: Vector3, strapped: bool = true) -> ArrayMesh:
	var half := size * 0.5
	var layout := _layout(size)
	var batten := float(layout["batten"])
	var panel := float(layout["panel"])
	var lid := float(layout["lid"])
	var foot_lift := float(layout["foot_lift"])
	var rail_height := float(layout["rail_height"])
	var rail_depth := float(layout["rail_depth"])
	var mid_rail_y := float(layout["mid_rail_y"])
	var shell: Array[Dictionary] = []
	var trim: Array[Dictionary] = []

	# Four corner battens, full height, flush on every axis. These alone reach
	# the six extremes of the published envelope.
	for corner_x in SIGNS:
		for corner_z in SIGNS:
			trim.append({
				"position": Vector3(
					corner_x * (half.x - batten * 0.5), 0.0, corner_z * (half.z - batten * 0.5)
				),
				"size": Vector3(batten, size.y, batten),
			})

	# The shell core: recessed `panel` on all four sides, buried into the skirt
	# rail below and the lid above so no core face is ever an exposed edge.
	var skirt_y := -half.y + foot_lift + rail_height * 0.5
	var lid_y := half.y - LID_DROP - lid * 0.5
	shell.append({
		"position": Vector3(0.0, (skirt_y + lid_y) * 0.5, 0.0),
		"size": Vector3(
			maxf(size.x - panel * 2.0, panel),
			maxf(lid_y - skirt_y, panel),
			maxf(size.z - panel * 2.0, panel)
		),
	})

	# The lid: one slab dropped below the batten tops, sides set `FRAME_INSET`
	# in, corners buried in the battens.
	shell.append({
		"position": Vector3(0.0, lid_y, 0.0),
		"size": Vector3(
			maxf(size.x - FRAME_INSET * 2.0, panel),
			lid,
			maxf(size.z - FRAME_INSET * 2.0, panel)
		),
	})

	# Skirt rails (lifted off the ground so the battens stand as feet) and mid
	# rails, on all four faces, set `FRAME_INSET` behind the battens and butted
	# end-into-face against them.
	var along_z := maxf(size.z - batten * 2.0, rail_depth)
	var along_x := maxf(size.x - batten * 2.0, rail_depth)
	for rail_y in [skirt_y, mid_rail_y]:
		for side in SIGNS:
			trim.append({
				"position": Vector3(side * (half.x - FRAME_INSET - rail_depth * 0.5), rail_y, 0.0),
				"size": Vector3(rail_depth, rail_height, along_z),
			})
			trim.append({
				"position": Vector3(0.0, rail_y, side * (half.z - FRAME_INSET - rail_depth * 0.5)),
				"size": Vector3(along_x, rail_height, rail_depth),
			})

	# The strap pair: over the lid and down both X faces, `STRAP_STANDOFF`
	# inside the envelope so a strap crossing a batten is never on its plane.
	if strapped:
		var strap_width := strap_width_for(size)
		var strap_top := half.y - STRAP_STANDOFF
		var strap_bottom := skirt_y
		for side_z in SIGNS:
			var strap_z := side_z * size.z * STRAP_OFFSET_FRACTION
			trim.append({
				"position": Vector3(0.0, strap_top - STRAP_THICKNESS * 0.5, strap_z),
				"size": Vector3(size.x - STRAP_STANDOFF * 2.0, STRAP_THICKNESS, strap_width),
			})
			for side_x in SIGNS:
				trim.append({
					"position": Vector3(
						side_x * (half.x - STRAP_STANDOFF - STRAP_THICKNESS * 0.5),
						(strap_top + strap_bottom) * 0.5,
						strap_z
					),
					"size": Vector3(STRAP_THICKNESS, strap_top - strap_bottom, strap_width),
				})

	var mesh := ArrayMesh.new()
	FreightContainerKit.commit_boxes(mesh, shell)
	FreightContainerKit.commit_boxes(mesh, trim)
	_commit_stencil(mesh, size, strapped, layout)
	mesh.resource_name = "freight_crate_shell"
	return mesh


## Where the parts sit for a crate of this size. Published through one function
## so the mesh and the plate can never disagree about where the upper panel is.
static func _layout(size: Vector3) -> Dictionary:
	var half := size * 0.5
	var batten := batten_for(size)
	var lid := lid_for(size)
	var foot_lift := foot_lift_for(size)
	var rail_height := batten * RAIL_HEIGHT_FRACTION
	var mid_rail_y := size.y * MID_RAIL_HEIGHT_FRACTION
	var upper_panel_bottom := mid_rail_y + rail_height * 0.5
	var upper_panel_top := half.y - LID_DROP - lid
	return {
		"batten": batten,
		"panel": panel_for(size),
		"lid": lid,
		"foot_lift": foot_lift,
		"rail_height": rail_height,
		"rail_depth": batten * RAIL_DEPTH_FRACTION,
		"mid_rail_y": mid_rail_y,
		"upper_panel_height": maxf(upper_panel_top - upper_panel_bottom, 0.0),
		"upper_panel_center_y": (upper_panel_top + upper_panel_bottom) * 0.5,
	}


## One quad in the upper panel of each X face, `STENCIL_STANDOFF` proud of the
## recessed shell and still well behind the rail and batten planes.
static func _commit_stencil(
		mesh: ArrayMesh, size: Vector3, strapped: bool, layout: Dictionary
	) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side_x in SIGNS:
		FreightContainerKit.emit_plate(
			tool,
			Vector3(
				side_x * (size.x * 0.5 - float(layout["panel"]) + STENCIL_STANDOFF),
				float(layout["upper_panel_center_y"]),
				0.0
			),
			Vector3.RIGHT * side_x, Vector3.UP,
			stencil_size(size, strapped)
		)
	tool.index()
	tool.generate_tangents()
	tool.commit(mesh)
