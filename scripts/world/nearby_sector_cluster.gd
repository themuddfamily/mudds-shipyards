class_name NearbySectorCluster
extends Node3D

## The one hand-authored destination cluster outside the shipyard envelope.
##
## Flying out of the launch corridor used to give the player the target range and
## then nothing: an empty volume with a decorative backdrop painted 900 m away on
## a shell nobody can reach. This component is the answer to "where do I go", and
## it is deliberately *small*. Four route beacons, one ringed moonlet, one debris
## field, one open dock gate and one derelict extraction platform, every one of
## them placed by hand at a written coordinate. There is no generator here and
## there is no galaxy: the
## roadmap's second Phase 8 item is a constraint on this file, and the way it is
## honoured is that every destination in the cluster is a named constant you can
## read in one screen.
##
## **Distance is a design number, not an accident.** The Torrent cruises at
## 82 m/s and boosts to 118 m/s, and it accelerates at 34 m/s². The platform sits
## 706 m from the station origin, which is about nine seconds outbound at cruise
## and six on boost — long enough that leaving is a decision, short enough that
## coming back is not a chore. The four beacons are spaced 100-130 m apart along
## the way so the trip has a rhythm and the pilot is never between landmarks for
## more than two seconds. Nothing in the cluster reaches past 900 m; the
## presentation-only backdrop star shell still begins at 1450 m, unreachable,
## doing the job it already did.
##
## **This component owns no gameplay authority.** It grants nothing, scores
## nothing, leases nothing and damages nothing. Its structural bodies sit on the
## World collision layer exactly as the station's own geometry does, so the
## existing hull-impact path in `HeroShip` treats a boulder like a bulkhead and no
## second damage route exists. It deliberately adds no range targets either: the
## guided mission counts `ShipyardWorld.get_target_count()`, so a decorative drone
## out here would silently rewrite the objective.
##
## Everything here is `modern_interpretation`. No source authenticates Cinder
## Reach, the platform, the moonlet or the route; the research ledger constrains
## the station and the fleet and says nothing about this sector.

enum DetailQuality {
	LOW,
	MEDIUM,
	HIGH,
}

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"nearby-sector-cluster"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const WORLD_LAYER := PhysicsLayers.WORLD
const CARGO_ACCESS_SCENE := preload("res://scenes/world/components/cinder_cargo_access.tscn")
const CARGO_DESTINATION_TERMINAL_SCENE := preload("res://scenes/world/modules/cargo_destination_terminal.tscn")

const CONTENT_NOTE := (
	"Cinder Reach, its extraction platform, the route beacon chain and the ringed "
	+ "moonlet are original modern remake design. No surviving source names, depicts "
	+ "or authenticates any destination outside the shipyard, and nothing here should "
	+ "be read as recovered historical content."
)

## Travel envelope, published so a test can hold the cluster to the bounds this
## file argues for rather than trusting the prose.
const CRUISE_SPEED := 82.0
const BOOST_SPEED := 118.0
const MINIMUM_ANCHOR_DISTANCE := 200.0
const MAXIMUM_ANCHOR_DISTANCE := 760.0
## Outermost reach of anything this component builds, including the debris field
## around the platform. The backdrop star shell starts at 1450 m, so the cluster
## and the painted sky never share a depth.
const MAXIMUM_CONTENT_DISTANCE := 940.0
## Everything must start beyond the target range's last drone (z = -165) so the
## cluster cannot crowd the range or the approach behind it.
const TARGET_RANGE_CLEARANCE_Z := -200.0

## Station-relative placement. The component root is mounted at the shipyard
## origin with an identity transform, so every constant below is also a world
## coordinate and can be read straight off against the station, the launch gate at
## (0, 8, -64) and the target range that ends near z = -165.
const PLATFORM_ANCHOR := Vector3(60.0, -70.0, -700.0)
const MOONLET_ANCHOR := Vector3(-260.0, 40.0, -560.0)
const MOONLET_RADIUS := 90.0

## Four beacons, bowed starboard and down and then back to port so the chain is
## read in perspective rather than as one point, and so the last leg leaves the
## platform's approach lane empty. Each carries an amber outbound lamp and a cyan
## homebound lamp on opposite faces: flying out you see amber, turning for home
## you see cyan. That is the whole return-route cue and it needs no HUD.
const ROUTE_BEACON_SPECS: Array[Dictionary] = [
	{"name": "RouteBeaconAlpha", "position": Vector3(16.0, -9.0, -240.0), "index": 1},
	{"name": "RouteBeaconBravo", "position": Vector3(32.0, -26.0, -372.0), "index": 2},
	{"name": "RouteBeaconCharlie", "position": Vector3(46.0, -44.0, -498.0), "index": 3},
	{"name": "RouteBeaconDelta", "position": Vector3(30.0, -46.0, -600.0), "index": 4},
]
const RACE_ACTIVITY_ID: StringName = &"cinder_reach_checkpoint_route"
const RACE_CHECKPOINT_COUNT := 5
const RACE_GATE_RING_CENTER := Vector3(0.0, 12.0, 0.0)
const RACE_GATE_CLEARED_SCALE := Vector3.ONE * 0.72
const RACE_GATE_PENDING_SCALE := Vector3.ONE * 0.84
const RACE_GATE_NEXT_SCALE := Vector3.ONE * 1.28
const RACE_GATE_MISSED_SIGNAL_SCALE := Vector3.ONE * 1.52
const RACE_GATE_MISSED_TRIM_SCALE := Vector3.ONE * 0.64
const RACE_GATE_COMPLETE_SCALE := Vector3.ONE * 1.22
const RACE_GATE_MISSED_SIGNAL_POSITION := Vector3(0.0, 15.0, 0.0)
const RACE_GATE_MISSED_TRIM_POSITION := Vector3(0.0, 9.0, 0.0)
const RACE_GATE_COMPLETE_SIGNAL_POSITION := Vector3(0.0, 13.5, 0.0)
const RACE_GATE_COMPLETE_TRIM_POSITION := Vector3(0.0, 10.5, 0.0)
const RACE_GATE_AUTHORED_ROTATION_DEGREES := Vector3(90.0, 0.0, 0.0)
const RACE_GATE_TIMEOUT_SIGNAL_SCALE := Vector3(1.34, 0.28, 1.34)
const RACE_GATE_TIMEOUT_TRIM_SCALE := Vector3(0.66, 1.42, 0.66)
const RACE_GATE_FAILED_SIGNAL_SCALE := Vector3(1.36, 0.42, 0.74)
const RACE_GATE_FAILED_TRIM_SCALE := Vector3(0.74, 0.42, 1.36)
const RACE_GATE_ABORTED_SIGNAL_POSITION := Vector3(-2.8, 14.0, 0.0)
const RACE_GATE_ABORTED_TRIM_POSITION := Vector3(2.8, 10.0, 0.0)
const RACE_GATE_ABORTED_SIGNAL_ROTATION_DEGREES := Vector3(90.0, 0.0, -24.0)
const RACE_GATE_ABORTED_TRIM_ROTATION_DEGREES := Vector3(90.0, 0.0, 24.0)

## Debris field: an ellipsoid flattened in Y so it reads as a drift rather than a
## ball, centred on the platform.
const FIELD_RADII := Vector3(180.0, 58.0, 180.0)
const FIELD_SEED := 8140719
const BOULDER_COUNT := 16
const BOULDER_MINIMUM_EXTENT := 20.0
const BOULDER_MAXIMUM_EXTENT := 46.0
const BOULDER_MINIMUM_SEPARATION := 56.0
const DEBRIS_CHIP_COUNT := 520
const DEBRIS_CHIP_SEED := 5512803
## Kept clear so the platform is approachable and the dock gate is not blocked by
## a rock the pilot cannot see until it fills the canopy. It applies to the fine
## debris shell as well as the boulders — the first rendered pass filtered only
## the boulders, and 720 unfiltered chips packed the gate aperture solid and hid
## the platform completely from 170 m out.
const PLATFORM_KEEP_CLEAR_RADIUS := 105.0
const APPROACH_CORRIDOR_RADIUS := 30.0
const APPROACH_CORRIDOR_LENGTH := 200.0
const BEACON_KEEP_CLEAR_RADIUS := 70.0

## The ordered Alpha -> Delta activity is presented as one flyable polyline,
## not four unrelated lights. Fine debris is still one MultiMesh submission but
## is distributed into eight authored flank clusters outside this frozen tube.
const BEACON_TRAVERSAL_ACTIVITY_ID: StringName = &"cinder_debris_beacon_traversal"
const BEACON_TRAVERSAL_CORRIDOR_RADIUS := 42.0
const DEBRIS_CHIP_CLEARANCE_MARGIN := 3.0
const TRAVERSAL_DEBRIS_CLUSTER_SPECS: Array[Dictionary] = [
	{"center": Vector3(-54.0, 2.0, -245.0), "radii": Vector3(26.0, 14.0, 30.0)},
	{"center": Vector3(86.0, -22.0, -245.0), "radii": Vector3(26.0, 14.0, 30.0)},
	{"center": Vector3(-46.0, -3.0, -306.0), "radii": Vector3(26.0, 14.0, 34.0)},
	{"center": Vector3(94.0, -32.0, -306.0), "radii": Vector3(26.0, 14.0, 34.0)},
	{"center": Vector3(-31.0, -20.0, -435.0), "radii": Vector3(26.0, 14.0, 36.0)},
	{"center": Vector3(109.0, -50.0, -435.0), "radii": Vector3(26.0, 14.0, 36.0)},
	{"center": Vector3(-32.0, -30.0, -558.0), "radii": Vector3(26.0, 14.0, 34.0)},
	{"center": Vector3(108.0, -61.0, -558.0), "radii": Vector3(26.0, 14.0, 34.0)},
]
const TRAVERSAL_DEBRIS_PRESENTATION_BOUNDS := AABB(
	Vector3(-84.0, -82.0, -596.0), Vector3(224.0, 102.0, 385.0)
)
const TRAVERSAL_BEACON_MESH_BUDGET := 44
const TRAVERSAL_BEACON_LIGHT_BUDGET := 12
const TRAVERSAL_BEACON_DESCENDANT_BUDGET := 60
const TRAVERSAL_DEBRIS_BATCH_BUDGET := 1
const BEACON_TRAVERSAL_STATE_NODE_DELTA := 0
const BEACON_TRAVERSAL_STATE_LIGHT_DELTA := 0
const BEACON_TRAVERSAL_STATE_SUBMISSION_DELTA := 0
const TRAVERSAL_VANE_BASE_POSITION := Vector3(0.0, -11.0, 0.0)
const TRAVERSAL_CLEARED_COUNTER_SCALE := Vector3(0.72, 0.45, 0.72)
const TRAVERSAL_CLEARED_SPAR_SCALE := Vector3(0.7, 0.7, 0.7)
const TRAVERSAL_PENDING_SCALE := Vector3.ONE * 0.65
const TRAVERSAL_TARGET_COUNTER_SCALE := Vector3(1.5, 0.35, 1.5)
const TRAVERSAL_TARGET_SPAR_SCALE := Vector3(0.45, 2.0, 0.45)
const TRAVERSAL_WRONG_COUNTER_SCALE := Vector3(1.8, 0.3, 0.55)
const TRAVERSAL_WRONG_SPAR_SCALE := Vector3(0.55, 1.8, 0.55)
const TRAVERSAL_COMPLETE_SCALE := Vector3(1.6, 0.28, 1.6)
const PATROL_SIGN_BASE_POSITION := Vector3(0.0, 5.4, 0.0)
const PATROL_SIGN_CLEARED_SCALE := Vector3(0.55, 0.5, 1.0)
const PATROL_SIGN_PENDING_SCALE := Vector3(0.75, 0.6, 1.0)
const PATROL_SIGN_TARGET_SCALE := Vector3(1.2, 0.55, 1.0)
const PATROL_SIGN_INTERRUPTED_SCALE := Vector3(1.4, 0.35, 1.0)
const PATROL_SIGN_COMPLETE_SCALE := Vector3(1.1, 1.1, 3.0)

## Rocks take a much heavier chamfer than station stock. The kit's box rule caps
## at 0.18 m, which on a 30 m boulder is invisible, so the chamfer is proportional
## here instead. 0.13 is where the rendered evidence put it: at 0.30 the inset
## shell rounds so far that a boulder reads as a pale pillow with no facets at
## all, and a field of them looked like spilled packing foam. At 0.13 the block
## keeps its faces and the chamfer is a lit edge between them. Well under the
## builder's own 0.45 safety limit either way, so the shell cannot invert.
const ROCK_BEVEL_PROPORTION := 0.13
const ROCK_LOBES_PER_BOULDER := 3

## Platform envelope, local to `PLATFORM_ANCHOR`. The dock gate is the reason to
## actually arrive: two open frames 18 m apart with a 28 x 23 m clear aperture,
## standing free on the approach lane 77-95 m off the platform and squared to it,
## so the run ends by threading a structure instead of stopping beside one.
##
## It is deliberately *detached* from the platform rather than bolted to the end
## of the processing spine. A tunnel that dead-ends into a hull is not a
## flythrough, it is a wall with a frame around it, and the pilot only finds that
## out at 82 m/s. Standing the gate off on the lane leaves 60 m of clear space on
## the far side to pull up, bank, or run straight past.
const GANTRY_CLEAR_WIDTH := 28.0
const GANTRY_CLEAR_HEIGHT := 23.0
const GANTRY_BEAM := 3.0
const GANTRY_NEAR_Z := 95.0
const GANTRY_FAR_Z := 77.0
const GANTRY_CENTER_Y := 4.0
const SPINE_SIZE := Vector3(9.0, 7.0, 44.0)
const SPINE_CENTER_Z := -6.0
const PROCESSING_SPINE_RIB_SIZE := Vector3(13.0, 9.5, 1.6)
const PROCESSING_SPINE_RIB_Z_POSITIONS: Array[float] = [-24.0, -14.0, 0.0, 12.0]
const PROCESSING_SPINE_RIB_FAMILY_ID: StringName = &"nearby-processing-spine-ribs"
const EXTRACTION_ARM_COLLAR_SIZE := Vector3(6.0, 1.4, 6.0)
const EXTRACTION_ARM_COLLAR_Y_POSITIONS: Array[float] = [-6.0, -17.0, -28.0]
const EXTRACTION_ARM_COLLAR_FAMILY_ID: StringName = &"cinder-extraction-arm-collars"
const GANTRY_RAIL_SIZE := Vector3(1.2, 1.2, GANTRY_NEAR_Z - GANTRY_FAR_Z)
const GANTRY_RAIL_FAMILY_ID: StringName = &"nearby-gantry-rails"
const LAMP_LENS_RADIUS := 0.45
const LAMP_LENS_HEIGHT := 0.9
const LAMP_LENS_RADIAL_SEGMENTS := 12
const LAMP_LENS_RINGS := 6
const LAMP_LENS_COPY_COUNT := 26
const TORUS_RINGS := 40
const TORUS_RING_SEGMENTS := 14
const TORUS_COPY_COUNT := 19
const TORUS_MESH_RESOURCE_ALLOCATIONS := 12

## Activity-specific silhouette behind the existing dock gate. The fixed mining
## approach anchor remains the gate centre; this bounded, collision-free stock
## gives that activity a headframe/hopper read without duplicating authority.
const MINING_ACTIVITY_ID: StringName = &"cinder_platform_mining_run"
const MINING_APPROACH_LOCAL := Vector3(0.0, GANTRY_CENTER_Y, GANTRY_NEAR_Z)
const MINING_PRESENTATION_LOCAL_BOUNDS := AABB(
	Vector3(-17.0, -1.0, -13.0), Vector3(34.0, 36.0, 34.0)
)
const MINING_PRESENTATION_MESH_BUDGET := 6
const MINING_PRESENTATION_MULTIMESH_BUDGET := 5
const MINING_PRESENTATION_RENDERER_BUDGET := 11
const MINING_PRESENTATION_VISIBLE_COPY_BUDGET := 18
const MINING_PRESENTATION_SUBMISSION_BUDGET := 11
const MINING_PRESENTATION_MESH_RESOURCE_BUDGET := 10
const MINING_PRESENTATION_LIGHT_BUDGET := 2
const MINING_PRESENTATION_DESCENDANT_BUDGET := 14
const MINING_PRESENTATION_STATE_NODE_DELTA := 0
const MINING_PRESENTATION_STATE_LIGHT_DELTA := 0
const MINING_PRESENTATION_STATE_SUBMISSION_DELTA := 0
const MINING_PRESENTATION_PREBATCH_RENDERERS := 18
const MINING_PRESENTATION_PREBATCH_SUBMISSIONS := 18
const MINING_PRESENTATION_PREBATCH_DESCENDANTS := 21
const MINING_COLLECTOR_COUNT := 3
const MINING_COLLECTOR_BAND_IDLE_Y := 4.0
const MINING_COLLECTOR_BAND_FULL_Y := 7.0
const MINING_CAPACITY_HOPPER_SCALE := Vector3(1.2, 1.0, 1.2)
const MINING_FAILED_HOPPER_SCALE := Vector3(0.65, 1.35, 0.65)
const MINING_FAILED_BAND_TURNS := [-38.0, 38.0, -38.0]

## The scan begins twenty metres in front of the platform centre. A fractured
## datum frame gathers the existing torn habitat and collapsed solar wing into
## one readable derelict silhouette without becoming a scan target or trigger.
const STRUCTURE_SCAN_ACTIVITY_ID: StringName = &"cinder_derelict_structure_scan"
const STRUCTURE_SCAN_APPROACH_LOCAL := Vector3(0.0, GANTRY_CENTER_Y, 20.0)
const STRUCTURE_SCAN_PRESENTATION_LOCAL_BOUNDS := AABB(
	Vector3(-30.0, -4.0, -24.0), Vector3(64.0, 38.0, 40.0)
)
const STRUCTURE_SCAN_PRESENTATION_MESH_BUDGET := 15
const STRUCTURE_SCAN_PRESENTATION_LIGHT_BUDGET := 2
const STRUCTURE_SCAN_PRESENTATION_DESCENDANT_BUDGET := 18
const STRUCTURE_SCAN_PRESENTATION_STATE_NODE_DELTA := 0
const STRUCTURE_SCAN_PRESENTATION_STATE_LIGHT_DELTA := 0
const STRUCTURE_SCAN_PRESENTATION_STATE_SUBMISSION_DELTA := 0
const STRUCTURE_SCAN_RECEIVER_IDLE_ROTATION := Vector3(90.0, 0.0, 0.0)
const STRUCTURE_SCAN_RECEIVER_RESOLVED_ROTATION := Vector3.ZERO
const STRUCTURE_SCAN_COLLAR_IDLE_POSITION := Vector3(20.0, 15.0, 5.0)
const STRUCTURE_SCAN_COLLAR_RESOLVED_POSITION := Vector3(20.0, 15.0, 8.0)
const STRUCTURE_SCAN_COMPLETE_RECEIVER_SCALE := Vector3.ONE * 1.2
const STRUCTURE_SCAN_COMPLETE_COLLAR_SCALE := Vector3.ONE * 1.35
const STRUCTURE_SCAN_FAILED_RECEIVER_ROTATION := Vector3(32.0, -48.0, 72.0)
const STRUCTURE_SCAN_FAILED_RECEIVER_SCALE := Vector3(1.3, 0.28, 0.75)
const STRUCTURE_SCAN_FAILED_COLLAR_POSITION := Vector3(23.5, 12.0, 4.0)
const STRUCTURE_SCAN_FAILED_COLLAR_ROTATION := Vector3(-25.0, 55.0, -42.0)
const STRUCTURE_SCAN_FAILED_COLLAR_SCALE := Vector3(0.55, 1.45, 0.3)

const PERFORMANCE_BUDGET := {
	# Includes the production cargo access route (21 bodies/19 meshes/three
	# batches) and the real destination terminal (two bodies/four meshes).
	"static_bodies": 61,
	"mesh_instances": 203,
	# Bounded visual batches retain the debris shell, processing-spine ribs,
	# gantry rails, and streamed aperture lenses without increasing gameplay or
	# collision ownership.
	"multimesh_instances": 14,
	"omni_lights": 26,
	"spot_lights": 1,
	"shadow_casting_lights": 0,
	"audio_nodes": 0,
	"particle_emitters": 0,
	"animation_players": 0,
}

const ROCK_BASALT := Color("3c4249")
const ROCK_RUST := Color("55402f")
const ROCK_PALE := Color("5a636a")
const HULL_OCHRE := Color("7d5c34")
const HULL_SHADOW := Color("2a2f36")
const HULL_CHAR := Color("14171b")
const STEEL_BLUE := Color("1c566e")
const KETH_CYAN := Color("48dbe2")
const KETH_ORANGE := Color("ff9f43")
const MOONLET_TEAL := Color("3f8f7a")
const MOONLET_RING := Color("8b7f63")
const MOONLET_CRATER_COUNT := 6

@export_category("Presentation")
@export var starts_enabled := true
@export_enum("Low", "Medium", "High") var initial_quality: int = DetailQuality.HIGH

@onready var _route_root: Node3D = get_node(^"RouteBeacons") as Node3D
@onready var _field_root: Node3D = get_node(^"DebrisField") as Node3D
@onready var _platform_root: Node3D = get_node(^"ExtractionPlatform") as Node3D
@onready var _landmark_root: Node3D = get_node(^"Landmarks") as Node3D
@onready var _activity_binding: Node3D = get_node(^"ActivityBinding") as Node3D

var _materials: Dictionary = {}
var _lens_materials: Dictionary = {}
var _lamp_lens_mesh: SphereMesh
var _lamp_lenses: Array[MeshInstance3D] = []
var _box_cache: Dictionary = {}
var _rock_mesh_cache: Dictionary = {}
var _cylinder_cache: Dictionary = {}
var _torus_mesh_cache: Dictionary = {}
var _spin_bodies: Array[Node3D] = []
var _pulse_lamps: Array[OmniLight3D] = []
var _boulder_offsets: Array[Vector3] = []
var _hazard_head: Node3D
var _moonlet: Node3D
var _built := false
var _cluster_enabled := true
var _quality_level: int = DetailQuality.HIGH
var _elapsed := 0.0
var _audit_report: Dictionary = {}
var _streaming_transition: CinderStreamingTransitionPresentation
var _cargo_access: CinderCargoAccess
var _cargo_destination_terminal: CargoTransferTerminal
var _mining_presentation_snapshot: Dictionary = {}
var _structure_scan_presentation_snapshot: Dictionary = {}
var _beacon_traversal_presentation_snapshot: Dictionary = {}
var _race_gate_presentation_snapshot: Dictionary = {}
var _patrol_marker_presentation_snapshot: Dictionary = {}


func _enter_tree() -> void:
	# A whole-`Main` detach and re-add must restore the animation lifecycle. The
	# geometry survives the round trip untouched; only processing has to come
	# back, and it comes back through the same setter the inspector uses so there
	# is one path rather than two.
	if _built:
		call_deferred("_restore_cluster_enabled_after_reentry")


func _exit_tree() -> void:
	if not _built or not is_instance_valid(_activity_binding):
		return
	_activity_binding.call(
		"unbind_race_presentation",
		Callable(self, "_apply_race_gate_presentation")
	)
	_activity_binding.call(
		"unbind_patrol_presentation",
		Callable(self, "_apply_patrol_marker_presentation")
	)
	_activity_binding.call(
		"unbind_mining_presentation",
		Callable(self, "_apply_mining_activity_presentation")
	)
	_activity_binding.call(
		"unbind_structure_scan_presentation",
		Callable(self, "_apply_structure_scan_activity_presentation")
	)
	_activity_binding.call(
		"unbind_beacon_traversal_presentation",
		Callable(self, "_apply_beacon_traversal_activity_presentation")
	)


## A deferred re-entry callback must use the state retained at execution time:
## callers may synchronously change the presentation profile after mounting the
## component and before idle. A callback that captured the old boolean would
## overwrite that newer request. It also becomes inert if the component leaves
## the tree again before idle.
func _restore_cluster_enabled_after_reentry() -> void:
	if not _built or is_queued_for_deletion() or not is_inside_tree():
		return
	if is_instance_valid(_cargo_access) and is_instance_valid(_cargo_destination_terminal):
		_activity_binding.call(
			"bind_cargo_access",
			_cargo_access,
			_cargo_destination_terminal,
			_cargo_access.get_attachment_generation()
		)
	_activity_binding.call(
		"bind_race_presentation",
		Callable(self, "_apply_race_gate_presentation")
	)
	_activity_binding.call(
		"bind_patrol_presentation",
		Callable(self, "_apply_patrol_marker_presentation")
	)
	_activity_binding.call(
		"bind_mining_presentation",
		Callable(self, "_apply_mining_activity_presentation")
	)
	_activity_binding.call(
		"bind_structure_scan_presentation",
		Callable(self, "_apply_structure_scan_activity_presentation")
	)
	_activity_binding.call(
		"bind_beacon_traversal_presentation",
		Callable(self, "_apply_beacon_traversal_activity_presentation")
	)
	set_cluster_enabled(_cluster_enabled)


func _ready() -> void:
	if _built:
		set_cluster_enabled(_cluster_enabled)
		return
	_built = true
	_quality_level = clampi(initial_quality, DetailQuality.LOW, DetailQuality.HIGH)
	_create_materials()
	_build_route_beacons()
	_activity_binding.call(
		"bind_beacon_traversal_presentation",
		Callable(self, "_apply_beacon_traversal_activity_presentation")
	)
	_activity_binding.call(
		"bind_race_presentation",
		Callable(self, "_apply_race_gate_presentation")
	)
	_activity_binding.call(
		"bind_patrol_presentation",
		Callable(self, "_apply_patrol_marker_presentation")
	)
	_build_landmarks()
	_build_debris_field()
	_build_extraction_platform()
	_audit_report = _compose_audit_report()
	set_cluster_enabled(starts_enabled)
	_arm_streaming_transition()


func _process(delta: float) -> void:
	# Accumulated frame delta only. Nothing here reads a wall clock, so two runs
	# stepped with the same deltas produce the same transforms.
	_elapsed += delta
	for body in _spin_bodies:
		if not is_instance_valid(body):
			continue
		var axis := body.get_meta(&"spin_axis", Vector3.UP) as Vector3
		var rate := float(body.get_meta(&"spin_rate", 0.0))
		var rest := body.get_meta(&"rest_basis", Basis.IDENTITY) as Basis
		body.basis = Basis(axis, deg_to_rad(rate) * _elapsed) * rest
	for lamp in _pulse_lamps:
		if not is_instance_valid(lamp):
			continue
		var phase := float(lamp.get_meta(&"pulse_phase", 0.0))
		var base := float(lamp.get_meta(&"base_energy", 1.0))
		var raw_energy := base * (
			0.62 + 0.38 * (0.5 + 0.5 * sin(_elapsed * 1.9 + phase))
		)
		lamp.light_energy = (
			_streaming_transition.scale_dynamic_light_energy(raw_energy)
			if _streaming_transition != null
			else raw_energy
		)
	if is_instance_valid(_hazard_head):
		_hazard_head.rotation.y = _elapsed * 0.9
	if is_instance_valid(_moonlet):
		_moonlet.rotation.y = _elapsed * 0.012


## Suspends every animated element and hides the cluster without destroying it,
## so a paused or low-profile world pays nothing per frame and the exact same
## geometry comes back on re-enable.
func set_cluster_enabled(enabled: bool) -> void:
	if not _is_current():
		return
	_cluster_enabled = enabled
	var presentation_opacity := float(
		get_streaming_transition_snapshot().get("opacity", 1.0)
	)
	visible = enabled and presentation_opacity > 0.0
	set_process(enabled and _built)
	set_physics_process(false)


func is_cluster_enabled() -> bool:
	return _cluster_enabled


## Drops the fine debris shell on the lowest profile. The structures, the
## boulders and every collision shape are identical at all three settings: the
## flyable shape of the sector must not depend on a graphics option.
func set_detail_quality(quality: int) -> void:
	if not _is_current():
		return
	_quality_level = clampi(quality, DetailQuality.LOW, DetailQuality.HIGH)
	if _field_root == null:
		return
	var chips := _field_root.get_node_or_null(^"DebrisChips") as MultiMeshInstance3D
	if chips != null:
		chips.visible = _quality_level >= DetailQuality.MEDIUM


func get_detail_quality() -> int:
	return _quality_level


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


## Production streaming facade. Direct component fixtures have no coordinator
## metadata, remain fully authored, and reject advancement.
func advance_streaming_transition(
	delta: Variant, distance_meters: Variant, expected_generation: Variant
	) -> Dictionary:
	if _streaming_transition == null:
		return {
			"accepted": false,
			"reason": &"not_streamed",
			"generation": -1,
			"opacity": 1.0,
			"phase": &"standalone",
			"retire_ready": false,
		}
	return _streaming_transition.advance_physics(
		delta, distance_meters, expected_generation
	)


func get_streaming_transition_snapshot() -> Dictionary:
	if _streaming_transition == null:
		return {
			"schema_version": CinderStreamingTransitionPresentation.SCHEMA_VERSION,
			"bound": false,
			"generation": -1,
			"opacity": 1.0,
			"phase": &"standalone",
			"retire_ready": false,
			"root_visible": visible,
		}.duplicate(true)
	return _streaming_transition.get_snapshot()


func get_streaming_transition_audit() -> Dictionary:
	if _streaming_transition == null:
		return {
			"valid": true,
			"standalone": true,
			"automatic_processing": false,
			"streaming_authority": false,
			"gameplay_authority": false,
		}.duplicate(true)
	return _streaming_transition.audit()


func _arm_streaming_transition() -> void:
	var location_id := get_meta(&"world_location_id", &"") as StringName
	var generation := int(get_meta(&"world_location_generation", -1))
	if location_id != CinderStreamingTransitionPresentation.LOCATION_ID \
		or generation <= 0:
		return
	_streaming_transition = CinderStreamingTransitionPresentation.new()
	var bound := _streaming_transition.bind_streamed_content(self, generation)
	if not bool(bound.get("accepted", false)):
		# A streamed generation whose renderer roster cannot be safely controlled
		# fails visually closed. Collision and coordinator ownership remain intact.
		visible = false


## Straight-line distance from the station origin to the platform, in metres.
func get_platform_distance() -> float:
	return PLATFORM_ANCHOR.length()


func get_cinder_cargo_access() -> CinderCargoAccess:
	return _cargo_access if is_instance_valid(_cargo_access) else null


func get_cinder_cargo_destination_terminal() -> CargoTransferTerminal:
	return _cargo_destination_terminal if is_instance_valid(_cargo_destination_terminal) else null


## Seconds at the Torrent's steady cruise speed, ignoring spin-up. Reported so
## the travel envelope is a measured number in the audit, not a comment.
func get_cruise_travel_seconds() -> float:
	return get_platform_distance() / CRUISE_SPEED


## World-space point on the platform's approach lane, `distance` metres out from
## the platform along +Z. The boulder scatter is forbidden anywhere inside this
## lane, so any point this returns within `APPROACH_CORRIDOR_LENGTH` is flyable.
func get_approach_lane_point(distance: float) -> Vector3:
	return PLATFORM_ANCHOR + Vector3(0.0, GANTRY_CENTER_Y, distance)


## Centre of the dock gate's outer aperture — the point the pilot lines up on.
func get_dock_gate_center() -> Vector3:
	return get_approach_lane_point(GANTRY_NEAR_Z)


func get_route_beacon_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for spec in ROUTE_BEACON_SPECS:
		positions.append(spec["position"] as Vector3)
	return positions


## Maps only authority-produced race order and rejection state onto the retained
## route rings. The fifth checkpoint remains the existing platform return; this
## presenter neither creates a gate nor decides whether a ship passed one.
func _apply_race_gate_presentation(snapshot: Dictionary) -> Dictionary:
	if StringName(snapshot.get("activity_id", &"")) != RACE_ACTIVITY_ID:
		return {"accepted": false, "reason": &"wrong_activity_snapshot"}
	var generation := int(snapshot.get("session_generation", -1))
	var state_id := StringName(snapshot.get("state_id", &""))
	var next_checkpoint := int(snapshot.get("next_checkpoint_index", -1))
	var checkpoint_count := int(snapshot.get("checkpoint_count", -1))
	if generation < 0 or state_id not in [
		&"idle", &"countdown", &"active", &"completed", &"failed", &"aborted"
	] or next_checkpoint < 0 or next_checkpoint > checkpoint_count \
			or checkpoint_count != RACE_CHECKPOINT_COUNT:
		return {"accepted": false, "reason": &"invalid_activity_snapshot"}
	var route_root := get_node_or_null(^"RouteBeacons") as Node3D
	if route_root == null:
		return {"accepted": false, "reason": &"presentation_unavailable"}
	var reset := state_id == &"idle" and int(snapshot.get("reset_serial", 0)) > 0
	var missed_gate := state_id == &"active" and (
		StringName(snapshot.get("presentation_reason", &"")) == &"outside_checkpoint"
		or StringName(snapshot.get("checkpoint_id", &"")) == &"race_missed_gate"
	)
	var failure_reason := StringName(snapshot.get("failure_reason", &""))
	var terminal_state: StringName = &""
	if state_id in [&"failed", &"aborted"]:
		if state_id == &"aborted" or failure_reason in [
			&"abort", &"aborted", &"caller_abort", &"activity_aborted"
		]:
			terminal_state = &"aborted"
		elif failure_reason == &"timeout":
			terminal_state = &"timed_out"
		else:
			terminal_state = &"failed"
	var gate_states: Array[Dictionary] = []
	for gate_index in ROUTE_BEACON_SPECS.size():
		var gate := route_root.get_node_or_null(
			NodePath(String(ROUTE_BEACON_SPECS[gate_index]["name"]))
		) as Node3D
		if gate == null:
			return {"accepted": false, "reason": &"presentation_roster_incomplete"}
		var signal_ring := gate.get_node_or_null(^"SignalRing") as MeshInstance3D
		var trim_ring := gate.get_node_or_null(^"TrimRing") as MeshInstance3D
		if signal_ring == null or trim_ring == null:
			return {"accepted": false, "reason": &"presentation_roster_incomplete"}
		var status_id: StringName = &"available"
		var signal_scale := Vector3.ONE
		var trim_scale := Vector3.ONE
		var signal_position := RACE_GATE_RING_CENTER
		var trim_position := RACE_GATE_RING_CENTER
		var signal_rotation_degrees := RACE_GATE_AUTHORED_ROTATION_DEGREES
		var trim_rotation_degrees := RACE_GATE_AUTHORED_ROTATION_DEGREES
		if reset:
			status_id = &"reset"
		elif state_id == &"countdown":
			status_id = &"next_gate" if gate_index == 0 else &"pending"
			signal_scale = RACE_GATE_NEXT_SCALE \
				if gate_index == 0 else RACE_GATE_PENDING_SCALE
			trim_scale = RACE_GATE_PENDING_SCALE
		elif state_id == &"active":
			if gate_index < next_checkpoint:
				status_id = &"cleared"
				signal_scale = RACE_GATE_CLEARED_SCALE
				trim_scale = RACE_GATE_CLEARED_SCALE
			elif gate_index == next_checkpoint:
				if missed_gate:
					status_id = &"missed_expected_gate"
					signal_scale = RACE_GATE_MISSED_SIGNAL_SCALE
					trim_scale = RACE_GATE_MISSED_TRIM_SCALE
					signal_position = RACE_GATE_MISSED_SIGNAL_POSITION
					trim_position = RACE_GATE_MISSED_TRIM_POSITION
				else:
					status_id = &"next_gate"
					signal_scale = RACE_GATE_NEXT_SCALE
			else:
				status_id = &"pending"
				signal_scale = RACE_GATE_PENDING_SCALE
				trim_scale = RACE_GATE_PENDING_SCALE
		elif state_id == &"completed":
			status_id = &"completed"
			signal_scale = RACE_GATE_COMPLETE_SCALE
			trim_scale = RACE_GATE_COMPLETE_SCALE
			signal_position = RACE_GATE_COMPLETE_SIGNAL_POSITION
			trim_position = RACE_GATE_COMPLETE_TRIM_POSITION
		elif terminal_state == &"timed_out":
			status_id = &"timed_out"
			signal_scale = RACE_GATE_TIMEOUT_SIGNAL_SCALE
			trim_scale = RACE_GATE_TIMEOUT_TRIM_SCALE
		elif terminal_state == &"aborted":
			status_id = &"aborted"
			signal_position = RACE_GATE_ABORTED_SIGNAL_POSITION
			trim_position = RACE_GATE_ABORTED_TRIM_POSITION
			signal_rotation_degrees = RACE_GATE_ABORTED_SIGNAL_ROTATION_DEGREES
			trim_rotation_degrees = RACE_GATE_ABORTED_TRIM_ROTATION_DEGREES
		elif terminal_state == &"failed":
			status_id = &"failed"
			signal_scale = RACE_GATE_FAILED_SIGNAL_SCALE
			trim_scale = RACE_GATE_FAILED_TRIM_SCALE
		signal_ring.scale = signal_scale
		signal_ring.position = signal_position
		signal_ring.rotation_degrees = signal_rotation_degrees
		trim_ring.scale = trim_scale
		trim_ring.position = trim_position
		trim_ring.rotation_degrees = trim_rotation_degrees
		gate_states.append({
			"index": gate_index,
			"status_id": status_id,
			"signal_scale": signal_scale,
			"trim_scale": trim_scale,
			"signal_position": signal_position,
			"trim_position": trim_position,
			"signal_rotation_degrees": signal_rotation_degrees,
			"trim_rotation_degrees": trim_rotation_degrees,
		})
	_race_gate_presentation_snapshot = {
		"activity_id": RACE_ACTIVITY_ID,
		"state_id": &"reset" if reset else state_id,
		"generation": generation,
		"next_checkpoint_index": next_checkpoint,
		"checkpoint_count": checkpoint_count,
		"best_time_seconds": float(snapshot.get("best_time_seconds", -1.0)),
		"best_result_persisted": bool(snapshot.get("best_result_persisted", false)),
		"best_reward_consumed": bool(snapshot.get("best_reward_consumed", false)),
		"missed_gate_recovery": missed_gate,
		"terminal_state": terminal_state,
		"failure_reason": failure_reason,
		"gates": gate_states,
		"node_delta": 0,
		"light_delta": 0,
		"collision_delta": 0,
		"checkpoint_authority": false,
		"gameplay_authority": false,
		"reward_authority": false,
	}.duplicate(true)
	return {"accepted": true, "reason": &"race_gate_presentation_applied"}


func get_race_gate_presentation_state() -> Dictionary:
	return _race_gate_presentation_snapshot.duplicate(true)


## Applies the patrol's detached order, dwell and interruption state only to the
## retained sign boards. Race rings and traversal vanes remain separate, while
## ActivityDirector and PatrolActivity retain every checkpoint and timing rule.
func _apply_patrol_marker_presentation(snapshot: Dictionary) -> Dictionary:
	if StringName(snapshot.get("activity_id", &"")) != RACE_ACTIVITY_ID:
		return {"accepted": false, "reason": &"wrong_activity_snapshot"}
	var generation := int(snapshot.get("generation", -1))
	var state_id := StringName(snapshot.get("state_id", &""))
	var phase_id := StringName(snapshot.get("phase_id", &""))
	var next_checkpoint := int(snapshot.get("next_checkpoint_index", -1))
	var checkpoint_count := int(snapshot.get("checkpoint_count", -1))
	if generation < 0 or state_id not in [
		&"idle", &"active", &"completed", &"failed", &"aborted",
	] or phase_id not in [&"idle", &"travel", &"dwell", &"complete", &"failed", &"aborted"] \
			or checkpoint_count != RACE_CHECKPOINT_COUNT \
			or next_checkpoint < 0 or next_checkpoint > checkpoint_count:
		return {"accepted": false, "reason": &"invalid_activity_snapshot"}
	var route_root := get_node_or_null(^"RouteBeacons") as Node3D
	if route_root == null:
		return {"accepted": false, "reason": &"presentation_unavailable"}
	var interruption := (
		StringName(snapshot.get("reason", &"")) == &"dwell_interrupted"
		or StringName(snapshot.get("presentation_reason", &"")) == &"dwell_interrupted"
	)
	var reset := state_id == &"idle" and StringName(snapshot.get("reason", &"")) == &"reset"
	var dwell_seconds := maxf(0.0, float(snapshot.get("dwell_seconds", 0.0)))
	var dwell_elapsed := clampf(
		float(snapshot.get("dwell_elapsed_seconds", 0.0)), 0.0, dwell_seconds
	)
	var dwell_fraction := dwell_elapsed / dwell_seconds if dwell_seconds > 0.0 else 0.0
	var marker_states: Array[Dictionary] = []
	for marker_index in ROUTE_BEACON_SPECS.size():
		var marker := route_root.get_node_or_null(
			NodePath(String(ROUTE_BEACON_SPECS[marker_index]["name"]))
		) as Node3D
		var sign_board := marker.get_node_or_null(^"SignBoard") as MeshInstance3D \
			if marker != null else null
		if sign_board == null:
			return {"accepted": false, "reason": &"presentation_roster_incomplete"}
		var status_id: StringName = &"available"
		var board_scale := Vector3.ONE
		var board_position := PATROL_SIGN_BASE_POSITION
		var board_rotation := Vector3.ZERO
		if reset:
			status_id = &"reset"
		elif state_id == &"active":
			if next_checkpoint >= ROUTE_BEACON_SPECS.size():
				status_id = &"platform_return" if marker_index == ROUTE_BEACON_SPECS.size() - 1 \
					else &"cleared"
				board_scale = PATROL_SIGN_TARGET_SCALE \
					if status_id == &"platform_return" else PATROL_SIGN_CLEARED_SCALE
				if status_id == &"platform_return":
					board_position = Vector3(0.0, 8.0, 0.0)
			elif marker_index < next_checkpoint:
				status_id = &"cleared"
				board_scale = PATROL_SIGN_CLEARED_SCALE
			elif marker_index == next_checkpoint:
				if interruption:
					status_id = &"hold_interrupted"
					board_scale = PATROL_SIGN_INTERRUPTED_SCALE
					board_position = Vector3(0.0, 8.0, 0.0)
					board_rotation = Vector3(0.0, 0.0, 45.0)
				elif phase_id == &"dwell":
					status_id = &"holding"
					board_scale = Vector3(1.2, lerpf(0.55, 1.5, dwell_fraction), 1.0)
				else:
					status_id = &"next_hold"
					board_scale = PATROL_SIGN_TARGET_SCALE
			else:
				status_id = &"pending"
				board_scale = PATROL_SIGN_PENDING_SCALE
		elif state_id == &"completed":
			status_id = &"completed"
			board_scale = PATROL_SIGN_COMPLETE_SCALE
		elif state_id in [&"failed", &"aborted"]:
			status_id = &"route_risk"
			board_scale = PATROL_SIGN_INTERRUPTED_SCALE
			board_position = Vector3(0.0, 8.0, 0.0)
			board_rotation = Vector3(0.0, 0.0, -35.0 if marker_index % 2 == 0 else 35.0)
		sign_board.scale = board_scale
		sign_board.position = board_position
		sign_board.rotation_degrees = board_rotation
		marker_states.append({
			"index": marker_index,
			"status_id": status_id,
			"board_scale": board_scale,
			"board_position": board_position,
			"board_rotation_degrees": board_rotation,
		})
	var expected_marker_name: StringName = &""
	if next_checkpoint < ROUTE_BEACON_SPECS.size():
		expected_marker_name = StringName(ROUTE_BEACON_SPECS[next_checkpoint]["name"])
	elif state_id == &"active" and next_checkpoint == ROUTE_BEACON_SPECS.size():
		expected_marker_name = &"CinderReachPlatform"
	_patrol_marker_presentation_snapshot = {
		"activity_id": RACE_ACTIVITY_ID,
		"state_id": &"reset" if reset else state_id,
		"phase_id": phase_id,
		"generation": generation,
		"next_checkpoint_index": next_checkpoint,
		"checkpoint_count": checkpoint_count,
		"expected_marker_name": expected_marker_name,
		"dwell_fraction": dwell_fraction,
		"route_risk_interrupted": interruption,
		"markers": marker_states,
		"static_geometry_only": true,
		"node_delta": 0,
		"collision_delta": 0,
		"checkpoint_authority": false,
		"movement_authority": false,
		"reward_authority": false,
	}.duplicate(true)
	return {"accepted": true, "reason": &"patrol_marker_presentation_applied"}


func get_patrol_marker_presentation_state() -> Dictionary:
	return _patrol_marker_presentation_snapshot.duplicate(true)


## Detached proof that the ordered traversal is visually expressed by the four
## existing guide beacons and one collision-free batched debris field outside a
## frozen safe tube. The activity remains the sole order/progress authority.
func get_beacon_traversal_presentation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var snapshot: Dictionary = {}
	if is_instance_valid(_activity_binding):
		snapshot = (
			_activity_binding.call("get_snapshot").get("beacon_traversal", {}) as Dictionary
		).duplicate(true)
	if StringName(snapshot.get("activity_id", &"")) != BEACON_TRAVERSAL_ACTIVITY_ID:
		errors.append("beacon_traversal_activity_id_not_bound")
	if int(snapshot.get("beacon_count", -1)) != ROUTE_BEACON_SPECS.size():
		errors.append("beacon_traversal_order_count_drift")
	var route_root := get_node_or_null(^"RouteBeacons") as Node3D
	var chips := get_node_or_null(^"DebrisField/DebrisChips") as MultiMeshInstance3D
	var beacon_meshes: Array[Node] = []
	var beacon_lights: Array[Node] = []
	var route_descendants := 0
	var ordered := true
	var maximum_leg_length := 0.0
	if route_root != null:
		beacon_meshes = route_root.find_children("*", "MeshInstance3D", true, false)
		beacon_lights = route_root.find_children("*", "Light3D", true, false)
		route_descendants = route_root.find_children("*", "", true, false).size()
		for index in ROUTE_BEACON_SPECS.size():
			var spec := ROUTE_BEACON_SPECS[index]
			var beacon := route_root.get_node_or_null(NodePath(String(spec["name"]))) as Node3D
			if beacon == null \
					or not beacon.global_position.is_equal_approx(spec["position"] as Vector3) \
					or int(beacon.get_meta(&"traversal_order_index", -1)) != index \
					or StringName(beacon.get_meta(&"activity_id", &"")) \
						!= BEACON_TRAVERSAL_ACTIVITY_ID:
				ordered = false
			if index > 0:
				maximum_leg_length = maxf(
					maximum_leg_length,
					(spec["position"] as Vector3).distance_to(
						ROUTE_BEACON_SPECS[index - 1]["position"] as Vector3
					)
				)
	if not ordered:
		errors.append("beacon_traversal_visual_order_drift")
	if beacon_meshes.size() != TRAVERSAL_BEACON_MESH_BUDGET:
		errors.append("beacon_traversal_mesh_budget_drift")
	if beacon_lights.size() != TRAVERSAL_BEACON_LIGHT_BUDGET:
		errors.append("beacon_traversal_light_budget_drift")
	if route_descendants != TRAVERSAL_BEACON_DESCENDANT_BUDGET:
		errors.append("beacon_traversal_node_budget_drift")
	for raw_light in beacon_lights:
		if (raw_light as Light3D).shadow_enabled:
			errors.append("beacon_traversal_shadow_light_added")
	var chip_count := 0
	var minimum_chip_clearance := INF
	var cluster_counts := PackedInt32Array()
	cluster_counts.resize(TRAVERSAL_DEBRIS_CLUSTER_SPECS.size())
	var chips_inside_bounds := true
	var chips_inside_content_envelope := true
	var chips_inside_authored_clusters := true
	if chips == null or chips.multimesh == null or chips.multimesh.mesh == null:
		errors.append("beacon_traversal_debris_batch_missing")
	else:
		chip_count = chips.multimesh.visible_instance_count
		if chip_count < 0:
			chip_count = chips.multimesh.instance_count
		var authored_positions := chips.get_meta(
			&"authored_instance_positions", PackedVector3Array()
		) as PackedVector3Array
		var authored_cluster_indices := chips.get_meta(
			&"authored_cluster_indices", PackedInt32Array()
		) as PackedInt32Array
		if authored_positions.size() != chip_count \
				or authored_cluster_indices.size() != chip_count:
			errors.append("beacon_traversal_debris_recipe_count_drift")
		for chip_index in mini(authored_positions.size(), authored_cluster_indices.size()):
			var position := authored_positions[chip_index]
			minimum_chip_clearance = minf(
				minimum_chip_clearance,
				_distance_to_beacon_traversal(position) - DEBRIS_CHIP_CLEARANCE_MARGIN
			)
			chips_inside_bounds = chips_inside_bounds \
				and TRAVERSAL_DEBRIS_PRESENTATION_BOUNDS.has_point(position)
			chips_inside_content_envelope = chips_inside_content_envelope \
				and position.length() <= MAXIMUM_CONTENT_DISTANCE
			var cluster_index := authored_cluster_indices[chip_index]
			if cluster_index < 0 or cluster_index >= TRAVERSAL_DEBRIS_CLUSTER_SPECS.size():
				chips_inside_authored_clusters = false
				continue
			cluster_counts[cluster_index] += 1
			var cluster_spec := TRAVERSAL_DEBRIS_CLUSTER_SPECS[cluster_index]
			var normalised_offset := (position - (cluster_spec["center"] as Vector3)) \
				/ (cluster_spec["radii"] as Vector3)
			chips_inside_authored_clusters = chips_inside_authored_clusters \
				and normalised_offset.length() <= 1.0001
		if not chips.custom_aabb.is_equal_approx(TRAVERSAL_DEBRIS_PRESENTATION_BOUNDS) \
				or not bool(chips.get_meta(&"presentation_only", false)) \
				or int(chips.get_meta(&"authored_cluster_count", -1)) \
					!= TRAVERSAL_DEBRIS_CLUSTER_SPECS.size() \
				or StringName(chips.get_meta(&"activity_id", &"")) \
					!= BEACON_TRAVERSAL_ACTIVITY_ID:
			errors.append("beacon_traversal_debris_batch_contract_drift")
	if chip_count != DEBRIS_CHIP_COUNT:
		errors.append("beacon_traversal_debris_copy_budget_drift")
	if minimum_chip_clearance < BEACON_TRAVERSAL_CORRIDOR_RADIUS:
		errors.append("beacon_traversal_debris_entered_safe_corridor")
	if not chips_inside_bounds or not chips_inside_content_envelope:
		errors.append("beacon_traversal_debris_left_bounds")
	if not chips_inside_authored_clusters:
		errors.append("beacon_traversal_debris_left_authored_clusters")
	var expected_per_cluster := DEBRIS_CHIP_COUNT / TRAVERSAL_DEBRIS_CLUSTER_SPECS.size()
	for count in cluster_counts:
		if count != expected_per_cluster:
			errors.append("beacon_traversal_debris_cluster_budget_drift")
			break
	var minimum_boulder_clearance := INF
	for offset in _boulder_offsets:
		minimum_boulder_clearance = minf(
			minimum_boulder_clearance,
			_distance_to_beacon_traversal(PLATFORM_ANCHOR + offset)
				- BOULDER_MAXIMUM_EXTENT * 0.40
		)
	if minimum_boulder_clearance < BEACON_TRAVERSAL_CORRIDOR_RADIUS:
		errors.append("beacon_traversal_collision_entered_safe_corridor")
	if route_root != null \
			and (not route_root.find_children("*", "CollisionObject3D", true, false).is_empty() \
			or not route_root.find_children("*", "CollisionShape3D", true, false).is_empty()):
		errors.append("beacon_traversal_guides_gained_collision_authority")
	var state_feedback := get_beacon_traversal_presentation_state()
	if (
		StringName(state_feedback.get("activity_id", &"")) != BEACON_TRAVERSAL_ACTIVITY_ID
		or StringName(state_feedback.get("state_id", &"")) \
			not in [&"available", &"traversing", &"wrong_order", &"completed", &"reset"]
		or int(state_feedback.get("node_delta", -1)) != 0
		or int(state_feedback.get("light_delta", -1)) != 0
		or int(state_feedback.get("submission_delta", -1)) != 0
		or bool(state_feedback.get("order_authority", true))
		or bool(state_feedback.get("reward_authority", true))
	):
		errors.append("beacon_traversal_state_feedback_contract_drift")
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"activity_id": BEACON_TRAVERSAL_ACTIVITY_ID,
		"content_class": &"NEW",
		"evidence_status": EVIDENCE_STATUS,
		"beacon_positions": get_route_beacon_positions(),
		"corridor_radius": BEACON_TRAVERSAL_CORRIDOR_RADIUS,
		"minimum_chip_clearance": minimum_chip_clearance,
		"minimum_boulder_clearance": minimum_boulder_clearance,
		"maximum_leg_length": maximum_leg_length,
		"debris_bounds": TRAVERSAL_DEBRIS_PRESENTATION_BOUNDS,
		"cluster_counts": cluster_counts,
		"counts": {
			"beacon_meshes": beacon_meshes.size(),
			"beacon_lights": beacon_lights.size(),
			"beacon_descendants": route_descendants,
			"debris_batches": 1 if chips != null else 0,
			"debris_copies": chip_count,
			"debris_clusters": TRAVERSAL_DEBRIS_CLUSTER_SPECS.size(),
		},
		"budgets": {
			"beacon_meshes": TRAVERSAL_BEACON_MESH_BUDGET,
			"beacon_lights": TRAVERSAL_BEACON_LIGHT_BUDGET,
			"beacon_descendants": TRAVERSAL_BEACON_DESCENDANT_BUDGET,
			"debris_batches": TRAVERSAL_DEBRIS_BATCH_BUDGET,
			"debris_copies": DEBRIS_CHIP_COUNT,
			"debris_clusters": TRAVERSAL_DEBRIS_CLUSTER_SPECS.size(),
		},
		"state_feedback": state_feedback,
		"approach_readable": ordered and maximum_leg_length <= 140.0,
		"activity_authority": false,
		"order_authority": false,
		"collision_authority": false,
		"reward_authority": false,
	}.duplicate(true)


## Maps an authority-produced detached traversal record onto the existing four
## guide rosters. No route order is calculated here: next/cleared status comes
## directly from the activity's authoritative `next_beacon_index` field.
func _apply_beacon_traversal_activity_presentation(snapshot: Dictionary) -> Dictionary:
	if StringName(snapshot.get("activity_id", &"")) != BEACON_TRAVERSAL_ACTIVITY_ID:
		return {"accepted": false, "reason": &"wrong_activity_snapshot"}
	var generation := int(snapshot.get("generation", -1))
	var authority_state := int(snapshot.get("state", -1))
	var next_index := int(snapshot.get("next_beacon_index", -1))
	var beacon_count := int(snapshot.get("beacon_count", -1))
	if generation < 0 or authority_state < 0 or authority_state > 3 \
			or next_index < 0 or beacon_count != ROUTE_BEACON_SPECS.size() \
			or next_index > beacon_count:
		return {"accepted": false, "reason": &"invalid_activity_snapshot"}
	var route_root := get_node_or_null(^"RouteBeacons") as Node3D
	if route_root == null:
		return {"accepted": false, "reason": &"presentation_unavailable"}
	var state_id: StringName = &"available"
	if authority_state == CinderBeaconTraversalActivity.State.ACTIVE:
		state_id = &"traversing"
		if (
			(not bool(snapshot.get("accepted", true))
			and StringName(snapshot.get("reason", &"")) == &"out_of_order_beacon")
			or StringName(snapshot.get("presentation_reason", &"")) \
			== &"out_of_order_beacon"
		):
			state_id = &"wrong_order"
	elif authority_state == CinderBeaconTraversalActivity.State.COMPLETE:
		state_id = &"completed"
	elif authority_state == CinderBeaconTraversalActivity.State.RESET:
		state_id = &"reset"
	var beacon_states: Array[Dictionary] = []
	for index in ROUTE_BEACON_SPECS.size():
		var beacon := route_root.get_node_or_null(
			NodePath(String(ROUTE_BEACON_SPECS[index]["name"]))
		) as Node3D
		if beacon == null:
			return {"accepted": false, "reason": &"presentation_roster_incomplete"}
		var status_id: StringName = &"available"
		var home_energy := 1.2
		var outbound_energy := 1.2
		var foot_energy := 0.7
		var status_color := KETH_ORANGE
		var counter_scale := Vector3.ONE
		var spar_scale := Vector3.ONE
		var counter_position := TRAVERSAL_VANE_BASE_POSITION
		var spar_position := TRAVERSAL_VANE_BASE_POSITION
		if state_id == &"traversing" or state_id == &"wrong_order":
			if index < next_index:
				status_id = &"cleared"
				home_energy = 2.0
				outbound_energy = 0.5
				foot_energy = 1.4
				status_color = KETH_CYAN
				counter_scale = TRAVERSAL_CLEARED_COUNTER_SCALE
				spar_scale = TRAVERSAL_CLEARED_SPAR_SCALE
				counter_position = Vector3(0.0, -13.0, 0.0)
			elif index == next_index:
				status_id = &"next_target" if state_id == &"traversing" else &"wrong_order_no_progress"
				home_energy = 1.0
				outbound_energy = 4.6 if state_id == &"traversing" else 2.2
				foot_energy = 3.0 if state_id == &"traversing" else 4.2
				if state_id == &"wrong_order":
					counter_scale = TRAVERSAL_WRONG_COUNTER_SCALE
					spar_scale = TRAVERSAL_WRONG_SPAR_SCALE
					counter_position = Vector3(-3.5, -7.5, 0.0)
					spar_position = Vector3(3.5, -10.5, 0.0)
				else:
					counter_scale = TRAVERSAL_TARGET_COUNTER_SCALE
					spar_scale = TRAVERSAL_TARGET_SPAR_SCALE
					counter_position = Vector3(0.0, -7.5, 0.0)
					spar_position = Vector3(0.0, -10.5, 0.0)
			else:
				status_id = &"pending"
				home_energy = 0.35
				outbound_energy = 0.35
				foot_energy = 0.25
				counter_scale = TRAVERSAL_PENDING_SCALE
				spar_scale = TRAVERSAL_PENDING_SCALE
		elif state_id == &"completed":
			status_id = &"cleared"
			home_energy = 2.8
			outbound_energy = 2.8
			foot_energy = 2.0
			status_color = KETH_CYAN
			counter_scale = TRAVERSAL_COMPLETE_SCALE
			spar_scale = TRAVERSAL_COMPLETE_SCALE
			counter_position = Vector3(0.0, -7.5, 0.0)
			spar_position = Vector3(0.0, -10.5, 0.0)
		elif state_id == &"reset":
			status_id = &"reset"
			home_energy = 0.2
			outbound_energy = 0.2
			foot_energy = 0.2
		_apply_beacon_visual_state(
			beacon, home_energy, outbound_energy, foot_energy, status_color
		)
		_apply_beacon_traversal_geometry(
			beacon, counter_scale, spar_scale, counter_position, spar_position
		)
		beacon_states.append({
			"index": index,
			"status_id": status_id,
			"home_energy": home_energy,
			"outbound_energy": outbound_energy,
			"foot_energy": foot_energy,
			"counter_scale": counter_scale,
			"spar_scale": spar_scale,
			"counter_position": counter_position,
			"spar_position": spar_position,
		})
	var expected_beacon_name: StringName = &""
	if next_index >= 0 and next_index < ROUTE_BEACON_SPECS.size():
		expected_beacon_name = StringName(ROUTE_BEACON_SPECS[next_index]["name"])
	_beacon_traversal_presentation_snapshot = {
		"activity_id": BEACON_TRAVERSAL_ACTIVITY_ID,
		"state_id": state_id,
		"authority_state": authority_state,
		"generation": generation,
		"next_beacon_index": next_index,
		"expected_beacon_name": expected_beacon_name,
		"beacons": beacon_states,
		"static_geometry_only": true,
		"node_delta": BEACON_TRAVERSAL_STATE_NODE_DELTA,
		"light_delta": BEACON_TRAVERSAL_STATE_LIGHT_DELTA,
		"submission_delta": BEACON_TRAVERSAL_STATE_SUBMISSION_DELTA,
		"order_authority": false,
		"reward_authority": false,
	}.duplicate(true)
	return {"accepted": true, "reason": &"beacon_traversal_presentation_applied"}


func _apply_beacon_traversal_geometry(
	beacon: Node3D,
	counter_scale: Vector3,
	spar_scale: Vector3,
	counter_position: Vector3,
	spar_position: Vector3
	) -> void:
	var counter := beacon.get_node(^"CounterVane") as MeshInstance3D
	var spar := beacon.get_node(^"VaneSpar") as MeshInstance3D
	counter.scale = counter_scale
	counter.position = counter_position
	spar.scale = spar_scale
	spar.position = spar_position


func _apply_beacon_visual_state(
	beacon: Node3D,
	home_energy: float,
	outbound_energy: float,
	foot_energy: float,
	status_color: Color
	) -> void:
	var home := beacon.get_node(^"HomeLamp") as OmniLight3D
	var outbound := beacon.get_node(^"OutboundLamp") as OmniLight3D
	var foot := beacon.get_node(^"MastFootLamp") as OmniLight3D
	var home_lens := beacon.get_node(^"HomeLampLens") as MeshInstance3D
	var outbound_lens := beacon.get_node(^"OutboundLampLens") as MeshInstance3D
	var foot_lens := beacon.get_node(^"MastFootLampLens") as MeshInstance3D
	var lights: Array[OmniLight3D] = [home, outbound, foot]
	var energies := [home_energy, outbound_energy, foot_energy]
	for light_index in lights.size():
		lights[light_index].light_energy = energies[light_index]
		lights[light_index].set_meta(&"base_energy", energies[light_index])
	home.light_color = KETH_CYAN if status_color == KETH_ORANGE else status_color
	outbound.light_color = status_color
	foot.light_color = status_color
	home_lens.material_override = _lens_material(home.light_color)
	outbound_lens.material_override = _lens_material(outbound.light_color)
	foot_lens.material_override = _lens_material(foot.light_color)
	var status_material: Material = _materials["cyan_glow"] \
		if status_color == KETH_CYAN else _materials["orange_glow"]
	(beacon.get_node(^"SignalRing") as MeshInstance3D).material_override = status_material
	for raw_child in beacon.get_children():
		if raw_child is MeshInstance3D and String(raw_child.name).begins_with("Sign_"):
			(raw_child as MeshInstance3D).material_override = status_material


func get_beacon_traversal_presentation_state() -> Dictionary:
	return _beacon_traversal_presentation_snapshot.duplicate(true)


## Station-relative offsets of the boulders this instance actually placed.
## Returned as a copy; the field is deterministic, so two builds from the same
## seed produce the same list.
func get_boulder_offsets() -> Array[Vector3]:
	return _boulder_offsets.duplicate()


## Deep copy, so a caller inspecting the cluster cannot edit the component's own
## record of what it built.
func get_cluster_audit_report() -> Dictionary:
	return _audit_report.duplicate(true)


## Detached proof that the mining activity's fixed IDs/anchors terminate on one
## bounded, approach-readable presentation family without acquiring authority.
func get_mining_platform_presentation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var platform := get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform"
	) as Node3D
	var presentation := get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/MiningActivityPresentation"
	) as Node3D
	var approach := (
		presentation.get_node_or_null(^"MiningApproachAnchor") as Marker3D
		if presentation != null else null
	)
	var mining_snapshot: Dictionary = {}
	if is_instance_valid(_activity_binding):
		mining_snapshot = (
			_activity_binding.call("get_snapshot").get("mining", {}) as Dictionary
		).duplicate(true)
	if StringName(mining_snapshot.get("activity_id", &"")) != MINING_ACTIVITY_ID:
		errors.append("mining_activity_id_not_bound")
	if (mining_snapshot.get("platform_anchor", Vector3(999999.0, 999999.0, 999999.0)) as Vector3) \
			.distance_to(PLATFORM_ANCHOR) > 0.001:
		errors.append("mining_platform_anchor_not_bound")
	if (mining_snapshot.get("approach_anchor", Vector3(999999.0, 999999.0, 999999.0)) as Vector3) \
			.distance_to(get_dock_gate_center()) > 0.001:
		errors.append("mining_approach_anchor_not_bound_to_gate")
	if platform == null or presentation == null or approach == null:
		errors.append("mining_presentation_roster_missing")
	var mesh_nodes: Array[Node] = []
	var multimesh_nodes: Array[Node] = []
	var light_nodes: Array[Node] = []
	var descendant_count := 0
	var material_ids: Dictionary = {}
	var mesh_resource_ids: Dictionary = {}
	var local_bounds := AABB()
	var first_bound := true
	var visible_copies := 0
	var surface_submissions := 0
	if presentation != null:
		descendant_count = presentation.find_children("*", "", true, false).size()
		mesh_nodes = presentation.find_children("*", "MeshInstance3D", true, false)
		multimesh_nodes = presentation.find_children("*", "MultiMeshInstance3D", true, false)
		light_nodes = presentation.find_children("*", "Light3D", true, false)
		visible_copies = mesh_nodes.size()
		var presentation_inverse := presentation.global_transform.affine_inverse()
		for raw_node in mesh_nodes:
			var instance := raw_node as MeshInstance3D
			if instance.mesh == null:
				errors.append("mining_presentation_mesh_missing")
				continue
			if instance.material_override != null:
				material_ids[instance.material_override.get_instance_id()] = true
			mesh_resource_ids[instance.mesh.get_instance_id()] = true
			surface_submissions += instance.mesh.get_surface_count()
			var bounds := (
				presentation_inverse * instance.global_transform * instance.mesh.get_aabb()
			).abs()
			if first_bound:
				local_bounds = bounds
				first_bound = false
			else:
				local_bounds = local_bounds.merge(bounds)
		for raw_node in multimesh_nodes:
			var batch := raw_node as MultiMeshInstance3D
			if batch.multimesh == null or batch.multimesh.mesh == null:
				errors.append("mining_presentation_batch_mesh_missing")
				continue
			var copy_count := batch.multimesh.visible_instance_count
			if copy_count < 0:
				copy_count = batch.multimesh.instance_count
			visible_copies += copy_count
			surface_submissions += batch.multimesh.mesh.get_surface_count()
			mesh_resource_ids[batch.multimesh.mesh.get_instance_id()] = true
			if batch.material_override != null:
				material_ids[batch.material_override.get_instance_id()] = true
			var bounds := (
				presentation_inverse * batch.global_transform * batch.custom_aabb
			).abs()
			if first_bound:
				local_bounds = bounds
				first_bound = false
			else:
				local_bounds = local_bounds.merge(bounds)
			if not bool(batch.get_meta(&"presentation_only", false)) \
					or (batch.get_meta(&"authored_instance_transforms", []) as Array).size() \
						!= copy_count:
				errors.append("mining_presentation_batch_contract_drift")
		if presentation.get_parent() != platform \
				or not presentation.transform.is_equal_approx(Transform3D.IDENTITY) \
				or not bool(presentation.get_meta(&"presentation_only", false)) \
				or StringName(presentation.get_meta(&"activity_id", &"")) \
					!= MINING_ACTIVITY_ID:
			errors.append("mining_presentation_root_drift")
	if approach == null \
			or not approach.position.is_equal_approx(MINING_APPROACH_LOCAL) \
			or approach.get_child_count() != 0:
		errors.append("mining_approach_marker_drift")
	if mesh_nodes.size() != MINING_PRESENTATION_MESH_BUDGET:
		errors.append("mining_presentation_mesh_budget_drift")
	if multimesh_nodes.size() != MINING_PRESENTATION_MULTIMESH_BUDGET:
		errors.append("mining_presentation_multimesh_budget_drift")
	if mesh_nodes.size() + multimesh_nodes.size() != MINING_PRESENTATION_RENDERER_BUDGET:
		errors.append("mining_presentation_renderer_budget_drift")
	if visible_copies != MINING_PRESENTATION_VISIBLE_COPY_BUDGET:
		errors.append("mining_presentation_visible_copy_drift")
	if surface_submissions != MINING_PRESENTATION_SUBMISSION_BUDGET:
		errors.append("mining_presentation_submission_budget_drift")
	if mesh_resource_ids.size() != MINING_PRESENTATION_MESH_RESOURCE_BUDGET:
		errors.append("mining_presentation_mesh_resource_budget_drift")
	if light_nodes.size() != MINING_PRESENTATION_LIGHT_BUDGET:
		errors.append("mining_presentation_light_budget_drift")
	if descendant_count != MINING_PRESENTATION_DESCENDANT_BUDGET:
		errors.append("mining_presentation_node_budget_drift")
	if not MINING_PRESENTATION_LOCAL_BOUNDS.encloses(local_bounds):
		errors.append("mining_presentation_left_local_bounds")
	if local_bounds.size.x < 28.0 or local_bounds.size.y < 32.0 \
			or presentation == null \
			or presentation.get_node_or_null(^"Sign_ORE_EXTRACTION") == null:
		errors.append("mining_presentation_approach_readability_drift")
	for raw_light in light_nodes:
		var light := raw_light as Light3D
		if light.shadow_enabled:
			errors.append("mining_presentation_shadow_light_added")
	if presentation != null \
			and (not presentation.find_children(
				"*", "CollisionObject3D", true, false
			).is_empty() \
			or not presentation.find_children("*", "CollisionShape3D", true, false).is_empty() \
			or not presentation.find_children("*", "Area3D", true, false).is_empty()):
		errors.append("mining_presentation_gained_collision_or_interaction_authority")
	var state_feedback := get_mining_activity_presentation_state()
	if (
		StringName(state_feedback.get("activity_id", &"")) != MINING_ACTIVITY_ID
		or StringName(state_feedback.get("state_id", &"")) \
			not in [&"available", &"extracting", &"secured", &"failed", &"reset"]
		or int(state_feedback.get("node_delta", -1)) != 0
		or int(state_feedback.get("light_delta", -1)) != 0
		or int(state_feedback.get("submission_delta", -1)) != 0
		or bool(state_feedback.get("activity_authority", true))
		or bool(state_feedback.get("reward_authority", true))
	):
		errors.append("mining_state_feedback_contract_drift")
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"activity_id": MINING_ACTIVITY_ID,
		"content_class": &"NEW",
		"evidence_status": EVIDENCE_STATUS,
		"platform_anchor": PLATFORM_ANCHOR,
		"approach_anchor": get_dock_gate_center(),
		"presentation_local_bounds": local_bounds,
		"maximum_local_bounds": MINING_PRESENTATION_LOCAL_BOUNDS,
		"counts": {
			"mesh_nodes": mesh_nodes.size(),
			"multimesh_nodes": multimesh_nodes.size(),
			"renderer_nodes": mesh_nodes.size() + multimesh_nodes.size(),
			"visible_copies": visible_copies,
			"surface_submissions": surface_submissions,
			"mesh_resource_allocations": mesh_resource_ids.size(),
			"light_nodes": light_nodes.size(),
			"descendant_nodes": descendant_count,
			"material_resources": material_ids.size(),
		},
		"budgets": {
			"mesh_nodes": MINING_PRESENTATION_MESH_BUDGET,
			"multimesh_nodes": MINING_PRESENTATION_MULTIMESH_BUDGET,
			"renderer_nodes": MINING_PRESENTATION_RENDERER_BUDGET,
			"visible_copies": MINING_PRESENTATION_VISIBLE_COPY_BUDGET,
			"surface_submissions": MINING_PRESENTATION_SUBMISSION_BUDGET,
			"mesh_resource_allocations": MINING_PRESENTATION_MESH_RESOURCE_BUDGET,
			"light_nodes": MINING_PRESENTATION_LIGHT_BUDGET,
			"descendant_nodes": MINING_PRESENTATION_DESCENDANT_BUDGET,
		},
		"optimization_delta": {
			"renderer_nodes_before": MINING_PRESENTATION_PREBATCH_RENDERERS,
			"renderer_nodes_after": mesh_nodes.size() + multimesh_nodes.size(),
			"surface_submissions_before": MINING_PRESENTATION_PREBATCH_SUBMISSIONS,
			"surface_submissions_after": surface_submissions,
			"descendant_nodes_before": MINING_PRESENTATION_PREBATCH_DESCENDANTS,
			"descendant_nodes_after": descendant_count,
			"mesh_resource_allocations_before": MINING_PRESENTATION_MESH_RESOURCE_BUDGET,
			"mesh_resource_allocations_after": mesh_resource_ids.size(),
			"visible_copies_before": MINING_PRESENTATION_VISIBLE_COPY_BUDGET,
			"visible_copies_after": visible_copies,
		},
		"state_feedback": state_feedback,
		"approach_readable": local_bounds.size.x >= 28.0 \
			and local_bounds.size.y >= 32.0,
		"activity_authority": false,
		"interaction_authority": false,
		"collision_authority": false,
		"reward_authority": false,
	}.duplicate(true)


## Detached proof that the abandoned-structure scan points at the existing
## platform wreckage and one bounded visual datum, never a second interaction.
func get_structure_scan_presentation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var platform := get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform"
	) as Node3D
	var presentation := get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/AbandonedStructureScanPresentation"
	) as Node3D
	var approach := (
		presentation.get_node_or_null(^"StructureScanApproachAnchor") as Marker3D
		if presentation != null else null
	)
	var scan_snapshot: Dictionary = {}
	if is_instance_valid(_activity_binding):
		scan_snapshot = (
			_activity_binding.call("get_snapshot").get("structure_scan", {}) as Dictionary
		).duplicate(true)
	if StringName(scan_snapshot.get("activity_id", &"")) != STRUCTURE_SCAN_ACTIVITY_ID:
		errors.append("structure_scan_activity_id_not_bound")
	if (scan_snapshot.get("structure_anchor", Vector3(999999.0, 999999.0, 999999.0)) as Vector3) \
			.distance_to(PLATFORM_ANCHOR) > 0.001:
		errors.append("structure_scan_anchor_not_bound_to_platform")
	var expected_approach := PLATFORM_ANCHOR + STRUCTURE_SCAN_APPROACH_LOCAL
	if (scan_snapshot.get("approach_anchor", Vector3(999999.0, 999999.0, 999999.0)) as Vector3) \
			.distance_to(expected_approach) > 0.001:
		errors.append("structure_scan_approach_anchor_not_bound")
	if platform == null or presentation == null or approach == null:
		errors.append("structure_scan_presentation_roster_missing")
	var mesh_nodes: Array[Node] = []
	var light_nodes: Array[Node] = []
	var descendant_count := 0
	var material_ids: Dictionary = {}
	var local_bounds := AABB()
	var first_bound := true
	var world_outer_distance := 0.0
	if presentation != null:
		descendant_count = presentation.find_children("*", "", true, false).size()
		mesh_nodes = presentation.find_children("*", "MeshInstance3D", true, false)
		light_nodes = presentation.find_children("*", "Light3D", true, false)
		var presentation_inverse := presentation.global_transform.affine_inverse()
		for raw_node in mesh_nodes:
			var instance := raw_node as MeshInstance3D
			if instance.mesh == null:
				errors.append("structure_scan_presentation_mesh_missing")
				continue
			if instance.material_override != null:
				material_ids[instance.material_override.get_instance_id()] = true
			var bounds := (
				presentation_inverse * instance.global_transform * instance.mesh.get_aabb()
			).abs()
			if first_bound:
				local_bounds = bounds
				first_bound = false
			else:
				local_bounds = local_bounds.merge(bounds)
		if presentation.get_parent() != platform \
				or not presentation.transform.is_equal_approx(Transform3D.IDENTITY) \
				or not bool(presentation.get_meta(&"presentation_only", false)) \
				or StringName(presentation.get_meta(&"activity_id", &"")) \
					!= STRUCTURE_SCAN_ACTIVITY_ID:
			errors.append("structure_scan_presentation_root_drift")
		for corner_x in [0.0, 1.0]:
			for corner_y in [0.0, 1.0]:
				for corner_z in [0.0, 1.0]:
					var local_corner := local_bounds.position + local_bounds.size * Vector3(
						corner_x, corner_y, corner_z
					)
					world_outer_distance = maxf(
						world_outer_distance, presentation.to_global(local_corner).length()
					)
	if approach == null \
			or not approach.position.is_equal_approx(STRUCTURE_SCAN_APPROACH_LOCAL) \
			or approach.get_child_count() != 0:
		errors.append("structure_scan_approach_marker_drift")
	if mesh_nodes.size() != STRUCTURE_SCAN_PRESENTATION_MESH_BUDGET:
		errors.append("structure_scan_presentation_mesh_budget_drift")
	if light_nodes.size() != STRUCTURE_SCAN_PRESENTATION_LIGHT_BUDGET:
		errors.append("structure_scan_presentation_light_budget_drift")
	if descendant_count != STRUCTURE_SCAN_PRESENTATION_DESCENDANT_BUDGET:
		errors.append("structure_scan_presentation_node_budget_drift")
	if not STRUCTURE_SCAN_PRESENTATION_LOCAL_BOUNDS.encloses(local_bounds):
		errors.append("structure_scan_presentation_left_local_bounds")
	if world_outer_distance > MAXIMUM_CONTENT_DISTANCE:
		errors.append("structure_scan_presentation_left_cluster_bounds")
	if local_bounds.size.x < 44.0 or local_bounds.size.y < 30.0 \
			or presentation == null \
			or presentation.get_node_or_null(^"Sign_DERELICT_SCAN") == null:
		errors.append("structure_scan_approach_readability_drift")
	for raw_light in light_nodes:
		if (raw_light as Light3D).shadow_enabled:
			errors.append("structure_scan_shadow_light_added")
	if presentation != null \
			and (not presentation.find_children(
				"*", "CollisionObject3D", true, false
			).is_empty() \
			or not presentation.find_children("*", "CollisionShape3D", true, false).is_empty() \
			or not presentation.find_children("*", "Area3D", true, false).is_empty()):
		errors.append("structure_scan_gained_collision_or_interaction_authority")
	var state_feedback := get_structure_scan_presentation_state()
	if (
		StringName(state_feedback.get("activity_id", &"")) != STRUCTURE_SCAN_ACTIVITY_ID
		or StringName(state_feedback.get("state_id", &"")) \
			not in [&"available", &"scanning", &"completed", &"failed", &"aborted", &"reset"]
		or int(state_feedback.get("node_delta", -1)) != 0
		or int(state_feedback.get("light_delta", -1)) != 0
		or int(state_feedback.get("submission_delta", -1)) != 0
		or bool(state_feedback.get("scan_authority", true))
		or bool(state_feedback.get("reward_authority", true))
	):
		errors.append("structure_scan_state_feedback_contract_drift")
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"activity_id": STRUCTURE_SCAN_ACTIVITY_ID,
		"content_class": &"NEW",
		"evidence_status": EVIDENCE_STATUS,
		"structure_anchor": PLATFORM_ANCHOR,
		"approach_anchor": expected_approach,
		"presentation_local_bounds": local_bounds,
		"maximum_local_bounds": STRUCTURE_SCAN_PRESENTATION_LOCAL_BOUNDS,
		"world_outer_distance": world_outer_distance,
		"maximum_content_distance": MAXIMUM_CONTENT_DISTANCE,
		"counts": {
			"mesh_nodes": mesh_nodes.size(),
			"light_nodes": light_nodes.size(),
			"descendant_nodes": descendant_count,
			"material_resources": material_ids.size(),
		},
		"budgets": {
			"mesh_nodes": STRUCTURE_SCAN_PRESENTATION_MESH_BUDGET,
			"light_nodes": STRUCTURE_SCAN_PRESENTATION_LIGHT_BUDGET,
			"descendant_nodes": STRUCTURE_SCAN_PRESENTATION_DESCENDANT_BUDGET,
		},
		"state_feedback": state_feedback,
		"approach_readable": local_bounds.size.x >= 44.0 \
			and local_bounds.size.y >= 30.0,
		"scan_authority": false,
		"interaction_authority": false,
		"collision_authority": false,
		"reward_authority": false,
	}.duplicate(true)


## One immutable primitive serves every visual-only lamp lens. The individual
## MeshInstance3D nodes retain their authored paths, transforms, materials and
## light siblings; only indistinguishable resource allocation is shared.
func get_lamp_lens_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids := {}
	for lens in _lamp_lenses:
		if not is_instance_valid(lens):
			errors.append("lamp_lens_node_lost")
			continue
		if lens.mesh == null:
			errors.append("lamp_lens_missing_mesh")
			continue
		mesh_ids[lens.mesh.get_instance_id()] = true
		if lens.mesh != _lamp_lens_mesh:
			errors.append("lamp_lens_retained_private_mesh")
		if lens.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			errors.append("lamp_lens_shadow_contract_drift")
		if not lens.find_children("*", "CollisionObject3D", true, false).is_empty():
			errors.append("lamp_lens_collision_authority_added")
	if _lamp_lenses.size() != LAMP_LENS_COPY_COUNT:
		errors.append("lamp_lens_copy_count_drift")
	if mesh_ids.size() != 1:
		errors.append("lamp_lens_mesh_identity_drift")
	if _lamp_lens_mesh == null \
			or not is_equal_approx(_lamp_lens_mesh.radius, LAMP_LENS_RADIUS) \
			or not is_equal_approx(_lamp_lens_mesh.height, LAMP_LENS_HEIGHT) \
			or _lamp_lens_mesh.radial_segments != LAMP_LENS_RADIAL_SEGMENTS \
			or _lamp_lens_mesh.rings != LAMP_LENS_RINGS:
		errors.append("lamp_lens_mesh_recipe_drift")
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"copy_count": _lamp_lenses.size(),
		"mesh_resource_allocations": mesh_ids.size(),
		"expected_copy_count": LAMP_LENS_COPY_COUNT,
		"expected_mesh_resource_allocations": 1,
		"mesh_recipe": {
			"radius": LAMP_LENS_RADIUS,
			"height": LAMP_LENS_HEIGHT,
			"radial_segments": LAMP_LENS_RADIAL_SEGMENTS,
			"rings": LAMP_LENS_RINGS,
		}.duplicate(true),
	}.duplicate(true)


## Exact torus recipes are component-local immutable render resources. This
## checks the cache only shares indistinguishable geometry; every named instance
## keeps its authored path, transform, material override and no-collision status.
func get_torus_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids := {}
	var tori: Array[MeshInstance3D] = []
	for candidate in find_children("*", "MeshInstance3D", true, false):
		var instance := candidate as MeshInstance3D
		var mesh := instance.mesh as TorusMesh
		if mesh == null:
			continue
		tori.append(instance)
		mesh_ids[mesh.get_instance_id()] = true
		if instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			errors.append("torus_shadow_contract_drift")
		if not instance.find_children("*", "CollisionObject3D", true, false).is_empty():
			errors.append("torus_collision_authority_added")
		if not _torus_recipe_is_authored(mesh):
			errors.append("torus_mesh_recipe_drift")
	if tori.size() != TORUS_COPY_COUNT:
		errors.append("torus_copy_count_drift")
	if mesh_ids.size() != TORUS_MESH_RESOURCE_ALLOCATIONS:
		errors.append("torus_mesh_allocation_count_drift")
	if _torus_mesh_cache.size() != TORUS_MESH_RESOURCE_ALLOCATIONS:
		errors.append("torus_cache_recipe_count_drift")
	_validate_shared_torus_family(
		[
			^"RouteBeacons/RouteBeaconAlpha/SignalRing",
			^"RouteBeacons/RouteBeaconBravo/SignalRing",
			^"RouteBeacons/RouteBeaconCharlie/SignalRing",
			^"RouteBeacons/RouteBeaconDelta/SignalRing",
		], errors
	)
	_validate_shared_torus_family(
		[
			^"RouteBeacons/RouteBeaconAlpha/TrimRing",
			^"RouteBeacons/RouteBeaconBravo/TrimRing",
			^"RouteBeacons/RouteBeaconCharlie/TrimRing",
			^"RouteBeacons/RouteBeaconDelta/TrimRing",
		], errors
	)
	_validate_shared_torus_family(
		[
			^"ExtractionPlatform/CinderReachPlatform/DrumCollarUpper",
			^"ExtractionPlatform/CinderReachPlatform/DrumCollarLower",
		], errors
	)
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"copy_count": tori.size(),
		"mesh_resource_allocations": mesh_ids.size(),
		"expected_copy_count": TORUS_COPY_COUNT,
		"expected_mesh_resource_allocations": TORUS_MESH_RESOURCE_ALLOCATIONS,
		"authored_recipe": {
			"rings": TORUS_RINGS,
			"ring_segments": TORUS_RING_SEGMENTS,
		}.duplicate(true),
	}.duplicate(true)


func _validate_shared_torus_family(paths: Array[NodePath], errors: PackedStringArray) -> void:
	var shared_mesh: TorusMesh
	for path in paths:
		var instance := get_node_or_null(path) as MeshInstance3D
		var mesh := instance.mesh as TorusMesh if instance != null else null
		if mesh == null:
			errors.append("torus_family_node_or_mesh_lost")
			continue
		if shared_mesh == null:
			shared_mesh = mesh
		elif mesh != shared_mesh:
			errors.append("torus_shared_family_identity_drift")


func _torus_recipe_is_authored(mesh: TorusMesh) -> bool:
	if mesh == null:
		return false
	if mesh.has_meta(TorusGeometryBudget.AUTHORED_META):
		var authored := mesh.get_meta(TorusGeometryBudget.AUTHORED_META) as Vector2i
		return authored == Vector2i(TORUS_RINGS, TORUS_RING_SEGMENTS)
	return mesh.rings == TORUS_RINGS and mesh.ring_segments == TORUS_RING_SEGMENTS


func _compose_audit_report() -> Dictionary:
	var beacon_distances: Array[float] = []
	for spec in ROUTE_BEACON_SPECS:
		beacon_distances.append((spec["position"] as Vector3).length())
	var counts := _count_live_nodes()
	var errors: Array[String] = []
	var platform_distance := get_platform_distance()
	if platform_distance > MAXIMUM_ANCHOR_DISTANCE or platform_distance < MINIMUM_ANCHOR_DISTANCE:
		errors.append(
			"platform anchor %.1f m is outside the published travel envelope" % platform_distance
		)
	for spec in ROUTE_BEACON_SPECS:
		var beacon_position := spec["position"] as Vector3
		if beacon_position.z > TARGET_RANGE_CLEARANCE_Z:
			errors.append("beacon %s crowds the target range" % spec["name"])
	if MOONLET_ANCHOR.length() + MOONLET_RADIUS > MAXIMUM_CONTENT_DISTANCE:
		errors.append("moonlet landmark reaches past the published content envelope")
	var field_outer := _get_field_outer_distance()
	if field_outer > MAXIMUM_CONTENT_DISTANCE:
		errors.append("debris field reaches %.1f m, past the published content envelope" % field_outer)
	if _boulder_offsets.size() != BOULDER_COUNT:
		errors.append(
			"placed %d boulders, expected %d" % [_boulder_offsets.size(), BOULDER_COUNT]
		)
	for offset in _boulder_offsets:
		if offset.length() < PLATFORM_KEEP_CLEAR_RADIUS:
			errors.append("a boulder landed inside the platform keep-clear sphere")
			break
	for key: String in PERFORMANCE_BUDGET:
		if int(counts.get(key, 0)) > int(PERFORMANCE_BUDGET[key]):
			errors.append(
				"%s count %d exceeds budget %d" % [key, int(counts[key]), int(PERFORMANCE_BUDGET[key])]
			)
	var mining_presentation := get_mining_platform_presentation_audit()
	if not bool(mining_presentation.valid):
		for presentation_error in (mining_presentation.get("errors", PackedStringArray()) as PackedStringArray):
			errors.append("mining presentation: %s" % presentation_error)
	var structure_scan_presentation := get_structure_scan_presentation_audit()
	if not bool(structure_scan_presentation.valid):
		for presentation_error in (
			structure_scan_presentation.get("errors", PackedStringArray()) as PackedStringArray
		):
			errors.append("structure scan presentation: %s" % presentation_error)
	var beacon_traversal_presentation := get_beacon_traversal_presentation_audit()
	if not bool(beacon_traversal_presentation.valid):
		for presentation_error in (
			beacon_traversal_presentation.get("errors", PackedStringArray()) as PackedStringArray
		):
			errors.append("beacon traversal presentation: %s" % presentation_error)
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"content_note": CONTENT_NOTE,
		"gameplay_authority": false,
		"activity_authority": is_instance_valid(_activity_binding),
		"activity_id": &"cinder_reach_emberline_convoy" if is_instance_valid(_activity_binding) else &"",
		"activity_audit": (
			_activity_binding.call("audit") if is_instance_valid(_activity_binding) else {}
		),
		"grants_rewards": false,
		"range_targets_added": 0,
		"platform_anchor": PLATFORM_ANCHOR,
		"platform_distance": platform_distance,
		"cruise_travel_seconds": get_cruise_travel_seconds(),
		"boost_travel_seconds": platform_distance / BOOST_SPEED,
		"moonlet_anchor": MOONLET_ANCHOR,
		"moonlet_distance": MOONLET_ANCHOR.length(),
		"field_outer_distance": field_outer,
		"content_envelope": MAXIMUM_CONTENT_DISTANCE,
		"beacon_count": ROUTE_BEACON_SPECS.size(),
		"beacon_distances": beacon_distances,
		"boulder_count": _boulder_offsets.size(),
		"debris_chip_count": DEBRIS_CHIP_COUNT,
		"field_seed": FIELD_SEED,
		"debris_chip_seed": DEBRIS_CHIP_SEED,
		"gantry_clear_width": GANTRY_CLEAR_WIDTH,
		"gantry_clear_height": GANTRY_CLEAR_HEIGHT,
		"mining_platform_presentation": mining_presentation,
		"structure_scan_presentation": structure_scan_presentation,
		"beacon_traversal_presentation": beacon_traversal_presentation,
		"counts": counts,
		"budget": PERFORMANCE_BUDGET.duplicate(true),
		"errors": errors,
		"valid": errors.is_empty(),
	}


## Furthest any placed boulder actually reaches from the station origin, lobes
## included. Measured from the built field rather than assumed from the radii.
func _get_field_outer_distance() -> float:
	var furthest := PLATFORM_ANCHOR.length()
	for offset in _boulder_offsets:
		furthest = maxf(furthest, (PLATFORM_ANCHOR + offset).length() + BOULDER_MAXIMUM_EXTENT)
	return furthest


func _count_live_nodes() -> Dictionary:
	var shadow_casting := 0
	for candidate in find_children("*", "Light3D", true, false):
		if (candidate as Light3D).shadow_enabled:
			shadow_casting += 1
	return {
		"static_bodies": find_children("*", "StaticBody3D", true, false).size(),
		"mesh_instances": find_children("*", "MeshInstance3D", true, false).size(),
		"multimesh_instances": find_children("*", "MultiMeshInstance3D", true, false).size(),
		"omni_lights": find_children("*", "OmniLight3D", true, false).size(),
		"spot_lights": find_children("*", "SpotLight3D", true, false).size(),
		"shadow_casting_lights": shadow_casting,
		"audio_nodes": find_children("*", "AudioStreamPlayer3D", true, false).size(),
		"particle_emitters": find_children("*", "GPUParticles3D", true, false).size(),
		"animation_players": find_children("*", "AnimationPlayer", true, false).size(),
		"collision_shapes": find_children("*", "CollisionShape3D", true, false).size(),
	}


# --- Route -------------------------------------------------------------------


func _build_route_beacons() -> void:
	# The chain starts at the launch gate, so beacon one is oriented to the exact
	# heading the pilot leaves the corridor on.
	var previous := Vector3(0.0, 8.0, -64.0)
	for spec in ROUTE_BEACON_SPECS:
		var beacon_position := spec["position"] as Vector3
		var index := int(spec["index"])
		var beacon := Node3D.new()
		beacon.name = String(spec["name"])
		beacon.position = beacon_position
		# Local +Z points back down the leg the pilot just flew. Built from the
		# leg vector rather than `look_at`, which needs a global transform and a
		# node already in the tree; this is exact whatever the world is parented to.
		beacon.basis = _basis_facing(previous - beacon_position)
		beacon.set_meta(&"presentation_only", true)
		beacon.set_meta(&"activity_id", BEACON_TRAVERSAL_ACTIVITY_ID)
		beacon.set_meta(&"traversal_order_index", index - 1)
		_route_root.add_child(beacon)
		previous = beacon_position

		# Presentation only, and deliberately so: a 1.2 m mast standing in the
		# middle of the corridor the pilot is being told to follow would be a
		# cheap collision at 82 m/s. The beacons guide; the boulders and the
		# platform are the things that are solid.
		_cylinder(beacon, "Mast", Vector3.ZERO, 1.2, 1.2, 30.0, _materials["steel"], false)
		_torus(beacon, "SignalRing", Vector3(0.0, 12.0, 0.0), 5.0, 5.6, _materials["cyan_glow"], Vector3(90.0, 0.0, 0.0))
		_torus(beacon, "TrimRing", Vector3(0.0, 12.0, 0.0), 6.4, 6.7, _materials["orange"], Vector3(90.0, 0.0, 0.0))
		_box(beacon, "CounterVane", Vector3(0.0, -11.0, 0.0), Vector3(9.0, 5.0, 0.5), _materials["hull"], false)
		_box(beacon, "VaneSpar", Vector3(0.0, -11.0, 0.0), Vector3(0.5, 5.6, 3.2), _materials["steel"], false)

		# Homebound face (+Z, toward the station) cyan; outbound face amber.
		_lamp(beacon, "HomeLamp", Vector3(0.0, 12.0, 3.4), KETH_CYAN, 3.4, 26.0, true)
		_lamp(beacon, "OutboundLamp", Vector3(0.0, 12.0, -3.4), KETH_ORANGE, 3.0, 24.0, true)
		_lamp(beacon, "MastFootLamp", Vector3(0.0, -15.2, 0.0), KETH_CYAN, 1.6, 14.0, false)

		# `TextMesh` glyphs are thin and the two faces sit either side of the same
		# mast, so without something opaque between them the far sign reads
		# straight through the near one and both legends arrive scrambled. The
		# board is that something, and it also gives each legend a surface to sit
		# on instead of floating in vacuum.
		# The board has to be wider than the longest legend on it, not merely
		# present: at 2.6 scale a 26-character line spans about 20 m, so on the
		# first 15 m board both legends hung over the edges and the reversed far
		# face read straight through beside the near one. Two shorter lines at 2.2
		# span about 14 m inside a 20 m board.
		_box(beacon, "SignBoard", Vector3(0.0, 5.4, 0.0), Vector3(20.0, 3.4, 0.4), _materials["hull_shadow"], false)
		_sign(
			beacon,
			"CINDER REACH  %d m" % int(round((PLATFORM_ANCHOR - beacon_position).length())),
			Vector3(0.0, 5.4, -0.32),
			Vector3(0.0, 180.0, 0.0),
			2.2,
			_materials["orange_glow"]
		)
		_sign(
			beacon,
			"SHIPYARDS  MARKER %d" % index,
			Vector3(0.0, 5.4, 0.32),
			Vector3.ZERO,
			2.2,
			_materials["cyan_glow"]
		)


## Orthonormal basis whose local +Z points along `forward`.
func _basis_facing(forward: Vector3) -> Basis:
	if forward.length_squared() < 0.000001:
		return Basis.IDENTITY
	var z_axis := forward.normalized()
	var up_hint := Vector3.UP if absf(z_axis.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var x_axis := up_hint.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


# --- Landmarks ---------------------------------------------------------------


func _build_landmarks() -> void:
	# The one large colour body inside the flyable envelope. The backdrop's four
	# bodies are on a 900-1250 m shell and can never be reached; this one can be
	# circled in well under a minute, which is what makes it a landmark and not a
	# painting. It is solid for the same reason: a body you fly through is a
	# poster.
	var moonlet := StaticBody3D.new()
	moonlet.name = "ReachMoonlet"
	moonlet.position = MOONLET_ANCHOR
	moonlet.collision_layer = WORLD_LAYER
	moonlet.collision_mask = 0
	_landmark_root.add_child(moonlet)
	var moonlet_mesh := SphereMesh.new()
	moonlet_mesh.radius = MOONLET_RADIUS
	moonlet_mesh.height = MOONLET_RADIUS * 2.0
	moonlet_mesh.radial_segments = 48
	moonlet_mesh.rings = 24
	var moonlet_view := MeshInstance3D.new()
	moonlet_view.name = "Mesh"
	moonlet_view.mesh = moonlet_mesh
	moonlet_view.material_override = _materials["moonlet"]
	moonlet_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moonlet.add_child(moonlet_view)
	var moonlet_shape := CollisionShape3D.new()
	moonlet_shape.name = "Collision"
	var moonlet_sphere := SphereShape3D.new()
	moonlet_sphere.radius = MOONLET_RADIUS
	moonlet_shape.shape = moonlet_sphere
	moonlet.add_child(moonlet_shape)

	# Two dust bands rather than one, tilted off the body axis so the moonlet has
	# an orientation to read against while the ship moves.
	var ring_holder := Node3D.new()
	ring_holder.name = "MoonletRings"
	ring_holder.position = MOONLET_ANCHOR
	ring_holder.rotation_degrees = Vector3(18.0, 0.0, -11.0)
	_landmark_root.add_child(ring_holder)
	_torus(ring_holder, "InnerRing", Vector3.ZERO, 116.0, 132.0, _materials["ring"], Vector3.ZERO)
	_torus(ring_holder, "OuterRing", Vector3.ZERO, 140.0, 148.0, _materials["ring_pale"], Vector3.ZERO)

	# Crater rims. A 90 m sphere with one albedo has no scale cue at all: it could
	# be a marble ten metres away or a moon a kilometre off, and the pilot has no
	# way to tell which until they hit it. Six rims of known size fix that, and
	# they are deterministic rather than scattered.
	var crater_random := RandomNumberGenerator.new()
	crater_random.seed = FIELD_SEED + 4111
	for crater_index in MOONLET_CRATER_COUNT:
		var latitude := crater_random.randf_range(-0.75, 0.75)
		var longitude := crater_random.randf_range(-PI, PI)
		var planar := sqrt(maxf(0.0, 1.0 - latitude * latitude))
		var normal := Vector3(planar * cos(longitude), latitude, planar * sin(longitude))
		var rim_radius := crater_random.randf_range(9.0, 21.0)
		var rim := _torus(
			moonlet,
			"CraterRim%d" % (crater_index + 1),
			normal * (MOONLET_RADIUS - rim_radius * 0.22),
			rim_radius,
			rim_radius * 1.28,
			_materials["moonlet_crater"],
			Vector3.ZERO
		)
		# A torus lies in its own XZ plane, so aligning local +Y with the surface
		# normal lays the rim flat on the body instead of standing it on edge.
		rim.basis = _basis_facing(normal) * Basis(Vector3.RIGHT, PI * 0.5)
	_moonlet = moonlet


# --- Debris field ------------------------------------------------------------


func _build_debris_field() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = FIELD_SEED
	var rock_materials: Array = [
		_materials["rock_basalt"],
		_materials["rock_rust"],
		_materials["rock_pale"],
	]
	var attempts := 0
	while _boulder_offsets.size() < BOULDER_COUNT and attempts < BOULDER_COUNT * 80:
		attempts += 1
		var offset := _sample_field_offset(random)
		if not _is_placeable_boulder_offset(offset):
			continue
		var extent := random.randf_range(BOULDER_MINIMUM_EXTENT, BOULDER_MAXIMUM_EXTENT)
		_boulder_offsets.append(offset)
		_build_rock_chunk(
			_field_root,
			"Boulder%02d" % _boulder_offsets.size(),
			PLATFORM_ANCHOR + offset,
			extent,
			random,
			rock_materials[_boulder_offsets.size() % rock_materials.size()] as Material,
			true,
			true
		)
	if _boulder_offsets.size() < BOULDER_COUNT:
		push_error(
			"NearbySectorCluster placed only %d of %d boulders before exhausting attempts"
			% [_boulder_offsets.size(), BOULDER_COUNT]
		)

	_build_debris_chips()


## Fine debris as one instanced set of authored flank clusters. The eight
## clusters make the ordered route read as a corridor through a field while all
## 520 chips remain collision-free in one renderer submission.
func _build_debris_chips() -> void:
	var chip_material := _material(ROCK_BASALT, 0.04, 0.95)
	chip_material.vertex_color_use_as_albedo = true
	var chip_mesh := StationSurfaceKit.rounded_box_mesh_with_bevel(
		Vector3(1.0, 0.72, 1.34), 0.72 * ROCK_BEVEL_PROPORTION
	)
	chip_mesh.surface_set_material(0, chip_material)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = chip_mesh
	multimesh.instance_count = DEBRIS_CHIP_COUNT
	var random := RandomNumberGenerator.new()
	random.seed = DEBRIS_CHIP_SEED
	var placed_chips := 0
	var chip_attempts := 0
	var authored_positions := PackedVector3Array()
	var authored_cluster_indices := PackedInt32Array()
	while placed_chips < DEBRIS_CHIP_COUNT and chip_attempts < DEBRIS_CHIP_COUNT * 20:
		chip_attempts += 1
		var cluster_index := placed_chips % TRAVERSAL_DEBRIS_CLUSTER_SPECS.size()
		var world_position := _sample_traversal_debris_cluster(random, cluster_index)
		if not _is_clear_of_beacon_traversal(world_position, DEBRIS_CHIP_CLEARANCE_MARGIN):
			continue
		var index := placed_chips
		placed_chips += 1
		authored_positions.append(world_position)
		authored_cluster_indices.append(cluster_index)
		var scale_value := random.randf_range(0.7, 2.4)
		var chip_basis := Basis.from_euler(
			Vector3(
				random.randf_range(-PI, PI),
				random.randf_range(-PI, PI),
				random.randf_range(-PI, PI)
			)
		).scaled(
			Vector3(
				scale_value,
				scale_value * random.randf_range(0.55, 1.0),
				scale_value * random.randf_range(0.7, 1.25)
			)
		)
		multimesh.set_instance_transform(index, Transform3D(chip_basis, world_position))
		multimesh.set_instance_color(
			index,
			ROCK_BASALT.lerp(ROCK_RUST if index % 3 == 0 else ROCK_PALE, random.randf_range(0.1, 0.85))
		)
	multimesh.visible_instance_count = placed_chips

	var chips := MultiMeshInstance3D.new()
	chips.name = "DebrisChips"
	chips.multimesh = multimesh
	chips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chips.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	chips.custom_aabb = TRAVERSAL_DEBRIS_PRESENTATION_BOUNDS
	chips.visible = _quality_level >= DetailQuality.MEDIUM
	chips.set_meta(&"presentation_only", true)
	chips.set_meta(&"activity_id", BEACON_TRAVERSAL_ACTIVITY_ID)
	chips.set_meta(&"authored_cluster_count", TRAVERSAL_DEBRIS_CLUSTER_SPECS.size())
	chips.set_meta(&"authored_instance_positions", authored_positions)
	chips.set_meta(&"authored_cluster_indices", authored_cluster_indices)
	_field_root.add_child(chips)


## Uniform-by-volume sample of the flattened field ellipsoid.
func _sample_field_offset(random: RandomNumberGenerator) -> Vector3:
	var y := random.randf_range(-1.0, 1.0)
	var longitude := random.randf_range(-PI, PI)
	var planar := sqrt(maxf(0.0, 1.0 - y * y))
	var direction := Vector3(planar * cos(longitude), y, planar * sin(longitude))
	var radial := pow(random.randf(), 1.0 / 3.0)
	return direction * radial * FIELD_RADII


func _sample_traversal_debris_cluster(
		random: RandomNumberGenerator, cluster_index: int
	) -> Vector3:
	var spec := TRAVERSAL_DEBRIS_CLUSTER_SPECS[cluster_index]
	var y := random.randf_range(-1.0, 1.0)
	var longitude := random.randf_range(-PI, PI)
	var planar := sqrt(maxf(0.0, 1.0 - y * y))
	var direction := Vector3(planar * cos(longitude), y, planar * sin(longitude))
	var radial := pow(random.randf(), 1.0 / 3.0)
	return (spec["center"] as Vector3) + direction * radial * (spec["radii"] as Vector3)


func _is_clear_of_beacon_traversal(world_position: Vector3, geometry_margin: float) -> bool:
	if _distance_to_beacon_traversal(world_position) \
			< BEACON_TRAVERSAL_CORRIDOR_RADIUS + geometry_margin:
		return false
	for spec in ROUTE_BEACON_SPECS:
		if world_position.distance_to(spec["position"] as Vector3) \
				< BEACON_KEEP_CLEAR_RADIUS + geometry_margin:
			return false
	return true


func _distance_to_beacon_traversal(world_position: Vector3) -> float:
	var nearest := INF
	for index in ROUTE_BEACON_SPECS.size() - 1:
		var start := ROUTE_BEACON_SPECS[index]["position"] as Vector3
		var finish := ROUTE_BEACON_SPECS[index + 1]["position"] as Vector3
		var segment := finish - start
		var along := clampf((world_position - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		nearest = minf(nearest, world_position.distance_to(start + segment * along))
	return nearest


## Whether this platform-relative offset is outside both the keep-clear sphere
## around the structure and the lane the pilot flies down to reach it. Shared by
## the boulders and the fine debris shell, because a chip in the gate aperture
## blocks the view exactly as effectively as a rock does.
func _is_clear_of_platform_and_lane(offset: Vector3) -> bool:
	if offset.length() < PLATFORM_KEEP_CLEAR_RADIUS:
		return false
	if offset.z > 0.0 and offset.z < APPROACH_CORRIDOR_LENGTH:
		if Vector2(offset.x, offset.y - GANTRY_CENTER_Y).length() < APPROACH_CORRIDOR_RADIUS:
			return false
	return true


## A boulder may stand here only if it clears the platform, the lane the pilot
## flies down to reach it, every route beacon, and the boulders already placed.
func _is_placeable_boulder_offset(offset: Vector3) -> bool:
	if not _is_clear_of_platform_and_lane(offset):
		return false
	var world_position := PLATFORM_ANCHOR + offset
	if _distance_to_beacon_traversal(world_position) \
			< BEACON_TRAVERSAL_CORRIDOR_RADIUS + BOULDER_MAXIMUM_EXTENT * 0.40:
		return false
	for spec in ROUTE_BEACON_SPECS:
		if world_position.distance_to(spec["position"] as Vector3) < BEACON_KEEP_CLEAR_RADIUS:
			return false
	for placed in _boulder_offsets:
		if offset.distance_to(placed) < BOULDER_MINIMUM_SEPARATION:
			return false
	return true


## One asteroid: three overlapping heavily chamfered boxes under a single sphere
## collider. The visual lobes reach further than the collider on purpose — the
## forgiving side of a hazard the pilot meets at cruise speed.
func _build_rock_chunk(
		parent: Node3D,
		node_name: String,
		chunk_position: Vector3,
		mean_extent: float,
		random: RandomNumberGenerator,
		material: Material,
		collidable: bool,
		tumbling: bool
	) -> Node3D:
	var container: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		container = body
	else:
		container = Node3D.new()
	container.name = node_name
	container.position = chunk_position
	parent.add_child(container)

	var lobes := Node3D.new()
	lobes.name = "Lobes"
	container.add_child(lobes)
	for lobe_index in ROCK_LOBES_PER_BOULDER:
		var size := Vector3(
			snappedf(mean_extent * random.randf_range(0.62, 1.12), 0.05),
			snappedf(mean_extent * random.randf_range(0.50, 0.95), 0.05),
			snappedf(mean_extent * random.randf_range(0.62, 1.12), 0.05)
		)
		var lobe := MeshInstance3D.new()
		lobe.name = "Lobe%d" % (lobe_index + 1)
		lobe.mesh = _rock_mesh(size)
		lobe.material_override = material
		lobe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lobe.position = Vector3(
			random.randf_range(-0.22, 0.22),
			random.randf_range(-0.18, 0.18),
			random.randf_range(-0.22, 0.22)
		) * mean_extent
		lobe.rotation = Vector3(
			random.randf_range(-PI, PI),
			random.randf_range(-PI, PI),
			random.randf_range(-PI, PI)
		)
		lobes.add_child(lobe)

	if collidable:
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		var sphere := SphereShape3D.new()
		sphere.radius = mean_extent * 0.40
		shape.shape = sphere
		container.add_child(shape)

	# Slow tumble, set once and driven from accumulated delta, so the field is
	# alive without a physics body or an animation player anywhere in the
	# cluster. The platform's host rock never tumbles: a structure is bolted to it.
	var axis := Vector3(
		random.randf_range(-1.0, 1.0),
		random.randf_range(-1.0, 1.0),
		random.randf_range(-1.0, 1.0)
	)
	var rate := random.randf_range(0.8, 3.5)
	if tumbling:
		if axis.length_squared() < 0.0001:
			axis = Vector3.UP
		lobes.set_meta(&"spin_axis", axis.normalized())
		lobes.set_meta(&"spin_rate", rate)
		lobes.set_meta(&"rest_basis", lobes.basis)
		_spin_bodies.append(lobes)
	return container


func _rock_mesh(size: Vector3) -> ArrayMesh:
	var key := "rock:%0.2f:%0.2f:%0.2f" % [size.x, size.y, size.z]
	if _rock_mesh_cache.has(key):
		return _rock_mesh_cache[key] as ArrayMesh
	var shortest := minf(size.x, minf(size.y, size.z))
	var mesh := StationSurfaceKit.rounded_box_mesh_with_bevel(size, shortest * ROCK_BEVEL_PROPORTION)
	_rock_mesh_cache[key] = mesh
	return mesh


# --- Extraction platform -----------------------------------------------------


func _build_extraction_platform() -> void:
	var platform := Node3D.new()
	platform.name = "CinderReachPlatform"
	platform.position = PLATFORM_ANCHOR
	_platform_root.add_child(platform)

	# Host body. The platform was built onto a rock, so the rock is part of the
	# silhouette rather than a prop standing beside it.
	var host_random := RandomNumberGenerator.new()
	host_random.seed = FIELD_SEED + 977
	_build_rock_chunk(
		platform,
		"HostAsteroid",
		Vector3(0.0, -46.0, -8.0),
		64.0,
		host_random,
		_materials["rock_rust"],
		true,
		false
	)

	# Core drum and its collars.
	_cylinder(platform, "CoreDrum", Vector3.ZERO, 11.0, 11.0, 26.0, _materials["hull"], true)
	_torus(platform, "DrumCollarUpper", Vector3(0.0, 9.0, 0.0), 11.6, 13.2, _materials["steel"], Vector3(90.0, 0.0, 0.0))
	_torus(platform, "DrumCollarLower", Vector3(0.0, -9.0, 0.0), 11.6, 13.2, _materials["steel"], Vector3(90.0, 0.0, 0.0))
	_cylinder(platform, "DrumCap", Vector3(0.0, 15.0, 0.0), 7.4, 9.2, 5.0, _materials["hull_shadow"], true)

	# Processing spine, running out toward the station so the structure points at
	# the pilot's approach instead of presenting a blank flank.
	_box(platform, "ProcessingSpine", Vector3(0.0, 0.0, SPINE_CENTER_Z), SPINE_SIZE, _materials["hull"], true)
	_build_processing_spine_ribs(platform)
	# Burned-through bays: the abandonment read, done with material rather than a
	# hole, so the collision envelope stays one simple solid spine.
	for z_position in [-18.0, 6.0]:
		for side in [-1.0, 1.0]:
			_box(
				platform,
				"ScorchedBay",
				Vector3(side * 4.62, 0.0, z_position),
				Vector3(0.4, 5.4, 8.0),
				_materials["char"],
				false
			)

	_build_gantry(platform)
	_build_extraction_arms(platform)
	_build_derelict_hardware(platform)
	_build_structure_scan_presentation(platform)
	_build_platform_mast(platform)
	_build_mining_activity_presentation(platform)
	_build_cargo_access(platform)


## Production composition only: the access module owns the physical berth and
## walkable route, while the reusable terminal remains an unbound adapter until
## the caller-owned CargoTransferAuthority/GameFlow composition supplies it a
## registered handle.
func _build_cargo_access(platform: Node3D) -> void:
	_cargo_access = CARGO_ACCESS_SCENE.instantiate() as CinderCargoAccess
	_cargo_access.name = "CinderCargoAccess"
	_cargo_access.transform = CinderCargoAccess.EXTRACTION_PLATFORM_LOCAL_TRANSFORM
	platform.add_child(_cargo_access)
	_cargo_destination_terminal = (
		CARGO_DESTINATION_TERMINAL_SCENE.instantiate() as CargoTransferTerminal
	)
	_cargo_destination_terminal.name = "CargoDestinationTerminal"
	_cargo_destination_terminal.transform = CinderCargoAccess.DESTINATION_TERMINAL_ROOT_LOCAL
	platform.add_child(_cargo_destination_terminal)
	_activity_binding.call(
		"bind_cargo_access",
		_cargo_access,
		_cargo_destination_terminal,
		_cargo_access.get_attachment_generation()
	)


## Original-modern activity silhouette. Every child is presentation-only:
## existing platform bodies remain the collision owner and the RefCounted
## mining activity remains the only progress/reward-request authority.
func _build_mining_activity_presentation(platform: Node3D) -> void:
	var presentation := Node3D.new()
	presentation.name = "MiningActivityPresentation"
	presentation.set_meta(&"presentation_only", true)
	presentation.set_meta(&"activity_id", MINING_ACTIVITY_ID)
	platform.add_child(presentation)

	var approach := Marker3D.new()
	approach.name = "MiningApproachAnchor"
	approach.position = MINING_APPROACH_LOCAL
	presentation.add_child(approach)

	_box(presentation, "HeadframeHeader", Vector3(0.0, 31.0, -4.0), Vector3(28.0, 2.0, 4.0), _materials["hull"], false)
	var leg_transforms: Array[Transform3D] = []
	var brace_transforms: Array[Transform3D] = []
	var chute_transforms: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		leg_transforms.append(Transform3D(Basis.IDENTITY, Vector3(side * 12.0, 20.0, -4.0)))
		brace_transforms.append(Transform3D(
			Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(side * 48.0))),
			Vector3(side * 6.2, 23.0, -4.0)
		))
		chute_transforms.append(Transform3D(
			Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(side * 24.0))),
			Vector3(side * 7.0, 11.0, -2.0)
		))
	_presentation_multimesh_batch(
		presentation, "MiningHeadframeLegs",
		StationSurfaceKit.rounded_box_mesh_cached(Vector3(3.0, 22.0, 3.0), _box_cache),
		_materials["steel"], leg_transforms, &"mining-headframe-legs"
	)
	_presentation_multimesh_batch(
		presentation, "MiningHeadframeBraces",
		StationSurfaceKit.rounded_box_mesh_cached(Vector3(15.0, 1.2, 2.0), _box_cache),
		_materials["orange"], brace_transforms, &"mining-headframe-braces"
	)
	_presentation_multimesh_batch(
		presentation, "MiningFeedChutes",
		StationSurfaceKit.rounded_box_mesh_cached(Vector3(3.0, 13.0, 3.0), _box_cache),
		_materials["hull_shadow"], chute_transforms, &"mining-feed-chutes"
	)

	_cylinder(presentation, "OreSeparatorHopper", Vector3(0.0, 19.0, -4.0), 5.5, 2.0, 9.0, _materials["hull"], false)
	_cylinder(presentation, "HopperServiceBand", Vector3(0.0, 15.0, -4.0), 5.8, 5.8, 0.7, _materials["orange"], false)
	var bin_transforms: Array[Transform3D] = []
	var bin_band_transforms: Array[Transform3D] = []
	for bin_index in 3:
		var bin_x := -8.0 + float(bin_index) * 8.0
		bin_transforms.append(Transform3D(Basis.IDENTITY, Vector3(bin_x, 4.0, 11.0)))
		bin_band_transforms.append(Transform3D(Basis.IDENTITY, Vector3(bin_x, 4.0, 11.0)))
	_presentation_multimesh_batch(
		presentation, "MiningOreBufferBins",
		StationSurfaceKit.chamfered_cylinder_mesh_cached(
			2.6, 3.2, 7.0, 24, _cylinder_cache, 4, true, true
		), _materials["hull_shadow"], bin_transforms, &"mining-ore-buffer-bins"
	)
	var collector_bands := _presentation_multimesh_batch(
		presentation, "MiningOreBufferBands",
		StationSurfaceKit.rounded_box_mesh_cached(Vector3(6.6, 0.8, 6.6), _box_cache),
		_materials["steel"], bin_band_transforms, &"mining-ore-buffer-bands"
	)
	# The retained bands travel only inside their fixed collectors. Expand the
	# batch culling bounds once for that complete presentation range; snapshots
	# subsequently change transforms only and never allocate geometry.
	for full_transform in _mining_collector_band_transforms(1.0):
		collector_bands.custom_aabb = collector_bands.custom_aabb.merge(
			(full_transform * collector_bands.multimesh.mesh.get_aabb()).abs()
		)
	for failed_transform in _mining_collector_band_transforms(0.0, true):
		collector_bands.custom_aabb = collector_bands.custom_aabb.merge(
			(failed_transform * collector_bands.multimesh.mesh.get_aabb()).abs()
		)

	_lamp(presentation, "MiningCrownLampPort", Vector3(-12.0, 33.0, 0.0), KETH_CYAN, 2.0, 24.0, false)
	_lamp(presentation, "MiningCrownLampStarboard", Vector3(12.0, 33.0, 0.0), KETH_ORANGE, 2.0, 24.0, false)
	_sign(presentation, "ORE EXTRACTION", Vector3(0.0, 27.0, 18.0), Vector3.ZERO, 2.4, _materials["orange_glow"])
	_activity_binding.call(
		"bind_mining_presentation",
		Callable(self, "_apply_mining_activity_presentation")
	)


## Reuses the two crown practicals, fixed sign, ore-buffer bands, and hopper
## service ring to distinguish available, extracting, secured, and reset states.
## It consumes authority snapshots only; no node/resource is allocated and no
## progress is inferred from world state.
func _apply_mining_activity_presentation(snapshot: Dictionary) -> Dictionary:
	if StringName(snapshot.get("activity_id", &"")) != MINING_ACTIVITY_ID:
		return {"accepted": false, "reason": &"wrong_activity_snapshot"}
	var generation := int(snapshot.get("generation", -1))
	var state := int(snapshot.get("state", -1))
	var terminal_outcome := StringName(snapshot.get("terminal_outcome", &""))
	var elapsed := float(snapshot.get("elapsed_seconds", -1.0))
	var duration := float(snapshot.get("extraction_seconds", 0.0))
	if generation < 0 or state < 0 or state > 3 or elapsed < 0.0 or duration <= 0.0 \
			or terminal_outcome not in [&"", &"failed"]:
		return {"accepted": false, "reason": &"invalid_activity_snapshot"}
	var presentation := get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/MiningActivityPresentation"
	) as Node3D
	if presentation == null:
		return {"accepted": false, "reason": &"presentation_unavailable"}
	var port := presentation.get_node_or_null(^"MiningCrownLampPort") as OmniLight3D
	var starboard := presentation.get_node_or_null(^"MiningCrownLampStarboard") as OmniLight3D
	var port_lens := presentation.get_node_or_null(^"MiningCrownLampPortLens") as MeshInstance3D
	var starboard_lens := presentation.get_node_or_null(^"MiningCrownLampStarboardLens") as MeshInstance3D
	var sign := presentation.get_node_or_null(^"Sign_ORE_EXTRACTION") as MeshInstance3D
	var collector_bands := presentation.get_node_or_null(^"MiningOreBufferBands") as MultiMeshInstance3D
	var hopper_band := presentation.get_node_or_null(^"HopperServiceBand") as MeshInstance3D
	if port == null or starboard == null or port_lens == null or starboard_lens == null \
			or sign == null or collector_bands == null or collector_bands.multimesh == null \
			or hopper_band == null:
		return {"accepted": false, "reason": &"presentation_roster_incomplete"}
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var collector_levels := _mining_collector_levels(progress)
	var failed := terminal_outcome == &"failed"
	var collector_transforms := _mining_collector_band_transforms(progress, failed)
	collector_bands.multimesh.buffer = _mining_collector_transform_buffer(
		collector_transforms
	)
	var state_id: StringName = &"available"
	port.light_color = KETH_CYAN
	starboard.light_color = KETH_ORANGE
	port_lens.material_override = _lens_material(KETH_CYAN)
	starboard_lens.material_override = _lens_material(KETH_ORANGE)
	port.light_energy = 0.7
	starboard.light_energy = 0.7
	sign.material_override = _materials["orange_glow"]
	sign.scale = Vector3.ONE * 2.4
	hopper_band.scale = Vector3.ONE
	if failed:
		state_id = &"failed"
		port.light_energy = 0.2
		starboard.light_energy = 3.5
		sign.material_override = _materials["orange_glow"]
		sign.scale = Vector3(2.05, 2.8, 2.05)
		hopper_band.scale = MINING_FAILED_HOPPER_SCALE
	elif state == CinderMiningPlatformActivity.State.ACTIVE:
		state_id = &"extracting"
		port.light_energy = lerpf(1.4, 3.2, progress)
		starboard.light_energy = lerpf(3.2, 1.4, progress)
		sign.material_override = _materials["cyan_glow"]
		sign.scale = Vector3.ONE * 2.55
	elif state == CinderMiningPlatformActivity.State.COMPLETE:
		state_id = &"secured"
		port.light_energy = 3.4
		starboard.light_energy = 3.4
		starboard.light_color = KETH_CYAN
		starboard_lens.material_override = _lens_material(KETH_CYAN)
		sign.material_override = _materials["cyan_glow"]
		sign.scale = Vector3.ONE * 2.75
		hopper_band.scale = MINING_CAPACITY_HOPPER_SCALE
	elif state == CinderMiningPlatformActivity.State.RESET:
		state_id = &"reset"
		port.light_energy = 0.35
		starboard.light_energy = 0.35
	# IDLE retains the authored available state through the defaults above.
	_mining_presentation_snapshot = {
		"activity_id": MINING_ACTIVITY_ID,
		"state_id": state_id,
		"authority_state": state,
		"generation": generation,
		"progress": progress,
		"port_energy": port.light_energy,
		"starboard_energy": starboard.light_energy,
		"port_color": port.light_color,
		"starboard_color": starboard.light_color,
		"sign_scale": sign.scale.x,
		"collector_levels": collector_levels,
		"collector_band_heights": collector_transforms.map(
			func(transform_value: Transform3D) -> float: return transform_value.origin.y
		),
		"capacity_ready_geometry": hopper_band.scale.is_equal_approx(
			MINING_CAPACITY_HOPPER_SCALE
		),
		"failure_geometry": failed,
		"hopper_scale": hopper_band.scale,
		"node_delta": MINING_PRESENTATION_STATE_NODE_DELTA,
		"light_delta": MINING_PRESENTATION_STATE_LIGHT_DELTA,
		"submission_delta": MINING_PRESENTATION_STATE_SUBMISSION_DELTA,
		"activity_authority": false,
		"reward_authority": false,
	}.duplicate(true)
	return {"accepted": true, "reason": &"mining_presentation_applied"}


func _mining_collector_levels(progress: float) -> Array[float]:
	var levels: Array[float] = []
	for collector_index in MINING_COLLECTOR_COUNT:
		levels.append(clampf(
			progress * float(MINING_COLLECTOR_COUNT) - float(collector_index),
			0.0,
			1.0
		))
	return levels


func _mining_collector_band_transforms(
	progress: float, failed: bool = false
	) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var levels := _mining_collector_levels(progress)
	for collector_index in MINING_COLLECTOR_COUNT:
		var basis := Basis.IDENTITY
		if failed:
			basis = Basis.from_euler(Vector3(
				0.0, 0.0, deg_to_rad(MINING_FAILED_BAND_TURNS[collector_index])
			))
		transforms.append(Transform3D(
			basis,
			Vector3(
				-8.0 + float(collector_index) * 8.0,
				lerpf(
					MINING_COLLECTOR_BAND_IDLE_Y,
					MINING_COLLECTOR_BAND_FULL_Y,
					levels[collector_index]
				),
				11.0
			)
		))
	return transforms


func _mining_collector_transform_buffer(
		transforms: Array[Transform3D]
	) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for transform_index in transforms.size():
		var transform_value := transforms[transform_index]
		var offset := transform_index * 12
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


func get_mining_activity_presentation_state() -> Dictionary:
	return _mining_presentation_snapshot.duplicate(true)


## A fractured datum frame visually gathers the already-authored torn habitat,
## dead solar wing, and loose shards into one approach read. It carries no body,
## Area, progress state, scan callback, or reward path.
func _build_structure_scan_presentation(platform: Node3D) -> void:
	var presentation := Node3D.new()
	presentation.name = "AbandonedStructureScanPresentation"
	presentation.set_meta(&"presentation_only", true)
	presentation.set_meta(&"activity_id", STRUCTURE_SCAN_ACTIVITY_ID)
	platform.add_child(presentation)

	var approach := Marker3D.new()
	approach.name = "StructureScanApproachAnchor"
	approach.position = STRUCTURE_SCAN_APPROACH_LOCAL
	presentation.add_child(approach)

	_box(presentation, "SurveyPylonPort", Vector3(-22.0, 13.0, -5.0), Vector3(3.0, 30.0, 3.0), _materials["char"], false, Vector3(0.0, 0.0, -8.0))
	_box(presentation, "SurveyPylonStarboard", Vector3(22.0, 12.0, -5.0), Vector3(3.0, 29.0, 3.0), _materials["hull_shadow"], false, Vector3(0.0, 0.0, 13.0))
	_box(presentation, "FracturedHeaderPort", Vector3(-11.5, 28.0, -5.0), Vector3(20.0, 2.5, 3.0), _materials["steel"], false, Vector3(0.0, 0.0, 6.0))
	_box(presentation, "FracturedHeaderStarboard", Vector3(11.5, 27.0, -5.0), Vector3(19.0, 2.5, 3.0), _materials["char"], false, Vector3(0.0, 0.0, -11.0))
	_box(presentation, "FractureBracePort", Vector3(-12.0, 16.0, -5.0), Vector3(25.0, 1.2, 2.0), _materials["hull_shadow"], false, Vector3(0.0, 0.0, 44.0))
	_box(presentation, "FractureBraceStarboard", Vector3(12.0, 15.0, -5.0), Vector3(24.0, 1.2, 2.0), _materials["steel"], false, Vector3(0.0, 0.0, -49.0))
	_box(presentation, "DeadArrayBoom", Vector3(20.0, 12.0, -1.0), Vector3(2.0, 2.0, 22.0), _materials["char"], false, Vector3(8.0, -7.0, 0.0))
	_cylinder(presentation, "DeadArrayReceiver", Vector3(20.0, 15.0, 8.0), 2.0, 6.0, 5.0, _materials["solar_dead"], false, Vector3(90.0, 0.0, 0.0))
	_cylinder(presentation, "DeadArrayCollar", Vector3(20.0, 15.0, 5.0), 2.8, 2.8, 0.8, _materials["orange"], false, Vector3(90.0, 0.0, 0.0))
	_box(presentation, "HullRuptureShard01", Vector3(17.0, 7.0, -13.0), Vector3(7.0, 1.0, 3.0), _materials["char"], false, Vector3(18.0, 25.0, 14.0))
	_box(presentation, "HullRuptureShard02", Vector3(29.0, 13.0, -10.0), Vector3(5.0, 1.2, 4.0), _materials["hull_shadow"], false, Vector3(-12.0, -16.0, 31.0))
	_box(presentation, "HullRuptureShard03", Vector3(24.0, 3.0, -17.0), Vector3(6.0, 1.0, 2.5), _materials["steel"], false, Vector3(34.0, 10.0, -22.0))

	_lamp(presentation, "DerelictDatumLampPort", Vector3(-22.0, 28.0, 0.0), KETH_ORANGE, 1.1, 20.0, false)
	_lamp(presentation, "DerelictDatumLampStarboard", Vector3(22.0, 27.0, 0.0), MOONLET_TEAL, 0.8, 18.0, false)
	_sign(presentation, "DERELICT SCAN", Vector3(0.0, 23.0, 4.0), Vector3.ZERO, 2.0, _materials["orange_glow"])
	_activity_binding.call(
		"bind_structure_scan_presentation",
		Callable(self, "_apply_structure_scan_activity_presentation")
	)


## Detached scan state drives only the existing datum practicals, sign, dead
## receiver, and receiver collar. Collision, scan progression, completion, and
## reward requests remain external.
func _apply_structure_scan_activity_presentation(snapshot: Dictionary) -> Dictionary:
	if StringName(snapshot.get("activity_id", &"")) != STRUCTURE_SCAN_ACTIVITY_ID:
		return {"accepted": false, "reason": &"wrong_activity_snapshot"}
	var generation := int(snapshot.get("generation", -1))
	var state := int(snapshot.get("state", -1))
	var elapsed := float(snapshot.get("elapsed_seconds", -1.0))
	var duration := float(snapshot.get("scan_seconds", 0.0))
	var terminal_outcome := StringName(snapshot.get("terminal_outcome", &""))
	if generation < 0 or state < 0 or state > 3 or elapsed < 0.0 or duration <= 0.0 \
			or terminal_outcome not in [&"", &"failed", &"aborted"]:
		return {"accepted": false, "reason": &"invalid_activity_snapshot"}
	var presentation := get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/AbandonedStructureScanPresentation"
	) as Node3D
	if presentation == null:
		return {"accepted": false, "reason": &"presentation_unavailable"}
	var port := presentation.get_node_or_null(^"DerelictDatumLampPort") as OmniLight3D
	var starboard := presentation.get_node_or_null(^"DerelictDatumLampStarboard") as OmniLight3D
	var port_lens := presentation.get_node_or_null(^"DerelictDatumLampPortLens") as MeshInstance3D
	var starboard_lens := presentation.get_node_or_null(^"DerelictDatumLampStarboardLens") as MeshInstance3D
	var sign := presentation.get_node_or_null(^"Sign_DERELICT_SCAN") as MeshInstance3D
	var receiver := presentation.get_node_or_null(^"DeadArrayReceiver") as MeshInstance3D
	var receiver_collar := presentation.get_node_or_null(^"DeadArrayCollar") as MeshInstance3D
	if port == null or starboard == null or port_lens == null or starboard_lens == null \
			or sign == null or receiver == null or receiver_collar == null:
		return {"accepted": false, "reason": &"presentation_roster_incomplete"}
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var receiver_rotation := STRUCTURE_SCAN_RECEIVER_IDLE_ROTATION.lerp(
		STRUCTURE_SCAN_RECEIVER_RESOLVED_ROTATION, progress
	)
	var collar_position := STRUCTURE_SCAN_COLLAR_IDLE_POSITION.lerp(
		STRUCTURE_SCAN_COLLAR_RESOLVED_POSITION, progress
	)
	receiver.rotation_degrees = receiver_rotation
	receiver.scale = Vector3.ONE
	receiver_collar.rotation_degrees = receiver_rotation
	receiver_collar.position = collar_position
	receiver_collar.scale = Vector3.ONE
	var state_id: StringName = &"available"
	port.light_color = KETH_ORANGE
	starboard.light_color = MOONLET_TEAL
	port_lens.material_override = _lens_material(KETH_ORANGE)
	starboard_lens.material_override = _lens_material(MOONLET_TEAL)
	port.light_energy = 0.45
	starboard.light_energy = 0.45
	sign.material_override = _materials["orange_glow"]
	sign.scale = Vector3.ONE * 2.0
	match state:
		CinderAbandonedStructureScanActivity.State.SCANNING:
			state_id = &"scanning"
			port.light_energy = lerpf(2.6, 0.9, progress)
			starboard.light_energy = lerpf(0.9, 2.6, progress)
			sign.material_override = _materials["cyan_glow"]
			sign.scale = Vector3.ONE * 2.15
		CinderAbandonedStructureScanActivity.State.COMPLETE:
			state_id = &"completed"
			port.light_color = KETH_CYAN
			starboard.light_color = KETH_CYAN
			port_lens.material_override = _lens_material(KETH_CYAN)
			starboard_lens.material_override = _lens_material(KETH_CYAN)
			port.light_energy = 2.8
			starboard.light_energy = 2.8
			sign.material_override = _materials["cyan_glow"]
			sign.scale = Vector3.ONE * 2.35
			receiver.scale = STRUCTURE_SCAN_COMPLETE_RECEIVER_SCALE
			receiver_collar.scale = STRUCTURE_SCAN_COMPLETE_COLLAR_SCALE
		CinderAbandonedStructureScanActivity.State.RESET:
			state_id = &"reset"
			port.light_energy = 0.2
			starboard.light_energy = 0.2
		_:
			pass
	if terminal_outcome in [&"failed", &"aborted"]:
		state_id = terminal_outcome
		receiver.rotation_degrees = STRUCTURE_SCAN_FAILED_RECEIVER_ROTATION
		receiver.scale = STRUCTURE_SCAN_FAILED_RECEIVER_SCALE
		receiver_collar.rotation_degrees = STRUCTURE_SCAN_FAILED_COLLAR_ROTATION
		receiver_collar.position = STRUCTURE_SCAN_FAILED_COLLAR_POSITION
		receiver_collar.scale = STRUCTURE_SCAN_FAILED_COLLAR_SCALE
	_structure_scan_presentation_snapshot = {
		"activity_id": STRUCTURE_SCAN_ACTIVITY_ID,
		"state_id": state_id,
		"authority_state": state,
		"generation": generation,
		"progress": progress,
		"port_energy": port.light_energy,
		"starboard_energy": starboard.light_energy,
		"port_color": port.light_color,
		"starboard_color": starboard.light_color,
		"sign_scale": sign.scale.x,
		"receiver_rotation_degrees": receiver.rotation_degrees,
		"receiver_scale": receiver.scale,
		"receiver_collar_position": receiver_collar.position,
		"receiver_collar_scale": receiver_collar.scale,
		"complete_geometry": receiver.scale.is_equal_approx(
			STRUCTURE_SCAN_COMPLETE_RECEIVER_SCALE
		) and receiver_collar.scale.is_equal_approx(
			STRUCTURE_SCAN_COMPLETE_COLLAR_SCALE
		),
		"failure_geometry": terminal_outcome in [&"failed", &"aborted"] \
			and receiver.rotation_degrees.is_equal_approx(
				STRUCTURE_SCAN_FAILED_RECEIVER_ROTATION
			) and receiver.scale.is_equal_approx(
				STRUCTURE_SCAN_FAILED_RECEIVER_SCALE
			) and receiver_collar.rotation_degrees.is_equal_approx(
				STRUCTURE_SCAN_FAILED_COLLAR_ROTATION
			) and receiver_collar.position.is_equal_approx(
				STRUCTURE_SCAN_FAILED_COLLAR_POSITION
			) and receiver_collar.scale.is_equal_approx(
				STRUCTURE_SCAN_FAILED_COLLAR_SCALE
			),
		"node_delta": STRUCTURE_SCAN_PRESENTATION_STATE_NODE_DELTA,
		"light_delta": STRUCTURE_SCAN_PRESENTATION_STATE_LIGHT_DELTA,
		"submission_delta": STRUCTURE_SCAN_PRESENTATION_STATE_SUBMISSION_DELTA,
		"scan_authority": false,
		"reward_authority": false,
	}.duplicate(true)
	return {"accepted": true, "reason": &"structure_scan_presentation_applied"}


func get_structure_scan_presentation_state() -> Dictionary:
	return _structure_scan_presentation_snapshot.duplicate(true)


## Four identical visual-only ribs use the exact cached bevel mesh, steel
## material and authored local transforms they had as separate MeshInstances.
## They own no collision, interaction, animation, evidence or gameplay path, so
## one MultiMesh submission preserves the visible copies and triangles while
## removing three renderer nodes/submissions from this bounded component.
func _build_processing_spine_ribs(platform: Node3D) -> void:
	var transforms: Array[Transform3D] = []
	for z_position in PROCESSING_SPINE_RIB_Z_POSITIONS:
		transforms.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, z_position)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = StationSurfaceKit.rounded_box_mesh_cached(
		PROCESSING_SPINE_RIB_SIZE, _box_cache
	)
	multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = -1
	# Bulk-author the renderer payload so the exact 12-float transform record is
	# auditable even when the headless backend exposes identity transform reads.
	multimesh.buffer = _encode_multimesh_transforms(transforms)
	# Raw-buffer MultiMeshes do not derive a CPU AABB under headless. Publish the
	# transformed union explicitly so renderer culling matches the four old nodes.
	multimesh.custom_aabb = _transformed_mesh_bounds(multimesh.mesh.get_aabb(), transforms)
	var batch := MultiMeshInstance3D.new()
	batch.name = "ProcessingSpineRibs"
	batch.multimesh = multimesh
	batch.material_override = _materials["steel"]
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta(&"visual_detail_only", true)
	batch.set_meta(&"visual_batch_family_id", PROCESSING_SPINE_RIB_FAMILY_ID)
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	platform.add_child(batch)


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


## The reason to come out here: two open frames the ship fits through with room
## to spare, lit around the aperture so the opening is legible on approach. Both
## frames stand on the approach lane the boulder scatter is forbidden to enter,
## so the run in is clear whatever the field seed produces.
func _build_gantry(platform: Node3D) -> void:
	var half_width := GANTRY_CLEAR_WIDTH * 0.5
	var half_height := GANTRY_CLEAR_HEIGHT * 0.5
	for frame_index in 2:
		var z_position := GANTRY_NEAR_Z if frame_index == 0 else GANTRY_FAR_Z
		var frame := Node3D.new()
		frame.name = "GantryFrame%d" % (frame_index + 1)
		frame.position = Vector3(0.0, GANTRY_CENTER_Y, z_position)
		platform.add_child(frame)
		var span := GANTRY_CLEAR_WIDTH + GANTRY_BEAM * 2.0
		_box(
			frame,
			"Header",
			Vector3(0.0, half_height + GANTRY_BEAM * 0.5, 0.0),
			Vector3(span, GANTRY_BEAM, 4.0),
			_materials["hull"],
			true
		)
		_box(
			frame,
			"Sill",
			Vector3(0.0, -half_height - GANTRY_BEAM * 0.5, 0.0),
			Vector3(span, GANTRY_BEAM, 4.0),
			_materials["hull"],
			true
		)
		for side in [-1.0, 1.0]:
			_box(
				frame,
				"Post",
				Vector3(side * (half_width + GANTRY_BEAM * 0.5), 0.0, 0.0),
				Vector3(GANTRY_BEAM, GANTRY_CLEAR_HEIGHT, 4.0),
				_materials["hull"],
				true
			)
			_box(
				frame,
				"CornerBrace",
				Vector3(side * (half_width - 2.0), half_height - 2.0, 0.0),
				Vector3(7.0, 0.8, 2.4),
				_materials["steel"],
				false,
				Vector3(0.0, 0.0, side * 38.0)
			)
		# Aperture lamps: low energy, short range. They mark the opening from
		# outside without washing out the structure the ship is about to pass.
		for corner_x in [-1.0, 1.0]:
			for corner_y in [-1.0, 1.0]:
				_lamp(
					frame,
					"ApertureLamp",
					Vector3(corner_x * (half_width - 1.0), corner_y * (half_height - 1.0), 2.2),
					KETH_CYAN,
					1.9,
					16.0,
					frame_index == 0
				)

	# Rails linking the two frames into a short tunnel rather than two loose rings.
	_build_gantry_rails(platform, half_width, half_height)
	_sign(
		platform,
		"CINDER REACH DOCK GATE",
		Vector3(0.0, GANTRY_CENTER_Y + half_height + GANTRY_BEAM + 3.5, GANTRY_NEAR_Z),
		Vector3.ZERO,
		2.4,
		_materials["cyan_glow"]
	)
	# Platform signage sits above the spine's front face, so it is read once the
	# pilot is through the gate and still has 60 m to slow down.
	_sign(platform, "CINDER REACH", Vector3(0.0, 26.0, 20.0), Vector3.ZERO, 5.0, _materials["orange_glow"])
	_sign(
		platform,
		"EXTRACTION PLATFORM - DERELICT",
		Vector3(0.0, 21.0, 20.0),
		Vector3.ZERO,
		2.2,
		_materials["cyan_glow"]
	)


## The four rails have one exact rounded-box recipe, material and no gameplay or
## collision authority. One MultiMesh retains the authored four-copy tunnel while
## removing three renderer nodes and submissions from the nearby-sector cluster.
func _build_gantry_rails(platform: Node3D, half_width: float, half_height: float) -> void:
	var transforms: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for rail_y in [-1.0, 1.0]:
			transforms.append(
				Transform3D(
					Basis.IDENTITY,
					Vector3(
						side * (half_width + 1.5),
						GANTRY_CENTER_Y + rail_y * (half_height + 1.5),
						(GANTRY_NEAR_Z + GANTRY_FAR_Z) * 0.5
					)
				)
			)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = StationSurfaceKit.rounded_box_mesh_cached(GANTRY_RAIL_SIZE, _box_cache)
	multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = -1
	multimesh.buffer = _encode_multimesh_transforms(transforms)
	multimesh.custom_aabb = _transformed_mesh_bounds(multimesh.mesh.get_aabb(), transforms)
	var batch := MultiMeshInstance3D.new()
	batch.name = "GantryRails"
	batch.multimesh = multimesh
	batch.material_override = _materials["steel"]
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta(&"visual_detail_only", true)
	batch.set_meta(&"visual_batch_family_id", GANTRY_RAIL_FAMILY_ID)
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	platform.add_child(batch)


func _build_extraction_arms(platform: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ExtractionArm%s" % ("Port" if side < 0.0 else "Starboard")
		arm.position = Vector3(side * 12.0, -8.0, -6.0)
		arm.rotation_degrees = Vector3(-36.0, 0.0, side * 14.0)
		platform.add_child(arm)
		_box(arm, "ArmSpar", Vector3(0.0, -17.0, 0.0), Vector3(4.4, 38.0, 4.4), _materials["hull_shadow"], true)
		_build_extraction_arm_collars(arm)
		_cylinder(arm, "DrillHead", Vector3(0.0, -37.5, 0.0), 1.2, 3.6, 6.0, _materials["orange"], true)
		_lamp(arm, "ArmLamp", Vector3(0.0, -33.0, 3.6), KETH_ORANGE, 1.5, 12.0, false)


## Each arm retains its authored transform and canonical ArmCollar path while
## three identical, presentation-only steel collars submit as one renderer.
## The arm spar and drill stay collision-backed; this batch owns no authority.
func _build_extraction_arm_collars(arm: Node3D) -> void:
	var transforms: Array[Transform3D] = []
	for y_position in EXTRACTION_ARM_COLLAR_Y_POSITIONS:
		transforms.append(Transform3D(Basis.IDENTITY, Vector3(0.0, y_position, 0.0)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = StationSurfaceKit.rounded_box_mesh_cached(
		EXTRACTION_ARM_COLLAR_SIZE, _box_cache
	)
	multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = -1
	multimesh.buffer = _encode_multimesh_transforms(transforms)
	var bounds := _transformed_mesh_bounds(multimesh.mesh.get_aabb(), transforms)
	multimesh.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "ArmCollar"
	batch.multimesh = multimesh
	batch.material_override = _materials["steel"]
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.custom_aabb = bounds
	batch.set_meta(&"visual_detail_only", true)
	batch.set_meta(&"visual_batch_family_id", EXTRACTION_ARM_COLLAR_FAMILY_ID)
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	batch.set_meta(&"authored_instance_names", PackedStringArray(["ArmCollar", "ArmCollar", "ArmCollar"]))
	arm.add_child(batch)


func _build_derelict_hardware(platform: Node3D) -> void:
	# A habitat can torn open at one end. Leaving the cap off is not a texture
	# trick: the builder is asked for an uncapped cylinder, so the interior wall
	# is real geometry the pilot can look down.
	var can := Node3D.new()
	can.name = "DerelictHabitatCan"
	can.position = Vector3(25.0, 9.0, -12.0)
	can.rotation_degrees = Vector3(0.0, 12.0, 90.0)
	platform.add_child(can)
	_cylinder(can, "CanShell", Vector3.ZERO, 6.0, 6.0, 18.0, _materials["hull_shadow"], true, Vector3.ZERO, false, true)
	_torus(can, "CanTornRim", Vector3(0.0, 9.0, 0.0), 5.6, 6.3, _materials["char"], Vector3(90.0, 0.0, 0.0))
	_box(can, "CanSpine", Vector3(0.0, -10.4, 0.0), Vector3(2.0, 3.0, 2.0), _materials["steel"], false)

	# Two solar wings, one still oriented and one collapsed off its hinge. The
	# broken one is the fastest read that this place stopped working.
	var wing_intact := Node3D.new()
	wing_intact.name = "SolarWingIntact"
	wing_intact.position = Vector3(-32.0, 11.0, -2.0)
	wing_intact.rotation_degrees = Vector3(0.0, 0.0, 6.0)
	platform.add_child(wing_intact)
	_box(wing_intact, "Panel", Vector3.ZERO, Vector3(42.0, 0.7, 15.0), _materials["solar"], false)
	_box(wing_intact, "Boom", Vector3(20.0, 0.0, 0.0), Vector3(10.0, 1.2, 1.2), _materials["steel"], true)

	var wing_broken := Node3D.new()
	wing_broken.name = "SolarWingCollapsed"
	wing_broken.position = Vector3(31.0, -6.0, -22.0)
	wing_broken.rotation_degrees = Vector3(12.0, 8.0, 58.0)
	platform.add_child(wing_broken)
	_box(wing_broken, "Panel", Vector3.ZERO, Vector3(34.0, 0.7, 15.0), _materials["solar_dead"], false)
	_box(wing_broken, "Boom", Vector3(-17.0, 0.0, 0.0), Vector3(10.0, 1.2, 1.2), _materials["char"], false)

	# Ore chutes hanging under the drum toward the host rock.
	for side in [-1.0, 1.0]:
		_cylinder(
			platform,
			"OreChute",
			Vector3(side * 6.0, -16.0, 2.0),
			2.4,
			2.0,
			22.0,
			_materials["steel"],
			true,
			Vector3(side * 9.0, 0.0, side * 7.0)
		)


func _build_platform_mast(platform: Node3D) -> void:
	_cylinder(platform, "SignalMast", Vector3(0.0, 25.0, 0.0), 1.1, 1.5, 16.0, _materials["steel"], true)
	var head := Node3D.new()
	head.name = "HazardBeaconHead"
	head.position = Vector3(0.0, 34.0, 0.0)
	platform.add_child(head)
	_box(head, "HeadShell", Vector3.ZERO, Vector3(2.6, 1.8, 2.6), _materials["hull_shadow"], false)
	_box(head, "HeadLens", Vector3(0.0, 0.0, 1.5), Vector3(1.6, 1.2, 0.5), _materials["orange_glow"], false)
	var hazard := SpotLight3D.new()
	hazard.name = "HazardBeacon"
	hazard.position = Vector3(0.0, 0.0, 1.4)
	hazard.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	hazard.light_color = KETH_ORANGE
	hazard.light_energy = 6.0
	hazard.spot_range = 90.0
	hazard.spot_angle = 21.0
	hazard.shadow_enabled = false
	head.add_child(hazard)
	_hazard_head = head


# --- Shared builders ---------------------------------------------------------


func _create_materials() -> void:
	_materials["steel"] = _panel_material(STEEL_BLUE, 0.5, 0.36, 0.12)
	_materials["hull"] = _panel_material(HULL_OCHRE, 0.2, 0.66, 0.075)
	_materials["hull_shadow"] = _panel_material(HULL_SHADOW, 0.3, 0.7, 0.1)
	_materials["char"] = _material(HULL_CHAR, 0.1, 0.94)
	_materials["orange"] = _material(KETH_ORANGE, 0.1, 0.56)
	_materials["rock_basalt"] = _material(ROCK_BASALT, 0.04, 0.93)
	_materials["rock_rust"] = _material(ROCK_RUST, 0.06, 0.9)
	_materials["rock_pale"] = _material(ROCK_PALE, 0.05, 0.88)
	_materials["moonlet"] = _material(MOONLET_TEAL, 0.0, 0.94)
	_materials["ring"] = _material(MOONLET_RING, 0.0, 1.0)
	_materials["ring_pale"] = _material(MOONLET_RING.darkened(0.18), 0.0, 1.0)
	_materials["moonlet_crater"] = _material(MOONLET_TEAL.darkened(0.42), 0.0, 0.96)
	_materials["solar"] = _material(Color("15384a"), 0.55, 0.24, Color("1d6f7f"), 0.35)
	_materials["solar_dead"] = _material(Color("101820"), 0.4, 0.72)
	_materials["cyan_glow"] = _material(KETH_CYAN, 0.0, 0.28, KETH_CYAN, 1.5)
	_materials["orange_glow"] = _material(KETH_ORANGE, 0.0, 0.3, KETH_ORANGE, 1.4)


func _material(
		color: Color,
		metallic: float = 0.0,
		roughness: float = 0.65,
		emission_color: Color = Color.TRANSPARENT,
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	# The same per-pixel/Burley/Schlick-GGX trio the station hub and the modules
	# already answer light with, so the cluster does not shade differently from
	# the place the pilot just left.
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	result.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	result.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
	return result


## Manufactured surfaces in the cluster take the registered station panel recipe,
## because the platform is built stock, not rock. `apply_panel_triplanar` returns
## false when the maps are unavailable; the untextured PBR values are then left
## exactly as set rather than half a recipe being bound.
func _panel_material(
		color: Color,
		metallic: float,
		roughness: float,
		uv_scale: float
	) -> StandardMaterial3D:
	var result := _material(color, metallic, roughness)
	StationSurfaceKit.apply_panel_triplanar(result, uv_scale)
	return result


func _lens_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if not _lens_materials.has(key):
		_lens_materials[key] = _material(color, 0.0, 0.25, color, 1.6)
	return _lens_materials[key] as StandardMaterial3D


func _shared_lamp_lens_mesh() -> SphereMesh:
	if not is_instance_valid(_lamp_lens_mesh):
		_lamp_lens_mesh = SphereMesh.new()
		_lamp_lens_mesh.radius = LAMP_LENS_RADIUS
		_lamp_lens_mesh.height = LAMP_LENS_HEIGHT
		_lamp_lens_mesh.radial_segments = LAMP_LENS_RADIAL_SEGMENTS
		_lamp_lens_mesh.rings = LAMP_LENS_RINGS
	return _lamp_lens_mesh


func _presentation_multimesh_batch(
		parent: Node3D,
		node_name: String,
		mesh: Mesh,
		material: Material,
		transforms: Array[Transform3D],
		family_id: StringName
	) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	var bounds := AABB()
	var first_bound := true
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
		var instance_bounds := (transform_value * mesh.get_aabb()).abs()
		if first_bound:
			bounds = instance_bounds
			first_bound = false
		else:
			bounds = bounds.merge(instance_bounds)
	multimesh.buffer = buffer
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.custom_aabb = bounds
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"visual_batch_family_id", family_id)
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


func _box(
		parent: Node3D,
		node_name: String,
		box_position: Vector3,
		size: Vector3,
		material: Material,
		collidable: bool = true,
		box_rotation_degrees: Vector3 = Vector3.ZERO
	) -> Node3D:
	var mesh := StationSurfaceKit.rounded_box_mesh_cached(size, _box_cache)
	if collidable:
		var body := StaticBody3D.new()
		body.name = node_name
		body.position = box_position
		body.rotation_degrees = box_rotation_degrees
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		parent.add_child(body)
		var view := MeshInstance3D.new()
		view.name = "Mesh"
		view.mesh = mesh
		view.material_override = material
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(view)
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		return body
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = box_position
	instance.rotation_degrees = box_rotation_degrees
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _cylinder(
		parent: Node3D,
		node_name: String,
		cylinder_position: Vector3,
		top_radius: float,
		bottom_radius: float,
		height: float,
		material: Material,
		collidable: bool = true,
		cylinder_rotation_degrees: Vector3 = Vector3.ZERO,
		cap_top: bool = true,
		cap_bottom: bool = true
	) -> Node3D:
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		top_radius, bottom_radius, height, 24, _cylinder_cache, 4, cap_top, cap_bottom
	)
	if collidable:
		var body := StaticBody3D.new()
		body.name = node_name
		body.position = cylinder_position
		body.rotation_degrees = cylinder_rotation_degrees
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		parent.add_child(body)
		var view := MeshInstance3D.new()
		view.name = "Mesh"
		view.mesh = mesh
		view.material_override = material
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(view)
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = maxf(top_radius, bottom_radius)
		cylinder_shape.height = height
		shape.shape = cylinder_shape
		body.add_child(shape)
		return body
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = cylinder_position
	instance.rotation_degrees = cylinder_rotation_degrees
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## A torus is smooth everywhere and has no rim, so it is outside the surface
## kit's scope and stays on the engine primitive.
func _torus(
		parent: Node3D,
		node_name: String,
		torus_position: Vector3,
		inner_radius: float,
		outer_radius: float,
		material: Material,
		torus_rotation_degrees: Vector3
	) -> MeshInstance3D:
	var mesh := _shared_torus_mesh(inner_radius, outer_radius)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = torus_position
	instance.rotation_degrees = torus_rotation_degrees
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _shared_torus_mesh(inner_radius: float, outer_radius: float) -> TorusMesh:
	var key := _torus_recipe_key(inner_radius, outer_radius)
	if _torus_mesh_cache.has(key):
		return _torus_mesh_cache[key] as TorusMesh
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = TORUS_RINGS
	mesh.ring_segments = TORUS_RING_SEGMENTS
	_torus_mesh_cache[key] = mesh
	return mesh


## Vector4 hashing retains the exact authored float pair; unlike a formatted
## decimal key, it cannot alias nearby but distinct geometry recipes.
func _torus_recipe_key(inner_radius: float, outer_radius: float) -> Vector4:
	return Vector4(inner_radius, outer_radius, TORUS_RINGS, TORUS_RING_SEGMENTS)


func _lamp(
		parent: Node3D,
		node_name: String,
		lamp_position: Vector3,
		color: Color,
		energy: float,
		range_value: float,
		pulsing: bool
	) -> OmniLight3D:
	var lens := MeshInstance3D.new()
	lens.name = node_name + "Lens"
	lens.position = lamp_position
	lens.mesh = _shared_lamp_lens_mesh()
	lens.material_override = _lens_material(color)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(lens)
	_lamp_lenses.append(lens)

	var light := OmniLight3D.new()
	light.name = node_name
	light.position = lamp_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	parent.add_child(light)
	if pulsing:
		light.set_meta(&"pulse_phase", float(_pulse_lamps.size()) * 0.71)
		light.set_meta(&"base_energy", energy)
		_pulse_lamps.append(light)
	return light


func _sign(
		parent: Node3D,
		text: String,
		text_position: Vector3,
		text_rotation_degrees: Vector3,
		scale_value: float,
		material: Material
	) -> MeshInstance3D:
	# Same shared budget as the station: sector legends are read from a moving
	# craft at tens of metres, where a 0.03 m extrusion on a sign scaled 2.2x is
	# geometry nobody is ever placed to see. See `SignGeometryBudget`.
	var text_mesh := SignGeometryBudget.build(text)
	var instance := MeshInstance3D.new()
	instance.name = "Sign_" + text.replace(" ", "_").replace("/", "-")
	instance.position = text_position
	instance.rotation_degrees = text_rotation_degrees
	instance.scale = Vector3.ONE * scale_value
	instance.mesh = text_mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
