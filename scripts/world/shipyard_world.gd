class_name ShipyardWorld
extends Node3D

## Procedurally assembled vertical-slice environment for Keth Shipyards.
##
## The slice uses an exposed, source-informed dock lattice assembled from
## original geometry. The flyable berth opens toward negative Z; all spawn
## markers and the launch signal use that same gameplay convention.

signal target_destroyed(target_id: StringName, position: Vector3)

const WORLD_LAYER := PhysicsLayers.WORLD
const TARGET_LAYER := PhysicsLayers.TARGET
const RAYCAST_MASK := WORLD_LAYER | TARGET_LAYER
const CENTRAL_BERTH_ID: StringName = &"central_berth"
const ARROW_RECON_BERTH_ID: StringName = &"arrow_recon_berth"
const JOVIAN_FREIGHT_BERTH_ID: StringName = &"jovian_freight_berth"
const ZENITH_FLEET_DOCK_BERTH_ID: StringName = &"zenith_fleet_dock_berth"
const HALYARD_FLEET_DOCK_BERTH_ID: StringName = &"halyard_fleet_dock_berth"
const BULWARK_FLEET_DOCK_BERTH_ID: StringName = &"bulwark_fleet_dock_berth"
const COMPONENT_DAMAGE_AUDIO_BINDING := preload("res://scripts/audio/component_damage_audio_binding.gd")
const FLEET_EXPANSION_BINDING := preload("res://scripts/world/fleet_expansion_production_binding.gd")
const STATION_SOLAR_READABILITY_SCRIPT := preload(
	"res://scripts/world/station_solar_readability_presentation.gd"
)
const STATION_DEFENSE_CONTENT_SCENE := preload("res://scenes/activities/station_defense_encounter.tscn")
const STATION_DEFENSE_ACTIVITY_BOARD_SCRIPT := preload("res://scripts/activities/station_defense_activity_board.gd")
const HEAVY_BREACH_ACTIVITY_BOARD_SCRIPT := preload("res://scripts/activities/heavy_breach_activity_board.gd")
const STATION_DEFENSE_ACTIVITY_BOARD_TRANSFORM := Transform3D(
	Basis.IDENTITY, Vector3(12.0, 1.0, -26.0)
)
const HEAVY_BREACH_ACTIVITY_BOARD_TRANSFORM := Transform3D(
	Basis.IDENTITY, Vector3(17.0, 1.0, -26.0)
)
const HEAVY_BREACH_PROTECTED_OBJECTIVE_TRANSFORM := Transform3D(
	Basis.IDENTITY, Vector3(24.0, 1.0, -26.0)
)
const SHIP_BERTH_FEEDBACK_SCHEMA_VERSION := 2
const SHIP_BERTH_FEEDBACK_MATERIAL_COUNT := 4
const SHIP_BERTH_FEEDBACK_BERTH_IDS: Array[StringName] = [
	CENTRAL_BERTH_ID,
	ARROW_RECON_BERTH_ID,
	JOVIAN_FREIGHT_BERTH_ID,
	ZENITH_FLEET_DOCK_BERTH_ID,
	HALYARD_FLEET_DOCK_BERTH_ID,
	BULWARK_FLEET_DOCK_BERTH_ID,
]
const SHIP_BERTH_FEEDBACK_MATERIAL_IDS: Array[StringName] = [
	&"dim",
	&"cyan",
	&"amber",
	&"secured",
]
## Contact bias between a seated berth cue plate and the deck it marks.
##
## The four berth cues hovered over their decks — the player's own reported
## category, "random objects floating in the air". Measured by raying down onto
## **drawn triangles**, per plate, over the whole cue rectangle, because the two
## cheap answers both lie here: the berth rings are tori whose bounding box covers
## their own hole, and the central berth's drawn deck is an authored Blender shell
## sitting 0.115 m above the collision box under it, so a World-layer ray reports
## the wrong surface by exactly that much.
##
## Measured before, and the deck each cue actually reads against:
##
##   berth      plate underside   deck under the cue                    hover
##   Zenith            4.380      SlabInset01        4.240 (83.8%)      0.140
##   Jovian            0.590      ApronDeck01-04     0.380 (57.7%)      0.210
##   central           0.330      authored shell     0.095 (73.5%)      0.235
##   Arrow             0.360      PortBerthNode     -0.020 (83.2%)      0.380
##
## The Zenith reads worst despite the smallest number, and that is the whole
## reason this was reported there: the other three berths carry a raised pad or
## dock ring whose top happens to stand at roughly cue height, so the eye has
## something at that height for the plate to belong to. Dock 01 has no ring, so
## there the plates read as loose blocks over a bare slab.
##
## What changed is only how high the cue sits. `RENDER_MIN_Y`/`RENDER_MAX_Y`, the
## plate sizes, the four-material budget, the colourblind-safe lightness ladder
## and the non-colour shape channel are untouched — those are frozen for
## accessibility and are owned elsewhere. Each berth's `local_transform` drops by
## its own measured hover less this bias, so every cue's underside now sits
## exactly this far above the drawn deck:
##
##   central  -0.960 -> -1.185   Arrow  -0.930 -> -1.300
##   Jovian   -1.180 -> -1.380   Zenith -1.040 -> -1.170
##
## 0.010 m rather than 0: coincident faces z-fight, and this is the same seat the
## thirteen floating structural pieces took in the 2026-08-16 pass. Deck dressing
## that stands proud of the deck — pad rings, grip strips, centrelines — now
## crosses over the cue instead of under it, which is what a painted deck marking
## running past a raised rib actually looks like.
const BERTH_CUE_SEAT_HEIGHT := 0.010
const SHIP_BERTH_FEEDBACK_SPECS := {
	CENTRAL_BERTH_ID: {
		"berth_path": NodePath("CentralBerth"),
		"berth_local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -10.0)),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(12.0, 3.8, 17.0),
		"assist_capture_center": Vector3(0.0, 8.0, -22.0),
		"assist_capture_half_extents": Vector3(30.0, 16.0, 45.0),
		"assist_capture_maximum_speed": 35.0,
		"assist_maximum_tilt_degrees": 75.0,
		"compatibility_tags": ["small_craft"],
		"feedback_path": NodePath("CentralBerth/BerthFeedback"),
		# Re-frozen -0.96 -> -1.185. See BERTH_CUE_SEAT_HEIGHT.
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.185, 0.0)),
		"cue_half_width": 8.2,
		"cue_half_length": 12.5,
	},
	ARROW_RECON_BERTH_ID: {
		"berth_path": NodePath("ArrowReconBerth"),
		"berth_local_transform": Transform3D(
			Basis(Vector3.UP, deg_to_rad(90.0)),
			Vector3(-43.0, 1.15, 15.5)
		),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(8.0, 4.5, 9.0),
		"assist_capture_center": Vector3(0.0, 8.0, -15.0),
		"assist_capture_half_extents": Vector3(22.0, 14.0, 32.0),
		"assist_capture_maximum_speed": 32.0,
		"assist_maximum_tilt_degrees": 75.0,
		# The port branch rails make this physical envelope Arrow-specific.
		# ShipBerth intentionally uses any-tag matching, so advertising the generic
		# small-craft tag here would falsely admit the wider Torrent interceptor.
		"compatibility_tags": ["recon"],
		"feedback_path": NodePath("ArrowReconBerth/BerthFeedback"),
		# Re-frozen -0.93 -> -1.30. See BERTH_CUE_SEAT_HEIGHT.
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.30, 0.0)),
		"cue_half_width": 6.3,
		"cue_half_length": 7.2,
	},
	JOVIAN_FREIGHT_BERTH_ID: {
		"berth_path": NodePath("JovianFreightShipBerth"),
		"berth_local_transform": Transform3D(
			Basis(Vector3.UP, deg_to_rad(180.0)),
			Vector3(-53.0, 1.63, 57.3)
		),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(14.0, 8.0, 21.5),
		"assist_capture_center": Vector3(0.0, 12.0, -26.0),
		"assist_capture_half_extents": Vector3(36.0, 20.0, 52.0),
		"assist_capture_maximum_speed": 24.0,
		"assist_maximum_tilt_degrees": 75.0,
		"compatibility_tags": [
			"medium_craft",
			"freighter",
			"cargo",
			"walkable_interior",
			"light_freighter",
			"freight",
		],
		"feedback_path": NodePath("JovianFreightShipBerth/BerthFeedback"),
		# Re-frozen -1.18 -> -1.38. See BERTH_CUE_SEAT_HEIGHT.
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.38, 0.0)),
		"cue_half_width": 11.6,
		"cue_half_length": 16.5,
	},
	ZENITH_FLEET_DOCK_BERTH_ID: {
		"berth_path": NodePath("ZenithFleetDockBerth"),
		"berth_local_transform": Transform3D(
			Basis.IDENTITY,
			Vector3(22.0, 5.28, 53.3)
		),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(8.4, 4.6, 7.4),
		"assist_capture_center": Vector3(0.0, 10.0, -18.0),
		"assist_capture_half_extents": Vector3(20.0, 14.0, 30.0),
		"assist_capture_maximum_speed": 34.0,
		"assist_maximum_tilt_degrees": 75.0,
		"compatibility_tags": ["zenith_b7"],
		"feedback_path": NodePath("ZenithFleetDockBerth/BerthFeedback"),
		# Re-frozen -1.04 -> -1.17. See BERTH_CUE_SEAT_HEIGHT.
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.17, 0.0)),
		"cue_half_width": 5.0,
		"cue_half_length": 4.8,
	},
	# Fleet Dock 02. The comb already built this slab and its marker and left it
	# deliberately empty; promoting it to a live berth follows Dock 01's pattern
	# exactly — the marker keeps no berth authority and the berth is owned
	# directly by the world, 0.93 m above it.
	#
	# HALYARD-DECK-001. The line that used to stand here — "the Halyard's four
	# feet sit inside the 12 m slab while its bow collar and tail yoke overhang,
	# so the strict landing volume is longer than the slab" — recorded the defect
	# as if it were a design. It is not. The craft is 28.35 m long on a 12.0 m
	# slab: 7.85 m of nose and 8.50 m of tail stood over open space, only 42% of
	# the footprint was on structure, and two of four footprint corners had
	# nothing under them at all. The apron below (`HALYARD_APRON_*`, built in
	# `_build_architecture`) is the world's answer; the comb keeps its own
	# three-tooth rhythm, its own footprint and its own dressing rule untouched.
	HALYARD_FLEET_DOCK_BERTH_ID: {
		"berth_path": NodePath("HalyardFleetDockBerth"),
		"berth_local_transform": Transform3D(
			Basis.IDENTITY,
			Vector3(37.0, 5.28, 53.3)
		),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(7.0, 6.5, 16.5),
		"assist_capture_center": Vector3(0.0, 11.0, -24.0),
		"assist_capture_half_extents": Vector3(24.0, 16.0, 44.0),
		"assist_capture_maximum_speed": 22.0,
		"assist_maximum_tilt_degrees": 75.0,
		# Class-specific, like Dock 01. ShipBerth uses any-tag matching, so
		# advertising `medium_craft` here would also admit the Jovian, whose
		# 18.55 m span does not fit between this dock and its neighbours.
		"compatibility_tags": ["crew_transport"],
		"feedback_path": NodePath("HalyardFleetDockBerth/BerthFeedback"),
		# Re-frozen -1.04 -> -1.21. See BERTH_CUE_SEAT_HEIGHT. This berth was the
		# one Dock 01's re-freeze missed: the Zenith beside it went -1.04 -> -1.17
		# to seat on the comb's 0.040 m grip inset, and this cue kept the old value
		# over the identical y = 4.2 deck, so its plates floated 0.215 m. Seated on
		# bare deck rather than on the inset, because the widened pad puts all four
		# boundary strips outside the inset's 10.4 m square: 4.2 + 0.010 = 4.210 is
		# the plate underside, so the offset is 4.210 - 0.14 - 5.28 = -1.21.
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.21, 0.0)),
		# Re-cut for the widened pad. The old 5.4 x 6.2 rectangle was not merely
		# small, it was hanging off both ends of the slab it marked: its forward
		# strips spanned z = 47.20 … 47.36 against a deck edge at 47.3 and its aft
		# strips 59.24 … 59.40 against an edge at 59.3, which is why only 21 of 45
		# cue samples had anything drawn beneath them. The new rectangle sits at
		# least 1.30 m inside every edge of the pad it marks, as the Arrow's does:
		# 4.7 against a half-width of 6.0, and 11.3 against the 12.6 m from the
		# berth origin aft to the comb trunk (the forward apron is deeper still).
		"cue_half_width": 4.7,
		"cue_half_length": 11.3,
	},
	# Fleet Dock 03. This is the first original-modern Bulwark assignment: the
	# berth owns the physical landing/recovery contract while the comb marker
	# remains presentation-only. No historical class-to-berth mapping is implied.
	BULWARK_FLEET_DOCK_BERTH_ID: {
		"berth_path": NodePath("BulwarkFleetDockBerth"),
		"berth_local_transform": Transform3D(
			Basis.IDENTITY,
			Vector3(52.0, 5.28, 53.3)
		),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(6.0, 4.5, 6.4),
		"assist_capture_center": Vector3(0.0, 10.0, -18.0),
		"assist_capture_half_extents": Vector3(20.0, 14.0, 30.0),
		"assist_capture_maximum_speed": 26.0,
		"assist_maximum_tilt_degrees": 75.0,
		"compatibility_tags": ["bulwark_gunship"],
		"feedback_path": NodePath("BulwarkFleetDockBerth/BerthFeedback"),
		# Fleet Dock 03 is the comb's raised deck: its top is 2.4 m above Dock 02.
		# Seat this presentation cue on that surface without moving the berth,
		# landing volume, or ship authority owned by ShipBerth.
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.19, 0.0)),
		"cue_half_width": 4.7,
		"cue_half_length": 4.7,
	},
}
## PORT-DECK-001 / RUNWAY-SEAM-001 measured geometry constants.
##
## `AUTHORED_CENTRAL_BERTH_EDGE_Z` is the +Z extent of the authored central-berth
## shell (`edge_fascia__EdgeIvory` reaches z = 7.75; its deck panels reach 7.55).
## Every generic lattice deck stops at or beyond this plane so no station surface
## shares a volume with the authored runway plate.
const AUTHORED_CENTRAL_BERTH_EDGE_Z := 7.75
## Drawn top faces the hero cell's ground-support line is seated against.
##
## These are two different planes and confusing them is how the berth cues came
## to hover. `AUTHORED_CENTRAL_BERTH_DECK_TOP` is the top face of the authored
## Blender shell, which is what the eye reads as the floor inside the berth and
## what `CentralBerthHeroPresentation.EXPECTED_MAXIMUM.y` publishes.
## `LATTICE_DECK_TOP` is the top of the generic procedural lattice decks
## (`CentralJunction`, branch arms, aft spine: centre -0.62, 1.2 m thick), which
## is also where their collision boxes end. The shell stands 0.115 m proud of the
## `HeroBerthNode` collision beneath it, so anything seated by raycast against
## the World layer inside the berth lands 0.115 m low.
const AUTHORED_CENTRAL_BERTH_DECK_TOP := 0.095
const LATTICE_DECK_TOP := -0.02
## Bearing a seated ground-support piece takes into the surface under it.
##
## Not zero: coincident faces z-fight. This is the same 0.010 m the freight
## berth's eight cargo units and the thirteen structural pieces re-seated by the
## 2026-08-16 sweep took, so the whole station now uses one figure.
const SERVICE_LINE_SEAT_BEARING := 0.010
## Hue of the dock-mast foot practicals.
##
## The established idiom is that a practical carries the hue of the lens it sits
## beside, so the spill identifies its source. Each mast already carries a
## `KETH_CYAN` guide lamp on its cap; this is that cyan pulled most of the way to
## white, because a foot lamp lighting bare structure at 1 m reads as a working
## floodlight rather than as a signal.
const MAST_FOOT_PRACTICAL_COLOR := Color("bfeaf0")
## Fixture practicals in the hero cell's ground-support line: one at each of the
## three dock mast feet, plus the readiness board hood, the parts-rack strip and
## the work stand's clamp lamp.
const SERVICE_LINE_PRACTICAL_COUNT := 6
## Renderer roster for the four anonymous black stock blocks in the parts rack.
##
## These are visual shelf fill only: the six independently named, colliding
## `PartsBin` bodies retain the rack's physical and state-readable roster, while
## the two ivory stock blocks retain their ordinary node paths. Batching only
## this black family removes three submissions without moving or merging any
## berth, route, evidence, lifecycle, collision or fixture authority.
const SERVICE_LINE_BLACK_BIN_STOCK_COPY_COUNT := 4
const SERVICE_LINE_RENDER_DESCENDANT_COUNT := 224
const SERVICE_LINE_RENDER_MESH_INSTANCE_COUNT := 96
const SERVICE_LINE_RENDER_MULTIMESH_BATCH_COUNT := 1
const SERVICE_LINE_RENDER_DRAWN_COPY_COUNT := 100
const SERVICE_LINE_RENDER_SUBMISSION_COUNT := 97
## Rounded plan profile for the access stand's main boarding platform.
##
## The old 1.8 x 2.2 m shallow `_box` had only a 0.022 m bevel because its
## 0.10 m thickness drove the shared proportional rule. At walking distance it
## therefore read as an unmodified rectangle. This radius is large enough to
## author the footprint visibly while keeping the exact old AABB and collider.
const ACCESS_STAND_PLATFORM_SIZE := Vector3(1.80, 0.10, 2.20)
const ACCESS_STAND_PLATFORM_CORNER_RADIUS := 0.35
const ACCESS_STAND_PLATFORM_CURVE_SEGMENTS := 4
## Local renderer contract for ModernFleetRegistry's four roof-column visuals.
##
## The four `StaticBody3D` columns and their box colliders stay independent and
## keep the pod's physical/path roster. Only their identical child render meshes
## are drawn through one sibling batch, retaining the cached chamfered mesh and
## the shared steel-blue material while removing three structural submissions.
const MODERN_REGISTRY_COLUMN_SIZE := Vector3(0.34, 5.4, 0.34)
const MODERN_REGISTRY_COLUMN_COPY_COUNT := 4
const MODERN_REGISTRY_RENDER_DESCENDANT_COUNT := 62
const MODERN_REGISTRY_RENDER_MESH_INSTANCE_COUNT := 35
const MODERN_REGISTRY_RENDER_MULTIMESH_BATCH_COUNT := 1
const MODERN_REGISTRY_RENDER_DRAWN_COPY_COUNT := 39
const MODERN_REGISTRY_RENDER_SUBMISSION_COUNT := 36
const MODERN_REGISTRY_PHYSICS_BODY_COUNT := 12
const MODERN_REGISTRY_COLLISION_SHAPE_COUNT := 12
const MODERN_REGISTRY_LIGHT_COUNT := 2
## Spawn-facing identity header for the modern regeneration/registry deck. Its
## previous 92 mm proportional bevel was imperceptible across the branch-arm
## approach; a half-metre capsule radius gives the twelve-metre fascia a real
## authored silhouette without moving its sign seat, collider or roof lap.
const MODERN_REGISTRY_HEADER_SIZE := Vector3(12.0, 1.0, 0.42)
const MODERN_REGISTRY_HEADER_END_RADIUS := 0.5
const MODERN_REGISTRY_HEADER_CURVE_SEGMENTS := 8
## Port berth node, widened from 12.0 m so the 12.2 m Arrow no longer overhangs
## the pad it is parked on. Its centre is unchanged, so berth transforms, the
## landing envelope and the cue strips all keep their published coordinates.
const PORT_BERTH_NODE_OUTER_X := -43.0
const PORT_BERTH_NODE_HALF_WIDTH := 8.4

## HALYARD-DECK-001 measured geometry. All of it is world space, because the
## surfaces it has to meet belong to three different owners.
##
## Fleet Dock 02's slab is `FleetDockComb`'s `DockSlab02`, a 12 x 12 m tooth
## whose top plane is y = 4.2 and which spans x = 31.0 … 43.0, z = 47.3 … 59.3.
## The parked Halyard's collision footprint is 9.6 x 28.35 m at x = 32.2 … 41.8,
## z = 39.45 … 67.8. Laterally that is fine — the cabin is only 5.44 m wide, so
## each flank already has a 3.28 m lane. Along the craft it is not: 16.35 m of a
## 28.35 m transport stood over open space.
##
## The apron is built here rather than in the comb for three reasons, all of them
## structural rather than stylistic. The craft is longer than the comb module is
## wide (its tail is over the trunk and its nose is 7.85 m outside the module's
## declared `FOOTPRINT_MAX`), so a slab that supported it would have to break the
## published integration envelope. Stretching one tooth to 34 m would also destroy
## the repeated three-tooth rhythm that is this module's actual evidence claim
## (OE-B2-COMB). And the comb owns no berth authority at all by design, while this
## world already owns `halyard_fleet_dock_berth`: a berth apron is berth
## infrastructure. `FleetDockCombConnector` is the existing precedent for the
## world building walkable structure that meets the comb's plane.
##
## Every piece butts its neighbour exactly and none overlaps one, so no two decks
## share the y = 4.2 plane — the coplanar-deck defect the Arrow pass recorded.
const HALYARD_APRON_DECK_TOP := 4.2
const HALYARD_APRON_DECK_THICKNESS := 0.6
## The pad's lateral extent is DockSlab02's, unchanged. Widening it would eat the
## 3 m voids at x = 28 … 31 and 43 … 46 that `FleetDockComb` publishes as genuine
## negative space (samples at x = 29.5 and 44.5), and it does not need widening:
## the craft's walls stand at x = 34.28 and 39.72.
const HALYARD_APRON_MIN_X := 31.0
const HALYARD_APRON_MAX_X := 43.0
## `FleetDockComb.DockSlab02`'s own z extent, restated in world space. The module
## sits at (12.0, 4.2, 68.3) rotated a quarter turn about +Y, so its local +X runs
## along world -Z: the slab's local x = 9.0 … 21.0 is world z = 47.3 … 59.3. The
## apron meets these two planes exactly and crosses neither.
const FLEET_DOCK_SLAB_02_MIN_Z := 47.3
const FLEET_DOCK_SLAB_02_MAX_Z := 59.3
## Forward apron, from the pad's own forward edge out past the bow. 36.3 leaves
## 3.15 m of clear deck ahead of the bow collar at z = 39.45, which is the Arrow's
## 1.95 m nose apron scaled to a craft two and a half times as long.
const HALYARD_APRON_NOSE_MIN_Z := 36.3
## Aft apron, from the pad's aft edge to the comb trunk's near face. The craft's
## tail already reaches z = 67.8 and lands on the trunk; this closes the 6.6 m
## gap between the two, which until now was crossed only by the 3.6 m `Rung02`.
## Closing it is what turns two dead ends into one loop.
const HALYARD_APRON_TAIL_MAX_Z := 65.9
## `FleetDockComb`'s `Rung02` occupies x = 35.2 … 38.8 of that gap already. The
## aft apron is therefore two wings that butt it, not one slab over it.
const HALYARD_APRON_RUNG_MIN_X := 35.2
const HALYARD_APRON_RUNG_MAX_X := 38.8
## The world-owned bridge into Fleet Dock Comb keeps this exact authored span.
## Its old shared rounded box used a 0.128 m bevel, driven by the 0.64 m deck
## thickness, so the twelve-metre threshold still read as a rectangular slab.
## A broad plan radius makes the gateway visible during normal traversal while
## leaving the full legacy collider and route-support envelope unchanged.
const FLEET_DOCK_CONNECTOR_DECK_SIZE := Vector3(12.5, 0.64, 3.6)
const FLEET_DOCK_CONNECTOR_CORNER_RADIUS := 0.72
const FLEET_DOCK_CONNECTOR_CURVE_SEGMENTS := 4
## Habitat's world-facing pressure facade keeps its component-owned body,
## collider, material, sign and door. The world replaces only this lintel's
## shallow 108-triangle box render mesh with a 72-triangle capsule silhouette.
const HABITAT_ENTRY_HEADER_SIZE := Vector3(4.2, 0.72, 0.48)
const HABITAT_ENTRY_HEADER_END_RADIUS := 0.36
const HABITAT_ENTRY_HEADER_CURVE_SEGMENTS := 8

const CENTRAL_HERO_SCHEMA_VERSION := 2
const OPERATIONAL_LATTICE_SCHEMA_VERSION := 1
const SPACE_BACKDROP_SCHEMA_VERSION := 1
const SPACE_BACKDROP_MODULE_ID: StringName = &"source-bounded-space-backdrop"
const SPACE_BACKDROP_STAR_SEED := 19780704
const SPACE_BACKDROP_STAR_COUNT := 2600
const SPACE_BACKDROP_STAR_RADIUS_MIN := 1450.0
const SPACE_BACKDROP_STAR_RADIUS_MAX := 1650.0
const SPACE_BACKDROP_NEBULA_COVER_STRENGTH := 0.08
const SPACE_BACKDROP_BODY_MESH_RADIUS := 1.0
const SPACE_BACKDROP_BODY_MESH_RADIAL_SEGMENTS := 24
const SPACE_BACKDROP_BODY_MESH_RINGS := 12
const SPACE_BACKDROP_BODY_MESH_FAMILY_ID: StringName = &"space-backdrop-celestial-bodies"
const SPACE_BACKDROP_BODY_SPECS := {
	&"CelestialGreenBody": {
		"position": Vector3(-310.0, 100.0, -890.0),
		"radius": 95.0,
		"palette_role": &"green",
		"color": Color("5a9b58"),
	},
	&"CelestialTanBody": {
		"position": Vector3(250.0, -120.0, -1040.0),
		"radius": 110.0,
		"palette_role": &"tan_cream",
		"color": Color("c7b887"),
	},
	&"CelestialGreyBody": {
		"position": Vector3(70.0, 230.0, -1250.0),
		"radius": 85.0,
		"palette_role": &"grey",
		"color": Color("86878c"),
	},
	&"CelestialOrangeBody": {
		"position": Vector3(-500.0, -160.0, -1150.0),
		"radius": 75.0,
		"palette_role": &"orange",
		"color": Color("d57635"),
	},
}
const CENTRAL_HERO_MODULE_ID: StringName = &"central-berth-hero-cell"
const CENTRAL_HERO_SHIP_ID: StringName = &"torrent_provisional"
const CENTRAL_HERO_EVIDENCE_STATUS: StringName = &"creator_roster_supported_modern_interpretation"
const OPERATIONAL_LATTICE_EVIDENCE_STATUS: StringName = &"modern_interpretation"
## Re-frozen from 4 by the station-life pass: the four original fixed-rail roles
## plus one cargo transfer line, one crew work post, one skywatch post and one
## wayfinding pylon.
##
## Re-frozen again from 8 by the long-cargo pass, which added two 21.6 m transfer
## runs to the yard — one down the port branch and one down the starboard branch.
## The roster is no longer one placement per profile and is not meant to be; the
## exact per-profile counts live in
## `StationOperationsActivity.RECOMMENDED_PRODUCTION_ROSTER_PROFILE_COUNTS`, which
## keeps the equality exact rather than widening it.
##
## All ten activity subtrees remain presentation-only and collision-free. The
## solid parts declared by seven placements — the three cargo lines' crate stacks,
## gantry posts, rail stops and control pedestals, plus the fixed columns and
## service-arm pedestals at Central, Aft and Freight — are given matching
## World-layer collision by `_build_station_activity_collision()` in a sibling
## group. Re-frozen after the tow-tractor report: 3 -> 7 bodies and 39 -> 63
## shapes. The twenty-four additions are four FULL gantry columns plus two fixed
## FULL pedestal drums, four GANTRY columns, two SERVICE_ARM pedestal drums and
## twelve fixed Aft crew-workpost volumes on the tractor-reachable upper deck.
const EXPECTED_STATION_ACTIVITY_COUNT := 10
const EXPECTED_STATION_ACTIVITY_COLLISION_BODY_COUNT := 7
const EXPECTED_STATION_ACTIVITY_COLLISION_SHAPE_COUNT := 63
const EXPECTED_STATION_ACTIVITY_COLLISION_BOX_COUNT := 55
const EXPECTED_STATION_ACTIVITY_COLLISION_CYLINDER_COUNT := 8
const EXPECTED_STATION_AMBIENCE_COUNT := 4
const EXPECTED_STATION_DRESSING_COUNT := 4
const STATION_ACTIVITY_SPECS := {
	&"CentralTowServiceActivity": {"path": NodePath("OperationalLattice/Activities/CentralTowServiceActivity"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(6.8, 0.0, 14.0)), "profile": &"full", "seed": 1103},
	&"AftOperationsActivity": {"path": NodePath("OperationalLattice/Activities/AftOperationsActivity"), "transform": Transform3D(Basis(Vector3.UP, PI), Vector3(5.8, 4.99, 61.2)), "profile": &"service_arm", "seed": 2207},
	&"HabitatServicePatrol": {"path": NodePath("OperationalLattice/Activities/HabitatServicePatrol"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(59.15, 4.88, 15.5)), "profile": &"drone_patrol", "seed": 3301},
	&"FreightApproachGantry": {"path": NodePath("OperationalLattice/Activities/FreightApproachGantry"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-53.0, 0.38, 29.7)), "profile": &"gantry", "seed": 4409},
	# Station-life placements. Each sits on a support body an existing sibling
	# already proved walkable or roofed, keeps at least 12 m from every other
	# activity root, and clears every berth landing volume. Activity subtrees own
	# no collision; selected profiles declare fixed hard volumes which this world
	# realises as lifecycle-matched sibling bodies under `ActivityCollision`.
	# Re-sited by the long-cargo pass, and this is the "open the space up" half of
	# that request rather than a redesign. The line used to run along world Z with
	# its far end buried in `JunctionPortalPost` — a solid 1.1 x 1.2 m gateway leg
	# standing from y = 0 to 6.5 inside the published envelope, with `RailBeam` and
	# `RailStop` passing straight through it. Nothing caught that: the roster audit
	# is a budget count, the only spatial test is against berth landing volumes,
	# and the four mount-foot raycasts straddled the leg without touching it. The
	# line now runs along world X across the open middle of the same deck: 1.45 m
	# clear of the portal leg, 0.44 m clear of the port dock mast, 2.45 m from the
	# deck's +Z edge, and 4.25 m from the player spawn instead of 2.15 m. It is
	# still the first thing in front of you when you turn around at spawn, and the
	# whole 8.6 m run now reads broadside instead of receding behind a column.
	&"CentralCargoTransferLine": {"path": NodePath("OperationalLattice/Activities/CentralCargoTransferLine"), "transform": Transform3D(Basis.IDENTITY, Vector3(-6.0, 0.0, 17.9)), "profile": &"cargo_line", "seed": 5507},
	# The two long runs. Each works the full length of a branch arm, moving
	# containers between an outer berth and the hub, and each stands between the
	# branch guard rails leaving a 2.8 m walking lane on the -Z side. Verified
	# against the built world rather than by reading coordinates: zero overlaps
	# with any station mesh, every envelope corner supported by deck, and 0.70 m
	# and 7.90 m of clearance from the nearest berth landing volume.
	&"PortBranchCargoLine": {"path": NodePath("OperationalLattice/Activities/PortBranchCargoLine"), "transform": Transform3D(Basis.IDENTITY, Vector3(-22.0, 0.0, 16.75)), "profile": &"cargo_line_long", "seed": 9931},
	&"StarboardBranchCargoLine": {"path": NodePath("OperationalLattice/Activities/StarboardBranchCargoLine"), "transform": Transform3D(Basis.IDENTITY, Vector3(23.3, 0.0, 16.75)), "profile": &"cargo_line_long", "seed": 10739},
	&"AftCrewWorkPost": {"path": NodePath("OperationalLattice/Activities/AftCrewWorkPost"), "transform": Transform3D(Basis.IDENTITY, Vector3(-7.0, 4.2, 65.0)), "profile": &"crew_workpost", "seed": 6607},
	&"HabitatSkywatchPost": {"path": NodePath("OperationalLattice/Activities/HabitatSkywatchPost"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(73.0, 5.08, 19.0)), "profile": &"observatory", "seed": 7703},
	&"FreightApproachSignage": {"path": NodePath("OperationalLattice/Activities/FreightApproachSignage"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-41.0, 6.18, 29.0)), "profile": &"signage_pylon", "seed": 8821},
}
const STATION_AMBIENCE_SPECS := {
	&"central-berth-utilities": {"node_name": &"CentralBerthUtilitiesAmbience", "path": NodePath("OperationalLattice/Ambience/CentralBerthUtilitiesAmbience"), "position": Vector3(10.65, 1.8, -19.25), "seed": 4831, "base_frequency_hz": 44.0, "maximum_distance": 26.0, "reference_distance": 4.0},
	&"aft-operations-service-wall": {"node_name": &"AftOperationsAmbience", "path": NodePath("OperationalLattice/Ambience/AftOperationsAmbience"), "position": Vector3(10.0, 2.35, 60.55), "seed": 7759, "base_frequency_hz": 52.0, "maximum_distance": 24.0, "reference_distance": 3.5},
	&"habitat-environmental-main": {"node_name": &"HabitatEnvironmentalAmbience", "path": NodePath("OperationalLattice/Ambience/HabitatEnvironmentalAmbience"), "position": Vector3(59.15, 3.2, 20.95), "seed": 9127, "base_frequency_hz": 39.0, "maximum_distance": 22.0, "reference_distance": 3.0},
	&"freight-control-machinery": {"node_name": &"FreightControlAmbience", "path": NodePath("OperationalLattice/Ambience/FreightControlAmbience"), "position": Vector3(-33.75, 2.58, 57.8), "seed": 12203, "base_frequency_hz": 61.0, "maximum_distance": 28.0, "reference_distance": 4.0},
}
const STATION_DRESSING_SPECS := {
	&"CentralBerthOuterFascia": {"path": NodePath("OperationalLattice/StructuralDressing/CentralBerthOuterFascia"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(13.5, -0.02, -10.0)), "length": 20.0, "profile": &"standard", "orientation": &"along_mount_x"},
	&"AftOperationsOuterFascia": {"path": NodePath("OperationalLattice/StructuralDressing/AftOperationsOuterFascia"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(10.86, 4.6, 60.55)), "length": 6.0, "profile": &"light", "orientation": &"along_mount_x"},
	&"HabitatOuterServiceDressing": {"path": NodePath("OperationalLattice/StructuralDressing/HabitatOuterServiceDressing"), "transform": Transform3D(Basis.IDENTITY, Vector3(59.15, 4.45, 21.94)), "length": 12.0, "profile": &"standard", "orientation": &"along_mount_x"},
	&"FreightRackServiceDressing": {"path": NodePath("OperationalLattice/StructuralDressing/FreightRackServiceDressing"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-75.34, 0.38, 56.8)), "length": 20.0, "profile": &"light", "orientation": &"along_mount_x"},
}
const STATION_NAVIGATION_SCHEMA_VERSION := 1
const EXPECTED_STATION_SERVICE_AGENT_COUNT := 7
const STATION_SERVICE_AGENT_MINIMUM_BERTH_GAP := 0.15
## Metres the bottom of a courier's published envelope must clear the highest
## waypoint of its own route by. The route markers sit on the connector deck, so
## this keeps the presentation body above the production player capsule
## (`1.94 m`). The real deck-surface clearance is proved by raycast in
## `tests/station_navigation_graph_test.gd`.
const STATION_SERVICE_AGENT_MINIMUM_ROUTE_CLEARANCE := 2.2

## Exactly one presentation courier per declared station connection slot.
##
## Every route below is *resolved* from `StationNavigationGraph`, never authored
## here: the world names the two declared endpoints and the graph decides whether
## and how they connect. A slot that stops pairing therefore removes its courier
## and turns the navigation audit red instead of leaving an agent flying a stale
## line. Hover lifts keep the courier body at least
## `STATION_SERVICE_AGENT_MINIMUM_DECK_CLEARANCE` above the deck it follows, so a
## presentation body never appears to occupy player walking space.
const STATION_SERVICE_AGENT_SPECS := {
	&"aft-junction-courier": {
		"node_name": &"AftJunctionServiceCourier",
		"path": NodePath("OperationalLattice/ServiceAgents/AftJunctionServiceCourier"),
		"slot_id": &"hub-aft-junction",
		"from_node_id": &"station-hub:hub-aft-junction",
		"to_node_id": &"aft-junction-stack:approach",
		"seed": 5501,
		"speed": 0.85,
		"lift": 3.7,
	},
	&"fleet-dock-courier": {
		"node_name": &"FleetDockServiceCourier",
		"path": NodePath("OperationalLattice/ServiceAgents/FleetDockServiceCourier"),
		"slot_id": &"hub-fleet-dock-comb",
		"from_node_id": &"station-hub:hub-fleet-dock-comb",
		"to_node_id": &"fleet-dock-comb:approach",
		"seed": 7703,
		"speed": 1.2,
		"lift": 3.4,
	},
	&"freight-branch-courier": {
		"node_name": &"FreightBranchServiceCourier",
		"path": NodePath("OperationalLattice/ServiceAgents/FreightBranchServiceCourier"),
		"slot_id": &"hub-registry-pod-freight",
		"from_node_id": &"station-hub:hub-registry-pod-freight",
		"to_node_id": &"jovian-freight-berth:approach",
		"seed": 8821,
		"speed": 1.5,
		# Preserves player headroom above FreightApproachGantry at the courier's
		# lowest sway, while leaving the route and vehicle handoff fixed.
		"lift": 9.1,
	},
	&"habitat-spine-courier": {
		"node_name": &"HabitatSpineServiceCourier",
		"path": NodePath("OperationalLattice/ServiceAgents/HabitatSpineServiceCourier"),
		"slot_id": &"hub-starboard-habitat",
		"from_node_id": &"station-hub:hub-starboard-habitat",
		"to_node_id": &"habitat-spine:approach",
		"seed": 6607,
		"speed": 0.9,
		"lift": 3.7,
	},
	&"fabrication-annex-courier": {
		"node_name": &"FabricationAnnexServiceCourier",
		"path": NodePath("OperationalLattice/ServiceAgents/FabricationAnnexServiceCourier"),
		"slot_id": &"fabrication_annex_inbound",
		"from_node_id": &"station-hub:fabrication_annex_inbound",
		"to_node_id": &"fabrication_annex:annex_inbound",
		"seed": 11807,
		"speed": 0.95,
		"lift": 3.7,
	},
	&"observation-logistics-courier": {
		"node_name": &"ObservationLogisticsServiceCourier",
		"path": NodePath("OperationalLattice/ServiceAgents/ObservationLogisticsServiceCourier"),
		"slot_id": &"observation-logistics-spur-origin",
		"from_node_id": &"station-hub:observation-logistics-spur-origin",
		"to_node_id": &"observation-logistics-spur:origin",
		"seed": 12847,
		"speed": 0.9,
		"lift": 3.7,
	},
	&"salvage-terrace-courier": {
		"node_name": &"SalvageTerraceServiceCourier",
		"path": NodePath("OperationalLattice/ServiceAgents/SalvageTerraceServiceCourier"),
		"slot_id": &"hub-salvage-terrace",
		"from_node_id": &"station-hub:hub-salvage-terrace",
		"to_node_id": &"salvage-terrace:connector",
		"seed": 13861,
		"speed": 0.85,
		"lift": 3.7,
	},
}
const STATION_ACTIVITY_SCENE := preload("res://scenes/world/components/station_operations_activity.tscn")
const STATION_SERVICE_AGENT_SCENE := preload("res://scenes/world/components/station_service_agent.tscn")
const STATION_NAVIGATION_GRAPH_SCRIPT := preload("res://scripts/world/station_navigation_graph.gd")
const STATION_AMBIENCE_SCENE := preload("res://scenes/audio/station_machinery_ambience.tscn")
const STATION_DRESSING_SCENE := preload("res://scenes/world/components/station_structural_service_dressing.tscn")
const STATION_ROUTE_REGISTRY_SCENE := preload("res://scripts/world/station_route_registry.gd")
const TOW_TRACTOR_SCENE := preload("res://scenes/world/tow_tractor.tscn")

## The world-side half of every station connection slot. Each entry names the
## real lattice geometry the player crosses to reach that module, so the station
## graph stays one connected structure instead of four isolated islands. The
## adjacency itself is declared, not measured: physical continuity across these
## connectors is proved by `station_surface_playability_test.gd` and the
## per-module integration suites.
const STATION_HUB_ENDPOINT_DECLARATIONS := [
	{
		"slot_id": &"hub-aft-junction",
		"expects_module": &"aft-junction-stack",
		"evidence_status": &"modern_interpretation",
		"anchor_path": "ExposedDockLattice/AftModuleConnector",
	},
	{
		"slot_id": &"hub-starboard-habitat",
		"expects_module": &"habitat-spine",
		"evidence_status": &"modern_interpretation",
		"anchor_path": "ExposedDockLattice/StarboardBerthNode",
	},
	{
		"slot_id": &"hub-fleet-dock-comb",
		"expects_module": &"fleet-dock-comb",
		"evidence_status": &"modern_interpretation",
		"anchor_path": "ExposedDockLattice/FleetDockCombConnector/FleetDockCombConnectorDeck",
	},
	{
		"slot_id": &"hub-registry-pod-freight",
		"expects_module": &"jovian-freight-berth",
		"evidence_status": &"modern_interpretation",
		"anchor_path": "ModernFleetRegistry/RegistryPodDeck",
	},
	{
		"slot_id": &"fabrication_annex_inbound",
		"expects_module": &"fabrication_annex",
		"evidence_status": &"modern_interpretation",
		"anchor_path": "ExposedDockLattice/FabricationAnnexConnector/ConnectorDeckC",
	},
	{
		"slot_id": &"observation-logistics-spur-origin",
		"expects_module": &"observation-logistics-spur",
		"evidence_status": &"modern_interpretation",
		# The courier component requires at least one metre of declared travel. This
		# world-owned anchor is on the real rear-aisle floor immediately behind the
		# split rail; it never borrows endpoint authority from a module subtree.
		"anchor_path": "ExposedDockLattice/ObservationLogisticsConnector/RouteAnchor",
	},
	{
		"slot_id": &"hub-salvage-terrace",
		"expects_module": &"salvage-terrace",
		"evidence_status": &"modern_interpretation",
		# This world-owned point is 0.09 m inside Fabrication's real north
		# service floor. It keeps the declared courier route at the component's
		# honest 1.0 m minimum while the live service marker at z=52 remains on
		# the exact seam between that floor and the connector.
		"anchor_path": "ExposedDockLattice/SalvageTerraceConnector/RouteAnchor",
	},
]
const CENTRAL_BERTH_HERO_PRESENTATION_SCENE := preload(
	"res://scenes/world/presentation/central_berth_hero_presentation.tscn"
)

# The ship root is authored at the berth transform. These presentation contacts
# match the three visible Torrent feet, but remain non-colliding so the berth's
# broader `small_craft` contract and vertical landing volume stay authoritative.
const TORRENT_GEAR_CONTACT_OFFSETS := {
	&"port_main": Vector3(-1.92, -0.68, 1.25),
	&"starboard_main": Vector3(1.92, -0.68, 1.25),
	&"nose": Vector3(0.0, -0.58, -3.05),
}

const CENTRAL_HERO_CONTENT_NOTE := (
	"The Torrent class name and interceptor role are creator-roster supported. "
	+ "The current craft geometry, this berth layout, dimensions, trusses, clamps, "
	+ "utilities, controls, materials, lighting, station adjacency, and exact "
	+ "name-to-model mapping are provisional modern interpretation."
)

## Hub palette.
##
## Re-frozen as a group, because the problem was the group and not any one entry.
## Every structural colour here sat between 41% and 79% HSV saturation, which is
## a range real painted and bare metal essentially never occupies: photographed
## station hardware clusters in a narrow, desaturated band and takes its variety
## from how surfaces answer light, not from hue. A set of evenly spaced saturated
## primaries laid over untextured volumes is the exact signature the player
## described, and the hub was the last part of the station still using one — the
## four authored modules had already moved to greys at 5-25% saturation, so this
## also stops the hub disagreeing with everything it joins.
##
## Structural roles, old -> new, with saturation before and after:
##   NAVY        0b1d2a -> 141c22   74% -> 41%
##   DEEP_BLUE   10364b -> 1d2f39   79% -> 49%
##   STEEL_BLUE  1c566e -> 33505c   74% -> 45%
##   DECK        203744 -> 232d33   53% -> 33%
##   DECK_LIGHT  36505c -> 424c51   41% -> 19%
##   IVORY       dce8e4 -> cfd6d3    5% ->  3%
##
## Value spacing is deliberately made uneven at the same time. The old set walked
## up in near-equal steps, which is another toy-render tell: it makes a palette
## read as a swatch strip. DECK and NAVY are now close together and DECK_LIGHT
## pulls away from both, so the decks group as one material family with one
## lighter grade rather than as three ranked tones.
##
## The signal colours are NOT desaturated. KETH_CYAN, ALERT_RED, PALE_CYAN and
## KETH_ORANGE drive emissives, guide lights, warning lamps and weapon impacts,
## where saturation is carrying meaning rather than describing a surface, and
## where the accessibility work downstream depends on them. Desaturating a
## signal is a legibility regression, not an art improvement.
##
## What the hazard paint needed was to stop borrowing the lamp's colour. One
## constant was serving both a warning light and roughly every railing post,
## cross brace, safety pylon and tow tractor on the station, so the largest
## painted areas in the frame were being drawn at full-value 100% signal orange.
## HAZARD_AMBER splits the surface off at the ochre real hazard paint actually
## photographs as; KETH_ORANGE keeps the lamps.
const NAVY := Color("141c22")
const DEEP_BLUE := Color("1d2f39")
const STEEL_BLUE := Color("33505c")
const KETH_CYAN := Color("48dbe2")
const PALE_CYAN := Color("baf7f1")
const KETH_ORANGE := Color("ff9f43")
const ALERT_RED := Color("ff5f57")
const DECK := Color("232d33")
const DECK_LIGHT := Color("424c51")
const IVORY := Color("cfd6d3")
const HAZARD_AMBER := Color("8f6530")
const GLASS := Color(0.24, 0.86, 0.93, 0.24)

## All 50 world-built guide lenses are the same childless 0.16 m sphere and use
## one of four immutable emissive recipes. Their stable sibling paths remain as
## childless markers beside each OmniLight3D, while four color-specific batches
## draw the exact authored transforms with one shared SphereMesh.
const GUIDE_LENS_RADIUS := 0.16
const GUIDE_LENS_HEIGHT := 0.32
const GUIDE_LENS_RADIAL_SEGMENTS := 24
const GUIDE_LENS_RINGS := 12
const GUIDE_LENS_EXPECTED_COUNT := 50
const GUIDE_LENS_EXPECTED_RECIPE_COUNT := 4
const GUIDE_LENS_BASELINE_RETAINED_RESOURCES := 100
const GUIDE_LENS_BASELINE_SCOPE_NODES := 100
const GUIDE_LENS_BASELINE_SUBMISSIONS := 50
const GUIDE_LENS_BATCH_COUNT := 4
const GUIDE_LENS_BATCHED_SCOPE_NODES := 104
const GUIDE_LENS_BATCHED_SUBMISSIONS := 4
const GUIDE_LIGHT_BEHAVIOR_FINGERPRINT := "790d4162ba1c9e4369d79c69afe066390d4f34c65780068d3cf6f6a88f867f3a"
const GUIDE_LENS_COLOR_COUNTS := {
	"48dbe2ff": 16,
	"ff9f43ff": 13,
	"ff5f57ff": 20,
	"cfe6eeff": 1,
}

const DOCK_OPERATIONS_KEYLINE_SIZE := Vector3(1.26, 0.035, 0.31)
const DOCK_OPERATIONS_KEYLINE_ROTATION_DEGREES := Vector3(-20.0, -90.0, 0.0)
const DOCK_OPERATIONS_KEYLINE_POSITIONS := [
	Vector3(38.18, 1.67, 24.5),
	Vector3(38.18, 1.67, 27.0),
	Vector3(38.18, 1.67, 29.5),
]

## The three freestanding mast collars are presentation trim around collidable
## mast bodies. Their authored nodes remain separate; only the immutable torus
## resource is shared.
const DOCK_MAST_COLLAR_INNER_RADIUS := 0.55
const DOCK_MAST_COLLAR_OUTER_RADIUS := 0.74
const DOCK_MAST_COLLAR_RINGS := 48
const DOCK_MAST_COLLAR_RING_SEGMENTS := 16
const DOCK_MAST_COLLAR_BUDGETED_RINGS := 40
const DOCK_MAST_COLLAR_BUDGETED_RING_SEGMENTS := 16
const DOCK_MAST_COLLAR_COPY_COUNT := 3
const DOCK_MAST_COLLAR_POSITIONS := [
	Vector3(11.0, 1.0, 10.0),
	Vector3(-11.0, 1.0, -23.0),
	Vector3(11.0, 1.0, -23.0),
]

## The three parked LandingPad utility hoses end in the same childless visual
## torus. They retain separate nodes, names, parents, transforms and one-surface
## submissions because the hoses are separately identified presentation
## assemblies; only their previously private mesh resource is shared.
const LANDING_PAD_DECK_CONNECTOR_INNER_RADIUS := 0.16
const LANDING_PAD_DECK_CONNECTOR_OUTER_RADIUS := 0.24
const LANDING_PAD_DECK_CONNECTOR_AUTHORED_RINGS := 64
const LANDING_PAD_DECK_CONNECTOR_AUTHORED_RING_SEGMENTS := 16
const LANDING_PAD_DECK_CONNECTOR_BUDGETED_RINGS := 32
const LANDING_PAD_DECK_CONNECTOR_BUDGETED_RING_SEGMENTS := 13
const LANDING_PAD_DECK_CONNECTOR_BASELINE_NODES := 3
const LANDING_PAD_DECK_CONNECTOR_BASELINE_SUBMISSIONS := 3
const LANDING_PAD_DECK_CONNECTOR_BASELINE_MESH_RESOURCES := 3
const LANDING_PAD_DECK_CONNECTOR_PATHS := [
	NodePath("LandingPad/StarboardUtilityBay/ParkedUmbilicalHosePower/DeckConnector"),
	NodePath("LandingPad/StarboardUtilityBay/ParkedUmbilicalHoseData/DeckConnector"),
	NodePath("LandingPad/StarboardUtilityBay/ParkedUmbilicalHoseFuel/DeckConnector"),
]
const LANDING_PAD_DECK_CONNECTOR_POSITIONS := [
	Vector3(8.62, 0.13, -5.4),
	Vector3(8.62, 0.13, -9.6),
	Vector3(8.62, 0.13, -13.8),
]

## Each of the four independently moving/destroyed range targets retains its
## named childless Core node and one-surface submission. Only the identical
## SphereMesh resource behind those copies is shared; target authority and
## lifecycle remain on the four StaticBody3D parents.
const EXTERIOR_TARGET_CORE_RADIUS := 1.4
const EXTERIOR_TARGET_CORE_HEIGHT := 2.8
const EXTERIOR_TARGET_CORE_RADIAL_SEGMENTS := 24
const EXTERIOR_TARGET_CORE_RINGS := 12
const EXTERIOR_TARGET_CORE_BASELINE_NODES := 4
const EXTERIOR_TARGET_CORE_BASELINE_SUBMISSIONS := 4
const EXTERIOR_TARGET_CORE_BASELINE_MESH_RESOURCES := 4
const EXTERIOR_TARGET_CORE_PATHS := [
	NodePath("ExteriorTargetRange/TargetDrone01/DroneVisual/Core"),
	NodePath("ExteriorTargetRange/TargetDrone02/DroneVisual/Core"),
	NodePath("ExteriorTargetRange/TargetDrone03/DroneVisual/Core"),
	NodePath("ExteriorTargetRange/TargetDrone04/DroneVisual/Core"),
]

## The four lamps on each of the four independently authoritative range targets
## retain their 16 named MeshInstance3D nodes and one-surface submissions. Their
## exact 0.22 m SphereMesh recipe is immutable, so only that resource is shared.
const EXTERIOR_TARGET_LAMP_RADIUS := 0.22
const EXTERIOR_TARGET_LAMP_HEIGHT := 0.44
const EXTERIOR_TARGET_LAMP_RADIAL_SEGMENTS := 24
const EXTERIOR_TARGET_LAMP_RINGS := 12
const EXTERIOR_TARGET_LAMP_COUNT := 16
const EXTERIOR_TARGET_LAMP_BASELINE_MESH_RESOURCES := 16
const EXTERIOR_TARGET_LAMP_SHARED_MESH_RESOURCES := 1
const EXTERIOR_TARGET_LAMP_SUBMISSIONS := 16

## Aim of the station's key light, and of the sky's sun glow.
##
## One constant serves both. A backdrop whose bright side does not agree with the
## direction the geometry is lit from is one of the things that makes a sky read
## as a painted wall rather than as the place the light is coming from.
const KEY_LIGHT_ROTATION_DEGREES := Vector3(-42.0, -28.0, 0.0)

## Outbound flight clearance under the exterior range gate.
##
## The range's own header beam spans the full 63 m of the gate at y = 8.5 .. 9.5,
## z = -120.5 .. -119.5, and a review flight flew into it at 46 m/s. The beam is
## not the defect and does not move — the layout is confirmed correct — but two
## things about it were: the station's published outbound aim, the `LaunchGate`
## marker, sat at y = 8.0, which is *inside* the band the beam blocks; and the
## beam itself carried no lamp, no marking and no clearance legend over its whole
## span, so it did not read as an obstacle until it filled the canopy.
##
## Measured against the real production hulls with the production World layer, as
## a ship-origin altitude on the launch centreline (`tests/outbound_route_clearance_test.gd`
## re-measures all of this from the live tree rather than trusting these numbers):
##
##   craft    hull (m)              clear under the gate   blocked band
##   Torrent   7.20 x 4.50 x  9.00  y <= 4.70              4.80 .. 10.20
##   Arrow    11.10 x 1.65 x 12.20  y <= 6.80              6.90 ..  9.50
##   Jovian   18.53 x 5.94 x 26.15  y <= 3.80              3.90 .. 10.70
##   Zenith   14.42 x 4.28 x 10.45  y <= 5.20              5.30 .. 10.50
##
## The aperture is uniform across the whole span: every sampled x from -35 to +35
## gives a Torrent the same 4.70 m ceiling, so there is no lateral way around it
## inside the gate. Over the top is not a usable route either — it needs y >= 10.3
## for a Torrent and y >= 10.8 for a Jovian, an 8 m climb inside the 56 m between
## the launch gate and the beam, and the beacon chain descends from there anyway
## (RouteBeaconAlpha is at y = -9). **Under is the only line the whole fleet can
## fly**, which is also the line the Cinder Reach beacon chain was already drawn
## for.
##
## `OUTBOUND_CLEARANCE_CEILING` is the fleet-worst ceiling: the Jovian's, because
## it is the deepest hull. `OUTBOUND_CLEARANCE_FLOOR` is the same craft's clearance
## over the launch arm deck at z = -64. The launch gate is aimed at the centre of
## that band, so the largest craft in the fleet leaves the station with the same
## margin under the beam as it has over its own deck.
const OUTBOUND_CLEARANCE_CEILING := 3.80
const OUTBOUND_CLEARANCE_FLOOR := 1.24
const LAUNCH_GATE_AIM_Y := 2.5
## Nine positions along the header beam. Nine and not four because the span is
## 63 m: at four the lamps are 15.75 m apart and the beam still reads as unlit
## structure between them from the launch gate.
const RANGE_HEADER_CUE_X: Array[float] = [-28.0, -21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0, 28.0]

## Deep-space sky. See `deep_space_sky.gdshader` for why this replaced
## ProceduralSkyMaterial; these are its complete authored state.
const SKY_SHADER_PATH := "res://scripts/rendering/deep_space_sky.gdshader"
## Pole of the great-circle dust band, so the band lies perpendicular to it. It
## is deliberately oblique to the station's own axes: a band that ran parallel to
## the launch spine would read as part of the architecture.
const SKY_BAND_AXIS := Vector3(0.34, 0.88, -0.33)
const SKY_BAND_WIDTH := 0.42
const SKY_BAND_COLOR := Color("18202c")
const SKY_CORE_COLOR := Color("4a3928")
const SKY_CORE_AXIS := Vector3(-0.62, -0.12, -0.77)
const SKY_CORE_FOCUS := 7.0
const SKY_ZENITH_COLOR := Color("0b1018")
const SKY_NADIR_COLOR := Color("0c0c0e")
const SKY_SUN_COLOR := Color("3c606f")
const SKY_SUN_FOCUS := 260.0
const SKY_SUN_HALO := 0.18
const SKY_SUN_HALO_FOCUS := 48.0
const SKY_DUST_SCALE := 3.4

@export_category("Landing")
@export var landing_half_extents := Vector3(12.0, 3.8, 17.0)

@export_category("Target Range")
@export_range(1.0, 500.0, 1.0) var target_health := 100.0
@export_range(1.0, 500.0, 1.0) var projectile_damage := 50.0

@export_category("Presentation")
@export_enum("Low:0", "Medium:1", "High:2") var visual_quality_level := 2

@onready var player_spawn: Marker3D = %PlayerSpawn
@onready var ship_spawn: Marker3D = %ShipSpawn
@onready var landing_zone: Marker3D = %LandingZone
@onready var launch_gate: Marker3D = %LaunchGate
@onready var habitat_spine: HabitatSpine = $HabitatSpine
@onready var jovian_freight_berth: JovianFreightBerth = $JovianFreightBerth
@onready var fleet_dock_comb: FleetDockComb = $FleetDockComb
@onready var fabrication_annex: FabricationAnnex = $FabricationAnnex
@onready var observation_logistics_spur: ObservationLogisticsSpur = $ObservationLogisticsSpur
@onready var salvage_terrace: SalvageTerrace = $SalvageTerrace

var _materials: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
var _chamfered_cylinder_cache: Dictionary = {}
var _guide_lens_mesh: SphereMesh
var _guide_lens_material_cache: Dictionary = {}
var _guide_lens_nodes: Array[Marker3D] = []
var _guide_light_nodes: Array[OmniLight3D] = []
var _guide_lens_batches: Dictionary = {}
var _landing_pad_deck_connector_mesh: TorusMesh
var _tie_down_socket_mesh: TorusMesh
var _dock_mast_collar_mesh: TorusMesh
var _exterior_target_core_mesh: SphereMesh
var _exterior_target_lamp_mesh: SphereMesh
var _targets: Array[StaticBody3D] = []
var _warning_lights: Array[OmniLight3D] = []
var _crane_trolley: Node3D
var _crane_hook: Node3D
var _built := false
## Set only by a boot loader, through `prepare_staged_construction()`, before
## this world enters the tree. Cleared again the moment the staged build starts.
var _staged_construction := false
var _elapsed := 0.0
var _destroyed_target_count := 0
const MAX_PENDING_TARGET_PRESENTATIONS := 16
var _pending_target_presentations: Dictionary = {}
var _pending_target_presentation_order: Array[int] = []
var _visual_quality_report: Dictionary = {}
var _berth_transforms: Dictionary = {}
var _berth_half_extents: Dictionary = {}
var _berth_nodes: Dictionary = {}
var _berth_feedback_nodes: Dictionary = {}
var _central_berth_root: Node3D
var _central_berth_hero_presentation: CentralBerthHeroPresentation
var _central_berth_service_line: Node3D
var _central_service_black_stock_transforms: Array[Transform3D] = []
var _central_service_black_stock_batch: MultiMeshInstance3D
var _modern_registry_column_transforms: Array[Transform3D] = []
var _modern_registry_column_bodies: Array[StaticBody3D] = []
var _modern_registry_column_batch: MultiMeshInstance3D
var _station_operations_activities: Array[StationOperationsActivity] = []
var _station_machinery_ambience_nodes: Array[StationMachineryAmbience] = []
var _station_structural_service_dressings: Array[StationStructuralServiceDressing] = []
var _station_activity_enabled := true
var _station_door_audio_hook_count := 0
var _station_door_audio_bindings: Dictionary = {}
var _station_route_registry := STATION_ROUTE_REGISTRY_SCENE.new() as StationRouteRegistry
var _station_route_registry_report: Dictionary = {}
var _station_service_agents: Array[StationServiceAgent] = []
var _station_navigation_graph := STATION_NAVIGATION_GRAPH_SCRIPT.new() as StationNavigationGraph
var _station_navigation_graph_report: Dictionary = {}
var _fleet_expansion_production_binding: Node3D
var _station_defense_content: StationDefenseEncounterContent
var _station_defense_activity_board: Area3D
var _heavy_breach_activity_board: Area3D
var _heavy_breach_protected_objective: Node3D
var _station_solar_readability_presentation: RefCounted
var _last_station_solar_readability_result: Dictionary = {}
var _station_solar_readability_attach_count := 0
var _station_solar_readability_detach_count := 0


func _enter_tree() -> void:
	# `_ready` runs only once. A detached/re-added built world restores its
	# component lifecycle after every descendant has re-entered the tree.
	if _built:
		call_deferred("_restore_operational_lattice_after_reentry")
		call_deferred("_bind_station_defense_external_owners")
		call_deferred("_bind_heavy_breach_external_owners")
		call_deferred("_restore_range_targets_after_reentry")
		call_deferred("_restore_station_solar_readability_after_reentry")


func _exit_tree() -> void:
	_retire_station_solar_readability(&"station_detached")
	# Door signals target this long-lived world object. Explicitly remove the
	# bound instance-ID callables so a streamed world never retains stale hooks.
	_disconnect_operational_lattice_audio()


func _ready() -> void:
	if _built:
		# Re-entering the SceneTree must restore the world-owned presentation
		# lifecycle after component teardown disabled processing/audio resources.
		_index_operational_lattice_components()
		_initialize_station_route_registry()
		_connect_operational_lattice_audio()
		_apply_operational_dressing_quality()
		set_station_activity_enabled(_station_activity_enabled)
		return
	if _staged_construction:
		# A boot loader owns the build and will drive `run_staged_construction()`.
		return
	_built = true
	_run_build_stages()


## The one-time procedural build, in order, as `[method, progress label]`.
##
## This is the same sequence `_ready` always ran, lifted into data so a boot
## loader can walk it one stage per frame instead of paying for all of it inside
## one main-loop iteration. The ordering is load-bearing:
##
## * `_build_module_reflection_probes` follows `_build_space_backdrop` so the
##   update-once bake sees the finished sky.
## * The hub endpoints resolve against lattice geometry built above, so
##   `_initialize_station_route_registry` can only run once the environment
##   exists. Service couriers consume routes resolved from that registry, so
##   `_build_station_service_agents` follows it and is indexed with the rest of
##   the lattice.
## * `_build_station_activity_collision` remains the last geometry pass. Where
##   two station decks meet, broad-phase registration order decides which of two
##   coincident World colliders answers a downward ray, so moving this earlier
##   would perturb existing mount-foot support audits.
## * `_apply_sign_geometry_budget` runs last, once every module owns its signs.
const BUILD_STAGES: Array[Array] = [
	[&"_initialize_berths", "Surveying berths"],
	[&"_build_operational_lattice_components", "Staffing the operations lattice"],
	[&"_create_materials", "Mixing station materials"],
	[&"_build_environment", "Lighting the yard"],
	[&"_build_architecture", "Raising the structure"],
	[&"_build_landing_pad", "Laying the central berth"],
	[&"_build_launch_corridor", "Opening the launch corridor"],
	[&"_build_central_berth_service_line", "Running the berth service line"],
	[&"_build_catwalks_and_control_room", "Hanging catwalks"],
	[&"_build_regeneration_gallery", "Fitting the regeneration gallery"],
	[&"_build_provisional_fleet", "Parking the provisional fleet"],
	[&"_build_industrial_details", "Dressing the industrial deck"],
	[&"_build_cargo_and_machinery", "Loading cargo and machinery"],
	[&"_build_exterior_range", "Setting the exterior range"],
	[&"_build_space_backdrop", "Hanging the sky"],
	[&"_build_module_reflection_probes", "Baking reflections"],
	[&"_build_station_defense_production_content", "Placing perimeter defense"],
	[&"_build_heavy_breach_production_activity", "Placing heavy breach board"],
	[&"_initialize_station_route_registry", "Routing the station"],
	[&"_build_station_service_agents", "Dispatching service couriers"],
	[&"_build_station_activity_collision", "Securing station machinery"],
	[&"_index_operational_lattice_components", "Indexing station systems"],
	[&"_connect_operational_lattice_audio", "Wiring station audio"],
	[&"_apply_operational_dressing_quality", "Applying visual quality"],
	[&"_restore_station_activity_state", "Starting station life"],
	[&"_apply_sign_geometry_budget", "Setting the signage"],
]


func _run_build_stages() -> void:
	for stage: Array in BUILD_STAGES:
		call(stage[0] as StringName)


## Re-states the authored activity flag through the setter, which is what
## actually starts the station's moving parts. A stage entry rather than a tail
## call so both build paths run the identical ordered sequence.
func _restore_station_activity_state() -> void:
	set_station_activity_enabled(_station_activity_enabled)


func _build_station_defense_production_content() -> void:
	if is_instance_valid(_station_defense_content) or is_instance_valid(_station_defense_activity_board):
		return
	_station_defense_content = (
		STATION_DEFENSE_CONTENT_SCENE.instantiate() as StationDefenseEncounterContent
	)
	_station_defense_content.name = "StationDefenseEncounter"
	add_child(_station_defense_content)
	_station_defense_activity_board = (
		STATION_DEFENSE_ACTIVITY_BOARD_SCRIPT.new() as Area3D
	)
	_station_defense_activity_board.name = "StationDefenseActivityBoard"
	_station_defense_activity_board.transform = STATION_DEFENSE_ACTIVITY_BOARD_TRANSFORM
	add_child(_station_defense_activity_board)
	call_deferred("_bind_station_defense_external_owners")


func _build_heavy_breach_production_activity() -> void:
	if is_instance_valid(_heavy_breach_activity_board):
		return
	_heavy_breach_protected_objective = Node3D.new()
	_heavy_breach_protected_objective.name = "HeavyBreachProtectedObjective"
	_heavy_breach_protected_objective.transform = HEAVY_BREACH_PROTECTED_OBJECTIVE_TRANSFORM
	_heavy_breach_protected_objective.set_meta(&"activity_id", &"shipyard_heavy_breach")
	_heavy_breach_protected_objective.set_meta(&"caller_owned", true)
	_heavy_breach_protected_objective.set_meta(&"combat_authority", false)
	add_child(_heavy_breach_protected_objective)
	var objective_marker := MeshInstance3D.new()
	objective_marker.name = "ProtectedObjectiveMarker"
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 1.35
	marker_mesh.bottom_radius = 1.35
	marker_mesh.height = 0.16
	marker_mesh.radial_segments = 6
	objective_marker.mesh = marker_mesh
	# A vertical hexagonal shield remains collisionless presentation, but reads
	# from the station approach unlike the old flat floor puck.
	objective_marker.position = Vector3(0.0, 0.55, 0.0)
	objective_marker.rotation.x = PI * 0.5
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("5b2020")
	marker_material.emission_enabled = true
	marker_material.emission = Color("ff5c43")
	marker_material.emission_energy_multiplier = 0.24
	objective_marker.material_override = marker_material
	_heavy_breach_protected_objective.add_child(objective_marker)
	var objective_label := Label3D.new()
	objective_label.name = "ProtectedObjectiveLabel"
	objective_label.text = "BREACH\nPROTECTED ASSET"
	objective_label.font_size = 22
	objective_label.modulate = Color("ffb09a")
	objective_label.pixel_size = 0.0045
	objective_label.outline_size = 5
	objective_label.position = Vector3(0.0, 2.25, 0.0)
	_heavy_breach_protected_objective.add_child(objective_label)
	_heavy_breach_activity_board = HEAVY_BREACH_ACTIVITY_BOARD_SCRIPT.new() as Area3D
	_heavy_breach_activity_board.name = "HeavyBreachActivityBoard"
	_heavy_breach_activity_board.transform = HEAVY_BREACH_ACTIVITY_BOARD_TRANSFORM
	add_child(_heavy_breach_activity_board)
	call_deferred("_bind_heavy_breach_external_owners")


func _bind_station_defense_external_owners() -> void:
	if (
		is_queued_for_deletion()
		or not is_inside_tree()
		or not is_instance_valid(_station_defense_content)
		or not is_instance_valid(_station_defense_activity_board)
	):
		return
	var host := get_parent()
	if host == null:
		return
	var combat_authority := host.get_node_or_null(^"CombatAuthority") as LiveCombatAuthority
	var activity_director := host.get_node_or_null(^"ActivityDirector") as ActivityDirector
	if not is_instance_valid(combat_authority) or not is_instance_valid(activity_director):
		return
	_station_defense_activity_board.call(
		"configure_external_owners",
		_station_defense_content, combat_authority, activity_director
	)


func _bind_heavy_breach_external_owners() -> void:
	if (
		is_queued_for_deletion()
		or not is_inside_tree()
		or not is_instance_valid(_heavy_breach_protected_objective)
		or not is_instance_valid(_heavy_breach_activity_board)
	):
		return
	var host := get_parent()
	if host == null:
		return
	var combat_authority := host.get_node_or_null(^"CombatAuthority") as LiveCombatAuthority
	var scenario_director := host.get_node_or_null(^"EncounterScenarios") as EncounterScenarioDirector
	if not is_instance_valid(combat_authority) or not is_instance_valid(scenario_director):
		return
	_heavy_breach_activity_board.call(
		"configure_external_owners",
		_heavy_breach_protected_objective, scenario_director, combat_authority
	)


## Opt-in staged construction, requested by a boot loader before this world
## enters the tree. Returns without doing anything if the world is already in the
## tree or already built, so the synchronous `_ready` build stays the default for
## every direct instantiation - which is every test suite - and for the
## detach/re-entry path, where `_built` is already true.
func prepare_staged_construction() -> void:
	if _built or is_inside_tree():
		return
	_staged_construction = true


## How many stages [method run_staged_construction] will report, so a loader can
## size its progress bar against real work rather than a guess.
func get_staged_construction_stage_count() -> int:
	return BUILD_STAGES.size()


## Longest the staged build will hold the main loop before yielding. Several of
## these stages cost well under a millisecond, and a yield is not free - the
## engine draws a whole frame of a half-built yard nobody can see - so cheap
## stages are batched up to this budget and expensive ones yield immediately
## after. 24 ms keeps the window repainting at better than 40 Hz throughout.
const STAGED_BUILD_FRAME_BUDGET_USEC := 24_000


## Walks [constant BUILD_STAGES], calling `on_stage.call(label: String)` after
## each and yielding to the main loop whenever the frame budget is spent. The
## sequence is identical to the synchronous build; the only difference is that
## the main loop gets to draw and pump input in between.
func run_staged_construction(on_stage: Callable = Callable()) -> void:
	if _built or not _staged_construction:
		return
	_staged_construction = false
	_built = true
	var tree := get_tree()
	var budget_started := Time.get_ticks_usec()
	for stage: Array in BUILD_STAGES:
		call(stage[0] as StringName)
		if on_stage.is_valid():
			on_stage.call(stage[1] as String)
		if tree == null:
			continue
		if Time.get_ticks_usec() - budget_started < STAGED_BUILD_FRAME_BUDGET_USEC:
			continue
		await tree.process_frame
		budget_started = Time.get_ticks_usec()


## Brings every sign in the world under one geometry budget.
##
## The station's lettering is built by five different modules, and each of them
## had independently authored the same expensive `TextMesh` settings. Rather
## than five copies of the budget that drift apart, the world sweeps its whole
## subtree once, after the modules have finished building. Godot readies children
## before parents, so `AftJunctionStack`, `HabitatSpine`, `JovianFreightBerth`,
## `FleetDockComb` and the other resident station modules have built their signs by the
## time this runs. Modules that already call `SignGeometryBudget` themselves are
## detected and skipped, so this only ever catches what nothing else owns.
##
## It changes tessellation and extrusion only. Text, colour, alignment, scale,
## position and rotation are untouched, so MAP-004 sign facing and the
## colourblind-safe cue palette cannot be affected by it.
func _apply_sign_geometry_budget() -> void:
	SignGeometryBudget.normalise_tree(self)
	_finalize_guide_lens_batches()


func _process(delta: float) -> void:
	_elapsed += delta
	_animate_crane()
	_animate_warning_lights()
	_animate_targets()


## Exact world-space transform for placing the on-foot player.
func get_player_spawn() -> Transform3D:
	return player_spawn.global_transform


## Exact world-space transform for placing the flyable ship.
func get_ship_spawn() -> Transform3D:
	return get_berth_transform(CENTRAL_BERTH_ID)


## The station's published outbound aim point, at the mouth of the launch
## corridor.
##
## Re-aimed in the open, `(0, 8, -64)` -> `(0, 2.5, -64)`. The old altitude was
## inside the band the exterior range's own header beam blocks — a craft holding
## it out of the corridor meets the beam 51 m later, and a review flight did, at
## 46 m/s. The new altitude is the centre of the measured lane the deepest hull in
## the fleet can hold between the launch arm deck and the beam's 8.5 m underside;
## see `OUTBOUND_CLEARANCE_CEILING` for the full per-craft measurement and
## `tests/outbound_route_clearance_test.gd` for the guard. The range itself did
## not move.
func get_launch_gate_transform() -> Transform3D:
	return launch_gate.global_transform


## Ship-origin altitudes on the outbound centreline that clear both the launch
## arm deck and the range header beam, for every craft in the fleet.
##
## Published rather than left implicit because three separate things need to agree
## on it: the launch gate marker, the rendered flight review's first outbound
## waypoint, and the clearance regression. It is a design envelope measured from
## the production hulls, not a runtime constraint — nothing forces a pilot to
## stay inside it, which is exactly why the beam also carries a visible cue.
func get_outbound_clearance_band() -> Dictionary:
	return {
		"floor": OUTBOUND_CLEARANCE_FLOOR,
		"ceiling": OUTBOUND_CLEARANCE_CEILING,
		"aim_y": LAUNCH_GATE_AIM_Y,
	}


func get_dock_operations_keyline_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var room := get_node_or_null(^"UpperOperations/DockOperationsRoom") as Node3D
	var anchors: Array[Marker3D] = []
	var expected_transforms: Array[Transform3D] = []
	for keyline_index in DOCK_OPERATIONS_KEYLINE_POSITIONS.size():
		var expected_transform := Transform3D(
			Basis.from_euler(Vector3(
				deg_to_rad(DOCK_OPERATIONS_KEYLINE_ROTATION_DEGREES.x),
				deg_to_rad(DOCK_OPERATIONS_KEYLINE_ROTATION_DEGREES.y),
				deg_to_rad(DOCK_OPERATIONS_KEYLINE_ROTATION_DEGREES.z)
			)),
			DOCK_OPERATIONS_KEYLINE_POSITIONS[keyline_index]
		)
		expected_transforms.append(expected_transform)
		var anchor := room.get_node_or_null(NodePath(
			"DispatchKeyline%02d" % (keyline_index + 1)
		)) as Marker3D if room != null else null
		if anchor == null:
			errors.append("dock_operations_keyline_anchor_missing")
			continue
		anchors.append(anchor)
		if (
			not anchor.transform.is_equal_approx(expected_transform)
			or not bool(anchor.get_meta("batched_visual_anchor", false))
			or anchor.get_child_count() != 0
			or anchor.get_script() != null
		):
			errors.append("dock_operations_keyline_anchor_state_drift")
	var batch := room.get_node_or_null(
		^"DispatchKeylineRenderBatch"
	) as MultiMeshInstance3D if room != null else null
	var mesh_resource_count := 0
	var material_resource_count := 0
	var structural_submissions := 0
	var drawn_copies := 0
	if batch == null or batch.multimesh == null or batch.multimesh.mesh == null:
		errors.append("dock_operations_keyline_batch_missing")
	else:
		mesh_resource_count = 1
		material_resource_count = 1 if batch.material_override != null else 0
		structural_submissions = batch.multimesh.mesh.get_surface_count()
		drawn_copies = batch.multimesh.instance_count
		var authored_transforms := batch.get_meta("authored_instance_transforms", []) as Array
		if (
			batch.multimesh.mesh != _rounded_box_mesh(DOCK_OPERATIONS_KEYLINE_SIZE)
			or batch.material_override != _materials.get("steel_blue")
			or batch.multimesh.instance_count != expected_transforms.size()
			or batch.multimesh.buffer != _encode_multimesh_transforms(expected_transforms)
			or authored_transforms != expected_transforms
			or not bool(batch.get_meta("visual_detail_only", false))
			or batch.get_child_count() != 0
			or batch.get_script() != null
		):
			errors.append("dock_operations_keyline_batch_recipe_or_transform_drift")
	if anchors.size() != 3:
		errors.append("dock_operations_keyline_anchor_count_drift")
	if structural_submissions != 1 or drawn_copies != 3:
		errors.append("dock_operations_keyline_allocation_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"dock_operations_dispatch_keylines",
		"before": {
			"family_nodes": 3,
			"renderer_nodes": 3,
			"structural_submissions": 3,
			"mesh_resources": 1,
			"material_resources": 1,
			"drawn_copies": 3,
		},
		"current": {
			"family_nodes": anchors.size() + (1 if batch != null else 0),
			"renderer_nodes": 1 if batch != null else 0,
			"structural_submissions": structural_submissions,
			"mesh_resources": mesh_resource_count,
			"material_resources": material_resource_count,
			"drawn_copies": drawn_copies,
		},
		"stable_paths_exact": anchors.size() == 3,
		"transforms_exact": not errors.has("dock_operations_keyline_anchor_state_drift")
			and not errors.has("dock_operations_keyline_batch_recipe_or_transform_drift"),
		"collision_nodes": 0,
		"interaction_nodes": 0,
	}.duplicate(true)


## Renderer-independent retention audit for the world guide-light stock.
##
## "Submission" here is deliberately the structural mesh-surface submission
## count, not a driver draw-call claim. Four color-specific MultiMeshes retain
## all 50 visible copies while stable per-light paths remain childless markers.
func get_guide_light_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var lenses: Array[Marker3D] = []
	var lights: Array[OmniLight3D] = []
	for lens in _guide_lens_nodes:
		if is_instance_valid(lens):
			lenses.append(lens)
	for light in _guide_light_nodes:
		if is_instance_valid(light):
			lights.append(light)

	var mesh_ids: Dictionary = {}
	var material_ids: Dictionary = {}
	var color_counts: Dictionary = {}
	var structural_submissions := 0
	var drawn_copies := 0
	var authority_node_count := 0
	var scripted_node_count := 0
	var child_node_count := 0
	for lens in lenses:
		var color := lens.get_meta("guide_lens_color", Color.TRANSPARENT) as Color
		var color_key := color.to_html(true)
		color_counts[color_key] = int(color_counts.get(color_key, 0)) + 1
		if not bool(lens.get_meta("batched_visual_anchor", false)):
			errors.append("guide_lens_anchor_state_drift")
		if lens.get_script() != null:
			scripted_node_count += 1
		child_node_count += lens.get_child_count()
		for child in lens.get_children():
			if child.get_script() != null:
				scripted_node_count += 1
			if child is CollisionObject3D or child is NavigationRegion3D:
				authority_node_count += 1
	for color_variant in _guide_lens_batches:
		var color_key := str(color_variant)
		var color := Color(color_key)
		var batch := _guide_lens_batches[color_variant] as MultiMeshInstance3D
		if not is_instance_valid(batch) or batch.multimesh == null:
			errors.append("guide_lens_batch_missing")
			continue
		var mesh := batch.multimesh.mesh as SphereMesh
		var material := batch.material_override as StandardMaterial3D
		if mesh != null:
			mesh_ids[mesh.get_instance_id()] = true
			structural_submissions += mesh.get_surface_count()
		if material != null:
			material_ids[material.get_instance_id()] = true
		drawn_copies += batch.multimesh.instance_count
		var expected_transforms: Array[Transform3D] = []
		for lens in lenses:
			if (lens.get_meta("guide_lens_color", Color.TRANSPARENT) as Color).to_html(true) == color_key:
				expected_transforms.append(_transform_relative_to(self, lens))
		var authored_transforms := batch.get_meta("authored_instance_transforms", []) as Array
		if (
			mesh != _guide_lens_mesh
			or material != _guide_lens_material_cache.get(color)
			or batch.multimesh.instance_count != expected_transforms.size()
			or batch.multimesh.buffer != _encode_multimesh_transforms(expected_transforms)
			or authored_transforms != expected_transforms
			or not bool(batch.get_meta("guide_lens_batch", false))
		):
			errors.append("guide_lens_batch_recipe_or_transform_drift")
		child_node_count += batch.get_child_count()
	for light in lights:
		if light.get_script() != null:
			scripted_node_count += 1
		child_node_count += light.get_child_count()
		for child in light.get_children():
			if child.get_script() != null:
				scripted_node_count += 1
			if child is CollisionObject3D or child is NavigationRegion3D:
				authority_node_count += 1

	if lenses.size() != GUIDE_LENS_EXPECTED_COUNT:
		errors.append("guide_lens_node_count_drift")
	if lights.size() != GUIDE_LENS_EXPECTED_COUNT:
		errors.append("guide_light_node_count_drift")
	if _guide_lens_batches.size() != GUIDE_LENS_BATCH_COUNT:
		errors.append("guide_lens_batch_count_drift")
	if mesh_ids.size() != 1 or not is_instance_valid(_guide_lens_mesh):
		errors.append("guide_lens_mesh_identity_not_shared")
	if material_ids.size() != GUIDE_LENS_EXPECTED_RECIPE_COUNT \
		or _guide_lens_material_cache.size() != GUIDE_LENS_EXPECTED_RECIPE_COUNT:
		errors.append("guide_lens_material_identity_count_drift")
	if color_counts != GUIDE_LENS_COLOR_COUNTS:
		errors.append("guide_lens_color_roster_drift")
	if not _guide_lens_mesh_matches_recipe(_guide_lens_mesh):
		errors.append("guide_lens_mesh_recipe_drift")
	for color_variant in _guide_lens_material_cache:
		var color := color_variant as Color
		var material := _guide_lens_material_cache[color_variant] as StandardMaterial3D
		if not _guide_lens_material_matches_recipe(material, color):
			errors.append("guide_lens_material_recipe_drift")
			break

	for light in lights:
		var lens: Marker3D = null
		if light.get_index() > 0:
			lens = light.get_parent().get_child(light.get_index() - 1) as Marker3D
		if (
			lens == null
			or not is_ancestor_of(lens)
			or not is_ancestor_of(light)
			or not lens.position.is_equal_approx(light.position)
			or not (lens.get_meta("guide_lens_color", Color.TRANSPARENT) as Color).is_equal_approx(
				light.light_color
			)
		):
			errors.append("guide_light_pair_or_resource_identity_drift")
			break

	var behavior_rows := _guide_light_behavior_rows(lights)
	var behavior_fingerprint := JSON.stringify(behavior_rows).sha256_text()
	if behavior_fingerprint != GUIDE_LIGHT_BEHAVIOR_FINGERPRINT:
		errors.append("guide_light_behavior_drift")
	if structural_submissions != GUIDE_LENS_BATCHED_SUBMISSIONS:
		errors.append("guide_lens_submission_count_drift")
	if drawn_copies != GUIDE_LENS_EXPECTED_COUNT:
		errors.append("guide_lens_copy_count_drift")
	if authority_node_count != 0 or scripted_node_count != 0 or child_node_count != 0:
		errors.append("guide_light_stock_gained_authority_or_lifecycle_children")

	var retained_resource_count := mesh_ids.size() + material_ids.size()
	var scope_node_count := lenses.size() + lights.size() + _guide_lens_batches.size()
	var upper_operations := get_node_or_null("UpperOperations") as Node3D
	var upper_operations_lens_count := 0
	if upper_operations != null:
		for lens in lenses:
			if upper_operations.is_ancestor_of(lens):
				upper_operations_lens_count += 1
	if upper_operations_lens_count != 1:
		errors.append("upper_operations_guide_lens_roster_drift")
	var batch_instance_counts := {}
	for color_variant in _guide_lens_batches:
		var batch := _guide_lens_batches[color_variant] as MultiMeshInstance3D
		batch_instance_counts[str(color_variant)] = (
			batch.multimesh.instance_count if is_instance_valid(batch) and batch.multimesh != null else -1
		)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"shipyard_world_childless_guide_light_stock",
		"upper_operations_lens_count": upper_operations_lens_count,
		"lens_node_count": lenses.size(),
		"light_node_count": lights.size(),
		"scope_node_count": scope_node_count,
		"baseline_scope_node_count": GUIDE_LENS_BASELINE_SCOPE_NODES,
		"node_delta": scope_node_count - GUIDE_LENS_BASELINE_SCOPE_NODES,
		"renderer_node_count": _guide_lens_batches.size(),
		"baseline_renderer_node_count": GUIDE_LENS_EXPECTED_COUNT,
		"renderer_node_delta": _guide_lens_batches.size() - GUIDE_LENS_EXPECTED_COUNT,
		"structural_submission_count": structural_submissions,
		"baseline_structural_submission_count": GUIDE_LENS_BASELINE_SUBMISSIONS,
		"submission_delta": structural_submissions - GUIDE_LENS_BASELINE_SUBMISSIONS,
		"drawn_copy_count": drawn_copies,
		"baseline_drawn_copy_count": GUIDE_LENS_EXPECTED_COUNT,
		"drawn_copy_delta": drawn_copies - GUIDE_LENS_EXPECTED_COUNT,
		"batch_instance_counts": batch_instance_counts,
		"mesh_resource_identity_count": mesh_ids.size(),
		"material_resource_identity_count": material_ids.size(),
		"retained_visual_resource_identity_count": retained_resource_count,
		"baseline_retained_visual_resource_identity_count": GUIDE_LENS_BASELINE_RETAINED_RESOURCES,
		"retained_visual_resource_identity_delta": retained_resource_count - GUIDE_LENS_BASELINE_RETAINED_RESOURCES,
		"color_counts": color_counts.duplicate(true),
		"behavior_fingerprint": behavior_fingerprint,
		"behavior_fingerprint_matches_baseline": behavior_fingerprint == GUIDE_LIGHT_BEHAVIOR_FINGERPRINT,
		"authority_node_count": authority_node_count,
		"scripted_node_count": scripted_node_count,
		"child_node_count": child_node_count,
		"before": {
			"scope_nodes": GUIDE_LENS_BASELINE_SCOPE_NODES,
			"renderer_nodes": GUIDE_LENS_EXPECTED_COUNT,
			"structural_submissions": GUIDE_LENS_BASELINE_SUBMISSIONS,
			"drawn_copies": GUIDE_LENS_EXPECTED_COUNT,
			"retained_visual_resources": 5,
		},
		"current": {
			"scope_nodes": scope_node_count,
			"renderer_nodes": _guide_lens_batches.size(),
			"structural_submissions": structural_submissions,
			"drawn_copies": drawn_copies,
			"retained_visual_resources": retained_resource_count,
		},
		"batched": true,
		"frame_time_claimed": false,
		"gpu_draw_call_claimed": false,
	}


## Allocation-only proof for the three visual DockMast collars. Masts retain
## their separate collision bodies, route clearance, lights, and lifecycle.
func get_dock_mast_collar_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var collars: Array[MeshInstance3D] = []
	var mesh_ids := {}
	var material_ids := {}
	var authority_nodes := 0
	for raw_node in find_children("*", "MeshInstance3D", true, false):
		var collar := raw_node as MeshInstance3D
		var is_authored_position := false
		for expected_position in DOCK_MAST_COLLAR_POSITIONS:
			if collar.position.is_equal_approx(expected_position as Vector3):
				is_authored_position = true
				break
		if not is_authored_position or collar.material_override != _materials.get("orange"):
			continue
		collars.append(collar)
		if collar.mesh != null:
			mesh_ids[collar.mesh.get_instance_id()] = true
		if collar.material_override != null:
			material_ids[collar.material_override.get_instance_id()] = true
		var index := collars.size() - 1
		if collar.mesh != _dock_mast_collar_mesh:
			errors.append("dock_mast_collar_mesh_identity_not_shared")
		if index >= DOCK_MAST_COLLAR_POSITIONS.size() \
				or not collar.position.is_equal_approx(DOCK_MAST_COLLAR_POSITIONS[index] as Vector3) \
				or not collar.rotation.is_equal_approx(Vector3.ZERO) \
				or collar.scale != Vector3.ONE \
				or collar.material_override != _materials.get("orange") \
				or not collar.visible \
				or collar.get_child_count() != 0 \
				or collar.get_script() != null \
				or not collar.get_groups().is_empty():
			errors.append("dock_mast_collar_visual_or_authority_drift")
		authority_nodes += collar.find_children("*", "CollisionObject3D", true, false).size()
		authority_nodes += collar.find_children("*", "CollisionShape3D", true, false).size()
	if collars.size() != DOCK_MAST_COLLAR_COPY_COUNT:
		errors.append("dock_mast_collar_copy_count_drift")
	if mesh_ids.size() != 1:
		errors.append("dock_mast_collar_mesh_identity_not_shared")
	if material_ids.size() != 1:
		errors.append("dock_mast_collar_material_identity_drift")
	if authority_nodes != 0:
		errors.append("dock_mast_collar_gained_collision_authority")
	var normalised := _dock_mast_collar_mesh != null and _dock_mast_collar_mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
	var expected_live_tessellation := Vector2i(DOCK_MAST_COLLAR_BUDGETED_RINGS, DOCK_MAST_COLLAR_BUDGETED_RING_SEGMENTS) if normalised else Vector2i(DOCK_MAST_COLLAR_RINGS, DOCK_MAST_COLLAR_RING_SEGMENTS)
	if _dock_mast_collar_mesh == null \
			or not is_equal_approx(_dock_mast_collar_mesh.inner_radius, DOCK_MAST_COLLAR_INNER_RADIUS) \
			or not is_equal_approx(_dock_mast_collar_mesh.outer_radius, DOCK_MAST_COLLAR_OUTER_RADIUS) \
			or _dock_mast_collar_mesh.rings != expected_live_tessellation.x \
			or _dock_mast_collar_mesh.ring_segments != expected_live_tessellation.y \
			or (normalised and _dock_mast_collar_mesh.get_meta(TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO) != Vector2i(DOCK_MAST_COLLAR_RINGS, DOCK_MAST_COLLAR_RING_SEGMENTS)) \
			or _dock_mast_collar_mesh.get_surface_count() != 1:
		errors.append("dock_mast_collar_mesh_recipe_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"legacy": {"visual_nodes": 3, "drawn_copies": 3, "surface_submissions": 3, "mesh_resource_allocations": 3, "material_resource_allocations": 1},
		"current": {"visual_nodes": collars.size(), "drawn_copies": collars.size(), "surface_submissions": collars.size(), "mesh_resource_allocations": mesh_ids.size(), "material_resource_allocations": material_ids.size()},
		"reductions": {"visual_nodes": 0, "drawn_copies": 0, "surface_submissions": 0, "mesh_resource_allocations": 2, "material_resource_allocations": 0},
		"collision_authority_count": authority_nodes,
		"mesh_recipe": {
			"inner_radius": _dock_mast_collar_mesh.inner_radius if _dock_mast_collar_mesh != null else 0.0,
			"outer_radius": _dock_mast_collar_mesh.outer_radius if _dock_mast_collar_mesh != null else 0.0,
			"rings": _dock_mast_collar_mesh.rings if _dock_mast_collar_mesh != null else 0,
			"ring_segments": _dock_mast_collar_mesh.ring_segments if _dock_mast_collar_mesh != null else 0,
		},
		"authored_tessellation": _dock_mast_collar_mesh.get_meta(TorusGeometryBudget.AUTHORED_META, Vector2i(DOCK_MAST_COLLAR_RINGS, DOCK_MAST_COLLAR_RING_SEGMENTS)) if _dock_mast_collar_mesh != null else Vector2i.ZERO,
		"live_tessellation": Vector2i(_dock_mast_collar_mesh.rings, _dock_mast_collar_mesh.ring_segments) if _dock_mast_collar_mesh != null else Vector2i.ZERO,
		"normalised": normalised,
		"batched": false,
	}.duplicate(true)


func get_tie_down_socket_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var meshes := {}
	var details := get_node_or_null(^"LandingPad/IntegratedDeckServices") as Node
	var sockets: Array[MeshInstance3D] = []
	if details != null:
		for child in details.get_children():
			var socket := child as MeshInstance3D
			if socket != null and bool(socket.get_meta("flush_deck_detail", false)):
				sockets.append(socket)
	for raw_socket in sockets:
		var socket := raw_socket as MeshInstance3D
		var mesh := socket.mesh as TorusMesh
		if mesh == null:
			errors.append("tie_down_socket_mesh_missing")
			continue
		meshes[mesh.get_instance_id()] = true
		if mesh != _tie_down_socket_mesh:
			errors.append("tie_down_socket_mesh_identity_drift")
		var authored_tessellation := mesh.get_meta(TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO) as Vector2i
		var budgeted_tessellation := TorusGeometryBudget.plan(mesh.outer_radius, mesh.inner_radius)
		var is_unbudgeted_authored_recipe := not mesh.has_meta(TorusGeometryBudget.AUTHORED_META) \
				and mesh.rings == 64 and mesh.ring_segments == 16
		var is_budgeted_authored_recipe := authored_tessellation == Vector2i(64, 16) \
				and mesh.rings == int(budgeted_tessellation.rings) \
				and mesh.ring_segments == int(budgeted_tessellation.ring_segments)
		if not is_equal_approx(mesh.inner_radius, 0.16) \
				or not is_equal_approx(mesh.outer_radius, 0.25) \
				or not (is_unbudgeted_authored_recipe or is_budgeted_authored_recipe):
			errors.append("tie_down_socket_recipe_drift")
		if socket.material_override != _materials.get("steel_blue") or not bool(socket.get_meta("flush_deck_detail", false)) or not socket.find_children("*", "CollisionObject3D", true, false).is_empty():
			errors.append("tie_down_socket_presentation_or_authority_drift")
	if sockets.size() != 6:
		errors.append("tie_down_socket_copy_count_drift")
	if meshes.size() != 1:
		errors.append("tie_down_socket_mesh_count_drift")
	errors.sort()
	return {"valid": errors.is_empty(), "errors": errors, "copies": sockets.size(), "mesh_resource_allocations": meshes.size()}.duplicate(true)


## Renderer-independent allocation audit for one LandingPad-local visual family.
##
## "Submission" is a structural mesh-surface count, not a driver draw-call
## claim. The three childless connector nodes retain one surface each; this
## report proves only that their identical TorusMesh allocation is shared.
func get_landing_pad_deck_connector_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var connector_nodes: Array[MeshInstance3D] = []
	var behavior_rows: Array[Dictionary] = []
	var mesh_ids: Dictionary = {}
	var material_ids: Dictionary = {}
	var structural_submissions := 0
	var authority_node_count := 0
	var scripted_node_count := 0
	var child_node_count := 0
	var metadata_entry_count := 0
	var processing_node_count := 0
	var utility_bay := get_node_or_null(
		^"LandingPad/StarboardUtilityBay"
	) as Node3D
	var discovered_connector_count := 0
	if utility_bay != null:
		discovered_connector_count = utility_bay.find_children(
			"DeckConnector", "MeshInstance3D", true, false
		).size()

	for index in LANDING_PAD_DECK_CONNECTOR_PATHS.size():
		var connector_path: NodePath = LANDING_PAD_DECK_CONNECTOR_PATHS[index]
		var expected_position: Vector3 = LANDING_PAD_DECK_CONNECTOR_POSITIONS[index]
		var connector := get_node_or_null(connector_path) as MeshInstance3D
		if connector == null:
			errors.append("deck_connector_missing:%s" % String(connector_path))
			continue
		connector_nodes.append(connector)
		if connector.mesh != null:
			mesh_ids[connector.mesh.get_instance_id()] = true
			structural_submissions += connector.mesh.get_surface_count()
		if connector.material_override != null:
			material_ids[connector.material_override.get_instance_id()] = true
		if (
			not connector.position.is_equal_approx(expected_position)
			or not connector.rotation.is_equal_approx(Vector3.ZERO)
			or not connector.scale.is_equal_approx(Vector3.ONE)
			or not connector.visible
			or connector.layers != 1
			or connector.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		):
			errors.append("deck_connector_visual_transform_or_visibility_drift")
		if connector.mesh != _landing_pad_deck_connector_mesh:
			errors.append("deck_connector_mesh_identity_not_shared")
		if connector.material_override != _materials.get("black"):
			errors.append("deck_connector_material_identity_drift")
		if connector.get_script() != null:
			scripted_node_count += 1
		metadata_entry_count += connector.get_meta_list().size()
		if connector.is_processing() or connector.is_physics_processing():
			processing_node_count += 1
		child_node_count += connector.get_child_count()
		for child in connector.find_children("*", "Node", true, false):
			if child.get_script() != null:
				scripted_node_count += 1
			if (
				child is CollisionObject3D
				or child is CollisionShape3D
				or child is NavigationRegion3D
				or child is Light3D
				or child is AudioStreamPlayer
				or child is AudioStreamPlayer3D
				or child is Camera3D
			):
				authority_node_count += 1
		behavior_rows.append({
			"path": String(connector_path),
			"position": [connector.position.x, connector.position.y, connector.position.z],
			"rotation_degrees": [
				connector.rotation_degrees.x,
				connector.rotation_degrees.y,
				connector.rotation_degrees.z,
			],
			"scale": [connector.scale.x, connector.scale.y, connector.scale.z],
			"material": "black",
		})

	var mesh := _landing_pad_deck_connector_mesh
	var authored_value: Variant = mesh.get_meta(
		"torus_budget_authored_tessellation", Vector2i.ZERO
	) if mesh != null else Vector2i.ZERO
	var authored_segments := Vector2i.ZERO
	if authored_value is Vector2i:
		authored_segments = authored_value
	if (
		mesh == null
		or not is_equal_approx(mesh.inner_radius, LANDING_PAD_DECK_CONNECTOR_INNER_RADIUS)
		or not is_equal_approx(mesh.outer_radius, LANDING_PAD_DECK_CONNECTOR_OUTER_RADIUS)
		or mesh.rings != LANDING_PAD_DECK_CONNECTOR_BUDGETED_RINGS
		or mesh.ring_segments != LANDING_PAD_DECK_CONNECTOR_BUDGETED_RING_SEGMENTS
		or authored_segments != Vector2i(
			LANDING_PAD_DECK_CONNECTOR_AUTHORED_RINGS,
			LANDING_PAD_DECK_CONNECTOR_AUTHORED_RING_SEGMENTS
		)
		or mesh.get_surface_count() != 1
	):
		errors.append("deck_connector_mesh_recipe_drift")
	if connector_nodes.size() != LANDING_PAD_DECK_CONNECTOR_BASELINE_NODES:
		errors.append("deck_connector_node_count_drift")
	if discovered_connector_count != LANDING_PAD_DECK_CONNECTOR_BASELINE_NODES:
		errors.append("deck_connector_local_roster_drift")
	if mesh_ids.size() != 1:
		errors.append("deck_connector_mesh_identity_count_drift")
	if material_ids.size() != 1:
		errors.append("deck_connector_material_identity_count_drift")
	if structural_submissions != LANDING_PAD_DECK_CONNECTOR_BASELINE_SUBMISSIONS:
		errors.append("deck_connector_submission_count_drift")
	if (
		authority_node_count != 0
		or scripted_node_count != 0
		or child_node_count != 0
		or metadata_entry_count != 0
		or processing_node_count != 0
	):
		errors.append("deck_connector_stock_gained_authority_or_lifecycle_children")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"landing_pad_parked_umbilical_deck_connectors",
		"node_count": connector_nodes.size(),
		"discovered_connector_count": discovered_connector_count,
		"baseline_node_count": LANDING_PAD_DECK_CONNECTOR_BASELINE_NODES,
		"node_delta": connector_nodes.size() - LANDING_PAD_DECK_CONNECTOR_BASELINE_NODES,
		"drawn_copy_count": connector_nodes.size(),
		"structural_submission_count": structural_submissions,
		"baseline_structural_submission_count": LANDING_PAD_DECK_CONNECTOR_BASELINE_SUBMISSIONS,
		"submission_delta": structural_submissions - LANDING_PAD_DECK_CONNECTOR_BASELINE_SUBMISSIONS,
		"mesh_resource_identity_count": mesh_ids.size(),
		"baseline_mesh_resource_identity_count": LANDING_PAD_DECK_CONNECTOR_BASELINE_MESH_RESOURCES,
		"mesh_resource_identity_delta": mesh_ids.size() - LANDING_PAD_DECK_CONNECTOR_BASELINE_MESH_RESOURCES,
		"material_resource_identity_count": material_ids.size(),
		"baseline_material_resource_identity_count": 1,
		"material_resource_identity_delta": material_ids.size() - 1,
		"mesh_recipe": {
			"inner_radius": mesh.inner_radius if mesh != null else -1.0,
			"outer_radius": mesh.outer_radius if mesh != null else -1.0,
			"rings": mesh.rings if mesh != null else -1,
			"ring_segments": mesh.ring_segments if mesh != null else -1,
			"authored_rings": authored_segments.x,
			"authored_ring_segments": authored_segments.y,
			"surface_count": mesh.get_surface_count() if mesh != null else 0,
		},
		"behavior_rows": behavior_rows,
		"authority_node_count": authority_node_count,
		"scripted_node_count": scripted_node_count,
		"child_node_count": child_node_count,
		"metadata_entry_count": metadata_entry_count,
		"processing_node_count": processing_node_count,
		"batched": false,
		"frame_time_claimed": false,
		"gpu_draw_call_claimed": false,
		"vram_claimed": false,
		"whole_scene_budget_claimed": false,
	}.duplicate(true)


## Renderer-independent allocation audit for the four ExteriorTargetRange cores.
##
## "Submission" is a structural mesh-surface count, not a driver draw-call
## claim. The four named childless MeshInstance3D nodes retain one surface each;
## this report proves only that their exact SphereMesh allocation is shared.
func get_exterior_target_core_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var core_nodes: Array[MeshInstance3D] = []
	var behavior_rows: Array[Dictionary] = []
	var mesh_ids: Dictionary = {}
	var material_ids: Dictionary = {}
	var structural_submissions := 0
	var authority_node_count := 0
	var scripted_node_count := 0
	var child_node_count := 0
	var metadata_entry_count := 0
	var processing_node_count := 0
	var exterior := get_node_or_null(^"ExteriorTargetRange") as Node3D
	var discovered_core_count := 0
	if exterior != null:
		discovered_core_count = exterior.find_children(
			"Core", "MeshInstance3D", true, false
		).size()

	for core_path: NodePath in EXTERIOR_TARGET_CORE_PATHS:
		var core := get_node_or_null(core_path) as MeshInstance3D
		if core == null:
			errors.append("target_core_missing:%s" % String(core_path))
			continue
		core_nodes.append(core)
		if core.mesh != null:
			mesh_ids[core.mesh.get_instance_id()] = true
			structural_submissions += core.mesh.get_surface_count()
		if core.material_override != null:
			material_ids[core.material_override.get_instance_id()] = true
		if core.mesh != _exterior_target_core_mesh:
			errors.append("target_core_mesh_identity_not_shared")
		if core.material_override != _materials.get("orange_glow"):
			errors.append("target_core_material_identity_drift")
		if (
			not core.position.is_equal_approx(Vector3.ZERO)
			or not core.rotation.is_equal_approx(Vector3.ZERO)
			or not core.scale.is_equal_approx(Vector3.ONE)
			or not core.visible
			or core.layers != 1
			or core.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		):
			errors.append("target_core_visual_transform_or_visibility_drift")
		if core.get_script() != null:
			scripted_node_count += 1
		metadata_entry_count += core.get_meta_list().size()
		if core.is_processing() or core.is_physics_processing():
			processing_node_count += 1
		child_node_count += core.get_child_count()
		for child in core.find_children("*", "Node", true, false):
			if child.get_script() != null:
				scripted_node_count += 1
			if (
				child is CollisionObject3D
				or child is CollisionShape3D
				or child is NavigationRegion3D
				or child is Light3D
				or child is AudioStreamPlayer
				or child is AudioStreamPlayer3D
				or child is Camera3D
			):
				authority_node_count += 1
		behavior_rows.append({
			"path": String(core_path),
			"position": [core.position.x, core.position.y, core.position.z],
			"rotation_degrees": [
				core.rotation_degrees.x,
				core.rotation_degrees.y,
				core.rotation_degrees.z,
			],
			"scale": [core.scale.x, core.scale.y, core.scale.z],
			"visible": core.visible,
			"layers": core.layers,
			"cast_shadow": core.cast_shadow,
			"material": "orange_glow",
		})

	var mesh := _exterior_target_core_mesh
	if (
		mesh == null
		or not is_equal_approx(mesh.radius, EXTERIOR_TARGET_CORE_RADIUS)
		or not is_equal_approx(mesh.height, EXTERIOR_TARGET_CORE_HEIGHT)
		or mesh.radial_segments != EXTERIOR_TARGET_CORE_RADIAL_SEGMENTS
		or mesh.rings != EXTERIOR_TARGET_CORE_RINGS
		or mesh.get_surface_count() != 1
	):
		errors.append("target_core_mesh_recipe_drift")
	var material := _materials.get("orange_glow") as StandardMaterial3D
	if not _exterior_target_core_material_matches_recipe(material):
		errors.append("target_core_material_recipe_drift")
	if core_nodes.size() != EXTERIOR_TARGET_CORE_BASELINE_NODES:
		errors.append("target_core_node_count_drift")
	if discovered_core_count != EXTERIOR_TARGET_CORE_BASELINE_NODES:
		errors.append("target_core_local_roster_drift")
	if mesh_ids.size() != 1:
		errors.append("target_core_mesh_identity_count_drift")
	if material_ids.size() != 1:
		errors.append("target_core_material_identity_count_drift")
	if structural_submissions != EXTERIOR_TARGET_CORE_BASELINE_SUBMISSIONS:
		errors.append("target_core_submission_count_drift")
	if (
		authority_node_count != 0
		or scripted_node_count != 0
		or child_node_count != 0
		or metadata_entry_count != 0
		or processing_node_count != 0
	):
		errors.append("target_core_stock_gained_authority_or_lifecycle_children")

	var retained_resource_count := mesh_ids.size() + material_ids.size()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"exterior_target_range_childless_target_cores",
		"node_count": core_nodes.size(),
		"discovered_core_count": discovered_core_count,
		"baseline_node_count": EXTERIOR_TARGET_CORE_BASELINE_NODES,
		"node_delta": core_nodes.size() - EXTERIOR_TARGET_CORE_BASELINE_NODES,
		"drawn_copy_count": core_nodes.size(),
		"structural_submission_count": structural_submissions,
		"baseline_structural_submission_count": EXTERIOR_TARGET_CORE_BASELINE_SUBMISSIONS,
		"submission_delta": structural_submissions - EXTERIOR_TARGET_CORE_BASELINE_SUBMISSIONS,
		"mesh_resource_identity_count": mesh_ids.size(),
		"baseline_mesh_resource_identity_count": EXTERIOR_TARGET_CORE_BASELINE_MESH_RESOURCES,
		"mesh_resource_identity_delta": mesh_ids.size() - EXTERIOR_TARGET_CORE_BASELINE_MESH_RESOURCES,
		"material_resource_identity_count": material_ids.size(),
		"baseline_material_resource_identity_count": 1,
		"material_resource_identity_delta": material_ids.size() - 1,
		"retained_visual_resource_identity_count": retained_resource_count,
		"baseline_retained_visual_resource_identity_count": EXTERIOR_TARGET_CORE_BASELINE_MESH_RESOURCES + 1,
		"retained_visual_resource_identity_delta": retained_resource_count - (EXTERIOR_TARGET_CORE_BASELINE_MESH_RESOURCES + 1),
		"mesh_recipe": {
			"radius": mesh.radius if mesh != null else -1.0,
			"height": mesh.height if mesh != null else -1.0,
			"radial_segments": mesh.radial_segments if mesh != null else -1,
			"rings": mesh.rings if mesh != null else -1,
			"surface_count": mesh.get_surface_count() if mesh != null else 0,
		},
		"behavior_rows": behavior_rows,
		"authority_node_count": authority_node_count,
		"scripted_node_count": scripted_node_count,
		"child_node_count": child_node_count,
		"metadata_entry_count": metadata_entry_count,
		"processing_node_count": processing_node_count,
		"authority_exclusions": {
			"owns_target_registration": false,
			"owns_collision": false,
			"owns_combat_or_damage": false,
			"owns_movement": false,
			"owns_lifecycle": false,
			"owns_launch_clearance_or_cues": false,
			"owns_evidence": false,
		},
		"batched": false,
		"frame_time_claimed": false,
		"gpu_draw_call_claimed": false,
		"vram_claimed": false,
		"whole_scene_budget_claimed": false,
	}.duplicate(true)


func _exterior_target_core_material_matches_recipe(material: StandardMaterial3D) -> bool:
	return (
		material != null
		and material.albedo_color.is_equal_approx(KETH_ORANGE)
		and is_equal_approx(material.metallic, 0.04)
		and is_equal_approx(material.roughness, 0.34)
		and material.emission_enabled
		and material.emission.is_equal_approx(KETH_ORANGE)
		and is_equal_approx(material.emission_energy_multiplier, 1.8)
		and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
		and material.diffuse_mode == BaseMaterial3D.DIFFUSE_BURLEY
		and material.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX
	)


func _guide_light_behavior_rows(lights: Array[OmniLight3D]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for light in lights:
		rows.append({
			"path": _stable_guide_node_path(self, light),
			"position": [light.position.x, light.position.y, light.position.z],
			"color": light.light_color.to_html(true),
			# Pulsing lights legitimately animate `light_energy`; their authored
			# behavior is the immutable base, not the sampled animation phase.
			"energy": float(light.get_meta("base_energy", light.light_energy)),
			"range": light.omni_range,
			"shadow": light.shadow_enabled,
			"pulsing": light.has_meta("pulse_phase"),
			"pulse_phase": float(light.get_meta("pulse_phase", -1.0)),
			"base_energy": float(light.get_meta("base_energy", -1.0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.path) < str(b.path))
	return rows


## Godot's fallback `@Class@instance` names contain process-local counters. A
## module that creates unrelated nodes before this world builds can therefore
## change those names without changing this guide stock. Canonicalize only the
## fallback segments to same-class sibling ordinals; explicit authored names
## stay byte-exact. This mirrors the station light census policy locally without
## making production code depend on a tool script.
static func _stable_guide_node_path(scene_root: Node, node: Node) -> String:
	if node == scene_root:
		return "."
	var segments := PackedStringArray()
	var cursor := node
	while cursor != null and cursor != scene_root:
		segments.append(_stable_guide_sibling_segment(cursor))
		cursor = cursor.get_parent()
	if cursor != scene_root:
		return "<outside-scene>/%s" % "/".join(segments)
	segments.reverse()
	return "/".join(segments)


static func _stable_guide_sibling_segment(node: Node) -> String:
	var runtime_name := str(node.name)
	if not runtime_name.begins_with("@"):
		return runtime_name
	var parent := node.get_parent()
	if parent == null:
		return "%s[01]" % node.get_class()
	var ordinal := 0
	for sibling in parent.get_children():
		if sibling.get_class() == node.get_class() and str(sibling.name).begins_with("@"):
			ordinal += 1
		if sibling == node:
			break
	return "%s[%02d]" % [node.get_class(), ordinal]


func _guide_lens_mesh_matches_recipe(mesh: SphereMesh) -> bool:
	return (
		mesh != null
		and is_equal_approx(mesh.radius, GUIDE_LENS_RADIUS)
		and is_equal_approx(mesh.height, GUIDE_LENS_HEIGHT)
		and mesh.radial_segments == GUIDE_LENS_RADIAL_SEGMENTS
		and mesh.rings == GUIDE_LENS_RINGS
	)


func _guide_lens_material_matches_recipe(material: StandardMaterial3D, color: Color) -> bool:
	return (
		material != null
		and material.albedo_color.is_equal_approx(color)
		and is_zero_approx(material.metallic)
		and is_equal_approx(material.roughness, 0.25)
		and material.emission_enabled
		and material.emission.is_equal_approx(color)
		and is_equal_approx(material.emission_energy_multiplier, 1.35)
		and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
		and material.diffuse_mode == BaseMaterial3D.DIFFUSE_BURLEY
		and material.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX
	)


## Fixed-era-inspired habitat insertion at the starboard physical node. The
## component's own evidence report records that its exact plan and adjacency
## are modern interpretation, not recovered original station geometry.
func get_habitat_spine() -> HabitatSpine:
	return habitat_spine


func get_jovian_freight_berth() -> JovianFreightBerth:
	return jovian_freight_berth


func get_station_defense_content() -> StationDefenseEncounterContent:
	return _station_defense_content if is_instance_valid(_station_defense_content) else null


func get_station_defense_activity_board() -> Area3D:
	return (
		_station_defense_activity_board
		if is_instance_valid(_station_defense_activity_board) else null
	)


func get_heavy_breach_activity_board() -> Area3D:
	return (
		_heavy_breach_activity_board
		if is_instance_valid(_heavy_breach_activity_board) else null
	)


func get_heavy_breach_protected_objective() -> Node3D:
	return (
		_heavy_breach_protected_objective
		if is_instance_valid(_heavy_breach_protected_objective) else null
	)


## The one diegetic adapter for the shared sortie-selection board.  Its parent
## console remains part of the authored Aft Operations room; this accessor only
## exposes the live interaction node to the production coordinator.
func get_activity_board_console() -> Area3D:
	var console := get_node_or_null(
		^"AftJunctionStack/Structure/OperationsRoom/ConsoleBay02/ActivityBoardConsole"
	) as Area3D
	return console if is_instance_valid(console) else null


## Binds the caller-owned reward sink to the board's shared nearby-activity
## adapter. ShipyardWorld never grants or persists the reward itself.
func configure_station_defense_reward_handoff(callback: Callable) -> Dictionary:
	if not is_instance_valid(_station_defense_activity_board):
		return {"accepted": false, "reason": &"station_defense_board_unavailable"}
	return _station_defense_activity_board.call("configure_reward_handoff", callback)


func configure_heavy_breach_reward_handoff(callback: Callable) -> Dictionary:
	if not is_instance_valid(_heavy_breach_activity_board):
		return {"accepted": false, "reason": &"heavy_breach_board_unavailable"}
	return _heavy_breach_activity_board.call("configure_reward_handoff", callback)


func configure_station_defense_session_persistence(
		store: RefCounted,
		slot_id: StringName
	) -> bool:
	return is_instance_valid(_station_defense_activity_board) and bool(
		_station_defense_activity_board.call(
			"configure_session_persistence", store, slot_id
		)
	)


func save_station_defense_session(
		expected_store_generation: int,
		commit_id: String
	) -> Dictionary:
	if not is_instance_valid(_station_defense_activity_board):
		return {"accepted": false, "reason": &"station_defense_board_unavailable"}
	return _station_defense_activity_board.call(
		"save_session", expected_store_generation, commit_id
	)


func load_station_defense_session() -> Dictionary:
	if not is_instance_valid(_station_defense_activity_board):
		return {"accepted": false, "reason": &"station_defense_board_unavailable"}
	return _station_defense_activity_board.call("load_session")


## Resolves the currently committed, coordinator-owned Cinder instance without
## caching a Node across streaming generations. The cluster is intentionally
## absent at station start and after return travel, so callers must handle null.
## Its authored coordinates are station-world coordinates and the coordinator
## mounts its root at identity. It owns no gameplay authority and adds no range
## targets, so `get_target_count()` and the guided mission are unaffected.
func get_nearby_sector_cluster() -> NearbySectorCluster:
	var host := get_parent()
	if host == null:
		return null
	var bootstrap := host.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	if not is_instance_valid(bootstrap):
		return null
	return bootstrap.get_loaded_instance() as NearbySectorCluster


func get_nearby_sector_cluster_audit_report() -> Dictionary:
	var cluster := get_nearby_sector_cluster()
	if not is_instance_valid(cluster):
		return {
			"valid": false,
			"available": false,
			"reason": &"streamed_cluster_unavailable",
			"errors": PackedStringArray([
				"nearby sector cluster is not currently loaded"
			]),
			"streaming_owned": true,
		}.duplicate(true)
	return cluster.get_cluster_audit_report()


## Source-bounded B2 comb/slab macro correction. Dock 01 records a modern,
## externally owned Zenith assignment; Dock 02 and Dock 03 record externally
## owned Halyard and Bulwark assignments. The component exposes station
## circulation and landmarks, never berth or ship-regeneration authority itself.
func get_fleet_dock_comb() -> FleetDockComb:
	return fleet_dock_comb


## Production-owned composition for the original-modern Dock 04/05/06 craft.
## ShipyardWorld owns placement only; flight, landing, damage, and berth
## contracts remain on the composed craft and FleetExpansionBerths node.
func get_fleet_expansion_production_binding() -> FleetExpansionProductionBinding:
	return _fleet_expansion_production_binding as FleetExpansionProductionBinding


func get_fleet_expansion_production_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var binding := get_fleet_expansion_production_binding()
	if binding == null or binding.get_parent() != self:
		errors.append("fleet expansion production binding is missing from ShipyardWorld")
	var component_audit: Dictionary = binding.get_audit_report() if binding != null else {}
	if not bool(component_audit.get("valid", false)):
		errors.append("fleet expansion production binding audit failed")
	var snapshot: Dictionary = binding.get_fleet_snapshot() if binding != null else {}
	var craft_rows := snapshot.get("craft", []) as Array
	if craft_rows.size() != 3:
		errors.append("Dock 04/05/06 must publish exactly three composed craft")
	return {
		"schema_version": 1,
		"valid": errors.is_empty(),
		"errors": errors,
		"binding": component_audit.duplicate(true),
		"snapshot": snapshot.duplicate(true),
		"dock_ids": [&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"],
		"shipyard_placement_authority": true,
		"flight_authority": false,
		"berth_lease_authority": false,
	}.duplicate(true)


## Integration-only audit for the authored modern placement and its narrow,
## visible collision-backed connector from the existing Aft upper deck.
func get_fleet_dock_comb_integration_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var module_audit := {}
	var assigned_docks: Array[Dictionary] = []
	var deferred_docks: Array[Dictionary] = []
	var expected_berth_origin := Vector3(22.0, 5.28, 53.3)
	var assigned_marker_transform := Transform3D.IDENTITY
	if not is_instance_valid(fleet_dock_comb):
		errors.append("fleet dock comb instance is missing")
	else:
		module_audit = fleet_dock_comb.get_audit_report()
		assigned_docks = fleet_dock_comb.get_assigned_dock_roster()
		deferred_docks = fleet_dock_comb.get_deferred_dock_roster()
		if not bool(module_audit.get("valid", false)):
			errors.append("fleet dock comb component audit is invalid")
		var expected_transform := Transform3D(
			Basis(Vector3.UP, PI * 0.5),
			Vector3(12.0, 4.2, 68.3)
		)
		if not fleet_dock_comb.transform.is_equal_approx(expected_transform):
			errors.append("fleet dock comb integration transform drifted")
		if not fleet_dock_comb.find_children("*", "ShipBerth", true, false).is_empty():
			errors.append("fleet dock comb landmark module gained live berth authority")
		# Dock 01 carries the Zenith; dock 02 carries the Halyard and dock 03 the
		# Bulwark, both original modern designs. None of these assignments gives
		# the comb berth authority or makes a historical class-to-berth mapping.
		if assigned_docks.size() != 3:
			errors.append("fleet dock comb must expose exactly three external dock assignments")
		else:
			var expected_assignments := {
				&"assigned-dock-01": {
					"ship": &"zenith_b7_observed",
					"berth": ZENITH_FLEET_DOCK_BERTH_ID,
				},
				&"deferred-dock-02": {
					"ship": &"halyard_new_design",
					"berth": HALYARD_FLEET_DOCK_BERTH_ID,
				},
				&"deferred-dock-03": {
					"ship": &"bulwark_heavy_gunship",
					"berth": BULWARK_FLEET_DOCK_BERTH_ID,
				},
			}
			for assignment in assigned_docks:
				var dock_id: StringName = assignment.get("dock_id", &"")
				if not expected_assignments.has(dock_id):
					errors.append("fleet dock comb published an unexpected dock assignment %s" % dock_id)
					continue
				var expected: Dictionary = expected_assignments[dock_id]
				if assignment.get("ship_assignment", &"") != expected["ship"] \
					or assignment.get("berth_id", &"") != expected["berth"] \
					or bool(assignment.get("owns_berth_authority", true)) \
					or bool(assignment.get("historical_class_to_berth_mapping", true)):
					errors.append("fleet dock %s assignment contract drifted" % dock_id)
				if dock_id == &"assigned-dock-01":
					assigned_marker_transform = assignment.get(
						"marker_transform", Transform3D.IDENTITY
					) as Transform3D
					expected_berth_origin = assigned_marker_transform.origin + Vector3.UP * 0.93
		if not deferred_docks.is_empty():
			errors.append("fleet dock comb must have no deferred empty dock after Bulwark promotion")
	var zenith_berth := get_berth_node(ZENITH_FLEET_DOCK_BERTH_ID)
	if not is_instance_valid(zenith_berth):
		errors.append("world-owned Zenith fleet dock berth is missing")
	else:
		if zenith_berth.get_parent() != self:
			errors.append("Zenith fleet dock berth must remain owned directly by ShipyardWorld")
		if not zenith_berth.global_transform.is_equal_approx(
			Transform3D(Basis.IDENTITY, expected_berth_origin)
		):
			errors.append("Zenith fleet dock berth no longer aligns above assigned dock 01")
		if not zenith_berth.get_landing_half_extents().is_equal_approx(Vector3(8.4, 4.6, 7.4)):
			errors.append("Zenith fleet dock berth strict landing volume drifted")
		if zenith_berth.get_compatibility_tags() != PackedStringArray(["zenith_b7"]):
			errors.append("Zenith fleet dock berth compatibility must remain class-specific")
		if not zenith_berth.get_assist_capture_center().is_equal_approx(Vector3(0.0, 10.0, -18.0)) \
			or not zenith_berth.get_assist_capture_half_extents().is_equal_approx(Vector3(20.0, 14.0, 30.0)) \
			or not is_equal_approx(zenith_berth.get_assist_capture_maximum_speed(), 34.0) \
			or not is_equal_approx(zenith_berth.get_assist_maximum_tilt_degrees(), 75.0):
			errors.append("Zenith fleet dock assist-capture contract drifted")
	var bulwark_berth := get_berth_node(BULWARK_FLEET_DOCK_BERTH_ID)
	if not is_instance_valid(bulwark_berth):
		errors.append("world-owned Bulwark fleet dock berth is missing")
	else:
		if bulwark_berth.get_parent() != self:
			errors.append("Bulwark fleet dock berth must remain owned directly by ShipyardWorld")
		if not bulwark_berth.global_transform.is_equal_approx(
			Transform3D(Basis.IDENTITY, Vector3(52.0, 5.28, 53.3))
		):
			errors.append("Bulwark fleet dock berth no longer aligns above assigned dock 03")
		if bulwark_berth.get_compatibility_tags() != PackedStringArray(["bulwark_gunship"]):
			errors.append("Bulwark fleet dock berth compatibility must remain class-specific")
		if not bulwark_berth.get_landing_half_extents().is_equal_approx(Vector3(6.0, 4.5, 6.4)) \
			or not is_equal_approx(bulwark_berth.get_assist_capture_maximum_speed(), 26.0) \
			or not is_equal_approx(bulwark_berth.get_assist_maximum_tilt_degrees(), 75.0):
			errors.append("Bulwark fleet dock landing/recovery contract drifted")
	var connector := get_node_or_null(^"ExposedDockLattice/FleetDockCombConnector") as Node3D
	if connector == null:
		errors.append("fleet dock comb connector is missing")
	else:
		var floor := connector.get_node_or_null(^"FleetDockCombConnectorDeck") as StaticBody3D
		if floor == null:
			errors.append("fleet dock comb connector floor is missing")
		elif floor.get_node_or_null(^"Collision") == null:
			errors.append("fleet dock comb connector floor lacks collision")
	return {
		"schema_version": 3,
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence_status": &"modern_interpretation",
		"source_claim": &"OE-B2-COMB",
		"placement_authored": true,
		"external_assignment_count": assigned_docks.size(),
		"deferred_empty_dock_count": deferred_docks.size(),
		"historical_class_to_berth_mapping": false,
		"module_transform": fleet_dock_comb.global_transform if is_instance_valid(fleet_dock_comb) else Transform3D.IDENTITY,
		"assigned_marker_transform": assigned_marker_transform,
		"zenith_berth_transform": zenith_berth.global_transform if is_instance_valid(zenith_berth) else Transform3D.IDENTITY,
		"zenith_berth_id": ZENITH_FLEET_DOCK_BERTH_ID,
		"zenith_ship_id": &"zenith_b7_observed",
		"bulwark_berth_transform": bulwark_berth.global_transform if is_instance_valid(bulwark_berth) else Transform3D.IDENTITY,
		"bulwark_berth_id": BULWARK_FLEET_DOCK_BERTH_ID,
		"bulwark_ship_id": &"bulwark_heavy_gunship",
		"connector_local_bounds": AABB(Vector3(-0.25, 3.56, 66.5), Vector3(12.5, 1.94, 3.6)),
		"assigned_docks": assigned_docks.duplicate(true),
		"deferred_docks": deferred_docks.duplicate(true),
		"component": module_audit.duplicate(true),
	}


## Integrated, presentation-only activity components. The returned arrays are
## detached registries; callers can control a component but cannot mutate the
## world's authoritative roster by changing an array.
func get_station_operations_activities() -> Array[StationOperationsActivity]:
	var result: Array[StationOperationsActivity] = []
	for activity in _station_operations_activities:
		if is_instance_valid(activity) and is_ancestor_of(activity):
			result.append(activity)
	return result


## Exact world-owned collision realised from each activity's declaration.
##
## The bodies are siblings rather than children so an activity never owns
## gameplay authority. This audit closes the other half of that boundary: every
## body must follow its declaring component's pose, enabled/tree lifecycle and
## exact ordered `{name, position, size, shape_kind, basis}` contract, with no
## extra body or shape. Optional kind/basis fields default to box/identity.
func get_station_activity_collision_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var collision_root := get_node_or_null(^"OperationalLattice/ActivityCollision") as Node3D
	var activities_root := get_node_or_null(^"OperationalLattice/Activities") as Node3D
	if collision_root == null:
		return {
			"valid": false,
			"errors": PackedStringArray(["station activity collision root is missing"]),
			"body_count": 0,
			"shape_count": 0,
			"expected_body_count": EXPECTED_STATION_ACTIVITY_COLLISION_BODY_COUNT,
			"expected_shape_count": EXPECTED_STATION_ACTIVITY_COLLISION_SHAPE_COUNT,
			"active_body_count": 0,
			"placements": {},
		}.duplicate(true)

	var live_activity_instance_ids := {}
	var ignored_ambience_instance_ids := {}
	var ignored_dressing_instance_ids := {}
	_collect_live_operational_lattice_component_ids(
		self,
		live_activity_instance_ids,
		ignored_ambience_instance_ids,
		ignored_dressing_instance_ids
	)
	var registered_activity_instance_ids := {}
	for activity in _station_operations_activities:
		if is_instance_valid(activity):
			registered_activity_instance_ids[activity.get_instance_id()] = true
	if not _instance_id_sets_match(
		registered_activity_instance_ids, live_activity_instance_ids
	):
		errors.append("station activity collision declarations differ from the live activity hierarchy")

	var expected_body_count := 0
	var expected_shape_count := 0
	var active_body_count := 0
	var placements := {}
	for activity in _station_operations_activities:
		if not is_instance_valid(activity):
			continue
		var volumes := activity.get_solid_volume_contract()
		if volumes.is_empty():
			continue
		expected_body_count += 1
		expected_shape_count += volumes.size()
		var body_name := "%sSolids" % activity.name
		var body := collision_root.get_node_or_null(NodePath(body_name)) as StaticBody3D
		if body == null:
			errors.append("%s has declarations but no world-owned solid body" % activity.name)
			continue
		var activity_live := activity.is_inside_tree()
		var canonically_owned := activities_root != null \
			and activity.get_parent() == activities_root
		if activity_live and not canonically_owned:
			errors.append("%s is outside the canonical station Activities root" % activity.name)
		var expected_active := activity_live and canonically_owned \
			and collision_root.is_inside_tree() and activity.is_activity_enabled()
		var expected_layer := WORLD_LAYER if expected_active else PhysicsLayers.NONE
		if body.collision_layer == WORLD_LAYER:
			active_body_count += 1
		if body.collision_layer != expected_layer or body.collision_mask != PhysicsLayers.NONE:
			errors.append("%s world-owned solid body differs from its declaring lifecycle" % activity.name)
		if activity_live and canonically_owned \
			and not body.global_transform.is_equal_approx(activity.global_transform):
			errors.append("%s world-owned solid body differs from its declaring transform" % activity.name)
		var shapes := body.find_children("*", "CollisionShape3D", true, false)
		if shapes.size() != volumes.size():
			errors.append("%s world-owned solid shape count differs from its declaration" % activity.name)
		else:
			for index in volumes.size():
				var volume := volumes[index] as Dictionary
				var collision := shapes[index] as CollisionShape3D
				var shape_kind := StringName(volume.get("shape_kind", &"box"))
				var expected_basis := volume.get("basis", Basis.IDENTITY) as Basis
				var expected_name := "%s%02d" % [str(volume.name), index + 1]
				if collision.get_parent() != body \
					or collision.name != expected_name \
					or not collision.transform.is_equal_approx(Transform3D(
						expected_basis, volume.position as Vector3
					)) \
					or collision.disabled:
					errors.append("%s world-owned solid %d differs from its declaration" % [activity.name, index])
				elif shape_kind == &"cylinder":
					var cylinder := collision.shape as CylinderShape3D
					if cylinder == null \
						or not is_equal_approx(cylinder.radius, float(volume.radius)) \
						or not is_equal_approx(cylinder.height, float(volume.height)):
						errors.append("%s world-owned cylinder %d differs from its declaration" % [activity.name, index])
				else:
					var box := collision.shape as BoxShape3D
					if shape_kind != &"box" \
						or box == null \
						or not box.size.is_equal_approx(volume.size as Vector3):
						errors.append("%s world-owned box %d differs from its declaration" % [activity.name, index])
		placements[StringName(activity.name)] = {
			"activity_path": activity.get_path() if activity_live else NodePath(),
			"body_path": body.get_path(),
			"body_instance_id": body.get_instance_id(),
			"active": expected_active,
			"shape_count": shapes.size(),
			"transform": body.transform,
		}

	var bodies := collision_root.find_children("*", "StaticBody3D", true, false)
	var actual_shape_count := 0
	var actual_box_count := 0
	var actual_cylinder_count := 0
	for candidate in bodies:
		var candidate_body := candidate as StaticBody3D
		var candidate_shapes := candidate_body.find_children(
			"*", "CollisionShape3D", true, false
		)
		actual_shape_count += candidate_shapes.size()
		for shape_candidate in candidate_shapes:
			var realised_shape := (shape_candidate as CollisionShape3D).shape
			if realised_shape is BoxShape3D:
				actual_box_count += 1
			elif realised_shape is CylinderShape3D:
				actual_cylinder_count += 1
	if bodies.size() != expected_body_count:
		errors.append("station activity collision body roster differs from live declarations")
	if expected_body_count != EXPECTED_STATION_ACTIVITY_COLLISION_BODY_COUNT \
		or expected_shape_count != EXPECTED_STATION_ACTIVITY_COLLISION_SHAPE_COUNT:
		errors.append("station activity collision declaration roster drifted from the frozen 7-body/63-shape contract")
	if actual_shape_count != expected_shape_count:
		errors.append("station activity collision shape roster differs from live declarations")
	if actual_box_count != EXPECTED_STATION_ACTIVITY_COLLISION_BOX_COUNT \
		or actual_cylinder_count != EXPECTED_STATION_ACTIVITY_COLLISION_CYLINDER_COUNT:
		errors.append("station activity collision primitive roster drifted from the frozen 55-box/8-cylinder contract")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"body_count": bodies.size(),
		"shape_count": actual_shape_count,
		"box_shape_count": actual_box_count,
		"cylinder_shape_count": actual_cylinder_count,
		"expected_body_count": expected_body_count,
		"expected_shape_count": expected_shape_count,
		"active_body_count": active_body_count,
		"placements": placements,
	}.duplicate(true)


func get_station_machinery_ambience_nodes() -> Array[StationMachineryAmbience]:
	var result: Array[StationMachineryAmbience] = []
	for ambience in _station_machinery_ambience_nodes:
		if is_instance_valid(ambience) and is_ancestor_of(ambience):
			result.append(ambience)
	return result


func get_station_structural_service_dressings() -> Array[StationStructuralServiceDressing]:
	var result: Array[StationStructuralServiceDressing] = []
	for dressing in _station_structural_service_dressings:
		if is_instance_valid(dressing) and is_ancestor_of(dressing):
			result.append(dressing)
	return result


## Integrated, presentation-only service couriers. Like the activity accessor,
## the returned array is a detached registry: a caller can control a component
## but cannot mutate the world's authoritative roster by changing an array.
func get_station_service_agents() -> Array[StationServiceAgent]:
	var result: Array[StationServiceAgent] = []
	for agent in _station_service_agents:
		if is_instance_valid(agent) and is_ancestor_of(agent):
			result.append(agent)
	return result


## Deep-detached navigation graph derived from the station route registry. The
## graph owns no topology of its own and grants no gameplay authority.
func get_station_navigation_graph_report() -> Dictionary:
	return _station_navigation_graph_report.duplicate(true)


## Deterministic route resolution over the declared station graph, for tests and
## UI. A valid route is not proof the player can physically walk it.
func find_station_route(from_node_id: StringName, to_node_id: StringName) -> Dictionary:
	return _station_navigation_graph.find_route(from_node_id, to_node_id)


## Deep-detached route-registry report for static station modules. The data is
## refreshed when the world is built and on reentry reindex.
func get_station_route_registry_report() -> Dictionary:
	return _station_route_registry_report.duplicate(true)


## Convenience accessor for the registry's edge graph and singleton summary.
func get_station_route_adjacency_graph() -> Dictionary:
	return (_station_route_registry_report.get("adjacency", {}) as Dictionary).duplicate(true)


## Validates the embodied station controls against the live module roster.
##
## This is intentionally a read-only topology/interaction audit: a door does
## not create a route or acquire gameplay authority merely by being visible,
## but an orphaned door must not advertise an interaction in a module that the
## route registry rejected.  The report is consumed by tests and diagnostics;
## GameFlow remains the sole interaction selector and StationDoor remains the
## sole door authority.
func get_station_interaction_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var doors := find_children("*", "StationDoor", true, false)
	var modules := {}
	for module_id: StringName in (_station_route_registry_report.get("modules", {}) as Dictionary).keys():
		modules[module_id] = true
	var placements := {}
	for raw_door in doors:
		var door := raw_door as StationDoor
		if door == null or not is_instance_valid(door):
			continue
		var module_id := StringName("")
		var cursor: Node = door.get_parent()
		while cursor != null and cursor != self:
			if cursor.has_method("get_module_id"):
				module_id = StringName(cursor.call("get_module_id"))
				break
			cursor = cursor.get_parent()
		if module_id.is_empty() or not modules.has(module_id):
			errors.append("station door %s is not owned by a registered route module" % door.get_path())
		if door.collision_layer != StationDoor.INTERACTION_LAYER or door.collision_mask != 0:
			errors.append("station door %s interaction layer/mask drifted" % door.get_path())
		if door.monitoring:
			errors.append("station door %s must remain a passive interaction area" % door.get_path())
		var door_transform := door.global_transform
		if (
			not door_transform.origin.is_finite()
			or not door_transform.basis.x.is_finite()
			or not door_transform.basis.y.is_finite()
			or not door_transform.basis.z.is_finite()
		):
			errors.append("station door %s transform is not finite" % door.get_path())
		placements[String(door.get_path())] = {
			"module_id": module_id,
			"deferred_access": door.deferred_access,
			"evidence_status": door.evidence_status,
			"global_transform": door.global_transform,
		}
	if doors.is_empty():
		errors.append("station interaction roster is empty")
	return {
		"schema_version": 1,
		"valid": errors.is_empty(),
		"errors": errors,
		"door_count": placements.size(),
		"registered_module_count": modules.size(),
		"placements": placements,
		"owns_interaction_authority": false,
		"derived_from": &"station_route_registry",
	}.duplicate(true)


## One reversible switch for station movers, the existing freight crane, and
## the finite-range machinery beds. Static structural dressing deliberately
## stays visible because it remains part of the station silhouette.
func set_station_activity_enabled(enabled: bool) -> void:
	_station_activity_enabled = enabled
	var target_activities: Array[StationOperationsActivity] = []
	for registered_activity in _station_operations_activities:
		target_activities.append(registered_activity)
	# During frame-staged construction the activity hierarchy exists before the
	# later indexing stage fills the cached roster. A loader may toggle from its
	# progress callback in that interval; discover the live children so the next
	# collision stage cannot briefly realise starts-enabled bodies.
	if target_activities.is_empty():
		var activities_root := get_node_or_null(^"OperationalLattice/Activities")
		if activities_root != null:
			for child in activities_root.get_children():
				if child is StationOperationsActivity:
					target_activities.append(child as StationOperationsActivity)
	for activity in target_activities:
		if is_instance_valid(activity):
			activity.set_activity_enabled(enabled)
	for ambience in _station_machinery_ambience_nodes:
		if is_instance_valid(ambience):
			ambience.set_ambience_enabled(enabled)
	for agent in _station_service_agents:
		if is_instance_valid(agent):
			agent.set_agent_enabled(enabled)
	if is_instance_valid(jovian_freight_berth):
		jovian_freight_berth.set_equipment_animation_enabled(enabled)


func is_station_activity_enabled() -> bool:
	return _station_activity_enabled


## Deep-detached evidence, placement, lifecycle, and performance report for the
## bounded Phase-3 operational-lattice pass. Exact machinery, motion, audio,
## structure, and placement remain modern remake decisions.
func get_operational_lattice_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var live_activity_instance_ids := {}
	var live_ambience_instance_ids := {}
	var live_dressing_instance_ids := {}
	_collect_live_operational_lattice_component_ids(
		self,
		live_activity_instance_ids,
		live_ambience_instance_ids,
		live_dressing_instance_ids
	)
	var registered_activity_instance_ids := {}
	var registered_ambience_instance_ids := {}
	var registered_dressing_instance_ids := {}
	for activity in _station_operations_activities:
		if is_instance_valid(activity):
			registered_activity_instance_ids[activity.get_instance_id()] = true
	for ambience in _station_machinery_ambience_nodes:
		if is_instance_valid(ambience):
			registered_ambience_instance_ids[ambience.get_instance_id()] = true
	for dressing in _station_structural_service_dressings:
		if is_instance_valid(dressing):
			registered_dressing_instance_ids[dressing.get_instance_id()] = true
	if not _instance_id_sets_match(registered_activity_instance_ids, live_activity_instance_ids):
		errors.append("station activity registry does not match the live world hierarchy")
	if not _instance_id_sets_match(registered_ambience_instance_ids, live_ambience_instance_ids):
		errors.append("station ambience registry does not match the live world hierarchy")
	if not _instance_id_sets_match(registered_dressing_instance_ids, live_dressing_instance_ids):
		errors.append("station structural dressing registry does not match the live world hierarchy")
	var activity_nodes: Array[Node] = []
	var activity_profiles := PackedStringArray()
	var activity_placements := {}
	for activity in _station_operations_activities:
		if not is_instance_valid(activity):
			errors.append("station activity registry contains a freed instance")
			continue
		if not is_ancestor_of(activity):
			errors.append("station activity registry contains a node outside the live world hierarchy")
			continue
		activity_nodes.append(activity)
		activity_profiles.append(str(activity.get_activity_profile_id()))
		var activity_name := StringName(activity.name)
		if activity_placements.has(activity_name):
			errors.append("duplicate station activity name %s" % activity_name)
		activity_placements[activity_name] = {
			"path": activity.get_path(),
			"profile": activity.get_activity_profile_id(),
			"variation_seed": activity.variation_seed,
			"global_transform": activity.global_transform,
			"integration": activity.get_integration_contract(),
		}
		var activity_audit := activity.get_audit_report()
		if not bool(activity_audit.get("valid", false)):
			errors.append("station activity %s failed its component audit" % activity.name)
		var activity_spec := STATION_ACTIVITY_SPECS.get(activity_name, {}) as Dictionary
		if activity_spec.is_empty():
			errors.append("unknown station activity placement %s" % activity.name)
		elif (
			get_node_or_null(activity_spec.path as NodePath) != activity
			or not activity.global_transform.is_equal_approx(activity_spec.transform as Transform3D)
			or activity.get_activity_profile_id() != StringName(activity_spec.profile)
			or activity.variation_seed != int(activity_spec.seed)
		):
			errors.append("station activity %s diverged from its audited placement/profile/seed" % activity.name)
	activity_profiles.sort()
	# Still an exact multiset, not a range. The long cargo run appears twice
	# because the yard is meant to have two of them; a third, or one, is an error
	# exactly as a missing role is.
	var expected_profiles := PackedStringArray([
		"cargo_line",
		"cargo_line_long",
		"cargo_line_long",
		"crew_workpost",
		"drone_patrol",
		"full",
		"gantry",
		"observatory",
		"service_arm",
		"signage_pylon",
	])
	if activity_profiles != expected_profiles:
		errors.append("station activity roster must contain exactly the audited profile multiset")
	if activity_placements.size() != STATION_ACTIVITY_SPECS.size():
		errors.append("station activity roster must contain each exact production name once")
	var activity_roster := StationOperationsActivity.audit_production_roster(activity_nodes)
	if not bool(activity_roster.get("valid", false)):
		errors.append_array(activity_roster.get("errors", PackedStringArray()) as PackedStringArray)
	var activity_collision := get_station_activity_collision_audit_report()
	if not bool(activity_collision.get("valid", false)):
		errors.append_array(
			activity_collision.get("errors", PackedStringArray()) as PackedStringArray
		)

	var ambience_ids := PackedStringArray()
	var ambience_placements := {}
	var audio_totals := {
		"emitter_count": 0,
		"loop_voice_count": 0,
		"transient_voice_count": 0,
		"maximum_simultaneous_voices": 0,
		"resident_sample_bytes": 0,
		"resident_byte_budget": 0,
	}
	for ambience in _station_machinery_ambience_nodes:
		if not is_instance_valid(ambience):
			errors.append("station ambience registry contains a freed instance")
			continue
		if not is_ancestor_of(ambience):
			errors.append("station ambience registry contains a node outside the live world hierarchy")
			continue
		var ambience_id := ambience.get_emitter_id()
		ambience_ids.append(str(ambience_id))
		if ambience_placements.has(ambience_id):
			errors.append("duplicate station ambience ID %s" % ambience_id)
		var ambience_audit := ambience.get_audit_report()
		if not bool(ambience_audit.get("valid", false)):
			errors.append("station ambience %s failed its component audit" % ambience_id)
		var spatial := ambience_audit.get("spatial", {}) as Dictionary
		var synthesis := ambience_audit.get("synthesis", {}) as Dictionary
		var performance := ambience_audit.get("performance", {}) as Dictionary
		ambience_placements[ambience_id] = {
			"path": ambience.get_path(),
			"global_position": ambience.global_position,
			"synthesis_seed": ambience.synthesis_seed,
			"spatial": spatial,
			"synthesis": synthesis,
		}
		audio_totals.emitter_count = int(audio_totals.emitter_count) + 1
		audio_totals.loop_voice_count = int(audio_totals.loop_voice_count) + int(performance.get("loop_voice_count", 0))
		audio_totals.transient_voice_count = int(audio_totals.transient_voice_count) + int(performance.get("transient_voice_count", 0))
		audio_totals.maximum_simultaneous_voices = int(audio_totals.maximum_simultaneous_voices) + int(performance.get("maximum_simultaneous_voices", 0))
		audio_totals.resident_sample_bytes = int(audio_totals.resident_sample_bytes) + int(synthesis.get("resident_sample_bytes", 0))
		audio_totals.resident_byte_budget = int(audio_totals.resident_byte_budget) + int(performance.get("resident_byte_budget", 0))
		var ambience_spec := STATION_AMBIENCE_SPECS.get(ambience_id, {}) as Dictionary
		if ambience_spec.is_empty():
			errors.append("unknown station ambience placement %s" % ambience_id)
		elif (
			StringName(ambience.name) != StringName(ambience_spec.node_name)
			or get_node_or_null(ambience_spec.path as NodePath) != ambience
			or
			not ambience.global_position.is_equal_approx(ambience_spec.position as Vector3)
			or ambience.synthesis_seed != int(ambience_spec.seed)
			or not is_equal_approx(ambience.base_frequency_hz, float(ambience_spec.base_frequency_hz))
			or not is_equal_approx(float(spatial.get("maximum_distance", 0.0)), float(ambience_spec.maximum_distance))
			or not is_equal_approx(float(spatial.get("reference_distance", 0.0)), float(ambience_spec.reference_distance))
		):
			errors.append("station ambience %s diverged from its audited placement/seed/spatial contract" % ambience_id)
	ambience_ids.sort()
	var expected_ambience_ids := PackedStringArray([
		"aft-operations-service-wall",
		"central-berth-utilities",
		"freight-control-machinery",
		"habitat-environmental-main",
	])
	if ambience_ids != expected_ambience_ids:
		errors.append("station ambience roster IDs changed")
	if ambience_placements.size() != STATION_AMBIENCE_SPECS.size():
		errors.append("station ambience roster must contain each exact production ID once")
	if int(audio_totals.resident_sample_bytes) > int(audio_totals.resident_byte_budget):
		errors.append("station machinery audio exceeds its aggregate resident budget")

	var dressing_placements := {}
	var dressing_totals := {
		"instance_count": 0,
		"node_count": 0,
		"mesh_instances": 0,
		"visible_lights": 0,
		"collision_nodes": 0,
	}
	for dressing in _station_structural_service_dressings:
		if not is_instance_valid(dressing):
			errors.append("station structural dressing registry contains a freed instance")
			continue
		if not is_ancestor_of(dressing):
			errors.append("station structural dressing registry contains a node outside the live world hierarchy")
			continue
		var dressing_audit := dressing.get_audit_report()
		if not bool(dressing_audit.get("valid", false)):
			errors.append("station dressing %s failed its component audit" % dressing.name)
		var performance := dressing_audit.get("performance", {}) as Dictionary
		var counts := performance.get("counts", {}) as Dictionary
		dressing_totals.instance_count = int(dressing_totals.instance_count) + 1
		for key: String in ["node_count", "mesh_instances", "visible_lights", "collision_nodes"]:
			dressing_totals[key] = int(dressing_totals.get(key, 0)) + int(counts.get(key, 0))
		var dressing_name := StringName(dressing.name)
		if dressing_placements.has(dressing_name):
			errors.append("duplicate station structural dressing name %s" % dressing_name)
		dressing_placements[dressing_name] = {
			"path": dressing.get_path(),
			"global_transform": dressing.global_transform,
			"configuration": dressing.get_configuration(),
			"integration": dressing.get_integration_contract(),
		}
		var dressing_spec := STATION_DRESSING_SPECS.get(dressing_name, {}) as Dictionary
		var configuration := dressing.get_configuration()
		if dressing_spec.is_empty():
			errors.append("unknown station structural dressing placement %s" % dressing.name)
		elif (
			get_node_or_null(dressing_spec.path as NodePath) != dressing
			or not dressing.global_transform.is_equal_approx(dressing_spec.transform as Transform3D)
			or not is_equal_approx(float(configuration.get("segment_length", 0.0)), float(dressing_spec.length))
			or StringName(configuration.get("structural_profile_name", &"")) != StringName(dressing_spec.profile)
			or StringName(configuration.get("segment_orientation_name", &"")) != StringName(dressing_spec.orientation)
		):
			errors.append("station dressing %s diverged from its audited placement/profile/length/orientation" % dressing.name)
	if int(dressing_totals.collision_nodes) != 0:
		errors.append("station structural dressing must remain collision-free")
	if dressing_placements.size() != STATION_DRESSING_SPECS.size():
		errors.append("station structural dressing roster must contain each exact production name once")

	if _station_operations_activities.size() != EXPECTED_STATION_ACTIVITY_COUNT:
		errors.append("station must integrate exactly eight operations activity instances")
	if _station_machinery_ambience_nodes.size() != EXPECTED_STATION_AMBIENCE_COUNT:
		errors.append("station must integrate exactly four machinery ambience emitters")
	if _station_structural_service_dressings.size() != EXPECTED_STATION_DRESSING_COUNT:
		errors.append("station must integrate exactly four structural service dressings")
	if _station_door_audio_hook_count != 3:
		errors.append("Aft, Habitat, and Freight door audio hooks must all be connected")
	if not _operational_lattice_audio_hooks_are_valid():
		errors.append("station door audio hooks do not target the current live ambience roster")

	return {
		"schema_version": OPERATIONAL_LATTICE_SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence_status": OPERATIONAL_LATTICE_EVIDENCE_STATUS,
		"evidence": {
			"schema_version": OPERATIONAL_LATTICE_SCHEMA_VERSION,
			"evidence_status": OPERATIONAL_LATTICE_EVIDENCE_STATUS,
			"source_bounded": true,
			"authenticated_original_geometry": false,
			"authenticated_original_placement": false,
			"authenticated_original_layout": false,
			"authenticated_original_audio": false,
			"historically_supported_machinery_layout": false,
			"content_note": (
				"The exposed modular lattice and separated negative-space composition are source-informed. "
				+ "All machinery, drones, service structure, animation, sound, dimensions, and placements "
				+ "in this bounded activity pass are project-original modern interpretation."
			),
		},
		"placements": {
			"activities": activity_placements,
			"ambience": ambience_placements,
			"structural_dressing": dressing_placements,
		},
		"performance": {
			"activity_roster": activity_roster,
			"activity_collision": activity_collision,
			"audio_totals": audio_totals,
			"structural_totals": dressing_totals,
			"dynamic_reflection_probes_added": 0,
			"particle_emitters_added": 0,
		},
		"lifecycle": {
			"enabled": _station_activity_enabled,
			"activity_collision_active_body_count": int(
				activity_collision.get("active_body_count", 0)
			),
			"freight_equipment_enabled": jovian_freight_berth.is_equipment_animation_enabled() if is_instance_valid(jovian_freight_berth) else false,
			"door_audio_hook_count": _station_door_audio_hook_count,
		},
	}.duplicate(true)


## Deep-detached audit for the declared station navigation graph and the
## presentation couriers that consume it.
##
## The graph is derived, never authored: every assertion here compares a live
## courier against the route the graph resolves *now*. A module that stops
## declaring its connection slot, a hub endpoint that moves, a courier that is
## re-aimed, re-seeded, or re-parented, or a courier that gains collision,
## interaction, or berth authority all turn this report red.
func get_station_navigation_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var graph_report := _station_navigation_graph_report
	if not bool(graph_report.get("valid", false)):
		errors.append("station navigation graph is invalid: %s" % ", ".join(
			graph_report.get("errors", PackedStringArray()) as PackedStringArray
		))
	if int(graph_report.get("edge_count", 0)) != STATION_HUB_ENDPOINT_DECLARATIONS.size():
		errors.append("station navigation graph must expose one edge per declared hub endpoint")

	var live_agent_instance_ids := {}
	_collect_live_station_service_agent_ids(self, live_agent_instance_ids)
	var registered_agent_instance_ids := {}
	for agent in _station_service_agents:
		if is_instance_valid(agent):
			registered_agent_instance_ids[agent.get_instance_id()] = true
	if not _instance_id_sets_match(registered_agent_instance_ids, live_agent_instance_ids):
		errors.append("station service agent registry does not match the live world hierarchy")
	if _station_service_agents.size() != EXPECTED_STATION_SERVICE_AGENT_COUNT:
		errors.append("station must integrate exactly seven declared-slot service couriers")

	var berth_volumes: Array[AABB] = []
	for berth_id in get_berth_ids():
		var berth := get_berth_node(berth_id)
		if not is_instance_valid(berth):
			continue
		var half := berth.get_landing_half_extents()
		berth_volumes.append(_station_local_aabb_to_world(berth.get_dock_transform(), -half, half))

	var placements := {}
	var smallest_berth_gap := INF
	var smallest_route_clearance := INF
	for agent in _station_service_agents:
		if not is_instance_valid(agent):
			errors.append("station service agent registry contains a freed instance")
			continue
		if not is_ancestor_of(agent):
			errors.append("station service agent registry contains a node outside the live world hierarchy")
			continue
		var agent_id := agent.get_agent_id()
		if placements.has(agent_id):
			errors.append("duplicate station service agent id %s" % agent_id)
		var agent_audit := agent.get_audit_report()
		if not bool(agent_audit.get("valid", false)):
			errors.append("station service agent %s failed its component audit: %s" % [
				agent_id,
				", ".join(agent_audit.get("errors", PackedStringArray()) as PackedStringArray),
			])
		var integration := agent.get_integration_contract()
		var envelope := _station_local_aabb_to_world(
			agent.global_transform,
			integration.local_min as Vector3,
			integration.local_max as Vector3
		)
		placements[agent_id] = {
			"path": agent.get_path(),
			"global_transform": agent.global_transform,
			"route_id": agent.get_route_id(),
			"route_node_ids": agent.get_route_node_ids(),
			"route_length": agent.get_route_length(),
			"variation_seed": agent.variation_seed,
			"traversal_speed": agent.traversal_speed,
			"hover_lift": agent.hover_lift,
			"service_envelope_world": envelope,
			"integration": integration,
		}
		var spec := STATION_SERVICE_AGENT_SPECS.get(agent_id, {}) as Dictionary
		if spec.is_empty():
			errors.append("unknown station service agent %s" % agent_id)
			continue
		if (
			StringName(agent.name) != StringName(spec.node_name)
			or get_node_or_null(spec.path as NodePath) != agent
			or agent.variation_seed != int(spec.seed)
			or not is_equal_approx(agent.traversal_speed, float(spec.speed))
			or not is_equal_approx(agent.hover_lift, float(spec.lift))
			or agent.get_route_id() != StringName(spec.slot_id)
		):
			errors.append("station service agent %s diverged from its audited placement/seed/cadence" % agent_id)
		# The route is re-resolved from the live graph on every audit, so a station
		# graph that changed under a running courier is reported rather than flown.
		var route := _station_navigation_graph.find_route(
			spec.from_node_id as StringName,
			spec.to_node_id as StringName
		)
		if not bool(route.get("valid", false)):
			errors.append("station service agent %s no longer resolves a declared route: %s" % [
				agent_id,
				", ".join(route.get("errors", PackedStringArray()) as PackedStringArray),
			])
			continue
		if agent.get_route_node_ids() != (route.get("node_ids", PackedStringArray()) as PackedStringArray):
			errors.append("station service agent %s route endpoints diverged from the live navigation graph" % agent_id)
		var graph_waypoints := route.get("waypoints", PackedVector3Array()) as PackedVector3Array
		var agent_waypoints := agent.get_world_route_points()
		if agent_waypoints.size() != graph_waypoints.size():
			errors.append("station service agent %s waypoint count diverged from the live navigation graph" % agent_id)
		else:
			var highest_route_y := -INF
			for index in graph_waypoints.size():
				if not agent_waypoints[index].is_equal_approx(graph_waypoints[index]):
					errors.append("station service agent %s waypoint %d diverged from the live navigation graph" % [agent_id, index])
					break
				highest_route_y = maxf(highest_route_y, graph_waypoints[index].y)
			var clearance := envelope.position.y - highest_route_y
			smallest_route_clearance = minf(smallest_route_clearance, clearance)
			if clearance < STATION_SERVICE_AGENT_MINIMUM_ROUTE_CLEARANCE:
				errors.append(
					"station service agent %s hovers only %.3f m above its own route line" % [agent_id, clearance]
				)
		for berth_volume in berth_volumes:
			if _station_aabbs_overlap(envelope, berth_volume):
				errors.append("station service agent %s service envelope intrudes on a live berth volume" % agent_id)
				smallest_berth_gap = 0.0
			else:
				smallest_berth_gap = minf(smallest_berth_gap, _station_aabb_separation(envelope, berth_volume))
	if smallest_berth_gap < STATION_SERVICE_AGENT_MINIMUM_BERTH_GAP:
		errors.append("station service couriers must leave every berth volume clear by at least 0.15 m")
	if placements.size() != STATION_SERVICE_AGENT_SPECS.size():
		errors.append("station service courier roster must contain each exact production id once")

	var agent_root := get_node_or_null(^"OperationalLattice/ServiceAgents")
	var forbidden_nodes := PackedStringArray()
	if agent_root == null:
		errors.append("OperationalLattice/ServiceAgents root is missing")
	else:
		for node in agent_root.find_children("*", "", true, false):
			var script := node.get_script() as Script
			if (
				node is CollisionObject3D
				or node is CollisionShape3D
				or node is Area3D
				or node is Light3D
				or node is GPUParticles3D
				or node is CPUParticles3D
				or node is AudioStreamPlayer3D
				or (script != null and script.resource_path.ends_with("/ship_berth.gd"))
			):
				forbidden_nodes.append(str(agent_root.get_path_to(node)))
		if not forbidden_nodes.is_empty():
			errors.append("station service courier subtree gained forbidden authority or emitter nodes: %s" % ", ".join(forbidden_nodes))

	return {
		"schema_version": STATION_NAVIGATION_SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence_status": OPERATIONAL_LATTICE_EVIDENCE_STATUS,
		"evidence": {
			"schema_version": STATION_NAVIGATION_SCHEMA_VERSION,
			"evidence_status": OPERATIONAL_LATTICE_EVIDENCE_STATUS,
			"source_bounded": true,
			"derived_from": &"station_route_registry",
			"authenticated_original_routes": false,
			"authenticated_original_logistics": false,
			"authenticated_original_traffic": false,
			"content_note": (
				"Station service couriers travel routes resolved from the declared, non-metric "
				+ "station route registry. Which endpoints connect, the courier silhouette, its "
				+ "cadence, hover band, and the idea of autonomous station logistics at all are "
				+ "project-original modern interpretation."
			),
		},
		"authority": {
			"owns_berth_authority": false,
			"owns_lease_authority": false,
			"owns_spawn_or_regeneration_authority": false,
			"owns_combat_or_damage_authority": false,
			"owns_interaction_authority": false,
			"forbidden_node_paths": forbidden_nodes,
			"proves_physical_traversability": false,
		},
		"graph": graph_report.duplicate(true),
		"placements": placements,
		"clearances": {
			"minimum_berth_gap": smallest_berth_gap,
			"minimum_route_clearance": smallest_route_clearance,
			"required_berth_gap": STATION_SERVICE_AGENT_MINIMUM_BERTH_GAP,
			"required_route_clearance": STATION_SERVICE_AGENT_MINIMUM_ROUTE_CLEARANCE,
		},
		"lifecycle": {
			"enabled": _station_activity_enabled,
			"agent_count": _station_service_agents.size(),
		},
	}.duplicate(true)


func _station_local_aabb_to_world(world_transform: Transform3D, local_min: Vector3, local_max: Vector3) -> AABB:
	var bounds := AABB(world_transform * local_min, Vector3.ZERO)
	for corner_index in range(1, 8):
		var corner := Vector3(
			local_max.x if corner_index & 1 else local_min.x,
			local_max.y if corner_index & 2 else local_min.y,
			local_max.z if corner_index & 4 else local_min.z
		)
		bounds = bounds.expand(world_transform * corner)
	return bounds


func _station_aabbs_overlap(first: AABB, second: AABB) -> bool:
	return (
		first.position.x < second.end.x and second.position.x < first.end.x
		and first.position.y < second.end.y and second.position.y < first.end.y
		and first.position.z < second.end.z and second.position.z < first.end.z
	)


func _station_aabb_separation(first: AABB, second: AABB) -> float:
	var gap := Vector3(
		maxf(first.position.x - second.end.x, second.position.x - first.end.x),
		maxf(first.position.y - second.end.y, second.position.y - first.end.y),
		maxf(first.position.z - second.end.z, second.position.z - first.end.z)
	)
	return maxf(maxf(gap.x, gap.y), gap.z)


## Stable physical berth registry used by the multi-ship sandbox. Exact side-
## berth dimensions and orientation are modern blockout decisions, not claims
## about recovered original station coordinates.
func get_berth_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for berth_id: StringName in _berth_transforms.keys():
		ids.append(berth_id)
	ids.sort()
	return ids


func has_berth(berth_id: StringName) -> bool:
	return _berth_transforms.has(berth_id)


func get_berth_transform(berth_id: StringName) -> Transform3D:
	return _berth_transforms.get(berth_id, ship_spawn.global_transform) as Transform3D


func get_berth_node(berth_id: StringName) -> ShipBerth:
	return _berth_nodes.get(berth_id) as ShipBerth


## Exact presentation children of the authoritative physical berth registry.
## Marker-only module geometry is deliberately excluded from this roster.
func get_ship_berth_feedback_nodes() -> Array[ShipBerthFeedback]:
	var result: Array[ShipBerthFeedback] = []
	for berth_id in SHIP_BERTH_FEEDBACK_BERTH_IDS:
		var spec := SHIP_BERTH_FEEDBACK_SPECS[berth_id] as Dictionary
		var berth := _berth_nodes.get(berth_id) as ShipBerth
		var feedback := _berth_feedback_nodes.get(berth_id) as ShipBerthFeedback
		if (
			not is_instance_valid(berth)
			or not is_instance_valid(feedback)
			or not is_ancestor_of(berth)
			or not is_ancestor_of(feedback)
			or feedback.get_parent() != berth
			or get_node_or_null(spec.get("berth_path", NodePath())) != berth
			or get_node_or_null(spec.get("feedback_path", NodePath())) != feedback
		):
			continue
		result.append(feedback)
	return result


## Fail-red integration report for the three modern lease-state displays. The
## ShipBerth remains the sole authority; this only proves one direct visual child
## per registered production berth and delegates each component's deep audit.
func get_ship_berth_feedback_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var placements: Dictionary = {}
	var expected_ids: Array[StringName] = []
	expected_ids.assign(SHIP_BERTH_FEEDBACK_BERTH_IDS)
	if not _dictionary_has_exact_keys(_berth_nodes, expected_ids):
		errors.append("cached_berth_registry_ids_do_not_match_production_contract")
	if not _dictionary_has_exact_keys(_berth_transforms, expected_ids):
		errors.append("cached_berth_transform_ids_do_not_match_production_contract")
	if not _dictionary_has_exact_keys(_berth_half_extents, expected_ids):
		errors.append("cached_berth_extent_ids_do_not_match_production_contract")
	if not _dictionary_has_exact_keys(_berth_feedback_nodes, expected_ids):
		errors.append("cached_feedback_registry_ids_do_not_match_production_contract")

	var live_berths: Array[ShipBerth] = []
	_collect_ship_berths(self, live_berths)
	var live_feedback_nodes: Array[ShipBerthFeedback] = []
	_collect_ship_berth_feedback_nodes(self, live_feedback_nodes)
	var grouped_feedback_nodes: Array[ShipBerthFeedback] = []
	if is_inside_tree():
		for candidate in get_tree().get_nodes_in_group(&"ship_berth_feedback"):
			if candidate is ShipBerthFeedback and is_ancestor_of(candidate):
				grouped_feedback_nodes.append(candidate as ShipBerthFeedback)
	var canonical_berths: Array[ShipBerth] = []
	var canonical_feedback_nodes: Array[ShipBerthFeedback] = []
	var material_ids: Dictionary = {}
	for berth_id in expected_ids:
		var spec := SHIP_BERTH_FEEDBACK_SPECS[berth_id] as Dictionary
		var berth_path := spec.get("berth_path", NodePath()) as NodePath
		var feedback_path := spec.get("feedback_path", NodePath()) as NodePath
		var berth := get_node_or_null(berth_path) as ShipBerth
		var feedback := get_node_or_null(feedback_path) as ShipBerthFeedback
		var cached_berth := _berth_nodes.get(berth_id) as ShipBerth
		var cached_feedback := _berth_feedback_nodes.get(berth_id) as ShipBerthFeedback

		if not is_instance_valid(berth):
			errors.append("missing_canonical_berth_%s" % berth_id)
		else:
			canonical_berths.append(berth)
			if berth.get_parent() != self or get_path_to(berth) != berth_path:
				errors.append("canonical_berth_path_drift_%s" % berth_id)
			if berth.get_berth_id() != berth_id:
				errors.append("canonical_berth_id_drift_%s" % berth_id)
			var expected_berth_transform := spec.get(
				"berth_local_transform", Transform3D.IDENTITY
			) as Transform3D
			if not berth.transform.is_equal_approx(expected_berth_transform):
				errors.append("berth_local_transform_drift_%s" % berth_id)
			if berth.top_level:
				errors.append("berth_top_level_drift_%s" % berth_id)
			var expected_dock_transform := spec.get(
				"dock_transform", Transform3D.IDENTITY
			) as Transform3D
			if not berth.dock_transform.is_equal_approx(expected_dock_transform):
				errors.append("berth_dock_transform_drift_%s" % berth_id)
			var expected_extents := spec.get(
				"landing_half_extents", Vector3.ZERO
			) as Vector3
			if not berth.get_landing_half_extents().is_equal_approx(expected_extents):
				errors.append("berth_landing_half_extents_drift_%s" % berth_id)
			var expected_capture_center := spec.get(
				"assist_capture_center", Vector3.ZERO
			) as Vector3
			if not berth.get_assist_capture_center().is_equal_approx(expected_capture_center):
				errors.append("berth_assist_capture_center_drift_%s" % berth_id)
			var expected_capture_extents := spec.get(
				"assist_capture_half_extents", Vector3.ZERO
			) as Vector3
			if not berth.get_assist_capture_half_extents().is_equal_approx(expected_capture_extents):
				errors.append("berth_assist_capture_half_extents_drift_%s" % berth_id)
			if not is_equal_approx(
				berth.get_assist_capture_maximum_speed(),
				float(spec.get("assist_capture_maximum_speed", -1.0))
			):
				errors.append("berth_assist_capture_maximum_speed_drift_%s" % berth_id)
			if not is_equal_approx(
				berth.get_assist_maximum_tilt_degrees(),
				float(spec.get("assist_maximum_tilt_degrees", -1.0))
			):
				errors.append("berth_assist_maximum_tilt_drift_%s" % berth_id)
			var expected_tags := PackedStringArray(
				spec.get("compatibility_tags", []) as Array
			)
			if berth.get_compatibility_tags() != expected_tags:
				errors.append("berth_compatibility_tags_drift_%s" % berth_id)
			if not is_instance_valid(cached_berth) or cached_berth != berth:
				errors.append("cached_berth_identity_drift_%s" % berth_id)
			var cached_transform_value = _berth_transforms.get(berth_id)
			if (
				typeof(cached_transform_value) != TYPE_TRANSFORM3D
				or not (cached_transform_value as Transform3D).is_equal_approx(berth.get_dock_transform())
			):
				errors.append("cached_berth_transform_drift_%s" % berth_id)
			var cached_extents_value = _berth_half_extents.get(berth_id)
			if (
				typeof(cached_extents_value) != TYPE_VECTOR3
				or not (cached_extents_value as Vector3).is_equal_approx(berth.get_landing_half_extents())
			):
				errors.append("cached_berth_extents_drift_%s" % berth_id)

		if not is_instance_valid(feedback):
			errors.append("missing_canonical_feedback_%s" % berth_id)
			continue
		canonical_feedback_nodes.append(feedback)
		if (
			not is_instance_valid(berth)
			or feedback.get_parent() != berth
			or get_path_to(feedback) != feedback_path
		):
			errors.append("feedback_direct_child_path_drift_%s" % berth_id)
		if not is_instance_valid(cached_feedback) or cached_feedback != feedback:
			errors.append("cached_feedback_identity_drift_%s" % berth_id)
		var expected_transform := spec.get("local_transform", Transform3D.IDENTITY) as Transform3D
		if not feedback.transform.is_equal_approx(expected_transform):
			errors.append("feedback_local_transform_drift_%s" % berth_id)
		if not is_equal_approx(feedback.cue_half_width, float(spec.get("cue_half_width", -1.0))):
			errors.append("feedback_cue_half_width_drift_%s" % berth_id)
		if not is_equal_approx(feedback.cue_half_length, float(spec.get("cue_half_length", -1.0))):
			errors.append("feedback_cue_half_length_drift_%s" % berth_id)

		var report := feedback.get_audit_report()
		var component_errors := report.get("errors", PackedStringArray()) as PackedStringArray
		if (
			feedback.get_component_id() != &"ship_berth_feedback"
			or StringName(report.get("component_id", &"")) != &"ship_berth_feedback"
			or StringName(report.get("berth_id", &"")) != berth_id
			or not bool(report.get("valid", false))
			or not component_errors.is_empty()
		):
			errors.append("feedback_%s_failed_exact_component_audit" % berth_id)
		var component_material_ids := report.get("material_instance_ids", {}) as Dictionary
		var local_material_ids: Dictionary = {}
		if not _dictionary_has_exact_keys(
			component_material_ids,
			SHIP_BERTH_FEEDBACK_MATERIAL_IDS
		):
			errors.append("feedback_%s_material_id_count_drift" % berth_id)
		for material_instance_id_value in component_material_ids.values():
			var material_instance_id := int(material_instance_id_value)
			if (
				material_instance_id == 0
				or not is_instance_valid(instance_from_id(material_instance_id))
				or local_material_ids.has(material_instance_id)
			):
				errors.append("feedback_%s_material_ids_not_unique" % berth_id)
				continue
			local_material_ids[material_instance_id] = true
			if material_ids.has(material_instance_id):
				errors.append("feedback_instances_share_mutable_state_material")
			else:
				material_ids[material_instance_id] = berth_id
		placements[berth_id] = {
			"berth_path": berth_path,
			"berth_local_transform": berth.transform if is_instance_valid(berth) else null,
			"dock_transform": berth.dock_transform if is_instance_valid(berth) else null,
			"landing_half_extents": berth.get_landing_half_extents() if is_instance_valid(berth) else null,
			"assist_capture_center": berth.get_assist_capture_center() if is_instance_valid(berth) else null,
			"assist_capture_half_extents": berth.get_assist_capture_half_extents() if is_instance_valid(berth) else null,
			"assist_capture_maximum_speed": berth.get_assist_capture_maximum_speed() if is_instance_valid(berth) else null,
			"assist_maximum_tilt_degrees": berth.get_assist_maximum_tilt_degrees() if is_instance_valid(berth) else null,
			"compatibility_tags": berth.get_compatibility_tags() if is_instance_valid(berth) else PackedStringArray(),
			"path": get_path_to(feedback),
			"local_transform": feedback.transform,
			"cue_half_width": feedback.cue_half_width,
			"cue_half_length": feedback.cue_half_length,
			"state": feedback.get_feedback_state(),
			"material_instance_ids": component_material_ids,
			"component_audit": report,
		}

	if not _node_instance_sets_match(live_berths, canonical_berths):
		errors.append("ship_berth_descendants_do_not_match_production_contract")
	if not _node_instance_sets_match(live_feedback_nodes, canonical_feedback_nodes):
		errors.append("feedback_descendants_do_not_match_production_contract")
	if not _node_instance_sets_match(grouped_feedback_nodes, canonical_feedback_nodes):
		errors.append("feedback_group_does_not_match_production_contract")
	if material_ids.size() != expected_ids.size() * SHIP_BERTH_FEEDBACK_MATERIAL_COUNT:
		errors.append("feedback_material_ids_do_not_match_production_contract")
	var feedback_nodes := get_ship_berth_feedback_nodes()
	if feedback_nodes.size() != expected_ids.size():
		errors.append("feedback_accessor_does_not_match_production_contract")
	return {
		"schema_version": SHIP_BERTH_FEEDBACK_SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"component_count": feedback_nodes.size(),
		"live_berth_count": live_berths.size(),
		"live_feedback_count": live_feedback_nodes.size(),
		"expected_berth_ids": expected_ids,
		"evidence_status": &"modern_interpretation",
		"authenticated_original_docking_feedback": false,
		"presentation_only": true,
		"placements": placements,
	}.duplicate(true)


func is_landing_position_for_berth(world_position: Vector3, berth_id: StringName) -> bool:
	if not _berth_transforms.has(berth_id):
		return false
	var berth_transform := get_berth_transform(berth_id)
	var half_extents: Vector3 = _berth_half_extents.get(berth_id, landing_half_extents)
	var local_point := berth_transform.affine_inverse() * world_position
	return absf(local_point.x) <= half_extents.x \
		and absf(local_point.y) <= half_extents.y \
		and absf(local_point.z) <= half_extents.z


## Broad acquisition-volume query. The strict physical parked-volume helper
## above intentionally remains unchanged.
func is_landing_assist_position_for_berth(
	world_position: Vector3,
	berth_id: StringName
	) -> bool:
	var berth := get_berth_node(berth_id)
	if is_instance_valid(berth):
		return berth.contains_assist_capture(world_position)
	# Marker-only compatibility scenes have no separate assist authoring.
	return is_landing_position_for_berth(world_position, berth_id)


## Selects a broad capture without mutating reservations. A compatible home
## berth wins whenever it contains the craft; otherwise the closest compatible
## capture centre wins. Sorted IDs make equal-distance ties deterministic.
func find_landing_berth(
	world_position: Vector3,
	preferred_id: StringName = &"",
	definition: ShipDefinition = null,
	requester: Node = null
	) -> StringName:
	if _is_landing_assist_candidate(world_position, preferred_id, definition, requester):
		return preferred_id
	var nearest_id: StringName = &""
	var nearest_distance := INF
	for berth_id in get_berth_ids():
		if not _is_landing_assist_candidate(world_position, berth_id, definition, requester):
			continue
		var berth := get_berth_node(berth_id)
		var capture_origin := (
			berth.get_assist_capture_transform().origin
			if is_instance_valid(berth)
			else get_berth_transform(berth_id).origin
		)
		var distance := world_position.distance_squared_to(capture_origin)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = berth_id
	return nearest_id


## One detached, non-mutating report drives both HUD eligibility and the later
## request preflight. ShipBerth remains the physical acceptance authority.
func get_landing_assist_report(
	candidate: HeroShip,
	preferred_id: StringName = &""
	) -> Dictionary:
	if candidate == null or not is_instance_valid(candidate):
		return _empty_landing_assist_report(&"candidate_unavailable")
	if candidate.is_destroyed():
		return _empty_landing_assist_report(&"candidate_destroyed")
	var definition := candidate.get_ship_definition()
	if definition == null or not definition.is_definition_valid():
		return _empty_landing_assist_report(&"ship_definition_invalid")
	var berth_id := find_landing_berth(
		candidate.global_position,
		preferred_id,
		definition,
		candidate
	)
	if berth_id.is_empty():
		return _empty_landing_assist_report(&"no_available_compatible_capture")
	var berth := get_berth_node(berth_id)
	if not is_instance_valid(berth):
		return _empty_landing_assist_report(&"berth_contract_unavailable")
	var collision_report := candidate.get_landing_collision_report()
	var collision_bounds := collision_report.get("local_bounds", AABB()) as AABB
	var report := berth.evaluate_assist_capture_candidate(
		candidate.global_transform,
		collision_bounds,
		candidate.velocity,
		candidate.landing_maximum_speed
	)
	report["selected_berth_id"] = berth_id
	report["berth_id"] = berth_id
	report["berth_available"] = _is_berth_preview_available(berth, candidate)
	report["compatibility_accepted"] = berth.is_compatible_with(definition)
	report["preview_non_mutating"] = true
	report["collision_report"] = collision_report.duplicate(true)
	return report.duplicate(true)


## Tests whether a world-space point is inside the designated landing volume.
func is_landing_position(world_position: Vector3) -> bool:
	return not find_landing_berth(world_position).is_empty()


func _is_landing_assist_candidate(
	world_position: Vector3,
	berth_id: StringName,
	definition: ShipDefinition,
	_requester: Node
	) -> bool:
	if berth_id.is_empty() or not is_landing_assist_position_for_berth(world_position, berth_id):
		return false
	var berth := get_berth_node(berth_id)
	if not is_instance_valid(berth):
		return definition == null
	if definition != null and not berth.is_compatible_with(definition):
		return false
	return true


func _is_berth_preview_available(berth: ShipBerth, requester: Node) -> bool:
	var owner := berth.get_reservation_owner()
	var occupant := berth.get_occupant()
	return (owner == null or owner == requester) and (occupant == null or occupant == requester)


func _empty_landing_assist_report(error: StringName) -> Dictionary:
	return {
		"schema_version": 1,
		"valid": false,
		"contract_accepted": false,
		"assist_capture_accepted": false,
		"errors": PackedStringArray([str(error)]),
		"berth_id": &"",
		"selected_berth_id": &"",
		"berth_available": false,
		"compatibility_accepted": false,
		"preview_non_mutating": true,
	}.duplicate(true)


func _initialize_berths() -> void:
	_berth_transforms.clear()
	_berth_half_extents.clear()
	_berth_nodes.clear()
	_berth_feedback_nodes.clear()
	var discovered: Array[ShipBerth] = []
	_collect_ship_berths(self, discovered)
	for berth in discovered:
		if not berth.get_validation_errors().is_empty():
			push_error("Invalid ship berth ignored: %s" % berth.get_path())
			continue
		if _berth_nodes.has(berth.get_berth_id()):
			push_error(
				"Duplicate ship berth ID %s ignored at %s"
				% [berth.get_berth_id(), berth.get_path()]
			)
			continue
		_berth_nodes[berth.get_berth_id()] = berth
		_berth_transforms[berth.get_berth_id()] = berth.get_dock_transform()
		_berth_half_extents[berth.get_berth_id()] = berth.get_landing_half_extents()
	# Compatibility fallback for old custom scenes that contain only markers.
	if not _berth_transforms.has(CENTRAL_BERTH_ID):
		_berth_transforms[CENTRAL_BERTH_ID] = ship_spawn.global_transform
		_berth_half_extents[CENTRAL_BERTH_ID] = landing_half_extents
	for berth_id in SHIP_BERTH_FEEDBACK_BERTH_IDS:
		var spec := SHIP_BERTH_FEEDBACK_SPECS[berth_id] as Dictionary
		var berth := get_node_or_null(spec.get("berth_path", NodePath())) as ShipBerth
		var feedback := get_node_or_null(spec.get("feedback_path", NodePath())) as ShipBerthFeedback
		if (
			is_instance_valid(berth)
			and is_instance_valid(feedback)
			and feedback.get_parent() == berth
		):
			_berth_feedback_nodes[berth_id] = feedback


func _collect_ship_berths(search_root: Node, result: Array[ShipBerth]) -> void:
	for child in search_root.get_children():
		if child is ShipBerth:
			result.append(child as ShipBerth)
		_collect_ship_berths(child, result)


func _collect_ship_berth_feedback_nodes(
	search_root: Node,
	result: Array[ShipBerthFeedback]
) -> void:
	for child in search_root.get_children():
		if child is ShipBerthFeedback:
			result.append(child as ShipBerthFeedback)
		_collect_ship_berth_feedback_nodes(child, result)


func _initialize_station_route_registry() -> void:
	var discovered_modules: Array[Node] = []
	_collect_station_route_modules(self, discovered_modules)
	_station_route_registry_report = _station_route_registry.build_registry(
		discovered_modules,
		_build_station_hub_endpoints()
	)
	# The navigation graph is a pure consumer of the registry report, so it is
	# rebuilt together with it. Rebuilding never touches courier node identities;
	# a drifted graph is reported by the navigation audit instead.
	_station_navigation_graph_report = _station_navigation_graph.build_from_registry_report(
		_station_route_registry_report
	)


## The world owns placement, so it also owns the hub half of every station
## connection. Each endpoint points at the real lattice geometry that carries the
## player onto the module, and names the module it is built to serve, so a module
## tagged with the wrong slot is reported instead of silently forming an edge.
func _build_station_hub_endpoints() -> Array:
	var endpoints: Array = []
	for declaration in STATION_HUB_ENDPOINT_DECLARATIONS:
		var anchor_path := str(declaration.get("anchor_path", ""))
		endpoints.append({
			"slot_id": declaration.get("slot_id", &""),
			"expects_module": declaration.get("expects_module", &""),
			"evidence_status": declaration.get("evidence_status", &""),
			"anchor": get_node_or_null(NodePath(anchor_path)),
		})
	return endpoints


## Station modules already join the `station_modules` group in `_apply_metadata`,
## so discovery uses that exact roster rather than duck-typing on a partial
## method list. Duck-typing collected any node that merely resembled a module,
## missed `has_route_marker`, and kept descending into a module it had already
## matched — which would have registered a future nested sub-module as a peer.
func _collect_station_route_modules(search_root: Node, result: Array[Node]) -> void:
	for child in search_root.get_children():
		if child.is_in_group(&"station_modules"):
			result.append(child)
			continue
		_collect_station_route_modules(child, result)


func _dictionary_has_exact_keys(source: Dictionary, expected_keys: Array[StringName]) -> bool:
	if source.size() != expected_keys.size():
		return false
	for expected_key in expected_keys:
		if not source.has(expected_key):
			return false
	return true


func _node_instance_sets_match(first, second) -> bool:
	if first.size() != second.size():
		return false
	var second_ids: Dictionary = {}
	for candidate in second:
		if not is_instance_valid(candidate):
			return false
		second_ids[candidate.get_instance_id()] = true
	for candidate in first:
		if not is_instance_valid(candidate) or not second_ids.has(candidate.get_instance_id()):
			return false
	return true


func _restore_operational_lattice_after_reentry() -> void:
	if is_queued_for_deletion() or not is_inside_tree() or not _built:
		return
	_index_operational_lattice_components()
	_initialize_station_route_registry()
	_connect_operational_lattice_audio()
	_apply_operational_dressing_quality()
	set_station_activity_enabled(_station_activity_enabled)


func _build_operational_lattice_components() -> void:
	var lattice := Node3D.new()
	lattice.name = "OperationalLattice"
	add_child(lattice)
	var activities := Node3D.new()
	activities.name = "Activities"
	lattice.add_child(activities)
	var ambience := Node3D.new()
	ambience.name = "Ambience"
	lattice.add_child(ambience)
	var dressings := Node3D.new()
	dressings.name = "StructuralDressing"
	lattice.add_child(dressings)
	# Populated after the route registry and navigation graph resolve, because a
	# courier route is read out of the declared station graph rather than authored.
	var service_agents := Node3D.new()
	service_agents.name = "ServiceAgents"
	lattice.add_child(service_agents)

	_add_station_activity(
		activities, "CentralTowServiceActivity",
		Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(6.8, 0.0, 14.0)),
		StationOperationsActivity.ActivityProfile.FULL, 1103
	)
	_add_station_activity(
		activities, "AftOperationsActivity",
		Transform3D(Basis(Vector3.UP, PI), Vector3(5.8, 4.99, 61.2)),
		StationOperationsActivity.ActivityProfile.SERVICE_ARM, 2207
	)
	_add_station_activity(
		activities, "HabitatServicePatrol",
		Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(59.15, 4.88, 15.5)),
		StationOperationsActivity.ActivityProfile.DRONE_PATROL, 3301
	)
	# The exact source-audited mount stays fixed. When its four drawn columns became
	# honest solids, the south/east post exposed that the adjacent approach rail
	# overran the only vehicle handoff; the freight module shortens that rail at its
	# open end rather than moving this supported frame into a berth or pod roof.
	_add_station_activity(
		activities, "FreightApproachGantry",
		Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-53.0, 0.38, 29.7)),
		StationOperationsActivity.ActivityProfile.GANTRY, 4409
	)

	# Station life. Cargo movement beside the Central berth, a crew work post at
	# the head of the Aft upper stair, an observation instrument on the Habitat
	# common roof, and wayfinding at the Freight approach.
	# Turned across the deck and moved clear of `JunctionPortalPost`; see the note
	# on this entry in `STATION_ACTIVITY_SPECS`.
	_add_station_activity(
		activities, "CentralCargoTransferLine",
		Transform3D(Basis.IDENTITY, Vector3(-6.0, 0.0, 17.9)),
		StationOperationsActivity.ActivityProfile.CARGO_LINE, 5507
	)
	# Two 21.6 m transfer runs, one per branch arm. Different seeds so the two
	# sleds and hoists are out of phase with each other and with the short line.
	_add_station_activity(
		activities, "PortBranchCargoLine",
		Transform3D(Basis.IDENTITY, Vector3(-22.0, 0.0, 16.75)),
		StationOperationsActivity.ActivityProfile.CARGO_LINE_LONG, 9931
	)
	_add_station_activity(
		activities, "StarboardBranchCargoLine",
		Transform3D(Basis.IDENTITY, Vector3(23.3, 0.0, 16.75)),
		StationOperationsActivity.ActivityProfile.CARGO_LINE_LONG, 10739
	)
	_add_station_activity(
		activities, "AftCrewWorkPost",
		Transform3D(Basis.IDENTITY, Vector3(-7.0, 4.2, 65.0)),
		StationOperationsActivity.ActivityProfile.CREW_WORKPOST, 6607
	)
	_add_station_activity(
		activities, "HabitatSkywatchPost",
		Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(73.0, 5.08, 19.0)),
		StationOperationsActivity.ActivityProfile.OBSERVATORY, 7703
	)
	_add_station_activity(
		activities, "FreightApproachSignage",
		Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-41.0, 6.18, 29.0)),
		StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON, 8821
	)

	_add_station_ambience(ambience, "CentralBerthUtilitiesAmbience", Vector3(10.65, 1.8, -19.25), &"central-berth-utilities", 4831, 44.0, 26.0, 4.0)
	_add_station_ambience(ambience, "AftOperationsAmbience", Vector3(10.0, 2.35, 60.55), &"aft-operations-service-wall", 7759, 52.0, 24.0, 3.5)
	_add_station_ambience(ambience, "HabitatEnvironmentalAmbience", Vector3(59.15, 3.2, 20.95), &"habitat-environmental-main", 9127, 39.0, 22.0, 3.0)
	_add_station_ambience(ambience, "FreightControlAmbience", Vector3(-33.75, 2.58, 57.8), &"freight-control-machinery", 12203, 61.0, 28.0, 4.0)

	_add_station_dressing(dressings, "CentralBerthOuterFascia", Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(13.5, -0.02, -10.0)), 20.0, StationStructuralServiceDressing.StructuralProfile.STANDARD)
	_add_station_dressing(dressings, "AftOperationsOuterFascia", Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(10.86, 4.6, 60.55)), 6.0, StationStructuralServiceDressing.StructuralProfile.LIGHT)
	_add_station_dressing(dressings, "HabitatOuterServiceDressing", Transform3D(Basis.IDENTITY, Vector3(59.15, 4.45, 21.94)), 12.0, StationStructuralServiceDressing.StructuralProfile.STANDARD)
	_add_station_dressing(dressings, "FreightRackServiceDressing", Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-75.34, 0.38, 56.8)), 20.0, StationStructuralServiceDressing.StructuralProfile.LIGHT)


## Gives the solid-looking parts of an activity matching World-layer collision.
##
## The activity component itself stays collision-free — its own audit still
## requires `collision_nodes == 0`, so a presentation rail can never quietly grow
## gameplay authority — and the bodies are built here instead, as a sibling group
## under the lattice. Every shape's primitive kind, dimensions and local position
## come from `get_solid_volume_contract()`, which in turn copies them from the
## drawn primitive: box stock stays BoxShape3D, while the fixed service-arm drums
## stay cylindrical rather than acquiring a square AABB proxy.
##
## Only static structure is made solid. The movers stay nonblocking, because a
## sled whose pose is a closed-form function of a clock has no physics behind it,
## and a body that teleports through the player each frame is worse than one they
## can walk through. And only geometry drawn by an individual `MeshInstance3D`
## appears in the contract, so `tests/station_surface_playability_test.gd`'s
## inverse sweep can find something drawn at every standable surface these add.
func _build_station_activity_collision() -> void:
	var lattice := get_node_or_null(^"OperationalLattice") as Node3D
	var activities := get_node_or_null(^"OperationalLattice/Activities") as Node3D
	if lattice == null or activities == null:
		return
	var collision_root := Node3D.new()
	collision_root.name = "ActivityCollision"
	lattice.add_child(collision_root)
	for child in activities.get_children():
		var activity := child as StationOperationsActivity
		if activity == null:
			continue
		var volumes := activity.get_solid_volume_contract()
		if volumes.is_empty():
			continue
		var body := StaticBody3D.new()
		body.name = "%sSolids" % activity.name
		body.collision_layer = PhysicsLayers.NONE
		body.collision_mask = 0
		body.transform = activity.transform
		collision_root.add_child(body)
		for index in volumes.size():
			var volume := volumes[index]
			var shape: Shape3D
			if StringName(volume.get("shape_kind", &"box")) == &"cylinder":
				var cylinder := CylinderShape3D.new()
				cylinder.radius = float(volume.radius)
				cylinder.height = float(volume.height)
				shape = cylinder
			else:
				var box := BoxShape3D.new()
				box.size = volume.size as Vector3
				shape = box
			var collision := CollisionShape3D.new()
			collision.name = "%s%02d" % [str(volume.name), index + 1]
			collision.shape = shape
			collision.transform = Transform3D(
				volume.get("basis", Basis.IDENTITY) as Basis,
				volume.position as Vector3
			)
			body.add_child(collision)
		# The activity remains the source of desired visibility and pose while the
		# world remains the owner of physics. The bound body survives an independent
		# activity detach, so the signal explicitly turns it off until re-entry.
		activity.solid_volume_state_changed.connect(
			_on_station_activity_solid_volume_state_changed.bind(activity, body)
		)
		_on_station_activity_solid_volume_state_changed(
			activity.is_activity_enabled() and activity.is_inside_tree(),
			activity.global_transform,
			activity,
			body
		)


func _on_station_activity_solid_volume_state_changed(
	active: bool,
	activity_global_transform: Transform3D,
	activity: StationOperationsActivity,
	body: StaticBody3D
) -> void:
	if not is_instance_valid(body):
		return
	body.collision_layer = PhysicsLayers.NONE
	body.collision_mask = PhysicsLayers.NONE
	# A declaration belongs to this world, not merely to whichever tree later
	# receives the source node. If an activity is independently streamed into a
	# different live root, its enter signal must never resurrect the old world's
	# surviving sibling collider.
	if not is_instance_valid(activity) or not self.is_ancestor_of(activity):
		return
	var collision_root := body.get_parent() as Node3D
	var canonical_root := get_node_or_null(
		^"OperationalLattice/ActivityCollision"
	) as Node3D
	var canonical_activities_root := get_node_or_null(
		^"OperationalLattice/Activities"
	) as Node3D
	if collision_root == null or collision_root != canonical_root \
		or canonical_activities_root == null \
		or activity.get_parent() != canonical_activities_root:
		return
	# During whole-world teardown the activity exits after the sibling collision
	# root has already left the tree. Turning the body off is sufficient and avoids
	# asking Godot for an out-of-tree global transform. Re-entry's world lifecycle
	# setter publishes a fresh active transform after every sibling is live again.
	# A live but disabled activity still synchronises pose: otherwise moving it
	# while hidden would leave a stale body waiting at the old site for re-enable.
	if not collision_root.is_inside_tree():
		return
	# Activities and collision live under different sibling containers. Convert
	# through world space so a future container transform or whole-world placement
	# cannot desynchronise a body from the presentation it represents.
	body.transform = (
		collision_root.global_transform.affine_inverse()
		* activity_global_transform
	)
	if active:
		body.collision_layer = WORLD_LAYER


## Creates one courier per declared connection slot from routes the navigation
## graph resolved. Nothing is authored here except the identity, cadence, and
## hover band: if the graph cannot resolve a spec's two declared endpoints, no
## courier is created and `get_station_navigation_audit_report()` turns red.
func _build_station_service_agents() -> void:
	var parent := get_node_or_null(^"OperationalLattice/ServiceAgents") as Node3D
	if parent == null:
		return
	var agent_ids: Array[StringName] = []
	for agent_id: StringName in STATION_SERVICE_AGENT_SPECS.keys():
		agent_ids.append(agent_id)
	agent_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for agent_id in agent_ids:
		var spec := STATION_SERVICE_AGENT_SPECS[agent_id] as Dictionary
		var route := _station_navigation_graph.find_route(
			spec.from_node_id as StringName,
			spec.to_node_id as StringName
		)
		if not bool(route.get("valid", false)):
			continue
		var waypoints := route.get("waypoints", PackedVector3Array()) as PackedVector3Array
		if waypoints.size() < 2:
			continue
		# The mount keeps the world basis so the courier's hover lift stays world-up;
		# only the origin follows the route's first declared endpoint.
		var mount := Transform3D(Basis.IDENTITY, waypoints[0])
		var local_waypoints := PackedVector3Array()
		for point in waypoints:
			local_waypoints.append(point - waypoints[0])
		var agent := STATION_SERVICE_AGENT_SCENE.instantiate() as StationServiceAgent
		agent.name = String(spec.node_name)
		agent.transform = mount
		agent.agent_id = agent_id
		agent.variation_seed = int(spec.seed)
		agent.traversal_speed = float(spec.speed)
		agent.hover_lift = float(spec.lift)
		if not agent.configure_service_route(
			spec.slot_id as StringName,
			route.get("node_ids", PackedStringArray()) as PackedStringArray,
			local_waypoints
		):
			agent.free()
			continue
		parent.add_child(agent)


func _add_station_activity(
	parent: Node3D,
	node_name: String,
	world_transform: Transform3D,
	profile: int,
	seed: int
) -> void:
	var activity := STATION_ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	activity.name = node_name
	activity.transform = world_transform
	activity.activity_profile = profile
	activity.variation_seed = seed
	# A pre-tree global disable is authoritative during both synchronous and
	# frame-staged construction. Seed the component before `_ready()` so the later
	# collision stage can never expose a starts-enabled body for one playable frame.
	activity.starts_enabled = _station_activity_enabled
	parent.add_child(activity)


func _add_station_ambience(
	parent: Node3D,
	node_name: String,
	world_position: Vector3,
	emitter_id: StringName,
	seed: int,
	base_frequency: float,
	maximum_distance: float,
	reference_distance: float
) -> void:
	var emitter := STATION_AMBIENCE_SCENE.instantiate() as StationMachineryAmbience
	emitter.name = node_name
	emitter.position = world_position
	emitter.emitter_id = emitter_id
	emitter.synthesis_seed = seed
	emitter.base_frequency_hz = base_frequency
	emitter.maximum_distance = maximum_distance
	emitter.reference_distance = reference_distance
	parent.add_child(emitter)


func _add_station_dressing(
	parent: Node3D,
	node_name: String,
	world_transform: Transform3D,
	length: float,
	profile: int
) -> void:
	var dressing := STATION_DRESSING_SCENE.instantiate() as StationStructuralServiceDressing
	dressing.name = node_name
	dressing.transform = world_transform
	dressing.segment_length = length
	dressing.structural_profile = profile
	dressing.segment_orientation = StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_X
	dressing.initial_quality = visual_quality_level
	parent.add_child(dressing)


func _index_operational_lattice_components() -> void:
	_station_operations_activities.clear()
	_station_machinery_ambience_nodes.clear()
	_station_structural_service_dressings.clear()
	_station_service_agents.clear()
	_collect_operational_lattice_components(self)


func _collect_operational_lattice_components(search_root: Node) -> void:
	for child in search_root.get_children():
		if child is StationOperationsActivity:
			_station_operations_activities.append(child as StationOperationsActivity)
		elif child is StationMachineryAmbience:
			_station_machinery_ambience_nodes.append(child as StationMachineryAmbience)
		elif child is StationStructuralServiceDressing:
			_station_structural_service_dressings.append(child as StationStructuralServiceDressing)
		elif child is StationServiceAgent:
			_station_service_agents.append(child as StationServiceAgent)
		_collect_operational_lattice_components(child)


func _collect_live_station_service_agent_ids(search_root: Node, agent_instance_ids: Dictionary) -> void:
	for child in search_root.get_children():
		if child is StationServiceAgent:
			agent_instance_ids[child.get_instance_id()] = true
		_collect_live_station_service_agent_ids(child, agent_instance_ids)


func _collect_live_operational_lattice_component_ids(
	search_root: Node,
	activity_instance_ids: Dictionary,
	ambience_instance_ids: Dictionary,
	dressing_instance_ids: Dictionary
) -> void:
	for child in search_root.get_children():
		if child is StationOperationsActivity:
			activity_instance_ids[child.get_instance_id()] = true
		elif child is StationMachineryAmbience:
			ambience_instance_ids[child.get_instance_id()] = true
		elif child is StationStructuralServiceDressing:
			dressing_instance_ids[child.get_instance_id()] = true
		_collect_live_operational_lattice_component_ids(
			child,
			activity_instance_ids,
			ambience_instance_ids,
			dressing_instance_ids
		)


func _instance_id_sets_match(first: Dictionary, second: Dictionary) -> bool:
	if first.size() != second.size():
		return false
	for instance_id in first:
		if not second.has(instance_id):
			return false
	return true


func _connect_operational_lattice_audio() -> void:
	_disconnect_operational_lattice_audio()
	_station_door_audio_hook_count = 0
	var ambience_by_id := {}
	for ambience in _station_machinery_ambience_nodes:
		if is_instance_valid(ambience):
			ambience_by_id[ambience.get_emitter_id()] = ambience
	var aft := get_node_or_null("AftJunctionStack") as AftJunctionStack
	_connect_operational_door_audio(
		aft.get_operations_entrance() if is_instance_valid(aft) else null,
		ambience_by_id.get(&"aft-operations-service-wall") as StationMachineryAmbience
	)
	_connect_operational_door_audio(
		habitat_spine.get_main_access() if is_instance_valid(habitat_spine) else null,
		ambience_by_id.get(&"habitat-environmental-main") as StationMachineryAmbience
	)
	_connect_operational_door_audio(
		jovian_freight_berth.get_service_access() if is_instance_valid(jovian_freight_berth) else null,
		ambience_by_id.get(&"freight-control-machinery") as StationMachineryAmbience
	)


func _connect_operational_door_audio(
	door: StationDoor,
	ambience: StationMachineryAmbience
) -> void:
	if (
		not is_instance_valid(door)
		or not is_instance_valid(ambience)
		or not is_ancestor_of(door)
		or not is_ancestor_of(ambience)
		or not _is_canonical_operational_audio_door(door)
	):
		return
	var ambience_instance_id := ambience.get_instance_id()
	var state_callable := _on_operational_door_state_changed.bind(ambience_instance_id)
	var completed_callable := _on_operational_door_motion_completed.bind(ambience_instance_id)
	if not door.state_changed.is_connected(state_callable):
		door.state_changed.connect(state_callable)
	if not door.motion_completed.is_connected(completed_callable):
		door.motion_completed.connect(completed_callable)
	_station_door_audio_bindings[door.get_instance_id()] = {
		"door": weakref(door),
		"ambience": weakref(ambience),
		"ambience_instance_id": ambience_instance_id,
		"state_callable": state_callable,
		"completed_callable": completed_callable,
	}
	_station_door_audio_hook_count += 1


func _disconnect_operational_lattice_audio() -> void:
	for binding_value in _station_door_audio_bindings.values():
		var binding := binding_value as Dictionary
		var door_reference := binding.get("door") as WeakRef
		var door := door_reference.get_ref() as StationDoor if door_reference != null else null
		if not is_instance_valid(door):
			continue
		var state_callable := binding.get("state_callable") as Callable
		var completed_callable := binding.get("completed_callable") as Callable
		if state_callable.is_valid() and door.state_changed.is_connected(state_callable):
			door.state_changed.disconnect(state_callable)
		if completed_callable.is_valid() and door.motion_completed.is_connected(completed_callable):
			door.motion_completed.disconnect(completed_callable)
	_station_door_audio_bindings.clear()
	_station_door_audio_hook_count = 0


func _operational_lattice_audio_hooks_are_valid() -> bool:
	if _station_door_audio_bindings.size() != 3:
		return false
	var expected_door_emitters := _get_canonical_operational_audio_door_emitters()
	if expected_door_emitters.size() != 3:
		return false
	var live_ambience_ids := {}
	for ambience in _station_machinery_ambience_nodes:
		if is_instance_valid(ambience) and is_ancestor_of(ambience):
			live_ambience_ids[ambience.get_instance_id()] = true
	var bound_door_ids := {}
	for binding_value in _station_door_audio_bindings.values():
		var binding := binding_value as Dictionary
		var door_reference := binding.get("door") as WeakRef
		var ambience_reference := binding.get("ambience") as WeakRef
		var door := door_reference.get_ref() as StationDoor if door_reference != null else null
		var ambience := ambience_reference.get_ref() as StationMachineryAmbience if ambience_reference != null else null
		var ambience_instance_id := int(binding.get("ambience_instance_id", 0))
		var state_callable := binding.get("state_callable") as Callable
		var completed_callable := binding.get("completed_callable") as Callable
		if (
			not is_instance_valid(door)
			or not is_ancestor_of(door)
			or not expected_door_emitters.has(door.get_instance_id())
			or not is_instance_valid(ambience)
			or ambience.get_emitter_id()
				!= StringName(expected_door_emitters.get(door.get_instance_id(), &""))
			or ambience.get_instance_id() != ambience_instance_id
			or not live_ambience_ids.has(ambience_instance_id)
			or not state_callable.is_valid()
			or not completed_callable.is_valid()
			or not door.state_changed.is_connected(state_callable)
			or not door.motion_completed.is_connected(completed_callable)
		):
			return false
		bound_door_ids[door.get_instance_id()] = true
	var expected_door_ids := {}
	for door_instance_id in expected_door_emitters:
		expected_door_ids[door_instance_id] = true
	return _instance_id_sets_match(bound_door_ids, expected_door_ids)


func _get_canonical_operational_audio_door_ids() -> Dictionary:
	var result := {}
	for door_instance_id in _get_canonical_operational_audio_door_emitters():
		result[door_instance_id] = true
	return result


func _get_canonical_operational_audio_door_emitters() -> Dictionary:
	var result := {}
	var contracts := {
		NodePath("AftJunctionStack/OperationsEntrance"): &"aft-operations-service-wall",
		NodePath("HabitatSpine/MainAccess"): &"habitat-environmental-main",
		NodePath("JovianFreightBerth/ServiceAccess"): &"freight-control-machinery",
	}
	for door_path_value in contracts:
		var door_path := door_path_value as NodePath
		var door := get_node_or_null(door_path) as StationDoor
		if is_instance_valid(door) and is_ancestor_of(door):
			result[door.get_instance_id()] = contracts[door_path_value]
	return result


func _is_canonical_operational_audio_door(door: StationDoor) -> bool:
	if not is_instance_valid(door):
		return false
	return _get_canonical_operational_audio_door_ids().has(door.get_instance_id())


func _on_operational_door_state_changed(
	_previous_state: int,
	current_state: int,
	ambience_instance_id: int
) -> void:
	if not _station_activity_enabled or not is_instance_id_valid(ambience_instance_id):
		return
	var ambience := instance_from_id(ambience_instance_id) as StationMachineryAmbience
	if not is_instance_valid(ambience):
		return
	if current_state == StationDoor.DoorState.OPENING or current_state == StationDoor.DoorState.CLOSING:
		ambience.play_cue(&"servo", 0.82)


func _on_operational_door_motion_completed(
	_final_state: int,
	ambience_instance_id: int
) -> void:
	if not _station_activity_enabled or not is_instance_id_valid(ambience_instance_id):
		return
	var ambience := instance_from_id(ambience_instance_id) as StationMachineryAmbience
	if is_instance_valid(ambience):
		ambience.play_cue(&"latch", 0.72)


func _apply_operational_dressing_quality() -> void:
	for dressing in _station_structural_service_dressings:
		if is_instance_valid(dressing):
			dressing.set_quality_level(visual_quality_level)
	# A currently loaded cluster follows the same presentation profile. The
	# production streaming binding also forwards the retained profile once to
	# each newly committed generation, because the cluster is absent at startup.
	var cluster := get_nearby_sector_cluster()
	if is_instance_valid(cluster):
		cluster.set_detail_quality(visual_quality_level)


## Resolves a hitscan projectile against station collision and target drones.
##
## The returned dictionary always contains `hit`, `position`, `normal`,
## `target`, and `target_destroyed`.  Hits also expose `collider`, and target
## hits expose `target_id` plus the remaining `target_health`.
func register_projectile_hit(origin: Vector3, end: Vector3) -> Dictionary:
	var response := {
		"hit": false,
		"position": end,
		"normal": Vector3.ZERO,
		"collider": null,
		"target": false,
		"target_destroyed": false,
	}
	if not is_inside_tree() or origin.is_equal_approx(end):
		return response

	var query := PhysicsRayQueryParameters3D.create(origin, end, RAYCAST_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return response

	response["hit"] = true
	response["position"] = hit.get("position", end)
	response["normal"] = hit.get("normal", Vector3.ZERO)
	response["collider"] = hit.get("collider")
	_spawn_impact(response["position"], KETH_ORANGE)

	var collider := hit.get("collider") as Node
	if collider == null or not collider.get_meta("is_shipyard_target", false):
		return response

	response["target"] = true
	var target_id := StringName(collider.get_meta("target_id", &"UNKNOWN"))
	var health := maxf(0.0, float(collider.get_meta("health", target_health)) - projectile_damage)
	collider.set_meta("health", health)
	response["target_id"] = target_id
	response["target_health"] = health
	if health <= 0.0 and not collider.get_meta("destroyed", false):
		response["target_destroyed"] = true
		_destroy_target(collider as StaticBody3D, target_id, response["position"])
	return response


func get_target_count() -> int:
	return _targets.size()


func get_destroyed_target_count() -> int:
	return _destroyed_target_count


## Re-arms only surviving targets when this same built world returns to the
## tree. Already-authorized destructions stay retired, preserving the mission's
## exactly-once count and preventing a disabled body from being resurrected.
func _restore_range_targets_after_reentry() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	for target in _targets:
		if not is_instance_valid(target) or bool(target.get_meta("destroyed", false)):
			continue
		reset_range_target_for_reuse(target)


func reset_range_target_for_reuse(target: StaticBody3D) -> Dictionary:
	if (
		not is_instance_valid(target)
		or not _targets.has(target)
		or not target.get_meta("is_shipyard_target", false)
		or bool(target.get_meta("destroyed", false))
	):
		return {"accepted": false, "reason": &"target_unavailable"}.duplicate(true)
	var adapter := target.get_node_or_null("AuthoritativeDamageable") as RangeTargetDamageableAdapter
	if adapter == null:
		return {"accepted": false, "reason": &"component_adapter_unavailable"}.duplicate(true)
	var snapshot := adapter.get_component_snapshot()
	var expected_generation := int(snapshot.get("generation", 0))
	var reset_result := adapter.reset_for_reuse(expected_generation)
	if not bool(reset_result.get("accepted", false)):
		return reset_result.duplicate(true)
	target.set_meta("health", adapter.get_maximum_health())
	target.set_meta("destroyed", false)
	return reset_result.duplicate(true)


## Consumes detached component condition for the four authored range drones.
## This presentation seam deliberately has no health, collision, destruction,
## or mission authority; those remain in the target metadata lifecycle below.
func apply_range_target_component_presentation(
		target: StaticBody3D,
		component_snapshot: Dictionary
	) -> bool:
	if not is_instance_valid(target) or not target.get_meta("is_shipyard_target", false):
		return false
	var visual := target.get_node_or_null("DroneVisual") as Node3D
	if visual == null:
		return false
	var stages: Dictionary = {}
	for raw_state in component_snapshot.get("components", []) as Array:
		if not raw_state is Dictionary:
			continue
		var state := raw_state as Dictionary
		var stage := state.get("stage", {}) as Dictionary
		stages[StringName(state.get("component_id", &""))] = StringName(
			stage.get("stage_id", &"nominal")
		)
	var frame_stage := StringName(stages.get(&"frame", &"nominal"))
	var core_stage := StringName(stages.get(&"core", &"nominal"))
	var outer_ring := visual.get_node_or_null("OuterRing") as MeshInstance3D
	var core := visual.get_node_or_null("Core") as MeshInstance3D
	if outer_ring != null:
		outer_ring.set_meta("component_stage", frame_stage)
		outer_ring.material_override = _range_target_frame_material(frame_stage)
		outer_ring.scale = _range_target_frame_scale(frame_stage)
	if core != null:
		core.set_meta("component_stage", core_stage)
		core.material_override = _range_target_core_material(core_stage)
		core.scale = _range_target_core_scale(core_stage)
	return outer_ring != null and core != null


func _range_target_frame_material(stage: StringName) -> Material:
	match stage:
		&"damaged":
			return _materials["orange"]
		&"critical", &"destroyed":
			return _materials["red"]
		_:
			return _materials["ivory"]


func _range_target_core_material(stage: StringName) -> Material:
	match stage:
		&"damaged", &"critical":
			return _materials["red_glow"]
		&"destroyed":
			return _materials["black"]
		_:
			return _materials["orange_glow"]


## Static silhouette changes keep component state legible without relying on
## hue or flashing. These transforms affect visual children only; the target's
## collision sphere and authoritative aim point never move or resize.
func _range_target_frame_scale(stage: StringName) -> Vector3:
	match stage:
		&"damaged":
			return Vector3.ONE * 0.86
		&"critical":
			return Vector3.ONE * 0.68
		&"destroyed":
			return Vector3.ONE * 0.50
		_:
			return Vector3.ONE


func _range_target_core_scale(stage: StringName) -> Vector3:
	match stage:
		&"damaged":
			return Vector3.ONE * 0.78
		&"critical":
			return Vector3.ONE * 0.52
		&"destroyed":
			return Vector3.ONE * 0.30
		_:
			return Vector3.ONE


func defer_target_damage_presentation(
		receipt_id: int,
		target: StaticBody3D,
		target_id: StringName,
		hit_position: Vector3,
		terminal: bool
	) -> bool:
	if (
		not is_inside_tree()
		or is_queued_for_deletion()
		or receipt_id < 0
		or not is_instance_valid(target)
	):
		return false
	if _pending_target_presentations.has(receipt_id):
		_pending_target_presentation_order.erase(receipt_id)
	_pending_target_presentations[receipt_id] = {
		"target": weakref(target),
		"target_id": target_id,
		"hit_position": hit_position,
		"terminal": terminal,
	}
	_pending_target_presentation_order.append(receipt_id)
	while _pending_target_presentation_order.size() > MAX_PENDING_TARGET_PRESENTATIONS:
		var evicted: int = _pending_target_presentation_order.pop_front()
		_pending_target_presentations.erase(evicted)
	return true


func get_pending_target_damage_presentation_count() -> int:
	return _pending_target_presentations.size()


## Clears deferred target presentation queues for whole-Main re-entry safety.
func discard_deferred_damage_presentations() -> void:
	_pending_target_presentations.clear()
	_pending_target_presentation_order.clear()


func commit_deferred_damage_presentation(receipt_id: int) -> bool:
	if (
		not is_inside_tree()
		or is_queued_for_deletion()
		or not _pending_target_presentations.has(receipt_id)
	):
		return false
	var record := _pending_target_presentations[receipt_id] as Dictionary
	_pending_target_presentations.erase(receipt_id)
	_pending_target_presentation_order.erase(receipt_id)
	var target_ref := record.get("target") as WeakRef
	var target := target_ref.get_ref() as StaticBody3D if target_ref != null else null
	if not is_instance_valid(target):
		return false
	if bool(record.terminal):
		present_authorized_target_destruction(target, record.hit_position)
	else:
		_spawn_impact(record.hit_position, KETH_ORANGE)
	return true


func get_visual_quality_report() -> Dictionary:
	return _visual_quality_report.duplicate(true)


func get_station_solar_readability_report() -> Dictionary:
	return {
		"active": _station_solar_readability_presentation != null,
		"attach_count": _station_solar_readability_attach_count,
		"detach_count": _station_solar_readability_detach_count,
		"last_result": _last_station_solar_readability_result.duplicate(true),
		"presentation": (
			_station_solar_readability_presentation.call(&"get_snapshot")
			if _station_solar_readability_presentation != null else {}
		),
	}.duplicate(true)


func get_space_backdrop_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SPACE_BACKDROP_SCHEMA_VERSION,
		"module_id": SPACE_BACKDROP_MODULE_ID,
		"sources": PackedStringArray(["A8", "B1", "B2", "B3", "B4"]),
		"source_bounded": true,
		"broad_composition_supported": true,
		"authenticated_exact_count": false,
		"authenticated_exact_placement": false,
		"authenticated_exact_scale": false,
		"authenticated_exact_materials": false,
		"content_note": (
			"Registered sources support near-black dense stars, large simple colourful "
			+ "bodies, exposed grey station forms, and pale craft as a broad relationship. "
			+ "The exact four-body count, blocking colours, positions, radii, materials, "
			+ "star count, and nebula attenuation are modern composition decisions."
		),
	}.duplicate(true)


static func _sky_color_matches(material: ShaderMaterial, name: StringName, expected: Color) -> bool:
	var value = material.get_shader_parameter(name)
	return value is Color and (value as Color).is_equal_approx(expected)


static func _sky_vector_matches(material: ShaderMaterial, name: StringName, expected: Vector3) -> bool:
	var value = material.get_shader_parameter(name)
	return value is Vector3 and (value as Vector3).is_equal_approx(expected)


static func _sky_scalar_matches(material: ShaderMaterial, name: StringName, expected: float) -> bool:
	var value = material.get_shader_parameter(name)
	return (value is float or value is int) and is_equal_approx(float(value), expected)


func get_space_backdrop_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var backdrop := get_node_or_null(^"SpaceBackdrop") as Node3D
	var stars := get_node_or_null(^"SpaceBackdrop/ParallaxStars") as MultiMeshInstance3D
	var environment_node := get_node_or_null(^"ShipyardEnvironment") as WorldEnvironment
	var environment := environment_node.environment if environment_node != null else null
	var sky_material: ShaderMaterial = null
	var mesh_resource_ids: Dictionary = {}
	var material_resource_ids: Dictionary = {}
	var surface_submission_count := 0
	var visible_copy_count := 0
	if environment != null and environment.sky != null:
		sky_material = environment.sky.sky_material as ShaderMaterial
	if backdrop == null:
		errors.append("SpaceBackdrop root is unavailable")
	elif (
		backdrop.get_meta(&"presentation_only", false) != true
		or backdrop.get_meta(&"gameplay_authority", true) != false
	):
		errors.append("space backdrop authority metadata drifted")
	# Re-frozen from the ProceduralSkyMaterial contract. The four hemisphere
	# colours it used to check no longer exist: the sky is a shader now, because
	# the procedural material's sky/ground model drew a ruled horizon across every
	# wide frame and could not give the ambient or the reflections any lateral
	# structure. What is asserted is unchanged in kind — the sky's entire authored
	# state, exactly, plus the survival of the project-original nebula at the same
	# faint eight percent — only the property names moved.
	if sky_material == null:
		errors.append("deep-space sky shader material is unavailable")
	else:
		if (
			sky_material.shader == null
			or sky_material.shader.resource_path != SKY_SHADER_PATH
		):
			errors.append("deep-space sky shader binding drifted")
		if (
			not _sky_color_matches(sky_material, &"zenith_color", SKY_ZENITH_COLOR)
			or not _sky_color_matches(sky_material, &"nadir_color", SKY_NADIR_COLOR)
			or not _sky_color_matches(sky_material, &"band_color", SKY_BAND_COLOR)
			or not _sky_color_matches(sky_material, &"core_color", SKY_CORE_COLOR)
			or not _sky_color_matches(sky_material, &"sun_color", SKY_SUN_COLOR)
		):
			errors.append("deep-space sky palette drifted")
		if (
			not _sky_vector_matches(sky_material, &"band_axis", SKY_BAND_AXIS)
			or not _sky_vector_matches(sky_material, &"core_axis", SKY_CORE_AXIS)
			or not _sky_scalar_matches(sky_material, &"band_width", SKY_BAND_WIDTH)
			or not _sky_scalar_matches(sky_material, &"core_focus", SKY_CORE_FOCUS)
			or not _sky_scalar_matches(sky_material, &"dust_scale", SKY_DUST_SCALE)
		):
			errors.append("deep-space sky composition drifted")
		# The sky's sun glow and the key light are one aim by construction. This is
		# the assertion that keeps them one aim.
		if (
			not _sky_vector_matches(sky_material, &"sun_direction", sky_sun_direction())
			or not _sky_scalar_matches(sky_material, &"sun_focus", SKY_SUN_FOCUS)
			or not _sky_scalar_matches(sky_material, &"sun_halo", SKY_SUN_HALO)
			or not _sky_scalar_matches(
				sky_material, &"sun_halo_focus", SKY_SUN_HALO_FOCUS
			)
		):
			errors.append("deep-space sky sun disagrees with the key light aim")
		var cover := sky_material.get_shader_parameter(&"nebula_cover") as Texture2D
		if (
			cover == null
			or cover.resource_path != "res://assets/keth-nebula.png"
			or not _sky_scalar_matches(
				sky_material, &"nebula_strength", SPACE_BACKDROP_NEBULA_COVER_STRENGTH
			)
		):
			errors.append("faint legacy-nebula cover contract drifted")
	var solar_readability_audit := (
		_station_solar_readability_presentation.call(&"audit") as Dictionary
		if _station_solar_readability_presentation != null else {}
	)
	if not bool(solar_readability_audit.get("valid", false)):
		errors.append("station solar readability presentation is unavailable")
	if (
		stars == null
		or stars.multimesh == null
		or stars.multimesh.instance_count != SPACE_BACKDROP_STAR_COUNT
		or not stars.multimesh.use_colors
		or stars.multimesh.transform_format != MultiMesh.TRANSFORM_3D
		or stars.multimesh.mesh is not SphereMesh
		or stars.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		or stars.gi_mode != GeometryInstance3D.GI_MODE_DISABLED
	):
		errors.append("deterministic instanced star-shell contract drifted")
	elif stars.multimesh.mesh is SphereMesh:
		var star_sphere := stars.multimesh.mesh as SphereMesh
		var star_material := star_sphere.material as StandardMaterial3D
		mesh_resource_ids[star_sphere.get_instance_id()] = true
		if star_material != null:
			material_resource_ids[star_material.get_instance_id()] = true
		surface_submission_count += star_sphere.get_surface_count()
		visible_copy_count += (
			stars.multimesh.instance_count
			if stars.multimesh.visible_instance_count < 0
			else stars.multimesh.visible_instance_count
		)
		if (
			not is_equal_approx(star_sphere.radius, 0.9)
			or not is_equal_approx(star_sphere.height, 1.8)
			or star_sphere.radial_segments != 6
			or star_sphere.rings != 3
			or star_material == null
			or star_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
			or not star_material.vertex_color_use_as_albedo
			or not star_material.emission_enabled
			or not is_equal_approx(star_material.emission_energy_multiplier, 0.55)
		):
			errors.append("star mesh or material readability contract drifted")
		if not stars.custom_aabb.is_equal_approx(
			AABB(Vector3.ONE * -SPACE_BACKDROP_STAR_RADIUS_MAX, Vector3.ONE * SPACE_BACKDROP_STAR_RADIUS_MAX * 2.0)
		):
			errors.append("star shell culling envelope drifted")

	var body_specs: Dictionary = {}
	for body_name: StringName in SPACE_BACKDROP_BODY_SPECS:
		var spec := SPACE_BACKDROP_BODY_SPECS[body_name] as Dictionary
		body_specs[body_name] = spec.duplicate(true)
		var body := get_node_or_null(NodePath("SpaceBackdrop/%s" % String(body_name))) as MeshInstance3D
		if body == null or body.mesh is not SphereMesh:
			errors.append("space body is unavailable: %s" % String(body_name))
			continue
		var sphere := body.mesh as SphereMesh
		var material := body.material_override as StandardMaterial3D
		mesh_resource_ids[sphere.get_instance_id()] = true
		if material != null:
			material_resource_ids[material.get_instance_id()] = true
		surface_submission_count += sphere.get_surface_count()
		visible_copy_count += 1
		if (
			not body.position.is_equal_approx(spec.position as Vector3)
			or not body.scale.is_equal_approx(Vector3.ONE * float(spec.radius))
			or not is_equal_approx(sphere.radius, SPACE_BACKDROP_BODY_MESH_RADIUS)
			or not is_equal_approx(sphere.height, SPACE_BACKDROP_BODY_MESH_RADIUS * 2.0)
			or sphere.radial_segments != SPACE_BACKDROP_BODY_MESH_RADIAL_SEGMENTS
			or sphere.rings != SPACE_BACKDROP_BODY_MESH_RINGS
			or material == null
			or not material.albedo_color.is_equal_approx(spec.color as Color)
			or not material.emission_enabled
			or not material.emission.is_equal_approx(spec.color as Color)
			# Re-frozen from 0.32/0.9 by the anti-flare presentation pass. See the body material
			# construction for the full reason: at 0.32 emission each body filled its
			# own night side back in and rendered as a flat saturated disc rather
			# than a lit sphere. Still an exact equality, still the same four
			# source-bounded colours and placements, with deliberately bounded radii.
			or not is_equal_approx(material.emission_energy_multiplier, 0.04)
			or not is_equal_approx(material.roughness, 1.0)
			or body.get_meta(&"palette_role", &"") != spec.palette_role
			or body.get_meta(&"visual_resource_family_id", &"") != SPACE_BACKDROP_BODY_MESH_FAMILY_ID
			or body.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			or body.gi_mode != GeometryInstance3D.GI_MODE_DISABLED
		):
			errors.append("space body presentation contract drifted: %s" % String(body_name))

	var authority_node_count := 0
	var renderable_count := 0
	if backdrop != null:
		if backdrop.get_child_count() != SPACE_BACKDROP_BODY_SPECS.size() + 1:
			errors.append("space backdrop direct-child roster drifted")
		for candidate in backdrop.find_children("*", "Node", true, false):
			if candidate is GeometryInstance3D:
				renderable_count += 1
			if (
				candidate is CollisionObject3D
				or candidate is CollisionShape3D
				or candidate is Light3D
				or candidate is GPUParticles3D
				or candidate is CPUParticles3D
				or candidate is AudioStreamPlayer
				or candidate is AudioStreamPlayer3D
				or candidate is Camera3D
				or candidate is NavigationRegion3D
			):
				authority_node_count += 1
	if authority_node_count != 0:
		errors.append("space backdrop gained gameplay or active presentation authority")
	if renderable_count != SPACE_BACKDROP_BODY_SPECS.size() + 1:
		errors.append("space backdrop renderable roster drifted")
	if mesh_resource_ids.size() != 2:
		errors.append("space backdrop immutable mesh sharing drifted")
	if material_resource_ids.size() != 5:
		errors.append("space backdrop distinct material roster drifted")
	if surface_submission_count != 5 or visible_copy_count != 2604:
		errors.append("space backdrop bounded renderer counts drifted")

	return {
		"schema_version": SPACE_BACKDROP_SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"module_id": SPACE_BACKDROP_MODULE_ID,
		"evidence": get_space_backdrop_evidence_metadata(),
		"star_seed": SPACE_BACKDROP_STAR_SEED,
		"star_count": SPACE_BACKDROP_STAR_COUNT,
		"star_radius_min": SPACE_BACKDROP_STAR_RADIUS_MIN,
		"star_radius_max": SPACE_BACKDROP_STAR_RADIUS_MAX,
		"body_count": SPACE_BACKDROP_BODY_SPECS.size(),
		"body_specs": body_specs,
		"near_black_sky": sky_material != null and errors.find("deep-space sky palette drifted") < 0,
		"sky_shader_path": SKY_SHADER_PATH,
		"sky_sun_direction": sky_sun_direction(),
		"legacy_nebula_cover_strength": SPACE_BACKDROP_NEBULA_COVER_STRENGTH,
		"authority_node_count": authority_node_count,
		"renderable_count": renderable_count,
		"runtime_draw_upper_bound": SPACE_BACKDROP_BODY_SPECS.size() + 1,
		# 2,600 instances * 48 star triangles + 4 bodies * 624 triangles.
		"runtime_triangle_upper_bound": 127_296,
		"performance": {
			"mesh_resource_count": mesh_resource_ids.size(),
			"material_resource_count": material_resource_ids.size(),
			"renderer_node_count": renderable_count,
			"surface_submission_count": surface_submission_count,
			"visible_copy_count": visible_copy_count,
			"triangle_count": 127_296,
		},
		"target_count": get_target_count(),
		# Deliberately enumerated rather than derived from get_berth_ids(): the
		# suite compares this list, the live registry and its own expectation
		# against each other, so an independent statement here is what catches
		# drift. Deriving it would make that comparison tautological.
		# HALYARD_FLEET_DOCK_BERTH_ID was missing when the fifth craft landed,
		# so this report under-stated the registry while the live one was right.
		"berth_ids": PackedStringArray([
			String(CENTRAL_BERTH_ID),
			String(ARROW_RECON_BERTH_ID),
			String(JOVIAN_FREIGHT_BERTH_ID),
			String(ZENITH_FLEET_DOCK_BERTH_ID),
			String(HALYARD_FLEET_DOCK_BERTH_ID),
		]),
	}.duplicate(true)


## Explicit evidence boundary for the central Torrent presentation. The
## authoritative ShipBerth remains scene-owned; this reports only the modern
## visual/operational dressing assembled around it.
func get_central_berth_evidence_metadata() -> Dictionary:
	return {
		"schema_version": CENTRAL_HERO_SCHEMA_VERSION,
		"module_id": CENTRAL_HERO_MODULE_ID,
		"berth_id": CENTRAL_BERTH_ID,
		"ship_id": CENTRAL_HERO_SHIP_ID,
		"evidence_status": CENTRAL_HERO_EVIDENCE_STATUS,
		"creator_supported": PackedStringArray(["Torrent class name", "interceptor role"]),
		"modern_provisional": PackedStringArray([
			"name-to-model mapping",
			"craft-to-berth alignment",
			"berth geometry and dimensions",
			"trusses and docking clamps",
			"utility and service equipment",
			"deck finish, markings, and lighting",
			"station placement and adjacency",
		]),
		"source_bounded": true,
		"authenticated_original_geometry": false,
		"authenticated_berth_layout": false,
		"content_note": CENTRAL_HERO_CONTENT_NOTE,
	}.duplicate(true)


func get_central_berth_hero_presentation() -> CentralBerthHeroPresentation:
	return (
		_central_berth_hero_presentation
		if is_instance_valid(_central_berth_hero_presentation) else null
	)


## Deep-detached construction audit for focused visual, clearance, and material
## tests. It intentionally does not claim that modern presentation metadata is
## historical evidence.
func get_central_berth_audit_report() -> Dictionary:
	var hero_root := _central_berth_root
	if hero_root == null:
		hero_root = get_node_or_null("LandingPad") as Node3D
	var feature_counts := _get_central_feature_counts(hero_root)
	var errors: PackedStringArray = []
	var expected_counts := {
		&"docking_clamp": 3,
		&"umbilical_housing": 3,
		&"parked_umbilical_hose": 3,
		&"service_cabinet": 1,
		&"cable_trench": 2,
		&"drain": 4,
		&"recessed_fixture": 8,
		&"control_pedestal": 1,
		&"work_detail": 6,
		&"reflection_probe": 1,
	}
	if hero_root == null:
		errors.append("LandingPad hero-cell root is unavailable")
	var authored_presentation := get_central_berth_hero_presentation()
	var authored_audit: Dictionary = {}
	if authored_presentation == null:
		errors.append("Blender-authored central berth presentation is unavailable")
	else:
		authored_audit = authored_presentation.get_asset_audit_report()
		if (
			authored_presentation.get_parent() != hero_root
			or authored_presentation.name != &"CentralBerthHeroPresentation"
			or authored_presentation.top_level
			or not authored_presentation.transform.is_equal_approx(Transform3D.IDENTITY)
		):
			errors.append("Blender-authored presentation mount changed")
		if not bool(authored_audit.get("valid", false)):
			errors.append("Blender-authored presentation audit is red")
	if hero_root != null and (
		hero_root.get_node_or_null(^"PadInset") != null
		or hero_root.get_node_or_null(^"HeroBerthStructure") != null
	):
		errors.append("legacy procedural central berth shell is still present")
	for feature_id: StringName in expected_counts:
		var actual_count := int(feature_counts.get(feature_id, 0))
		var expected_count := int(expected_counts[feature_id])
		if actual_count != expected_count:
			errors.append(
				"%s feature count is %d, expected %d"
				% [feature_id, actual_count, expected_count]
			)

	var berth_transform := get_berth_transform(CENTRAL_BERTH_ID)
	if not berth_transform.origin.is_equal_approx(Vector3(0.0, 1.15, -10.0)) \
			or not berth_transform.basis.is_equal_approx(Basis.IDENTITY):
		errors.append("central berth transform changed")
	var berth_node := get_berth_node(CENTRAL_BERTH_ID)
	if berth_node == null \
			or not berth_node.get_landing_half_extents().is_equal_approx(Vector3(12.0, 3.8, 17.0)):
		errors.append("central berth landing envelope changed")

	var gear_contacts := {}
	for contact_id: StringName in TORRENT_GEAR_CONTACT_OFFSETS:
		gear_contacts[contact_id] = berth_transform * (TORRENT_GEAR_CONTACT_OFFSETS[contact_id] as Vector3)

	return {
		"schema_version": CENTRAL_HERO_SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"module_id": CENTRAL_HERO_MODULE_ID,
		"berth_id": CENTRAL_BERTH_ID,
		"ship_id": CENTRAL_HERO_SHIP_ID,
		"evidence": get_central_berth_evidence_metadata(),
		"feature_counts": feature_counts,
		"expected_feature_counts": expected_counts,
		"gear_contact_positions": gear_contacts,
		"landing_half_extents": Vector3(12.0, 3.8, 17.0),
		"protected_small_craft_half_width": 6.5,
		"protected_small_craft_half_length": 6.6,
		"presentation_collision_free": true,
		"authored_presentation": true,
		"authored_asset_valid": bool(authored_audit.get("valid", false)),
		"authored_asset_audit": authored_audit,
		"deck_pbr": {
			"albedo": str((authored_audit.get("deck_maps", {}) as Dictionary).get("albedo", "")),
			"normal": str((authored_audit.get("deck_maps", {}) as Dictionary).get("normal", "")),
			"roughness": str((authored_audit.get("deck_maps", {}) as Dictionary).get("roughness", "")),
			"texture_coordinate": authored_audit.get("deck_texture_coordinate", &""),
			"triplanar": bool(authored_audit.get("deck_triplanar", true)),
			"scope": &"operational_walking_surface_only",
		},
	}.duplicate(true)


func _get_central_feature_counts(hero_root: Node3D) -> Dictionary:
	var counts := {}
	if hero_root == null:
		return counts
	for candidate in hero_root.find_children("*", "", true, false):
		var feature_id := StringName(candidate.get_meta("central_berth_feature", &""))
		if feature_id.is_empty():
			continue
		counts[feature_id] = int(counts.get(feature_id, 0)) + 1
	return counts


## Reapplies the selected profile to this world's existing environment. This
## is deliberately local to the active viewport and does not mutate global
## renderer ProjectSettings.
func apply_visual_quality(quality_level: int) -> Dictionary:
	if not _can_apply_visual_quality():
		return get_visual_quality_report()
	# Restore the previous profile's exact source values before selecting another
	# one; the station-specific caps are always derived from the new profile, never
	# compounded across settings changes.
	_retire_station_solar_readability(&"visual_quality_reselected")
	visual_quality_level = clampi(quality_level, 0, 2)
	_apply_operational_dressing_quality()
	var world_environment := get_node_or_null("ShipyardEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		_visual_quality_report = {
			"applied": false,
			"reason": &"environment_unavailable",
			"requested_quality": visual_quality_level,
		}
		return get_visual_quality_report()
	_visual_quality_report = VisualQualityController.apply_profile(
		world_environment.environment,
		get_viewport(),
		visual_quality_level
	)
	_present_station_solar_readability()
	return get_visual_quality_report()


func _present_station_solar_readability() -> Dictionary:
	if _station_solar_readability_presentation != null:
		return _last_station_solar_readability_result.duplicate(true)
	var world_environment := get_node_or_null(^"ShipyardEnvironment") as WorldEnvironment
	var environment := (
		world_environment.environment if world_environment != null else null
	)
	var sky_material: ShaderMaterial = null
	if environment != null and environment.sky != null:
		sky_material = environment.sky.sky_material as ShaderMaterial
	if environment == null or sky_material == null:
		_last_station_solar_readability_result = {
			"accepted": false,
			"reason": &"station_environment_unavailable",
		}
		return _last_station_solar_readability_result.duplicate(true)
	var candidate := STATION_SOLAR_READABILITY_SCRIPT.new() as RefCounted
	var configured := candidate.call(
		&"configure", environment, sky_material
	) as Dictionary
	_last_station_solar_readability_result = configured.duplicate(true)
	if not bool(configured.get("accepted", false)):
		return configured.duplicate(true)
	_station_solar_readability_presentation = candidate
	_station_solar_readability_attach_count += 1
	return configured.duplicate(true)


func _retire_station_solar_readability(reason: StringName) -> void:
	if _station_solar_readability_presentation == null:
		return
	var result := _station_solar_readability_presentation.call(
		&"detach", reason,
		_station_solar_readability_presentation.call(&"get_generation")
	) as Dictionary
	_last_station_solar_readability_result = result.duplicate(true)
	if bool(result.get("accepted", false)):
		_station_solar_readability_presentation = null
		_station_solar_readability_detach_count += 1


func _restore_station_solar_readability_after_reentry() -> void:
	if _built and is_inside_tree() \
			and _station_solar_readability_presentation == null:
		_present_station_solar_readability()


func _can_apply_visual_quality() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _create_materials() -> void:
	# Metalness and roughness now separate the roles instead of only the hue.
	# Every opaque hub surface previously sat inside metallic 0.08-0.32 and
	# roughness 0.48-0.78, so two adjacent surfaces answered the same light almost
	# identically and the whole station read as one painted polymer. The structural
	# steel roles are raised toward the range the service dressing and the Freight
	# berth already use, traffic-worn deck plate stays low-metal and rough, and the
	# painted roles stay paint. Colours are unchanged.
	#
	# The cap that used to sit on metalness is lifted, and the reason it existed is
	# gone. It was capped because reflections are sourced from the background and
	# the background was uniformly near-black, so metalness had nothing to return
	# and only subtracted diffuse. The sky now carries a dust band, a warm core and
	# a sun halo, which is a real if dim environment to reflect, so the roles that
	# are supposed to be metal can finally be metal.
	#
	# The spread is the point. The old set ran 0.06-0.50 metallic over 0.34-0.82
	# roughness with the two loosely correlated, which is one material family with
	# a slider on it: everything answered a highlight the same way and only the hue
	# changed. Real dock hardware separates hard, so the roles are pushed apart
	# into recognisably different substances rather than ranked along one axis:
	#
	#   deck        0.06/0.82 -> 0.04/0.88  traffic-worn plate; almost no highlight
	#   deck_light  0.14/0.70 -> 0.10/0.74  the same plate, less walked on
	#   navy        0.18/0.60 -> 0.30/0.55  painted structural steel
	#   blue        0.42/0.42 -> 0.72/0.34  bare structural steel
	#   steel_blue  0.50/0.34 -> 0.86/0.22  polished mast and keel stock
	#   ivory       0.05/0.62 -> 0.02/0.48  gloss paint, carried by clearcoat
	#   orange      0.10/0.56 -> 0.02/0.52  the same gloss paint, hazard ochre
	#   red         0.08/0.54 -> 0.02/0.50  the same gloss paint, alert
	#   black       0.34/0.66 -> 0.02/0.94  rubber and composite, not dark metal
	#
	# `black` moving from mid-metal to a dead-matte non-metal is the largest single
	# jump and the most useful one: it covers gaskets, treads, kick plates and
	# service dressing, and while it was 0.34 metallic those all carried a faint
	# sheen that made them read as painted plastic parts. At 0.94 roughness and
	# effectively no metalness they read as rubber, which gives the frame a genuine
	# matte end to sit against the polished end. Its colour moves 03080d -> 0a0c0d
	# in the same step: at 0.94 roughness a nearly pure black albedo returns almost
	# nothing at all and the role dropped out of the frame entirely, so it comes up
	# to a very dark neutral that can still show a form.
	#
	# Colours here are unchanged except where the palette block above changed them,
	# and `orange` is the one role whose *identity* moved: it now takes
	# HAZARD_AMBER rather than the signal-orange the warning lamps use. See the
	# palette block for why.
	_materials["deck"] = _material(DECK, 0.04, 0.88)
	_materials["deck_light"] = _material(DECK_LIGHT, 0.1, 0.74)
	_materials["navy"] = _material(NAVY, 0.3, 0.55)
	_materials["blue"] = _material(DEEP_BLUE, 0.72, 0.34)
	_materials["steel_blue"] = _material(STEEL_BLUE, 0.86, 0.22)
	_materials["ivory"] = _painted_material(IVORY, 0.48)
	_materials["orange"] = _painted_material(HAZARD_AMBER, 0.52)
	_materials["red"] = _painted_material(ALERT_RED, 0.5)
	_materials["black"] = _material(Color("0a0c0d"), 0.02, 0.94)
	_materials["cyan_glow"] = _material(
		KETH_CYAN,
		0.05,
		0.34,
		KETH_CYAN,
		1.65
	)
	_materials["orange_glow"] = _material(
		KETH_ORANGE,
		0.04,
		0.34,
		KETH_ORANGE,
		1.8
	)
	_materials["red_glow"] = _material(
		ALERT_RED,
		0.03,
		0.4,
		ALERT_RED,
		2.0
	)
	_materials["white_glow"] = _material(
		Color("f4fff9"),
		0.03,
		0.35,
		Color("d8fff5"),
		1.4
	)
	_materials["glass"] = _transparent_material(GLASS, 0.12, 0.15)
	_materials["berth_cyan_glow"] = _material(
		Color("63dadd"),
		0.12,
		0.42,
		Color("39bfc4"),
		0.62
	)
	_materials["berth_orange_glow"] = _material(
		Color("e99a46"),
		0.12,
		0.43,
		Color("d7772d"),
		0.72
	)
	_apply_station_panel_family()


## Bind the registered station panel/normal/roughness recipe to the hub's
## structural and deck greys.
##
## This was the largest single gap in the presentation. The hub's boxes have been
## chamfered for a long time, but `_material()` produced pure scalar colour: no
## albedo texture, no normal, no roughness map, no triplanar. That left roughly
## 6.6 thousand square metres of walkable deck and another 2.8 thousand of keels,
## cross braces and pods rendering as unbroken plastic in three colours, directly
## alongside four modules that were already plated. Bevelling alone cannot fix
## that; a 1.8 thousand square metre deck needs surface information across its
## face, not only at its edge.
##
## The recipe, `normal_scale`, red-channel roughness, world-triplanar mode and
## sharpness are copied verbatim from `AftJunctionStack`, at that module's 0.30
## physical scale, so the hub is stamped from the same plate stock as everything
## that joins it. Only structural roles are bound: hazard paint, every emissive
## legend and the transparent glass deliberately stay unmapped, as they do in the
## sibling modules, so signage and lit cues keep their flat readable identity.
func _apply_station_panel_family() -> void:
	# Keep the shared map recipe in StationSurfaceKit so the world and authored
	# modules cannot drift. The finish is deliberately role-specific: deck plate
	# should not sparkle like a polished handrail, while structural trim needs a
	# tighter edge response to remain legible at the wide-lattice read distance.
	var finish_by_key := {
		"deck": StationSurfaceKit.PanelFinish.WALKED_DECK,
		"deck_light": StationSurfaceKit.PanelFinish.WALKED_DECK,
		"steel_blue": StationSurfaceKit.PanelFinish.METAL_TRIM,
		# Paired guard rails/posts and their red service equipment are one coated
		# safety-furniture family. Keep the shared panel grain without flattening
		# their paint into the generic structural-alloy response.
		"ivory": StationSurfaceKit.PanelFinish.PAINTED_METAL,
		"orange": StationSurfaceKit.PanelFinish.PAINTED_METAL,
		"red": StationSurfaceKit.PanelFinish.PAINTED_METAL,
	}
	for key in [
		"deck", "deck_light", "navy", "blue", "steel_blue",
		"ivory", "black", "orange", "red",
	]:
		var panel_material := _materials[key] as StandardMaterial3D
		StationSurfaceKit.apply_panel_triplanar(
			panel_material,
			0.3,
			finish_by_key.get(key, StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY)
		)


## Unit vector pointing from the station *toward* the sun.
##
## A DirectionalLight3D emits along its local -Z, so the direction light arrives
## from is its basis' +Z. Deriving the sky's glow from the same rotation the key
## light is given is what keeps the two from drifting apart; it is exposed rather
## than inlined so a test can assert the agreement instead of trusting it.
static func sky_sun_direction() -> Vector3:
	return Basis.from_euler(
		Vector3(
			deg_to_rad(KEY_LIGHT_ROTATION_DEGREES.x),
			deg_to_rad(KEY_LIGHT_ROTATION_DEGREES.y),
			deg_to_rad(KEY_LIGHT_ROTATION_DEGREES.z)
		)
	).z.normalized()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ShipyardEnvironment"
	var environment := Environment.new()
	var sky := Sky.new()
	# Original-era and later surviving sources consistently read as near-black space
	# with dense stars and large simple colour bodies. Retain the project-original
	# nebula only as faint modern atmosphere rather than the live composition's
	# dominant identity. Exact colours/placement remain explicitly unauthenticated.
	#
	# The sky is no longer a ProceduralSkyMaterial. That material is built out of a
	# sky hemisphere blended into a *ground* hemisphere, and in a vacuum scene the
	# ground half is a liability: with the four authored colours it drew a ruled
	# horizontal line across the middle of every wide frame, which read as a
	# distant wall standing behind the station. Softening the two curves in an
	# earlier pass spread the line but did not remove it, because the model itself
	# has an equator. See `deep_space_sky.gdshader` for the full reasoning; in
	# short, the sky here has two structural jobs beyond being a backdrop, and the
	# procedural material could do neither:
	#
	#   * It is the ambient source. Ambient with no lateral structure lands on
	#     every face identically no matter which way the face points, which is the
	#     single most reliable way to make a scene read as filled rather than lit.
	#     The dust band is bright on one side of the sphere and dark on the other,
	#     so the fill itself now has a direction.
	#   * It is the reflection source. Against a uniformly near-black background
	#     metalness had nothing to return, which is why every broad structural
	#     role was pinned to low metallic and the whole station answered light like
	#     one painted polymer. A band and a sun glow give metal something to
	#     reflect, which is what unlocks the material split below.
	#
	# The sun is a glow, not a disc, and it is aimed by the same constant that
	# aims the key light, so the bright quarter of the sky and the lit face of
	# every surface cannot disagree.
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load(SKY_SHADER_PATH) as Shader
	sky_material.set_shader_parameter(&"band_axis", SKY_BAND_AXIS)
	sky_material.set_shader_parameter(&"band_width", SKY_BAND_WIDTH)
	sky_material.set_shader_parameter(&"band_color", SKY_BAND_COLOR)
	sky_material.set_shader_parameter(&"core_color", SKY_CORE_COLOR)
	sky_material.set_shader_parameter(&"core_axis", SKY_CORE_AXIS)
	sky_material.set_shader_parameter(&"core_focus", SKY_CORE_FOCUS)
	sky_material.set_shader_parameter(&"zenith_color", SKY_ZENITH_COLOR)
	sky_material.set_shader_parameter(&"nadir_color", SKY_NADIR_COLOR)
	sky_material.set_shader_parameter(&"sun_direction", sky_sun_direction())
	sky_material.set_shader_parameter(&"sun_color", SKY_SUN_COLOR)
	sky_material.set_shader_parameter(&"sun_focus", SKY_SUN_FOCUS)
	sky_material.set_shader_parameter(&"sun_halo", SKY_SUN_HALO)
	sky_material.set_shader_parameter(&"sun_halo_focus", SKY_SUN_HALO_FOCUS)
	sky_material.set_shader_parameter(&"dust_scale", SKY_DUST_SCALE)
	sky_material.set_shader_parameter(
		&"nebula_cover",
		load("res://assets/keth-nebula.png") as Texture2D
	)
	sky_material.set_shader_parameter(
		&"nebula_strength",
		SPACE_BACKDROP_NEBULA_COVER_STRENGTH
	)
	sky.sky_material = sky_material
	# Nothing in this sky animates, so it never needs re-integrating per frame.
	# High quality resolves the band and the sun halo into the radiance map once.
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# Lowered from 0.8. This multiplier scales the sky both as drawn and as the
	# ambient source, and the sky it is now scaling carries a dust band and a sun
	# halo instead of a flat near-black gradient, so the same number delivers
	# considerably more light than it used to. It is brought down so the total
	# ambient budget is roughly held while its *composition* changes: the light
	# that remains arrives from a direction instead of from everywhere. Raising
	# this is the brightness knob that flattened the frame the last time it was
	# tried; the depth cue below and the widened key/fill ratio are what carry
	# contrast.
	environment.background_energy_multiplier = 0.95
	# Ambient comes from the sky rather than a single colour. A flat colour fill
	# lands identically on every face regardless of orientation, which is the
	# reason a bevelled box still reads as a toy: nothing distinguishes a deck top
	# from a catwalk underside except direct light. Sky ambient is hemispheric, so
	# up-facing surfaces take the star hemisphere and down-facing surfaces take the
	# darker ground hemisphere.
	#
	# Three quarters of the fill is that hemispheric sky. The remaining quarter is
	# a flat colour floor, kept because the backdrop is deliberately near-black:
	# pure sky ambient drove the outer Fleet Dock decks to near-black and cost
	# readability. `ambient_light_energy` also only applies while
	# `ambient_light_sky_contribution` is below 1.0, so this split is what makes
	# the level tunable at all. The colour is desaturated from the previous
	# `6db3bd` so the flat quarter stops tinting every face the same cyan. Levels
	# were set by measuring frame luminance against the old flat fill.
	#
	# The split moved from 0.75 to 0.82 after measuring the two terms separately.
	# `background_energy_multiplier` moves the hemispheric term and barely touched
	# the enclosed operations room and habitat; `ambient_light_energy` moves the
	# flat term and barely touched the open decks. They are not interchangeable.
	# Shifting the split toward the sky makes the added ambient orientation-
	# dependent on the exteriors, while the raised flat energy keeps the two
	# enclosed rooms — which the sky hemisphere cannot see into — from going
	# backwards. The flat term is now a smaller share of a larger total, which is
	# the opposite of a global gain.
	#
	# The split moves from 0.82 to 0.93 and the flat term's energy comes down with
	# it. The flat quarter was doing the job the sky could not do while the sky was
	# featureless; now that the sky has a band, a core and a sun side, the flat
	# term is mostly working against it, because a colour floor is by definition
	# the orientation-independent part of the fill. What is left of it is a floor
	# under the darkest faces so the outer Fleet Dock decks and the two enclosed
	# rooms do not fall out of the frame, and its colour is pulled further toward
	# neutral so it stops tinting every unlit face the same cyan.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.86
	environment.ambient_light_color = Color("5a656b")
	environment.ambient_light_energy = 6.4
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.94
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	environment.glow_bloom = 0.08

	# Atmospheric depth. This is the largest single change in the pass and the one
	# aimed squarely at the wide shot.
	#
	# The station is roughly 220 m corner to corner and the free-flight range runs
	# out past 165 m beyond it, and until now none of that distance was visible:
	# depth fog was on, but at density 0.00065 exponential it removed about 6% of
	# contrast at 100 m, which is nothing. A gantry 140 m away carried exactly the
	# same local contrast as a railing two metres from the camera, so the eye had
	# no cue for scale and a 220 m lattice read the size of a desk model. Distance
	# haze is the strongest realism cue available in a large exterior, and it was
	# effectively switched off.
	#
	# The mode changes from exponential to depth-ranged, which is the part that
	# makes the strength affordable. Exponential fog starts at the camera, so any
	# density strong enough to separate 150 m also veils the deck plate under the
	# player's feet and every interior. Depth-ranged fog contributes nothing at all
	# inside `fog_depth_begin`, so the near field, the berths and both enclosed
	# rooms are untouched by a cue that is entirely about the far field. That is
	# deliberately not a global gain knob: it is a change that is invisible under
	# 55 m and unmissable past 120 m. Every interior in the station, every berth
	# and the whole near deck sit inside `fog_depth_begin` and are untouched.
	#
	# `fog_depth_end` sits past the far corner of the lattice but well inside the
	# 900-1250 m celestial bodies, so a distant body is muted rather than erased,
	# and the 1450-1650 m star shell opts out of fog entirely at its material.
	#
	# `fog_light_energy` is the number this took the longest to get right, and the
	# reason is worth writing down. Fog only reads as *haze* if its colour sits
	# above the thing it is veiling. Here the background is vacuum, so at the
	# energy this started at the fog colour was darker than the station and the cue
	# rendered as "distant things get slightly dimmer" - measurable at about one
	# percent of frame mean, which is to say invisible. Turning the fog off
	# entirely and rendering the same frame changed the image by 0.8%. Raising the
	# energy until the haze sits above the station's shadow side is what turns the
	# same density into visible aerial perspective: far structure loses contrast
	# in both directions, lit faces coming down and unlit faces coming up.
	#
	# Aerial perspective is raised hard in the quality profiles so the haze takes
	# its colour from the sky in the view direction rather than being one flat slab
	# of blue laid over everything.
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 55.0
	environment.fog_depth_end = 260.0
	environment.fog_depth_curve = 0.55
	environment.fog_density = 0.42
	environment.fog_light_color = Color("4a6e82")
	environment.fog_light_energy = 1.6
	environment.fog_sky_affect = 0.0
	world_environment.environment = environment
	add_child(world_environment)
	_visual_quality_report = VisualQualityController.apply_profile(
		environment,
		get_viewport(),
		visual_quality_level
	)
	_present_station_solar_readability()

	# Key and counter-fill pair. A single grazing key gave every object exactly one
	# lit face and one dead face, which is the strongest "flat primitive" tell
	# after untextured albedo. Steepening the key raises NdotL on the broad decks
	# and the cool counter-fill from behind separates a shape's dark side from the
	# background instead of merging them. The fill casts no shadows: it is a
	# lighting device, not a second sun, and it must not double the shadow cost.
	#
	# The key is raised with the ambient rather than instead of it. Ambient lifts
	# lit and unlit faces equally, so raising it alone compresses the frame; the
	# key is raised in step so the ratio between a lit face and a shaded one is
	# wider than before, not narrower.
	#
	# `light_angular_distance` gives the sun a finite apparent size, so shadow
	# edges soften with distance from the caster instead of staying razor sharp at
	# every depth. A perfectly hard edge at 40 m is one of the tells that reads as
	# untextured primitives; this costs nothing but the existing shadow map.
	#
	# `directional_shadow_max_distance` came down from 180 m. The same shadow
	# atlas now covers 130 m, so the near field where the player actually walks
	# gets more texels and contact shadows under railings, treads and landing gear
	# resolve instead of dissolving. Nothing at the station is 130 m from the
	# camera and still expected to cast a legible shadow.
	#
	# The key's aim is `KEY_LIGHT_ROTATION_DEGREES`, the same constant the sky
	# shader's sun glow is derived from. A sun that is visible in the backdrop and
	# a sun that lights the geometry disagreeing about where they are is one of the
	# things that makes a backdrop read as wallpaper.
	#
	# Energy is raised again and `light_specular` with it. Ambient's flat term came
	# down in the same pass, so the ratio between a face this light reaches and a
	# face it does not is wider than before, not narrower. The specular rise
	# matters more than it used to: with a sky that has a bright side, a raised
	# specular response on a metal role now produces a highlight that moves across
	# the surface as the camera does, instead of a uniform sheen.
	var key_light := DirectionalLight3D.new()
	key_light.name = "SpaceKeyLight"
	key_light.rotation_degrees = KEY_LIGHT_ROTATION_DEGREES
	key_light.light_color = Color("cdeef2")
	key_light.light_energy = 2.2
	key_light.light_specular = 0.9
	key_light.light_angular_distance = 0.65
	key_light.shadow_enabled = true
	key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	key_light.directional_shadow_split_1 = 0.06
	key_light.directional_shadow_split_2 = 0.16
	key_light.directional_shadow_split_3 = 0.42
	key_light.directional_shadow_blend_splits = true
	key_light.directional_shadow_max_distance = 130.0
	add_child(key_light)

	var counter_fill := DirectionalLight3D.new()
	counter_fill.name = "SpaceCounterFill"
	counter_fill.rotation_degrees = Vector3(-16.0, 152.0, 0.0)
	counter_fill.light_color = Color("2f5a75")
	counter_fill.light_energy = 0.44
	counter_fill.light_specular = 0.45
	counter_fill.shadow_enabled = false
	add_child(counter_fill)

	# Deck bounce. The decks are the brightest large surfaces on the station, and
	# in a real dock they would throw light back up onto every hull underside,
	# catwalk soffit, landing-gear bay and equipment belly. Nothing did that here:
	# the key comes from above, the counter-fill comes from behind and level, so
	# every downward-facing surface in the station received only ambient. That is
	# why a parked craft read as a flat pale cut-out — its whole lower half sat at
	# one value with no gradient across it.
	#
	# This is aimed upward, casts no shadows, and carries no specular: a bounce is
	# diffuse, and giving it a highlight would read as a second sun under the
	# floor. Its colour is deliberately warm against the cool key and the cool
	# counter-fill. Three lights from three directions in three hues is what lets
	# a surface's orientation be read from its colour as well as its brightness,
	# and it is the cheapest way to stop a monochrome cyan scene reading as one
	# flat material.
	var deck_bounce := DirectionalLight3D.new()
	deck_bounce.name = "DeckBounceFill"
	deck_bounce.rotation_degrees = Vector3(58.0, 26.0, 0.0)
	deck_bounce.light_color = Color("b09070")
	deck_bounce.light_energy = 0.46
	deck_bounce.light_specular = 0.0
	deck_bounce.shadow_enabled = false
	deck_bounce.set_meta("diffuse_bounce_fill", true)
	add_child(deck_bounce)

	# Freestanding light masts keep the open decks readable without implying a
	# roof. Exact placement is a modern blockout decision.
	#
	# The cones were measured against the decks they are supposed to serve rather
	# than left at their authored numbers. A 39 degree cone from y = 9.0 lands a
	# 7.3 m radius pool, so the mast at x = -35 stopped at x = -42.3 and the Arrow
	# sitting at x = -43 was outside its own berth light entirely. Widening to 47
	# degrees and extending the range covers the berth the mast exists to light.
	# No light is added by this: the same six fixtures now reach the surfaces they
	# were placed for.
	#
	# `spot_angle_attenuation` softens the cone edge. At the default the pool ends
	# on a hard circular boundary across the deck plate, which reads as a painted
	# disc rather than a luminaire, and `spot_attenuation` below 1.0 slows the
	# distance falloff so the pool has a long tail instead of a sharp rim.
	var deck_lights := [
		Vector3(-11.5, 10.5, 10.0),
		Vector3(11.5, 10.5, 10.0),
		Vector3(-11.5, 10.5, -22.0),
		Vector3(11.5, 10.5, -22.0),
		Vector3(-35.0, 9.0, 16.0),
		Vector3(35.0, 9.0, 16.0),
	]
	for light_position in deck_lights:
		var light := SpotLight3D.new()
		var is_hero_work_light: bool = light_position.z < -10.0
		light.name = "HeroBerthWorkLight" if is_hero_work_light else "DockMastSpot"
		light.position = light_position
		light.rotation_degrees.x = -90.0
		light.light_color = Color("e3f1e9") if is_hero_work_light else Color("d7fffa")
		light.light_energy = 1.35 if is_hero_work_light else 1.7
		light.spot_range = 30.0 if is_hero_work_light else 36.0
		light.spot_angle = 47.0
		light.spot_angle_attenuation = 0.55
		light.spot_attenuation = 0.75
		light.shadow_enabled = true
		light.set_meta("central_berth_key_light", is_hero_work_light)
		add_child(light)

	# Two outer nodes had no mast of their own. The freight approach was lit only
	# by its module's own apron pair, which point at the apron and not at the
	# gantry work zone station-ward of it, and the Fleet Dock comb has no light
	# nodes at all by its own frozen contract — the Zenith parks there under
	# nothing but the key and whatever ambient reaches it. These are the same
	# freestanding mast idiom, placed over the two work zones the existing six
	# never covered, and they are the reason the fix is not a global gain.
	#
	# The freight mast casts shadows because the gantry, the racks and a parked
	# freighter are all inside its cone and the cast shadow is the point. The
	# fleet-dock mast does not: the comb is an open lattice, its shadow would be a
	# stripe pattern of no informational value, and one shadow map is enough new
	# per-frame cost to take without being able to measure it on this box.
	var outer_masts := [
		["FreightApproachMastSpot", Vector3(-53.0, 11.0, 30.5), Color("d7fffa"), 1.55, 34.0, true],
		["FleetDockMastSpot", Vector3(34.0, 10.5, 57.0), Color("cfeef0"), 1.35, 38.0, false],
	]
	for mast: Array in outer_masts:
		var light := SpotLight3D.new()
		light.name = str(mast[0])
		light.position = mast[1] as Vector3
		light.rotation_degrees.x = -90.0
		light.light_color = mast[2] as Color
		light.light_energy = float(mast[3])
		light.spot_range = float(mast[4])
		light.spot_angle = 47.0
		light.spot_angle_attenuation = 0.55
		light.spot_attenuation = 0.75
		light.shadow_enabled = bool(mast[5])
		light.set_meta("outer_node_work_mast", true)
		add_child(light)

	var landing_fill := OmniLight3D.new()
	landing_fill.name = "LandingPadFill"
	landing_fill.position = Vector3(0.0, 6.0, -10.0)
	landing_fill.light_color = Color("8bc6c4")
	landing_fill.light_energy = 0.52
	landing_fill.omni_range = 14.0
	landing_fill.omni_attenuation = 1.65
	landing_fill.shadow_enabled = false
	landing_fill.set_meta("restrained_hero_fill", true)
	add_child(landing_fill)


func _build_architecture() -> void:
	var shell := Node3D.new()
	shell.name = "ExposedDockLattice"
	add_child(shell)

	# Source material supports this hierarchy—central crossing, narrow orthogonal
	# arms, compact solid nodes, and substantial void—not these exact dimensions.
	# Each visible deck module carries its own collision; there is deliberately no
	# hidden full-footprint slab bridging the gaps.
	# The walkway stops at the authored central-berth shell's outer edge
	# (z = AUTHORED_CENTRAL_BERTH_EDGE_Z) instead of running 2.75 m underneath it.
	# The authored plate's deck panels bottom out at y = -0.005 and its recessed
	# service channels reach y = -0.110, while this walkway's top face is at
	# y = -0.020: over the old x = -12.5 … 12.5, z = 5.0 … 7.55 band the walkway
	# surface passed *through* the runway plate, and the grey deck read through the
	# runway's channels as a shimmering seam. Separating the two surfaces is the
	# fix; no material, depth-write or render-priority value is touched.
	_box(
		shell,
		"CentralJunction",
		Vector3(0, -0.62, (AUTHORED_CENTRAL_BERTH_EDGE_Z + 23.0) * 0.5),
		Vector3(25.0, 1.2, 23.0 - AUTHORED_CENTRAL_BERTH_EDGE_Z),
		_materials["deck"]
	)
	# The walkable floor must not move when the render slab does, so the hidden
	# hero-berth collision body takes over the 2.75 m the walkway gave up. Its top
	# face is the same y = -0.020 plane, so the physical surface is unchanged.
	# The width drops from 27.0 m to the authored shell's own 25.5 m. The extra
	# 0.75 m per side was collision the shell never rendered: a 0.75 x 32.75 m
	# invisible ledge down each flank of the central berth that a player could
	# stand on over open space. Nothing rendered moves — the render slab below is
	# hidden either way.
	var hero_berth_body := _box(
		shell,
		"HeroBerthNode",
		Vector3(0, -0.62, (-25.0 + AUTHORED_CENTRAL_BERTH_EDGE_Z) * 0.5),
		Vector3(25.5, 1.2, AUTHORED_CENTRAL_BERTH_EDGE_Z + 25.0),
		_materials["deck"]
	)
	# The physical floor remains authoritative, but its old generic render slab
	# must not double-render through the Blender-authored presentation shell.
	var legacy_hero_mesh := hero_berth_body.get_node_or_null(^"Mesh") as MeshInstance3D
	if legacy_hero_mesh != null:
		legacy_hero_mesh.visible = false
		legacy_hero_mesh.set_meta("hidden_by_authored_central_berth", true)
	# `JunctionLink` lies wholly inside the authored shell's footprint
	# (x = -6.5 … 6.5, z = -3.0 … 6.0 against the shell's -12.75 … 12.75 by
	# -27.75 … 7.75), so its render slab was the second surface the runway plate
	# was cutting through — 143 m² of it. It keeps its collision and takes the
	# same treatment the hero berth node already had.
	var junction_link_body := _box(
		shell,
		"JunctionLink",
		Vector3(0, -0.62, 1.5),
		Vector3(13.0, 1.2, 9.0),
		_materials["deck_light"]
	)
	var legacy_link_mesh := junction_link_body.get_node_or_null(^"Mesh") as MeshInstance3D
	if legacy_link_mesh != null:
		legacy_link_mesh.visible = false
		legacy_link_mesh.set_meta("hidden_by_authored_central_berth", true)
	# Branch arms butt against their berth nodes instead of overlapping them by
	# 0.5 m. The old overlap put two differently-materialled decks on one exact
	# y = -0.020 plane over 3.5 m² per side.
	_box(
		shell,
		"PortBranchArm",
		Vector3((PORT_BERTH_NODE_OUTER_X + PORT_BERTH_NODE_HALF_WIDTH - 12.5) * 0.5, -0.62, 15.5),
		Vector3(-12.5 - (PORT_BERTH_NODE_OUTER_X + PORT_BERTH_NODE_HALF_WIDTH), 1.2, 7.0),
		_materials["deck_light"]
	)
	# PORT-DECK-001. The parked Arrow is 12.2 m long on a deck that was 12.0 m
	# across, so its nose hung 0.450 m past the edge with two of four footprint
	# corners unsupported, and the berth cue strips lay entirely off the structure
	# they mark. 16.8 m is the measured Zenith-parity floor and leaves the craft
	# 1.95 m of apron at the nose and 2.65 m at the tail, so a player can walk a
	# full circuit around it.
	_box(
		shell,
		"PortBerthNode",
		Vector3(PORT_BERTH_NODE_OUTER_X, -0.62, 15.5),
		Vector3(PORT_BERTH_NODE_HALF_WIDTH * 2.0, 1.2, 17.0),
		_materials["deck"]
	)
	_box(shell, "StarboardBranchArm", Vector3(24.75, -0.62, 15.5), Vector3(24.5, 1.2, 7.0), _materials["deck_light"])
	_box(shell, "StarboardBerthNode", Vector3(43.0, -0.62, 15.5), Vector3(12.0, 1.2, 17.0), _materials["deck"])
	_box(shell, "AftSpine", Vector3(0, -0.62, 31.0), Vector3(8.0, 1.2, 16.0), _materials["deck_light"])
	# The first authored station module begins at Z=48. This narrow landing
	# bridges the original spine to that module's connection plane without
	# hiding its open-space footprint beneath a legacy service slab.
	_box(shell, "AftModuleConnector", Vector3(0, -0.62, 43.5), Vector3(7.0, 1.2, 9.0), _materials["deck_light"])

	# FABRICATION-INTEGRATION-001. The only path into the Annex is this exact
	# collision-backed 99 m2 dogleg. It leaves Dock Operations at x=49, runs
	# around its cargo edge, turns north, and opens through a short handoff into
	# the Annex apron at x=72. Adjacent slabs only touch at their boundaries; no
	# hidden overlap pads the walkable-area census.
	var fabrication_connector := Node3D.new()
	fabrication_connector.name = "FabricationAnnexConnector"
	fabrication_connector.set_meta("evidence_status", &"modern_interpretation")
	fabrication_connector.set_meta("connects_station_module", &"fabrication_annex")
	shell.add_child(fabrication_connector)
	var fabrication_deck_a := _box(
		fabrication_connector, "ConnectorDeckA", Vector3(59.5, 0.18, 28.0),
		Vector3(21.0, 0.4, 3.0), _materials["deck_light"]
	)
	var fabrication_deck_b := _box(
		fabrication_connector, "ConnectorDeckB", Vector3(68.5, 0.18, 34.5),
		Vector3(3.0, 0.4, 10.0), _materials["deck_light"]
	)
	var fabrication_deck_c := _box(
		fabrication_connector, "ConnectorDeckC", Vector3(71.0, 0.18, 38.0),
		Vector3(2.0, 0.4, 3.0), _materials["deck_light"]
	)
	for surface_spec in [
		[fabrication_deck_a, &"fabrication_connector_a", 63.0],
		[fabrication_deck_b, &"fabrication_connector_b", 30.0],
		[fabrication_deck_c, &"fabrication_connector_c", 6.0],
	]:
		var body := surface_spec[0] as StaticBody3D
		body.set_meta(&"walkable_surface", true)
		body.set_meta(&"walkable_surface_id", surface_spec[1] as StringName)
		body.set_meta(&"walkable_surface_kind", &"level")
		body.set_meta(&"walkable_surface_owner", &"station_hub")
		body.set_meta(&"horizontal_area_m2", surface_spec[2] as float)

	# Seven guarded outer edges preserve the two deliberate dogleg mouths and the
	# open C-to-Annex handoff. Rail dimensions are the reviewed siting contract.
	for rail_spec in [
		["ConnectorRailASouth", Vector3(59.5, 1.10, 26.5), Vector3(21.0, 1.44, 0.14)],
		["ConnectorRailANorth", Vector3(58.0, 1.10, 29.5), Vector3(18.0, 1.44, 0.14)],
		["ConnectorRailBWest", Vector3(67.0, 1.10, 34.5), Vector3(0.14, 1.44, 10.0)],
		["ConnectorRailBEast", Vector3(70.0, 1.10, 33.0), Vector3(0.14, 1.44, 7.0)],
		["ConnectorRailBNorth", Vector3(68.5, 1.10, 39.5), Vector3(3.0, 1.44, 0.14)],
		["ConnectorRailCSouth", Vector3(71.0, 1.10, 36.5), Vector3(2.0, 1.44, 0.14)],
		["ConnectorRailCNorth", Vector3(71.0, 1.10, 39.5), Vector3(2.0, 1.44, 0.14)],
	]:
		_box(
			fabrication_connector,
			rail_spec[0] as String,
			rail_spec[1] as Vector3,
			rail_spec[2] as Vector3,
			_materials["ivory"]
		)

	# OBSERVATION-LOGISTICS-INTEGRATION-001. This half-metre world-owned deck is
	# the complete handoff between Fabrication's rear boundary at x=92 and the
	# Observation spur origin at x=92.5. The production Fabrication instance
	# atomically replaces its full rear rail with the two returned twelve-metre
	# segments, leaving exactly the connector's four-metre opening at z=36..40.
	var observation_connector := Node3D.new()
	observation_connector.name = "ObservationLogisticsConnector"
	observation_connector.set_meta(&"evidence_status", &"modern_interpretation")
	observation_connector.set_meta(&"connects_station_module", &"observation-logistics-spur")
	shell.add_child(observation_connector)
	var observation_route_anchor := Node3D.new()
	observation_route_anchor.name = "RouteAnchor"
	observation_route_anchor.position = Vector3(91.0, 0.53, 38.0)
	observation_route_anchor.set_meta(&"station_hub_route_anchor", true)
	observation_route_anchor.set_meta(&"route_support", &"fabrication_rear_aisle_to_observation_connector")
	observation_connector.add_child(observation_route_anchor)
	var observation_connector_deck := _box(
		observation_connector,
		"ConnectorDeck",
		Vector3(92.25, 0.23, 38.0),
		Vector3(0.5, 0.3, 4.0),
		_materials["deck_light"]
	)
	observation_connector_deck.set_meta(&"walkable_surface", true)
	observation_connector_deck.set_meta(&"walkable_surface_id", &"observation_logistics_connector")
	observation_connector_deck.set_meta(&"walkable_surface_kind", &"level")
	observation_connector_deck.set_meta(&"walkable_surface_owner", &"station_hub")
	observation_connector_deck.set_meta(&"horizontal_area_m2", 2.0)
	for rail_spec in [
		["ConnectorRailSouth", Vector3(92.25, 1.0, 35.88)],
		["ConnectorRailNorth", Vector3(92.25, 1.0, 40.12)],
	]:
		_box(
			observation_connector,
			rail_spec[0] as String,
			rail_spec[1] as Vector3,
			Vector3(0.5, 1.24, 0.16),
			_materials["ivory"]
		)

	# SALVAGE-TERRACE-INTEGRATION-001. Fabrication's deliberately open north
	# service gate ends at z=52. This exact 3.9312 m2 world-owned deck crosses the
	# 0.91 m gap to Salvage Terrace's four-metre origin opening. The route anchor
	# begins on the live Fabrication port-side bypass, rather than borrowing a
	# marker or endpoint from either module subtree.
	var salvage_connector := Node3D.new()
	salvage_connector.name = "SalvageTerraceConnector"
	salvage_connector.set_meta(&"evidence_status", &"modern_interpretation")
	salvage_connector.set_meta(&"connects_station_module", &"salvage-terrace")
	shell.add_child(salvage_connector)
	var salvage_route_anchor := Node3D.new()
	salvage_route_anchor.name = "RouteAnchor"
	salvage_route_anchor.position = Vector3(84.0, 0.53, 51.91)
	salvage_route_anchor.set_meta(&"station_hub_route_anchor", true)
	salvage_route_anchor.set_meta(
		&"route_support", &"fabrication_port_service_to_salvage_connector"
	)
	salvage_connector.add_child(salvage_route_anchor)
	var salvage_connector_deck := _box(
		salvage_connector,
		"ConnectorDeck",
		Vector3(84.0, 0.18, 52.455),
		Vector3(4.32, 0.40, 0.91),
		_materials["deck_light"]
	)
	salvage_connector_deck.set_meta(&"walkable_surface", true)
	salvage_connector_deck.set_meta(&"walkable_surface_id", &"salvage_terrace_connector")
	salvage_connector_deck.set_meta(&"walkable_surface_kind", &"level")
	salvage_connector_deck.set_meta(&"walkable_surface_owner", &"station_hub")
	salvage_connector_deck.set_meta(&"horizontal_area_m2", 3.9312)
	for rail_spec in [
		["ConnectorRailWest", Vector3(81.92, 1.03, 52.45)],
		["ConnectorRailEast", Vector3(86.08, 1.03, 52.45)],
	]:
		_box(
			salvage_connector,
			rail_spec[0] as String,
			rail_spec[1] as Vector3,
			Vector3(0.16, 1.30, 0.76),
			_materials["ivory"]
		)

	# The B2-bounded comb is mounted beyond the Aft upper deck rather than across
	# any live landing volume. This short, visibly modelled bridge is the complete
	# pedestrian connection—there is no hidden slab beneath the module's large
	# open voids. Its 1.54/1.38 m guarded mouth is intentionally narrower than the
	# 2.3 m tug; Fleet Dock is connected for walking circulation, not vehicle use.
	var fleet_comb_connector := Node3D.new()
	fleet_comb_connector.name = "FleetDockCombConnector"
	fleet_comb_connector.set_meta("evidence_status", &"modern_interpretation")
	fleet_comb_connector.set_meta("connects_station_module", &"fleet-dock-comb")
	shell.add_child(fleet_comb_connector)
	_rounded_fleet_connector_deck(
		fleet_comb_connector,
		"FleetDockCombConnectorDeck",
		Vector3(6.0, 3.88, 68.3),
		FLEET_DOCK_CONNECTOR_DECK_SIZE,
		_materials["deck_light"],
		FLEET_DOCK_CONNECTOR_CORNER_RADIUS,
		FLEET_DOCK_CONNECTOR_CURVE_SEGMENTS
	)
	_box(
		fleet_comb_connector,
		"FleetDockCombConnectorPortRail",
		Vector3(6.0, 4.85, 66.5),
		Vector3(12.5, 1.3, 0.16),
		_materials["ivory"]
	)
	_box(
		fleet_comb_connector,
		"FleetDockCombConnectorStarboardRail",
		Vector3(6.0, 4.85, 70.1),
		Vector3(12.5, 1.3, 0.16),
		_materials["ivory"]
	)

	_build_halyard_berth_apron(shell)

	# Deep under-deck beams make the separated modules read as one supported
	# station lattice while leaving space visible between every branch.
	for z_position in [-22.5, -10.0, 2.0, 10.0, 18.0, 31.0, 44.0]:
		_box(shell, "SpineKeel", Vector3(0, -2.0, z_position), Vector3(3.0, 1.6, 9.0), _materials["steel_blue"], false)
	for side in [-1.0, 1.0]:
		_box(shell, "BranchKeel", Vector3(side * 27.0, -2.0, 15.5), Vector3(28.0, 1.6, 2.2), _materials["steel_blue"], false)
		for x_position in [14.0, 24.0, 34.0, 43.0]:
			_box(shell, "BranchCrossBrace", Vector3(side * x_position, -2.8, 15.5), Vector3(0.7, 4.8, 8.0), _materials["orange"], false, Vector3(0, 0, side * 42.0))

	# Low rails protect the walkable branch arms. The active berth and launch
	# spine remain unobstructed for the hero ship's wide collision envelope.
	#
	# PORT-DECK-001. The rails used to run 5 m *past* the arm and across the berth
	# node itself (x = -42.5 … -11.5 against an arm of -37.5 … -12.5). On the port
	# node that fenced the 7 m approach corridor shut: the parked Arrow's wing
	# (x = -44.2 … -39.3) blocks the west end of the corridor and the hull blocks
	# its middle, so the only way onto the walkway beside the craft was over a
	# 1.24 m rail. Each rail now ends exactly where its arm ends, leaving the berth
	# node open on both sides. The post roster stays at five per rail.
	var branch_rail_spans := [
		[PORT_BERTH_NODE_OUTER_X + PORT_BERTH_NODE_HALF_WIDTH, -12.5],
		[12.5, 37.0],
	]
	for span in branch_rail_spans:
		var inner_x := float(span[0])
		var outer_x := float(span[1])
		var rail_centre := (inner_x + outer_x) * 0.5
		var rail_length := absf(outer_x - inner_x)
		for z_edge in [12.0, 19.0]:
			_box(shell, "BranchRail", Vector3(rail_centre, 1.15, z_edge), Vector3(rail_length, 0.18, 0.18), _materials["ivory"])
			for post_index in 5:
				var post_x := lerpf(
					minf(inner_x, outer_x) + 0.2,
					maxf(inner_x, outer_x) - 0.2,
					float(post_index) / 4.0
				)
				_box(shell, "BranchRailPost", Vector3(post_x, 0.55, z_edge), Vector3(0.18, 1.3, 0.18), _materials["orange"])
	for side in [-1.0, 1.0]:
		_box(shell, "AftSpineRail", Vector3(side * 4.0, 1.15, 31.0), Vector3(0.18, 0.18, 17.0), _materials["ivory"])
		for z_position in [24.0, 30.0, 36.0]:
			_box(shell, "AftRailPost", Vector3(side * 4.0, 0.55, z_position), Vector3(0.18, 1.3, 0.18), _materials["orange"])
		_box(shell, "AftConnectorRail", Vector3(side * 3.35, 1.15, 43.5), Vector3(0.18, 0.18, 9.0), _materials["ivory"])
		for z_position in [40.0, 44.0, 47.5]:
			_box(shell, "AftConnectorRailPost", Vector3(side * 3.35, 0.55, z_position), Vector3(0.18, 1.3, 0.18), _materials["orange"])
		# The spine is 8 m wide while the module connector is 7 m wide.  Their
		# floor slabs meet at z=39, but the former independently-ended rails made
		# that safe, continuous handoff read as two disconnected walkways.  These
		# two short mitres visibly and physically carry each outer guard into the
		# narrowed connector without reducing the player-clear route.
		_beam_between(
			shell,
			"AftConnectorTransitionRail",
			Vector3(side * 4.0, 1.15, 39.5),
			Vector3(side * 3.35, 1.15, 39.0),
			0.09,
			_materials["ivory"],
			true
		)
		for join_position in [Vector3(side * 4.0, 0.55, 39.5), Vector3(side * 3.35, 0.55, 39.0)]:
			_cylinder(shell, "AftConnectorTransitionPost", join_position, 0.09, 1.3, _materials["orange"], true)

	# Freestanding rounded masts establish several readable heights without
	# becoming a roof cage.
	# The former port mast at (-11, 0, 14) stood directly in the live junction
	# walkway beside the player spawn. Keep that route open; the remaining three
	# masts retain the height markers without narrowing circulation.
	_dock_mast_collar_mesh = TorusMesh.new()
	_dock_mast_collar_mesh.inner_radius = DOCK_MAST_COLLAR_INNER_RADIUS
	_dock_mast_collar_mesh.outer_radius = DOCK_MAST_COLLAR_OUTER_RADIUS
	_dock_mast_collar_mesh.rings = DOCK_MAST_COLLAR_RINGS
	_dock_mast_collar_mesh.ring_segments = DOCK_MAST_COLLAR_RING_SEGMENTS
	for mast_position in DOCK_MAST_COLLAR_POSITIONS:
		var mast_base_position: Vector3 = (mast_position as Vector3) - Vector3.UP
		_cylinder(shell, "DockMast", mast_base_position + Vector3(0, 5.2, 0), 0.46, 10.4, _materials["steel_blue"], true)
		_torus(shell, "DockMastCollar", mast_position, DOCK_MAST_COLLAR_INNER_RADIUS, DOCK_MAST_COLLAR_OUTER_RADIUS, _materials["orange"], Vector3.ZERO, _dock_mast_collar_mesh)
		_box(shell, "MastCap", mast_base_position + Vector3(0, 10.15, 0), Vector3(2.4, 0.55, 1.6), _materials["ivory"], false)
		_add_guide_light(shell, mast_base_position + Vector3(0, 9.5, -0.55), KETH_CYAN, false, 2.2, 9.0)

	# Modern navigation pylon; text describes this slice's deck, not a recovered
	# historical bay number or original structure.
	# A high header and two narrow posts replace the former solid pylon. The
	# opening is a real player-clear route into the aft circulation stack.
	#
	# The first version put the header's underside at y = 6.4. From the upper
	# operations walkway camera near (3.2, 7.7, 61.0), its broad rear face read as
	# an unreachable floating platform and crowded the lit walkway below it. Raise
	# the complete sign assembly by 4.6 m and lengthen its grounded posts to meet it;
	# the portal keeps the same footprint and navigation role while the walkway
	# retains an open sky/light gap above the player sightline and the header's key-
	# light shadow lands beyond the branch walkway.
	for x_position in [-6.1, 6.1]:
		_box(shell, "JunctionPortalPost", Vector3(x_position, 5.55, 22.6), Vector3(1.1, 11.1, 1.2), _materials["blue"])
	_box(shell, "JunctionPortalHeader", Vector3(0, 12.0, 22.6), Vector3(13.3, 2.0, 1.2), _materials["blue"])
	_box(shell, "JunctionSignFace", Vector3(0, 12.0, 21.95), Vector3(12.0, 1.3, 0.12), _materials["navy"], false)
	# MAP-004 family, found by sweeping every live `TextMesh` rather than only the
	# six the intake listed. Both legends stand at z = 21.86/21.84, in front of
	# `JunctionSignFace` (z = 21.95) on the -Z side of the portal, and both were
	# authored with `Vector3.ZERO`, so the station's most prominent navigation
	# board read backwards to everyone walking aft through it. Rendered and
	# confirmed reversed before the change.
	_text_sign(
		shell,
		"MUDDS  //  REGENERATION DECK",
		Vector3(0, 12.25, 21.86),
		Vector3(0.0, 180.0, 0.0),
		0.54,
		_materials["cyan_glow"]
	)
	_text_sign(
		shell,
		"CENTRAL JUNCTION  //  FLEET DOCKS",
		Vector3(0, 11.68, 21.84),
		Vector3(0.0, 180.0, 0.0),
		0.27,
		_materials["orange_glow"]
	)

	_apply_habitat_entry_curve()


## HALYARD-DECK-001. The walkable apron that makes Fleet Dock 02 big enough for
## the craft standing on it. See the `HALYARD_APRON_*` constants for the measured
## geometry and for why this is the world's structure rather than the comb's.
##
## Three decks, all flush at y = 4.2 with `DockSlab02`, `Rung02` and the comb
## trunk, none of them overlapping any of those:
##
##   `HalyardApronNose`         x 31.0 … 43.0, z 36.3 … 47.3   (12.0 x 11.0)
##   `HalyardApronTailPort`     x 31.0 … 35.2, z 59.3 … 65.9   ( 4.2 x  6.6)
##   `HalyardApronTailStarboard`x 38.8 … 43.0, z 59.3 … 65.9   ( 4.2 x  6.6)
##
## Together with the comb's own pieces that gives one unbroken 12 m wide deck
## from z = 36.3 to the far side of the trunk at 70.7 — 34.4 m under a 28.35 m
## craft, with 3.15 m of apron off the bow and 2.9 m off the tail, and a lane
## down each flank that is 3.28 m wide beside the cabin walls. Every one of the
## craft's four footprint corners now has structure under it.
##
## No rail is added. The Arrow's berth had to have one taken away — its
## `BranchRail` fenced the only corridor shut — and a rail around this pad would
## fence exactly the loop the report is asking for.
##
## Each deck is a `_box`, so it renders and collides from the same measurements:
## the station sweep for standable collision with nothing drawn at it would catch
## an invisible ledge here, and `FleetDockComb`'s "no collision on dressing" rule
## is untouched because none of this is in that module.
func _build_halyard_berth_apron(shell: Node3D) -> void:
	var apron := Node3D.new()
	apron.name = "HalyardBerthApron"
	apron.set_meta("evidence_status", &"modern_interpretation")
	apron.set_meta("serves_berth", HALYARD_FLEET_DOCK_BERTH_ID)
	shell.add_child(apron)

	var deck_centre_y := HALYARD_APRON_DECK_TOP - HALYARD_APRON_DECK_THICKNESS * 0.5
	var pad_centre_x := (HALYARD_APRON_MIN_X + HALYARD_APRON_MAX_X) * 0.5
	var pad_width := HALYARD_APRON_MAX_X - HALYARD_APRON_MIN_X
	var nose_depth := FLEET_DOCK_SLAB_02_MIN_Z - HALYARD_APRON_NOSE_MIN_Z
	_box(
		apron,
		"HalyardApronNose",
		Vector3(pad_centre_x, deck_centre_y, HALYARD_APRON_NOSE_MIN_Z + nose_depth * 0.5),
		Vector3(pad_width, HALYARD_APRON_DECK_THICKNESS, nose_depth),
		_materials["deck"]
	)

	var tail_depth := HALYARD_APRON_TAIL_MAX_Z - FLEET_DOCK_SLAB_02_MAX_Z
	var tail_centre_z := FLEET_DOCK_SLAB_02_MAX_Z + tail_depth * 0.5
	var tail_wings := [
		["HalyardApronTailPort", HALYARD_APRON_MIN_X, HALYARD_APRON_RUNG_MIN_X],
		["HalyardApronTailStarboard", HALYARD_APRON_RUNG_MAX_X, HALYARD_APRON_MAX_X],
	]
	for wing in tail_wings:
		var wing_min_x := float(wing[1])
		var wing_max_x := float(wing[2])
		_box(
			apron,
			str(wing[0]),
			Vector3((wing_min_x + wing_max_x) * 0.5, deck_centre_y, tail_centre_z),
			Vector3(wing_max_x - wing_min_x, HALYARD_APRON_DECK_THICKNESS, tail_depth),
			_materials["deck"]
		)

	# Understructure, so the apron reads as carried rather than as plate hanging
	# in space. Sections and seats are `FleetDockComb`'s own `SlabSupport` values
	# (0.55 m square, 2.5 m tall, standing y = 1.20 … 3.70 so the head enters the
	# 3.60 m deck underside by 0.10 m), because this deck is continuous with that
	# module's and a different underframe two metres away would look like two
	# stations. The chords take the same module's COMB-UNDERFRAME-001 rule — crown
	# 0.06 m inside the plate it is bolted to — which is the measured rule written
	# after every beam over there was found hanging clear of its own deck. Colours
	# are this world's: keel steel-blue, strut orange, as `BranchKeel` and
	# `BranchCrossBrace` already are. All of it visual only; an underframe a player
	# can stand on is the invisible-ledge defect in a different costume.
	var chord_centre_y := HALYARD_APRON_DECK_TOP - HALYARD_APRON_DECK_THICKNESS - 0.70 + 0.06
	for chord_x in [pad_centre_x - 3.6, pad_centre_x + 3.6]:
		_box(
			apron,
			"HalyardApronChord",
			Vector3(float(chord_x), chord_centre_y, HALYARD_APRON_NOSE_MIN_Z + nose_depth * 0.5),
			Vector3(0.55, 1.4, nose_depth - 0.4),
			_materials["steel_blue"],
			false
		)
	for chord_x in [(HALYARD_APRON_MIN_X + HALYARD_APRON_RUNG_MIN_X) * 0.5,
			(HALYARD_APRON_RUNG_MAX_X + HALYARD_APRON_MAX_X) * 0.5]:
		_box(
			apron,
			"HalyardApronChord",
			Vector3(float(chord_x), chord_centre_y, tail_centre_z),
			Vector3(0.55, 1.4, tail_depth - 0.4),
			_materials["steel_blue"],
			false
		)
	var strut_centre_y := HALYARD_APRON_DECK_TOP - HALYARD_APRON_DECK_THICKNESS + 0.10 - 1.25
	var strut_specs := [
		[pad_centre_x - 3.6, HALYARD_APRON_NOSE_MIN_Z + 2.6],
		[pad_centre_x + 3.6, HALYARD_APRON_NOSE_MIN_Z + 2.6],
		[pad_centre_x - 3.6, FLEET_DOCK_SLAB_02_MIN_Z - 2.6],
		[pad_centre_x + 3.6, FLEET_DOCK_SLAB_02_MIN_Z - 2.6],
		[(HALYARD_APRON_MIN_X + HALYARD_APRON_RUNG_MIN_X) * 0.5, tail_centre_z],
		[(HALYARD_APRON_RUNG_MAX_X + HALYARD_APRON_MAX_X) * 0.5, tail_centre_z],
	]
	for strut in strut_specs:
		_box(
			apron,
			"HalyardApronStrut",
			Vector3(float(strut[0]), strut_centre_y, float(strut[1])),
			Vector3(0.55, 2.5, 0.55),
			_materials["orange"],
			false
		)


func _build_landing_pad() -> void:
	var pad := Node3D.new()
	pad.name = "LandingPad"
	add_child(pad)
	_central_berth_root = pad
	_apply_central_berth_metadata(pad)
	_central_berth_hero_presentation = (
		CENTRAL_BERTH_HERO_PRESENTATION_SCENE.instantiate()
		as CentralBerthHeroPresentation
	)
	_central_berth_hero_presentation.name = "CentralBerthHeroPresentation"
	pad.add_child(_central_berth_hero_presentation)
	# The authored berth asset owns its deck margins and ivory fascia.  The old
	# primitive borders occupied the same edge band and intersected the imported
	# deck by 5 mm, producing the flickering seam at the runway perimeter.

	# Centreline and launch-vector arrows lead straight to the open aperture.
	_box(pad, "Centreline", Vector3(0, 0.145, -10), Vector3(0.22, 0.04, 31.5), _materials["berth_cyan_glow"], false)
	for z_position in [-23.5, -18.5, -13.5, -8.5, -3.5, 1.5]:
		for side in [-1.0, 1.0]:
			var chevron := _box(
				pad,
				"Chevron",
				Vector3(side * 2.0, 0.155, z_position),
				Vector3(3.7, 0.035, 0.42),
				_materials["berth_orange_glow"],
				false,
				Vector3(0, side * 25.0, 0)
			)
			chevron.set_meta("navigation_role", &"launch_vector_chevron")

	# Concentric rings make the active physical berth readable from the cockpit.
	_torus(pad, "OuterPadRing", Vector3(0, 0.18, -10), 8.7, 9.0, _materials["ivory"])
	_torus(pad, "InnerPadRing", Vector3(0, 0.19, -10), 5.7, 5.92, _materials["berth_cyan_glow"])
	# The H remains a strong navigation mark but opens around the three actual
	# contact points so the amber clamp silhouettes read as hardware, not paint.
	_box(pad, "PadHLeft", Vector3(-2.65, 0.2, -10), Vector3(0.35, 0.04, 4.2), _materials["ivory"], false)
	_box(pad, "PadHRight", Vector3(2.65, 0.2, -10), Vector3(0.35, 0.04, 4.2), _materials["ivory"], false)
	_box(pad, "PadHBar", Vector3(0, 0.205, -10), Vector3(5.0, 0.04, 0.35), _materials["ivory"], false)

	# Eight flush fixtures replace the previous line of glowing beads. Their low
	# local output carries the pad edge without recreating a broad cyan wash.
	for z_position in [-23.0, -15.0, -7.0, 1.0]:
		for x_position in [-11.5, 11.5]:
			_add_recessed_berth_fixture(pad, Vector3(x_position, 0.105, z_position))

	_build_central_docking_hardware(pad)
	_build_central_utility_bay(pad)
	_build_central_deck_details(pad)
	_build_central_reflection_probe(pad)

	_text_sign(
		pad,
		"ACTIVE",
		Vector3(-10.1, 0.19, 4.3),
		Vector3(-90, 0, 0),
		0.46,
		_materials["berth_orange_glow"]
	)

	# The established port-side physical node now hosts the provisional Arrow
	# recon interpretation. Only the name, reconnaissance role and written
	# two-pod count in A3's dated page text carry historical support; the Arrow
	# name-to-model mapping is unknown, and this berth label and placement are
	# modern layout decisions that authenticate neither the model nor adjacency.
	var arrow_berth_origin := get_berth_transform(ARROW_RECON_BERTH_ID).origin
	_torus(pad, "ArrowReconBerthOuterRing", arrow_berth_origin + Vector3(0.0, -0.94, 0.0), 4.45, 4.68, _materials["ivory"])
	_torus(pad, "ArrowReconBerthInnerRing", arrow_berth_origin + Vector3(0.0, -0.93, 0.0), 3.15, 3.34, _materials["orange_glow"])
	_box(
		pad,
		"ArrowReconBerthVector",
		arrow_berth_origin + Vector3(0.0, -0.91, 0.0),
		Vector3(8.4, 0.04, 0.18),
		_materials["cyan_glow"],
		false
	)
	for z_offset in [-7.1, 7.1]:
		_add_guide_light(
			pad,
			arrow_berth_origin + Vector3(0.0, -0.78, z_offset),
			KETH_ORANGE,
			false,
			1.4,
			7.0
		)
	_text_sign(
		pad,
		"ARROW RECON  //  PROVISIONAL INTERPRETATION",
		arrow_berth_origin + Vector3(0.0, -0.9, 6.35),
		Vector3(-90.0, 90.0, 0.0),
		0.24,
		_materials["orange_glow"]
	)


func _apply_central_berth_metadata(pad: Node3D) -> void:
	pad.set_meta("station_module", true)
	pad.set_meta("module_id", CENTRAL_HERO_MODULE_ID)
	pad.set_meta("berth_id", CENTRAL_BERTH_ID)
	pad.set_meta("ship_id", CENTRAL_HERO_SHIP_ID)
	pad.set_meta("torrent_berth_candidate", true)
	pad.set_meta("geometry_status", &"provisional")
	pad.set_meta("evidence_status", CENTRAL_HERO_EVIDENCE_STATUS)
	pad.set_meta("source_bounded", true)
	pad.set_meta("authenticated_original_geometry", false)
	pad.set_meta("authenticated_berth_layout", false)
	pad.set_meta("content_note", CENTRAL_HERO_CONTENT_NOTE)
	pad.add_to_group("central_berth_hero_cell")


func _tag_central_feature(node: Node, feature_id: StringName) -> void:
	node.set_meta("central_berth_feature", feature_id)
	node.set_meta("geometry_status", &"provisional")
	node.set_meta("authenticated_original_geometry", false)


func _build_central_docking_hardware(pad: Node3D) -> void:
	var hardware := Node3D.new()
	hardware.name = "TorrentDockingHardware"
	hardware.set_meta("presentation_collision_free", true)
	pad.add_child(hardware)
	var berth_transform := get_berth_transform(CENTRAL_BERTH_ID)
	var clamp_specs := {
		&"port_main": ["DockingClampPortMain", Vector2(1.4, 2.05)],
		&"starboard_main": ["DockingClampStarboardMain", Vector2(1.4, 2.05)],
		&"nose": ["DockingClampNose", Vector2(1.15, 1.55)],
	}
	for contact_id: StringName in clamp_specs:
		var contact_world: Vector3 = berth_transform * (TORRENT_GEAR_CONTACT_OFFSETS[contact_id] as Vector3)
		var spec: Array = clamp_specs[contact_id]
		var footprint: Vector2 = spec[1] as Vector2
		var clamp := Node3D.new()
		clamp.name = spec[0] as String
		clamp.position = Vector3(contact_world.x, 0.108, contact_world.z)
		clamp.set_meta("gear_contact_id", contact_id)
		clamp.set_meta("gear_contact_world", contact_world)
		clamp.set_meta("takeoff_obstruction", false)
		clamp.set_meta("presentation_collision_free", true)
		hardware.add_child(clamp)
		_tag_central_feature(clamp, &"docking_clamp")

		_box(
			clamp,
			"ClampRecess",
			Vector3(0.0, 0.005, 0.0),
			Vector3(footprint.x, 0.018, footprint.y),
			_materials["black"],
			false
		)
		for side in [-1.0, 1.0]:
			_box(
				clamp,
				"RetractedJaw",
				Vector3(side * footprint.x * 0.47, 0.09, 0.0),
				Vector3(0.14, 0.17, footprint.y * 0.72),
				_materials["orange"],
				false
			)
			_box(
				clamp,
				"ClampPad",
				Vector3(side * footprint.x * 0.39, 0.16, 0.0),
				Vector3(0.1, 0.08, footprint.y * 0.54),
				_materials["black"],
				false
			)
		_box(
			clamp,
			"ClampStatus",
			Vector3(0.0, 0.026, footprint.y * 0.39),
			Vector3(footprint.x * 0.42, 0.018, 0.08),
			_materials["berth_orange_glow"],
			false
		)


func _build_central_utility_bay(pad: Node3D) -> void:
	var utility_bay := Node3D.new()
	utility_bay.name = "StarboardUtilityBay"
	utility_bay.set_meta("presentation_collision_free", true)
	pad.add_child(utility_bay)
	_landing_pad_deck_connector_mesh = TorusMesh.new()
	_landing_pad_deck_connector_mesh.inner_radius = LANDING_PAD_DECK_CONNECTOR_INNER_RADIUS
	_landing_pad_deck_connector_mesh.outer_radius = LANDING_PAD_DECK_CONNECTOR_OUTER_RADIUS
	_landing_pad_deck_connector_mesh.rings = LANDING_PAD_DECK_CONNECTOR_AUTHORED_RINGS
	_landing_pad_deck_connector_mesh.ring_segments = LANDING_PAD_DECK_CONNECTOR_AUTHORED_RING_SEGMENTS
	var utility_specs := [
		["Power", -5.4, "orange", "berth_orange_glow"],
		["Data", -9.6, "steel_blue", "berth_cyan_glow"],
		["Fuel", -13.8, "ivory", "orange"],
	]
	for index in utility_specs.size():
		var spec: Array = utility_specs[index]
		var utility_name: String = spec[0]
		var z_position: float = spec[1]
		var housing := Node3D.new()
		housing.name = "UmbilicalHousing" + utility_name
		housing.position = Vector3(10.65, 0.11, z_position)
		housing.set_meta("utility_kind", StringName(utility_name.to_lower()))
		housing.set_meta("parked", true)
		housing.set_meta("presentation_collision_free", true)
		utility_bay.add_child(housing)
		_tag_central_feature(housing, &"umbilical_housing")
		_box(housing, "HousingPlinth", Vector3(0.0, 0.12, 0.0), Vector3(1.25, 0.22, 1.55), _materials["black"], false)
		_box(housing, "HousingBody", Vector3(0.0, 0.54, 0.0), Vector3(1.05, 0.72, 1.35), _materials[spec[2] as String], false)
		_box(housing, "HousingFace", Vector3(-0.54, 0.55, 0.0), Vector3(0.055, 0.48, 0.92), _materials["navy"], false)
		_box(housing, "UtilityCode", Vector3(-0.58, 0.62, 0.0), Vector3(0.025, 0.1, 0.58), _materials[spec[3] as String], false)

		var hose := Node3D.new()
		hose.name = "ParkedUmbilicalHose" + utility_name
		hose.set_meta("utility_kind", StringName(utility_name.to_lower()))
		hose.set_meta("parked", true)
		hose.set_meta("maximum_world_height", 0.46)
		hose.set_meta("presentation_collision_free", true)
		utility_bay.add_child(hose)
		_tag_central_feature(hose, &"parked_umbilical_hose")
		var hose_material: Material = _materials[spec[3] as String]
		var points := PackedVector3Array([
			Vector3(10.08, 0.43, z_position),
			Vector3(9.72, 0.28, z_position),
			Vector3(9.32, 0.18, z_position + 0.42),
			Vector3(8.88, 0.15, z_position + 0.42),
			Vector3(8.62, 0.135, z_position),
		])
		for segment_index in points.size() - 1:
			_beam_between(
				hose,
				"StowedHoseSegment%02d" % segment_index,
				points[segment_index],
				points[segment_index + 1],
				0.055 if index != 2 else 0.072,
				hose_material,
				false
			)
		var deck_connector := MeshInstance3D.new()
		deck_connector.name = "DeckConnector"
		deck_connector.position = Vector3(8.62, 0.13, z_position)
		deck_connector.mesh = _landing_pad_deck_connector_mesh
		deck_connector.material_override = _materials["black"]
		hose.add_child(deck_connector)

	var cabinet := Node3D.new()
	cabinet.name = "CentralServiceCabinet"
	cabinet.position = Vector3(11.05, 0.1, -19.25)
	cabinet.set_meta("presentation_collision_free", true)
	utility_bay.add_child(cabinet)
	_tag_central_feature(cabinet, &"service_cabinet")
	_box(cabinet, "CabinetPlinth", Vector3(0.0, 0.12, 0.0), Vector3(1.5, 0.22, 2.3), _materials["black"], false)
	_box(cabinet, "CabinetShell", Vector3(0.0, 0.92, 0.0), Vector3(1.35, 1.55, 2.15), _materials["ivory"], false)
	_box(cabinet, "CabinetDoor", Vector3(-0.7, 0.95, 0.0), Vector3(0.055, 1.25, 1.75), _materials["navy"], false)
	for z_offset in [-0.48, 0.0, 0.48]:
		_box(cabinet, "CabinetStatus", Vector3(-0.735, 1.2, z_offset), Vector3(0.025, 0.1, 0.24), _materials["berth_cyan_glow"], false)

	var pedestal := Node3D.new()
	pedestal.name = "BerthControlPedestal"
	pedestal.position = Vector3(8.75, 0.1, 2.65)
	pedestal.set_meta("hand_scale_height", 1.12)
	pedestal.set_meta("presentation_collision_free", true)
	utility_bay.add_child(pedestal)
	_tag_central_feature(pedestal, &"control_pedestal")
	_box(pedestal, "PedestalFoot", Vector3.ZERO, Vector3(0.72, 0.12, 0.75), _materials["black"], false)
	_box(pedestal, "PedestalStem", Vector3(0.0, 0.44, 0.0), Vector3(0.32, 0.76, 0.32), _materials["steel_blue"], false)
	_box(pedestal, "PedestalHead", Vector3(0.0, 0.91, -0.04), Vector3(0.78, 0.3, 0.58), _materials["ivory"], false, Vector3(-16.0, 0.0, 0.0))
	_box(pedestal, "PedestalScreen", Vector3(0.0, 1.01, -0.34), Vector3(0.5, 0.12, 0.025), _materials["berth_cyan_glow"], false, Vector3(-16.0, 0.0, 0.0))


func _build_central_deck_details(pad: Node3D) -> void:
	var details := Node3D.new()
	details.name = "IntegratedDeckServices"
	details.set_meta("presentation_collision_free", true)
	pad.add_child(details)
	var drain_slat_transforms: Array[Transform3D] = []

	var long_trench := _box(details, "CableTrenchLong", Vector3(8.08, 0.103, -10.0), Vector3(0.46, 0.018, 25.7), _materials["black"], false)
	long_trench.set_meta("recessed_below_surface", true)
	_tag_central_feature(long_trench, &"cable_trench")
	var cross_trench := _box(details, "CableTrenchServiceBranch", Vector3(9.35, 0.104, -17.0), Vector3(3.0, 0.018, 0.38), _materials["black"], false)
	cross_trench.set_meta("recessed_below_surface", true)
	_tag_central_feature(cross_trench, &"cable_trench")

	for drain_position in [
		Vector3(-9.6, 0.104, -20.0),
		Vector3(9.6, 0.104, -20.0),
		Vector3(-9.6, 0.104, 0.0),
		Vector3(9.6, 0.104, 0.0),
	]:
		var drain := _box(details, "RecessedDrain", drain_position, Vector3(1.8, 0.018, 0.36), _materials["black"], false)
		drain.set_meta("recessed_below_surface", true)
		_tag_central_feature(drain, &"drain")
		for slat_index in 5:
			var local_position := Vector3(-0.64 + float(slat_index) * 0.32, 0.015, 0.0)
			drain_slat_transforms.append(
				Transform3D(Basis.IDENTITY, drain.transform * local_position)
			)
			# Preserve the old repeated path without retaining a renderer node. The
			# slat has always been inert deck dressing; its batch index is metadata,
			# not gameplay or interaction authority.
			var slat_anchor := Marker3D.new()
			slat_anchor.name = "DrainSlat"
			slat_anchor.position = local_position
			slat_anchor.set_meta("visual_batch", ^"../../DrainSlatVisuals")
			slat_anchor.set_meta("visual_batch_index", drain_slat_transforms.size() - 1)
			drain.add_child(slat_anchor)
	_multimesh_visual_boxes(
		details,
		"DrainSlatVisuals",
		Vector3(0.055, 0.012, 0.29),
		_materials["steel_blue"],
		drain_slat_transforms
	)

	# Six flush tie-down sockets add scale and believable work detail without
	# filling the player or craft lanes with freestanding props.
	_tie_down_socket_mesh = TorusMesh.new()
	_tie_down_socket_mesh.inner_radius = 0.16
	_tie_down_socket_mesh.outer_radius = 0.25
	_tie_down_socket_mesh.rings = 64
	_tie_down_socket_mesh.ring_segments = 16
	for tie_position in [
		Vector3(-8.7, 0.125, -21.5),
		Vector3(8.7, 0.125, -21.5),
		Vector3(-8.7, 0.125, -3.0),
		Vector3(8.7, 0.125, -3.0),
		Vector3(-8.7, 0.125, 3.2),
		Vector3(8.7, 0.125, 3.2),
	]:
		var tie_down := _torus(details, "TieDownSocket", tie_position, 0.16, 0.25, _materials["steel_blue"], Vector3.ZERO, _tie_down_socket_mesh)
		tie_down.set_meta("flush_deck_detail", true)
		_tag_central_feature(tie_down, &"work_detail")


func _add_recessed_berth_fixture(parent: Node3D, fixture_position: Vector3) -> void:
	var fixture := Node3D.new()
	fixture.name = "RecessedBerthFixture"
	fixture.position = fixture_position
	fixture.set_meta("recessed_below_surface", true)
	fixture.set_meta("presentation_collision_free", true)
	parent.add_child(fixture)
	_tag_central_feature(fixture, &"recessed_fixture")
	_box(fixture, "FixtureWell", Vector3.ZERO, Vector3(0.82, 0.018, 0.34), _materials["black"], false)
	_box(fixture, "FixtureEmitter", Vector3(0.0, 0.012, 0.0), Vector3(0.48, 0.012, 0.09), _materials["berth_cyan_glow"], false)
	var light := OmniLight3D.new()
	light.name = "RecessedFixtureLight"
	light.position = Vector3(0.0, 0.12, 0.0)
	light.light_color = Color("7ed9d7")
	light.light_energy = 0.32
	light.omni_range = 3.4
	light.omni_attenuation = 1.8
	light.shadow_enabled = false
	fixture.add_child(light)


func _build_central_reflection_probe(pad: Node3D) -> void:
	var probe := ReflectionProbe.new()
	probe.name = "CentralBerthReflectionProbe"
	probe.position = Vector3(0.0, 4.0, -10.0)
	probe.size = Vector3(26.0, 9.0, 34.0)
	probe.max_distance = 44.0
	probe.intensity = 0.72
	probe.box_projection = true
	probe.enable_shadows = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.set_meta("bounded_hero_cell_probe", true)
	pad.add_child(probe)
	_tag_central_feature(probe, &"reflection_probe")


## Ground-support hardware on the central berth's port flank, and foot hardware
## at the three remaining dock masts.
##
## Why this exists, and why it is not under `LandingPad`. The starboard flank of
## the hero berth already carries the *utility* half of a working berth — power,
## data and fuel umbilicals, a service cabinet, a control pedestal. The port
## flank carried nothing at all: a 34 m by 3 m strip of bare deck that the player
## walks down on the way to the Torrent and drives the tow tractor along, with
## four flush deck lights in it and no object taller than 18 mm between the pad
## border and the shell edge. A berth with utilities on one side and an empty
## apron on the other does not read as a place anyone works.
##
## `LandingPad`'s whole dressing roster is contractually presentation-only and
## collision-free (`get_central_berth_audit_report()["presentation_collision_free"]`),
## which is correct for paint, flush fixtures, retracted clamps and parked hoses.
## Ground support equipment is the opposite kind of object: a parts rack or a
## maintenance stand that a tow tractor passes through at 11.5 m/s is exactly the
## defect class this pass exists to avoid. So this line is a sibling of
## `LandingPad`, not a child of it, and everything in it that reads as solid is
## built through `_box`/`_cylinder` with `collidable = true`, which produces the
## chamfered mesh and the `BoxShape3D`/`CylinderShape3D` from the same `size`.
## The berth's own collision-free contract is therefore unchanged.
##
## Seating. The drawn walking surface here is the authored Blender shell, whose
## top face is `y = 0.095`, **not** the `y = -0.02` top of the `HeroBerthNode`
## collision box beneath it — the same 0.115 m discrepancy that made the berth
## cues read as floating. Every piece below is seated with a 0.010 m bearing into
## the surface it stands on (`SERVICE_LINE_SEAT_BEARING`), the figure the freight
## berth's cargo units already use, so nothing hovers and no two faces are
## coincident. Sub-pieces stack on the drawn top face of the piece under them.
##
## Lane discipline, measured against the contracts that already exist here:
##   * `protected_small_craft_half_width` is 6.5 m and the Torrent hull is 7.20 m
##     wide, so the launch sweep in `central_berth_hero_test` stages hull shapes
##     out to x = ±3.6. Nothing here comes inboard of x = -9.6.
##   * The published port exit route runs through `(-7.6, 0.2, -9.25)` with a
##     0.42 m capsule. The nearest piece to it is a deployed chock at x = -9.75,
##     leaving 2.15 m, and the walking lane between this line and the pad border
##     at x = -12.2 stays open at 2.7 m — wider than the tractor.
##   * The four recessed deck fixtures sit at x = -11.5, z = 1/-7/-15/-23. Every
##     assembly z is chosen to clear their 0.34 m wells.
##
## State, carried by hardware rather than paint. This is the idiom the registry
## pod's dispatch board and the dock arms already use: the readiness board's
## two assigned bays have their retaining pins **seated in their sockets** and
## their tiles lit; the one deferred bay has its pin **withdrawn and parked in
## the clip** under the board and its tile dark. The chocks are **out of the locker and
## on the deck** because a craft is berthed. Reading the berth's state does not
## require reading a colour.
##
## Every placement here is `modern_interpretation`: this is what a berth of this
## size needs to be worked, not recovered original station equipment.
func _build_central_berth_service_line() -> void:
	var line := Node3D.new()
	line.name = "CentralBerthServiceLine"
	line.set_meta("station_service_line", true)
	line.set_meta("berth_id", CENTRAL_BERTH_ID)
	line.set_meta("geometry_status", &"modern_interpretation")
	line.set_meta("interpretation_confidence", &"low")
	line.set_meta("authenticated_original_geometry", false)
	add_child(line)
	_central_berth_service_line = line
	_build_port_flank_ground_support(line)
	_build_dock_mast_foot_hardware(line)


## One ground-support assembly root, seated and tagged.
func _service_assembly(parent: Node3D, node_name: String, origin: Vector3, role: StringName) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = node_name
	assembly.position = origin
	assembly.set_meta("berth_service_role", role)
	assembly.set_meta("geometry_status", &"modern_interpretation")
	assembly.set_meta("interpretation_confidence", &"low")
	assembly.set_meta("authenticated_original_geometry", false)
	parent.add_child(assembly)
	return assembly


## Centre height for a box of `height` standing on the drawn face `support_top`.
func _seated_centre_y(support_top: float, height: float) -> float:
	return support_top - SERVICE_LINE_SEAT_BEARING + height * 0.5


## One fixture practical, in the idiom the four authored modules already share.
##
## Shadowless, sub-7 m, steeply attenuated, distance-faded, and always placed
## just outside a lens that is actually drawn, so the spill reads as coming from
## a fixture the player can see. This is the only mechanism in Forward+ that puts
## light on the plate a fixture is bolted to: `emission` is a purely local
## surface term and the glow pass is a screen-space convolution of the finished
## image, so neither delivers any radiance to a mount. Raising emission to
## compensate only widens the bloom, which is the bimodal-frame defect.
func _service_practical(
	parent: Node3D,
	node_name: String,
	light_position: Vector3,
	color: Color,
	energy: float,
	range_value: float
) -> OmniLight3D:
	var practical := OmniLight3D.new()
	practical.name = node_name
	practical.position = light_position
	practical.light_color = color
	practical.light_energy = energy
	practical.omni_range = range_value
	practical.omni_attenuation = 1.6
	practical.shadow_enabled = false
	practical.distance_fade_enabled = true
	practical.distance_fade_begin = 26.0
	practical.distance_fade_length = 12.0
	parent.add_child(practical)
	return practical


func _build_port_flank_ground_support(line: Node3D) -> void:
	var flank := Node3D.new()
	flank.name = "PortFlank"
	line.add_child(flank)
	var deck := AUTHORED_CENTRAL_BERTH_DECK_TOP

	# --- Berth readiness board -------------------------------------------------
	# Yawed 35 deg so its face is square to the walk down from the spawn marker
	# at (-8.5, 11) rather than to the world axes.
	var board := _service_assembly(flank, "BerthReadinessBoard", Vector3(-10.6, 0.0, 3.6), &"readiness_board")
	board.rotation_degrees = Vector3(0.0, 35.0, 0.0)
	_box(board, "BoardFoot", Vector3(0.0, _seated_centre_y(deck, 0.12), 0.0), Vector3(0.78, 0.12, 0.66), _materials["black"])
	var board_foot_top := deck - SERVICE_LINE_SEAT_BEARING + 0.12
	_box(board, "BoardMast", Vector3(0.0, _seated_centre_y(board_foot_top, 1.34), 0.0), Vector3(0.16, 1.34, 0.16), _materials["steel_blue"])
	_box(board, "BoardPanel", Vector3(0.0, 1.42, 0.06), Vector3(1.16, 0.80, 0.11), _materials["ivory"])
	_box(board, "BoardFace", Vector3(0.0, 1.42, 0.125), Vector3(1.00, 0.66, 0.02), _materials["navy"], false)
	# Three bays, one tile each. Bay 0 is this berth and bay 1 is the assigned
	# Halyard dock; only bay 2 remains deferred. The pin, not the tile colour, is
	# the state: seated in the socket for an assignment, parked in the clip for
	# the one deferral.
	var bay_states := [true, true, false]
	for bay_index in bay_states.size():
		var assigned: bool = bay_states[bay_index]
		var tile_x := -0.32 + float(bay_index) * 0.32
		_box(
			board,
			"BayTile%02d" % bay_index,
			Vector3(tile_x, 1.60, 0.14),
			Vector3(0.24, 0.16, 0.02),
			_materials["berth_cyan_glow"] if assigned else _materials["black"],
			false
		)
		_box(board, "BayPinSocket%02d" % bay_index, Vector3(tile_x, 1.34, 0.135), Vector3(0.10, 0.10, 0.02), _materials["black"], false)
		if assigned:
			_cylinder(board, "BaySeatedPin%02d" % bay_index, Vector3(tile_x, 1.34, 0.20), 0.028, 0.16, _materials["ivory"], false, Vector3(90.0, 0.0, 0.0))
	# Hooded lamp over the board. The board is the first object on this flank a
	# player walking down from the spawn marker meets, and an unlit board is a
	# board nobody reads.
	_box(board, "BoardLampHood", Vector3(0.0, 1.90, 0.16), Vector3(0.86, 0.09, 0.30), _materials["black"])
	_box(board, "BoardLampLens", Vector3(0.0, 1.845, 0.20), Vector3(0.72, 0.03, 0.20), _materials["white_glow"], false)
	_service_practical(board, "BoardLampPractical", Vector3(0.0, 1.74, 0.30), Color("dcefe9"), 1.05, 5.6)
	_box(board, "WithdrawnPinClip", Vector3(0.30, 1.14, 0.14), Vector3(0.30, 0.05, 0.03), _materials["black"], false)
	for parked_index in 1:
		_cylinder(
			board,
			"WithdrawnPin%02d" % parked_index,
			Vector3(0.22 + float(parked_index) * 0.14, 1.14, 0.155),
			0.028,
			0.16,
			_materials["orange"],
			false,
			Vector3(0.0, 0.0, 90.0)
		)

	# --- Cable drum and its deck coupling --------------------------------------
	var drum := _service_assembly(flank, "CableDrumStand", Vector3(-10.6, 0.0, -1.6), &"cable_drum")
	_box(drum, "DrumPlinth", Vector3(0.0, _seated_centre_y(deck, 0.22), 0.0), Vector3(1.34, 0.22, 1.08), _materials["black"])
	var drum_plinth_top := deck - SERVICE_LINE_SEAT_BEARING + 0.22
	for side in [-1.0, 1.0]:
		_box(
			drum,
			"DrumCheek%s" % ("Port" if side < 0.0 else "Starboard"),
			Vector3(side * 0.54, _seated_centre_y(drum_plinth_top, 0.92), 0.0),
			Vector3(0.11, 0.92, 0.74),
			_materials["steel_blue"]
		)
	var drum_axis_y := drum_plinth_top + 0.56
	_cylinder(drum, "DrumBarrel", Vector3(0.0, drum_axis_y, 0.0), 0.30, 0.94, _materials["orange"], true, Vector3(0.0, 0.0, 90.0))
	for coil_offset in [-0.24, 0.0, 0.24]:
		_torus(drum, "StowedCableCoil%s" % str(coil_offset).replace("-", "M").replace(".", "_"), Vector3(coil_offset, drum_axis_y, 0.0), 0.305, 0.36, _materials["black"], Vector3(0.0, 0.0, 90.0))
	# Hub, arm and grip, each overlapping the piece it is attached to. Built as
	# three touching parts rather than a stub and a floating bar: the focused
	# suite's drawn-geometry sweep found the first attempt's grip hanging 0.155 m
	# clear of the crank, which is exactly the reported defect class.
	_cylinder(drum, "DrumCrankHub", Vector3(0.60, drum_axis_y, 0.0), 0.05, 0.16, _materials["ivory"], false, Vector3(0.0, 0.0, 90.0))
	_box(drum, "DrumCrankArm", Vector3(0.67, drum_axis_y - 0.11, 0.0), Vector3(0.05, 0.28, 0.05), _materials["ivory"], false)
	_cylinder(drum, "DrumCrankGrip", Vector3(0.74, drum_axis_y - 0.22, 0.0), 0.035, 0.16, _materials["ivory"], false, Vector3(0.0, 0.0, 90.0))
	# The working end runs off the drum and down to a flush deck coupling, the
	# same "parked, and you can see where it plugs in" read the starboard
	# umbilicals already have.
	var lead_points := PackedVector3Array([
		Vector3(0.0, drum_axis_y - 0.30, 0.36),
		Vector3(0.10, drum_plinth_top * 0.5, 0.72),
		Vector3(0.42, deck + 0.05, 1.02),
		Vector3(0.96, deck + 0.04, 1.18),
	])
	for segment_index in lead_points.size() - 1:
		_beam_between(drum, "DrumLeadSegment%02d" % segment_index, lead_points[segment_index], lead_points[segment_index + 1], 0.05, _materials["black"], false)
	_torus(drum, "DrumDeckCoupling", Vector3(0.96, deck + 0.02, 1.18), 0.14, 0.22, _materials["steel_blue"])

	# --- Parts bin rack --------------------------------------------------------
	var rack := _service_assembly(flank, "PartsBinRack", Vector3(-10.6, 0.0, -6.2), &"parts_bin_rack")
	_box(rack, "RackFoot", Vector3(0.0, _seated_centre_y(deck, 0.12), 0.0), Vector3(1.48, 0.12, 0.82), _materials["black"])
	var rack_foot_top := deck - SERVICE_LINE_SEAT_BEARING + 0.12
	for side in [-1.0, 1.0]:
		_box(
			rack,
			"RackUpright%s" % ("Port" if side < 0.0 else "Starboard"),
			Vector3(side * 0.68, _seated_centre_y(rack_foot_top, 1.26), 0.0),
			Vector3(0.10, 1.26, 0.74),
			_materials["steel_blue"]
		)
	var shelf_tops := PackedFloat32Array()
	for shelf_index in 2:
		var shelf_top := rack_foot_top + 0.50 + float(shelf_index) * 0.52
		shelf_tops.append(shelf_top)
		_box(rack, "RackShelf%02d" % shelf_index, Vector3(0.0, shelf_top - 0.035, 0.0), Vector3(1.44, 0.07, 0.72), _materials["ivory"])
	var black_stock_transforms: Array[Transform3D] = []
	for shelf_index in shelf_tops.size():
		for bin_index in 3:
			var bin_material: Material = _materials["orange"] if (shelf_index + bin_index) % 2 == 0 else _materials["blue"]
			var bin_x := -0.46 + float(bin_index) * 0.46
			_box(
				rack,
				"PartsBin%02d%02d" % [shelf_index, bin_index],
				Vector3(bin_x, _seated_centre_y(shelf_tops[shelf_index], 0.28), 0.0),
				Vector3(0.42, 0.28, 0.58),
				bin_material
			)
			var stock_transform := Transform3D(
				Basis.IDENTITY,
				Vector3(bin_x, shelf_tops[shelf_index] + 0.20, 0.0)
			)
			if bin_index == 1:
				_box(
					rack,
					"BinStock%02d%02d" % [shelf_index, bin_index],
					stock_transform.origin,
					Vector3(0.30, 0.09, 0.44),
					_materials["ivory"],
					false
				)
			else:
				black_stock_transforms.append(stock_transform)
	_central_service_black_stock_transforms = black_stock_transforms.duplicate()
	_central_service_black_stock_batch = _multimesh_visual_boxes(
		rack,
		"BlackBinStock",
		Vector3(0.30, 0.09, 0.44),
		_materials["black"],
		black_stock_transforms
	)
	# Strip light under the upper shelf, so the lower bins are picked out and the
	# rack's own uprights carry a highlight rather than reading as a dark frame.
	var rack_strip_y := shelf_tops[1] - 0.10
	_box(rack, "RackStripHousing", Vector3(0.0, rack_strip_y, -0.16), Vector3(1.30, 0.07, 0.14), _materials["black"], false)
	_box(rack, "RackStripLens", Vector3(0.0, rack_strip_y - 0.045, -0.16), Vector3(1.18, 0.02, 0.10), _materials["white_glow"], false)
	_service_practical(rack, "RackStripPractical", Vector3(0.0, rack_strip_y - 0.16, 0.08), Color("e4ece6"), 0.85, 4.8)

	# --- Chock and strop locker, with the chocks deployed ----------------------
	var locker := _service_assembly(flank, "ChockLocker", Vector3(-10.6, 0.0, -11.2), &"chock_locker")
	_box(locker, "LockerBody", Vector3(0.0, _seated_centre_y(deck, 0.72), 0.0), Vector3(0.80, 0.72, 1.62), _materials["deck_light"])
	var locker_top := deck - SERVICE_LINE_SEAT_BEARING + 0.72
	_box(locker, "LockerLid", Vector3(0.0, _seated_centre_y(locker_top, 0.10), 0.0), Vector3(0.88, 0.10, 1.70), _materials["black"])
	_box(locker, "LockerDoor", Vector3(0.41, 0.44, 0.0), Vector3(0.02, 0.50, 1.34), _materials["navy"], false)
	_cylinder(locker, "LockerHandle", Vector3(0.44, 0.44, 0.0), 0.032, 0.46, _materials["ivory"], false, Vector3(90.0, 0.0, 0.0))
	# Out of the locker and on the deck: a craft is berthed.
	for chock_index in 2:
		var chock_z := -0.56 + float(chock_index) * 1.12
		_box(locker, "DeployedChockBody%02d" % chock_index, Vector3(0.85, _seated_centre_y(deck, 0.15), chock_z), Vector3(0.46, 0.15, 0.32), _materials["orange"])
		_box(locker, "DeployedChockRamp%02d" % chock_index, Vector3(0.94, _seated_centre_y(deck + 0.14, 0.13), chock_z), Vector3(0.26, 0.13, 0.32), _materials["orange"])

	# --- Rolling access work stand ---------------------------------------------
	# Risers are 0.29 m, under the 0.298 m step the station traversal graph
	# accepts, so the platform is genuinely climbable rather than a solid block
	# the player can only walk around.
	var stand := _service_assembly(flank, "AccessWorkStand", Vector3(-10.5, 0.0, -17.4), &"access_work_stand")
	var platform_top := deck + 0.87
	for leg_x in [-0.78, 0.78]:
		for leg_z in [-0.98, 0.98]:
			_box(
				stand,
				"StandLeg%s%s" % ["Port" if leg_x < 0.0 else "Starboard", "Aft" if leg_z < 0.0 else "Forward"],
				Vector3(leg_x, _seated_centre_y(deck, 0.685), leg_z),
				Vector3(0.16, 0.685, 0.16),
				_materials["steel_blue"]
			)
	_rounded_access_platform(
		stand,
		"StandPlatform",
		Vector3(0.0, platform_top - ACCESS_STAND_PLATFORM_SIZE.y * 0.5, 0.0),
		ACCESS_STAND_PLATFORM_SIZE,
		_materials["deck_light"],
		ACCESS_STAND_PLATFORM_CORNER_RADIUS,
		ACCESS_STAND_PLATFORM_CURVE_SEGMENTS
	)
	_box(stand, "StandStepLower", Vector3(0.0, _seated_centre_y(deck, 0.205), 1.44), Vector3(1.00, 0.205, 0.34), _materials["deck_light"])
	_box(stand, "StandStepUpper", Vector3(0.0, _seated_centre_y(deck, 0.495), 1.10), Vector3(1.00, 0.495, 0.34), _materials["deck_light"])
	# Rail on the outboard side only, so crew on the platform face the hull.
	for rail_z in [-0.92, 0.0, 0.92]:
		_box(stand, "StandRailPost%s" % str(rail_z).replace("-", "M").replace(".", "_"), Vector3(-0.82, _seated_centre_y(platform_top, 0.98), rail_z), Vector3(0.09, 0.98, 0.09), _materials["orange"])
	_box(stand, "StandRail", Vector3(-0.82, platform_top + 0.92, 0.0), Vector3(0.10, 0.10, 2.16), _materials["orange"])
	_box(stand, "StandToolbox", Vector3(0.10, _seated_centre_y(platform_top, 0.22), 0.34), Vector3(0.46, 0.22, 0.32), _materials["red"])
	# A hard hat left on the platform, the same "someone was here" note the crew
	# work post already carries.
	_sphere(stand, "StowedHardHat", Vector3(0.46, platform_top + 0.03, -0.62), 0.15, _materials["orange"], false)
	# Clamp-on work lamp on the rail, on its stub arm, aimed inboard at the hull
	# side of the platform. This is the lamp that makes the far end of the flank
	# read as a place being worked rather than as unlit deck.
	_box(stand, "WorkLampArm", Vector3(-0.66, platform_top + 0.94, -0.92), Vector3(0.34, 0.07, 0.07), _materials["steel_blue"], false)
	_box(stand, "WorkLampHood", Vector3(-0.44, platform_top + 0.90, -0.92), Vector3(0.26, 0.20, 0.26), _materials["black"])
	_box(stand, "WorkLampLens", Vector3(-0.44, platform_top + 0.80, -0.92), Vector3(0.19, 0.03, 0.19), _materials["white_glow"], false)
	_service_practical(stand, "WorkLampPractical", Vector3(-0.30, platform_top + 0.62, -0.92), Color("f1e6cf"), 1.35, 6.8)


## Foot hardware and a practical at each of the three freestanding dock masts.
##
## The masts are the tallest things in the hero cell. Before this each was a bare
## 10.4 m column with a lamp on its cap and
## nothing at its base: the cap lamp is 9.5 m up, so from eye height the mast is
## an unlit silhouette with no indication of what it is for or what it is bolted
## to. Emission cannot fix that — it is a purely local surface term and lights
## nothing it is mounted to — so each mast gets a real `OmniLight3D`, shadowless,
## sub-7 m, distance-faded, carrying the hue of the lens beside it, in the same
## idiom as the thirty-nine fixture practicals in the four authored modules.
##
## The mast at `z = 10` stands on the lattice deck, whose drawn top is
## `y = -0.02`; the two at `z = -23` stand on the authored
## shell at `y = 0.095`. Each foot is seated against its own deck.
func _build_dock_mast_foot_hardware(line: Node3D) -> void:
	# Preserve the remaining assemblies' stable IDs after removing foot 00 with
	# the obstructing port mast.
	var mast_specs := [
		[1, Vector3(11.0, 0.0, 10.0)],
		[2, Vector3(-11.0, 0.0, -23.0)],
		[3, Vector3(11.0, 0.0, -23.0)],
	]
	for mast_spec: Array in mast_specs:
		var mast_index := int(mast_spec[0])
		var mast_position := mast_spec[1] as Vector3
		var deck := (
			AUTHORED_CENTRAL_BERTH_DECK_TOP
			if mast_position.z <= AUTHORED_CENTRAL_BERTH_EDGE_Z
			else LATTICE_DECK_TOP
		)
		var foot := _service_assembly(
			line,
			"DockMastFoot%02d" % mast_index,
			Vector3(mast_position.x, 0.0, mast_position.z),
			&"mast_foot"
		)
		# Flush base plate: 0.09 m proud of the deck and deliberately not a
		# collider, because a 0.4 m wide lip around a mast the player walks past
		# at spawn is precisely the snagging defect this area already fixed twice.
		var flange := _cylinder(foot, "MastBaseFlange", Vector3(0.0, _seated_centre_y(deck, 0.09), 0.0), 0.86, 0.09, _materials["black"], false)
		flange.set_meta("flush_deck_detail", true)
		for cleat_index in 2:
			var cleat_z := -0.74 + float(cleat_index) * 1.48
			_box(foot, "MooringCleatStem%02d" % cleat_index, Vector3(0.0, _seated_centre_y(deck, 0.20), cleat_z), Vector3(0.14, 0.20, 0.14), _materials["ivory"])
			_box(foot, "MooringCleatHorn%02d" % cleat_index, Vector3(0.0, deck + 0.24, cleat_z), Vector3(0.56, 0.11, 0.15), _materials["ivory"])
		_box(foot, "MastFootJunctionBox", Vector3(0.68, _seated_centre_y(deck, 0.56), 0.0), Vector3(0.36, 0.56, 0.48), _materials["steel_blue"])
		var junction_top := deck - SERVICE_LINE_SEAT_BEARING + 0.56
		_box(foot, "MastFootStateTile", Vector3(0.87, deck + 0.38, 0.0), Vector3(0.02, 0.12, 0.30), _materials["berth_cyan_glow"], false)
		_box(foot, "MastFootLampHood", Vector3(0.68, _seated_centre_y(junction_top, 0.10), 0.0), Vector3(0.40, 0.10, 0.52), _materials["black"])
		_box(foot, "MastFootLens", Vector3(0.68, junction_top + 0.055, 0.0), Vector3(0.28, 0.03, 0.38), _materials["berth_cyan_glow"], false)
		# Lifted clear of the hood rather than sat on it: at 0.16 m the practical
		# put a blown ellipse of deck directly under itself in the spawn frame,
		# which is the same near-white patch the lighting pass was measuring
		# against. At 0.42 m with the shared 1.6 attenuation the same energy is
		# spread across the mast plate and the flange instead.
		_service_practical(
			foot,
			"MastFootPractical",
			Vector3(0.68, junction_top + 0.42, 0.0),
			MAST_FOOT_PRACTICAL_COLOR,
			0.95,
			6.4
		)


## Deep-detached renderer audit for the service line's one visual-only batch.
func get_central_berth_service_line_render_contract() -> Dictionary:
	var line := _central_berth_service_line
	if line == null or not is_instance_valid(line):
		line = get_node_or_null("CentralBerthServiceLine") as Node3D
	var descendant_count := 0
	var mesh_nodes: Array[Node] = []
	var batch_nodes: Array[Node] = []
	var drawn_copies := 0
	var submissions := 0
	var body_count := 0
	var shape_count := 0
	var light_count := 0
	var area_count := 0
	var ship_berth_count := 0
	if line != null:
		descendant_count = line.find_children("*", "Node", true, false).size()
		mesh_nodes = line.find_children("*", "MeshInstance3D", true, false)
		batch_nodes = line.find_children("*", "MultiMeshInstance3D", true, false)
		body_count = line.find_children("*", "PhysicsBody3D", true, false).size()
		shape_count = line.find_children("*", "CollisionShape3D", true, false).size()
		light_count = line.find_children("*", "Light3D", true, false).size()
		area_count = line.find_children("*", "Area3D", true, false).size()
		ship_berth_count = line.find_children("*", "ShipBerth", true, false).size()
		for raw_node in mesh_nodes:
			var instance := raw_node as MeshInstance3D
			if instance.mesh == null:
				continue
			drawn_copies += 1
			submissions += instance.mesh.get_surface_count()
		for raw_node in batch_nodes:
			var batch := raw_node as MultiMeshInstance3D
			if batch.multimesh == null or batch.multimesh.mesh == null:
				continue
			var visible_copies := batch.multimesh.visible_instance_count
			if visible_copies < 0:
				visible_copies = batch.multimesh.instance_count
			drawn_copies += visible_copies
			submissions += batch.multimesh.mesh.get_surface_count()

	var buffer_matches := false
	var bounds_match := false
	var metadata_matches := false
	var buffer_floats := 0
	if is_instance_valid(_central_service_black_stock_batch) \
			and _central_service_black_stock_batch.multimesh != null \
			and _central_service_black_stock_batch.multimesh.mesh != null:
		var multi := _central_service_black_stock_batch.multimesh
		var expected_buffer := _encode_multimesh_transforms(
			_central_service_black_stock_transforms
		)
		var expected_bounds := _transformed_mesh_bounds(
			multi.mesh.get_aabb(),
			_central_service_black_stock_transforms
		)
		buffer_floats = multi.buffer.size()
		buffer_matches = multi.buffer == expected_buffer
		bounds_match = multi.custom_aabb.is_equal_approx(expected_bounds)
		var published := _central_service_black_stock_batch.get_meta(
			"authored_instance_transforms", []
		) as Array
		metadata_matches = published.size() == _central_service_black_stock_transforms.size()
		for index in mini(published.size(), _central_service_black_stock_transforms.size()):
			metadata_matches = metadata_matches and (published[index] as Transform3D).is_equal_approx(
				_central_service_black_stock_transforms[index]
			)

	var exact_counts := (
		descendant_count == SERVICE_LINE_RENDER_DESCENDANT_COUNT
		and mesh_nodes.size() == SERVICE_LINE_RENDER_MESH_INSTANCE_COUNT
		and batch_nodes.size() == SERVICE_LINE_RENDER_MULTIMESH_BATCH_COUNT
		and drawn_copies == SERVICE_LINE_RENDER_DRAWN_COPY_COUNT
		and submissions == SERVICE_LINE_RENDER_SUBMISSION_COUNT
	)
	return {
		"descendant_nodes": descendant_count,
		"mesh_instances": mesh_nodes.size(),
		"multimesh_batches": batch_nodes.size(),
		"drawn_copies": drawn_copies,
		"geometry_submissions": submissions,
		"physics_bodies": body_count,
		"collision_shapes": shape_count,
		"lights": light_count,
		"areas": area_count,
		"ship_berths": ship_berth_count,
		"black_bin_stock_copies": _central_service_black_stock_transforms.size(),
		"renderer_buffer_floats": buffer_floats,
		"renderer_buffer_matches_authored": buffer_matches,
		"bounds_match_authored": bounds_match,
		"metadata_matches_authored": metadata_matches,
		"exact_counts": exact_counts,
		"line_parent_is_world": line != null and line.get_parent() == self,
		"line_transform_identity": line != null and line.transform.is_equal_approx(Transform3D.IDENTITY),
		"process_free": line != null and not line.is_processing() and not line.is_physics_processing(),
		"authored_black_stock_transforms": _central_service_black_stock_transforms.duplicate(),
	}.duplicate(true)


## Deep-detached audit for the port-flank ground support line and the mast feet.
##
## The roster is exact rather than a floor: this line exists to be a fixed,
## reviewable set of objects on a surface the player sees every session, and a
## range would let a piece silently disappear. `solid_body_count` is published
## because "looks solid, is solid" is the property that matters here — a tow
## tractor crosses this flank at 11.5 m/s.
func get_central_berth_service_line_report() -> Dictionary:
	var line := _central_berth_service_line
	if line == null or not is_instance_valid(line):
		line = get_node_or_null("CentralBerthServiceLine") as Node3D
	var errors: PackedStringArray = []
	var expected_roles := {
		&"readiness_board": 1,
		&"cable_drum": 1,
		&"parts_bin_rack": 1,
		&"chock_locker": 1,
		&"access_work_stand": 1,
		&"mast_foot": 3,
	}
	var role_counts := {}
	var solid_body_count := 0
	var practical_count := 0
	var minimum_x := INF
	var maximum_x := -INF
	if line == null:
		errors.append("CentralBerthServiceLine root is unavailable")
	else:
		if line.get_parent() != self or not line.transform.is_equal_approx(Transform3D.IDENTITY):
			errors.append("service line mount changed")
		if _central_berth_root != null and _central_berth_root.is_ancestor_of(line):
			errors.append("service line moved inside the collision-free LandingPad roster")
		for candidate in line.find_children("*", "", true, false):
			var role := StringName(candidate.get_meta("berth_service_role", &""))
			if not role.is_empty():
				role_counts[role] = int(role_counts.get(role, 0)) + 1
			if candidate is StaticBody3D:
				solid_body_count += 1
				var body := candidate as StaticBody3D
				if body.collision_layer != WORLD_LAYER or body.collision_mask != 0:
					errors.append("service body physics layers changed: %s" % body.name)
				if body.find_children("*", "CollisionShape3D", true, false).size() != 1 \
						or body.find_children("*", "MeshInstance3D", true, false).size() != 1:
					errors.append("service body is not one drawn mesh with one matched shape: %s" % body.name)
			if candidate is OmniLight3D:
				practical_count += 1
				var practical := candidate as OmniLight3D
				if practical.shadow_enabled or practical.omni_range > 7.0 or not practical.distance_fade_enabled:
					errors.append("mast foot practical left the fixture-practical idiom")
		# Deliberately the port flank only. The mast feet are a separate roster and
		# two of the three masts stand at x = +11, so sweeping the whole line would
		# report a starboard extent under a port-flank name.
		var flank := line.get_node_or_null(^"PortFlank") as Node3D
		if flank == null:
			errors.append("PortFlank ground support root is unavailable")
		else:
			for mesh_candidate in flank.find_children("*", "MeshInstance3D", true, false):
				var mesh_instance := mesh_candidate as MeshInstance3D
				if mesh_instance.mesh == null:
					continue
				var aabb := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
				minimum_x = minf(minimum_x, aabb.position.x)
				maximum_x = maxf(maximum_x, aabb.end.x)
	for role: StringName in expected_roles:
		if int(role_counts.get(role, 0)) != int(expected_roles[role]):
			errors.append(
				"%s assembly count is %d, expected %d"
				% [role, int(role_counts.get(role, 0)), int(expected_roles[role])]
			)
	# Three mast feet, plus the readiness board hood, the parts-rack strip and the
	# work stand's clamp lamp. Every one is mounted just outside a drawn lens.
	if practical_count != SERVICE_LINE_PRACTICAL_COUNT:
		errors.append(
			"service line practical count is %d, expected %d"
			% [practical_count, SERVICE_LINE_PRACTICAL_COUNT]
		)
	var render_contract := get_central_berth_service_line_render_contract()
	if not bool(render_contract.get("exact_counts", false)):
		errors.append("service line render roster changed")
	if int(render_contract.get("black_bin_stock_copies", 0)) != SERVICE_LINE_BLACK_BIN_STOCK_COPY_COUNT:
		errors.append("black bin-stock copy roster changed")
	if not bool(render_contract.get("renderer_buffer_matches_authored", false)):
		errors.append("black bin-stock renderer buffer changed")
	if not bool(render_contract.get("bounds_match_authored", false)):
		errors.append("black bin-stock culling bounds changed")
	if not bool(render_contract.get("metadata_matches_authored", false)):
		errors.append("black bin-stock authored roster metadata changed")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"berth_id": CENTRAL_BERTH_ID,
		"geometry_status": &"modern_interpretation",
		"interpretation_confidence": &"low",
		"authenticated_original_geometry": false,
		"assembly_counts": role_counts.duplicate(true),
		"expected_assembly_counts": expected_roles.duplicate(true),
		"solid_body_count": solid_body_count,
		"practical_count": practical_count,
		"seat_bearing": SERVICE_LINE_SEAT_BEARING,
		"authored_deck_top": AUTHORED_CENTRAL_BERTH_DECK_TOP,
		"port_flank_minimum_x": minimum_x,
		"port_flank_maximum_x": maximum_x,
		"render_batches": render_contract,
	}.duplicate(true)


## Bounded specular environment over the three module cells the hero probe never
## reached.
##
## `reflected_light_source` is the background, and the backdrop is nearly black,
## so before this every metal surface outside the central berth reflected nothing
## and metalness only subtracted diffuse. These three probes give the raised
## structural metalness something local to answer with. All are `UPDATE_ONCE`, so
## they are baked at load and cost nothing per frame, and none is tagged as a
## central feature, so the hero cell's single-probe contract is unchanged.
func _build_module_reflection_probes() -> void:
	var cells := [
		["AftOperationsReflectionProbe", Vector3(6.0, 5.5, 58.0), Vector3(40.0, 14.0, 30.0), 52.0],
		["HabitatExteriorReflectionProbe", Vector3(52.0, 5.0, 15.5), Vector3(34.0, 14.0, 30.0), 48.0],
		["FreightBerthReflectionProbe", Vector3(-53.0, 4.5, 34.0), Vector3(44.0, 14.0, 40.0), 56.0],
		["FleetDockCombReflectionProbe", Vector3(34.0, 5.0, 59.0), Vector3(58.0, 16.0, 30.0), 70.0],
	]
	for cell: Array in cells:
		var probe := ReflectionProbe.new()
		probe.name = str(cell[0])
		probe.position = cell[1] as Vector3
		probe.size = cell[2] as Vector3
		probe.max_distance = float(cell[3])
		probe.intensity = 0.85
		probe.box_projection = true
		probe.enable_shadows = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.set_meta("presentation_only", true)
		add_child(probe)


func _build_launch_corridor() -> void:
	var launch := Node3D.new()
	launch.name = "OpenLaunchSpine"
	add_child(launch)

	# The authored berth skin reaches the launch-arm threshold. Fill the prior
	# 3 m support gap with collision only, keeping the visible Blender shell and
	# the existing HeroBerthNode/LaunchArmDeck bodies otherwise unchanged.
	# Its top plane is the authored shell's y = 0.095, not the launch arm's y = 0.0,
	# so it must stay wholly under the shell. It used to reach z = -28.0 while the
	# shell stops at z = -27.75, leaving a 25.5 x 0.25 m strip of invisible ledge
	# standing 0.095 m proud of the arm. The launch arm deck below now reaches
	# z = -27.75 to meet the shell, and this block starts where the shell does.
	var transition := StaticBody3D.new()
	transition.name = "CentralBerthLaunchTransitionCollision"
	transition.position = Vector3(0.0, -0.5625, -26.375)
	transition.collision_layer = WORLD_LAYER
	transition.collision_mask = 0
	transition.set_meta("authored_surface_support", true)
	var transition_shape := CollisionShape3D.new()
	transition_shape.name = "Collision"
	var transition_box := BoxShape3D.new()
	transition_box.size = Vector3(25.5, 1.315, 2.75)
	transition_shape.shape = transition_box
	transition.add_child(transition_shape)
	launch.add_child(transition)

	# A narrow exposed flight arm replaces the previous enclosed runway. Width is
	# a modern safety allowance for the hero ship, not an inferred measurement.
	# Extended 0.25 m aft so its rendered edge meets the authored central-berth
	# shell at z = -27.75 instead of stopping short of it under a bare collision
	# block. Its forward end, width and top plane are unchanged.
	_box(
		launch,
		"LaunchArmDeck",
		Vector3(0, -0.36, (-68.0 - 27.75) * 0.5),
		Vector3(21.5, 0.72, 68.0 - 27.75),
		_materials["navy"]
	)
	_box(launch, "LaunchArmCentre", Vector3(0, 0.035, -48.0), Vector3(0.2, 0.05, 37.0), _materials["orange_glow"], false)
	for x_position in [-10.35, 10.35]:
		_box(launch, "LaunchEdgeTrim", Vector3(x_position, 0.08, -48.0), Vector3(0.26, 0.12, 39.0), _materials["cyan_glow"], false)
		_box(launch, "LaunchUnderRail", Vector3(x_position, -1.1, -48.0), Vector3(0.8, 1.0, 39.0), _materials["steel_blue"], false)

	for z_position in [-34.0, -40.0, -46.0, -52.0, -58.0]:
		for x_position in [-9.7, 9.7]:
			_add_guide_light(launch, Vector3(x_position, 0.85, z_position), KETH_ORANGE, true)

	# An open signal gantry marks the gameplay launch threshold near z=-66. It is
	# navigation infrastructure, not a pressure frame or recovered station gate.
	for side in [-1.0, 1.0]:
		_cylinder(launch, "SignalMast", Vector3(side * 13.0, 6.8, -66.0), 0.62, 13.6, _materials["steel_blue"], true)
		_cylinder(launch, "SignalMastCollar", Vector3(side * 13.0, 1.6, -66.0), 1.0, 0.65, _materials["orange"], false)
		for y_position in [2.7, 6.2, 9.7]:
			_add_guide_light(launch, Vector3(side * 12.9, y_position, -65.45), ALERT_RED, true)
	_box(launch, "SignalGantry", Vector3(0, 12.2, -66.0), Vector3(27.0, 0.8, 0.8), _materials["steel_blue"], false)
	_box(launch, "SignalFace", Vector3(0, 12.15, -65.52), Vector3(12.0, 1.4, 0.08), _materials["navy"], false)
	var launch_vector_sign := _text_sign(
		launch,
		"OPEN DOCK  //  FLIGHT VECTOR",
		Vector3(0, 12.2, -65.42),
		Vector3.ZERO,
		0.46,
		_materials["white_glow"]
	)
	launch_vector_sign.visibility_range_begin = 7.0
	launch_vector_sign.visibility_range_begin_margin = 2.0
	var clearance_sign := _text_sign(
		launch,
		"CLEAR OF BERTH",
		Vector3(0, 11.35, -65.4),
		Vector3.ZERO,
		0.28,
		_materials["orange_glow"]
	)
	clearance_sign.visibility_range_begin = 7.0
	clearance_sign.visibility_range_begin_margin = 2.0

	# Narrow continuation beams carry the eye into open space and keep the
	# negative-space silhouette visible from the central junction.
	for side in [-1.0, 1.0]:
		_box(launch, "OutboundKeel", Vector3(side * 8.0, -1.0, -76.0), Vector3(0.7, 0.7, 20.0), _materials["steel_blue"], false)
		for z_position in [-68.0, -75.0, -82.0]:
			_add_guide_light(launch, Vector3(side * 8.0, 0.4, z_position), KETH_CYAN, true)


func _build_catwalks_and_control_room() -> void:
	var upper := Node3D.new()
	upper.name = "UpperOperations"
	add_child(upper)

	# B3's registered 00:04-00:52 anchor supports an exposed spawn/return deck
	# and a "short vertical transition". It does not identify a ladder, stair or
	# ramp, nor does it establish this implementation's placement, rise or tread
	# count. The traversable stair/ramp below is therefore a modern interpretation.
	_box(upper, "ObservationLanding", Vector3(-11.5, 3.05, 3.0), Vector3(4.6, 0.55, 4.4), _materials["deck_light"])
	# CharacterBody3D has no implicit step-up solver. The former seven physical
	# boxes rose 0.425 m per tread, so continuous W stalled against the first
	# vertical face even though the stairs looked traversable. One rendered and
	# colliding ramp is now the true walking surface and terminates flush inside
	# the unchanged landing. Seven shallow overlays retain tread rhythm without
	# diverging materially from the capsule's physical foot plane.
	var ramp_surface_start := Vector3(-11.5, 0.0, 9.6)
	var ramp_surface_finish := Vector3(-11.5, 3.325, 5.2)
	var ramp_down_direction := ramp_surface_start - ramp_surface_finish
	var ramp_up_normal := Vector3(0.0, ramp_down_direction.z, -ramp_down_direction.y).normalized()
	var stair_ramp := StaticBody3D.new()
	stair_ramp.name = "JunctionAccessRamp"
	stair_ramp.collision_layer = WORLD_LAYER
	stair_ramp.collision_mask = 0
	stair_ramp.position = (ramp_surface_start + ramp_surface_finish) * 0.5 - ramp_up_normal * 0.11
	stair_ramp.quaternion = Quaternion(Vector3.BACK, ramp_down_direction.normalized())
	stair_ramp.set_meta("continuous_player_stair", true)
	stair_ramp.set_meta("visible_tread_count", 7)
	stair_ramp.set_meta("evidence_source", "B3")
	stair_ramp.set_meta("evidence_anchor", "00:04-00:52")
	stair_ramp.set_meta("evidence_claim_id", "station.spawn_deck_short_vertical_transition")
	stair_ramp.set_meta("evidence_observation", "Exposed spawn/return deck, short vertical transition, branching arms, and red VIP sightline.")
	stair_ramp.set_meta("evidence_status", "original_era_observed")
	stair_ramp.set_meta("implementation_form", "modern_stair_ramp")
	stair_ramp.set_meta("historical_form_identified", false)
	stair_ramp.set_meta("historical_ladder_supported", false)
	upper.add_child(stair_ramp)
	var stair_ramp_mesh_instance := MeshInstance3D.new()
	stair_ramp_mesh_instance.name = "Mesh"
	# The only raw `BoxMesh` left in this file, sitting directly under seven
	# chamfered treads built by `_box()`. It now uses the same helper, so the ramp
	# slab and its own treads stop disagreeing about their edge treatment. The
	# helper preserves the requested extent exactly, so the collider below and the
	# continuous-stair contract are untouched.
	var stair_ramp_size := Vector3(3.6, 0.22, ramp_down_direction.length())
	stair_ramp_mesh_instance.mesh = _rounded_box_mesh(stair_ramp_size)
	stair_ramp_mesh_instance.material_override = _materials["deck_light"]
	stair_ramp.add_child(stair_ramp_mesh_instance)
	var stair_ramp_collision := CollisionShape3D.new()
	stair_ramp_collision.name = "Collision"
	var stair_ramp_shape := BoxShape3D.new()
	stair_ramp_shape.size = stair_ramp_size
	stair_ramp_collision.shape = stair_ramp_shape
	stair_ramp.add_child(stair_ramp_collision)
	for step in 7:
		var progress := float(step) / 6.0
		var tread_z := lerpf(ramp_surface_start.z - 0.12, ramp_surface_finish.z + 0.12, progress)
		var ramp_progress := inverse_lerp(ramp_surface_start.z, ramp_surface_finish.z, tread_z)
		var tread_top := lerpf(ramp_surface_start.y, ramp_surface_finish.y, ramp_progress)
		_box(
			upper,
			"JunctionAccessTread%02d" % (step + 1),
			Vector3(-11.5, tread_top, tread_z),
			Vector3(3.6, 0.024, 0.12),
			_materials["deck_light"],
			false
		)
	for side in [-1.0, 1.0]:
		_box(upper, "JunctionStairRail", Vector3(-11.5 + side * 1.85, 2.2, 7.2), Vector3(0.15, 0.15, 5.2), _materials["orange"], true, Vector3(38, 0, 0))
		_box(upper, "LandingRail", Vector3(-11.5 + side * 2.15, 4.0, 3.0), Vector3(0.16, 1.65, 4.4), _materials["ivory"])
	_box(upper, "LandingEndRail", Vector3(-11.5, 4.0, 0.85), Vector3(4.4, 1.65, 0.16), _materials["ivory"])
	_build_observation_landing_post(upper)

	# A compact modern operations pod is attached to, rather than enclosing, the
	# starboard node. Its purpose and adjacency are not recovered original facts.
	_box(upper, "OperationsPodFloor", Vector3(43.0, 0.18, 27.0), Vector3(12.0, 0.4, 8.0), _materials["deck_light"])
	# The pod floor is a 0.40 m slab resting on the starboard node, so its glazed
	# frontage presented a 0.40 m vertical face to anyone walking up to it — a wall,
	# not a step, for a CharacterBody3D. The pod keeps its authored placement; a
	# rendered threshold apron closes the seam across the whole frontage.
	var operations_threshold := _approach_threshold(
		upper,
		"OperationsPodThreshold",
		Vector3(43.0, -0.02, 21.85),
		Vector3(43.0, 0.38, 23.05),
		12.0,
		_materials["deck_light"]
	)
	# The threshold remains the full-width approach apron, but its centreline is
	# the pod's sole ingress.  Publishing the opening on the rendered threshold
	# keeps route consumers aligned with the actual gap in the frontage below.
	operations_threshold.set_meta("station_doorway", true)
	operations_threshold.set_meta("open_bay_center_x", 43.0)
	operations_threshold.set_meta("open_bay_clear_width", 3.34)
	_box(upper, "OperationsPodRoof", Vector3(43.0, 5.9, 27.0), Vector3(12.0, 0.55, 8.0), _materials["ivory"])
	_box(upper, "OperationsPodBack", Vector3(43.0, 3.0, 30.8), Vector3(12.0, 5.5, 0.5), _materials["steel_blue"])
	for x_position in [37.5, 41.2, 44.8, 48.5]:
		_box(upper, "OperationsWindowMullion", Vector3(x_position, 3.0, 22.95), Vector3(0.26, 5.4, 0.32), _materials["steel_blue"])
	# OPS-GLAZING-001, found by measuring every mesh in this pod against every
	# other mesh in the station rather than by reading the code.
	#
	# The glazing was authored inside the mullion loop as one 3.15 m pane per
	# mullion, offset +1.75 m in x. Two consequences, both live until now and both
	# in the class the 2026-08-15 report named:
	#
	#   Every pane floated. A pane spanned `x_position + 0.175 … + 3.325` while its
	#   own mullion occupies `x_position ± 0.13` and the next one starts at
	#   `+ 3.57`, so all four panes stood in a 0.245 m gap between the frames they
	#   are supposed to be glazed into and touched no geometry anywhere.
	#   The fourth pane hung off the end of the building. The pod floor is
	#   `x 37 … 49`; that pane reached `x = 51.825`, so 2.83 m of a 4.7 m tall
	#   sheet of glass stood in open space past the corner of the pod.
	#
	# The four mullions stay exactly where they were — they carry this roof, which
	# is why this pod never had the cantilever its mirror image did. The two outer
	# bays retain the same glass material and 0.1 m bedding into each frame, now as
	# real World-layer pressure barriers. The 3.34 m clear middle bay is the one
	# explicit entrance, centred at x=43 on OperationsPodThreshold and on the
	# production controller's no-jump approach. Making all three old panes solid
	# would have fixed glass by sealing the room.
	for bay in [["OperationsWindow", 39.35, 3.9], ["OperationsWindow03", 46.65, 3.9]]:
		var pane_visual := _box(
			upper,
			String(bay[0]),
			Vector3(float(bay[1]), 3.0, 22.8),
			Vector3(float(bay[2]), 4.7, 0.08),
			_materials["glass"],
			false
		) as MeshInstance3D
		pane_visual.set_meta("station_glazing", true)
		pane_visual.set_meta("frontage_role", &"side_glazing")
		var pane_body := StaticBody3D.new()
		pane_body.name = "PressureBarrier"
		pane_body.collision_layer = WORLD_LAYER
		pane_body.collision_mask = PhysicsLayers.NONE
		pane_body.set_meta("station_glazing", true)
		pane_body.set_meta("physical_pressure_barrier", true)
		pane_body.set_meta("frontage_role", &"side_glazing")
		pane_visual.add_child(pane_body)
		var pane_collision := CollisionShape3D.new()
		pane_collision.name = "Collision"
		var pane_shape := BoxShape3D.new()
		pane_shape.size = Vector3(float(bay[2]), 4.7, 0.08)
		pane_collision.shape = pane_shape
		pane_body.add_child(pane_collision)
	# REGEN-DECK-002's mirror image, and measured the same way: the DOCK OPERATIONS
	# legend occupied y = 5.003 … 5.268 at z = 22.674, touching nothing. Same
	# fascia, sized to meet these glyphs where they already stand (fascia face
	# z = 22.68 against a glyph rear of 22.686) and hung off this roof's leading
	# edge. The legend's position, rotation, scale and material are untouched, so
	# its recorded MAP-004 approach-facing expectation still holds.
	_extruded_capsule_fascia(
		upper,
		"OperationsPodFascia",
		Vector3(43.0, 5.35, 22.90),
		Vector3(12.0, 1.0, 0.44),
		_materials["steel_blue"],
		0.5,
		8,
	)
	# MAP-004. `TextMesh` renders its readable face toward local +Z, so a legend
	# authored with `Vector3.ZERO` on a structure's -Z frontage reads as mirror
	# writing to the only person who can see it. The pod is approached from the
	# lattice deck at lower z, so the legend is yawed 180 degrees to face them.
	# The glyph extrusion is symmetric about local z = 0, so this does not change
	# the sign's depth footprint and cannot push it into the glazing behind it.
	_text_sign(
		upper,
		"DOCK OPERATIONS",
		Vector3(43.0, 5.15, 22.68),
		Vector3(0.0, 180.0, 0.0),
		0.48,
		_materials["cyan_glow"]
	)
	_build_dock_operations_room(upper)


## The glass-fronted Dock Operations pod is a modern, non-authoritative traffic
## workspace.  It deliberately stays separate from the Aft Operations module:
## this is a readable destination and staging space, not another route, berth,
## or activity owner.  The outer 0.9 m of the east side remains clear because
## the production walk to Fabrication Annex passes through that aisle.
func _build_dock_operations_room(upper: Node3D) -> void:
	var room := Node3D.new()
	room.name = "DockOperationsRoom"
	room.set_meta("presentation_only", true)
	room.set_meta("historical_form_identified", false)
	upper.add_child(room)
	# Room-local displays use the same restrained dark-screen recipe as Aft
	# Operations. The station-wide cyan signal material is intentionally much
	# brighter and made this room's large traffic board clip white, forcing the
	# exposure down until the surrounding floor and furniture read as black.
	var room_screen_material := _material(
		Color("3a7479"), 0.34, 0.42, Color("2aa6ae"), 0.35
	)

	# A shallow inset breaks up the otherwise empty deck without adding a raised
	# edge to the approach path.
	_box(room, "OperationsDeckInset", Vector3(42.35, 0.391, 27.55), Vector3(8.3, 0.022, 5.0), _materials["deck"], false)

	# The back-wall board supplies the room's at-a-glance purpose from the open
	# frontage.  It is seated against the structural back wall, not suspended in
	# the glazed volume.
	_box(room, "DockStatusBoard", Vector3(42.4, 3.35, 30.52), Vector3(7.4, 2.45, 0.12), _materials["navy"], false)
	_box(room, "DockStatusField", Vector3(42.4, 3.35, 30.44), Vector3(6.85, 1.78, 0.035), room_screen_material, false)
	_text_sign(room, "TRAFFIC BOARD", Vector3(42.4, 4.18, 30.405), Vector3(0.0, 180.0, 0.0), 0.20, _materials["ivory"])
	_text_sign(room, "DOCK 01  CLEAR", Vector3(42.4, 3.62, 30.40), Vector3(0.0, 180.0, 0.0), 0.16, _materials["ivory"])
	_text_sign(room, "DOCK 02  TRANSFER", Vector3(42.4, 3.24, 30.40), Vector3(0.0, 180.0, 0.0), 0.14, _materials["ivory"])
	_text_sign(room, "DOCK 03  STANDBY", Vector3(42.4, 2.88, 30.40), Vector3(0.0, 180.0, 0.0), 0.14, _materials["ivory"])

	# A compact dispatch island faces the glazed front, with three independently
	# legible posts. The east aisle beyond x=47.0 is intentionally left open for
	# the Annex route and for a clear view through the right-hand window bay.
	# The original row ran across the middle of the room. Moving only station 03
	# exposed station 02 in the same sightline, so the row itself was the defect.
	# All three stations now form a west-wall bank, rotated toward the open room;
	# the centre and the full east/Annex arrival aisle remain unobstructed.
	var dispatch_station_z_positions := [24.50, 27.00, 29.50]
	var keyline_transforms: Array[Transform3D] = []
	for station_index in dispatch_station_z_positions.size():
		var station_z := float(dispatch_station_z_positions[station_index])
		_box(room, "DispatchConsole%02d" % (station_index + 1), Vector3(38.25, 1.02, station_z), Vector3(1.82, 1.22, 0.88), _materials["navy"], true, Vector3(0.0, -90.0, 0.0))
		_box(room, "DispatchScreen%02d" % (station_index + 1), Vector3(38.72, 1.48, station_z), Vector3(1.48, 0.56, 0.045), room_screen_material, false, Vector3(-20.0, -90.0, 0.0))
		var keyline_anchor := Marker3D.new()
		keyline_anchor.name = "DispatchKeyline%02d" % (station_index + 1)
		keyline_anchor.position = DOCK_OPERATIONS_KEYLINE_POSITIONS[station_index]
		keyline_anchor.rotation_degrees = DOCK_OPERATIONS_KEYLINE_ROTATION_DEGREES
		keyline_anchor.set_meta("batched_visual_anchor", true)
		room.add_child(keyline_anchor)
		keyline_transforms.append(keyline_anchor.transform)
		_text_sign(room, "BAY %02d" % (station_index + 1), Vector3(38.755, 1.49, station_z), Vector3(-20.0, 90.0, 0.0), 0.12, _materials["ivory"])
		_cylinder(room, "DispatchStool%02d" % (station_index + 1), Vector3(37.45, 0.73, station_z), 0.32, 0.62, _materials["steel_blue"], true)
		_box(room, "DispatchSeat%02d" % (station_index + 1), Vector3(37.45, 1.06, station_z), Vector3(0.76, 0.16, 0.70), _materials["ivory"], true, Vector3(0.0, -90.0, 0.0))
	_multimesh_visual_boxes(
		room,
		"DispatchKeylineRenderBatch",
		DOCK_OPERATIONS_KEYLINE_SIZE,
		_materials["steel_blue"],
		keyline_transforms
	)

	# A shared plotting surface adds a foreground read from outside without
	# sealing the pod's centre. It is low enough to read as equipment rather than
	# a second wall between the player and the room.
	_box(room, "DockPlotTable", Vector3(45.40, 0.78, 29.60), Vector3(2.55, 0.76, 1.35), _materials["steel_blue"])
	_box(room, "DockPlotDisplay", Vector3(45.40, 1.175, 29.60), Vector3(2.12, 0.035, 0.96), room_screen_material, false)
	_torus(room, "DockPlotLocatorRing", Vector3(45.40, 1.21, 29.60), 0.25, 0.42, _materials["orange_glow"])

	# The west-wall console bank takes over the lockers' former strip. The old
	# lockers are omitted instead of being pushed into the glass-fronted entrance;
	# that would merely exchange a centre obstruction for an approach obstruction.

	# Narrow ceiling ribs make the interior read as an occupied room from the
	# exterior.
	for x_position in [39.2, 43.0, 46.8]:
		_box(room, "OperationsCeilingRib", Vector3(x_position, 5.59, 27.0), Vector3(0.16, 0.08, 6.9), _materials["steel_blue"], false)

	# Two visible, local ceiling practicals light the plated floor and furniture.
	# They are shadowless and tightly ranged so this room gains readable fill
	# without changing the lighting of the adjoining exterior deck.
	var room_light_specs := [
		["OperationsCeilingLightWest", Vector3(40.5, 5.10, 27.0)],
		["OperationsCeilingLightEast", Vector3(45.5, 5.10, 27.0)],
	]
	for light_spec: Array in room_light_specs:
		var light_name := light_spec[0] as String
		var light_position := light_spec[1] as Vector3
		_box(room, light_name + "Body", Vector3(light_position.x, 5.57, light_position.z), Vector3(2.15, 0.11, 0.44), _materials["black"], false)
		_box(room, light_name + "Lens", Vector3(light_position.x, 5.4975, light_position.z), Vector3(1.85, 0.035, 0.20), _materials["white_glow"], false)
		var room_light := SpotLight3D.new()
		room_light.name = light_name
		room_light.position = light_position
		room_light.rotation_degrees.x = -90.0
		room_light.light_color = Color("d9f6f3")
		room_light.light_energy = 1.6
		room_light.spot_range = 8.5
		room_light.spot_angle = 55.0
		room_light.spot_angle_attenuation = 0.55
		room_light.spot_attenuation = 0.85
		room_light.shadow_enabled = false
		room_light.distance_fade_enabled = true
		room_light.distance_fade_begin = 28.0
		room_light.distance_fade_length = 12.0
		room_light.set_meta("localized_room_practical", true)
		room.add_child(room_light)


## Why anyone climbs the ramp.
##
## `ObservationLanding` is the one live platform the topology grading ties to a
## registered anchor — B3's "short vertical transition" near an open junction —
## and everything above the first tread is `modern_interpretation`: the landing's
## own dimensions, its rails, and the fact that it is called "observation" at all.
## It was a 4.6 x 4.4 m plate with three rails and nothing on it, so the seven
## treads led to an empty box directly in front of the spawn deck, which is the
## worst possible first read of the station.
##
## It is now a traffic observation post: a console with a lit readout facing the
## reader who arrives up the ramp, a fixed viewer on a post pointed out over the
## junction, a stowed equipment locker against the starboard rail, a grip inset
## over the walking plate, and a task light. That is a reason for the platform to
## exist which claims nothing historical — B3's anchor observes a transition, not
## a function, and this pass does not upgrade it.
##
## Two rules held throughout. **Anything a player would be stopped by is
## collidable**: the console and the locker are `StaticBody3D` on the World layer
## like every other solid thing in this file, so nothing here is a solid-looking
## object you walk through, and both are drawn where they collide. **Nothing
## floats**: the console and the viewer post stand on the landing's 3.325 m top
## plane, the readout is inset into the console's own 4.225 m top, the locker
## meets the starboard rail, and the sign's glyph face is on the console front
## rather than proud of it in air.
func _build_observation_landing_post(upper: Node3D) -> void:
	# Grip plate over the walking surface. It sits on the collidable landing, so
	# the discovery sweep keeps proving there is floor beneath it.
	_box(upper, "LandingDeckInset", Vector3(-11.5, 3.335, 3.0), Vector3(3.9, 0.03, 3.7), _materials["deck"], false)

	# The console faces the ramp: a reader arriving from higher z looks in -Z, so
	# the legend's readable +Z face needs no yaw at all. This is the same MAP-004
	# rule the pod legends in this file follow, applied from the other side —
	# copying their 180-degree yaw here would mirror it.
	_box(upper, "LandingObservationConsole", Vector3(-11.5, 3.775, 1.3), Vector3(2.2, 0.9, 0.62), _materials["navy"])
	_box(upper, "LandingConsoleReadout", Vector3(-11.5, 4.24, 1.3), Vector3(1.9, 0.06, 0.44), _materials["cyan_glow"], false)
	_text_sign(upper, "TRAFFIC OBSERVATION", Vector3(-11.5, 3.95, 1.612), Vector3.ZERO, 0.16, _materials["white_glow"])

	# Fixed viewer, pointed out over the open junction rather than at the wall.
	_cylinder(upper, "LandingViewerPost", Vector3(-12.75, 3.85, 2.4), 0.13, 1.05, _materials["steel_blue"], false)
	_box(upper, "LandingViewerHead", Vector3(-12.75, 4.42, 2.55), Vector3(0.46, 0.3, 0.78), _materials["navy"], false, Vector3(-18.0, 0.0, 0.0))
	_add_guide_light(upper, Vector3(-12.75, 4.45, 2.4), KETH_CYAN, false, 1.2, 5.5)

	# Stowed kit against the starboard rail, which it physically meets.
	_box(upper, "LandingEquipmentLocker", Vector3(-9.75, 3.825, 1.35), Vector3(0.8, 1.0, 0.6), _materials["deck_light"])


func _build_regeneration_gallery() -> void:
	# Creator-authored pages and footage prove name/chat-based regeneration, but
	# do not prove a bank of physical per-ship controls. This single terminal is
	# an explicitly modern diegetic interface for that classic convention. Its
	# linked indicator points to a real berth rather than authenticating a model.
	var gallery := Node3D.new()
	gallery.name = "ModernFleetRegistry"
	add_child(gallery)

	# PORT-DECK-001 knock-on, answered on measurement rather than carried.
	#
	# `ARROW_BERTH_CUE_DECK_DECISION.md` asked whether this pod deck widens with
	# the berth node or whether the node tapers around it. Widened to the node's
	# new 16.8 m it reaches x = -51.4, which puts it underneath the Jovian freight
	# branch's connection lattice: measured live, that adds `ConnectionDeckA`,
	# `ConnectionDeckB` and `LatticePost5` to the freight module's legacy-overlap
	# set, all three sharing this deck's exact y = 0.380 top plane, where
	# `tests/jovian_freight_berth_transform_test.gd` deliberately admits exactly
	# one declared handoff leaf. Three new coplanar decks on a walked route is a
	# worse defect than the 2.4 m re-entrant ledge it would remove, so the pod
	# keeps its 12.0 m width and the node tapers around it.
	_box(gallery, "RegistryPodDeck", Vector3(-43.0, 0.18, 27.0), Vector3(12.0, 0.4, 8.0), _materials["deck_light"])
	# Same 0.40 m slab seam as the operations pod, and the one that also sealed the
	# entire freight branch: the freight connection lattice hands off to this deck,
	# so nothing beyond it could be walked to either (MAP-002).
	_approach_threshold(
		gallery,
		"RegistryPodThreshold",
		Vector3(-43.0, -0.02, 21.85),
		Vector3(-43.0, 0.38, 23.05),
		12.0,
		_materials["deck_light"]
	)
	_box(gallery, "RegistryPodBack", Vector3(-43.0, 3.0, 30.8), Vector3(12.0, 5.5, 0.5), _materials["ivory"])
	_box(gallery, "RegistryPodRoof", Vector3(-43.0, 5.9, 27.0), Vector3(12.0, 0.55, 8.0), _materials["steel_blue"])

	# REGEN-DECK-001, measured rather than assumed. This roof is a 12 x 8 m slab
	# whose only support anywhere in the module was the back wall at z = 30.55, so
	# it cantilevered 7.5 m over the deck on nothing at all. Its mirror image, the
	# Dock Operations pod, is carried by its four window mullions and always was;
	# only this pod was unsupported. Four corner columns restore the parity. Each
	# is buried in the deck slab at the bottom (column base y = 0.25 against a deck
	# section of -0.02 … 0.38) and enters the roof at the top (column crown 5.65
	# against a roof underside of 5.625), so neither end floats, and they stand
	# 0.4 m inside the deck's own footprint so nothing overhangs.
	var column_transforms: Array[Transform3D] = []
	var column_bodies: Array[StaticBody3D] = []
	for column_x in [-48.6, -37.4]:
		for column_z in [23.4, 30.4]:
			var column_transform := Transform3D(
				Basis.IDENTITY,
				Vector3(column_x, 2.95, column_z)
			)
			# Keep each independently named physical column. Only the identical
			# child render meshes are batched below; collision and path authority
			# remain one body and one shape per authored transform.
			var column := StaticBody3D.new()
			column.name = "RegistryPodColumn"
			column.transform = column_transform
			column.collision_layer = WORLD_LAYER
			column.collision_mask = 0
			gallery.add_child(column)
			var collision := CollisionShape3D.new()
			collision.name = "Collision"
			var shape := BoxShape3D.new()
			shape.size = MODERN_REGISTRY_COLUMN_SIZE
			collision.shape = shape
			column.add_child(collision)
			column_transforms.append(column_transform)
			column_bodies.append(column)
	_modern_registry_column_transforms = column_transforms.duplicate()
	_modern_registry_column_bodies = column_bodies.duplicate()
	_modern_registry_column_batch = _multimesh_visual_boxes(
		gallery,
		"RegistryPodColumnVisuals",
		MODERN_REGISTRY_COLUMN_SIZE,
		_materials["steel_blue"],
		column_transforms
	)

	# REGEN-DECK-002. The pod's own identity legend hung in mid-air: measured live
	# it occupied y = 4.928 … 5.148 at z = 22.815, which is 0.18 m in front of the
	# roof's leading edge and 0.48 m below it, touching no geometry in the station.
	# MAP-004 turned it the right way round; nothing ever mounted it. This fascia
	# is the panel it is lettered onto — hung off the roof's front edge (fascia top
	# 5.85 against a roof underside of 5.625) with its face at z = 22.82, exactly
	# where the existing glyphs already stand. The legend's position, rotation,
	# scale, wording and material are deliberately untouched, so `MAP-004`'s
	# recorded approach-facing expectation still holds unchanged.
	var registry_header := _extruded_capsule_fascia(
		gallery,
		"RegistryPodFascia",
		Vector3(-43.0, 5.35, 23.03),
		MODERN_REGISTRY_HEADER_SIZE,
		_materials["navy"],
		MODERN_REGISTRY_HEADER_END_RADIUS,
		MODERN_REGISTRY_HEADER_CURVE_SEGMENTS
	)
	var registry_header_visual := registry_header.get_node(^"Mesh") as MeshInstance3D
	registry_header_visual.mesh.resource_name = "modern_registry_capsule_header_v1"
	registry_header.set_meta("geometry_profile", &"regeneration_deck_capsule_header")
	registry_header.set_meta("authenticated_original_geometry", false)
	# MAP-004, same cause as the Dock Operations legend above.
	_text_sign(
		gallery,
		"FLEET REGISTRY  //  MODERN INTERFACE",
		Vector3(-43.0, 5.05, 22.82),
		Vector3(0.0, 180.0, 0.0),
		0.4,
		_materials["orange_glow"]
	)

	var terminal_position := Vector3(-43.0, 1.45, 24.6)
	_box(gallery, "FleetRegistryTerminal", terminal_position, Vector3(4.6, 2.7, 1.9), _materials["navy"])
	# The panel was 1.35 m tall, spanning y = 1.195 … 2.545, while the legend block
	# in front of it runs y = 1.134 … 2.254. The bottom line ("UTOPIA  ARROW") fell
	# 0.061 m off the lit panel onto the navy terminal body — black-on-near-black,
	# invisible. Nobody could see that while the legends were still mirrored. The
	# panel now spans y = 1.08 … 2.58 so the whole block reads on it. Legend
	# positions are unchanged, so the coordinates recorded in `bugs.md` still hold.
	_box(gallery, "RegistryScreen", terminal_position + Vector3(0, 0.38, -0.98), Vector3(3.8, 1.5, 0.06), _materials["cyan_glow"], false)
	# MAP-004. These four legends are the only diegetic regeneration interface in
	# the game and every one of them was reading backwards *into* `RegistryScreen`.
	# They are yawed 180 degrees for the reader standing on the deck at lower z.
	# Depth ordering was checked rather than assumed: `RegistryScreen` presents its
	# -Z face at z = 23.590, and the four legends occupy z = 23.558 … 23.574, so
	# they already stand 0.016-0.028 m proud of the panel. `TextMesh` extrudes
	# symmetrically about local z = 0, so the yaw leaves that clearance untouched
	# and moves the readable glyph face further towards the reader, not into the
	# panel.
	_text_sign(gallery, "SAY SHIP NAME", terminal_position + Vector3(0, 0.72, -1.03), Vector3(0.0, 180.0, 0.0), 0.34, _materials["black"])
	_text_sign(gallery, "TORRENT  JOVIAN  TITAN  VORTEX", terminal_position + Vector3(0, 0.25, -1.04), Vector3(0.0, 180.0, 0.0), 0.18, _materials["black"])
	_text_sign(gallery, "KATANA  PARADOX  PREDATOR  DYNAMIC", terminal_position + Vector3(0, -0.02, -1.04), Vector3(0.0, 180.0, 0.0), 0.14, _materials["black"])
	_text_sign(gallery, "UTOPIA  ARROW", terminal_position + Vector3(0, -0.27, -1.04), Vector3(0.0, 180.0, 0.0), 0.15, _materials["black"])
	_add_guide_light(gallery, terminal_position + Vector3(1.72, 0.95, -1.05), KETH_ORANGE, false, 1.4, 6.0)

	# Physical destination indicator for the active berth. It communicates the
	# modern slice workflow but makes no name-to-silhouette historical claim.
	_cylinder(gallery, "BerthIndicatorBase", Vector3(-38.5, 0.75, 27.6), 1.05, 1.4, _materials["steel_blue"], true)
	_torus(gallery, "BerthIndicatorRing", Vector3(-38.5, 1.52, 27.6), 0.72, 0.92, _materials["cyan_glow"])
	_box(gallery, "BerthIndicatorNeedle", Vector3(-38.5, 2.55, 27.6), Vector3(0.16, 2.1, 0.16), _materials["orange_glow"], false)
	# Recorded in `bugs.md` as an unconfirmed observation ("a sign with nothing
	# within 0.62 m") and confirmed here: at z = 26.90 this legend hung 0.62 m clear
	# of `BerthIndicatorNeedle` (z = 27.52 … 27.68), the mast it belongs to, and it
	# faced +Z — away from the deck, so it was mirrored as well as unmounted. It is
	# now a blade sign on the mast head, 0.018 m proud of the needle's -Z face and
	# yawed to the reader. Height and copy are unchanged.
	_text_sign(gallery, "ACTIVE BERTH  //  CENTRE SPINE", Vector3(-38.5, 3.35, 27.5), Vector3(0.0, 180.0, 0.0), 0.2, _materials["white_glow"])

	_build_regeneration_deck_life(gallery)


## What the regeneration deck is besides a terminal.
##
## `docs/research/STATION_TOPOLOGY.md` grades this pod `new` / `modern_interpretation`
## across the board: B2's registered anchor observes that an enclosed
## regeneration/control space existed, and nothing joins that observation to this
## pod, so nothing here is a reconstruction and nothing here may become one. What
## it *can* be is a place. Before this pass the deck held one terminal, one
## indicator mast and 96 m² of empty plate under an unsupported roof; a player
## walked in, read four legends off a screen and had no reason to look anywhere
## else, which is precisely the "reads as a box" complaint.
##
## The additions are all crew-side rather than authority-side, which is the line
## that matters: the pod holds no regeneration, lease, berth or spawn authority
## and this pass adds none. A dispatch board that mirrors the four registered
## berth slots is a *readout*, the bench and tool rack are furniture, the two
## risers are the terminal's own service run to the roof, and the floor marks are
## paint. Nothing here can reserve, regenerate or move a craft.
##
## Seating was measured, not assumed — every piece below either sits on the
## 0.38 m deck top, hangs off the 5.625 m roof underside, or shares volume with
## the 30.55 m back-wall face it is bolted to.
func _build_regeneration_deck_life(gallery: Node3D) -> void:
	# Berth dispatch board on the back wall, and one lit tile per registered
	# berth. Four tiles because the registry is four berths — the count is read
	# off `SHIP_BERTH_FEEDBACK_BERTH_IDS`, so a board that stops matching the
	# registry is a code change rather than a silent drift.
	_box(gallery, "RegistryDispatchBoard", Vector3(-43.0, 3.3, 30.48), Vector3(5.6, 1.7, 0.14), _materials["navy"], false)
	var tile_span := 4.2
	for tile_index in SHIP_BERTH_FEEDBACK_BERTH_IDS.size():
		var tile_ratio := (float(tile_index) + 0.5) / float(SHIP_BERTH_FEEDBACK_BERTH_IDS.size())
		_box(
			gallery,
			"RegistryBerthTile%02d" % (tile_index + 1),
			Vector3(-43.0 - tile_span * 0.5 + tile_span * tile_ratio, 3.5, 30.40),
			Vector3(0.86, 0.52, 0.08),
			_materials["cyan_glow"],
			false
		)
	# The reader stands on the deck at lower z and looks toward the back wall, so
	# this legend faces them with the same 180-degree yaw MAP-004 established for
	# every other approach-side legend in this file. Its glyph face sits at
	# z = 30.405 against a board face of z = 30.41, so it is lettering on a panel
	# rather than another sign hanging in air.
	_text_sign(gallery, "REGISTERED BERTHS", Vector3(-43.0, 4.05, 30.408), Vector3(0.0, 180.0, 0.0), 0.2, _materials["white_glow"])

	# The terminal's service run. Two risers from the terminal head into the roof
	# slab: bottom at y = 2.70 inside a terminal whose top is 2.80, top at y = 5.70
	# inside a roof whose underside is 5.625.
	for riser_x in [-45.0, -41.0]:
		_cylinder(gallery, "RegistryTerminalRiser", Vector3(riser_x, 4.2, 25.2), 0.11, 3.0, _materials["steel_blue"], false)
	# Overhead task light over the terminal, and the practical that makes it one.
	# An emissive housing lights nothing in Forward+ — the same mechanism the
	# station's fixture-practical pass recorded — so the housing carries a real
	# `OmniLight3D` under it rather than more emission energy.
	_box(gallery, "RegistryTaskLampHousing", Vector3(-43.0, 5.55, 24.9), Vector3(3.4, 0.2, 0.6), _materials["steel_blue"], false)
	_add_guide_light(gallery, Vector3(-43.0, 5.36, 24.9), Color("cfe6ee"), false, 1.5, 7.0)

	# Crew side of the room, against the back wall so it cannot be walked into
	# from behind. The bench is collidable because a bench a player walks through
	# is the same defect as a floating one seen from the other side; it stands on
	# the deck top at y = 0.38 and its far face meets the wall at z = 30.55.
	_box(gallery, "RegistryServiceBench", Vector3(-47.4, 0.805, 30.1), Vector3(2.4, 0.85, 0.9), _materials["deck_light"])
	_box(gallery, "RegistryToolRack", Vector3(-47.4, 2.15, 30.49), Vector3(1.8, 1.0, 0.12), _materials["navy"], false)
	_box(gallery, "RegistryPartsTray", Vector3(-47.9, 1.29, 30.1), Vector3(0.9, 0.12, 0.5), _materials["steel_blue"], false)
	_box(gallery, "RegistryStowedManifest", Vector3(-46.6, 1.255, 30.0), Vector3(0.32, 0.05, 0.24), _materials["ivory"], false)

	# Paint. Two approach stripes from the threshold to the terminal and one stand
	# mark in front of the screen, all lying on the collidable deck so the
	# discovery sweep can keep proving there is floor under them.
	for stripe_x in [-45.6, -40.4]:
		_box(gallery, "RegistryApproachStripe", Vector3(stripe_x, 0.385, 24.4), Vector3(0.22, 0.03, 2.6), _materials["orange"], false)
	_box(gallery, "RegistryStandMark", Vector3(-43.0, 0.385, 23.5), Vector3(1.1, 0.03, 0.9), _materials["orange"], false)


## Bounded renderer/collision audit for the ModernFleetRegistry pod.
##
## This deliberately stops at the pod root. It freezes the one batched family
## and the authority/readability nodes that batching must not absorb, without
## turning a module-local optimization into another whole-scene absolute count.
func get_modern_fleet_registry_render_contract() -> Dictionary:
	var registry := get_node_or_null(^"ModernFleetRegistry") as Node3D
	var mesh_nodes: Array[Node] = []
	var batch_nodes: Array[Node] = []
	var descendant_count := 0
	var drawn_copies := 0
	var submissions := 0
	var body_count := 0
	var shape_count := 0
	var light_count := 0
	var area_count := 0
	if registry != null:
		descendant_count = registry.find_children("*", "Node", true, false).size()
		mesh_nodes = registry.find_children("*", "MeshInstance3D", true, false)
		batch_nodes = registry.find_children("*", "MultiMeshInstance3D", true, false)
		body_count = registry.find_children("*", "PhysicsBody3D", true, false).size()
		shape_count = registry.find_children("*", "CollisionShape3D", true, false).size()
		light_count = registry.find_children("*", "Light3D", true, false).size()
		area_count = registry.find_children("*", "Area3D", true, false).size()
		for raw_node in mesh_nodes:
			var instance := raw_node as MeshInstance3D
			if instance.mesh == null:
				continue
			drawn_copies += 1
			submissions += instance.mesh.get_surface_count()
		for raw_node in batch_nodes:
			var batch := raw_node as MultiMeshInstance3D
			if batch.multimesh == null or batch.multimesh.mesh == null:
				continue
			var visible_copies := batch.multimesh.visible_instance_count
			if visible_copies < 0:
				visible_copies = batch.multimesh.instance_count
			drawn_copies += visible_copies
			submissions += batch.multimesh.mesh.get_surface_count()

	var renderer_buffer_matches := false
	var bounds_match := false
	var metadata_matches := false
	var mesh_identity_matches := false
	var material_identity_matches := false
	var batch_configuration_matches := false
	var renderer_buffer_floats := 0
	if is_instance_valid(_modern_registry_column_batch) \
			and _modern_registry_column_batch.multimesh != null \
			and _modern_registry_column_batch.multimesh.mesh != null:
		var multi := _modern_registry_column_batch.multimesh
		var expected_buffer := _encode_multimesh_transforms(
			_modern_registry_column_transforms
		)
		var expected_bounds := _transformed_mesh_bounds(
			multi.mesh.get_aabb(),
			_modern_registry_column_transforms
		)
		renderer_buffer_floats = multi.buffer.size()
		renderer_buffer_matches = multi.buffer == expected_buffer
		bounds_match = multi.custom_aabb.is_equal_approx(expected_bounds)
		mesh_identity_matches = multi.mesh == _rounded_box_mesh(MODERN_REGISTRY_COLUMN_SIZE)
		material_identity_matches = _modern_registry_column_batch.material_override == _materials.get("steel_blue")
		batch_configuration_matches = (
			_modern_registry_column_batch.get_parent() == registry
			and _modern_registry_column_batch.transform.is_equal_approx(Transform3D.IDENTITY)
			and _modern_registry_column_batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and _modern_registry_column_batch.layers == 1
			and _modern_registry_column_batch.material_overlay == null
			and _modern_registry_column_batch.get_child_count() == 0
			and _modern_registry_column_batch.get_script() == null
			and bool(_modern_registry_column_batch.get_meta("visual_detail_only", false))
			and multi.transform_format == MultiMesh.TRANSFORM_3D
			and multi.instance_count == MODERN_REGISTRY_COLUMN_COPY_COUNT
			and multi.visible_instance_count == -1
			and multi.mesh.get_surface_count() == 1
			and multi.mesh.get_aabb().size.is_equal_approx(MODERN_REGISTRY_COLUMN_SIZE)
		)
		var published := _modern_registry_column_batch.get_meta(
			"authored_instance_transforms", []
		) as Array
		metadata_matches = published.size() == _modern_registry_column_transforms.size()
		for index in mini(published.size(), _modern_registry_column_transforms.size()):
			metadata_matches = metadata_matches and (published[index] as Transform3D).is_equal_approx(
				_modern_registry_column_transforms[index]
			)

	var column_collision_matches := _modern_registry_column_bodies.size() \
		== MODERN_REGISTRY_COLUMN_COPY_COUNT
	for index in mini(_modern_registry_column_bodies.size(), _modern_registry_column_transforms.size()):
		var body := _modern_registry_column_bodies[index]
		var collision: CollisionShape3D = null
		if is_instance_valid(body):
			collision = body.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		column_collision_matches = (
			column_collision_matches
			and is_instance_valid(body)
			and body.get_parent() == registry
			and body.transform.is_equal_approx(_modern_registry_column_transforms[index])
			and body.collision_layer == WORLD_LAYER
			and body.collision_mask == 0
			and body.get_script() == null
			and body.get_child_count() == 1
			and body.find_children("*", "MeshInstance3D", true, false).is_empty()
			and shape != null
			and shape.size.is_equal_approx(MODERN_REGISTRY_COLUMN_SIZE)
		)
	if not _modern_registry_column_bodies.is_empty():
		column_collision_matches = column_collision_matches \
			and _modern_registry_column_bodies[0].name == &"RegistryPodColumn"

	var preserved_paths := [
		^"RegistryPodDeck",
		^"RegistryPodThreshold",
		^"FleetRegistryTerminal",
		^"RegistryScreen",
		^"BerthIndicatorBase",
		^"RegistryDispatchBoard",
		^"RegistryTaskLampHousing",
		^"RegistryToolRack",
		^"RegistryPartsTray",
		^"RegistryStowedManifest",
		^"Sign_FLEET_REGISTRY__--__MODERN_INTERFACE",
		^"Sign_SAY_SHIP_NAME",
		^"Sign_TORRENT__JOVIAN__TITAN__VORTEX",
		^"Sign_KATANA__PARADOX__PREDATOR__DYNAMIC",
		^"Sign_UTOPIA__ARROW",
		^"Sign_ACTIVE_BERTH__--__CENTRE_SPINE",
		^"Sign_REGISTERED_BERTHS",
	]
	var preserved_paths_match := registry != null
	if registry != null:
		for path: NodePath in preserved_paths:
			preserved_paths_match = preserved_paths_match and registry.get_node_or_null(path) != null
		for tile_index in SHIP_BERTH_FEEDBACK_BERTH_IDS.size():
			preserved_paths_match = preserved_paths_match and registry.get_node_or_null(
				NodePath("RegistryBerthTile%02d" % (tile_index + 1))
			) is MeshInstance3D

	var exact_counts := (
		descendant_count == MODERN_REGISTRY_RENDER_DESCENDANT_COUNT
		and mesh_nodes.size() == MODERN_REGISTRY_RENDER_MESH_INSTANCE_COUNT
		and batch_nodes.size() == MODERN_REGISTRY_RENDER_MULTIMESH_BATCH_COUNT
		and drawn_copies == MODERN_REGISTRY_RENDER_DRAWN_COPY_COUNT
		and submissions == MODERN_REGISTRY_RENDER_SUBMISSION_COUNT
		and body_count == MODERN_REGISTRY_PHYSICS_BODY_COUNT
		and shape_count == MODERN_REGISTRY_COLLISION_SHAPE_COUNT
		and light_count == MODERN_REGISTRY_LIGHT_COUNT
		and area_count == 0
	)
	var errors := PackedStringArray()
	if not exact_counts:
		errors.append("modern_registry_local_roster_changed")
	if not renderer_buffer_matches:
		errors.append("registry_column_renderer_buffer_changed")
	if not bounds_match:
		errors.append("registry_column_culling_bounds_changed")
	if not metadata_matches:
		errors.append("registry_column_authored_metadata_changed")
	if not mesh_identity_matches or not material_identity_matches:
		errors.append("registry_column_shared_resource_identity_changed")
	if not batch_configuration_matches:
		errors.append("registry_column_batch_configuration_changed")
	if not column_collision_matches:
		errors.append("registry_column_collision_roster_changed")
	if not preserved_paths_match:
		errors.append("registry_authority_or_readability_path_changed")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"descendant_nodes": descendant_count,
		"mesh_instances": mesh_nodes.size(),
		"multimesh_batches": batch_nodes.size(),
		"drawn_copies": drawn_copies,
		"geometry_submissions": submissions,
		"physics_bodies": body_count,
		"collision_shapes": shape_count,
		"lights": light_count,
		"areas": area_count,
		"column_visual_copies": _modern_registry_column_transforms.size(),
		"renderer_buffer_floats": renderer_buffer_floats,
		"renderer_buffer_matches_authored": renderer_buffer_matches,
		"bounds_match_authored": bounds_match,
		"metadata_matches_authored": metadata_matches,
		"mesh_identity_matches_cache": mesh_identity_matches,
		"material_identity_matches_shared_palette": material_identity_matches,
		"batch_configuration_matches": batch_configuration_matches,
		"column_collision_matches": column_collision_matches,
		"preserved_paths_match": preserved_paths_match,
		"exact_counts": exact_counts,
		"registry_parent_is_world": registry != null and registry.get_parent() == self,
		"registry_transform_identity": registry != null and registry.transform.is_equal_approx(Transform3D.IDENTITY),
		"process_free": registry != null and not registry.is_processing() and not registry.is_physics_processing(),
		"authored_column_transforms": _modern_registry_column_transforms.duplicate(),
	}.duplicate(true)


func _build_provisional_fleet() -> void:
	# Several physically parked craft around separate nodes are source-supported;
	# every silhouette below is an original modern blockout with no historic name
	# assignment. Static collision keeps the ships tangible while their berths and
	# the hero launch corridor remain clear.
	var fleet := Node3D.new()
	fleet.name = "ProvisionalParkedFleet"
	add_child(fleet)
	_fleet_expansion_production_binding = FLEET_EXPANSION_BINDING.new()
	_fleet_expansion_production_binding.name = "FleetExpansionProductionBinding"
	_fleet_expansion_production_binding.transform = Transform3D(
		Basis(Vector3.UP, PI * 0.5),
		Vector3(12.0, 4.2, 68.3)
	)
	add_child(_fleet_expansion_production_binding)
	# The port node is now a second live berth. Its former static courier concept
	# is intentionally omitted so a real flyable test article occupies the space.
	# The former starboard gunship placeholder is deliberately absent: this node
	# now forms the real, player-clear connector into HabitatSpine. The deck,
	# rails, and separate Dock Operations pod remain unchanged.
	# The previous aft shuttle placeholder occupied the route now used by the
	# physical Aft Junction Stack, so it is deliberately removed rather than
	# being presented inside authored circulation geometry.


func _build_static_fleet_silhouette(
		parent: Node3D,
		craft_name: String,
		craft_position: Vector3,
		craft_rotation_degrees: Vector3,
		variant: int,
		accent_key: String
	) -> void:
	var craft := StaticBody3D.new()
	craft.name = craft_name
	craft.position = craft_position
	craft.rotation_degrees = craft_rotation_degrees
	craft.collision_layer = WORLD_LAYER
	craft.collision_mask = 0
	craft.set_meta("provisional_static_fleet_concept", true)
	parent.add_child(craft)

	var collision_size := Vector3.ZERO
	match variant:
		0:
			# Long, narrow courier concept with a single axial engine.
			_box(craft, "CourierKeel", Vector3(0, 1.2, 0), Vector3(2.4, 0.95, 9.8), _materials["ivory"], false)
			_box(craft, "CourierUnderside", Vector3(0, 0.72, 0.7), Vector3(2.8, 0.4, 7.6), _materials["steel_blue"], false)
			for side in [-1.0, 1.0]:
				_box(craft, "CourierWing", Vector3(side * 1.9, 1.02, 1.1), Vector3(3.4, 0.24, 3.2), _materials["ivory"], false, Vector3(0, side * -23.0, 0))
				_box(craft, "CourierTip", Vector3(side * 3.25, 1.2, 2.0), Vector3(0.3, 0.72, 2.2), _materials[accent_key], false)
			_cylinder(craft, "CourierEngine", Vector3(0, 0.88, 4.25), 0.72, 2.0, _materials["steel_blue"], false, Vector3(90, 0, 0))
			_cylinder(craft, "CourierEngineGlow", Vector3(0, 0.88, 5.3), 0.41, 0.22, _materials["cyan_glow"], false, Vector3(90, 0, 0))
			_box(craft, "CourierCanopy", Vector3(0, 1.9, -1.4), Vector3(1.45, 0.62, 2.7), _materials["glass"], false, Vector3(-10, 0, 0))
			collision_size = Vector3(7.4, 2.4, 10.2)
		1:
			# Broad gunship concept with separated engine shoulders and gun booms.
			_box(craft, "GunshipCore", Vector3(0, 1.45, 0), Vector3(4.4, 1.2, 8.2), _materials["ivory"], false)
			_box(craft, "GunshipUnderside", Vector3(0, 0.75, 0.6), Vector3(5.0, 0.48, 6.8), _materials["steel_blue"], false)
			for side in [-1.0, 1.0]:
				_box(craft, "GunshipShoulder", Vector3(side * 3.35, 1.28, 0.8), Vector3(5.1, 0.44, 4.8), _materials["ivory"], false, Vector3(0, side * -15.0, 0))
				_box(craft, "GunshipBoom", Vector3(side * 4.85, 0.94, -2.0), Vector3(0.42, 0.42, 4.6), _materials["steel_blue"], false)
				_cylinder(craft, "GunshipEngine", Vector3(side * 2.0, 1.0, 3.65), 0.74, 2.35, _materials["steel_blue"], false, Vector3(90, 0, 0))
				_cylinder(craft, "GunshipEngineGlow", Vector3(side * 2.0, 1.0, 4.86), 0.42, 0.24, _materials["cyan_glow"], false, Vector3(90, 0, 0))
			_box(craft, "GunshipCanopy", Vector3(0, 2.42, -1.05), Vector3(2.2, 0.82, 2.8), _materials["glass"], false, Vector3(-8, 0, 0))
			_box(craft, "GunshipAccent", Vector3(0, 2.12, 1.55), Vector3(0.5, 0.16, 2.6), _materials[accent_key], false)
			collision_size = Vector3(11.0, 3.0, 8.8)
		_:
			# Compact twin-cabin shuttle concept with a short, blunt planform.
			_box(craft, "ShuttleCore", Vector3(0, 1.3, 0.2), Vector3(5.0, 1.35, 6.3), _materials["ivory"], false)
			_box(craft, "ShuttleBelly", Vector3(0, 0.58, 0.6), Vector3(5.5, 0.46, 5.4), _materials["steel_blue"], false)
			for side in [-1.0, 1.0]:
				_box(craft, "ShuttleCabin", Vector3(side * 2.7, 1.42, -0.35), Vector3(2.2, 1.25, 4.9), _materials["ivory"], false)
				_box(craft, "ShuttleWindowBand", Vector3(side * 2.7, 1.75, -1.05), Vector3(2.24, 0.36, 2.6), _materials["glass"], false)
				_cylinder(craft, "ShuttleEngine", Vector3(side * 2.35, 0.78, 3.25), 0.58, 1.55, _materials["steel_blue"], false, Vector3(90, 0, 0))
				_cylinder(craft, "ShuttleEngineGlow", Vector3(side * 2.35, 0.78, 4.06), 0.34, 0.2, _materials["cyan_glow"], false, Vector3(90, 0, 0))
			_box(craft, "ShuttleAccent", Vector3(0, 2.03, 0.7), Vector3(4.5, 0.18, 0.48), _materials[accent_key], false)
			collision_size = Vector3(8.0, 2.8, 7.0)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "ProvisionalCraftCollision"
	var collision_box := BoxShape3D.new()
	collision_box.size = collision_size
	collision_shape.position = Vector3(0, collision_size.y * 0.48, 0)
	collision_shape.shape = collision_box
	craft.add_child(collision_shape)

	# World label states epistemic status instead of assigning a classic name.
	_text_sign(craft, "STATIC CONCEPT  //  MODEL UNVERIFIED", Vector3(0, 3.9, 1.8), Vector3.ZERO, 0.18, _materials["orange_glow"])


func _build_industrial_details() -> void:
	var infrastructure := Node3D.new()
	infrastructure.name = "IndustrialInfrastructure"
	add_child(infrastructure)

	# Short colour-coded utility runs cling to the central and branch keels. They
	# add modern operational detail without recreating the deleted bay walls.
	for side in [-1.0, 1.0]:
		for pipe_index in 3:
			var x_position: float = float(side) * (2.15 + float(pipe_index) * 0.36)
			var y_position: float = -1.35 - float(pipe_index) * 0.24
			var pipe_material: Material = _materials["orange"] if pipe_index == 1 else _materials["cyan_glow"]
			_cylinder(
				infrastructure,
				"UtilityPipe",
				Vector3(x_position, y_position, 3.0),
				0.18 + pipe_index * 0.03,
				72.0,
				pipe_material,
				false,
				Vector3(90, 0, 0)
			)
			for z_position in range(-30, 38, 8):
				_cylinder(
					infrastructure,
					"PipeCoupler",
					Vector3(x_position, y_position, float(z_position)),
					0.32 + pipe_index * 0.04,
					0.35,
					_materials["ivory"],
					false,
					Vector3(90, 0, 0)
				)

	# The old aft jib and exchanger blockout was removed when the authored Aft
	# Junction Stack took ownership of this volume.


func _build_cargo_and_machinery() -> void:
	var props := Node3D.new()
	props.name = "CargoAndMachinery"
	add_child(props)

	# The former Cargo00/Cargo01 cluster occupied the Dock Operations pod at
	# x=42.5..46.0, z=27.5. It was global dressing built after the room, which is
	# why room-local clearance checks missed the large blocks entirely. The pod's
	# purpose-built dispatch furniture now supplies that visual role, so the stale
	# cargo cluster is removed rather than relocated onto another player route.

	# Refuelling cabinets and a tiny tow tractor suggest active dock operations.
	for z_position in [12.8, 18.1]:
		_box(props, "ServiceCabinet", Vector3(36.8, 1.5, z_position), Vector3(2.3, 3.0, 2.0), _materials["ivory"])
		_box(props, "CabinetFace", Vector3(35.6, 1.5, z_position), Vector3(0.08, 2.3, 1.5), _materials["navy"], false)
		for y_position in [1.1, 1.7, 2.3]:
			_box(props, "StatusLine", Vector3(35.52, y_position, z_position), Vector3(0.04, 0.12, 1.0), _materials["cyan_glow"], false)

	# The tow tractor is no longer three static boxes and four cylinders: it is a
	# real drivable vehicle that owns its own geometry, collision and handling.
	# It keeps the prop's authored parking spot and heading (long axis along +X,
	# cab toward +X) and is deliberately parked clear of the player spawn, the
	# hero berth and the disembark point, exactly as the prop was. It is a world
	# prop, not fleet: it holds no berth, lease, landing or combat authority.
	var tow_tractor := TOW_TRACTOR_SCENE.instantiate() as TowTractor
	tow_tractor.name = "TowTractor"
	# Parked a little above the deck so it settles onto whatever the deck's
	# finished height actually is, instead of freezing one today.
	#
	# Moved inboard along the same lattice deck from the prop's (7.0, 18.0). Two
	# measured reasons, both of which only matter once the thing moves: the prop's
	# 2.3 m body was centred on z = 18.0 and so interpenetrated the guard rail at
	# z = 19.0, wedging a vehicle against the rail stanchions inside its first
	# metre of travel; and it stood hard against a lattice column, which put an
	# unbroken black mast between the chase camera and the tractor for the whole
	# first second of driving. This spot is the nearest one to the player spawn
	# with a clear 4.6 x 2.4 x 4.6 volume and continuous deck for six metres in
	# every direction, and it is 11 m from the spawn — closer to the "right where
	# you spawn" the prop was meant to read as, and still far outside the player's
	# 2.35 m interaction reach, so it cannot take the first prompt they see.
	tow_tractor.position = Vector3(2.5, 0.45, 15.6)
	tow_tractor.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	props.add_child(tow_tractor)

	# Freestanding safety pylons visually protect both pad approaches.
	for z_position in [-27.5, 8.5]:
		for x_position in [-13.8, 13.8]:
			_box(props, "SafetyPylon", Vector3(x_position, 0.9, z_position), Vector3(0.8, 1.8, 0.8), _materials["orange"])
			_add_guide_light(props, Vector3(x_position, 1.95, z_position), ALERT_RED, true)


func _build_exterior_range() -> void:
	var exterior := Node3D.new()
	exterior.name = "ExteriorTargetRange"
	add_child(exterior)

	# Range signal and lightweight truss indicate a playable destination beyond
	# the dock instead of treating the nebula as a decorative dead end.
	for side in [-1.0, 1.0]:
		_box(exterior, "RangeTruss", Vector3(side * 31.0, 9.0, -104), Vector3(1.0, 1.0, 32), _materials["steel_blue"])
		for z_position in [-91.0, -102.0, -113.0]:
			_add_guide_light(exterior, Vector3(side * 31.0, 9.8, z_position), KETH_CYAN, true)
	_box(exterior, "RangeHeader", Vector3(0, 9.0, -120), Vector3(63, 1.0, 1.0), _materials["steel_blue"])
	_text_sign(
		exterior,
		"MUDDS FLIGHT TEST RANGE",
		Vector3(0, 10.3, -119.4),
		Vector3.ZERO,
		0.68,
		_materials["cyan_glow"]
	)
	_build_range_gate_clearance_cue(exterior)

	var target_positions := [
		Vector3(-13.0, 7.0, -95.0),
		Vector3(14.0, 11.0, -116.0),
		Vector3(-2.0, 1.5, -142.0),
		Vector3(22.0, -4.0, -165.0),
	]
	for index in target_positions.size():
		_create_target(exterior, index + 1, target_positions[index])

	# A distant maintenance beacon and antenna give scale to free flight.
	_cylinder(exterior, "BeaconMast", Vector3(-48, 0, -145), 1.1, 26, _materials["steel_blue"])
	_torus(exterior, "BeaconRing", Vector3(-48, 9, -145), 4.5, 4.85, _materials["orange_glow"], Vector3(90, 0, 0))
	_add_guide_light(exterior, Vector3(-48, 13.4, -145), ALERT_RED, true, 8.0, 38.0)


## Makes the range gate's header beam read as an obstacle from the launch gate,
## and says where the clear lane is.
##
## The measurements this exists for are on `OUTBOUND_CLEARANCE_CEILING` above. In
## short: the beam blocks a 5.4 m band of outbound altitude for a Torrent and a
## 6.8 m band for a Jovian, and before this pass it carried nothing at all — the
## gate's only lamps were six on the trusses, 31 m off the centreline and *above*
## the beam, which if anything reads as "the gap is under the lamps" while
## actually being level with the thing that stops you.
##
## Everything here is presentation on the beam's own faces. Nothing collides,
## nothing is added away from the beam, and the header, the trusses, the four
## drones and the range sign are all exactly where they were: the map is right
## and this pass does not touch it. The two cues are deliberately different
## channels — a lit line and a repeated shape — so the gate still reads with the
## colour taken out of it.
func _build_range_gate_clearance_cue(exterior: Node3D) -> void:
	# Every piece below lives on the beam's own station-facing face or is sunk into
	# its underside, and every one is checked against the beam's 8.5 .. 9.5 m band
	# by the regression. That constraint is not decoration: a cue hung *under* the
	# beam would be drawn geometry inside the very aperture it advertises, and a
	# craft flying the top of the clear lane would pass straight through it — the
	# same floating/ghost-geometry class the player has already reported twice.
	var header_face_z := -119.42
	var header_under_y := 8.5

	# One continuous lit line along the face. This is the element that carries at
	# range: 63 m of emissive edge resolves as a drawn horizontal at the distance
	# where a 1 m unlit bar against vacuum is nothing at all.
	_box(
		exterior,
		"RangeHeaderClearanceStripe",
		Vector3(0.0, 9.36, header_face_z),
		Vector3(62.6, 0.2, 0.1),
		_materials["orange_glow"],
		false
	)

	# The legend, centred on the face under the stripe. Redundant with the chevrons
	# on purpose; it is the cue that still works once the pilot is close enough to
	# read it and slow enough for words to help.
	#
	# `+0.02`, toward the station, and not `-0.09`: the beam's station-facing face
	# is at z = -119.5 and z runs *away* from the station, so the first version of
	# this line put the legend 0.04 m inside the girder. Nothing in the audit could
	# see that — the sign existed, it was in the right y band, it was not a
	# collider — and the rendered close-up is what showed the beam face with no
	# legend on it at all.
	_text_sign(
		exterior,
		"CLEARANCE BELOW",
		Vector3(0.0, 8.95, header_face_z + 0.02),
		Vector3.ZERO,
		0.4,
		_materials["orange_glow"]
	)

	for index in RANGE_HEADER_CUE_X.size():
		var x_position := RANGE_HEADER_CUE_X[index]
		# Downward chevrons flanking the legend: the aperture is below this line.
		# Shape, not colour, is what this cue is — it is the channel that survives a
		# fully desaturated frame, and it points at the only line the whole fleet
		# can fly. The centre position is left to the legend.
		if not is_zero_approx(x_position):
			for side in [-1.0, 1.0]:
				var arm := _box(
					exterior,
					"RangeHeaderClearanceChevron%02d%s" % [index, "Port" if side < 0.0 else "Starboard"],
					Vector3(x_position + side * 0.52, 8.92, header_face_z),
					Vector3(1.2, 0.14, 0.1),
					_materials["cyan_glow"],
					false
				)
				arm.rotation_degrees = Vector3(0.0, 0.0, side * 26.0)
		# Pulsing red obstruction lamps sunk into the underside, the same cue the
		# launch corridor's signal masts and the deck safety pylons use for "solid
		# thing here". Short range and low energy: these exist to be seen, not to
		# light anything, and the gate is 120 m from the nearest lit surface.
		_add_guide_light(
			exterior,
			Vector3(x_position, header_under_y - 0.02, header_face_z - 0.5),
			ALERT_RED,
			true,
			2.6,
			9.0
		)
func _build_space_backdrop() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "SpaceBackdrop"
	backdrop.set_meta(&"presentation_only", true)
	backdrop.set_meta(&"gameplay_authority", false)
	add_child(backdrop)

	# One deterministic instanced shell supplies the dense star identity without
	# per-star nodes, processing, collision, lights, or camera-relative updates.
	var star_mesh := SphereMesh.new()
	# A base 0.9 m radius yields roughly one default-window pixel for the mean
	# scale at shell distance, so TAA does not erase the entire identity cue.
	star_mesh.radius = 0.9
	star_mesh.height = 1.8
	star_mesh.radial_segments = 6
	star_mesh.rings = 3
	var star_material := _material(
		Color("e7edf2"), 0.0, 1.0, Color("e7edf2"), 0.55
	)
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.vertex_color_use_as_albedo = true
	star_material.disable_receive_shadows = true
	# The depth fog that separates the station's far field is a local dock
	# atmosphere, and this shell sits 1.45 kilometres out. Without this the fog
	# reaches full density long before the stars and dissolves the entire star
	# identity into haze - the cue that was added to make the station read as
	# large would have erased the backdrop it is read against.
	star_material.disable_fog = true
	star_mesh.material = star_material
	var stars := MultiMeshInstance3D.new()
	stars.name = "ParallaxStars"
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stars.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	stars.custom_aabb = AABB(
		Vector3.ONE * -SPACE_BACKDROP_STAR_RADIUS_MAX,
		Vector3.ONE * SPACE_BACKDROP_STAR_RADIUS_MAX * 2.0
	)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = star_mesh
	multimesh.instance_count = SPACE_BACKDROP_STAR_COUNT
	var random := RandomNumberGenerator.new()
	random.seed = SPACE_BACKDROP_STAR_SEED
	for index in multimesh.instance_count:
		var y := random.randf_range(-1.0, 1.0)
		var longitude := random.randf_range(-PI, PI)
		var planar_radius := sqrt(maxf(0.0, 1.0 - y * y))
		var direction := Vector3(
			planar_radius * cos(longitude),
			y,
			planar_radius * sin(longitude)
		)
		var radius := random.randf_range(
			SPACE_BACKDROP_STAR_RADIUS_MIN,
			SPACE_BACKDROP_STAR_RADIUS_MAX
		)
		var scale_value := random.randf_range(0.55, 2.35)
		multimesh.set_instance_transform(
			index,
			Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), direction * radius)
		)
		var warmth := random.randf()
		multimesh.set_instance_color(
			index,
			Color("fff1df").lerp(Color("dceaff"), warmth) * random.randf_range(0.52, 1.0)
		)
	stars.multimesh = multimesh
	backdrop.add_child(stars)

	# The four bodies retain distinct nodes and materials, but their immutable
	# 24x12 unit-sphere topology is one shared resource. Uniform node scale carries
	# each authored radius without changing a world vertex, normal or silhouette.
	var body_mesh := SphereMesh.new()
	body_mesh.radius = SPACE_BACKDROP_BODY_MESH_RADIUS
	body_mesh.height = SPACE_BACKDROP_BODY_MESH_RADIUS * 2.0
	body_mesh.radial_segments = SPACE_BACKDROP_BODY_MESH_RADIAL_SEGMENTS
	body_mesh.rings = SPACE_BACKDROP_BODY_MESH_RINGS
	for body_name: StringName in SPACE_BACKDROP_BODY_SPECS:
		var spec := SPACE_BACKDROP_BODY_SPECS[body_name] as Dictionary
		var body_color := spec.color as Color
		# Emission re-frozen from 0.32 to 0.04. The four bodies are lit by the same
		# key light as the station, but at 0.32 the self-emission was bright enough
		# to fill the unlit half back in, so each one rendered as a flat saturated
		# disc with a barely visible terminator - four coloured circles pasted on
		# the backdrop, and the most toy-like objects left in any wide frame. At
		# 0.04 the emission is a night-side floor rather than a fill, the terminator
		# resolves, and a body reads as a sphere with a lit limb whose bright side
		# agrees with the direction everything else on screen is lit from. The
		# colours and placements remain source-bounded; the radii are deliberately
		# reduced to keep a low-poly facet from becoming a screen-sized white/orange
		# flare when it crosses the station sightline.
		var body_material := _material(body_color, 0.0, 1.0, body_color, 0.04)
		body_material.disable_receive_shadows = true
		# The bodies deliberately stay *in* the depth fog, unlike the star shell.
		# Exempting them was tried and reverted: unfogged and lit by the raised key
		# they came back as vivid, fully saturated green and orange billiard balls,
		# which is a worse toy tell than the flat discs the emission change was
		# fixing. Aerial perspective is doing the right thing to them - a body a
		# kilometre out should read muted and far, and the haze is the only thing
		# on hand that says so about an untextured sphere.
		var body := MeshInstance3D.new()
		body.name = String(body_name)
		body.position = spec.position as Vector3
		body.scale = Vector3.ONE * float(spec.radius)
		body.mesh = body_mesh
		body.material_override = body_material
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		body.set_meta(&"palette_role", spec.palette_role)
		body.set_meta(&"visual_resource_family_id", SPACE_BACKDROP_BODY_MESH_FAMILY_ID)
		backdrop.add_child(body)


func _create_target(parent: Node3D, index: int, target_position: Vector3) -> void:
	var target := StaticBody3D.new()
	target.name = "TargetDrone%02d" % index
	target.position = target_position
	target.collision_layer = TARGET_LAYER
	target.collision_mask = 0
	target.set_meta("is_shipyard_target", true)
	target.set_meta("target_id", StringName("DRONE-%02d" % index))
	target.set_meta("health", target_health)
	target.set_meta("destroyed", false)
	target.set_meta("base_position", target_position)
	target.set_meta("phase", float(index) * 1.43)
	target.add_to_group("shipyard_targets")
	parent.add_child(target)

	var collision_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 2.35
	collision_shape.shape = sphere_shape
	target.add_child(collision_shape)

	var visual := Node3D.new()
	visual.name = "DroneVisual"
	target.add_child(visual)
	_add_exterior_target_core(visual)
	_torus(visual, "OuterRing", Vector3.ZERO, 2.25, 2.55, _materials["ivory"], Vector3(90, 0, 0))
	_torus(visual, "InnerRing", Vector3.ZERO, 1.75, 1.93, _materials["cyan_glow"], Vector3(0, 0, 90))
	for angle in [0.0, 90.0, 180.0, 270.0]:
		var radians := deg_to_rad(angle)
		var arm_position := Vector3(cos(radians) * 2.6, sin(radians) * 2.6, 0)
		_box(visual, "TargetArm", arm_position, Vector3(1.65, 0.36, 0.42), _materials["steel_blue"], false, Vector3(0, 0, angle))
		_sphere(
			visual, "TargetLamp", arm_position * 1.22,
			EXTERIOR_TARGET_LAMP_RADIUS, _materials["red_glow"], false,
			_shared_exterior_target_lamp_mesh()
		)
	_targets.append(target)


func _add_exterior_target_core(visual: Node3D) -> void:
	var core := MeshInstance3D.new()
	core.name = "Core"
	core.mesh = _shared_exterior_target_core_mesh()
	core.material_override = _materials["orange_glow"]
	visual.add_child(core)


func _shared_exterior_target_core_mesh() -> SphereMesh:
	if not is_instance_valid(_exterior_target_core_mesh):
		_exterior_target_core_mesh = SphereMesh.new()
		_exterior_target_core_mesh.radius = EXTERIOR_TARGET_CORE_RADIUS
		_exterior_target_core_mesh.height = EXTERIOR_TARGET_CORE_HEIGHT
		_exterior_target_core_mesh.radial_segments = EXTERIOR_TARGET_CORE_RADIAL_SEGMENTS
		_exterior_target_core_mesh.rings = EXTERIOR_TARGET_CORE_RINGS
	return _exterior_target_core_mesh


func _shared_exterior_target_lamp_mesh() -> SphereMesh:
	if not is_instance_valid(_exterior_target_lamp_mesh):
		_exterior_target_lamp_mesh = SphereMesh.new()
		_exterior_target_lamp_mesh.radius = EXTERIOR_TARGET_LAMP_RADIUS
		_exterior_target_lamp_mesh.height = EXTERIOR_TARGET_LAMP_HEIGHT
		_exterior_target_lamp_mesh.radial_segments = EXTERIOR_TARGET_LAMP_RADIAL_SEGMENTS
		_exterior_target_lamp_mesh.rings = EXTERIOR_TARGET_LAMP_RINGS
	return _exterior_target_lamp_mesh


func _destroy_target(
		target: StaticBody3D,
		target_id: StringName,
		hit_position: Vector3
	) -> void:
	authorize_target_destruction(target, target_id, hit_position)
	present_authorized_target_destruction(target, hit_position)


## Commits the target's gameplay authority synchronously. The visible burst and
## collapse may be receipt-delayed, but collision, mission count, and the
## one-shot target signal must be final as soon as authoritative damage lands.
func authorize_target_destruction(
		target: StaticBody3D,
		target_id: StringName,
		hit_position: Vector3
	) -> bool:
	if not is_instance_valid(target) or bool(target.get_meta("destruction_authority_committed", false)):
		return false
	target.set_meta("destroyed", true)
	target.set_meta("destruction_authority_committed", true)
	_destroyed_target_count += 1
	target.collision_layer = 0
	target.collision_mask = 0
	for child in target.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
	target_destroyed.emit(target_id, hit_position)
	return true


## Releases only the already-authorized target presentation at pulse arrival.
func present_authorized_target_destruction(
		target: StaticBody3D,
		_hit_position: Vector3
	) -> void:
	if not is_instance_valid(target) or bool(target.get_meta("destruction_visual_committed", false)):
		return
	target.set_meta("destruction_visual_committed", true)
	_spawn_target_burst(target.global_position)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	# Never collapse a PhysicsBody3D transform to a singular basis. Tween only
	# the visual child so the disabled collision remains mathematically valid.
	var target_visual := target.get_node_or_null("DroneVisual") as Node3D
	if target_visual != null:
		tween.tween_property(target_visual, "scale", Vector3.ZERO, 0.34)
	tween.tween_property(target, "rotation", target.rotation + Vector3(0.8, 1.5, 1.1), 0.34)
	tween.chain().tween_callback(target.queue_free)


func _spawn_impact(world_position: Vector3, color: Color) -> void:
	var impact_material := _material(color, 0.0, 0.3, color, 6.0)
	var impact := _sphere(self, "ProjectileImpact", world_position, 0.16, impact_material, false)
	impact.top_level = true
	impact.global_position = world_position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(impact, "scale", Vector3.ONE * 4.0, 0.18)
	tween.tween_property(impact, "rotation", Vector3(0.5, 1.2, 0.8), 0.18)
	tween.chain().tween_callback(impact.queue_free)


func _spawn_target_burst(world_position: Vector3) -> void:
	var burst := Node3D.new()
	burst.name = "TargetBurst"
	add_child(burst)
	burst.top_level = true
	burst.global_position = world_position
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var vertical := sin(float(index) * 2.17) * 0.75
		var direction := Vector3(cos(angle), vertical, sin(angle)).normalized()
		var material: Material = _materials["orange_glow"] if index % 2 == 0 else _materials["cyan_glow"]
		var fragment := _box(
			burst,
			"Fragment",
			direction * 0.25,
			Vector3(0.22, 0.22, 0.65),
			material,
			false,
			direction * 50.0
		)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(fragment, "position", direction * 5.5, 0.48)
		tween.tween_property(fragment, "scale", Vector3.ZERO, 0.48)
	var cleanup := get_tree().create_timer(0.55)
	cleanup.timeout.connect(burst.queue_free)


func _animate_crane() -> void:
	if is_instance_valid(_crane_trolley):
		_crane_trolley.rotation.y = sin(_elapsed * 0.19) * 0.42
	if is_instance_valid(_crane_hook):
		_crane_hook.rotation.z = sin(_elapsed * 0.72) * 0.025
		_crane_hook.rotation.x = cos(_elapsed * 0.51) * 0.018


func _animate_warning_lights() -> void:
	for light in _warning_lights:
		if is_instance_valid(light):
			var phase := float(light.get_meta("pulse_phase", 0.0))
			var base_energy := float(light.get_meta("base_energy", 4.0))
			light.light_energy = base_energy * (0.35 + 0.65 * maxf(0.0, sin(_elapsed * 3.8 + phase)))


func _animate_targets() -> void:
	for index in _targets.size():
		var target := _targets[index]
		if not is_instance_valid(target) or target.get_meta("destroyed", false):
			continue
		var base_position: Vector3 = target.get_meta("base_position", target.position)
		var phase := float(target.get_meta("phase", 0.0))
		target.position = base_position + Vector3(
			sin(_elapsed * 0.41 + phase) * 1.35,
			sin(_elapsed * 0.72 + phase) * 1.1,
			cos(_elapsed * 0.33 + phase) * 0.8
		)
		target.rotation.y += 0.34 * get_process_delta_time()
		target.rotation.z = sin(_elapsed * 0.6 + phase) * 0.13


func _add_guide_light(
	parent: Node3D,
	light_position: Vector3,
	color: Color,
	pulsing: bool,
	energy: float = 1.7,
	range_value: float = 7.0
) -> void:
	# Stable per-light paths remain local to their authored parents. Rendering is
	# finalized once all lights exist, in one batch per immutable color recipe.
	var lens := Marker3D.new()
	lens.name = "GuideLens"
	lens.position = light_position
	lens.set_meta("guide_lens_color", color)
	lens.set_meta("batched_visual_anchor", true)
	parent.add_child(lens)
	_guide_lens_nodes.append(lens)
	var light := OmniLight3D.new()
	light.name = "GuideLight"
	light.position = light_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	parent.add_child(light)
	_guide_light_nodes.append(light)
	if pulsing:
		light.set_meta("pulse_phase", float(_warning_lights.size()) * 0.83)
		light.set_meta("base_energy", energy)
		_warning_lights.append(light)


func _finalize_guide_lens_batches() -> void:
	if not _guide_lens_batches.is_empty():
		return
	var batch_names := {
		KETH_CYAN.to_html(true): "GuideLensBatchCyan",
		KETH_ORANGE.to_html(true): "GuideLensBatchOrange",
		ALERT_RED.to_html(true): "GuideLensBatchRed",
		Color("cfe6ee").to_html(true): "GuideLensBatchNeutral",
	}
	for color_variant in batch_names:
		var color_key := str(color_variant)
		var color := Color(color_key)
		var transforms: Array[Transform3D] = []
		for lens in _guide_lens_nodes:
			var lens_color := lens.get_meta("guide_lens_color", Color.TRANSPARENT) as Color
			if lens_color.to_html(true) == color_key:
				transforms.append(_transform_relative_to(self, lens))
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _shared_guide_lens_mesh()
		multi.instance_count = transforms.size()
		multi.visible_instance_count = -1
		multi.buffer = _encode_multimesh_transforms(transforms)
		multi.custom_aabb = _transformed_mesh_bounds(multi.mesh.get_aabb(), transforms)
		var batch := MultiMeshInstance3D.new()
		batch.name = str(batch_names[color_variant])
		batch.multimesh = multi
		batch.material_override = _shared_guide_lens_material(color)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		batch.set_meta("guide_lens_batch", true)
		batch.set_meta("guide_lens_color", color)
		batch.set_meta("authored_instance_transforms", transforms.duplicate())
		add_child(batch)
		_guide_lens_batches[color_key] = batch


static func _transform_relative_to(ancestor: Node3D, node: Node3D) -> Transform3D:
	var result := node.transform
	var cursor := node.get_parent()
	while cursor != null and cursor != ancestor:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result if cursor == ancestor else Transform3D.IDENTITY


func _shared_guide_lens_mesh() -> SphereMesh:
	if not is_instance_valid(_guide_lens_mesh):
		_guide_lens_mesh = SphereMesh.new()
		_guide_lens_mesh.radius = GUIDE_LENS_RADIUS
		_guide_lens_mesh.height = GUIDE_LENS_HEIGHT
		_guide_lens_mesh.radial_segments = GUIDE_LENS_RADIAL_SEGMENTS
		_guide_lens_mesh.rings = GUIDE_LENS_RINGS
	return _guide_lens_mesh


func _shared_guide_lens_material(color: Color) -> StandardMaterial3D:
	if not _guide_lens_material_cache.has(color):
		_guide_lens_material_cache[color] = _material(color, 0.0, 0.25, color, 1.35)
	return _guide_lens_material_cache[color] as StandardMaterial3D


func _material(
	color: Color,
	metallic: float = 0.0,
	roughness: float = 0.65,
	emission_color: Color = Color.TRANSPARENT,
	emission_energy: float = 0.0
) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	# The four station modules already shade per pixel with Burley diffuse and
	# Schlick-GGX specular; the hub was still on the engine defaults, so the same
	# grey under the same light answered differently on either side of a module
	# seam. `CentralBerthHeroPresentation` sets exactly this trio.
	result.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	result.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
	return result


## Painted metal: a dielectric base under a thin gloss layer.
##
## The hub had no way to say "painted" that was distinct from "made of paint".
## Every painted role was a plain dielectric with a middling roughness, which
## gives one broad diffuse-plus-soft-highlight response — and that response is
## indistinguishable from moulded plastic, which is precisely the read the whole
## pass is trying to break. Paint over metal has *two* specular lobes: a broad
## dull one from the pigment layer and a tight bright one from the clear coat on
## top. Clearcoat supplies the second lobe, so a painted railing catches a sharp
## line of the key light along its edge while its face stays matte, and a
## bare-steel brace beside it answers with a single wide highlight instead. That
## difference is what separates two surfaces that are the same brightness.
##
## The base roughness is also dropped relative to the old painted roles. A high
## base roughness under a clear coat reads as chalked, weathered paint; these are
## maintained station surfaces.
func _painted_material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := _material(color, 0.02, roughness)
	result.clearcoat_enabled = true
	result.clearcoat = 0.45
	result.clearcoat_roughness = 0.12
	return result


func _transparent_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result := _material(color, metallic, roughness)
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return result


func _box(
	parent: Node3D,
	node_name: String,
	box_position: Vector3,
	size: Vector3,
	material: Material,
	collidable: bool = true,
	box_rotation_degrees: Vector3 = Vector3.ZERO
) -> Node3D:
	var container: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		container = body
	else:
		container = MeshInstance3D.new()
	container.name = node_name
	container.position = box_position
	container.rotation_degrees = box_rotation_degrees
	parent.add_child(container)

	# Render a softly chamfered profile while retaining a simple, dependable box
	# collider. This is an inexpensive realism pass over the early blockout.
	var box_mesh := _rounded_box_mesh(size)
	if collidable:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = box_mesh
		mesh_instance.material_override = material
		container.add_child(mesh_instance)
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "Collision"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		container.add_child(collision_shape)
	else:
		var mesh_instance := container as MeshInstance3D
		mesh_instance.mesh = box_mesh
		mesh_instance.material_override = material
	return container


## One rounded-plan boarding platform with the access stand's original bounds,
## material, box collider and node hierarchy. Four quarter-circle arcs replace
## the almost invisible shallow-box bevel in plan view. At four segments per
## corner this mesh is 64 triangles instead of the shared box's 108, so the more
## legible silhouette also costs less geometry and no extra submission.
func _rounded_access_platform(
	parent: Node3D,
	node_name: String,
	platform_position: Vector3,
	size: Vector3,
	material: Material,
	corner_radius: float,
	segments_per_corner: int,
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = platform_position
	body.collision_layer = WORLD_LAYER
	body.collision_mask = PhysicsLayers.NONE
	body.set_meta("geometry_profile", &"horizontal_rounded_rectangle")
	body.set_meta("corner_radius_m", corner_radius)
	body.set_meta("curve_segments_per_corner", segments_per_corner)
	body.set_meta("geometry_status", &"modern_interpretation")
	body.set_meta("interpretation_confidence", &"low")
	body.set_meta("authenticated_original_geometry", false)
	parent.add_child(body)

	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = _horizontal_rounded_rectangle_mesh(size, corner_radius, segments_per_corner)
	visual.material_override = material
	body.add_child(visual)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


## The Fleet Dock approach bridge uses the same low-cost rounded-plan topology
## as the central access platform but retains its own evidence and resource
## identity. This replaces one 108-triangle box with 64 triangles without adding
## a renderer, body, shape or submission.
func _rounded_fleet_connector_deck(
	parent: Node3D,
	node_name: String,
	deck_position: Vector3,
	size: Vector3,
	material: Material,
	corner_radius: float,
	segments_per_corner: int,
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = deck_position
	body.collision_layer = WORLD_LAYER
	body.collision_mask = PhysicsLayers.NONE
	body.set_meta("geometry_profile", &"horizontal_rounded_gateway")
	body.set_meta("corner_radius_m", corner_radius)
	body.set_meta("curve_segments_per_corner", segments_per_corner)
	body.set_meta("evidence_status", OPERATIONAL_LATTICE_EVIDENCE_STATUS)
	body.set_meta("historical_form_identified", false)
	parent.add_child(body)

	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	var mesh := _horizontal_rounded_rectangle_mesh(size, corner_radius, segments_per_corner)
	mesh.resource_name = "fleet_dock_connector_rounded_gateway_v1"
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _horizontal_rounded_rectangle_mesh(
	size: Vector3,
	corner_radius: float,
	segments_per_corner: int,
) -> ArrayMesh:
	var radius := clampf(corner_radius, 0.001, minf(size.x, size.z) * 0.5)
	var segment_count := maxi(segments_per_corner, 2)
	var half_size := Vector2(size.x, size.z) * 0.5
	var centres: Array[Vector2] = [
		Vector2(half_size.x - radius, -half_size.y + radius),
		Vector2(half_size.x - radius, half_size.y - radius),
		Vector2(-half_size.x + radius, half_size.y - radius),
		Vector2(-half_size.x + radius, -half_size.y + radius),
	]
	var boundary: Array[Vector2] = []
	for corner_index in centres.size():
		var start_angle := -PI * 0.5 + float(corner_index) * PI * 0.5
		for segment in segment_count:
			var angle := start_angle + float(segment) / float(segment_count) * PI * 0.5
			boundary.append(centres[corner_index] + Vector2(cos(angle), sin(angle)) * radius)

	var half_height := size.y * 0.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in boundary.size():
		var current := boundary[index]
		var next := boundary[(index + 1) % boundary.size()]
		var current_uv := Vector2(current.x / size.x + 0.5, current.y / size.z + 0.5)
		var next_uv := Vector2(next.x / size.x + 0.5, next.y / size.z + 0.5)
		# Standard counter-clockwise X/Z points face down in Godot coordinates,
		# so reverse the upper cap and retain that order for the lower cap.
		_emit_capsule_vertex(surface, Vector3(0.0, half_height, 0.0), Vector3.UP, Vector2(0.5, 0.5))
		_emit_capsule_vertex(surface, Vector3(next.x, half_height, next.y), Vector3.UP, next_uv)
		_emit_capsule_vertex(surface, Vector3(current.x, half_height, current.y), Vector3.UP, current_uv)
		_emit_capsule_vertex(surface, Vector3(0.0, -half_height, 0.0), Vector3.DOWN, Vector2(0.5, 0.5))
		_emit_capsule_vertex(surface, Vector3(current.x, -half_height, current.y), Vector3.DOWN, current_uv)
		_emit_capsule_vertex(surface, Vector3(next.x, -half_height, next.y), Vector3.DOWN, next_uv)
		var rim_normal := Vector3(next.y - current.y, 0.0, current.x - next.x).normalized()
		var rim_u := float(index) / float(boundary.size())
		var rim_next_u := float(index + 1) / float(boundary.size())
		_emit_capsule_vertex(surface, Vector3(current.x, -half_height, current.y), rim_normal, Vector2(rim_u, 0.0))
		_emit_capsule_vertex(surface, Vector3(current.x, half_height, current.y), rim_normal, Vector2(rim_u, 1.0))
		_emit_capsule_vertex(surface, Vector3(next.x, half_height, next.y), rim_normal, Vector2(rim_next_u, 1.0))
		_emit_capsule_vertex(surface, Vector3(current.x, -half_height, current.y), rim_normal, Vector2(rim_u, 0.0))
		_emit_capsule_vertex(surface, Vector3(next.x, half_height, next.y), rim_normal, Vector2(rim_next_u, 1.0))
		_emit_capsule_vertex(surface, Vector3(next.x, -half_height, next.y), rim_normal, Vector2(rim_next_u, 0.0))
	surface.generate_tangents()
	var mesh := surface.commit()
	mesh.resource_name = "central_berth_access_platform_rounded_v1"
	return mesh


## One audited batch for repeated, anonymous visual stock. Semantic and solid
## pieces continue through `_box`; this helper must never receive their roster.
func _multimesh_visual_boxes(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	material: Material,
	transforms: Array[Transform3D]
) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _rounded_box_mesh(size)
	multi.instance_count = transforms.size()
	multi.visible_instance_count = -1
	multi.buffer = _encode_multimesh_transforms(transforms)
	# Raw-buffer authorship is deterministic, but headless Godot does not rebuild
	# a CPU AABB from it. Publish the exact transformed union for renderer culling.
	multi.custom_aabb = _transformed_mesh_bounds(multi.mesh.get_aabb(), transforms)
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multi
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.layers = 1
	batch.set_meta("visual_detail_only", true)
	batch.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


func _encode_multimesh_transforms(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var transform_value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = transform_value.basis.x.x
		buffer[offset + 1] = transform_value.basis.y.x
		buffer[offset + 2] = transform_value.basis.z.x
		buffer[offset + 3] = transform_value.origin.x
		buffer[offset + 4] = transform_value.basis.x.y
		buffer[offset + 5] = transform_value.basis.y.y
		buffer[offset + 6] = transform_value.basis.z.y
		buffer[offset + 7] = transform_value.origin.y
		buffer[offset + 8] = transform_value.basis.x.z
		buffer[offset + 9] = transform_value.basis.y.z
		buffer[offset + 10] = transform_value.basis.z.z
		buffer[offset + 11] = transform_value.origin.z
	return buffer


func _transformed_mesh_bounds(mesh_bounds: AABB, transforms: Array[Transform3D]) -> AABB:
	var result := AABB()
	var first := true
	for transform_value in transforms:
		var piece := (transform_value * mesh_bounds).abs()
		if first:
			result = piece
			first = false
		else:
			result = result.merge(piece)
	return result


## One approach-facing structural fascia with a capsule outline in its broad
## X/Y face and a constant Z extrusion. The previous chamfered box still read as
## a twelve-metre rectangular lintel from gameplay distance: its bevel occupied
## less than ten centimetres at each end. A half-metre radius makes the outer
## silhouette visibly curve without moving the fascia's authored bounds, sign
## seat or box collider. Eight segments per end keep that curve smooth at the
## room's approach distance while reducing this one mesh from 108 to 72 triangles.
func _extruded_capsule_fascia(
		parent: Node3D,
		node_name: String,
		fascia_position: Vector3,
		size: Vector3,
		material: Material,
		end_radius: float,
		segments_per_end: int,
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = fascia_position
	body.collision_layer = WORLD_LAYER
	body.collision_mask = PhysicsLayers.NONE
	body.set_meta("geometry_profile", &"extruded_capsule")
	body.set_meta("end_radius_m", end_radius)
	body.set_meta("curve_segments_per_end", segments_per_end)
	body.set_meta("evidence_status", OPERATIONAL_LATTICE_EVIDENCE_STATUS)
	body.set_meta("historical_form_identified", false)
	parent.add_child(body)

	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = _extruded_capsule_mesh(size, end_radius, segments_per_end)
	visual.material_override = material
	body.add_child(visual)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


## Give the normal Habitat walk route a true curved pressure-lintel silhouette
## without taking ownership away from HabitatSpine. The existing StaticBody,
## BoxShape, shell-light material and children remain in place; only the render
## resource changes. This also leaves the separately authored amber sign at x=4
## and the live StationDoor below the lintel wholly untouched.
func _apply_habitat_entry_curve() -> void:
	var header := habitat_spine.get_node_or_null(
		^"Structure/PlayerClearConnector/EntryFacadeHeader"
	) as StaticBody3D
	if header == null:
		push_error("Habitat entry header is missing from the production world")
		return
	var visual := header.get_node_or_null(^"Mesh") as MeshInstance3D
	var collision := header.get_node_or_null(^"Collision") as CollisionShape3D
	if visual == null or collision == null or not collision.shape is BoxShape3D:
		push_error("Habitat entry header lost its matched render/collision pair")
		return
	var shape := collision.shape as BoxShape3D
	if not shape.size.is_equal_approx(HABITAT_ENTRY_HEADER_SIZE):
		push_error("Habitat entry header collision envelope drifted before curve treatment")
		return
	var mesh := _extruded_capsule_mesh(
		HABITAT_ENTRY_HEADER_SIZE,
		HABITAT_ENTRY_HEADER_END_RADIUS,
		HABITAT_ENTRY_HEADER_CURVE_SEGMENTS
	)
	mesh.resource_name = "habitat_entry_capsule_header_v1"
	visual.mesh = mesh
	header.set_meta("geometry_profile", &"extruded_capsule_header")
	header.set_meta("end_radius_m", HABITAT_ENTRY_HEADER_END_RADIUS)
	header.set_meta("curve_segments_per_end", HABITAT_ENTRY_HEADER_CURVE_SEGMENTS)


func _extruded_capsule_mesh(
		size: Vector3,
		end_radius: float,
		segments_per_end: int,
	) -> ArrayMesh:
	var radius := clampf(end_radius, 0.001, minf(size.x, size.y) * 0.5)
	var segment_count := maxi(segments_per_end, 2)
	var straight_half_width := size.x * 0.5 - radius
	var boundary: Array[Vector2] = []
	for segment in segment_count + 1:
		var angle := lerpf(-PI * 0.5, PI * 0.5, float(segment) / float(segment_count))
		boundary.append(Vector2(
			straight_half_width + cos(angle) * radius,
			sin(angle) * radius,
		))
	for segment in segment_count + 1:
		var angle := lerpf(PI * 0.5, PI * 1.5, float(segment) / float(segment_count))
		boundary.append(Vector2(
			-straight_half_width + cos(angle) * radius,
			sin(angle) * radius,
		))

	var half_depth := size.z * 0.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in boundary.size():
		var current := boundary[index]
		var next := boundary[(index + 1) % boundary.size()]
		var current_uv := Vector2(current.x / size.x + 0.5, current.y / size.y + 0.5)
		var next_uv := Vector2(next.x / size.x + 0.5, next.y / size.y + 0.5)
		# Approach/front cap, outward toward local -Z.
		_emit_capsule_vertex(surface, Vector3(0.0, 0.0, -half_depth), Vector3.FORWARD, Vector2(0.5, 0.5))
		_emit_capsule_vertex(surface, Vector3(next.x, next.y, -half_depth), Vector3.FORWARD, next_uv)
		_emit_capsule_vertex(surface, Vector3(current.x, current.y, -half_depth), Vector3.FORWARD, current_uv)
		# Rear cap, outward toward local +Z.
		_emit_capsule_vertex(surface, Vector3(0.0, 0.0, half_depth), Vector3.BACK, Vector2(0.5, 0.5))
		_emit_capsule_vertex(surface, Vector3(current.x, current.y, half_depth), Vector3.BACK, current_uv)
		_emit_capsule_vertex(surface, Vector3(next.x, next.y, half_depth), Vector3.BACK, next_uv)
		# Constant-depth rim following the rounded outline.
		var rim_normal := Vector3(next.y - current.y, current.x - next.x, 0.0).normalized()
		var rim_u := float(index) / float(boundary.size())
		var rim_next_u := float(index + 1) / float(boundary.size())
		_emit_capsule_vertex(surface, Vector3(current.x, current.y, -half_depth), rim_normal, Vector2(rim_u, 0.0))
		_emit_capsule_vertex(surface, Vector3(next.x, next.y, -half_depth), rim_normal, Vector2(rim_next_u, 0.0))
		_emit_capsule_vertex(surface, Vector3(next.x, next.y, half_depth), rim_normal, Vector2(rim_next_u, 1.0))
		_emit_capsule_vertex(surface, Vector3(current.x, current.y, -half_depth), rim_normal, Vector2(rim_u, 0.0))
		_emit_capsule_vertex(surface, Vector3(next.x, next.y, half_depth), rim_normal, Vector2(rim_next_u, 1.0))
		_emit_capsule_vertex(surface, Vector3(current.x, current.y, half_depth), rim_normal, Vector2(rim_u, 1.0))
	surface.generate_tangents()
	var mesh := surface.commit()
	mesh.resource_name = "dock_operations_capsule_fascia_v1"
	return mesh


func _emit_capsule_vertex(
		surface: SurfaceTool,
		position: Vector3,
		normal: Vector3,
		uv: Vector2,
	) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv)
	surface.add_vertex(position)


## One rendered, colliding threshold ramp between two decks at different heights.
##
## `surface_start` and `surface_finish` are points on the finished walking plane,
## not box centres, so the caller states the seam it wants closed and the helper
## derives the slab beneath it. This is the same construction the junction access
## stair already uses; it exists as a helper because raised pods hand off to the
## lattice deck in more than one place (MAP-002).
func _approach_threshold(
	parent: Node3D,
	node_name: String,
	surface_start: Vector3,
	surface_finish: Vector3,
	width: float,
	material: Material,
	thickness: float = 0.22
) -> StaticBody3D:
	var along := surface_finish - surface_start
	var run := along.length()
	if run <= 0.001:
		push_error("Threshold %s has no run between its two surface points" % node_name)
		return null
	var length_axis := along / run
	var width_axis := Vector3.UP.cross(length_axis).normalized()
	var up_normal := length_axis.cross(width_axis)
	var threshold := StaticBody3D.new()
	threshold.name = node_name
	threshold.collision_layer = WORLD_LAYER
	threshold.collision_mask = 0
	threshold.basis = Basis(width_axis, up_normal, length_axis)
	threshold.position = (surface_start + surface_finish) * 0.5 - up_normal * (thickness * 0.5)
	threshold.set_meta("continuous_player_threshold", true)
	parent.add_child(threshold)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = _rounded_box_mesh(Vector3(width, thickness, run))
	mesh_instance.material_override = material
	threshold.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, thickness, run)
	collision.shape = shape
	threshold.add_child(collision)
	return threshold


## Box with softly chamfered edges, at the hub's frozen bevel rule.
##
## The rule stays `clamp(shortest_side * 0.22, 0.003, 0.2)` and is *not* the
## kit's own `bevel_for_size`. Measured over every live chamfered box in the hub,
## adopting the kit rule would move 43 of 88 distinct sizes by up to 0.0200 m —
## the largest movement anywhere in the station, because the hub owns both the
## thinnest overlays and the big slabs the 0.20 m cap holds back from the kit's
## 0.18 m. So the shared code is the builder, not the rule. The outer extent
## along each axis is preserved exactly, so `get_aabb()` still returns the
## requested size and no footprint, collider or published envelope moves.
func _rounded_box_mesh(size: Vector3) -> ArrayMesh:
	return StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
		size,
		StationSurfaceKit.proportional_bevel_for_size(size, 0.2),
		_rounded_box_cache,
		StationSurfaceKit.BevelUV.FACE_GRID
	)


func _cylinder(
	parent: Node3D,
	node_name: String,
	cylinder_position: Vector3,
	radius: float,
	height: float,
	material: Material,
	collidable: bool = false,
	cylinder_rotation_degrees: Vector3 = Vector3.ZERO
) -> Node3D:
	var container: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		container = body
	else:
		container = MeshInstance3D.new()
	container.name = node_name
	container.position = cylinder_position
	container.rotation_degrees = cylinder_rotation_degrees
	parent.add_child(container)

	# Chamfered rims at the hub's frozen 24 radial segments. The cap radius and
	# the lateral height both shrink by the chamfer; the outer radius and the
	# overall height do not, so `get_aabb()` still returns the requested
	# 2r x h x 2r and the collision cylinder below is untouched.
	var cylinder_mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius, radius, height, 24, _chamfered_cylinder_cache
	)
	if collidable:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = cylinder_mesh
		mesh_instance.material_override = material
		container.add_child(mesh_instance)
		var collision_shape := CollisionShape3D.new()
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = radius
		cylinder_shape.height = height
		collision_shape.shape = cylinder_shape
		container.add_child(collision_shape)
	else:
		var mesh_instance := container as MeshInstance3D
		mesh_instance.mesh = cylinder_mesh
		mesh_instance.material_override = material
	return container


func _beam_between(
	parent: Node3D,
	node_name: String,
	from_position: Vector3,
	to_position: Vector3,
	radius: float,
	material: Material,
	collidable: bool = false
) -> Node3D:
	var direction := to_position - from_position
	var beam := _cylinder(
		parent,
		node_name,
		(from_position + to_position) * 0.5,
		radius,
		direction.length(),
		material,
		collidable
	)
	if direction.length_squared() > 0.000001:
		beam.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return beam


func _sphere(
	parent: Node3D,
	node_name: String,
	sphere_position: Vector3,
	radius: float,
	material: Material,
	collidable: bool = false,
	shared_mesh: SphereMesh = null
) -> Node3D:
	var container: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		container = body
	else:
		container = MeshInstance3D.new()
	container.name = node_name
	container.position = sphere_position
	parent.add_child(container)
	var sphere_mesh := shared_mesh
	if sphere_mesh == null:
		sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = radius
		sphere_mesh.height = radius * 2.0
		sphere_mesh.radial_segments = 24
		sphere_mesh.rings = 12
	if collidable:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = sphere_mesh
		mesh_instance.material_override = material
		container.add_child(mesh_instance)
		var collision_shape := CollisionShape3D.new()
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = radius
		collision_shape.shape = sphere_shape
		container.add_child(collision_shape)
	else:
		var mesh_instance := container as MeshInstance3D
		mesh_instance.mesh = sphere_mesh
		mesh_instance.material_override = material
	return container


func _torus(
	parent: Node3D,
	node_name: String,
	torus_position: Vector3,
	inner_radius: float,
	outer_radius: float,
	material: Material,
	torus_rotation_degrees: Vector3 = Vector3.ZERO,
	shared_mesh: TorusMesh = null
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = torus_position
	mesh_instance.rotation_degrees = torus_rotation_degrees
	var torus_mesh := shared_mesh
	if torus_mesh == null:
		torus_mesh = TorusMesh.new()
		torus_mesh.inner_radius = inner_radius
		torus_mesh.outer_radius = outer_radius
		torus_mesh.rings = 64
		torus_mesh.ring_segments = 16
	mesh_instance.mesh = torus_mesh
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _quad(
	parent: Node3D,
	node_name: String,
	quad_position: Vector3,
	size: Vector2,
	material: Material,
	quad_rotation_degrees: Vector3
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = quad_position
	mesh_instance.rotation_degrees = quad_rotation_degrees
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = size
	mesh_instance.mesh = quad_mesh
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _text_sign(
	parent: Node3D,
	text: String,
	text_position: Vector3,
	text_rotation_degrees: Vector3,
	scale_value: float,
	material: Material
) -> MeshInstance3D:
	# Tessellation and extrusion are owned by `SignGeometryBudget`, not authored
	# here, so the station cannot drift back to 10,000-triangle lettering one
	# sign at a time. The glyph block this produces is the same world size as the
	# former `font_size = 64`, `pixel_size = 0.012`; only the curve resolution and
	# the invisible extrusion change.
	var text_mesh := SignGeometryBudget.build(text)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Sign_" + text.replace(" ", "_").replace("/", "-")
	mesh_instance.position = text_position
	mesh_instance.rotation_degrees = text_rotation_degrees
	mesh_instance.scale = Vector3.ONE * scale_value
	mesh_instance.mesh = text_mesh
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance
