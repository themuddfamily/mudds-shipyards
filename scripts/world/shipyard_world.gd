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
const SHIP_BERTH_FEEDBACK_SCHEMA_VERSION := 2
const SHIP_BERTH_FEEDBACK_MATERIAL_COUNT := 4
const SHIP_BERTH_FEEDBACK_BERTH_IDS: Array[StringName] = [
	CENTRAL_BERTH_ID,
	ARROW_RECON_BERTH_ID,
	JOVIAN_FREIGHT_BERTH_ID,
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
}
const CENTRAL_HERO_SCHEMA_VERSION := 1
const OPERATIONAL_LATTICE_SCHEMA_VERSION := 1
const CENTRAL_HERO_MODULE_ID: StringName = &"central-berth-hero-cell"
const CENTRAL_HERO_SHIP_ID: StringName = &"torrent_provisional"
const CENTRAL_HERO_EVIDENCE_STATUS: StringName = &"creator_roster_supported_modern_interpretation"
const OPERATIONAL_LATTICE_EVIDENCE_STATUS: StringName = &"modern_interpretation"
const EXPECTED_STATION_ACTIVITY_COUNT := 4
const EXPECTED_STATION_AMBIENCE_COUNT := 4
const EXPECTED_STATION_DRESSING_COUNT := 4
const STATION_ACTIVITY_SPECS := {
	&"CentralTowServiceActivity": {"path": NodePath("OperationalLattice/Activities/CentralTowServiceActivity"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(6.8, 0.0, 14.0)), "profile": &"full", "seed": 1103},
	&"AftOperationsActivity": {"path": NodePath("OperationalLattice/Activities/AftOperationsActivity"), "transform": Transform3D(Basis(Vector3.UP, PI), Vector3(5.8, 4.99, 61.2)), "profile": &"service_arm", "seed": 2207},
	&"HabitatServicePatrol": {"path": NodePath("OperationalLattice/Activities/HabitatServicePatrol"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(59.15, 4.88, 15.5)), "profile": &"drone_patrol", "seed": 3301},
	&"FreightApproachGantry": {"path": NodePath("OperationalLattice/Activities/FreightApproachGantry"), "transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-53.0, 0.38, 29.7)), "profile": &"gantry", "seed": 4409},
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
const SHIPYARD_DECK_ALBEDO_PATH := "res://assets/materials/shipyard-deck-albedo-v1.png"
const SHIPYARD_DECK_NORMAL_PATH := "res://assets/materials/shipyard-deck-normal-v1.png"
const SHIPYARD_DECK_ROUGHNESS_PATH := "res://assets/materials/shipyard-deck-roughness-v1.png"
const STATION_ACTIVITY_SCENE := preload("res://scenes/world/components/station_operations_activity.tscn")
const STATION_AMBIENCE_SCENE := preload("res://scenes/audio/station_machinery_ambience.tscn")
const STATION_DRESSING_SCENE := preload("res://scenes/world/components/station_structural_service_dressing.tscn")

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

const NAVY := Color("0b1d2a")
const DEEP_BLUE := Color("10364b")
const STEEL_BLUE := Color("1c566e")
const KETH_CYAN := Color("48dbe2")
const PALE_CYAN := Color("baf7f1")
const KETH_ORANGE := Color("ff9f43")
const ALERT_RED := Color("ff5f57")
const DECK := Color("203744")
const DECK_LIGHT := Color("36505c")
const IVORY := Color("dce8e4")
const GLASS := Color(0.24, 0.86, 0.93, 0.24)

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

var _materials: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
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
var _station_operations_activities: Array[StationOperationsActivity] = []
var _station_machinery_ambience_nodes: Array[StationMachineryAmbience] = []
var _station_structural_service_dressings: Array[StationStructuralServiceDressing] = []
var _station_activity_enabled := true
var _station_door_audio_hook_count := 0
var _station_door_audio_bindings: Dictionary = {}


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
	_build_nebula_backdrop()
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
	var expected_profiles := PackedStringArray(["drone_patrol", "full", "gantry", "service_arm"])
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
		errors.append("station must integrate exactly four operations activity instances")
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

	_add_station_ambience(ambience, "CentralBerthUtilitiesAmbience", Vector3(10.65, 1.8, -19.25), &"central-berth-utilities", 4831, 44.0, 26.0, 4.0)
	_add_station_ambience(ambience, "AftOperationsAmbience", Vector3(10.0, 2.35, 60.55), &"aft-operations-service-wall", 7759, 52.0, 24.0, 3.5)
	_add_station_ambience(ambience, "HabitatEnvironmentalAmbience", Vector3(59.15, 3.2, 20.95), &"habitat-environmental-main", 9127, 39.0, 22.0, 3.0)
	_add_station_ambience(ambience, "FreightControlAmbience", Vector3(-33.75, 2.58, 57.8), &"freight-control-machinery", 12203, 61.0, 28.0, 4.0)

	_add_station_dressing(dressings, "CentralBerthOuterFascia", Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(13.5, -0.02, -10.0)), 20.0, StationStructuralServiceDressing.StructuralProfile.STANDARD)
	_add_station_dressing(dressings, "AftOperationsOuterFascia", Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(10.86, 4.6, 60.55)), 6.0, StationStructuralServiceDressing.StructuralProfile.LIGHT)
	_add_station_dressing(dressings, "HabitatOuterServiceDressing", Transform3D(Basis.IDENTITY, Vector3(59.15, 4.45, 21.94)), 12.0, StationStructuralServiceDressing.StructuralProfile.STANDARD)
	_add_station_dressing(dressings, "FreightRackServiceDressing", Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-75.34, 0.38, 56.8)), 20.0, StationStructuralServiceDressing.StructuralProfile.LIGHT)


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
	_collect_operational_lattice_components(self)


func _collect_operational_lattice_components(search_root: Node) -> void:
	for child in search_root.get_children():
		if child is StationOperationsActivity:
			_station_operations_activities.append(child as StationOperationsActivity)
		elif child is StationMachineryAmbience:
			_station_machinery_ambience_nodes.append(child as StationMachineryAmbience)
		elif child is StationStructuralServiceDressing:
			_station_structural_service_dressings.append(child as StationStructuralServiceDressing)
		_collect_operational_lattice_components(child)


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
		&"primary_truss": 5,
		&"secondary_truss": 12,
		&"deck_fascia": 4,
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

	var deck_material := _materials.get("hero_deck_surface") as StandardMaterial3D
	if deck_material == null:
		errors.append("hero deck PBR material is unavailable")
	else:
		if deck_material.albedo_texture == null \
				or deck_material.albedo_texture.resource_path != SHIPYARD_DECK_ALBEDO_PATH:
			errors.append("hero deck albedo map is not assigned")
		if not deck_material.normal_enabled \
				or deck_material.normal_texture == null \
				or deck_material.normal_texture.resource_path != SHIPYARD_DECK_NORMAL_PATH:
			errors.append("hero deck normal map is not assigned")
		if deck_material.roughness_texture == null \
				or deck_material.roughness_texture.resource_path != SHIPYARD_DECK_ROUGHNESS_PATH:
			errors.append("hero deck roughness map is not assigned")
		if not deck_material.uv1_triplanar:
			errors.append("hero deck material is not triplanar")

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
		"deck_pbr": {
			"albedo": SHIPYARD_DECK_ALBEDO_PATH,
			"normal": SHIPYARD_DECK_NORMAL_PATH,
			"roughness": SHIPYARD_DECK_ROUGHNESS_PATH,
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
	_materials["deck"] = _material(DECK, 0.08, 0.78)
	_materials["deck_light"] = _material(DECK_LIGHT, 0.18, 0.66)
	_materials["navy"] = _material(NAVY, 0.12, 0.72)
	_materials["blue"] = _material(DEEP_BLUE, 0.22, 0.58)
	_materials["steel_blue"] = _material(STEEL_BLUE, 0.32, 0.48)
	_materials["ivory"] = _material(IVORY, 0.08, 0.55)
	_materials["orange"] = _material(KETH_ORANGE, 0.16, 0.5)
	_materials["red"] = _material(ALERT_RED, 0.1, 0.5)
	_materials["black"] = _material(Color("03080d"), 0.15, 0.72)
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

	# This purpose-built finish is intentionally isolated to the thin operational
	# walking skin. Structure, fascia, pressure hardware, signs, and distant set
	# dressing retain separate untinted materials rather than inheriting a ship or
	# deck texture through a shared key.
	var hero_deck := _material(Color("253c45"), 0.48, 0.62)
	var deck_albedo := load(SHIPYARD_DECK_ALBEDO_PATH) as Texture2D
	var deck_normal := load(SHIPYARD_DECK_NORMAL_PATH) as Texture2D
	var deck_roughness := load(SHIPYARD_DECK_ROUGHNESS_PATH) as Texture2D
	hero_deck.albedo_texture = deck_albedo
	hero_deck.normal_enabled = deck_normal != null
	hero_deck.normal_texture = deck_normal
	hero_deck.normal_scale = 0.42
	hero_deck.roughness_texture = deck_roughness
	hero_deck.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	hero_deck.uv1_triplanar = true
	hero_deck.uv1_triplanar_sharpness = 4.5
	hero_deck.uv1_scale = Vector3.ONE * 0.16
	hero_deck.clearcoat_enabled = true
	hero_deck.clearcoat = 0.2
	hero_deck.clearcoat_roughness = 0.58
	_materials["hero_deck_surface"] = hero_deck


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ShipyardEnvironment"
	var environment := Environment.new()
	var sky := Sky.new()
	# Use the project's wide original nebula as a continuous panorama rather
	# than a finite quad. The old plane exposed hard black edges whenever flight
	# pitch or a wide camera crossed its bounds, which made space read like a set.
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://assets/keth-nebula.png") as Texture2D
	sky_material.filter = true
	sky_material.energy_multiplier = 0.72
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.55
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6db3bd")
	environment.ambient_light_energy = 0.44
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.94
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	environment.glow_bloom = 0.08
	environment.fog_enabled = true
	environment.fog_light_color = Color("183849")
	environment.fog_light_energy = 0.38
	environment.fog_density = 0.00065
	environment.fog_sky_affect = 0.08
	world_environment.environment = environment
	add_child(world_environment)
	_visual_quality_report = VisualQualityController.apply_profile(
		environment,
		get_viewport(),
		visual_quality_level
	)

	var key_light := DirectionalLight3D.new()
	key_light.name = "SpaceKeyLight"
	key_light.rotation_degrees = Vector3(-34.0, -28.0, 0.0)
	key_light.light_color = Color("b8edf1")
	key_light.light_energy = 0.84
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 180.0
	add_child(key_light)

	# Freestanding light masts keep the open decks readable without implying a
	# roof. Exact placement is a modern blockout decision.
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
		light.spot_range = 22.0 if is_hero_work_light else 24.0
		light.spot_angle = 39.0
		light.shadow_enabled = true
		light.set_meta("central_berth_key_light", is_hero_work_light)
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
	_box(shell, "CentralJunction", Vector3(0, -0.62, 14.0), Vector3(25.0, 1.2, 18.0), _materials["deck"])
	_box(shell, "HeroBerthNode", Vector3(0, -0.62, -10.0), Vector3(27.0, 1.2, 30.0), _materials["deck"])
	_box(shell, "JunctionLink", Vector3(0, -0.62, 1.5), Vector3(13.0, 1.2, 9.0), _materials["deck_light"])
	_box(shell, "PortBranchArm", Vector3(-25.0, -0.62, 15.5), Vector3(25.0, 1.2, 7.0), _materials["deck_light"])
	_box(shell, "PortBerthNode", Vector3(-43.0, -0.62, 15.5), Vector3(12.0, 1.2, 17.0), _materials["deck"])
	_box(shell, "StarboardBranchArm", Vector3(25.0, -0.62, 15.5), Vector3(25.0, 1.2, 7.0), _materials["deck_light"])
	_box(shell, "StarboardBerthNode", Vector3(43.0, -0.62, 15.5), Vector3(12.0, 1.2, 17.0), _materials["deck"])
	_box(shell, "AftSpine", Vector3(0, -0.62, 31.0), Vector3(8.0, 1.2, 16.0), _materials["deck_light"])
	# The first authored station module begins at Z=48. This narrow landing
	# bridges the original spine to that module's connection plane without
	# hiding its open-space footprint beneath a legacy service slab.
	_box(shell, "AftModuleConnector", Vector3(0, -0.62, 43.5), Vector3(7.0, 1.2, 9.0), _materials["deck_light"])

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
	for side in [-1.0, 1.0]:
		for z_edge in [12.0, 19.0]:
			_box(shell, "BranchRail", Vector3(side * 27.0, 1.15, z_edge), Vector3(31.0, 0.18, 0.18), _materials["ivory"])
			for x_position in [13.0, 21.0, 29.0, 37.0, 49.0]:
				_box(shell, "BranchRailPost", Vector3(side * x_position, 0.55, z_edge), Vector3(0.18, 1.3, 0.18), _materials["orange"])
	for side in [-1.0, 1.0]:
		_box(shell, "AftSpineRail", Vector3(side * 4.0, 1.15, 31.0), Vector3(0.18, 0.18, 17.0), _materials["ivory"])
		for z_position in [24.0, 30.0, 36.0]:
			_box(shell, "AftRailPost", Vector3(side * 4.0, 0.55, z_position), Vector3(0.18, 1.3, 0.18), _materials["orange"])
		_box(shell, "AftConnectorRail", Vector3(side * 3.35, 1.15, 43.5), Vector3(0.18, 0.18, 9.0), _materials["ivory"])
		for z_position in [40.0, 44.0, 47.5]:
			_box(shell, "AftConnectorRailPost", Vector3(side * 3.35, 0.55, z_position), Vector3(0.18, 1.3, 0.18), _materials["orange"])

	# Freestanding rounded mast pairs establish several readable heights without
	# becoming a roof cage.
	for mast_position in [Vector3(-11.0, 0.0, 10.0), Vector3(11.0, 0.0, 10.0), Vector3(-11.0, 0.0, -23.0), Vector3(11.0, 0.0, -23.0)]:
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
	_text_sign(
		shell,
		"MUDDS  //  REGENERATION DECK",
		Vector3(0, 7.65, 21.86),
		Vector3.ZERO,
		0.54,
		_materials["cyan_glow"]
	)
	_text_sign(
		shell,
		"CENTRAL JUNCTION  //  FLEET DOCKS",
		Vector3(0, 7.08, 21.84),
		Vector3.ZERO,
		0.27,
		_materials["orange_glow"]
	)


func _build_landing_pad() -> void:
	var pad := Node3D.new()
	pad.name = "LandingPad"
	add_child(pad)
	_central_berth_root = pad
	_apply_central_berth_metadata(pad)
	_build_central_berth_understructure(pad)

	var pad_inset := _box(
		pad,
		"PadInset",
		Vector3(0, 0.045, -10),
		Vector3(25.5, 0.1, 35.5),
		_materials["hero_deck_surface"],
		false
	)
	pad_inset.set_meta("surface_role", &"operational_walking_deck")
	pad_inset.set_meta("deck_pbr_scope", &"central_berth_top_skin")
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
	# recon interpretation. Only Arrow's creator-proven name/role and two-pod
	# requirement carry historical support; this berth label and placement are
	# modern layout decisions and do not authenticate the model or adjacency.
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


func _build_central_berth_understructure(pad: Node3D) -> void:
	var structure := Node3D.new()
	structure.name = "HeroBerthStructure"
	structure.set_meta("surface_role", &"structural_lattice")
	pad.add_child(structure)

	var fascia_specs := [
		["PortDeckFascia", Vector3(-13.32, -0.62, -10.0), Vector3(0.34, 1.12, 29.4)],
		["StarboardDeckFascia", Vector3(13.32, -0.62, -10.0), Vector3(0.34, 1.12, 29.4)],
		["ForwardDeckFascia", Vector3(0.0, -0.62, -24.82), Vector3(26.3, 1.12, 0.34)],
		["AftDeckFascia", Vector3(0.0, -0.62, 4.82), Vector3(26.3, 1.12, 0.34)],
	]
	for spec: Array in fascia_specs:
		var fascia := _box(
			structure,
			spec[0] as String,
			spec[1] as Vector3,
			spec[2] as Vector3,
			_materials["navy"],
			false
		)
		fascia.set_meta("surface_role", &"deck_fascia")
		_tag_central_feature(fascia, &"deck_fascia")

	# Two deep longitudinal chords and three transverse girders make the pad mass
	# legible from launch and open-space angles without adding gameplay collision.
	for side in [-1.0, 1.0]:
		var long_truss := _box(
			structure,
			"PrimaryLongitudinalTruss",
			Vector3(side * 7.25, -1.78, -10.0),
			Vector3(0.72, 0.72, 28.6),
			_materials["steel_blue"],
			false
		)
		_tag_central_feature(long_truss, &"primary_truss")
	for z_position in [-20.8, -10.0, 0.8]:
		var cross_truss := _box(
			structure,
			"PrimaryCrossTruss",
			Vector3(0.0, -1.7, z_position),
			Vector3(24.8, 0.58, 0.72),
			_materials["steel_blue"],
			false
		)
		_tag_central_feature(cross_truss, &"primary_truss")

	# Paired diagonals form three restrained X bays on each exposed side.
	for side in [-1.0, 1.0]:
		for z_position in [-19.0, -10.0, -1.0]:
			for lean in [-1.0, 1.0]:
				var brace := _box(
					structure,
					"SecondaryDiagonalTruss",
					Vector3(side * 11.9, -1.48, z_position),
					Vector3(0.24, 0.3, 6.4),
					_materials["orange"],
					false,
					Vector3(lean * 13.0, 0.0, 0.0)
				)
				_tag_central_feature(brace, &"secondary_truss")


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


func _build_launch_corridor() -> void:
	var launch := Node3D.new()
	launch.name = "OpenLaunchSpine"
	add_child(launch)

	# A narrow exposed flight arm replaces the previous enclosed runway. Width is
	# a modern safety allowance for the hero ship, not an inferred measurement.
	_box(launch, "LaunchArmDeck", Vector3(0, -0.36, -48.0), Vector3(21.5, 0.72, 40.0), _materials["navy"])
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
	for step in 7:
		var progress := float(step) / 6.0
		_box(
			upper,
			"JunctionAccessStep",
			Vector3(-11.5, 0.16 + progress * 2.55, 9.0 - progress * 3.6),
			Vector3(3.6, 0.34, 1.05),
			_materials["deck_light"]
		)
	for side in [-1.0, 1.0]:
		_box(upper, "JunctionStairRail", Vector3(-11.5 + side * 1.85, 2.2, 7.2), Vector3(0.15, 0.15, 5.2), _materials["orange"], true, Vector3(38, 0, 0))
		_box(upper, "LandingRail", Vector3(-11.5 + side * 2.15, 4.0, 3.0), Vector3(0.16, 1.65, 4.4), _materials["ivory"])
	_box(upper, "LandingEndRail", Vector3(-11.5, 4.0, 0.85), Vector3(4.4, 1.65, 0.16), _materials["ivory"])

	# A compact modern operations pod is attached to, rather than enclosing, the
	# starboard node. Its purpose and adjacency are not recovered original facts.
	_box(upper, "OperationsPodFloor", Vector3(43.0, 0.18, 27.0), Vector3(12.0, 0.4, 8.0), _materials["deck_light"])
	_box(upper, "OperationsPodRoof", Vector3(43.0, 5.9, 27.0), Vector3(12.0, 0.55, 8.0), _materials["ivory"])
	_box(upper, "OperationsPodBack", Vector3(43.0, 3.0, 30.8), Vector3(12.0, 5.5, 0.5), _materials["steel_blue"])
	for x_position in [37.5, 41.2, 44.8, 48.5]:
		_box(upper, "OperationsWindowMullion", Vector3(x_position, 3.0, 22.95), Vector3(0.26, 5.4, 0.32), _materials["steel_blue"])
		_box(upper, "OperationsWindow", Vector3(x_position + 1.75, 3.0, 22.8), Vector3(3.15, 4.7, 0.08), _materials["glass"], false)
	_text_sign(
		upper,
		"DOCK OPERATIONS",
		Vector3(43.0, 5.15, 22.68),
		Vector3.ZERO,
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

	_box(gallery, "RegistryPodDeck", Vector3(-43.0, 0.18, 27.0), Vector3(12.0, 0.4, 8.0), _materials["deck_light"])
	_box(gallery, "RegistryPodBack", Vector3(-43.0, 3.0, 30.8), Vector3(12.0, 5.5, 0.5), _materials["ivory"])
	_box(gallery, "RegistryPodRoof", Vector3(-43.0, 5.9, 27.0), Vector3(12.0, 0.55, 8.0), _materials["steel_blue"])
	_text_sign(
		gallery,
		"FLEET REGISTRY  //  MODERN INTERFACE",
		Vector3(-43.0, 5.05, 22.82),
		Vector3.ZERO,
		0.4,
		_materials["orange_glow"]
	)

	var terminal_position := Vector3(-43.0, 1.45, 24.6)
	_box(gallery, "FleetRegistryTerminal", terminal_position, Vector3(4.6, 2.7, 1.9), _materials["navy"])
	_box(gallery, "RegistryScreen", terminal_position + Vector3(0, 0.42, -0.98), Vector3(3.8, 1.35, 0.06), _materials["cyan_glow"], false)
	_text_sign(gallery, "SAY SHIP NAME", terminal_position + Vector3(0, 0.72, -1.03), Vector3.ZERO, 0.34, _materials["black"])
	_text_sign(gallery, "TORRENT  JOVIAN  TITAN  VORTEX", terminal_position + Vector3(0, 0.25, -1.04), Vector3.ZERO, 0.18, _materials["black"])
	_text_sign(gallery, "KATANA  PARADOX  PREDATOR  DYNAMIC", terminal_position + Vector3(0, -0.02, -1.04), Vector3.ZERO, 0.14, _materials["black"])
	_text_sign(gallery, "UTOPIA  ARROW", terminal_position + Vector3(0, -0.27, -1.04), Vector3.ZERO, 0.15, _materials["black"])
	_add_guide_light(gallery, terminal_position + Vector3(1.72, 0.95, -1.05), KETH_ORANGE, false, 1.4, 6.0)

	# Physical destination indicator for the active berth. It communicates the
	# modern slice workflow but makes no name-to-silhouette historical claim.
	_cylinder(gallery, "BerthIndicatorBase", Vector3(-38.5, 0.75, 27.6), 1.05, 1.4, _materials["steel_blue"], true)
	_torus(gallery, "BerthIndicatorRing", Vector3(-38.5, 1.52, 27.6), 0.72, 0.92, _materials["cyan_glow"])
	_box(gallery, "BerthIndicatorNeedle", Vector3(-38.5, 2.55, 27.6), Vector3(0.16, 2.1, 0.16), _materials["orange_glow"], false)
	_text_sign(gallery, "ACTIVE BERTH  //  CENTRE SPINE", Vector3(-38.5, 3.35, 26.9), Vector3.ZERO, 0.2, _materials["white_glow"])


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

	_box(props, "TowTractor", Vector3(7.0, 0.7, 18.0), Vector3(3.8, 1.1, 2.3), _materials["orange"])
	_box(props, "TowCab", Vector3(7.7, 1.55, 18.0), Vector3(1.5, 0.9, 1.9), _materials["ivory"])
	for z_side in [-1.0, 1.0]:
		for x_position in [5.9, 8.0]:
			_cylinder(
				props,
				"TowWheel",
				Vector3(x_position, 0.45, 18.0 + z_side * 1.15),
				0.4,
				0.25,
				_materials["black"],
				false,
				Vector3(90, 0, 0)
			)

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


func _build_nebula_backdrop() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "SpaceBackdrop"
	add_child(backdrop)

	# A sparse star volume adds parallax ahead of the panoramic sky.
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.12
	star_mesh.height = 0.24
	star_mesh.radial_segments = 6
	star_mesh.rings = 3
	star_mesh.material = _materials["white_glow"]
	var stars := MultiMeshInstance3D.new()
	stars.name = "ParallaxStars"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = star_mesh
	multimesh.instance_count = 140
	var random := RandomNumberGenerator.new()
	random.seed = 19780704
	for index in multimesh.instance_count:
		var star_position := Vector3(
			random.randf_range(-150.0, 150.0),
			random.randf_range(-65.0, 100.0),
			random.randf_range(-245.0, -88.0)
		)
		var scale_value := random.randf_range(0.45, 2.2)
		multimesh.set_instance_transform(
			index,
			Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), star_position)
		)
	stars.multimesh = multimesh
	backdrop.add_child(stars)

	_sphere(backdrop, "DistantMoon", Vector3(91, -18, -220), 18.0, _materials["deck_light"], false)
	_torus(backdrop, "MoonRing", Vector3(91, -18, -220), 25.0, 26.2, _materials["orange"], Vector3(68, 20, 4))


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
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
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


func _rounded_box_mesh(size: Vector3) -> ArrayMesh:
	var cache_key := "%0.4f:%0.4f:%0.4f" % [size.x, size.y, size.z]
	if _rounded_box_cache.has(cache_key):
		return _rounded_box_cache[cache_key] as ArrayMesh

	var half := size * 0.5
	var bevel := minf(0.2, minf(size.x, minf(size.y, size.z)) * 0.22)
	bevel = maxf(bevel, 0.003)
	var inner_half := Vector3(
		maxf(0.0, half.x - bevel),
		maxf(0.0, half.y - bevel),
		maxf(0.0, half.z - bevel)
	)
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
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
				var u0 := float(u_index) / 3.0
				var u1 := float(u_index + 1) / 3.0
				var v0 := float(v_index) / 3.0
				var v1 := float(v_index + 1) / 3.0
				_add_rounded_box_vertex(surface_tool, points[0], inner_half, bevel, Vector2(u0, v0))
				_add_rounded_box_vertex(surface_tool, points[1], inner_half, bevel, Vector2(u1, v0))
				_add_rounded_box_vertex(surface_tool, points[2], inner_half, bevel, Vector2(u1, v1))
				_add_rounded_box_vertex(surface_tool, points[0], inner_half, bevel, Vector2(u0, v0))
				_add_rounded_box_vertex(surface_tool, points[2], inner_half, bevel, Vector2(u1, v1))
				_add_rounded_box_vertex(surface_tool, points[3], inner_half, bevel, Vector2(u0, v1))
	# Rounded procedural primitives now support the hero deck normal map. The UV
	# atlas is generated above, so tangents are deterministic and cacheable too.
	surface_tool.generate_tangents()
	var rounded_mesh := surface_tool.commit()
	_rounded_box_cache[cache_key] = rounded_mesh
	return rounded_mesh


func _add_rounded_box_vertex(
		surface_tool: SurfaceTool,
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
	surface_tool.set_normal(normal)
	surface_tool.set_uv(uv)
	surface_tool.add_vertex(closest + normal * bevel)


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

	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = height
	cylinder_mesh.radial_segments = 24
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
