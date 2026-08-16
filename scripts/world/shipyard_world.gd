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
const SHIP_BERTH_FEEDBACK_SCHEMA_VERSION := 2
const SHIP_BERTH_FEEDBACK_MATERIAL_COUNT := 4
const SHIP_BERTH_FEEDBACK_BERTH_IDS: Array[StringName] = [
	CENTRAL_BERTH_ID,
	ARROW_RECON_BERTH_ID,
	JOVIAN_FREIGHT_BERTH_ID,
	ZENITH_FLEET_DOCK_BERTH_ID,
]
const SHIP_BERTH_FEEDBACK_MATERIAL_IDS: Array[StringName] = [
	&"dim",
	&"cyan",
	&"amber",
	&"secured",
]
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
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -0.96, 0.0)),
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
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -0.93, 0.0)),
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
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.18, 0.0)),
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
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.04, 0.0)),
		"cue_half_width": 5.0,
		"cue_half_length": 4.8,
	},
}
## PORT-DECK-001 / RUNWAY-SEAM-001 measured geometry constants.
##
## `AUTHORED_CENTRAL_BERTH_EDGE_Z` is the +Z extent of the authored central-berth
## shell (`edge_fascia__EdgeIvory` reaches z = 7.75; its deck panels reach 7.55).
## Every generic lattice deck stops at or beyond this plane so no station surface
## shares a volume with the authored runway plate.
const AUTHORED_CENTRAL_BERTH_EDGE_Z := 7.75
## Port berth node, widened from 12.0 m so the 12.2 m Arrow no longer overhangs
## the pad it is parked on. Its centre is unchanged, so berth transforms, the
## landing envelope and the cue strips all keep their published coordinates.
const PORT_BERTH_NODE_OUTER_X := -43.0
const PORT_BERTH_NODE_HALF_WIDTH := 8.4

const CENTRAL_HERO_SCHEMA_VERSION := 2
const OPERATIONAL_LATTICE_SCHEMA_VERSION := 1
const SPACE_BACKDROP_SCHEMA_VERSION := 1
const SPACE_BACKDROP_MODULE_ID: StringName = &"source-bounded-space-backdrop"
const SPACE_BACKDROP_STAR_SEED := 19780704
const SPACE_BACKDROP_STAR_COUNT := 2600
const SPACE_BACKDROP_STAR_RADIUS_MIN := 1450.0
const SPACE_BACKDROP_STAR_RADIUS_MAX := 1650.0
const SPACE_BACKDROP_NEBULA_COVER_STRENGTH := 0.08
const SPACE_BACKDROP_BODY_SPECS := {
	&"CelestialGreenBody": {
		"position": Vector3(-310.0, 100.0, -890.0),
		"radius": 135.0,
		"palette_role": &"green",
		"color": Color("5a9b58"),
	},
	&"CelestialTanBody": {
		"position": Vector3(250.0, -120.0, -1040.0),
		"radius": 165.0,
		"palette_role": &"tan_cream",
		"color": Color("c7b887"),
	},
	&"CelestialGreyBody": {
		"position": Vector3(70.0, 230.0, -1250.0),
		"radius": 120.0,
		"palette_role": &"grey",
		"color": Color("86878c"),
	},
	&"CelestialOrangeBody": {
		"position": Vector3(-500.0, -160.0, -1150.0),
		"radius": 105.0,
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
## wayfinding pylon. Every one of the eight remains presentation-only.
const EXPECTED_STATION_ACTIVITY_COUNT := 8
const EXPECTED_STATION_AMBIENCE_COUNT := 4
const EXPECTED_STATION_DRESSING_COUNT := 4
const STATION_ACTIVITY_SPECS := {
	&"CentralTowServiceActivity": {"path": NodePath("OperationalLattice/Activities/CentralTowServiceActivity"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(6.8, 0.0, 14.0)), "profile": &"full", "seed": 1103},
	&"AftOperationsActivity": {"path": NodePath("OperationalLattice/Activities/AftOperationsActivity"), "transform": Transform3D(Basis(Vector3.UP, PI), Vector3(5.8, 4.99, 61.2)), "profile": &"service_arm", "seed": 2207},
	&"HabitatServicePatrol": {"path": NodePath("OperationalLattice/Activities/HabitatServicePatrol"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(59.15, 4.88, 15.5)), "profile": &"drone_patrol", "seed": 3301},
	&"FreightApproachGantry": {"path": NodePath("OperationalLattice/Activities/FreightApproachGantry"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-53.0, 0.38, 29.7)), "profile": &"gantry", "seed": 4409},
	# Station-life placements. Each sits on a support body an existing sibling
	# already proved walkable or roofed, keeps at least 12 m from every other
	# activity root, and clears every berth landing volume; none of them adds
	# collision, so no deliberate void is filled and no deck is widened.
	&"CentralCargoTransferLine": {"path": NodePath("OperationalLattice/Activities/CentralCargoTransferLine"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(-7.0, 0.0, 18.0)), "profile": &"cargo_line", "seed": 5507},
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
const EXPECTED_STATION_SERVICE_AGENT_COUNT := 4
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
		"lift": 3.6,
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

## Aim of the station's key light, and of the sky's sun glow.
##
## One constant serves both. A backdrop whose bright side does not agree with the
## direction the geometry is lit from is one of the things that makes a sky read
## as a painted wall rather than as the place the light is coming from.
const KEY_LIGHT_ROTATION_DEGREES := Vector3(-42.0, -28.0, 0.0)

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
const SKY_SUN_HALO := 0.55
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
@onready var nearby_sector_cluster: NearbySectorCluster = $NearbySectorCluster

var _materials: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
var _chamfered_cylinder_cache: Dictionary = {}
var _targets: Array[StaticBody3D] = []
var _warning_lights: Array[OmniLight3D] = []
var _crane_trolley: Node3D
var _crane_hook: Node3D
var _built := false
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


func _enter_tree() -> void:
	# `_ready` runs only once. A detached/re-added built world restores its
	# component lifecycle after every descendant has re-entered the tree.
	if _built:
		call_deferred("_restore_operational_lattice_after_reentry")


func _exit_tree() -> void:
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
	_built = true
	_initialize_berths()
	_build_operational_lattice_components()
	_create_materials()
	_build_environment()
	_build_architecture()
	_build_landing_pad()
	_build_launch_corridor()
	_build_catwalks_and_control_room()
	_build_regeneration_gallery()
	_build_provisional_fleet()
	_build_industrial_details()
	_build_cargo_and_machinery()
	_build_exterior_range()
	_build_space_backdrop()
	# After the backdrop, so the update-once bake sees the finished sky.
	_build_module_reflection_probes()
	# The hub endpoints resolve against lattice geometry built above, so the
	# registry can only be assembled once the environment exists. Service couriers
	# consume routes resolved from that registry, so they are created afterwards
	# and indexed together with the rest of the lattice.
	_initialize_station_route_registry()
	_build_station_service_agents()
	_index_operational_lattice_components()
	_connect_operational_lattice_audio()
	_apply_operational_dressing_quality()
	set_station_activity_enabled(_station_activity_enabled)


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


## Fixed-era-inspired habitat insertion at the starboard physical node. The
## component's own evidence report records that its exact plan and adjacency
## are modern interpretation, not recovered original station geometry.
func get_habitat_spine() -> HabitatSpine:
	return habitat_spine


func get_jovian_freight_berth() -> JovianFreightBerth:
	return jovian_freight_berth


## The hand-authored destination cluster outside the station envelope: the route
## beacon chain, the ringed moonlet, the Cinder Reach debris field and the
## derelict extraction platform. It is mounted at the world origin with an
## identity transform, so its published coordinates read directly against the
## launch gate and the target range. It owns no gameplay authority and adds no
## range targets, so `get_target_count()` and the guided mission are unaffected.
func get_nearby_sector_cluster() -> NearbySectorCluster:
	return nearby_sector_cluster


func get_nearby_sector_cluster_audit_report() -> Dictionary:
	if not is_instance_valid(nearby_sector_cluster):
		return {"valid": false, "errors": ["nearby sector cluster is missing from the world"]}
	return nearby_sector_cluster.get_cluster_audit_report()


## Source-bounded B2 comb/slab macro correction. Dock 01 records one modern,
## externally owned Zenith assignment; docks 02/03 remain empty and deferred.
## The component exposes station circulation and landmarks, never berth or
## ship-regeneration authority itself.
func get_fleet_dock_comb() -> FleetDockComb:
	return fleet_dock_comb


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
		if assigned_docks.size() != 1:
			errors.append("fleet dock comb must expose exactly one external dock assignment")
		else:
			var assignment := assigned_docks[0]
			if assignment.get("dock_id", &"") != &"assigned-dock-01" \
				or assignment.get("ship_assignment", &"") != &"zenith_b7_observed" \
				or assignment.get("berth_id", &"") != ZENITH_FLEET_DOCK_BERTH_ID \
				or bool(assignment.get("owns_berth_authority", true)) \
				or bool(assignment.get("historical_class_to_berth_mapping", true)):
				errors.append("fleet dock 01 Zenith assignment contract drifted")
			assigned_marker_transform = assignment.get("marker_transform", Transform3D.IDENTITY) as Transform3D
			expected_berth_origin = assigned_marker_transform.origin + Vector3.UP * 0.93
		if deferred_docks.size() != 2:
			errors.append("fleet dock comb must retain exactly two deferred empty docks")
		else:
			for dock in deferred_docks:
				if dock.get("status", &"") != &"deferred_empty" \
					or dock.get("ship_assignment", &"") != &"none" \
					or bool(dock.get("owns_berth_authority", true)):
					errors.append("fleet dock 02/03 deferred landmark contract drifted")
					break
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
		"schema_version": 2,
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


## One reversible switch for station movers, the existing freight crane, and
## the finite-range machinery beds. Static structural dressing deliberately
## stays visible because it remains part of the station silhouette.
func set_station_activity_enabled(enabled: bool) -> void:
	_station_activity_enabled = enabled
	for activity in _station_operations_activities:
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
	var expected_profiles := PackedStringArray([
		"cargo_line",
		"crew_workpost",
		"drone_patrol",
		"full",
		"gantry",
		"observatory",
		"service_arm",
		"signage_pylon",
	])
	if activity_profiles != expected_profiles:
		errors.append("station activity roster must contain each role-specific profile exactly once")
	if activity_placements.size() != STATION_ACTIVITY_SPECS.size():
		errors.append("station activity roster must contain each exact production name once")
	var activity_roster := StationOperationsActivity.audit_production_roster(activity_nodes)
	if not bool(activity_roster.get("valid", false)):
		errors.append_array(activity_roster.get("errors", PackedStringArray()) as PackedStringArray)

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
			"audio_totals": audio_totals,
			"structural_totals": dressing_totals,
			"dynamic_reflection_probes_added": 0,
			"particle_emitters_added": 0,
		},
		"lifecycle": {
			"enabled": _station_activity_enabled,
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
		errors.append("station must integrate exactly four declared-slot service couriers")

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
	if not is_inside_tree() or not _built:
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
	# Corrected station-ward mount: its service zone ends at world Z=35.6,
	# preserving at least 0.2 m before the Jovian landing volume begins.
	_add_station_activity(
		activities, "FreightApproachGantry",
		Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-53.0, 0.38, 29.7)),
		StationOperationsActivity.ActivityProfile.GANTRY, 4409
	)

	# Station life. Cargo movement beside the Central berth, a crew work post at
	# the head of the Aft upper stair, an observation instrument on the Habitat
	# common roof, and wayfinding at the Freight approach.
	_add_station_activity(
		activities, "CentralCargoTransferLine",
		Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(-7.0, 0.0, 18.0)),
		StationOperationsActivity.ActivityProfile.CARGO_LINE, 5507
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
	# The cluster's fine debris shell follows the same profile the station
	# dressing does. Its structures, boulders and collision never vary.
	if is_instance_valid(nearby_sector_cluster):
		nearby_sector_cluster.set_detail_quality(visual_quality_level)


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


func defer_target_damage_presentation(
		receipt_id: int,
		target: StaticBody3D,
		target_id: StringName,
		hit_position: Vector3,
		terminal: bool
	) -> bool:
	if receipt_id < 0 or not is_instance_valid(target):
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
	if not _pending_target_presentations.has(receipt_id):
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
		if (
			not body.position.is_equal_approx(spec.position as Vector3)
			or not is_equal_approx(sphere.radius, float(spec.radius))
			or not is_equal_approx(sphere.height, float(spec.radius) * 2.0)
			or material == null
			or not material.albedo_color.is_equal_approx(spec.color as Color)
			or not material.emission_enabled
			or not material.emission.is_equal_approx(spec.color as Color)
			# Re-frozen from 0.32/0.9 by the global art pass. See the body material
			# construction for the full reason: at 0.32 emission each body filled its
			# own night side back in and rendered as a flat saturated disc rather
			# than a lit sphere. Still an exact equality, still the same four
			# authored colours, radii and placements.
			or not is_equal_approx(material.emission_energy_multiplier, 0.1)
			or not is_equal_approx(material.roughness, 1.0)
			or body.get_meta(&"palette_role", &"") != spec.palette_role
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
		"target_count": get_target_count(),
		"berth_ids": PackedStringArray([
			String(CENTRAL_BERTH_ID),
			String(ARROW_RECON_BERTH_ID),
			String(JOVIAN_FREIGHT_BERTH_ID),
			String(ZENITH_FLEET_DOCK_BERTH_ID),
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
	return get_visual_quality_report()


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
	var panel_albedo := load("res://assets/materials/procedural-panel-triplanar-albedo-v2.png") as Texture2D
	var panel_normal := load("res://assets/materials/procedural-panel-triplanar-normal-v2.png") as Texture2D
	var panel_roughness := load("res://assets/materials/procedural-panel-triplanar-roughness-v2.png") as Texture2D
	if panel_albedo == null or panel_normal == null or panel_roughness == null:
		return
	for key in ["deck", "deck_light", "navy", "blue", "steel_blue", "ivory", "black", "orange"]:
		var panel_material := _materials[key] as StandardMaterial3D
		panel_material.albedo_texture = panel_albedo
		panel_material.normal_enabled = true
		panel_material.normal_texture = panel_normal
		# Raised from 0.48 by a rendered sweep at 0.48 / 1.0 / 1.4 / 1.9. At 0.48 a
		# plated wall at eye height is nearly featureless: the seams and rivets are
		# present in the map but too shallow to catch light, which is much of why
		# plated geometry still read as untextured. At 1.9 the plate faces dome and
		# read as embossed plastic, worst on the bright pod walls. 1.0 is the highest
		# value at which no frame showed doming while the dark walls resolved into
		# pressed sheet metal. Every module shares the value so a deck and the wall
		# beside it cannot disagree.
		panel_material.normal_scale = 1.0
		panel_material.roughness_texture = panel_roughness
		panel_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		panel_material.uv1_triplanar = true
		panel_material.uv1_world_triplanar = true
		panel_material.uv1_triplanar_sharpness = 4.0
		panel_material.uv1_scale = Vector3(0.3, 0.3, 0.3)
		panel_material.texture_repeat = true


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
	# The walkway now stops at the authored central-berth shell's own outer edge
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

	# The B2-bounded comb is mounted beyond the Aft upper deck rather than across
	# any live landing volume. This short, visibly modelled bridge is the complete
	# connection—there is no hidden slab beneath the module's large open voids.
	var fleet_comb_connector := Node3D.new()
	fleet_comb_connector.name = "FleetDockCombConnector"
	fleet_comb_connector.set_meta("evidence_status", &"modern_interpretation")
	fleet_comb_connector.set_meta("connects_station_module", &"fleet-dock-comb")
	shell.add_child(fleet_comb_connector)
	_box(
		fleet_comb_connector,
		"FleetDockCombConnectorDeck",
		Vector3(6.0, 3.88, 68.3),
		Vector3(12.5, 0.64, 3.6),
		_materials["deck_light"]
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

	# Freestanding rounded mast pairs establish several readable heights without
	# becoming a roof cage.
	# Keep the port mast outside the observation-stair approach while retaining
	# physical support on CentralJunction. Its previous (-11, 0, 10) position
	# overlapped the production player's centreline before the first tread.
	for mast_position in [Vector3(-11.0, 0.0, 14.0), Vector3(11.0, 0.0, 10.0), Vector3(-11.0, 0.0, -23.0), Vector3(11.0, 0.0, -23.0)]:
		_cylinder(shell, "DockMast", mast_position + Vector3(0, 5.2, 0), 0.46, 10.4, _materials["steel_blue"], true)
		_torus(shell, "DockMastCollar", mast_position + Vector3(0, 1.0, 0), 0.55, 0.74, _materials["orange"])
		_box(shell, "MastCap", mast_position + Vector3(0, 10.15, 0), Vector3(2.4, 0.55, 1.6), _materials["ivory"], false)
		_add_guide_light(shell, mast_position + Vector3(0, 9.5, -0.55), KETH_CYAN, false, 2.2, 9.0)

	# Modern navigation pylon; text describes this slice's deck, not a recovered
	# historical bay number or original structure.
	# A high header and two narrow posts replace the former solid pylon. The
	# opening is a real player-clear route into the aft circulation stack.
	for x_position in [-6.1, 6.1]:
		_box(shell, "JunctionPortalPost", Vector3(x_position, 3.25, 22.6), Vector3(1.1, 6.5, 1.2), _materials["blue"])
	_box(shell, "JunctionPortalHeader", Vector3(0, 7.4, 22.6), Vector3(13.3, 2.0, 1.2), _materials["blue"])
	_box(shell, "JunctionSignFace", Vector3(0, 7.4, 21.95), Vector3(12.0, 1.3, 0.12), _materials["navy"], false)
	# MAP-004 family, found by sweeping every live `TextMesh` rather than only the
	# six the intake listed. Both legends stand at z = 21.86/21.84, in front of
	# `JunctionSignFace` (z = 21.95) on the -Z side of the portal, and both were
	# authored with `Vector3.ZERO`, so the station's most prominent navigation
	# board read backwards to everyone walking aft through it. Rendered and
	# confirmed reversed before the change.
	_text_sign(
		shell,
		"MUDDS  //  REGENERATION DECK",
		Vector3(0, 7.65, 21.86),
		Vector3(0.0, 180.0, 0.0),
		0.54,
		_materials["cyan_glow"]
	)
	_text_sign(
		shell,
		"CENTRAL JUNCTION  //  FLEET DOCKS",
		Vector3(0, 7.08, 21.84),
		Vector3(0.0, 180.0, 0.0),
		0.27,
		_materials["orange_glow"]
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
	# Bright border, split into straightforward bars for crisp silhouettes.
	for x_position in [-12.2, 12.2]:
		_box(pad, "PadBorder", Vector3(x_position, 0.115, -10), Vector3(0.28, 0.05, 34.5), _materials["ivory"], false)
	for z_position in [-27.1, 7.1]:
		_box(pad, "PadBorder", Vector3(0, 0.115, z_position), Vector3(24.5, 0.05, 0.28), _materials["ivory"], false)

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
		_torus(
			hose,
			"DeckConnector",
			Vector3(8.62, 0.13, z_position),
			0.16,
			0.24,
			_materials["black"]
		)

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
			_box(
				drain,
				"DrainSlat",
				Vector3(-0.64 + float(slat_index) * 0.32, 0.015, 0.0),
				Vector3(0.055, 0.012, 0.29),
				_materials["steel_blue"],
				false
			)

	# Six flush tie-down sockets add scale and believable work detail without
	# filling the player or craft lanes with freestanding props.
	for tie_position in [
		Vector3(-8.7, 0.125, -21.5),
		Vector3(8.7, 0.125, -21.5),
		Vector3(-8.7, 0.125, -3.0),
		Vector3(8.7, 0.125, -3.0),
		Vector3(-8.7, 0.125, 3.2),
		Vector3(8.7, 0.125, 3.2),
	]:
		var tie_down := _torus(details, "TieDownSocket", tie_position, 0.16, 0.25, _materials["steel_blue"])
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

	# A short traversable stair rises directly in front of the central-junction
	# spawn. The observed spawn/ladder relationship is source-supported; this
	# modern stair geometry and exact placement are provisional.
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

	# A compact modern operations pod is attached to, rather than enclosing, the
	# starboard node. Its purpose and adjacency are not recovered original facts.
	_box(upper, "OperationsPodFloor", Vector3(43.0, 0.18, 27.0), Vector3(12.0, 0.4, 8.0), _materials["deck_light"])
	# The pod floor is a 0.40 m slab resting on the starboard node, so its glazed
	# frontage presented a 0.40 m vertical face to anyone walking up to it — a wall,
	# not a step, for a CharacterBody3D. The pod keeps its authored placement; a
	# rendered threshold apron closes the seam across the whole frontage.
	_approach_threshold(
		upper,
		"OperationsPodThreshold",
		Vector3(43.0, -0.02, 21.85),
		Vector3(43.0, 0.38, 23.05),
		12.0,
		_materials["deck_light"]
	)
	_box(upper, "OperationsPodRoof", Vector3(43.0, 5.9, 27.0), Vector3(12.0, 0.55, 8.0), _materials["ivory"])
	_box(upper, "OperationsPodBack", Vector3(43.0, 3.0, 30.8), Vector3(12.0, 5.5, 0.5), _materials["steel_blue"])
	for x_position in [37.5, 41.2, 44.8, 48.5]:
		_box(upper, "OperationsWindowMullion", Vector3(x_position, 3.0, 22.95), Vector3(0.26, 5.4, 0.32), _materials["steel_blue"])
		_box(upper, "OperationsWindow", Vector3(x_position + 1.75, 3.0, 22.8), Vector3(3.15, 4.7, 0.08), _materials["glass"], false)
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


func _build_provisional_fleet() -> void:
	# Several physically parked craft around separate nodes are source-supported;
	# every silhouette below is an original modern blockout with no historic name
	# assignment. Static collision keeps the ships tangible while their berths and
	# the hero launch corridor remain clear.
	var fleet := Node3D.new()
	fleet.name = "ProvisionalParkedFleet"
	add_child(fleet)
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

	# Cargo is clustered on solid service nodes and kept clear of the player,
	# hero berth, disembark point, and direct launch line.
	var cargo_layout := [
		[Vector3(46.0, 1.1, 27.5), Vector3(3.0, 2.2, 2.7), "ivory"],
		[Vector3(42.5, 0.9, 27.5), Vector3(2.7, 1.8, 2.5), "orange"],
	]
	for index in cargo_layout.size():
		var entry: Array = cargo_layout[index]
		var cargo_position: Vector3 = entry[0]
		var cargo_size: Vector3 = entry[1]
		var material_key: String = entry[2]
		_box(props, "Cargo%02d" % index, cargo_position, cargo_size, _materials[material_key])
		for x_side in [-1.0, 1.0]:
			_box(
				props,
				"CargoBrace",
				cargo_position + Vector3(x_side * cargo_size.x * 0.38, cargo_size.y * 0.02, cargo_size.z * 0.505),
				Vector3(0.18, cargo_size.y * 0.82, 0.08),
				_materials["navy"],
				false
			)

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

	for body_name: StringName in SPACE_BACKDROP_BODY_SPECS:
		var spec := SPACE_BACKDROP_BODY_SPECS[body_name] as Dictionary
		var body_color := spec.color as Color
		# Emission re-frozen from 0.32 to 0.10. The four bodies are lit by the same
		# key light as the station, but at 0.32 the self-emission was bright enough
		# to fill the unlit half back in, so each one rendered as a flat saturated
		# disc with a barely visible terminator - four coloured circles pasted on
		# the backdrop, and the most toy-like objects left in any wide frame. At
		# 0.10 the emission is a night-side floor rather than a fill, the terminator
		# resolves, and a body reads as a sphere with a lit limb whose bright side
		# agrees with the direction everything else on screen is lit from. The
		# authored colours, radii and placements are untouched; this changes only
		# how the surface answers light, which is the whole subject of the pass.
		var body_material := _material(body_color, 0.0, 1.0, body_color, 0.1)
		body_material.disable_receive_shadows = true
		# The bodies deliberately stay *in* the depth fog, unlike the star shell.
		# Exempting them was tried and reverted: unfogged and lit by the raised key
		# they came back as vivid, fully saturated green and orange billiard balls,
		# which is a worse toy tell than the flat discs the emission change was
		# fixing. Aerial perspective is doing the right thing to them - a body a
		# kilometre out should read muted and far, and the haze is the only thing
		# on hand that says so about an untextured sphere.
		var body := _sphere(
			backdrop,
			String(body_name),
			spec.position as Vector3,
			float(spec.radius),
			body_material,
			false
		) as MeshInstance3D
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		body.set_meta(&"palette_role", spec.palette_role)


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
	_sphere(visual, "Core", Vector3.ZERO, 1.4, _materials["orange_glow"], false)
	_torus(visual, "OuterRing", Vector3.ZERO, 2.25, 2.55, _materials["ivory"], Vector3(90, 0, 0))
	_torus(visual, "InnerRing", Vector3.ZERO, 1.75, 1.93, _materials["cyan_glow"], Vector3(0, 0, 90))
	for angle in [0.0, 90.0, 180.0, 270.0]:
		var radians := deg_to_rad(angle)
		var arm_position := Vector3(cos(radians) * 2.6, sin(radians) * 2.6, 0)
		_box(visual, "TargetArm", arm_position, Vector3(1.65, 0.36, 0.42), _materials["steel_blue"], false, Vector3(0, 0, angle))
		_sphere(visual, "TargetLamp", arm_position * 1.22, 0.22, _materials["red_glow"], false)
	_targets.append(target)


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
	_sphere(parent, "GuideLens", light_position, 0.16, _material(color, 0.0, 0.25, color, 1.35), false)
	var light := OmniLight3D.new()
	light.name = "GuideLight"
	light.position = light_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	parent.add_child(light)
	if pulsing:
		light.set_meta("pulse_phase", float(_warning_lights.size()) * 0.83)
		light.set_meta("base_energy", energy)
		_warning_lights.append(light)


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
	collidable: bool = false
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
	var sphere_mesh := SphereMesh.new()
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
	torus_rotation_degrees: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = torus_position
	mesh_instance.rotation_degrees = torus_rotation_degrees
	var torus_mesh := TorusMesh.new()
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
	var text_mesh := TextMesh.new()
	text_mesh.text = text
	text_mesh.font_size = 64
	text_mesh.pixel_size = 0.012
	text_mesh.depth = 0.025
	text_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Sign_" + text.replace(" ", "_").replace("/", "-")
	mesh_instance.position = text_position
	mesh_instance.rotation_degrees = text_rotation_degrees
	mesh_instance.scale = Vector3.ONE * scale_value
	mesh_instance.mesh = text_mesh
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance
