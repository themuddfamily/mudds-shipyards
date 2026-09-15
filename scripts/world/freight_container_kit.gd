class_name FreightContainerKit
extends RefCounted

## One freight-container finish for the whole station (Phase 10 §3).
##
## ## What this replaces
##
## Until now every freight container on the station was a *box*. Dock 04's seven
## units were a `BoxMesh` in the station's own deck teal drawn through one
## `MultiMeshInstance3D`; the Jovian freight berth's eight tagged cargo units were
## chamfered boxes in the berth's ceramic/orange/steel-blue module palette. The
## Dock 04 re-dress recorded the resulting read honestly: "the containers are
## still untextured blocks in the station's own teal; the lit ID stripes carry
## most of the 'this is freight' signal." Two different sites, two different
## palettes, and in both cases the only thing saying *freight* was a lamp.
##
## ## The finish
##
## A container is not a box, it is a **frame with skins hung on it**, and every
## part of that is readable at gameplay distance without a single new texture:
##
## * **corner castings** — the eight proud cast blocks that take the whole load.
##   They are the only parts flush with the published envelope, which is what
##   makes the rest of the box read as recessed skin rather than as a slab.
## * **top and bottom rails** — four longitudinal rolled sections set
##   `FRAME_INSET` behind the castings, so the castings stand off them.
## * **end frames** — a header, a sill and two corner posts at each end.
## * **corrugated side and front skins** — `_rib_count_for` formed ribs per face,
##   each one a chamfered stock box whose outer face is flush with the envelope
##   and whose inner half is buried in the body core. That is a real formed sheet
##   profile, not a batten glued to a flat wall: the eye reads the alternation of
##   lit rib crown and shaded valley, which is the single strongest "shipping
##   container" cue there is.
## * **a door end** — two leaves recessed `DOOR_RECESS` from the envelope, four
##   full-height locking bars and two cam handles.
## * **a painted operator livery** — `OPERATORS`, three of them, so a yard reads
##   as a yard and not as a warehouse of one company's stock.
## * **a stencilled data plate** — the operator's mark, unit code and route, from
##   `tools/generate_ship_markings.py`'s existing font-free engineering alphabet,
##   on a flat un-ribbed bay in the side skin and on the port door leaf.
##
## ## What it costs, and what it deliberately does not
##
## The whole finish is **one `ArrayMesh` with four surfaces**. It adds no node, no
## light, no collider and no texture that a generator did not already produce
## deterministically:
##
## * `SURFACE_BODY` — core, side ribs and front ribs, operator paint.
## * `SURFACE_CASTING` — castings, rails, end frames, lock bars, cam handles.
## * `SURFACE_DOOR` — the two leaves.
## * `SURFACE_STENCIL` — two quads, four triangles in total, carrying the plate.
##
## Every part is `ShipChamferedStock.box_mesh`, which is the fleet's existing
## chamfered stock recipe: no new mesh family, and the cheap 44-triangle tangent
## chamfer wherever the part's own chamfer width earns it.
##
## ## The envelope is exact
##
## `shell_mesh` returns a mesh whose AABB is exactly `AABB(-size * 0.5, size)`.
## This is not a convenience, it is the contract that lets the finish be applied
## to *already-placed* freight without moving anything: Dock 04's seven authored
## instance transforms, its published landing and approach clearances, the Jovian
## berth's eight `BoxShape3D` colliders and its published cargo-unit tags are all
## sized from the same `size` and none of them moves by a millimetre. The corner
## castings are what reach the six extremes; nothing else touches them.
##
## ## Coplanar safety
##
## Two solids on one plane within `CoplanarSeamAudit.OFFSET_TOLERANCE_M` (3 mm)
## z-fight. Every inset here is chosen against that number, not by eye:
##
## * castings are flush; rails and end frames are `FRAME_INSET` (12 mm) behind
##   them, so no frame member is ever coplanar with a casting.
## * frame members that *do* meet are butted end-into-face, which the audit
##   excludes as back-to-back — two solids in contact cannot flicker, because
##   backface culling removes one of them before the depth test.
## * ribs are flush with the envelope like the castings, but occupy disjoint
##   spans along the face, so the pair has zero overlap area.
## * the stencil plates stand `STENCIL_STANDOFF` (6 mm) proud of the surface they
##   are painted on — twice the tolerance, and still deep inside the rib plane.

const SURFACE_BODY := 0
const SURFACE_CASTING := 1
const SURFACE_DOOR := 2
const SURFACE_STENCIL := 3
const SURFACE_COUNT := 4

const MARKING_DIRECTORY := "res://assets/ships/markings/"

## The three operators whose stock moves through this station.
##
## Colour rules, in order of priority. (1) None of them may be the station's own
## structural teal, because that is the exact defect this pass exists to fix: a
## container painted the colour of the deck it stands on is a block. (2) They
## separate from one another at distance under the same perceptual reading
## `docs/design/FLEET_VISUAL_GRAMMAR.md` §2 applies to the fleet — an oxide red,
## a deep navy and a warm sand are three different hue families, not three
## values of one. (3) They stay clear of the five craft body tones and the five
## craft accents frozen in `tests/fleet_role_differentiation_test.gd`: these are
## muted, low-clearcoat freight paint, so a container behind a parked craft can
## never be mistaken for part of it. The oxide red is deliberately much darker
## and browner than the Jovian's `b32620` accent, and the navy much darker and
## duller than the Zenith's `2f5fbe`.
const OPERATORS: Array[Dictionary] = [
	{
		"id": &"ardent_freight",
		"body_color": Color("8c4430"),
		"marking": "freight-ardent",
	},
	{
		"id": &"meridian_bulk",
		"body_color": Color("2c4a6e"),
		"marking": "freight-meridian",
	},
	{
		"id": &"cinder_run",
		"body_color": Color("9d8154"),
		"marking": "freight-cinder",
	},
]

## Galvanised cast steel. Shared by every operator, at every site: this is the
## part of the finish that makes the family a family.
const CASTING_COLOR := Color("39434a")
const CASTING_METALLIC := 0.74
## Door leaves are the same paint one step down in value, which is what a real
## container does — the leaves are a separate pressing, sprayed apart from the
## body, and they weather differently. Applied as an albedo multiplier so it
## tracks whichever operator livery the caller supplies.
const DOOR_SHADE := 0.76

## Proportions. Everything scales with the unit so a 1.2 m rack crate and a 3.6 m
## yard container are the same object at two sizes rather than two objects.
## Half the crest-to-valley depth of the corrugation, which is also how far the
## painted skin sits behind the published envelope between ribs. `SKIN_MAXIMUM`
## is 0.040 rather than the 0.075 the first pass used, for two reasons that agree
## with each other. It is closer to real formed-sheet proportion — an ISO
## container's corrugation is about 36 mm deep on a 2.44 m box, and 0.075 gave a
## 3 m container a 150 mm trench. And the deeper valley was measurably hollow to
## the chase-camera boom: `tools/camera_intrusion_audit.gd` retracts against drawn
## geometry, so a skin that stands 150 mm behind its own silhouette is 150 mm the
## boom can sink into that the box it replaced did not have.
const SKIN_PROPORTION := 0.014
const SKIN_MINIMUM := 0.016
const SKIN_MAXIMUM := 0.040
const CASTING_PROPORTION := 0.085
const CASTING_MINIMUM := 0.075
const CASTING_MAXIMUM := 0.26
const FRAME_INSET := 0.012
const RAIL_PROPORTION := 0.055
const RAIL_MINIMUM := 0.05
const RAIL_MAXIMUM := 0.16
const RIB_PITCH := 0.42
const RIB_MINIMUM_COUNT := 3
const RIB_MAXIMUM_COUNT := 9
const RIB_DUTY := 0.52
const DOOR_RECESS := 0.02
const DOOR_GAP_PROPORTION := 0.012
const LOCK_BAR_PROPORTION := 0.035
const LOCK_BAR_MINIMUM := 0.032
const LOCK_BAR_MAXIMUM := 0.075
const STENCIL_STANDOFF := 0.006
const STENCIL_ASPECT := 0.5
const STENCIL_LENGTH_PROPORTION := 0.40
const STENCIL_MAXIMUM_LENGTH := 2.0
const STENCIL_MINIMUM_LENGTH := 0.34
const STENCIL_SIDE_HEIGHT_OFFSET := -0.17
const STENCIL_SIDE_LENGTH_OFFSET := 0.13
## How many ribs come out of the `-X` skin to leave the side plate flat steel to
## stand on. One rib's worth of gap is too narrow on a 4 m unit for a legible
## plate; two leaves a bay the plate fits inside without a rib crossing it.
const STENCIL_BAY_RIBS := 2
## The locking bars are the outermost thing on the door end, so this is what
## keeps them inside the published envelope — and more than
## `CoplanarSeamAudit.OFFSET_TOLERANCE_M` clear of the cast corner faces, so the
## bar crowns and the castings are two planes rather than one flickering one.
const LOCK_BAR_STANDOFF := 0.006

## The door is on `+Z` and the stencilled side is `-X`. Callers orient the
## container by placing it, exactly as they already do; no instance is rotated by
## this kit.
## Signed unit pairs, typed so inferred loop variables stay `float`.
const SIGNS: Array[float] = [-1.0, 1.0]

const DOOR_AXIS := Vector3.BACK
const STENCIL_SIDE_AXIS := Vector3.LEFT


## Which operator a unit belongs to, from its authored index. Deterministic and
## stable: re-running the build gives the same yard, and a unit keeps its livery
## across sessions, saves and captures.
static func operator_for_index(index: int) -> Dictionary:
	return OPERATORS[posmod(index, OPERATORS.size())]


static func operator_color(index: int) -> Color:
	return operator_for_index(index)["body_color"] as Color


## The same livery for `MultiMesh.set_instance_color`.
##
## `albedo_color` is an sRGB property the engine converts for the shader;
## per-instance colour is not — it arrives in `COLOR` exactly as written and is
## multiplied into an already-linear albedo. Handing the raw authored value to it
## paints the container in sRGB numbers read as linear, which is how the first
## rendered pass of Dock 04 came back in pastel while the Jovian berth's units,
## which carry the identical values through `albedo_color`, came back in the
## authored oxide red and navy. Converting here is what keeps one livery table
## producing one colour at both sites.
static func operator_instance_color(index: int) -> Color:
	return operator_color(index).srgb_to_linear()


static func operator_marking(index: int) -> String:
	return String(operator_for_index(index)["marking"])


static func marking_texture(marking: String) -> Texture2D:
	return load(MARKING_DIRECTORY + marking + ".svg") as Texture2D


## Operator paint. `vertex_colored` is for the batched case: a
## `MultiMeshInstance3D` can only carry one material, so Dock 04's seven units
## get their livery from `MultiMesh.set_instance_color` multiplied into a white
## body material instead of from seven materials.
static func body_material(
		color: Color, panel_scale: float, vertex_colored: bool = false
	) -> StandardMaterial3D:
	var material := _base_material(Color.WHITE if vertex_colored else color, 0.46)
	StationSurfaceKit.apply_panel_triplanar(
		material, panel_scale, StationSurfaceKit.PanelFinish.PAINTED_METAL
	)
	material.vertex_color_use_as_albedo = vertex_colored
	return material


static func casting_material(panel_scale: float) -> StandardMaterial3D:
	var material := _base_material(CASTING_COLOR, CASTING_METALLIC)
	StationSurfaceKit.apply_panel_triplanar(
		material, panel_scale, StationSurfaceKit.PanelFinish.METAL_TRIM
	)
	return material


static func door_material(
		color: Color, panel_scale: float, vertex_colored: bool = false
	) -> StandardMaterial3D:
	var shade := Color(DOOR_SHADE, DOOR_SHADE, DOOR_SHADE)
	var material := _base_material(shade if vertex_colored else color * shade, 0.50)
	StationSurfaceKit.apply_panel_triplanar(
		material, panel_scale, StationSurfaceKit.PanelFinish.PAINTED_METAL
	)
	material.vertex_color_use_as_albedo = vertex_colored
	return material


## The stencil plate. It carries the printed graphic on UV1 and is deliberately
## *not* triplanar and *not* instance-tinted: a data plate that took the body's
## world-projected panel grain would be a painted box, and one that took the
## body's livery would be unreadable on the dark navy.
static func stencil_material(marking: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = marking_texture(marking)
	material.metallic = 0.10
	material.roughness = 0.58
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.vertex_color_use_as_albedo = false
	return material


## Number of formed ribs across `span` metres of face.
static func rib_count_for(span: float) -> int:
	return clampi(int(round(span / RIB_PITCH)), RIB_MINIMUM_COUNT, RIB_MAXIMUM_COUNT)


static func skin_for(size: Vector3) -> float:
	var shortest := minf(size.x, minf(size.y, size.z))
	return clampf(shortest * SKIN_PROPORTION, SKIN_MINIMUM, SKIN_MAXIMUM)


static func casting_for(size: Vector3) -> Vector3:
	return Vector3(
		clampf(size.x * CASTING_PROPORTION, CASTING_MINIMUM, CASTING_MAXIMUM),
		clampf(size.y * CASTING_PROPORTION, CASTING_MINIMUM, CASTING_MAXIMUM),
		clampf(size.z * CASTING_PROPORTION, CASTING_MINIMUM, CASTING_MAXIMUM)
	)


## The finish itself. One `ArrayMesh`, four surfaces, exact `size` AABB.
##
## `stencilled` is for a caller that wants the shell without its side plate.
##
## `stencil_side` says which long side the plate is painted on, because that is
## the one thing about a container that cannot be decided by the kit: it depends
## entirely on where the player stands. Dock 04's yard is read from the trunk
## walkway inboard of the stacks, so its plates face `-X`; the Jovian berth's
## units are read from the transfer lane outboard of the rack line, so theirs
## face `+X`. Rotating the unit instead would have been the wrong tool — it would
## have swung the door end and the `CargoBand` stripes round with it.
static func shell_mesh(
		size: Vector3, stencilled: bool = true, stencil_side: float = -1.0
	) -> ArrayMesh:
	var stencil_sign := signf(stencil_side) if not is_zero_approx(stencil_side) else -1.0
	var half := size * 0.5
	var skin := skin_for(size)
	var casting := casting_for(size)
	var rail := Vector3(
		clampf(size.x * RAIL_PROPORTION, RAIL_MINIMUM, RAIL_MAXIMUM),
		clampf(size.y * RAIL_PROPORTION, RAIL_MINIMUM, RAIL_MAXIMUM),
		clampf(size.z * RAIL_PROPORTION, RAIL_MINIMUM, RAIL_MAXIMUM)
	)
	var body: Array[Dictionary] = []
	var frame: Array[Dictionary] = []
	var door: Array[Dictionary] = []

	# Body core. Recessed `skin` on every face, so the ribs, the castings and the
	# frame are the only things that reach the published envelope.
	body.append({
		"position": Vector3.ZERO,
		"size": Vector3(
			maxf(size.x - skin * 2.0, skin),
			maxf(size.y - skin * 2.0, skin),
			maxf(size.z - skin * 2.0, skin)
		),
	})

	# Eight corner castings, flush on all three axes. These are the only parts
	# that touch the envelope corners, which is the whole reason the AABB is
	# exact without any part of the skin being a hard slab edge.
	for corner_x in SIGNS:
		for corner_y in SIGNS:
			for corner_z in SIGNS:
				frame.append({
					"position": Vector3(
						corner_x * (half.x - casting.x * 0.5),
						corner_y * (half.y - casting.y * 0.5),
						corner_z * (half.z - casting.z * 0.5)
					),
					"size": casting,
				})

	# Four longitudinal top/bottom rails, set behind the castings.
	var rail_length := maxf(size.z - casting.z * 2.0, rail.z)
	for side_x in SIGNS:
		for side_y in SIGNS:
			frame.append({
				"position": Vector3(
					side_x * (half.x - FRAME_INSET - rail.x * 0.5),
					side_y * (half.y - FRAME_INSET - rail.y * 0.5),
					0.0
				),
				"size": Vector3(rail.x, rail.y, rail_length),
			})

	# End frames: header, sill and two corner posts at each end, also behind the
	# castings. The posts run only between the castings, so their ends butt into
	# cast faces rather than sharing a plane with them.
	var header_width := maxf(size.x - casting.x * 2.0, rail.x)
	var post_height := maxf(size.y - casting.y * 2.0, rail.y)
	for side_z in SIGNS:
		var frame_z := side_z * (half.z - FRAME_INSET - rail.z * 0.5)
		for side_y in SIGNS:
			frame.append({
				"position": Vector3(
					0.0, side_y * (half.y - FRAME_INSET - rail.y * 0.5), frame_z
				),
				"size": Vector3(header_width, rail.y, rail.z),
			})
		for side_x in SIGNS:
			frame.append({
				"position": Vector3(
					side_x * (half.x - FRAME_INSET - rail.x * 0.5), 0.0, frame_z
				),
				"size": Vector3(rail.x, post_height, rail.z),
			})

	# Corrugated side skins. Each rib is flush with the envelope and buried half
	# its depth in the body core, which is what makes the profile a formed sheet
	# rather than a batten laid on a flat wall.
	var rib_span := maxf(size.z - casting.z * 2.0, 0.0)
	var rib_height := maxf(size.y - casting.y * 2.0, rail.y)
	var side_ribs := rib_count_for(rib_span)
	var side_pitch := rib_span / float(side_ribs)
	var side_rib_width := side_pitch * RIB_DUTY
	# The stencil bay. `STENCIL_BAY_RIBS` ribs are left out of the `-X` skin so the
	# plate has flat steel to stand on instead of being sliced by the corrugation
	# it is supposed to sit in front of. Chosen by position rather than by index,
	# so the bay lands in the same place on a 4 m yard container and on a 2.4 m
	# rack crate.
	var bay := side_bay(size)
	var bay_index := int(bay["first_rib"])
	for side_x in SIGNS:
		for rib in side_ribs:
			if is_equal_approx(side_x, stencil_sign) and stencilled \
					and rib >= bay_index and rib < bay_index + STENCIL_BAY_RIBS:
				continue
			body.append({
				"position": Vector3(
					side_x * (half.x - skin),
					0.0,
					-rib_span * 0.5 + (float(rib) + 0.5) * side_pitch
				),
				"size": Vector3(skin * 2.0, rib_height, side_rib_width),
			})

	# Corrugated front skin on the closed `-Z` end. The `+Z` end is the door.
	var front_span := maxf(size.x - casting.x * 2.0, 0.0)
	var front_ribs := rib_count_for(front_span)
	var front_pitch := front_span / float(front_ribs)
	for rib in front_ribs:
		body.append({
			"position": Vector3(
				-front_span * 0.5 + (float(rib) + 0.5) * front_pitch,
				0.0,
				-(half.z - skin)
			),
			"size": Vector3(front_pitch * RIB_DUTY, rib_height, skin * 2.0),
		})

	# Door end: two leaves recessed behind the frame line, four full-height
	# locking bars and two cam handles.
	var leaf_gap := maxf(size.x * DOOR_GAP_PROPORTION, 0.01)
	var leaf_width := maxf((header_width - leaf_gap) * 0.5, leaf_gap)
	var leaf_thickness := maxf(skin * 1.6, 0.02)
	var leaf_z := half.z - DOOR_RECESS - leaf_thickness * 0.5
	for side_x in SIGNS:
		door.append({
			"position": Vector3(
				side_x * (leaf_width + leaf_gap) * 0.5, 0.0, leaf_z
			),
			"size": Vector3(leaf_width, rib_height, leaf_thickness),
		})
	var bar := clampf(size.x * LOCK_BAR_PROPORTION, LOCK_BAR_MINIMUM, LOCK_BAR_MAXIMUM)
	# The bars are the outermost thing on the door end, so their own outer face is
	# what has to stay inside the published envelope. `LOCK_BAR_STANDOFF` holds
	# them clear of the casting faces by more than
	# `CoplanarSeamAudit.OFFSET_TOLERANCE_M`, so the bar crowns and the cast
	# corners are two separate planes rather than one flickering one.
	var bar_z := half.z - LOCK_BAR_STANDOFF - bar * 0.5
	for slot in 4:
		var bar_x := (float(slot) - 1.5) * (leaf_width * 0.5 + leaf_gap * 0.5)
		frame.append({
			"position": Vector3(bar_x, 0.0, bar_z),
			"size": Vector3(bar, maxf(rib_height - bar, bar), bar),
		})
	for side_x in SIGNS:
		frame.append({
			"position": Vector3(
				side_x * (leaf_width * 0.5 + leaf_gap * 0.5),
				-rib_height * 0.12,
				bar_z
			),
			"size": Vector3(bar * 2.6, bar * 1.2, bar * 0.9),
		})

	var mesh := ArrayMesh.new()
	_commit_boxes(mesh, body)
	_commit_boxes(mesh, frame)
	_commit_boxes(mesh, door)
	_commit_stencils(
		mesh, size, skin, rib_height, bay, leaf_z + leaf_thickness * 0.5,
		leaf_width, leaf_gap, bar, stencilled, stencil_sign
	)
	mesh.resource_name = "freight_container_shell"
	return mesh


## The nominal plate proportion for a unit of this size, before it is trimmed to
## the flat bay or to the clear span between the door's locking bars.
static func stencil_plate_size(size: Vector3) -> Vector2:
	var length := clampf(
		size.z * STENCIL_LENGTH_PROPORTION,
		STENCIL_MINIMUM_LENGTH,
		STENCIL_MAXIMUM_LENGTH
	)
	return Vector2(length, length * STENCIL_ASPECT)


## The flat un-ribbed bay left in the `-X` corrugation for the side plate:
## `center` in container-local Z and the usable flat `width` between the two ribs
## that still bracket it. Published so the bay and the plate can never drift
## apart — the same call decides which ribs come out and how wide the plate is.
static func side_bay(size: Vector3) -> Dictionary:
	var casting := casting_for(size)
	var span := maxf(size.z - casting.z * 2.0, 0.0)
	var ribs := rib_count_for(span)
	var pitch := span / float(ribs)
	var rib_width := pitch * RIB_DUTY
	var wanted := size.z * STENCIL_SIDE_LENGTH_OFFSET
	var removed := mini(STENCIL_BAY_RIBS, ribs)
	var first := clampi(
		int(floor((wanted + span * 0.5) / pitch - float(removed - 1) * 0.5)),
		0, maxi(ribs - removed, 0)
	)
	return {
		"first_rib": first,
		"rib_count": removed,
		"center": -span * 0.5 + (float(first) + float(removed) * 0.5) * pitch,
		"width": maxf(float(removed + 1) * pitch - rib_width, pitch * 0.5),
	}


## The side plate's drawn size, trimmed to the flat bay so no rib crosses it.
static func stencil_side_size(size: Vector3, rib_height: float) -> Vector2:
	var bay := side_bay(size)
	var plate := stencil_plate_size(size)
	var width := minf(plate.x, float(bay["width"]) * 0.92)
	return Vector2(width, minf(width * STENCIL_ASPECT, rib_height * 0.62))


static func _commit_boxes(mesh: ArrayMesh, boxes: Array[Dictionary]) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry in boxes:
		var size := entry["size"] as Vector3
		var part := ShipChamferedStock.box_mesh(
			size, ShipChamferedStock.fleet_box_bevel(size)
		)
		var offset := entry["position"] as Vector3
		var arrays := part.surface_get_arrays(0)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		# The two stock builders differ here: the chamfered-box path commits an
		# unindexed surface while the rolled-edge path indexes its. Walk whichever
		# one the part actually carries so both recipes fuse identically.
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		else:
			indices.resize(vertices.size())
			for position in vertices.size():
				indices[position] = position
		for index in indices:
			tool.set_normal(normals[index])
			tool.set_uv(uvs[index])
			tool.add_vertex(vertices[index] + offset)
	tool.index()
	tool.generate_tangents()
	tool.commit(mesh)


## Two quads. The side plate lies in the flat bay left in the corrugation; the
## door plate lies on the port leaf. Both stand `STENCIL_STANDOFF` proud of the
## steel they are painted on — twice `CoplanarSeamAudit.OFFSET_TOLERANCE_M` — and
## both stay well inside the rib and casting planes, so neither can z-fight and
## neither moves the envelope.
static func _commit_stencils(
		mesh: ArrayMesh,
		size: Vector3,
		skin: float,
		rib_height: float,
		bay: Dictionary,
		leaf_face_z: float,
		leaf_width: float,
		leaf_gap: float,
		bar: float,
		stencilled: bool,
		stencil_sign: float
	) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if stencilled:
		_emit_plate(
			tool,
			Vector3(
				stencil_sign * ((size.x * 0.5 - skin) + STENCIL_STANDOFF),
				size.y * STENCIL_SIDE_HEIGHT_OFFSET,
				float(bay["center"])
			),
			Vector3.RIGHT * stencil_sign, Vector3.UP,
			stencil_side_size(size, rib_height)
		)
	# The door plate sits in the clear span between the port leaf's two locking
	# bars rather than under them, so the bars frame it instead of slicing it.
	var bar_pitch := (leaf_width + leaf_gap) * 0.5
	var door_width := minf(
		stencil_plate_size(size).x * 0.7, maxf(bar_pitch - bar * 1.6, leaf_gap)
	)
	var door_plate := Vector2(
		door_width, minf(door_width * STENCIL_ASPECT, rib_height * 0.34)
	)
	_emit_plate(
		tool,
		Vector3(
			-(leaf_width + leaf_gap) * 0.5,
			rib_height * 0.14,
			leaf_face_z + STENCIL_STANDOFF
		),
		Vector3.BACK, Vector3.UP, door_plate
	)
	tool.index()
	tool.generate_tangents()
	tool.commit(mesh)


static func _emit_plate(
		tool: SurfaceTool, origin: Vector3, outward: Vector3, up: Vector3,
		plate: Vector2
	) -> void:
	var normal := outward.normalized()
	var upright := (up - normal * up.dot(normal)).normalized()
	var across := upright.cross(normal).normalized()
	var corners := [
		origin - across * plate.x * 0.5 + upright * plate.y * 0.5,
		origin + across * plate.x * 0.5 + upright * plate.y * 0.5,
		origin + across * plate.x * 0.5 - upright * plate.y * 0.5,
		origin - across * plate.x * 0.5 - upright * plate.y * 0.5,
	]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		# Emission order is the front-face winding. Godot's front face runs
		# clockwise seen from outside, so `(b - a) x (c - a)` must point *against*
		# the outward normal; measuring it here rather than hand-ordering the
		# corners is the same guard `ShipChamferedStock._emit_triangle` uses and
		# is what `tests/station_surface_winding_test.gd` calibrates against.
		var order: Array = triangle
		var geometric := (
			(corners[triangle[1]] as Vector3) - (corners[triangle[0]] as Vector3)
		).cross(
			(corners[triangle[2]] as Vector3) - (corners[triangle[0]] as Vector3)
		)
		if geometric.dot(normal) > 0.0:
			order = [triangle[0], triangle[2], triangle[1]]
		for corner in order:
			tool.set_normal(normal)
			tool.set_uv(uvs[corner])
			tool.add_vertex(corners[corner] as Vector3)


static func _base_material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.44
	return material
