class_name JovianLightFreighter
extends HeroShip

## Evidence-bounded Jovian-class Light Freighter candidate.
##
## Creator-authored material (A3, page archived 2009-11-12) supports the class
## name and light-freighter role. No registered source shows a craft identified
## as Jovian: B4 records the label string alone, with no ledger frame anchor and
## no tied craft, so the Jovian name-to-model mapping is `unknown`.
## Every visible dimension, colour, access route, interior, system, hardpoint,
## and handling value in this component is a revisable modern interpretation.
## The cargo deck, passenger cabin, cockpit, and exterior ramp are one physical
## ship-local hierarchy; no detached or teleported interior is involved.

const FitoutSurfaceData := preload("res://scripts/rendering/construction_surface_data.gd")

const SCHEMA_VERSION := 1
const CrewSeatRoleAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const CrewRoleGameplayProfileType := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")
const RepairAuthorityType := preload("res://scripts/combat/repair_authority.gd")
const JovianEngineerRepairConsoleType := preload("res://scripts/ships/jovian_engineer_repair_console.gd")
const JovianEngineerRepairPresentationType := preload("res://scripts/ships/jovian_engineer_repair_presentation.gd")
const CrewEngineerAudioBindingType := preload("res://scripts/audio/crew_engineer_audio_binding.gd")
const ShipPerspectiveAudioBindingType := preload("res://scripts/audio/ship_perspective_audio_binding.gd")
const JovianCopilotNavigationAudioBindingType := preload("res://scripts/audio/jovian_copilot_navigation_audio_binding.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")
const EVIDENCE_STATUS: StringName = &"provisional"
const EVIDENCE_SCOPE: StringName = &"name_and_role_only"
const NAME_TO_MODEL_STATUS: StringName = &"unknown"
const COMBAT_SOURCE_ID := 1103
const INTERIOR_SCHEMA_VERSION := 1
const PILOT_SEAT_ID: StringName = &"pilot_station"
const ENGINEER_SEAT_ID: StringName = &"passenger_port_01"
const COPILOT_SEAT_ID: StringName = &"co_pilot_station"
const COPILOT_ROLE_ID: StringName = &"copilot_navigation_support"
const COPILOT_NAVIGATION_CHANNEL: StringName = &"navigation_route"
const MAX_ENGINEER_COMPONENT_GENERATION := 1_000_000
const ENGINEER_REPAIR_DURATION_SECONDS := 0.4
const ENGINEER_REPAIR_COOLDOWN_SECONDS := 0.75
const ENGINEER_REPAIR_RESOURCE_ID: StringName = &"jovian_repair_tool"
const ENGINEER_REPAIR_RESOURCE_CAPACITY := 6
# Shared stations keep fitted service assemblies on the pressure-skin profile.
const CARGO_ROOF_SECTIONS: Array[Vector3] = [Vector3(0.92, -0.20, -3.10), Vector3(1.0, 0.0, -1.8),
	Vector3(1.0, 0.0, 8.25), Vector3(0.86, -0.22, 9.35)]
const CABIN_ROOF_SECTIONS: Array[Vector3] = [Vector3(0.70, -0.70, -9.65), Vector3(0.91, -0.12, -7.65),
	Vector3(1.0, 0.0, -4.05), Vector3(1.28, 0.30, -2.88)]
const INTERIOR_BOUNDS := AABB(Vector3(-5.72, 0.0, -8.0), Vector3(11.44, 4.6, 17.25))
## Ship-local envelope a crew member may occupy while the freighter is under way.
##
## `modern_interpretation`. This is deliberately *not* `INTERIOR_BOUNDS`: the
## pressurised occupancy volume stops at the forward cabin bulkhead, while the
## physical cockpit deck runs on to z = -10.375, and a pilot who has just left
## the seat is standing on that deck. The box is the tight bounding box of the
## craft's walkable deck collision footprints — `tests/in_flight_cabin_test.gd`
## samples those colliders and asserts every one is enclosed — so nothing outside
## it is hull interior. Real walls do the room-by-room work; this is the outer
## anti-stranding envelope, and `PlayerController` confines the occupant to it,
## so the only way out of a flying Jovian is the pilot seat.
const CABIN_MOVEMENT_BOUNDS := AABB(Vector3(-5.75, 0.30, -10.4), Vector3(11.5, 4.5, 19.65))
## Standing pose one clear stride aft of the cockpit portal, on the passenger
## deck's central aisle. The full moving-frame disembark needs this separation:
## a pose closer to the chair can be stepped onto its back as collision returns.
## Facing aft, into the cabin the pilot has just been given.
const CABIN_STAND_LOCAL_ORIGIN := Vector3(0.0, 0.52, -6.70)
const CABIN_STAND_LOCAL_YAW := PI
## Secured freight in the hold: four tie-down stations, each carrying a pallet
## with a container strapped to it.
##
## Published as one roster because the drawn crate and the collider that stops a
## crew member walking through it are built from it in two different places, and
## the whole point of making the freight solid is that those two cannot disagree.
## Every value is ship-local; `WalkableInterior` and `CargoBay` are both identity
## children of the physical ship, so cargo-bay local coordinates are ship-local.
const CARGO_UNIT_ANCHORS: Array[Vector3] = [
	Vector3(-3.75, 0.64, 0.25),
	Vector3(3.75, 0.64, 0.25),
	Vector3(-3.75, 0.64, 5.55),
	Vector3(3.75, 0.64, 5.55),
]
const CARGO_PALLET_OFFSET_Y := 0.12
const CARGO_PALLET_SIZE := Vector3(2.25, 0.22, 2.5)
const CARGO_CONTAINER_OFFSET_Y := 0.9
const CARGO_CONTAINER_SIZE := Vector3(1.95, 1.3, 2.15)
const CARGO_RESTRAINT_OFFSET_Y := 1.62
const CARGO_RESTRAINT_BAND_Z: Array[float] = [-0.64, 0.64]
const CARGO_RESTRAINT_SIZE := Vector3(2.02, 0.08, 0.1)
const CARGO_RESTRAINT_COPY_COUNT := 8
const PASSENGER_SEAT_COUNT := 6
const PASSENGER_CABIN_LIGHT_STRIP_SIZE := Vector3(0.04, 0.12, 3.55)
# Three childless emissive ceiling strips share one immutable visual recipe.
# Their separate OmniLight3D practicals remain authoritative for illumination;
# this ship-local batch only removes two renderer nodes and submissions.
const CARGO_CEILING_LIGHT_COPY_COUNT := 3
const CARGO_CEILING_LIGHT_SIZE := Vector3(2.1, 0.05, 0.18)
# Four childless amber portal uprights retain their named MeshInstance3D nodes,
# exact local transforms, and four surface submissions. Their visual-only
# rounded-box recipe is identical, so one immutable ArrayMesh supplies all four
# copies instead of allocating the same geometry four times.
const CABIN_PORTAL_UPRIGHT_COPY_COUNT := 4
const CABIN_PORTAL_UPRIGHT_SIZE := Vector3(0.18, 3.25, 0.2)
## Broad amber lintel above the deployed cargo ramp. The old rounded box spent
## 108 triangles on a 0.054 m bevel that still read rectangular while boarding.
## A true Y/Z capsule uses the same bounds and one surface in 72 triangles.
const CARGO_APERTURE_HEADER_SIZE := Vector3(0.34, 0.30, 4.20)
const CARGO_APERTURE_HEADER_END_RADIUS := 0.15
const CARGO_APERTURE_HEADER_CURVE_SEGMENTS := 8

# Two childless amber edge rails retain their named renderer nodes and exact
# ramp-aligned transforms. They own no collision, boarding, interaction, or
# lifecycle authority, so one immutable rounded-box recipe supplies both.
const CARGO_RAMP_EDGE_RAIL_COPY_COUNT := 2
const CARGO_RAMP_EDGE_RAIL_SIZE := Vector3(5.15, 0.24, 0.16)

# Two childless structure-dark ramp actuators retain their ordinary named
# renderers and exact ramp-aligned transforms. Boarding and collision remain on
# the adjacent ramp and ship-root shapes; these cosmetic leaves can therefore
# share one immutable rounded-box recipe without acquiring route authority.
const CARGO_RAMP_ACTUATOR_COPY_COUNT := 2
const CARGO_RAMP_ACTUATOR_SIZE := Vector3(0.24, 0.24, 1.35)

## Three childless teal deck-lane inlays are one identical visual recipe. They
## carry no collision, interaction, cargo, route, or evidence identity, so the
## moving cargo bay can submit their three exact local transforms as one batch.
const CARGO_DECK_LANE_COPY_COUNT := 3
const CARGO_DECK_LANE_SIZE := Vector3(0.11, 0.025, 11.4)

## Six childless load marks are the same amber exterior cue at mirrored flank
## transforms. They own no collision, interaction, evidence or lifecycle state,
## so one visual-only MultiMesh keeps all six visible copies while removing five
## renderer nodes and structural surface submissions.
const LOAD_MARK_COPY_COUNT := 6
const LOAD_MARK_SIZE := Vector3(0.12, 0.42, 0.72)

## Seven childless shoulder service panels share one structure-material visual
## recipe. They own no collision, interaction, marker, evidence, or lifecycle
## authority, so one exterior-root batch preserves their exact authored copies.
const SERVICE_PANEL_COPY_COUNT := 7
const SERVICE_PANEL_SIZE := Vector3(0.1, 1.48, 2.45)

## Four childless landing-bogie feet are one identical structure-material visual
## recipe at fixed mirrored transforms. The ship-root collision envelope, berth
## fit and parked contact plane do not read these renderers, so one visual-only
## batch preserves all four drawn copies while removing three renderer nodes,
## submissions and private rounded-box mesh allocations.
const LANDING_BOGIE_FOOT_COPY_COUNT := 4
const LANDING_BOGIE_FOOT_SIZE := Vector3(1.65, 0.56, 2.2)

# Phase 9 allocation boundary. The five dorsal ribs each retain five ordinary
# MeshInstance3D curve joints and therefore all 25 authored draw submissions.
# Their geometry recipe and structure material are exact, so those nodes share
# one immutable SphereMesh instead of retaining 25 indistinguishable resources.
const DORSAL_CARGO_RIB_COUNT := 5
const DORSAL_CARGO_RIB_JOINTS_PER_RIB := 5
const DORSAL_CARGO_RIB_JOINT_COPY_COUNT := (
	DORSAL_CARGO_RIB_COUNT * DORSAL_CARGO_RIB_JOINTS_PER_RIB
)
const DORSAL_CARGO_RIB_JOINT_RADIUS := 0.095
const DORSAL_CARGO_RIB_JOINT_RADIAL_SEGMENTS := 24
const DORSAL_CARGO_RIB_JOINT_RINGS := 12
const DORSAL_CARGO_RIB_JOINT_XY: Array[Vector2] = [
	Vector2(-5.55, 4.28),
	Vector2(-3.7, 4.72),
	Vector2(0.0, 4.9),
	Vector2(3.7, 4.72),
	Vector2(5.55, 4.28),
]

# The three shoulder service rails retain their exact Node3D roots, seven
# ordinary MeshInstance3D joints, and seven surface submissions. The joint
# recipe and structural finish are identical, so only the immutable SphereMesh
# resource is shared.
const SHOULDER_RAIL_JOINT_COPY_COUNT := 7
const SHOULDER_RAIL_JOINT_RADIUS := 0.13
const SHOULDER_RAIL_JOINT_RADIAL_SEGMENTS := 24
const SHOULDER_RAIL_JOINT_RINGS := 12
const SHOULDER_RAIL_NAMES: Array[StringName] = [
	&"PortForwardShoulderRail",
	&"PortAftShoulderRail",
	&"StarboardShoulderRail",
]
const SHOULDER_RAIL_JOINT_POSITIONS: Array[Array] = [
	[Vector3(-5.85, 4.42, -3.0), Vector3(-5.85, 4.42, 0.95)],
	[Vector3(-5.85, 4.42, 5.48), Vector3(-5.85, 4.42, 8.1)],
	[
		Vector3(5.85, 4.42, -3.0),
		Vector3(5.85, 4.42, 1.0),
		Vector3(5.85, 4.42, 8.1),
	],
]

# Four interior cargo frames retain their exact roots, 20 ordinary named joint
# nodes, and 20 surface submissions inside the moving ship hierarchy. Their
# hull-cool geometry recipe is identical, so the immutable SphereMesh resource
# is shared without batching or moving any authored renderer node.
const CARGO_FRAME_COUNT := 4
const CARGO_FRAME_JOINTS_PER_FRAME := 5
const CARGO_FRAME_JOINT_COPY_COUNT := CARGO_FRAME_COUNT * CARGO_FRAME_JOINTS_PER_FRAME
const CARGO_FRAME_JOINT_RADIUS := 0.085
const CARGO_FRAME_JOINT_RADIAL_SEGMENTS := 24
const CARGO_FRAME_JOINT_RINGS := 12
const CARGO_FRAME_START_Z := -1.7
const CARGO_FRAME_Z_STEP := 3.25
const CARGO_FRAME_JOINT_XY: Array[Vector2] = [
	Vector2(-5.35, 0.72),
	Vector2(-5.35, 4.15),
	Vector2(0.0, 4.48),
	Vector2(5.35, 4.15),
	Vector2(5.35, 0.72),
]

const PARKED_RENDER_BOUNDS := AABB(Vector3(-10.6, -1.36, -14.1), Vector3(19.1, 6.31, 28.55))
const FLIGHT_COLLISION_BOUNDS := AABB(Vector3(-10.45, -1.45, -13.9), Vector3(18.55, 6.2, 26.2))

# One childless two-surface renderer carries a mirrored pair of forward cargo
# guide vanes plus their amber index faces. The long, converging forks make the
# negative-Z bow and the ship's freight role readable from the normal chase
# camera without adding collision, lights, interaction, cargo capacity, or a
# claim about the unknown historical silhouette. Every point stays inside the
# already published parked render envelope.
const FORWARD_CARGO_GUIDE_NAME: StringName = &"ForwardCargoGuideSilhouette"
const FORWARD_CARGO_GUIDE_STATUS: StringName = &"modern_provisional"
const FORWARD_CARGO_GUIDE_ROLE: StringName = &"forward_freight_index"
const FORWARD_CARGO_GUIDE_THICKNESS := 0.16
const FORWARD_CARGO_GUIDE_PORT_OUTLINE: Array[Vector3] = [
	Vector3(-5.45, 4.46, -2.80),
	Vector3(-6.15, 4.58, -3.75),
	Vector3(-8.18, 4.62, -11.35),
	Vector3(-7.15, 4.60, -10.72),
]
const FORWARD_CARGO_INDEX_THICKNESS := 0.08
const FORWARD_CARGO_INDEX_PORT_OUTLINE: Array[Vector3] = [
	Vector3(-5.70, 4.58, -3.25),
	Vector3(-6.00, 4.64, -3.90),
	Vector3(-7.77, 4.70, -10.55),
	Vector3(-7.38, 4.67, -10.28),
]
const PROVISIONAL_NOTE := (
	"Creator-supported facts (A3 page text): Jovian-class Light Freighter name "
	+ "and light-freighter role. No registered source ties any visible craft to "
	+ "the Jovian name, so the name-to-model mapping is unknown. "
	+ "The displayed geometry, dimensions, colours, cargo and "
	+ "passenger interior, ramp, cockpit access, capacity, systems, weapons, "
	+ "materials, and handling are modern provisional interpretation; no "
	+ "authenticated historical silhouette mapping is claimed."
)

# Fleet readability palette. The Jovian's name-to-model mapping is unknown and
# its palette is listed among its unknowns in docs/research/ship_evidence_matrix.json,
# so these are freely chosen modern hull tints picked to separate the freighter
# from the rest of the fleet under normal and dichromatic vision. See
# tests/fleet_role_differentiation_test.gd for the frozen separation floors.
# HULL_COOL keeps its name because `hull_cool` is the craft's stable public
# material-family key, asserted by tests/fleet_pbr_test.gd; it now carries the
# subordinate shade of the same warm clay family rather than a cool grey.
const HULL_WARM := Color("a9977e")
const HULL_COOL := Color("827766")
const JOVIAN_STRUCTURE := Color("283c42")
const JOVIAN_STRUCTURE_DARK := Color("0e2026")
const FREIGHT_TEAL := Color("35bbb5")
const FREIGHT_AMBER := Color("e9a844")
const CARGO_BLUE := Color("39798d")
const CABIN_CLOTH := Color("365259")
const DECK_GREY := Color("718084")
const ENGINE_AQUA := Color("70eee7")
const JOVIAN_NAV_RED := Color("ff635d")
const JOVIAN_NAV_GREEN := Color("70e995")

# A steady starboard-aft silhouette makes engine-bay impairment legible from
# the normal chase camera without another warning light or animated effect. The
# dark footprint and hot isolation blade sit entirely on AftHullCollision's
# upper face (y = 3.9) and consume only the existing component ledger stage.
const ENGINE_DAMAGE_CUE_COMPONENT_ID: StringName = &"engine_bay"
const ENGINE_DAMAGE_CUE_POSITION := Vector3(3.25, 3.92, 11.65)
const ENGINE_DAMAGE_SCORCH_SIZE := Vector3(2.15, 0.04, 1.05)
const ENGINE_DAMAGE_SCORCH_POSITION := Vector3(0.0, 0.0, 0.0)
const ENGINE_DAMAGE_VANE_SIZE := Vector3(1.55, 1.22, 0.16)
const ENGINE_DAMAGE_VANE_POSITION := Vector3(0.0, 0.61, 0.0)
const ENGINE_DAMAGE_SCORCH_COLOR := Color("171a19")
const ENGINE_DAMAGE_VANE_COLOR := Color("ff7438")

# Modern-provisional civilian defensive fit. These dimensions deliberately sit
# between the Arrow's light nose guns and gunship-scale hardware: broad mounts
# carry the visual load, while the short barrels end at the inherited firing
# markers and remain subordinate to the freighter hull.
const DEFENSIVE_TURRET_STATUS: StringName = &"modern_provisional"
const DEFENSIVE_TURRET_ROLE: StringName = &"freighter_defensive"
const DEFENSIVE_TURRET_MUZZLE_Z := -6.95
const DEFENSIVE_TURRET_BASE_RADIUS := 0.68
const DEFENSIVE_TURRET_BASE_HEIGHT := 0.38
const DEFENSIVE_TURRET_BARREL_RADIUS := 0.19
const DEFENSIVE_TURRET_BARREL_LENGTH := 1.55
const DEFENSIVE_TURRET_PART_SUFFIXES: Array[StringName] = [
	&"DefensiveTurretBase",
	&"DefensiveTurretRotationCollar",
	&"DefensiveTurretReceiver",
	&"DefensiveTurretBarrelShroud",
	&"DefensivePulseBarrel",
	&"DefensiveTurretMuzzleCollar",
	&"DefensiveTurretMuzzleLens",
]

var _fitout_mesh_cache: Dictionary = {}
var _jovian_built := false
var _jovian_visual: Node3D
var _jovian_materials: Dictionary = {}
var _walkable_interior: Node3D
var _cargo_bay: Node3D
var _passenger_cabin: Node3D
var _moving_interior_component: MovingInteriorFrame
var _occupant_volume: Area3D
var _interior_access_marker: Marker3D
var _interior_deck_marker: Marker3D
var _interior_exit_marker: Marker3D
var _cabin_stand_marker: Marker3D
var _interior_occupant_count := 0
var _cargo_hardpoints: Array[Marker3D] = []
var _passenger_seat_anchors: Array[Marker3D] = []
var _engine_cores: Array[MeshInstance3D] = []
var _engine_plumes: Array[MeshInstance3D] = []
var _jovian_engine_lights: Array[OmniLight3D] = []
var _engine_damage_cue: Node3D
var _dorsal_cargo_rib_joint_mesh: SphereMesh
var _shoulder_rail_joint_mesh: SphereMesh
var _cargo_frame_joint_mesh: SphereMesh
var _cargo_restraint_mesh: ArrayMesh
var _passenger_seat_base_mesh: ArrayMesh
var _passenger_seat_back_mesh: ArrayMesh
var _passenger_seat_harness_mesh: ArrayMesh
var _passenger_cabin_light_strip_mesh: ArrayMesh
var _cabin_portal_upright_mesh: ArrayMesh
var _cargo_ramp_edge_rail_mesh: ArrayMesh
var _cargo_ramp_actuator_mesh: ArrayMesh
var _cargo_ceiling_light_mesh: ArrayMesh
var _cargo_ceiling_light_batch: MultiMeshInstance3D
var _cargo_ceiling_light_transforms: Array[Transform3D] = []
var _load_mark_mesh: ArrayMesh
var _load_mark_batch: MultiMeshInstance3D
var _load_mark_transforms: Array[Transform3D] = []
var _service_panel_mesh: ArrayMesh
var _service_panel_batch: MultiMeshInstance3D
var _service_panel_transforms: Array[Transform3D] = []
var _landing_bogie_foot_mesh: ArrayMesh
var _landing_bogie_foot_batch: MultiMeshInstance3D
var _landing_bogie_foot_transforms: Array[Transform3D] = []
var _cargo_deck_lane_mesh: ArrayMesh
var _cargo_deck_lane_batch: MultiMeshInstance3D
var _cargo_deck_lane_transforms: Array[Transform3D] = []
var _elapsed_jovian := 0.0
var _crew_role_authority: CrewSeatRoleAuthority
var _engineer_component_selection: Dictionary = {}
var _engineer_component_generation := 1
var _engineer_repair_authority: RepairAuthority
var _engineer_repair_actor_id: StringName = &""
var _engineer_repair_elapsed := 0.0
var _engineer_repair_state: Dictionary = {
	"status": &"idle",
	"reason": &"",
	"component_id": &"",
	"component_generation": 0,
	"progress": 0.0,
}
var _engineer_status_readout: Label3D
# Constructed through the explicit preload above so a clean checkout does not
# need this new presentation class in Godot's generated global-class cache
# before JovianLightFreighter itself can parse.
var _engineer_repair_console
var _engineer_console_generation := 0
var _engineer_console_sequence := -1
var _engineer_repair_presentation
var _engineer_presentation_generation := 0
var _engineer_presentation_sequence := -1
var _engineer_repair_audio
var _engineer_audio_generation := 0
var _engineer_audio_sequence := -1
var _copilot_navigation_receipt: Dictionary = {}
var _copilot_navigation_generation := 1
var _ship_perspective_audio_binding: RefCounted
var _copilot_navigation_audio_binding: RefCounted

signal engineer_component_selected(component_id: StringName, component_generation: int, receipt: Dictionary)
signal engineer_component_cleared(component_id: StringName, component_generation: int, reason: StringName)
signal engineer_repair_state_changed(snapshot: Dictionary)
signal copilot_navigation_intent_accepted(receipt: Dictionary)
signal copilot_navigation_intent_cleared(generation: int, reason: StringName)


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _enter_tree() -> void:
	super._enter_tree()
	call_deferred("_sync_jovian_engine_presentation_immediately")
	if _engineer_repair_console != null:
		call_deferred("_rebind_engineer_repair_console")
	if _engineer_repair_presentation != null:
		call_deferred("_rebind_engineer_repair_presentation")
	if _engineer_repair_audio != null:
		call_deferred("_rebind_engineer_repair_audio")
	if _ship_perspective_audio_binding != null:
		call_deferred("_rebind_jovian_perspective_audio")
	if _copilot_navigation_audio_binding != null:
		call_deferred("_rebind_copilot_navigation_audio")


func _ready() -> void:
	super._ready()
	_ship_perspective_audio_binding = ShipPerspectiveAudioBindingType.new()
	_copilot_navigation_audio_binding = JovianCopilotNavigationAudioBindingType.new()
	_copilot_navigation_audio_binding.attach()
	var perspective_result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(perspective_result.get("accepted", false)):
		camera_view_changed.connect(_on_jovian_camera_view_changed)
	else:
		_ship_perspective_audio_binding = null
	if not copilot_navigation_intent_cleared.is_connected(_on_copilot_navigation_audio_cleared):
		copilot_navigation_intent_cleared.connect(_on_copilot_navigation_audio_cleared)
	if not _jovian_built:
		_jovian_built = rebuild_variant_presentation(_build_jovian_variant)
	if _jovian_built:
		_jovian_built = _reconfigure_component_damage_from_final_root_collision()
	if _jovian_built:
		_build_engineer_repair_audio()
	if _jovian_built:
		_build_engineer_repair_presentation()
	if not component_damage_changed.is_connected(_on_jovian_component_damage_changed):
		component_damage_changed.connect(_on_jovian_component_damage_changed)
	_sync_engine_damage_cue()
	_apply_jovian_metadata()
	_sync_jovian_engine_presentation_immediately()


func _exit_tree() -> void:
	_set_jovian_engine_presentation_inactive()
	_interrupt_engineer_repair(&"ship_detached")
	if _engineer_repair_presentation != null:
		var detached: Dictionary = _engineer_repair_presentation.detach(
			_engineer_presentation_generation
		)
		if bool(detached.get("accepted", false)):
			_engineer_presentation_generation += 1
			_engineer_presentation_sequence = -1
	if _engineer_repair_audio != null:
		var audio_detached: Dictionary = _engineer_repair_audio.detach()
		if bool(audio_detached.get("accepted", false)):
			_engineer_audio_generation = int(audio_detached.get(
				"generation", _engineer_audio_generation + 1
			))
			_engineer_audio_sequence = -1
	if _engineer_repair_console != null:
		_engineer_repair_console.detach()
		_engineer_console_generation += 1
		_engineer_console_sequence = -1
	_clear_copilot_navigation_state(&"ship_detached")
	if _ship_perspective_audio_binding != null:
		if camera_view_changed.is_connected(_on_jovian_camera_view_changed):
			camera_view_changed.disconnect(_on_jovian_camera_view_changed)
		_ship_perspective_audio_binding.detach()
	if _copilot_navigation_audio_binding != null:
		if copilot_navigation_intent_cleared.is_connected(_on_copilot_navigation_audio_cleared):
			copilot_navigation_intent_cleared.disconnect(_on_copilot_navigation_audio_cleared)
		_copilot_navigation_audio_binding.detach()
	super._exit_tree()


func _rebind_jovian_perspective_audio() -> void:
	if not is_inside_tree() or _ship_perspective_audio_binding == null \
			or _ship_audio_rig == null or not is_instance_valid(_ship_audio_rig):
		return
	var snapshot: Dictionary = _ship_perspective_audio_binding.get_snapshot()
	if bool(snapshot.get("attached", false)):
		return
	var result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(result.get("accepted", false)) \
		and not camera_view_changed.is_connected(_on_jovian_camera_view_changed):
		camera_view_changed.connect(_on_jovian_camera_view_changed)


func _rebind_engineer_repair_console() -> void:
	if not is_inside_tree() or _engineer_repair_console == null \
			or _engineer_status_readout == null or not is_instance_valid(_engineer_status_readout):
		return
	var snapshot: Dictionary = _engineer_repair_console.get_snapshot()
	if not bool(snapshot.get("attached", false)):
		_engineer_repair_console.bind(_engineer_status_readout, _engineer_console_generation)
		# The retained console may re-observe the authoritative terminal state, but
		# work presenters must stay fresh and empty until a new repair is admitted.
		_refresh_engineer_status_readout(false)


func _rebind_engineer_repair_presentation() -> void:
	if not is_inside_tree() or _engineer_repair_presentation == null:
		return
	var snapshot: Dictionary = _engineer_repair_presentation.get_snapshot()
	if bool(snapshot.get("attached", false)):
		return
	var attached: Dictionary = _engineer_repair_presentation.attach(
		_engineer_presentation_generation
	)
	if not bool(attached.get("accepted", false)):
		return


func _rebind_engineer_repair_audio() -> void:
	if not is_inside_tree() or _engineer_repair_audio == null:
		return
	var snapshot: Dictionary = _engineer_repair_audio.get_snapshot()
	if bool(snapshot.get("attached", false)):
		return
	_engineer_audio_generation = int(snapshot.get("generation", _engineer_audio_generation))
	_engineer_audio_sequence = -1
	_engineer_repair_audio.attach(_engineer_audio_generation)


func _rebind_copilot_navigation_audio() -> void:
	if not is_inside_tree() or _copilot_navigation_audio_binding == null:
		return
	var snapshot: Dictionary = _copilot_navigation_audio_binding.get_snapshot()
	if not bool(snapshot.get("attached", false)):
		_copilot_navigation_audio_binding.attach(int(snapshot.get("generation", 0)))
	if camera_view_changed.is_connected(_on_jovian_camera_view_changed):
		_on_jovian_camera_view_changed(get_camera_view())


func _on_jovian_camera_view_changed(view: StringName) -> void:
	if _ship_perspective_audio_binding == null:
		return
	var perspective: StringName = &"cockpit" if view == CAMERA_VIEW_COCKPIT else &"exterior"
	var generation := int(_ship_perspective_audio_binding.get_snapshot().get("generation", -1))
	_ship_perspective_audio_binding.present_perspective(perspective, generation)
	if _copilot_navigation_audio_binding != null:
		_copilot_navigation_audio_binding.present_perspective(perspective)


func _on_copilot_navigation_audio_cleared(generation: int, reason: StringName) -> void:
	if _copilot_navigation_audio_binding != null:
		_copilot_navigation_audio_binding.present_cleared(generation, reason)


func get_copilot_navigation_audio_snapshot() -> Dictionary:
	return _copilot_navigation_audio_binding.get_snapshot() \
		if _copilot_navigation_audio_binding != null else {"attached": false}


func _present_copilot_navigation_result(result: Dictionary) -> void:
	if _copilot_navigation_audio_binding == null:
		return
	if bool(result.get("accepted", false)):
		var effect := result.get("effect", {}) as Dictionary
		var receipt := effect.get("receipt", {}) as Dictionary
		if not receipt.is_empty():
			_copilot_navigation_audio_binding.present_accepted_receipt(receipt)
	else:
		_copilot_navigation_audio_binding.present_rejected_result(result)


func get_ship_perspective_audio_snapshot() -> Dictionary:
	return _ship_perspective_audio_binding.get_snapshot() \
		if _ship_perspective_audio_binding != null else {"attached": false}


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _reset_for_reuse_mutation_blocked():
		return
	_advance_engineer_repair(maxf(delta, 0.0))
	_cleanup_detached_engineer_state()
	_elapsed_jovian += delta
	_update_jovian_presentation(delta)


func apply_damage(
		amount: float,
		world_hit_position: Vector3 = Vector3.INF,
		world_hit_normal: Vector3 = Vector3.ZERO,
		presentation_receipt_id: int = -1,
		defer_presentation: bool = false
	) -> void:
	super.apply_damage(
		amount,
		world_hit_position,
		world_hit_normal,
		presentation_receipt_id,
		defer_presentation
	)
	if is_destroyed():
		_clear_engineer_component_selection(&"ship_destroyed")
		_clear_copilot_navigation_state(&"ship_destroyed")
		_set_interior_operational(false)


func _preflight_variant_reset_for_reuse(spawn_transform: Transform3D) -> Dictionary:
	return super._preflight_variant_reset_for_reuse(spawn_transform)


func _commit_variant_reset_for_reuse(context: Dictionary) -> void:
	super._commit_variant_reset_for_reuse(context)
	_sync_engine_damage_cue()
	_clear_engineer_component_selection(&"ship_reused", false)
	_engineer_component_generation = 1
	_reset_engineer_repair_state()
	_restart_engineer_console_presentation()
	_restart_engineer_work_presentation()
	_restart_engineer_repair_audio_presentation()
	_clear_copilot_navigation_state(&"ship_reused")
	_copilot_navigation_generation = 1
	_set_interior_operational(true)
	if _moving_interior_component != null:
		_moving_interior_component.configure(self, INTERIOR_BOUNDS, _occupant_volume)
		_moving_interior_component.reset_frame_tracking(true)


## The complete visible freighter hierarchy used by the common presentation
## lifecycle. Its `WalkableInterior` child stays attached while the ship moves.
func get_jovian_visual_root() -> Node3D:
	return _jovian_visual


## Stable local combat registry identity reserved for this physical candidate.
## The shared combat authority remains the owner of actual registration.
func get_combat_source_id() -> int:
	return COMBAT_SOURCE_ID


## Stable ship-local hierarchy containing the deck, rooms, lights, fixtures,
## access aperture, and semantic markers of the connected interior.
func get_interior_root() -> Node3D:
	return _walkable_interior


## Registration frame for moving-interior occupant stabilisation. This returns
## a Node3D rather than a concrete component type so the ship contract remains
## usable before or without multiplayer motion compensation.
func get_interior_frame() -> Node3D:
	return self


## Typed coordinator for occupant registration, frame-delta compensation, and
## inertial exit velocity. It is separate from the spatial frame by design.
func get_moving_interior_component() -> MovingInteriorFrame:
	return _moving_interior_component


func get_cargo_bay_root() -> Node3D:
	return _cargo_bay


func get_passenger_cabin_root() -> Node3D:
	return _passenger_cabin


## Detached presentation snapshot. The cue reports the existing engine-bay
## ledger stage and retained geometry but exposes no damage or repair mutation.
func get_engine_damage_cue_snapshot() -> Dictionary:
	var cue := _engine_damage_cue
	var scorch := cue.get_node_or_null(^"EngineBreachScorch") as MeshInstance3D \
		if cue != null else null
	var vane := cue.get_node_or_null(^"EngineIsolationBlade") as MeshInstance3D \
		if cue != null else null
	var bounds := AABB()
	var has_bounds := false
	for renderer in [scorch, vane]:
		if renderer == null or renderer.mesh == null or cue == null:
			continue
		var renderer_bounds: AABB = cue.transform * renderer.transform * renderer.mesh.get_aabb()
		bounds = renderer_bounds if not has_bounds else bounds.merge(renderer_bounds)
		has_bounds = true
	var model := get_component_damage()
	return {
		"component_id": ENGINE_DAMAGE_CUE_COMPONENT_ID,
		"stage": ShipComponentDamageType.state_id_for(
			model.get_component_state(ENGINE_DAMAGE_CUE_COMPONENT_ID)
		) if model != null and model.is_configured() else &"unavailable",
		"visible": cue.visible if cue != null else false,
		"local_bounds": bounds,
		"supported_surface_y": 3.9,
		"processes": false,
		"flashes": false,
		"damage_authority": false,
		"repair_authority": false,
	}.duplicate(true)


func get_interior_access_marker() -> Marker3D:
	return _interior_access_marker


func get_interior_deck_marker() -> Marker3D:
	return _interior_deck_marker


## World-space safe transform beyond the deployed ramp. This is intentionally
## distinct from HeroShip.get_exit_transform(), which serves the pilot seat.
func get_interior_exit_transform() -> Transform3D:
	if _interior_exit_marker == null:
		return Transform3D(global_basis.orthonormalized(), global_position)
	return _interior_exit_marker.global_transform


## Pressurised/walkable cabin envelope in ship-local coordinates. The deployed
## exterior ramp is deliberately outside this box.
func get_interior_bounds() -> AABB:
	return INTERIOR_BOUNDS


## World-space standing pose a pilot arrives at when leaving the seat under way.
func get_cabin_stand_transform() -> Transform3D:
	if _cabin_stand_marker == null:
		return global_transform.translated_local(CABIN_STAND_LOCAL_ORIGIN)
	return Transform3D(
		_cabin_stand_marker.global_basis.orthonormalized(),
		_cabin_stand_marker.global_position
	)


## `modern_interpretation`. The freighter is the one craft in the fleet with a
## connected, bounded, physically walkable cabin, so it is the one craft whose
## pilot may stand up while it is away from a berth. A destroyed or
## un-instantiated interior withdraws the offer rather than opening a hatch onto
## nothing.
func get_in_flight_cabin_report() -> Dictionary:
	var ready := (
		not is_destroyed()
		and is_instance_valid(_walkable_interior)
		and is_instance_valid(_moving_interior_component)
		and _moving_interior_component.get_moving_frame() == self
	)
	return {
		"supported": ready,
		"status": &"walkable_cabin" if ready else &"interior_unavailable",
		"frame": _moving_interior_component,
		"stand_transform": get_cabin_stand_transform(),
		"local_bounds": CABIN_MOVEMENT_BOUNDS,
	}


## Number of occupants the interior coordinator is currently carrying. Exposed
## for tests and for the multi-occupant work that comes later; the hull's own
## collision response reads it rather than assuming a single crew member.
func get_interior_occupant_count() -> int:
	return _interior_occupant_count


## Typed clearance contract for a berth or landing planner. These are bounds of
## this provisional implementation, not evidence about the historical Jovian.
func get_berth_clearance_report() -> Dictionary:
	return {
		"schema_version": 1,
		"home_berth_id": get_home_berth_id(),
		"parked_render_bounds": PARKED_RENDER_BOUNDS,
		"flight_collision_bounds": FLIGHT_COLLISION_BOUNDS,
		"ramp_side": &"port",
		"ramp_local_direction": Vector3.LEFT,
		"landing_contact_y": -1.25,
		"deployed_ramp_may_overlap_apron": true,
		"provisional": true,
	}


func get_cargo_hardpoints() -> Array[Marker3D]:
	return _cargo_hardpoints.duplicate()


func get_passenger_seat_anchors() -> Array[Marker3D]:
	return _passenger_seat_anchors.duplicate()


## The port passenger seat is the optional physical systems station for this
## freighter. It remains a normal ship-owned anchor; role admission is still
## delegated to the injected CrewSeatRoleAuthority.
func get_engineer_seat_anchor() -> Marker3D:
	for anchor in _passenger_seat_anchors:
		if StringName(anchor.get_meta("seat_id", &"")) == ENGINEER_SEAT_ID:
			return anchor
	return null


## Physical cockpit-side station for the freighter's optional navigation
## support role. The role ledger remains caller-owned; this anchor only names
## the seat that may submit navigation-route receipts.
func get_copilot_seat_anchor() -> Marker3D:
	var cockpit := _walkable_interior.get_node_or_null(^"CockpitInterior") as Node3D \
		if _walkable_interior != null else null
	return cockpit.get_node_or_null(^"CopilotSeatAnchor") as Marker3D \
		if cockpit != null else null


## Binds the injected role ledger. Jovian consumes only its pilot and engineer
## entries; it never creates a second occupancy or repair ledger.
func attach_crew_role_authority(authority: CrewSeatRoleAuthority) -> Dictionary:
	if authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	if _crew_role_authority != null and _crew_role_authority != authority:
		return _crew_role_result(false, &"authority_already_attached")
	var snapshot := authority.get_snapshot()
	if not bool(snapshot.get("roster_sealed", false)):
		return _crew_role_result(false, &"roster_not_sealed")
	var has_pilot := false
	var has_engineer := false
	var has_copilot := false
	for seat_variant in snapshot.get("seats", []) as Array:
		if not seat_variant is Dictionary:
			continue
		var seat := seat_variant as Dictionary
		if StringName(seat.get("vessel_id", &"")) != get_ship_id():
			continue
		if StringName(seat.get("seat_id", &"")) == PILOT_SEAT_ID \
				and StringName(seat.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PILOT:
			has_pilot = true
		if StringName(seat.get("seat_id", &"")) == ENGINEER_SEAT_ID \
				and StringName(seat.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_ENGINEER:
			has_engineer = true
		if StringName(seat.get("seat_id", &"")) == COPILOT_SEAT_ID \
				and StringName(seat.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PASSENGER:
			has_copilot = true
	if not has_pilot or not has_engineer or not has_copilot \
			or get_copilot_seat_anchor() == null:
		return _crew_role_result(false, &"jovian_roster_mismatch")
	_crew_role_authority = authority
	var result := _crew_role_result(true, &"authority_attached")
	result["role_count"] = (snapshot.get("seats", []) as Array).size()
	return result


func get_crew_role_authority() -> CrewSeatRoleAuthority:
	return _crew_role_authority


## Admits one engineer receipt and routes it to ShipComponentDamage's existing
## owner-controlled repair pulse. The role consumer owns no health dictionary,
## movement, combat, or lifecycle authority.
func submit_crew_intent(
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		action: StringName,
		payload: Dictionary,
		request_sequence: int
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var assignment := _crew_role_authority.get_assignment(occupant_peer_id, avatar_id)
	if assignment.is_empty():
		return _crew_role_result(false, &"assignment_not_found")
	if StringName(assignment.get("vessel_id", &"")) != get_ship_id():
		return _crew_role_result(false, &"foreign_vessel")
	if StringName(assignment.get("role", &"")) != CrewRoleGameplayProfileType.ROLE_ENGINEER \
			or StringName(assignment.get("seat_id", &"")) != ENGINEER_SEAT_ID \
			or action != CrewRoleGameplayProfileType.ACTION_ENGINEER_REPAIR:
		if StringName(assignment.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PASSENGER \
				and StringName(assignment.get("seat_id", &"")) == COPILOT_SEAT_ID \
				and action == CrewRoleGameplayProfileType.ACTION_PASSENGER_PING:
			var navigation_admission := _crew_role_authority.submit_intent(
				source_peer_id,
				occupant_peer_id,
				avatar_id,
				action,
				payload,
				request_sequence
			)
			if not bool(navigation_admission.get("accepted", false)):
				_present_copilot_navigation_result(navigation_admission)
				return navigation_admission
			var navigation_effect := _consume_copilot_navigation_intent(
				navigation_admission.get("intent", {}) as Dictionary
			)
			var navigation_result := navigation_admission.duplicate(true)
			navigation_result["status"] = (
				&"intent_consumed" if bool(navigation_effect.get("accepted", false))
				else &"intent_effect_rejected"
			)
			navigation_result["consumed"] = bool(navigation_effect.get("accepted", false))
			navigation_result["effect"] = navigation_effect
			_present_copilot_navigation_result(navigation_result)
			return navigation_result
		return _crew_role_result(false, &"unsupported_jovian_role_action")
	var admission := _crew_role_authority.submit_intent(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		action,
		payload,
		request_sequence
	)
	if not bool(admission.get("accepted", false)):
		return admission
	var effect := _consume_engineer_repair_intent(admission.get("intent", {}) as Dictionary)
	var result := admission.duplicate(true)
	result["status"] = &"intent_consumed" if bool(effect.get("accepted", false)) else &"intent_effect_rejected"
	result["consumed"] = bool(effect.get("accepted", false))
	result["effect"] = effect
	return result


func release_crew_role(
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		seat_id: StringName,
		request_sequence: int,
		seat_generation: int = 0
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var result := _crew_role_authority.release(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		seat_id,
		request_sequence,
		seat_generation
	)
	if bool(result.get("accepted", false)):
		_clear_engineer_component_state(occupant_peer_id, avatar_id, &"role_released")
		_clear_copilot_navigation_state_for_actor(occupant_peer_id, avatar_id, &"role_released")
	return result


func handoff_crew_role(
		source_peer_id: int,
		previous_occupant_peer_id: int,
		previous_avatar_id: StringName,
		seat_id: StringName,
		release_request_sequence: int,
		new_occupant_peer_id: int,
		new_avatar_id: StringName,
		requested_role: StringName,
		claim_request_sequence: int,
		seat_generation: int = 0
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var result := _crew_role_authority.handoff(
		source_peer_id,
		previous_occupant_peer_id,
		previous_avatar_id,
		seat_id,
		release_request_sequence,
		new_occupant_peer_id,
		new_avatar_id,
		requested_role,
		claim_request_sequence,
		seat_generation
	)
	if bool(result.get("accepted", false)):
		_clear_engineer_component_state(previous_occupant_peer_id, previous_avatar_id, &"role_handoff")
		_clear_copilot_navigation_state_for_actor(previous_occupant_peer_id, previous_avatar_id, &"role_handoff")
	return result


func get_engineer_gameplay_state() -> Dictionary:
	var repair := get_engineer_repair_state()
	return {
		"schema_version": 1,
		"authority_attached": _crew_role_authority != null,
		"component_generation": _engineer_component_generation,
		"selection": _engineer_component_selection.duplicate(true),
		"repair": repair,
		"repair_ready": not is_destroyed()
			and bool(get_telemetry().get("landed", false))
			and not bool(get_telemetry().get("landing_active", false))
			and not _engineer_component_selection.is_empty()
			and bool(repair.get("cooldown_ready", false))
			and bool(repair.get("resource_ready", false))
			and not bool(repair.get("active", false)),
	}.duplicate(true)


## Detached navigation-support state. Cargo and berth values are read-only
## observations; this role never steers, throttles, fires, mutates cargo, or
## claims a helm/landing lease.
func get_copilot_navigation_state() -> Dictionary:
	var telemetry := get_telemetry()
	return {
		"schema_version": 1,
		"role": COPILOT_ROLE_ID,
		"seat_id": COPILOT_SEAT_ID,
		"authority_attached": _crew_role_authority != null,
		"navigation_generation": _copilot_navigation_generation,
		"receipt": _copilot_navigation_receipt.duplicate(true),
		"cargo_status": {
			"hardpoint_count": _cargo_hardpoints.size(),
			"secured": _cargo_hardpoints.size() == CARGO_UNIT_ANCHORS.size(),
			"mutation_authority": false,
		},
		"berth_status": {
			"home_berth_id": get_home_berth_id(),
			"landed": bool(telemetry.get("landed", false)),
			"landing_active": bool(telemetry.get("landing_active", false)),
			"lease_authority": false,
		},
		"authority": {
			"navigation": false,
			"movement": false,
			"throttle": false,
			"fire": false,
			"cargo": false,
			"helm": false,
		},
	}.duplicate(true)


func _consume_copilot_navigation_intent(intent: Dictionary) -> Dictionary:
	var payload := intent.get("payload", {}) as Dictionary
	if StringName(payload.get("channel", &"")) != COPILOT_NAVIGATION_CHANNEL:
		return _crew_role_result(false, &"unsupported_navigation_channel")
	if is_destroyed():
		return _crew_role_result(false, &"ship_destroyed")
	var receipt := {
		"role": COPILOT_ROLE_ID,
		"seat_id": COPILOT_SEAT_ID,
		"occupant_peer_id": int(intent.get("occupant_peer_id", 0)),
		"avatar_id": StringName(intent.get("avatar_id", &"")),
		"seat_generation": int(intent.get("seat_generation", 0)),
		"request_sequence": int(intent.get("request_sequence", -1)),
		"navigation_generation": _copilot_navigation_generation,
		"route_id": StringName(payload.get("marker_id", &"")),
		"target_id": StringName(payload.get("marker_id", &"")),
		"cargo_status": get_copilot_navigation_state().get("cargo_status", {}).duplicate(true),
		"berth_status": get_copilot_navigation_state().get("berth_status", {}).duplicate(true),
	}.duplicate(true)
	_copilot_navigation_receipt = receipt
	copilot_navigation_intent_accepted.emit(receipt.duplicate(true))
	var result := _crew_role_result(true, &"navigation_receipt_accepted")
	result["receipt"] = receipt.duplicate(true)
	return result


func _clear_copilot_navigation_state_for_actor(
	occupant_peer_id: int,
	avatar_id: StringName,
	reason: StringName
) -> void:
	if not _copilot_navigation_receipt.is_empty() \
			and int(_copilot_navigation_receipt.get("occupant_peer_id", 0)) == occupant_peer_id \
			and StringName(_copilot_navigation_receipt.get("avatar_id", &"")) == avatar_id:
		_clear_copilot_navigation_state(reason)


func _clear_copilot_navigation_state(reason: StringName) -> void:
	_copilot_navigation_receipt.clear()
	_copilot_navigation_generation = mini(_copilot_navigation_generation + 1, 1_000_000)
	copilot_navigation_intent_cleared.emit(_copilot_navigation_generation, reason)


func _consume_engineer_repair_intent(intent: Dictionary) -> Dictionary:
	var payload := intent.get("payload", {}) as Dictionary
	var component_id := StringName(payload.get("system_id", &""))
	var requested_repair := float(payload.get("repair", 0.0))
	var component_generation := int(payload.get("system_generation", 0))
	var model := get_component_damage()
	if model == null or not model.is_configured():
		return _crew_role_result(false, &"component_damage_unavailable")
	var telemetry := get_telemetry()
	if bool(telemetry.get("destroyed", false)):
		return _crew_role_result(false, &"ship_destroyed")
	if not bool(telemetry.get("landed", false)) or bool(telemetry.get("landing_active", false)):
		return _crew_role_result(false, &"repair_requires_berthed_ship")
	var report := model.get_component_report()
	var order: Array = report.get("component_order", []) as Array
	if not order.has(component_id):
		return _crew_role_result(false, &"foreign_component")
	if component_generation != _engineer_component_generation:
		return _crew_role_result(false, &"stale_component_generation")
	var before := model.get_component_integrity(component_id)
	if before < 0.0:
		return _crew_role_result(false, &"foreign_component")
	if before >= 1.0:
		return _crew_role_result(false, &"healthy_component")
	if requested_repair <= 0.0:
		return _select_engineer_component(intent, component_id, component_generation)
	var prepared := _prepare_engineer_repair_authority(intent, model)
	if not bool(prepared.get("accepted", false)):
		return prepared
	var repair_request := _engineer_repair_authority.request_repair({
		"actor_id": _engineer_repair_actor_id,
		"target_id": get_ship_id(),
		"component_id": component_id,
		"generation": model.get_ledger_generation(),
		"distance_meters": 0.0,
		"seated": true,
		"resource_id": ENGINEER_REPAIR_RESOURCE_ID,
		"interrupted": false,
		"repair": requested_repair,
	})
	if not bool(repair_request.get("accepted", false)):
		var rejected := _crew_role_result(
			false,
			StringName(repair_request.get("reason", &"repair_not_started"))
		)
		rejected["repair"] = repair_request
		return rejected
	var selection := _select_engineer_component(intent, component_id, component_generation)
	if not bool(selection.get("accepted", false)):
		_engineer_repair_authority.interrupt(&"selection_rejected")
		return selection
	_engineer_repair_elapsed = 0.0
	_set_engineer_repair_state({
		"status": &"repairing",
		"reason": &"",
		"component_id": component_id,
		"component_generation": component_generation,
		"progress": 0.0,
		"token": int(repair_request.get("token", -1)),
		"receipt": repair_request.duplicate(true),
	})
	var result := _crew_role_result(true, &"repair_started")
	result["component_id"] = component_id
	result["integrity_before"] = before
	result["repair"] = repair_request
	result["selection"] = selection
	result["repair_state"] = get_engineer_repair_state()
	return result


func _select_engineer_component(
		intent: Dictionary,
		component_id: StringName,
		component_generation: int
) -> Dictionary:
	var selection := {
		"component_id": component_id,
		"component_generation": component_generation,
		"occupant_peer_id": int(intent.get("occupant_peer_id", 0)),
		"avatar_id": StringName(intent.get("avatar_id", &"")),
		"seat_generation": int(intent.get("seat_generation", 0)),
		"request_sequence": int(intent.get("request_sequence", -1)),
	}
	_engineer_component_selection = selection
	# Selection is an admission precursor, not a new repair presentation state.
	# Keep the console current, then let the accepted `repairing` transition below
	# publish the first fresh work/audio snapshot atomically.
	_refresh_engineer_status_readout(false)
	engineer_component_selected.emit(
		component_id,
		component_generation,
		selection.duplicate(true)
	)
	var result := _crew_role_result(true, &"component_selected")
	result["selection"] = selection.duplicate(true)
	return result


func _prepare_engineer_repair_authority(
	intent: Dictionary,
	model: ShipComponentDamage
) -> Dictionary:
	var actor_id := StringName("peer_%d" % int(intent.get("occupant_peer_id", 0)))
	var ledger_generation := model.get_ledger_generation()
	if _engineer_repair_authority != null \
			and _engineer_repair_authority.get_generation() == ledger_generation:
		if _engineer_repair_actor_id == actor_id:
			return _crew_role_result(true, &"repair_authority_ready")
		if _engineer_repair_authority.has_active_repair():
			_interrupt_engineer_repair(&"repair_actor_changed")
		var rebound := _engineer_repair_authority.rebind_actor(
			actor_id, ledger_generation
		)
		if not bool(rebound.get("accepted", false)):
			var rejected := _crew_role_result(
				false,
				StringName(rebound.get("reason", &"repair_actor_rebind_rejected"))
			)
			rejected["repair"] = rebound.duplicate(true)
			return rejected
		_engineer_repair_actor_id = actor_id
		return _crew_role_result(true, &"repair_authority_rebound")
	if _engineer_repair_authority != null \
			and _engineer_repair_authority.has_active_repair():
		_interrupt_engineer_repair(&"repair_actor_changed")
	_engineer_repair_authority = RepairAuthorityType.new(
		actor_id,
		get_ship_id(),
		ENGINEER_REPAIR_RESOURCE_ID,
		1.0,
		ENGINEER_REPAIR_COOLDOWN_SECONDS,
		1.0,
		ENGINEER_REPAIR_RESOURCE_CAPACITY
	) as RepairAuthority
	_engineer_repair_actor_id = actor_id
	if _engineer_repair_authority == null \
			or not _engineer_repair_authority.is_configuration_valid():
		_reset_engineer_repair_state()
		return _crew_role_result(false, &"repair_authority_unavailable")
	var begun := _engineer_repair_authority.begin_generation(ledger_generation)
	if not bool(begun.get("accepted", false)):
		_reset_engineer_repair_state()
		return _crew_role_result(
			false,
			StringName(begun.get("reason", &"repair_generation_rejected"))
		)
	return _crew_role_result(true, &"repair_authority_ready")


func _advance_engineer_repair(delta: float) -> void:
	if _engineer_repair_authority == null:
		return
	var had_cooldown := _engineer_repair_authority.get_cooldown_remaining() > 0.0
	_engineer_repair_authority.advance(delta)
	if not _engineer_repair_authority.has_active_repair():
		if had_cooldown:
			_refresh_engineer_status_readout()
		return
	var interruption := _engineer_repair_interruption_reason()
	if not interruption.is_empty():
		_interrupt_engineer_repair(interruption)
		return
	_engineer_repair_elapsed = minf(
		_engineer_repair_elapsed + delta,
		ENGINEER_REPAIR_DURATION_SECONDS
	)
	var progress := clampf(
		_engineer_repair_elapsed / ENGINEER_REPAIR_DURATION_SECONDS,
		0.0,
		1.0
	)
	_engineer_repair_state["progress"] = progress
	if progress < 1.0:
		engineer_repair_state_changed.emit(get_engineer_repair_state())
		_refresh_engineer_status_readout()
		return
	var model := get_component_damage()
	var token := int(_engineer_repair_state.get("token", -1))
	var committed := _engineer_repair_authority.commit_component_repair(model, token)
	if not bool(committed.get("accepted", false)):
		var commit_reason := StringName(
			committed.get("reason", &"repair_commit_rejected")
		)
		if commit_reason == &"component_not_damaged":
			_set_engineer_repair_state({
				"status": &"completed",
				"reason": &"berth_repair_completed",
				"component_id": StringName(
					_engineer_repair_state.get("component_id", &"")
				),
				"component_generation": int(
					_engineer_repair_state.get("component_generation", 0)
				),
				"progress": 1.0,
			})
			return
		_set_engineer_repair_state({
			"status": &"interrupted",
			"reason": commit_reason,
			"component_id": StringName(_engineer_repair_state.get("component_id", &"")),
			"component_generation": int(
				_engineer_repair_state.get("component_generation", 0)
			),
			"progress": progress,
		})
		return
	_set_engineer_repair_state({
		"status": &"completed",
		"reason": &"repair_committed",
		"component_id": StringName(_engineer_repair_state.get("component_id", &"")),
		"component_generation": int(_engineer_repair_state.get("component_generation", 0)),
		"progress": 1.0,
		"receipt": committed.duplicate(true),
	})


func _engineer_repair_interruption_reason() -> StringName:
	var telemetry := get_telemetry()
	if bool(telemetry.get("destroyed", false)):
		return &"ship_destroyed"
	if not bool(telemetry.get("landed", false)) \
			or bool(telemetry.get("landing_active", false)):
		return &"left_berth"
	if _engineer_component_selection.is_empty():
		return &"selection_lost"
	if StringName(_engineer_component_selection.get("component_id", &"")) \
			!= StringName(_engineer_repair_state.get("component_id", &"")) \
			or int(_engineer_component_selection.get("component_generation", 0)) \
			!= int(_engineer_repair_state.get("component_generation", 0)):
		return &"selection_changed"
	if _crew_role_authority == null:
		return &"authority_detached"
	var assignment := _crew_role_authority.get_assignment(
		int(_engineer_component_selection.get("occupant_peer_id", 0)),
		StringName(_engineer_component_selection.get("avatar_id", &""))
	)
	if StringName(assignment.get("role", &"")) != CrewRoleGameplayProfileType.ROLE_ENGINEER \
			or StringName(assignment.get("seat_id", &"")) != ENGINEER_SEAT_ID:
		return &"engineer_seat_lost"
	var model := get_component_damage()
	if model == null \
			or model.get_ledger_generation() != _engineer_repair_authority.get_generation():
		return &"component_generation_changed"
	return &""


func _interrupt_engineer_repair(reason: StringName) -> void:
	if _engineer_repair_authority == null \
			or not _engineer_repair_authority.has_active_repair():
		return
	var interruption_receipt := _engineer_repair_authority.interrupt(reason)
	_set_engineer_repair_state({
		"status": &"interrupted",
		"reason": reason,
		"component_id": StringName(_engineer_repair_state.get("component_id", &"")),
		"component_generation": int(_engineer_repair_state.get("component_generation", 0)),
		"progress": float(_engineer_repair_state.get("progress", 0.0)),
		"token": int(_engineer_repair_state.get("token", -1)),
		"receipt": interruption_receipt.duplicate(true),
	})


func _set_engineer_repair_state(state: Dictionary) -> void:
	_engineer_repair_state = state.duplicate(true)
	engineer_repair_state_changed.emit(get_engineer_repair_state())
	_refresh_engineer_status_readout()


func _reset_engineer_repair_state() -> void:
	_engineer_repair_authority = null
	_engineer_repair_actor_id = &""
	_engineer_repair_elapsed = 0.0
	_engineer_repair_state = {
		"status": &"idle",
		"reason": &"",
		"component_id": &"",
		"component_generation": 0,
		"progress": 0.0,
	}
	_refresh_engineer_status_readout()


func get_engineer_repair_state() -> Dictionary:
	var snapshot := _engineer_repair_state.duplicate(true)
	var cooldown := (
		_engineer_repair_authority.get_cooldown_remaining()
		if _engineer_repair_authority != null else 0.0
	)
	snapshot["duration_seconds"] = ENGINEER_REPAIR_DURATION_SECONDS
	snapshot["cooldown_seconds"] = ENGINEER_REPAIR_COOLDOWN_SECONDS
	snapshot["cooldown_remaining"] = cooldown
	snapshot["cooldown_ready"] = cooldown <= 0.0
	var resource_units := (
		_engineer_repair_authority.get_resource_units()
		if _engineer_repair_authority != null else ENGINEER_REPAIR_RESOURCE_CAPACITY
	)
	snapshot["resource_id"] = ENGINEER_REPAIR_RESOURCE_ID
	snapshot["resource_capacity"] = ENGINEER_REPAIR_RESOURCE_CAPACITY
	snapshot["resource_units"] = resource_units
	snapshot["resource_ready"] = resource_units > 0
	snapshot["active"] = _engineer_repair_authority != null \
		and _engineer_repair_authority.has_active_repair()
	return snapshot.duplicate(true)


## Dockside service fills only this live craft's repair locker. GameFlow owns
## the physical on-foot console gate; the shared RepairAuthority owns the exact
## generation/resource mutation and preserves damage, cooldown, and actor state.
func restock_engineer_repair_kits() -> Dictionary:
	var telemetry := get_telemetry()
	if is_destroyed():
		return {"accepted": false, "reason": &"ship_destroyed"}
	if is_piloted():
		return {"accepted": false, "reason": &"pilot_seated"}
	if not bool(telemetry.get("landed", false)) \
			or bool(telemetry.get("landing_active", false)):
		return {"accepted": false, "reason": &"ship_not_landed"}
	if _engineer_repair_authority == null:
		return {
			"accepted": true,
			"reason": &"resource_already_full",
			"ship_id": get_ship_id(),
			"display_name": get_display_name(),
			"resource_id": ENGINEER_REPAIR_RESOURCE_ID,
			"resource_capacity": ENGINEER_REPAIR_RESOURCE_CAPACITY,
			"resource_units": ENGINEER_REPAIR_RESOURCE_CAPACITY,
			"previous_resource_units": ENGINEER_REPAIR_RESOURCE_CAPACITY,
			"units_added": 0,
		}
	var model := get_component_damage()
	if model == null:
		return {"accepted": false, "reason": &"component_authority_unavailable"}
	var result := _engineer_repair_authority.restock_resource(
		ENGINEER_REPAIR_RESOURCE_ID, model.get_ledger_generation()
	)
	result["ship_id"] = get_ship_id()
	result["display_name"] = get_display_name()
	if bool(result.get("accepted", false)) \
			and int(result.get("units_added", 0)) > 0:
		engineer_repair_state_changed.emit(get_engineer_repair_state())
		_refresh_engineer_status_readout(false)
	return result.duplicate(true)


## Shared, read-only repair-network contract. RepairAuthority remains the only
## operation owner; this snapshot merely binds its receipt to the selected
## engineer seat for canonical presentation.
func get_engineer_repair_network_snapshot() -> Dictionary:
	var repair := get_engineer_repair_state()
	var owner: Dictionary = {}
	if not _engineer_component_selection.is_empty() \
			and StringName(_engineer_component_selection.get("component_id", &"")) \
			== StringName(repair.get("component_id", &"")) \
			and int(_engineer_component_selection.get("component_generation", 0)) \
			== int(repair.get("component_generation", 0)):
		owner = {
			"occupant_peer_id": int(_engineer_component_selection.get("occupant_peer_id", 0)),
			"avatar_id": StringName(_engineer_component_selection.get("avatar_id", &"")),
			"seat_id": ENGINEER_SEAT_ID,
			"seat_generation": int(_engineer_component_selection.get("seat_generation", 0)),
		}
	return {
		"repair": repair,
		"owner": owner,
		"presentation_only": true,
	}.duplicate(true)


func get_engineer_status_text() -> String:
	return _engineer_status_readout.text \
		if _engineer_status_readout != null and is_instance_valid(_engineer_status_readout) \
		else ""


func get_engineer_console_presentation_snapshot() -> Dictionary:
	return _engineer_repair_console.get_snapshot() \
		if _engineer_repair_console != null else {"attached": false}


func get_engineer_repair_presentation_snapshot() -> Dictionary:
	return _engineer_repair_presentation.get_snapshot() \
		if _engineer_repair_presentation != null else {"attached": false}


func get_engineer_repair_audio_snapshot() -> Dictionary:
	return _engineer_repair_audio.get_snapshot() \
		if _engineer_repair_audio != null else {"attached": false}


func _build_engineer_repair_audio() -> void:
	if _engineer_repair_audio != null:
		return
	_engineer_repair_audio = CrewEngineerAudioBindingType.new()
	_engineer_repair_audio.name = "EngineerRepairAudioPresentation"
	add_child(_engineer_repair_audio)
	_engineer_repair_audio.semantic_engine_cue_emitted.connect(
		_on_engineer_repair_audio_cue_emitted
	)
	_engineer_repair_audio.attach(_engineer_audio_generation)


func _build_engineer_repair_presentation() -> void:
	if _engineer_repair_presentation != null:
		return
	_engineer_repair_presentation = JovianEngineerRepairPresentationType.new()
	_engineer_repair_presentation.name = "EngineerRepairWorkPresentation"
	add_child(_engineer_repair_presentation)
	var attached: Dictionary = _engineer_repair_presentation.attach(
		_engineer_presentation_generation
	)
	if bool(attached.get("accepted", false)):
		_refresh_engineer_status_readout()


func _refresh_engineer_status_readout(publish_work_presentations: bool = true) -> void:
	var network_snapshot := get_engineer_repair_network_snapshot()
	if _engineer_repair_console != null:
		_engineer_console_sequence += 1
		_engineer_repair_console.present_snapshot({
			"generation": _engineer_console_generation,
			"sequence": _engineer_console_sequence,
			"repair_snapshot": network_snapshot,
		})
	_fit_engineer_status_readout()
	if not publish_work_presentations:
		return
	if _engineer_repair_presentation != null:
		_engineer_presentation_sequence += 1
		_engineer_repair_presentation.present_snapshot(
			{
				"generation": _engineer_presentation_generation,
				"sequence": _engineer_presentation_sequence,
				"repair_snapshot": network_snapshot,
			},
			_engineer_repair_component_exterior_anchor(
				StringName((network_snapshot.get("repair", {}) as Dictionary).get(
					"component_id", &""
				))
			)
		)
	_present_engineer_repair_audio_snapshot(network_snapshot)


# Fit the real producer's current lines to the physical display after every
# snapshot, including reset/rebind. Keep short states large without letting
# longer component names or interruption reasons escape the bezel.
func _fit_engineer_status_readout() -> void:
	if not is_instance_valid(_engineer_status_readout):
		return
	var font := _engineer_status_readout.font
	if font == null:
		font = ThemeDB.fallback_font
	var lines := _engineer_status_readout.text.split("\n")
	var widest := 1.0
	for line in lines:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _engineer_status_readout.font_size).x)
	var outline := float(_engineer_status_readout.outline_size * 2)
	var height := font.get_height(_engineer_status_readout.font_size) * lines.size() + outline
	_engineer_status_readout.pixel_size = minf(0.003, minf(0.95 / (widest + outline), 0.48 / maxf(height, 1.0)))


func _restart_engineer_console_presentation() -> void:
	if _engineer_repair_console == null:
		return
	_engineer_console_generation += 1
	_engineer_console_sequence = -1
	var begun: Dictionary = _engineer_repair_console.begin_generation(
		_engineer_console_generation
	)
	if bool(begun.get("accepted", false)):
		_refresh_engineer_status_readout(false)


func _restart_engineer_work_presentation() -> void:
	if _engineer_repair_presentation == null:
		return
	_engineer_presentation_generation += 1
	_engineer_presentation_sequence = -1
	_engineer_repair_presentation.begin_generation(_engineer_presentation_generation)


func _restart_engineer_repair_audio_presentation() -> void:
	if _engineer_repair_audio == null:
		return
	var snapshot: Dictionary = _engineer_repair_audio.get_snapshot()
	if bool(snapshot.get("attached", false)):
		var detached: Dictionary = _engineer_repair_audio.detach()
		if not bool(detached.get("accepted", false)):
			return
		snapshot = _engineer_repair_audio.get_snapshot()
	_engineer_audio_generation = int(snapshot.get("generation", _engineer_audio_generation))
	_engineer_audio_sequence = -1
	if is_inside_tree():
		_engineer_repair_audio.attach(_engineer_audio_generation)


func _present_engineer_repair_audio_snapshot(network_snapshot: Dictionary) -> void:
	if _engineer_repair_audio == null:
		return
	var audio_snapshot: Dictionary = _engineer_repair_audio.get_snapshot()
	if not bool(audio_snapshot.get("attached", false)):
		return
	var repair := network_snapshot.get("repair", {}) as Dictionary
	var status := StringName(repair.get("status", &""))
	var progress := clampf(float(repair.get("progress", 0.0)), 0.0, 1.0)
	var last_state := StringName(audio_snapshot.get("last_state", &""))
	var last_envelope := audio_snapshot.get("last_snapshot", {}) as Dictionary
	var last_progress := float(last_envelope.get("progress", -1.0))
	var cue_state: StringName = &""
	match status:
		&"repairing":
			if last_state not in [&"started", &"progress"]:
				cue_state = &"started"
			elif progress > last_progress and not is_equal_approx(progress, last_progress):
				cue_state = &"progress"
		&"completed":
			if last_state != &"completed":
				cue_state = &"completed"
		&"interrupted":
			if last_state != &"interrupted":
				cue_state = &"interrupted"
	if cue_state.is_empty():
		return
	_engineer_audio_sequence += 1
	var presented: Dictionary = _engineer_repair_audio.present_repair_snapshot({
		"generation": _engineer_audio_generation,
		"sequence": _engineer_audio_sequence,
		"repair_state": cue_state,
		"progress": progress,
	})
	if bool(presented.get("accepted", false)) \
			and cue_state in [&"completed", &"interrupted"]:
		_engineer_repair_audio.retire_active_cues(
			_engineer_audio_generation,
			StringName(repair.get("reason", cue_state))
		)


func _on_engineer_repair_audio_cue_emitted(cue_id: StringName, intensity: float) -> void:
	if _ship_audio_rig != null and is_instance_valid(_ship_audio_rig):
		_ship_audio_rig.semantic_engine_cue_emitted.emit(cue_id, intensity)


func _engineer_repair_component_exterior_anchor(component_id: StringName) -> Vector3:
	if component_id == &"":
		return Vector3.ZERO
	var model := get_component_damage()
	if model == null or not model.is_configured():
		return Vector3.INF
	var component_bounds := (
		model.get_component_report().get("local_bounds", AABB()) as AABB
	)
	for component: Dictionary in model.get_component_states():
		if StringName(component.get("id", &"")) == component_id:
			return JovianEngineerRepairPresentationType.resolve_exterior_anchor(
				component.get("local_position", Vector3.INF) as Vector3,
				component_bounds
			)
	return Vector3.INF


func _cleanup_detached_engineer_state() -> void:
	if _engineer_component_selection.is_empty():
		return
	if _crew_role_authority == null:
		_clear_engineer_component_selection(&"authority_detached")
		return
	var assignment := _crew_role_authority.get_assignment(
		int(_engineer_component_selection.get("occupant_peer_id", 0)),
		StringName(_engineer_component_selection.get("avatar_id", &""))
	)
	if assignment.is_empty():
		_clear_engineer_component_state(
			int(_engineer_component_selection.get("occupant_peer_id", 0)),
			StringName(_engineer_component_selection.get("avatar_id", &"")),
			&"role_detached"
		)


func _clear_engineer_component_state(
		occupant_peer_id: int,
		avatar_id: StringName,
		reason: StringName
) -> void:
	if not _engineer_component_selection.is_empty() \
			and int(_engineer_component_selection.get("occupant_peer_id", 0)) == occupant_peer_id \
			and StringName(_engineer_component_selection.get("avatar_id", &"")) == avatar_id:
		_clear_engineer_component_selection(reason)


func _clear_engineer_component_selection(reason: StringName, advance_generation: bool = true) -> void:
	_interrupt_engineer_repair(reason)
	_engineer_repair_state = {
		"status": &"idle",
		"reason": &"",
		"component_id": &"",
		"component_generation": 0,
		"progress": 0.0,
	}
	if _engineer_component_selection.is_empty():
		if advance_generation:
			_engineer_component_generation = mini(
				_engineer_component_generation + 1,
				MAX_ENGINEER_COMPONENT_GENERATION
			)
			_engineer_repair_elapsed = 0.0
			_restart_engineer_console_presentation()
			_restart_engineer_work_presentation()
			_restart_engineer_repair_audio_presentation()
		return
	var component_id := StringName(_engineer_component_selection.get("component_id", &""))
	var component_generation := int(_engineer_component_selection.get("component_generation", 0))
	_engineer_component_selection.clear()
	engineer_component_cleared.emit(component_id, component_generation, reason)
	if advance_generation:
		_engineer_component_generation = mini(
			_engineer_component_generation + 1,
			MAX_ENGINEER_COMPONENT_GENERATION
		)
		_engineer_repair_elapsed = 0.0
		_restart_engineer_console_presentation()
		_restart_engineer_work_presentation()
		_restart_engineer_repair_audio_presentation()


static func _crew_role_result(accepted: bool, status: StringName) -> Dictionary:
	return {"accepted": accepted, "status": status}


func get_walkable_interior_report() -> Dictionary:
	return {
		"schema_version": INTERIOR_SCHEMA_VERSION,
		"frame": self,
		"moving_interior_component": _moving_interior_component,
		"root": _walkable_interior,
		"ship_local_bounds": INTERIOR_BOUNDS,
		"access_marker": _interior_access_marker,
		"deck_marker": _interior_deck_marker,
		"exit_transform": get_interior_exit_transform(),
		"cargo_bay": _cargo_bay,
		"passenger_cabin": _passenger_cabin,
		"pilot_cockpit": get_pilot_seat_anchor().get_parent() if get_pilot_seat_anchor() != null else null,
		"connected_spaces": PackedStringArray(["exterior_ramp", "cargo_bay", "passenger_cabin", "pilot_cockpit"]),
		"cargo_hardpoint_count": _cargo_hardpoints.size(),
		"passenger_seat_count": _passenger_seat_anchors.size(),
		"detached_interior": false,
		"physical_deck_collision": true,
		"moving_occupant_compensation": _moving_interior_component != null,
		"historically_authenticated_layout": false,
		"content_note": PROVISIONAL_NOTE,
	}


func get_jovian_evidence_report() -> Dictionary:
	var definition := get_ship_definition()
	return {
		"schema_version": SCHEMA_VERSION,
		"evidence_status": EVIDENCE_STATUS,
		"evidence_scope": EVIDENCE_SCOPE,
		"name_to_model_status": NAME_TO_MODEL_STATUS,
		"authenticated_geometry": false,
		"creator_supported": PackedStringArray([
			"Jovian-class Light Freighter name (A3 page text)",
			"light-freighter role (A3 page text)",
		]),
		"modern_provisional": PackedStringArray([
			"silhouette, dimensions, proportions, and colours",
			"cargo ramp, walkable interior, room layout, fixtures, and capacity",
			"cockpit, pilot hatch, seat, access side, and cameras",
			"quad engines, defensive weapons, landing gear, and cargo hardware",
			"materials, handling, durability, audio profile, and all mechanics",
		]),
		"content_note": PROVISIONAL_NOTE,
		"ship_definition": definition.get_audit_report() if definition != null else {},
	}


## Visual-only audit for the restrained twin defensive fit. Actual projectile
## authority remains on HeroShip and its two root muzzle markers.
func get_defensive_weapon_visual_report() -> Dictionary:
	var errors := PackedStringArray()
	var component_paths := PackedStringArray()
	var visual_only := true
	for side_index in 2:
		var prefix := "Port" if side_index == 0 else "Starboard"
		var expected_x := -5.15 if side_index == 0 else 5.15
		for suffix in DEFENSIVE_TURRET_PART_SUFFIXES:
			var path := prefix + String(suffix)
			var component := _jovian_visual.get_node_or_null(NodePath(path)) as MeshInstance3D \
				if _jovian_visual != null else null
			component_paths.append(path)
			if component == null:
				errors.append("defensive_turret_component_missing:%s" % path)
				continue
			if (
				StringName(component.get_meta("interpretation_status", &"")) != DEFENSIVE_TURRET_STATUS
				or StringName(component.get_meta("weapon_role", &"")) != DEFENSIVE_TURRET_ROLE
				or bool(component.get_meta("authenticated_historical_weapon", true))
				or not bool(component.get_meta("visual_only", false))
			):
				errors.append("defensive_turret_metadata_drift:%s" % path)
			visual_only = visual_only and component.get_child_count() == 0
		var muzzle := get_node_or_null(NodePath("LeftMuzzle" if side_index == 0 else "RightMuzzle")) as Marker3D
		if muzzle == null or not muzzle.position.is_equal_approx(Vector3(expected_x, 3.76, DEFENSIVE_TURRET_MUZZLE_Z)):
			errors.append("defensive_turret_muzzle_alignment_drift:%s" % prefix)
	var port_base := _jovian_visual.get_node_or_null(^"PortDefensiveTurretBase") as MeshInstance3D \
		if _jovian_visual != null else null
	var port_barrel := _jovian_visual.get_node_or_null(^"PortDefensivePulseBarrel") as MeshInstance3D \
		if _jovian_visual != null else null
	var base_size := port_base.mesh.get_aabb().size if port_base != null and port_base.mesh != null else Vector3.ZERO
	var barrel_size := port_barrel.mesh.get_aabb().size if port_barrel != null and port_barrel.mesh != null else Vector3.ZERO
	if (
		not base_size.is_equal_approx(Vector3(
			DEFENSIVE_TURRET_BASE_RADIUS * 2.0,
			DEFENSIVE_TURRET_BASE_HEIGHT,
			DEFENSIVE_TURRET_BASE_RADIUS * 2.0
		))
	):
		errors.append("defensive_turret_base_dimensions_drift")
	if (
		not barrel_size.is_equal_approx(Vector3(
			DEFENSIVE_TURRET_BARREL_RADIUS * 2.0,
			DEFENSIVE_TURRET_BARREL_LENGTH,
			DEFENSIVE_TURRET_BARREL_RADIUS * 2.0
		))
	):
		errors.append("defensive_turret_barrel_dimensions_drift")
	if not visual_only:
		errors.append("defensive_turret_visual_gained_children")
	return {
		"schema_version": 1,
		"valid": errors.is_empty(),
		"errors": errors,
		"interpretation_status": DEFENSIVE_TURRET_STATUS,
		"weapon_role": DEFENSIVE_TURRET_ROLE,
		"authenticated_historical_weapon": false,
		"visual_only": visual_only,
		"turret_count": 2,
		"components_per_turret": DEFENSIVE_TURRET_PART_SUFFIXES.size(),
		"component_paths": component_paths,
		"muzzle_positions": [Vector3(-5.15, 3.76, DEFENSIVE_TURRET_MUZZLE_Z), Vector3(5.15, 3.76, DEFENSIVE_TURRET_MUZZLE_Z)],
		"base_radius": DEFENSIVE_TURRET_BASE_RADIUS,
		"base_height": DEFENSIVE_TURRET_BASE_HEIGHT,
		"barrel_radius": DEFENSIVE_TURRET_BARREL_RADIUS,
		"barrel_length": DEFENSIVE_TURRET_BARREL_LENGTH,
	}


## Presentation-only role/orientation cue. The report deliberately proves the
## cue has no gameplay authority and remains inside the already published
## parked envelope; it does not elevate the craft's historical evidence status.
func get_forward_cargo_guide_visual_report() -> Dictionary:
	var errors := PackedStringArray()
	var guide := _jovian_visual.get_node_or_null(NodePath(FORWARD_CARGO_GUIDE_NAME)) \
		as MeshInstance3D if _jovian_visual != null else null
	var mesh := guide.mesh as ArrayMesh if guide != null else null
	var bounds := mesh.get_aabb() if mesh != null else AABB()
	if guide == null or mesh == null:
		errors.append("forward_cargo_guide_renderer_missing")
	else:
		if (
			mesh.get_surface_count() != 2
			or mesh.surface_get_material(0) != _jovian_materials.get("structure")
			or mesh.surface_get_material(1) != _jovian_materials.get("amber")
		):
			errors.append("forward_cargo_guide_surface_recipe_drift")
		if (
			guide.get_child_count() != 0
			or not bool(guide.get_meta("visual_only", false))
			or StringName(guide.get_meta("orientation_axis", &"")) != &"forward_negative_z"
			or StringName(guide.get_meta("cargo_role_cue", &"")) != FORWARD_CARGO_GUIDE_ROLE
			or StringName(guide.get_meta("interpretation_status", &"")) \
				!= FORWARD_CARGO_GUIDE_STATUS
			or bool(guide.get_meta("authenticated_historical_silhouette", true))
			or bool(guide.get_meta("collision_authority", true))
			or bool(guide.get_meta("cargo_authority", true))
		):
			errors.append("forward_cargo_guide_presentation_boundary_drift")
		if (
			guide.is_processing()
			or guide.is_physics_processing()
			or not guide.find_children("*", "CollisionObject3D", true, false).is_empty()
			or not guide.find_children("*", "CollisionShape3D", true, false).is_empty()
			or not guide.find_children("*", "Light3D", true, false).is_empty()
		):
			errors.append("forward_cargo_guide_gained_runtime_authority")
		if (
			bounds.position.x < PARKED_RENDER_BOUNDS.position.x
			or bounds.position.y < PARKED_RENDER_BOUNDS.position.y
			or bounds.position.z < PARKED_RENDER_BOUNDS.position.z
			or bounds.end.x > PARKED_RENDER_BOUNDS.end.x
			or bounds.end.y > PARKED_RENDER_BOUNDS.end.y
			or bounds.end.z > PARKED_RENDER_BOUNDS.end.z
		):
			errors.append("forward_cargo_guide_exceeded_parked_render_envelope")
		if not is_zero_approx(bounds.get_center().x):
			errors.append("forward_cargo_guide_lost_centerline_symmetry")
		if bounds.position.z > -11.3 or bounds.end.z < -2.81 or bounds.size.x < 16.3:
			errors.append("forward_cargo_guide_gameplay_distance_silhouette_drift")
	return {
		"schema_version": 1,
		"valid": errors.is_empty(),
		"errors": errors,
		"interpretation_status": FORWARD_CARGO_GUIDE_STATUS,
		"authenticated_historical_silhouette": false,
		"visual_only": true,
		"orientation_axis": &"forward_negative_z",
		"cargo_role_cue": FORWARD_CARGO_GUIDE_ROLE,
		"renderer_nodes": 1 if guide != null else 0,
		"surface_count": mesh.get_surface_count() if mesh != null else 0,
		"local_bounds": bounds,
		"parked_render_bounds": PARKED_RENDER_BOUNDS,
	}


func get_jovian_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var defensive_weapon_visual := get_defensive_weapon_visual_report()
	var forward_cargo_guide_visual := get_forward_cargo_guide_visual_report()
	var load_mark_allocation := get_load_mark_render_audit()
	var service_panel_allocation := get_service_panel_render_audit()
	var cargo_deck_lane_allocation := get_cargo_deck_lane_render_audit()
	var dorsal_rib_allocation := get_dorsal_cargo_rib_joint_allocation_audit()
	var shoulder_rail_allocation := get_shoulder_rail_joint_allocation_audit()
	var cargo_frame_allocation := get_cargo_frame_joint_allocation_audit()
	var cargo_restraint_allocation := get_cargo_restraint_mesh_allocation_audit()
	var passenger_seat_allocation := get_passenger_seat_mesh_allocation_audit()
	var passenger_cabin_light_strip_allocation := get_passenger_cabin_light_strip_allocation_audit()
	var definition := get_ship_definition()
	if definition == null or not definition.is_definition_valid():
		errors.append("valid provisional ShipDefinition is missing")
	elif definition.get_evidence_status_id() != &"provisional":
		errors.append("Jovian definition must remain provisional")
	if _jovian_visual == null:
		errors.append("dedicated Jovian visual root is missing")
	if _walkable_interior == null or _cargo_bay == null or _passenger_cabin == null:
		errors.append("connected cargo and passenger interior hierarchy is incomplete")
	if _interior_access_marker == null or _interior_deck_marker == null or _interior_exit_marker == null:
		errors.append("interior route markers are incomplete")
	if _cabin_stand_marker == null:
		errors.append("in-flight cabin standing marker is missing")
	elif not CABIN_MOVEMENT_BOUNDS.has_point(CABIN_STAND_LOCAL_ORIGIN):
		errors.append("in-flight cabin standing pose falls outside the confined cabin envelope")
	if _moving_interior_component == null or _moving_interior_component.get_moving_frame() != self:
		errors.append("typed moving-interior component is not configured against the ship frame")
	if _cargo_hardpoints.size() < 4:
		errors.append("cargo bay requires at least four stable cargo hardpoints")
	if _passenger_seat_anchors.size() < 4:
		errors.append("passenger cabin requires at least four seat anchors")
	if _engine_plumes.size() != 4:
		errors.append("provisional quad-engine presentation is incomplete")
	if get_node_or_null("LeftMuzzle") == null or get_node_or_null("RightMuzzle") == null:
		errors.append("defensive muzzle markers are missing")
	if not bool(defensive_weapon_visual.get("valid", false)):
		errors.append("modern provisional defensive weapon visual drifted")
	if not bool(forward_cargo_guide_visual.get("valid", false)):
		errors.append("modern provisional forward cargo-guide silhouette drifted")
	if not bool(load_mark_allocation.get("valid", false)):
		errors.append("load-mark visual batching contract drifted")
	if not bool(service_panel_allocation.get("valid", false)):
		errors.append("service-panel visual batching contract drifted")
	if not bool(cargo_deck_lane_allocation.get("valid", false)):
		errors.append("cargo-deck lane visual batching contract drifted")
	if not bool(dorsal_rib_allocation.get("valid", false)):
		errors.append("dorsal cargo rib joint allocation contract drifted")
	if not bool(shoulder_rail_allocation.get("valid", false)):
		errors.append("shoulder rail joint allocation contract drifted")
	if not bool(cargo_frame_allocation.get("valid", false)):
		errors.append("cargo frame joint allocation contract drifted")
	if not bool(cargo_restraint_allocation.get("valid", false)):
		errors.append("cargo restraint mesh allocation contract drifted")
	if not bool(passenger_seat_allocation.get("valid", false)):
		errors.append("passenger seat mesh allocation contract drifted")
	if not bool(passenger_cabin_light_strip_allocation.get("valid", false)):
		errors.append("passenger cabin light-strip allocation contract drifted")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"ship_id": get_ship_id(),
		"display_name": get_display_name(),
		"role": get_role(),
		"engine_count": _engine_plumes.size(),
		"weapon_class": &"freighter_defensive_pulse",
		"defensive_weapon_visual": defensive_weapon_visual,
		"forward_cargo_guide_visual": forward_cargo_guide_visual,
		"load_mark_render_allocation": load_mark_allocation,
		"service_panel_render_allocation": service_panel_allocation,
		"cargo_deck_lane_render_allocation": cargo_deck_lane_allocation,
		"combat_source_id": COMBAT_SOURCE_ID,
		"interior": get_walkable_interior_report(),
		"evidence": get_jovian_evidence_report(),
		"dorsal_cargo_rib_joint_allocation": dorsal_rib_allocation,
		"shoulder_rail_joint_allocation": shoulder_rail_allocation,
		"cargo_frame_joint_allocation": cargo_frame_allocation,
		"cargo_restraint_mesh_allocation": cargo_restraint_allocation,
		"passenger_seat_mesh_allocation": passenger_seat_allocation,
		"passenger_cabin_light_strip_allocation": passenger_cabin_light_strip_allocation,
	}


func get_load_mark_render_audit() -> Dictionary:
	var errors := PackedStringArray()
	var multi := _load_mark_batch.multimesh if is_instance_valid(_load_mark_batch) else null
	var expected_names := PackedStringArray([
		"PortLoadMark00", "PortLoadMark01", "PortLoadMark02",
		"StarboardLoadMark00", "StarboardLoadMark01", "StarboardLoadMark02",
	])
	if _jovian_visual == null or not is_instance_valid(_jovian_visual):
		errors.append("load_mark_visual_root_unavailable")
	if not is_instance_valid(_load_mark_batch) or multi == null or multi.mesh == null:
		errors.append("load_mark_batch_unavailable")
	else:
		if _load_mark_batch.get_parent() != _jovian_visual or _load_mark_batch.name != &"LoadMarkBatch":
			errors.append("load_mark_batch_path_drift")
		if multi.mesh != _load_mark_mesh or not multi.mesh.get_aabb().size.is_equal_approx(LOAD_MARK_SIZE):
			errors.append("load_mark_mesh_recipe_drift")
		if (
			multi.instance_count != LOAD_MARK_COPY_COUNT
			or multi.visible_instance_count != -1
			or multi.mesh.get_surface_count() != 1
			or multi.mesh.surface_get_material(0) != _jovian_materials.get("amber")
			or _load_mark_batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			or _load_mark_batch.layers != 1
		):
			errors.append("load_mark_renderer_recipe_drift")
		if multi.buffer != _encode_load_mark_transforms(_load_mark_transforms):
			errors.append("load_mark_transform_buffer_drift")
		if not multi.custom_aabb.is_equal_approx(_load_mark_bounds(multi.mesh.get_aabb(), _load_mark_transforms)):
			errors.append("load_mark_culling_bounds_drift")
		if _load_mark_batch.get_meta("authored_visual_names", PackedStringArray()) != expected_names:
			errors.append("load_mark_authored_name_roster_drift")
		if _load_mark_batch.get_child_count() != 0 or not bool(_load_mark_batch.get_meta("visual_detail_only", false)):
			errors.append("load_mark_gained_authority")
	if _load_mark_transforms.size() != LOAD_MARK_COPY_COUNT:
		errors.append("load_mark_transform_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"legacy": {"renderer_nodes": LOAD_MARK_COPY_COUNT, "submissions": LOAD_MARK_COPY_COUNT},
		"current": {"renderer_nodes": 1, "submissions": 1, "copies": LOAD_MARK_COPY_COUNT},
		"delta": {"renderer_nodes": 1 - LOAD_MARK_COPY_COUNT, "submissions": 1 - LOAD_MARK_COPY_COUNT},
		"authored_transforms": _load_mark_transforms.duplicate(),
		"batched": true,
		"collision_authority": false,
	}.duplicate(true)


func _encode_load_mark_transforms(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


func get_service_panel_render_audit() -> Dictionary:
	var errors := PackedStringArray()
	var multi := _service_panel_batch.multimesh \
		if is_instance_valid(_service_panel_batch) else null
	var expected_names := PackedStringArray([
		"PortServicePanel00", "PortServicePanel01", "PortServicePanel03",
		"StarboardServicePanel00", "StarboardServicePanel01",
		"StarboardServicePanel02", "StarboardServicePanel03",
	])
	if not is_instance_valid(_jovian_visual):
		errors.append("service_panel_visual_root_unavailable")
	if not is_instance_valid(_service_panel_batch) or multi == null or multi.mesh == null:
		errors.append("service_panel_batch_unavailable")
	else:
		if (
			_service_panel_batch.get_parent() != _jovian_visual
			or _service_panel_batch.name != &"ServicePanelBatch"
		):
			errors.append("service_panel_batch_path_drift")
		if (
			multi.mesh != _service_panel_mesh
			or not multi.mesh.get_aabb().size.is_equal_approx(SERVICE_PANEL_SIZE)
		):
			errors.append("service_panel_mesh_recipe_drift")
		if (
			multi.instance_count != SERVICE_PANEL_COPY_COUNT
			or multi.visible_instance_count != -1
			or multi.mesh.get_surface_count() != 1
			or multi.mesh.surface_get_material(0) != _jovian_materials.get("structure")
			or _service_panel_batch.cast_shadow
				!= GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			or _service_panel_batch.layers != 1
			or not is_zero_approx(_service_panel_batch.extra_cull_margin)
		):
			errors.append("service_panel_renderer_recipe_drift")
		if multi.buffer != _encode_load_mark_transforms(_service_panel_transforms):
			errors.append("service_panel_transform_buffer_drift")
		if not multi.custom_aabb.is_equal_approx(
			_load_mark_bounds(multi.mesh.get_aabb(), _service_panel_transforms)
		):
			errors.append("service_panel_culling_bounds_drift")
		if _service_panel_batch.get_meta(
			"authored_visual_names", PackedStringArray()
		) != expected_names:
			errors.append("service_panel_authored_name_roster_drift")
		if (
			_service_panel_batch.get_child_count() != 0
			or not bool(_service_panel_batch.get_meta("visual_detail_only", false))
		):
			errors.append("service_panel_gained_authority")
	if _service_panel_transforms.size() != SERVICE_PANEL_COPY_COUNT:
		errors.append("service_panel_transform_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"legacy": {
			"renderer_nodes": SERVICE_PANEL_COPY_COUNT,
			"submissions": SERVICE_PANEL_COPY_COUNT,
		},
		"current": {
			"renderer_nodes": 1,
			"submissions": 1,
			"copies": SERVICE_PANEL_COPY_COUNT,
		},
		"delta": {
			"renderer_nodes": 1 - SERVICE_PANEL_COPY_COUNT,
			"submissions": 1 - SERVICE_PANEL_COPY_COUNT,
		},
		"authored_transforms": _service_panel_transforms.duplicate(),
		"batched": true,
		"collision_authority": false,
	}.duplicate(true)


func _load_mark_bounds(mesh_bounds: AABB, transforms: Array[Transform3D]) -> AABB:
	var result := AABB()
	var first := true
	for transform in transforms:
		var transformed := (transform * mesh_bounds).abs()
		if first:
			result = transformed
			first = false
		else:
			result = result.merge(transformed)
	return result


func get_cargo_deck_lane_render_audit() -> Dictionary:
	var errors := PackedStringArray()
	var multi := _cargo_deck_lane_batch.multimesh \
		if is_instance_valid(_cargo_deck_lane_batch) else null
	var expected_names := PackedStringArray([
		"CargoDeckLane", "CargoDeckLane", "CargoDeckLane",
	])
	if not is_instance_valid(_cargo_bay):
		errors.append("cargo_deck_lane_parent_unavailable")
	if not is_instance_valid(_cargo_deck_lane_batch) or multi == null or multi.mesh == null:
		errors.append("cargo_deck_lane_batch_unavailable")
	else:
		if (
			_cargo_deck_lane_batch.get_parent() != _cargo_bay
			or _cargo_deck_lane_batch.name != &"CargoDeckLaneBatch"
		):
			errors.append("cargo_deck_lane_batch_path_drift")
		if (
			multi.mesh != _cargo_deck_lane_mesh
			or not multi.mesh.get_aabb().size.is_equal_approx(CARGO_DECK_LANE_SIZE)
		):
			errors.append("cargo_deck_lane_mesh_recipe_drift")
		if (
			multi.instance_count != CARGO_DECK_LANE_COPY_COUNT
			or multi.visible_instance_count != -1
			or multi.mesh.get_surface_count() != 1
			or multi.mesh.surface_get_material(0) != _jovian_materials.get("teal")
			or _cargo_deck_lane_batch.cast_shadow
				!= GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			or _cargo_deck_lane_batch.layers != 1
			or not is_zero_approx(_cargo_deck_lane_batch.extra_cull_margin)
		):
			errors.append("cargo_deck_lane_renderer_recipe_drift")
		if multi.buffer != _encode_load_mark_transforms(_cargo_deck_lane_transforms):
			errors.append("cargo_deck_lane_transform_buffer_drift")
		if not multi.custom_aabb.is_equal_approx(
			_load_mark_bounds(multi.mesh.get_aabb(), _cargo_deck_lane_transforms)
		):
			errors.append("cargo_deck_lane_culling_bounds_drift")
		if _cargo_deck_lane_batch.get_meta(
			"authored_visual_names", PackedStringArray()
		) != expected_names:
			errors.append("cargo_deck_lane_authored_name_roster_drift")
		if (
			_cargo_deck_lane_batch.get_child_count() != 0
			or not bool(_cargo_deck_lane_batch.get_meta("visual_detail_only", false))
		):
			errors.append("cargo_deck_lane_gained_authority")
	if _cargo_deck_lane_transforms.size() != CARGO_DECK_LANE_COPY_COUNT:
		errors.append("cargo_deck_lane_transform_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"legacy": {"renderer_nodes": CARGO_DECK_LANE_COPY_COUNT, "submissions": CARGO_DECK_LANE_COPY_COUNT},
		"current": {"renderer_nodes": 1, "submissions": 1, "copies": CARGO_DECK_LANE_COPY_COUNT},
		"delta": {"renderer_nodes": 1 - CARGO_DECK_LANE_COPY_COUNT, "submissions": 1 - CARGO_DECK_LANE_COPY_COUNT},
		"authored_transforms": _cargo_deck_lane_transforms.duplicate(),
		"batched": true,
		"collision_authority": false,
	}.duplicate(true)


## Six passenger seats retain all 18 visible parts and submissions, while their
## three fitted cushion/webbing recipes share one immutable ArrayMesh each. Seat anchors and
## collision remain separately owned; this changes no authority or batching.
func get_passenger_seat_mesh_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids: Dictionary = {}
	var node_ids: Dictionary = {}
	var surface_count := 0
	var family_counts := {&"SeatBase": 0, &"SeatBack": 0, &"Harness": 0}
	var expected_meshes := {
		&"SeatBase": _passenger_seat_base_mesh,
		&"SeatBack": _passenger_seat_back_mesh,
		&"Harness": _passenger_seat_harness_mesh,
	}
	var expected_materials := {
		&"SeatBase": _jovian_materials.get("cabin_cloth"),
		&"SeatBack": _jovian_materials.get("cabin_cloth"),
		&"Harness": _jovian_materials.get("webbing"),
	}
	var expected_positions := {
		&"SeatBase": Vector3(0.0, 0.88, 0.0),
		&"SeatBack": Vector3(0.0, 1.42, 0.36),
		&"Harness": Vector3(0.0, 1.42, 0.25),
	}
	var expected_rotations := {
		&"SeatBase": Vector3.ZERO,
		&"SeatBack": Vector3(deg_to_rad(8.0), 0.0, 0.0),
		&"Harness": Vector3.ZERO,
	}
	if not is_instance_valid(_passenger_cabin):
		errors.append("passenger_seat_cabin_unavailable")
	else:
		for side_name in [&"Port", &"Starboard"]:
			for seat_index in 3:
				var root_name := "%sPassengerSeat%02d" % [side_name, seat_index]
				var seat_root := _passenger_cabin.get_node_or_null(NodePath(root_name)) as Node3D
				if not is_instance_valid(seat_root):
					errors.append("passenger_seat_root_missing:%s" % root_name)
					continue
				if seat_root.get_node_or_null(^"PassengerAnchor") == null:
					errors.append("passenger_seat_anchor_missing:%s" % root_name)
				for family_name: StringName in expected_meshes:
					var visual := seat_root.get_node_or_null(NodePath(family_name)) as MeshInstance3D
					if not is_instance_valid(visual):
						errors.append("passenger_seat_visual_missing:%s/%s" % [root_name, family_name])
						continue
					family_counts[family_name] = int(family_counts[family_name]) + 1
					node_ids[visual.get_instance_id()] = true
					var mesh := visual.mesh as ArrayMesh
					if mesh == null:
						errors.append("passenger_seat_mesh_type_drift:%s/%s" % [root_name, family_name])
						continue
					mesh_ids[mesh.get_instance_id()] = true
					surface_count += mesh.get_surface_count()
					if (
						mesh != expected_meshes[family_name]
						or mesh.surface_get_material(0) != expected_materials[family_name]
						or mesh.get_surface_count() != 1
						or visual.get_child_count() != 0
						or not visual.position.is_equal_approx(expected_positions[family_name] as Vector3)
						or not visual.rotation.is_equal_approx(expected_rotations[family_name] as Vector3)
						or not visual.scale.is_equal_approx(Vector3.ONE)
						or not visual.visible
						or visual.material_override != null
						or visual.material_overlay != null
					):
						errors.append("passenger_seat_recipe_or_authority_drift:%s/%s" % [root_name, family_name])
	for family_name: StringName in family_counts:
		if int(family_counts[family_name]) != PASSENGER_SEAT_COUNT:
			errors.append("passenger_seat_family_count_drift:%s" % family_name)
	if node_ids.size() != PASSENGER_SEAT_COUNT * 3:
		errors.append("passenger_seat_node_count_drift")
	if mesh_ids.size() != 3:
		errors.append("passenger_seat_mesh_resource_count_drift")
	if surface_count != PASSENGER_SEAT_COUNT * 3:
		errors.append("passenger_seat_submission_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"jovian_passenger_seat_visuals",
		"current": {"nodes": node_ids.size(), "copies": PASSENGER_SEAT_COUNT * 3, "submissions": surface_count, "mesh_resource_allocations": mesh_ids.size()},
		"legacy": {"nodes": PASSENGER_SEAT_COUNT * 3, "copies": PASSENGER_SEAT_COUNT * 3, "submissions": PASSENGER_SEAT_COUNT * 3, "mesh_resource_allocations": PASSENGER_SEAT_COUNT * 3},
		"delta": {"mesh_resource_allocations": mesh_ids.size() - PASSENGER_SEAT_COUNT * 3},
		"batched": false,
		"collision_authority": false,
	}.duplicate(true)


## The port and starboard cabin light strips retain their independent authored
## nodes and transforms, but one exact rounded ArrayMesh supplies their shared
## visual-only recipe. No collision, material override, batching, or authority
## is introduced by this allocation reduction.
func get_passenger_cabin_light_strip_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids: Dictionary = {}
	var node_ids: Dictionary = {}
	var surface_count := 0
	var expected_positions := {
		&"Port": Vector3(-3.23, 3.46, -5.25),
		&"Starboard": Vector3(3.23, 3.46, -5.25),
	}
	if not is_instance_valid(_passenger_cabin):
		errors.append("passenger_cabin_light_strip_cabin_unavailable")
	else:
		for side_name: StringName in expected_positions:
			var expected_position := expected_positions[side_name] as Vector3
			var strip: MeshInstance3D
			for candidate in _passenger_cabin.get_children():
				if (
					candidate is MeshInstance3D
					and (candidate as MeshInstance3D).position.is_equal_approx(expected_position)
				):
					if is_instance_valid(strip):
						errors.append("passenger_cabin_light_strip_duplicate:%s" % side_name)
					else:
						strip = candidate as MeshInstance3D
			if not is_instance_valid(strip):
				errors.append("passenger_cabin_light_strip_missing:%s" % side_name)
				continue
			node_ids[strip.get_instance_id()] = true
			var mesh := strip.mesh as ArrayMesh
			if mesh == null:
				errors.append("passenger_cabin_light_strip_mesh_type_drift:%s" % side_name)
				continue
			mesh_ids[mesh.get_instance_id()] = true
			surface_count += mesh.get_surface_count()
			if (
				mesh != _passenger_cabin_light_strip_mesh
				or mesh.surface_get_material(0) != _jovian_materials.get("interior_light")
				or mesh.get_surface_count() != 1
				or strip.get_child_count() != 0
				or not strip.position.is_equal_approx(expected_position)
				or not strip.rotation.is_equal_approx(Vector3.ZERO)
				or not strip.scale.is_equal_approx(Vector3.ONE)
				or not strip.visible
				or strip.material_override != null
				or strip.material_overlay != null
			):
				errors.append("passenger_cabin_light_strip_recipe_or_authority_drift:%s" % side_name)
	if node_ids.size() != 2:
		errors.append("passenger_cabin_light_strip_node_count_drift")
	if mesh_ids.size() != 1:
		errors.append("passenger_cabin_light_strip_mesh_resource_count_drift")
	if surface_count != 2:
		errors.append("passenger_cabin_light_strip_submission_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"jovian_passenger_cabin_light_strips",
		"current": {"nodes": node_ids.size(), "copies": 2, "submissions": surface_count, "mesh_resource_allocations": mesh_ids.size()},
		"legacy": {"nodes": 2, "copies": 2, "submissions": 2, "mesh_resource_allocations": 2},
		"delta": {"mesh_resource_allocations": mesh_ids.size() - 2},
		"batched": false,
		"collision_authority": false,
	}.duplicate(true)


## Eight named cargo-restraint bands retain their exact visual nodes, transforms,
## and submissions while sharing one immutable rounded-box mesh. Their matching
## cargo-unit collision remains separately authored on the ship root.
func get_cargo_restraint_mesh_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var node_ids: Dictionary = {}
	var node_names: Dictionary = {}
	var mesh_ids: Dictionary = {}
	var material_ids: Dictionary = {}
	var submission_count := 0
	if not is_instance_valid(_cargo_bay):
		errors.append("cargo_restraint_bay_unavailable")
	else:
		for unit_index in CARGO_UNIT_ANCHORS.size():
			var anchor := CARGO_UNIT_ANCHORS[unit_index]
			var suffix := cargo_unit_suffix(unit_index)
			for band_index in CARGO_RESTRAINT_BAND_Z.size():
				var node_name := "CargoRestraint%s%02d" % [suffix, band_index]
				var restraint := _cargo_bay.get_node_or_null(
					NodePath(node_name)
				) as MeshInstance3D
				if not is_instance_valid(restraint):
					errors.append("cargo_restraint_missing:%s" % node_name)
					continue
				node_ids[restraint.get_instance_id()] = true
				node_names[String(restraint.name)] = true
				var mesh := restraint.mesh as ArrayMesh
				if mesh == null:
					errors.append("cargo_restraint_mesh_type_drift:%s" % node_name)
					continue
				mesh_ids[mesh.get_instance_id()] = true
				submission_count += mesh.get_surface_count()
				for surface_index in mesh.get_surface_count():
					var material := mesh.surface_get_material(surface_index)
					if material != null:
						material_ids[material.get_instance_id()] = true
				var expected_position := anchor + Vector3(
					0.0,
					CARGO_RESTRAINT_OFFSET_Y,
					CARGO_RESTRAINT_BAND_Z[band_index]
				)
				if (
					mesh != _cargo_restraint_mesh
					or mesh.get_surface_count() != 1
					or not mesh.get_aabb().size.is_equal_approx(CARGO_RESTRAINT_SIZE)
					or mesh.surface_get_material(0) != _jovian_materials.get("amber")
					or not restraint.position.is_equal_approx(expected_position)
					or not restraint.rotation.is_equal_approx(Vector3.ZERO)
					or not restraint.scale.is_equal_approx(Vector3.ONE)
					or not restraint.visible
					or restraint.layers != 1
					or restraint.cast_shadow
						!= GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					or restraint.material_override != null
					or restraint.material_overlay != null
					or restraint.get_child_count() != 0
					or restraint.get_script() != null
					or not restraint.get_meta_list().is_empty()
				):
					errors.append("cargo_restraint_recipe_or_authority_drift:%s" % node_name)
	if node_ids.size() != CARGO_RESTRAINT_COPY_COUNT:
		errors.append("cargo_restraint_node_count_drift")
	if node_names.size() != CARGO_RESTRAINT_COPY_COUNT:
		errors.append("cargo_restraint_name_count_drift")
	if mesh_ids.size() != 1:
		errors.append("cargo_restraint_mesh_resource_count_drift")
	if material_ids.size() != 1:
		errors.append("cargo_restraint_material_resource_count_drift")
	if submission_count != CARGO_RESTRAINT_COPY_COUNT:
		errors.append("cargo_restraint_submission_count_drift")
	var current := {
		"geometry_nodes": node_ids.size(),
		"named_nodes": node_names.size(),
		"drawn_copies": node_ids.size(),
		"geometry_submissions": submission_count,
		"mesh_resource_allocations": mesh_ids.size(),
		"material_resource_allocations": material_ids.size(),
		"multimesh_batches": 0,
	}
	var legacy := {
		"geometry_nodes": CARGO_RESTRAINT_COPY_COUNT,
		"named_nodes": CARGO_RESTRAINT_COPY_COUNT,
		"drawn_copies": CARGO_RESTRAINT_COPY_COUNT,
		"geometry_submissions": CARGO_RESTRAINT_COPY_COUNT,
		"mesh_resource_allocations": CARGO_RESTRAINT_COPY_COUNT,
		"material_resource_allocations": 1,
		"multimesh_batches": 0,
	}
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"current": current,
		"legacy": legacy,
		"delta": {
			"geometry_nodes": int(current.geometry_nodes) - int(legacy.geometry_nodes),
			"drawn_copies": int(current.drawn_copies) - int(legacy.drawn_copies),
			"geometry_submissions": int(current.geometry_submissions)
				- int(legacy.geometry_submissions),
			"mesh_resource_allocations": int(current.mesh_resource_allocations)
				- int(legacy.mesh_resource_allocations),
			"material_resource_allocations": int(current.material_resource_allocations)
				- int(legacy.material_resource_allocations),
		},
		"batched": false,
		"collision_authority": false,
		"crew_authority": false,
		"cargo_authority": false,
		"flight_authority": false,
		"lifecycle_authority": false,
	}.duplicate(true)


## Renderer-independent component evidence for one bounded repeated family.
##
## The report deliberately makes no driver draw-call, timing, or VRAM claim:
## resource identity is the only changed currency. Every named MeshInstance3D,
## drawn copy, surface submission, transform, renderer value, and semantic
## boundary remains independently present in the live Jovian hierarchy.
func get_dorsal_cargo_rib_joint_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids: Dictionary = {}
	var material_resource_ids: Dictionary = {}
	var node_instance_ids: Dictionary = {}
	var family_node_count := 0
	var named_node_count := 0
	var drawn_copy_count := 0
	var structural_surface_submission_count := 0
	var multimesh_batch_count := 0
	var descendant_node_count := 0
	var collision_object_count := 0
	var collision_shape_count := 0
	var interaction_area_count := 0
	var marker_count := 0
	var metadata_entry_count := 0
	var scripted_node_count := 0
	var grouped_node_count := 0
	var processing_node_count := 0
	var behavior_rows: Array[Dictionary] = []

	if _jovian_visual == null or not is_instance_valid(_jovian_visual):
		errors.append("dorsal_rib_visual_root_unavailable")
	else:
		for rib_index in DORSAL_CARGO_RIB_COUNT:
			var rib_name := "DorsalCargoRib%02d" % rib_index
			var rib := _jovian_visual.get_node_or_null(NodePath(rib_name)) as Node3D
			if rib == null:
				errors.append("dorsal_rib_root_missing:%s" % rib_name)
				continue
			if (
				not rib.position.is_equal_approx(Vector3.ZERO)
				or not rib.rotation.is_equal_approx(Vector3.ZERO)
				or not rib.scale.is_equal_approx(Vector3.ONE)
				or not rib.visible
			):
				errors.append("dorsal_rib_root_transform_drift:%s" % rib_name)

			var rib_joints: Array[MeshInstance3D] = []
			var rib_segment_count := 0
			var rib_node_names: Dictionary = {}
			for child in rib.get_children():
				var mesh_instance := child as MeshInstance3D
				if mesh_instance == null:
					continue
				if mesh_instance.mesh is SphereMesh:
					rib_joints.append(mesh_instance)
					rib_node_names[String(mesh_instance.name)] = true
				elif String(mesh_instance.name).begins_with("Segment"):
					rib_segment_count += 1
			if (
				rib.get_child_count() != 9
				or rib_segment_count != 4
				or rib_joints.size() != DORSAL_CARGO_RIB_JOINTS_PER_RIB
			):
				errors.append("dorsal_rib_child_roster_drift:%s" % rib_name)
			if rib_node_names.size() != rib_joints.size():
				errors.append("dorsal_rib_joint_name_roster_drift:%s" % rib_name)
			if (
				rib_joints.is_empty()
				or rib.get_node_or_null(^"CurveJoint") != rib_joints[0]
			):
				errors.append("dorsal_rib_primary_joint_path_drift:%s" % rib_name)
			multimesh_batch_count += rib.find_children(
				"*", "MultiMeshInstance3D", true, false
			).size()

			for joint_index in rib_joints.size():
				var joint := rib_joints[joint_index]
				var sphere := joint.mesh as SphereMesh
				family_node_count += 1
				drawn_copy_count += 1
				node_instance_ids[joint.get_instance_id()] = true
				if not String(joint.name).is_empty():
					named_node_count += 1
				if sphere == null:
					errors.append(
						"dorsal_rib_joint_mesh_type_drift:%s/%s" % [rib_name, joint.name]
					)
					continue
				mesh_resource_ids[sphere.get_instance_id()] = true
				structural_surface_submission_count += sphere.get_surface_count()
				for surface_index in sphere.get_surface_count():
					var material := sphere.surface_get_material(surface_index)
					if material != null:
						material_resource_ids[material.get_instance_id()] = true
				if sphere != _dorsal_cargo_rib_joint_mesh:
					errors.append(
						"dorsal_rib_joint_mesh_identity_drift:%s/%s" % [rib_name, joint.name]
					)
				if (
					not is_equal_approx(sphere.radius, DORSAL_CARGO_RIB_JOINT_RADIUS)
					or not is_equal_approx(
						sphere.height, DORSAL_CARGO_RIB_JOINT_RADIUS * 2.0
					)
					or sphere.radial_segments != DORSAL_CARGO_RIB_JOINT_RADIAL_SEGMENTS
					or sphere.rings != DORSAL_CARGO_RIB_JOINT_RINGS
					or sphere.material != _jovian_materials.get("structure")
					or sphere.get_surface_count() != 1
				):
					errors.append(
						"dorsal_rib_joint_mesh_recipe_drift:%s/%s" % [rib_name, joint.name]
					)

				var expected_xy := DORSAL_CARGO_RIB_JOINT_XY[joint_index]
				var expected_position := Vector3(
					expected_xy.x,
					expected_xy.y,
					-2.4 + float(rib_index) * 2.72
				)
				if (
					not joint.position.is_equal_approx(expected_position)
					or not joint.rotation.is_equal_approx(Vector3.ZERO)
					or not joint.scale.is_equal_approx(Vector3.ONE)
					or not joint.visible
					or joint.layers != 1
					or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					or joint.material_override != null
					or joint.material_overlay != null
					or not is_zero_approx(joint.transparency)
					or not is_zero_approx(joint.extra_cull_margin)
					or joint.custom_aabb != AABB()
				):
					errors.append(
						"dorsal_rib_joint_renderer_recipe_drift:%s/%s" % [rib_name, joint.name]
					)

				var authority_state := {
					"descendants": 0,
					"collision_objects": 0,
					"collision_shapes": 0,
					"interaction_areas": 0,
					"markers": 0,
					"metadata_entries": 0,
					"scripted_nodes": 0,
					"grouped_nodes": 0,
					"processing_nodes": 0,
				}
				_accumulate_visual_family_authority(joint, joint, authority_state)
				descendant_node_count += int(authority_state["descendants"])
				collision_object_count += int(authority_state["collision_objects"])
				collision_shape_count += int(authority_state["collision_shapes"])
				interaction_area_count += int(authority_state["interaction_areas"])
				marker_count += int(authority_state["markers"])
				metadata_entry_count += int(authority_state["metadata_entries"])
				scripted_node_count += int(authority_state["scripted_nodes"])
				grouped_node_count += int(authority_state["grouped_nodes"])
				processing_node_count += int(authority_state["processing_nodes"])
				behavior_rows.append({
					"rib_index": rib_index,
					"joint_index": joint_index,
					"node_name": String(joint.name),
					"position": [joint.position.x, joint.position.y, joint.position.z],
					"rotation": [joint.rotation.x, joint.rotation.y, joint.rotation.z],
					"scale": [joint.scale.x, joint.scale.y, joint.scale.z],
				})

	if family_node_count != DORSAL_CARGO_RIB_JOINT_COPY_COUNT:
		errors.append("dorsal_rib_joint_node_count_drift")
	if named_node_count != DORSAL_CARGO_RIB_JOINT_COPY_COUNT:
		errors.append("dorsal_rib_joint_named_node_count_drift")
	if node_instance_ids.size() != DORSAL_CARGO_RIB_JOINT_COPY_COUNT:
		errors.append("dorsal_rib_joint_node_identity_count_drift")
	if mesh_resource_ids.size() != 1:
		errors.append("dorsal_rib_joint_mesh_resource_count_drift")
	if material_resource_ids.size() != 1:
		errors.append("dorsal_rib_joint_material_resource_count_drift")
	if structural_surface_submission_count != DORSAL_CARGO_RIB_JOINT_COPY_COUNT:
		errors.append("dorsal_rib_joint_submission_count_drift")
	if multimesh_batch_count != 0:
		errors.append("dorsal_rib_joint_unexpected_batch")
	if descendant_node_count != 0:
		errors.append("dorsal_rib_joint_gained_children")
	if collision_object_count != 0 or collision_shape_count != 0 or interaction_area_count != 0:
		errors.append("dorsal_rib_joint_gained_collision_or_interaction_authority")
	if metadata_entry_count != 0:
		errors.append("dorsal_rib_joint_gained_evidence_metadata")
	if (
		marker_count != 0
		or scripted_node_count != 0
		or grouped_node_count != 0
		or processing_node_count != 0
	):
		errors.append("dorsal_rib_joint_gained_lifecycle_or_semantic_authority")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"jovian_dorsal_cargo_rib_curve_joints",
		"current": {
			"geometry_nodes": family_node_count,
			"named_nodes": named_node_count,
			"drawn_copies": drawn_copy_count,
			"geometry_submissions": structural_surface_submission_count,
			"mesh_resource_allocations": mesh_resource_ids.size(),
			"material_resource_allocations": material_resource_ids.size(),
			"multimesh_batches": multimesh_batch_count,
		},
		"legacy": {
			"geometry_nodes": DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"named_nodes": DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"drawn_copies": DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"geometry_submissions": DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"mesh_resource_allocations": DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		},
		"delta": {
			"geometry_nodes": family_node_count - DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"drawn_copies": drawn_copy_count - DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"geometry_submissions": (
				structural_surface_submission_count - DORSAL_CARGO_RIB_JOINT_COPY_COUNT
			),
			"mesh_resource_allocations": (
				mesh_resource_ids.size() - DORSAL_CARGO_RIB_JOINT_COPY_COUNT
			),
			"material_resource_allocations": material_resource_ids.size() - 1,
		},
		"descendant_node_count": descendant_node_count,
		"collision_object_count": collision_object_count,
		"collision_shape_count": collision_shape_count,
		"interaction_area_count": interaction_area_count,
		"marker_count": marker_count,
		"metadata_entry_count": metadata_entry_count,
		"scripted_node_count": scripted_node_count,
		"grouped_node_count": grouped_node_count,
		"processing_node_count": processing_node_count,
		"batched": false,
		"driver_draw_call_claimed": false,
		"frame_time_claimed": false,
		"vram_claimed": false,
		"behavior_rows": behavior_rows,
	}.duplicate(true)


## Renderer-independent allocation evidence for the seven shoulder-rail joints.
##
## This freezes resource identity without claiming a batch or draw-call saving:
## the three rail roots, seven renderer nodes, visible copies, and submissions
## remain independently live.
func get_shoulder_rail_joint_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids: Dictionary = {}
	var material_resource_ids: Dictionary = {}
	var node_instance_ids: Dictionary = {}
	var family_node_count := 0
	var named_node_count := 0
	var drawn_copy_count := 0
	var structural_surface_submission_count := 0
	var multimesh_batch_count := 0
	var descendant_node_count := 0
	var collision_object_count := 0
	var collision_shape_count := 0
	var interaction_area_count := 0
	var marker_count := 0
	var metadata_entry_count := 0
	var scripted_node_count := 0
	var grouped_node_count := 0
	var processing_node_count := 0
	var behavior_rows: Array[Dictionary] = []

	if _jovian_visual == null or not is_instance_valid(_jovian_visual):
		errors.append("shoulder_rail_visual_root_unavailable")
	else:
		for rail_index in SHOULDER_RAIL_NAMES.size():
			var rail_name := SHOULDER_RAIL_NAMES[rail_index]
			var rail := _jovian_visual.get_node_or_null(NodePath(rail_name)) as Node3D
			var expected_positions := SHOULDER_RAIL_JOINT_POSITIONS[rail_index] as Array
			if rail == null:
				errors.append("shoulder_rail_root_missing:%s" % rail_name)
				continue
			if (
				not rail.position.is_equal_approx(Vector3.ZERO)
				or not rail.rotation.is_equal_approx(Vector3.ZERO)
				or not rail.scale.is_equal_approx(Vector3.ONE)
				or not rail.visible
			):
				errors.append("shoulder_rail_root_transform_drift:%s" % rail_name)

			var rail_joints: Array[MeshInstance3D] = []
			var rail_segment_count := 0
			for child in rail.get_children():
				var mesh_instance := child as MeshInstance3D
				if mesh_instance == null:
					continue
				if mesh_instance.mesh is SphereMesh:
					rail_joints.append(mesh_instance)
				elif String(mesh_instance.name).begins_with("Segment"):
					rail_segment_count += 1
			if (
				rail.get_child_count() != expected_positions.size() * 2 - 1
				or rail_segment_count != expected_positions.size() - 1
				or rail_joints.size() != expected_positions.size()
			):
				errors.append("shoulder_rail_child_roster_drift:%s" % rail_name)
			if rail_joints.is_empty() or rail.get_node_or_null(^"CurveJoint") != rail_joints[0]:
				errors.append("shoulder_rail_primary_joint_path_drift:%s" % rail_name)
			multimesh_batch_count += rail.find_children(
				"*", "MultiMeshInstance3D", true, false
			).size()

			for joint_index in rail_joints.size():
				var joint := rail_joints[joint_index]
				var sphere := joint.mesh as SphereMesh
				family_node_count += 1
				drawn_copy_count += 1
				node_instance_ids[joint.get_instance_id()] = true
				if not String(joint.name).is_empty():
					named_node_count += 1
				if sphere == null:
					errors.append("shoulder_rail_joint_mesh_type_drift:%s/%s" % [
					rail_name, joint.name,
				])
					continue
				mesh_resource_ids[sphere.get_instance_id()] = true
				structural_surface_submission_count += sphere.get_surface_count()
				for surface_index in sphere.get_surface_count():
					var material := sphere.surface_get_material(surface_index)
					if material != null:
						material_resource_ids[material.get_instance_id()] = true
				if sphere != _shoulder_rail_joint_mesh:
					errors.append("shoulder_rail_joint_mesh_identity_drift:%s/%s" % [
					rail_name, joint.name,
				])
				if (
					not is_equal_approx(sphere.radius, SHOULDER_RAIL_JOINT_RADIUS)
					or not is_equal_approx(sphere.height, SHOULDER_RAIL_JOINT_RADIUS * 2.0)
					or sphere.radial_segments != SHOULDER_RAIL_JOINT_RADIAL_SEGMENTS
					or sphere.rings != SHOULDER_RAIL_JOINT_RINGS
					or sphere.material != _jovian_materials.get("structure")
					or sphere.get_surface_count() != 1
				):
					errors.append("shoulder_rail_joint_mesh_recipe_drift:%s/%s" % [
					rail_name, joint.name,
				])
				var expected_position := expected_positions[joint_index] as Vector3
				if (
					not joint.position.is_equal_approx(expected_position)
					or not joint.rotation.is_equal_approx(Vector3.ZERO)
					or not joint.scale.is_equal_approx(Vector3.ONE)
					or not joint.visible
					or joint.layers != 1
					or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					or joint.material_override != null
					or joint.material_overlay != null
					or not is_zero_approx(joint.transparency)
					or not is_zero_approx(joint.extra_cull_margin)
					or joint.custom_aabb != AABB()
				):
					errors.append("shoulder_rail_joint_renderer_recipe_drift:%s/%s" % [
					rail_name, joint.name,
				])

				var authority_state := {
					"descendants": 0,
					"collision_objects": 0,
					"collision_shapes": 0,
					"interaction_areas": 0,
					"markers": 0,
					"metadata_entries": 0,
					"scripted_nodes": 0,
					"grouped_nodes": 0,
					"processing_nodes": 0,
				}
				_accumulate_visual_family_authority(joint, joint, authority_state)
				descendant_node_count += int(authority_state["descendants"])
				collision_object_count += int(authority_state["collision_objects"])
				collision_shape_count += int(authority_state["collision_shapes"])
				interaction_area_count += int(authority_state["interaction_areas"])
				marker_count += int(authority_state["markers"])
				metadata_entry_count += int(authority_state["metadata_entries"])
				scripted_node_count += int(authority_state["scripted_nodes"])
				grouped_node_count += int(authority_state["grouped_nodes"])
				processing_node_count += int(authority_state["processing_nodes"])
				behavior_rows.append({
					"rail_name": String(rail_name),
					"joint_index": joint_index,
					"node_name": String(joint.name),
					"position": [joint.position.x, joint.position.y, joint.position.z],
					"rotation": [joint.rotation.x, joint.rotation.y, joint.rotation.z],
					"scale": [joint.scale.x, joint.scale.y, joint.scale.z],
				})

	if family_node_count != SHOULDER_RAIL_JOINT_COPY_COUNT:
		errors.append("shoulder_rail_joint_node_count_drift")
	if named_node_count != SHOULDER_RAIL_JOINT_COPY_COUNT:
		errors.append("shoulder_rail_joint_named_node_count_drift")
	if node_instance_ids.size() != SHOULDER_RAIL_JOINT_COPY_COUNT:
		errors.append("shoulder_rail_joint_node_identity_count_drift")
	if mesh_resource_ids.size() != 1:
		errors.append("shoulder_rail_joint_mesh_resource_count_drift")
	if material_resource_ids.size() != 1:
		errors.append("shoulder_rail_joint_material_resource_count_drift")
	if structural_surface_submission_count != SHOULDER_RAIL_JOINT_COPY_COUNT:
		errors.append("shoulder_rail_joint_submission_count_drift")
	if multimesh_batch_count != 0:
		errors.append("shoulder_rail_joint_unexpected_batch")
	if descendant_node_count != 0:
		errors.append("shoulder_rail_joint_gained_children")
	if collision_object_count != 0 or collision_shape_count != 0 or interaction_area_count != 0:
		errors.append("shoulder_rail_joint_gained_collision_or_interaction_authority")
	if metadata_entry_count != 0:
		errors.append("shoulder_rail_joint_gained_evidence_metadata")
	if (
		marker_count != 0
		or scripted_node_count != 0
		or grouped_node_count != 0
		or processing_node_count != 0
	):
		errors.append("shoulder_rail_joint_gained_lifecycle_or_semantic_authority")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"jovian_exterior_shoulder_rail_curve_joints",
		"current": {
			"geometry_nodes": family_node_count,
			"named_nodes": named_node_count,
			"drawn_copies": drawn_copy_count,
			"geometry_submissions": structural_surface_submission_count,
			"mesh_resource_allocations": mesh_resource_ids.size(),
			"material_resource_allocations": material_resource_ids.size(),
			"multimesh_batches": multimesh_batch_count,
		},
		"legacy": {
			"geometry_nodes": SHOULDER_RAIL_JOINT_COPY_COUNT,
			"named_nodes": SHOULDER_RAIL_JOINT_COPY_COUNT,
			"drawn_copies": SHOULDER_RAIL_JOINT_COPY_COUNT,
			"geometry_submissions": SHOULDER_RAIL_JOINT_COPY_COUNT,
			"mesh_resource_allocations": SHOULDER_RAIL_JOINT_COPY_COUNT,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		},
		"delta": {
			"geometry_nodes": family_node_count - SHOULDER_RAIL_JOINT_COPY_COUNT,
			"drawn_copies": drawn_copy_count - SHOULDER_RAIL_JOINT_COPY_COUNT,
			"geometry_submissions": (
				structural_surface_submission_count - SHOULDER_RAIL_JOINT_COPY_COUNT
			),
			"mesh_resource_allocations": (
				mesh_resource_ids.size() - SHOULDER_RAIL_JOINT_COPY_COUNT
			),
			"material_resource_allocations": material_resource_ids.size() - 1,
		},
		"descendant_node_count": descendant_node_count,
		"collision_object_count": collision_object_count,
		"collision_shape_count": collision_shape_count,
		"interaction_area_count": interaction_area_count,
		"marker_count": marker_count,
		"metadata_entry_count": metadata_entry_count,
		"scripted_node_count": scripted_node_count,
		"grouped_node_count": grouped_node_count,
		"processing_node_count": processing_node_count,
		"batched": false,
		"driver_draw_call_claimed": false,
		"frame_time_claimed": false,
		"vram_claimed": false,
		"behavior_rows": behavior_rows,
	}.duplicate(true)


## Renderer-independent allocation evidence for the 20 moving-interior cargo
## frame joints. Resource identity is the only changed currency: every frame
## root, joint node, visible copy, transform, renderer value, and submission
## remains live under the same connected CargoBay hierarchy.
func get_cargo_frame_joint_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids: Dictionary = {}
	var material_resource_ids: Dictionary = {}
	var node_instance_ids: Dictionary = {}
	var family_node_count := 0
	var named_node_count := 0
	var drawn_copy_count := 0
	var structural_surface_submission_count := 0
	var multimesh_batch_count := 0
	var descendant_node_count := 0
	var collision_object_count := 0
	var collision_shape_count := 0
	var interaction_area_count := 0
	var marker_count := 0
	var metadata_entry_count := 0
	var scripted_node_count := 0
	var grouped_node_count := 0
	var processing_node_count := 0
	var behavior_rows: Array[Dictionary] = []
	var moving_interior_attached := (
		_cargo_bay != null
		and is_instance_valid(_cargo_bay)
		and _walkable_interior != null
		and is_instance_valid(_walkable_interior)
		and _cargo_bay.get_parent() == _walkable_interior
		and _walkable_interior.get_parent() == self
		and _moving_interior_component != null
		and _moving_interior_component.get_moving_frame() == self
	)

	if not moving_interior_attached:
		errors.append("cargo_frame_moving_interior_attachment_drift")
	if _cargo_bay == null or not is_instance_valid(_cargo_bay):
		errors.append("cargo_frame_visual_root_unavailable")
	else:
		for frame_index in CARGO_FRAME_COUNT:
			var frame_name := "CargoFrame%02d" % frame_index
			var frame := _cargo_bay.get_node_or_null(NodePath(frame_name)) as Node3D
			if frame == null:
				errors.append("cargo_frame_root_missing:%s" % frame_name)
				continue
			if (
				not frame.position.is_equal_approx(Vector3.ZERO)
				or not frame.rotation.is_equal_approx(Vector3.ZERO)
				or not frame.scale.is_equal_approx(Vector3.ONE)
				or not frame.visible
			):
				errors.append("cargo_frame_root_transform_drift:%s" % frame_name)

			var frame_joints: Array[MeshInstance3D] = []
			var frame_segment_count := 0
			var frame_node_names: Dictionary = {}
			for child in frame.get_children():
				var mesh_instance := child as MeshInstance3D
				if mesh_instance == null:
					continue
				if mesh_instance.mesh is SphereMesh:
					frame_joints.append(mesh_instance)
					frame_node_names[String(mesh_instance.name)] = true
				elif String(mesh_instance.name).begins_with("Segment"):
					frame_segment_count += 1
			if (
				frame.get_child_count() != 9
				or frame_segment_count != 4
				or frame_joints.size() != CARGO_FRAME_JOINTS_PER_FRAME
			):
				errors.append("cargo_frame_child_roster_drift:%s" % frame_name)
			if frame_node_names.size() != frame_joints.size():
				errors.append("cargo_frame_joint_name_roster_drift:%s" % frame_name)
			if frame_joints.is_empty() or frame.get_node_or_null(^"CurveJoint") != frame_joints[0]:
				errors.append("cargo_frame_primary_joint_path_drift:%s" % frame_name)
			multimesh_batch_count += frame.find_children(
				"*", "MultiMeshInstance3D", true, false
			).size()

			for joint_index in frame_joints.size():
				var joint := frame_joints[joint_index]
				var sphere := joint.mesh as SphereMesh
				family_node_count += 1
				drawn_copy_count += 1
				node_instance_ids[joint.get_instance_id()] = true
				if not String(joint.name).is_empty():
					named_node_count += 1
				if sphere == null:
					errors.append("cargo_frame_joint_mesh_type_drift:%s/%s" % [
						frame_name, joint.name,
					])
					continue
				mesh_resource_ids[sphere.get_instance_id()] = true
				structural_surface_submission_count += sphere.get_surface_count()
				for surface_index in sphere.get_surface_count():
					var material := sphere.surface_get_material(surface_index)
					if material != null:
						material_resource_ids[material.get_instance_id()] = true
				if sphere != _cargo_frame_joint_mesh:
					errors.append("cargo_frame_joint_mesh_identity_drift:%s/%s" % [
						frame_name, joint.name,
					])
				if (
					not is_equal_approx(sphere.radius, CARGO_FRAME_JOINT_RADIUS)
					or not is_equal_approx(sphere.height, CARGO_FRAME_JOINT_RADIUS * 2.0)
					or sphere.radial_segments != CARGO_FRAME_JOINT_RADIAL_SEGMENTS
					or sphere.rings != CARGO_FRAME_JOINT_RINGS
					or sphere.material != _jovian_materials.get("hull_cool")
					or sphere.get_surface_count() != 1
				):
					errors.append("cargo_frame_joint_mesh_recipe_drift:%s/%s" % [
						frame_name, joint.name,
					])

				var expected_xy := CARGO_FRAME_JOINT_XY[joint_index]
				var expected_position := Vector3(
					expected_xy.x,
					expected_xy.y,
					CARGO_FRAME_START_Z + float(frame_index) * CARGO_FRAME_Z_STEP
				)
				if (
					not joint.position.is_equal_approx(expected_position)
					or not joint.rotation.is_equal_approx(Vector3.ZERO)
					or not joint.scale.is_equal_approx(Vector3.ONE)
					or not joint.visible
					or joint.layers != 1
					or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					or joint.material_override != null
					or joint.material_overlay != null
					or not is_zero_approx(joint.transparency)
					or not is_zero_approx(joint.extra_cull_margin)
					or joint.custom_aabb != AABB()
				):
					errors.append("cargo_frame_joint_renderer_recipe_drift:%s/%s" % [
						frame_name, joint.name,
					])

				var authority_state := {
					"descendants": 0,
					"collision_objects": 0,
					"collision_shapes": 0,
					"interaction_areas": 0,
					"markers": 0,
					"metadata_entries": 0,
					"scripted_nodes": 0,
					"grouped_nodes": 0,
					"processing_nodes": 0,
				}
				_accumulate_visual_family_authority(joint, joint, authority_state)
				descendant_node_count += int(authority_state["descendants"])
				collision_object_count += int(authority_state["collision_objects"])
				collision_shape_count += int(authority_state["collision_shapes"])
				interaction_area_count += int(authority_state["interaction_areas"])
				marker_count += int(authority_state["markers"])
				metadata_entry_count += int(authority_state["metadata_entries"])
				scripted_node_count += int(authority_state["scripted_nodes"])
				grouped_node_count += int(authority_state["grouped_nodes"])
				processing_node_count += int(authority_state["processing_nodes"])
				behavior_rows.append({
					"frame_index": frame_index,
					"joint_index": joint_index,
					"node_name": String(joint.name),
					"position": [joint.position.x, joint.position.y, joint.position.z],
					"rotation": [joint.rotation.x, joint.rotation.y, joint.rotation.z],
					"scale": [joint.scale.x, joint.scale.y, joint.scale.z],
				})

	if family_node_count != CARGO_FRAME_JOINT_COPY_COUNT:
		errors.append("cargo_frame_joint_node_count_drift")
	if named_node_count != CARGO_FRAME_JOINT_COPY_COUNT:
		errors.append("cargo_frame_joint_named_node_count_drift")
	if node_instance_ids.size() != CARGO_FRAME_JOINT_COPY_COUNT:
		errors.append("cargo_frame_joint_node_identity_count_drift")
	if mesh_resource_ids.size() != 1:
		errors.append("cargo_frame_joint_mesh_resource_count_drift")
	if material_resource_ids.size() != 1:
		errors.append("cargo_frame_joint_material_resource_count_drift")
	if structural_surface_submission_count != CARGO_FRAME_JOINT_COPY_COUNT:
		errors.append("cargo_frame_joint_submission_count_drift")
	if multimesh_batch_count != 0:
		errors.append("cargo_frame_joint_unexpected_batch")
	if descendant_node_count != 0:
		errors.append("cargo_frame_joint_gained_children")
	if collision_object_count != 0 or collision_shape_count != 0 or interaction_area_count != 0:
		errors.append("cargo_frame_joint_gained_collision_or_interaction_authority")
	if metadata_entry_count != 0:
		errors.append("cargo_frame_joint_gained_evidence_metadata")
	if (
		marker_count != 0
		or scripted_node_count != 0
		or grouped_node_count != 0
		or processing_node_count != 0
	):
		errors.append("cargo_frame_joint_gained_lifecycle_or_semantic_authority")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"jovian_moving_interior_cargo_frame_curve_joints",
		"current": {
			"geometry_nodes": family_node_count,
			"named_nodes": named_node_count,
			"drawn_copies": drawn_copy_count,
			"geometry_submissions": structural_surface_submission_count,
			"mesh_resource_allocations": mesh_resource_ids.size(),
			"material_resource_allocations": material_resource_ids.size(),
			"multimesh_batches": multimesh_batch_count,
		},
		"legacy": {
			"geometry_nodes": CARGO_FRAME_JOINT_COPY_COUNT,
			"named_nodes": CARGO_FRAME_JOINT_COPY_COUNT,
			"drawn_copies": CARGO_FRAME_JOINT_COPY_COUNT,
			"geometry_submissions": CARGO_FRAME_JOINT_COPY_COUNT,
			"mesh_resource_allocations": CARGO_FRAME_JOINT_COPY_COUNT,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		},
		"delta": {
			"geometry_nodes": family_node_count - CARGO_FRAME_JOINT_COPY_COUNT,
			"drawn_copies": drawn_copy_count - CARGO_FRAME_JOINT_COPY_COUNT,
			"geometry_submissions": (
				structural_surface_submission_count - CARGO_FRAME_JOINT_COPY_COUNT
			),
			"mesh_resource_allocations": (
				mesh_resource_ids.size() - CARGO_FRAME_JOINT_COPY_COUNT
			),
			"material_resource_allocations": material_resource_ids.size() - 1,
		},
		"moving_interior_attached": moving_interior_attached,
		"descendant_node_count": descendant_node_count,
		"collision_object_count": collision_object_count,
		"collision_shape_count": collision_shape_count,
		"interaction_area_count": interaction_area_count,
		"marker_count": marker_count,
		"metadata_entry_count": metadata_entry_count,
		"scripted_node_count": scripted_node_count,
		"grouped_node_count": grouped_node_count,
		"processing_node_count": processing_node_count,
		"batched": false,
		"driver_draw_call_claimed": false,
		"frame_time_claimed": false,
		"vram_claimed": false,
		"behavior_rows": behavior_rows,
	}.duplicate(true)


func _accumulate_visual_family_authority(
	root_joint: MeshInstance3D,
	node: Node,
	state: Dictionary
	) -> void:
	if node != root_joint:
		state["descendants"] = int(state["descendants"]) + 1
	if node is CollisionObject3D:
		state["collision_objects"] = int(state["collision_objects"]) + 1
	if node is CollisionShape3D:
		state["collision_shapes"] = int(state["collision_shapes"]) + 1
	if node is Area3D:
		state["interaction_areas"] = int(state["interaction_areas"]) + 1
	if node is Marker3D:
		state["markers"] = int(state["markers"]) + 1
	state["metadata_entries"] = int(state["metadata_entries"]) + node.get_meta_list().size()
	if node.get_script() != null:
		state["scripted_nodes"] = int(state["scripted_nodes"]) + 1
	if not node.get_groups().is_empty():
		state["grouped_nodes"] = int(state["grouped_nodes"]) + 1
	if (
		node.is_processing()
		or node.is_physics_processing()
		or node.is_processing_input()
		or node.is_processing_unhandled_input()
	):
		state["processing_nodes"] = int(state["processing_nodes"]) + 1
	for child in node.get_children():
		_accumulate_visual_family_authority(root_joint, child, state)


func _build_jovian_variant(_controller: HeroShip) -> bool:
	var inherited_visual := get_variant_visual_root()
	if inherited_visual == null:
		return false
	# Keep common-controller cockpit objects and their private references intact,
	# but relocate the entire cabin into the freighter's forward flight deck.
	var cockpit := inherited_visual.get_node_or_null("CockpitInterior") as Node3D
	var canopy := inherited_visual.get_node_or_null("CanopyHinge") as Node3D
	var hinge_bar := inherited_visual.get_node_or_null("CanopyHingeBar") as Node3D
	var hinge_mounts := inherited_visual.find_children("*CanopyHingeMount", "Node3D", false, false)
	for preserved in [cockpit, canopy, hinge_bar]:
		if preserved != null:
			preserved.reparent(self, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(self, true)
	if inherited_visual.get_parent() != null:
		inherited_visual.get_parent().remove_child(inherited_visual)
	inherited_visual.queue_free()

	_jovian_visual = Node3D.new()
	_jovian_visual.name = "JovianFreighterVisual"
	_jovian_visual.set_meta("geometry_status", EVIDENCE_STATUS)
	_jovian_visual.set_meta("authenticated_historical_silhouette", false)
	_jovian_visual.set_meta("content_note", PROVISIONAL_NOTE)
	add_child(_jovian_visual)
	for preserved in [cockpit, canopy, hinge_bar]:
		if preserved != null:
			preserved.reparent(_jovian_visual, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(_jovian_visual, true)

	_create_jovian_materials()
	_relocate_and_restyle_cockpit(cockpit, canopy, hinge_bar, hinge_mounts)
	_build_exterior()
	_build_connected_interior()
	_build_propulsion_and_gear()
	_build_fitted_freighter_details()
	_fitout_mesh_cache.clear()
	_build_hull_markings()
	_configure_interior_furnishing_ranges()
	_build_engine_damage_cue()
	_replace_collision_and_markers()
	_bind_optional_interior_frame()
	if not replace_variant_visual_root(_jovian_visual):
		return false
	return true


func _create_jovian_materials() -> void:
	_jovian_materials.hull_warm = _jovian_material(HULL_WARM, 0.08, 0.58)
	_jovian_materials.hull_cool = _jovian_material(HULL_COOL, 0.10, 0.62)
	# Freighter secondary structure. Before this pass structure/dark/amber sat at
	# roughness 0.36/0.30/0.35 and cargo_blue/deck at 0.47/0.52 — the whole
	# working half of the ship inside a 0.22 band, so the painted bulkheads, the
	# oiled load rails and the yellow cargo-aperture frame all returned the same
	# highlight and separated only by hue. They are now painted plate, oiled
	# steel, matte industrial paint, a painted crate and worn deck tread.
	# Colours are unchanged.
	_jovian_materials.structure = _jovian_material(JOVIAN_STRUCTURE, 0.34, 0.66)
	_jovian_materials.dark = _jovian_material(JOVIAN_STRUCTURE_DARK, 0.72, 0.22)
	_jovian_materials.teal = _jovian_material(FREIGHT_TEAL.darkened(0.28), 0.24, 0.58)
	_jovian_materials.amber = _jovian_material(FREIGHT_AMBER.darkened(0.22), 0.10, 0.72)
	_jovian_materials.cargo_blue = _jovian_material(CARGO_BLUE.darkened(0.40), 0.10, 0.78)
	_jovian_materials.cabin_cloth = _jovian_material(Color("536c6d"), 0.0, 0.88)
	CabinTextile.apply(_jovian_materials.cabin_cloth)
	_jovian_materials.cabin_shell = _jovian_material(Color("929488"), 0.08, 0.72)
	_jovian_materials.cabin_liner = _jovian_material(Color("b0ada0"), 0.02, 0.91)
	_jovian_materials.webbing = _jovian_material(Color("666456"), 0.0, 0.98)
	_jovian_materials.freight_shell = _jovian_material(Color("65716d"), 0.12, 0.79)
	_jovian_materials.deck = _jovian_material(DECK_GREY, 0.40, 0.74)
	_jovian_materials.thermal_cover = _jovian_material(Color("697779"), 0.12, 0.77)
	_jovian_materials.engine = _jovian_material(ENGINE_AQUA, 0.1, 0.16, ENGINE_AQUA, 3.2)
	_jovian_materials.nav_red = _jovian_material(JOVIAN_NAV_RED, 0.08, 0.2, JOVIAN_NAV_RED, 2.4)
	_jovian_materials.nav_green = _jovian_material(JOVIAN_NAV_GREEN, 0.08, 0.2, JOVIAN_NAV_GREEN, 2.4)
	_jovian_materials.interior_light = _jovian_material(Color("d5f9ee"), 0.0, 0.24, Color("b7fff0"), 2.5)
	_jovian_materials.display = _jovian_material(Color("183b40"), 0.18, 0.22, FREIGHT_TEAL, 2.8)
	_jovian_materials.liner = _jovian_material(Color("686f6b"), 0.04, 0.85)
	_jovian_materials.glass = _jovian_glass(Color(0.12, 0.48, 0.52, 0.2))
	# Continuous paint over manufactured shell geometry. The old cargo-panel
	# image stamped deep rectangular cells over every curve at the same scale.
	var hull_normal := load("res://assets/materials/manufactured-paint-normal.png") as Texture2D
	for hull_material: StandardMaterial3D in [_jovian_materials.hull_warm, _jovian_materials.hull_cool, _jovian_materials.thermal_cover]:
		ShipSurfaceDetail.bind_manufactured_paint(hull_material)
		hull_material.uv1_triplanar = true
		hull_material.uv1_world_triplanar = false
		hull_material.uv1_triplanar_sharpness = 4.5
		hull_material.uv1_scale = Vector3.ONE * 0.24
		hull_material.clearcoat = 0.04
		hull_material.clearcoat_roughness = 0.58
	# The working rails, cargo fittings and deck use the shared microtexture at
	# their own scale. Their paint/steel roughness and colours remain distinct.
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.structure, hull_normal, 2.0, 1.20)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.dark, hull_normal, 4.0, 0.90)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.amber, hull_normal, 5.0, 1.30)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.cargo_blue, hull_normal, 2.0, 1.20)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.deck, hull_normal, 2.2, 1.00)


func get_variant_materials() -> Dictionary:
	return _jovian_materials


func _relocate_and_restyle_cockpit(
		cockpit: Node3D,
		canopy: Node3D,
		hinge_bar: Node3D,
		hinge_mounts: Array[Node]
	) -> void:
	const COCKPIT_SHIFT := Vector3(0.0, -1.38, -8.15)
	if cockpit != null:
		cockpit.position += COCKPIT_SHIFT
		cockpit.set_meta("space_id", &"pilot_cockpit")
		var rear_wall := cockpit.get_node_or_null("RearPressureWall") as MeshInstance3D
		if rear_wall != null:
			# The freighter connects this former fighter rear bulkhead to a real
			# passenger passage. A new open pressure frame replaces the solid panel.
			rear_wall.visible = false
		for surface in cockpit.find_children("*Sidewall", "MeshInstance3D", true, false):
			(surface as MeshInstance3D).material_override = _jovian_materials.structure
		for surface in cockpit.find_children("*Sill", "MeshInstance3D", true, false):
			(surface as MeshInstance3D).material_override = _jovian_materials.amber
		# Keep the shared flight display and its bezel as dark instrument faces.
		# Only individual console keys receive the freighter emissive accent.
		for key in cockpit.find_children("*ConsoleKey*", "MeshInstance3D", true, false):
			(key as MeshInstance3D).material_override = _jovian_materials.display
	if canopy != null:
		canopy.position += COCKPIT_SHIFT
		for glass in canopy.find_children("CanopyGlass", "MeshInstance3D", true, false):
			(glass as MeshInstance3D).material_override = _jovian_materials.glass
		for frame in canopy.find_children("*Canopy*Frame", "MeshInstance3D", true, false):
			(frame as MeshInstance3D).material_override = _jovian_materials.structure
		for rail in canopy.find_children("*Canopy*Rail", "MeshInstance3D", true, false):
			(rail as MeshInstance3D).material_override = _jovian_materials.amber
	if hinge_bar != null:
		hinge_bar.position += COCKPIT_SHIFT
		(hinge_bar as MeshInstance3D).material_override = _jovian_materials.structure
	for mount in hinge_mounts:
		var mount_3d := mount as Node3D
		mount_3d.position += COCKPIT_SHIFT
		if mount_3d is MeshInstance3D:
			(mount_3d as MeshInstance3D).material_override = _jovian_materials.amber


func _build_exterior() -> void:
	# A rolled bow apron supports the pressure glazing. Its deck stays flat
	# across the ship while the rim follows a continuous manufactured radius.
	_forward_bow_apron(
		_jovian_visual,
		"ForwardFlightDeck",
		Vector3(0.0, -0.02, 0.0),
		PackedVector3Array([
			Vector3(1.20, 0.12, -13.55),
			Vector3(2.30, 0.32, -12.15),
			Vector3(3.35, 0.43, -10.25),
			Vector3(4.15, 0.54, -7.2),
			Vector3(4.5, 0.48, -4.4),
		]),
		_jovian_materials.hull_warm
	)
	_shoulder_rail_joint_mesh = SphereMesh.new()
	_shoulder_rail_joint_mesh.radius = SHOULDER_RAIL_JOINT_RADIUS
	_shoulder_rail_joint_mesh.height = SHOULDER_RAIL_JOINT_RADIUS * 2.0
	_shoulder_rail_joint_mesh.radial_segments = SHOULDER_RAIL_JOINT_RADIAL_SEGMENTS
	_shoulder_rail_joint_mesh.rings = SHOULDER_RAIL_JOINT_RINGS
	_shoulder_rail_joint_mesh.material = _jovian_materials.structure
	# The pressure crown folds directly into broad load-bearing sponsons. Their
	# inboard faces stop at the cabin wall; the port sections retain the full
	# boarding aperture rather than bridging it with a decorative solid.
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var side_name := "Port" if side < 0.0 else "Starboard"
		if side < 0.0:
			_freighter_sponson("PortCargoShoulder", side, PackedVector3Array([
				Vector3(0.46, 0.28, -8.2), Vector3(0.90, 0.74, -6.15),
				Vector3(1.0, 1.0, -3.1), Vector3(1.0, 1.0, 1.12)]))
			_freighter_sponson("PortAftCargoShoulder", side, PackedVector3Array([
				Vector3(1.0, 1.0, 5.28), Vector3(1.0, 1.0, 8.25),
				Vector3(0.90, 0.78, 10.7), Vector3(0.70, 0.62, 11.2)]))
		else:
			_freighter_sponson("StarboardCargoShoulder", side, PackedVector3Array([
				Vector3(0.46, 0.28, -8.2), Vector3(0.90, 0.74, -6.15),
				Vector3(1.0, 1.0, -3.1), Vector3(1.0, 1.0, 8.25),
				Vector3(0.90, 0.78, 10.7), Vector3(0.70, 0.62, 11.2)]))
		# Service rails follow the crown/shoulder joint. Relocating their whole
		# shared recipe avoids exposed tube ends piercing the new sloping skin.
		if side < 0.0:
			_curve_tube(_jovian_visual, "PortForwardShoulderRail", PackedVector3Array([
				Vector3(-5.85, 4.42, -3.0), Vector3(-5.85, 4.42, 0.95),
			]), 0.13, _jovian_materials.structure, _shoulder_rail_joint_mesh)
			_curve_tube(_jovian_visual, "PortAftShoulderRail", PackedVector3Array([
				Vector3(-5.85, 4.42, 5.48), Vector3(-5.85, 4.42, 8.1),
			]), 0.13, _jovian_materials.structure, _shoulder_rail_joint_mesh)
		else:
			_curve_tube(
				_jovian_visual,
				"StarboardShoulderRail",
				PackedVector3Array([
					Vector3(side * 5.85, 4.42, -3.0),
					Vector3(side * 5.85, 4.42, 1.0),
					Vector3(side * 5.85, 4.42, 8.1),
				]),
				0.13,
				_jovian_materials.structure,
				_shoulder_rail_joint_mesh
			)
		for panel_index in 4:
			if side < 0.0 and panel_index == 2:
				continue
			var panel_z := -4.1 + float(panel_index) * 3.75
			_service_panel_transforms.append(Transform3D(
				Basis.IDENTITY, Vector3(side * 8.04, 2.12, panel_z)
			))
		_sphere(
			_jovian_visual,
			side_name + "NavigationLight",
			Vector3(side * 8.02, 3.7, 8.4),
			0.16,
			_jovian_materials.nav_red if side < 0.0 else _jovian_materials.nav_green
		)
	_build_forward_cargo_guide_silhouette()

	# Arched roof and keel members visually unify the load-bearing shoulders.
	_pressed_roof(_jovian_visual, "CargoRoofShell", 5.75, 4.43, 0.38,
		PackedVector3Array(CARGO_ROOF_SECTIONS),
		0.12, _jovian_materials.hull_warm)
	# The cabin and flight deck now sit in one manufactured pressure fairing.
	# Its cheeks remain outside the cabin walls and its crown clears the roof.
	_pressed_roof(_jovian_visual, "ForwardCabinCrown", 3.56, 3.80, 0.43,
		PackedVector3Array(CABIN_ROOF_SECTIONS),
		0.12, _jovian_materials.hull_warm)
	for side in [-1.0, 1.0]:
		_flight_deck_transition(side)
	# A full-width raked pressure windscreen belongs to the freighter hull.
	# The common functional seat/canopy stays inside this volume; boarding and
	# flight-deck access still use the connected passenger/cargo route.
	var screen_tool := SurfaceTool.new()
	screen_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	screen_tool.set_material(_jovian_glass(Color(0.10, 0.19, 0.21, 0.58)))
	var screen_bottom_left := Vector3(-2.25, 0.94, -11.60)
	var screen_top_left := Vector3(-2.48, 3.10, -9.65)
	var screen_top_right := Vector3(2.48, 3.10, -9.65)
	var screen_bottom_right := Vector3(2.25, 0.94, -11.60)
	_skin_quad(screen_tool, screen_bottom_left, screen_top_left, screen_top_right, screen_bottom_right)
	_skin_quad(screen_tool, screen_bottom_left, Vector3(-3.2, 0.60, -7.65), Vector3(-3.2, 3.65, -7.65), screen_top_left)
	_skin_quad(screen_tool, screen_top_right, Vector3(3.2, 3.65, -7.65), Vector3(3.2, 0.60, -7.65), screen_bottom_right)
	var screen := MeshInstance3D.new()
	screen.name = "FreighterPressureWindscreen"
	# The transparent pane does not cast an opaque dithered silhouette across
	# the bow apron; the surrounding pressure frames cast the structural shadow.
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.mesh = screen_tool.commit()
	_jovian_visual.add_child(screen)
	_curve_tube(_jovian_visual, "FlightDeckWindscreenSeal", PackedVector3Array([
		screen_bottom_left, screen_top_left, screen_top_right, screen_bottom_right, screen_bottom_left]), 0.075, _jovian_materials.structure)
	_curve_tube(_jovian_visual, "FlightDeckWindscreenCentrePost", PackedVector3Array([
		Vector3(0.0, 0.94, -11.60), Vector3(0.0, 3.10, -9.65)]), 0.045, _jovian_materials.structure)
	for side in [-1.0, 1.0]:
		_curve_tube(_jovian_visual, "FlightDeckQuarterlightSeal", PackedVector3Array([
			Vector3(side * 2.25, 0.94, -11.60), Vector3(side * 3.2, 0.60, -7.65), Vector3(side * 3.2, 3.65, -7.65), Vector3(side * 2.48, 3.10, -9.65)]), 0.065, _jovian_materials.structure)
	_pressed_roof(_jovian_visual, "FlightDeckWindscreenCowl", 2.25, 0.35, 0.10,
		PackedVector3Array([Vector3(0.90, 0.0, -12.20), Vector3(1.0, 0.50, -11.60)]), 0.10, _jovian_materials.hull_cool)
	# Sparse panel divisions follow the broad stamped crown, not a tiled image.
	for seam_z in [0.2, 3.7, 7.2]:
		_pressed_roof(_jovian_visual, "CargoPressureJoint", 5.75, 4.445, 0.38,
			PackedVector3Array([Vector3(1.0, 0.0, seam_z - 0.026), Vector3(1.0, 0.0, seam_z + 0.026)]),
			0.014, _jovian_materials.dark)
	_build_pressure_shell_panels()
	_dorsal_cargo_rib_joint_mesh = SphereMesh.new()
	_dorsal_cargo_rib_joint_mesh.radius = DORSAL_CARGO_RIB_JOINT_RADIUS
	_dorsal_cargo_rib_joint_mesh.height = DORSAL_CARGO_RIB_JOINT_RADIUS * 2.0
	_dorsal_cargo_rib_joint_mesh.radial_segments = DORSAL_CARGO_RIB_JOINT_RADIAL_SEGMENTS
	_dorsal_cargo_rib_joint_mesh.rings = DORSAL_CARGO_RIB_JOINT_RINGS
	_dorsal_cargo_rib_joint_mesh.material = _jovian_materials.structure
	for rib_index in DORSAL_CARGO_RIB_COUNT:
		var rib_z := -2.4 + float(rib_index) * 2.72
		_curve_tube(
			_jovian_visual,
			"DorsalCargoRib%02d" % rib_index,
			PackedVector3Array([
				Vector3(-5.55, 4.28, rib_z),
				Vector3(-3.7, 4.72, rib_z),
				Vector3(0.0, 4.9, rib_z),
				Vector3(3.7, 4.72, rib_z),
				Vector3(5.55, 4.28, rib_z),
			]),
			DORSAL_CARGO_RIB_JOINT_RADIUS,
			_jovian_materials.structure,
			_dorsal_cargo_rib_joint_mesh
		)
	_box(_jovian_visual, "VentralKeel", Vector3(0.0, 0.02, 3.25), Vector3(2.2, 0.42, 19.4), _jovian_materials.structure)
	for side in [-1.0, 1.0]:
		_box(_jovian_visual, "VentralLoadRail", Vector3(side * 3.9, 0.15, 2.9), Vector3(0.42, 0.48, 18.5), _jovian_materials.dark)

	# Aft machinery deck, tapered tail bridge, radiators, and restrained colour
	# blocks make the class readable as a utility vessel rather than a fighter.
	_armour_pod(
		_jovian_visual,
		"AftMachinerySpine",
		Vector3(0.0, 2.25, 0.0),
		PackedVector3Array([
			Vector3(4.5, 1.35, 8.4),
			Vector3(4.85, 1.42, 10.5),
			Vector3(3.9, 1.15, 12.25),
			Vector3(2.2, 0.72, 13.35),
		]),
		_jovian_materials.hull_cool,
		24
	)
	for side in [-1.0, 1.0]:
		_planform_surface(
			_jovian_visual,
			"PortRadiator" if side < 0.0 else "StarboardRadiator",
			PackedVector3Array([
				Vector3(side * 4.6, 3.15, 8.9),
				Vector3(side * 8.2, 2.85, 9.45),
				Vector3(side * 8.45, 2.55, 12.0),
				Vector3(side * 4.05, 2.85, 11.55),
			]),
			0.15,
			_jovian_materials.structure
		)
		for stripe_index in 3:
			_load_mark_transforms.append(Transform3D(
				Basis.from_euler(Vector3(0.0, 0.0, side * deg_to_rad(18.0))),
				Vector3(side * 7.88, 1.15, -1.3 + stripe_index * 1.1)
			))
	_service_panel_mesh = _rounded_box_mesh(SERVICE_PANEL_SIZE, _jovian_materials.structure)
	var service_panels := MultiMesh.new()
	service_panels.transform_format = MultiMesh.TRANSFORM_3D
	service_panels.mesh = _service_panel_mesh
	service_panels.instance_count = _service_panel_transforms.size()
	service_panels.visible_instance_count = -1
	service_panels.buffer = _encode_load_mark_transforms(_service_panel_transforms)
	service_panels.custom_aabb = _load_mark_bounds(
		_service_panel_mesh.get_aabb(), _service_panel_transforms
	)
	_service_panel_batch = MultiMeshInstance3D.new()
	_service_panel_batch.name = "ServicePanelBatch"
	_service_panel_batch.multimesh = service_panels
	_service_panel_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_service_panel_batch.layers = 1
	_service_panel_batch.extra_cull_margin = 0.0
	_service_panel_batch.set_meta("visual_detail_only", true)
	_service_panel_batch.set_meta("authored_visual_names", PackedStringArray([
		"PortServicePanel00", "PortServicePanel01", "PortServicePanel03",
		"StarboardServicePanel00", "StarboardServicePanel01",
		"StarboardServicePanel02", "StarboardServicePanel03",
	]))
	_service_panel_batch.set_meta(
		"authored_instance_transforms", _service_panel_transforms.duplicate()
	)
	_jovian_visual.add_child(_service_panel_batch)
	_load_mark_mesh = _rounded_box_mesh(LOAD_MARK_SIZE, _jovian_materials.amber)
	var load_marks := MultiMesh.new()
	load_marks.transform_format = MultiMesh.TRANSFORM_3D
	load_marks.mesh = _load_mark_mesh
	load_marks.instance_count = _load_mark_transforms.size()
	load_marks.visible_instance_count = -1
	load_marks.buffer = _encode_load_mark_transforms(_load_mark_transforms)
	load_marks.custom_aabb = _load_mark_bounds(_load_mark_mesh.get_aabb(), _load_mark_transforms)
	_load_mark_batch = MultiMeshInstance3D.new()
	_load_mark_batch.name = "LoadMarkBatch"
	_load_mark_batch.multimesh = load_marks
	_load_mark_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_load_mark_batch.layers = 1
	_load_mark_batch.set_meta("visual_detail_only", true)
	_load_mark_batch.set_meta("authored_visual_names", PackedStringArray([
		"PortLoadMark00", "PortLoadMark01", "PortLoadMark02",
		"StarboardLoadMark00", "StarboardLoadMark01", "StarboardLoadMark02",
	]))
	_load_mark_batch.set_meta("authored_instance_transforms", _load_mark_transforms.duplicate())
	_jovian_visual.add_child(_load_mark_batch)

	# The deployed ramp and frame are deliberately obvious from the berth. The
	# opening remains geometrically clear all the way to the cargo deck.
	# A 20-degree rise gives the wedge's walkable upper surface y=-1.25 at
	# x=-10.45 and y=+0.48 at the cargo-deck threshold x=-5.725. Unlike a
	# rotated box, its flat underside never extends below the landing plane.
	var ramp_angle := deg_to_rad(20.0)
	_ramp_wedge(
		_jovian_visual,
		"PortCargoRamp",
		-10.45,
		-5.725,
		-1.25,
		-1.25,
		0.48,
		3.2,
		1.7,
		_jovian_materials.deck
	)
	_cargo_ramp_edge_rail_mesh = _rounded_box_mesh(
		CARGO_RAMP_EDGE_RAIL_SIZE, _jovian_materials.amber
	)
	for rail_z in [1.62, 4.78]:
		_rounded_box_from_mesh(
			_jovian_visual,
			"CargoRampEdgeRail",
			Vector3(-7.9, -0.22, rail_z),
			_cargo_ramp_edge_rail_mesh,
			Vector3(0.0, 0.0, ramp_angle)
		)
	for vertical_z in [1.25, 5.15]:
		_box(_jovian_visual, "CargoApertureUpright", Vector3(-5.78, 2.38, vertical_z), Vector3(0.32, 3.75, 0.3), _jovian_materials.amber)
	_cargo_aperture_capsule_header(
		_jovian_visual,
		"CargoApertureHeader",
		Vector3(-5.78, 4.22, 3.2),
		CARGO_APERTURE_HEADER_SIZE,
		_jovian_materials.amber,
		CARGO_APERTURE_HEADER_END_RADIUS,
		CARGO_APERTURE_HEADER_CURVE_SEGMENTS
	)
	_cargo_ramp_actuator_mesh = _rounded_box_mesh(
		CARGO_RAMP_ACTUATOR_SIZE, _jovian_materials.structure
	)
	for actuator_z in [1.3, 5.1]:
		_rounded_box_from_mesh(
			_jovian_visual,
			"CargoRampActuator",
			Vector3(-6.1, 0.12, actuator_z),
			_cargo_ramp_actuator_mesh,
			Vector3(0.0, 0.0, ramp_angle)
		)


func _build_forward_cargo_guide_silhouette() -> void:
	var guide_mesh := ArrayMesh.new()
	var guide_tool := SurfaceTool.new()
	guide_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	guide_tool.set_material(_jovian_materials.structure)
	_append_planform_prism(
		guide_tool, FORWARD_CARGO_GUIDE_PORT_OUTLINE, FORWARD_CARGO_GUIDE_THICKNESS, 0
	)
	_append_planform_prism(
		guide_tool,
		_mirror_outline_across_centerline(FORWARD_CARGO_GUIDE_PORT_OUTLINE),
		FORWARD_CARGO_GUIDE_THICKNESS,
		8
	)
	guide_tool.generate_normals()
	guide_tool.commit(guide_mesh)

	var index_tool := SurfaceTool.new()
	index_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	index_tool.set_material(_jovian_materials.amber)
	_append_planform_prism(
		index_tool, FORWARD_CARGO_INDEX_PORT_OUTLINE, FORWARD_CARGO_INDEX_THICKNESS, 0
	)
	_append_planform_prism(
		index_tool,
		_mirror_outline_across_centerline(FORWARD_CARGO_INDEX_PORT_OUTLINE),
		FORWARD_CARGO_INDEX_THICKNESS,
		8
	)
	index_tool.generate_normals()
	index_tool.commit(guide_mesh)

	var guide := MeshInstance3D.new()
	guide.name = FORWARD_CARGO_GUIDE_NAME
	guide.mesh = guide_mesh
	guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	guide.layers = 1
	guide.process_mode = Node.PROCESS_MODE_DISABLED
	guide.set_meta("visual_only", true)
	guide.set_meta("orientation_axis", &"forward_negative_z")
	guide.set_meta("cargo_role_cue", FORWARD_CARGO_GUIDE_ROLE)
	guide.set_meta("interpretation_status", FORWARD_CARGO_GUIDE_STATUS)
	guide.set_meta("authenticated_historical_silhouette", false)
	guide.set_meta("collision_authority", false)
	guide.set_meta("cargo_authority", false)
	_jovian_visual.add_child(guide)


func _append_planform_prism(
		tool: SurfaceTool,
		outline: Array[Vector3],
		thickness: float,
		base_index: int
	) -> void:
	var half_thickness := thickness * 0.5
	for point in outline:
		tool.add_vertex(point + Vector3.UP * half_thickness)
	for point in outline:
		tool.add_vertex(point - Vector3.UP * half_thickness)
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		tool.add_index(base_index + triangle[0])
		tool.add_index(base_index + triangle[1])
		tool.add_index(base_index + triangle[2])
		tool.add_index(base_index + 4 + triangle[0])
		tool.add_index(base_index + 4 + triangle[2])
		tool.add_index(base_index + 4 + triangle[1])
	for index in 4:
		var next := (index + 1) % 4
		tool.add_index(base_index + index)
		tool.add_index(base_index + 4 + index)
		tool.add_index(base_index + 4 + next)
		tool.add_index(base_index + index)
		tool.add_index(base_index + 4 + next)
		tool.add_index(base_index + next)


func _mirror_outline_across_centerline(outline: Array[Vector3]) -> Array[Vector3]:
	var mirrored: Array[Vector3] = []
	for index in range(outline.size() - 1, -1, -1):
		var point := outline[index]
		mirrored.append(Vector3(-point.x, point.y, point.z))
	return mirrored


func _build_connected_interior() -> void:
	_walkable_interior = Node3D.new()
	_walkable_interior.name = "WalkableInterior"
	_walkable_interior.set_meta("space_id", &"jovian_connected_interior")
	_walkable_interior.set_meta("geometry_status", EVIDENCE_STATUS)
	_walkable_interior.set_meta("detached_interior", false)
	_walkable_interior.set_meta("historically_authenticated_layout", false)
	# This must be a direct child of the physical ship, not the banked exterior
	# visual root. Its deck meshes, direct hull colliders, occupancy volume, and
	# MovingInteriorFrame therefore share one authoritative rigid transform.
	add_child(_walkable_interior)
	var cockpit := _jovian_visual.get_node_or_null("CockpitInterior") as Node3D
	if cockpit != null:
		cockpit.reparent(_walkable_interior, true)

	_build_cargo_bay()
	_build_passenger_cabin()
	_build_interior_route_and_markers()


## Stable per-station suffix shared by a cargo unit's drawn meshes and its
## colliders, so `CargoContainerPort00` and `CargoContainerCollisionPort00` name
## the same crate.
static func cargo_unit_suffix(index: int) -> String:
	var anchor := CARGO_UNIT_ANCHORS[index]
	return "%s%02d" % ["Port" if anchor.x < 0.0 else "Starboard", index / 2]


func _build_cargo_bay() -> void:
	_cargo_bay = Node3D.new()
	_cargo_bay.name = "CargoBay"
	_cargo_bay.set_meta("space_id", &"cargo_bay")
	_cargo_bay.set_meta("capacity_status", &"provisional")
	_walkable_interior.add_child(_cargo_bay)
	_box(_cargo_bay, "CargoDeck", Vector3(0.0, 0.5, 3.15), Vector3(11.3, 0.18, 12.1), _jovian_materials.deck)
	# Slim inlaid lanes leave an unobstructed route from ramp to forward cabin.
	for lane_x in [-2.15, 0.0, 2.15]:
		_cargo_deck_lane_transforms.append(Transform3D(
			Basis.IDENTITY, Vector3(lane_x, 0.61, 3.15)
		))
	_cargo_deck_lane_mesh = _rounded_box_mesh(CARGO_DECK_LANE_SIZE, _jovian_materials.teal)
	var cargo_deck_lanes := MultiMesh.new()
	cargo_deck_lanes.transform_format = MultiMesh.TRANSFORM_3D
	cargo_deck_lanes.mesh = _cargo_deck_lane_mesh
	cargo_deck_lanes.instance_count = _cargo_deck_lane_transforms.size()
	cargo_deck_lanes.visible_instance_count = -1
	cargo_deck_lanes.buffer = _encode_load_mark_transforms(_cargo_deck_lane_transforms)
	cargo_deck_lanes.custom_aabb = _load_mark_bounds(
		_cargo_deck_lane_mesh.get_aabb(), _cargo_deck_lane_transforms
	)
	_cargo_deck_lane_batch = MultiMeshInstance3D.new()
	_cargo_deck_lane_batch.name = "CargoDeckLaneBatch"
	_cargo_deck_lane_batch.multimesh = cargo_deck_lanes
	_cargo_deck_lane_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_cargo_deck_lane_batch.layers = 1
	_cargo_deck_lane_batch.extra_cull_margin = 0.0
	_cargo_deck_lane_batch.set_meta("visual_detail_only", true)
	_cargo_deck_lane_batch.set_meta("authored_visual_names", PackedStringArray([
		"CargoDeckLane", "CargoDeckLane", "CargoDeckLane",
	]))
	_cargo_bay.add_child(_cargo_deck_lane_batch)
	# Starboard wall is continuous. The port wall is split around the open ramp.
	_box(_cargo_bay, "StarboardInnerWall", Vector3(5.64, 2.5, 3.15), Vector3(0.18, 3.86, 12.0), _jovian_materials.structure)
	_box(_cargo_bay, "PortInnerWallForward", Vector3(-5.64, 2.5, -0.9), Vector3(0.18, 3.86, 3.65), _jovian_materials.structure)
	_box(_cargo_bay, "PortInnerWallAft", Vector3(-5.64, 2.5, 7.15), Vector3(0.18, 3.86, 4.05), _jovian_materials.structure)
	_box(_cargo_bay, "AftPressureWall", Vector3(0.0, 2.5, 9.17), Vector3(11.3, 3.86, 0.18), _jovian_materials.structure)
	for bay_index in 4:
		var bay_z := -1.35 + float(bay_index) * 2.65
		_box(_cargo_bay, "CeilingAcousticCassette%02d" % bay_index, Vector3(0.0, 4.49, bay_z), Vector3(8.8, 0.08, 2.52), _jovian_materials.liner)
		_box(_cargo_bay, "StarboardWallLiner%02d" % bay_index, Vector3(5.51, 2.53, bay_z), Vector3(0.07, 2.92, 2.52), _jovian_materials.liner)
		if bay_index != 1 and bay_index != 2:
			_box(_cargo_bay, "PortWallLiner%02d" % bay_index, Vector3(-5.51, 2.53, bay_z), Vector3(0.07, 2.92, 2.52), _jovian_materials.liner)
	# Forward bulkhead wraps a 2.8 m passage to the passenger cabin.
	for side in [-1.0, 1.0]:
		_box(_cargo_bay, "ForwardBulkheadWing", Vector3(side * 3.55, 2.5, -2.88), Vector3(4.2, 3.86, 0.18), _jovian_materials.structure)
	_box(_cargo_bay, "ForwardBulkheadHeader", Vector3(0.0, 4.12, -2.88), Vector3(2.95, 0.62, 0.18), _jovian_materials.cabin_shell)
	# Curved interior frames expose the true structural scale without closing the
	# route. All fixtures are children of the moving ship.
	_cargo_frame_joint_mesh = SphereMesh.new()
	_cargo_frame_joint_mesh.radius = CARGO_FRAME_JOINT_RADIUS
	_cargo_frame_joint_mesh.height = CARGO_FRAME_JOINT_RADIUS * 2.0
	_cargo_frame_joint_mesh.radial_segments = CARGO_FRAME_JOINT_RADIAL_SEGMENTS
	_cargo_frame_joint_mesh.rings = CARGO_FRAME_JOINT_RINGS
	_cargo_frame_joint_mesh.material = _jovian_materials.hull_cool
	for frame_index in CARGO_FRAME_COUNT:
		var frame_z := CARGO_FRAME_START_Z + float(frame_index) * CARGO_FRAME_Z_STEP
		_curve_tube(
			_cargo_bay,
			"CargoFrame%02d" % frame_index,
			PackedVector3Array([
				Vector3(-5.35, 0.72, frame_z),
				Vector3(-5.35, 4.15, frame_z),
				Vector3(0.0, 4.48, frame_z),
				Vector3(5.35, 4.15, frame_z),
				Vector3(5.35, 0.72, frame_z),
			]),
			CARGO_FRAME_JOINT_RADIUS,
			_jovian_materials.hull_cool,
			_cargo_frame_joint_mesh
		)
	# Four stable tie-down hardpoints and their secured cargo units. The central
	# lane and door-to-cabin diagonal remain at least 2 m wide. Positions come from
	# `CARGO_UNIT_ANCHORS`, which `_build_collision` also builds the freight's
	# colliders from, so the drawn crate and the solid crate cannot drift apart.
	_cargo_restraint_mesh = _rounded_box_mesh(
		CARGO_RESTRAINT_SIZE, _jovian_materials.amber
	)
	for index in CARGO_UNIT_ANCHORS.size():
		var position := CARGO_UNIT_ANCHORS[index]
		var side := signf(position.x)
		var row := index / 2
		var suffix := cargo_unit_suffix(index)
		var hardpoint := Marker3D.new()
		hardpoint.name = ("Port" if side < 0.0 else "Starboard") + "CargoHardpoint%02d" % row
		hardpoint.position = position
		hardpoint.set_meta("hardpoint_id", StringName("cargo_%s_%02d" % ["port" if side < 0.0 else "starboard", row]))
		_cargo_bay.add_child(hardpoint)
		_cargo_hardpoints.append(hardpoint)
		# Named per station rather than four times over. Godot renames same-named
		# siblings to generated identifiers, which is how four crates could only
		# ever be found as two by name — and an audit that can only see half a
		# roster is how they stayed permeable this long.
		_box(_cargo_bay, "CargoPallet" + suffix, position + Vector3(0.0, CARGO_PALLET_OFFSET_Y, 0.0), CARGO_PALLET_SIZE, _jovian_materials.structure)
		_box(_cargo_bay, "CargoContainer" + suffix, position + Vector3(0.0, CARGO_CONTAINER_OFFSET_Y, 0.0), CARGO_CONTAINER_SIZE, _jovian_materials.freight_shell)
		for corner_x in [-0.87, 0.87]:
			for corner_z in [-0.98, 0.98]:
				_limit_interior_furnishing_range(_box(_cargo_bay, "ContainerCorner" + suffix, position + Vector3(corner_x, 0.90, corner_z), Vector3(0.16, 1.24, 0.16), _jovian_materials.structure))
		for face_z in [-1.079, 1.079]:
			_limit_interior_furnishing_range(_box(_cargo_bay, "ContainerRecess" + suffix, position + Vector3(0.0, 0.91, face_z), Vector3(1.47, 0.85, 0.035), _jovian_materials.dark))
			_limit_interior_furnishing_range(_box(_cargo_bay, "ContainerDataPlate" + suffix, position + Vector3(0.40, 1.07, face_z * 1.021), Vector3(0.43, 0.23, 0.02), _jovian_materials.liner))

		for band_index in CARGO_RESTRAINT_BAND_Z.size():
			_rounded_box_from_mesh(
				_cargo_bay,
				"CargoRestraint%s%02d" % [suffix, band_index],
				position + Vector3(0.0, CARGO_RESTRAINT_OFFSET_Y, CARGO_RESTRAINT_BAND_Z[band_index]),
				_cargo_restraint_mesh
			)
	# Rear corner lockers add believable stowage without obstructing egress.
	for side in [-1.0, 1.0]:
		_box(_cargo_bay, "ServiceLocker", Vector3(side * 4.75, 1.52, 8.25), Vector3(1.25, 1.9, 1.15), _jovian_materials.hull_cool)
		_box(_cargo_bay, "LockerDisplay", Vector3(side * 4.1, 1.62, 8.25), Vector3(0.03, 0.38, 0.52), _materials.display_substrate)
	# Warm-neutral practicals illuminate the actual interior, not a detached set.
	_cargo_ceiling_light_mesh = _rounded_box_mesh(
		CARGO_CEILING_LIGHT_SIZE, _jovian_materials.interior_light
	)
	for light_z in [-1.25, 2.85, 6.95]:
		_cargo_ceiling_light_transforms.append(Transform3D(
			Basis.IDENTITY, Vector3(0.0, 4.36, light_z)
		))
		var cargo_light := OmniLight3D.new()
		cargo_light.name = "CargoPracticalLight"
		cargo_light.position = Vector3(0.0, 4.12, light_z)
		cargo_light.light_color = Color("d7fff2")
		cargo_light.light_energy = 0.72
		cargo_light.omni_range = 7.4
		cargo_light.shadow_enabled = true
		_cargo_bay.add_child(cargo_light)
	var ceiling_light_multimesh := MultiMesh.new()
	ceiling_light_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	ceiling_light_multimesh.mesh = _cargo_ceiling_light_mesh
	ceiling_light_multimesh.instance_count = _cargo_ceiling_light_transforms.size()
	ceiling_light_multimesh.visible_instance_count = -1
	for index in _cargo_ceiling_light_transforms.size():
		ceiling_light_multimesh.set_instance_transform(
			index, _cargo_ceiling_light_transforms[index]
		)
	ceiling_light_multimesh.custom_aabb = _load_mark_bounds(
		_cargo_ceiling_light_mesh.get_aabb(), _cargo_ceiling_light_transforms
	)
	_cargo_ceiling_light_batch = MultiMeshInstance3D.new()
	_cargo_ceiling_light_batch.name = "CargoCeilingLightBatch"
	_cargo_ceiling_light_batch.multimesh = ceiling_light_multimesh
	_cargo_ceiling_light_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_cargo_ceiling_light_batch.layers = 1
	_cargo_ceiling_light_batch.extra_cull_margin = 0.0
	_cargo_ceiling_light_batch.set_meta("visual_detail_only", true)
	_cargo_ceiling_light_batch.set_meta("authored_visual_names", PackedStringArray([
		"CargoCeilingLight", "CargoCeilingLight", "CargoCeilingLight",
	]))
	_cargo_ceiling_light_batch.set_meta(
		"authored_instance_transforms", _cargo_ceiling_light_transforms.duplicate()
	)
	_cargo_bay.add_child(_cargo_ceiling_light_batch)


func _rounded_box_from_mesh(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	mesh: ArrayMesh,
	rotation_value := Vector3.ZERO
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	instance.rotation = rotation_value
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _build_passenger_cabin() -> void:
	_passenger_cabin = Node3D.new()
	_passenger_cabin.name = "PassengerCabin"
	_passenger_cabin.set_meta("space_id", &"passenger_cabin")
	_passenger_cabin.set_meta("capacity_status", &"provisional")
	_walkable_interior.add_child(_passenger_cabin)
	_build_fitted_passenger_seat_meshes()
	_passenger_cabin_light_strip_mesh = _rounded_box_mesh(
		PASSENGER_CABIN_LIGHT_STRIP_SIZE, _jovian_materials.interior_light
	)
	_cabin_portal_upright_mesh = _rounded_box_mesh(
		CABIN_PORTAL_UPRIGHT_SIZE, _jovian_materials.cabin_shell
	)
	_box(_passenger_cabin, "PassengerDeck", Vector3(0.0, 0.5, -5.25), Vector3(6.9, 0.18, 4.65), _jovian_materials.deck)
	_box(_passenger_cabin, "PassengerRoof", Vector3(0.0, 3.82, -5.25), Vector3(6.9, 0.16, 4.65), _jovian_materials.hull_cool)
	for side in [-1.0, 1.0]:
		_box(_passenger_cabin, "CabinSidewall", Vector3(side * 3.36, 2.15, -5.25), Vector3(0.18, 3.35, 4.6), _jovian_materials.structure)
		_rounded_box_from_mesh(
			_passenger_cabin,
			"CabinLightStrip",
			Vector3(side * 3.23, 3.46, -5.25),
			_passenger_cabin_light_strip_mesh
		)
		# Three side-facing seats per side keep a clear central passage to the
		# inherited cockpit. Their anchors are explicit future passenger contracts.
		for seat_index in 3:
			var seat_z := -6.55 + float(seat_index) * 1.3
			var seat_root := Node3D.new()
			seat_root.name = ("Port" if side < 0.0 else "Starboard") + "PassengerSeat%02d" % seat_index
			seat_root.position = Vector3(side * 2.62, 0.0, seat_z)
			# Local -Z faces the aisle; the old opposite yaw faced the wall.
			seat_root.rotation.y = side * PI * 0.5
			_passenger_cabin.add_child(seat_root)
			_rounded_box_from_mesh(seat_root, "SeatBase", Vector3(0.0, 0.88, 0.0), _passenger_seat_base_mesh)
			_rounded_box_from_mesh(seat_root, "SeatBack", Vector3(0.0, 1.42, 0.36), _passenger_seat_back_mesh, Vector3(deg_to_rad(8.0), 0.0, 0.0))
			_rounded_box_from_mesh(seat_root, "Harness", Vector3(0.0, 1.42, 0.25), _passenger_seat_harness_mesh)
			_box(seat_root, "SeatHeadrest", Vector3(0.0, 1.99, 0.44), Vector3(0.52, 0.25, 0.22), _jovian_materials.cabin_cloth)
			for arm_side in [-1.0, 1.0]:
				_box(seat_root, "SeatArmrest", Vector3(arm_side * 0.40, 1.12, 0.05), Vector3(0.10, 0.12, 0.66), _jovian_materials.dark)
			var anchor := Marker3D.new()
			anchor.name = "PassengerAnchor"
			# Compensate the reversed yaw to retain the ship-local seat centre.
			anchor.position = Vector3(0.0, 0.24, 0.02)
			anchor.set_meta("seat_id", StringName("passenger_%s_%02d" % ["port" if side < 0.0 else "starboard", seat_index]))
			seat_root.add_child(anchor)
			_passenger_seat_anchors.append(anchor)
	# Open frames make both forward and aft connections visually explicit.
	for bulkhead_z in [-7.48, -3.0]:
		for side in [-1.0, 1.0]:
			_rounded_box_from_mesh(
				_passenger_cabin,
				"CabinPortalUpright",
				Vector3(side * 1.45, 2.1, bulkhead_z),
				_cabin_portal_upright_mesh
			)
		_box(_passenger_cabin, "CabinPortalHeader", Vector3(0.0, 3.68, bulkhead_z), Vector3(3.05, 0.18, 0.2), _jovian_materials.cabin_shell)
	_box(_passenger_cabin, "CabinStatusPanel", Vector3(0.0, 2.5, -3.13), Vector3(1.05, 0.58, 0.04), _materials.display_substrate)
	_engineer_status_readout = Label3D.new()
	_engineer_status_readout.name = "EngineerRepairReadout"
	_engineer_status_readout.position = Vector3(0.0, 2.5, -3.10)
	_engineer_status_readout.font_size = 28
	_engineer_status_readout.pixel_size = 0.003
	_engineer_status_readout.modulate = Color("b9f1e4")
	_engineer_status_readout.outline_modulate = Color("07111d")
	_engineer_status_readout.outline_size = 2
	_engineer_status_readout.no_depth_test = false
	_engineer_status_readout.set_meta("presentation_only", true)
	_passenger_cabin.add_child(_engineer_status_readout)
	_engineer_repair_console = JovianEngineerRepairConsoleType.new()
	_engineer_repair_console.bind(_engineer_status_readout, _engineer_console_generation)
	_refresh_engineer_status_readout()
	var cabin_light := OmniLight3D.new()
	cabin_light.name = "PassengerPracticalLight"
	cabin_light.position = Vector3(0.0, 3.34, -5.25)
	cabin_light.light_color = Color("fff1db")
	cabin_light.light_energy = 1.12
	cabin_light.omni_range = 5.2
	cabin_light.shadow_enabled = true
	_passenger_cabin.add_child(cabin_light)


func _build_interior_route_and_markers() -> void:
	# A short same-level bridge joins the passenger room to the flight deck.
	_box(_walkable_interior, "CockpitConnectorDeck", Vector3(0.0, 0.5, -8.0), Vector3(2.75, 0.18, 1.45), _jovian_materials.deck)
	for side in [-1.0, 1.0]:
		_box(_walkable_interior, "CockpitConnectorRail", Vector3(side * 1.42, 1.75, -8.0), Vector3(0.12, 2.4, 1.42), _jovian_materials.structure)
	var cockpit := _walkable_interior.get_node_or_null(^"CockpitInterior") as Node3D
	if cockpit != null:
		_box(cockpit, "CopilotSeatBase", Vector3(1.05, 1.18, -0.02), Vector3(0.78, 0.18, 0.82), _jovian_materials.cabin_cloth)
		_box(cockpit, "CopilotSeatBack", Vector3(1.05, 1.72, 0.34), Vector3(0.78, 0.96, 0.16), _jovian_materials.cabin_cloth, Vector3(deg_to_rad(8.0), 0.0, 0.0))
		var copilot_anchor := Marker3D.new()
		copilot_anchor.name = "CopilotSeatAnchor"
		copilot_anchor.position = Vector3(1.05, 1.44, -0.02)
		copilot_anchor.set_meta("seat_id", COPILOT_SEAT_ID)
		copilot_anchor.set_meta("role_id", COPILOT_ROLE_ID)
		copilot_anchor.set_meta("route_id", &"pilot_cockpit")
		cockpit.add_child(copilot_anchor)

	_interior_access_marker = Marker3D.new()
	_interior_access_marker.name = "InteriorAccessMarker"
	_interior_access_marker.position = Vector3(-10.05, -1.08, 3.2)
	_interior_access_marker.rotation.y = PI * 0.5
	_interior_access_marker.set_meta("route_id", &"port_cargo_ramp")
	_walkable_interior.add_child(_interior_access_marker)
	_interior_deck_marker = Marker3D.new()
	_interior_deck_marker.name = "InteriorDeckMarker"
	_interior_deck_marker.position = Vector3(-5.05, 0.64, 3.2)
	_interior_deck_marker.rotation.y = PI * 0.5
	_interior_deck_marker.set_meta("space_id", &"cargo_bay")
	_walkable_interior.add_child(_interior_deck_marker)
	_interior_exit_marker = Marker3D.new()
	_interior_exit_marker.name = "InteriorExitMarker"
	_interior_exit_marker.position = Vector3(-10.7, -1.08, 3.2)
	_interior_exit_marker.rotation.y = PI * 0.5
	_walkable_interior.add_child(_interior_exit_marker)
	# Standing pose used when the pilot leaves the seat away from a berth. It is
	# a real ship-local marker rather than a computed offset so the cabin route,
	# the containment recall, and the re-boarding prompt all name one place.
	_cabin_stand_marker = Marker3D.new()
	_cabin_stand_marker.name = "CabinStandMarker"
	_cabin_stand_marker.position = CABIN_STAND_LOCAL_ORIGIN
	_cabin_stand_marker.rotation.y = CABIN_STAND_LOCAL_YAW
	_cabin_stand_marker.set_meta("space_id", &"cabin_stand")
	_walkable_interior.add_child(_cabin_stand_marker)

	# Direct CharacterBody collision shapes below make the interior physically
	# walkable; this volume drives production MovingInteriorFrame occupancy while
	# keeping every occupant in the same world-space scene.
	_occupant_volume = Area3D.new()
	_occupant_volume.name = "InteriorOccupantVolume"
	_occupant_volume.collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
	_occupant_volume.collision_mask = PhysicsLayers.PLAYER_BODY_LAYER
	_occupant_volume.monitoring = true
	_occupant_volume.monitorable = false
	_occupant_volume.set_meta("ship_local_bounds", INTERIOR_BOUNDS)
	_walkable_interior.add_child(_occupant_volume)
	var volume_shape := CollisionShape3D.new()
	volume_shape.name = "InteriorBoundsShape"
	volume_shape.position = INTERIOR_BOUNDS.get_center()
	var box := BoxShape3D.new()
	box.size = INTERIOR_BOUNDS.size
	volume_shape.shape = box
	_occupant_volume.add_child(volume_shape)


func _build_propulsion_and_gear() -> void:
	# All four replaceable propulsion modules use the same immutable shell.
	var nacelle_mesh := _freighter_engine_module_mesh()
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var side_name := "Port" if side < 0.0 else "Starboard"
		for vertical_index in 2:
			var engine_y := 1.15 + float(vertical_index) * 2.25
			var engine_x := side * (5.05 + float(vertical_index) * 1.35)
			var prefix := side_name + ("Lower" if vertical_index == 0 else "Upper")
			var housing := MeshInstance3D.new()
			housing.name = prefix + "EngineHousing"
			housing.position = Vector3(engine_x, engine_y, 0.0)
			housing.mesh = nacelle_mesh
			housing.set_meta("visual_only", true)
			_jovian_visual.add_child(housing)
			_freighter_exhaust_collar(prefix + "EngineCollar", Vector3(engine_x, engine_y, 13.05))
			var core := _cylinder(_jovian_visual, prefix + "EngineCore", Vector3(engine_x, engine_y, 13.31), 0.57, 0.2, _jovian_materials.engine, Vector3(90.0, 0.0, 0.0))
			_engine_cores.append(core)
			var plume := _cylinder(_jovian_visual, prefix + "EnginePlume", Vector3(engine_x, engine_y, 13.8), 0.38, 1.1, _jovian_materials.engine, Vector3(90.0, 0.0, 0.0))
			EngineExhaustPresentation.install(plume, Vector3.UP, true)
			_engine_plumes.append(plume)
			var light := OmniLight3D.new()
			light.name = prefix + "EngineLight"
			light.position = Vector3(engine_x, engine_y, 13.45)
			light.light_color = ENGINE_AQUA
			light.light_energy = 0.0
			light.omni_range = 8.0
			light.shadow_enabled = false
			_jovian_visual.add_child(light)
			_jovian_engine_lights.append(light)

	# Shared, static load-bearing assemblies. The formed sole keeps the original
	# footprint and bottom plane; its raised shoe receives the lower strut end.
	var strut_mesh := _defensive_turned_mesh(PackedVector2Array([
		Vector2(0, -0.75), Vector2(0.15, -0.75), Vector2(0.17, -0.70),
		Vector2(0.17, -0.30), Vector2(0.23, -0.27), Vector2(0.24, -0.22),
		Vector2(0.24, -0.12), Vector2(0.21, -0.08), Vector2(0.21, 0.58),
		Vector2(0.26, 0.62), Vector2(0.26, 0.71), Vector2(0.22, 0.75),
		Vector2(0, 0.75)]), _jovian_materials.dark)
	var damper_mesh := _defensive_turned_mesh(PackedVector2Array([
		Vector2(0, -0.625), Vector2(0.08, -0.625), Vector2(0.09, -0.58),
		Vector2(0.09, -0.22), Vector2(0.14, -0.19), Vector2(0.14, -0.12),
		Vector2(0.13, -0.09), Vector2(0.13, 0.52), Vector2(0.15, 0.55),
		Vector2(0.15, 0.59), Vector2(0.11, 0.625), Vector2(0, 0.625)
	]), _jovian_materials.amber)
	for side in [-1.0, 1.0]:
		for z_position in [-5.8, 7.3]:
			_rounded_box_from_mesh(_jovian_visual, "LandingBogieStrut", Vector3(side * 4.85, -0.42, z_position), strut_mesh, Vector3(0, 0, side * deg_to_rad(-7.0)))
			_landing_bogie_foot_transforms.append(Transform3D(
				Basis.IDENTITY, Vector3(side * 5.05, -1.14, z_position)
			))
			_rounded_box_from_mesh(_jovian_visual, "LandingDamper", Vector3(side * 4.64, -0.22, z_position), damper_mesh)
	_landing_bogie_foot_mesh = _landing_formed_foot_mesh()
	var landing_bogie_feet := MultiMesh.new()
	landing_bogie_feet.transform_format = MultiMesh.TRANSFORM_3D
	landing_bogie_feet.mesh = _landing_bogie_foot_mesh
	landing_bogie_feet.instance_count = _landing_bogie_foot_transforms.size()
	landing_bogie_feet.visible_instance_count = -1
	landing_bogie_feet.buffer = _encode_load_mark_transforms(
		_landing_bogie_foot_transforms
	)
	landing_bogie_feet.custom_aabb = _load_mark_bounds(
		_landing_bogie_foot_mesh.get_aabb(), _landing_bogie_foot_transforms
	)
	_landing_bogie_foot_batch = MultiMeshInstance3D.new()
	_landing_bogie_foot_batch.name = "LandingBogieFootBatch"
	_landing_bogie_foot_batch.multimesh = landing_bogie_feet
	_landing_bogie_foot_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_landing_bogie_foot_batch.layers = 1
	_landing_bogie_foot_batch.extra_cull_margin = 0.0
	_landing_bogie_foot_batch.set_meta("visual_detail_only", true)
	_landing_bogie_foot_batch.set_meta("authored_visual_names", PackedStringArray([
		"LandingBogieFoot", "LandingBogieFoot", "LandingBogieFoot", "LandingBogieFoot",
	]))
	_landing_bogie_foot_batch.set_meta(
		"authored_instance_transforms", _landing_bogie_foot_transforms.duplicate()
	)
	_jovian_visual.add_child(_landing_bogie_foot_batch)

	# Fitted defensive cartridges sit in a low turned crown bearing. The seven
	# semantic owners remain separate, with one shared mesh for each paired part.
	var turret_meshes: Dictionary = {}
	for side in [-1.0, 1.0]:
		var prefix := "Port" if side < 0.0 else "Starboard"
		var parts := [
			["DefensiveTurretBase", Vector3(side * 5.15, 3.54, -5.55), &"mount_base"],
			["DefensiveTurretRotationCollar", Vector3(side * 5.15, 3.77, -5.55), &"rotation_collar"],
			["DefensiveTurretReceiver", Vector3(side * 5.15, 3.78, -5.72), &"receiver"],
			["DefensiveTurretBarrelShroud", Vector3(side * 5.15, 3.76, -6.02), &"barrel_shroud"],
			["DefensivePulseBarrel", Vector3(side * 5.15, 3.76, -6.175), &"pulse_barrel"],
			["DefensiveTurretMuzzleCollar", Vector3(side * 5.15, 3.76, -6.79), &"muzzle_collar"],
			["DefensiveTurretMuzzleLens", Vector3(side * 5.15, 3.76, -6.92), &"muzzle_lens"],
		]
		for part in parts:
			var suffix: String = part[0]
			var component: MeshInstance3D
			if turret_meshes.has(suffix):
				component = _rounded_box_from_mesh(_jovian_visual, prefix + suffix, part[1], turret_meshes[suffix])
			elif suffix == "DefensiveTurretReceiver":
				# Broad rear trunnion cheeks neck down into the barrel saddle.
				component = _loft_hull(_jovian_visual, prefix + suffix, part[1], PackedVector3Array([
					Vector3(0.25, 0.16, -0.35), Vector3(0.34, 0.22, -0.27),
					Vector3(0.38, 0.24, -0.08), Vector3(0.38, 0.24, 0.20),
					Vector3(0.30, 0.18, 0.35)]), _jovian_materials.structure)
			elif suffix == "DefensiveTurretBarrelShroud":
				component = _loft_hull(_jovian_visual, prefix + suffix, part[1], PackedVector3Array([
					Vector3(0.21, 0.18, -0.36), Vector3(0.24, 0.20, -0.29),
					Vector3(0.28, 0.23, 0.12), Vector3(0.28, 0.23, 0.26),
					Vector3(0.24, 0.19, 0.36)]), _jovian_materials.hull_cool)
			else:
				var profile := PackedVector2Array()
				var material: Material = _jovian_materials.structure
				match suffix:
					"DefensiveTurretBase":
						profile = PackedVector2Array([Vector2(0, -0.19), Vector2(0.60, -0.19), Vector2(0.66, -0.16), Vector2(0.68, -0.12), Vector2(0.68, -0.07), Vector2(0.64, -0.03), Vector2(0.54, 0.15), Vector2(0.49, 0.19), Vector2(0, 0.19)])
					"DefensiveTurretRotationCollar":
						profile = PackedVector2Array([Vector2(0, -0.08), Vector2(0.46, -0.08), Vector2(0.5, -0.05), Vector2(0.5, 0.03), Vector2(0.47, 0.07), Vector2(0.43, 0.08), Vector2(0, 0.08)])
						material = _jovian_materials.hull_cool
					"DefensivePulseBarrel":
						profile = PackedVector2Array([Vector2(0.175, -0.775), Vector2(0.19, -0.745), Vector2(0.19, 0.72), Vector2(0.17, 0.775), Vector2(0.15, 0.775), Vector2(0.15, -0.74), Vector2(0.175, -0.775)])
						# An open bore avoids a coplanar barrel cap fighting the lens.
						material = _jovian_materials.dark
					"DefensiveTurretMuzzleCollar":
						# Open rolled seat: the teal lens remains its own live material owner.
						profile = PackedVector2Array([Vector2(0.19, -0.10), Vector2(0.24, -0.10), Vector2(0.265, -0.075), Vector2(0.27, -0.035), Vector2(0.255, 0.04), Vector2(0.22, 0.10), Vector2(0.19, 0.10), Vector2(0.19, -0.10)])
					"DefensiveTurretMuzzleLens":
						profile = PackedVector2Array([Vector2(0, -0.03), Vector2(0.16, -0.03), Vector2(0.17, -0.02), Vector2(0.17, 0.02), Vector2(0.16, 0.03), Vector2(0, 0.03)])
						material = _jovian_materials.teal
				component = _rounded_box_from_mesh(_jovian_visual, prefix + suffix, part[1], _defensive_turned_mesh(profile, material))
			if suffix in ["DefensiveTurretReceiver", "DefensiveTurretBarrelShroud"]:
				component.set_meta("closed_loft_hull", true)
			if suffix in ["DefensivePulseBarrel", "DefensiveTurretMuzzleCollar", "DefensiveTurretMuzzleLens"]:
				component.rotation_degrees.x = 90.0
			turret_meshes[suffix] = component.mesh
			_mark_defensive_weapon_detail(component, part[2])


## One closed casting: a chamfered sole, rolled perimeter and tapered load shoe.
## Local Y=-0.09 and X/Z extrema are the original contact footprint. Only the
## upper shoe grows into the existing leg volume. The transverse pin uses the
## same surface/material, so the four feet still submit as one shared batch.
func _landing_formed_foot_mesh() -> ArrayMesh:
	var temporary := Node3D.new()
	var casting := _loft_hull(temporary, "Casting", Vector3.ZERO, PackedVector3Array([
		Vector3(0.75, 1.02, -0.09), Vector3(0.81, 1.085, -0.065),
		Vector3(0.825, 1.1, -0.02), Vector3(0.825, 1.1, 0.025),
		Vector3(0.79, 1.06, 0.075), Vector3(0.67, 0.89, 0.09),
		Vector3(0.54, 0.58, 0.16), Vector3(0.50, 0.40, 0.34),
		Vector3(0.46, 0.33, 0.40)
	]), _jovian_materials.structure, 24)
	var casting_surface := SurfaceTool.new()
	casting_surface.create_from(casting.mesh, 0)
	casting_surface.deindex()
	var tool := SurfaceTool.new()
	tool.append_from(casting_surface.commit(), 0, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
	var pin := _defensive_turned_mesh(PackedVector2Array([
		Vector2(0, -0.61), Vector2(0.13, -0.61), Vector2(0.17, -0.58),
		Vector2(0.17, -0.53), Vector2(0.14, -0.50), Vector2(0.14, 0.50),
		Vector2(0.17, 0.53), Vector2(0.17, 0.58), Vector2(0.13, 0.61),
		Vector2(0, 0.61)]), _jovian_materials.structure)
	tool.append_from(pin, 0, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.30, 0)))
	tool.set_material(_jovian_materials.structure)
	tool.index()
	var mesh := tool.commit()
	temporary.free()
	return mesh


## Turn a profile around local Y, matching the former cylinders' local bounds.
## Reuse the authored radial normals and metric UVs of the engine lathe.
func _defensive_turned_mesh(profile: PackedVector2Array, material: Material) -> ArrayMesh:
	var axial := ArrayMesh.new()
	_engine_module_surface(axial, profile, material, 24)
	var tool := SurfaceTool.new()
	tool.append_from(axial, 0, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
	tool.set_material(material)
	return tool.commit()


func _build_engine_damage_cue() -> void:
	_engine_damage_cue = Node3D.new()
	_engine_damage_cue.name = "StarboardAftEngineDamageCue"
	_engine_damage_cue.position = ENGINE_DAMAGE_CUE_POSITION
	_engine_damage_cue.process_mode = Node.PROCESS_MODE_DISABLED
	_engine_damage_cue.set_meta(&"presentation_only", true)
	_engine_damage_cue.set_meta(&"component_id", ENGINE_DAMAGE_CUE_COMPONENT_ID)
	_engine_damage_cue.set_meta(&"damage_authority", false)
	_engine_damage_cue.set_meta(&"repair_authority", false)
	_engine_damage_cue.set_meta(&"animated", false)
	_jovian_visual.add_child(_engine_damage_cue)

	var scorch_mesh := BoxMesh.new()
	scorch_mesh.size = ENGINE_DAMAGE_SCORCH_SIZE
	var scorch := MeshInstance3D.new()
	scorch.name = "EngineBreachScorch"
	scorch.mesh = scorch_mesh
	scorch.position = ENGINE_DAMAGE_SCORCH_POSITION
	scorch.material_override = _jovian_material(
		ENGINE_DAMAGE_SCORCH_COLOR, 0.06, 0.94
	)
	_engine_damage_cue.add_child(scorch)

	var vane_mesh := BoxMesh.new()
	vane_mesh.size = ENGINE_DAMAGE_VANE_SIZE
	var vane := MeshInstance3D.new()
	vane.name = "EngineIsolationBlade"
	vane.mesh = vane_mesh
	vane.position = ENGINE_DAMAGE_VANE_POSITION
	vane.material_override = _jovian_material(
		ENGINE_DAMAGE_VANE_COLOR,
		0.12,
		0.44,
		ENGINE_DAMAGE_VANE_COLOR,
		1.4
	)
	_engine_damage_cue.add_child(vane)
	_engine_damage_cue.visible = false


func _on_jovian_component_damage_changed(
		component_id: StringName,
		_state: int,
		_integrity: float
	) -> void:
	if component_id == ENGINE_DAMAGE_CUE_COMPONENT_ID:
		_sync_engine_damage_cue()


func _sync_engine_damage_cue() -> void:
	if not is_instance_valid(_engine_damage_cue):
		return
	var model := get_component_damage()
	_engine_damage_cue.visible = model != null \
		and model.is_configured() \
		and model.get_component_state(ENGINE_DAMAGE_CUE_COMPONENT_ID) \
			!= ShipComponentDamageType.ComponentState.NOMINAL


func _mark_defensive_weapon_detail(component: MeshInstance3D, component_role: StringName) -> void:
	component.set_meta("interpretation_status", DEFENSIVE_TURRET_STATUS)
	component.set_meta("weapon_role", DEFENSIVE_TURRET_ROLE)
	component.set_meta("component_role", component_role)
	component.set_meta("authenticated_historical_weapon", false)
	component.set_meta("visual_only", true)


func _replace_collision_and_markers() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.queue_free()
	# Physical decks form the lower hull and support walking while landed.
	_add_box_collision("CargoDeckCollision", Vector3(0.0, 0.36, 3.15), Vector3(11.45, 0.24, 12.15))
	_add_box_collision("PassengerDeckCollision", Vector3(0.0, 0.36, -5.25), Vector3(7.0, 0.24, 4.72))
	_add_box_collision("CockpitDeckCollision", Vector3(0.0, 0.36, -8.75), Vector3(3.1, 0.24, 3.25))
	_add_box_collision("VentralHullCollision", Vector3(0.0, -0.05, -10.9), Vector3(6.25, 0.65, 6.0))
	# The port shoulder is split around the 3.9 m cargo aperture. No collision
	# volume crosses the exterior-ramp-to-deck path.
	_add_box_collision("StarboardShoulderCollision", Vector3(6.65, 2.0, 1.8), Vector3(2.85, 4.15, 19.0))
	_add_box_collision("PortForwardShoulderCollision", Vector3(-6.65, 2.0, -3.5), Vector3(2.85, 4.15, 8.45))
	_add_box_collision("PortAftShoulderCollision", Vector3(-6.65, 2.0, 7.25), Vector3(2.85, 4.15, 4.15))
	_add_box_collision("CargoRoofCollision", Vector3(0.0, 4.54, 3.15), Vector3(11.6, 0.3, 12.3))
	_add_box_collision("AftHullCollision", Vector3(0.0, 2.0, 10.75), Vector3(10.2, 3.8, 3.0))
	# Interior walls and portal wings preserve a connected central route.
	_add_box_collision("StarboardInteriorWallCollision", Vector3(5.64, 2.5, 3.15), Vector3(0.22, 3.9, 12.0))
	_add_box_collision("PortInteriorWallForwardCollision", Vector3(-5.64, 2.5, -0.9), Vector3(0.22, 3.9, 3.65))
	_add_box_collision("PortInteriorWallAftCollision", Vector3(-5.64, 2.5, 7.15), Vector3(0.22, 3.9, 4.05))
	_add_box_collision("AftPressureWallCollision", Vector3(0.0, 2.5, 9.17), Vector3(11.3, 3.9, 0.22))
	for side in [-1.0, 1.0]:
		_add_box_collision("ForwardBulkheadWingCollision", Vector3(side * 3.55, 2.5, -2.88), Vector3(4.2, 3.9, 0.22))
		_add_box_collision("PassengerSidewallCollision", Vector3(side * 3.36, 2.15, -5.25), Vector3(0.22, 3.4, 4.65))
		# The flight deck had a floor but no sides. That was invisible while the
		# only way onto it was the seat transition; it is load-bearing now that a
		# crew member can walk on to it, because an unenclosed deck edge is a way
		# out of a pressurised hull.
		_add_box_collision(
			("Port" if side < 0.0 else "Starboard") + "CockpitSidewallCollision",
			Vector3(side * 1.66, 1.75, -8.75),
			Vector3(0.22, 2.6, 3.4)
		)
	_add_box_collision("CockpitForwardWallCollision", Vector3(0.0, 1.75, -10.46), Vector3(3.55, 2.6, 0.22))
	# The inherited chair is part of this walkable cockpit, not a presentation
	# seen only while seated. Its visible back crossed the old cabin standing pose
	# and had no physics counterpart, so a released pilot spawned partly inside it
	# and an on-foot pilot could walk straight through it to the pressure wall.
	# Derive both shapes from the live mesh transforms so restyling or relocating
	# the cockpit cannot separate the visible chair from the collision that closes
	# the route at the seat.
	var cockpit := _walkable_interior.get_node_or_null(^"CockpitInterior") as Node3D
	if cockpit != null:
		_add_visual_box_collision(
			"PilotSeatPanCollision", cockpit.get_node_or_null(^"SeatPan") as MeshInstance3D
		)
		_add_visual_box_collision(
			"PilotSeatBackCollision", cockpit.get_node_or_null(^"SeatBack") as MeshInstance3D
		)
	# Passenger cushions and backs are solid at their fitted local transforms.
	# They remain outside the central passage and follow the moving ship body.
	for anchor in _passenger_seat_anchors:
		var seat := anchor.get_parent() as Node3D
		for part in ["SeatBase", "SeatBack"]:
			_add_visual_box_collision(String(seat.name) + part + "Collision", seat.get_node(part) as MeshInstance3D)
	# Secured freight is solid. It was presentation-only for as long as the hold
	# was scenery a chase camera flew past; once a crew member could leave the seat
	# and walk it, a crate you walk through — and a chase boom pushed inside a
	# container, which is what `artifacts/cabin_04_walking_the_hold.png` shows — is
	# the same "solid-looking thing with no collision" defect the station sweep
	# closed everywhere else.
	#
	# This was written and reverted once, because it jammed
	# `tests/fleet_role_differentiation_test.gd`, which staged its Jovian approach
	# inside the hull and walked a straight line through the port crates. That
	# suite's approach has been restaged onto the berth apron outside the hull,
	# where its subject — role differentiation and boarding through the exterior
	# pilot hatch — actually lives. The two halves went in together.
	#
	# Built from `CARGO_UNIT_ANCHORS`, the same roster `_build_cargo_bay` draws
	# from, so the collider and the crate cannot drift apart. Sizes are the drawn
	# sizes exactly; the restraint bands are inside the container's own volume and
	# need nothing of their own.
	for index in CARGO_UNIT_ANCHORS.size():
		var anchor := CARGO_UNIT_ANCHORS[index]
		var suffix := cargo_unit_suffix(index)
		_add_box_collision(
			"CargoPalletCollision" + suffix,
			anchor + Vector3(0.0, CARGO_PALLET_OFFSET_Y, 0.0),
			CARGO_PALLET_SIZE
		)
		_add_box_collision(
			"CargoContainerCollision" + suffix,
			anchor + Vector3(0.0, CARGO_CONTAINER_OFFSET_Y, 0.0),
			CARGO_CONTAINER_SIZE
		)
	# The ramp is a real sloped ship-owned collider, aligned with its visual.
	_add_ramp_wedge_collision(
		"PortCargoRampCollision",
		-10.45,
		-5.725,
		-1.25,
		-1.25,
		0.48,
		3.2,
		1.7
	)

	var boarding := get_node_or_null("BoardingPoint") as Marker3D
	var exit := get_node_or_null("ExitPoint") as Marker3D
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	if boarding != null:
		boarding.position = Vector3(-3.4, -0.52, -8.15)
	if exit != null:
		exit.position = Vector3(-4.7, -1.05, -8.2)
		exit.rotation.y = -PI * 0.5
	if left_muzzle != null:
		left_muzzle.position = Vector3(-5.15, 3.76, -6.95)
	if right_muzzle != null:
		right_muzzle.position = Vector3(5.15, 3.76, -6.95)
	var boarding_area := get_node_or_null("ShipBoardingArea") as Area3D
	if boarding_area != null:
		boarding_area.position = Vector3(-3.4, -0.02, -8.15)
	var camera_rig := get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.position = Vector3(0.0, 4.0, 6.5)


func _add_box_collision(
		node_name: String,
		collision_position: Vector3,
		size: Vector3,
		rotation := Vector3.ZERO
	) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.position = collision_position
	collision.rotation = rotation
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)
	return collision


## Gives a visible, centred box mesh an exact ship-root physics counterpart.
## Keeping this Jovian-local avoids granting generic presentation nodes collision
## authority and preserves the physical ship as the one collision owner.
func _add_visual_box_collision(
		node_name: String,
		visual: MeshInstance3D
	) -> CollisionShape3D:
	if visual == null or visual.mesh == null:
		return null
	var bounds := visual.mesh.get_aabb()
	if not bounds.has_volume():
		return null
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.transform = (
		global_transform.affine_inverse() * visual.global_transform
		* Transform3D(Basis.IDENTITY, bounds.get_center())
	)
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	collision.shape = shape
	add_child(collision)
	return collision


func _add_ramp_wedge_collision(
		node_name: String,
		outer_x: float,
		inner_x: float,
		bottom_y: float,
		outer_top_y: float,
		inner_top_y: float,
		center_z: float,
		half_width_z: float
	) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(outer_x, bottom_y, center_z - half_width_z),
		Vector3(outer_x, outer_top_y, center_z - half_width_z),
		Vector3(inner_x, bottom_y, center_z - half_width_z),
		Vector3(inner_x, inner_top_y, center_z - half_width_z),
		Vector3(outer_x, bottom_y, center_z + half_width_z),
		Vector3(outer_x, outer_top_y, center_z + half_width_z),
		Vector3(inner_x, bottom_y, center_z + half_width_z),
		Vector3(inner_x, inner_top_y, center_z + half_width_z),
	])
	collision.shape = shape
	add_child(collision)
	return collision


func _bind_optional_interior_frame() -> void:
	_moving_interior_component = get_node_or_null("MovingInteriorFrame") as MovingInteriorFrame
	if _moving_interior_component == null:
		_moving_interior_component = MovingInteriorFrame.new()
		_moving_interior_component.name = "MovingInteriorFrame"
		add_child(_moving_interior_component)
	_moving_interior_component.set_meta("frame_id", &"jovian_walkable_interior")
	# Ship scenes build their volume after the pre-authored coordinator has run
	# `_ready`; enable automatic monitoring before configure so signal wiring and
	# existing-overlap registration are both active immediately.
	_moving_interior_component.auto_register_from_volume = true
	# PlayerController consumes MovingInteriorFrame.get_frame_gravity directly,
	# so the component's default registration options avoid double correction.
	_moving_interior_component.configure(self, INTERIOR_BOUNDS, _occupant_volume)
	# Occupancy stays owned by the coordinator. The hull only observes it, so a
	# crew member standing on this ship's own deck stops being an obstacle to
	# this ship's own `move_and_slide()` while it is under way. Counting rather
	# than latching keeps the behaviour correct for more than one occupant.
	if not _moving_interior_component.occupant_registered.is_connected(_on_interior_occupant_registered):
		_moving_interior_component.occupant_registered.connect(_on_interior_occupant_registered)
	if not _moving_interior_component.occupant_unregistered.is_connected(_on_interior_occupant_unregistered):
		_moving_interior_component.occupant_unregistered.connect(_on_interior_occupant_unregistered)
	_sync_interior_occupant_collision()
	_moving_interior_component.call_deferred("_register_existing_overlaps")


func _on_interior_occupant_registered(_occupant: Node3D) -> void:
	_sync_interior_occupant_collision()


func _on_interior_occupant_unregistered(
		_occupant: Node3D,
		_exit_velocity: Vector3,
		_reason: StringName
	) -> void:
	_sync_interior_occupant_collision()


func _sync_interior_occupant_collision() -> void:
	_interior_occupant_count = (
		_moving_interior_component.get_occupant_count()
		if _moving_interior_component != null
		else 0
	)
	if is_destroyed():
		# A destroyed hull owns layer 0 / mask 0. Never re-arm it from here.
		return
	collision_mask = (
		PhysicsLayers.SHIP_BODY_MASK & ~PhysicsLayers.PLAYER
		if _interior_occupant_count > 0
		else PhysicsLayers.SHIP_BODY_MASK
	)


func _set_interior_operational(enabled: bool) -> void:
	if _walkable_interior != null:
		_walkable_interior.visible = enabled
	if _occupant_volume != null:
		_occupant_volume.set_deferred(&"monitoring", enabled)
		for child in _occupant_volume.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred(&"disabled", not enabled)
	if not enabled and _moving_interior_component != null:
		_moving_interior_component.clear_occupants(true, &"ship_destroyed")
	_sync_interior_occupant_collision()


func _update_jovian_presentation(delta: float) -> void:
	var telemetry := get_telemetry()
	var engine_state := StringName(telemetry.get("engine_state", &"OFFLINE"))
	var engine_active := not is_destroyed() and engine_state in [ENGINE_STARTING, ENGINE_ONLINE]
	var exhaust_profile := get_engine_exhaust_damage_presentation_profile()
	var engine_level := 0.0
	if engine_state == ENGINE_STARTING:
		engine_level = 0.22 + 0.08 * sin(_elapsed_jovian * 10.0)
	elif engine_state == ENGINE_ONLINE:
		engine_level = 0.46 + clampf(velocity.length() / maxf(maximum_speed, 1.0), 0.0, 1.0) * 0.54
	var damage_presentation := get_damage_presentation()
	if is_instance_valid(damage_presentation):
		engine_level *= clampf(damage_presentation.get_engine_power_multiplier(), 0.0, 1.0)
	engine_level *= float(exhaust_profile.get("intensity_multiplier", 1.0))
	var exhaust_geometry := float(exhaust_profile.get("geometry_multiplier", 1.0))
	for core in _engine_cores:
		core.visible = engine_active
	for plume in _engine_plumes:
		plume.visible = engine_level > 0.01
		plume.scale.y = lerpf(
			plume.scale.y,
			0.5 + engine_level * 1.25 * exhaust_geometry,
			1.0 - exp(-6.0 * delta)
		)
	for light in _jovian_engine_lights:
		light.light_energy = engine_level * 2.6
	_apply_engine_exhaust_damage_presentation(
		_engine_plumes, _jovian_engine_lights, engine_active, exhaust_profile
	)


func _sync_jovian_engine_presentation_immediately() -> void:
	var telemetry := get_telemetry()
	var state := StringName(telemetry.get("engine_state", ENGINE_OFFLINE))
	var active := not is_destroyed() and state in [ENGINE_STARTING, ENGINE_ONLINE]
	var exhaust_profile := get_engine_exhaust_damage_presentation_profile()
	var engine_level := 0.22 if state == ENGINE_STARTING else (0.46 if state == ENGINE_ONLINE else 0.0)
	engine_level *= float(exhaust_profile.get("intensity_multiplier", 1.0))
	var exhaust_geometry := float(exhaust_profile.get("geometry_multiplier", 1.0))
	for core in _engine_cores:
		if is_instance_valid(core):
			core.visible = active
	for plume in _engine_plumes:
		if is_instance_valid(plume):
			plume.visible = active
			plume.scale.y = 0.5 + engine_level * 1.25 * exhaust_geometry if active else 0.5
	for light in _jovian_engine_lights:
		if is_instance_valid(light):
			light.light_energy = engine_level * 2.6 if active else 0.0
	_apply_engine_exhaust_damage_presentation(
		_engine_plumes, _jovian_engine_lights, active, exhaust_profile
	)


func _set_jovian_engine_presentation_inactive() -> void:
	for core in _engine_cores:
		if is_instance_valid(core):
			core.visible = false
	for plume in _engine_plumes:
		if is_instance_valid(plume):
			plume.visible = false
	for light in _jovian_engine_lights:
		if is_instance_valid(light):
			light.light_energy = 0.0


func _sync_variant_engine_presentation_immediately() -> void:
	_sync_jovian_engine_presentation_immediately()


func _apply_jovian_metadata() -> void:
	set_meta("jovian_light_freighter_candidate", true)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("evidence_scope", EVIDENCE_SCOPE)
	set_meta("name_to_model_status", NAME_TO_MODEL_STATUS)
	set_meta("authenticated_historical_silhouette", false)
	set_meta("connected_walkable_interior", true)
	set_meta("content_note", PROVISIONAL_NOTE)
	set_meta("weapon_class", &"freighter_defensive_pulse")
	set_meta("weapon_visual_status", DEFENSIVE_TURRET_STATUS)
	set_meta("authenticated_historical_weapon", false)
	set_meta("engine_profile", &"heavy_quad_freighter")


func _jovian_material(
		color: Color,
		metallic: float,
		roughness: float,
		emission := Color.BLACK,
		energy := 0.0
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = clampf(metallic, 0.0, 1.0)
	material.roughness = clampf(roughness, 0.04, 1.0)
	# The freighter is dominated by runtime-authored plate and block geometry.
	# Two-sided opaque materials keep those closed if a later mesh edit reverses
	# a face; `_jovian_glass` explicitly restores the single-sided alpha path.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _jovian_glass(color: Color) -> StandardMaterial3D:
	var material := _jovian_material(color, 0.1, 0.09, Color("17464c"), 0.16)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 1
	return material


func _loft_hull(
		parent: Node3D,
		node_name: String,
		origin: Vector3,
		sections: PackedVector3Array,
		material: Material,
		ring_count := 24
	) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for section_index in sections.size():
		var section := sections[section_index]
		for ring_index in ring_count:
			var angle := TAU * float(ring_index) / float(ring_count)
			var cosine := cos(angle)
			var sine := sin(angle)
			var rounded_x := signf(cosine) * pow(absf(cosine), 0.42)
			var rounded_y := signf(sine) * pow(absf(sine), 0.42)
			tool.set_uv(Vector2(float(ring_index) / float(ring_count), float(section_index) / float(maxi(1, sections.size() - 1))))
			tool.add_vertex(Vector3(section.x * rounded_x, section.y * rounded_y, section.z))
	for section_index in sections.size() - 1:
		for ring_index in ring_count:
			var next_ring := (ring_index + 1) % ring_count
			var current := section_index * ring_count + ring_index
			var current_next := section_index * ring_count + next_ring
			var following := (section_index + 1) * ring_count + ring_index
			var following_next := (section_index + 1) * ring_count + next_ring
			tool.add_index(current)
			tool.add_index(following)
			tool.add_index(following_next)
			tool.add_index(current)
			tool.add_index(following_next)
			tool.add_index(current_next)
	var front_center := sections.size() * ring_count
	tool.add_vertex(Vector3(0.0, 0.0, sections[0].z))
	var rear_center := front_center + 1
	tool.add_vertex(Vector3(0.0, 0.0, sections[sections.size() - 1].z))
	for ring_index in ring_count:
		var next_ring := (ring_index + 1) % ring_count
		tool.add_index(front_center)
		tool.add_index(ring_index)
		tool.add_index(next_ring)
		var rear_base := (sections.size() - 1) * ring_count
		tool.add_index(rear_center)
		tool.add_index(rear_base + next_ring)
		tool.add_index(rear_base + ring_index)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = origin
	instance.mesh = tool.commit()
	instance.set_meta("closed_loft_hull", true)
	parent.add_child(instance)
	return instance


func _planform_surface(
		parent: Node3D,
		node_name: String,
		outline: PackedVector3Array,
		thickness: float,
		material: Material
	) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var half_thickness := thickness * 0.5
	for point in outline:
		tool.add_vertex(point + Vector3.UP * half_thickness)
	for point in outline:
		tool.add_vertex(point - Vector3.UP * half_thickness)
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		tool.add_index(triangle[0])
		tool.add_index(triangle[1])
		tool.add_index(triangle[2])
		tool.add_index(outline.size() + triangle[0])
		tool.add_index(outline.size() + triangle[2])
		tool.add_index(outline.size() + triangle[1])
	for index in outline.size():
		var next := (index + 1) % outline.size()
		tool.add_index(index)
		tool.add_index(outline.size() + index)
		tool.add_index(outline.size() + next)
		tool.add_index(index)
		tool.add_index(outline.size() + next)
		tool.add_index(next)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	parent.add_child(instance)
	return instance


func _curve_tube(
		parent: Node3D,
		node_name: String,
		points: PackedVector3Array,
		radius: float,
		material: Material,
		joint_mesh: SphereMesh = null
	) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	for index in points.size() - 1:
		var direction := points[index + 1] - points[index]
		var segment := _cylinder(root, "Segment%02d" % index, (points[index] + points[index + 1]) * 0.5, radius, direction.length(), material)
		segment.quaternion = Quaternion(Vector3.UP, direction.normalized())
	for point in points:
		if joint_mesh == null:
			_sphere(root, "CurveJoint", point, radius, material)
		else:
			var joint := MeshInstance3D.new()
			joint.name = "CurveJoint"
			joint.position = point
			joint.mesh = joint_mesh
			root.add_child(joint)
	return root


func _ramp_wedge(
		parent: Node3D,
		node_name: String,
		outer_x: float,
		inner_x: float,
		bottom_y: float,
		outer_top_y: float,
		inner_top_y: float,
		center_z: float,
		half_width_z: float,
		material: Material
	) -> MeshInstance3D:
	var points := PackedVector3Array([
		Vector3(outer_x, bottom_y, center_z - half_width_z),
		Vector3(outer_x, outer_top_y, center_z - half_width_z),
		Vector3(inner_x, bottom_y, center_z - half_width_z),
		Vector3(inner_x, inner_top_y, center_z - half_width_z),
		Vector3(outer_x, bottom_y, center_z + half_width_z),
		Vector3(outer_x, outer_top_y, center_z + half_width_z),
		Vector3(inner_x, bottom_y, center_z + half_width_z),
		Vector3(inner_x, inner_top_y, center_z + half_width_z),
	])
	# Each face is wound outward. The cross-section retains a slim outer lip, so
	# the convex shape remains numerically stable while meeting the apron cleanly.
	var triangles := PackedInt32Array([
		1, 3, 7, 1, 7, 5, # walkable slope
		0, 4, 6, 0, 6, 2, # flat underside
		0, 1, 5, 0, 5, 4, # outer lip
		2, 6, 7, 2, 7, 3, # inner riser
		0, 2, 3, 0, 3, 1, # forward edge
		4, 5, 7, 4, 7, 6, # aft edge
	])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for index in triangles:
		var point := points[index]
		tool.set_uv(Vector2(
			inverse_lerp(outer_x, inner_x, point.x),
			inverse_lerp(center_z - half_width_z, center_z + half_width_z, point.z)
		))
		tool.add_vertex(point)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	parent.add_child(instance)
	return instance


## One capsule lintel in the broad local Y/Z plane, extruded through local X.
## It is presentation-only like the former `_box`: the true ramp wedge and hull
## collision remain ship-root shapes, and no boarding, door, seat, or cargo
## authority moves under this node.
func _cargo_aperture_capsule_header(
	parent: Node3D,
	node_name: String,
	header_position: Vector3,
	size: Vector3,
	material: Material,
	end_radius: float,
	segments_per_end: int,
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = header_position
	instance.mesh = _cargo_aperture_capsule_mesh(
		size, material, end_radius, segments_per_end
	)
	instance.set_meta("geometry_profile", &"yz_extruded_capsule")
	instance.set_meta("end_radius_m", end_radius)
	instance.set_meta("curve_segments_per_end", segments_per_end)
	instance.set_meta("evidence_status", EVIDENCE_STATUS)
	instance.set_meta("authenticated_historical_geometry", false)
	instance.set_meta("visual_only", true)
	parent.add_child(instance)
	return instance


func _cargo_aperture_capsule_mesh(
	size: Vector3,
	material: Material,
	end_radius: float,
	segments_per_end: int,
) -> ArrayMesh:
	var radius := clampf(end_radius, 0.001, minf(size.y, size.z) * 0.5)
	var segment_count := maxi(segments_per_end, 2)
	var straight_half_length := size.z * 0.5 - radius
	# Vector2 stores local (Z, Y), counter-clockwise around the approach face.
	var boundary: Array[Vector2] = []
	for segment in segment_count + 1:
		var angle := lerpf(-PI * 0.5, PI * 0.5, float(segment) / float(segment_count))
		boundary.append(Vector2(
			straight_half_length + cos(angle) * radius,
			sin(angle) * radius,
		))
	for segment in segment_count + 1:
		var angle := lerpf(PI * 0.5, PI * 1.5, float(segment) / float(segment_count))
		boundary.append(Vector2(
			-straight_half_length + cos(angle) * radius,
			sin(angle) * radius,
		))

	var half_depth := size.x * 0.5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for index in boundary.size():
		var current := boundary[index]
		var next := boundary[(index + 1) % boundary.size()]
		var current_uv := Vector2(current.x / size.z + 0.5, current.y / size.y + 0.5)
		var next_uv := Vector2(next.x / size.z + 0.5, next.y / size.y + 0.5)
		# Godot treats clockwise triangles viewed from outside as front-facing.
		# Keep the emitted winding opposite the authored outward normals, matching
		# BoxMesh and the fleet's shared rounded-box builders. The former order was
		# reversed on every triangle, so back-face culling exposed this header's
		# dark inner shell at the cargo entrance.
		# Port/approach cap, facing local -X.
		_emit_cargo_header_vertex(tool, Vector3(-half_depth, 0.0, 0.0), Vector3.LEFT, Vector2(0.5, 0.5))
		_emit_cargo_header_vertex(tool, Vector3(-half_depth, next.y, next.x), Vector3.LEFT, next_uv)
		_emit_cargo_header_vertex(tool, Vector3(-half_depth, current.y, current.x), Vector3.LEFT, current_uv)
		# Cargo-bay cap, facing local +X.
		_emit_cargo_header_vertex(tool, Vector3(half_depth, 0.0, 0.0), Vector3.RIGHT, Vector2(0.5, 0.5))
		_emit_cargo_header_vertex(tool, Vector3(half_depth, current.y, current.x), Vector3.RIGHT, current_uv)
		_emit_cargo_header_vertex(tool, Vector3(half_depth, next.y, next.x), Vector3.RIGHT, next_uv)
		var rim_normal := Vector3(
			0.0,
			-(next.x - current.x),
			next.y - current.y
		).normalized()
		var rim_u := float(index) / float(boundary.size())
		var rim_next_u := float(index + 1) / float(boundary.size())
		_emit_cargo_header_vertex(tool, Vector3(-half_depth, current.y, current.x), rim_normal, Vector2(rim_u, 0.0))
		_emit_cargo_header_vertex(tool, Vector3(half_depth, next.y, next.x), rim_normal, Vector2(rim_next_u, 1.0))
		_emit_cargo_header_vertex(tool, Vector3(half_depth, current.y, current.x), rim_normal, Vector2(rim_u, 1.0))
		_emit_cargo_header_vertex(tool, Vector3(-half_depth, current.y, current.x), rim_normal, Vector2(rim_u, 0.0))
		_emit_cargo_header_vertex(tool, Vector3(-half_depth, next.y, next.x), rim_normal, Vector2(rim_next_u, 0.0))
		_emit_cargo_header_vertex(tool, Vector3(half_depth, next.y, next.x), rim_normal, Vector2(rim_next_u, 1.0))
	tool.generate_tangents()
	var mesh := tool.commit()
	mesh.resource_name = "jovian_cargo_aperture_capsule_header_v1"
	return mesh


func _emit_cargo_header_vertex(
	tool: SurfaceTool,
	position: Vector3,
	normal: Vector3,
	uv: Vector2,
) -> void:
	tool.set_normal(normal)
	tool.set_uv(uv)
	tool.add_vertex(position)


## Monotone station slopes preserve each authored width/height and never swell
## beyond adjacent stations. A shared derivative makes the formed crown C1 at
## station joins, including the flat cargo run, without rounding its perimeter.
func _roof_station_slope(sections: PackedVector3Array, station: int) -> Vector3:
	if station == 0:
		return (sections[1] - sections[0]) / (sections[1].z - sections[0].z)
	if station == sections.size() - 1:
		return (sections[station] - sections[station - 1]) / (sections[station].z - sections[station - 1].z)
	var before := sections[station].z - sections[station - 1].z
	var after := sections[station + 1].z - sections[station].z
	var left := (sections[station] - sections[station - 1]) / before
	var right := (sections[station + 1] - sections[station]) / after
	var slope := Vector3(0.0, 0.0, 1.0)
	for axis in [0, 1]:
		if left[axis] * right[axis] > 0.0:
			var w_left := 2.0 * after + before
			var w_right := after + 2.0 * before
			slope[axis] = (w_left + w_right) / (w_left / left[axis] + w_right / right[axis])
	return slope


## Position and d(position)/dz on the same bounded cubic used by roof fittings.
func _roof_profile(sections: PackedVector3Array, z: float) -> PackedVector3Array:
	z = clampf(z, sections[0].z, sections[-1].z)
	for station in sections.size() - 1:
		if z > sections[station + 1].z:
			continue
		var a := sections[station]
		var b := sections[station + 1]
		var length := b.z - a.z
		var t := (z - a.z) / length
		var start := _roof_station_slope(sections, station)
		var end := _roof_station_slope(sections, station + 1)
		var section := (2.0 * t * t * t - 3.0 * t * t + 1.0) * a \
			+ (t * t * t - 2.0 * t * t + t) * length * start \
			+ (-2.0 * t * t * t + 3.0 * t * t) * b \
			+ (t * t * t - t * t) * length * end
		var derivative := (6.0 * t * t - 6.0 * t) * (a - b) / length \
			+ (3.0 * t * t - 4.0 * t + 1.0) * start + (3.0 * t * t - 2.0 * t) * end
		section.z = z
		derivative.z = 1.0
		return PackedVector3Array([section, derivative])
	return PackedVector3Array([sections[-1], _roof_station_slope(sections, sections.size() - 1)])


## Flat or linear spans need no additional tessellation. Curved spans use a
## bounded physical spacing, shared by the pressure skin and its fitted covers.
func _roof_span_steps(sections: PackedVector3Array, front: float, rear: float) -> int:
	var a := _roof_profile(sections, front)
	var b := _roof_profile(sections, rear)
	var secant := (b[0] - a[0]) / (rear - front)
	if a[1].is_equal_approx(secant) and b[1].is_equal_approx(secant):
		return 1
	return maxi(1, ceili((rear - front) / 0.30))


## Thin pressed skin curved in both directions. Its underside shares the
## profile and opposite normals; sharp closing folds only occur at the perimeter.
func _pressed_roof(parent: Node3D, node_name: String, half_width: float, base_y: float,
		rise: float, sections: PackedVector3Array, thickness: float, material: Material) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	const STEPS := 32
	var profiles: Array[PackedVector3Array] = []
	for station in sections.size() - 1:
		var count := _roof_span_steps(sections, sections[station].z, sections[station + 1].z)
		for sample in count:
			profiles.append(_roof_profile(sections, lerpf(sections[station].z, sections[station + 1].z, float(sample) / count)))
	profiles.append(_roof_profile(sections, sections[-1].z))
	for station in profiles.size() - 1:
		for step in STEPS:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner in [Vector2i(station, step), Vector2i(station + 1, step), Vector2i(station + 1, step + 1), Vector2i(station, step + 1)]:
				var section := profiles[corner.x][0]
				var derivative := profiles[corner.x][1]
				var u := float(corner.y) / float(STEPS) * 2.0 - 1.0
				points.append(Vector3(u * half_width * section.x, base_y + section.y + rise * pow(maxf(0.0, 1.0 - u * u), 0.60), section.z))
				var safe_u := clampf(u, -0.995, 0.995)
				var slope := -1.2 * rise * safe_u * pow(1.0 - safe_u * safe_u, -0.40)
				var across := Vector3(half_width * section.x, slope, 0.0)
				var along := Vector3(u * half_width * derivative.x, derivative.y, 1.0)
				normals.append(along.cross(across).normalized())
			_skin_curved_quad(tool, points, normals)
			var down := Vector3.DOWN * thickness
			var inner: Array[Vector3] = [points[3] + down, points[2] + down, points[1] + down, points[0] + down]
			var inner_normals: Array[Vector3] = [-normals[3], -normals[2], -normals[1], -normals[0]]
			_skin_curved_quad(tool, inner, inner_normals)
			if station == 0:
				_roof_service_quad(tool, points[3], points[3] + down, points[0] + down, points[0], false)
			if station == profiles.size() - 2:
				_roof_service_quad(tool, points[1], points[1] + down, points[2] + down, points[2], false)
			if step == 0:
				_roof_service_quad(tool, points[0], points[0] + down, points[1] + down, points[1], false)
			if step == STEPS - 1:
				_roof_service_quad(tool, points[2], points[2] + down, points[3] + down, points[3], false)
	tool.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	instance.set_meta("visual_only", true)
	parent.add_child(instance)
	return instance


func _skin_curved_quad(tool: SurfaceTool, points: Array[Vector3], normals: Array[Vector3]) -> void:
	for index in [0, 2, 1, 0, 3, 2]:
		tool.set_normal(normals[index])
		tool.set_uv(Vector2(points[index].x, points[index].z))
		tool.add_vertex(points[index])


func _skin_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for vertex in [a, c, b, a, d, c]:
		tool.set_normal(normal)
		tool.set_uv(Vector2(vertex.x, vertex.z))
		tool.add_vertex(vertex)


## Broad planar armour faces with two shallow corner facets. This is a sheet
## assembly, not an inflated superellipse; every panel reflects light as a plane.
func _armour_pod(parent: Node3D, node_name: String, origin: Vector3,
		sections: PackedVector3Array, material: Material, _ring_count := 24) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var rings: Array[PackedVector3Array] = []
	for section in sections:
		var ring := PackedVector3Array()
		for xy in [Vector2(1.0, 0.68), Vector2(0.94, 0.90), Vector2(0.77, 1.0), Vector2(-0.77, 1.0), Vector2(-0.94, 0.90), Vector2(-1.0, 0.68), Vector2(-1.0, -0.68), Vector2(-0.94, -0.90), Vector2(-0.77, -1.0), Vector2(0.77, -1.0), Vector2(0.94, -0.90), Vector2(1.0, -0.68)]:
			ring.append(Vector3(section.x * xy.x, section.y * xy.y, section.z))
		rings.append(ring)
	for station in rings.size() - 1:
		for edge in 12:
			var next := (edge + 1) % 12
			_skin_quad(tool, rings[station][edge], rings[station][next], rings[station + 1][next], rings[station + 1][edge])
	for edge in 12:
		var next := (edge + 1) % 12
		_skin_quad(tool, Vector3(0.0, 0.0, sections[0].z), rings[0][next], rings[0][edge], Vector3(0.0, 0.0, sections[0].z))
		_skin_quad(tool, Vector3(0.0, 0.0, sections[-1].z), rings[-1][edge], rings[-1][next], Vector3(0.0, 0.0, sections[-1].z))
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = origin
	instance.mesh = tool.commit()
	instance.set_meta("closed_loft_hull", true)
	parent.add_child(instance)
	return instance


## A removable forward cowl surrounds the narrow power cartridge. Its rolled
## trailing lip ends ahead of the exposed cooling stack; both surfaces are open
## along the exhaust axis, so neither seals the existing live exhaust aperture.
## This mesh is built once and shared by the four engine nodes on each ship.
func _freighter_engine_module_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_engine_module_surface(mesh, PackedVector2Array([
		Vector2(0.61, 9.65), Vector2(0.84, 9.98),
		Vector2(0.94, 10.16), Vector2(0.97, 10.30),
		Vector2(0.97, 11.06), Vector2(0.95, 11.16),
		Vector2(0.90, 11.22), Vector2(0.83, 11.22),
		Vector2(0.82, 11.15), Vector2(0.86, 10.30),
		Vector2(0.54, 9.65), Vector2(0.61, 9.65)]),
		_jovian_materials.hull_cool)
	_engine_module_surface(mesh, PackedVector2Array([
		Vector2(0.68, 10.94), Vector2(0.72, 11.15),
		Vector2(0.72, 12.63), Vector2(0.80, 12.76),
		Vector2(0.83, 12.94), Vector2(0.68, 12.94),
		Vector2(0.63, 12.70), Vector2(0.63, 10.94),
		Vector2(0.68, 10.94)]), _jovian_materials.dark)
	return mesh


func _engine_module_surface(mesh: ArrayMesh, profile: PackedVector2Array, material: Material, segments := 48) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var profile_distance := 0.0
	var wrap_radius := 0.0
	for point in profile:
		wrap_radius = maxf(wrap_radius, point.x)
	for station in profile.size() - 1:
		var front := profile[station]
		var rear := profile[station + 1]
		var next_distance := profile_distance + front.distance_to(rear)
		var along := Vector2(rear.y - front.y, front.x - rear.x).normalized()
		for segment in segments:
			var a := TAU * float(segment) / float(segments)
			var b := TAU * float(segment + 1) / float(segments)
			var radial_a := Vector3(cos(a), sin(a), 0.0)
			var radial_b := Vector3(cos(b), sin(b), 0.0)
			var normal_a := radial_a * along.x + Vector3.BACK * along.y
			var normal_b := radial_b * along.x + Vector3.BACK * along.y
			var points := [radial_a * front.x + Vector3.BACK * front.y,
				radial_b * front.x + Vector3.BACK * front.y,
				radial_b * rear.x + Vector3.BACK * rear.y,
				radial_a * rear.x + Vector3.BACK * rear.y]
			var normals := [normal_a, normal_b, normal_b, normal_a]
			# Unwrap by arc length and accumulated section distance. The seam
			# has separate 0/TAU vertices; the rolled lips retain useful UV area
			# and tangent space instead of collapsing under roof-style X/Z UVs.
			var uvs := [Vector2(a * wrap_radius, profile_distance),
				Vector2(b * wrap_radius, profile_distance),
				Vector2(b * wrap_radius, next_distance),
				Vector2(a * wrap_radius, next_distance)]
			for index in [0, 2, 1, 0, 3, 2]:
				tool.set_normal(normals[index])
				tool.set_uv(uvs[index])
				tool.add_vertex(points[index])
		profile_distance = next_distance
	tool.generate_tangents()
	tool.commit(mesh)


## An open exhaust collar exposes a dark recessed throat while offline. The
## existing emissive core and damage-controlled plume occupy the same aperture
## while running; a solid hull-coloured cylinder cap no longer seals it shut.
func _freighter_exhaust_collar(node_name: String, at: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_jovian_materials.structure)
	for segment in 32:
		var angle_a := TAU * float(segment) / 32.0
		var angle_b := TAU * float(segment + 1) / 32.0
		var radial_a := Vector3(cos(angle_a), sin(angle_a), 0.0)
		var radial_b := Vector3(cos(angle_b), sin(angle_b), 0.0)
		var forward := Vector3.FORWARD * 0.21
		var aft := Vector3.BACK * 0.21
		_skin_quad(tool, radial_a * 1.02 + forward, radial_b * 1.02 + forward,
			radial_b * 0.98 + aft, radial_a * 0.98 + aft)
		_skin_quad(tool, radial_b * 0.68 + forward, radial_a * 0.68 + forward,
			radial_a * 0.82 + aft, radial_b * 0.82 + aft)
		_skin_quad(tool, radial_b * 0.98 + aft, radial_b * 0.82 + aft,
			radial_a * 0.82 + aft, radial_a * 0.98 + aft)
		_skin_quad(tool, radial_a * 1.02 + forward, radial_a * 0.68 + forward,
			radial_b * 0.68 + forward, radial_b * 1.02 + forward)
	var collar := MeshInstance3D.new()
	collar.name = node_name
	collar.position = at
	collar.mesh = tool.commit()
	_jovian_visual.add_child(collar)
	_cylinder(_jovian_visual, node_name + "RecessedThroat", at + Vector3.BACK * 0.03,
		0.69, 0.04, _jovian_materials.dark, Vector3(90.0, 0.0, 0.0))


## Asymmetric pressed shoulder: a broad sloping upper load face meets the
## pressure crown, a straight outer service face carries the existing hatches,
## and a tucked lower chine exposes the landing gear. The ring stays outside
## x=5.75 at full section, preserving the actual freight-room volume.
func _freighter_sponson(node_name: String, side: float, sections: PackedVector3Array) -> void:
	var profile := PackedVector2Array([
		Vector2(1.15, 0.90), Vector2(0.70, 1.72),
		Vector2(0.42, 1.86), Vector2(0.34, 1.80),
		Vector2(-0.68, 2.25), Vector2(-0.85, 2.38),
		Vector2(-1.15, 2.38), Vector2(-1.15, -1.72),
		Vector2(-0.80, -1.98), Vector2(0.65, -1.98), Vector2(1.15, -1.30)])
	# Form a small bend radius at every fold instead of an infinitely sharp
	# extrusion. Straight runs stay planar; bends retain the profile extrema
	# and inner pressure-room boundary, preserving cargo-aperture clearance.
	var rounded_profile := PackedVector2Array()
	var profile_materials: Array[Material] = []
	for corner in profile.size():
		var previous := profile[(corner - 1 + profile.size()) % profile.size()]
		var at := profile[corner]
		var next := profile[(corner + 1) % profile.size()]
		var bend := minf(0.40, minf(at.distance_to(previous), at.distance_to(next)) * 0.45)
		var start := at + (previous - at).normalized() * bend
		var finish := at + (next - at).normalized() * bend
		var face_material: Material = _jovian_materials.hull_cool
		if corner in [2, 3, 4]:
			face_material = _jovian_materials.thermal_cover
		elif corner in [8, 9]:
			face_material = _jovian_materials.structure
		for step in 5:
			var t := float(step) / 4.0
			rounded_profile.append(start.lerp(at, t).lerp(at.lerp(finish, t), t))
			profile_materials.append(face_material)
	var rings: Array[PackedVector3Array] = []
	for section in _pressure_loft_stations(sections):
		var ring := PackedVector3Array()
		for xy in rounded_profile:
			ring.append(Vector3(side * (6.9 + xy.x * section.x),
				2.05 + xy.y * section.y, section.z))
		if side < 0.0:
			ring.reverse()
		rings.append(ring)
	var edge_materials := {}
	for edge in rounded_profile.size():
		var mirrored_edge: int = (rounded_profile.size() - 2 - edge + rounded_profile.size()) % rounded_profile.size() if side < 0.0 else edge
		edge_materials[mirrored_edge] = profile_materials[edge]
	_curved_pressure_member(_jovian_visual, node_name, rings, _jovian_materials.hull_cool, edge_materials)


## The cabin is nested between these tapered shell wings. They join its roof
## and lower deck to the freight crown without filling the walking volume.
func _flight_deck_transition(side: float) -> void:
	var rings: Array[PackedVector3Array] = []
	var sections := PackedVector3Array([
		Vector3(3.72, 3.90, -7.60), Vector3(6.00, 4.00, -6.35),
		Vector3(6.00, 4.10, -4.75), Vector3(5.73, 4.43, -2.88)])
	for station in _pressure_loft_stations(sections, 0.12):
		var inner_x := 3.46
		var width := station.x - inner_x
		var bottom := 0.42
		var height := station.y - bottom
		var ring := PackedVector3Array()
		# A quarter-ellipse rolls the broad crown into the outer cheek. The
		# inboard pressure wall remains exactly at the cabin clearance plane.
		var radius_x := width * 0.72
		var radius_y := height * 0.50
		for step in 33:
			var angle := float(step) / 32.0 * PI * 0.5
			ring.append(Vector3(side * (station.x - radius_x + radius_x * cos(angle)),
				station.y - radius_y + radius_y * sin(angle), station.z))
		ring.append(Vector3(side * inner_x, station.y, station.z))
		ring.append(Vector3(side * inner_x, bottom, station.z))
		for step in 32:
			var angle := PI * 1.5 + float(step) / 32.0 * PI * 0.5
			ring.append(Vector3(side * (station.x - radius_x + radius_x * cos(angle)),
				bottom + radius_y + radius_y * sin(angle), station.z))
		# An integral machined landing under the unchanged defensive bearing
		# blends into the pressure cheek; it is part of this skin, not a pad
		# layered over it. The full support footprint meets y=3.37.
		for index in ring.size():
			var point := ring[index]
			var distance := Vector2(absf(point.x) - 5.15, point.z + 5.55).length()
			var radial_weight := 1.0 - smoothstep(0.78, 1.65, distance)
			var upper_weight := smoothstep(bottom + radius_y - 0.70,
				bottom + radius_y + 0.10, point.y)
			point.y = lerpf(point.y, 3.37, radial_weight * upper_weight)
			ring[index] = point
		if side < 0.0:
			ring.reverse()
		rings.append(ring)
	_curved_pressure_member(_jovian_visual,
		"PortCabinTransition" if side < 0.0 else "StarboardCabinTransition",
		rings, _jovian_materials.hull_warm)


## Sample only where the authored station profile bends; straight cargo runs
## stay single spans. Monotone interpolation preserves their physical envelope.
func _pressure_loft_stations(sections: PackedVector3Array, spacing := 0.30) -> PackedVector3Array:
	var sampled := PackedVector3Array()
	for station in sections.size() - 1:
		var steps := _roof_span_steps(sections, sections[station].z, sections[station + 1].z)
		if spacing < 0.30:
			steps = ceili((sections[station + 1].z - sections[station].z) / spacing)
		for step in steps:
			sampled.append(_roof_profile(sections, lerpf(sections[station].z,
				sections[station + 1].z, float(step) / steps))[0])
	sampled.append(sections[-1])
	return sampled


func _forward_bow_apron(parent: Node3D, node_name: String, origin: Vector3,
		sections: PackedVector3Array, material: Material) -> void:
	var rings: Array[PackedVector3Array] = []
	for station in _pressure_loft_stations(sections):
		var ring := PackedVector3Array()
		# Flat upper/lower deck faces terminate in a rolled elliptical edge.
		for side in [1.0, -1.0]:
			for step in 17:
				var angle := -PI * 0.5 + float(step) / 16.0 * PI
				ring.append(Vector3(side * (station.x * 0.86 + station.x * 0.14 * cos(angle)),
					side * station.y * sin(angle), station.z))
		rings.append(ring)
	var member := _curved_pressure_member(parent, node_name, rings, material)
	member.position = origin


## Smooth side normals come from the actual loft tangents. Caps keep their
## hard tooling seam; sharp pressure-wall corners retain their planar normals.
func _curved_pressure_member(parent: Node3D, node_name: String,
		rings: Array[PackedVector3Array], material: Material, edge_materials: Dictionary = {}) -> MeshInstance3D:
	var surface_tools := {}
	var normals: Array[PackedVector3Array] = []
	for station in rings.size():
		var ring_normals := PackedVector3Array()
		for edge in rings[station].size():
			var count := rings[station].size()
			var at := rings[station][edge]
			var before := (at - rings[station][(edge - 1 + count) % count]).normalized()
			var after := (rings[station][(edge + 1) % count] - at).normalized()
			var along := rings[mini(station + 1, rings.size() - 1)][edge] - rings[maxi(0, station - 1)][edge]
			ring_normals.append((before + after).cross(along).normalized())
		normals.append(ring_normals)
	for station in rings.size() - 1:
		for edge in rings[station].size():
			var face_material: Material = edge_materials.get(edge, material)
			if not surface_tools.has(face_material):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(face_material)
				surface_tools[face_material] = tool
			var next := (edge + 1) % rings[station].size()
			var points: Array[Vector3] = [rings[station][edge], rings[station][next],
				rings[station + 1][next], rings[station + 1][edge]]
			var face_normals: Array[Vector3] = [normals[station][edge], normals[station][next],
				normals[station + 1][next], normals[station + 1][edge]]
			# Preserve intentional hard corners at the inner pressure wall.
			# The sampled radius tangents remain smooth regardless of span size.
			for corner in 4:
				var ring_index := station if corner < 2 else station + 1
				var point_index := edge if corner in [0, 3] else next
				var ring := rings[ring_index]
				var prev := (point_index - 1 + ring.size()) % ring.size()
				var following := (point_index + 1) % ring.size()
				var incoming := (ring[point_index] - ring[prev]).normalized()
				var outgoing := (ring[following] - ring[point_index]).normalized()
				if incoming.dot(outgoing) < 0.5:
					face_normals[corner] = (points[1] - points[0]).cross(points[3] - points[0]).normalized()
			_skin_curved_quad(surface_tools[face_material], points, face_normals)
	var cap_tool: SurfaceTool = surface_tools[material]
	for end in [0, rings.size() - 1]:
		var center := Vector3.ZERO
		for point in rings[end]:
			center += point
		center /= rings[end].size()
		for edge in rings[end].size():
			var next := (edge + 1) % rings[end].size()
			var vertices := [center, rings[end][edge], rings[end][next]] if end == 0 else [center, rings[end][next], rings[end][edge]]
			for vertex: Vector3 in vertices:
				cap_tool.set_normal(Vector3.FORWARD if end == 0 else Vector3.BACK)
				cap_tool.set_uv(Vector2(vertex.x, vertex.y))
				cap_tool.add_vertex(vertex)
	var mesh := ArrayMesh.new()
	for tool: SurfaceTool in surface_tools.values():
		tool.commit(mesh)
	var member := MeshInstance3D.new()
	member.name = node_name
	member.mesh = mesh
	member.set_meta("visual_only", true)
	member.set_meta("closed_loft_hull", true)
	parent.add_child(member)
	return member


## Explicit folded sections keep panel normals flat at manufacturing breaks.
## Cap fans use real triangles rather than degenerate quads.
func _formed_pressure_member(node_name: String, rings: Array[PackedVector3Array], material: Material, edge_materials: Dictionary = {}, open_bottom_edge: int = -1, curved_crown: bool = false) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var surface_tools := {material: tool}
	for station in rings.size() - 1:
		for edge in rings[station].size():
			if edge == open_bottom_edge:
				continue
			var face_material: Material = edge_materials.get(edge, material)
			if not surface_tools.has(face_material):
				var face_tool := SurfaceTool.new()
				face_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				face_tool.set_material(face_material)
				surface_tools[face_material] = face_tool
			var next := (edge + 1) % rings[station].size()
			var points: Array[Vector3] = [rings[station][edge], rings[station][next],
				rings[station + 1][next], rings[station + 1][edge]]
			var crown_edge := edge >= 1 and edge <= 6
			if rings[station][0].x < 0.0:
				crown_edge = edge >= 3 and edge <= 8
			if curved_crown and crown_edge:
				var normals: Array[Vector3] = []
				for point in points:
					var u := point.x / 5.75
					var slope := -1.2 * 0.38 * u * pow(maxf(0.001, 1.0 - u * u), -0.40) / 5.75
					var longitudinal_slope := 0.20 / 1.30 if point.z < -1.8 else 0.0
					normals.append(Vector3(-slope, 1.0, -longitudinal_slope).normalized())
				_skin_curved_quad(surface_tools[face_material], points, normals)
			else:
				_skin_quad(surface_tools[face_material], points[0], points[1], points[2], points[3])
	for end in [0, rings.size() - 1]:
		var center := Vector3.ZERO
		for point in rings[end]:
			center += point
		center /= float(rings[end].size())
		for edge in rings[end].size():
			var next := (edge + 1) % rings[end].size()
			var normal := Vector3.FORWARD if end == 0 else Vector3.BACK
			var vertices := [center, rings[end][edge], rings[end][next]] if end == 0 else [center, rings[end][next], rings[end][edge]]
			for vertex: Vector3 in vertices:
				tool.set_normal(normal)
				tool.set_uv(Vector2(vertex.x, vertex.y))
				tool.add_vertex(vertex)
	var member := MeshInstance3D.new()
	member.name = node_name
	var mesh := ArrayMesh.new()
	for surface_tool: SurfaceTool in surface_tools.values():
		surface_tool.commit(mesh)
	member.mesh = mesh
	member.set_meta("visual_only", true)
	# Service covers have an open underside over the existing pressure skin.
	# Only closed load-bearing members publish the solid hull-volume contract.
	if open_bottom_edge < 0:
		member.set_meta("closed_loft_hull", true)
	_jovian_visual.add_child(member)


## The roof carries two continuous service frames. Recessed thermal fields and
## gasketed access doors share these frames, which land directly on the curved
## pressure skin. Geometry is collected by finish, not one draw per fitting.
func _build_pressure_shell_panels() -> void:
	var roof := {}
	for side in [-1.0, 1.0]:
		var inner := 1.82
		var outer := 5.31
		_roof_service_patch(roof, "structure", side, inner, outer, -2.18, 8.27, 0.048)
		# Continuous edge folds join the existing transverse cargo ribs.
		for edge in [inner + 0.025, outer - 0.15]:
			_roof_service_patch(roof, "hull_cool", side, edge, edge + 0.125, -2.14, 8.23, 0.11)
		for bay in 4:
			var front := -2.08 + float(bay) * 2.72
			var rear := front + 2.06
			# The dark thermal well sits lower than its rolled edge and louvers.
			_roof_service_patch(roof, "dark", side, 2.00, 3.02, front, rear, 0.057)
			for lip in [2.00, 2.94]:
				_roof_service_patch(roof, "hull_cool", side, lip, lip + 0.08, front, rear, 0.12)
			for slat in 9:
				var slat_z := front + 0.12 + float(slat) * 0.215
				_roof_service_patch(roof, "thermal_cover", side, 2.075, 2.945,
					slat_z, slat_z + 0.115, 0.103)
			# A framed access opening occupies the outer half of each bay.
			_roof_service_patch(roof, "hull_cool", side, 3.13, 5.12, front, rear, 0.12)
			_roof_service_patch(roof, "dark", side, 3.22, 5.03, front + 0.09, rear - 0.09, 0.125)
			_roof_service_patch(roof, "hull_warm", side, 3.265, 4.985, front + 0.135, rear - 0.135, 0.137)
			# Folded stiffening channel is part of the lid, with a seated root.
			_roof_service_patch(roof, "hull_cool", side, 4.48, 4.60, front + 0.24, rear - 0.24, 0.164)
			for hinge_z in [front + 0.36, rear - 0.36]:
				_roof_service_patch(roof, "structure", side, 4.92, 5.11, hinge_z, hinge_z + 0.19, 0.166)
			_roof_service_patch(roof, "dark", side, 3.39, 3.64, front + 0.86, front + 1.17, 0.142)
			_roof_service_patch(roof, "structure", side, 3.465, 3.565, front + 0.905, front + 1.12, 0.16)
			# Cross straps meet the perimeter folds at the load-bearing ribs.
			if bay < 3:
				_roof_service_patch(roof, "hull_cool", side, inner + 0.025, outer - 0.025,
					rear + 0.12, rear + 0.32, 0.085)
	_finish_roof_service_mesh(roof, "RoofServiceAssembly")

	# The avionics fairing now follows the passenger crown exactly, with a
	# narrow service lid and a paired recessed cooling field behind the glass.
	var avionics := {}
	_roof_service_patch(avionics, "structure", 1.0, -1.46, 1.46, -8.90, -3.43, 0.055, true)
	_roof_service_patch(avionics, "hull_cool", 1.0, -1.40, 1.40, -8.82, -3.49, 0.135, true)
	_roof_service_patch(avionics, "dark", 1.0, -1.18, 1.18, -7.36, -4.13, 0.14, true)
	_roof_service_patch(avionics, "thermal_cover", 1.0, -1.115, 1.115, -7.285, -4.205, 0.151, true)
	for side in [-1.0, 1.0]:
		_roof_service_patch(avionics, "dark", side, 0.26, 1.07, -8.53, -7.63, 0.14, true)
		for slat in 5:
			var z := -8.47 + float(slat) * 0.16
			_roof_service_patch(avionics, "structure", side, 0.28, 1.05, z, z + 0.075, 0.172, true)
		for z in [-6.96, -4.73]:
			_roof_service_patch(avionics, "structure", side, 1.06, 1.31, z, z + 0.22, 0.18, true)
	_roof_service_patch(avionics, "dark", 1.0, -0.25, 0.25, -4.70, -4.43, 0.16, true)
	_roof_service_patch(avionics, "hull_cool", 1.0, -0.17, 0.17, -4.64, -4.49, 0.18, true)
	_finish_roof_service_mesh(avionics, "FlightDeckAvionicsBonnet")


## Evaluate the same transverse crown and longitudinal stations as the actual
## pressure roof. Even at the taper, every perimeter returns to this surface.
func _roof_service_height(x: float, z: float, cabin: bool) -> float:
	var sections := CARGO_ROOF_SECTIONS
	var half_width := 5.75
	var base_y := 4.43
	var rise := 0.38
	if cabin:
		sections = CABIN_ROOF_SECTIONS
		half_width = 3.56
		base_y = 3.80
		rise = 0.43
	var section := _roof_profile(PackedVector3Array(sections), z)[0]
	return base_y + section.y + rise * pow(maxf(0.0, 1.0 - pow(x / (half_width * section.x), 2)), 0.60)


## A shallow pressed patch with a rolled edge and an open underside. Station
## cuts follow the formed pressure shell so long frames cannot bridge in air.
func _roof_service_patch(batch: Dictionary, finish: String, side: float, inner: float,
		outer: float, front: float, rear: float, lift: float, cabin := false) -> void:
	if not batch.has(finish):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(_jovian_materials[finish])
		batch[finish] = tool
	var tool: SurfaceTool = batch[finish]
	var bevel := minf(0.10, minf((outer - inner) * 0.22, (rear - front) * 0.22))
	var stations: Array[float] = [front, front + bevel, rear - bevel, rear]
	for split in [-7.65, -4.05, -1.8, 8.25]:
		if split > front + bevel and split < rear - bevel:
			stations.append(split)
	stations.sort()
	var fitted_stations: Array[float] = []
	var roof_sections := PackedVector3Array(CABIN_ROOF_SECTIONS if cabin else CARGO_ROOF_SECTIONS)
	for station in stations.size() - 1:
		var count := _roof_span_steps(roof_sections, stations[station], stations[station + 1])
		for sample in count:
			fitted_stations.append(lerpf(stations[station], stations[station + 1], float(sample) / count))
	fitted_stations.append(stations[-1])
	var rings: Array[PackedVector3Array] = []
	for z in fitted_stations:
		var end := is_equal_approx(z, front) or is_equal_approx(z, rear)
		var xmin := inner + (bevel if end else 0.0)
		var xmax := outer - (bevel if end else 0.0)
		var ring := PackedVector3Array()
		for step in 13:
			var x := side * lerpf(xmin, xmax, float(step) / 12.0)
			var edge := end or step == 0 or step == 12
			ring.append(Vector3(x, _roof_service_height(x, z, cabin) + lift - (minf(lift * 0.3, 0.035) if edge else 0.0), z))
		rings.append(ring)
	for station in rings.size() - 1:
		for step in 12:
			_roof_service_quad(tool, rings[station][step], rings[station + 1][step],
				rings[station + 1][step + 1], rings[station][step + 1], side < 0)
		for edge in [0, 12]:
			var a := rings[station][edge]
			var b := rings[station + 1][edge]
			var c := Vector3(b.x, _roof_service_height(b.x, b.z, cabin), b.z)
			var d := Vector3(a.x, _roof_service_height(a.x, a.z, cabin), a.z)
			_roof_service_quad(tool, a, d, c, b, (edge == 12) != (side < 0))
	for end in [0, rings.size() - 1]:
		for step in 12:
			var a := rings[end][step]
			var b := rings[end][step + 1]
			var c := Vector3(b.x, _roof_service_height(b.x, b.z, cabin), b.z)
			var d := Vector3(a.x, _roof_service_height(a.x, a.z, cabin), a.z)
			_roof_service_quad(tool, a, b, c, d, (end != 0) != (side < 0))


func _roof_service_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, reverse: bool) -> void:
	var points := [a, d, c, b] if reverse else [a, b, c, d]
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	for index in [0, 2, 1, 0, 3, 2]:
		var point: Vector3 = points[index]
		tool.set_normal(normal)
		# Side walls need their own projection to preserve UV area/tangents.
		var uv := Vector2(point.x, point.z)
		if absf(normal.x) > absf(normal.y):
			uv = Vector2(point.z, point.y)
		elif absf(normal.z) > absf(normal.y):
			uv = Vector2(point.x, point.y)
		tool.set_uv(uv)
		tool.add_vertex(point)


func _finish_roof_service_mesh(batch: Dictionary, node_name: String) -> void:
	var mesh := ArrayMesh.new()
	for tool: SurfaceTool in batch.values():
		tool.generate_tangents()
		tool.commit(mesh)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.set_meta("visual_only", true)
	_jovian_visual.add_child(instance)


func _build_fitted_freighter_details() -> void:
	var exterior := {}
	# The shoulder service doors are fitted inside their existing dark bezels:
	# perimeter reveals, hinge pins and a recessed pull replace blank blue tiles.
	for side in [-1.0, 1.0]:
		for panel_index in 4:
			if side < 0.0 and panel_index == 2:
				continue
			var at := Vector3(side * 8.09, 2.12, -4.1 + panel_index * 3.75)
			_fitout_stock(exterior, "hull_cool", at, Vector3(0.035, 1.20, 1.75))
			_fitout_stock(exterior, "dark", at + Vector3(side * 0.025, 0, -0.54), Vector3(0.025, 0.26, 0.10))
			_fitout_stock(exterior, "structure", at + Vector3(side * 0.045, 0, -0.54), Vector3(0.035, 0.14, 0.045))
			for hinge_y in [-0.43, 0.43]:
				_fitout_stock(exterior, "structure", at + Vector3(side * 0.025, hinge_y, 0.76), Vector3(0.065, 0.15, 0.085))
			for seam_y in [0.84, -0.86]:
				_fitout_stock(exterior, "structure", at + Vector3(-side * 0.045, seam_y, 0), Vector3(0.024, 0.025, 2.42))
		# A structural apron meets the pressure glazing instead of ending in air.
		_fitout_stock(exterior, "structure", Vector3(side * 2.8, 0.77, -9.48), Vector3(0.15, 0.12, 3.9), Vector3(0, side * 0.22, 0))
	for side in [-1.0, 1.0]:
		for tier in 2:
			var engine_x: float = side * (5.05 + tier * 1.35)
			var engine_y := 1.15 + tier * 2.25
			# Exposed heat exchanger fins sit around the actual service barrel.
			# The forward cowl stops ahead of them, leaving a dark reveal and
			# clearance for longitudinal tie rods and the aft retaining flange.
			for ring_z in [11.40, 11.58, 11.76, 11.94, 12.12, 12.30, 12.48]:
				_fitout_ring(exterior, "structure", Vector3(engine_x, engine_y, ring_z), 0.73, 0.86)
			for ring_z in [11.25, 12.70]:
				_fitout_ring(exterior, "structure", Vector3(engine_x, engine_y, ring_z), 0.78, 0.96)
			for rod in 4:
				var angle := TAU * float(rod) / 4.0 + PI * 0.25
				var offset := Vector3(sin(angle), cos(angle), 0.0)
				_fitout_stock(exterior, "thermal_cover", Vector3(engine_x, engine_y, 11.97) + offset * 0.88,
					Vector3(0.11, 0.12, 1.70), Vector3(0, 0, -angle))
				for flange_z in [11.25, 12.70]:
					_fitout_stock(exterior, "hull_cool", Vector3(engine_x, engine_y, flange_z) + offset * 0.88,
						Vector3(0.21, 0.20, 0.20), Vector3(0, 0, -angle))
			# The upper service lid and amber latch are visibly mounted on the
			# forward nacelle, instead of surface lines cutting through armour.
			_fitout_stock(exterior, "dark", Vector3(engine_x, engine_y + 0.95, 10.64), Vector3(0.70, 0.07, 0.70))
			_fitout_stock(exterior, "thermal_cover", Vector3(engine_x, engine_y + 0.985, 10.64), Vector3(0.61, 0.065, 0.60))
			_fitout_stock(exterior, "amber", Vector3(engine_x, engine_y + 1.025, 10.82), Vector3(0.22, 0.035, 0.085))

	_finish_fitout(_jovian_visual, exterior, "FreighterServiceFittings")

	var interior := {}
	# Segmented load-bearing deck plates, with removable centre service covers.
	for bay_z in [-1.85, 0.15, 2.15, 4.15, 6.15, 8.15]:
		_fitout_stock(interior, "structure", Vector3(0, 0.596, bay_z), Vector3(10.96, 0.009, 0.023))
		for x in [-4.18, 4.18]:
			_fitout_stock(interior, "dark", Vector3(x, 0.597, bay_z + 0.18), Vector3(0.32, 0.009, 0.055))
	for side in [-1.0, 1.0]:
		# Pressure bulkhead wings have a shallow liner, kick plate and service
		# access face. All remain outside the central door and cargo route.
		_fitout_stock(interior, "cabin_liner", Vector3(side * 3.55, 2.58, -2.77), Vector3(3.8, 2.74, 0.045))
		_fitout_stock(interior, "dark", Vector3(side * 3.55, 0.93, -2.745), Vector3(3.82, 0.42, 0.055))
		_fitout_stock(interior, "dark", Vector3(side * 2.7, 2.66, -2.724), Vector3(1.18, 1.60, 0.028))
		_fitout_stock(interior, "hull_cool", Vector3(side * 2.7, 2.66, -2.698), Vector3(1.10, 1.52, 0.026))
		_fitout_stock(interior, "structure", Vector3(side * 2.32, 2.66, -2.677), Vector3(0.085, 0.23, 0.024))
		for bay_index in 4:
			if side < 0.0 and bay_index in [1, 2]:
				continue
			var bay_z := -1.35 + bay_index * 2.65
			_fitout_stock(interior, "structure", Vector3(side * 5.452, 1.04, bay_z), Vector3(0.033, 0.24, 2.46))
			_fitout_stock(interior, "dark", Vector3(side * 5.451, 3.66, bay_z), Vector3(0.028, 0.21, 2.20))
			for slat in 8:
				_fitout_stock(interior, "structure", Vector3(side * 5.43, 3.66, bay_z - 0.92 + slat * 0.26), Vector3(0.03, 0.22, 0.04))
		# Ceiling cable trays live at the frame springline, with hangers aligned
		# to pressure bays rather than arbitrary blocks over the roof surface.
		_fitout_stock(interior, "structure", Vector3(side * 4.52, 4.16, 3.05), Vector3(0.30, 0.16, 11.60))
		_fitout_stock(interior, "dark", Vector3(side * 4.52, 4.068, 3.05), Vector3(0.19, 0.027, 11.52))
	for light_z in [-1.25, 2.85, 6.95]:
		_fitout_stock(interior, "structure", Vector3(0, 4.44, light_z), Vector3(2.62, 0.08, 0.66))
		for edge in [-1.27, 1.27]:
			_fitout_stock(interior, "dark", Vector3(edge, 4.355, light_z), Vector3(0.045, 0.11, 0.65))
	# Container door cassettes have rolled stiffeners, paired lockbars and
	# hinges within the existing restrained crate/collider envelope.
	for at in CARGO_UNIT_ANCHORS:
		for face in [-1.0, 1.0]:
			for x in [-0.43, 0.43]:
				_fitout_stock(interior, "freight_shell", at + Vector3(x, 0.91, face * 1.102), Vector3(0.67, 0.72, 0.033))
				_fitout_stock(interior, "structure", at + Vector3(x, 0.91, face * 1.126), Vector3(0.048, 0.67, 0.035))
				_fitout_stock(interior, "liner", at + Vector3(x + 0.065, 0.85, face * 1.15), Vector3(0.17, 0.045, 0.03))
	_build_fitted_cargo_restraints(interior)
	_finish_fitout(_cargo_bay, interior, "CargoFitout")
	_build_passenger_room_fitout()


# Padding is formed from a dished centre and raised lateral bolsters. Merging
# the pieces preserves the three immutable meshes shared by all six stations.
func _build_fitted_passenger_seat_meshes() -> void:
	var cushion := {}
	_fitout_stock(cushion, "cabin_cloth", Vector3(0, -0.014, -0.015), Vector3(0.55, 0.18, 0.78))
	for side in [-1.0, 1.0]:
		_fitout_stock(cushion, "cabin_cloth", Vector3(side * 0.31, 0.025, 0), Vector3(0.10, 0.22, 0.78), Vector3(0, 0, side * -0.10))
	_passenger_seat_base_mesh = (cushion.cabin_cloth as SurfaceTool).commit()
	var back := {}
	_fitout_stock(back, "cabin_cloth", Vector3(0, -0.025, 0), Vector3(0.51, 0.83, 0.16))
	_fitout_stock(back, "cabin_cloth", Vector3(0, -0.32, -0.045), Vector3(0.52, 0.17, 0.19), Vector3(-0.15, 0, 0))
	for side in [-1.0, 1.0]:
		_fitout_stock(back, "cabin_cloth", Vector3(side * 0.305, 0, -0.035), Vector3(0.105, 0.90, 0.23), Vector3(0, side * -0.20, side * 0.05))
	_passenger_seat_back_mesh = (back.cabin_cloth as SurfaceTool).commit()
	var straps := {}
	for side in [-1.0, 1.0]:
		_fitout_stock(straps, "webbing", Vector3(side * 0.16, 0.025, -0.052), Vector3(0.062, 0.82, 0.024), Vector3(0.14, 0, side * -0.12))
		_fitout_stock(straps, "webbing", Vector3(side * 0.17, -0.365, -0.16), Vector3(0.36, 0.065, 0.022), Vector3(0, 0.18 * side, 0.12 * side))
	_passenger_seat_harness_mesh = (straps.webbing as SurfaceTool).commit()


func _build_passenger_room_fitout() -> void:
	var room := {}
	# Continuous upper liner and a single cabinet run read as pressure-cabin
	# construction; reveals coincide with seat stations and service access.
	for side in [-1.0, 1.0]:
		_fitout_stock(room, "cabin_liner", Vector3(side * 3.247, 2.025, -5.25), Vector3(0.035, 0.65, 4.37))
		_build_cabin_formed_shoulder(room, side)
		_fitout_stock(room, "cabin_shell", Vector3(side * 3.22, 1.12, -5.25), Vector3(0.075, 1.13, 4.37))
		_fitout_stock(room, "structure", Vector3(side * 3.17, 0.69, -5.25), Vector3(0.10, 0.15, 4.33))
		_fitout_stock(room, "cabin_shell", Vector3(side * 3.19, 3.59, -5.25), Vector3(0.20, 0.12, 4.36), Vector3(0, 0, side * -0.40))
		_fitout_stock(room, "dark", Vector3(side * 3.20, 3.13, -5.25), Vector3(0.035, 0.028, 4.34))
		for seam_z in [-5.9, -4.6]:
			_fitout_stock(room, "structure", Vector3(side * 3.223, 2.025, seam_z), Vector3(0.018, 0.63, 0.018))
		# Seat support rails sit below the cushion instead of floating furniture.
		_fitout_stock(room, "structure", Vector3(side * 2.62, 0.66, -5.25), Vector3(0.50, 0.09, 3.9))
		for seat_index in 3:
			var seat_root := _passenger_cabin.get_node(("Port" if side < 0 else "Starboard") + "PassengerSeat%02d" % seat_index) as Node3D
			var fittings := {}
			_fitout_stock(fittings, "cabin_shell", Vector3(0, 0.775, 0.015), Vector3(0.79, 0.12, 0.89))
			_fitout_stock(fittings, "structure", Vector3(0, 0.655, 0.09), Vector3(0.40, 0.16, 0.40))
			_fitout_stock(fittings, "cabin_shell", Vector3(0, 1.43, 0.49), Vector3(0.78, 1.08, 0.09), Vector3(0.14, 0, 0))
			# Recessed rear shell insert, moulded edge wings and headrest carrier.
			_fitout_stock(fittings, "structure", Vector3(0, 1.44, 0.557), Vector3(0.58, 0.67, 0.045), Vector3(0.14, 0, 0))
			_fitout_stock(fittings, "cabin_shell", Vector3(0, 1.89, 0.48), Vector3(0.30, 0.28, 0.07))
			_fitout_stock(fittings, "cabin_shell", Vector3(0, 1.99, 0.565), Vector3(0.55, 0.27, 0.055))
			_fitout_stock(fittings, "structure", Vector3(0, 1.06, 0.04), Vector3(0.13, 0.12, 0.055))
			_fitout_stock(fittings, "amber", Vector3(0, 1.065, 0.005), Vector3(0.067, 0.045, 0.022))
			for edge in [-1.0, 1.0]:
				_fitout_stock(fittings, "cabin_shell", Vector3(edge * 0.386, 1.39, 0.36), Vector3(0.065, 1.02, 0.22), Vector3(0.14, edge * -0.12, 0))
				_fitout_stock(fittings, "structure", Vector3(edge * 0.40, 0.97, 0.26), Vector3(0.055, 0.28, 0.08))
			# One merged mesh per finish for the whole room, using the existing
			# station transform; the seat roots and anchors remain untouched.
			for finish: String in fittings:
				if not room.has(finish):
					var tool := SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					tool.set_material(_jovian_materials[finish])
					room[finish] = tool
				(room[finish] as SurfaceTool).append_from((fittings[finish] as SurfaceTool).commit(), 0, seat_root.transform)
	# A fitted overhead service spine and curved shoulder fillets leave the
	# existing cabin roof and its load-bearing envelope intact.
	_fitout_stock(room, "cabin_liner", Vector3(0, 3.708, -5.25), Vector3(4.82, 0.045, 4.33))
	_fitout_stock(room, "cabin_shell", Vector3(0, 3.65, -5.25), Vector3(0.58, 0.09, 4.3))
	# The existing single practical now sits immediately below a real central
	# diffuser. The broad tray throws light across upholstery and the aisle.
	_fitout_stock(room, "structure", Vector3(0, 3.56, -5.25), Vector3(1.05, 0.18, 2.90))
	_fitout_stock(room, "interior_light", Vector3(0, 3.456, -5.25), Vector3(0.86, 0.025, 2.70))
	for side in [-1.0, 1.0]:
		_fitout_stock(room, "cabin_shell", Vector3(side * 0.54, 3.57, -5.25), Vector3(0.12, 0.20, 2.98), Vector3(0, 0, side * 0.22))
	# Recessed floor runner, with two service joints and a narrow safety reveal.
	_fitout_stock(room, "structure", Vector3(0, 0.594, -5.25), Vector3(2.56, 0.008, 4.26))
	for side in [-1.0, 1.0]:
		_fitout_stock(room, "cabin_shell", Vector3(side * 1.30, 0.597, -5.25), Vector3(0.035, 0.012, 4.27))
	for seam_z in [-5.9, -4.6]:
		_fitout_stock(room, "dark", Vector3(0, 0.603, seam_z), Vector3(2.53, 0.007, 0.018))
	# The live engineer readout is suspended from the pressure-frame header.
	# A continuous surround and rear spine give the existing screen a housing.
	_fitout_stock(room, "cabin_shell", Vector3(0, 2.5, -3.19), Vector3(1.18, 0.72, 0.13))
	_fitout_stock(room, "structure", Vector3(0, 3.17, -3.23), Vector3(0.20, 0.83, 0.16))
	_finish_fitout(_passenger_cabin, room, "PassengerFitout")


# One formed liner sweeps the wall into the roof, replacing the flat upper
# panels. Its smooth shoulder is above the occupied seat envelope; the long
# luminous strip is retained in a recessed cove behind the inward return.
func _build_cabin_formed_shoulder(room: Dictionary, side: float) -> void:
	var tool := room["cabin_liner"] as SurfaceTool
	for segment in 16:
		# Leave a continuous recessed aperture in front of the shared strip.
		if segment in [9, 10]:
			continue
		var angle_a := float(segment) / 16.0 * PI * 0.5
		var angle_b := float(segment + 1) / 16.0 * PI * 0.5
		var a := Vector3(side * (2.42 + 0.81 * cos(angle_a)), 2.38 + 1.31 * sin(angle_a), -7.415)
		var b := Vector3(side * (2.42 + 0.81 * cos(angle_b)), 2.38 + 1.31 * sin(angle_b), -7.415)
		var length := Vector3(0, 0, 4.33)
		if side > 0:
			_skin_quad(tool, a, a + length, b + length, b)
		else:
			_skin_quad(tool, b, b + length, a + length, a)
	_fitout_stock(room, "structure", Vector3(side * 3.29, 3.46, -5.25), Vector3(0.04, 0.25, 3.76))


func _build_fitted_cargo_restraints(interior: Dictionary) -> void:
	for at in CARGO_UNIT_ANCHORS:
		# Existing amber top restraints now continue down to pallet clevises.
		# Faces are shallow additions around the unchanged solid freight volume.
		for side in [-1.0, 1.0]:
			for band_z in CARGO_RESTRAINT_BAND_Z:
				_fitout_stock(interior, "webbing", at + Vector3(side * 0.99, 0.94, band_z), Vector3(0.028, 1.30, 0.10))
				_fitout_stock(interior, "structure", at + Vector3(side * 1.012, 0.55, band_z), Vector3(0.047, 0.27, 0.18))
				_fitout_stock(interior, "amber", at + Vector3(side * 1.04, 0.57, band_z), Vector3(0.025, 0.11, 0.09))
			# Broad replaceable panels are inset between the two tension bands.
			_fitout_stock(interior, "structure", at + Vector3(side * 0.978, 0.93, 0), Vector3(0.028, 0.80, 1.03))
			_fitout_stock(interior, "freight_shell", at + Vector3(side * 0.997, 0.94, 0), Vector3(0.025, 0.69, 0.91))
			for seam_y in [0.52, 1.34]:
				_fitout_stock(interior, "cabin_shell", at + Vector3(side * 0.988, seam_y, 0), Vector3(0.028, 0.048, 1.83))
			for foot_z in [-0.97, 0.97]:
				_fitout_stock(interior, "cabin_shell", at + Vector3(side * 0.84, 0.30, foot_z), Vector3(0.24, 0.18, 0.20))
		# Fitted lid edging explains the top bands' slight standoff.
		for side in [-1.0, 1.0]:
			_fitout_stock(interior, "cabin_shell", at + Vector3(side * 0.92, 1.55, 0), Vector3(0.085, 0.12, 2.05))
	for side in [-1.0, 1.0]:
		# Panel hinges and a flush latch complete the existing service-door faces.
		for hinge_y in [2.11, 3.17]:
			_fitout_stock(interior, "structure", Vector3(side * 3.20, hinge_y, -2.671), Vector3(0.06, 0.16, 0.035))
		_fitout_stock(interior, "cabin_shell", Vector3(side * 2.32, 2.65, -2.650), Vector3(0.028, 0.14, 0.025))
		# The portal is painted neutral with a restrained amber threshold cue.
		_fitout_stock(interior, "amber", Vector3(side * 1.46, 0.82, -2.76), Vector3(0.15, 0.37, 0.04))
		_fitout_stock(interior, "structure", Vector3(side * 1.64, 2.37, -2.725), Vector3(0.06, 3.34, 0.042))
		_fitout_stock(interior, "dark", Vector3(side * 3.55, 3.64, -2.737), Vector3(3.70, 0.021, 0.024))


# Fitted visual stock is merged by finish. The moving hull owns its transform;
# gameplay seats, hatch, route markers and colliders retain their own authority.
func _fitout_stock(batch: Dictionary, finish: String, at: Vector3, size: Vector3,
		rotation_value := Vector3.ZERO) -> void:
	if not batch.has(finish):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(_jovian_materials[finish])
		batch[finish] = tool
	var stock_key := "padding:" + str(size) if finish == "cabin_cloth" else \
		"%0.4f:%0.4f:%0.4f" % [size.x, size.y, size.z]
	if not _fitout_mesh_cache.has(stock_key):
		var bevel := minf(0.045, minf(size.x, minf(size.y, size.z)) * 0.35) \
			if finish == "cabin_cloth" else StationSurfaceKit.bevel_for_size(size)
		var stock := StationSurfaceKit.rounded_box_mesh_with_bevel(size, bevel)
		_fitout_mesh_cache[stock_key] = FitoutSurfaceData.new(stock)
	(batch[finish] as SurfaceTool).append_from(_fitout_mesh_cache[stock_key], 0,
		Transform3D(Basis.from_euler(rotation_value), at))


func _finish_fitout(parent: Node3D, batch: Dictionary, prefix: String) -> void:
	for finish: String in batch:
		var visual := MeshInstance3D.new()
		visual.name = prefix + finish.capitalize()
		visual.mesh = (batch[finish] as SurfaceTool).commit()
		visual.material_override = _jovian_materials[finish]
		visual.set_meta("visual_detail_only", true)
		parent.add_child(visual)


func _fitout_ring(batch: Dictionary, finish: String, at: Vector3,
		inside: float, outside: float) -> void:
	if not batch.has(finish):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(_jovian_materials[finish])
		batch[finish] = tool
	var ring_key := Vector2(inside, outside)
	if not _fitout_mesh_cache.has(ring_key):
		var ring := TorusMesh.new()
		ring.inner_radius = inside
		ring.outer_radius = outside
		ring.rings = 48
		ring.ring_segments = 8
		# Stock panels are unindexed; mixing indexed torus geometry into the same
		# SurfaceTool leaves the earlier panels outside its index buffer.
		var ring_stock := SurfaceTool.new()
		ring_stock.create_from(ring, 0)
		ring_stock.deindex()
		_fitout_mesh_cache[ring_key] = FitoutSurfaceData.new(ring_stock.commit())
	(batch[finish] as SurfaceTool).append_from(_fitout_mesh_cache[ring_key], 0,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at))


func _build_hull_markings() -> void:
	# Registration belongs to the broad cargo crown; service stencils fit inside
	# the forward shoulder closures without reaching the open freight aperture.
	var registration := ShipSurfaceDetail.mark_surface(_jovian_visual, "CargoCrownRegistration", "jovian",
		Vector3(0.0, 4.79, 2.1), Vector2(3.3, 1.65), Vector3.UP, Vector3.FORWARD)
	registration.modulate = Color(0.35, 0.35, 0.35, 1.0)
	for side in [-1.0, 1.0]:
		ShipSurfaceDetail.mark_surface(_jovian_visual,
			"PortServiceStencil" if side < 0.0 else "StarboardServiceStencil", "service",
			Vector3(side * 8.12, 2.12, -4.1), Vector2(0.8, 0.4),
			Vector3(side, 0.0, 0.0), Vector3.UP)


## Seat furniture can disappear at distance without opening the passenger shell.
## Cargo boxes, pallets, walls, curved frames, doors and lights stay unbounded.
func _configure_interior_furnishing_ranges() -> void:
	for side in ["Port", "Starboard"]:
		for row in 3:
			_limit_interior_furnishing_range(_passenger_cabin.get_node(
				NodePath(side + "PassengerSeat%02d" % row)) as Node3D)


## Native camera-distance culling affects rendering only; it never changes the
## furniture's visibility flag, seat anchors, interactions or physics lifecycle.
func _limit_interior_furnishing_range(furnishing: Node3D) -> void:
	if furnishing is GeometryInstance3D:
		var geometry := furnishing as GeometryInstance3D
		geometry.visibility_range_end = 100.0
		geometry.visibility_range_end_margin = 10.0
		geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for child in furnishing.get_children():
		if child is Node3D:
			_limit_interior_furnishing_range(child as Node3D)
